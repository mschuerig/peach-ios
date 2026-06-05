import Foundation

/// The 1-based position of the note that carries the timing offset in a TOD
/// pattern. Range is `1...6` to cover every catalog entry's `audibleCount`
/// through Epic 84: most entries have ≤ 4 audibles, the sextuplet
/// `pattern_sextuplet_01` reaches 6. Future entries with a higher audible count must
/// widen this range alongside their catalog registration.
///
/// Pattern-aware clamping of a stored `Int` is the responsibility of
/// ``TimingOffsetDetectionPattern/clampedOffsetNotePosition(_:)`` — the range
/// alone is not enough, because audible position 1 (the metric anchor) is in
/// `validRange` but is never pickable for any registered pattern.
struct OffsetNotePosition: Hashable, Sendable {
    static let validRange: ClosedRange<Int> = 1...6
    static let `default` = OffsetNotePosition(3)

    let rawValue: Int

    init(_ rawValue: Int) {
        precondition(
            Self.validRange.contains(rawValue),
            "OffsetNotePosition must be in \(Self.validRange), got \(rawValue)"
        )
        self.rawValue = rawValue
    }

    var zeroBasedIndex: Int { rawValue - 1 }
}
