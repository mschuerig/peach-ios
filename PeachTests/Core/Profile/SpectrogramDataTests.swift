import Foundation
import Testing
@testable import Peach

@Suite("SpectrogramData")
struct SpectrogramDataTests {

    // MARK: - Thresholds

    @Test("default thresholds have expected base percentages and clamp values")
    func defaultThresholds() async {
        let thresholds = SpectrogramThresholds.default
        #expect(thresholds.preciseBasePercent == 8.0)
        #expect(thresholds.moderateBasePercent == 20.0)
        #expect(thresholds.preciseFloorMs == 12.0)
        #expect(thresholds.moderateFloorMs == 25.0)
        #expect(thresholds.preciseCeilingMs == 30.0)
        #expect(thresholds.moderateCeilingMs == 50.0)
    }

    @Test("accuracy level returns nil for nil input")
    func accuracyLevelNil() async {
        let level = SpectrogramThresholds.default.accuracyLevel(for: nil, tempoRange: .medium)
        #expect(level == nil)
    }

    @Test("at medium tempo, 7% is precise (floor binds at 12 ms)")
    func preciseAtMediumTempo() async {
        // Medium midpoint = 100 BPM, sixteenth = 150ms
        // precise threshold = clamp(150 * 0.08, 12, 30) = clamp(12, 12, 30) = 12ms → 8.0%
        // Floor binds exactly (raw 12ms = floor 12ms), effective threshold = 8.0%
        let level = SpectrogramThresholds.default.accuracyLevel(for: 7.0, tempoRange: .medium)
        #expect(level == .precise)
    }

    @Test("at medium tempo, 15% is moderate")
    func moderateAtMediumTempo() async {
        // moderate threshold = clamp(150 * 0.20, 25, 50) = 30ms → 20.0%
        let level = SpectrogramThresholds.default.accuracyLevel(for: 15.0, tempoRange: .medium)
        #expect(level == .moderate)
    }

    @Test("at medium tempo, 25% is erratic")
    func erraticAtMediumTempo() async {
        let level = SpectrogramThresholds.default.accuracyLevel(for: 25.0, tempoRange: .medium)
        #expect(level == .erratic)
    }

    @Test("at fast tempo, floor clamps precise threshold upward")
    func floorClampsAtFastTempo() async {
        // Fast midpoint = 160 BPM, sixteenth = 93.75ms
        // precise threshold = clamp(93.75 * 0.08, 12, 30) = clamp(7.5, 12, 30) = 12ms → 12.8%
        // 10% of 93.75ms = 9.375ms < 12ms floor, so 10% should still be precise
        let level = SpectrogramThresholds.default.accuracyLevel(for: 10.0, tempoRange: .fast)
        #expect(level == .precise)
    }

    @Test("at fast tempo, moderate floor clamps upward")
    func moderateFloorClampsAtFastTempo() async {
        // moderate threshold = clamp(93.75 * 0.20, 25, 50) = clamp(18.75, 25, 50) = 25ms → 26.7%
        // 22% of 93.75ms = 20.625ms < 25ms floor, so 22% should be moderate
        let level = SpectrogramThresholds.default.accuracyLevel(for: 22.0, tempoRange: .fast)
        #expect(level == .moderate)
    }

    @Test("at slow tempo, ceiling binds at moderate boundary (raw = ceiling)")
    func ceilingBindsAtSlowTempo() async {
        // Slow midpoint = 60 BPM, sixteenth = 250ms
        // moderate threshold = clamp(250 * 0.20, 25, 50) = clamp(50, 25, 50) = 50ms → 20.0%
        // Raw value (50ms) exactly equals ceiling — ceiling is binding at boundary
        // 15% of 250ms = 37.5ms < 50ms ceiling → moderate
        let level = SpectrogramThresholds.default.accuracyLevel(for: 15.0, tempoRange: .slow)
        #expect(level == .moderate)
    }

