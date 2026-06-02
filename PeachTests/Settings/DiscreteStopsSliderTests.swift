import Testing
import Foundation
import SwiftUI
@testable import Peach

@Suite("DiscreteStopsSlider")
struct DiscreteStopsSliderTests {

    private static let todStops: [Int] = [1, 2, 3, 5, 10, 20]
    private static let enUS = Locale(identifier: "en_US")

    // MARK: - Nearest-Stop Lookup

    @Test("nearestStopIndex returns the exact index for an in-set value")
    func nearestStopIndexExactMatch() async {
        #expect(DiscreteStopsSlider.nearestStopIndex(to: 1, in: Self.todStops) == 0)
        #expect(DiscreteStopsSlider.nearestStopIndex(to: 5, in: Self.todStops) == 3)
        #expect(DiscreteStopsSlider.nearestStopIndex(to: 20, in: Self.todStops) == 5)
    }

    @Test("nearestStopIndex returns the nearest index for an out-of-set value")
    func nearestStopIndexOutOfSet() async {
        #expect(DiscreteStopsSlider.nearestStopIndex(to: 7, in: Self.todStops) == 3)
        #expect(DiscreteStopsSlider.nearestStopIndex(to: 8, in: Self.todStops) == 4)
        #expect(DiscreteStopsSlider.nearestStopIndex(to: 0, in: Self.todStops) == 0)
        #expect(DiscreteStopsSlider.nearestStopIndex(to: 100, in: Self.todStops) == 5)
    }

    @Test("nearestStopIndex resolves ties to the higher index")
    func nearestStopIndexTieBreak() async {
        // value 5 is equidistant from stops 2 and 8 (distance 3 each).
        #expect(DiscreteStopsSlider.nearestStopIndex(to: 5, in: [2, 8]) == 1)
    }

    // MARK: - Increment / Decrement

    @Test("incrementValue moves to the next stop")
    func incrementValueMovesToNextStop() async {
        #expect(DiscreteStopsSlider.incrementValue(5, in: Self.todStops) == 10)
        #expect(DiscreteStopsSlider.incrementValue(1, in: Self.todStops) == 2)
    }

    @Test("incrementValue clamps at the upper bound")
    func incrementValueClampsAtUpperBound() async {
        #expect(DiscreteStopsSlider.incrementValue(20, in: Self.todStops) == 20)
    }

    @Test("decrementValue moves to the previous stop")
    func decrementValueMovesToPreviousStop() async {
        #expect(DiscreteStopsSlider.decrementValue(5, in: Self.todStops) == 3)
        #expect(DiscreteStopsSlider.decrementValue(20, in: Self.todStops) == 10)
    }

    @Test("decrementValue clamps at the lower bound")
    func decrementValueClampsAtLowerBound() async {
        #expect(DiscreteStopsSlider.decrementValue(1, in: Self.todStops) == 1)
    }

    @Test("increment from an out-of-set value anchors at the nearest stop then steps")
    func incrementFromOutOfSetValue() async {
        // nearestStopIndex(7, …) == 3 (stop value 5); incrementing → stops[4] == 10
        #expect(DiscreteStopsSlider.incrementValue(7, in: Self.todStops) == 10)
    }

    @Test("decrement from an out-of-set value anchors at the nearest stop then steps")
    func decrementFromOutOfSetValue() async {
        // nearestStopIndex(8, …) == 4 (stop value 10); decrementing → stops[3] == 5
        #expect(DiscreteStopsSlider.decrementValue(8, in: Self.todStops) == 5)
    }

    // MARK: - Enabled-State Predicates

    @Test("isIncrementEnabled is true below the cap, false at the cap")
    func isIncrementEnabledAtBounds() async {
        #expect(DiscreteStopsSlider.isIncrementEnabled(at: 10, in: Self.todStops) == true)
        #expect(DiscreteStopsSlider.isIncrementEnabled(at: 20, in: Self.todStops) == false)
    }

    @Test("isDecrementEnabled is true above the floor, false at the floor")
    func isDecrementEnabledAtBounds() async {
        #expect(DiscreteStopsSlider.isDecrementEnabled(at: 1, in: Self.todStops) == false)
        #expect(DiscreteStopsSlider.isDecrementEnabled(at: 2, in: Self.todStops) == true)
    }

    // MARK: - Display Format

