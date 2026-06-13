import SwiftUI

/// Dots-on-baseline visualization for the Chromatic Construction discipline
/// (iteration 4 — per-slider *audible* offsets replace visual Y jitter).
///
/// **Walking mode.** Anchors are rendered as filled rounded squares at the
/// two endpoints of the contour (their Y positions communicate ascending vs
/// descending — the only authorised shape leak). A faint horizontal hairline
/// marks the *lower anchor's Y* — the baseline. Pending interior positions
/// sit on the baseline as a straight row; the user-facing affordance reads
/// "these positions are waiting" without leaking target Y per column.
///
/// **The audible-offset trick.** The trial carries a per-position
/// `audibleOffsets: [Cents]` (each in `[-50, +50]¢`, random per trial). The
/// audio during a drag of position `k` plays at `drag_cents +
/// audibleOffsets[k - 1]`, and the cents committed via `place(offset:)` is
/// the same value (i.e. what the user *heard*). The walking-view's placed
/// dot for position `k` renders at `(committed - audibleOffsets[k - 1])`,
/// i.e. the drag Y the user *saw* — so two columns with the same committed
/// audio land at different visual Ys. Visual cent triangulation across
/// columns fails; ear adjustment lands the user on the right cent.
///
/// **Gesture model.** A single `DragGesture(minimumDistance: 0)` is attached
/// to the whole contour. The first `onChanged` callback dispatches to the
/// nearest interior thumb within `hitRadius`, reverts the session to that
/// index, and starts a drag (which the screen turns into a continuous tone
/// via `session.startContinuousTone(at:)`). Subsequent callbacks update the
/// drag value via a fixed `centsPerDragPoint` mapping (3.3 ¢/pt). Per-dot
/// `.position()` would inflate each dot's hit area to the full frame, so
/// dot views use `.offset()` instead.
struct ChromaticContourView: View {
    let path: ChromaticPath
    let placedOffsets: [Cents]
    /// Per-interior-position audible offset (in cents), pulled from the
    /// trial. Used both as an audio offset during drag *and* to derive the
    /// walking-view's placed-dot Y from the committed value.
    let audibleOffsets: [Cents]
    /// 1-based interior-position index; `nil` when the trial is idle or
    /// showing its result.
    let activePositionIndex: Int?
    /// Initial slider value when this position re-activates from a prior
    /// placement (the trial's `active.preservedValue?.offset`). `nil` if the
    /// active position is being entered for the first time.
    let preservedValueForActive: Cents?
    let isShowingResult: Bool
    let onRevertTo: (Int) -> Void
    /// Fires once at touch-down (after `onRevertTo`). The screen opens the
    /// continuous tone in response. Carries the *audible* cents the audio
    /// will start at (drag + offset).
    let onDragStarted: (Cents) -> Void
    /// Fires on every drag tick after the first. The screen re-pitches the
    /// continuous tone via `session.adjustContinuousTone(to:)`. Carries the
    /// *audible* cents (drag + offset).
    let onDragChanged: (Cents) -> Void
    /// Carries the *audible* cents (drag + offset) — this is what the user
    /// heard, so this is what gets committed via `place(offset:)`.
    let onCommit: (Cents) -> Void
    let onResultTap: (Int) -> Void

    /// Half-range of the active-position drag slider, in cents. ±300 ¢
    /// covers three semitones in either direction. The slider clamps the
    /// drag value to this range around the previous committed pitch.
    static let sliderRangeCents = Cents(300.0)

    /// Visual length of the active pill, in points.
    static let sliderTrackHeight: CGFloat = 180

    /// Drag mapping: how many cents one point of finger motion translates
    /// to. `600 / sliderTrackHeight` keeps `±300 ¢` of cents tied to half
    /// the pill's length.
    static let centsPerDragPoint: Double = 600.0 / 180.0

    /// Distance from each edge of the contour view to the drawable rect
    /// where dots are placed.
    static let drawableInsetVertical: CGFloat = 50

