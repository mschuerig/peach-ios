import Testing
@testable import Peach

@Suite("RhythmDotView Tests")
struct RhythmDotViewTests {

    @Test("dot diameter is 16pt")
    func dotDiameter() async {
        #expect(RhythmDotView.dotDiameter == 16)
    }

    @Test("beat one dot diameter is 22pt")
    func beatOneDotDiameter() async {
        #expect(RhythmDotView.beatOneDotDiameter == 22)
    }

    @Test("dot spacing is 24pt")
    func dotSpacing() async {
        #expect(RhythmDotView.dotSpacing == 24)
    }

    @Test("diameter for step index 0 returns beat one diameter")
    func diameterForFirstStep() async {
        #expect(RhythmDotView.diameter(forStepIndex: 0) == 22)
    }

    @Test("diameter for step indices 1-3 returns standard diameter")
    func diameterForOtherSteps() async {
        for i in 1...3 {
            #expect(RhythmDotView.diameter(forStepIndex: i) == 16)
        }
    }

    @Test("tested note index matches session's tested note index")
    func testedNoteIndex() async {
        #expect(RhythmDotView.testedNoteIndex == RhythmOffsetDetectionSession.testedNoteIndex)
    }

    @Test("overlap offset is half the dot diameter")
    func overlapOffset() async {
        #expect(abs(RhythmDotView.overlapOffset - RhythmDotView.dotDiameter / 2) < 0.001)
    }

    @Test("tested note frame width is dot diameter plus overlap offset")
    func testedNoteFrameWidthIsDotDiameterPlusOverlapOffset() async {
        #expect(abs(RhythmDotView.testedNoteFrameWidth - (RhythmDotView.dotDiameter + RhythmDotView.overlapOffset)) < 0.001)
    }

    @Test("isTestedNote returns true only for index 2")
    func isTestedNote() async {
        #expect(RhythmDotView.isTestedNote(index: 0) == false)
        #expect(RhythmDotView.isTestedNote(index: 1) == false)
        #expect(RhythmDotView.isTestedNote(index: 2) == true)
        #expect(RhythmDotView.isTestedNote(index: 3) == false)
    }
}
