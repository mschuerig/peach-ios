import Foundation
import Testing
@testable import Peach

@Suite("PitchDiscriminationTrial Tests")
struct PitchDiscriminationTrialTests {

    private func centsAbove(_ reference: Frequency, _ target: Frequency) -> Double {
        1200.0 * log2(target.rawValue / reference.rawValue)
    }

    @Test("referenceFrequency calculates valid frequency for middle C")
    func referenceFrequencyCalculatesCorrectly() async {
        let trial = PitchDiscriminationTrial(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(100.0)), interval: .prime)

        let freq = trial.referenceFrequency(referencePitch: .concert440)

        #expect(freq.rawValue >= 260 && freq.rawValue <= 263)
    }

    @Test("targetFrequency applies positive cent offset (higher)")
    func targetFrequencyAppliesCentOffsetHigher() async {
        let trial = PitchDiscriminationTrial(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(100.0)), interval: .prime)

        let freq1 = trial.referenceFrequency(referencePitch: .concert440)
        let freq2 = trial.targetFrequency(tuningSystem: .equalTemperament, referencePitch: .concert440)

        #expect(freq2 > freq1)

        let ratio = freq2.rawValue / freq1.rawValue
        #expect(ratio >= 1.05 && ratio <= 1.07)
    }

    @Test("targetFrequency applies negative cent offset (lower)")
    func targetFrequencyAppliesCentOffsetLower() async {
        let trial = PitchDiscriminationTrial(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(-100.0)), interval: .prime)

        let freq1 = trial.referenceFrequency(referencePitch: .concert440)
        let freq2 = trial.targetFrequency(tuningSystem: .equalTemperament, referencePitch: .concert440)

        #expect(freq2 < freq1)
    }

    @Test("isTargetHigher reflects positive cent difference")
    func isTargetHigherPositiveCents() async {
        let trial = PitchDiscriminationTrial(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(50.0)), interval: .prime)
        #expect(trial.isTargetHigher == true)
    }

    @Test("isTargetHigher reflects negative cent difference")
    func isTargetHigherNegativeCents() async {
        let trial = PitchDiscriminationTrial(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(-50.0)), interval: .prime)
        #expect(trial.isTargetHigher == false)
    }

    @Test("isCorrect validates user answer against cent direction")
    func isCorrectValidatesAnswer() async {
        let higher = PitchDiscriminationTrial(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(100.0)), interval: .prime)
        let lower = PitchDiscriminationTrial(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(-100.0)), interval: .prime)

        #expect(higher.isCorrect(userAnswerHigher: true) == true)
        #expect(higher.isCorrect(userAnswerHigher: false) == false)
        #expect(lower.isCorrect(userAnswerHigher: false) == true)
        #expect(lower.isCorrect(userAnswerHigher: true) == false)
    }

    // MARK: - Reference-Relative Frequencies (Story 87.1)

    @Test("reference tone sounds equal-tempered regardless of the trial's tuning system")
    func referenceFrequencyIsAlwaysEqualTempered() async {
        let trial = PitchDiscriminationTrial(referenceNote: 61, targetNote: DetunedMIDINote(note: 65, offset: Cents(0)), interval: .up(.majorThird))

        let expected = TuningSystem.equalTemperament.frequency(for: MIDINote(61), referencePitch: .concert440)

        #expect(trial.referenceFrequency(referencePitch: .concert440) == expected)
    }

    @Test("justIntonation in-tune relationship is invariant under the reference note (matrix row 3)")
    func justIntonationTrialRootInvariance() async {
        let detune = Cents(8.0)
        let trialFromCSharp = PitchDiscriminationTrial(
            referenceNote: 61, targetNote: DetunedMIDINote(note: 65, offset: detune), interval: .up(.majorThird))
        let trialFromG = PitchDiscriminationTrial(
            referenceNote: 67, targetNote: DetunedMIDINote(note: 71, offset: detune), interval: .up(.majorThird))

        let relationshipFromCSharp = centsAbove(
            trialFromCSharp.referenceFrequency(referencePitch: .concert440),
            trialFromCSharp.targetFrequency(tuningSystem: .justIntonation, referencePitch: .concert440))
        let relationshipFromG = centsAbove(
            trialFromG.referenceFrequency(referencePitch: .concert440),
            trialFromG.targetFrequency(tuningSystem: .justIntonation, referencePitch: .concert440))

        #expect(abs(relationshipFromCSharp - relationshipFromG) < 0.000001)
        #expect(abs(relationshipFromCSharp - (386.314 + 8.0)) < 0.001)
    }

    @Test("equalTemperament trial frequencies match the pre-change absolute path (matrix row 5)")
    func equalTemperamentTrialMatchesAbsolutePath() async {
        let trials = [
            PitchDiscriminationTrial(referenceNote: 48, targetNote: DetunedMIDINote(note: 55, offset: Cents(-14.6)), interval: .up(.perfectFifth)),
            PitchDiscriminationTrial(referenceNote: 71, targetNote: DetunedMIDINote(note: 67, offset: Cents(8.0)), interval: .down(.majorThird)),
            PitchDiscriminationTrial(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(3.2)), interval: .prime),
        ]
        for trial in trials {
            let absoluteReference = TuningSystem.equalTemperament.frequency(
                for: trial.referenceNote, referencePitch: .concert440)
            let absoluteTarget = TuningSystem.equalTemperament.frequency(
                for: trial.targetNote, referencePitch: .concert440)

            let reference = trial.referenceFrequency(referencePitch: .concert440)
            let target = trial.targetFrequency(tuningSystem: .equalTemperament, referencePitch: .concert440)

            #expect(abs(centsAbove(absoluteReference, reference)) < 0.000001)
            #expect(abs(centsAbove(absoluteTarget, target)) < 0.000001)
        }
    }

    @Test("justIntonation unison trial keeps the bare-detune relationship (matrix row 6)")
    func justIntonationUnisonTrialUnchangedRelationship() async {
        let trial = PitchDiscriminationTrial(referenceNote: 57, targetNote: DetunedMIDINote(note: 57, offset: Cents(8.0)), interval: .prime)

        let reference = trial.referenceFrequency(referencePitch: .concert440)
        let target = trial.targetFrequency(tuningSystem: .justIntonation, referencePitch: .concert440)

        #expect(abs(centsAbove(reference, target) - 8.0) < 0.001)
    }

    @Test("justIntonation descending fifth trial is the inverted pure ratio (matrix row 4)")
    func justIntonationDescendingFifthThroughTrialAPI() async {
        let trial = PitchDiscriminationTrial(referenceNote: 71, targetNote: DetunedMIDINote(note: 64, offset: Cents(0)), interval: .down(.perfectFifth))

        let reference = trial.referenceFrequency(referencePitch: .concert440)
        let target = trial.targetFrequency(tuningSystem: .justIntonation, referencePitch: .concert440)

        #expect(abs(centsAbove(reference, target) + 701.955) < 0.001)
    }

    @Test("justIntonation octave trial is exactly 2/1 (matrix row 7)")
    func justIntonationOctaveTrialPure() async {
        let trial = PitchDiscriminationTrial(referenceNote: 52, targetNote: DetunedMIDINote(note: 64, offset: Cents(0)), interval: .up(.octave))

        let reference = trial.referenceFrequency(referencePitch: .concert440)
        let target = trial.targetFrequency(tuningSystem: .justIntonation, referencePitch: .concert440)

        #expect(abs(centsAbove(reference, target) - 1200.0) < 0.000001)
    }

    @Test("justIntonation major third target sits 13.686 cents flat of the equal-tempered target (matrix row 10)")
    func justIntonationMajorThirdDivergenceThroughTrialAPI() async {
        let trial = PitchDiscriminationTrial(referenceNote: 61, targetNote: DetunedMIDINote(note: 65, offset: Cents(0)), interval: .up(.majorThird))

        let etTarget = trial.targetFrequency(tuningSystem: .equalTemperament, referencePitch: .concert440)
        let jiTarget = trial.targetFrequency(tuningSystem: .justIntonation, referencePitch: .concert440)

        #expect(abs(centsAbove(jiTarget, etTarget) - 13.686) < 0.001)
    }
}

@Suite("CompletedPitchDiscriminationTrial Tests")
struct CompletedPitchDiscriminationTrialTests {

    @Test("isCorrect delegates to discrimination logic")
    func isCorrectDelegatesToPitchDiscriminationTrial() async {
        let trial = PitchDiscriminationTrial(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(100.0)), interval: .prime)

        let correct = CompletedPitchDiscriminationTrial(trial: trial, userAnsweredHigher: true, tuningSystem: .equalTemperament)
        let incorrect = CompletedPitchDiscriminationTrial(trial: trial, userAnsweredHigher: false, tuningSystem: .equalTemperament)

        #expect(correct.isCorrect == true)
        #expect(incorrect.isCorrect == false)
    }

    @Test("timestamp defaults to now")
    func timestampDefaultsToNow() async {
        let before = Date()
        let completed = CompletedPitchDiscriminationTrial(
            trial: PitchDiscriminationTrial(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(50.0)), interval: .prime),
            userAnsweredHigher: true,
            tuningSystem: .equalTemperament
        )
        let after = Date()

        #expect(completed.timestamp >= before)
        #expect(completed.timestamp <= after)
    }
}
