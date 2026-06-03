import Testing
import Foundation
@testable import Peach

#if PEACH_RESEARCH
@Suite("TimingOffsetDetectionPattern Tests")
struct TimingOffsetDetectionPatternTests {

    // MARK: - Init / derived metadata

    @Test("init derives audibleToGrid by collecting the grid indices of `.note` subdivisions in order")
    func initDerivesAudibleToGridFromSubdivisions() {
        // Fixture: `* - * *` — grid positions 1, 3, 4 audible; grid position 2 a rest.
        // Audible-1-based → grid-0-based: 1 → 0, 2 → 2, 3 → 3.
        let pattern = TimingOffsetDetectionPattern(
            id: "fixture_1011",
            subdivisions: [
                .note(velocity: RhythmVelocity.accent, offset: .zero),
                .rest,
                .note(velocity: RhythmVelocity.normal, offset: .zero),
                .note(velocity: RhythmVelocity.normal, offset: .zero)
            ],
            defaultOffsetNotePosition: OffsetNotePosition(2)
        )

        #expect(pattern.audibleToGrid == [0, 2, 3])
        #expect(pattern.audibleCount == 3)
    }

    @Test("audibleCount for pattern_1111 is 4 (every subdivision is a note)")
    func audibleCountPattern1111() {
        let pattern = TimingOffsetDetectionPattern.pattern1111
        #expect(pattern.audibleCount == 4)
        #expect(pattern.audibleToGrid == [0, 1, 2, 3])
    }

    // MARK: - pickable invariant

    @Test("pickable equals Set(2...audibleCount) — never contains position 1")
    func pickableEqualsTwoThroughAudibleCount() {
        let pattern = TimingOffsetDetectionPattern.pattern1111
        #expect(pattern.pickable == Set(2...pattern.audibleCount))
        #expect(pattern.pickable.contains(1) == false)
    }

    @Test("pickable for a 3-audible-note fixture is {2, 3}")
    func pickableForThreeAudibleNoteFixture() {
        let pattern = TimingOffsetDetectionPattern(
            id: "fixture_1011",
            subdivisions: [
                .note(velocity: RhythmVelocity.accent, offset: .zero),
                .rest,
                .note(velocity: RhythmVelocity.normal, offset: .zero),
                .note(velocity: RhythmVelocity.normal, offset: .zero)
            ],
            defaultOffsetNotePosition: OffsetNotePosition(2)
        )
        #expect(pattern.pickable == Set([2, 3]))
        #expect(pattern.pickable.contains(1) == false)
    }

    // MARK: - clampedOffsetNotePosition

    @Test(
        "clampedOffsetNotePosition returns the requested position when it is pickable",
        arguments: [2, 3, 4]
    )
    func clampedPassesPickableValues(raw: Int) {
        let pattern = TimingOffsetDetectionPattern.pattern1111
        #expect(pattern.clampedOffsetNotePosition(raw) == OffsetNotePosition(raw))
    }

    @Test("clampedOffsetNotePosition replaces the metric-anchor position 1 with the pattern default")
    func clampedReplacesMetricAnchorWithDefault() {
        let pattern = TimingOffsetDetectionPattern.pattern1111
        #expect(pattern.clampedOffsetNotePosition(1) == pattern.defaultOffsetNotePosition)
        #expect(pattern.clampedOffsetNotePosition(1) == OffsetNotePosition(3))
    }

    @Test(
        "clampedOffsetNotePosition replaces out-of-range values with the pattern default",
        arguments: [0, -1, 5, 99, Int.min, Int.max]
    )
    func clampedReplacesOutOfRangeWithDefault(raw: Int) {
        let pattern = TimingOffsetDetectionPattern.pattern1111
        #expect(pattern.clampedOffsetNotePosition(raw) == pattern.defaultOffsetNotePosition)
    }

    // MARK: - beat construction (pattern_1111)

    @Test(
        "beat for pattern_1111 places the offset on the chosen audible position",
        arguments: [2, 3, 4]
    )
    func beatForPattern1111PlacesOffsetOnChosenAudiblePosition(positionValue: Int) {
        let pattern = TimingOffsetDetectionPattern.pattern1111
        let position = OffsetNotePosition(positionValue)
        let offsetAmount: Duration = .milliseconds(20)

        let beat = pattern.beat(offsetNotePosition: position, offsetAmount: offsetAmount)

        #expect(beat.subdivisions.count == 4)
        for index in 0..<4 {
            guard case let .note(velocity, offset) = beat.subdivisions[index] else {
                Issue.record("Expected subdivision \(index) to be a note in pattern_1111")
                return
            }
            let expectedVelocity: MIDIVelocity = (index == 0) ? RhythmVelocity.accent : RhythmVelocity.normal
            let expectedOffset: Duration = (index == position.zeroBasedIndex) ? offsetAmount : .zero
            #expect(velocity == expectedVelocity, "velocity mismatch at index \(index)")
            #expect(offset == expectedOffset, "offset mismatch at index \(index)")
        }
    }

    // MARK: - beat construction (audible→grid via rests)

