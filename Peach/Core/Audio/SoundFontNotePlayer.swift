import AVFoundation
import Foundation
import os

final class SoundFontNotePlayer: NotePlayer {

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.peach.app", category: "SoundFontNotePlayer")

    // MARK: - Audio Components

    private let engine: AVAudioEngine
    private let sampler: AVAudioUnitSampler

    // MARK: - State

    private var isSessionConfigured = false
    private var loadedProgram: Int
    private var loadedBank: Int

    // MARK: - Constants

    nonisolated static let channel: UInt8 = 0
    private nonisolated static let defaultBankMSB: UInt8 = 0x79 // kAUSampler_DefaultMelodicBankMSB
    nonisolated static let pitchBendCenter: UInt16 = 8192
    nonisolated static let validFrequencyRange = 20.0...20000.0

    /// Pitch bend range in semitones, set via MIDI RPN in `sendPitchBendRange()`.
    /// All pitch bend calculations derive their cent limits from this value.
    nonisolated static let pitchBendRangeSemitones: Int = 2

    /// Maximum pitch bend displacement in cents, derived from `pitchBendRangeSemitones`.
    nonisolated static let pitchBendRangeCents: Double = Double(pitchBendRangeSemitones) * 100.0
    /// Duration to mute `sampler.volume` before stopping a note, allowing the audio render
    /// thread to propagate silence and avoid click/pop artifacts. Set to `.zero` to skip the
    /// fade-out entirely (notes stop immediately). 25ms covers 2+ render cycles at 44.1kHz/512.
    let stopPropagationDelay: Duration

    // MARK: - Dependencies

    private let library: SoundFontLibrary
    private let userSettings: UserSettings

    // MARK: - Initialization

    init(library: SoundFontLibrary, userSettings: UserSettings, stopPropagationDelay: Duration = .milliseconds(25)) throws {
        let initial = library.resolve(userSettings.soundSource)

        self.library = library
        self.userSettings = userSettings
        self.stopPropagationDelay = stopPropagationDelay
        self.engine = AVAudioEngine()
        self.sampler = AVAudioUnitSampler()
        self.loadedProgram = initial.program
        self.loadedBank = initial.bank

        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)

        try engine.start()
        try sampler.loadSoundBankInstrument(
            at: library.sf2URL,
            program: UInt8(initial.program),
            bankMSB: Self.defaultBankMSB,
            bankLSB: UInt8(initial.bank)
        )

        sendPitchBendRange()

