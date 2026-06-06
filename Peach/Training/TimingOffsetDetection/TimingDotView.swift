import SwiftUI

/// Proportional-timeline dot row for the active ``TimingOffsetDetectionPattern``.
///
/// Replaces Epic 82's equal-cell ``HStack`` renderer with a proportional layout
/// per `docs/planning-artifacts/tod-tuplet-renderer-design.md` § *Cell-width math*:
/// each visual cell's width reflects its share of the beat after the depth-first
/// walk of the `Beat` tree. Immediately-following `.rest` subdivisions are
/// absorbed into the preceding `.note`'s visual cell; orphan rests emit their
/// own non-focusable cell; nested figures get a thin bracket overlay.
///
/// The doubled-glyph offset indicator overlays the visual cell whose
/// `audiblePosition` matches the user-facing ``OffsetNotePosition``. Pass
/// `offsetNotePosition: nil` (e.g. for the pattern-picker preview) to suppress
/// the doubled-glyph indicator; pass `scale: previewScale` to render the
/// preview-sized variant of the same vocabulary.
struct TimingDotView: View {
    let pattern: TimingOffsetDetectionPattern
    /// Pass `nil` when no offset should be drawn (picker preview shows pattern
    /// identity, not offset choice).
    let offsetNotePosition: OffsetNotePosition?
    let litCount: Int

    /// Multiplier applied to all four size constants. Defaults to `1.0`
    /// (training-screen vocabulary); ``previewScale`` produces the smaller
    /// pattern-picker preview. One knob means the four dimensions can never
    /// drift out of proportion.
    var scale: CGFloat = 1.0

    @ScaledMetric(relativeTo: .caption2) private var bracketThickness: CGFloat = Self.bracketThicknessBase
    @ScaledMetric(relativeTo: .caption2) private var bracketOffsetAbove: CGFloat = Self.bracketOffsetAboveBase
    @ScaledMetric(relativeTo: .caption2) private var bracketEndInset: CGFloat = Self.bracketEndInsetBase

