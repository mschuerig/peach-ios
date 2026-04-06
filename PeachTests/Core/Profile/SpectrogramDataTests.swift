import Foundation
import Testing
@testable import Peach

@Suite("SpectrogramData")
struct SpectrogramDataTests {

    // MARK: - Thresholds

    @Test("default thresholds have expected boundary values")
    func defaultThresholds() async {
        let t = SpectrogramThresholds.default
        #expect(t.excellent.basePercent == 4.0)
        #expect(t.excellent.floorMs == 8.0)
        #expect(t.excellent.ceilingMs == 15.0)
        #expect(t.precise.basePercent == 8.0)
        #expect(t.precise.floorMs == 12.0)
        #expect(t.precise.ceilingMs == 30.0)
        #expect(t.moderate.basePercent == 15.0)
        #expect(t.moderate.floorMs == 20.0)
        #expect(t.moderate.ceilingMs == 40.0)
        #expect(t.loose.basePercent == 25.0)
        #expect(t.loose.floorMs == 30.0)
        #expect(t.loose.ceilingMs == 55.0)
    }

    @Test("accuracy level returns nil for nil input")
    func accuracyLevelNil() async {
        let level = SpectrogramThresholds.default.accuracyLevel(for: nil, tempoRange: .brisk)
        #expect(level == nil)
    }

    @Test("at brisk tempo, very low percentage is excellent")
    func excellentAtBriskTempo() async {
        // Brisk midpoint = 110 BPM, sixteenth = 136.4ms
        // excellent = clamp(136.4 * 0.04, 8, 15) = clamp(5.45, 8, 15) = 8ms → 5.87%
        let level = SpectrogramThresholds.default.accuracyLevel(for: 3.0, tempoRange: .brisk)
        #expect(level == .excellent)
    }

    @Test("at brisk tempo, 7% is precise")
    func preciseAtBriskTempo() async {
        // precise = clamp(136.4 * 0.08, 12, 30) = clamp(10.9, 12, 30) = 12ms → 8.8%
        let level = SpectrogramThresholds.default.accuracyLevel(for: 7.0, tempoRange: .brisk)
        #expect(level == .precise)
    }

    @Test("at brisk tempo, 12% is moderate")
    func moderateAtBriskTempo() async {
        // moderate = clamp(136.4 * 0.15, 20, 40) = clamp(20.45, 20, 40) = 20.45ms → 15.0%
        let level = SpectrogramThresholds.default.accuracyLevel(for: 12.0, tempoRange: .brisk)
        #expect(level == .moderate)
    }

    @Test("at brisk tempo, 20% is loose")
    func looseAtBriskTempo() async {
        // loose = clamp(136.4 * 0.25, 30, 55) = clamp(34.1, 30, 55) = 34.1ms → 25.0%
        let level = SpectrogramThresholds.default.accuracyLevel(for: 20.0, tempoRange: .brisk)
        #expect(level == .loose)
    }

    @Test("at brisk tempo, 30% is erratic")
    func erraticAtBriskTempo() async {
        let level = SpectrogramThresholds.default.accuracyLevel(for: 30.0, tempoRange: .brisk)
        #expect(level == .erratic)
    }

    @Test("at veryFast tempo, floor clamps precise threshold upward")
    func floorClampsAtVeryFastTempo() async {
        // VeryFast midpoint = 180 BPM, sixteenth = 83.3ms
        // precise = clamp(83.3 * 0.08, 12, 30) = clamp(6.67, 12, 30) = 12ms → 14.4%
        // 10% of 83.3ms = 8.33ms < 12ms floor → still precise
        let level = SpectrogramThresholds.default.accuracyLevel(for: 10.0, tempoRange: .veryFast)
        #expect(level == .precise)
    }

    @Test("at veryFast tempo, moderate floor clamps upward")
    func moderateFloorClampsAtVeryFastTempo() async {
        // moderate = clamp(83.3 * 0.15, 20, 40) = clamp(12.5, 20, 40) = 20ms → 24.0%
        // 18% of 83.3ms = 15ms < 20ms floor → still moderate
        let level = SpectrogramThresholds.default.accuracyLevel(for: 18.0, tempoRange: .veryFast)
        #expect(level == .moderate)
    }

