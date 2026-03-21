import Testing
@testable import Peach

@Suite("RhythmMatchingFeedbackView")
struct RhythmMatchingFeedbackViewTests {

    // MARK: - band() Tests

    @Test("precise band for exactly 0 percent")
    func returnsPreciseBandForZero() async {
        #expect(RhythmMatchingFeedbackView.band(offsetPercentage: 0) == .precise)
    }

    @Test("precise band for 5 percent (boundary)")
    func returnsPreciseBandForFive() async {
        #expect(RhythmMatchingFeedbackView.band(offsetPercentage: 5) == .precise)
    }

    @Test("precise band for negative 5 percent")
    func returnsPreciseBandForNegativeFive() async {
        #expect(RhythmMatchingFeedbackView.band(offsetPercentage: -5) == .precise)
    }

    @Test("moderate band for 6 percent")
    func returnsModerateBandForSix() async {
        #expect(RhythmMatchingFeedbackView.band(offsetPercentage: 6) == .moderate)
    }

    @Test("moderate band for 15 percent (boundary)")
    func returnsModerateBandForFifteen() async {
        #expect(RhythmMatchingFeedbackView.band(offsetPercentage: 15) == .moderate)
    }

    @Test("moderate band for negative 10 percent")
    func returnsModerateBandForNegativeTen() async {
        #expect(RhythmMatchingFeedbackView.band(offsetPercentage: -10) == .moderate)
    }

    @Test("erratic band for 16 percent")
    func returnsErraticBandForSixteen() async {
        #expect(RhythmMatchingFeedbackView.band(offsetPercentage: 16) == .erratic)
    }

    @Test("erratic band for negative 20 percent")
    func returnsErraticBandForNegativeTwenty() async {
        #expect(RhythmMatchingFeedbackView.band(offsetPercentage: -20) == .erratic)
    }

    // MARK: - feedbackColor() Tests

    @Test("green color for precise band")
    func returnsGreenForPrecise() async {
        #expect(RhythmMatchingFeedbackView.feedbackColor(band: .precise) == .green)
    }

    @Test("yellow color for moderate band")
    func returnsYellowForModerate() async {
        #expect(RhythmMatchingFeedbackView.feedbackColor(band: .moderate) == .yellow)
    }

    @Test("red color for erratic band")
    func returnsRedForErratic() async {
        #expect(RhythmMatchingFeedbackView.feedbackColor(band: .erratic) == .red)
    }

    // MARK: - arrowSymbolName() Tests

    @Test("arrow.left for negative (early) offset")
    func returnsArrowLeftForNegative() async {
        #expect(RhythmMatchingFeedbackView.arrowSymbolName(offsetPercentage: -3) == "arrow.left")
    }

    @Test("arrow.right for positive (late) offset")
    func returnsArrowRightForPositive() async {
        #expect(RhythmMatchingFeedbackView.arrowSymbolName(offsetPercentage: 8) == "arrow.right")
    }

    @Test("circle.fill for zero offset")
    func returnsCircleFillForZero() async {
        #expect(RhythmMatchingFeedbackView.arrowSymbolName(offsetPercentage: 0) == "circle.fill")
    }

    // MARK: - feedbackText() Tests

    @Test("early text for negative offset")
    func earlyTextForNegativeOffset() async {
        let text = RhythmMatchingFeedbackView.feedbackText(offsetPercentage: -3)
        #expect(text == "3% " + String(localized: "early"))
    }

    @Test("late text for positive offset")
    func lateTextForPositiveOffset() async {
        let text = RhythmMatchingFeedbackView.feedbackText(offsetPercentage: 8)
        #expect(text == "8% " + String(localized: "late"))
    }

    @Test("On the beat for zero offset")
    func onTheBeatForZero() async {
        let text = RhythmMatchingFeedbackView.feedbackText(offsetPercentage: 0)
        #expect(text == String(localized: "On the beat"))
    }

    @Test("rounds to integer for display")
    func roundsToIntegerForDisplay() async {
        let text = RhythmMatchingFeedbackView.feedbackText(offsetPercentage: 3.7)
        #expect(text == "4% " + String(localized: "late"))
    }

    @Test("rounds small value to zero shows On the beat")
    func roundsSmallValueToZero() async {
        let text = RhythmMatchingFeedbackView.feedbackText(offsetPercentage: 0.3)
        #expect(text == String(localized: "On the beat"))
    }

    // MARK: - accessibilityLabel() Tests

    @Test("accessibility label for early offset")
    func accessibilityLabelForEarly() async {
        let label = RhythmMatchingFeedbackView.accessibilityLabel(offsetPercentage: -3)
        #expect(label == "3 " + String(localized: "percent early"))
    }

    @Test("accessibility label for late offset")
    func accessibilityLabelForLate() async {
        let label = RhythmMatchingFeedbackView.accessibilityLabel(offsetPercentage: 8)
        #expect(label == "8 " + String(localized: "percent late"))
    }

    @Test("accessibility label for zero offset")
    func accessibilityLabelForZero() async {
        let label = RhythmMatchingFeedbackView.accessibilityLabel(offsetPercentage: 0)
        #expect(label == String(localized: "On the beat"))
    }

    @Test("accessibility label rounds to integer")
    func accessibilityLabelRoundsToInteger() async {
        let label = RhythmMatchingFeedbackView.accessibilityLabel(offsetPercentage: 4.7)
        #expect(label == "5 " + String(localized: "percent late"))
    }
}
