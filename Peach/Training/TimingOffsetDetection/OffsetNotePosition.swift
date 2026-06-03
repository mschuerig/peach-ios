import Foundation

/// The 1-based position of the note that carries the timing offset in a TOD
/// pattern. The initial catalog has `audibleCount ≤ 4` across the board, so the
/// type's valid range is `1...4`; future K > 4 patterns will widen it.
///
/// Pattern-aware clamping of a stored `Int` is the responsibility of
/// ``TimingOffsetDetectionPattern/clampedOffsetNotePosition(_:)`` — the range
/// alone is not enough, because audible position 1 (the metric anchor) is in
/// `validRange` but is never pickable for any registered pattern.
struct OffsetNotePosition: Hashable, Sendable {
    static let validRange: ClosedRange<Int> = 1...4
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
