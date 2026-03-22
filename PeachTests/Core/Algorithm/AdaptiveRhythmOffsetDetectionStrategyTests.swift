import Testing
import Foundation
@testable import Peach

@Suite("AdaptiveRhythmOffsetDetectionStrategy Tests")
struct AdaptiveRhythmOffsetDetectionStrategyTests {

    // MARK: - Cold Start

    @Test("cold start with empty profile returns max offset percentage")
    func coldStartReturnsMaxOffset() async {
        let strategy = AdaptiveRhythmOffsetDetectionStrategy()
        let settings = RhythmOffsetDetectionSettings(tempo: TempoBPM(120), maxOffsetPercentage: 20.0)

        let trial = strategy.nextRhythmOffsetDetectionTrial(
            profile: PerceptualProfile(),
            settings: settings,
            lastResult: nil
        )

        let percentage = trial.offset.percentageOfSixteenthNote(at: trial.tempo)
        #expect(abs(percentage - 20.0) < 0.001)
    }

    @Test("cold start passes settings tempo through to trial")
    func coldStartPassesTempo() async {
        let strategy = AdaptiveRhythmOffsetDetectionStrategy()
        let settings = RhythmOffsetDetectionSettings(tempo: TempoBPM(100))

        let trial = strategy.nextRhythmOffsetDetectionTrial(
            profile: PerceptualProfile(),
            settings: settings,
            lastResult: nil
        )

        #expect(trial.tempo == TempoBPM(100))
    }

    // MARK: - Kazez Narrowing (correct answer)

    @Test("narrows offset after correct answer")
    func narrowsAfterCorrect() async {
        let strategy = AdaptiveRhythmOffsetDetectionStrategy()
        let settings = RhythmOffsetDetectionSettings(
            tempo: TempoBPM(120),
            maxOffsetPercentage: 20.0,
            minOffsetPercentage: 0.1
        )

        let lastPercentage = 20.0
        let lastResult = makeCompleted(percentage: lastPercentage, tempo: TempoBPM(120), direction: .late, correct: true)

        let trial = strategy.nextRhythmOffsetDetectionTrial(
            profile: PerceptualProfile(),
            settings: settings,
            lastResult: lastResult
        )

        let newPercentage = trial.offset.percentageOfSixteenthNote(at: trial.tempo)
        // N = 20 × [1 - 0.05 × √20] ≈ 20 × 0.776 ≈ 15.53
        let expected = 20.0 * (1.0 - 0.05 * 20.0.squareRoot())
        #expect(abs(newPercentage - expected) < 0.01)
        #expect(newPercentage < lastPercentage)
    }

    // MARK: - Kazez Widening (incorrect answer)

    @Test("widens offset after incorrect answer")
    func widensAfterIncorrect() async {
        let strategy = AdaptiveRhythmOffsetDetectionStrategy()
        let settings = RhythmOffsetDetectionSettings(
            tempo: TempoBPM(120),
            maxOffsetPercentage: 50.0,
            minOffsetPercentage: 0.1
        )

        let lastPercentage = 10.0
        let lastResult = makeCompleted(percentage: lastPercentage, tempo: TempoBPM(120), direction: .early, correct: false)

        let trial = strategy.nextRhythmOffsetDetectionTrial(
            profile: PerceptualProfile(),
            settings: settings,
            lastResult: lastResult
        )

        let newPercentage = trial.offset.percentageOfSixteenthNote(at: trial.tempo)
        // N = 10 × [1 + 0.09 × √10] ≈ 10 × 1.2846 ≈ 12.85
        let expected = 10.0 * (1.0 + 0.09 * 10.0.squareRoot())
        #expect(abs(newPercentage - expected) < 0.01)
        #expect(newPercentage > lastPercentage)
    }

    // MARK: - Clamping

    @Test("offset stays within min bound")
    func clampedToMin() async {
        let strategy = AdaptiveRhythmOffsetDetectionStrategy()
        let settings = RhythmOffsetDetectionSettings(
            tempo: TempoBPM(120),
            maxOffsetPercentage: 20.0,
            minOffsetPercentage: 5.0
        )

        // At p=1: N = 1 × [1 - 0.05 × 1] = 0.95 → clamped to 5.0
        let lastResult = makeCompleted(percentage: 1.0, tempo: TempoBPM(120), direction: .late, correct: true)

        let trial = strategy.nextRhythmOffsetDetectionTrial(
            profile: PerceptualProfile(),
            settings: settings,
            lastResult: lastResult
        )

        let percentage = trial.offset.percentageOfSixteenthNote(at: trial.tempo)
        #expect(abs(percentage - 5.0) < 0.01)
    }

    @Test("offset stays within max bound")
    func clampedToMax() async {
        let strategy = AdaptiveRhythmOffsetDetectionStrategy()
        let settings = RhythmOffsetDetectionSettings(
            tempo: TempoBPM(120),
            maxOffsetPercentage: 20.0,
            minOffsetPercentage: 1.0
        )

        // At p=20 incorrect: N = 20 × [1 + 0.09 × √20] ≈ 28.05 → clamped to 20.0
        let lastResult = makeCompleted(percentage: 20.0, tempo: TempoBPM(120), direction: .early, correct: false)

        let trial = strategy.nextRhythmOffsetDetectionTrial(
            profile: PerceptualProfile(),
            settings: settings,
            lastResult: lastResult
        )

        let percentage = trial.offset.percentageOfSixteenthNote(at: trial.tempo)
        #expect(abs(percentage - 20.0) < 0.01)
    }