    @Test("at fast tempo, floor widens precise band beyond base 8%")
    func floorWidensPreciseBand() async {
        // Fast midpoint = 160 BPM, sixteenth = 93.75ms
        // Without floor: precise < 8.0%, moderate < 20.0%
        // With floor: precise = 12ms → 12.8%, moderate = 25ms → 26.7%
        // 12% is above the base 8% but below the floor-adjusted 12.8% → still precise
        let thresholds = SpectrogramThresholds.default
        let level = thresholds.accuracyLevel(for: 12.0, tempoRange: .fast)
        #expect(level == .precise)
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

    // MARK: - Sample Variance (Bessel's Correction)

    @Test("cell stddev uses sample variance not population variance")
    func cellStdDevUsesSampleVariance() async {
        // Three early metrics at slow tempo: 10ms, 20ms, 30ms
        // Mean = 20ms, sample variance = ((10-20)²+(20-20)²+(30-20)²)/(3-1) = 200/2 = 100
        // Sample stddev = 10ms
        // As % of sixteenth at 60 BPM (250ms): 10/250*100 = 4.0%
        // Population stddev would be √(200/3) ≈ 8.165ms → 3.27%
        let profile = PerceptualProfile { builder in
            let now = Date()
            builder.addPoint(
                MetricPoint(timestamp: now, value: 10.0),
                for: .rhythm(.rhythmOffsetDetection, .slow, .early)
            )
            builder.addPoint(
                MetricPoint(timestamp: now.addingTimeInterval(60), value: 20.0),
                for: .rhythm(.rhythmOffsetDetection, .slow, .early)
            )
            builder.addPoint(
                MetricPoint(timestamp: now.addingTimeInterval(120), value: 30.0),
                for: .rhythm(.rhythmOffsetDetection, .slow, .early)
            )
        }
        let timeline = ProgressTimeline(profile: profile)
        let data = SpectrogramData.compute(
            mode: .rhythmOffsetDetection,
            profile: profile,
            timeBuckets: timeline.allGranularityBuckets(for: .rhythmOffsetDetection)
        )
        guard let column = data.columns.first,
              let cell = column.cells.first(where: { $0.tempoRange == .slow }),
              let earlyStats = cell.earlyStats else {
            Issue.record("Expected a column with slow cell and early stats")
            return
        }
        // Sample stddev = 10ms → 4.0% of 250ms sixteenth
        #expect(abs(earlyStats.stdDevPercent - 4.0) < 0.01)
    }

    // MARK: - Combined Mean (Bimodal Distribution Bug)

    @Test("equal-magnitude early and late offsets produce non-zero combined accuracy")
    func bimodalMeanDoesNotCancelOut() async {
        // Early hits at 50ms, late hits at 50ms (absolute) at slow midpoint (60 BPM)
        // Sixteenth = 250ms → 50/250*100 = 20%
        // Bug: if signed mean were used, -50 + 50 would cancel to ~0%
        let profile = makeProfileWithSymmetricEarlyLate(ms: 50.0, range: .slow)
        let timeline = ProgressTimeline(profile: profile)
        let data = SpectrogramData.compute(
            mode: .rhythmOffsetDetection,
            profile: profile,
            timeBuckets: timeline.allGranularityBuckets(for: .rhythmOffsetDetection)
        )
        guard let column = data.columns.first,
              let cell = column.cells.first(where: { $0.tempoRange == .slow }),
              let accuracy = cell.meanAccuracyPercent else {
            Issue.record("Expected a column with slow cell and non-nil accuracy")
            return
        }
        // Must be ~20%, not ~0%
        #expect(abs(accuracy - 20.0) < 0.5)
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

    private func makeProfileWithSymmetricEarlyLate(ms: Double, range: TempoRange) -> PerceptualProfile {
        PerceptualProfile { builder in
            let now = Date()
            for i in 0..<5 {
                builder.addPoint(
                    MetricPoint(
                        timestamp: now.addingTimeInterval(Double(i) * 60),
                        value: ms
                    ),
                    for: .rhythm(.rhythmOffsetDetection, range, .early)
                )
                builder.addPoint(
                    MetricPoint(
                        timestamp: now.addingTimeInterval(Double(i) * 60),
                        value: ms
                    ),
                    for: .rhythm(.rhythmOffsetDetection, range, .late)
                )
            }
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
