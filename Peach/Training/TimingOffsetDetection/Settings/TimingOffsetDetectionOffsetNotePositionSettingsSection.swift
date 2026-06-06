import SwiftUI

/// Pattern-driven slot picker. Lays its cells out with the same
/// proportional-timeline math the pattern preview uses
/// (``TimingDotView/visualCells(for:)``) so the slot-picker dots align
/// horizontally with the dots in the *Pattern* section's preview row. Each
/// visual cell renders by kind:
///
/// - **Accent** (audible 1) — large `beatOneDotDiameter` circle, non-tappable,
///   VoiceOver-focusable as "Accent, not selectable".
/// - **Normal audible** (audible 2..K) — tappable `Button` whose label is the
///   selection glyph (single dot if not selected, doubled glyph if selected).
///   The cell's full proportional width is the tap target.
/// - **Orphan rest** — empty cell of preserved proportional width, not
///   focusable. None of the Epic-82 flat catalog entries triggers this case.
/// - **Nesting bracket** — suppressed in the slot picker; brackets are a
///   visual-grouping affordance for the pattern preview only.
///
/// Dots are leading-aligned within their cell so the audible's note onset sits
/// at the cell's left edge; the doubled-glyph's first circle sits at the same
/// x as the pattern preview's dot for that audible position.
struct TimingOffsetDetectionOffsetNotePositionSettingsSection: View {
    @AppStorage(TimingOffsetDetectionSettingsKeys.offsetNotePosition)
    private var offsetNotePosition: Int = OffsetNotePosition.default.rawValue

    @AppStorage(TimingOffsetDetectionSettingsKeys.selectedPatternId)
    private var selectedPatternId: String = TimingOffsetDetectionPatternCatalog.defaultPatternId

    /// Story 85.7: fixed shared width mirrored from the *Pattern* row above.
    /// The two flexible dot containers are guaranteed identical by direct
    /// assignment of this width, so audible positions land at the same x in
    /// both rows regardless of what trails them.
    @ScaledMetric(relativeTo: .caption2) private var dotRowWidth: CGFloat = TimingDotView.settingsRowDotsBaseWidth

    private var activePattern: TimingOffsetDetectionPattern {
        TimingOffsetDetectionPatternCatalog.pattern(forStoredId: selectedPatternId)
    }

    private var effectivePosition: OffsetNotePosition {
        activePattern.clampedOffsetNotePosition(offsetNotePosition)
    }

    var body: some View {
        let pattern = activePattern
        let selected = effectivePosition
        let cells = TimingDotView.visualCells(for: pattern).filter {
            if case .nestingBracket = $0.kind { return false }
            return true
        }
        let contentHeight = TimingDotView.beatOneDotDiameter

        Section {
            GeometryReader { proxy in
                let containerWidth = proxy.size.width
                ZStack(alignment: .topLeading) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                        slotCell(
                            cell,
                            containerWidth: containerWidth,
                            contentHeight: contentHeight,
                            selected: selected,
                            audibleCount: pattern.audibleCount
                        )
                    }
                }
            }
            .frame(maxWidth: dotRowWidth, alignment: .leading)
            .frame(height: contentHeight)
        } header: {
            Text(String(localized: "Offset Note Position"))
        } footer: {
            Text(String(localized: "Pick which note carries the timing offset."))
        }
    }

    @ViewBuilder
    private func slotCell(
        _ cell: TimingDotView.VisualCell,
        containerWidth: CGFloat,
        contentHeight: CGFloat,
        selected: OffsetNotePosition,
        audibleCount: Int
    ) -> some View {
        let cellWidth = cell.widthProportion * containerWidth
        let cellLeftX = cell.startXProportion * containerWidth

        switch cell.kind {
        case .accent:
            Circle()
                .fill(.primary)
                .frame(width: TimingDotView.beatOneDotDiameter, height: TimingDotView.beatOneDotDiameter)
                .frame(width: cellWidth, height: contentHeight, alignment: .leading)
                .offset(x: cellLeftX, y: 0)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Self.anchorCellLabel)
                .accessibilityAddTraits(.isStaticText)

        case .normalAudible(let audiblePosition):
            let isSelected = (selected.rawValue == audiblePosition)
            Button {
                offsetNotePosition = audiblePosition
            } label: {
                glyph(isSelected: isSelected)
                    .frame(width: cellWidth, height: contentHeight, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .platformHoverEffect()
            .offset(x: cellLeftX, y: 0)
            .accessibilityLabel(Self.pickableCellLabel(
                position: OffsetNotePosition(audiblePosition),
                audibleCount: audibleCount
            ))
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])

        case .orphanRest:
            Color.clear
                .frame(width: cellWidth, height: contentHeight)
                .offset(x: cellLeftX, y: 0)
                .accessibilityHidden(true)

        case .nestingBracket:
            // Filtered out before this switch; included for exhaustiveness.
            EmptyView()
        }
    }

    /// Slot-picker anchor cell label per `tod-tuplet-renderer-design.md`
    /// § *Per-cell accessibility labels*: locked position-1 form (`"Accent"`)
    /// appended with `", not selectable"` so the slot-picker hint preserves
    /// 82.3's non-tappable signal. Exposed for unit-testability.
    static var anchorCellLabel: String {
        String(localized: "Accent, not selectable")
    }


    @ViewBuilder
    private func glyph(isSelected: Bool) -> some View {
        if isSelected {
            // Shift the doubled-glyph left by `overlapOffset/2` so its visual
            // center sits at the same x as the corresponding single dot in the
            // *Pattern* row's preview. Same rationale as
            // `TimingDotView.audibleDot`.
            TimingDotView.doubledGlyph(
                diameter: TimingDotView.dotDiameter,
                overlapOffset: TimingDotView.overlapOffset
            )
            .offset(x: -TimingDotView.overlapOffset / 2)
        } else {
            Circle()
                .fill(.primary)
                .frame(width: TimingDotView.dotDiameter, height: TimingDotView.dotDiameter)
        }
    }

    /// VoiceOver label for a pickable cell. K is the *audible* count per
    /// `tod-initial-pattern-catalog.md` § *Pickable-position rule* — avoids the
    /// audible-3-of-grid-4 mismatch on rest-bearing patterns.
    static func pickableCellLabel(
        position: OffsetNotePosition,
        audibleCount: Int
    ) -> String {
        String(localized: "Note \(position.rawValue) of \(audibleCount)")
    }
}
