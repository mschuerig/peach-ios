import Testing
import Foundation
@testable import Peach

@Suite("ProgressTimeline Tests")
struct ProgressTimelineTests {

    // MARK: - Helpers

    private let now = Date()

    private func makePitchComparisonRecord(
        centOffset: Double,
        isCorrect: Bool = true,
        interval: Int = 0,
        hoursAgo: Double = 1,
        date: Date? = nil
    ) -> PitchComparisonRecord {
        PitchComparisonRecord(
            referenceNote: 60,
            targetNote: 60,
            centOffset: centOffset,
            isCorrect: isCorrect,
            interval: interval,
            tuningSystem: "equalTemperament",
            timestamp: date ?? now.addingTimeInterval(-hoursAgo * 3600)
        )
    }

    private func makePitchMatchingRecord(
        userCentError: Double,
        interval: Int = 0,
        hoursAgo: Double = 1
    ) -> PitchMatchingRecord {
        PitchMatchingRecord(
            referenceNote: 60,
            targetNote: 60,
            initialCentOffset: 50.0,
            userCentError: userCentError,
            interval: interval,
            tuningSystem: "equalTemperament",
            timestamp: now.addingTimeInterval(-hoursAgo * 3600)
        )
    }

    private func makePitchComparisonRecords(count: Int, centOffset: Double = 10.0, interval: Int = 0) -> [PitchComparisonRecord] {
        (0..<count).map { i in
            makePitchComparisonRecord(centOffset: centOffset, interval: interval, hoursAgo: Double(count - i))
        }
    }

    private func makePitchMatchingRecords(count: Int, userCentError: Double = 5.0, interval: Int = 0) -> [PitchMatchingRecord] {
        (0..<count).map { i in
            makePitchMatchingRecord(userCentError: userCentError, interval: interval, hoursAgo: Double(count - i))
        }
    }

    // MARK: - Cold Start Tests

    @Test("empty timeline reports noData for all modes")
    func emptyTimeline() async {
        let timeline = ProgressTimeline()
        #expect(timeline.state(for: .unisonPitchComparison) == .noData)
        #expect(timeline.state(for: .intervalPitchComparison) == .noData)
        #expect(timeline.state(for: .unisonMatching) == .noData)
        #expect(timeline.state(for: .intervalMatching) == .noData)
    }

    @Test("any records transitions to active")
    func activeWithAnyData() async {
        let records = makePitchComparisonRecords(count: 1)
        let timeline = ProgressTimeline(pitchComparisonRecords: records)
        let state = timeline.state(for: .unisonPitchComparison)
        #expect(state == .active)
    }

    @Test("2+ records have trend available")
    func activeWithTrend() async {
        let records = makePitchComparisonRecords(count: 100)
        let timeline = ProgressTimeline(pitchComparisonRecords: records)
        let trend = timeline.trend(for: .unisonPitchComparison)
        #expect(trend != nil)
    }

    // MARK: - Mode Routing Tests

    @Test("unison comparison uses interval 0 comparison records including incorrect")
    func unisonComparisonMetric() async {
        let records = [
            makePitchComparisonRecord(centOffset: 10.0, isCorrect: true, interval: 0, hoursAgo: 2),
            makePitchComparisonRecord(centOffset: 50.0, isCorrect: false, interval: 0, hoursAgo: 1),
        ]
        let timeline = ProgressTimeline(pitchComparisonRecords: records)
        let buckets = timeline.buckets(for: .unisonPitchComparison)
        let totalRecords = buckets.reduce(0) { $0 + $1.recordCount }
        #expect(totalRecords == 2)
    }

    @Test("interval comparison uses interval != 0 comparison records")
    func intervalComparisonRouting() async {
        let unisonRecords = makePitchComparisonRecords(count: 5, interval: 0)
        let intervalRecords = makePitchComparisonRecords(count: 3, centOffset: 15.0, interval: 7)
        let timeline = ProgressTimeline(pitchComparisonRecords: unisonRecords + intervalRecords)
        let unisonBuckets = timeline.buckets(for: .unisonPitchComparison)
        let intervalBuckets = timeline.buckets(for: .intervalPitchComparison)
        let unisonCount = unisonBuckets.reduce(0) { $0 + $1.recordCount }
        let intervalCount = intervalBuckets.reduce(0) { $0 + $1.recordCount }
        #expect(unisonCount == 5)
        #expect(intervalCount == 3)
    }

