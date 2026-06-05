import Testing
import Foundation
@testable import Peach

@Suite("TimingOffsetDetectionPatternCatalog Tests")
struct TimingOffsetDetectionPatternCatalogTests {

    @Test("all lists the catalog entries in design-doc display order (Nested bucket gated by PEACH_RESEARCH)")
    func allListsCatalogEntriesInDisplayOrder() {
        var expected: [TimingOffsetDetectionPattern] = [
            .pattern_straight16ths_01, .pattern_gapped16ths_01, .pattern_gapped16ths_02, .pattern_gapped16ths_03, .pattern_gapped16ths_04,
            .pattern_triplets_01, .pattern_triplets_02, .pattern_triplets_03, .pattern_triplets_04
        ]
        #if PEACH_RESEARCH
        expected.append(contentsOf: [.pattern_nested_01, .pattern_nested_02, .pattern_nested_03, .pattern_nested_04, .pattern_nested_05])
        #endif
        expected.append(.pattern_sextuplet_01)
        #expect(TimingOffsetDetectionPatternCatalog.all == expected)
    }

    @Test("defaultPatternId is `pattern_straight16ths_01`")
    func defaultPatternIdIsPattern01() {
        #expect(TimingOffsetDetectionPatternCatalog.defaultPatternId == "pattern_straight16ths_01")
    }

    @Test("defaultPattern resolves to pattern_straight16ths_01")
    func defaultPatternResolvesToPattern01() {
        #expect(TimingOffsetDetectionPatternCatalog.defaultPattern.id == "pattern_straight16ths_01")
        #expect(TimingOffsetDetectionPatternCatalog.defaultPattern == TimingOffsetDetectionPattern.pattern_straight16ths_01)
    }

    @Test("pattern(withId:) returns the registered pattern for a known id")
    func patternWithKnownIdReturnsThatPattern() throws {
        let pattern = try TimingOffsetDetectionPatternCatalog.pattern(withId: "pattern_straight16ths_01")
        #expect(pattern == TimingOffsetDetectionPattern.pattern_straight16ths_01)
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
        let pattern = TimingOffsetDetectionPatternCatalog.pattern(forStoredId: "pattern_straight16ths_01")
        #expect(pattern == TimingOffsetDetectionPattern.pattern_straight16ths_01)
    }

    @Test("pattern(forStoredId:) falls back to defaultPattern for an unknown id (no throw, no log)")
    func patternForStoredIdFallsBackOnUnknownId() {
        let pattern = TimingOffsetDetectionPatternCatalog.pattern(forStoredId: "pattern_xxxx")
        #expect(pattern == TimingOffsetDetectionPatternCatalog.defaultPattern)
    }

    // MARK: - ID-schema regression (Story 84.4 iteration 4)

    /// Locks the exact id strings — `Pattern == Pattern` is id-only (see
    /// ``TimingOffsetDetectionPattern`` `Hashable` extension), so the
    /// `allListsCatalogEntriesInDisplayOrder` test above would pass even if
    /// every entry's `id` literal were rewritten to garbage. This test reads
    /// the ids directly and pins them to the locked `pattern_<category>_NN`
    /// schema.
    @Test("catalog ids match the locked `pattern_<category>_NN` schema in display order (Nested gated by PEACH_RESEARCH)")
    func catalogIdsMatchSchema() {
        let ids = TimingOffsetDetectionPatternCatalog.all.map(\.id)
        var expected = [
            "pattern_straight16ths_01", "pattern_gapped16ths_01", "pattern_gapped16ths_02", "pattern_gapped16ths_03", "pattern_gapped16ths_04",
            "pattern_triplets_01", "pattern_triplets_02", "pattern_triplets_03", "pattern_triplets_04"
        ]
        #if PEACH_RESEARCH
        expected.append(contentsOf: ["pattern_nested_01", "pattern_nested_02", "pattern_nested_03", "pattern_nested_04", "pattern_nested_05"])
        #endif
        expected.append("pattern_sextuplet_01")
        #expect(ids == expected)
    }