    var body: some View {
        let cells = Self.visualCells(for: pattern)
        let highlightedAudible = offsetNotePosition.flatMap { Self.audiblePositionToHighlight(for: pattern, offsetNotePosition: $0) }
        let hasBracket = cells.contains { if case .nestingBracket = $0.kind { return true } else { return false } }
        let contentHeight = Self.beatOneDotDiameter * scale
        let bracketReserve = hasBracket
            ? Self.bracketReserve(offsetAbove: bracketOffsetAbove, thickness: bracketThickness, scale: scale)
            : 0

        GeometryReader { proxy in
            let containerWidth = proxy.size.width
            ZStack(alignment: .topLeading) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    cellView(cell, containerWidth: containerWidth, contentHeight: contentHeight, bracketReserve: bracketReserve, highlightedAudible: highlightedAudible)
                }
            }
        }
        .frame(height: bracketReserve + contentHeight)
    }

    @ViewBuilder
    private func cellView(
        _ cell: VisualCell,
        containerWidth: CGFloat,
        contentHeight: CGFloat,
        bracketReserve: CGFloat,
        highlightedAudible: Int?
    ) -> some View {
        let cellWidth = cell.widthProportion * containerWidth
        let cellLeftX = cell.startXProportion * containerWidth
        let scaledDot = Self.dotDiameter * scale
        let scaledBeatOne = Self.beatOneDotDiameter * scale
        let scaledOverlap = Self.overlapOffset * scale

        switch cell.kind {
        case .accent:
            let isHighlighted = (highlightedAudible == 1)
            audibleDot(
                size: scaledBeatOne,
                cellWidth: cellWidth,
                contentHeight: contentHeight,
                cellLeftX: cellLeftX,
                topInset: bracketReserve,
                opacity: opacity(forAudiblePosition: 1),
                isHighlighted: isHighlighted,
                normalDot: scaledDot,
                overlapOffset: scaledOverlap
            )
            .accessibilityLabel(Self.cellAccessibilityLabel(for: cell, in: pattern))

        case .normalAudible(let audiblePosition):
            let isHighlighted = (highlightedAudible == audiblePosition)
            audibleDot(
                size: scaledDot,
                cellWidth: cellWidth,
                contentHeight: contentHeight,
                cellLeftX: cellLeftX,
                topInset: bracketReserve,
                opacity: opacity(forAudiblePosition: audiblePosition),
                isHighlighted: isHighlighted,
                normalDot: scaledDot,
                overlapOffset: scaledOverlap
            )
            .accessibilityLabel(Self.cellAccessibilityLabel(for: cell, in: pattern))

        case .orphanRest:
            Color.clear
                .frame(width: cellWidth, height: contentHeight)
                .offset(x: cellLeftX, y: bracketReserve)
                .accessibilityHidden(true)

        case .nestingBracket:
            let strokeWidth = bracketThickness * scale
            let inset = bracketEndInset * scale
            let visibleWidth = max(cellWidth - 2 * inset, 0)
            Rectangle()
                .fill(.primary)
                .opacity(0.5)
                .frame(width: visibleWidth, height: strokeWidth)
                .offset(x: cellLeftX + inset, y: 0)
                .accessibilityHidden(true)
        }
    }

    private func opacity(forAudiblePosition audiblePosition: Int) -> Double {
        Self.isAudibleLit(audiblePosition: audiblePosition, in: pattern, litCount: litCount) ? 1.0 : 0.2
    }

    /// An audible is "lit" when its top-level grid index has been reached by the
    /// session's grid-based ``TimingOffsetDetectionSession/litDotCount`` counter
    /// (which advances per top-level subdivision tick). Nested-child audibles
    /// share their top-level parent's lit state — the engine publishes lit
    /// progression at the top-level granularity only.
    static func isAudibleLit(
        audiblePosition: Int,
        in pattern: TimingOffsetDetectionPattern,
        litCount: Int
    ) -> Bool {
        let zeroBased = audiblePosition - 1
        guard zeroBased >= 0, zeroBased < pattern.audibleToGrid.count else { return false }
        guard let topIndex = pattern.audibleToGrid[zeroBased].first else { return false }
        return topIndex < litCount
    }

    @ViewBuilder
    private func audibleDot(
        size: CGFloat,
        cellWidth: CGFloat,
        contentHeight: CGFloat,
        cellLeftX: CGFloat,
        topInset: CGFloat,
        opacity: Double,
        isHighlighted: Bool,
        normalDot: CGFloat,
        overlapOffset: CGFloat
    ) -> some View {
        // Dots are leading-aligned within their cell: the note's onset sits at
        // the cell's left edge, with absorbed-rest space extending to the right.
        // Center-alignment would shift the dot rightward as its cell absorbed
        // rests, distorting the rhythm-as-spacing intent — pattern_gapped16ths_04's accent
        // would land at 3W/8 instead of 0, hiding the 3:1 gap.
        //
        // The doubled-glyph offset marker is shifted left by `overlapOffset/2`
        // so its visual center sits at the same x as a single dot's center
        // (cellLeftX + dotDiameter/2). Without the shift, the glyph's first
        // circle would align with the single dot but its visual mass would
        // skew right, making the offset note appear displaced from the audible
        // it represents.
        Group {
            if isHighlighted {
                Self.doubledGlyph(diameter: normalDot, overlapOffset: overlapOffset)
                    .opacity(opacity)
                    .offset(x: -overlapOffset / 2)
            } else {
                Circle()
                    .fill(.primary)
                    .frame(width: size, height: size)
                    .opacity(opacity)
            }
        }
        .frame(width: cellWidth, height: contentHeight, alignment: .leading)
        .offset(x: cellLeftX, y: topInset)
    }

    // MARK: - Layout Parameters (extracted for testability)

    static let dotDiameter: CGFloat = 16
    static let beatOneDotDiameter: CGFloat = 22
    static let dotSpacing: CGFloat = 24
    static let overlapOffset: CGFloat = 8
    static let testedNoteFrameWidth: CGFloat = dotDiameter + overlapOffset

    static let bracketThicknessBase: CGFloat = 1.5
    static let bracketOffsetAboveBase: CGFloat = 4
    static let bracketEndInsetBase: CGFloat = 1

    /// Vertical space the nesting bracket occupies above the content cells:
    /// `(offsetAbove + thickness) * scale`. Extracted as a static so a unit
    /// test can pin the `* scale` step at the bracket-reserve site — the
    /// renderer's `scale` parameter is the only knob that aligns the picker
    /// preview at `previewScale` with the training-screen layout at full scale.
    static func bracketReserve(offsetAbove: CGFloat, thickness: CGFloat, scale: CGFloat) -> CGFloat {
        (offsetAbove + thickness) * scale
    }

    /// Scale used by the pattern-picker preview. Centralized here so every
    /// small-preview surface stays in lockstep with the training-screen
    /// vocabulary (`tod-initial-pattern-catalog.md` § *Preview Rendering*).
    static let previewScale: CGFloat = 0.625

    static func diameter(
        forStepIndex index: Int,
        beatOne: CGFloat = beatOneDotDiameter,
        normal: CGFloat = dotDiameter
    ) -> CGFloat {
        index == 0 ? beatOne : normal
    }

    /// Story 85.7 / PF-046: base width applied via `.frame(maxWidth:)` to both
    /// the *Pattern* row's dot preview and the *Offset Note Position* row's
    /// slot picker in `SettingsScreen`. Sourced from a single constant so the
    /// two flexible dot containers can never drift; each section view wraps
    /// this base in `@ScaledMetric(relativeTo: .caption2)` so the width grows
    /// with Dynamic Type symmetrically across both rows. Replaces the
    /// pre-85.7 mechanism that mirrored an intrinsic-width chevron on both
    /// rows to deliver identical residual widths — the chevron-mirroring trick
    /// retires entirely. 220pt fits within iPhone SE Form row inner widths
    /// after the system NavigationLink chevron and gives a 6-cell sextuplet at
    /// `previewScale` (0.625) enough breathing room to render without
    /// dot crowding.
    static let settingsRowDotsBaseWidth: CGFloat = 220

    /// Doubled-glyph indicator: two overlapping `Circle`s used by both the
    /// training-screen offset marker and the slot-picker selected-cell marker.
    /// Sized by the caller so the same primitive serves every surface (full
    /// scale, picker preview, slot picker) without copy-paste.
    static func doubledGlyph(diameter: CGFloat, overlapOffset: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(.primary)
                .frame(width: diameter, height: diameter)
                .offset(x: -overlapOffset / 2)
            Circle()
                .fill(.primary)
                .frame(width: diameter, height: diameter)
                .offset(x: overlapOffset / 2)
        }
        .frame(width: diameter + overlapOffset, height: diameter)
    }

}

