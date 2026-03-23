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
}
