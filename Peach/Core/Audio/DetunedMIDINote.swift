import Foundation

/// A MIDI note with a microtonal cent offset — a logical pitch identity.
///
/// DetunedMIDINote lives in the logical world alongside MIDINote, Interval,
/// and Cents. It carries no frequency or tuning knowledge. To convert to a
/// sounding frequency, pass it through the explicit bridge:
/// `TuningSystem.frequency(for:referencePitch:)`.
struct DetunedMIDINote: Hashable, Sendable {
    let note: MIDINote
    let offset: Cents

    init(note: MIDINote, offset: Cents) {
        self.note = note
        self.offset = offset
    }

    init(_ note: MIDINote) {
        self.init(note: note, offset: Cents(0))
    }
}