    // MARK: - Asymmetric Direction Tracking

    @Test("favors direction with less data")
    func favorsWeakerDirection() async {
        let strategy = AdaptiveRhythmOffsetDetectionStrategy()
        let profile = PerceptualProfile()
        let settings = RhythmOffsetDetectionSettings(tempo: TempoBPM(80))

        // Train only late results — early direction should be favored
        for _ in 0..<5 {
            RhythmOffsetDetectionProfileAdapter(profile: profile).rhythmOffsetDetectionCompleted(CompletedRhythmOffsetDetectionTrial(
                tempo: TempoBPM(80),
                offset: RhythmOffset(.milliseconds(30)),
                isCorrect: true
            ))
        }

        // Run many trials and count direction choices
        var earlyCount = 0
        for _ in 0..<100 {
            let trial = strategy.nextRhythmOffsetDetectionTrial(
                profile: profile,
                settings: settings,
                lastResult: nil
            )
            if trial.offset.direction == .early {
                earlyCount += 1
            }
        }

        // Early should be chosen every time since late has more data
        #expect(earlyCount == 100)
    }

    @Test("both directions explored when profile has no data")
    func bothDirectionsWithNoData() async {
        let strategy = AdaptiveRhythmOffsetDetectionStrategy()
        let settings = RhythmOffsetDetectionSettings(tempo: TempoBPM(80))

        var earlyCount = 0
        var lateCount = 0
        for _ in 0..<200 {
            let trial = strategy.nextRhythmOffsetDetectionTrial(
                profile: PerceptualProfile(),
                settings: settings,
                lastResult: nil
            )
            if trial.offset.direction == .early {
                earlyCount += 1
            } else {
                lateCount += 1
            }
        }

        // Both directions should be explored (random with 50/50 odds)
        #expect(earlyCount > 30)
        #expect(lateCount > 30)
    }

    // MARK: - Profile Cold Start

    @Test("cold start with trained profile uses profile mean converted to percentage")
    func coldStartWithProfileMean() async {
        let strategy = AdaptiveRhythmOffsetDetectionStrategy()
        let profile = PerceptualProfile()
        let settings = RhythmOffsetDetectionSettings(
            tempo: TempoBPM(80),
            maxOffsetPercentage: 20.0,
            minOffsetPercentage: 1.0
        )

        // Train with known offset to establish a profile mean
        // At 80 BPM, sixteenth = 60 / (80 × 4) = 0.1875s = 187.5ms
        // 50ms offset → percentage = (50 / 187.5) × 100 = 26.67% → clamped to 20.0
        let offset = RhythmOffset(.milliseconds(50))
        for direction in RhythmDirection.allCases {
            let signedOffset = direction == .early
                ? RhythmOffset(.zero - .milliseconds(50))
                : offset
            RhythmOffsetDetectionProfileAdapter(profile: profile).rhythmOffsetDetectionCompleted(CompletedRhythmOffsetDetectionTrial(
                tempo: TempoBPM(80),
                offset: signedOffset,
                isCorrect: true
            ))
        }

        let trial = strategy.nextRhythmOffsetDetectionTrial(
            profile: profile,
            settings: settings,
            lastResult: nil
        )

        let percentage = trial.offset.percentageOfSixteenthNote(at: trial.tempo)
        // Profile mean 50ms → 26.67% → clamped to max 20.0
        #expect(abs(percentage - 20.0) < 0.01)
    }

    // MARK: - Convergence

    @Test("10 consecutive correct answers from max converges to lower difficulty")
    func convergenceFromMax() async {
        let strategy = AdaptiveRhythmOffsetDetectionStrategy()
        let tempo = TempoBPM(120)
        let settings = RhythmOffsetDetectionSettings(
            tempo: tempo,
            maxOffsetPercentage: 20.0,
            minOffsetPercentage: 0.1
        )

        var trial = strategy.nextRhythmOffsetDetectionTrial(
            profile: PerceptualProfile(),
            settings: settings,
            lastResult: nil
        )
        #expect(abs(trial.offset.percentageOfSixteenthNote(at: tempo) - 20.0) < 0.01)

        for _ in 0..<10 {
            let completed = CompletedRhythmOffsetDetectionTrial(
                tempo: trial.tempo,
                offset: trial.offset,
                isCorrect: true
            )
            trial = strategy.nextRhythmOffsetDetectionTrial(
                profile: PerceptualProfile(),
                settings: settings,
                lastResult: completed
            )
        }

        let finalPercentage = trial.offset.percentageOfSixteenthNote(at: tempo)
        #expect(finalPercentage < 5.0)
        #expect(finalPercentage > 0.1)
    }

    // MARK: - Helpers

    private func makeCompleted(
        percentage: Double,
        tempo: TempoBPM,
        direction: RhythmDirection,
        correct: Bool
    ) -> CompletedRhythmOffsetDetectionTrial {
        let sixteenthDuration = tempo.sixteenthNoteDuration
        let offsetDuration = sixteenthDuration * (percentage / 100.0)
        let signedDuration = direction == .early ? .zero - offsetDuration : offsetDuration
        let offset = RhythmOffset(signedDuration)
        return CompletedRhythmOffsetDetectionTrial(
            tempo: tempo,
            offset: offset,
            isCorrect: correct
        )
    }
}
