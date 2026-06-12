import Testing
import Foundation
@testable import Peach

@Suite("Slot Tests")
struct SlotTests {

    // MARK: - Construction

    @Test("Initial slot is pending with no placedCents")
    func initialPendingState() async {
        let slot = Slot(index: 1)
        #expect(slot.index == 1)
        #expect(slot.state == .pending)
        #expect(slot.placedCents == nil)
    }

    @Test("Slot preserves index")
    func preservesIndex() async {
        let slot = Slot(index: 5)
        #expect(slot.index == 5)
    }

    // MARK: - Commit transition

    @Test("committing(at:) transitions pending → committed and stores placedCents")
    func commitFromPending() async {
        let slot = Slot(index: 1)
        let committed = slot.committing(at: Cents(100.0))
        #expect(committed.state == .committed)
        #expect(committed.placedCents == Cents(100.0))
        #expect(committed.index == 1)
    }

    @Test("committing(at:) transitions active → committed and stores placedCents")
    func commitFromActive() async {
        let active = Slot(index: 2).reactivated()
        let committed = active.committing(at: Cents(200.0))
        #expect(committed.state == .committed)
        #expect(committed.placedCents == Cents(200.0))
        #expect(committed.index == 2)
    }

    // MARK: - Reactivate transition

    @Test("reactivated() preserves placedCents (slider starting position)")
    func reactivatePreservesPlacedCents() async {
        let committed = Slot(index: 3).committing(at: Cents(300.0))
        let reactivated = committed.reactivated()
        #expect(reactivated.state == .active)
        #expect(reactivated.placedCents == Cents(300.0))
        #expect(reactivated.index == 3)
    }

    @Test("reactivated() from pending sets state to active with no placedCents")
    func reactivateFromPending() async {
        let pending = Slot(index: 1)
        let reactivated = pending.reactivated()
        #expect(reactivated.state == .active)
        #expect(reactivated.placedCents == nil)
    }

    // MARK: - PendingAgain transition

    @Test("pendingAgain clears placedCents to prevent stale targets")
    func pendingAgainClearsPlacedCents() async {
        let committed = Slot(index: 4).committing(at: Cents(400.0))
        let pendingAgain = committed.pendingAgain()
        #expect(pendingAgain.state == .pending)
        #expect(pendingAgain.placedCents == nil)
        #expect(pendingAgain.index == 4)
    }

    // MARK: - Hashable

    @Test("Slots with same index/state/placedCents are equal")
    func equality() async {
        let a = Slot(index: 1).committing(at: Cents(100.0))
        let b = Slot(index: 1).committing(at: Cents(100.0))
        #expect(a == b)
    }

    @Test("Slots with different placedCents are not equal")
    func inequalityOnPlacedCents() async {
        let a = Slot(index: 1).committing(at: Cents(100.0))
        let b = Slot(index: 1).committing(at: Cents(101.0))
        #expect(a != b)
    }
}
