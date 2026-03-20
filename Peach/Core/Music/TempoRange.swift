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

    // MARK: - Default Ranges

    static let slow   = TempoRange(lowerBound: TempoBPM(40),  upperBound: TempoBPM(79))
    static let medium = TempoRange(lowerBound: TempoBPM(80),  upperBound: TempoBPM(119))
    static let fast   = TempoRange(lowerBound: TempoBPM(120), upperBound: TempoBPM(200))

    static let defaultRanges: [TempoRange] = [.slow, .medium, .fast]

    /// Returns the range containing the given tempo, or nil if no range matches.
    static func range(for tempo: TempoBPM, in ranges: [TempoRange] = defaultRanges) -> TempoRange? {
        ranges.first { $0.contains(tempo) }
    }
}