    /// Hand-written expected subdivisions per entry — proves the catalog's
    /// `Beat` builder shapes match the locked design-doc *Catalog* table at
    /// the engine boundary. The test does NOT compose against the production
    /// constants (which would tautologically agree with themselves). Nested
    /// entries use ``Cell/nested(_:)`` with the recursive expected shape;
    /// match is depth-recursive via ``expectSubdivisions(_:matches:)``.
    @Test(
        "each registered catalog entry exposes the locked subdivisions per the design-doc Catalog table",
        arguments: [
            ("pattern_straight16ths_01", [Self.Cell.accent, .normal, .normal, .normal]),
            ("pattern_gapped16ths_01", [Self.Cell.accent, .rest, .normal, .normal]),
            ("pattern_gapped16ths_02", [Self.Cell.accent, .normal, .rest, .normal]),
            ("pattern_gapped16ths_03", [Self.Cell.accent, .rest, .normal, .rest]),
            ("pattern_gapped16ths_04", [Self.Cell.accent, .rest, .rest, .normal]),
            ("pattern_triplets_01", [Self.Cell.accent, .normal, .normal]),
            ("pattern_triplets_02", [Self.Cell.accent, .normal, .rest]),
            ("pattern_triplets_03", [Self.Cell.accent, .rest, .normal]),
            ("pattern_triplets_04", [Self.Cell.accent, .rest, .normal, .rest, .rest, .normal]),
            ("pattern_sextuplet_01", [Self.Cell.accent, .normal, .normal, .normal, .normal, .normal])
        ] as [(String, [Self.Cell])]
    )
    func catalogEntrySubdivisions(expectation: (id: String, cells: [Self.Cell])) throws {
        let pattern = try TimingOffsetDetectionPatternCatalog.pattern(withId: expectation.id)
        Self.expectSubdivisions(pattern.subdivisions, matches: expectation.cells, patternId: pattern.id, pathPrefix: [])
    }

    #if PEACH_RESEARCH
    /// Nested-bucket subdivision checks — registered only in `PEACH_RESEARCH`
    /// builds. See ``TimingOffsetDetectionPatternCatalog/all``'s gating note.
    @Test(
        "each Nested-bucket entry exposes the locked subdivisions (PEACH_RESEARCH-gated)",
        arguments: [
            ("pattern_nested_01", [Self.Cell.accent, .nested([.normal, .normal, .normal])]),
            ("pattern_nested_02", [Self.Cell.nested([.accent, .normal, .normal]), .normal]),
            ("pattern_nested_03", [Self.Cell.accent, .normal, .nested([.normal, .normal])]),
            ("pattern_nested_04", [Self.Cell.accent, .nested([.normal, .normal]), .normal]),
            ("pattern_nested_05", [Self.Cell.nested([.accent, .normal]), .normal, .normal])
        ] as [(String, [Self.Cell])]
    )
    func researchOnlyNestedCatalogEntrySubdivisions(expectation: (id: String, cells: [Self.Cell])) throws {
        let pattern = try TimingOffsetDetectionPatternCatalog.pattern(withId: expectation.id)
        Self.expectSubdivisions(pattern.subdivisions, matches: expectation.cells, patternId: pattern.id, pathPrefix: [])
    }
    #endif

    /// Depth-recursive subdivisions matcher: walks both expected and actual
    /// in lockstep, descending into nested children when the expected cell is
    /// ``Cell/nested(_:)``. Records a precise issue location (`pathPrefix`)
    /// on mismatch so a failure at e.g. `pattern_nested_01` nested-child index 1
    /// reports `"pattern_nested_01 grid 1.1: expected normal, got rest"`.
    /// Hard cap on the matcher's recursion so a malformed expected fixture
    /// (`Cell.nested(.nested(.nested(...)))` running away) can't infinite-loop
    /// alongside an equally deep actual `Beat` tree. Raise this if a catalog
    /// entry genuinely needs deeper nesting; Epic 84 is depth-1 only.
    private static let maxRecursionDepth = 4

