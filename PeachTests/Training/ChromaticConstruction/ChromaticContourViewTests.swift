import Testing
import CoreGraphics
@testable import Peach

@Suite("ChromaticContourView layout helpers")
struct ChromaticContourViewTests {

    private let drawable = CGRect(x: 0, y: 0, width: 400, height: 200)

    @Test("ascending P5 outerCents is +700")
    func ascendingP5OuterCents() throws {
        let path = try ChromaticPath(
            lowerAnchor: MIDINote(60),
            outerInterval: .up(.perfectFifth),
            steps: Array(repeating: .up, count: 7)
        )
        #expect(ChromaticContourView.outerCents(path).rawValue == 700)
    }

    @Test("descending P5 outerCents is -700")
    func descendingP5OuterCents() throws {
        let path = try ChromaticPath(
            lowerAnchor: MIDINote(60),
            outerInterval: .down(.perfectFifth),
            steps: Array(repeating: .down, count: 7)
        )
        #expect(ChromaticContourView.outerCents(path).rawValue == -700)
    }

    @Test("ascending step 0 is at drawable leftmost x and bottom y")
    func ascendingStartPointIsLowerLeft() throws {
        let path = try ChromaticPath(
            lowerAnchor: MIDINote(60),
            outerInterval: .up(.perfectFifth),
            steps: Array(repeating: .up, count: 7)
        )
        let p = ChromaticContourView.renderedPoint(forStepIndex: 0, cents: Cents(0), path: path, in: drawable)
        #expect(p.x == drawable.minX)
        #expect(p.y == drawable.maxY)
    }

    @Test("ascending step N+1 is at drawable rightmost x and top y")
    func ascendingEndPointIsUpperRight() throws {
        let path = try ChromaticPath(
            lowerAnchor: MIDINote(60),
            outerInterval: .up(.perfectFifth),
            steps: Array(repeating: .up, count: 7)
        )
        let end = path.interiorPositionCount + 1
        let p = ChromaticContourView.renderedPoint(forStepIndex: end, cents: Cents(700), path: path, in: drawable)
        #expect(p.x == drawable.maxX)
        #expect(p.y == drawable.minY)
    }

    @Test("descending step 0 (lower anchor) renders at drawable leftmost top")
    func descendingStartPointIsUpperLeft() throws {
        let path = try ChromaticPath(
            lowerAnchor: MIDINote(60),
            outerInterval: .down(.perfectFifth),
            steps: Array(repeating: .down, count: 7)
        )
        let p = ChromaticContourView.renderedPoint(forStepIndex: 0, cents: Cents(0), path: path, in: drawable)
        #expect(p.x == drawable.minX)
        #expect(p.y == drawable.minY)
    }

    @Test("meandering net-zero path pins y to drawable midpoint instead of dividing by zero")
    func meanderingNetZeroPathPinsYToMidpoint() throws {
        let path = try ChromaticPath(
            lowerAnchor: MIDINote(60),
            outerInterval: .prime,
            steps: [.up, .down]
        )
        let p = ChromaticContourView.renderedPoint(forStepIndex: 1, cents: Cents(50), path: path, in: drawable)
        #expect(p.x == drawable.width * 0.5)
        #expect(p.y == drawable.midY)
        #expect(p.y.isNaN == false)
    }

    @Test("slider clamp confines drag values to ±sliderRangeCents around prior")
    func sliderClampSymmetricAroundPrior() {
        let prior = Cents(200)
        let inside = ChromaticContourView.clamp(Cents(250), around: prior)
        let aboveUpper = ChromaticContourView.clamp(Cents(700), around: prior)
        let belowLower = ChromaticContourView.clamp(Cents(-500), around: prior)
        #expect(inside.rawValue == 250)
        #expect(aboveUpper.rawValue == 200 + ChromaticContourView.sliderRangeCents.rawValue)
        #expect(belowLower.rawValue == 200 - ChromaticContourView.sliderRangeCents.rawValue)
    }

    @Test("centsPerDragPoint matches the declared 600 / sliderTrackHeight")
    func centsPerDragPointMatchesDeclaredResolution() {
        let expected = 600.0 / Double(ChromaticContourView.sliderTrackHeight)
        #expect(ChromaticContourView.centsPerDragPoint == expected)
    }

    @Test("descending step N+1 lands at drawable rightmost bottom")
    func descendingEndPointIsLowerRight() throws {
        let path = try ChromaticPath(
            lowerAnchor: MIDINote(60),
            outerInterval: .down(.perfectFifth),
            steps: Array(repeating: .down, count: 7)
        )
        let end = path.interiorPositionCount + 1
        let p = ChromaticContourView.renderedPoint(forStepIndex: end, cents: Cents(-700), path: path, in: drawable)
        #expect(p.x == drawable.maxX)
        #expect(p.y == drawable.maxY)
    }

    @Test("drawableRect insets vertically by drawableInsetVertical on both sides")
    func drawableRectInsets() {
        let containerSize = CGSize(width: 400, height: 320)
        let rect = ChromaticContourView.drawableRect(in: containerSize)
        #expect(rect.minY == ChromaticContourView.drawableInsetVertical)
        #expect(rect.height == 320 - ChromaticContourView.drawableInsetVertical * 2)
        #expect(rect.width == 400)
    }
}
