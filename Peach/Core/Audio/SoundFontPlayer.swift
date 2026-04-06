import AVFoundation
import Foundation
import os

final class SoundFontPlayer: NotePlayer, RhythmPlayer {

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.peach.app", category: "SoundFontPlayer")

    // MARK: - Audio Components

    private let soundFontEngine: SoundFontEngine

    // MARK: - Constants

    nonisolated static let validFrequencyRange = 20.0...20000.0

    /// Delay between note-on and note-off for percussion hits.
    /// Percussion samples have natural decay; this just ensures the MIDI note-off
    /// doesn't cut the sample short while still releasing the voice promptly.
    private nonisolated static let percussionNoteOffDuration: Duration = .milliseconds(50)

    /// Duration to mute `sampler.volume` before stopping a note, allowing the audio render
    /// thread to propagate silence and avoid click/pop artifacts. Set to `.zero` to skip the
    /// fade-out entirely (notes stop immediately). 25ms covers 2+ render cycles at 44.1kHz/512.
    let stopPropagationDelay: Duration

    // MARK: - Preset

    private let preset: SF2Preset

    // MARK: - Channel

    private let channel: SoundFontEngine.ChannelID

    // MARK: - Initialization

    init(engine: SoundFontEngine, preset: SF2Preset, channel: SoundFontEngine.ChannelID = SoundFontEngine.ChannelID(0), stopPropagationDelay: Duration = .milliseconds(25)) {
        self.soundFontEngine = engine
        self.preset = preset
        self.channel = channel
        self.stopPropagationDelay = stopPropagationDelay

        logger.info("SoundFontPlayer initialized on channel \(channel.rawValue) with preset \(preset.rawValue)")
    }

    // MARK: - NotePlayer Protocol

    func play(frequency: Frequency, velocity: MIDIVelocity, amplitudeDB: AmplitudeDB) async throws -> PlaybackHandle {
        try await soundFontEngine.loadPreset(preset, channel: channel)
        try validateFrequency(frequency)
        try soundFontEngine.ensureAudioSessionConfigured()
        try soundFontEngine.ensureEngineRunning()
        let midiNote = startNote(frequency: frequency, velocity: velocity, amplitudeDB: amplitudeDB)
        logger.debug("play: \(frequency.rawValue, format: .fixed(precision: 1))Hz, vel=\(velocity.rawValue), amp=\(amplitudeDB.rawValue, format: .fixed(precision: 1))dB → MIDI \(midiNote.rawValue)")
        return SoundFontPlaybackHandle(engine: soundFontEngine, channel: channel, midiNote: midiNote, stopPropagationDelay: stopPropagationDelay)
    }

    // MARK: - RhythmPlayer Protocol

    func play(_ pattern: RhythmPattern) async throws -> RhythmPlaybackHandle {
        try soundFontEngine.ensureAudioSessionConfigured()
        try soundFontEngine.ensureEngineRunning()
        try await soundFontEngine.loadPreset(preset, channel: channel)

        // Convert pattern events to scheduled MIDI events
        let noteOffDelaySamples = Int64(pattern.sampleRate.rawValue * Self.percussionNoteOffDuration.timeInterval)

        // Cap note-off delay to avoid overlap with the next note-on
        let minSpacing: Int64
        if pattern.events.count >= 2 {
            minSpacing = zip(pattern.events, pattern.events.dropFirst())
                .map { $1.sampleOffset - $0.sampleOffset }
                .min() ?? Int64.max
        } else {
            minSpacing = Int64.max
        }
        let cappedNoteOffDelay = min(noteOffDelaySamples, max(minSpacing - 1, 0))

        var scheduledEvents: [ScheduledMIDIEvent] = []
        scheduledEvents.reserveCapacity(pattern.events.count * 2)

        for event in pattern.events {
            let midiNoteRaw = UInt8(clamping: event.midiNote.rawValue)

            // Note-on
            scheduledEvents.append(ScheduledMIDIEvent(
                sampleOffset: event.sampleOffset,
                midiStatus: SoundFontEngine.noteOnBase | channel.rawValue,
                midiNote: midiNoteRaw,
                velocity: event.velocity.rawValue
            ))

            // Note-off
            scheduledEvents.append(ScheduledMIDIEvent(
                sampleOffset: event.sampleOffset + cappedNoteOffDelay,
                midiStatus: SoundFontEngine.noteOffBase | channel.rawValue,
                midiNote: midiNoteRaw,
                velocity: 0
            ))
        }

        scheduledEvents.sort { $0.sampleOffset < $1.sampleOffset }

        soundFontEngine.scheduleEvents(scheduledEvents)

        return SoundFontRhythmPlaybackHandle(engine: soundFontEngine, channel: channel)
    }

    // MARK: - stopAll (shared by both NotePlayer and RhythmPlayer)

    func stopAll() async throws {
        logger.debug("stopAll: clearing schedule and stopping notes on channel \(self.channel.rawValue)")
        soundFontEngine.clearSchedule()
        await soundFontEngine.stopNotes(channel: channel, stopPropagationDelay: stopPropagationDelay)
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

