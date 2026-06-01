import SwiftUI
import Testing
@testable import Peach

#if PEACH_RESEARCH
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
            index: 2, activeBeatPosition: .first, gapPosition: .fourth
        )
        #expect(opacity == 0.2)
    }

    @Test("active position dot has full opacity")
    func activePositionFullOpacity() async {
        let opacity = ContinuousRhythmMatchingDotView.dotOpacity(
            index: 0, activeBeatPosition: .first, gapPosition: .fourth
        )
        #expect(opacity == 1.0)
    }

    @Test("gap dot that is also active has full opacity")
    func gapActiveFullOpacity() async {
        let opacity = ContinuousRhythmMatchingDotView.dotOpacity(
            index: 1, activeBeatPosition: .second, gapPosition: .second
        )
        #expect(opacity == 1.0)
    }

    @Test("non-active gap dot has low opacity")
    func nonActiveGapDotOpacity() async {
        let opacity = ContinuousRhythmMatchingDotView.dotOpacity(
            index: 3, activeBeatPosition: .first, gapPosition: .fourth
        )
        #expect(opacity == 0.2)
    }

    @Test("gap dot is rendered as outline")
    func gapDotIsOutline() async {
        let isGap = ContinuousRhythmMatchingDotView.isGapDot(index: 1, gapPosition: .second)
        #expect(isGap == true)
    }

    @Test("non-gap dot is not outline")
    func nonGapDotIsNotOutline() async {
        let isGap = ContinuousRhythmMatchingDotView.isGapDot(index: 0, gapPosition: .second)
        #expect(isGap == false)
    }

    @Test("beat-1 dot uses larger diameter")
    func beatOneDotDiameter() async {
        let diameter = ContinuousRhythmMatchingDotView.diameter(forIndex: 0)
        #expect(diameter == ContinuousRhythmMatchingDotView.beatOneDotDiameter)
    }

    @Test("non-beat-1 dot uses standard diameter")
    func nonBeatOneDotDiameter() async {
        let diameter = ContinuousRhythmMatchingDotView.diameter(forIndex: 2)
        #expect(diameter == ContinuousRhythmMatchingDotView.dotDiameter)
    }

}
#endif
