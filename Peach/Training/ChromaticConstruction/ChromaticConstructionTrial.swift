import Foundation

/// In-progress chromatic-construction trial: the path the user is walking
/// plus the placements committed so far and the currently active position.
///
/// The user's per-position placement is captured as a `DetunedMIDINote`
/// (anchor identity + cent offset) — the logical-world type from
/// `Core/Music/`. State (pending / active / placed) is *not* a field on the
/// value; it is implicit in collection position: positions `1...placed.count`
/// are placed, position `active.index` is active, positions beyond are
/// pending.
struct ChromaticConstructionTrial: Hashable, Sendable {
    let path: ChromaticPath
    private(set) var placed: [DetunedMIDINote]
    private(set) var active: ActivePosition?

    /// Per-interior-position *audible* offset, fixed at trial init.
    ///
    /// During a drag of position `k`, the audio plays at
    /// `drag_cents + audibleOffsets[k - 1]`. The cents value committed via
    /// `place(offset:)` is the same `drag_cents + audibleOffsets[k - 1]`,
    /// i.e. the pitch the user heard. The walking-view's *visual* dot Y
    /// reflects the drag value (without the offset), so two columns with the
    /// same committed audio commit at different visual Y — visual
    /// triangulation across columns fails and the user is forced into
    /// ear-based adjustment. Result-view labels and tap-replay use the
    /// committed (audible) value directly, so the training data records what
    /// the user actually heard.
    let audibleOffsets: [Cents]

    init(path: ChromaticPath) {
        self.init(path: path, audibleOffsets: Self.randomAudibleOffsets(count: path.interiorPositionCount))
    }

    /// Designated initialiser; tests pass deterministic offsets via the
    /// `audibleOffsets:` argument. Production callers use `init(path:)`,
    /// which fills the array with random values in `Self.maxOffsetRange`.
    init(path: ChromaticPath, audibleOffsets: [Cents]) {
        precondition(audibleOffsets.count == path.interiorPositionCount,
                     "audibleOffsets must have one entry per interior position")
        self.path = path
        self.placed = []
        self.active = ActivePosition(index: 1, preservedValue: nil)
        self.audibleOffsets = audibleOffsets
    }

    /// The audible-offset range. `±50¢` chosen to push different sliders
    /// into pitches that audibly differ from their visual cent position —
    /// enough that the user can't rely on visual cent reading, but small
    /// enough that the drag-range clamp (`±300¢`) still gives generous
    /// adjustment headroom in either direction.
    static let maxOffsetRange: ClosedRange<Double> = -50.0...50.0

    private static func randomAudibleOffsets(count: Int) -> [Cents] {
        (0..<count).map { _ in Cents(Double.random(in: maxOffsetRange)) }
    }

    /// Commits the active position with the given cent offset from the lower
    /// anchor. If this was the final interior position, the trial completes
    /// and `active` becomes `nil`. Otherwise advances to the next position.
    mutating func place(offset: Cents) {
        guard let active else { return }
        let detuned = DetunedMIDINote(note: path.lowerAnchor, offset: offset)
        placed.append(detuned)
        if active.index == path.interiorPositionCount {
            self.active = nil  // trial complete
        } else {
            self.active = ActivePosition(index: active.index + 1, preservedValue: nil)
        }
    }

    /// Lossy step-back: re-activates the immediately previous position with
    /// its previously placed value preserved as the slider's starting point.
    /// No-op at position 1, and no-op if the trial is complete.
    mutating func stepBack() {
        guard let active, active.index > 1 else { return }
        let prior = placed.removeLast()
        self.active = ActivePosition(index: active.index - 1, preservedValue: prior)
    }

    /// Reopens a completed trial for revision: re-activates the final
    /// position with its placed value preserved. No-op if not complete.
    mutating func reopenFinalPosition() {
        guard active == nil else { return }
        let prior = placed.removeLast()
        self.active = ActivePosition(index: path.interiorPositionCount, preservedValue: prior)
    }

    /// Atomic step-back-to-index: drops every placed entry at index > `k`
    /// back to pending and re-activates position `k` with `placed[k-1]`
    /// preserved as the slider's starting value. No-op if `k < 1`, `k`
    /// exceeds the current active index, or the trial is already at `k`.
    /// Used by the touch-and-drag interaction: tapping a placed dot at
    /// index `k` reverts to that position in one observable step.
    mutating func revertTo(positionIndex k: Int) {
        guard k >= 1 else { return }
        if active == nil, placed.count == path.interiorPositionCount {
            reopenFinalPosition()
        }
        while let current = active, current.index > k {
            stepBack()
        }
    }

    /// True once every interior position is placed.
    var isComplete: Bool {
        active == nil && placed.count == path.interiorPositionCount
    }

    /// The currently active position descriptor, or `nil` once the trial
    /// completes.
    struct ActivePosition: Hashable, Sendable {
        /// 1-based position index within the path.
        let index: Int

        /// The slider's starting value when this position re-activates from a
        /// prior placement; `nil` on first visit.
        let preservedValue: DetunedMIDINote?
    }
}
