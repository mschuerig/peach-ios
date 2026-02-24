import Testing
import Foundation
@testable import Peach

@Suite("FrequencyCalculation Tests")
struct FrequencyCalculationTests {

    // MARK: - Forward Conversion

    @Test("Middle C (MIDI 60) at 0 cents is ~261.626 Hz")
    func frequencyCalculation_MiddleC() async throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 60, cents: 0.0)
        #expect(abs(frequency - 261.626) < 0.01)
    }

    @Test("A4 (MIDI 69) at 0 cents is 440.0 Hz")
    func frequencyCalculation_A4() async throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 69, cents: 0.0)
        #expect(abs(frequency - 440.0) < 0.001)
    }

    @Test("MIDI 60 at +50 cents is ~268.9 Hz")
    func frequencyCalculation_HalfStep() async throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 60, cents: 50.0)
        #expect(abs(frequency - 268.9) < 0.5)
    }

    @Test("0.1 cent precision verification")
    func frequencyCalculation_SubCentPrecision() async throws {
        let freq1 = try FrequencyCalculation.frequency(midiNote: 69, cents: 0.0)
        let freq2 = try FrequencyCalculation.frequency(midiNote: 69, cents: 0.1)
        #expect(freq1 != freq2)
        #expect(abs(freq2 - freq1) < 0.1)
    }

    @Test("Custom reference pitch (442 Hz)")
    func frequencyCalculation_CustomReferencePitch() async throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 69, cents: 0.0, referencePitch: 442.0)
        #expect(abs(frequency - 442.0) < 0.001)
    }

    @Test("MIDI note 0 (C-1, ~8.18 Hz)")
    func frequencyCalculation_MIDI0() async throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 0, cents: 0.0)
        #expect(abs(frequency - 8.18) < 0.1)
    }

    @Test("MIDI note 127 (G9, ~12543 Hz)")
    func frequencyCalculation_MIDI127() async throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 127, cents: 0.0)
        #expect(abs(frequency - 12543.0) < 1.0)
    }

    @Test("Negative cent offset (-50 cents)")
    func frequencyCalculation_NegativeCents() async throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 60, cents: -50.0)
        #expect(frequency < 261.626)
        #expect(abs(frequency - 254.2) < 1.0)
    }

    @Test("Extreme positive cent offset (+100 cents) equals next semitone")
    func frequencyCalculation_ExtremeCents() async throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 60, cents: 100.0)
        let cSharp = try FrequencyCalculation.frequency(midiNote: 61, cents: 0.0)
        #expect(abs(frequency - cSharp) < 0.01)
    }

    // MARK: - AudioError

    @Test("AudioError cases are properly defined")
    func audioError_CasesExist() async {
        let error1: AudioError = .engineStartFailed("test")
        let error2: AudioError = .invalidFrequency("test")
        let error3: AudioError = .invalidDuration("test")
        let error4: AudioError = .invalidVelocity("test")
        let error5: AudioError = .invalidPreset("test")
        let error6: AudioError = .contextUnavailable
        #expect(error1 as Error is AudioError)
        #expect(error2 as Error is AudioError)
        #expect(error3 as Error is AudioError)
        #expect(error4 as Error is AudioError)
        #expect(error5 as Error is AudioError)
        #expect(error6 as Error is AudioError)
    }

    // MARK: - Reference Pitch Configuration

    @Test("Default (no parameter) uses A4=440Hz")
    func referencePitch_Default_440Hz() async throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 69, cents: 0.0)
        #expect(abs(frequency - 440.0) < 0.001)
    }

    @Test("Baroque tuning (A4=442Hz)")
    func referencePitch_Baroque_442Hz() async throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 69, cents: 0.0, referencePitch: 442.0)
        #expect(abs(frequency - 442.0) < 0.001)
    }

    @Test("Alternative tuning (A4=432Hz)")
    func referencePitch_Alternative_432Hz() async throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 69, cents: 0.0, referencePitch: 432.0)
        #expect(abs(frequency - 432.0) < 0.001)
    }

    @Test("Historical tuning (A4=415Hz)")
    func referencePitch_Historical_415Hz() async throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 69, cents: 0.0, referencePitch: 415.0)
        #expect(abs(frequency - 415.0) < 0.001)
    }

    @Test("Middle C at different reference pitches")
    func referencePitch_MiddleC_VariousTunings() async throws {
        let c4_at_440 = try FrequencyCalculation.frequency(midiNote: 60, cents: 0.0, referencePitch: 440.0)
        #expect(abs(c4_at_440 - 261.626) < 0.01)

        let c4_at_442 = try FrequencyCalculation.frequency(midiNote: 60, cents: 0.0, referencePitch: 442.0)
        let expectedC4_442 = 261.626 * (442.0 / 440.0)
        #expect(abs(c4_at_442 - expectedC4_442) < 0.01)

        let c4_at_432 = try FrequencyCalculation.frequency(midiNote: 60, cents: 0.0, referencePitch: 432.0)
        let expectedC4_432 = 261.626 * (432.0 / 440.0)
        #expect(abs(c4_at_432 - expectedC4_432) < 0.01)
    }

    @Test("Cent offset with custom reference pitch")
    func referencePitch_WithCentOffset() async throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 69, cents: 50.0, referencePitch: 442.0)
        let expected = 442.0 * pow(2.0, 50.0 / 1200.0)
        #expect(abs(frequency - expected) < 0.01)
    }

    @Test("Fractional cent precision with custom reference pitch")
    func referencePitch_FractionalCent() async throws {
        let freq1 = try FrequencyCalculation.frequency(midiNote: 69, cents: 0.0, referencePitch: 442.0)
        let freq2 = try FrequencyCalculation.frequency(midiNote: 69, cents: 0.1, referencePitch: 442.0)
        #expect(freq1 != freq2)
        #expect(abs(freq2 - freq1) < 0.1)
    }

    @Test("Negative cent offset with custom reference pitch")
    func referencePitch_NegativeCentOffset() async throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 69, cents: -25.0, referencePitch: 432.0)
        let expected = 432.0 * pow(2.0, -25.0 / 1200.0)
        #expect(abs(frequency - expected) < 0.01)
    }

    // MARK: - Reference Pitch Validation

    @Test("Reference pitch too low (< 380 Hz) throws error")
    func referencePitch_TooLow_ThrowsError() async throws {
        #expect(throws: AudioError.self) {
            _ = try FrequencyCalculation.frequency(midiNote: 69, cents: 0.0, referencePitch: 350.0)
        }
    }

    @Test("Reference pitch too high (> 500 Hz) throws error")
    func referencePitch_TooHigh_ThrowsError() async throws {
        #expect(throws: AudioError.self) {
            _ = try FrequencyCalculation.frequency(midiNote: 69, cents: 0.0, referencePitch: 550.0)
        }
    }

    @Test("Reference pitch edge case - exactly 380 Hz is valid")
    func referencePitch_EdgeLow_Valid() async throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 69, cents: 0.0, referencePitch: 380.0)
        #expect(abs(frequency - 380.0) < 0.001)
    }

    @Test("Reference pitch edge case - exactly 500 Hz is valid")
    func referencePitch_EdgeHigh_Valid() async throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 69, cents: 0.0, referencePitch: 500.0)
        #expect(abs(frequency - 500.0) < 0.001)
    }

    // MARK: - Round-Trip Accuracy (Subtask 1.2)

    @Test("Round-trip: A4 (440 Hz) converts to MIDI 69, 0 cents and back within 0.01 cent")
    func roundTrip_A4() async throws {
        let originalFreq = try FrequencyCalculation.frequency(midiNote: 69, cents: 0.0)
        let result = FrequencyCalculation.midiNoteAndCents(frequency: originalFreq)
        #expect(result.midiNote == 69)
        #expect(abs(result.cents) < 0.01)
    }

    @Test("Round-trip: Middle C (MIDI 60) converts back within 0.01 cent")
    func roundTrip_MiddleC() async throws {
        let originalFreq = try FrequencyCalculation.frequency(midiNote: 60, cents: 0.0)
        let result = FrequencyCalculation.midiNoteAndCents(frequency: originalFreq)
        #expect(result.midiNote == 60)
        #expect(abs(result.cents) < 0.01)
    }

    @Test("Round-trip: MIDI 60 + 25 cents converts back within 0.01 cent")
    func roundTrip_withCentOffset() async throws {
        let originalFreq = try FrequencyCalculation.frequency(midiNote: 60, cents: 25.0)
        let result = FrequencyCalculation.midiNoteAndCents(frequency: originalFreq)
        #expect(result.midiNote == 60)
        #expect(abs(result.cents - 25.0) < 0.01)
    }

    @Test("Round-trip: MIDI 60 - 25 cents converts back within 0.01 cent")
    func roundTrip_withNegativeCentOffset() async throws {
        let originalFreq = try FrequencyCalculation.frequency(midiNote: 60, cents: -25.0)
        let result = FrequencyCalculation.midiNoteAndCents(frequency: originalFreq)
        #expect(result.midiNote == 60)
        #expect(abs(result.cents - (-25.0)) < 0.01)
    }

    @Test("Round-trip: MIDI 45 + 73.5 cents converts back within 0.01 cent")
    func roundTrip_arbitraryNoteAndCents() async throws {
        let originalFreq = try FrequencyCalculation.frequency(midiNote: 45, cents: 73.5)
        let result = FrequencyCalculation.midiNoteAndCents(frequency: originalFreq)
        // Could round to MIDI 46 with negative cents if 73.5 > 50, so check the round-trip via frequency
        let reconstructedFreq = try FrequencyCalculation.frequency(
            midiNote: result.midiNote, cents: result.cents
        )
        let centError = 1200.0 * log2(reconstructedFreq / originalFreq)
        #expect(abs(centError) < 0.01)
    }

    // MARK: - Exact MIDI Notes (Subtask 1.3)

    @Test("Exact MIDI note returns 0 cents remainder")
    func exactMidiNote_zeroCents() async throws {
        let freq = try FrequencyCalculation.frequency(midiNote: 69)
        let result = FrequencyCalculation.midiNoteAndCents(frequency: freq)
        #expect(result.midiNote == 69)
        #expect(abs(result.cents) < 0.01)
    }

    @Test("Exact MIDI notes across range return 0 cents")
    func exactMidiNotes_acrossRange() async throws {
        for midiNote in [0, 21, 36, 48, 60, 69, 84, 96, 108, 127] {
            let freq = try FrequencyCalculation.frequency(midiNote: midiNote)
            let result = FrequencyCalculation.midiNoteAndCents(frequency: freq)
            #expect(result.midiNote == midiNote, "MIDI note \(midiNote) failed")
            #expect(abs(result.cents) < 0.01, "MIDI note \(midiNote) had \(result.cents) cents remainder")
        }
    }

    // MARK: - Half-Semitone Offsets (Subtask 1.3)

    @Test("Half-semitone offset (+50 cents) returns ~50 cents remainder")
    func halfSemitoneOffset_positive() async throws {
        let freq = try FrequencyCalculation.frequency(midiNote: 60, cents: 50.0)
        let result = FrequencyCalculation.midiNoteAndCents(frequency: freq)
        // At exactly +50 cents, the nearest MIDI note is still 60 (rounds to 60, not 61)
        // But rounding could go either way at exactly 50 — check the round-trip
        let reconstructedFreq = try FrequencyCalculation.frequency(
            midiNote: result.midiNote, cents: result.cents
        )
        let centError = 1200.0 * log2(reconstructedFreq / freq)
        #expect(abs(centError) < 0.01)
        #expect(abs(abs(result.cents) - 50.0) < 0.01)
    }

    @Test("Half-semitone offset (-50 cents) returns ~-50 cents remainder")
    func halfSemitoneOffset_negative() async throws {
        let freq = try FrequencyCalculation.frequency(midiNote: 60, cents: -50.0)
        let result = FrequencyCalculation.midiNoteAndCents(frequency: freq)
        let reconstructedFreq = try FrequencyCalculation.frequency(
            midiNote: result.midiNote, cents: result.cents
        )
        let centError = 1200.0 * log2(reconstructedFreq / freq)
        #expect(abs(centError) < 0.01)
        #expect(abs(abs(result.cents) - 50.0) < 0.01)
    }

    // MARK: - Boundary Frequencies (Subtask 1.3)

    @Test("Lowest MIDI note (0) frequency converts back correctly")
    func boundaryFrequency_lowestMidi() async throws {
        let freq = try FrequencyCalculation.frequency(midiNote: 0)
        let result = FrequencyCalculation.midiNoteAndCents(frequency: freq)
        #expect(result.midiNote == 0)
        #expect(abs(result.cents) < 0.01)
    }

    @Test("Highest MIDI note (127) frequency converts back correctly")
    func boundaryFrequency_highestMidi() async throws {
        let freq = try FrequencyCalculation.frequency(midiNote: 127)
        let result = FrequencyCalculation.midiNoteAndCents(frequency: freq)
        #expect(result.midiNote == 127)
        #expect(abs(result.cents) < 0.01)
    }

    // MARK: - Non-440 Reference Pitches (Subtask 1.3)

    @Test("Round-trip with A442 reference pitch within 0.01 cent")
    func roundTrip_referencePitch442() async throws {
        let freq = try FrequencyCalculation.frequency(midiNote: 60, cents: 30.0, referencePitch: 442.0)
        let result = FrequencyCalculation.midiNoteAndCents(frequency: freq, referencePitch: 442.0)
        #expect(result.midiNote == 60)
        #expect(abs(result.cents - 30.0) < 0.01)
    }

    @Test("Round-trip with A415 reference pitch within 0.01 cent")
    func roundTrip_referencePitch415() async throws {
        let freq = try FrequencyCalculation.frequency(midiNote: 69, cents: -15.0, referencePitch: 415.0)
        let result = FrequencyCalculation.midiNoteAndCents(frequency: freq, referencePitch: 415.0)
        #expect(result.midiNote == 69)
        #expect(abs(result.cents - (-15.0)) < 0.01)
    }

    @Test("A4 at 442 Hz reference returns MIDI 69, 0 cents")
    func referencePitch442_A4() async {
        let result = FrequencyCalculation.midiNoteAndCents(frequency: 442.0, referencePitch: 442.0)
        #expect(result.midiNote == 69)
        #expect(abs(result.cents) < 0.01)
    }

    // MARK: - Cents Range Validation

    @Test("Cents remainder is always in range -50 to +50")
    func centsRemainderRange() async throws {
        // Test a variety of frequencies to ensure cents is always within [-50, 50]
        for midiNote in stride(from: 0, through: 127, by: 10) {
            for cents in stride(from: -49.0, through: 49.0, by: 7.0) {
                let freq = try FrequencyCalculation.frequency(midiNote: midiNote, cents: cents)
                let result = FrequencyCalculation.midiNoteAndCents(frequency: freq)
                #expect(result.cents >= -50.0 && result.cents <= 50.0)
            }
        }
    }
}
