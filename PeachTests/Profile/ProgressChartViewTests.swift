import Testing
import Foundation
@testable import Peach

@Suite("ProgressChartView Tests")
struct ProgressChartViewTests {

    // MARK: - Y-Domain Computation

    @Test("computes Y domain from zero to max with stddev")
    func yDomainFromBuckets() async {
        let buckets = [
            TimeBucket(periodStart: Date(), periodEnd: Date(), bucketSize: .month, mean: 20.0, stddev: 5.0, recordCount: 10),
            TimeBucket(periodStart: Date(), periodEnd: Date(), bucketSize: .day, mean: 10.0, stddev: 3.0, recordCount: 5),
            TimeBucket(periodStart: Date(), periodEnd: Date(), bucketSize: .session, mean: 30.0, stddev: 8.0, recordCount: 3),
        ]
        let domain = ProgressChartView.yDomain(for: buckets)
        #expect(domain.lowerBound == 0.0)
        #expect(domain.upperBound == 38.0)
    }

    @Test("Y domain always starts at zero")
    func yDomainAlwaysStartsAtZero() async {
        let buckets = [
            TimeBucket(periodStart: Date(), periodEnd: Date(), bucketSize: .month, mean: 2.0, stddev: 5.0, recordCount: 10),
        ]
        let domain = ProgressChartView.yDomain(for: buckets)
        #expect(domain.lowerBound == 0.0)
        #expect(domain.upperBound == 7.0)
    }

    @Test("Y domain for empty buckets returns 0...1")
    func yDomainEmptyBuckets() async {
        let domain = ProgressChartView.yDomain(for: [])
        #expect(domain.lowerBound == 0.0)
        #expect(domain.upperBound == 1.0)
    }

    @Test("Y domain for single bucket with zero stddev")
    func yDomainSingleBucketZeroStddev() async {
        let buckets = [
            TimeBucket(periodStart: Date(), periodEnd: Date(), bucketSize: .day, mean: 15.0, stddev: 0.0, recordCount: 1),
        ]
        let domain = ProgressChartView.yDomain(for: buckets)
        #expect(domain.lowerBound == 0.0)
        #expect(domain.upperBound == 15.0)
    }

    // MARK: - Zone Config Dictionary

    @Test("zone configs contains month, day, and session")
    func zoneConfigsContainsExpectedKeys() async {
        let configs = ProgressChartView.zoneConfigs
        #expect(configs[.month] != nil)
        #expect(configs[.day] != nil)
        #expect(configs[.session] != nil)
    }

    @Test("zone config point widths match expected values")
    func zoneConfigPointWidths() async {
        let configs = ProgressChartView.zoneConfigs
        #expect(configs[.month]?.pointWidth == 30)
        #expect(configs[.day]?.pointWidth == 40)
        #expect(configs[.session]?.pointWidth == 50)
    }

    // MARK: - Initial Scroll Position

    @Test("initial scroll position places latest data at right edge")
    func initialScrollPositionPinsRight() async {
        let buckets = makeBucketArray(count: 30)
        let position = ProgressChartView.initialScrollPosition(for: buckets)
        // With 30 buckets and visibleBucketCount=8, should start at index 22
        #expect(position == Double(30 - ProgressChartView.visibleBucketCount))
    }

