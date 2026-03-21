import Testing
@testable import Peach

@Suite("RhythmDotView Tests")
struct RhythmDotViewTests {

    @Test("dot diameter is 16pt")
    func dotDiameter() async {
        #expect(RhythmDotView.dotDiameter == 16)
    }

    @Test("dot spacing is 24pt")
    func dotSpacing() async {
        #expect(RhythmDotView.dotSpacing == 24)
    }
}
