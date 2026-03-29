import Foundation

/// A validated range of tempos measured in BPM.
///
/// Used to group rhythm training statistics by tempo band (slow, medium, fast).
/// Follows the same pattern as `NoteRange`.
struct TempoRange: Hashable, Sendable, Comparable {
    let lowerBound: TempoBPM
    let upperBound: TempoBPM

    init(lowerBound: TempoBPM, upperBound: TempoBPM) {
        precondition(upperBound >= lowerBound, "TempoRange upper bound must be >= lower bound")
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }

    func contains(_ tempo: TempoBPM) -> Bool {
        tempo >= lowerBound && tempo <= upperBound
    }

    static func < (lhs: TempoRange, rhs: TempoRange) -> Bool {
        lhs.lowerBound < rhs.lowerBound
    }

    /// The BPM value at the center of this range, used for approximate conversions.
    var midpointTempo: TempoBPM {
        TempoBPM((lowerBound.value + upperBound.value + 1) / 2)
    }

    /// Localized display name for this tempo range.
    var displayName: String {
        switch self {
        case .verySlow: String(localized: "Very Slow")
        case .slow: String(localized: "Slow")
        case .moderate: String(localized: "Moderate")
        case .brisk: String(localized: "Brisk")
        case .fast: String(localized: "Fast")
        case .veryFast: String(localized: "Very Fast")
        default: "\(lowerBound.value)–\(upperBound.value)"
        }
    }

    // MARK: - Default Ranges

    static let verySlow = TempoRange(lowerBound: TempoBPM(40),  upperBound: TempoBPM(59))
    static let slow     = TempoRange(lowerBound: TempoBPM(60),  upperBound: TempoBPM(79))
    static let moderate = TempoRange(lowerBound: TempoBPM(80),  upperBound: TempoBPM(99))
    static let brisk    = TempoRange(lowerBound: TempoBPM(100), upperBound: TempoBPM(119))
    static let fast     = TempoRange(lowerBound: TempoBPM(120), upperBound: TempoBPM(159))
    static let veryFast = TempoRange(lowerBound: TempoBPM(160), upperBound: TempoBPM(200))

    static let defaultRanges: [TempoRange] = [.verySlow, .slow, .moderate, .brisk, .fast, .veryFast]

    /// Returns the range containing the given tempo, or nil if no range matches.
    static func range(for tempo: TempoBPM, in ranges: [TempoRange] = defaultRanges) -> TempoRange? {
        ranges.first { $0.contains(tempo) }
    }
}
