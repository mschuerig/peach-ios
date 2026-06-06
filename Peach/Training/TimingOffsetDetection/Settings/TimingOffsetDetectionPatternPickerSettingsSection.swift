import SwiftUI

/// Settings row that lets the user pick the rhythmic pattern played on each
/// TOD trial. Renders a static dot-row preview per catalog entry — the visual
/// *is* the pattern's identity, no per-entry display name — sharing the
/// ``TimingDotView`` vocabulary at a smaller scale. Selecting a row writes
/// both ``TimingOffsetDetectionSettingsKeys/selectedPatternId`` *and*
/// ``TimingOffsetDetectionSettingsKeys/offsetNotePosition`` (reset to the new
/// pattern's ``TimingOffsetDetectionPattern/defaultOffsetNotePosition``); see
/// `tod-initial-pattern-catalog.md` § *Migration target* / *Cross-pattern
/// semantics*.
struct TimingOffsetDetectionPatternPickerSettingsSection: View {
    @AppStorage(TimingOffsetDetectionSettingsKeys.selectedPatternId)
    private var selectedPatternId: String = TimingOffsetDetectionPatternCatalog.defaultPatternId

    @AppStorage(TimingOffsetDetectionSettingsKeys.offsetNotePosition)
    private var offsetNotePosition: Int = OffsetNotePosition.default.rawValue

    /// Picker-preview scale, Dynamic-Type-aware. Initial value comes from
    /// ``TimingDotView/previewScale`` so all small-preview surfaces stay in
    /// lockstep with the training-screen vocabulary.
    @ScaledMetric(relativeTo: .caption2) private var dotScale: CGFloat = TimingDotView.previewScale

    /// Drives the programmatic push to the drill-down picker destination.
    /// We don't use `NavigationLink` here because its system-rendered
    /// disclosure chevron has an opaque intrinsic width — we render the
    /// chevron ourselves via ``TimingDotView/patternRowChevron(isVisible:)``
    /// so the *Offset Note Position* row can reserve identical trailing width
    /// and the two rows' dot positions align by construction.
    @State private var isShowingDestination = false

