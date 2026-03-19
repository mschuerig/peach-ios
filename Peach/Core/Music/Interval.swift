import Foundation

/// Semitone distance between two notes, from prime (0) through octave (12).
///
/// Wrapped by `DirectedInterval` to add direction. Raw value is the semitone count.
nonisolated enum Interval: Int, Hashable, Comparable, Sendable, CaseIterable, Codable {
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

    var abbreviation: String {
        switch self {
        case .prime: "P1"
        case .minorSecond: "m2"
        case .majorSecond: "M2"
        case .minorThird: "m3"
        case .majorThird: "M3"
        case .perfectFourth: "P4"
        case .tritone: "d5"
        case .perfectFifth: "P5"
        case .minorSixth: "m6"
        case .majorSixth: "M6"
        case .minorSeventh: "m7"
        case .majorSeventh: "M7"
        case .octave: "P8"
        }
    }

    var name: String {
        switch self {
        case .prime: String(localized: "Prime")
        case .minorSecond: String(localized: "Minor Second")
        case .majorSecond: String(localized: "Major Second")
        case .minorThird: String(localized: "Minor Third")
        case .majorThird: String(localized: "Major Third")
        case .perfectFourth: String(localized: "Perfect Fourth")
        case .tritone: String(localized: "Tritone")
        case .perfectFifth: String(localized: "Perfect Fifth")
        case .minorSixth: String(localized: "Minor Sixth")
        case .majorSixth: String(localized: "Major Sixth")
        case .minorSeventh: String(localized: "Minor Seventh")
        case .majorSeventh: String(localized: "Major Seventh")
        case .octave: String(localized: "Octave")
        }
    }

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

