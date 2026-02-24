import Testing
import Foundation
import SwiftUI
@testable import Peach

@Suite("ThresholdTimeline Tests")
@MainActor
struct ThresholdTimelineTests {

    // MARK: - Helpers

    /// Creates records spaced one day apart (noon UTC to avoid timezone boundary issues)
    private func makeDailyRecords(
        offsets: [Double],
        startDay: Int = 2,
        isCorrect: Bool = true
    ) -> [ComparisonRecord] {
        offsets.enumerated().map { index, offset in
            let daySeconds = Double(startDay + index) * 86400 + 43200
            return ComparisonRecord(
                note1: 60,
                note2: 60,
                note2CentOffset: offset,
                isCorrect: isCorrect,
                timestamp: Date(timeIntervalSince1970: daySeconds)
            )
        }
    }

    /// Creates records on the same calendar day, spaced 1 minute apart
    private func makeRecordsOnDay(
        offsets: [Double],
        correctness: [Bool]? = nil,
        day: Int = 2
    ) -> [ComparisonRecord] {
        let baseSeconds = Double(day) * 86400 + 43200
        return offsets.enumerated().map { index, offset in
            ComparisonRecord(
                note1: 60,
                note2: 60,
                note2CentOffset: offset,
                isCorrect: correctness?[index] ?? true,
                timestamp: Date(timeIntervalSince1970: baseSeconds + Double(index) * 60)
            )
        }
    }

    private func makeDailyTimeline(offsets: [Double], windowSize: Int = 20) -> ThresholdTimeline {
        let records = makeDailyRecords(offsets: offsets)
        return ThresholdTimeline(records: records, windowSize: windowSize)
    }

    // MARK: - TimelineDataPoint struct

    @Test("TimelineDataPoint stores all required fields")
    func dataPointFields() async throws {
        let date = Date()
        let point = TimelineDataPoint(
            timestamp: date,
            centDifference: 25.0,
            isCorrect: true,
            note1: 60
        )

        #expect(point.timestamp == date)
        #expect(point.centDifference == 25.0)
        #expect(point.isCorrect == true)
        #expect(point.note1 == 60)
    }

    // MARK: - AggregatedDataPoint struct

    @Test("AggregatedDataPoint stores all required fields")
    func aggregatedDataPointFields() async throws {
        let date = Date()
        let point = AggregatedDataPoint(
            periodStart: date,
            meanThreshold: 30.0,
            comparisonCount: 5,
            correctCount: 3
        )

        #expect(point.periodStart == date)
        #expect(point.meanThreshold == 30.0)
        #expect(point.comparisonCount == 5)
        #expect(point.correctCount == 3)
    }

    // MARK: - Load from ComparisonRecord array

    @Test("Loads data points from ComparisonRecord array")
    func loadFromRecords() async throws {
        let records = makeDailyRecords(offsets: [50.0, -30.0, 40.0])
        let timeline = ThresholdTimeline(records: records)

        #expect(timeline.dataPoints.count == 3)
    }

    @Test("Uses absolute cent difference from records")
    func absoluteCentDifference() async throws {
        let records = makeDailyRecords(offsets: [-25.0, 30.0])
        let timeline = ThresholdTimeline(records: records)

        #expect(timeline.dataPoints[0].centDifference == 25.0)
        #expect(timeline.dataPoints[1].centDifference == 30.0)
    }

    @Test("Preserves chronological ordering from records")
    func chronologicalOrder() async throws {
        let records = makeDailyRecords(offsets: [50.0, 30.0, 40.0])
        let timeline = ThresholdTimeline(records: records)

        #expect(timeline.dataPoints[0].centDifference == 50.0)
        #expect(timeline.dataPoints[1].centDifference == 30.0)
        #expect(timeline.dataPoints[2].centDifference == 40.0)
    }

    // MARK: - Aggregation by period

