import Testing
import Foundation
@testable import Peach

/// Tests for KazezNoteStrategy — Kazez et al. (2001) default training strategy
@Suite("KazezNoteStrategy Tests")
struct KazezNoteStrategyTests {

    // MARK: - Protocol Compliance

    @Test("Conforms to NextPitchComparisonStrategy and returns valid PitchComparison")
    func protocolCompliance() async {
        let strategy = KazezNoteStrategy()
        let settings = PitchComparisonTrainingSettings(referencePitch: .concert440, intervals: [.prime])
        let comparison = strategy.nextPitchComparison(
            profile: PerceptualProfile(),
            settings: settings,
            lastPitchComparison: nil,
            interval: .prime,
        )

        #expect(settings.noteRange.contains(comparison.referenceNote))
        #expect(comparison.targetNote.note == comparison.referenceNote)
        #expect(comparison.targetNote.offset.magnitude > 0)
    }

    // MARK: - First Comparison

    @Test("First comparison uses maxCentDifference")
    func firstComparisonUsesMax() async {
        let strategy = KazezNoteStrategy()
        let settings = PitchComparisonTrainingSettings(referencePitch: .concert440, intervals: [.prime], maxCentDifference: Cents(100.0))

        let comparison = strategy.nextPitchComparison(
            profile: PerceptualProfile(),
            settings: settings,
            lastPitchComparison: nil,
            interval: .prime,
        )

        #expect(comparison.targetNote.offset.magnitude == 100.0)
    }

    @Test("First comparison respects custom maxCentDifference")
    func firstComparisonCustomMax() async {
        let strategy = KazezNoteStrategy()
        let settings = PitchComparisonTrainingSettings(referencePitch: .concert440, intervals: [.prime], maxCentDifference: Cents(50.0))

        let comparison = strategy.nextPitchComparison(
            profile: PerceptualProfile(),
            settings: settings,
            lastPitchComparison: nil,
            interval: .prime,
        )

        #expect(comparison.targetNote.offset.magnitude == 50.0)
    }

    // MARK: - Kazez Correct Formula: N = P × [1 - (0.05 × √P)]

    @Test("Correct at P=100: N = 100 × [1 - 0.05×10] = 50")
    func correctAt100() async {
        let result = nextAfterCorrect(p: 100.0)
        #expect(abs(result - 50.0) < 0.001)
    }

    @Test("Correct at P=50: N = 50 × [1 - 0.05×√50] ≈ 32.32")
    func correctAt50() async {
        let expected = 50.0 * (1.0 - 0.05 * 50.0.squareRoot())
        let result = nextAfterCorrect(p: 50.0)
        #expect(abs(result - expected) < 0.001)
    }

    @Test("Correct at P=10: N = 10 × [1 - 0.05×√10] ≈ 8.42")
    func correctAt10() async {
        let expected = 10.0 * (1.0 - 0.05 * 10.0.squareRoot())
        let result = nextAfterCorrect(p: 10.0)
        #expect(abs(result - expected) < 0.001)
    }

    @Test("Correct at P=5: N = 5 × [1 - 0.05×√5] ≈ 4.44")
    func correctAt5() async {
        let expected = 5.0 * (1.0 - 0.05 * 5.0.squareRoot())
        let result = nextAfterCorrect(p: 5.0)
        #expect(abs(result - expected) < 0.001)
    }

    // MARK: - Kazez Incorrect Formula: N = P × [1 + (0.09 × √P)]

    @Test("Incorrect at P=5: N = 5 × [1 + 0.09×√5] ≈ 6.01")
    func incorrectAt5() async {
        let expected = 5.0 * (1.0 + 0.09 * 5.0.squareRoot())
        let result = nextAfterIncorrect(p: 5.0)
        #expect(abs(result - expected) < 0.001)
    }

