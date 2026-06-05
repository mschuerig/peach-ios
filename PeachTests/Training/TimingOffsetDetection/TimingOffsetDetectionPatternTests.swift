import Testing
import Foundation
@testable import Peach

@Suite("TimingOffsetDetectionPattern Tests")
struct TimingOffsetDetectionPatternTests {

    // MARK: - Init / derived metadata

    @Test("init derives audibleToGrid as path-from-root paths for `.note` subdivisions in order")
    func initDerivesAudibleToGridFromSubdivisions() {
        // Fixture: `* - * *` — grid positions 1, 3, 4 audible; grid position 2 a rest.
        // Audible-1-based → GridPath: 1 → [0], 2 → [2], 3 → [3].
        let pattern = TimingOffsetDetectionPattern(
            id: "pattern_gapped16ths_99",
            category: .gapped16ths,
            subdivisions: [
                .note(velocity: RhythmVelocity.accent, offset: .zero),
                .rest,
                .note(velocity: RhythmVelocity.normal, offset: .zero),
                .note(velocity: RhythmVelocity.normal, offset: .zero)
            ],
            defaultOffsetNotePosition: OffsetNotePosition(2)
        )

        #expect(pattern.audibleToGrid == [[0], [2], [3]])
        #expect(pattern.audibleCount == 3)
    }

    @Test("audibleCount for pattern_straight16ths_01 is 4 (every subdivision is a note)")
    func audibleCountPattern01() {
        let pattern = TimingOffsetDetectionPattern.pattern_straight16ths_01
        #expect(pattern.audibleCount == 4)
        #expect(pattern.audibleToGrid == [[0], [1], [2], [3]])
    }

    @Test("audibleToGrid for a nested-figure fixture extends paths into the nested child")
    func audibleToGridDescendsIntoNestedChild() {
        // Fixture: `* *-*-*` — top-level K=2, child at index 1 is a triplet
        // (3 notes). Audibles: top-level [0], nested [1, 0], [1, 1], [1, 2].
        let pattern = TimingOffsetDetectionPattern(
            id: "pattern_nested_99",
            category: .nested,
            subdivisions: [
                .note(velocity: RhythmVelocity.accent, offset: .zero),
                .nested(Beat(subdivisions: [
                    .note(velocity: RhythmVelocity.normal, offset: .zero),
                    .note(velocity: RhythmVelocity.normal, offset: .zero),
                    .note(velocity: RhythmVelocity.normal, offset: .zero)
                ]))
            ],
            defaultOffsetNotePosition: OffsetNotePosition(2)
        )

        #expect(pattern.audibleToGrid == [[0], [1, 0], [1, 1], [1, 2]])
        #expect(pattern.audibleCount == 4)
    }

    @Test("beat for a nested-figure fixture rebuilds the nested Beat with offset on the addressed leaf")
    func beatForNestedFixtureAppliesOffsetInsideChild() {
        // Same fixture as above; offset position 3 → audibleToGrid[2] = [1, 1] —
        // the middle note of the nested triplet.
        let pattern = TimingOffsetDetectionPattern(
            id: "pattern_nested_99",
            category: .nested,
            subdivisions: [
                .note(velocity: RhythmVelocity.accent, offset: .zero),
                .nested(Beat(subdivisions: [
                    .note(velocity: RhythmVelocity.normal, offset: .zero),
                    .note(velocity: RhythmVelocity.normal, offset: .zero),
                    .note(velocity: RhythmVelocity.normal, offset: .zero)
                ]))
            ],
            defaultOffsetNotePosition: OffsetNotePosition(2)
        )
        let offsetAmount: Duration = .milliseconds(25)

        let beat = pattern.beat(offsetNotePosition: OffsetNotePosition(3), offsetAmount: offsetAmount)

        // Top-level: accent at index 0 (no offset), nested at index 1 (rebuilt).
        guard case let .note(topVelocity, topOffset) = beat.subdivisions[0] else {
            Issue.record("Expected top-level subdivision 0 to remain a note"); return
        }
        #expect(topVelocity == RhythmVelocity.accent)
        #expect(topOffset == .zero)

        guard case let .nested(rebuiltChild) = beat.subdivisions[1] else {
            Issue.record("Expected top-level subdivision 1 to remain nested"); return
        }
        for (childIndex, sub) in rebuiltChild.subdivisions.enumerated() {
            guard case let .note(velocity, offset) = sub else {
                Issue.record("Expected nested subdivision \(childIndex) to be a note"); return
            }
            #expect(velocity == RhythmVelocity.normal)
            let expectedOffset: Duration = (childIndex == 1) ? offsetAmount : .zero
            #expect(offset == expectedOffset, "offset mismatch at nested index \(childIndex)")
        }
    }

