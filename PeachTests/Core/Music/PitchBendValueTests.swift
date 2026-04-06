import Testing
@testable import Peach

@Suite("PitchBendValue Tests")
struct PitchBendValueTests {

    @Test("Creates valid pitch bend at boundaries")
    func validBoundaries() async {
        let low = PitchBendValue(0)
        let high = PitchBendValue(16383)

        #expect(low.rawValue == 0)
        #expect(high.rawValue == 16383)
    }

    @Test("Center value is 8192")
    func center() async {
        #expect(PitchBendValue.center.rawValue == 8192)
    }

    @Test("Integer literal creates PitchBendValue")
    func integerLiteral() async {
        let bend: PitchBendValue = 8192
        #expect(bend.rawValue == 8192)
    }

    @Test("Equal values have same hash")
    func hashable() async {
        let set: Set<PitchBendValue> = [PitchBendValue(0), PitchBendValue(0), PitchBendValue(8192)]
        #expect(set.count == 2)
    }

    // MARK: - Clamping Initializer

    @Test("Clamping initializer clamps value below 0 to 0")
    func clampingBelowMinimum() async {
        let bend = PitchBendValue(clamping: -100)
        #expect(bend.rawValue == 0)
    }

    @Test("Clamping initializer clamps value above 16383 to 16383")
    func clampingAboveMaximum() async {
        let bend = PitchBendValue(clamping: 20000)
        #expect(bend.rawValue == 16383)
    }

    @Test("Clamping initializer passes through valid value")
    func clampingValidValue() async {
        let bend = PitchBendValue(clamping: 8192)
        #expect(bend.rawValue == 8192)
    }

    @Test("Clamping initializer passes through boundary values")
    func clampingBoundaryValues() async {
        #expect(PitchBendValue(clamping: 0).rawValue == 0)
        #expect(PitchBendValue(clamping: 16383).rawValue == 16383)
    }

    // MARK: - Normalized Slider Value

    @Test("normalizedSliderValue maps 0 to -1.0")
    func normalizedSliderValueMinimum() async {
        let bend = PitchBendValue(0)
        #expect(bend.normalizedSliderValue == -1.0)
    }

    @Test("normalizedSliderValue maps 8192 to approximately 0.0")
    func normalizedSliderValueCenter() async {
        let bend = PitchBendValue(8192)
        #expect(abs(bend.normalizedSliderValue) < 0.0001)
    }

    @Test("normalizedSliderValue maps 16383 to +1.0")
    func normalizedSliderValueMaximum() async {
        let bend = PitchBendValue(16383)
        #expect(bend.normalizedSliderValue == 1.0)
    }

    // MARK: - Neutral Zone

    @Test("isInNeutralZone returns true for center value")
    func neutralZoneCenter() async {
        #expect(PitchBendValue(8192).isInNeutralZone)
    }

    @Test("isInNeutralZone returns true at lower boundary (8192 - 256 = 7936)")
    func neutralZoneLowerBoundary() async {
        #expect(PitchBendValue(7936).isInNeutralZone)
    }

    @Test("isInNeutralZone returns true at upper boundary (8192 + 256 = 8448)")
    func neutralZoneUpperBoundary() async {
        #expect(PitchBendValue(8448).isInNeutralZone)
    }

    @Test("isInNeutralZone returns false just below lower boundary (7935)")
    func neutralZoneBelowLower() async {
        #expect(!PitchBendValue(7935).isInNeutralZone)
    }

    @Test("isInNeutralZone returns false just above upper boundary (8449)")
    func neutralZoneAboveUpper() async {
        #expect(!PitchBendValue(8449).isInNeutralZone)
    }

    @Test("isInNeutralZone returns false at extremes")
    func neutralZoneExtremes() async {
        #expect(!PitchBendValue(0).isInNeutralZone)
        #expect(!PitchBendValue(16383).isInNeutralZone)
    }
}
