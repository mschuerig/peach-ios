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

    @Test("formatCompactEWMA renders the cent symbol for pitch disciplines")
    func formatCompactEWMAIncludesCentSign() async {
        let result = ProgressSparklineView.formatCompactEWMA(8.2, unitSymbol: "¢")
        #expect(result.contains("¢"))
        #expect(result.contains("8"))
    }

    @Test("formatCompactEWMA handles zero value")
    func formatCompactEWMAZero() async {
        let result = ProgressSparklineView.formatCompactEWMA(0.0, unitSymbol: "¢")
        #expect(result.contains("0"))
        #expect(result.contains("¢"))
    }

    @Test("formatCompactEWMA renders milliseconds for timing disciplines, never cents")
    func formatCompactEWMAUsesMillisecondsForTiming() async {
        let result = ProgressSparklineView.formatCompactEWMA(80.5, unitSymbol: "ms")
        #expect(result.contains("ms"), "got \(result)")
        #expect(!result.contains("¢"), "got \(result)")
        // Decimal separator is locale-dependent; assert only the stable digits.
        #expect(result.contains("80"), "got \(result)")
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

    @Test("sparklineAccessibilityLabel speaks milliseconds for timing disciplines")
    func accessibilityLabelTiming() async {
        let label = ProgressSparklineView.sparklineAccessibilityLabel(
            modeName: "Compare Timing",
            ewma: 80.5,
            trend: .improving,
            unitLabel: "ms"
        )
        #expect(label.contains("Compare Timing"), "got \(label)")
        // Decimal separator is locale-dependent; assert only the stable digits.
        #expect(label.contains("80"), "got \(label)")
        #expect(label.contains("ms"), "got \(label)")
        #expect(!label.contains("¢"), "got \(label)")
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
            unitLabel: "cents",
            unitSymbol: "¢"
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
            unitLabel: "cents",
            unitSymbol: "¢"
        )
    }
}