        logger.info("SoundFontNotePlayer initialized with \(library.sf2URL.lastPathComponent), preset sf2:\(initial.bank):\(initial.program)")
    }

    // MARK: - Preset Switching

    func loadPreset(program: Int, bank: Int = 0) async throws {
        guard (0...127).contains(program) else {
            throw AudioError.invalidPreset("Program \(program) outside valid MIDI range 0-127")
        }
        guard (0...127).contains(bank) else {
            throw AudioError.invalidPreset("Bank \(bank) outside valid range 0-127")
        }
        guard program != loadedProgram || bank != loadedBank else { return }

        try sampler.loadSoundBankInstrument(
            at: library.sf2URL,
            program: UInt8(clamping: program),
            bankMSB: Self.defaultBankMSB,
            bankLSB: UInt8(clamping: bank)
        )

        loadedProgram = program
        loadedBank = bank

        sendPitchBendRange()

        // Allow audio graph to settle after instrument load — without this delay
        // the first MIDI note-on after a preset switch produces no sound.
        try await Task.sleep(for: .milliseconds(20))

        logger.info("Loaded preset bank \(bank) program \(program)")
    }

    // MARK: - NotePlayer Protocol

    func play(frequency: Frequency, velocity: MIDIVelocity, amplitudeDB: AmplitudeDB) async throws -> PlaybackHandle {
        try await ensurePresetLoaded()
        try validateFrequency(frequency)
        try ensureAudioSessionConfigured()
        try ensureEngineRunning()
        let midiNote = startNote(frequency: frequency, velocity: velocity, amplitudeDB: amplitudeDB)
        return SoundFontPlaybackHandle(sampler: sampler, midiNote: midiNote, channel: Self.channel, stopPropagationDelay: stopPropagationDelay)
    }

    func stopAll() async throws {
        if stopPropagationDelay > .zero {
            sampler.volume = 0
            try? await Task.sleep(for: stopPropagationDelay)
        }
        sampler.sendController(123, withValue: 0, onChannel: Self.channel)
        sampler.sendPitchBend(Self.pitchBendCenter, onChannel: Self.channel)
        if stopPropagationDelay > .zero {
            sampler.volume = 1.0
        }
    }

    // MARK: - Play Sub-operations

    private func ensurePresetLoaded() async throws {
        let resolved = library.resolve(userSettings.soundSource)
        do {
            try await loadPreset(program: resolved.program, bank: resolved.bank)
        } catch {
            let fallback = library.resolve(SettingsKeys.defaultSoundSource)
            try await loadPreset(program: fallback.program, bank: fallback.bank)
        }
    }

    private func validateFrequency(_ frequency: Frequency) throws {
        let freq = frequency.rawValue
        guard Self.validFrequencyRange.contains(freq) else {
            throw AudioError.invalidFrequency(
                "Frequency \(freq) Hz is outside valid range \(Self.validFrequencyRange)"
            )
        }
    }

    private func ensureAudioSessionConfigured() throws {
        if !isSessionConfigured {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            isSessionConfigured = true
        }
    }

    private func ensureEngineRunning() throws {
        if !engine.isRunning {
            try engine.start()
        }
    }

    private func startNote(frequency: Frequency, velocity: MIDIVelocity, amplitudeDB: AmplitudeDB) -> UInt8 {
        let decomposed = Self.decompose(frequency: frequency)
        let midiNote = decomposed.note
        let bendValue = Self.pitchBendValue(forCents: decomposed.cents)
        sampler.overallGain = Float(amplitudeDB.rawValue)
        sampler.sendPitchBend(bendValue, onChannel: Self.channel)
        sampler.startNote(midiNote, withVelocity: velocity.rawValue, onChannel: Self.channel)
        return midiNote
    }

    // MARK: - MIDI Helpers

    private func sendPitchBendRange() {
        // MIDI RPN 0x0000 (Pitch Bend Sensitivity): set range to ±pitchBendRangeSemitones
        sampler.sendController(101, withValue: 0, onChannel: Self.channel)   // RPN MSB
        sampler.sendController(100, withValue: 0, onChannel: Self.channel)   // RPN LSB
        sampler.sendController(6, withValue: UInt8(Self.pitchBendRangeSemitones), onChannel: Self.channel)  // Data Entry MSB (semitones)
        sampler.sendController(38, withValue: 0, onChannel: Self.channel)    // Data Entry LSB (cents)
    }

    // MARK: - Static Helpers

    nonisolated static func pitchBendValue(forCents cents: Cents) -> UInt16 {
        let raw = Int(Double(pitchBendCenter) + cents.rawValue * Double(pitchBendCenter) / pitchBendRangeCents)
        let clamped = Swift.min(16383, Swift.max(0, raw))
        return UInt16(clamped)
    }

    /// Decomposes a frequency into its nearest MIDI note and cent remainder.
    /// Always uses 12-TET at concert pitch (A4=440Hz) — this is a MIDI
    /// implementation detail, not a musical tuning choice.
    nonisolated static func decompose(frequency: Frequency) -> (note: UInt8, cents: Cents) {
        let referenceMIDINote = 69
        let semitonesPerOctave = 12.0
        let centsPerSemitone = 100.0
        let concert440 = 440.0
        let midiRange = 0...127

        let exactMidi = Double(referenceMIDINote)
            + semitonesPerOctave * log2(frequency.rawValue / concert440)
        let roundedMidi = Int(exactMidi.rounded())
        let centsRemainder = (exactMidi - Double(roundedMidi)) * centsPerSemitone
        let clampedMidi = roundedMidi.clamped(to: midiRange)
        return (note: UInt8(clampedMidi), cents: Cents(centsRemainder))
    }

}
