import AVFoundation
import Foundation
import os

final class SoundFontNotePlayer: NotePlayer {

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.peach.app", category: "SoundFontNotePlayer")

    // MARK: - Audio Components

    private let soundFontEngine: SoundFontEngine

    // MARK: - Constants

    nonisolated static let validFrequencyRange = 20.0...20000.0

    /// Duration to mute `sampler.volume` before stopping a note, allowing the audio render
    /// thread to propagate silence and avoid click/pop artifacts. Set to `.zero` to skip the
    /// fade-out entirely (notes stop immediately). 25ms covers 2+ render cycles at 44.1kHz/512.
    let stopPropagationDelay: Duration

    // MARK: - Dependencies

    private let library: SoundFontLibrary
    private let userSettings: UserSettings

    // MARK: - Initialization

    init(engine: SoundFontEngine, library: SoundFontLibrary, userSettings: UserSettings, stopPropagationDelay: Duration = .milliseconds(25)) {
        self.soundFontEngine = engine
        self.library = library
        self.userSettings = userSettings
        self.stopPropagationDelay = stopPropagationDelay

        logger.info("SoundFontNotePlayer initialized with delegated SoundFontEngine")
    }

    // MARK: - Preset Switching

    func loadPreset(program: Int, bank: Int = 0) async throws {
        try await soundFontEngine.loadPreset(SF2Preset(name: "", program: program, bank: bank))
    }

    // MARK: - NotePlayer Protocol

    func play(frequency: Frequency, velocity: MIDIVelocity, amplitudeDB: AmplitudeDB) async throws -> PlaybackHandle {
        try await ensurePresetLoaded()
        try validateFrequency(frequency)
        try soundFontEngine.ensureAudioSessionConfigured()
        try soundFontEngine.ensureEngineRunning()
        let midiNote = startNote(frequency: frequency, velocity: velocity, amplitudeDB: amplitudeDB)
        return SoundFontPlaybackHandle(engine: soundFontEngine, midiNote: midiNote, stopPropagationDelay: stopPropagationDelay)
    }

    func stopAll() async throws {
        await soundFontEngine.stopAllNotes(stopPropagationDelay: stopPropagationDelay)
    }

    // MARK: - Play Sub-operations

    private func ensurePresetLoaded() async throws {
        let resolved = library.resolve(userSettings.soundSource)
        do {
            try await soundFontEngine.loadPreset(resolved)
        } catch {
            let fallback = library.resolve(SoundSourceTag(rawValue: SettingsKeys.defaultSoundSource))
            try await soundFontEngine.loadPreset(fallback)
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

    private func startNote(frequency: Frequency, velocity: MIDIVelocity, amplitudeDB: AmplitudeDB) -> MIDINote {
        let decomposed = Self.decompose(frequency: frequency)
        let midiNote = MIDINote(Int(decomposed.note))
        let bendValue = Self.pitchBendValue(forCents: decomposed.cents)
        soundFontEngine.startNote(midiNote, velocity: velocity, amplitudeDB: amplitudeDB, pitchBend: bendValue)
        return midiNote
    }

    // MARK: - Static Helpers

    nonisolated static func pitchBendValue(forCents cents: Cents) -> PitchBendValue {
        let center = Double(PitchBendValue.center.rawValue)
        let raw = Int(center + cents.rawValue * center / SoundFontEngine.pitchBendRangeCents)
        let clamped = Swift.min(16383, Swift.max(0, raw))
        return PitchBendValue(UInt16(clamped))
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
