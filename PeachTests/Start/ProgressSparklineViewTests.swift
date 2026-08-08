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

    @Test("accessibility value combines value, unit, and trend without repeating the discipline name")
    func accessibilityValueImproving() async throws {
        let value = try #require(ProgressSparklineView.sparklineAccessibilityValue(
            ewma: 8.2,
            trend: .improving,
            config: Self.makeConfig()
        ))
        #expect(value.contains("8"), "got \(value)")
        // Spoken form, not the compact glyph: VoiceOver reads "¢" as a
        // currency symbol and "ms" as two letters.
        #expect(value.contains("cents"), "got \(value)")
        #expect(!value.contains("¢"), "got \(value)")
        #expect(value.contains(TrainingStatsView.trendLabel(.improving)), "got \(value)")
    }

    @Test("accessibility value speaks the timing unit and never cents")
    func accessibilityValueTiming() async throws {
        let value = try #require(ProgressSparklineView.sparklineAccessibilityValue(
            ewma: 80.5,
            trend: .improving,
            config: Self.makeConfig(unitLabel: "milliseconds", unitSymbol: "ms")
        ))
        // Decimal separator is locale-dependent; assert only the stable digits.
        #expect(value.contains("80"), "got \(value)")
        #expect(value.contains("milliseconds"), "got \(value)")
        #expect(!value.contains("¢"), "got \(value)")
    }

    @Test("accessibility value omits the trend clause when no trend has been computed")
    func accessibilityValueWithoutTrend() async throws {
        let value = try #require(ProgressSparklineView.sparklineAccessibilityValue(
            ewma: 8.2,
            trend: nil,
            config: Self.makeConfig()
        ))
        #expect(value.contains("cents"), "got \(value)")
        // A single record yields no trend; announcing "Stable" would assert a
        // trend that was never computed.
        #expect(!value.contains(TrainingStatsView.trendLabel(.stable)), "got \(value)")
    }

    @Test("accessibility value is absent when there is no measurement to announce")
    func accessibilityValueWithoutEWMA() async {
        let value = ProgressSparklineView.sparklineAccessibilityValue(
            ewma: nil,
            trend: nil,
            config: Self.makeConfig()
        )
        #expect(value == nil)
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
            config: Self.makeConfig()
        )
    }

    @Test("initializer accepts noData state")
    func initializerAcceptsNoDataState() async {
        let _ = ProgressSparklineView(
            state: .noData,
            bucketMeans: [],
            ewma: nil,
            trend: nil,
            config: Self.makeConfig()
        )
    }

    // MARK: - Fixtures

    private static func makeConfig(
        unitLabel: String = "cents",
        unitSymbol: String = "¢"
    ) -> TrainingDisciplineConfig {
        TrainingDisciplineConfig(
            displayName: "Compare Pitch",
            shortLabel: "Compare",
            systemImageName: "ear",
            isHero: true,
            helpDescription: "",
            unitLabel: unitLabel,
            unitSymbol: unitSymbol,
            optimalBaseline: 8.0,
            statistics: .default
        )
    }
}