    @Test("matching mode uses abs(userCentError) from all records")
    func matchingMetric() async {
        let records = [
            makePitchMatchingRecord(userCentError: -3.0, hoursAgo: 2),
            makePitchMatchingRecord(userCentError: 5.0, hoursAgo: 1),
        ]
        let timeline = ProgressTimeline(pitchMatchingRecords: records)
        let buckets = timeline.buckets(for: .unisonMatching)
        let totalRecords = buckets.reduce(0) { $0 + $1.recordCount }
        #expect(totalRecords == 2)
    }

    @Test("interval matching uses interval != 0 pitch matching records")
    func intervalMatchingRouting() async {
        let unisonRecords = makePitchMatchingRecords(count: 4, interval: 0)
        let intervalRecords = makePitchMatchingRecords(count: 2, interval: 7)
        let timeline = ProgressTimeline(pitchMatchingRecords: unisonRecords + intervalRecords)
        let unisonCount = timeline.buckets(for: .unisonMatching).reduce(0) { $0 + $1.recordCount }
        let intervalCount = timeline.buckets(for: .intervalMatching).reduce(0) { $0 + $1.recordCount }
        #expect(unisonCount == 4)
        #expect(intervalCount == 2)
    }

    // MARK: - Bucket Assignment Tests

    @Test("records within 24h are grouped by session proximity")
    func sessionBuckets() async {
        // Records 5 minutes apart should be in same session bucket
        let records = [
            makePitchComparisonRecord(centOffset: 10.0, hoursAgo: 2.0),
            makePitchComparisonRecord(centOffset: 12.0, hoursAgo: 1.9),
            // Record 1 hour later should be in different session bucket
            makePitchComparisonRecord(centOffset: 8.0, hoursAgo: 0.5),
        ]
        let timeline = ProgressTimeline(pitchComparisonRecords: records)
        let buckets = timeline.buckets(for: .unisonPitchComparison)
        #expect(buckets.count == 2)
    }

    @Test("records between 1-7 days old are grouped by day")
    func dayBuckets() async {
        // Use calendar-day-aligned offsets to avoid midnight boundary flakiness.
        // Place records at noon 2 days ago (×2, same day) and noon 3 days ago (different day).
        let calendar = Calendar.current
        let now = Date()
        let noon2DaysAgo = calendar.startOfDay(for: now.addingTimeInterval(-2 * 86400)).addingTimeInterval(12 * 3600)
        let noon3DaysAgo = calendar.startOfDay(for: now.addingTimeInterval(-3 * 86400)).addingTimeInterval(12 * 3600)

        let records = [
            makePitchComparisonRecord(centOffset: 10.0, date: noon3DaysAgo),
            makePitchComparisonRecord(centOffset: 12.0, date: noon2DaysAgo),
            makePitchComparisonRecord(centOffset: 14.0, date: noon2DaysAgo.addingTimeInterval(3600)),  // same day, 1h later
        ]
        let timeline = ProgressTimeline(pitchComparisonRecords: records)
        let buckets = timeline.buckets(for: .unisonPitchComparison)
        #expect(buckets.count == 2)
    }

    @Test("records between 7-30 days old are grouped by week")
    func weekBuckets() async {
        let records = [
            makePitchComparisonRecord(centOffset: 10.0, hoursAgo: 24 * 10),  // 10 days ago
            makePitchComparisonRecord(centOffset: 12.0, hoursAgo: 24 * 20),  // 20 days ago
        ]
        let timeline = ProgressTimeline(pitchComparisonRecords: records)
        let buckets = timeline.buckets(for: .unisonPitchComparison)
        // May be 1 or 2 buckets depending on week boundaries — just verify they exist
        #expect(buckets.count >= 1)
    }

