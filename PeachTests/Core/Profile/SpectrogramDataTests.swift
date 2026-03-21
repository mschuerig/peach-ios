import Foundation
import Testing
@testable import Peach

@Suite("SpectrogramData")
struct SpectrogramDataTests {

    // MARK: - Thresholds

    @Test("default thresholds are 5% and 15%")
    func defaultThresholds() async {
        let thresholds = SpectrogramThresholds.default
        #expect(thresholds.preciseUpperBound == 5.0)
        #expect(thresholds.moderateUpperBound == 15.0)
    }

    @Test("accuracy level returns precise for value at upper bound")
    func accuracyLevelPrecise() async {
        let level = SpectrogramThresholds.default.accuracyLevel(for: 5.0)
        #expect(level == .precise)
    }

    @Test("accuracy level returns moderate for value between bounds")
    func accuracyLevelModerate() async {
        let level = SpectrogramThresholds.default.accuracyLevel(for: 10.0)
        #expect(level == .moderate)
    }

    @Test("accuracy level returns erratic for value above moderate bound")
    func accuracyLevelErratic() async {
        let level = SpectrogramThresholds.default.accuracyLevel(for: 20.0)
        #expect(level == .erratic)
    }

    @Test("accuracy level returns nil for nil input")
    func accuracyLevelNil() async {
        let level = SpectrogramThresholds.default.accuracyLevel(for: nil)
        #expect(level == nil)
    }

    // MARK: - TempoRange midpointTempo

    @Test("midpoint tempo for slow range is 60 BPM")
    func slowMidpoint() async {
        #expect(TempoRange.slow.midpointTempo == TempoBPM(60))
    }

    @Test("midpoint tempo for medium range is 100 BPM")
    func mediumMidpoint() async {
        #expect(TempoRange.medium.midpointTempo == TempoBPM(100))
    }

    @Test("midpoint tempo for fast range is 160 BPM")
    func fastMidpoint() async {
        #expect(TempoRange.fast.midpointTempo == TempoBPM(160))
    }

    // MARK: - SpectrogramData computation

    @Test("empty profile produces empty spectrogram")
    func emptyProfile() async {
        let profile = PerceptualProfile()
        let timeline = ProgressTimeline(profile: profile)
        let data = SpectrogramData.compute(
            mode: .rhythmOffsetDetection,
            profile: profile,
            timeBuckets: timeline.allGranularityBuckets(for: .rhythmOffsetDetection)
        )
        #expect(data.columns.isEmpty)
        #expect(data.trainedRanges.isEmpty)
    }

    @Test("single tempo range with data produces one trained range")
    func singleTempoRange() async {
        let profile = makeProfileWithSlowData()
        let timeline = ProgressTimeline(profile: profile)
        let data = SpectrogramData.compute(
            mode: .rhythmOffsetDetection,
            profile: profile,
            timeBuckets: timeline.allGranularityBuckets(for: .rhythmOffsetDetection)
        )
        #expect(data.trainedRanges == [.slow])
        #expect(!data.columns.isEmpty)
    }

    @Test("multiple tempo ranges produce sorted trained ranges")
    func multipleTempoRanges() async {
        let profile = makeProfileWithSlowAndFastData()
        let timeline = ProgressTimeline(profile: profile)
        let data = SpectrogramData.compute(
            mode: .rhythmOffsetDetection,
            profile: profile,
            timeBuckets: timeline.allGranularityBuckets(for: .rhythmOffsetDetection)
        )
        #expect(data.trainedRanges == [.slow, .fast])
    }

    @Test("untrained ranges are excluded from trainedRanges")
    func untrainedRangesExcluded() async {
        let profile = makeProfileWithSlowAndFastData()
        let timeline = ProgressTimeline(profile: profile)
        let data = SpectrogramData.compute(
            mode: .rhythmOffsetDetection,
            profile: profile,
            timeBuckets: timeline.allGranularityBuckets(for: .rhythmOffsetDetection)
        )
        // medium range has no data — must not appear in trainedRanges or any cell
        #expect(!data.trainedRanges.contains(.medium))
        for column in data.columns {
            #expect(!column.cells.contains(where: { $0.tempoRange == .medium }))
        }
    }

    @Test("cell accuracy is computed as percentage of sixteenth note")
    func cellAccuracyIsPercentage() async {
        // 10ms at slow midpoint (60 BPM): sixteenth = 250ms → 10/250*100 = 4.0%
        let profile = makeProfileWithKnownValue(ms: 10.0, range: .slow, direction: .early)
        let timeline = ProgressTimeline(profile: profile)
        let data = SpectrogramData.compute(
            mode: .rhythmOffsetDetection,
            profile: profile,
            timeBuckets: timeline.allGranularityBuckets(for: .rhythmOffsetDetection)
        )
        guard let column = data.columns.first,
              let cell = column.cells.first(where: { $0.tempoRange == .slow }) else {
            Issue.record("Expected a column with a slow cell")
            return
        }
        guard let accuracy = cell.meanAccuracyPercent else {
            Issue.record("Expected non-nil accuracy")
            return
        }
        #expect(abs(accuracy - 4.0) < 0.01)
    }