    @Test("displayMaxRepetitions renders digits for integer stops and ∞ at the cap")
    func displayMaxRepetitionsFormatsCorrectly() async {
        #expect(DiscreteStopsSlider.displayMaxRepetitions(1, capValue: 20) == "1")
        #expect(DiscreteStopsSlider.displayMaxRepetitions(10, capValue: 20) == "10")
        #expect(DiscreteStopsSlider.displayMaxRepetitions(20, capValue: 20) == "∞")
    }

    // MARK: - Accessibility Format

    @Test("accessibilityMaxRepetitions renders the integer below the cap")
    func accessibilityMaxRepetitionsForIntegerStop() async {
        #expect(DiscreteStopsSlider.accessibilityMaxRepetitions(5, capValue: 20, locale: Self.enUS) == "5")
        #expect(DiscreteStopsSlider.accessibilityMaxRepetitions(1, capValue: 20, locale: Self.enUS) == "1")
    }

    // Note: the bundle-language resolution for `String(localized:)` is not
    // strictly assertable via the `locale:` parameter alone (see the 81.1
    // Spec Change Log for the rationale). We assert the structural presence
    // of one of the known unit words, so the test is robust whether the test
    // bundle picks up the English or German strings.
    @Test("accessibilityMaxRepetitions at the cap emits the unlimited vocabulary")
    func accessibilityMaxRepetitionsAtCap() async {
        let formatted = DiscreteStopsSlider.accessibilityMaxRepetitions(20, capValue: 20, locale: Self.enUS).lowercased()
        #expect(formatted.contains("unlimited") || formatted.contains("unbegrenzt"))
    }

    // MARK: - indexBinding Round-Trip

    /// Helper that materialises a `Binding<Int>` over a local box so we can
    /// exercise the static `indexBinding` adapter end-to-end. The closure
    /// receives the index-bound `Binding<Double>`; mutations to it are
    /// reflected in the returned `Int` value.
    private static func runIndexBinding(initial: Int, stops: [Int], _ body: (Binding<Double>) -> Void) -> Int {
        final class Box { var value: Int; init(_ v: Int) { self.value = v } }
        let box = Box(initial)
        let intBinding = Binding<Int>(get: { box.value }, set: { box.value = $0 })
        let doubleBinding = DiscreteStopsSlider.indexBinding(intBinding, in: stops)
        body(doubleBinding)
        return box.value
    }

    @Test("indexBinding.get returns the nearest stop's index for the stored value")
    func indexBindingGetReturnsNearestIndex() async {
        let result = Self.runIndexBinding(initial: 5, stops: Self.todStops) { binding in
            #expect(binding.wrappedValue == 3.0)
        }
        #expect(result == 5)
    }

    @Test("indexBinding.get returns the nearest stop's index for an out-of-set stored value")
    func indexBindingGetForOutOfSetValue() async {
        _ = Self.runIndexBinding(initial: 7, stops: Self.todStops) { binding in
            #expect(binding.wrappedValue == 3.0)
        }
    }

    @Test("indexBinding.set writes the stop value for an integer index")
    func indexBindingSetIntegerIndex() async {
        let result = Self.runIndexBinding(initial: 1, stops: Self.todStops) { binding in
            binding.wrappedValue = 4.0
        }
        #expect(result == 10)
    }

    @Test("indexBinding.set rounds a fractional index to the nearest integer stop")
    func indexBindingSetFractionalIndex() async {
        let resultRoundsDown = Self.runIndexBinding(initial: 1, stops: Self.todStops) { binding in
            binding.wrappedValue = 3.4
        }
        #expect(resultRoundsDown == 5)

        let resultRoundsUp = Self.runIndexBinding(initial: 1, stops: Self.todStops) { binding in
            binding.wrappedValue = 3.6
        }
        #expect(resultRoundsUp == 10)
    }

    @Test("indexBinding.set clamps an over-cap index to the last stop")
    func indexBindingSetClampsAboveCap() async {
        let result = Self.runIndexBinding(initial: 1, stops: Self.todStops) { binding in
            binding.wrappedValue = 99.0
        }
        #expect(result == 20)
    }

    @Test("indexBinding.set clamps an under-zero index to the first stop")
    func indexBindingSetClampsBelowFloor() async {
        let result = Self.runIndexBinding(initial: 20, stops: Self.todStops) { binding in
            binding.wrappedValue = -3.0
        }
        #expect(result == 1)
    }

    @Test("indexBinding.set is a no-op for empty stops")
    func indexBindingSetNoOpForEmptyStops() async {
        let result = Self.runIndexBinding(initial: 42, stops: []) { binding in
            binding.wrappedValue = 0.0
        }
        #expect(result == 42)
    }
}