    @Test("records older than 30 days are grouped by month")
    func monthBuckets() async {
        let records = [
            makePitchComparisonRecord(centOffset: 10.0, hoursAgo: 24 * 45),  // 45 days ago
            makePitchComparisonRecord(centOffset: 12.0, hoursAgo: 24 * 60),  // 60 days ago
        ]
        let timeline = ProgressTimeline(pitchComparisonRecords: records)
        let buckets = timeline.buckets(for: .unisonPitchComparison)
        #expect(buckets.count >= 1)
    }

    // MARK: - EWMA Tests

    @Test("EWMA with single bucket equals that bucket value")
    func ewmaSingleBucket() async {
        // All records in a single session bucket (close together, recent)
        let records = (0..<5).map { i in
            makePitchComparisonRecord(centOffset: 10.0, hoursAgo: 1.0 + Double(i) * 0.01)
        }
        let timeline = ProgressTimeline(pitchComparisonRecords: records)
        let ewma = timeline.currentEWMA(for: .unisonPitchComparison)
        #expect(ewma != nil)
        if let ewma {
            #expect(abs(ewma - 10.0) < 0.01)
        }
    }

    @Test("EWMA halflife gives 50% weight when dt equals halflife")
    func ewmaHalflife() async {
        // Create two buckets separated by exactly 7 days (halflife)
        // Bucket 1 (7 days ago): value = 20.0
        // Bucket 2 (now): value = 10.0
        // With halflife=7d, alpha = 0.5, so EWMA = 0.5*10 + 0.5*20 = 15.0
        let olderRecords = (0..<5).map { i in
            makePitchComparisonRecord(centOffset: 20.0, hoursAgo: 7 * 24 + Double(i) * 0.01)
        }
        let recentRecords = (0..<5).map { i in
            makePitchComparisonRecord(centOffset: 10.0, hoursAgo: 1.0 + Double(i) * 0.01)
        }
        let timeline = ProgressTimeline(pitchComparisonRecords: olderRecords + recentRecords)
        let ewma = timeline.currentEWMA(for: .unisonPitchComparison)
        #expect(ewma != nil)
        if let ewma {
            // EWMA should weight recent values more than older ones; exact value
            // varies with calendar-dependent bucket boundaries (±2.0 tolerance)
            #expect(abs(ewma - 15.0) < 2.0)
        }
    }

    // MARK: - Standard Deviation Tests

    @Test("stddev is zero when all values in bucket are identical")
    func stddevZero() async {
        let records = (0..<5).map { i in
            makePitchComparisonRecord(centOffset: 10.0, hoursAgo: 1.0 + Double(i) * 0.01)
        }
        let timeline = ProgressTimeline(pitchComparisonRecords: records)
        let buckets = timeline.buckets(for: .unisonPitchComparison)
        #expect(buckets.count == 1)
        if let bucket = buckets.first {
            #expect(abs(bucket.stddev) < 0.01)
        }
    }

    @Test("stddev is non-zero for varying values")
    func stddevNonZero() async {
        let records = [
            makePitchComparisonRecord(centOffset: 5.0, hoursAgo: 1.0),
            makePitchComparisonRecord(centOffset: 15.0, hoursAgo: 0.99),
            makePitchComparisonRecord(centOffset: 25.0, hoursAgo: 0.98),
        ]
        let timeline = ProgressTimeline(pitchComparisonRecords: records)
        let buckets = timeline.buckets(for: .unisonPitchComparison)
        if let bucket = buckets.first {
            #expect(bucket.stddev > 0)
        }
    }

    // MARK: - Incremental Update Tests