// MARK: - Visual cells

extension TimingDotView {
    struct VisualCell: Equatable {
        var startXProportion: CGFloat
        var widthProportion: CGFloat
        var kind: VisualCellKind
    }

    enum VisualCellKind: Equatable {
        case accent
        case normalAudible(audiblePosition: Int)
        case orphanRest
        case nestingBracket(childDivision: ChildDivision)
    }

    enum ChildDivision: Equatable {
        case triplet
        case duplet
        case sextuplet

        /// Returns the named child division for the canonical Epic-84 host
        /// counts (2 → duplet, 3 → triplet, 6 → sextuplet). Other K values are
        /// unsupported in the Epic-84 catalog; callers receive `nil` rather
        /// than a silently-wrong descriptor.
        static func inferred(forSubdivisionCount count: Int) -> ChildDivision? {
            switch count {
            case 2: return .duplet
            case 3: return .triplet
            case 6: return .sextuplet
            default: return nil
            }
        }
    }

    /// Depth-first walk of the pattern's `Beat` tree producing typed visual
    /// cells per `tod-tuplet-renderer-design.md` § *Cell-width math*. Content
    /// cells (`accent`, `normalAudible`, `orphanRest`) appear in display order;
    /// `nestingBracket` cells are appended after all content cells so the
    /// renderer can iterate cells linearly while treating brackets as
    /// overlays.
    ///
    /// Epic 84 caps nesting depth at 1; every shipped pattern's smallest
    /// cell stays well above the dot diameter on every target form factor.
    /// A future multi-beat or depth-3 epic where the smallest cell can
    /// reach ≈ 1/36 of a beat (sextuplet-inside-duplet-inside-triplet)
    /// would compress below the dot diameter — that epic must either cap
    /// the renderer's effective scale on deep nests or render an
    /// alternate summary representation. Documented per PF-033 WONT-FIX
    /// in `docs/implementation-artifacts/deferred-work.md`.
    static func visualCells(for pattern: TimingOffsetDetectionPattern) -> [VisualCell] {
        var content: [VisualCell] = []
        var brackets: [VisualCell] = []
        var audibleCounter = 1
        walk(
            subdivisions: pattern.subdivisions,
            startX: 0,
            allocatedWidth: 1,
            content: &content,
            brackets: &brackets,
            audibleCounter: &audibleCounter
        )
        return content + brackets
    }

