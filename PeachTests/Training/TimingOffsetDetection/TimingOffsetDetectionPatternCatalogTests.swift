import Testing
import Foundation
@testable import Peach

#if PEACH_RESEARCH
@Suite("TimingOffsetDetectionPatternCatalog Tests")
struct TimingOffsetDetectionPatternCatalogTests {

    @Test("all lists the five catalog entries in display order")
    func allListsFiveCatalogEntriesInDisplayOrder() {
        #expect(TimingOffsetDetectionPatternCatalog.all == [
            .pattern1111,
            .pattern1011,
            .pattern1101,
            .pattern1010,
            .pattern1001
        ])
    }

    @Test("defaultPatternId is `pattern_1111`")
    func defaultPatternIdIsPattern1111() {
        #expect(TimingOffsetDetectionPatternCatalog.defaultPatternId == "pattern_1111")
    }

    @Test("defaultPattern resolves to pattern_1111")
    func defaultPatternResolvesToPattern1111() {
        #expect(TimingOffsetDetectionPatternCatalog.defaultPattern.id == "pattern_1111")
        #expect(TimingOffsetDetectionPatternCatalog.defaultPattern == TimingOffsetDetectionPattern.pattern1111)
    }

    @Test("pattern(withId:) returns the registered pattern for a known id")
    func patternWithKnownIdReturnsThatPattern() throws {
        let pattern = try TimingOffsetDetectionPatternCatalog.pattern(withId: "pattern_1111")
        #expect(pattern == TimingOffsetDetectionPattern.pattern1111)
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
        let pattern = TimingOffsetDetectionPatternCatalog.pattern(forStoredId: "pattern_1111")
        #expect(pattern == TimingOffsetDetectionPattern.pattern1111)
    }

    @Test("pattern(forStoredId:) falls back to defaultPattern for an unknown id (no throw, no log)")
    func patternForStoredIdFallsBackOnUnknownId() {
        let pattern = TimingOffsetDetectionPatternCatalog.pattern(forStoredId: "pattern_xxxx")
        #expect(pattern == TimingOffsetDetectionPatternCatalog.defaultPattern)
    }
}
#endif
