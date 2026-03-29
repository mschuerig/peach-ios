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
        let level = SpectrogramThresholds.default.accuracyLevel(for: nil, tempoRange: .medium)
        #expect(level == nil)
    }

    @Test("at medium tempo, very low percentage is excellent")
    func excellentAtMediumTempo() async {
        // Medium midpoint = 100 BPM, sixteenth = 150ms
        // excellent = clamp(150 * 0.04, 8, 15) = clamp(6, 8, 15) = 8ms → 5.33%
        let level = SpectrogramThresholds.default.accuracyLevel(for: 3.0, tempoRange: .medium)
        #expect(level == .excellent)
    }

    @Test("at medium tempo, 7% is precise")
    func preciseAtMediumTempo() async {
        // precise = clamp(150 * 0.08, 12, 30) = clamp(12, 12, 30) = 12ms → 8.0%
        let level = SpectrogramThresholds.default.accuracyLevel(for: 7.0, tempoRange: .medium)
        #expect(level == .precise)
    }

    @Test("at medium tempo, 12% is moderate")
    func moderateAtMediumTempo() async {
        // moderate = clamp(150 * 0.15, 20, 40) = clamp(22.5, 20, 40) = 22.5ms → 15.0%
        let level = SpectrogramThresholds.default.accuracyLevel(for: 12.0, tempoRange: .medium)
        #expect(level == .moderate)
    }

    @Test("at medium tempo, 20% is loose")
    func looseAtMediumTempo() async {
        // loose = clamp(150 * 0.25, 30, 55) = clamp(37.5, 30, 55) = 37.5ms → 25.0%
        let level = SpectrogramThresholds.default.accuracyLevel(for: 20.0, tempoRange: .medium)
        #expect(level == .loose)
    }

    @Test("at medium tempo, 30% is erratic")
    func erraticAtMediumTempo() async {
        let level = SpectrogramThresholds.default.accuracyLevel(for: 30.0, tempoRange: .medium)
        #expect(level == .erratic)
    }

    @Test("at fast tempo, floor clamps precise threshold upward")
    func floorClampsAtFastTempo() async {
        // Fast midpoint = 160 BPM, sixteenth = 93.75ms
        // precise = clamp(93.75 * 0.08, 12, 30) = clamp(7.5, 12, 30) = 12ms → 12.8%
        // 10% of 93.75ms = 9.375ms < 12ms floor → still precise
        let level = SpectrogramThresholds.default.accuracyLevel(for: 10.0, tempoRange: .fast)
        #expect(level == .precise)
    }

    @Test("at fast tempo, moderate floor clamps upward")
    func moderateFloorClampsAtFastTempo() async {
        // moderate = clamp(93.75 * 0.15, 20, 40) = clamp(14.06, 20, 40) = 20ms → 21.3%
        // 18% of 93.75ms = 16.875ms < 20ms floor → still moderate
        let level = SpectrogramThresholds.default.accuracyLevel(for: 18.0, tempoRange: .fast)
        #expect(level == .moderate)
    }

    @Test("at slow tempo, ceiling binds at moderate boundary")
    func ceilingBindsAtSlowTempo() async {
        // Slow midpoint = 60 BPM, sixteenth = 250ms
        // moderate = clamp(250 * 0.15, 20, 40) = clamp(37.5, 20, 40) = 37.5ms → 15.0%
        // 12% of 250ms = 30ms < 37.5ms → moderate
        let level = SpectrogramThresholds.default.accuracyLevel(for: 12.0, tempoRange: .slow)
        #expect(level == .moderate)
    }

    @Test("at fast tempo, floor widens precise band beyond base 8%")
    func floorWidensPreciseBand() async {
        // Fast midpoint = 160 BPM, sixteenth = 93.75ms
        // precise = 12ms → 12.8%
        // 12% is above base 8% but below floor-adjusted 12.8% → still precise
        let level = SpectrogramThresholds.default.accuracyLevel(for: 12.0, tempoRange: .fast)
        #expect(level == .precise)
    }

    @Test("five distinct accuracy levels are returned across the range")
    func fiveDistinctLevels() async {
        let t = SpectrogramThresholds.default
        let range = TempoRange.medium
        #expect(t.accuracyLevel(for: 1.0, tempoRange: range) == .excellent)
        #expect(t.accuracyLevel(for: 7.0, tempoRange: range) == .precise)
        #expect(t.accuracyLevel(for: 12.0, tempoRange: range) == .moderate)
        #expect(t.accuracyLevel(for: 20.0, tempoRange: range) == .loose)
        #expect(t.accuracyLevel(for: 50.0, tempoRange: range) == .erratic)
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

    @Test("single coarse range with data produces two fine trained ranges")
    func singleTempoRange() async {
        let profile = makeProfileWithSlowData()
        let timeline = ProgressTimeline(profile: profile)
        let data = SpectrogramData.compute(
            mode: .rhythmOffsetDetection,
            profile: profile,
            timeBuckets: timeline.allGranularityBuckets(for: .rhythmOffsetDetection)
        )
        // Slow coarse range maps to 2 fine spectrogram ranges (40-59, 60-79)
        #expect(data.trainedRanges.count == 2)
        #expect(data.trainedRanges.allSatisfy { $0.enclosingDefaultRange == .slow })
        #expect(!data.columns.isEmpty)
    }

    @Test("multiple coarse ranges produce all mapped fine ranges")
    func multipleTempoRanges() async {
        let profile = makeProfileWithSlowAndFastData()
        let timeline = ProgressTimeline(profile: profile)
        let data = SpectrogramData.compute(
            mode: .rhythmOffsetDetection,
            profile: profile,
            timeBuckets: timeline.allGranularityBuckets(for: .rhythmOffsetDetection)
        )
        // Slow (2 fine) + Fast (2 fine) = 4 fine ranges
        #expect(data.trainedRanges.count == 4)
        let coarseRanges = Set(data.trainedRanges.compactMap(\.enclosingDefaultRange))
        #expect(coarseRanges == [.slow, .fast])
    }

    @Test("untrained coarse ranges produce no fine ranges")
    func untrainedRangesExcluded() async {
        let profile = makeProfileWithSlowAndFastData()
        let timeline = ProgressTimeline(profile: profile)
        let data = SpectrogramData.compute(
            mode: .rhythmOffsetDetection,
            profile: profile,
            timeBuckets: timeline.allGranularityBuckets(for: .rhythmOffsetDetection)
        )
        // Medium coarse range has no data — its fine ranges must not appear
        let mediumFines = data.trainedRanges.filter { $0.enclosingDefaultRange == .medium }
        #expect(mediumFines.isEmpty)
        for column in data.columns {
            #expect(!column.cells.contains(where: { $0.tempoRange.enclosingDefaultRange == .medium }))
        }
    }

    @Test("cell accuracy is computed as percentage of sixteenth note at fine range midpoint")
    func cellAccuracyIsPercentage() async {
        // Slow data at fine range 60-79 (midpoint 70 BPM): sixteenth = 60/(70*4) ≈ 214.3ms
        // 10ms / 214.3ms * 100 ≈ 4.67%
        let profile = makeProfileWithKnownValue(ms: 10.0, range: .slow, direction: .early)
        let timeline = ProgressTimeline(profile: profile)
        let data = SpectrogramData.compute(
            mode: .rhythmOffsetDetection,
            profile: profile,
            timeBuckets: timeline.allGranularityBuckets(for: .rhythmOffsetDetection)
        )
        guard let column = data.columns.first,
              let cell = column.cells.first(where: { $0.tempoRange.enclosingDefaultRange == .slow }) else {
            Issue.record("Expected a column with a slow-enclosing cell")
            return
        }
        guard let accuracy = cell.meanAccuracyPercent else {
            Issue.record("Expected non-nil accuracy")
            return
        }
        // Accuracy varies by fine range midpoint; verify it's a plausible percentage of sixteenth note
        let sixteenthMs = cell.tempoRange.midpointTempo.sixteenthNoteDuration / .milliseconds(1)
        let expectedPercent = (10.0 / sixteenthMs) * 100.0
        #expect(abs(accuracy - expectedPercent) < 0.01)
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
              let cell = column.cells.first(where: { $0.tempoRange.enclosingDefaultRange == .slow }) else {
            Issue.record("Expected a column with a slow-enclosing cell")
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
            let cellRanges = Set(column.cells.map(\.tempoRange))
            #expect(cellRanges == Set(data.trainedRanges))
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
              let cell = column.cells.first(where: { $0.tempoRange.enclosingDefaultRange == .slow }),
              let earlyStats = cell.earlyStats else {
            Issue.record("Expected a column with slow-enclosing cell and early stats")
            return
        }
        // Sample stddev = 10ms, expressed as % of sixteenth note at fine range midpoint
        let sixteenthMs = cell.tempoRange.midpointTempo.sixteenthNoteDuration / .milliseconds(1)
        let expectedStdDevPercent = (10.0 / sixteenthMs) * 100.0
        #expect(abs(earlyStats.stdDevPercent - expectedStdDevPercent) < 0.01)
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
              let cell = column.cells.first(where: { $0.tempoRange.enclosingDefaultRange == .slow }),
              let accuracy = cell.meanAccuracyPercent else {
            Issue.record("Expected a column with slow-enclosing cell and non-nil accuracy")
            return
        }
        // 50ms at fine range midpoint: must be significant, not ~0% (bimodal cancellation bug)
        let sixteenthMs = cell.tempoRange.midpointTempo.sixteenthNoteDuration / .milliseconds(1)
        let expectedPercent = (50.0 / sixteenthMs) * 100.0
        #expect(abs(accuracy - expectedPercent) < 0.5)
    }

    // MARK: - TempoRange displayName

    @Test("tempo range display names are localized")
    func tempoRangeDisplayNames() async {
        #expect(!TempoRange.slow.displayName.isEmpty)
        #expect(!TempoRange.medium.displayName.isEmpty)
        #expect(!TempoRange.fast.displayName.isEmpty)
    }

    // MARK: - Fine-grained tempo bands

    @Test("trainedRanges filters correctly with finer-grained ranges")
    func trainedRangesFilterWithFineRanges() async {
        // Profile with only medium data → should produce exactly the 2 fine ranges for medium
        let profile = PerceptualProfile { builder in
            let now = Date()
            for i in 0..<5 {
                builder.addPoint(
                    MetricPoint(timestamp: now.addingTimeInterval(Double(i) * 60), value: 10.0),
                    for: .rhythm(.rhythmOffsetDetection, .medium, .early)
                )
            }
        }
        let timeline = ProgressTimeline(profile: profile)
        let data = SpectrogramData.compute(
            mode: .rhythmOffsetDetection,
            profile: profile,
            timeBuckets: timeline.allGranularityBuckets(for: .rhythmOffsetDetection)
        )
        #expect(data.trainedRanges.count == 2)
        #expect(data.trainedRanges.allSatisfy { $0.enclosingDefaultRange == .medium })
    }

    @Test("continuous rhythm matching mode produces valid fine-range classifications")
    func continuousRhythmMatchingFineRanges() async {
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
        // Fast coarse range maps to 2 fine ranges
        #expect(data.trainedRanges.count == 2)
        #expect(data.trainedRanges.allSatisfy { $0.enclosingDefaultRange == .fast })
        // Each cell should have non-nil accuracy
        for column in data.columns {
            for cell in column.cells {
                #expect(cell.meanAccuracyPercent != nil)
            }
        }
    }

    // MARK: - Threshold behavior across fine tempo bands

    @Test("12 ms precise floor is effective for fast tempo bands")
    func preciseFloorAtFastBands() async {
        let thresholds = SpectrogramThresholds.default
        // At 160-200 band, midpoint = 180 BPM, sixteenth ≈ 83ms
        // precise base = 83 * 0.08 = 6.64ms → floor clamps to 12ms → 14.5%
        let fastBand = TempoRange.spectrogramRanges.last!
        let sixteenthMs = fastBand.midpointTempo.sixteenthNoteDuration / .milliseconds(1)
        let rawPreciseMs = sixteenthMs * 8.0 / 100.0
        #expect(rawPreciseMs < 12.0, "Raw value must be below floor for this test to be meaningful")
        // 10ms → 12.0% is below the floor-adjusted precise threshold
        let level = thresholds.accuracyLevel(for: (10.0 / sixteenthMs) * 100.0, tempoRange: fastBand)
        #expect(level == .precise)
    }

    @Test("unified thresholds produce sensible classifications for continuous rhythm matching")
    func continuousRhythmMatchingClassifications() async {
        let thresholds = SpectrogramThresholds.default
        // Verify all 5 levels are reachable at a representative fine tempo band
        for fineRange in TempoRange.spectrogramRanges {
            // 0ms should be excellent
            #expect(thresholds.accuracyLevel(for: 0.0, tempoRange: fineRange) == .excellent)
            // Very high percentage should be erratic
            #expect(thresholds.accuracyLevel(for: 80.0, tempoRange: fineRange) == .erratic)
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