    private static func walk(
        subdivisions: [Subdivision],
        startX: CGFloat,
        allocatedWidth: CGFloat,
        content: inout [VisualCell],
        brackets: inout [VisualCell],
        audibleCounter: inout Int
    ) {
        let count = subdivisions.count
        guard count > 0 else { return }
        let perCell = allocatedWidth / CGFloat(count)
        var inFlightContentIndex: Int? = nil

        for (index, subdivision) in subdivisions.enumerated() {
            let leafStartX = startX + CGFloat(index) * perCell
            switch subdivision {
            case .note:
                let kind: VisualCellKind = (audibleCounter == 1)
                    ? .accent
                    : .normalAudible(audiblePosition: audibleCounter)
                content.append(VisualCell(
                    startXProportion: leafStartX,
                    widthProportion: perCell,
                    kind: kind
                ))
                inFlightContentIndex = content.count - 1
                audibleCounter += 1

            case .rest:
                if let idx = inFlightContentIndex {
                    content[idx].widthProportion += perCell
                } else {
                    content.append(VisualCell(
                        startXProportion: leafStartX,
                        widthProportion: perCell,
                        kind: .orphanRest
                    ))
                    inFlightContentIndex = content.count - 1
                }

            case .nested(let child):
                inFlightContentIndex = nil
                let bracketStartContentIndex = content.count
                walk(
                    subdivisions: child.subdivisions,
                    startX: leafStartX,
                    allocatedWidth: perCell,
                    content: &content,
                    brackets: &brackets,
                    audibleCounter: &audibleCounter
                )
                if bracketStartContentIndex < content.count,
                   let childDivision = ChildDivision.inferred(forSubdivisionCount: child.subdivisions.count) {
                    let firstCell = content[bracketStartContentIndex]
                    let lastCell = content[content.count - 1]
                    let spanStart = firstCell.startXProportion
                    let spanEnd = lastCell.startXProportion + lastCell.widthProportion
                    brackets.append(VisualCell(
                        startXProportion: spanStart,
                        widthProportion: spanEnd - spanStart,
                        kind: .nestingBracket(childDivision: childDivision)
                    ))
                }
            }
        }
    }

    /// Translates the user-facing ``OffsetNotePosition`` into the audible
    /// position number used to match against a ``VisualCell``'s
    /// `.normalAudible(audiblePosition:)` kind. Returns `nil` when no offset
    /// should be drawn (picker preview), the position is out-of-range for the
    /// pattern, or the position is the metric anchor (audible 1) — the anchor
    /// is never pickable, so the doubled-glyph marker must never overlay it.
    static func audiblePositionToHighlight(
        for pattern: TimingOffsetDetectionPattern,
        offsetNotePosition: OffsetNotePosition
    ) -> Int? {
        let raw = offsetNotePosition.rawValue
        guard pattern.pickable.contains(raw) else { return nil }
        return raw
    }
}

// MARK: - Per-cell accessibility labels

extension TimingDotView {
    /// VoiceOver label for a single visual cell. Implements the locked form in
    /// `tod-tuplet-renderer-design.md` § *Per-cell accessibility labels*.
    /// Branches for nested-context ("in triplet" / "in duplet"), the
    /// leading-nest accent ("Accent, in triplet"), and the mixed-duration
    /// "dotted" descriptor are present for forward-compat; only the flat-pattern
    /// subset is exercised by the five Epic-82 entries this story renders.
    static func cellAccessibilityLabel(
        for cell: VisualCell,
        in pattern: TimingOffsetDetectionPattern
    ) -> String {
        switch cell.kind {
        case .accent:
            if let division = childDivision(forAudiblePosition: 1, in: pattern) {
                return composedAccent(in: division)
            }
            return String(localized: "Accent")
        case .normalAudible(let audiblePosition):
            // Dotted-vs-nested precedence: today the dotted branch wins and the
            // nested-context descriptor is silently dropped. No Epic-84 entry
            // exercises a position with both flags true (a nested mixed-duration
            // figure), so the question is latent. The first such catalog entry
            // must pick one of (a) combine descriptors ("Note N of K, dotted, in
            // triplet"), (b) define an explicit precedence in `tod-tuplet-renderer-design.md`,
            // or (c) make the flags mutually exclusive at the catalog boundary
            // via `TimingOffsetDetectionPattern.init` — consult Adam for the
            // user-facing label call. Documented per PF-035 WONT-FIX in
            // `docs/implementation-artifacts/deferred-work.md`.
            if pattern.dottedAudiblePositions.contains(audiblePosition) {
                return composedNote(
                    audiblePosition: audiblePosition,
                    audibleCount: pattern.audibleCount,
                    suffix: .dotted
                )
            }
            if let division = childDivision(forAudiblePosition: audiblePosition, in: pattern) {
                return composedNote(
                    audiblePosition: audiblePosition,
                    audibleCount: pattern.audibleCount,
                    suffix: .inNested(division)
                )
            }
            return composedNote(audiblePosition: audiblePosition, audibleCount: pattern.audibleCount, suffix: .none)
        case .orphanRest, .nestingBracket:
            return ""
        }
    }