    @Test("at verySlow tempo, ceiling binds at moderate boundary")
    func ceilingBindsAtVerySlowTempo() async {
        // VerySlow midpoint = 50 BPM, sixteenth = 300ms
        // moderate = clamp(300 * 0.15, 20, 40) = clamp(45, 20, 40) = 40ms → 13.3%
        // 12% of 300ms = 36ms < 40ms ceiling → moderate
        let level = SpectrogramThresholds.default.accuracyLevel(for: 12.0, tempoRange: .verySlow)
        #expect(level == .moderate)
    }

    @Test("at veryFast tempo, floor widens precise band beyond base 8%")
    func floorWidensPreciseBand() async {
        // VeryFast midpoint = 180 BPM, sixteenth = 83.3ms
        // precise = 12ms → 14.4%
        // 12% is above base 8% but below floor-adjusted 14.4% → still precise
        let level = SpectrogramThresholds.default.accuracyLevel(for: 12.0, tempoRange: .veryFast)
        #expect(level == .precise)
    }

    @Test("five distinct accuracy levels are returned across the range")
    func fiveDistinctLevels() async {
        let t = SpectrogramThresholds.default
        let range = TempoRange.brisk
        #expect(t.accuracyLevel(for: 1.0, tempoRange: range) == .excellent)
        #expect(t.accuracyLevel(for: 7.0, tempoRange: range) == .precise)
        #expect(t.accuracyLevel(for: 12.0, tempoRange: range) == .moderate)
        #expect(t.accuracyLevel(for: 20.0, tempoRange: range) == .loose)
        #expect(t.accuracyLevel(for: 50.0, tempoRange: range) == .erratic)
    }

    // MARK: - TempoRange midpointTempo

    @Test("midpoint tempo for verySlow range is 50 BPM")
    func verySlowMidpoint() async {
        #expect(TempoRange.verySlow.midpointTempo == TempoBPM(50))
    }

    @Test("midpoint tempo for slow range is 70 BPM")
    func slowMidpoint() async {
        #expect(TempoRange.slow.midpointTempo == TempoBPM(70))
    }

    @Test("midpoint tempo for fast range is 140 BPM")
    func fastMidpoint() async {
        #expect(TempoRange.fast.midpointTempo == TempoBPM(140))
    }

    // MARK: - SpectrogramData computation

    @Test("empty profile produces empty spectrogram")
    func emptyProfile() async {
        let profile = PerceptualProfile()
        let timeline = ProgressTimeline(profile: profile)
        let data = SpectrogramData.compute(
            mode: .timingOffsetDetection,
            profile: profile,
            timeBuckets: timeline.allGranularityBuckets(for: .timingOffsetDetection)
        )
        #expect(data.columns.isEmpty)
        #expect(data.trainedRanges.isEmpty)
    }

    @Test("single tempo range with data produces one trained range")
    func singleTempoRange() async {
        let profile = makeProfileWithSlowData()
        let timeline = ProgressTimeline(profile: profile)
        let data = SpectrogramData.compute(
            mode: .timingOffsetDetection,
            profile: profile,
            timeBuckets: timeline.allGranularityBuckets(for: .timingOffsetDetection)
        )
        #expect(data.trainedRanges == [.slow])
        #expect(!data.columns.isEmpty)
    }

    @Test("multiple tempo ranges produce sorted trained ranges")
    func multipleTempoRanges() async {
        let profile = makeProfileWithSlowAndFastData()
        let timeline = ProgressTimeline(profile: profile)
        let data = SpectrogramData.compute(
            mode: .timingOffsetDetection,
            profile: profile,
            timeBuckets: timeline.allGranularityBuckets(for: .timingOffsetDetection)
        )
        #expect(data.trainedRanges == [.slow, .fast])
    }

    @Test("untrained ranges are excluded from trainedRanges")
    func untrainedRangesExcluded() async {
        let profile = makeProfileWithSlowAndFastData()
        let timeline = ProgressTimeline(profile: profile)
        let data = SpectrogramData.compute(
            mode: .timingOffsetDetection,
            profile: profile,
            timeBuckets: timeline.allGranularityBuckets(for: .timingOffsetDetection)
        )
        // moderate range has no data — must not appear in trainedRanges or any cell
        #expect(!data.trainedRanges.contains(.moderate))
        for column in data.columns {
            #expect(!column.cells.contains(where: { $0.tempoRange == .moderate }))
        }
    }

