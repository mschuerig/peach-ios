import Foundation

/// Semitone distance between two notes, from prime (0) through octave (12).
///
/// Used by `MIDINote.transposed(by:)` to transpose a note and by `TuningSystem`
/// to look up the cent offset for that interval. Raw value is the semitone count.
enum Interval: Int, Hashable, Comparable, Sendable, CaseIterable, Codable {
    case prime = 0
    case minorSecond = 1
    case majorSecond = 2
    case minorThird = 3
    case majorThird = 4
    case perfectFourth = 5
    case tritone = 6
    case perfectFifth = 7
    case minorSixth = 8
    case majorSixth = 9
    case minorSeventh = 10
    case majorSeventh = 11
    case octave = 12

    var semitones: Int { rawValue }

    static func < (lhs: Interval, rhs: Interval) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static func between(_ reference: MIDINote, _ target: MIDINote) throws -> Interval {
        let distance = abs(reference.rawValue - target.rawValue)
        guard let interval = Interval(rawValue: distance) else {
            throw AudioError.invalidInterval("Semitone distance \(distance) exceeds octave range (0-12)")
        }
        return interval
    }
}

// MARK: - MIDINote Transposition

extension MIDINote {
    func transposed(by interval: Interval) -> MIDINote {
        let newValue = rawValue + interval.semitones
        precondition(Self.validRange.contains(newValue), "Transposed note \(newValue) out of MIDI range 0-127")
        return MIDINote(newValue)
    }
}