    @Test("early and late stats are populated separately")
    func earlyLateStatsSeparate() async {
        let profile = makeProfileWithEarlyAndLateData()
        let timeline = ProgressTimeline(profile: profile)
        let data = SpectrogramData.compute(
            mode: .rhythmOffsetDetection,
            profile: profile,
            timeBuckets: timeline.allGranularityBuckets(for: .rhythmOffsetDetection)
        )
        guard let column = data.columns.first,
              let cell = column.cells.first(where: { $0.tempoRange == .slow }) else {
            Issue.record("Expected a column with a slow cell")
            return
        }
        #expect(cell.earlyStats != nil)
        #expect(cell.lateStats != nil)
        #expect(cell.earlyStats?.count == 3)
        #expect(cell.lateStats?.count == 3)
    }

    @Test("columns match time bucket count")
    func columnsMatchBuckets() async {
        let profile = makeProfileWithSlowData()
        let timeline = ProgressTimeline(profile: profile)
        let buckets = timeline.allGranularityBuckets(for: .rhythmOffsetDetection)
        let data = SpectrogramData.compute(
            mode: .rhythmOffsetDetection,
            profile: profile,
            timeBuckets: buckets
        )
        #expect(data.columns.count == buckets.count)
    }

    @Test("each column has cells for all trained ranges")
    func columnsHaveCellsForAllRanges() async {
        let profile = makeProfileWithSlowAndFastData()
        let timeline = ProgressTimeline(profile: profile)
        let data = SpectrogramData.compute(
            mode: .rhythmOffsetDetection,
            profile: profile,
            timeBuckets: timeline.allGranularityBuckets(for: .rhythmOffsetDetection)
        )
        for column in data.columns {
            let ranges = column.cells.map(\.tempoRange)
            #expect(ranges.contains(.slow))
            #expect(ranges.contains(.fast))
        }
    }

    // MARK: - TempoRange displayName

    @Test("tempo range display names are localized")
    func tempoRangeDisplayNames() async {
        #expect(!TempoRange.slow.displayName.isEmpty)
        #expect(!TempoRange.medium.displayName.isEmpty)
        #expect(!TempoRange.fast.displayName.isEmpty)
    }

    // MARK: - Factories

    private func makeProfileWithSlowData() -> PerceptualProfile {
        PerceptualProfile { builder in
            let now = Date()
            for i in 0..<5 {
                builder.addPoint(
                    MetricPoint(
                        timestamp: now.addingTimeInterval(Double(i) * 60),
                        value: 10.0 + Double(i)
                    ),
                    for: .rhythm(.rhythmOffsetDetection, .slow, .early)
                )
            }
        }
    }

    private func makeProfileWithSlowAndFastData() -> PerceptualProfile {
        PerceptualProfile { builder in
            let now = Date()
            for i in 0..<5 {
                builder.addPoint(
                    MetricPoint(
                        timestamp: now.addingTimeInterval(Double(i) * 60),
                        value: 10.0
                    ),
                    for: .rhythm(.rhythmOffsetDetection, .slow, .early)
                )
                builder.addPoint(
                    MetricPoint(
                        timestamp: now.addingTimeInterval(Double(i) * 60),
                        value: 5.0
                    ),
                    for: .rhythm(.rhythmOffsetDetection, .fast, .late)
                )
            }
        }
    }

    private func makeProfileWithKnownValue(ms: Double, range: TempoRange, direction: RhythmDirection) -> PerceptualProfile {
        PerceptualProfile { builder in
            let now = Date()
            builder.addPoint(
                MetricPoint(timestamp: now, value: ms),
                for: .rhythm(.rhythmOffsetDetection, range, direction)
            )
        }
    }

    private func makeProfileWithEarlyAndLateData() -> PerceptualProfile {
        PerceptualProfile { builder in
            let now = Date()
            for i in 0..<3 {
                builder.addPoint(
                    MetricPoint(
                        timestamp: now.addingTimeInterval(Double(i) * 60),
                        value: 8.0
                    ),
                    for: .rhythm(.rhythmOffsetDetection, .slow, .early)
                )
                builder.addPoint(
                    MetricPoint(
                        timestamp: now.addingTimeInterval(Double(i) * 60),
                        value: 12.0
                    ),
                    for: .rhythm(.rhythmOffsetDetection, .slow, .late)
                )
            }
        }
    }
}