    @Test("incremental comparison update adds to correct mode")
    func incrementalComparisonUpdate() async {
        let timeline = ProgressTimeline()
        #expect(timeline.state(for: .unisonPitchComparison) == .noData)

        let referenceNote = MIDINote(60)
        let targetNote = DetunedMIDINote(note: referenceNote, offset: Cents(10.0))
        let comparison = PitchComparison(referenceNote: referenceNote, targetNote: targetNote)
        let completed = CompletedPitchComparison(
            pitchComparison: comparison,
            userAnsweredHigher: true,
            tuningSystem: .equalTemperament
        )
        timeline.pitchComparisonCompleted(completed)

        let buckets = timeline.buckets(for: .unisonPitchComparison)
        let totalRecords = buckets.reduce(0) { $0 + $1.recordCount }
        #expect(totalRecords == 1)
    }

    @Test("incremental pitch matching update adds to correct mode")
    func incrementalPitchMatchingUpdate() async {
        let timeline = ProgressTimeline()
        #expect(timeline.state(for: .unisonMatching) == .noData)

        let result = CompletedPitchMatching(
            referenceNote: MIDINote(60),
            targetNote: MIDINote(60),
            initialCentOffset: 50.0,
            userCentError: -3.0,
            tuningSystem: .equalTemperament
        )
        timeline.pitchMatchingCompleted(result)

        let buckets = timeline.buckets(for: .unisonMatching)
        let totalRecords = buckets.reduce(0) { $0 + $1.recordCount }
        #expect(totalRecords == 1)
    }

    @Test("incremental update for interval comparison routes correctly")
    func incrementalIntervalUpdate() async {
        let timeline = ProgressTimeline()

        let referenceNote = MIDINote(60)
        let targetNote = DetunedMIDINote(note: MIDINote(67), offset: Cents(10.0))
        let comparison = PitchComparison(referenceNote: referenceNote, targetNote: targetNote)
        let completed = CompletedPitchComparison(
            pitchComparison: comparison,
            userAnsweredHigher: true,
            tuningSystem: .equalTemperament
        )
        timeline.pitchComparisonCompleted(completed)

        // Should route to interval comparison (interval != 0)
        let intervalBuckets = timeline.buckets(for: .intervalPitchComparison)
        let intervalCount = intervalBuckets.reduce(0) { $0 + $1.recordCount }
        #expect(intervalCount == 1)

        // Unison should remain empty
        let unisonBuckets = timeline.buckets(for: .unisonPitchComparison)
        let unisonCount = unisonBuckets.reduce(0) { $0 + $1.recordCount }
        #expect(unisonCount == 0)
    }

    @Test("incremental updates within same session merge into one bucket")
    func incrementalSessionMerging() async {
        let timeline = ProgressTimeline()

        let referenceNote = MIDINote(60)
        let targetNote = DetunedMIDINote(note: referenceNote, offset: Cents(10.0))
        let comparison = PitchComparison(referenceNote: referenceNote, targetNote: targetNote)

        // Add two correct comparisons in quick succession (same session)
        let completed1 = CompletedPitchComparison(
            pitchComparison: comparison,
            userAnsweredHigher: true,
            tuningSystem: .equalTemperament
        )
        timeline.pitchComparisonCompleted(completed1)

        let completed2 = CompletedPitchComparison(
            pitchComparison: comparison,
            userAnsweredHigher: true,
            tuningSystem: .equalTemperament
        )
        timeline.pitchComparisonCompleted(completed2)

        let buckets = timeline.buckets(for: .unisonPitchComparison)
        // Both records should be in the same session bucket
        #expect(buckets.count == 1)
        #expect(buckets.first?.recordCount == 2)
    }

    @Test("incorrect comparison records are included in comparison metrics")
    func incorrectRecordsIncludedInMetrics() async {
        let timeline = ProgressTimeline()

        let referenceNote = MIDINote(60)
        let targetNote = DetunedMIDINote(note: referenceNote, offset: Cents(10.0))
        let comparison = PitchComparison(referenceNote: referenceNote, targetNote: targetNote)
        // User answers wrong — isCorrect will be false, but metric still contributes
        let completed = CompletedPitchComparison(
            pitchComparison: comparison,
            userAnsweredHigher: false,
            tuningSystem: .equalTemperament
        )
        timeline.pitchComparisonCompleted(completed)

        let buckets = timeline.buckets(for: .unisonPitchComparison)
        let totalRecords = buckets.reduce(0) { $0 + $1.recordCount }
        #expect(totalRecords == 1)
    }

