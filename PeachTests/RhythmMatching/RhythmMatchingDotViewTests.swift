import SwiftUI
import Testing
@testable import Peach

@Suite("RhythmMatchingDotView")
struct RhythmMatchingDotViewTests {

    // MARK: - Layout Parameters

    @Test("dot diameter matches RhythmDotView at 16pt")
    func dotDiameter() async {
        #expect(RhythmMatchingDotView.dotDiameter == 16)
    }

    @Test("dot spacing matches RhythmDotView at 24pt")
    func dotSpacing() async {
        #expect(RhythmMatchingDotView.dotSpacing == 24)
    }

    // MARK: - dotColor(forPercentage:) Tests

    @Test("green for precise timing (≤5%)")
    func greenForPrecise() async {
        #expect(RhythmMatchingDotView.dotColor(forPercentage: 3) == .green)
    }

    @Test("green for exactly 5%")
    func greenForFivePercent() async {
        #expect(RhythmMatchingDotView.dotColor(forPercentage: 5) == .green)
    }

    @Test("green for negative 5%")
    func greenForNegativeFive() async {
        #expect(RhythmMatchingDotView.dotColor(forPercentage: -5) == .green)
    }

    @Test("yellow for moderate timing (>5% and ≤15%)")
    func yellowForModerate() async {
        #expect(RhythmMatchingDotView.dotColor(forPercentage: 10) == .yellow)
    }

    @Test("yellow for exactly 15%")
    func yellowForFifteenPercent() async {
        #expect(RhythmMatchingDotView.dotColor(forPercentage: 15) == .yellow)
    }

    @Test("red for erratic timing (>15%)")
    func redForErratic() async {
        #expect(RhythmMatchingDotView.dotColor(forPercentage: 20) == .red)
    }

    @Test("red for negative erratic timing")
    func redForNegativeErratic() async {
        #expect(RhythmMatchingDotView.dotColor(forPercentage: -20) == .red)
    }
}
