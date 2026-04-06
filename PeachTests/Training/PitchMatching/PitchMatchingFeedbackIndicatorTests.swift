import Foundation
import SwiftUI
import Testing
@testable import Peach

@Suite("PitchMatchingFeedbackIndicator")
struct PitchMatchingFeedbackIndicatorTests {

    // MARK: - band() Tests

    @Test("dead center band for exactly 0.0 cent error")
    func returnsDeadCenterBandForZeroCentError() async {
        let band = PitchMatchingFeedbackIndicator.band(centError: 0.0)
        #expect(band == .deadCenter)
    }

    @Test("dead center band for small value that rounds to 0")
    func returnsDeadCenterBandForSmallValueRoundingToZero() async {
        let band = PitchMatchingFeedbackIndicator.band(centError: 0.4)
        #expect(band == .deadCenter)
    }

    @Test("dead center band for small negative value that rounds to 0")
    func returnsDeadCenterBandForSmallNegativeValueRoundingToZero() async {
        let band = PitchMatchingFeedbackIndicator.band(centError: -0.4)
        #expect(band == .deadCenter)
    }

    @Test("close band for positive error less than 10")
    func returnsCloseBandForSmallPositiveError() async {
        let band = PitchMatchingFeedbackIndicator.band(centError: 4.0)
        #expect(band == .close)
    }

    @Test("close band for negative error with absolute value less than 10")
    func returnsCloseBandForSmallNegativeError() async {
        let band = PitchMatchingFeedbackIndicator.band(centError: -3.0)
        #expect(band == .close)
    }

    @Test("boundary 9.99 rounds to 10 — moderate band, not close")
    func returnsModerateBandForNinePointNineNine() async {
        let band = PitchMatchingFeedbackIndicator.band(centError: 9.99)
        #expect(band == .moderate)
    }

    @Test("close band for 9.49 (rounds to 9 — close)")
    func returnsCloseBandForNinePointFourNine() async {
        let band = PitchMatchingFeedbackIndicator.band(centError: 9.49)
        #expect(band == .close)
    }

    @Test("moderate band for exactly 10 cents")
    func returnsModerateBandForTenCents() async {
        let band = PitchMatchingFeedbackIndicator.band(centError: 10.0)
        #expect(band == .moderate)
    }

    @Test("moderate band for exactly 30 cents")
    func returnsModerateBandForThirtyCents() async {
        let band = PitchMatchingFeedbackIndicator.band(centError: 30.0)
        #expect(band == .moderate)
    }

    @Test("moderate band for negative 22 cents")
    func returnsModerateBandForNegativeTwentyTwo() async {
        let band = PitchMatchingFeedbackIndicator.band(centError: -22.0)
        #expect(band == .moderate)
    }

    @Test("far band for error exceeding 30 cents")
    func returnsFarBandForLargePositiveError() async {
        let band = PitchMatchingFeedbackIndicator.band(centError: 55.0)
        #expect(band == .far)
    }

    @Test("far band for 30.01 (rounds to 30 — moderate)")
    func returnsModerateBandForThirtyPointZeroOne() async {
        let band = PitchMatchingFeedbackIndicator.band(centError: 30.01)
        #expect(band == .moderate)
    }

    @Test("far band for 30.5 (rounds to 31 — far)")
    func returnsFarBandForThirtyPointFive() async {
        let band = PitchMatchingFeedbackIndicator.band(centError: 30.5)
        #expect(band == .far)
    }

    @Test("far band for large negative error")
    func returnsFarBandForLargeNegativeError() async {
        let band = PitchMatchingFeedbackIndicator.band(centError: -50.0)
        #expect(band == .far)
    }

    // MARK: - arrowSymbolName() Tests

    @Test("circle.fill symbol for zero cent error")
    func returnsCircleFillForZeroCentError() async {
        let symbol = PitchMatchingFeedbackIndicator.arrowSymbolName(centError: 0.0)
        #expect(symbol == "circle.fill")
    }

    @Test("arrow.up symbol for positive cent error (sharp)")
    func returnsArrowUpForPositiveCentError() async {
        let symbol = PitchMatchingFeedbackIndicator.arrowSymbolName(centError: 15.0)
        #expect(symbol == "arrow.up")
    }

    @Test("arrow.down symbol for negative cent error (flat)")
    func returnsArrowDownForNegativeCentError() async {
        let symbol = PitchMatchingFeedbackIndicator.arrowSymbolName(centError: -15.0)
        #expect(symbol == "arrow.down")
    }

