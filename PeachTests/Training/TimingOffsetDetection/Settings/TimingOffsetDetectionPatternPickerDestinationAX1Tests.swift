#if canImport(UIKit)
import Testing
import SwiftUI
@testable import Peach

/// PF-041 — pins the AX1 no-truncation invariant locked by
/// `tod-tuplet-renderer-design.md` § *Categorization*. SwiftUI `Text` with
/// default modifiers (no `.lineLimit`, no `.truncationMode`) wraps to
/// multiple lines under width constraints rather than truncating. The
/// destination's `Section { } header: { … }` headers vend through the
/// extracted helper `TimingOffsetDetectionPatternPickerSettingsSection.categoryHeader(text:)`,
/// which returns a bare `Text`. If a future contributor adds `.lineLimit(1)`
/// or `.truncationMode(...)` inside the helper, this test catches it before
/// VoiceOver / AX1 users do.
///
/// The test wraps the helper in `.frame(width: constrainedWidth)` plus an
/// AX1 Dynamic Type override and compares the rendered height of the longest
/// German fixture (`Sechzehntel mit Lücken`) against a single-character
/// baseline. A two-line wrap must be ≥ 1.25× the baseline; equal heights
/// mean a wrap-collapsing modifier collapsed both renderings to one line.
///
/// Note on scope: SwiftUI accessibility-tree introspection in unit tests is
/// broken on iOS 26 (cashapp/AccessibilitySnapshot #245, #259) — `sizeThatFits`
/// for layout is unaffected and is what this test exercises. The matching
/// PF-036 and PF-040 invariants are pinned by structural tests in
/// `TimingOffsetDetectionPatternPickerSettingsSectionTests` instead of by
/// runtime a11y-tree walks.
@Suite("TimingOffsetDetectionPatternPickerDestination — AX1 section header no-truncation (PF-041)")
struct TimingOffsetDetectionPatternPickerDestinationAX1Tests {

    /// Narrow enough that the longest German header (`Sechzehntel mit Lücken`)
    /// must wrap to at least 2 lines at AX1 Dynamic Type, while a single-
    /// character baseline (`X`) stays on one line. `sizeThatFits(proposedWidth:)`
    /// does not by itself constrain the inner `Text`'s width — the harness
    /// wraps the helper in `.frame(width:)` so the wrap is forced and
    /// observable. The longest German fixture at AX1 in default Text font is
    /// ≈ 287 pt naturally; 150 pt forces a decisive multi-line wrap.
    private static let constrainedWidth: CGFloat = 150

    /// Longest German picker section header — defined in `Localizable.xcstrings`
    /// for the `"Gapped 16ths"` key, locked by
    /// `tod-tuplet-renderer-design.md` § *Categorization*. Replicated here as
    /// a string literal so the test does not depend on `Bundle.main`'s
    /// preferred-language resolution.
    private static let longestGermanHeader = "Sechzehntel mit Lücken"

    @Test("categoryHeader wraps the longest German fixture to multiple lines at AX1 while a single-character baseline stays one line")
    func longestGermanHeaderWrapsAtAX1() {
        let longHeight = AccessibilityTreeHelpers.renderedHeight(
            of: sectionHeaderHarness(headerText: Self.longestGermanHeader),
            proposedWidth: Self.constrainedWidth
        )
        let baselineHeight = AccessibilityTreeHelpers.renderedHeight(
            of: sectionHeaderHarness(headerText: "X"),
            proposedWidth: Self.constrainedWidth
        )

        // Multiplicative threshold survives Apple changing absolute AX1 line
        // metrics between iOS versions — what matters is the wrap RATIO. Today
        // (iOS 26) the long fixture wraps to two lines and reports ≈ 1.39× the
        // single-line baseline; `.lineLimit(1)` / `.truncationMode(...)` / any
        // wrap-collapsing modifier added to `categoryHeader(text:)` drops the
        // ratio to ~1.0. A 1.25× floor sits decisively between the two and
        // tolerates ±10% baseline drift across iOS recalibrations.
        let ratio = longHeight / baselineHeight
        #expect(
            ratio >= 1.25,
            "AX1 long-header height (\(longHeight) pt) must be ≥ 1.25× baseline (\(baselineHeight) pt, current ratio \(ratio)) to confirm multi-line wrap of `categoryHeader(text:)`. A near-1.0 ratio means a wrap-collapsing modifier was added to the helper."
        )
    }

    /// Wraps `categoryHeader(text:)` in an explicit `.frame(width:)` plus an
    /// AX1 Dynamic Type override. `UIHostingController.sizeThatFits(in:)`
    /// alone does not constrain the inner `Text`'s width — the explicit frame
    /// is the only reliable way to force the wrap.
    private func sectionHeaderHarness(headerText: String) -> some View {
        TimingOffsetDetectionPatternPickerSettingsSection.categoryHeader(text: headerText)
            .frame(width: Self.constrainedWidth, alignment: .leading)
            .environment(\.dynamicTypeSize, .accessibility1)
    }
}
#endif
