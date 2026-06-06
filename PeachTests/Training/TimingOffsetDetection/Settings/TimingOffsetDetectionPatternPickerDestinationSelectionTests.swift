import Testing
@testable import Peach

/// PF-040 — re-pins the catalog discipline that makes the destination's
/// sectioned-`Picker` shared-binding rendering safe: every catalog pattern
/// belongs to exactly one category, so at most one section's `Picker` can
/// ever contain the currently-selected id. Without this invariant, two
/// `Picker`s could both match the binding and SwiftUI would render two
/// selection indicators — the "phantom indicator" failure mode PF-040
/// describes.
///
/// The original Story 85.6 plan was to host the destination in a real
/// `UIWindow`, drive the binding, and read the `.isSelected` trait off
/// the SwiftUI accessibility tree — but iOS 26 + the SwiftUI a11y-tree
/// materialization regression (cashapp/AccessibilitySnapshot #245, #259)
/// leaves the hosted view's tree empty in unit tests, with no supported
/// workaround. The catalog-discipline check pins the *necessary condition*
/// for the runtime invariant, which is what actually fails when the
/// discipline drifts.
///
/// Coverage overlap by design. The same invariant is also pinned by
/// `TimingOffsetDetectionPatternCatalogTests.categoriesCoverEveryPatternExactlyOnce`
/// (set-equality + per-id-uniqueness across `categories.flatMap(patterns(in:))`)
/// and `patternIdMatchesCategoryPrefix` (self-reported `.category` matches
/// the id schema). This file keeps the assertion under a PF-040-named suite
/// so a future regression surfaces with the PF-040 framing in CI output, not
/// just a generic catalog-test failure. The expensive O(C²) pairwise
/// formulation has been replaced with the same `Set`-equality shape the
/// catalog tests use.
@Suite("TimingOffsetDetectionPatternPickerDestination — selection-uniqueness precondition (PF-040)")
struct TimingOffsetDetectionPatternPickerDestinationSelectionTests {

    @Test("the destination's sectioned-Picker shared-binding cannot render multiple selection indicators: every catalog pattern appears in exactly one category's bucket")
    func sectionedPickerSharedBindingMatchesAtMostOneRow() {
        // Each id flat-mapped from `categories.flatMap(patterns(in:))` is the
        // *runtime* surface the destination iterates to layout its sibling
        // `Picker`s. Set-equality with `all.map(\.id)` exhausts coverage;
        // count-equality forbids duplicate buckets. If a future refactor
        // sources `patterns(in:)` from a different table than the destination
        // walks for its sections, that table's drift surfaces here.
        let categories = TimingOffsetDetectionPatternCatalog.categories
        let bucketedIds = categories.flatMap {
            TimingOffsetDetectionPatternCatalog.patterns(in: $0).map(\.id)
        }
        let catalogIds = TimingOffsetDetectionPatternCatalog.all.map(\.id)

        #expect(
            Set(bucketedIds) == Set(catalogIds),
            "Coverage gap: ids surfaced by `categories.flatMap(patterns(in:))` differ from `all`. The destination's sections would either drop a pattern or surface an unregistered id, breaking the shared-binding selection cascade."
        )
        #expect(
            bucketedIds.count == Set(bucketedIds).count,
            "Duplicate-bucket regression: pattern ids \(Dictionary(grouping: bucketedIds, by: { $0 }).filter { $0.value.count > 1 }.keys) appear in more than one category. The destination's two sibling `Picker`s would both match the binding, rendering multiple selection indicators."
        )
        #expect(
            bucketedIds.count == catalogIds.count,
            "Total bucketed count \(bucketedIds.count) ≠ catalog count \(catalogIds.count) — destination's section list and catalog's pattern list are out of sync."
        )
    }
}
