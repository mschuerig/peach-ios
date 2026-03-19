import Foundation

/// A validated range of MIDI notes with a minimum span of 12 semitones (one octave).
///
/// NoteRange encapsulates a lower and upper MIDI note bound, validating
/// that the span is at least 12 semitones at construction time. Used throughout
/// the codebase to express note range constraints consistently.
struct NoteRange: Hashable, Sendable {
    static let minimumSpan = 12

    let lowerBound: MIDINote
    let upperBound: MIDINote

    init(lowerBound: MIDINote, upperBound: MIDINote) {
        precondition(
            upperBound.rawValue - lowerBound.rawValue >= Self.minimumSpan,
            "NoteRange requires at least \(Self.minimumSpan) semitones, got \(upperBound.rawValue - lowerBound.rawValue)"
        )
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }

    func contains(_ note: MIDINote) -> Bool {
        note >= lowerBound && note <= upperBound
    }

    func clamped(_ note: MIDINote) -> MIDINote {
        if note < lowerBound { return lowerBound }
        if note > upperBound { return upperBound }
        return note
    }

    var semitoneSpan: Int {
        upperBound.rawValue - lowerBound.rawValue
    }
}