    var body: some View {
        let activePattern = TimingOffsetDetectionPatternCatalog.pattern(forStoredId: selectedPatternId)
        Section {
            Button {
                isShowingDestination = true
            } label: {
                HStack(spacing: TimingDotView.patternRowChevronSpacing) {
                    Self.row(for: activePattern, dotScale: dotScale)
                    TimingDotView.patternRowChevron(isVisible: true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(Self.patternRowAccessibilityLabel(for: activePattern))
            .navigationDestination(isPresented: $isShowingDestination) {
                TimingOffsetDetectionPatternPickerDestination(
                    patternIdBinding: patternIdBinding,
                    dotScale: dotScale
                )
            }
        } header: {
            Text(String(localized: "Pattern"))
        } footer: {
            Text(String(localized: "Pick the rhythmic pattern used for each trial."))
        }
    }

    /// Writes both `@AppStorage` keys in one binding-set call so the
    /// reset-on-pattern-change rule (`tod-initial-pattern-catalog.md`
    /// § *Cross-pattern semantics*) is atomic. The stored selected id is the
    /// *resolved* pattern's id — an unknown user-supplied id is silently
    /// rewritten to the catalog default so storage stays self-consistent.
    /// The `get` returns the resolved canonical id (not the raw stored value)
    /// so the drill-down `Picker`'s row tags match even when storage carries
    /// a retired id — keeps the displayed selection in step with the outer
    /// row's preview, which already resolves through ``pattern(forStoredId:)``.
    private var patternIdBinding: Binding<String> {
        Binding(
            get: { TimingOffsetDetectionPatternCatalog.pattern(forStoredId: selectedPatternId).id },
            set: { newId in
                let resolved = Self.cascadeWrites(forNewId: newId)
                offsetNotePosition = resolved.offsetNotePosition
                selectedPatternId = resolved.selectedPatternId
            }
        )
    }

    /// Resolves the pair `(selectedPatternId, offsetNotePosition)` written by
    /// the binding when the user picks a row. Pulled out as a static helper so
    /// the cascade — including the unknown-id fallback — is unit-testable.
    static func cascadeWrites(
        forNewId newId: String
    ) -> (selectedPatternId: String, offsetNotePosition: Int) {
        let pattern = TimingOffsetDetectionPatternCatalog.pattern(forStoredId: newId)
        return (pattern.id, pattern.defaultOffsetNotePosition.rawValue)
    }

    /// Dot-row preview for one pattern. Uses ``accessibilityElement(children: .combine)``
    /// so the row stays a single focusable element while its VoiceOver label is
    /// composed from the per-cell labels ``TimingDotView`` now exposes (per
    /// `tod-tuplet-renderer-design.md` § *Per-cell accessibility labels*).
    @ViewBuilder
    static func row(
        for pattern: TimingOffsetDetectionPattern,
        dotScale: CGFloat
    ) -> some View {
        TimingDotView(
            pattern: pattern,
            offsetNotePosition: nil,
            litCount: pattern.subdivisions.count,
            scale: dotScale
        )
        .accessibilityElement(children: .combine)
    }

    /// Composes the row's locked-form VoiceOver label by joining per-cell
    /// ``TimingDotView/cellAccessibilityLabel(for:in:)`` outputs (skipping rest
    /// cells and brackets, which contribute no label). `pattern_straight16ths_01` reads
    /// "Accent, Note 2 of 4, Note 3 of 4, Note 4 of 4".
    static func patternRowAccessibilityLabel(for pattern: TimingOffsetDetectionPattern) -> String {
        TimingDotView.visualCells(for: pattern)
            .compactMap { cell -> String? in
                switch cell.kind {
                case .accent, .normalAudible:
                    return TimingDotView.cellAccessibilityLabel(for: cell, in: pattern)
                case .orphanRest, .nestingBracket:
                    return nil
                }
            }
            .joined(separator: ", ")
    }

    /// Section header `Text` rendered by the drill-down picker destination.
    /// Extracted so the Story 85.6 AX1 no-truncation test can render this
    /// exact view shape against the longest German header fixture. SwiftUI
    /// default `Text` modifiers are load-bearing here: any modifier that
    /// constrains line count, truncates, or scales text down (e.g.
    /// `.lineLimit(1)`, `.truncationMode(...)`, `.minimumScaleFactor(...)`,
    /// or wrapping the `Text` in a fixed-height container) breaks
    /// `TimingOffsetDetectionPatternPickerDestinationAX1Tests` by design, per
    /// `tod-tuplet-renderer-design.md` § *Categorization*.
    static func categoryHeader(text: String) -> some View {
        Text(text)
    }
}

/// Drill-down destination for the Pattern picker. Renders one
/// ``SwiftUI/Section`` per ``TimingOffsetDetectionPatternCategory`` present in
/// the current build's catalog; each section embeds an inline ``Picker`` over
/// its category's patterns, all sharing the same ``patternIdBinding`` so
/// selection cascades through the existing
/// `(selectedPatternId, offsetNotePosition)` reset logic regardless of which
/// category the user picks from. Section headers vend via SwiftUI defaults
/// (no `.lineLimit` / `.truncationMode`) so AX1 wraps rather than truncates
/// per `tod-tuplet-renderer-design.md` § *Categorization*. Build-flag gating
/// of categories is data-driven via
/// ``TimingOffsetDetectionPatternCatalog/categories``.
private struct TimingOffsetDetectionPatternPickerDestination: View {
    let patternIdBinding: Binding<String>
    let dotScale: CGFloat

    var body: some View {
        Form {
            ForEach(TimingOffsetDetectionPatternCatalog.categories, id: \.self) { category in
                Section {
                    // `Picker` requires a label argument, but the section
                    // header already carries the category name for both
                    // sighted and VoiceOver users — `EmptyView()` +
                    // `.labelsHidden()` ensures the label contributes no
                    // second announcement.
                    Picker(selection: patternIdBinding) {
                        ForEach(TimingOffsetDetectionPatternCatalog.patterns(in: category), id: \.id) { pattern in
                            TimingOffsetDetectionPatternPickerSettingsSection
                                .row(for: pattern, dotScale: dotScale)
                                .tag(pattern.id)
                        }
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    TimingOffsetDetectionPatternPickerSettingsSection.categoryHeader(
                        text: category.localizedHeader
                    )
                }
            }
        }
        .platformFormStyle()
        .navigationTitle(String(localized: "Pattern"))
        .inlineNavigationBarTitle()
    }
}