    @Test("Incorrect at P=10: N = 10 × [1 + 0.09×√10] ≈ 12.85")
    func incorrectAt10() async {
        let expected = 10.0 * (1.0 + 0.09 * 10.0.squareRoot())
        let result = nextAfterIncorrect(p: 10.0)
        #expect(abs(result - expected) < 0.001)
    }

    @Test("Incorrect at P=50: N = 50 × [1 + 0.09×√50] ≈ 81.82")
    func incorrectAt50() async {
        let expected = 50.0 * (1.0 + 0.09 * 50.0.squareRoot())
        let result = nextAfterIncorrect(p: 50.0)
        #expect(abs(result - expected) < 0.001)
    }

    // MARK: - Clamping

    @Test("Floor clamping: result never below minCentDifference")
    func floorClamping() async {
        let strategy = KazezNoteStrategy()
        let settings = PitchComparisonTrainingSettings(referencePitch: .concert440, intervals: [.prime], minCentDifference: Cents(5.0))
        // P=1: N = 1 × [1 - 0.05×1] = 0.95 → clamped to 5.0
        let last = makeCompleted(offset: 1.0, correct: true)

        let comparison = strategy.nextPitchComparison(
            profile: PerceptualProfile(),
            settings: settings,
            lastPitchComparison: last,
            interval: .prime,
        )

        #expect(comparison.targetNote.offset.magnitude == 5.0)
    }

    @Test("Ceiling clamping: result never above maxCentDifference")
    func ceilingClamping() async {
        let strategy = KazezNoteStrategy()
        let settings = PitchComparisonTrainingSettings(referencePitch: .concert440, intervals: [.prime], maxCentDifference: Cents(100.0))
        // P=50 incorrect: N = 50 × [1 + 0.09×7.07] ≈ 81.8 → under ceiling
        // P=100 incorrect: N = 100 × [1 + 0.09×10] = 190 → clamped to 100
        let last = makeCompleted(offset: 100.0, correct: false)

        let comparison = strategy.nextPitchComparison(
            profile: PerceptualProfile(),
            settings: settings,
            lastPitchComparison: last,
            interval: .prime,
        )

        #expect(comparison.targetNote.offset.magnitude == 100.0)
    }

    // MARK: - Note Range

    @Test("Notes always within settings noteRange")
    func noteRange() async {
        let strategy = KazezNoteStrategy()
        let settings = PitchComparisonTrainingSettings(noteRange: NoteRange(lowerBound: MIDINote(48), upperBound: MIDINote(72)), referencePitch: .concert440, intervals: [.prime])

        for _ in 0..<100 {
            let comparison = strategy.nextPitchComparison(
                profile: PerceptualProfile(),
                settings: settings,
                lastPitchComparison: nil,
                interval: .prime,
            )
            #expect(comparison.referenceNote >= 48 && comparison.referenceNote <= 72)
        }
    }

    @Test("Notes respect custom note range from settings")
    func customNoteRange() async {
        let strategy = KazezNoteStrategy()
        let settings = PitchComparisonTrainingSettings(noteRange: NoteRange(lowerBound: MIDINote(60), upperBound: MIDINote(72)), referencePitch: .concert440, intervals: [.prime])

        for _ in 0..<100 {
            let comparison = strategy.nextPitchComparison(
                profile: PerceptualProfile(),
                settings: settings,
                lastPitchComparison: nil,
                interval: .prime,
            )
            #expect(comparison.referenceNote >= 60 && comparison.referenceNote <= 72)
        }
    }

    // MARK: - Cold Start from Profile

    @Test("Cold start with empty profile uses maxCentDifference")
    func coldStartEmptyProfile() async {
        let strategy = KazezNoteStrategy()
        let profile = PerceptualProfile()
        let settings = PitchComparisonTrainingSettings(referencePitch: .concert440, intervals: [.prime], maxCentDifference: Cents(100.0))

        let comparison = strategy.nextPitchComparison(
            profile: profile,
            settings: settings,
            lastPitchComparison: nil,
            interval: .prime,
        )

        #expect(comparison.targetNote.offset.magnitude == 100.0)
    }

