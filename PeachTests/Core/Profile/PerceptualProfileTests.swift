import Testing
import Foundation
@testable import Peach

@Suite("PerceptualProfile Tests")
struct PerceptualProfileTests {

    // MARK: - Helpers

    private func makeComparisonCompleted(
        referenceNote: MIDINote = MIDINote(60),
        targetNote: MIDINote = MIDINote(60),
        centOffset: Cents,
        isCorrect: Bool = true
    ) -> CompletedPitchDiscriminationTrial {
        let isTargetHigher = centOffset > 0
        return CompletedPitchDiscriminationTrial(
            trial: PitchDiscriminationTrial(
                referenceNote: referenceNote,
                targetNote: DetunedMIDINote(note: targetNote, offset: centOffset)
            ),
            userAnsweredHigher: isCorrect ? isTargetHigher : !isTargetHigher,
            tuningSystem: .equalTemperament
        )
    }

    private func makeMatchingCompleted(
        referenceNote: MIDINote = MIDINote(60),
        targetNote: MIDINote = MIDINote(60),
        centError: Cents
    ) -> CompletedPitchMatchingTrial {
        CompletedPitchMatchingTrial(
            referenceNote: referenceNote,
            targetNote: targetNote,
            initialCentOffset: 50.0,
            userCentError: centError,
            tuningSystem: .equalTemperament
        )
    }

    // MARK: - Cold Start

    @Test("Cold start profile has no statistics")
    func coldStartProfile() async {
        let profile = PerceptualProfile()

        #expect(profile.comparisonMean(for: .prime) == nil)
        #expect(profile.matchingMean == nil)
        #expect(profile.matchingSampleCount == 0)
    }

    // MARK: - Comparison Statistics via Observer

    @Test("Single correct comparison sets comparison mean")
    func singleUpdateSetsMean() async {
        let profile = PerceptualProfile()

        PitchDiscriminationProfileAdapter(profile: profile).pitchDiscriminationCompleted(makeComparisonCompleted(centOffset: 50))

        #expect(profile.comparisonMean(for: .prime) == 50.0)
    }

    @Test("Multiple correct comparisons compute correct running mean")
    func multipleUpdatesComputeMean() async {
        let profile = PerceptualProfile()

        PitchDiscriminationProfileAdapter(profile: profile).pitchDiscriminationCompleted(makeComparisonCompleted(centOffset: 50))
        PitchDiscriminationProfileAdapter(profile: profile).pitchDiscriminationCompleted(makeComparisonCompleted(centOffset: 40))

        #expect(profile.comparisonMean(for: .prime) == 45.0) // (50+40)/2
    }

    @Test("Overall mean across all samples")
    func comparisonMeanComputation() async {
        let profile = PerceptualProfile()

        PitchDiscriminationProfileAdapter(profile: profile).pitchDiscriminationCompleted(makeComparisonCompleted(centOffset: 50))
        PitchDiscriminationProfileAdapter(profile: profile).pitchDiscriminationCompleted(makeComparisonCompleted(centOffset: 30))
        PitchDiscriminationProfileAdapter(profile: profile).pitchDiscriminationCompleted(makeComparisonCompleted(centOffset: 40))

        #expect(profile.comparisonMean(for: .prime) == 40.0) // (50+30+40)/3
    }

    @Test("Only correct answers contribute to comparison mean")
    func onlyCorrectAnswersContribute() async {
        let profile = PerceptualProfile()

        PitchDiscriminationProfileAdapter(profile: profile).pitchDiscriminationCompleted(makeComparisonCompleted(centOffset: 50, isCorrect: true))
        PitchDiscriminationProfileAdapter(profile: profile).pitchDiscriminationCompleted(makeComparisonCompleted(centOffset: 200, isCorrect: false))
        PitchDiscriminationProfileAdapter(profile: profile).pitchDiscriminationCompleted(makeComparisonCompleted(centOffset: 60, isCorrect: true))

        #expect(profile.comparisonMean(for: .prime) == 55.0) // (50+60)/2, incorrect answer excluded
    }

    // MARK: - Observer Integration

    @Test("PitchDiscriminationObserver routes interval comparison to correct mode")
    func comparisonObserverRoutesIntervalCorrectly() async {
        let profile = PerceptualProfile()

        let trial = PitchDiscriminationTrial(
            referenceNote: MIDINote(60),
            targetNote: DetunedMIDINote(note: MIDINote(67), offset: Cents(25.0))
        )
        let completed = CompletedPitchDiscriminationTrial(
            trial: trial,
            userAnsweredHigher: true,
            tuningSystem: .equalTemperament
        )

        PitchDiscriminationProfileAdapter(profile: profile).pitchDiscriminationCompleted(completed)

        #expect(profile.comparisonMean(for: .up(.perfectFifth)) == 25.0)
        #expect(profile.hasData(for: .intervalPitchDiscrimination))
        #expect(!profile.hasData(for: .unisonPitchDiscrimination))
    }

