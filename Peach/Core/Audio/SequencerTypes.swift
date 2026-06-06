import Foundation

// MARK: - Beat / Subdivision

/// A beat — the outer rhythmic pulse — composed of equally-spaced subdivisions.
///
/// Subdivisions are spaced uniformly across the beat's duration; unequal rhythms
/// (dotted, swing, etc.) are expressed by nesting beats and inserting rests.
struct Beat: Sendable, Equatable {
    let subdivisions: [Subdivision]
}

enum Subdivision: Sendable, Equatable {
    case rest
    case note(velocity: MIDIVelocity, offset: Duration)
    case nested(Beat)
}

// MARK: - BeatProvider

/// Provides a beat per request to a `BeatSequencer`.
///
/// **Actor-isolation contract.** `BeatProvider` is intentionally NOT `Sendable`.
/// Under the project's `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` build
/// setting, every conformer in the codebase is MainActor-isolated; the
/// sequencer invokes `nextBeat()` synchronously from MainActor on the same
/// actor-turn as its polling Task, so there is no cross-isolation hop. Marking
/// the protocol `Sendable` would force one of:
///   - actor-isolating the conformers (incompatible with `@Observable` + SwiftUI),
///   - `@unchecked Sendable` (defeats the analysis), or
///   - dropping the conformers' mutable trial state into actors of their own
///     (a substantial refactor with no observable safety gain).
///
/// Adding a non-MainActor caller would re-open the question. The PF-011 audit
/// (Story 85.3) verified the current shape is safe under default-MainActor
/// isolation; the contract stays documented inline rather than enforced by
/// Sendable conformance.
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
    /// `subdivisionDuration - 1` so adjacent subdivisions within the same beat
    /// cannot overlap. Inter-beat overlap (the last subdivision's note-off
    /// spilling into the next beat's first subdivision) is the scheduler's
    /// concern, not this function's.
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
        // Degenerate-grid guard: if subdivisions are many and beatDuration is
        // small (or after several layers of recursion), integer truncation can
        // produce a 0 here. Returning empty keeps callers safe instead of
        // stacking every audible at `baseOffset`.
        guard subdivisionDuration > 0 else { return events }
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
                // Signed offsets (Story 80.1+) can pull the first subdivision's
                // note-on below the beat origin. The audio scheduler requires
                // non-negative sample offsets — surface the violation at the
                // boundary where it's actually compilable instead of letting it
                // reach the render thread.
                precondition(
                    noteOnOffset >= 0,
                    "Beat.events: signed note offset produced a negative sampleOffset (baseOffset=\(baseOffset), offset=\(offset))"
                )
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
