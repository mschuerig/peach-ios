import Foundation

struct MIDINote: Hashable, Comparable, Codable, Sendable {
    nonisolated(unsafe) static let validRange = 0...127

    let rawValue: Int

    nonisolated init(_ rawValue: Int) {
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

    func frequency(referencePitch: Double = 440.0) throws -> Frequency {
        let hz = try FrequencyCalculation.frequency(midiNote: rawValue, referencePitch: referencePitch)
        return Frequency(hz)
    }

    // MARK: - Factory Methods

    static func random(in range: ClosedRange<MIDINote>) -> MIDINote {
        MIDINote(Int.random(in: range.lowerBound.rawValue...range.upperBound.rawValue))
    }

    // MARK: - Comparable

    nonisolated static func < (lhs: MIDINote, rhs: MIDINote) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension MIDINote: ExpressibleByIntegerLiteral {
    nonisolated init(integerLiteral value: Int) {
        self.init(value)
    }
}
