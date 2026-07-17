import Foundation
import Testing
@testable import Peach

@Suite("PitchMatchingTrial Tests")
struct PitchMatchingTrialTests {

    @Test("reference tone sounds equal-tempered regardless of the tuning system")
    func referenceFrequencyIsAlwaysEqualTempered() async {
        let trial = PitchMatchingTrial(referenceNote: MIDINote(61), targetNote: MIDINote(65), initialCentOffset: Cents(12), interval: .up(.majorThird))

        let expected = TuningSystem.equalTemperament.frequency(for: MIDINote(61), referencePitch: .concert440)

        #expect(trial.referenceFrequency(referencePitch: .concert440) == expected)
    }

    @Test("justIntonation in-tune target is the pure ratio above the reference")
    func justIntonationInTuneTargetIsPureRatio() async {
        let trial = PitchMatchingTrial(referenceNote: MIDINote(61), targetNote: MIDINote(65), initialCentOffset: Cents(12), interval: .up(.majorThird))

        let reference = trial.referenceFrequency(referencePitch: .concert440)
        let inTune = trial.inTuneTargetFrequency(tuningSystem: .justIntonation, referencePitch: .concert440)

        #expect(abs(centsAbove(reference, inTune) - 386.314) < 0.001)
    }

    @Test("equalTemperament in-tune target matches the absolute path")
    func equalTemperamentInTuneTargetMatchesAbsolutePath() async {
        let trial = PitchMatchingTrial(referenceNote: MIDINote(60), targetNote: MIDINote(67), initialCentOffset: Cents(-8), interval: .up(.perfectFifth))

        let absolute = TuningSystem.equalTemperament.frequency(for: trial.targetNote, referencePitch: .concert440)
        let inTune = trial.inTuneTargetFrequency(tuningSystem: .equalTemperament, referencePitch: .concert440)

        #expect(abs(centsAbove(absolute, inTune)) < 0.000001)
    }
}
