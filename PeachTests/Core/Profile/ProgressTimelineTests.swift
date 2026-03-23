import Testing
import Foundation
@testable import Peach

@Suite("ProgressTimeline Tests")
struct ProgressTimelineTests {

    // MARK: - Helpers

    private let now = Date()

    private func makeTimeline(
        pitchDiscriminationRecords: [PitchDiscriminationRecord] = [],
        pitchMatchingRecords: [PitchMatchingRecord] = [],
        rhythmOffsetDetectionRecords: [RhythmOffsetDetectionRecord] = []
    ) -> ProgressTimeline {
        let profile = PerceptualProfile { builder in
            builder.feedPitchDiscriminations(pitchDiscriminationRecords)
            builder.feedPitchMatchings(pitchMatchingRecords)
            builder.feedRhythmOffsetDetections(rhythmOffsetDetectionRecords)
        }
        return ProgressTimeline(profile: profile)
    }

    private func makePitchDiscriminationRecord(
        centOffset: Double,
        isCorrect: Bool = true,
        interval: Int = 0,
        hoursAgo: Double = 1,
        date: Date? = nil
    ) -> PitchDiscriminationRecord {
        PitchDiscriminationRecord(
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

    private func makePitchDiscriminationRecords(count: Int, centOffset: Double = 10.0, interval: Int = 0) -> [PitchDiscriminationRecord] {
        (0..<count).map { i in
            makePitchDiscriminationRecord(centOffset: centOffset, interval: interval, hoursAgo: Double(count - i))
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
        let timeline = ProgressTimeline(profile: PerceptualProfile())
        for mode in TrainingDisciplineID.allCases {
            #expect(timeline.state(for: mode) == .noData)
        }
    }

    @Test("any records transitions to active")
    func activeWithAnyData() async {
        let records = makePitchDiscriminationRecords(count: 1)
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let state = timeline.state(for: .unisonPitchDiscrimination)
        #expect(state == .active)
    }

    @Test("2+ records have trend available")
    func activeWithTrend() async {
        let records = makePitchDiscriminationRecords(count: 100)
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let trend = timeline.trend(for: .unisonPitchDiscrimination)
        #expect(trend != nil)
    }

    // MARK: - Mode Routing Tests

    @Test("unison comparison uses interval 0 correct comparison records")
    func unisonComparisonMetric() async {
        let records = [
            makePitchDiscriminationRecord(centOffset: 10.0, isCorrect: true, interval: 0, hoursAgo: 2),
            makePitchDiscriminationRecord(centOffset: 50.0, isCorrect: true, interval: 0, hoursAgo: 1),
        ]
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let buckets = timeline.buckets(for: .unisonPitchDiscrimination)
        let totalRecords = buckets.reduce(0) { $0 + $1.recordCount }
        #expect(totalRecords == 2)
    }

    @Test("interval comparison uses interval != 0 comparison records")
    func intervalComparisonRouting() async {
        let unisonRecords = makePitchDiscriminationRecords(count: 5, interval: 0)
        let intervalRecords = makePitchDiscriminationRecords(count: 3, centOffset: 15.0, interval: 7)
        let timeline = makeTimeline(pitchDiscriminationRecords: unisonRecords + intervalRecords)
        let unisonBuckets = timeline.buckets(for: .unisonPitchDiscrimination)
        let intervalBuckets = timeline.buckets(for: .intervalPitchDiscrimination)
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
        let timeline = makeTimeline(pitchMatchingRecords: records)
        let buckets = timeline.buckets(for: .unisonPitchMatching)
        let totalRecords = buckets.reduce(0) { $0 + $1.recordCount }
        #expect(totalRecords == 2)
    }

    @Test("interval matching uses interval != 0 pitch matching records")
    func intervalMatchingRouting() async {
        let unisonRecords = makePitchMatchingRecords(count: 4, interval: 0)
        let intervalRecords = makePitchMatchingRecords(count: 2, interval: 7)
        let timeline = makeTimeline(pitchMatchingRecords: unisonRecords + intervalRecords)
        let unisonCount = timeline.buckets(for: .unisonPitchMatching).reduce(0) { $0 + $1.recordCount }
        let intervalCount = timeline.buckets(for: .intervalPitchMatching).reduce(0) { $0 + $1.recordCount }
        #expect(unisonCount == 4)
        #expect(intervalCount == 2)
    }

    // MARK: - Bucket Assignment Tests

    @Test("records within 24h are grouped by session proximity")
    func sessionBuckets() async {
        let records = [
            makePitchDiscriminationRecord(centOffset: 10.0, hoursAgo: 2.0),
            makePitchDiscriminationRecord(centOffset: 12.0, hoursAgo: 1.9),
            // Record 1 hour later should be in different session bucket
            makePitchDiscriminationRecord(centOffset: 8.0, hoursAgo: 0.5),
        ]
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let buckets = timeline.buckets(for: .unisonPitchDiscrimination)
        #expect(buckets.count == 2)
    }

    @Test("records between 1-7 days old are grouped by day")
    func dayBuckets() async {
        // Use calendar-day-aligned offsets to avoid midnight boundary flakiness.
        let calendar = Calendar.current
        let now = Date()
        let noon2DaysAgo = calendar.startOfDay(for: now.addingTimeInterval(-2 * 86400)).addingTimeInterval(12 * 3600)
        let noon3DaysAgo = calendar.startOfDay(for: now.addingTimeInterval(-3 * 86400)).addingTimeInterval(12 * 3600)

        let records = [
            makePitchDiscriminationRecord(centOffset: 10.0, date: noon3DaysAgo),
            makePitchDiscriminationRecord(centOffset: 12.0, date: noon2DaysAgo),
            makePitchDiscriminationRecord(centOffset: 14.0, date: noon2DaysAgo.addingTimeInterval(3600)),  // same day, 1h later
        ]
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let buckets = timeline.buckets(for: .unisonPitchDiscrimination)
        #expect(buckets.count == 2)
    }

    @Test("records older than 7 days are grouped by month")
    func monthBucketsForOlderRecords() async {
        let calendar = Calendar.current
        let now = Date()
        let noon10DaysAgo = calendar.startOfDay(for: now.addingTimeInterval(-10 * 86400)).addingTimeInterval(12 * 3600)
        let noon20DaysAgo = calendar.startOfDay(for: now.addingTimeInterval(-20 * 86400)).addingTimeInterval(12 * 3600)

        let records = [
            makePitchDiscriminationRecord(centOffset: 10.0, date: noon10DaysAgo),
            makePitchDiscriminationRecord(centOffset: 12.0, date: noon20DaysAgo),
        ]
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let buckets = timeline.buckets(for: .unisonPitchDiscrimination)
        #expect(!buckets.isEmpty)
        for bucket in buckets {
            #expect(bucket.bucketSize == .month)
        }
    }

    @Test("records older than 30 days are grouped by month")
    func monthBuckets() async {
        let records = [
            makePitchDiscriminationRecord(centOffset: 10.0, hoursAgo: 24 * 45),  // 45 days ago
            makePitchDiscriminationRecord(centOffset: 12.0, hoursAgo: 24 * 60),  // 60 days ago
        ]
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let buckets = timeline.buckets(for: .unisonPitchDiscrimination)
        #expect(buckets.count >= 1)
    }

    // MARK: - EWMA Tests

    @Test("EWMA with single bucket equals that bucket value")
    func ewmaSingleBucket() async {
        // All records in a single session bucket (close together, recent)
        let records = (0..<5).map { i in
            makePitchDiscriminationRecord(centOffset: 10.0, hoursAgo: 1.0 + Double(i) * 0.01)
        }
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let ewma = timeline.currentEWMA(for: .unisonPitchDiscrimination)
        #expect(ewma != nil)
        if let ewma {
            #expect(abs(ewma - 10.0) < 0.01)
        }
    }

    @Test("EWMA halflife gives 50% weight when dt equals halflife")
    func ewmaHalflife() async {
        let calendar = Calendar.current
        let now = Date()
        let midnightToday = calendar.startOfDay(for: now)
        let midnight7DaysAgo = calendar.date(byAdding: .day, value: -7, to: midnightToday)!

        let olderRecords = (0..<5).map { i in
            makePitchDiscriminationRecord(centOffset: 20.0, date: midnight7DaysAgo.addingTimeInterval(12 * 3600 + Double(i) * 0.01))
        }
        let recentRecords = (0..<5).map { i in
            makePitchDiscriminationRecord(centOffset: 10.0, date: midnightToday.addingTimeInterval(60 + Double(i) * 0.01))
        }
        let timeline = makeTimeline(pitchDiscriminationRecords: olderRecords + recentRecords)
        let ewma = timeline.currentEWMA(for: .unisonPitchDiscrimination)
        #expect(ewma != nil)
        if let ewma {
            #expect(abs(ewma - 15.0) < 0.5)
        }
    }

    // MARK: - Standard Deviation Tests

    @Test("stddev is zero when all values in bucket are identical")
    func stddevZero() async {
        let records = (0..<5).map { i in
            makePitchDiscriminationRecord(centOffset: 10.0, hoursAgo: 1.0 + Double(i) * 0.01)
        }
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let buckets = timeline.buckets(for: .unisonPitchDiscrimination)
        #expect(buckets.count == 1)
        if let bucket = buckets.first {
            #expect(abs(bucket.stddev) < 0.01)
        }
    }

    @Test("stddev is non-zero for varying values")
    func stddevNonZero() async {
        let records = [
            makePitchDiscriminationRecord(centOffset: 5.0, hoursAgo: 1.0),
            makePitchDiscriminationRecord(centOffset: 15.0, hoursAgo: 0.99),
            makePitchDiscriminationRecord(centOffset: 25.0, hoursAgo: 0.98),
        ]
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let buckets = timeline.buckets(for: .unisonPitchDiscrimination)
        if let bucket = buckets.first {
            #expect(bucket.stddev > 0)
        }
    }

    // MARK: - Profile-Driven Incremental Tests

    @Test("profile observer update reflects in timeline buckets")
    func profileObserverReflectsInTimeline() async {
        let profile = PerceptualProfile()
        let timeline = ProgressTimeline(profile: profile)
        #expect(timeline.state(for: .unisonPitchDiscrimination) == .noData)

        let referenceNote = MIDINote(60)
        let targetNote = DetunedMIDINote(note: referenceNote, offset: Cents(10.0))
        let comparison = PitchDiscriminationTrial(referenceNote: referenceNote, targetNote: targetNote)
        let completed = CompletedPitchDiscriminationTrial(
            trial: comparison,
            userAnsweredHigher: true,
            tuningSystem: .equalTemperament
        )
        PitchDiscriminationProfileAdapter(profile: profile).pitchDiscriminationCompleted(completed)

        let buckets = timeline.buckets(for: .unisonPitchDiscrimination)
        let totalRecords = buckets.reduce(0) { $0 + $1.recordCount }
        #expect(totalRecords == 1)
    }

    @Test("profile pitch matching observer reflects in timeline")
    func profilePitchMatchingReflectsInTimeline() async {
        let profile = PerceptualProfile()
        let timeline = ProgressTimeline(profile: profile)
        #expect(timeline.state(for: .unisonPitchMatching) == .noData)

        let result = CompletedPitchMatchingTrial(
            referenceNote: MIDINote(60),
            targetNote: MIDINote(60),
            initialCentOffset: 50.0,
            userCentError: -3.0,
            tuningSystem: .equalTemperament
        )
        PitchMatchingProfileAdapter(profile: profile).pitchMatchingCompleted(result)

        let buckets = timeline.buckets(for: .unisonPitchMatching)
        let totalRecords = buckets.reduce(0) { $0 + $1.recordCount }
        #expect(totalRecords == 1)
    }

    @Test("profile interval comparison observer routes correctly")
    func profileIntervalObserverRouting() async {
        let profile = PerceptualProfile()
        let timeline = ProgressTimeline(profile: profile)

        let referenceNote = MIDINote(60)
        let targetNote = DetunedMIDINote(note: MIDINote(67), offset: Cents(10.0))
        let comparison = PitchDiscriminationTrial(referenceNote: referenceNote, targetNote: targetNote)
        let completed = CompletedPitchDiscriminationTrial(
            trial: comparison,
            userAnsweredHigher: true,
            tuningSystem: .equalTemperament
        )
        PitchDiscriminationProfileAdapter(profile: profile).pitchDiscriminationCompleted(completed)

        // Should route to interval comparison (interval != 0)
        let intervalBuckets = timeline.buckets(for: .intervalPitchDiscrimination)
        let intervalCount = intervalBuckets.reduce(0) { $0 + $1.recordCount }
        #expect(intervalCount == 1)

        // Unison should remain empty
        let unisonBuckets = timeline.buckets(for: .unisonPitchDiscrimination)
        let unisonCount = unisonBuckets.reduce(0) { $0 + $1.recordCount }
        #expect(unisonCount == 0)
    }

    @Test("profile updates within same session merge into one bucket in timeline")
    func profileSessionMerging() async {
        let profile = PerceptualProfile()
        let timeline = ProgressTimeline(profile: profile)

        let referenceNote = MIDINote(60)
        let targetNote = DetunedMIDINote(note: referenceNote, offset: Cents(10.0))
        let comparison = PitchDiscriminationTrial(referenceNote: referenceNote, targetNote: targetNote)

        let completed1 = CompletedPitchDiscriminationTrial(
            trial: comparison,
            userAnsweredHigher: true,
            tuningSystem: .equalTemperament
        )
        PitchDiscriminationProfileAdapter(profile: profile).pitchDiscriminationCompleted(completed1)

        let completed2 = CompletedPitchDiscriminationTrial(
            trial: comparison,
            userAnsweredHigher: true,
            tuningSystem: .equalTemperament
        )
        PitchDiscriminationProfileAdapter(profile: profile).pitchDiscriminationCompleted(completed2)

        let buckets = timeline.buckets(for: .unisonPitchDiscrimination)
        // Both records should be in the same session bucket
        #expect(buckets.count == 1)
        #expect(buckets.first?.recordCount == 2)
    }

    // MARK: - Trend Tests

    @Test("improving trend when latest value is below EWMA and within stddev")
    func improvingTrend() async {
        var records: [PitchDiscriminationRecord] = []
        for i in 0..<10 {
            records.append(makePitchDiscriminationRecord(centOffset: 20.0, hoursAgo: Double(12 - i)))
        }
        records.append(makePitchDiscriminationRecord(centOffset: 10.0, hoursAgo: 0.5))
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let trend = timeline.trend(for: .unisonPitchDiscrimination)
        #expect(trend == .improving)
    }

    @Test("declining trend when latest value is outside 1 stddev above mean")
    func decliningTrend() async {
        var records: [PitchDiscriminationRecord] = []
        for i in 0..<10 {
            records.append(makePitchDiscriminationRecord(centOffset: 10.0, hoursAgo: Double(12 - i)))
        }
        records.append(makePitchDiscriminationRecord(centOffset: 50.0, hoursAgo: 0.5))
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let trend = timeline.trend(for: .unisonPitchDiscrimination)
        #expect(trend == .declining)
    }

    @Test("stable trend when latest value is within stddev and at or above EWMA")
    func stableTrend() async {
        let records = makePitchDiscriminationRecords(count: 10, centOffset: 15.0)
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let trend = timeline.trend(for: .unisonPitchDiscrimination)
        #expect(trend == .stable)
    }

    @Test("no trend available with single record")
    func noTrendWithSingleRecord() async {
        let records = makePitchDiscriminationRecords(count: 1)
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let trend = timeline.trend(for: .unisonPitchDiscrimination)
        #expect(trend == nil)
    }

    @Test("trend available with 2+ records")
    func trendWithTwoRecords() async {
        let records = makePitchDiscriminationRecords(count: 2)
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let trend = timeline.trend(for: .unisonPitchDiscrimination)
        #expect(trend != nil)
    }

    @Test("declining trend from high centOffset added via profile")
    func decliningTrendFromProfileUpdate() async {
        // Start with correct records at low centOffset
        var records: [PitchDiscriminationRecord] = []
        for i in 0..<10 {
            records.append(makePitchDiscriminationRecord(centOffset: 8.0, hoursAgo: Double(12 - i)))
        }

        let profile = PerceptualProfile { builder in
            builder.feedPitchDiscriminations(records)
        }
        let timeline = ProgressTimeline(profile: profile)

        // Add a high centOffset via profile observer
        let referenceNote = MIDINote(60)
        let targetNote = DetunedMIDINote(note: referenceNote, offset: Cents(50.0))
        let comparison = PitchDiscriminationTrial(referenceNote: referenceNote, targetNote: targetNote)
        let completed = CompletedPitchDiscriminationTrial(
            trial: comparison,
            userAnsweredHigher: true,
            tuningSystem: .equalTemperament
        )
        PitchDiscriminationProfileAdapter(profile: profile).pitchDiscriminationCompleted(completed)

        let trend = timeline.trend(for: .unisonPitchDiscrimination)
        #expect(trend == .declining)
    }

    @Test("value exactly at runningMean + stddev is stable, not declining")
    func boundaryAtMeanPlusStddev() async {
        var records: [PitchDiscriminationRecord] = []
        for i in 0..<5 {
            records.append(makePitchDiscriminationRecord(centOffset: 10.0, hoursAgo: Double(12 - i)))
        }
        for i in 0..<5 {
            records.append(makePitchDiscriminationRecord(centOffset: 20.0, hoursAgo: Double(7 - i)))
        }
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let trend = timeline.trend(for: .unisonPitchDiscrimination)
        // value(20) == runningMean(15) + stddev(5) → NOT greater, so not declining
        #expect(trend != .declining)
    }

    @Test("value exactly at EWMA is stable, not improving")
    func boundaryAtEwma() async {
        let records = makePitchDiscriminationRecords(count: 5, centOffset: 12.0)
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let trend = timeline.trend(for: .unisonPitchDiscrimination)
        #expect(trend == .stable)
    }

    @Test("pitch matching declining when latest error is outside stddev")
    func pitchMatchingDecliningWhenOutsideStddev() async {
        var records: [PitchMatchingRecord] = []
        for i in 0..<10 {
            records.append(makePitchMatchingRecord(userCentError: 3.0, hoursAgo: Double(12 - i)))
        }
        records.append(makePitchMatchingRecord(userCentError: 40.0, hoursAgo: 0.5))
        let timeline = makeTimeline(pitchMatchingRecords: records)
        let trend = timeline.trend(for: .unisonPitchMatching)
        #expect(trend == .declining)
    }

    // MARK: - Sub-Bucket Tests

    @Test("subBuckets returns day-level buckets for a month bucket")
    func subBucketsMonthToDay() async {
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now.addingTimeInterval(-45 * 86400)))!
        let records = (0..<20).map { i in
            let dayOffset = Double(i % 28)
            let timestamp = monthStart.addingTimeInterval(dayOffset * 86400 + Double(i) * 60)
            return PitchDiscriminationRecord(
                referenceNote: 60,
                targetNote: 60,
                centOffset: 10.0 + Double(i),
                isCorrect: true,
                interval: 0,
                tuningSystem: "equalTemperament",
                timestamp: timestamp
            )
        }
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let buckets = timeline.buckets(for: .unisonPitchDiscrimination)
        guard let monthBucket = buckets.first(where: { $0.bucketSize == .month }) else {
            Issue.record("Expected at least one month bucket")
            return
        }
        let subs = timeline.subBuckets(for: .unisonPitchDiscrimination, expanding: monthBucket)
        #expect(!subs.isEmpty)
        for sub in subs {
            #expect(sub.bucketSize == .day)
        }
    }

    @Test("subBuckets returns session-level buckets for a day bucket")
    func subBucketsDayToSession() async {
        let baseDateHoursAgo = 36.0  // 1.5 days ago
        let records = [
            makePitchDiscriminationRecord(centOffset: 10.0, hoursAgo: baseDateHoursAgo),
            makePitchDiscriminationRecord(centOffset: 12.0, hoursAgo: baseDateHoursAgo - 0.01),
            // 2 hours later = different session
            makePitchDiscriminationRecord(centOffset: 8.0, hoursAgo: baseDateHoursAgo - 2.0),
            makePitchDiscriminationRecord(centOffset: 9.0, hoursAgo: baseDateHoursAgo - 2.01),
        ]
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let buckets = timeline.buckets(for: .unisonPitchDiscrimination)
        guard let dayBucket = buckets.first(where: { $0.bucketSize == .day }) else {
            Issue.record("Expected at least one day bucket")
            return
        }
        let subs = timeline.subBuckets(for: .unisonPitchDiscrimination, expanding: dayBucket)
        #expect(!subs.isEmpty)
        for sub in subs {
            #expect(sub.bucketSize == .session)
        }
    }

    @Test("subBuckets returns empty for session buckets (finest level)")
    func subBucketsSessionEmpty() async {
        let records = [
            makePitchDiscriminationRecord(centOffset: 10.0, hoursAgo: 1.0),
            makePitchDiscriminationRecord(centOffset: 12.0, hoursAgo: 0.99),
        ]
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let buckets = timeline.buckets(for: .unisonPitchDiscrimination)
        guard let sessionBucket = buckets.first(where: { $0.bucketSize == .session }) else {
            Issue.record("Expected at least one session bucket")
            return
        }
        let subs = timeline.subBuckets(for: .unisonPitchDiscrimination, expanding: sessionBucket)
        #expect(subs.isEmpty)
    }

    // MARK: - Multi-Granularity Bucket Tests

    @Test("multi-month data produces month, day, and session zones")
    func multiGranularityAllZones() async {
        let calendar = Calendar.current
        let now = Date()
        let midnightToday = calendar.startOfDay(for: now)

        let monthDate = calendar.startOfDay(for: now.addingTimeInterval(-45 * 86400)).addingTimeInterval(12 * 3600)
        let dayDate = calendar.startOfDay(for: now.addingTimeInterval(-5 * 86400)).addingTimeInterval(12 * 3600)
        let sessionDate = midnightToday.addingTimeInterval(60)

        let records = [
            makePitchDiscriminationRecord(centOffset: 10.0, date: monthDate),
            makePitchDiscriminationRecord(centOffset: 12.0, date: dayDate),
            makePitchDiscriminationRecord(centOffset: 8.0, date: sessionDate),
        ]
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let buckets = timeline.allGranularityBuckets(for: .unisonPitchDiscrimination)

        let sizes = Set(buckets.map(\.bucketSize))
        #expect(sizes.contains(.month))
        #expect(sizes.contains(.day))
        #expect(sizes.contains(.session))
    }

    @Test("single-day data produces only session buckets")
    func multiGranularitySingleDay() async {
        let calendar = Calendar.current
        let now = Date()
        let midnightToday = calendar.startOfDay(for: now)

        let records = [
            makePitchDiscriminationRecord(centOffset: 10.0, date: midnightToday.addingTimeInterval(60)),
            makePitchDiscriminationRecord(centOffset: 12.0, date: midnightToday.addingTimeInterval(120)),
        ]
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let buckets = timeline.allGranularityBuckets(for: .unisonPitchDiscrimination)

        #expect(!buckets.isEmpty)
        for bucket in buckets {
            #expect(bucket.bucketSize == .session)
        }
    }

    @Test("empty mode returns empty array for allGranularityBuckets")
    func multiGranularityEmpty() async {
        let timeline = ProgressTimeline(profile: PerceptualProfile())
        let buckets = timeline.allGranularityBuckets(for: .unisonPitchDiscrimination)
        #expect(buckets.isEmpty)
    }

    @Test("record exactly 30 days old goes to month zone")
    func multiGranularityBoundary30Days() async {
        let now = Date()
        let exactly30DaysAgo = now.addingTimeInterval(-30 * 86400)
        let records = [
            makePitchDiscriminationRecord(centOffset: 10.0, date: exactly30DaysAgo),
        ]
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let buckets = timeline.allGranularityBuckets(for: .unisonPitchDiscrimination)

        #expect(buckets.count == 1)
        #expect(buckets.first?.bucketSize == .month)
    }

    @Test("record exactly 24 hours old goes to day zone not session")
    func multiGranularityBoundary24Hours() async {
        let now = Date()
        let exactly24HoursAgo = now.addingTimeInterval(-24 * 3600)
        let records = [
            makePitchDiscriminationRecord(centOffset: 10.0, date: exactly24HoursAgo),
        ]
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let buckets = timeline.allGranularityBuckets(for: .unisonPitchDiscrimination)

        #expect(buckets.count == 1)
        #expect(buckets.first?.bucketSize == .day)
    }

    @Test("session merging in allGranularityBuckets for records within sessionGap")
    func multiGranularitySessionMerging() async {
        let calendar = Calendar.current
        let now = Date()
        let midnightToday = calendar.startOfDay(for: now)

        let records = [
            makePitchDiscriminationRecord(centOffset: 10.0, date: midnightToday.addingTimeInterval(60)),
            makePitchDiscriminationRecord(centOffset: 12.0, date: midnightToday.addingTimeInterval(660)),
        ]
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let buckets = timeline.allGranularityBuckets(for: .unisonPitchDiscrimination)

        #expect(buckets.count == 1)
        #expect(buckets.first?.recordCount == 2)
        #expect(buckets.first?.bucketSize == .session)
    }

    @Test("allGranularityBuckets are sorted chronologically")
    func multiGranularityChronologicalOrder() async {
        let calendar = Calendar.current
        let now = Date()
        let midnightToday = calendar.startOfDay(for: now)

        let monthDate = calendar.startOfDay(for: now.addingTimeInterval(-45 * 86400)).addingTimeInterval(12 * 3600)
        let dayDate = calendar.startOfDay(for: now.addingTimeInterval(-5 * 86400)).addingTimeInterval(12 * 3600)
        let sessionDate = midnightToday.addingTimeInterval(60)

        let records = [
            makePitchDiscriminationRecord(centOffset: 8.0, date: sessionDate),
            makePitchDiscriminationRecord(centOffset: 10.0, date: monthDate),
            makePitchDiscriminationRecord(centOffset: 12.0, date: dayDate),
        ]
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let buckets = timeline.allGranularityBuckets(for: .unisonPitchDiscrimination)

        for i in 1..<buckets.count {
            #expect(buckets[i].periodStart >= buckets[i - 1].periodStart)
        }
    }

    @Test("allGranularityBuckets retains correct BucketSize tag per zone")
    func multiGranularityBucketSizeTags() async {
        let calendar = Calendar.current
        let now = Date()
        let midnightToday = calendar.startOfDay(for: now)

        let monthDate = calendar.startOfDay(for: now.addingTimeInterval(-45 * 86400)).addingTimeInterval(12 * 3600)
        let dayDate = calendar.startOfDay(for: now.addingTimeInterval(-5 * 86400)).addingTimeInterval(12 * 3600)
        let sessionDate = midnightToday.addingTimeInterval(60)

        let records = [
            makePitchDiscriminationRecord(centOffset: 10.0, date: monthDate),
            makePitchDiscriminationRecord(centOffset: 12.0, date: dayDate),
            makePitchDiscriminationRecord(centOffset: 8.0, date: sessionDate),
        ]
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let buckets = timeline.allGranularityBuckets(for: .unisonPitchDiscrimination)

        let monthBuckets = buckets.filter { $0.bucketSize == .month }
        let dayBuckets = buckets.filter { $0.bucketSize == .day }
        let sessionBuckets = buckets.filter { $0.bucketSize == .session }

        #expect(!monthBuckets.isEmpty)
        #expect(!dayBuckets.isEmpty)
        #expect(!sessionBuckets.isEmpty)

        if let lastMonth = monthBuckets.last, let firstDay = dayBuckets.first {
            #expect(lastMonth.periodStart < firstDay.periodStart)
        }
        if let lastDay = dayBuckets.last, let firstSession = sessionBuckets.first {
            #expect(lastDay.periodStart < firstSession.periodStart)
        }
    }

    @Test("day and session zones only when no data older than 30 days")
    func multiGranularityDayAndSessionOnly() async {
        let calendar = Calendar.current
        let now = Date()
        let midnightToday = calendar.startOfDay(for: now)

        let dayDate = calendar.startOfDay(for: now.addingTimeInterval(-5 * 86400)).addingTimeInterval(12 * 3600)
        let sessionDate = midnightToday.addingTimeInterval(60)

        let records = [
            makePitchDiscriminationRecord(centOffset: 12.0, date: dayDate),
            makePitchDiscriminationRecord(centOffset: 8.0, date: sessionDate),
        ]
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let buckets = timeline.allGranularityBuckets(for: .unisonPitchDiscrimination)

        let sizes = Set(buckets.map(\.bucketSize))
        #expect(!sizes.contains(.month))
        #expect(sizes.contains(.day))
        #expect(sizes.contains(.session))
    }

    // MARK: - Calendar-Snapped Zone Boundary Tests

    @Test("session zone starts at midnight today, not 24h rolling window")
    func calendarSnappedSessionZone() async {
        let calendar = Calendar.current
        let now = Date()
        let midnightToday = calendar.startOfDay(for: now)

        let justAfterMidnight = midnightToday.addingTimeInterval(60)
        let justBeforeMidnight = midnightToday.addingTimeInterval(-60)

        let records = [
            makePitchDiscriminationRecord(centOffset: 10.0, date: justBeforeMidnight),
            makePitchDiscriminationRecord(centOffset: 12.0, date: justAfterMidnight),
        ]
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let buckets = timeline.allGranularityBuckets(for: .unisonPitchDiscrimination)

        let sessionBuckets = buckets.filter { $0.bucketSize == .session }
        let dayBuckets = buckets.filter { $0.bucketSize == .day }
        #expect(!sessionBuckets.isEmpty, "Record after midnight today should be in session zone")
        #expect(!dayBuckets.isEmpty, "Record before midnight today should be in day zone")
    }

    @Test("day zone covers 7 calendar days before today")
    func calendarSnappedDayZone() async {
        let calendar = Calendar.current
        let now = Date()
        let midnightToday = calendar.startOfDay(for: now)
        let dayStart = calendar.date(byAdding: .day, value: -7, to: midnightToday)!

        let inDayZone = dayStart.addingTimeInterval(3600)
        let inMonthZone = dayStart.addingTimeInterval(-3600)

        let records = [
            makePitchDiscriminationRecord(centOffset: 10.0, date: inMonthZone),
            makePitchDiscriminationRecord(centOffset: 12.0, date: inDayZone),
        ]
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let buckets = timeline.allGranularityBuckets(for: .unisonPitchDiscrimination)

        let dayBuckets = buckets.filter { $0.bucketSize == .day }
        let monthBuckets = buckets.filter { $0.bucketSize == .month }
        #expect(!dayBuckets.isEmpty, "Record within 7 calendar days should be in day zone")
        #expect(!monthBuckets.isEmpty, "Record older than 7 calendar days should be in month zone")
    }

    @Test("last monthly bucket is truncated at day zone start date")
    func monthBucketTruncatedAtDayZoneStart() async {
        let calendar = Calendar.current
        let now = Date()
        let midnightToday = calendar.startOfDay(for: now)
        let dayStart = calendar.date(byAdding: .day, value: -7, to: midnightToday)!

        let inMonthZone = calendar.date(byAdding: .day, value: -2, to: dayStart)!.addingTimeInterval(12 * 3600)
        let inDayZone = dayStart.addingTimeInterval(86400 + 12 * 3600)

        let records = [
            makePitchDiscriminationRecord(centOffset: 10.0, date: inMonthZone),
            makePitchDiscriminationRecord(centOffset: 12.0, date: inDayZone),
        ]
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let buckets = timeline.allGranularityBuckets(for: .unisonPitchDiscrimination)

        let monthBuckets = buckets.filter { $0.bucketSize == .month }
        let dayBuckets = buckets.filter { $0.bucketSize == .day }

        #expect(!monthBuckets.isEmpty)
        #expect(!dayBuckets.isEmpty)

        if let lastMonth = monthBuckets.last {
            #expect(lastMonth.periodEnd <= dayStart, "Monthly bucket should be truncated at dayStart")
        }
    }

    @Test("new user with only today's data produces only session buckets")
    func newUserOnlySessionBuckets() async {
        let calendar = Calendar.current
        let now = Date()
        let midnightToday = calendar.startOfDay(for: now)

        let records = [
            makePitchDiscriminationRecord(centOffset: 10.0, date: midnightToday.addingTimeInterval(60)),
            makePitchDiscriminationRecord(centOffset: 12.0, date: midnightToday.addingTimeInterval(120)),
            makePitchDiscriminationRecord(centOffset: 8.0, date: midnightToday.addingTimeInterval(180)),
        ]
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let buckets = timeline.allGranularityBuckets(for: .unisonPitchDiscrimination)

        #expect(!buckets.isEmpty)
        let dayBuckets = buckets.filter { $0.bucketSize == .day }
        let monthBuckets = buckets.filter { $0.bucketSize == .month }
        #expect(dayBuckets.isEmpty, "New user with only today's data should have no day buckets")
        #expect(monthBuckets.isEmpty, "New user with only today's data should have no month buckets")
    }

    @Test("buckets(for:) delegates to allGranularityBuckets producing calendar-snapped results")
    func bucketsForDelegatesToAllGranularity() async {
        let calendar = Calendar.current
        let now = Date()
        let midnightToday = calendar.startOfDay(for: now)

        // All three records are today (session zone)
        let records = [
            makePitchDiscriminationRecord(centOffset: 10.0, date: midnightToday.addingTimeInterval(60)),
            makePitchDiscriminationRecord(centOffset: 12.0, date: midnightToday.addingTimeInterval(120)),
            makePitchDiscriminationRecord(centOffset: 8.0, date: midnightToday.addingTimeInterval(7200)),
        ]
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let buckets = timeline.buckets(for: .unisonPitchDiscrimination)
        let allGranBuckets = timeline.allGranularityBuckets(for: .unisonPitchDiscrimination)

        // buckets(for:) and allGranularityBuckets(for:) must return identical results
        #expect(buckets.count == allGranBuckets.count)
        let totalRecords = buckets.reduce(0) { $0 + $1.recordCount }
        #expect(totalRecords == 3)
    }

    // MARK: - Sub-Bucket Tests

    @Test("sub-bucket record counts are consistent with parent bucket")
    func subBucketRecordCountConsistency() async {
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now.addingTimeInterval(-90 * 86400)))!
        let records = (0..<15).map { i in
            let dayOffset = Double(i)
            let timestamp = monthStart.addingTimeInterval(dayOffset * 86400 + Double(i) * 60)
            return PitchDiscriminationRecord(
                referenceNote: 60,
                targetNote: 60,
                centOffset: 10.0,
                isCorrect: true,
                interval: 0,
                tuningSystem: "equalTemperament",
                timestamp: timestamp
            )
        }
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let buckets = timeline.buckets(for: .unisonPitchDiscrimination)
        guard let monthBucket = buckets.first(where: { $0.bucketSize == .month }) else {
            Issue.record("Expected at least one month bucket")
            return
        }
        let subs = timeline.subBuckets(for: .unisonPitchDiscrimination, expanding: monthBucket)
        let subRecordCount = subs.reduce(0) { $0 + $1.recordCount }
        #expect(subRecordCount == monthBucket.recordCount)
    }

    // MARK: - Session Merging Bug Regression (ST-1)

    @Test("long session merges correctly when each record is within sessionGap of the previous one")
    func longSessionMergesCorrectly() async {
        let calendar = Calendar.current
        let now = Date()
        let midnightToday = calendar.startOfDay(for: now)

        // 3 records today, each 20 minutes apart (< 30 min sessionGap).
        // Total span is 40 minutes from first to last, but each consecutive gap is only 20 min.
        // The old assignBuckets compared against session START (record 1), so record 3
        // at +40min would incorrectly split because 40min > 30min sessionGap.
        // The correct behavior compares against the LAST record's timestamp.
        let records = [
            makePitchDiscriminationRecord(centOffset: 10.0, date: midnightToday.addingTimeInterval(60)),
            makePitchDiscriminationRecord(centOffset: 12.0, date: midnightToday.addingTimeInterval(60 + 20 * 60)),
            makePitchDiscriminationRecord(centOffset: 14.0, date: midnightToday.addingTimeInterval(60 + 40 * 60)),
        ]
        let timeline = makeTimeline(pitchDiscriminationRecords: records)
        let buckets = timeline.buckets(for: .unisonPitchDiscrimination)

        // All 3 should be in ONE session bucket
        #expect(buckets.count == 1, "All 3 records should merge into one session bucket")
        #expect(buckets.first?.recordCount == 3)
    }

    // MARK: - Rhythm Mode Tests

    @Test("rhythmOffsetDetection state is active with rhythm offset detection data")
    func rhythmOffsetDetectionActive() async {
        let records = [
            RhythmOffsetDetectionRecord(tempoBPM: 120, offsetMs: -20.0, isCorrect: true, timestamp: now.addingTimeInterval(-3600))
        ]
        let timeline = makeTimeline(rhythmOffsetDetectionRecords: records)
        #expect(timeline.state(for: .rhythmOffsetDetection) == .active)
    }

    @Test("rhythmOffsetDetection remains noData when only incorrect records exist")
    func rhythmOffsetDetectionNoDataWhenIncorrect() async {
        let records = [
            RhythmOffsetDetectionRecord(tempoBPM: 120, offsetMs: -20.0, isCorrect: false, timestamp: now.addingTimeInterval(-3600))
        ]
        let timeline = makeTimeline(rhythmOffsetDetectionRecords: records)
        #expect(timeline.state(for: .rhythmOffsetDetection) == .noData)
    }

    @Test("rhythmOffsetDetection buckets are produced from rhythm data")
    func rhythmOffsetDetectionBuckets() async {
        let records = (0..<5).map { i in
            RhythmOffsetDetectionRecord(
                tempoBPM: 120,
                offsetMs: -20.0 + Double(i),
                isCorrect: true,
                timestamp: now.addingTimeInterval(-3600 + Double(i) * 60)
            )
        }
        let timeline = makeTimeline(rhythmOffsetDetectionRecords: records)
        let buckets = timeline.buckets(for: .rhythmOffsetDetection)
        #expect(!buckets.isEmpty)
        let totalRecords = buckets.reduce(0) { $0 + $1.recordCount }
        #expect(totalRecords == 5)
    }

    @Test("rhythm modes merge across tempo ranges and directions")
    func rhythmModesMergeAcrossKeys() async {
        let records = [
            // slow tempo (60 BPM), early
            RhythmOffsetDetectionRecord(tempoBPM: 60, offsetMs: -10.0, isCorrect: true, timestamp: now.addingTimeInterval(-3600)),
            // fast tempo (180 BPM), late
            RhythmOffsetDetectionRecord(tempoBPM: 180, offsetMs: 15.0, isCorrect: true, timestamp: now.addingTimeInterval(-3500)),
        ]
        let timeline = makeTimeline(rhythmOffsetDetectionRecords: records)
        #expect(timeline.recordCount(for: .rhythmOffsetDetection) == 2)
        #expect(timeline.currentEWMA(for: .rhythmOffsetDetection) != nil)
    }
}
