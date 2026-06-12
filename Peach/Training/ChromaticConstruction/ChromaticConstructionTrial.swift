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

    init(path: ChromaticPath) {
        self.path = path
        self.placed = []
        self.active = ActivePosition(index: 1, preservedValue: nil)
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
