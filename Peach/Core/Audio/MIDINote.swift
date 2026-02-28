import Foundation

/// A discrete position on the 128-note MIDI grid (0–127).
///
/// MIDINote is a pure index in the logical world — it carries no tuning or
/// frequency information. To convert to a sounding frequency, use
/// `TuningSystem.frequency(for:referencePitch:)`.
struct MIDINote: Hashable, Comparable, Codable, Sendable {
    static let validRange = 0...127

    let rawValue: Int

    init(_ rawValue: Int) {
        precondition(Self.validRange.contains(rawValue), "MIDI note must be 0-127, got \(rawValue)")
        self.rawValue = rawValue
    }

    // MARK: - Computed Properties

    var name: String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let pitchClass = rawValue % 12
        let octave = (rawValue / 12) - 1
        return "\(noteNames[pitchClass])\(octave)"
    }

    // MARK: - Factory Methods

    static func random(in range: ClosedRange<MIDINote>) -> MIDINote {
        MIDINote(Int.random(in: range.lowerBound.rawValue...range.upperBound.rawValue))
    }

    // MARK: - Comparable

    static func < (lhs: MIDINote, rhs: MIDINote) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension MIDINote: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) {
        self.init(value)
    }
}