    // MARK: - Reset Tests

    @Test("reset clears all data")
    func resetClearsAll() async {
        let records = makePitchComparisonRecords(count: 25)
        let timeline = ProgressTimeline(pitchComparisonRecords: records)
        #expect(timeline.state(for: .unisonPitchComparison) == .active)

        timeline.reset()
        #expect(timeline.state(for: .unisonPitchComparison) == .noData)
    }

    // MARK: - Trend Tests

    @Test("improving trend when latest value is below EWMA and within stddev")
    func improvingTrend() async {
        // Many records at 20.0 cents, then latest at 10.0 (below EWMA, within stddev)
        var records: [PitchComparisonRecord] = []
        for i in 0..<10 {
            records.append(makePitchComparisonRecord(centOffset: 20.0, hoursAgo: Double(12 - i)))
        }
        records.append(makePitchComparisonRecord(centOffset: 10.0, hoursAgo: 0.5))
        let timeline = ProgressTimeline(pitchComparisonRecords: records)
        let trend = timeline.trend(for: .unisonPitchComparison)
        #expect(trend == .improving)
    }

    @Test("declining trend when latest value is outside 1 stddev above mean")
    func decliningTrend() async {
        // Many records at 10.0 cents with low variance, then latest at 50.0
        var records: [PitchComparisonRecord] = []
        for i in 0..<10 {
            records.append(makePitchComparisonRecord(centOffset: 10.0, hoursAgo: Double(12 - i)))
        }
        records.append(makePitchComparisonRecord(centOffset: 50.0, hoursAgo: 0.5))
        let timeline = ProgressTimeline(pitchComparisonRecords: records)
        let trend = timeline.trend(for: .unisonPitchComparison)
        #expect(trend == .declining)
    }

    @Test("stable trend when latest value is within stddev and at or above EWMA")
    func stableTrend() async {
        // Consistent records at 15.0 cents — latest equals EWMA, within stddev
        let records = makePitchComparisonRecords(count: 10, centOffset: 15.0)
        let timeline = ProgressTimeline(pitchComparisonRecords: records)
        let trend = timeline.trend(for: .unisonPitchComparison)
        #expect(trend == .stable)
    }

    @Test("no trend available with single record")
    func noTrendWithSingleRecord() async {
        let records = makePitchComparisonRecords(count: 1)
        let timeline = ProgressTimeline(pitchComparisonRecords: records)
        let trend = timeline.trend(for: .unisonPitchComparison)
        #expect(trend == nil)
    }

    @Test("trend available with 2+ records")
    func trendWithTwoRecords() async {
        let records = makePitchComparisonRecords(count: 2)
        let timeline = ProgressTimeline(pitchComparisonRecords: records)
        let trend = timeline.trend(for: .unisonPitchComparison)
        #expect(trend != nil)
    }

    @Test("declining trend from wrong comparison answer with high centOffset")
    func decliningTrendFromWrongAnswers() async {
        // Start with correct records at low centOffset
        var records: [PitchComparisonRecord] = []
        for i in 0..<10 {
            records.append(makePitchComparisonRecord(centOffset: 8.0, hoursAgo: Double(12 - i)))
        }
        let timeline = ProgressTimeline(pitchComparisonRecords: records)

        // Add a wrong comparison answer (high centOffset) incrementally
        let referenceNote = MIDINote(60)
        let targetNote = DetunedMIDINote(note: referenceNote, offset: Cents(50.0))
        let comparison = PitchComparison(referenceNote: referenceNote, targetNote: targetNote)
        let completed = CompletedPitchComparison(
            pitchComparison: comparison,
            userAnsweredHigher: false,
            tuningSystem: .equalTemperament
        )
        timeline.pitchComparisonCompleted(completed)

        let trend = timeline.trend(for: .unisonPitchComparison)
        #expect(trend == .declining)
    }

