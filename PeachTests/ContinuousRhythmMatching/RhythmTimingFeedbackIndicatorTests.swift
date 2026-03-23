import Foundation
import SwiftUI
import Testing
@testable import Peach

@Suite("RhythmTimingFeedbackIndicator")
struct RhythmTimingFeedbackIndicatorTests {

    // MARK: - arrowSymbolName() Tests

    @Test("left arrow for negative offset (early)")
    func leftArrowForEarlyTap() async {
        let symbol = RhythmTimingFeedbackIndicator.arrowSymbolName(offsetMs: -5.0)
        #expect(symbol == "arrow.left")
    }

    @Test("right arrow for positive offset (late)")
    func rightArrowForLateTap() async {
        let symbol = RhythmTimingFeedbackIndicator.arrowSymbolName(offsetMs: 5.0)
        #expect(symbol == "arrow.right")
    }

    @Test("circle.fill for zero offset")
    func circleFillForZeroOffset() async {
        let symbol = RhythmTimingFeedbackIndicator.arrowSymbolName(offsetMs: 0.0)
        #expect(symbol == "circle.fill")
    }

    @Test("circle.fill for value that rounds to zero")
    func circleFillForValueRoundingToZero() async {
        let symbol = RhythmTimingFeedbackIndicator.arrowSymbolName(offsetMs: 0.3)
        #expect(symbol == "circle.fill")
    }

    // MARK: - offsetText() Tests

    @Test("formats early tap as absolute ms value")
    func formatsEarlyTapText() async {
        let text = RhythmTimingFeedbackIndicator.offsetText(offsetMs: -5.0)
        #expect(text == "5 " + String(localized: "ms"))
    }

    @Test("formats late tap as absolute ms value")
    func formatsLateTapText() async {
        let text = RhythmTimingFeedbackIndicator.offsetText(offsetMs: 3.0)
        #expect(text == "3 " + String(localized: "ms"))
    }

    @Test("formats zero offset")
    func formatsZeroOffsetText() async {
        let text = RhythmTimingFeedbackIndicator.offsetText(offsetMs: 0.0)
        #expect(text == "0 " + String(localized: "ms"))
    }

    @Test("rounds to nearest integer for display")
    func roundsToNearestInteger() async {
        let text = RhythmTimingFeedbackIndicator.offsetText(offsetMs: 4.7)
        #expect(text == "5 " + String(localized: "ms"))
    }

    @Test("rounds negative value to nearest integer")
    func roundsNegativeToNearestInteger() async {
        let text = RhythmTimingFeedbackIndicator.offsetText(offsetMs: -12.3)
        #expect(text == "12 " + String(localized: "ms"))
    }

    @Test("rounds 0.4 to zero")
    func roundsSmallValueToZero() async {
        let text = RhythmTimingFeedbackIndicator.offsetText(offsetMs: 0.4)
        #expect(text == "0 " + String(localized: "ms"))
    }

    // MARK: - accuracyLevel() Tests

    @Test("precise for small offset at 120 BPM")
    func preciseForSmallOffset() async {
        // At 120 BPM, sixteenth = 125ms. 5ms offset = 4% — well within precise band.
        let level = RhythmTimingFeedbackIndicator.accuracyLevel(offsetMs: 5.0, tempo: TempoBPM(120))
        #expect(level == .precise)
    }

    @Test("moderate for medium offset at 120 BPM")
    func moderateForMediumOffset() async {
        // At 120 BPM, sixteenth = 125ms. 20ms offset = 16% — moderate band.
        let level = RhythmTimingFeedbackIndicator.accuracyLevel(offsetMs: 20.0, tempo: TempoBPM(120))
        #expect(level == .moderate)
    }

    @Test("erratic for large offset at 120 BPM")
    func erraticForLargeOffset() async {
        // At 120 BPM, sixteenth = 125ms. 40ms offset = 32% — erratic band.
        let level = RhythmTimingFeedbackIndicator.accuracyLevel(offsetMs: 40.0, tempo: TempoBPM(120))
        #expect(level == .erratic)
    }

    @Test("uses absolute value of negative offset")
    func usesAbsoluteValueForNegativeOffset() async {
        let level = RhythmTimingFeedbackIndicator.accuracyLevel(offsetMs: -5.0, tempo: TempoBPM(120))
        #expect(level == .precise)
    }

    @Test("zero offset is precise")
    func zeroOffsetIsPrecise() async {
        let level = RhythmTimingFeedbackIndicator.accuracyLevel(offsetMs: 0.0, tempo: TempoBPM(120))
        #expect(level == .precise)
    }

    // MARK: - feedbackColor() Tests

    @Test("green for precise level")
    func greenForPrecise() async {
        let color = RhythmTimingFeedbackIndicator.feedbackColor(level: .precise)
        #expect(color == .green)
    }

    @Test("yellow for moderate level")
    func yellowForModerate() async {
        let color = RhythmTimingFeedbackIndicator.feedbackColor(level: .moderate)
        #expect(color == .yellow)
    }

    @Test("red for erratic level")
    func redForErratic() async {
        let color = RhythmTimingFeedbackIndicator.feedbackColor(level: .erratic)
        #expect(color == .red)
    }

    // MARK: - accessibilityLabel() Tests

    @Test("accessibility label for early tap")
    func accessibilityLabelForEarlyTap() async {
        let label = RhythmTimingFeedbackIndicator.accessibilityLabel(offsetMs: -5.0)
        #expect(label == "5 " + String(localized: "milliseconds early"))
    }

    @Test("accessibility label for late tap")
    func accessibilityLabelForLateTap() async {
        let label = RhythmTimingFeedbackIndicator.accessibilityLabel(offsetMs: 3.0)
        #expect(label == "3 " + String(localized: "milliseconds late"))
    }

    @Test("accessibility label for dead center")
    func accessibilityLabelForDeadCenter() async {
        let label = RhythmTimingFeedbackIndicator.accessibilityLabel(offsetMs: 0.0)
        #expect(label == String(localized: "Dead center"))
    }

    @Test("accessibility label rounds to nearest integer")
    func accessibilityLabelRoundsToNearestInteger() async {
        let label = RhythmTimingFeedbackIndicator.accessibilityLabel(offsetMs: 4.7)
        #expect(label == "5 " + String(localized: "milliseconds late"))
    }

    @Test("accessibility label for value rounding to zero says dead center")
    func accessibilityLabelForSmallValueRoundingToZero() async {
        let label = RhythmTimingFeedbackIndicator.accessibilityLabel(offsetMs: 0.3)
        #expect(label == String(localized: "Dead center"))
    }
}
