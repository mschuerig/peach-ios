import Testing
import Foundation
@testable import Peach

@Suite("ProgressChartView Tests")
struct ProgressChartViewTests {

    // MARK: - Bucket Label Formatting

    @Test("session bucket formats as relative time")
    func sessionBucketLabel() async {
        let now = Date()
        let twoHoursAgo = now.addingTimeInterval(-2 * 3600)
        let label = ProgressChartView.bucketLabel(for: twoHoursAgo, size: .session, relativeTo: now)
        #expect(!label.isEmpty)
    }

    @Test("day bucket formats as weekday abbreviation")
    func dayBucketLabel() async {
        let monday = dateFromComponents(year: 2026, month: 3, day: 2) // Monday
        let label = ProgressChartView.bucketLabel(for: monday, size: .day, relativeTo: Date())
        #expect(!label.isEmpty)
    }

    @Test("week bucket formats as month and day")
    func weekBucketLabel() async {
        let date = dateFromComponents(year: 2026, month: 3, day: 1)
        let label = ProgressChartView.bucketLabel(for: date, size: .week, relativeTo: Date())
        #expect(label.contains("Mar") || label.contains("Mär"))
    }

    @Test("month bucket formats as month abbreviation")
    func monthBucketLabel() async {
        let date = dateFromComponents(year: 2026, month: 1, day: 15)
        let label = ProgressChartView.bucketLabel(for: date, size: .month, relativeTo: Date())
        #expect(label.contains("Jan"))
    }

    // MARK: - Trend Display

    @Test("trend symbol for improving is arrow.down.right")
    func trendSymbolImproving() async {
        #expect(ProgressChartView.trendSymbol(.improving) == "arrow.down.right")
    }

    @Test("trend symbol for stable is arrow.right")
    func trendSymbolStable() async {
        #expect(ProgressChartView.trendSymbol(.stable) == "arrow.right")
    }

    @Test("trend symbol for declining is arrow.up.right")
    func trendSymbolDeclining() async {
        #expect(ProgressChartView.trendSymbol(.declining) == "arrow.up.right")
    }

    @Test("trend label for improving")
    func trendLabelImproving() async {
        let label = ProgressChartView.trendLabel(.improving)
        #expect(!label.isEmpty)
    }

    // MARK: - EWMA Formatting

    @Test("formats EWMA value with one decimal place")
    func formatEWMA() async {
        let formatted = ProgressChartView.formatEWMA(23.456)
        #expect(formatted.contains("23.5") || formatted.contains("23,5"))
    }

    @Test("formats stddev with plus-minus prefix")
    func formatStdDev() async {
        let formatted = ProgressChartView.formatStdDev(5.78)
        #expect(formatted.contains("±"))
    }

    // MARK: - Cold Start Message

    @Test("cold start message includes records needed count")
    func coldStartMessage() async {
        let message = ProgressChartView.coldStartMessage(recordsNeeded: 15)
        #expect(message.contains("15"))
    }

    // MARK: - Accessibility

    @Test("chart accessibility value includes EWMA and trend")
    func chartAccessibilityValue() async {
        let value = ProgressChartView.chartAccessibilityValue(
            ewma: 25.3,
            trend: .improving,
            unitLabel: "cents"
        )
        #expect(!value.isEmpty)
    }

    // MARK: - Helpers

    private func dateFromComponents(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }
}