    @Test("cell accuracy is computed as percentage of sixteenth note")
    func cellAccuracyIsPercentage() async {
        // 10ms at slow midpoint (70 BPM): sixteenth ≈ 214.3ms → 10/214.3*100 ≈ 4.67%
        let profile = makeProfileWithKnownValue(ms: 10.0, range: .slow, direction: .early)
        let timeline = ProgressTimeline(profile: profile)
        let data = SpectrogramData.compute(
            mode: .timingOffsetDetection,
            profile: profile,
            timeBuckets: timeline.allGranularityBuckets(for: .timingOffsetDetection)
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
        let sixteenthMs = TempoRange.slow.midpointTempo.sixteenthNoteDuration / .milliseconds(1)
        let expectedPercent = (10.0 / sixteenthMs) * 100.0
        #expect(abs(accuracy - expectedPercent) < 0.01)
    }

    @Test("early and late stats are populated separately")
    func earlyLateStatsSeparate() async {
        let profile = makeProfileWithEarlyAndLateData()
        let timeline = ProgressTimeline(profile: profile)
        let data = SpectrogramData.compute(
            mode: .timingOffsetDetection,
            profile: profile,
            timeBuckets: timeline.allGranularityBuckets(for: .timingOffsetDetection)
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
        let buckets = timeline.allGranularityBuckets(for: .timingOffsetDetection)
        let data = SpectrogramData.compute(
            mode: .timingOffsetDetection,
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
            mode: .timingOffsetDetection,
            profile: profile,
            timeBuckets: timeline.allGranularityBuckets(for: .timingOffsetDetection)
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
        let profile = PerceptualProfile { builder in
            let now = Date()
            builder.addPoint(
                MetricPoint(timestamp: now, value: 10.0),
                for: .rhythm(.timingOffsetDetection, .slow, .early)
            )
            builder.addPoint(
                MetricPoint(timestamp: now.addingTimeInterval(60), value: 20.0),
                for: .rhythm(.timingOffsetDetection, .slow, .early)
            )
            builder.addPoint(
                MetricPoint(timestamp: now.addingTimeInterval(120), value: 30.0),
                for: .rhythm(.timingOffsetDetection, .slow, .early)
            )
        }
        let timeline = ProgressTimeline(profile: profile)
        let data = SpectrogramData.compute(
            mode: .timingOffsetDetection,
            profile: profile,
            timeBuckets: timeline.allGranularityBuckets(for: .timingOffsetDetection)
        )
        guard let column = data.columns.first,
              let cell = column.cells.first(where: { $0.tempoRange == .slow }),
              let earlyStats = cell.earlyStats else {
            Issue.record("Expected a column with slow cell and early stats")
            return
        }
        // Sample stddev = 10ms, expressed as % of sixteenth note at slow midpoint
        let sixteenthMs = TempoRange.slow.midpointTempo.sixteenthNoteDuration / .milliseconds(1)
        let expectedStdDevPercent = (10.0 / sixteenthMs) * 100.0
        #expect(abs(earlyStats.stdDevPercent - expectedStdDevPercent) < 0.01)
    }

    // MARK: - Combined Mean (Bimodal Distribution Bug)

    @Test("equal-magnitude early and late offsets produce non-zero combined accuracy")
    func bimodalMeanDoesNotCancelOut() async {
        let profile = makeProfileWithSymmetricEarlyLate(ms: 50.0, range: .slow)
        let timeline = ProgressTimeline(profile: profile)
        let data = SpectrogramData.compute(
            mode: .timingOffsetDetection,
            profile: profile,
            timeBuckets: timeline.allGranularityBuckets(for: .timingOffsetDetection)
        )
        guard let column = data.columns.first,
              let cell = column.cells.first(where: { $0.tempoRange == .slow }),
              let accuracy = cell.meanAccuracyPercent else {
            Issue.record("Expected a column with slow cell and non-nil accuracy")
            return
        }
        // 50ms at slow midpoint: must be significant, not ~0% (bimodal cancellation bug)
        let sixteenthMs = TempoRange.slow.midpointTempo.sixteenthNoteDuration / .milliseconds(1)
        let expectedPercent = (50.0 / sixteenthMs) * 100.0
        #expect(abs(accuracy - expectedPercent) < 0.5)
    }

    // MARK: - TempoRange displayName

    @Test("tempo range display names are localized")
    func tempoRangeDisplayNames() async {
        for range in TempoRange.defaultRanges {
            #expect(!range.displayName.isEmpty)
        }
    }

    // MARK: - Continuous rhythm matching

    @Test("continuous rhythm matching mode produces valid classifications")
    func continuousRhythmMatchingClassifications() async {
        let profile = PerceptualProfile { builder in
            let now = Date()
            for i in 0..<5 {
                builder.addPoint(
                    MetricPoint(timestamp: now.addingTimeInterval(Double(i) * 60), value: 15.0),
                    for: .rhythm(.continuousRhythmMatching, .fast, .early)
                )
                builder.addPoint(
                    MetricPoint(timestamp: now.addingTimeInterval(Double(i) * 60), value: 20.0),
                    for: .rhythm(.continuousRhythmMatching, .fast, .late)
                )
            }
        }
        let timeline = ProgressTimeline(profile: profile)
        let data = SpectrogramData.compute(
            mode: .continuousRhythmMatching,
            profile: profile,
            timeBuckets: timeline.allGranularityBuckets(for: .continuousRhythmMatching)
        )
        #expect(data.trainedRanges == [.fast])
        for column in data.columns {
            for cell in column.cells {
                #expect(cell.meanAccuracyPercent != nil)
            }
        }
    }

    // MARK: - Threshold behavior across tempo bands

    @Test("12 ms precise floor is effective for fast tempo bands")
    func preciseFloorAtFastBands() async {
        let thresholds = SpectrogramThresholds.default
        // VeryFast: midpoint = 180 BPM, sixteenth ≈ 83ms
        // precise base = 83 * 0.08 = 6.64ms → floor clamps to 12ms → 14.5%
        let sixteenthMs = TempoRange.veryFast.midpointTempo.sixteenthNoteDuration / .milliseconds(1)
        let rawPreciseMs = sixteenthMs * 8.0 / 100.0
        #expect(rawPreciseMs < 12.0, "Raw value must be below floor for this test to be meaningful")
        let level = thresholds.accuracyLevel(for: (10.0 / sixteenthMs) * 100.0, tempoRange: .veryFast)
        #expect(level == .precise)
    }

    @Test("unified thresholds produce sensible classifications across all ranges")
    func sensibleClassificationsAcrossAllRanges() async {
        let thresholds = SpectrogramThresholds.default
        for range in TempoRange.defaultRanges {
            #expect(thresholds.accuracyLevel(for: 0.0, tempoRange: range) == .excellent)
            #expect(thresholds.accuracyLevel(for: 80.0, tempoRange: range) == .erratic)
        }
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
                    for: .rhythm(.timingOffsetDetection, .slow, .early)
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
                    for: .rhythm(.timingOffsetDetection, .slow, .early)
                )
                builder.addPoint(
                    MetricPoint(
                        timestamp: now.addingTimeInterval(Double(i) * 60),
                        value: 5.0
                    ),
                    for: .rhythm(.timingOffsetDetection, .fast, .late)
                )
            }
        }
    }

    private func makeProfileWithKnownValue(ms: Double, range: TempoRange, direction: TimingDirection) -> PerceptualProfile {
        PerceptualProfile { builder in
            let now = Date()
            builder.addPoint(
                MetricPoint(timestamp: now, value: ms),
                for: .rhythm(.timingOffsetDetection, range, direction)
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
                    for: .rhythm(.timingOffsetDetection, range, .early)
                )
                builder.addPoint(
                    MetricPoint(
                        timestamp: now.addingTimeInterval(Double(i) * 60),
                        value: ms
                    ),
                    for: .rhythm(.timingOffsetDetection, range, .late)
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
                    for: .rhythm(.timingOffsetDetection, .slow, .early)
                )
                builder.addPoint(
                    MetricPoint(
                        timestamp: now.addingTimeInterval(Double(i) * 60),
                        value: 12.0
                    ),
                    for: .rhythm(.timingOffsetDetection, .slow, .late)
                )
            }
        }
    }
}
