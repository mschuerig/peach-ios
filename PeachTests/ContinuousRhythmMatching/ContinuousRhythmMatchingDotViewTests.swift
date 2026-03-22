import SwiftUI
import Testing
@testable import Peach

@Suite("ContinuousRhythmMatchingDotView")
struct ContinuousRhythmMatchingDotViewTests {

    // MARK: - Layout Parameters

    @Test("beat-1 dot is larger than other dots")
    func beatOneDotIsLarger() async {
        #expect(ContinuousRhythmMatchingDotView.beatOneDotDiameter > ContinuousRhythmMatchingDotView.dotDiameter)
    }

    @Test("dot spacing is consistent")
    func dotSpacing() async {
        #expect(ContinuousRhythmMatchingDotView.dotSpacing > 0)
    }

    // MARK: - Dot State

    @Test("non-active non-gap dot has low opacity")
    func nonActiveNonGapDotOpacity() async {
        let opacity = ContinuousRhythmMatchingDotView.dotOpacity(
            stepIndex: 2, activeStep: .first, gapPosition: .fourth
        )
        #expect(opacity == 0.2)
    }

    @Test("active step dot has full opacity")
    func activeStepFullOpacity() async {
        let opacity = ContinuousRhythmMatchingDotView.dotOpacity(
            stepIndex: 0, activeStep: .first, gapPosition: .fourth
        )
        #expect(opacity == 1.0)
    }

    @Test("gap dot that is also active has full opacity")
    func gapActiveFullOpacity() async {
        let opacity = ContinuousRhythmMatchingDotView.dotOpacity(
            stepIndex: 1, activeStep: .second, gapPosition: .second
        )
        #expect(opacity == 1.0)
    }

    @Test("non-active gap dot has low opacity")
    func nonActiveGapDotOpacity() async {
        let opacity = ContinuousRhythmMatchingDotView.dotOpacity(
            stepIndex: 3, activeStep: .first, gapPosition: .fourth
        )
        #expect(opacity == 0.2)
    }

    @Test("gap dot is rendered as outline")
    func gapDotIsOutline() async {
        let isGap = ContinuousRhythmMatchingDotView.isGapDot(stepIndex: 1, gapPosition: .second)
        #expect(isGap == true)
    }

    @Test("non-gap dot is not outline")
    func nonGapDotIsNotOutline() async {
        let isGap = ContinuousRhythmMatchingDotView.isGapDot(stepIndex: 0, gapPosition: .second)
        #expect(isGap == false)
    }

    @Test("beat-1 dot uses larger diameter")
    func beatOneDotDiameter() async {
        let diameter = ContinuousRhythmMatchingDotView.diameter(forStepIndex: 0)
        #expect(diameter == ContinuousRhythmMatchingDotView.beatOneDotDiameter)
    }

    @Test("non-beat-1 dot uses standard diameter")
    func nonBeatOneDotDiameter() async {
        let diameter = ContinuousRhythmMatchingDotView.diameter(forStepIndex: 2)
        #expect(diameter == ContinuousRhythmMatchingDotView.dotDiameter)
    }

    // MARK: - Feedback Color

    @Test("green for precise timing (≤5%)")
    func greenForPrecise() async {
        #expect(ContinuousRhythmMatchingDotView.feedbackColor(forPercentage: 3) == .green)
    }

    @Test("yellow for moderate timing (>5% and ≤15%)")
    func yellowForModerate() async {
        #expect(ContinuousRhythmMatchingDotView.feedbackColor(forPercentage: 10) == .yellow)
    }

    @Test("red for erratic timing (>15%)")
    func redForErratic() async {
        #expect(ContinuousRhythmMatchingDotView.feedbackColor(forPercentage: 20) == .red)
    }

    @Test("nil percentage returns nil color")
    func nilPercentageReturnsNilColor() async {
        #expect(ContinuousRhythmMatchingDotView.feedbackColor(forPercentage: nil) == nil)
    }
}