    @Test("Aggregates same-day comparisons into one point")
    func aggregatesSameDay() async throws {
        var records = makeRecordsOnDay(offsets: [10, 20, 30], day: 2)
        records += makeRecordsOnDay(offsets: [40, 50], day: 3)
        let timeline = ThresholdTimeline(records: records)

        let aggregated = timeline.aggregatedPoints
        #expect(aggregated.count == 2)
        #expect(aggregated[0].comparisonCount == 3)
        #expect(aggregated[0].meanThreshold == 20.0) // (10+20+30)/3
        #expect(aggregated[1].comparisonCount == 2)
        #expect(aggregated[1].meanThreshold == 45.0) // (40+50)/2
    }

    @Test("Aggregation uses absolute cent differences")
    func aggregationAbsoluteValues() async throws {
        let records = makeRecordsOnDay(offsets: [-10, 20, -30], day: 2)
        let timeline = ThresholdTimeline(records: records)

        let aggregated = timeline.aggregatedPoints
        #expect(aggregated.count == 1)
        #expect(aggregated[0].meanThreshold == 20.0) // (10+20+30)/3
    }

    @Test("Aggregation counts correct answers")
    func aggregationCorrectCount() async throws {
        let records = makeRecordsOnDay(
            offsets: [10, 20, 30, 40],
            correctness: [true, false, true, false],
            day: 2
        )
        let timeline = ThresholdTimeline(records: records)

        let aggregated = timeline.aggregatedPoints
        #expect(aggregated[0].correctCount == 2)
        #expect(aggregated[0].comparisonCount == 4)
    }

    @Test("Aggregated points in chronological order")
    func aggregationChronological() async throws {
        var records = makeRecordsOnDay(offsets: [50], day: 5)
        records += makeRecordsOnDay(offsets: [30], day: 3)
        records += makeRecordsOnDay(offsets: [40], day: 4)
        // Data arrives out of order but gets grouped by day and sorted
        let timeline = ThresholdTimeline(records: records)

        let aggregated = timeline.aggregatedPoints
        #expect(aggregated.count == 3)
        #expect(aggregated[0].meanThreshold == 30.0) // day 3
        #expect(aggregated[1].meanThreshold == 40.0) // day 4
        #expect(aggregated[2].meanThreshold == 50.0) // day 5
    }

    @Test("Single comparison produces single aggregated point")
    func singleComparisonAggregation() async throws {
        let records = makeRecordsOnDay(offsets: [42.0], day: 2)
        let timeline = ThresholdTimeline(records: records)

        let aggregated = timeline.aggregatedPoints
        #expect(aggregated.count == 1)
        #expect(aggregated[0].meanThreshold == 42.0)
        #expect(aggregated[0].comparisonCount == 1)
    }

    @Test("Supports hourly aggregation period")
    func hourlyAggregation() async throws {
        let hour1Base = 86400 * 2 + 43200.0 // day 2, noon
        let hour2Base = hour1Base + 3600     // day 2, 1pm
        let records = [
            ComparisonRecord(note1: 60, note2: 60, note2CentOffset: 10, isCorrect: true,
                           timestamp: Date(timeIntervalSince1970: hour1Base)),
            ComparisonRecord(note1: 60, note2: 60, note2CentOffset: 20, isCorrect: true,
                           timestamp: Date(timeIntervalSince1970: hour1Base + 60)),
            ComparisonRecord(note1: 60, note2: 60, note2CentOffset: 30, isCorrect: true,
                           timestamp: Date(timeIntervalSince1970: hour2Base)),
        ]
        let timeline = ThresholdTimeline(records: records, aggregationComponent: .hour)

        let aggregated = timeline.aggregatedPoints
        #expect(aggregated.count == 2)
        #expect(aggregated[0].comparisonCount == 2)
        #expect(aggregated[0].meanThreshold == 15.0) // (10+20)/2
        #expect(aggregated[1].comparisonCount == 1)
        #expect(aggregated[1].meanThreshold == 30.0)
    }