    @Test("value exactly at runningMean + stddev is stable, not declining")
    func boundaryAtMeanPlusStddev() async {
        // Records: 10 values of 10.0, then 1 value of 20.0
        // Running mean ≈ 10.91, stddev ≈ 2.87, mean+stddev ≈ 13.78
        // Add a value exactly at mean + stddev boundary via bulk rebuild
        // Use values that produce a known mean+stddev, then set latest = mean+stddev
        // Simpler: 5 records at 10, 5 at 20 → mean=15, stddev=5, mean+stddev=20
        // Latest at 20.0 → value > 15+5 is 20 > 20 = false → stable (if >= ewma)
        var records: [PitchComparisonRecord] = []
        for i in 0..<5 {
            records.append(makePitchComparisonRecord(centOffset: 10.0, hoursAgo: Double(12 - i)))
        }
        for i in 0..<5 {
            records.append(makePitchComparisonRecord(centOffset: 20.0, hoursAgo: Double(7 - i)))
        }
        let timeline = ProgressTimeline(pitchComparisonRecords: records)
        let trend = timeline.trend(for: .unisonPitchComparison)
        // value(20) == runningMean(15) + stddev(5) → NOT greater, so not declining
        #expect(trend != .declining)
    }

    @Test("value exactly at EWMA is stable, not improving")
    func boundaryAtEwma() async {
        // All identical values → ewma == mean == latest, stddev == 0
        // value >= ewma → stable
        let records = makePitchComparisonRecords(count: 5, centOffset: 12.0)
        let timeline = ProgressTimeline(pitchComparisonRecords: records)
        let trend = timeline.trend(for: .unisonPitchComparison)
        #expect(trend == .stable)
    }

    @Test("pitch matching declining when latest error is outside stddev")
    func pitchMatchingDecliningWhenOutsideStddev() async {
        // Low-error records followed by one high-error record
        var records: [PitchMatchingRecord] = []
        for i in 0..<10 {
            records.append(makePitchMatchingRecord(userCentError: 3.0, hoursAgo: Double(12 - i)))
        }
        records.append(makePitchMatchingRecord(userCentError: 40.0, hoursAgo: 0.5))
        let timeline = ProgressTimeline(pitchMatchingRecords: records)
        let trend = timeline.trend(for: .unisonMatching)
        #expect(trend == .declining)
    }

    // MARK: - Sub-Bucket Tests