    private static func expectSubdivisions(
        _ subdivisions: [Subdivision],
        matches expected: [Cell],
        patternId: String,
        pathPrefix: [Int]
    ) {
        #expect(
            pathPrefix.count <= maxRecursionDepth,
            "\(patternId) at path \(pathPrefix.map(String.init).joined(separator: ".")) exceeds matcher max recursion depth \(maxRecursionDepth) — raise the constant if a deeper-nesting catalog entry is being added"
        )
        guard pathPrefix.count <= maxRecursionDepth else { return }
        #expect(
            subdivisions.count == expected.count,
            "\(patternId) at path \(pathPrefix.map(String.init).joined(separator: ".")) count mismatch: got \(subdivisions.count), expected \(expected.count)"
        )
        guard subdivisions.count == expected.count else { return }
        for (index, expectedCell) in expected.enumerated() {
            let actual = subdivisions[index]
            let path = pathPrefix + [index]
            let pathLabel = path.map(String.init).joined(separator: ".")
            switch (expectedCell, actual) {
            case (.accent, .note(let velocity, let offset)):
                #expect(velocity == RhythmVelocity.accent, "\(patternId) grid \(pathLabel) wrong velocity")
                #expect(offset == .zero, "\(patternId) grid \(pathLabel) wrong offset")
            case (.normal, .note(let velocity, let offset)):
                #expect(velocity == RhythmVelocity.normal, "\(patternId) grid \(pathLabel) wrong velocity")
                #expect(offset == .zero, "\(patternId) grid \(pathLabel) wrong offset")
            case (.rest, .rest):
                continue
            case (.nested(let expectedChild), .nested(let actualChild)):
                expectSubdivisions(
                    actualChild.subdivisions,
                    matches: expectedChild,
                    patternId: patternId,
                    pathPrefix: path
                )
            default:
                Issue.record("\(patternId) grid \(pathLabel): expected \(expectedCell), got \(actual)")
            }
        }
    }

    indirect enum Cell {
        case accent
        case normal
        case rest
        case nested([Cell])
    }

    // MARK: - Category invariants (Story 84.4 iteration 4)

    @Test("categories lists the categories with at least one registered pattern, in display order (Nested gated by PEACH_RESEARCH)")
    func categoriesInDisplayOrder() {
        var expected: [TimingOffsetDetectionPatternCategory] = [.straight16ths, .gapped16ths, .triplets]
        #if PEACH_RESEARCH
        expected.append(.nested)
        #endif
        expected.append(.sextuplet)
        #expect(TimingOffsetDetectionPatternCatalog.categories == expected)
    }

    @Test("every catalog pattern belongs to exactly one category covered by Catalog.categories")
    func categoriesCoverEveryPatternExactlyOnce() {
        let allCategoryIds = TimingOffsetDetectionPatternCatalog.categories
            .flatMap { TimingOffsetDetectionPatternCatalog.patterns(in: $0).map(\.id) }
        let catalogIds = TimingOffsetDetectionPatternCatalog.all.map(\.id)
        // Exhaustive: every catalog id appears in some category's filtered list.
        #expect(Set(allCategoryIds) == Set(catalogIds), "Category coverage mismatch")
        // Exclusive: no id appears in two categories (each pattern carries one category).
        #expect(
            allCategoryIds.count == Set(allCategoryIds).count,
            "Pattern id appeared in multiple categories: \(allCategoryIds)"
        )
        // Total counts agree.
        #expect(allCategoryIds.count == catalogIds.count)
    }

    @Test("Catalog.patterns(in:) returns the patterns whose category matches, in catalog display order, for always-on categories")
    func patternsInCategoryAssignment() {
        #expect(
            TimingOffsetDetectionPatternCatalog.patterns(in: .straight16ths).map(\.id)
                == ["pattern_straight16ths_01"]
        )
        #expect(
            TimingOffsetDetectionPatternCatalog.patterns(in: .gapped16ths).map(\.id)
                == ["pattern_gapped16ths_01", "pattern_gapped16ths_02", "pattern_gapped16ths_03", "pattern_gapped16ths_04"]
        )
        #expect(
            TimingOffsetDetectionPatternCatalog.patterns(in: .triplets).map(\.id)
                == ["pattern_triplets_01", "pattern_triplets_02", "pattern_triplets_03", "pattern_triplets_04"]
        )
        #expect(
            TimingOffsetDetectionPatternCatalog.patterns(in: .sextuplet).map(\.id)
                == ["pattern_sextuplet_01"]
        )
    }

    @Test("Catalog.patterns(in: .nested) returns the five locked entries under PEACH_RESEARCH and an empty list otherwise")
    func nestedCategoryMembership() {
        #if PEACH_RESEARCH
        #expect(
            TimingOffsetDetectionPatternCatalog.patterns(in: .nested).map(\.id)
                == ["pattern_nested_01", "pattern_nested_02", "pattern_nested_03", "pattern_nested_04", "pattern_nested_05"]
        )
        #else
        #expect(TimingOffsetDetectionPatternCatalog.patterns(in: .nested).isEmpty)
        #endif
    }

    @Test("every registered pattern's category matches the prefix in its id")
    func patternIdMatchesCategoryPrefix() {
        for pattern in TimingOffsetDetectionPatternCatalog.all {
            #expect(
                pattern.id.hasPrefix("pattern_\(pattern.category.idToken)_"),
                "Pattern \(pattern.id) does not match the 'pattern_\(pattern.category.idToken)_NN' schema for its declared category \(pattern.category)"
            )
        }
    }

    @Test("Category.idToken round-trips: the token in every catalog pattern's id matches a known category's idToken")
    func categoryIdTokenRoundTrips() {
        let knownTokens = Set(TimingOffsetDetectionPatternCategory.allCases.map(\.idToken))
        for pattern in TimingOffsetDetectionPatternCatalog.all {
            // pattern_<idToken>_NN — extract the middle segment.
            let parts = pattern.id.split(separator: "_", maxSplits: 2).map(String.init)
            #expect(parts.count == 3, "Pattern \(pattern.id) does not have three underscore-separated segments")
            if parts.count == 3 {
                #expect(
                    knownTokens.contains(parts[1]),
                    "Pattern \(pattern.id) carries an unknown category idToken '\(parts[1])'"
                )
            }
        }
    }
}
