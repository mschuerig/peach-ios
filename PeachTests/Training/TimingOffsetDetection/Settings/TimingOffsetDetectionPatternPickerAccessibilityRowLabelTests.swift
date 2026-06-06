import Testing
@testable import Peach

/// PF-036 — pins the equivalence between the static
/// `TimingOffsetDetectionPatternPickerSettingsSection.patternRowAccessibilityLabel(for:)`
/// helper and the per-cell `TimingDotView.cellAccessibilityLabel(for:in:)`
/// pipeline that SwiftUI's `.accessibilityElement(children: .combine)` joins
/// at runtime. The original Story 85.6 plan was to host the row in a real
/// `UIWindow` and read VoiceOver's actual combined label — but iOS 26 + the
/// SwiftUI accessibility-tree materialization regression
/// (cashapp/AccessibilitySnapshot #245, #259) leaves
/// `UIHostingController(rootView:)`'s a11y tree empty in unit tests, with no
/// supported workaround.
///
/// Instead, this suite pins the *composition contract* structurally: the
/// static helper composes its output from `TimingDotView.cellAccessibilityLabel`
/// joined with `", "` over the focusable visual cells (`.accent` and
/// `.normalAudible`; `.orphanRest` and `.nestingBracket` contribute nothing).
/// A future refactor that diverges either path — e.g., inlines a different
/// formatter into `patternRowAccessibilityLabel`, changes the join separator,
/// or surfaces a new `VisualCellKind` case in `TimingDotView` without
/// updating the helper's exhaustive switch — fails this test, regardless of
/// whether the runtime `.combine` join is observable.
///
/// Cell-by-cell label correctness (the *content* of each focusable cell's
/// VoiceOver label) is already pinned by the existing per-pattern tests in
/// `TimingOffsetDetectionPatternPickerSettingsSectionTests`.
@Suite("TimingOffsetDetectionPatternPickerSettingsSection — row label composition pipeline (PF-036)")
struct TimingOffsetDetectionPatternPickerAccessibilityRowLabelTests {

    @Test("patternRowAccessibilityLabel(for:) equals the join of every non-empty TimingDotView.cellAccessibilityLabel for every catalog pattern")
    func patternRowLabelEqualsCellByCellJoinForEveryCatalogPattern() {
        for pattern in TimingOffsetDetectionPatternCatalog.all {
            // Independent oracle: ask each visual cell for its label and keep
            // the non-empty ones. This avoids re-implementing the helper's
            // `.accent / .normalAudible` switch in the test (which would make
            // the assertion tautological) — `cellAccessibilityLabel` returns
            // "" for `.orphanRest` / `.nestingBracket` by contract.
            let focusableCellLabels = TimingDotView.visualCells(for: pattern)
                .map { TimingDotView.cellAccessibilityLabel(for: $0, in: pattern) }
                .filter { !$0.isEmpty }
            let expected = focusableCellLabels.joined(separator: ", ")
            let actual = TimingOffsetDetectionPatternPickerSettingsSection.patternRowAccessibilityLabel(for: pattern)

            #expect(
                actual == expected,
                "Pattern \(pattern.id): row label must equal the join of every non-empty TimingDotView.cellAccessibilityLabel. Expected '\(expected)', got '\(actual)'."
            )
            // `count >= 1` catches the symmetric-empty-drift case: if
            // `cellAccessibilityLabel` ever returns `""` for every focusable
            // cell of some pattern, the filter strips them all, the join is
            // empty, the parity check passes, and the row goes silent — this
            // assertion fires.
            #expect(
                focusableCellLabels.count >= 1,
                "Pattern \(pattern.id): must contain at least one focusable cell with a non-empty label — a silent row is a catalog invariant violation."
            )
        }
    }
}
