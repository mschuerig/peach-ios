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

    @Test("overlap offset is half the dot diameter")
    func overlapOffset() async {
        #expect(abs(TimingDotView.overlapOffset - TimingDotView.dotDiameter / 2) < 0.001)
    }

    @Test("tested note frame width is dot diameter plus overlap offset")
    func testedNoteFrameWidthIsDotDiameterPlusOverlapOffset() async {
        #expect(abs(TimingDotView.testedNoteFrameWidth - (TimingDotView.dotDiameter + TimingDotView.overlapOffset)) < 0.001)
    }

    // MARK: - offsetGridIndex(for:offsetNotePosition:)

    @Test("offsetGridIndex returns nil when offsetNotePosition is nil (picker preview)")
    func offsetGridIndexNilWhenPositionAbsent() async {
        let grid = TimingDotView.offsetGridIndex(
            for: .pattern1111,
            offsetNotePosition: nil
        )
        #expect(grid == nil)
    }

    @Test(
        "offsetGridIndex for pattern_1111 maps audible 1-based → grid 0-based identity",
        arguments: [(1, 0), (2, 1), (3, 2), (4, 3)]
    )
    func offsetGridIndexPattern1111Identity(input: (Int, Int)) async {
        let (audiblePosition, expectedGrid) = input
        let grid = TimingDotView.offsetGridIndex(
            for: .pattern1111,
            offsetNotePosition: OffsetNotePosition(audiblePosition)
        )
        #expect(grid == expectedGrid)
    }

    @Test("offsetGridIndex translates audible→grid via audibleToGrid for a rest-bearing pattern")
    func offsetGridIndexRestBearingTranslation() async {
        let pattern = TimingOffsetDetectionPattern.pattern1011

        // audible 2 → grid 2, audible 3 → grid 3 — NOT identity.
        // This is the deferred-work bug closed by 82.6: an old call site that
        // used `offsetNotePosition.zeroBasedIndex` would have produced grid 1
        // (a rest cell) for audible position 2.
        #expect(TimingDotView.offsetGridIndex(for: pattern, offsetNotePosition: OffsetNotePosition(2)) == 2)
        #expect(TimingDotView.offsetGridIndex(for: pattern, offsetNotePosition: OffsetNotePosition(3)) == 3)
    }

    @Test("offsetGridIndex returns nil when the audible position is out of range")
    func offsetGridIndexOutOfRange() async {
        // pattern_1010 has audibleCount == 2; audible position 3 is out of range.
        let grid = TimingDotView.offsetGridIndex(
            for: .pattern1010,
            offsetNotePosition: OffsetNotePosition(3)
        )
        #expect(grid == nil)
    }
}
