import SwiftUI

/// One row of dot glyphs for the active ``TimingOffsetDetectionPattern``.
///
/// Per grid index, dispatches on the underlying ``Subdivision``:
/// - `.note` at grid 0 → ``beatOneDotDiameter`` accent dot.
/// - `.note` elsewhere → ``dotDiameter`` normal dot.
/// - `.rest` (and `.nested`, defensively) → invisible spacer of normal-dot width
///   so the audible/silent pattern shape is scannable at a glance.
///
/// The doubled-glyph offset indicator overlays the cell whose *grid* index
/// equals the translation of the user-facing audible ``OffsetNotePosition``
/// through ``TimingOffsetDetectionPattern/audibleToGrid``. Pass
/// `offsetNotePosition: nil` (e.g. for the pattern-picker preview) to suppress
/// the doubled-glyph indicator entirely; pass `scale: previewScale` to render
/// the preview-sized variant of the same vocabulary.
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

    var body: some View {
        let offsetGrid = Self.offsetGridIndex(for: pattern, offsetNotePosition: offsetNotePosition)
        HStack(spacing: Self.dotSpacing * scale) {
            ForEach(pattern.subdivisions.indices, id: \.self) { index in
                cell(at: index, offsetGrid: offsetGrid)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func cell(at index: Int, offsetGrid: Int?) -> some View {
        let subdivision = pattern.subdivisions[index]
        let opacity = index < litCount ? 1.0 : 0.2
        let scaledDot = Self.dotDiameter * scale
        let scaledBeatOne = Self.beatOneDotDiameter * scale
        let scaledOverlap = Self.overlapOffset * scale

        switch subdivision {
        case .rest, .nested:
            Color.clear.frame(width: scaledDot, height: scaledBeatOne)
        case .note:
            let size = Self.diameter(forStepIndex: index, beatOne: scaledBeatOne, normal: scaledDot)
            if offsetGrid == index {
                Self.doubledGlyph(diameter: scaledDot, overlapOffset: scaledOverlap)
                    .opacity(opacity)
            } else {
                Circle()
                    .fill(.primary)
                    .frame(width: size, height: size)
                    .opacity(opacity)
            }
        }
    }

    // MARK: - Layout Parameters (extracted for testability)

    static let dotDiameter: CGFloat = 16
    static let beatOneDotDiameter: CGFloat = 22
    static let dotSpacing: CGFloat = 24
    static let overlapOffset: CGFloat = 8
    static let testedNoteFrameWidth: CGFloat = dotDiameter + overlapOffset

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

    /// Translates a 1-based audible ``OffsetNotePosition`` into the 0-based
    /// grid index that ``cell(at:offsetGrid:)`` compares against. Returns `nil`
    /// when the position is `nil` (picker preview) or out of range for the
    /// pattern. Closes the 82.5 deferred-work entry "`TimingDotView.testedNoteIndex`
    /// audible-vs-grid mismatch" — callers no longer translate by hand.
    static func offsetGridIndex(
        for pattern: TimingOffsetDetectionPattern,
        offsetNotePosition: OffsetNotePosition?
    ) -> Int? {
        guard let offsetNotePosition else { return nil }
        let audibleIndex = offsetNotePosition.zeroBasedIndex
        guard audibleIndex >= 0, audibleIndex < pattern.audibleToGrid.count else { return nil }
        return pattern.audibleToGrid[audibleIndex]
    }
}

// MARK: - Previews

#Preview("pattern_01 — no dots lit, position 3 selected") {
    TimingDotView(
        pattern: .pattern01,
        offsetNotePosition: .default,
        litCount: 0
    )
    .padding()
}

#Preview("pattern_01 — 2 dots lit, position 3 selected") {
    TimingDotView(
        pattern: .pattern01,
        offsetNotePosition: .default,
        litCount: 2
    )
    .padding()
}

#Preview("pattern_01 — all dots lit, position 4 selected") {
    TimingDotView(
        pattern: .pattern01,
        offsetNotePosition: OffsetNotePosition(4),
        litCount: 4
    )
    .padding()
}

#Preview("pattern_01 — picker preview (no offset glyph)") {
    TimingDotView(
        pattern: .pattern01,
        offsetNotePosition: nil,
        litCount: TimingOffsetDetectionPattern.pattern01.subdivisions.count,
        scale: TimingDotView.previewScale
    )
    .padding()
}