    @Test("PitchMatchingObserver records centError correctly for non-prime interval")
    func pitchMatchingObserverRecordsCentErrorWithInterval() async throws {
        let profile = PerceptualProfile()

        let completed = CompletedPitchMatchingTrial(
            referenceNote: MIDINote(60),
            targetNote: MIDINote(60).transposed(by: .up(.perfectFifth)),
            initialCentOffset: 30.0,
            userCentError: -12.3,
            tuningSystem: .equalTemperament
        )

        PitchMatchingProfileAdapter(profile: profile).pitchMatchingCompleted(completed)

        #expect(profile.matchingSampleCount == 1)
        let mean = try #require(profile.matchingMean)
        #expect(abs(mean.rawValue - 12.3) < 0.01)
        #expect(profile.hasData(for: .intervalPitchMatching))
        #expect(!profile.hasData(for: .unisonPitchMatching))
    }

    // MARK: - Per-Mode Query API

    @Test("hasData returns false for empty modes")
    func hasDataEmptyProfile() async {
        let profile = PerceptualProfile()
        for mode in [TrainingDisciplineID.unisonPitchDiscrimination, .intervalPitchDiscrimination, .unisonPitchMatching, .intervalPitchMatching] {
            #expect(!profile.hasData(for: mode))
        }
    }

    @Test("per-mode statistics accessible after observer updates")
    func perModeStatisticsViaObserver() async {
        let profile = PerceptualProfile()

        // Unison comparison
        PitchDiscriminationProfileAdapter(profile: profile).pitchDiscriminationCompleted(makeComparisonCompleted(centOffset: 10))
        // Interval comparison
        let intervalComparison = CompletedPitchDiscriminationTrial(
            trial: PitchDiscriminationTrial(
                referenceNote: MIDINote(60),
                targetNote: DetunedMIDINote(note: MIDINote(67), offset: Cents(20.0))
            ),
            userAnsweredHigher: true,
            tuningSystem: .equalTemperament
        )
        PitchDiscriminationProfileAdapter(profile: profile).pitchDiscriminationCompleted(intervalComparison)

        #expect(profile.recordCount(for: .unisonPitchDiscrimination) == 1)
        #expect(profile.recordCount(for: .intervalPitchDiscrimination) == 1)
    }

    // MARK: - Builder Init

    @Test("init(build:) from metric points produces correct per-mode data")
    func builderFromMetrics() async {
        let now = Date()

        let profile = PerceptualProfile { builder in
            builder.addPoint(MetricPoint(timestamp: now, value: 10), for: .pitch(.unisonPitchDiscrimination))
            builder.addPoint(MetricPoint(timestamp: now.addingTimeInterval(1), value: 20), for: .pitch(.unisonPitchDiscrimination))
            builder.addPoint(MetricPoint(timestamp: now, value: 5), for: .pitch(.intervalPitchMatching))
        }

        #expect(profile.recordCount(for: .unisonPitchDiscrimination) == 2)
        #expect(profile.recordCount(for: .intervalPitchMatching) == 1)
        #expect(profile.recordCount(for: .intervalPitchDiscrimination) == 0)
        #expect(profile.recordCount(for: .unisonPitchMatching) == 0)
    }

    // MARK: - Reset

    @Test("resetAll clears all modes")
    func resetAllClearsAllModes() async {
        let profile = PerceptualProfile()

        PitchDiscriminationProfileAdapter(profile: profile).pitchDiscriminationCompleted(makeComparisonCompleted(centOffset: 10))
        PitchMatchingProfileAdapter(profile: profile).pitchMatchingCompleted(makeMatchingCompleted(centError: 5))

        profile.resetAll()

        for mode in [TrainingDisciplineID.unisonPitchDiscrimination, .intervalPitchDiscrimination, .unisonPitchMatching, .intervalPitchMatching] {
            #expect(!profile.hasData(for: mode))
        }
        #expect(profile.comparisonMean(for: .prime) == nil)
        #expect(profile.matchingMean == nil)
    }

    // MARK: - Matching Sample Count