    @Test("initial scroll position for small dataset returns zero")
    func initialScrollPositionSmallDataset() async {
        let buckets = makeBucketArray(count: 5)
        let position = ProgressChartView.initialScrollPosition(for: buckets)
        #expect(position == 0)
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

    // MARK: - Zone Separator Metadata (Index-Based)

    @Test("returns zone separator data for three-zone buckets with correct indices")
    func zoneSeparatorsThreeZones() async {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        let buckets = [
            TimeBucket(periodStart: base, periodEnd: base.addingTimeInterval(3600), bucketSize: .month, mean: 10, stddev: 1, recordCount: 5),
            TimeBucket(periodStart: base.addingTimeInterval(86400), periodEnd: base.addingTimeInterval(86400 + 3600), bucketSize: .month, mean: 12, stddev: 1, recordCount: 5),
            TimeBucket(periodStart: base.addingTimeInterval(86400 * 2), periodEnd: base.addingTimeInterval(86400 * 2 + 3600), bucketSize: .day, mean: 8, stddev: 1, recordCount: 3),
            TimeBucket(periodStart: base.addingTimeInterval(86400 * 3), periodEnd: base.addingTimeInterval(86400 * 3 + 3600), bucketSize: .day, mean: 9, stddev: 1, recordCount: 3),
            TimeBucket(periodStart: base.addingTimeInterval(86400 * 4), periodEnd: base.addingTimeInterval(86400 * 4 + 3600), bucketSize: .session, mean: 7, stddev: 1, recordCount: 1),
        ]

        let separators = ProgressChartView.zoneSeparatorData(for: buckets)

        #expect(separators.zones.count == 3)
        #expect(separators.dividerIndices.count == 2)

        #expect(separators.zones[0].bucketSize == .month)
        #expect(separators.zones[0].startIndex == 0)
        #expect(separators.zones[0].endIndex == 1)

        #expect(separators.zones[1].bucketSize == .day)
        #expect(separators.zones[1].startIndex == 2)
        #expect(separators.zones[1].endIndex == 3)

        #expect(separators.zones[2].bucketSize == .session)
        #expect(separators.zones[2].startIndex == 4)
        #expect(separators.zones[2].endIndex == 4)

        // Divider indices at zone transitions
        #expect(separators.dividerIndices[0] == 2)
        #expect(separators.dividerIndices[1] == 4)
    }

    @Test("returns no zone separators for single-zone buckets")
    func zoneSeparatorsSingleZone() async {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        let buckets = [
            TimeBucket(periodStart: base, periodEnd: base.addingTimeInterval(3600), bucketSize: .day, mean: 10, stddev: 1, recordCount: 5),
            TimeBucket(periodStart: base.addingTimeInterval(86400), periodEnd: base.addingTimeInterval(86400 + 3600), bucketSize: .day, mean: 12, stddev: 1, recordCount: 5),
        ]

        let separators = ProgressChartView.zoneSeparatorData(for: buckets)
        #expect(separators.zones.isEmpty)
        #expect(separators.dividerIndices.isEmpty)
    }

    @Test("returns zone separator data for two-zone buckets")
    func zoneSeparatorsTwoZones() async {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        let buckets = [
            TimeBucket(periodStart: base, periodEnd: base.addingTimeInterval(3600), bucketSize: .month, mean: 10, stddev: 1, recordCount: 5),
            TimeBucket(periodStart: base.addingTimeInterval(86400), periodEnd: base.addingTimeInterval(86400 + 3600), bucketSize: .day, mean: 8, stddev: 1, recordCount: 3),
            TimeBucket(periodStart: base.addingTimeInterval(86400 * 2), periodEnd: base.addingTimeInterval(86400 * 2 + 3600), bucketSize: .day, mean: 9, stddev: 1, recordCount: 3),
        ]

        let separators = ProgressChartView.zoneSeparatorData(for: buckets)
        #expect(separators.zones.count == 2)
        #expect(separators.dividerIndices.count == 1)
        #expect(separators.dividerIndices[0] == 1)
    }

    @Test("returns no zone separators for empty buckets")
    func zoneSeparatorsEmpty() async {
        let separators = ProgressChartView.zoneSeparatorData(for: [])
        #expect(separators.zones.isEmpty)
        #expect(separators.dividerIndices.isEmpty)
    }

    // MARK: - Year Boundary Tests

    @Test("year boundary within monthly zone adds divider index")
    func yearBoundaryDivider() async {
        let calendar = Calendar.current
        // Monthly buckets spanning Oct 2025 through Feb 2026 — year boundary at index 3
        let oct2025 = calendar.date(from: DateComponents(year: 2025, month: 10, day: 1))!
        let nov2025 = calendar.date(from: DateComponents(year: 2025, month: 11, day: 1))!
        let dec2025 = calendar.date(from: DateComponents(year: 2025, month: 12, day: 1))!
        let jan2026 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let feb2026 = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        let mar2026 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!

        let buckets = [
            TimeBucket(periodStart: oct2025, periodEnd: nov2025, bucketSize: .month, mean: 10, stddev: 1, recordCount: 5),
            TimeBucket(periodStart: nov2025, periodEnd: dec2025, bucketSize: .month, mean: 11, stddev: 1, recordCount: 5),
            TimeBucket(periodStart: dec2025, periodEnd: jan2026, bucketSize: .month, mean: 12, stddev: 1, recordCount: 5),
            TimeBucket(periodStart: jan2026, periodEnd: feb2026, bucketSize: .month, mean: 13, stddev: 1, recordCount: 5),
            TimeBucket(periodStart: feb2026, periodEnd: mar2026, bucketSize: .month, mean: 14, stddev: 1, recordCount: 5),
            // Day zone starts at index 5 — far enough from year boundary at index 3
            TimeBucket(periodStart: mar2026, periodEnd: mar2026.addingTimeInterval(86400), bucketSize: .day, mean: 8, stddev: 1, recordCount: 3),
        ]

        let separators = ProgressChartView.zoneSeparatorData(for: buckets)
        // Zone divider at index 5 (month→day transition)
        // Year divider at index 3 (Dec 2025 → Jan 2026) — not near zone transition
        #expect(separators.dividerIndices.contains(3), "Year boundary between Dec 2025 and Jan 2026 should be a divider")
        #expect(separators.dividerIndices.contains(5), "Zone transition should be a divider")
    }

    @Test("year boundary within 1 index of zone transition is suppressed")
    func yearBoundaryDeduplication() async {
        let calendar = Calendar.current
        // Monthly bucket for Dec 2025, then zone transition immediately at Jan 2026 (day zone)
        let dec2025 = calendar.date(from: DateComponents(year: 2025, month: 12, day: 1))!
        let jan2026 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!

        let buckets = [
            TimeBucket(periodStart: dec2025, periodEnd: jan2026, bucketSize: .month, mean: 10, stddev: 1, recordCount: 5),
            // Zone transition at index 1 (day zone starts at Jan 2026)
            TimeBucket(periodStart: jan2026, periodEnd: jan2026.addingTimeInterval(86400), bucketSize: .day, mean: 8, stddev: 1, recordCount: 3),
        ]

        let separators = ProgressChartView.zoneSeparatorData(for: buckets)
        // Zone divider at index 1. Year boundary would also be at index 1 — should be deduplicated (only 1 divider).
        #expect(separators.dividerIndices.count == 1)
        #expect(separators.dividerIndices[0] == 1)
    }

    // MARK: - Year Label Tests

    @Test("year labels for monthly buckets spanning two years")
    func yearLabelsMultiYear() async {
        let calendar = Calendar.current
        let oct2025 = calendar.date(from: DateComponents(year: 2025, month: 10, day: 1))!
        let nov2025 = calendar.date(from: DateComponents(year: 2025, month: 11, day: 1))!
        let dec2025 = calendar.date(from: DateComponents(year: 2025, month: 12, day: 1))!
        let jan2026 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let feb2026 = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!

        let buckets = [
            TimeBucket(periodStart: oct2025, periodEnd: nov2025, bucketSize: .month, mean: 10, stddev: 1, recordCount: 5),
            TimeBucket(periodStart: nov2025, periodEnd: dec2025, bucketSize: .month, mean: 11, stddev: 1, recordCount: 5),
            TimeBucket(periodStart: dec2025, periodEnd: jan2026, bucketSize: .month, mean: 12, stddev: 1, recordCount: 5),
            TimeBucket(periodStart: jan2026, periodEnd: feb2026, bucketSize: .month, mean: 13, stddev: 1, recordCount: 5),
            // Day zone
            TimeBucket(periodStart: feb2026, periodEnd: feb2026.addingTimeInterval(86400), bucketSize: .day, mean: 8, stddev: 1, recordCount: 3),
        ]

        let labels = ProgressChartView.yearLabels(for: buckets)

        #expect(labels.count == 2)
        #expect(labels[0].year == 2025)
        #expect(labels[0].firstIndex == 0)
        #expect(labels[0].lastIndex == 2)
        #expect(labels[1].year == 2026)
        #expect(labels[1].firstIndex == 3)
        #expect(labels[1].lastIndex == 3)
    }

    @Test("year labels for monthly buckets within single year")
    func yearLabelsSingleYear() async {
        let calendar = Calendar.current
        let oct2025 = calendar.date(from: DateComponents(year: 2025, month: 10, day: 1))!
        let nov2025 = calendar.date(from: DateComponents(year: 2025, month: 11, day: 1))!
        let dec2025 = calendar.date(from: DateComponents(year: 2025, month: 12, day: 1))!

        let buckets = [
            TimeBucket(periodStart: oct2025, periodEnd: nov2025, bucketSize: .month, mean: 10, stddev: 1, recordCount: 5),
            TimeBucket(periodStart: nov2025, periodEnd: dec2025, bucketSize: .month, mean: 11, stddev: 1, recordCount: 5),
            // Day zone
            TimeBucket(periodStart: dec2025, periodEnd: dec2025.addingTimeInterval(86400), bucketSize: .day, mean: 8, stddev: 1, recordCount: 3),
        ]

        let labels = ProgressChartView.yearLabels(for: buckets)

        #expect(labels.count == 1)
        #expect(labels[0].year == 2025)
        #expect(labels[0].firstIndex == 0)
        #expect(labels[0].lastIndex == 1)
    }

    @Test("no year labels when no monthly zone exists")
    func yearLabelsNoMonthlyZone() async {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        let buckets = [
            TimeBucket(periodStart: base, periodEnd: base.addingTimeInterval(86400), bucketSize: .day, mean: 8, stddev: 1, recordCount: 3),
            TimeBucket(periodStart: base.addingTimeInterval(86400), periodEnd: base.addingTimeInterval(86400 * 2), bucketSize: .session, mean: 7, stddev: 1, recordCount: 1),
        ]

        let labels = ProgressChartView.yearLabels(for: buckets)
        #expect(labels.isEmpty)
    }

    // MARK: - Axis Label Formatting

    @Test("session zone first bucket shows Today label")
    func sessionFirstBucketShowsToday() async {
        let base = Date()
        let buckets = [
            TimeBucket(periodStart: base.addingTimeInterval(-86400), periodEnd: base, bucketSize: .day, mean: 10, stddev: 1, recordCount: 5),
            TimeBucket(periodStart: base, periodEnd: base.addingTimeInterval(3600), bucketSize: .session, mean: 7, stddev: 1, recordCount: 1),
            TimeBucket(periodStart: base.addingTimeInterval(3600), periodEnd: base.addingTimeInterval(7200), bucketSize: .session, mean: 8, stddev: 1, recordCount: 1),
        ]

        let firstSessionLabel = ProgressChartView.formatAxisLabel(buckets[1].periodStart, size: .session, index: 1, buckets: buckets)
        let secondSessionLabel = ProgressChartView.formatAxisLabel(buckets[2].periodStart, size: .session, index: 2, buckets: buckets)

        #expect(firstSessionLabel == String(localized: "Today"))
        #expect(secondSessionLabel == "")
    }

    @Test("month and day buckets return non-empty axis labels")
    func monthDayBucketsHaveLabels() async {
        let base = Date()
        let buckets = [
            TimeBucket(periodStart: base, periodEnd: base.addingTimeInterval(86400), bucketSize: .month, mean: 10, stddev: 1, recordCount: 5),
        ]

        let label = ProgressChartView.formatAxisLabel(base, size: .month, index: 0, buckets: buckets)
        #expect(!label.isEmpty)
        // Should not end with a trailing dot (German abbreviation fix)
        #expect(!label.hasSuffix("."))
    }

    // MARK: - annotationDateLabel

    @Test("annotation date label for month shows abbreviated month and year")
    func annotationDateLabelMonth() async {
        let calendar = Calendar.current
        let jan2026 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!
        let label = ProgressChartView.annotationDateLabel(jan2026, size: .month)
        #expect(label.contains("2026"))
        #expect(label.contains("Jan"))
    }

    @Test("annotation date label for day shows weekday and date")
    func annotationDateLabelDay() async {
        let calendar = Calendar.current
        // March 5, 2026 is a Thursday
        let mar5 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 5))!
        let label = ProgressChartView.annotationDateLabel(mar5, size: .day)
        #expect(label.contains("5"))
        // Verify weekday abbreviation is present (Thu/Do/etc. depending on locale)
        let weekdaySymbols = calendar.shortWeekdaySymbols
        let containsWeekday = weekdaySymbols.contains { label.contains($0.replacingOccurrences(of: ".", with: "")) }
        #expect(containsWeekday, "Expected label '\(label)' to contain a weekday abbreviation")
    }

    @Test("annotation date label for session shows time")
    func annotationDateLabelSession() async {
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 5, hour: 14, minute: 30))!
        let label = ProgressChartView.annotationDateLabel(date, size: .session)
        #expect(label.contains("14") || label.contains("2:30"))
    }

    // MARK: - findNearestBucketIndex

    @Test("snaps to exact bucket index when tapping directly on it")
    func findNearestBucketIndexExact() async {
        #expect(ProgressChartView.findNearestBucketIndex(atX: 0.0, bucketCount: 5) == 0)
        #expect(ProgressChartView.findNearestBucketIndex(atX: 3.0, bucketCount: 5) == 3)
        #expect(ProgressChartView.findNearestBucketIndex(atX: 4.0, bucketCount: 5) == 4)
    }

    @Test("snaps to nearest bucket index when tapping between data points")
    func findNearestBucketIndexRounds() async {
        #expect(ProgressChartView.findNearestBucketIndex(atX: 1.3, bucketCount: 5) == 1)
        #expect(ProgressChartView.findNearestBucketIndex(atX: 1.7, bucketCount: 5) == 2)
        #expect(ProgressChartView.findNearestBucketIndex(atX: 2.6, bucketCount: 5) == 3)
    }

    @Test("returns nil for negative X outside valid range")
    func findNearestBucketIndexNegative() async {
        #expect(ProgressChartView.findNearestBucketIndex(atX: -1.0, bucketCount: 5) == nil)
        #expect(ProgressChartView.findNearestBucketIndex(atX: -0.6, bucketCount: 5) == nil)
    }

    @Test("returns zero for X at -0.5 boundary (rounds to 0)")
    func findNearestBucketIndexAtBoundary() async {
        #expect(ProgressChartView.findNearestBucketIndex(atX: -0.5, bucketCount: 5) == 0)
        #expect(ProgressChartView.findNearestBucketIndex(atX: -0.4, bucketCount: 5) == 0)
    }

    @Test("returns nil for X at or beyond bucket count")
    func findNearestBucketIndexBeyondCount() async {
        #expect(ProgressChartView.findNearestBucketIndex(atX: 5.0, bucketCount: 5) == nil)
        #expect(ProgressChartView.findNearestBucketIndex(atX: 10.0, bucketCount: 5) == nil)
    }

    @Test("returns nil for empty bucket count")
    func findNearestBucketIndexEmpty() async {
        #expect(ProgressChartView.findNearestBucketIndex(atX: 0.0, bucketCount: 0) == nil)
    }

    // MARK: - Zone Accessibility Summary

    @Test("produces VoiceOver summary for monthly zone")
    func zoneAccessibilitySummaryMonthly() async throws {
        let calendar = Calendar.current
        let nov2025 = calendar.date(from: DateComponents(year: 2025, month: 11, day: 1))!
        let dec2025 = calendar.date(from: DateComponents(year: 2025, month: 12, day: 1))!
        let jan2026 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let feb2026 = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!

        let buckets = [
            TimeBucket(periodStart: nov2025, periodEnd: dec2025, bucketSize: .month, mean: 15.2, stddev: 2.0, recordCount: 10),
            TimeBucket(periodStart: dec2025, periodEnd: jan2026, bucketSize: .month, mean: 13.0, stddev: 1.5, recordCount: 8),
            TimeBucket(periodStart: jan2026, periodEnd: feb2026, bucketSize: .month, mean: 11.0, stddev: 1.0, recordCount: 12),
        ]
        let zone = ProgressChartView.ZoneInfo(bucketSize: .month, startIndex: 0, endIndex: 2)
        let config = TrainingDisciplineID.unisonPitchDiscrimination.config

        let summary = ProgressChartView.zoneAccessibilitySummary(buckets: buckets, zone: zone, config: config)

        let s = try #require(summary)
        #expect(s.contains("15.2") || s.contains("15,2"))
        #expect(s.contains("11") || s.contains("11,0"))
        #expect(s.contains("3 data points") || s.contains("3 Datenpunkte"))
    }

    @Test("produces VoiceOver summary for daily zone")
    func zoneAccessibilitySummaryDaily() async throws {
        let calendar = Calendar.current
        let mar5 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 5))!
        let mar6 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 6))!
        let mar7 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 7))!

        let buckets = [
            TimeBucket(periodStart: mar5, periodEnd: mar6, bucketSize: .day, mean: 10.0, stddev: 1.0, recordCount: 5),
            TimeBucket(periodStart: mar6, periodEnd: mar7, bucketSize: .day, mean: 9.0, stddev: 0.5, recordCount: 3),
        ]
        let zone = ProgressChartView.ZoneInfo(bucketSize: .day, startIndex: 0, endIndex: 1)
        let config = TrainingDisciplineID.unisonPitchDiscrimination.config

        let summary = ProgressChartView.zoneAccessibilitySummary(buckets: buckets, zone: zone, config: config)

        let s2 = try #require(summary)
        #expect(s2.contains("2 data points") || s2.contains("2 Datenpunkte"))
    }

    @Test("single-zone data returns one summary")
    func zoneAccessibilitySummarySingleBucket() async throws {
        let date = Date()
        let buckets = [
            TimeBucket(periodStart: date, periodEnd: date.addingTimeInterval(3600), bucketSize: .session, mean: 8.5, stddev: 0.5, recordCount: 3),
        ]
        let zone = ProgressChartView.ZoneInfo(bucketSize: .session, startIndex: 0, endIndex: 0)
        let config = TrainingDisciplineID.unisonPitchDiscrimination.config

        let summary = ProgressChartView.zoneAccessibilitySummary(buckets: buckets, zone: zone, config: config)

        let s3 = try #require(summary)
        #expect(s3.contains("1 data points") || s3.contains("1 Datenpunkte"))
    }

    @Test("empty zone returns nil accessibility summary")
    func zoneAccessibilitySummaryEmptyZone() async {
        let buckets: [TimeBucket] = []
        let zone = ProgressChartView.ZoneInfo(bucketSize: .month, startIndex: 0, endIndex: -1)
        let config = TrainingDisciplineID.unisonPitchDiscrimination.config

        let summary = ProgressChartView.zoneAccessibilitySummary(buckets: buckets, zone: zone, config: config)

        #expect(summary == nil)
    }

    @Test("out-of-bounds zone endIndex returns nil accessibility summary")
    func zoneAccessibilitySummaryOutOfBounds() async {
        let date = Date()
        let buckets = [
            TimeBucket(periodStart: date, periodEnd: date.addingTimeInterval(3600), bucketSize: .month, mean: 10.0, stddev: 1.0, recordCount: 5),
        ]
        let zone = ProgressChartView.ZoneInfo(bucketSize: .month, startIndex: 0, endIndex: 5)
        let config = TrainingDisciplineID.unisonPitchDiscrimination.config

        let summary = ProgressChartView.zoneAccessibilitySummary(buckets: buckets, zone: zone, config: config)

        #expect(summary == nil)
    }

    // MARK: - Contrast Adjusted Opacity

    @Test("returns base opacity when standard contrast")
    func contrastAdjustedOpacityStandard() async {
        let result = ProgressChartView.contrastAdjustedOpacity(base: 0.15, increased: 0.3, isIncreaseContrast: false)
        #expect(result == 0.15)
    }

    @Test("returns higher opacity when increase contrast is enabled")
    func contrastAdjustedOpacityIncreased() async {
        let result = ProgressChartView.contrastAdjustedOpacity(base: 0.15, increased: 0.3, isIncreaseContrast: true)
        #expect(result == 0.3)
    }

    // MARK: - Performance: Bucket Count

    @Test("allGranularityBuckets with 365 days of data produces fewer than 2000 buckets")
    func bucketCountFor365Days() async {
        let timeline = makeTimeline(dayCount: 365, recordsPerDay: 5)
        let buckets = timeline.allGranularityBuckets(for: .unisonPitchDiscrimination)
        #expect(buckets.count < 2000)
    }

    @Test("allGranularityBuckets with 1000 days of data produces fewer than 2000 buckets")
    func bucketCountFor1000Days() async {
        let timeline = makeTimeline(dayCount: 1000, recordsPerDay: 5)
        let buckets = timeline.allGranularityBuckets(for: .unisonPitchDiscrimination)
        #expect(buckets.count < 2000)
    }

    @Test("session zone is limited to today only")
    func sessionZoneLimitedToToday() async {
        let timeline = makeTimeline(dayCount: 30, recordsPerDay: 5)
        let buckets = timeline.allGranularityBuckets(for: .unisonPitchDiscrimination)
        let sessionBuckets = buckets.filter { $0.bucketSize == .session }
        let startOfToday = Calendar.current.startOfDay(for: Date())
        for bucket in sessionBuckets {
            #expect(bucket.periodStart >= startOfToday)
        }
    }

    // MARK: - Share Button Accessibility Labels

    @Test("share accessibility label contains mode display name and is non-empty for all training modes",
          arguments: TrainingDisciplineID.allCases)
    func shareAccessibilityLabel(mode: TrainingDisciplineID) async {
        let label = String(localized: "Share \(mode.config.displayName) chart")
        #expect(!label.isEmpty)
        #expect(label.contains(mode.config.displayName),
                "Expected label to contain '\(mode.config.displayName)' but got: \(label)")
        // Verify the label is distinct per mode (not a generic fallback)
        let otherModes = TrainingDisciplineID.allCases.filter { $0 != mode }
        for other in otherModes {
            let otherLabel = String(localized: "Share \(other.config.displayName) chart")
            #expect(label != otherLabel, "Labels for \(mode) and \(other) should differ")
        }
    }

    // MARK: - Helpers

    private func makeBucketArray(count: Int) -> [TimeBucket] {
        let now = Date()
        return (0..<count).map { i in
            TimeBucket(
                periodStart: now.addingTimeInterval(Double(i) * -86400),
                periodEnd: now.addingTimeInterval(Double(i) * -86400 + 3600),
                bucketSize: .day,
                mean: Double(i),
                stddev: 1.0,
                recordCount: 5
            )
        }
    }

    private func makeTimeline(dayCount: Int, recordsPerDay: Int) -> ProgressTimeline {
        let now = Date()
        let profile = PerceptualProfile { builder in
            for day in 0..<dayCount {
                for record in 0..<recordsPerDay {
                    let timestamp = now.addingTimeInterval(Double(-day) * 86400 + Double(record) * 60)
                    builder.addPoint(
                        MetricPoint(timestamp: timestamp, value: Double.random(in: 5...25)),
                        for: .pitch(.unisonPitchDiscrimination)
                    )
                }
            }
        }
        return ProgressTimeline(profile: profile)
    }
}
