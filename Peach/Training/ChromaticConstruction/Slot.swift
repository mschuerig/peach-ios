import Foundation

enum SlotState: Hashable, Sendable {
    case pending
    case active
    case committed
}

/// One position the user must place during a chromatic-construction trial.
/// Only `.active` slots are editable; `.committed` slots are locked but
/// tappable for playback; `.pending` slots are placeholders for upcoming
/// positions. Step-back is lossy by design — see `pendingAgain()`.
struct Slot: Hashable, Sendable {
    let index: Int
    let state: SlotState
    let placedCents: Cents?

    init(index: Int, state: SlotState = .pending, placedCents: Cents? = nil) {
        self.index = index
        self.state = state
        self.placedCents = placedCents
    }

    func committing(at cents: Cents) -> Slot {
        Slot(index: index, state: .committed, placedCents: cents)
    }

    /// Re-activates this slot, preserving any previously committed `placedCents`
    /// so the view can use it as the slider's starting position. The user does
    /// not lose their prior intent unless they overwrite it.
    func reactivated() -> Slot {
        Slot(index: index, state: .active, placedCents: placedCents)
    }

    /// Lossy reset to `.pending` — clears `placedCents` because the predecessor
    /// slot's pitch may have changed, making this slot's prior target stale.
    func pendingAgain() -> Slot {
        Slot(index: index, state: .pending, placedCents: nil)
    }
}