    @Test("Cold start with trained profile uses comparisonMean")
    func coldStartWithProfile() async throws {
        let strategy = KazezNoteStrategy()
        let profile = PerceptualProfile()
        // Train some notes so comparisonMean returns a value
        profile.updateComparison(note: 60, centOffset: 10.0, isCorrect: true)
        profile.updateComparison(note: 60, centOffset: 8.0, isCorrect: true)
        profile.updateComparison(note: 72, centOffset: 12.0, isCorrect: false)

        let settings = PitchComparisonTrainingSettings(referencePitch: .concert440, intervals: [.prime], maxCentDifference: Cents(100.0))

        let comparison = strategy.nextPitchComparison(
            profile: profile,
            settings: settings,
            lastPitchComparison: nil,
            interval: .prime,
        )

        // comparisonMean should be used, not maxCentDifference
        let expectedMean = try #require(profile.comparisonMean)
        #expect(comparison.targetNote.offset.magnitude == expectedMean.rawValue)
        #expect(comparison.targetNote.offset.magnitude != 100.0)
    }

    @Test("Cold start with profile clamps to minCentDifference")
    func coldStartProfileClampedToMin() async {
        let strategy = KazezNoteStrategy()
        let profile = PerceptualProfile()
        // Train a note with very small offset
        profile.updateComparison(note: 60, centOffset: 0.05, isCorrect: true)

        let settings = PitchComparisonTrainingSettings(referencePitch: .concert440, intervals: [.prime], minCentDifference: Cents(1.0), maxCentDifference: Cents(100.0))

        let comparison = strategy.nextPitchComparison(
            profile: profile,
            settings: settings,
            lastPitchComparison: nil,
            interval: .prime,
        )

        // comparisonMean (0.05) should be clamped to minCentDifference (1.0)
        #expect(comparison.targetNote.offset.magnitude >= settings.minCentDifference.rawValue)
    }

    @Test("Cold start with profile clamps to maxCentDifference")
    func coldStartProfileClampedToMax() async {
        let strategy = KazezNoteStrategy()
        let profile = PerceptualProfile()
        // Train with large offsets
        profile.updateComparison(note: 60, centOffset: 200.0, isCorrect: true)

        let settings = PitchComparisonTrainingSettings(referencePitch: .concert440, intervals: [.prime], maxCentDifference: Cents(100.0))

        let comparison = strategy.nextPitchComparison(
            profile: profile,
            settings: settings,
            lastPitchComparison: nil,
            interval: .prime,
        )

        // comparisonMean (200.0) should be clamped to maxCentDifference (100.0)
        #expect(comparison.targetNote.offset.magnitude <= settings.maxCentDifference.rawValue)
    }

    // MARK: - Convergence

    @Test("10 consecutive correct answers from 100 cents reaches ~5 cents")
    func convergenceTest() async {
        let strategy = KazezNoteStrategy()
        let settings = PitchComparisonTrainingSettings(referencePitch: .concert440, intervals: [.prime], minCentDifference: Cents(1.0), maxCentDifference: Cents(100.0))

        // First comparison: 100 cents
        var comparison = strategy.nextPitchComparison(
            profile: PerceptualProfile(),
            settings: settings,
            lastPitchComparison: nil,
            interval: .prime,
        )
        #expect(comparison.targetNote.offset.magnitude == 100.0)

        // Simulate 10 consecutive correct answers
        for _ in 0..<10 {
            let completed = CompletedPitchComparison(
                pitchComparison: comparison,
                userAnsweredHigher: comparison.isTargetHigher, // correct
                tuningSystem: .equalTemperament
            )
            comparison = strategy.nextPitchComparison(
                profile: PerceptualProfile(),
                settings: settings,
                lastPitchComparison: completed,
                interval: .prime,
            )
        }

        // After 10 correct answers, should be in the ~4-6 cent range
        #expect(comparison.targetNote.offset.magnitude < 7.0)
        #expect(comparison.targetNote.offset.magnitude > 2.0)
    }