    // MARK: - Rolling mean over aggregated points

    @Test("Rolling mean computes correct arithmetic mean over day windows")
    func rollingMeanOverDays() async throws {
        // 5 days, one comparison per day: [10, 20, 30, 40, 50]
        let timeline = makeDailyTimeline(offsets: [10, 20, 30, 40, 50], windowSize: 5)
        let means = timeline.rollingMean()

        #expect(means.count == 5)
        #expect(means.last!.value == 30.0) // (10+20+30+40+50)/5
    }

    @Test("Rolling mean slides correctly over daily data")
    func rollingMeanSlidingDays() async throws {
        let timeline = makeDailyTimeline(offsets: [10, 20, 30, 40, 50], windowSize: 3)
        let means = timeline.rollingMean()

        #expect(means.count == 5)
        #expect(means[2].value == 20.0) // (10+20+30)/3
        #expect(means[3].value == 30.0) // (20+30+40)/3
        #expect(means[4].value == 40.0) // (30+40+50)/3
    }

    // MARK: - Expanding window for early data

    @Test("Uses expanding window when fewer periods than window size")
    func expandingWindow() async throws {
        let timeline = makeDailyTimeline(offsets: [10, 20, 30], windowSize: 5)
        let means = timeline.rollingMean()

        #expect(means.count == 3)
        #expect(means[0].value == 10.0) // [10]
        #expect(means[1].value == 15.0) // [10, 20]
        #expect(means[2].value == 20.0) // [10, 20, 30]
    }

    // MARK: - Rolling standard deviation over aggregated points

    @Test("Rolling stddev computes sample standard deviation over day windows")
    func rollingStdDevOverDays() async throws {
        // Window 4 over daily values [10, 20, 30, 40]
        // Mean = 25, variance = ((−15)²+(−5)²+(5)²+(15)²)/3 = 500/3
        // StdDev = sqrt(500/3) ≈ 12.909944
        let timeline = makeDailyTimeline(offsets: [10, 20, 30, 40], windowSize: 4)
        let stddevs = timeline.rollingStdDev()

        #expect(stddevs.count == 4)
        let lastStdDev = stddevs.last!.value
        #expect(abs(lastStdDev - 12.909944) < 0.001)
    }

    @Test("Rolling stddev returns 0 for single period window")
    func rollingStdDevSinglePeriod() async throws {
        let timeline = makeDailyTimeline(offsets: [42.0], windowSize: 5)
        let stddevs = timeline.rollingStdDev()

        #expect(stddevs.count == 1)
        #expect(stddevs[0].value == 0.0)
    }

    // MARK: - Empty state

    @Test("Empty timeline has no data points")
    func emptyState() async throws {
        let timeline = ThresholdTimeline()

        #expect(timeline.dataPoints.isEmpty)
    }

    @Test("Empty timeline has no aggregated points")
    func emptyAggregated() async throws {
        let timeline = ThresholdTimeline()

        #expect(timeline.aggregatedPoints.isEmpty)
    }

    @Test("Empty timeline returns empty rolling mean")
    func emptyRollingMean() async throws {
        let timeline = ThresholdTimeline()
        let means = timeline.rollingMean()

        #expect(means.isEmpty)
    }

    @Test("Empty timeline returns empty rolling stddev")
    func emptyRollingStdDev() async throws {
        let timeline = ThresholdTimeline()
        let stddevs = timeline.rollingStdDev()

        #expect(stddevs.isEmpty)
    }

    // MARK: - Single point

    @Test("Single point rolling mean equals the point value")
    func singlePointMean() async throws {
        let timeline = makeDailyTimeline(offsets: [42.0], windowSize: 20)
        let means = timeline.rollingMean()

        #expect(means.count == 1)
        #expect(means[0].value == 42.0)
    }

    @Test("Single point rolling stddev is 0")
    func singlePointStdDev() async throws {
        let timeline = makeDailyTimeline(offsets: [42.0], windowSize: 20)
        let stddevs = timeline.rollingStdDev()

        #expect(stddevs.count == 1)
        #expect(stddevs[0].value == 0.0)
    }