    private enum AudibleLabelSuffix {
        case none
        case dotted
        case inNested(ChildDivision)
    }

    /// Returns the named child division of the top-level `.nested(_)` that
    /// contains the given audible.
    ///
    /// Epic 84 caps nesting depth at 1; every shipped pattern's audible lives
    /// in either no nested figure or exactly one. The depth-2 epic (whenever
    /// it lands) must walk `path` through deeper `.nested(child)` levels to
    /// find the actual containing `Beat` instead of stopping at the top — for
    /// an audible at `path = [1, 2, 0]` (inside
    /// `pattern.subdivisions[1].nested(_).subdivisions[2].nested(_)`),
    /// this implementation returns the K of `subdivisions[1].nested(_)`'s
    /// direct child rather than of the actually-containing child. Documented
    /// per PF-034 WONT-FIX in `docs/implementation-artifacts/deferred-work.md`.
    private static func childDivision(
        forAudiblePosition audiblePosition: Int,
        in pattern: TimingOffsetDetectionPattern
    ) -> ChildDivision? {
        let zeroBased = audiblePosition - 1
        guard zeroBased >= 0, zeroBased < pattern.audibleToGrid.count else { return nil }
        let path = pattern.audibleToGrid[zeroBased]
        guard path.count > 1, let topIndex = path.first else { return nil }
        guard topIndex < pattern.subdivisions.count else { return nil }
        guard case .nested(let child) = pattern.subdivisions[topIndex] else { return nil }
        return ChildDivision.inferred(forSubdivisionCount: child.subdivisions.count)
    }

    private static func composedAccent(in division: ChildDivision) -> String {
        let accent = String(localized: "Accent")
        let descriptor = nestedDivisionDescriptor(division)
        return "\(accent), \(descriptor)"
    }

    private static func composedNote(
        audiblePosition: Int,
        audibleCount: Int,
        suffix: AudibleLabelSuffix
    ) -> String {
        let note = String(localized: "Note \(audiblePosition) of \(audibleCount)")
        switch suffix {
        case .none:
            return note
        case .dotted:
            return "\(note), \(String(localized: "dotted"))"
        case .inNested(let division):
            return "\(note), \(nestedDivisionDescriptor(division))"
        }
    }

    private static func nestedDivisionDescriptor(_ division: ChildDivision) -> String {
        switch division {
        case .triplet: return String(localized: "in triplet")
        case .duplet: return String(localized: "in duplet")
        case .sextuplet: return String(localized: "in sextuplet")
        }
    }
}

// MARK: - Previews

#Preview("pattern_straight16ths_01 — no dots lit, position 3 selected") {
    TimingDotView(
        pattern: .pattern_straight16ths_01,
        offsetNotePosition: .default,
        litCount: 0
    )
    .padding()
}

#Preview("pattern_straight16ths_01 — 2 dots lit, position 3 selected") {
    TimingDotView(
        pattern: .pattern_straight16ths_01,
        offsetNotePosition: .default,
        litCount: 2
    )
    .padding()
}

#Preview("pattern_straight16ths_01 — all dots lit, position 4 selected") {
    TimingDotView(
        pattern: .pattern_straight16ths_01,
        offsetNotePosition: OffsetNotePosition(4),
        litCount: 4
    )
    .padding()
}

#Preview("pattern_straight16ths_01 — picker preview (no offset glyph)") {
    TimingDotView(
        pattern: .pattern_straight16ths_01,
        offsetNotePosition: nil,
        litCount: TimingOffsetDetectionPattern.pattern_straight16ths_01.subdivisions.count,
        scale: TimingDotView.previewScale
    )
    .padding()
}
