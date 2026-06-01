import Foundation

// MARK: - Beat / Subdivision

/// A beat — the outer rhythmic pulse — composed of equally-spaced subdivisions.
///
/// Subdivisions are spaced uniformly across the beat's duration; unequal rhythms
/// (dotted, swing, etc.) are expressed by nesting beats and inserting rests.
struct Beat: Sendable {
    let subdivisions: [Subdivision]

    init(subdivisions: [Subdivision]) {
        self.subdivisions = subdivisions
    }
}

enum Subdivision: Sendable {
    case rest
    case note(velocity: MIDIVelocity, offset: Duration)
    case nested(Beat)
}

// MARK: - BeatProvider

protocol BeatProvider {
    func nextBeat() -> Beat
}

// MARK: - RhythmVelocity

enum RhythmVelocity {
    static let accent = MIDIVelocity(127)
    static let normal = MIDIVelocity(100)
}

// MARK: - SequencerTiming

/// Snapshot of all timing state needed to interpret sample positions.
/// Reading this as a single value avoids tearing when properties are
/// mutated concurrently (e.g. during stop).
struct SequencerTiming: Sendable {
    let samplePosition: Int64
    let samplesPerBeat: Int64
    let sampleRate: SampleRate
}

// MARK: - Beat → ScheduledMIDIEvent

extension Beat {
    /// Compiles this beat into scheduled MIDI events. Pure function; safe to call
    /// off any actor.
    ///
    /// `noteOffDelaySamples` is a *request*: it is clamped per-recursion to
    /// `subdivisionDuration - 1` so consecutive subdivisions never overlap,
    /// regardless of the caller's chosen default or the beat's nesting depth.
    func events(
        beatOffset: Int64,
        beatDuration: Int64,
        sampleRate: SampleRate,
        channel: MIDIChannel,
        clickNote: MIDINote,
        noteOffDelaySamples: Int64
    ) -> [ScheduledMIDIEvent] {
        var events: [ScheduledMIDIEvent] = []
        guard !subdivisions.isEmpty, beatDuration > 0 else { return events }
        events.reserveCapacity(subdivisions.count * 2)

        let subdivisionDuration = beatDuration / Int64(subdivisions.count)
        let effectiveNoteOff = max(min(noteOffDelaySamples, subdivisionDuration - 1), 1)
        let channelRaw = channel.rawValue
        let midiNoteRaw = UInt8(clickNote.rawValue)

        for (index, subdivision) in subdivisions.enumerated() {
            let baseOffset = beatOffset + Int64(index) * subdivisionDuration

            switch subdivision {
            case .rest:
                continue

            case .note(let velocity, let offset):
                let noteOnOffset = baseOffset + sampleRate.samples(for: offset)
                events.append(ScheduledMIDIEvent(
                    sampleOffset: noteOnOffset,
                    midiStatus: SoundFontEngine.noteOnBase | channelRaw,
                    midiNote: midiNoteRaw,
                    velocity: velocity.rawValue
                ))
                events.append(ScheduledMIDIEvent(
                    sampleOffset: noteOnOffset + effectiveNoteOff,
                    midiStatus: SoundFontEngine.noteOffBase | channelRaw,
                    midiNote: midiNoteRaw,
                    velocity: 0
                ))

            case .nested(let child):
                events.append(contentsOf: child.events(
                    beatOffset: baseOffset,
                    beatDuration: subdivisionDuration,
                    sampleRate: sampleRate,
                    channel: channel,
                    clickNote: clickNote,
                    noteOffDelaySamples: noteOffDelaySamples
                ))
            }
        }

        return events
    }
}