    // MARK: - pickable invariant

    @Test("pickable equals Set(2...audibleCount) — never contains position 1")
    func pickableEqualsTwoThroughAudibleCount() {
        let pattern = TimingOffsetDetectionPattern.pattern_straight16ths_01
        #expect(pattern.pickable == Set(2...pattern.audibleCount))
        #expect(pattern.pickable.contains(1) == false)
    }

    @Test("pickable for a 3-audible-note fixture is {2, 3}")
    func pickableForThreeAudibleNoteFixture() {
        let pattern = TimingOffsetDetectionPattern(
            id: "pattern_gapped16ths_99",
            category: .gapped16ths,
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
        let pattern = TimingOffsetDetectionPattern.pattern_straight16ths_01
        #expect(pattern.clampedOffsetNotePosition(raw) == OffsetNotePosition(raw))
    }

    @Test("clampedOffsetNotePosition replaces the metric-anchor position 1 with the pattern default")
    func clampedReplacesMetricAnchorWithDefault() {
        let pattern = TimingOffsetDetectionPattern.pattern_straight16ths_01
        #expect(pattern.clampedOffsetNotePosition(1) == pattern.defaultOffsetNotePosition)
        #expect(pattern.clampedOffsetNotePosition(1) == OffsetNotePosition(3))
    }

    @Test(
        "clampedOffsetNotePosition replaces out-of-range values with the pattern default",
        arguments: [0, -1, 5, 99, Int.min, Int.max]
    )
    func clampedReplacesOutOfRangeWithDefault(raw: Int) {
        let pattern = TimingOffsetDetectionPattern.pattern_straight16ths_01
        #expect(pattern.clampedOffsetNotePosition(raw) == pattern.defaultOffsetNotePosition)
    }

    // MARK: - beat construction (pattern_straight16ths_01)

    @Test(
        "beat for pattern_straight16ths_01 places the offset on the chosen audible position",
        arguments: [2, 3, 4]
    )
    func beatForPattern01PlacesOffsetOnChosenAudiblePosition(positionValue: Int) {
        let pattern = TimingOffsetDetectionPattern.pattern_straight16ths_01
        let position = OffsetNotePosition(positionValue)
        let offsetAmount: Duration = .milliseconds(20)

        let beat = pattern.beat(offsetNotePosition: position, offsetAmount: offsetAmount)

        #expect(beat.subdivisions.count == 4)
        for index in 0..<4 {
            guard case let .note(velocity, offset) = beat.subdivisions[index] else {
                Issue.record("Expected subdivision \(index) to be a note in pattern_straight16ths_01")
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
            id: "pattern_gapped16ths_99",
            category: .gapped16ths,
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
            id: "pattern_gapped16ths_98",
            category: .gapped16ths,
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
            id: "pattern_triplets_99",
            category: .triplets,
            subdivisions: [
                .note(velocity: RhythmVelocity.accent, offset: .zero),
                .note(velocity: RhythmVelocity.normal, offset: .zero)
            ],
            defaultOffsetNotePosition: OffsetNotePosition(2)
        )
        let b = TimingOffsetDetectionPattern(
            id: "pattern_triplets_99",
            category: .triplets,
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
            id: "pattern_triplets_99",
            category: .triplets,
            subdivisions: [
                .note(velocity: RhythmVelocity.accent, offset: .zero),
                .note(velocity: RhythmVelocity.normal, offset: .zero),
                .note(velocity: RhythmVelocity.normal, offset: .zero)
            ],
            defaultOffsetNotePosition: OffsetNotePosition(2)
        )
        let b = TimingOffsetDetectionPattern(
            id: "pattern_triplets_99",
            category: .triplets,
            subdivisions: [
                .note(velocity: RhythmVelocity.accent, offset: .zero),
                .note(velocity: RhythmVelocity.normal, offset: .zero)
            ],
            defaultOffsetNotePosition: OffsetNotePosition(2)
        )
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("pattern_straight16ths_01 carries id `pattern_straight16ths_01` and defaultOffsetNotePosition 3")
    func pattern01Identity() {
        let pattern = TimingOffsetDetectionPattern.pattern_straight16ths_01
        #expect(pattern.id == "pattern_straight16ths_01")
        #expect(pattern.defaultOffsetNotePosition == OffsetNotePosition(3))
        #expect(pattern.subdivisions.count == 4)
    }

    // MARK: - Rest-bearing catalog entries — shape + beat-builder coverage

    /// Shape expectations for one rest-bearing catalog entry (every entry except
    /// `pattern_straight16ths_01`, which is the all-audible reference covered above). Lookup
    /// happens in the test body via the id, so the arguments stay pure-value
    /// (no MainActor-isolated pattern accessors leak into the `arguments:`
    /// capture). `audibleCount` is asserted as a literal rather than
    /// `audibleToGrid.count` to avoid a tautological assertion — the production
    /// property is defined as `audibleToGrid.count` and so trivially agrees
    /// with itself.
    @Test(
        "each rest-bearing catalog entry exposes the expected shape (audibleToGrid, audibleCount, pickable, default)",
        arguments: [
            ("pattern_gapped16ths_01", [[0], [2], [3]], 3, Set([2, 3]), 2),
            ("pattern_gapped16ths_02", [[0], [1], [3]], 3, Set([2, 3]), 2),
            ("pattern_gapped16ths_03", [[0], [2]], 2, Set([2]), 2),
            ("pattern_gapped16ths_04", [[0], [3]], 2, Set([2]), 2)
        ] as [(String, [GridPath], Int, Set<Int>, Int)]
    )
    func restBearingCatalogEntryShape(
        expectation: (id: String, audibleToGrid: [GridPath], audibleCount: Int, pickable: Set<Int>, defaultPosition: Int)
    ) throws {
        let pattern = try TimingOffsetDetectionPatternCatalog.pattern(withId: expectation.id)
        #expect(pattern.id == expectation.id)
        #expect(pattern.audibleToGrid == expectation.audibleToGrid)
        #expect(pattern.audibleCount == expectation.audibleCount)
        #expect(pattern.pickable == expectation.pickable)
        #expect(pattern.defaultOffsetNotePosition == OffsetNotePosition(expectation.defaultPosition))
        #expect(pattern.subdivisions.count == 4)
    }

    /// Beat-builder coverage at every pickable position for every rest-bearing
    /// catalog entry. Covers the default-position path for all four entries
    /// plus the non-default pickable positions on `pattern_gapped16ths_01` and `pattern_gapped16ths_02`
    /// (the multi-pickable rest-bearing patterns) — pins the audible→grid
    /// translation that skips rests at the most-likely-regression positions.
    @Test(
        "each rest-bearing catalog entry's beat builder places the offset at the audible→grid-translated index for every pickable position",
        arguments: [
            ("pattern_gapped16ths_01", 2),
            ("pattern_gapped16ths_01", 3),
            ("pattern_gapped16ths_02", 2),
            ("pattern_gapped16ths_02", 3),
            ("pattern_gapped16ths_03", 2),
            ("pattern_gapped16ths_04", 2)
        ] as [(String, Int)]
    )
    func restBearingCatalogEntryBeatBuilderPlacesOffsetAtResolvedGridIndex(
        expectation: (patternID: String, position: Int)
    ) throws {
        let pattern = try TimingOffsetDetectionPatternCatalog.pattern(withId: expectation.patternID)
        let position = OffsetNotePosition(expectation.position)
        let offsetAmount: Duration = .milliseconds(20)
        // Flat catalog patterns have single-element GridPaths — pick the
        // top-level grid index to compare against the rebuilt subdivisions.
        let expectedOffsetGridIndex = pattern.audibleToGrid[position.zeroBasedIndex][0]

        let beat = pattern.beat(offsetNotePosition: position, offsetAmount: offsetAmount)

        #expect(beat.subdivisions.count == pattern.subdivisions.count)
        for index in beat.subdivisions.indices {
            switch (pattern.subdivisions[index], beat.subdivisions[index]) {
            case (.rest, .rest):
                continue
            case (.note, .note(let velocity, let offset)):
                let expectedVelocity: MIDIVelocity = (index == 0) ? RhythmVelocity.accent : RhythmVelocity.normal
                let expectedOffset: Duration = (index == expectedOffsetGridIndex) ? offsetAmount : .zero
                #expect(velocity == expectedVelocity, "velocity mismatch in \(pattern.id) at grid \(index)")
                #expect(offset == expectedOffset, "offset mismatch in \(pattern.id) at grid \(index)")
            default:
                Issue.record("Subdivision kind changed for \(pattern.id) at grid \(index)")
            }
        }
    }

    // MARK: - Tuplet catalog entries — shape, audibleToGrid, defaults (Epic 84.4)

    /// `(audibleToGrid, audibleCount, pickable, defaultPosition, subdivisionCount)`
    /// for the ten new tuplet catalog entries. Locked by
    /// `tod-tuplet-renderer-design.md` § *Catalog*. Single source of truth for
    /// the structural metadata exposed at the wrapper boundary; the worked
    /// expectations in the design doc derive from these values.
    @Test(
        "each registered tuplet catalog entry exposes the locked audibleToGrid, audibleCount, pickable, and default",
        arguments: [
            ("pattern_triplets_01", [[0], [1], [2]], 3, Set([2, 3]), 2, 3),
            ("pattern_triplets_02", [[0], [1]], 2, Set([2]), 2, 3),
            ("pattern_triplets_03", [[0], [2]], 2, Set([2]), 2, 3),
            ("pattern_triplets_04", [[0], [2], [5]], 3, Set([2, 3]), 2, 6),
            ("pattern_sextuplet_01", [[0], [1], [2], [3], [4], [5]], 6, Set([2, 3, 4, 5, 6]), 4, 6)
        ] as [(String, [GridPath], Int, Set<Int>, Int, Int)]
    )
    func tupletCatalogEntryShape(
        expectation: (id: String, audibleToGrid: [GridPath], audibleCount: Int, pickable: Set<Int>, defaultPosition: Int, subdivisionCount: Int)
    ) throws {
        let pattern = try TimingOffsetDetectionPatternCatalog.pattern(withId: expectation.id)
        #expect(pattern.id == expectation.id)
        #expect(pattern.audibleToGrid == expectation.audibleToGrid)
        #expect(pattern.audibleCount == expectation.audibleCount)
        #expect(pattern.pickable == expectation.pickable)
        #expect(pattern.defaultOffsetNotePosition == OffsetNotePosition(expectation.defaultPosition))
        #expect(pattern.subdivisions.count == expectation.subdivisionCount)
    }

    #if PEACH_RESEARCH
    /// Nested-bucket shape checks — registered only in `PEACH_RESEARCH` builds
    /// where `pattern_nested_01`..`pattern_nested_05` are part of
    /// ``TimingOffsetDetectionPatternCatalog/all``.
    @Test(
        "each Nested-bucket entry exposes the locked shape (PEACH_RESEARCH-gated)",
        arguments: [
            ("pattern_nested_01", [[0], [1, 0], [1, 1], [1, 2]], 4, Set([2, 3, 4]), 3, 2),
            ("pattern_nested_02", [[0, 0], [0, 1], [0, 2], [1]], 4, Set([2, 3, 4]), 3, 2),
            ("pattern_nested_03", [[0], [1], [2, 0], [2, 1]], 4, Set([2, 3, 4]), 4, 3),
            ("pattern_nested_04", [[0], [1, 0], [1, 1], [2]], 4, Set([2, 3, 4]), 3, 3),
            ("pattern_nested_05", [[0, 0], [0, 1], [1], [2]], 4, Set([2, 3, 4]), 2, 3)
        ] as [(String, [GridPath], Int, Set<Int>, Int, Int)]
    )
    func researchOnlyNestedCatalogEntryShape(
        expectation: (id: String, audibleToGrid: [GridPath], audibleCount: Int, pickable: Set<Int>, defaultPosition: Int, subdivisionCount: Int)
    ) throws {
        let pattern = try TimingOffsetDetectionPatternCatalog.pattern(withId: expectation.id)
        #expect(pattern.id == expectation.id)
        #expect(pattern.audibleToGrid == expectation.audibleToGrid)
        #expect(pattern.audibleCount == expectation.audibleCount)
        #expect(pattern.pickable == expectation.pickable)
        #expect(pattern.defaultOffsetNotePosition == OffsetNotePosition(expectation.defaultPosition))
        #expect(pattern.subdivisions.count == expectation.subdivisionCount)
    }
    #endif

    @Test("dottedAudiblePositions is locked to {2} for pattern_triplets_04 and empty for every other catalog entry")
    func dottedAudiblePositionsLockedToPattern09() {
        for pattern in TimingOffsetDetectionPatternCatalog.all {
            let expected: Set<Int> = (pattern.id == "pattern_triplets_04") ? [2] : []
            #expect(
                pattern.dottedAudiblePositions == expected,
                "Pattern \(pattern.id) dottedAudiblePositions mismatch: got \(pattern.dottedAudiblePositions), expected \(expected)"
            )
        }
    }

    @Test("beat for pattern_triplets_04 (sextuplet grid) places the offset on the top-level audible cell, not a rest")
    func beatForPattern09PlacesOffsetOnAudibleSextupletCell() {
        // pattern_triplets_04 (`* *. .`): `audibleToGrid = [[0], [2], [5]]`. Audible
        // position 2 → grid index 2 (the dotted-long note); rests at grid
        // 1, 3, 4 must stay rests.
        let pattern = TimingOffsetDetectionPattern.pattern_triplets_04
        let offsetAmount: Duration = .milliseconds(15)

        let beat = pattern.beat(offsetNotePosition: OffsetNotePosition(2), offsetAmount: offsetAmount)

        #expect(beat.subdivisions.count == 6)
        guard case let .note(v0, o0) = beat.subdivisions[0] else { Issue.record("Expected note at grid 0"); return }
        #expect(v0 == RhythmVelocity.accent)
        #expect(o0 == .zero)
        guard case .rest = beat.subdivisions[1] else { Issue.record("Expected rest at grid 1"); return }
        guard case let .note(v2, o2) = beat.subdivisions[2] else { Issue.record("Expected note at grid 2"); return }
        #expect(v2 == RhythmVelocity.normal)
        #expect(o2 == offsetAmount)
        guard case .rest = beat.subdivisions[3] else { Issue.record("Expected rest at grid 3"); return }
        guard case .rest = beat.subdivisions[4] else { Issue.record("Expected rest at grid 4"); return }
        guard case let .note(v5, o5) = beat.subdivisions[5] else { Issue.record("Expected note at grid 5"); return }
        #expect(v5 == RhythmVelocity.normal)
        #expect(o5 == .zero)
    }

    @Test("beat for pattern_nested_01 at default position 3 places the offset on the middle nested-triplet leaf")
    func beatForPattern10PlacesOffsetOnNestedMiddleLeaf() {
        // pattern_nested_01 (`* *-*-*`): `audibleToGrid[2] = [1, 1]` — middle note of
        // the nested triplet at top-level index 1.
        let pattern = TimingOffsetDetectionPattern.pattern_nested_01
        let offsetAmount: Duration = .milliseconds(18)

        let beat = pattern.beat(offsetNotePosition: OffsetNotePosition(3), offsetAmount: offsetAmount)

        #expect(beat.subdivisions.count == 2)
        guard case let .note(topVelocity, topOffset) = beat.subdivisions[0] else {
            Issue.record("Expected top-level subdivision 0 to remain a note"); return
        }
        #expect(topVelocity == RhythmVelocity.accent)
        #expect(topOffset == .zero)
        guard case let .nested(rebuiltChild) = beat.subdivisions[1] else {
            Issue.record("Expected top-level subdivision 1 to remain nested"); return
        }
        #expect(rebuiltChild.subdivisions.count == 3)
        for (childIndex, sub) in rebuiltChild.subdivisions.enumerated() {
            guard case let .note(velocity, offset) = sub else {
                Issue.record("Expected nested subdivision \(childIndex) to be a note"); return
            }
            #expect(velocity == RhythmVelocity.normal)
            let expectedOffset: Duration = (childIndex == 1) ? offsetAmount : .zero
            #expect(offset == expectedOffset, "nested offset mismatch at child index \(childIndex)")
        }
    }
}
