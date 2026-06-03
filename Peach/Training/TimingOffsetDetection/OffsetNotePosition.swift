import Foundation

/// The 1-based position of the note that carries the timing offset in a TOD
/// pattern. Today TOD plays one beat of four 16th notes per trial, so the
/// valid range is `1...4`; future catalog patterns (epic 82) may revisit the
/// range when `NamedPattern` introduces variable slot counts.
///
/// Two initializers serve two distinct callers. The strict `init(_:)` is for
/// code that has already validated the value (test fixtures, the
/// ``TimingOffsetDetectionSession/buildBeat(for:offsetNotePosition:)`` parameter,
/// the settings factory). The `init(clamping:)` factory replaces out-of-range
/// values with ``default`` and is used at every `@AppStorage` read site, so
/// corrupt storage cannot make the audio engine and the visual dot indicator
/// disagree on which note is the tested one.
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

    init(clamping rawValue: Int) {
        if Self.validRange.contains(rawValue) {
            self.init(rawValue)
        } else {
            self = .default
        }
    }

    var zeroBasedIndex: Int { rawValue - 1 }
}