    @Test("Recovery after incorrect answer at low difficulty")
    func recoveryTest() async {
        let strategy = KazezNoteStrategy()
        let settings = PitchComparisonTrainingSettings(referencePitch: .concert440, intervals: [.prime], minCentDifference: Cents(1.0), maxCentDifference: Cents(100.0))

        // Start at 5 cents, get it wrong
        let last = makeCompleted(offset: 5.0, correct: false)
        let comparison = strategy.nextPitchComparison(
            profile: PerceptualProfile(),
            settings: settings,
            lastPitchComparison: last,
            interval: .prime,
        )

        // N = 5 × [1 + 0.09×√5] ≈ 5 × 1.201 ≈ 6.0
        #expect(comparison.targetNote.offset.magnitude > 5.0)
        #expect(comparison.targetNote.offset.magnitude < 7.0)
    }

    // MARK: - Interval Support

    @Test("Unison interval produces targetNote.note == referenceNote")
    func unisonIntervalSameNote() async {
        let strategy = KazezNoteStrategy()
        let settings = PitchComparisonTrainingSettings(referencePitch: .concert440, intervals: [.prime])

        for _ in 0..<20 {
            let comparison = strategy.nextPitchComparison(
                profile: PerceptualProfile(),
                settings: settings,
                lastPitchComparison: nil,
                interval: .prime,
            )
            #expect(comparison.targetNote.note == comparison.referenceNote)
        }
    }

    @Test("Perfect fifth interval produces targetNote.note 7 semitones above referenceNote")
    func perfectFifthInterval() async {
        let strategy = KazezNoteStrategy()
        let settings = PitchComparisonTrainingSettings(noteRange: NoteRange(lowerBound: MIDINote(48), upperBound: MIDINote(84)), referencePitch: .concert440, intervals: [.prime])

        for _ in 0..<20 {
            let comparison = strategy.nextPitchComparison(
                profile: PerceptualProfile(),
                settings: settings,
                lastPitchComparison: nil,
                interval: .up(.perfectFifth),
            )
            #expect(comparison.targetNote.note.rawValue == comparison.referenceNote.rawValue + 7)
        }
    }

    @Test("MIDI range constraint prevents overflow with large interval")
    func midiRangeConstraint() async {
        let strategy = KazezNoteStrategy()
        let settings = PitchComparisonTrainingSettings(noteRange: NoteRange(lowerBound: MIDINote(60), upperBound: MIDINote(124)), referencePitch: .concert440, intervals: [.prime])

        for _ in 0..<50 {
            let comparison = strategy.nextPitchComparison(
                profile: PerceptualProfile(),
                settings: settings,
                lastPitchComparison: nil,
                interval: .up(.perfectFifth),
            )
            #expect(comparison.referenceNote.rawValue <= 120)
            #expect(comparison.targetNote.note.rawValue <= 127)
        }
    }

    @Test("Octave interval produces targetNote.note 12 semitones above referenceNote")
    func octaveInterval() async {
        let strategy = KazezNoteStrategy()
        let settings = PitchComparisonTrainingSettings(noteRange: NoteRange(lowerBound: MIDINote(48), upperBound: MIDINote(84)), referencePitch: .concert440, intervals: [.prime])

        for _ in 0..<20 {
            let comparison = strategy.nextPitchComparison(
                profile: PerceptualProfile(),
                settings: settings,
                lastPitchComparison: nil,
                interval: .up(.octave),
            )
            #expect(comparison.targetNote.note.rawValue == comparison.referenceNote.rawValue + 12)
            #expect(comparison.targetNote.note.rawValue <= 127)
        }
    }