    @Test("matching sample count sums across both matching modes")
    func matchingSampleCountSumsAcrossModes() async {
        let profile = PerceptualProfile()

        // 2 unison matching
        PitchMatchingProfileAdapter(profile: profile).pitchMatchingCompleted(makeMatchingCompleted(centError: 5))
        PitchMatchingProfileAdapter(profile: profile).pitchMatchingCompleted(makeMatchingCompleted(centError: 3))

        // 1 interval matching
        PitchMatchingProfileAdapter(profile: profile).pitchMatchingCompleted(makeMatchingCompleted(
            referenceNote: MIDINote(60),
            targetNote: MIDINote(67),
            centError: 8
        ))

        #expect(profile.matchingSampleCount == 3)
    }

    // MARK: - Builder-Based Init

    @Test("init(build:) produces correct per-mode data")
    func initWithBuilder() async {
        let now = Date()

        let profile = PerceptualProfile { builder in
            builder.addPoint(MetricPoint(timestamp: now, value: 10), for: .pitch(.unisonPitchDiscrimination))
            builder.addPoint(MetricPoint(timestamp: now.addingTimeInterval(1), value: 20), for: .pitch(.unisonPitchDiscrimination))
            builder.addPoint(MetricPoint(timestamp: now, value: 5), for: .pitch(.intervalPitchMatching))
        }

        #expect(profile.recordCount(for: .unisonPitchDiscrimination) == 2)
        #expect(profile.recordCount(for: .intervalPitchMatching) == 1)
        #expect(profile.recordCount(for: .intervalPitchDiscrimination) == 0)
        #expect(profile.recordCount(for: .unisonPitchMatching) == 0)
    }

    @Test("init(build:) computes correct statistics for multiple points")
    func builderComputesCorrectStatistics() async {
        let now = Date()

        let profile = PerceptualProfile { builder in
            for i in 0..<5 {
                builder.addPoint(
                    MetricPoint(timestamp: now.addingTimeInterval(Double(i) * 3600), value: Double(i * 10 + 5)),
                    for: .pitch(.unisonPitchDiscrimination)
                )
            }
        }

        #expect(profile.recordCount(for: .unisonPitchDiscrimination) == 5)
        // Mean of [5, 15, 25, 35, 45] = 25.0
        #expect(profile.comparisonMean(for: .prime) == 25.0)
        #expect(profile.trend(for: .unisonPitchDiscrimination) != nil)
    }

    @Test("Builder is received via closure, not constructed directly")
    func builderViaInit() async {
        let profile = PerceptualProfile { builder in
            builder.addPoint(MetricPoint(timestamp: Date(), value: 10.0), for: .pitch(.unisonPitchDiscrimination))
        }
        #expect(profile.recordCount(for: .unisonPitchDiscrimination) == 1)
    }

    @Test("replaceAll updates same instance with new data")
    func replaceAllUpdatesInstance() async {
        let now = Date()
        let profile = PerceptualProfile { builder in
            builder.addPoint(MetricPoint(timestamp: now, value: 50.0), for: .pitch(.unisonPitchDiscrimination))
        }

        #expect(profile.comparisonMean(for: .prime) == 50.0)

        profile.replaceAll { builder in
            builder.addPoint(MetricPoint(timestamp: now, value: 10.0), for: .pitch(.unisonPitchDiscrimination))
            builder.addPoint(MetricPoint(timestamp: now.addingTimeInterval(1), value: 20.0), for: .pitch(.unisonPitchDiscrimination))
        }

        #expect(profile.comparisonMean(for: .prime) == 15.0)
        #expect(profile.recordCount(for: .unisonPitchDiscrimination) == 2)
    }

    @Test("Builder skips incorrect comparison points")
    func builderSkipsIncorrect() async {
        let now = Date()
        let profile = PerceptualProfile { builder in
            builder.addPoint(MetricPoint(timestamp: now, value: 50.0), for: .pitch(.unisonPitchDiscrimination), isCorrect: true)
            builder.addPoint(MetricPoint(timestamp: now.addingTimeInterval(1), value: 200.0), for: .pitch(.unisonPitchDiscrimination), isCorrect: false)
            builder.addPoint(MetricPoint(timestamp: now.addingTimeInterval(2), value: 30.0), for: .pitch(.unisonPitchDiscrimination), isCorrect: true)
        }

        #expect(profile.recordCount(for: .unisonPitchDiscrimination) == 2)
        #expect(profile.comparisonMean(for: .prime) == 40.0) // (50+30)/2
    }

    // MARK: - Rhythm Offset Detection via Observer