    @Test("circle.fill for value that rounds to zero")
    func returnsCircleFillForValueRoundingToZero() async {
        let symbol = PitchMatchingFeedbackIndicator.arrowSymbolName(centError: 0.3)
        #expect(symbol == "circle.fill")
    }

    // MARK: - feedbackColor() Tests

    @Test("green color for dead center band")
    func returnsGreenForDeadCenterBand() async {
        let color = PitchMatchingFeedbackIndicator.feedbackColor(band: .deadCenter)
        #expect(color == .green)
    }

    @Test("green color for close band")
    func returnsGreenForCloseBand() async {
        let color = PitchMatchingFeedbackIndicator.feedbackColor(band: .close)
        #expect(color == .green)
    }

    @Test("yellow color for moderate band")
    func returnsYellowForModerateBand() async {
        let color = PitchMatchingFeedbackIndicator.feedbackColor(band: .moderate)
        #expect(color == .yellow)
    }

    @Test("red color for far band")
    func returnsRedForFarBand() async {
        let color = PitchMatchingFeedbackIndicator.feedbackColor(band: .far)
        #expect(color == .red)
    }

    // MARK: - centOffsetText() Tests

    @Test("formats positive cent error with plus sign")
    func formatsPositiveCentErrorWithPlusSign() async {
        let text = PitchMatchingFeedbackIndicator.centOffsetText(centError: 4.0)
        #expect(text == "+4 " + String(localized: "cents"))
    }

    @Test("formats negative cent error with minus sign")
    func formatsNegativeCentErrorWithMinusSign() async {
        let text = PitchMatchingFeedbackIndicator.centOffsetText(centError: -3.0)
        #expect(text == "-3 " + String(localized: "cents"))
    }

    @Test("formats zero cent error without sign")
    func formatsZeroCentErrorWithoutSign() async {
        let text = PitchMatchingFeedbackIndicator.centOffsetText(centError: 0.0)
        #expect(text == "0 " + String(localized: "cents"))
    }

    @Test("rounds to nearest integer for display")
    func roundsToNearestIntegerForDisplay() async {
        let text = PitchMatchingFeedbackIndicator.centOffsetText(centError: 4.7)
        #expect(text == "+5 " + String(localized: "cents"))
    }

    @Test("rounds negative value to nearest integer")
    func roundsNegativeValueToNearestInteger() async {
        let text = PitchMatchingFeedbackIndicator.centOffsetText(centError: -27.3)
        #expect(text == "-27 " + String(localized: "cents"))
    }

    @Test("rounds 0.4 to 0 cents")
    func roundsSmallValueToZero() async {
        let text = PitchMatchingFeedbackIndicator.centOffsetText(centError: 0.4)
        #expect(text == "0 " + String(localized: "cents"))
    }

    // MARK: - accessibilityLabel() Tests

    @Test("accessibility label for positive error says sharp")
    func accessibilityLabelSaysSharpForPositiveError() async {
        let label = PitchMatchingFeedbackIndicator.accessibilityLabel(centError: 4.0)
        #expect(label == "4 " + String(localized: "cents sharp"))
    }

    @Test("accessibility label for negative error says flat")
    func accessibilityLabelSaysFlatForNegativeError() async {
        let label = PitchMatchingFeedbackIndicator.accessibilityLabel(centError: -27.0)
        #expect(label == "27 " + String(localized: "cents flat"))
    }

    @Test("accessibility label for zero says Dead center")
    func accessibilityLabelSaysDeadCenterForZero() async {
        let label = PitchMatchingFeedbackIndicator.accessibilityLabel(centError: 0.0)
        #expect(label == String(localized: "Dead center"))
    }

    @Test("accessibility label rounds to nearest integer")
    func accessibilityLabelRoundsToNearestInteger() async {
        let label = PitchMatchingFeedbackIndicator.accessibilityLabel(centError: 4.7)
        #expect(label == "5 " + String(localized: "cents sharp"))
    }

    @Test("accessibility label for small value rounding to zero says Dead center")
    func accessibilityLabelForSmallValueRoundingToZero() async {
        let label = PitchMatchingFeedbackIndicator.accessibilityLabel(centError: 0.3)
        #expect(label == String(localized: "Dead center"))
    }
}
