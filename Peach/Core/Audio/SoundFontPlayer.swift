import AVFoundation
import Foundation
import os

final class SoundFontPlayer: NotePlayer {

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.peach.app", category: "SoundFontPlayer")

    // MARK: - Audio Components

    private let soundFontEngine: SoundFontEngine

    // MARK: - Constants

    nonisolated static let validFrequencyRange = 20.0...20000.0

    /// Duration to mute `sampler.volume` before stopping a note, allowing the audio render
    /// thread to propagate silence and avoid click/pop artifacts. Set to `.zero` to skip the
    /// fade-out entirely (notes stop immediately). 25ms covers 2+ render cycles at 44.1kHz/512.
    let fadeOutDuration: Duration

    // MARK: - Preset

    private let preset: SF2Preset

    // MARK: - Channel

    private let channel: MIDIChannel

    // MARK: - Audio-stop serialization

    /// Tail of the serial audio-operation chain. `scheduleStopAll()` updates
    /// this synchronously so any subsequent caller can see the stop in the
    /// chain at call time; `play()` awaits it before issuing its noteOn so
    /// a stop fade-out from a different session sharing this instance cannot
    /// silence the new note.
    private var pendingAudioStop: Task<Void, Never>?

    // MARK: - Initialization

    init(engine: SoundFontEngine, preset: SF2Preset, channel: MIDIChannel, fadeOutDuration: Duration) {
        self.soundFontEngine = engine
        self.preset = preset
        self.channel = channel
        self.fadeOutDuration = fadeOutDuration

        logger.info("SoundFontPlayer initialized on channel \(channel.rawValue) with preset \(preset.rawValue)")
    }

    // MARK: - NotePlayer Protocol

    func play(frequency: Frequency, velocity: MIDIVelocity, amplitudeDB: AmplitudeDB) async throws -> PlaybackHandle {
        await pendingAudioStop?.value
        try await soundFontEngine.loadPreset(preset, channel: channel)
        try validateFrequency(frequency)
        try soundFontEngine.ensureAudioSessionConfigured()
        try soundFontEngine.ensureEngineRunning()
        let midiNote = startNote(frequency: frequency, velocity: velocity, amplitudeDB: amplitudeDB)
        logger.debug("play: \(frequency.rawValue, format: .fixed(precision: 1))Hz, vel=\(velocity.rawValue), amp=\(amplitudeDB.rawValue, format: .fixed(precision: 1))dB → MIDI \(midiNote.rawValue)")
        return SoundFontPlaybackHandle(player: self, engine: soundFontEngine, channel: channel, midiNote: midiNote, fadeOutDuration: fadeOutDuration)
    }

    // MARK: - stopAll

    func stopAll() async throws {
        await scheduleStopAll().value
    }

    /// Synchronous-commit only enforces order on synchronous code paths. From an
    /// async cleanup continuation (e.g. a cancelled-trial `catch`), "commit"
    /// happens at whatever MainActor turn processes the continuation — after
    /// siblings may have already captured the chain tail — so callers from
    /// async-continuation contexts must NOT register additional chain entries
    /// that are already redundant with a session-level stop already in the
    /// chain. See `docs/project-context.md:84` and `NotePlayer+TimedPlay.swift`
    /// for the canonical pattern (cancellation catch does NOT call `handle.stop()`).
    @discardableResult
    func scheduleStopAll() -> Task<Void, Never> {
        logger.debug("scheduleStopAll: queuing stop on channel \(self.channel.rawValue)")
        let priorStop = pendingAudioStop
        let task = Task<Void, Never> {
            await priorStop?.value
            // Don't call clearSchedule: pitch never schedules events, and the deferred render-thread CC#123 it triggers would race a subsequent play()'s noteOn.
            await self.soundFontEngine.stopNotes(channel: self.channel, fadeOutDuration: self.fadeOutDuration)
        }
        pendingAudioStop = task
        return task
    }

    /// Chains a `SoundFontPlaybackHandle.stop()` through the serial audio chain
    /// so its `muteForFade()` cannot outlast a subsequent stopAll or silence
    /// the next `play()`'s noteOn — the handle's mute is global (it mutes
    /// every sampler on the engine), and `activeMuteCount` only restores
    /// volume when it drops to zero. Without this chain, an exit-then-re-enter
    /// sequence races the in-flight handle.stop against the new play.
    @discardableResult
    func scheduleNoteStop(midiNote: MIDINote) -> Task<Void, Never> {
        let channel = self.channel
        let fadeOutDuration = self.fadeOutDuration
        let engine = self.soundFontEngine
        let priorStop = pendingAudioStop
        let task = Task<Void, Never> {
            await priorStop?.value
            if fadeOutDuration > .zero {
                engine.muteForFade()
                try? await Task.sleep(for: fadeOutDuration)
            }
            engine.stopNote(midiNote, channel: channel)
            engine.sendPitchBend(.center, channel: channel)
            if fadeOutDuration > .zero {
                engine.restoreAfterFade()
            }
        }
        pendingAudioStop = task
        return task
    }

    // MARK: - Melodic Play Sub-operations

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
        soundFontEngine.startNote(midiNote, velocity: velocity, amplitudeDB: amplitudeDB, pitchBend: bendValue, channel: channel)
        return midiNote
    }

    // MARK: - Static Helpers

    nonisolated static func pitchBendValue(forCents cents: Cents) -> PitchBendValue {
        let center = Double(PitchBendValue.center.rawValue)
        let raw = Int(center + cents.rawValue * center / SoundFontEngine.pitchBendRangeCents)
        return PitchBendValue(clamping: raw)
    }

    /// Decomposes a frequency into its nearest MIDI note and cent remainder.
    /// Always uses 12-TET at concert pitch (A4=440Hz) — this is a MIDI
    /// implementation detail, not a musical tuning choice.
    nonisolated static func decompose(frequency: Frequency) -> (note: UInt8, cents: Cents) {
        let exactMidi = Double(MIDINote.a4.rawValue)
            + Double(Interval.octave.semitones) * log2(frequency / Frequency.concert440)
        let roundedMidi = Int(exactMidi.rounded())
        let centsRemainder = (exactMidi - Double(roundedMidi)) * Cents.perSemitone
        let clampedMidi = roundedMidi.clamped(to: MIDINote.validRange)
        return (note: UInt8(clampedMidi), cents: centsRemainder)
    }

}

