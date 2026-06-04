import SwiftUI

/// Rest-aware, pattern-driven slot picker. Renders one cell per grid
/// subdivision of the active ``TimingOffsetDetectionPattern``; cell behavior is
/// classified by ``cellKind(for:gridIndex:)``:
///
/// - **Anchor** — `.note` at the first audible position. Large accent dot,
///   non-tappable, VoiceOver-focusable as "Anchor note, not selectable".
/// - **Pickable** — `.note` whose audible position is in
///   ``TimingOffsetDetectionPattern/pickable``. Tappable; the doubled-glyph
///   indicator overlays the selected cell.
/// - **Rest** — `.rest` (and `.nested`, defensively). Empty cell of preserved
///   width, not focusable.
///
/// Uses ``TimingDotView`` size constants and the shared
/// ``TimingDotView/doubledGlyph(diameter:overlapOffset:)`` primitive so the
/// slot vocabulary stays in lockstep with the training-screen indicator and
/// the pattern preview.
struct TimingOffsetDetectionOffsetNotePositionSettingsSection: View {
    @AppStorage(TimingOffsetDetectionSettingsKeys.offsetNotePosition)
    private var offsetNotePosition: Int = OffsetNotePosition.default.rawValue

    @AppStorage(TimingOffsetDetectionSettingsKeys.selectedPatternId)
    private var selectedPatternId: String = TimingOffsetDetectionPatternCatalog.defaultPatternId

    @ScaledMetric(relativeTo: .caption2) private var cellSize: CGFloat = 32

    private var activePattern: TimingOffsetDetectionPattern {
        TimingOffsetDetectionPatternCatalog.pattern(forStoredId: selectedPatternId)
    }

    private var effectivePosition: OffsetNotePosition {
        activePattern.clampedOffsetNotePosition(offsetNotePosition)
    }

    var body: some View {
        let pattern = activePattern
        let selected = effectivePosition
        Section {
            HStack(spacing: 4) {
                ForEach(pattern.subdivisions.indices, id: \.self) { gridIndex in
                    cell(at: gridIndex, in: pattern, selected: selected)
                }
            }
        } header: {
            Text(String(localized: "Offset Note Position"))
        } footer: {
            Text(String(localized: "Pick which note carries the timing offset."))
        }
    }

    @ViewBuilder
    private func cell(
        at gridIndex: Int,
        in pattern: TimingOffsetDetectionPattern,
        selected: OffsetNotePosition
    ) -> some View {
        switch Self.cellKind(for: pattern, gridIndex: gridIndex) {
        case .anchor:
            anchorCell
        case .pickable(let position):
            pickableCell(position: position, isSelected: position == selected, audibleCount: pattern.audibleCount)
        case .rest:
            restCell
        }
    }

    private var anchorCell: some View {
        Circle()
            .fill(.primary)
            .frame(width: TimingDotView.beatOneDotDiameter, height: TimingDotView.beatOneDotDiameter)
            .frame(width: cellSize, height: cellSize)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "Anchor note, not selectable"))
            .accessibilityAddTraits(.isStaticText)
    }

    private func pickableCell(
        position: OffsetNotePosition,
        isSelected: Bool,
        audibleCount: Int
    ) -> some View {
        Button {
            offsetNotePosition = position.rawValue
        } label: {
            glyph(isSelected: isSelected)
                .frame(width: cellSize, height: cellSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .platformHoverEffect()
        .accessibilityLabel(Self.pickableCellLabel(
            position: position,
            audibleCount: audibleCount
        ))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private func glyph(isSelected: Bool) -> some View {
        if isSelected {
            TimingDotView.doubledGlyph(
                diameter: TimingDotView.dotDiameter,
                overlapOffset: TimingDotView.overlapOffset
            )
        } else {
            Circle()
                .fill(.primary)
                .frame(width: TimingDotView.dotDiameter, height: TimingDotView.dotDiameter)
        }
    }

    private var restCell: some View {
        Color.clear
            .frame(width: cellSize, height: cellSize)
            .accessibilityHidden(true)
    }

    // MARK: - Logic (static for testability)

    enum CellKind: Equatable {
        case anchor
        case pickable(OffsetNotePosition)
        case rest
    }

    /// Classifies a single grid cell. The audible position for a `.note` cell
    /// is derived from `pattern.audibleToGrid` via `firstIndex(of:)` — the
    /// inverse of the audible → grid map.
    static func cellKind(
        for pattern: TimingOffsetDetectionPattern,
        gridIndex: Int
    ) -> CellKind {
        switch pattern.subdivisions[gridIndex] {
        case .rest, .nested:
            return .rest
        case .note:
            guard let audibleZeroBased = pattern.audibleToGrid.firstIndex(of: gridIndex) else {
                return .rest
            }
            let audiblePosition = audibleZeroBased + 1
            return pattern.pickable.contains(audiblePosition)
                ? .pickable(OffsetNotePosition(audiblePosition))
                : .anchor
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