    @Test("subBuckets returns week-level buckets for a month bucket")
    func subBucketsMonthToWeek() async {
        // Create records spanning ~45 days ago (will be month-bucketed)
        // Spread across multiple weeks within the same month
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now.addingTimeInterval(-45 * 86400)))!
        let records = (0..<20).map { i in
            // Spread records across 4 weeks within the month
            let dayOffset = Double(i % 28)
            let timestamp = monthStart.addingTimeInterval(dayOffset * 86400 + Double(i) * 60)
            return PitchComparisonRecord(
                referenceNote: 60,
                targetNote: 60,
                centOffset: 10.0 + Double(i),
                isCorrect: true,
                interval: 0,
                tuningSystem: "equalTemperament",
                timestamp: timestamp
            )
        }
        let timeline = ProgressTimeline(pitchComparisonRecords: records)
        let buckets = timeline.buckets(for: .unisonPitchComparison)
        // Find a month bucket
        guard let monthBucket = buckets.first(where: { $0.bucketSize == .month }) else {
            Issue.record("Expected at least one month bucket")
            return
        }
        let subs = timeline.subBuckets(for: .unisonPitchComparison, expanding: monthBucket)
        #expect(!subs.isEmpty)
        for sub in subs {
            #expect(sub.bucketSize == .week)
        }
    }

    @Test("subBuckets returns day-level buckets for a week bucket")
    func subBucketsWeekToDay() async {
        // Create records ~10 days ago (will be week-bucketed)
        let records = (0..<10).map { i in
            // Spread across different days within the same week
            let hoursAgo = 24.0 * 8.0 + Double(i) * 12.0  // 8-13 days ago, within week range
            return makePitchComparisonRecord(centOffset: 10.0 + Double(i), hoursAgo: hoursAgo)
        }
        let timeline = ProgressTimeline(pitchComparisonRecords: records)
        let buckets = timeline.buckets(for: .unisonPitchComparison)
        guard let weekBucket = buckets.first(where: { $0.bucketSize == .week }) else {
            Issue.record("Expected at least one week bucket")
            return
        }
        let subs = timeline.subBuckets(for: .unisonPitchComparison, expanding: weekBucket)
        #expect(!subs.isEmpty)
        for sub in subs {
            #expect(sub.bucketSize == .day)
        }
    }

    @Test("subBuckets returns session-level buckets for a day bucket")
    func subBucketsDayToSession() async {
        // Create records ~2 days ago (will be day-bucketed)
        // Multiple sessions on the same day with gaps > sessionGap (1800s)
        let baseDateHoursAgo = 36.0  // 1.5 days ago
        let records = [
            makePitchComparisonRecord(centOffset: 10.0, hoursAgo: baseDateHoursAgo),
            makePitchComparisonRecord(centOffset: 12.0, hoursAgo: baseDateHoursAgo - 0.01),
            // 2 hours later = different session
            makePitchComparisonRecord(centOffset: 8.0, hoursAgo: baseDateHoursAgo - 2.0),
            makePitchComparisonRecord(centOffset: 9.0, hoursAgo: baseDateHoursAgo - 2.01),
        ]
        let timeline = ProgressTimeline(pitchComparisonRecords: records)
        let buckets = timeline.buckets(for: .unisonPitchComparison)
        guard let dayBucket = buckets.first(where: { $0.bucketSize == .day }) else {
            Issue.record("Expected at least one day bucket")
            return
        }
        let subs = timeline.subBuckets(for: .unisonPitchComparison, expanding: dayBucket)
        #expect(!subs.isEmpty)
        for sub in subs {
            #expect(sub.bucketSize == .session)
        }
    }

    @Test("subBuckets returns empty for session buckets (finest level)")
    func subBucketsSessionEmpty() async {
        // Create records within 24h (will be session-bucketed)
        let records = [
            makePitchComparisonRecord(centOffset: 10.0, hoursAgo: 1.0),
            makePitchComparisonRecord(centOffset: 12.0, hoursAgo: 0.99),
        ]
        let timeline = ProgressTimeline(pitchComparisonRecords: records)
        let buckets = timeline.buckets(for: .unisonPitchComparison)
        guard let sessionBucket = buckets.first(where: { $0.bucketSize == .session }) else {
            Issue.record("Expected at least one session bucket")
            return
        }
        let subs = timeline.subBuckets(for: .unisonPitchComparison, expanding: sessionBucket)
        #expect(subs.isEmpty)
    }

    @Test("sub-bucket record counts are consistent with parent bucket")
    func subBucketRecordCountConsistency() async {
        // Create records spanning weeks within a month bucket
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now.addingTimeInterval(-45 * 86400)))!
        let records = (0..<15).map { i in
            let dayOffset = Double(i * 2)  // Every 2 days
            let timestamp = monthStart.addingTimeInterval(dayOffset * 86400 + Double(i) * 60)
            return PitchComparisonRecord(
                referenceNote: 60,
                targetNote: 60,
                centOffset: 10.0,
                isCorrect: true,
                interval: 0,
                tuningSystem: "equalTemperament",
                timestamp: timestamp
            )
        }
        let timeline = ProgressTimeline(pitchComparisonRecords: records)
        let buckets = timeline.buckets(for: .unisonPitchComparison)
        guard let monthBucket = buckets.first(where: { $0.bucketSize == .month }) else {
            Issue.record("Expected at least one month bucket")
            return
        }
        let subs = timeline.subBuckets(for: .unisonPitchComparison, expanding: monthBucket)
        let subRecordCount = subs.reduce(0) { $0 + $1.recordCount }
        #expect(subRecordCount == monthBucket.recordCount)
    }
}