    static let dotDiameter: CGFloat = 16
    static let mostRecentDotDiameter: CGFloat = 22
    static let activeDotDiameter: CGFloat = 22
    static let pendingDotDiameter: CGFloat = 12
    static let anchorSize: CGFloat = 22
    static let pillWidth: CGFloat = 8

    /// Hit radius for dispatching the drag's first touch-down to a thumb.
    static let hitRadius: CGFloat = 28

    @State private var dragState: DragState?

    private struct DragState {
        let positionIndex: Int
        let priorCommittedCents: Cents
        let audibleOffset: Cents
        /// Drag cents at touch-down, used as the anchor for delta math —
        /// `DragGesture.value.translation` is total movement from
        /// touch-down, so the current drag cents is `startingDragCents +
        /// translationCents`. Without this anchor the first tick after
        /// touch-down jumps to `priorCommittedCents`, audibly snapping the
        /// continuous tone before the user has actually moved.
        let startingDragCents: Cents
        /// Drag cents (visual Y) at the current frame. Audible cents =
        /// `dragCents + audibleOffset`.
        var dragCents: Cents
    }

    var body: some View {
        GeometryReader { geo in
            let drawable = Self.drawableRect(in: geo.size)
            ZStack(alignment: .topLeading) {
                baselineLine(in: drawable)
                anchorMarkers(in: drawable)
                pendingThumbs(in: drawable)
                placedDots(in: drawable)
                activeThumbAndPill(in: drawable)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(containerGesture(drawable: drawable))
        }
        .frame(height: 320)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Layers

    private func baselineLine(in drawable: CGRect) -> some View {
        let baselinePoint = Self.renderedPoint(forStepIndex: 0, cents: Cents(0), path: path, in: drawable)
        return Path { p in
            p.move(to: CGPoint(x: drawable.minX, y: baselinePoint.y))
            p.addLine(to: CGPoint(x: drawable.maxX, y: baselinePoint.y))
        }
        .stroke(.tertiary.opacity(0.5), style: StrokeStyle(lineWidth: 0.5))
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func anchorMarkers(in drawable: CGRect) -> some View {
        let lower = Self.renderedPoint(forStepIndex: 0, cents: Cents(0), path: path, in: drawable)
        let upper = Self.renderedPoint(forStepIndex: path.interiorPositionCount + 1, cents: Self.outerCents(path), path: path, in: drawable)
        anchorDot(at: lower, label: String(localized: "Lower anchor"))
        anchorDot(at: upper, label: String(localized: "Upper anchor"))
    }

    private func anchorDot(at point: CGPoint, label: String) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(.primary)
            .frame(width: Self.anchorSize, height: Self.anchorSize)
            .offset(x: point.x - Self.anchorSize / 2, y: point.y - Self.anchorSize / 2)
            .accessibilityLabel(label)
    }

    @ViewBuilder
    private func pendingThumbs(in drawable: CGRect) -> some View {
        if let activeIndex = activePositionIndex, !isShowingResult {
            ForEach(activeIndex...path.interiorPositionCount, id: \.self) { positionIndex in
                // During an active drag, the dot for the position being
                // dragged is drawn by `activeThumbAndPill` instead.
                if positionIndex != dragState?.positionIndex {
                    // Pending positions sit in a clean horizontal row on the
                    // baseline — visual Y carries no per-column information.
                    let point = Self.renderedPoint(forStepIndex: positionIndex, cents: Cents(0), path: path, in: drawable)
                    pendingDot(at: point, positionIndex: positionIndex)
                }
            }
        }
    }

    private func pendingDot(at point: CGPoint, positionIndex: Int) -> some View {
        Circle()
            .fill(.secondary)
            .frame(width: Self.pendingDotDiameter, height: Self.pendingDotDiameter)
            .offset(x: point.x - Self.pendingDotDiameter / 2, y: point.y - Self.pendingDotDiameter / 2)
            .accessibilityLabel(String(localized: "Pending position \(positionIndex)"))
    }

    @ViewBuilder
    private func placedDots(in drawable: CGRect) -> some View {
        let placedCount = placedOffsets.count
        ForEach(placedOffsets.indices, id: \.self) { index in
            let positionIndex = index + 1
            if positionIndex != dragState?.positionIndex {
                // Walking-view: render at the drag value the user saw
                // (= committed − offset). Result-view: render at the
                // committed (audible) value — the user-facing truth.
                let committed = placedOffsets[index]
                let visualCents: Cents = isShowingResult
                    ? committed
                    : committed - audibleOffset(for: positionIndex)
                let point = Self.renderedPoint(forStepIndex: positionIndex, cents: visualCents, path: path, in: drawable)
                let diameter = positionIndex == placedCount ? Self.mostRecentDotDiameter : Self.dotDiameter
                placedDot(at: point, diameter: diameter, positionIndex: positionIndex)
            }
        }
    }

    private func placedDot(at point: CGPoint, diameter: CGFloat, positionIndex: Int) -> some View {
        Circle()
            .fill(.tint)
            .frame(width: diameter, height: diameter)
            .offset(x: point.x - diameter / 2, y: point.y - diameter / 2)
            .accessibilityLabel(String(localized: "Placed position \(positionIndex)"))
    }

    @ViewBuilder
    private func activeThumbAndPill(in drawable: CGRect) -> some View {
        if let drag = dragState {
            // Active thumb tracks the drag cents (the user's finger Y),
            // *not* the audible cents — so the pill rides exactly with
            // the finger and the visual response is direct.
            let point = Self.renderedPoint(forStepIndex: drag.positionIndex, cents: drag.dragCents, path: path, in: drawable)
            Capsule()
                .fill(.tint.opacity(0.18))
                .frame(width: Self.pillWidth, height: Self.sliderTrackHeight)
                .offset(x: point.x - Self.pillWidth / 2, y: point.y - Self.sliderTrackHeight / 2)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            Circle()
                .fill(.tint)
                .frame(width: Self.activeDotDiameter, height: Self.activeDotDiameter)
                .offset(x: point.x - Self.activeDotDiameter / 2, y: point.y - Self.activeDotDiameter / 2)
                .allowsHitTesting(false)
                .accessibilityLabel(String(localized: "Active position \(drag.positionIndex)"))
        }
    }

    // MARK: - Gesture

    private func containerGesture(drawable: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in handleDragChange(value: value, drawable: drawable) }
            .onEnded { _ in handleRelease() }
    }

    private func handleDragChange(value: DragGesture.Value, drawable: CGRect) {
        if isShowingResult { return }
        if let drag = dragState {
            // `value.translation` is cumulative from touch-down; anchor the
            // delta on `startingDragCents` so the very first tick (when
            // translation ≈ 0) leaves dragCents at touch-down's value
            // instead of jumping to `priorCommittedCents`.
            let translationCents = Cents(-Double(value.translation.height) * Self.centsPerDragPoint)
            let raw = drag.startingDragCents + translationCents
            let clampedDrag = Self.clamp(raw, around: drag.priorCommittedCents)
            dragState?.dragCents = clampedDrag
            onDragChanged(clampedDrag + drag.audibleOffset)
        } else {
            guard let activeIndex = activePositionIndex else { return }
            guard let touchedIndex = nearestInteriorIndex(to: value.location, activeIndex: activeIndex, drawable: drawable) else { return }
            // Touch-down value chosen so the audio = priorCommitted (the
            // prior step's audible pitch). That matches the musical
            // expectation "this slider continues from where the previous
            // step ended", and lets the user hear a clear difference
            // between slider 1, slider 2, slider 3, … at touch. The drag
            // cents at touch is `priorCommitted − offset[k]`, because
            // audio = drag + offset[k] and we want audio = priorCommitted.
            //
            // For a placed dot we recover the *original* drag value the
            // user saw (`committed − offset`). For the active position
            // returning from a step-back (preserved value set), we recover
            // the drag value from the preserved committed value.
            let prior = priorCommittedCents(forPositionIndex: touchedIndex)
            let offset = audibleOffset(for: touchedIndex)
            let touchedDragCents: Cents
            if touchedIndex <= placedOffsets.count {
                let committed = placedOffsets[touchedIndex - 1]
                touchedDragCents = committed - offset
            } else if let preserved = preservedValueForActive {
                touchedDragCents = preserved - offset
            } else {
                // Fresh pending visit — start at the prior step's audible
                // pitch (= priorCommitted in audible cents, = prior − offset
                // in drag cents).
                touchedDragCents = prior - offset
            }
            let clampedDrag = Self.clamp(touchedDragCents, around: prior)
            dragState = DragState(
                positionIndex: touchedIndex,
                priorCommittedCents: prior,
                audibleOffset: offset,
                startingDragCents: clampedDrag,
                dragCents: clampedDrag
            )
            onDragStarted(clampedDrag + offset)
        }
    }

    private func handleRelease() {
        if isShowingResult, let activeIndex = activePositionIndex {
            onResultTap(activeIndex)
            return
        }
        if let drag = dragState {
            onCommit(drag.dragCents + drag.audibleOffset)
            dragState = nil
        }
    }

    private func nearestInteriorIndex(to location: CGPoint, activeIndex: Int, drawable: CGRect) -> Int? {
        var best: (index: Int, distSq: CGFloat)?
        for k in 1...activeIndex {
            // Use the dot's *visual* Y so the hit test matches what the
            // user saw: pending positions on the baseline, placed dots at
            // (committed − offset).
            let visualCents: Cents
            if k <= placedOffsets.count {
                visualCents = placedOffsets[k - 1] - audibleOffset(for: k)
            } else {
                visualCents = Cents(0)
            }
            let point = Self.renderedPoint(forStepIndex: k, cents: visualCents, path: path, in: drawable)
            let dx = location.x - point.x
            let dy = location.y - point.y
            let distSq = dx * dx + dy * dy
            if best == nil || distSq < best!.distSq {
                best = (k, distSq)
            }
        }
        guard let best, best.distSq <= Self.hitRadius * Self.hitRadius else { return nil }
        return best.index
    }

    // MARK: - Helpers

    private func audibleOffset(for positionIndex: Int) -> Cents {
        guard positionIndex >= 1, positionIndex <= audibleOffsets.count else { return Cents(0) }
        return audibleOffsets[positionIndex - 1]
    }

    private func priorCommittedCents(forPositionIndex k: Int) -> Cents {
        let priorIndex = k - 1
        if priorIndex >= 1, priorIndex <= placedOffsets.count {
            return placedOffsets[priorIndex - 1]
        }
        return Cents(0)
    }

    // MARK: - Static layout helpers (testable)

    static func drawableRect(in size: CGSize) -> CGRect {
        CGRect(
            x: 0,
            y: drawableInsetVertical,
            width: size.width,
            height: max(0, size.height - drawableInsetVertical * 2)
        )
    }

    static func outerCents(_ path: ChromaticPath) -> Cents {
        path.targetOffsetCents(at: path.interiorPositionCount + 1)
    }

    static func renderedPoint(
        forStepIndex stepIndex: Int,
        cents: Cents,
        path: ChromaticPath,
        in drawable: CGRect
    ) -> CGPoint {
        let n = path.interiorPositionCount
        let xNorm = Double(stepIndex) / Double(n + 1)
        let x = drawable.minX + xNorm * drawable.width
        let outer = outerCents(path).rawValue
        guard outer != 0 else {
            return CGPoint(x: x, y: drawable.midY)
        }
        let yMin = min(0.0, outer)
        let yMax = max(0.0, outer)
        let yNorm = (cents.rawValue - yMin) / (yMax - yMin)
        // Y axis flipped so higher cents render upward.
        return CGPoint(x: x, y: drawable.minY + (1 - yNorm) * drawable.height)
    }

    static func clamp(_ cents: Cents, around prior: Cents) -> Cents {
        let lower = prior - sliderRangeCents
        let upper = prior + sliderRangeCents
        return Cents(min(max(cents.rawValue, lower.rawValue), upper.rawValue))
    }
}