    // MARK: - ComparisonObserver incremental update

    @Test("Appends new point via ComparisonObserver")
    func incrementalUpdate() async throws {
        let timeline = ThresholdTimeline()
        #expect(timeline.dataPoints.isEmpty)

        let comparison = Comparison(
            note1: 60,
            note2: 60,
            centDifference: 25.0,
            isSecondNoteHigher: true
        )
        let completed = CompletedComparison(
            comparison: comparison,
            userAnsweredHigher: true,
            timestamp: Date()
        )
        timeline.comparisonCompleted(completed)

        #expect(timeline.dataPoints.count == 1)
        #expect(timeline.dataPoints[0].centDifference == 25.0)
        #expect(timeline.dataPoints[0].isCorrect == true)
        #expect(timeline.dataPoints[0].note1 == 60)
        #expect(timeline.aggregatedPoints.count == 1)
    }

    @Test("Incremental update preserves existing data")
    func incrementalUpdatePreservesData() async throws {
        let records = makeDailyRecords(offsets: [50.0, 30.0])
        let timeline = ThresholdTimeline(records: records)
        #expect(timeline.dataPoints.count == 2)

        let comparison = Comparison(
            note1: 64,
            note2: 64,
            centDifference: 20.0,
            isSecondNoteHigher: false
        )
        let completed = CompletedComparison(
            comparison: comparison,
            userAnsweredHigher: false,
            timestamp: Date()
        )
        timeline.comparisonCompleted(completed)

        #expect(timeline.dataPoints.count == 3)
        #expect(timeline.dataPoints[2].centDifference == 20.0)
        #expect(timeline.dataPoints[2].note1 == 64)
    }

    // MARK: - Environment key

    @Test("ThresholdTimeline environment key provides default value")
    func environmentKeyDefault() async throws {
        var env = EnvironmentValues()
        let timeline = env.thresholdTimeline
        #expect(timeline.dataPoints.isEmpty)
    }

    @Test("ThresholdTimeline environment key can be set and retrieved")
    func environmentKeySetAndGet() async throws {
        let records = makeDailyRecords(offsets: [10.0, 20.0, 30.0])
        let timeline = ThresholdTimeline(records: records)

        var env = EnvironmentValues()
        env.thresholdTimeline = timeline

        let retrieved = env.thresholdTimeline
        #expect(retrieved.dataPoints.count == 3)
    }

    // MARK: - Rolling statistics return period timestamps

    @Test("Rolling mean entries carry correct period start timestamps")
    func rollingMeanTimestamps() async throws {
        let records = makeDailyRecords(offsets: [10, 20, 30], startDay: 2)
        let timeline = ThresholdTimeline(records: records, windowSize: 2)
        let means = timeline.rollingMean()

        let calendar = Calendar.current
        #expect(means.count == 3)
        // Each mean's date should be the start of the corresponding calendar day
        for (i, mean) in means.enumerated() {
            let expectedDate = Date(timeIntervalSince1970: Double(2 + i) * 86400 + 43200)
            let expectedDayStart = calendar.startOfDay(for: expectedDate)
            #expect(mean.date == expectedDayStart)
        }
    }

    // MARK: - Reset

    @Test("Reset clears all data points and aggregated points")
    func resetClearsData() async throws {
        let records = makeDailyRecords(offsets: [10.0, 20.0, 30.0])
        let timeline = ThresholdTimeline(records: records)
        #expect(timeline.dataPoints.count == 3)
        #expect(!timeline.aggregatedPoints.isEmpty)

        timeline.reset()

        #expect(timeline.dataPoints.isEmpty)
        #expect(timeline.aggregatedPoints.isEmpty)
        #expect(timeline.rollingMean().isEmpty)
        #expect(timeline.rollingStdDev().isEmpty)
    }
}
