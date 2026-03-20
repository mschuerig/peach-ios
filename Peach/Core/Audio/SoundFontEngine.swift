import AVFoundation
import os

final class SoundFontEngine {

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.peach.app", category: "SoundFontEngine")

    // MARK: - Audio Components

    private let engine: AVAudioEngine
    let sampler: AVAudioUnitSampler

    // MARK: - State

    private var loadedPreset: SF2Preset

    // MARK: - Constants

    private nonisolated static let channel: UInt8 = 0
    private nonisolated static let defaultBankMSB: UInt8 = 0x79 // kAUSampler_DefaultMelodicBankMSB

    /// Pitch bend range in semitones, set via MIDI RPN in `sendPitchBendRange()`.
    /// All pitch bend calculations derive their cent limits from this value.
    nonisolated static let pitchBendRangeSemitones: Int = 2

    /// Maximum pitch bend displacement in cents, derived from `pitchBendRangeSemitones`.
    nonisolated static let pitchBendRangeCents: Double = Double(pitchBendRangeSemitones) * 100.0

    // MARK: - SF2 URL

    private let sf2URL: URL

    // MARK: - Initialization

    init(library: SoundFontLibrary, soundSource: any SoundSourceID) throws {
        let preset = library.resolve(soundSource)
        self.sf2URL = library.sf2URL
        self.engine = AVAudioEngine()
        self.sampler = AVAudioUnitSampler()
        self.loadedPreset = preset

        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)

        try Self.configureAudioSession()
        try engine.start()
        try sampler.loadSoundBankInstrument(
            at: sf2URL,
            program: UInt8(preset.program),
            bankMSB: Self.defaultBankMSB,
            bankLSB: UInt8(preset.bank)
        )

        sendPitchBendRange()

        logger.info("SoundFontEngine initialized with \(library.sf2URL.lastPathComponent), preset \(preset.rawValue)")
    }

    isolated deinit {
        engine.stop()
    }

    // MARK: - Audio Session & Engine Lifecycle

    func ensureAudioSessionConfigured() throws {
        try Self.configureAudioSession()
    }

    func ensureEngineRunning() throws {
        if !engine.isRunning {
            try engine.start()
        }
    }

    // MARK: - Preset Loading

    func loadPreset(_ preset: SF2Preset) async throws {
        guard (0...127).contains(preset.program) else {
            throw AudioError.invalidPreset("Program \(preset.program) outside valid MIDI range 0-127")
        }
        guard (0...127).contains(preset.bank) else {
            throw AudioError.invalidPreset("Bank \(preset.bank) outside valid range 0-127")
        }
        guard preset != loadedPreset else { return }

        try sampler.loadSoundBankInstrument(
            at: sf2URL,
            program: UInt8(clamping: preset.program),
            bankMSB: Self.defaultBankMSB,
            bankLSB: UInt8(clamping: preset.bank)
        )

        loadedPreset = preset

        sendPitchBendRange()

        // Allow audio graph to settle after instrument load — without this delay
        // the first MIDI note-on after a preset switch produces no sound.
        try await Task.sleep(for: .milliseconds(20))

        logger.info("Loaded preset \(preset.rawValue)")
    }

    // MARK: - Immediate MIDI Dispatch

    func startNote(_ midiNote: MIDINote, velocity: MIDIVelocity, amplitudeDB: AmplitudeDB, pitchBend: PitchBendValue) {
        sampler.sendPitchBend(pitchBend.rawValue, onChannel: Self.channel)
        sampler.overallGain = Float(amplitudeDB.rawValue)
        sampler.startNote(UInt8(midiNote.rawValue), withVelocity: velocity.rawValue, onChannel: Self.channel)
    }

    func stopNote(_ midiNote: MIDINote) {
        sampler.stopNote(UInt8(midiNote.rawValue), onChannel: Self.channel)
    }

    func stopAllNotes(stopPropagationDelay: Duration) async {
        if stopPropagationDelay > .zero {
            sampler.volume = 0
            try? await Task.sleep(for: stopPropagationDelay)
        }
        sampler.sendController(123, withValue: 0, onChannel: Self.channel)
        sampler.sendPitchBend(PitchBendValue.center.rawValue, onChannel: Self.channel)
        if stopPropagationDelay > .zero {
            sampler.volume = 1.0
        }
    }

    func sendPitchBend(_ value: PitchBendValue) {
        sampler.sendPitchBend(value.rawValue, onChannel: Self.channel)
    }

    // MARK: - Audio Session

    private static func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true)
    }

    // MARK: - MIDI Helpers

    private func sendPitchBendRange() {
        // MIDI RPN 0x0000 (Pitch Bend Sensitivity): set range to ±pitchBendRangeSemitones
        sampler.sendController(101, withValue: 0, onChannel: Self.channel)   // RPN MSB
        sampler.sendController(100, withValue: 0, onChannel: Self.channel)   // RPN LSB
        sampler.sendController(6, withValue: UInt8(Self.pitchBendRangeSemitones), onChannel: Self.channel)  // Data Entry MSB (semitones)
        sampler.sendController(38, withValue: 0, onChannel: Self.channel)    // Data Entry LSB (cents)
    }
}