    @Test("Downward perfect fifth produces targetNote.note 7 semitones below referenceNote")
    func downwardPerfectFifthInterval() async {
        let strategy = KazezNoteStrategy()
        let settings = PitchComparisonTrainingSettings(noteRange: NoteRange(lowerBound: MIDINote(48), upperBound: MIDINote(84)), referencePitch: .concert440, intervals: [.prime])

        for _ in 0..<20 {
            let comparison = strategy.nextPitchComparison(
                profile: PerceptualProfile(),
                settings: settings,
                lastPitchComparison: nil,
                interval: .down(.perfectFifth),
            )
            #expect(comparison.targetNote.note.rawValue == comparison.referenceNote.rawValue - 7)
            #expect(comparison.targetNote.note.rawValue >= 0)
        }
    }

    @Test("Downward interval constrains reference note minimum to interval semitones")
    func downwardIntervalNoteRangeConstraint() async {
        let strategy = KazezNoteStrategy()
        let settings = PitchComparisonTrainingSettings(noteRange: NoteRange(lowerBound: MIDINote(0), upperBound: MIDINote(84)), referencePitch: .concert440, intervals: [.prime])

        for _ in 0..<50 {
            let comparison = strategy.nextPitchComparison(
                profile: PerceptualProfile(),
                settings: settings,
                lastPitchComparison: nil,
                interval: .down(.perfectFifth),
            )
            // Reference note must be >= 7 so target (ref - 7) stays >= 0
            #expect(comparison.referenceNote.rawValue >= 7)
            #expect(comparison.targetNote.note.rawValue >= 0)
        }
    }

    @Test("Downward octave constrains reference note minimum to 12")
    func downwardOctaveNoteRangeConstraint() async {
        let strategy = KazezNoteStrategy()
        let settings = PitchComparisonTrainingSettings(noteRange: NoteRange(lowerBound: MIDINote(0), upperBound: MIDINote(84)), referencePitch: .concert440, intervals: [.prime])

        for _ in 0..<50 {
            let comparison = strategy.nextPitchComparison(
                profile: PerceptualProfile(),
                settings: settings,
                lastPitchComparison: nil,
                interval: .down(.octave),
            )
            #expect(comparison.referenceNote.rawValue >= 12)
            #expect(comparison.targetNote.note.rawValue == comparison.referenceNote.rawValue - 12)
            #expect(comparison.targetNote.note.rawValue >= 0)
        }
    }

    // MARK: - Helpers

    private func nextAfterCorrect(p: Double) -> Double {
        let strategy = KazezNoteStrategy()
        let settings = PitchComparisonTrainingSettings(referencePitch: .concert440, intervals: [.prime], minCentDifference: Cents(0.1))
        let last = makeCompleted(offset: p, correct: true)
        return strategy.nextPitchComparison(
            profile: PerceptualProfile(),
            settings: settings,
            lastPitchComparison: last,
            interval: .prime,
        ).targetNote.offset.magnitude
    }

    private func nextAfterIncorrect(p: Double) -> Double {
        let strategy = KazezNoteStrategy()
        let settings = PitchComparisonTrainingSettings(referencePitch: .concert440, intervals: [.prime], maxCentDifference: Cents(200.0))
        let last = makeCompleted(offset: p, correct: false)
        return strategy.nextPitchComparison(
            profile: PerceptualProfile(),
            settings: settings,
            lastPitchComparison: last,
            interval: .prime,
        ).targetNote.offset.magnitude
    }

    private func makeCompleted(offset: Double, correct: Bool) -> CompletedPitchComparison {
        let comp = PitchComparison(
            referenceNote: 60,
            targetNote: DetunedMIDINote(note: 60, offset: Cents(offset))
        )
        return CompletedPitchComparison(
            pitchComparison: comp,
            userAnsweredHigher: correct, // isTargetHigher is true (positive cents), so correct = higher
            tuningSystem: .equalTemperament
        )
    }
}
