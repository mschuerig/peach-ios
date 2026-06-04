import Testing
import Foundation
@testable import Peach

@Suite("TimingOffsetDetectionPatternCatalog Tests")
struct TimingOffsetDetectionPatternCatalogTests {

    @Test("all lists the five catalog entries in display order")
    func allListsFiveCatalogEntriesInDisplayOrder() {
        #expect(TimingOffsetDetectionPatternCatalog.all == [
            .pattern01,
            .pattern02,
            .pattern03,
            .pattern04,
            .pattern05
        ])
    }

    @Test("defaultPatternId is `pattern_01`")
    func defaultPatternIdIsPattern01() {
        #expect(TimingOffsetDetectionPatternCatalog.defaultPatternId == "pattern_01")
    }

    @Test("defaultPattern resolves to pattern_01")
    func defaultPatternResolvesToPattern01() {
        #expect(TimingOffsetDetectionPatternCatalog.defaultPattern.id == "pattern_01")
        #expect(TimingOffsetDetectionPatternCatalog.defaultPattern == TimingOffsetDetectionPattern.pattern01)
    }

    @Test("pattern(withId:) returns the registered pattern for a known id")
    func patternWithKnownIdReturnsThatPattern() throws {
        let pattern = try TimingOffsetDetectionPatternCatalog.pattern(withId: "pattern_01")
        #expect(pattern == TimingOffsetDetectionPattern.pattern01)
    }

    @Test("pattern(withId:) throws `unknownPatternId` for an unknown id")
    func patternWithUnknownIdThrows() {
        #expect(throws: TimingOffsetDetectionPatternCatalogError.unknownPatternId("pattern_xxxx")) {
            try TimingOffsetDetectionPatternCatalog.pattern(withId: "pattern_xxxx")
        }
    }

    // MARK: - Catalog-wide invariants

    @Test("every registered pattern excludes audible position 1 from its pickable set (metric-anchor rule)")
    func everyPatternExcludesMetricAnchorFromPickable() {
        for pattern in TimingOffsetDetectionPatternCatalog.all {
            #expect(
                pattern.pickable.contains(1) == false,
                "Pattern \(pattern.id) must not list audible position 1 as pickable"
            )
        }
    }

    @Test("every registered pattern's defaultOffsetNotePosition is itself pickable (catalog invariant)")
    func everyPatternDefaultIsPickable() {
        for pattern in TimingOffsetDetectionPatternCatalog.all {
            #expect(
                pattern.pickable.contains(pattern.defaultOffsetNotePosition.rawValue),
                "Pattern \(pattern.id) lists a default that is not in its pickable set"
            )
        }
    }

    @Test("every registered pattern has a unique id (catalog invariant)")
    func everyPatternIdIsUnique() {
        let ids = TimingOffsetDetectionPatternCatalog.all.map(\.id)
        #expect(Set(ids).count == ids.count, "Duplicate pattern ids in catalog: \(ids)")
    }

    @Test("pattern(forStoredId:) returns the registered pattern for a known id")
    func patternForStoredIdReturnsKnownPattern() {
        let pattern = TimingOffsetDetectionPatternCatalog.pattern(forStoredId: "pattern_01")
        #expect(pattern == TimingOffsetDetectionPattern.pattern01)
    }

    @Test("pattern(forStoredId:) falls back to defaultPattern for an unknown id (no throw, no log)")
    func patternForStoredIdFallsBackOnUnknownId() {
        let pattern = TimingOffsetDetectionPatternCatalog.pattern(forStoredId: "pattern_xxxx")
        #expect(pattern == TimingOffsetDetectionPatternCatalog.defaultPattern)
    }

    // MARK: - Opaque-id-swap regression (Story 84.2)

    /// Locks the count and the exact id strings — `Pattern == Pattern` is id-only
    /// (see ``TimingOffsetDetectionPattern`` `Hashable` extension), so the
    /// `allListsFiveCatalogEntriesInDisplayOrder` test above would pass even if
    /// every entry's `id` literal were rewritten to garbage. This test reads the
    /// ids directly and pins them to the rename-map values from
    /// `tod-tuplet-renderer-design.md` § *Opaque pattern-id convention*.
    @Test("catalog ids match the locked opaque convention in display order (pattern_01…pattern_05)")
    func catalogIdsMatchOpaqueConvention() {
        let ids = TimingOffsetDetectionPatternCatalog.all.map(\.id)
        #expect(ids.count == 5)
        #expect(ids == ["pattern_01", "pattern_02", "pattern_03", "pattern_04", "pattern_05"])
    }

    /// Hand-written expected subdivisions per entry — proves the rename in
    /// Story 84.2 is data-only at the engine boundary. Any drift between the
    /// catalog's `Beat` builder shape and the locked Epic 82 audio surfaces
    /// here; the test does NOT compose against the production constants
    /// (which would tautologically agree with themselves).
    @Test(
        "each catalog entry exposes the locked Epic-82 subdivisions",
        arguments: [
            ("pattern_01", [Self.Cell.accent, .normal, .normal, .normal]),
            ("pattern_02", [Self.Cell.accent, .rest, .normal, .normal]),
            ("pattern_03", [Self.Cell.accent, .normal, .rest, .normal]),
            ("pattern_04", [Self.Cell.accent, .rest, .normal, .rest]),
            ("pattern_05", [Self.Cell.accent, .rest, .rest, .normal])
        ] as [(String, [Self.Cell])]
    )
    func catalogEntrySubdivisions(expectation: (id: String, cells: [Self.Cell])) throws {
        let pattern = try TimingOffsetDetectionPatternCatalog.pattern(withId: expectation.id)
        #expect(pattern.subdivisions.count == expectation.cells.count)
        for (index, expectedCell) in expectation.cells.enumerated() {
            let actual = pattern.subdivisions[index]
            switch (expectedCell, actual) {
            case (.accent, .note(let velocity, let offset)):
                #expect(velocity == RhythmVelocity.accent, "\(pattern.id) grid \(index) wrong velocity")
                #expect(offset == .zero, "\(pattern.id) grid \(index) wrong offset")
            case (.normal, .note(let velocity, let offset)):
                #expect(velocity == RhythmVelocity.normal, "\(pattern.id) grid \(index) wrong velocity")
                #expect(offset == .zero, "\(pattern.id) grid \(index) wrong offset")
            case (.rest, .rest):
                continue
            default:
                Issue.record("\(pattern.id) grid \(index): expected \(expectedCell), got \(actual)")
            }
        }
    }

    enum Cell {
        case accent
        case normal
        case rest
    }
}
