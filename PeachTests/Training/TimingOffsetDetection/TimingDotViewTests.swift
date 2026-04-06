import Testing
@testable import Peach

@Suite("TimingDotView Tests")
struct TimingDotViewTests {

    @Test("dot diameter is 16pt")
    func dotDiameter() async {
        #expect(TimingDotView.dotDiameter == 16)
    }

    @Test("beat one dot diameter is 22pt")
    func beatOneDotDiameter() async {
        #expect(TimingDotView.beatOneDotDiameter == 22)
    }

    @Test("dot spacing is 24pt")
    func dotSpacing() async {
        #expect(TimingDotView.dotSpacing == 24)
    }

    @Test("diameter for step index 0 returns beat one diameter")
    func diameterForFirstStep() async {
        #expect(TimingDotView.diameter(forStepIndex: 0) == 22)
    }

    @Test("diameter for step indices 1-3 returns standard diameter")
    func diameterForOtherSteps() async {
        for i in 1...3 {
            #expect(TimingDotView.diameter(forStepIndex: i) == 16)
        }
    }

    @Test("tested note index matches session's tested note index")
    func testedNoteIndex() async {
        #expect(TimingDotView.testedNoteIndex == TimingOffsetDetectionSession.testedNoteIndex)
    }

    @Test("overlap offset is half the dot diameter")
    func overlapOffset() async {
        #expect(abs(TimingDotView.overlapOffset - TimingDotView.dotDiameter / 2) < 0.001)
    }

    @Test("tested note frame width is dot diameter plus overlap offset")
    func testedNoteFrameWidthIsDotDiameterPlusOverlapOffset() async {
        #expect(abs(TimingDotView.testedNoteFrameWidth - (TimingDotView.dotDiameter + TimingDotView.overlapOffset)) < 0.001)
    }

    @Test("isTestedNote returns true only for index 2")
    func isTestedNote() async {
        #expect(TimingDotView.isTestedNote(index: 0) == false)
        #expect(TimingDotView.isTestedNote(index: 1) == false)
        #expect(TimingDotView.isTestedNote(index: 2) == true)
        #expect(TimingDotView.isTestedNote(index: 3) == false)
    }
}
