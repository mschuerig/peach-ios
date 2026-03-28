import Testing
import SwiftUI
@testable import Peach

@Suite("ProgressSparklineView Tests")
struct ProgressSparklineViewTests {

    // MARK: - sparklineColor Tests

    @Test("sparklineColor returns green for improving trend")
    func sparklineColorImproving() async {
        let color = ProgressSparklineView.sparklineColor(for: .improving)
        #expect(color == .green)
    }

    @Test("sparklineColor returns orange for stable trend")
    func sparklineColorStable() async {
        let color = ProgressSparklineView.sparklineColor(for: .stable)
        #expect(color == .orange)
    }

    @Test("sparklineColor returns secondary for declining trend")
    func sparklineColorDeclining() async {
        let color = ProgressSparklineView.sparklineColor(for: .declining)
        #expect(color == .secondary)
    }

    @Test("sparklineColor returns secondary for nil trend")
    func sparklineColorNil() async {
        let color = ProgressSparklineView.sparklineColor(for: nil)
        #expect(color == .secondary)
    }

    // MARK: - formatCompactEWMA Tests

    @Test("formatCompactEWMA includes cent sign")
    func formatCompactEWMAIncludesCentSign() async {
        let result = ProgressSparklineView.formatCompactEWMA(8.2)
        #expect(result.contains("¢"))
        #expect(result.contains("8"))
    }

    @Test("formatCompactEWMA handles zero value")
    func formatCompactEWMAZero() async {
        let result = ProgressSparklineView.formatCompactEWMA(0.0)
        #expect(result.contains("0"))
        #expect(result.contains("¢"))
    }

    // MARK: - sparklineAccessibilityLabel Tests

    @Test("sparklineAccessibilityLabel combines mode name, value, and trend")
    func accessibilityLabelImproving() async {
        let label = ProgressSparklineView.sparklineAccessibilityLabel(
            modeName: "Compare Pitch",
            ewma: 8.2,
            trend: .improving,
            unitLabel: "cents"
        )
        #expect(label.contains("Compare Pitch"))
        #expect(label.contains("8"))
        #expect(label.contains("cents"))
    }

    @Test("sparklineAccessibilityLabel works for stable trend")
    func accessibilityLabelStable() async {
        let label = ProgressSparklineView.sparklineAccessibilityLabel(
            modeName: "Match Intervals",
            ewma: 12.0,
            trend: .stable,
            unitLabel: "cents"
        )
        #expect(label.contains("Match Intervals"))
        #expect(label.contains("12"))
    }

    // MARK: - Value-type parameter isolation

    @Test("initializer accepts precomputed value-type parameters without environment dependency")
    func initializerAcceptsValueTypes() async {
        // Verifies the view can be created with value-type parameters
        // and does not require @Environment(\.progressTimeline)
        let _ = ProgressSparklineView(
            state: .active,
            bucketMeans: [10.0, 8.0, 6.0],
            ewma: 8.0,
            trend: .improving,
            modeName: "Compare Pitch",
            unitLabel: "cents"
        )
    }

    @Test("initializer accepts noData state")
    func initializerAcceptsNoDataState() async {
        let _ = ProgressSparklineView(
            state: .noData,
            bucketMeans: [],
            ewma: nil,
            trend: nil,
            modeName: "Compare Pitch",
            unitLabel: "cents"
        )
    }
}