    @Test("RhythmOffsetDetectionObserver routes to correct key")
    func rhythmOffsetDetectionObserverDelegates() async {
        let profile = PerceptualProfile()

        let result = CompletedRhythmOffsetDetectionTrial(
            tempo: TempoBPM(120),
            offset: RhythmOffset(.milliseconds(-20)),
            isCorrect: true
        )
        RhythmOffsetDetectionProfileAdapter(profile: profile).rhythmOffsetDetectionCompleted(result)

        let stats = profile.statistics(for: .rhythm(.rhythmOffsetDetection, .fast, .early))
        #expect(stats?.recordCount == 1)
        #expect(abs((stats?.welfordMean ?? 0) - 20.0) < 0.01)
    }

    @Test("RhythmOffsetDetectionObserver skips incorrect results")
    func rhythmOffsetDetectionObserverSkipsIncorrect() async {
        let profile = PerceptualProfile()

        let result = CompletedRhythmOffsetDetectionTrial(
            tempo: TempoBPM(120),
            offset: RhythmOffset(.milliseconds(-20)),
            isCorrect: false
        )
        RhythmOffsetDetectionProfileAdapter(profile: profile).rhythmOffsetDetectionCompleted(result)

        #expect(profile.statistics(for: .rhythm(.rhythmOffsetDetection, .fast, .early)) == nil)
    }

    // MARK: - Rhythm Builder

    @Test("Builder initialization with rhythm offset detection records rebuilds correctly")
    func builderWithRhythmOffsetDetectionRecords() async {
        let now = Date()

        let profile = PerceptualProfile { builder in
            builder.addPoint(
                MetricPoint(timestamp: now, value: 15.0),
                for: .rhythm(.rhythmOffsetDetection, .fast, .early),
                isCorrect: true
            )
            builder.addPoint(
                MetricPoint(timestamp: now.addingTimeInterval(1), value: 25.0),
                for: .rhythm(.rhythmOffsetDetection, .fast, .early),
                isCorrect: true
            )
        }

        let stats = profile.statistics(for: .rhythm(.rhythmOffsetDetection, .fast, .early))
        #expect(stats?.recordCount == 2)
        #expect(abs((stats?.welfordMean ?? 0) - 20.0) < 0.01) // (15+25)/2
    }

    @Test("Builder skips incorrect rhythm offset detection points")
    func builderSkipsIncorrectRhythm() async {
        let now = Date()

        let profile = PerceptualProfile { builder in
            builder.addPoint(
                MetricPoint(timestamp: now, value: 15.0),
                for: .rhythm(.rhythmOffsetDetection, .fast, .early),
                isCorrect: true
            )
            builder.addPoint(
                MetricPoint(timestamp: now.addingTimeInterval(1), value: 100.0),
                for: .rhythm(.rhythmOffsetDetection, .fast, .early),
                isCorrect: false
            )
        }

        let stats = profile.statistics(for: .rhythm(.rhythmOffsetDetection, .fast, .early))
        #expect(stats?.recordCount == 1)
    }

    // MARK: - Trained Tempo Ranges

    @Test("trainedTempoRanges returns correct set")
    func trainedTempoRangesReturnsCorrectSet() async {
        let profile = PerceptualProfile()

        let fast = CompletedRhythmOffsetDetectionTrial(
            tempo: TempoBPM(120),
            offset: RhythmOffset(.milliseconds(-10)),
            isCorrect: true
        )
        RhythmOffsetDetectionProfileAdapter(profile: profile).rhythmOffsetDetectionCompleted(fast)

        let medium = CompletedContinuousRhythmMatchingTrial(
            tempo: TempoBPM(90),
            gapResults: [
                GapResult(position: .first, offset: RhythmOffset(.milliseconds(5)))
            ]
        )
        ContinuousRhythmMatchingProfileAdapter(profile: profile).continuousRhythmMatchingCompleted(medium)

        let ranges = profile.trainedTempoRanges
        #expect(Set(ranges) == Set([TempoRange.fast, TempoRange.moderate]))
    }

    // MARK: - Rhythm Overall Accuracy

