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

    var body: some View {
        let activePattern = TimingOffsetDetectionPatternCatalog.pattern(forStoredId: selectedPatternId)
        Section {
            NavigationLink {
                TimingOffsetDetectionPatternPickerDestination(
                    patternIdBinding: patternIdBinding,
                    dotScale: dotScale
                )
            } label: {
                LabeledContent {
                    Self.row(for: activePattern, dotScale: dotScale)
                } label: {
                    Text(String(localized: "Pattern"))
                }
            }
            .accessibilityValue(Self.patternRowAccessibilityLabel(for: activePattern))
        } footer: {
            Text(String(localized: "Pick the rhythmic pattern used for each trial."))
        }
    }

    /// Writes both `@AppStorage` keys in one binding-set call so the
    /// reset-on-pattern-change rule (`tod-initial-pattern-catalog.md`
    /// § *Cross-pattern semantics*) is atomic. The stored selected id is the
    /// *resolved* pattern's id — an unknown user-supplied id is silently
    /// rewritten to the catalog default so storage stays self-consistent.
    private var patternIdBinding: Binding<String> {
        Binding(
            get: { selectedPatternId },
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

    /// Dot-row preview for one pattern, with the section's `accessibilityLabel`
    /// already applied. Static so the drill-down destination shares the exact
    /// same renderer — single source of truth for the row vocabulary.
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(patternRowAccessibilityLabel(for: pattern))
    }

    /// Programmatic VoiceOver label for a pattern row, derived from the
    /// subdivision shape per `tod-initial-pattern-catalog.md` § *Preview
    /// Rendering*: `.note` at grid 0 → "Accent"; other `.note` → "Note";
    /// `.rest` (and `.nested`, defensively) → "Rest"; joined by ", ".
    /// `pattern_1111` reads "Accent, Note, Note, Note".
    static func patternRowAccessibilityLabel(for pattern: TimingOffsetDetectionPattern) -> String {
        let tokens: [String] = pattern.subdivisions.enumerated().map { index, subdivision in
            switch subdivision {
            case .rest, .nested:
                return String(localized: "Rest")
            case .note:
                return index == 0 ? String(localized: "Accent") : String(localized: "Note")
            }
        }
        return tokens.joined(separator: ", ")
    }
}

/// Drill-down destination for the Pattern picker. Hosts the inline `Picker`
/// previously embedded in the Settings row, so the row collapses to a single
/// label + dot-row preview + chevron and the catalog can grow without crowding
/// the Settings screen.
private struct TimingOffsetDetectionPatternPickerDestination: View {
    let patternIdBinding: Binding<String>
    let dotScale: CGFloat

    var body: some View {
        Form {
            Section {
                Picker(selection: patternIdBinding) {
                    ForEach(TimingOffsetDetectionPatternCatalog.all, id: \.id) { pattern in
                        TimingOffsetDetectionPatternPickerSettingsSection
                            .row(for: pattern, dotScale: dotScale)
                            .tag(pattern.id)
                    }
                } label: {
                    Text(String(localized: "Pattern"))
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .platformFormStyle()
        .navigationTitle(String(localized: "Pattern"))
        .inlineNavigationBarTitle()
    }
}
