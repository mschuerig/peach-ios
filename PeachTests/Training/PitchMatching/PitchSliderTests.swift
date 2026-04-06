import Foundation
import Testing
@testable import Peach

@Suite("PitchSlider")
struct PitchSliderTests {

    // MARK: - Vertical value Tests

    @Test("vertical: center drag position yields zero value")
    func verticalCenterDragYieldsZeroValue() async {
        let value = PitchSlider.value(dragPosition: 200, trackLength: 400, isHorizontal: false)
        #expect(value == 0)
    }

    @Test("vertical: top of track yields +1.0 (sharper)")
    func verticalTopOfTrackYieldsPositiveOne() async {
        let value = PitchSlider.value(dragPosition: 0, trackLength: 400, isHorizontal: false)
        #expect(value == 1.0)
    }

    @Test("vertical: bottom of track yields -1.0 (flatter)")
    func verticalBottomOfTrackYieldsNegativeOne() async {
        let value = PitchSlider.value(dragPosition: 400, trackLength: 400, isHorizontal: false)
        #expect(value == -1.0)
    }

    @Test("vertical: quarter from top yields +0.5")
    func verticalQuarterFromTopYieldsHalf() async {
        let value = PitchSlider.value(dragPosition: 100, trackLength: 400, isHorizontal: false)
        #expect(value == 0.5)
    }

    @Test("vertical: drag beyond top clamps to +1.0")
    func verticalDragBeyondTopClampsToPositiveOne() async {
        let value = PitchSlider.value(dragPosition: -50, trackLength: 400, isHorizontal: false)
        #expect(value == 1.0)
    }

    @Test("vertical: drag beyond bottom clamps to -1.0")
    func verticalDragBeyondBottomClampsToNegativeOne() async {
        let value = PitchSlider.value(dragPosition: 450, trackLength: 400, isHorizontal: false)
        #expect(value == -1.0)
    }

    @Test("vertical: zero track length returns zero")
    func verticalZeroTrackLengthReturnsZero() async {
        let value = PitchSlider.value(dragPosition: 100, trackLength: 0, isHorizontal: false)
        #expect(value == 0)
    }

    @Test("horizontal: zero track length returns zero")
    func horizontalZeroTrackLengthReturnsZero() async {
        let value = PitchSlider.value(dragPosition: 100, trackLength: 0, isHorizontal: true)
        #expect(value == 0)
    }

    // MARK: - Vertical thumbPosition Tests

    @Test("vertical: zero value places thumb at center")
    func verticalZeroValuePlacesThumbAtCenter() async {
        let pos = PitchSlider.thumbPosition(value: 0, trackLength: 400, isHorizontal: false)
        #expect(abs(pos - 200) < 0.001)
    }

    @Test("vertical: +1.0 value places thumb at top")
    func verticalPositiveOneValuePlacesThumbAtTop() async {
        let pos = PitchSlider.thumbPosition(value: 1.0, trackLength: 400, isHorizontal: false)
        #expect(pos < 0.001)
    }

    @Test("vertical: -1.0 value places thumb at bottom")
    func verticalNegativeOneValuePlacesThumbAtBottom() async {
        let pos = PitchSlider.thumbPosition(value: -1.0, trackLength: 400, isHorizontal: false)
        #expect(abs(pos - 400) < 0.001)
    }

    @Test("vertical: +0.5 value places thumb at quarter from top")
    func verticalHalfValuePlacesThumbAtQuarterFromTop() async {
        let pos = PitchSlider.thumbPosition(value: 0.5, trackLength: 400, isHorizontal: false)
        #expect(abs(pos - 100) < 0.001)
    }

    // MARK: - Vertical Round-trip consistency

    @Test("vertical: value and thumbPosition are inverse operations")
    func verticalValueAndThumbPositionAreInverse() async {
        let trackLength: CGFloat = 600
        let originalPosition: CGFloat = 150

        let normalized = PitchSlider.value(dragPosition: originalPosition, trackLength: trackLength, isHorizontal: false)
        let recovered = PitchSlider.thumbPosition(value: normalized, trackLength: trackLength, isHorizontal: false)

        #expect(abs(recovered - originalPosition) < 0.001)
    }

    // MARK: - Horizontal value Tests

    @Test("horizontal: center drag position yields zero value")
    func horizontalCenterDragYieldsZeroValue() async {
        let value = PitchSlider.value(dragPosition: 200, trackLength: 400, isHorizontal: true)
        #expect(value == 0)
    }

    @Test("horizontal: left edge yields -1.0 (flatter)")
    func horizontalLeftEdgeYieldsNegativeOne() async {
        let value = PitchSlider.value(dragPosition: 0, trackLength: 400, isHorizontal: true)
        #expect(value == -1.0)
    }

    @Test("horizontal: right edge yields +1.0 (sharper)")
    func horizontalRightEdgeYieldsPositiveOne() async {
        let value = PitchSlider.value(dragPosition: 400, trackLength: 400, isHorizontal: true)
        #expect(value == 1.0)
    }

    @Test("horizontal: quarter from left yields -0.5")
    func horizontalQuarterFromLeftYieldsNegativeHalf() async {
        let value = PitchSlider.value(dragPosition: 100, trackLength: 400, isHorizontal: true)
        #expect(value == -0.5)
    }

    @Test("horizontal: drag beyond left clamps to -1.0")
    func horizontalDragBeyondLeftClampsToNegativeOne() async {
        let value = PitchSlider.value(dragPosition: -50, trackLength: 400, isHorizontal: true)
        #expect(value == -1.0)
    }

    @Test("horizontal: drag beyond right clamps to +1.0")
    func horizontalDragBeyondRightClampsToPositiveOne() async {
        let value = PitchSlider.value(dragPosition: 450, trackLength: 400, isHorizontal: true)
        #expect(value == 1.0)
    }

    // MARK: - Horizontal thumbPosition Tests

    @Test("horizontal: zero value places thumb at center")
    func horizontalZeroValuePlacesThumbAtCenter() async {
        let pos = PitchSlider.thumbPosition(value: 0, trackLength: 400, isHorizontal: true)
        #expect(abs(pos - 200) < 0.001)
    }

    @Test("horizontal: +1.0 value places thumb at right edge")
    func horizontalPositiveOneValuePlacesThumbAtRight() async {
        let pos = PitchSlider.thumbPosition(value: 1.0, trackLength: 400, isHorizontal: true)
        #expect(abs(pos - 400) < 0.001)
    }

    @Test("horizontal: -1.0 value places thumb at left edge")
    func horizontalNegativeOneValuePlacesThumbAtLeft() async {
        let pos = PitchSlider.thumbPosition(value: -1.0, trackLength: 400, isHorizontal: true)
        #expect(pos < 0.001)
    }

    @Test("horizontal: +0.5 value places thumb at three-quarters from left")
    func horizontalHalfValuePlacesThumbAtThreeQuarters() async {
        let pos = PitchSlider.thumbPosition(value: 0.5, trackLength: 400, isHorizontal: true)
        #expect(abs(pos - 300) < 0.001)
    }

    // MARK: - Horizontal Round-trip consistency

    @Test("horizontal: value and thumbPosition are inverse operations")
    func horizontalValueAndThumbPositionAreInverse() async {
        let trackLength: CGFloat = 600
        let originalPosition: CGFloat = 150

        let normalized = PitchSlider.value(dragPosition: originalPosition, trackLength: trackLength, isHorizontal: true)
        let recovered = PitchSlider.thumbPosition(value: normalized, trackLength: trackLength, isHorizontal: true)

        #expect(abs(recovered - originalPosition) < 0.001)
    }
}
