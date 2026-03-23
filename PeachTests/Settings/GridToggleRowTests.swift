import SwiftUI
import Testing

@testable import Peach

@Suite("GridToggleRow")
struct GridToggleRowTests {

    // MARK: - Test Helpers

    private enum Fruit: Int, CaseIterable, Hashable {
        case apple = 0
        case banana = 1
        case cherry = 2
    }

    // MARK: - Toggle Behavior

    @Test("Tapping inactive element activates it")
    func activateElement() {
        var selection: Set<Fruit> = [.apple]
        GridToggleRow<Fruit>.toggle(.banana, in: &selection)
        #expect(selection == [.apple, .banana])
    }

    @Test("Tapping active element deactivates it")
    func deactivateElement() {
        var selection: Set<Fruit> = [.apple, .banana]
        GridToggleRow<Fruit>.toggle(.apple, in: &selection)
        #expect(selection == [.banana])
    }

    @Test("Cannot deactivate last remaining element")
    func lastRemainingGuard() {
        var selection: Set<Fruit> = [.cherry]
        GridToggleRow<Fruit>.toggle(.cherry, in: &selection)
        #expect(selection == [.cherry])
    }

    @Test("isLastRemaining returns true when single element selected")
    func isLastRemainingTrue() {
        let selection: Set<Fruit> = [.banana]
        #expect(GridToggleRow<Fruit>.isLastRemaining(.banana, in: selection))
    }

    @Test("isLastRemaining returns false when multiple elements selected")
    func isLastRemainingFalseMultiple() {
        let selection: Set<Fruit> = [.apple, .banana]
        #expect(!GridToggleRow<Fruit>.isLastRemaining(.apple, in: selection))
    }

    @Test("isLastRemaining returns false for non-selected element")
    func isLastRemainingFalseNotSelected() {
        let selection: Set<Fruit> = [.banana]
        #expect(!GridToggleRow<Fruit>.isLastRemaining(.apple, in: selection))
    }
}