    @Test("beat for a rest-containing fixture applies the offset to the correct grid index via audibleToGrid")
    func beatForFixtureWithRestUsesAudibleToGridTranslation() {
        // Fixture: `* - * *` — audible positions 1, 2, 3 map to grid positions 1, 3, 4.
        // Audible position 2 must offset grid index 2 (the third subdivision, which is a `.note`),
        // not grid index 1 (the rest) — a raw-arithmetic translation would do the wrong thing.
        let pattern = TimingOffsetDetectionPattern(
            id: "fixture_1011",
            subdivisions: [
                .note(velocity: RhythmVelocity.accent, offset: .zero),
                .rest,
                .note(velocity: RhythmVelocity.normal, offset: .zero),
                .note(velocity: RhythmVelocity.normal, offset: .zero)
            ],
            defaultOffsetNotePosition: OffsetNotePosition(2)
        )
        let offsetAmount: Duration = .milliseconds(30)

        let beat = pattern.beat(offsetNotePosition: OffsetNotePosition(2), offsetAmount: offsetAmount)

        #expect(beat.subdivisions.count == 4)

        // Grid 0: the accent, no offset.
        guard case let .note(v0, o0) = beat.subdivisions[0] else {
            Issue.record("Expected subdivision 0 to be a note"); return
        }
        #expect(v0 == RhythmVelocity.accent)
        #expect(o0 == .zero)

        // Grid 1: rest — preserved as `.rest`.
        guard case .rest = beat.subdivisions[1] else {
            Issue.record("Expected subdivision 1 to be a rest"); return
        }

        // Grid 2: audible position 2 — receives the offset.
        guard case let .note(v2, o2) = beat.subdivisions[2] else {
            Issue.record("Expected subdivision 2 to be a note"); return
        }
        #expect(v2 == RhythmVelocity.normal)
        #expect(o2 == offsetAmount)

        // Grid 3: audible position 3 — no offset.
        guard case let .note(v3, o3) = beat.subdivisions[3] else {
            Issue.record("Expected subdivision 3 to be a note"); return
        }
        #expect(v3 == RhythmVelocity.normal)
        #expect(o3 == .zero)
    }

    @Test("beat for a rest-containing fixture preserves rests in their grid positions")
    func beatPreservesRests() {
        // Fixture: `* * - *` — rest at grid position 3 (index 2).
        let pattern = TimingOffsetDetectionPattern(
            id: "fixture_1101",
            subdivisions: [
                .note(velocity: RhythmVelocity.accent, offset: .zero),
                .note(velocity: RhythmVelocity.normal, offset: .zero),
                .rest,
                .note(velocity: RhythmVelocity.normal, offset: .zero)
            ],
            defaultOffsetNotePosition: OffsetNotePosition(2)
        )

        let beat = pattern.beat(offsetNotePosition: OffsetNotePosition(2), offsetAmount: .milliseconds(10))

        guard case .rest = beat.subdivisions[2] else {
            Issue.record("Expected subdivision 2 to remain `.rest` after beat construction"); return
        }
    }

    // MARK: - Equatable / Hashable

    @Test("two patterns with the same id, subdivisions, and default compare equal")
    func equalityHoldsForIdenticalPatterns() {
        let a = TimingOffsetDetectionPattern(
            id: "fixture",
            subdivisions: [
                .note(velocity: RhythmVelocity.accent, offset: .zero),
                .note(velocity: RhythmVelocity.normal, offset: .zero)
            ],
            defaultOffsetNotePosition: OffsetNotePosition(2)
        )
        let b = TimingOffsetDetectionPattern(
            id: "fixture",
            subdivisions: [
                .note(velocity: RhythmVelocity.accent, offset: .zero),
                .note(velocity: RhythmVelocity.normal, offset: .zero)
            ],
            defaultOffsetNotePosition: OffsetNotePosition(2)
        )
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    // Identity is id-only by design: the catalog enforces id uniqueness, and
    // `Subdivision` isn't `Hashable`, so widening to structural equality would
    // force conformance through the engine types. The downstream consequence is
    // that two fixtures sharing an id but differing in shape compare equal —
    // pinned here so a future refactor of `==` doesn't quietly break it.
    @Test("two patterns with the same id but differing subdivisions still compare equal (id-only identity)")
    func equalityIsIdentityBased() {
        let a = TimingOffsetDetectionPattern(
            id: "fixture",
            subdivisions: [
                .note(velocity: RhythmVelocity.accent, offset: .zero),
                .note(velocity: RhythmVelocity.normal, offset: .zero),
                .note(velocity: RhythmVelocity.normal, offset: .zero)
            ],
            defaultOffsetNotePosition: OffsetNotePosition(2)
        )
        let b = TimingOffsetDetectionPattern(
            id: "fixture",
            subdivisions: [
                .note(velocity: RhythmVelocity.accent, offset: .zero),
                .note(velocity: RhythmVelocity.normal, offset: .zero)
            ],
            defaultOffsetNotePosition: OffsetNotePosition(2)
        )
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("pattern_1111 carries id `pattern_1111` and defaultOffsetNotePosition 3")
    func pattern1111Identity() {
        let pattern = TimingOffsetDetectionPattern.pattern1111
        #expect(pattern.id == "pattern_1111")
        #expect(pattern.defaultOffsetNotePosition == OffsetNotePosition(3))
        #expect(pattern.subdivisions.count == 4)
    }
}
#endif
