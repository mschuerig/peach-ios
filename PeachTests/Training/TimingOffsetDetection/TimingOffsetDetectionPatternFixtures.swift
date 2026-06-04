import Foundation
@testable import Peach

#if PEACH_RESEARCH
/// Transient ``TimingOffsetDetectionPattern`` fixtures for tests that need
/// rest-aware or single-pickable shapes the production catalog won't ship until
/// 82.7. These are constructed on demand — they are **not** registered into
/// ``TimingOffsetDetectionPatternCatalog/all``.
enum TimingOffsetDetectionPatternFixtures {
    /// `* - * *` — anchor, rest, audible-pickable, audible-pickable.
    /// audibleToGrid = [0, 2, 3]; pickable = {2, 3}; default audible 2.
    static var pattern1011: TimingOffsetDetectionPattern {
        TimingOffsetDetectionPattern(
            id: "pattern_test_1011",
            subdivisions: [
                .note(velocity: RhythmVelocity.accent, offset: .zero),
                .rest,
                .note(velocity: RhythmVelocity.normal, offset: .zero),
                .note(velocity: RhythmVelocity.normal, offset: .zero)
            ],
            defaultOffsetNotePosition: OffsetNotePosition(2)
        )
    }

    /// `* - * -` — single-pickable pattern; audibleCount = 2, pickable = {2}.
    static var pattern1010: TimingOffsetDetectionPattern {
        TimingOffsetDetectionPattern(
            id: "pattern_test_1010",
            subdivisions: [
                .note(velocity: RhythmVelocity.accent, offset: .zero),
                .rest,
                .note(velocity: RhythmVelocity.normal, offset: .zero),
                .rest
            ],
            defaultOffsetNotePosition: OffsetNotePosition(2)
        )
    }
}
#endif