    @Test("rhythmOverallAccuracy computes combined accuracy")
    func rhythmOverallAccuracyComputesCombined() async throws {
        let profile = PerceptualProfile()

        // 2 samples at tempo 120 early, mean offset 20ms
        RhythmOffsetDetectionProfileAdapter(profile: profile).rhythmOffsetDetectionCompleted(CompletedRhythmOffsetDetectionTrial(
            tempo: TempoBPM(120), offset: RhythmOffset(.milliseconds(-15)), isCorrect: true
        ))
        RhythmOffsetDetectionProfileAdapter(profile: profile).rhythmOffsetDetectionCompleted(CompletedRhythmOffsetDetectionTrial(
            tempo: TempoBPM(120), offset: RhythmOffset(.milliseconds(-25)), isCorrect: true
        ))

        // 1 sample at tempo 90 late, mean offset 10ms
        ContinuousRhythmMatchingProfileAdapter(profile: profile).continuousRhythmMatchingCompleted(CompletedContinuousRhythmMatchingTrial(
            tempo: TempoBPM(90),
            gapResults: [
                GapResult(position: .first, offset: RhythmOffset(.milliseconds(10)))
            ]
        ))

        let accuracy = try #require(profile.rhythmOverallAccuracy)
        // weighted mean: (20*2 + 10*1) / 3 = 50/3 ≈ 16.67
        #expect(abs(accuracy - 50.0 / 3.0) < 0.01)
    }

    @Test("rhythmOverallAccuracy returns nil with no data")
    func rhythmOverallAccuracyNilWhenEmpty() async {
        let profile = PerceptualProfile()
        #expect(profile.rhythmOverallAccuracy == nil)
    }

    // MARK: - Reset

    @Test("resetAll clears everything including rhythm")
    func resetAllClearsEverythingIncludingRhythm() async {
        let profile = PerceptualProfile()

        PitchDiscriminationProfileAdapter(profile: profile).pitchDiscriminationCompleted(makeComparisonCompleted(centOffset: 50))
        RhythmOffsetDetectionProfileAdapter(profile: profile).rhythmOffsetDetectionCompleted(CompletedRhythmOffsetDetectionTrial(
            tempo: TempoBPM(120), offset: RhythmOffset(.milliseconds(-10)), isCorrect: true
        ))

        profile.resetAll()

        #expect(profile.comparisonMean(for: .prime) == nil)
        #expect(profile.trainedTempoRanges.isEmpty)
        #expect(profile.rhythmOverallAccuracy == nil)
    }

    // MARK: - Continuous Rhythm Matching via Observer

    @Test("ContinuousRhythmMatchingObserver routes to correct key with early mean offset")
    func continuousRhythmMatchingObserverEarlyOffset() async {
        let profile = PerceptualProfile()

        let trial = CompletedContinuousRhythmMatchingTrial(
            tempo: TempoBPM(100),
            gapResults: [
                GapResult(position: .first, offset: RhythmOffset(.milliseconds(-15))),
                GapResult(position: .third, offset: RhythmOffset(.milliseconds(-5)))
            ]
        )
        ContinuousRhythmMatchingProfileAdapter(profile: profile).continuousRhythmMatchingCompleted(trial)

        let stats = profile.statistics(for: .rhythm(.continuousRhythmMatching, .brisk, .early))
        #expect(stats?.recordCount == 1)
        #expect(abs((stats?.welfordMean ?? 0) - 10.0) < 0.01) // abs(mean of -15, -5 = -10) = 10
    }

    @Test("ContinuousRhythmMatchingObserver routes to correct key with late mean offset")
    func continuousRhythmMatchingObserverLateOffset() async {
        let profile = PerceptualProfile()

        let trial = CompletedContinuousRhythmMatchingTrial(
            tempo: TempoBPM(130),
            gapResults: [
                GapResult(position: .first, offset: RhythmOffset(.milliseconds(20))),
                GapResult(position: .second, offset: RhythmOffset(.milliseconds(10)))
            ]
        )
        ContinuousRhythmMatchingProfileAdapter(profile: profile).continuousRhythmMatchingCompleted(trial)

        let stats = profile.statistics(for: .rhythm(.continuousRhythmMatching, .fast, .late))
        #expect(stats?.recordCount == 1)
        #expect(abs((stats?.welfordMean ?? 0) - 15.0) < 0.01) // abs(mean of 20, 10 = 15) = 15
    }

    @Test("ContinuousRhythmMatchingObserver skips empty trials")
    func continuousRhythmMatchingObserverSkipsEmptyTrials() async {
        let profile = PerceptualProfile()

        let trial = CompletedContinuousRhythmMatchingTrial(
            tempo: TempoBPM(100),
            gapResults: []
        )
        ContinuousRhythmMatchingProfileAdapter(profile: profile).continuousRhythmMatchingCompleted(trial)

        // No rhythm stats should exist for any tempo range / direction
        for range in TempoRange.defaultRanges {
            for direction in RhythmDirection.allCases {
                #expect(profile.statistics(for: .rhythm(.continuousRhythmMatching, range, direction)) == nil)
            }
        }
    }
}
