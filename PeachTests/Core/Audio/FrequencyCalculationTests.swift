import Testing
import Foundation
@testable import Peach

@Suite("FrequencyCalculation Reverse Conversion Tests")
struct FrequencyCalculationTests {

    // MARK: - Round-Trip Accuracy (Subtask 1.2)

    @Test("Round-trip: A4 (440 Hz) converts to MIDI 69, 0 cents and back within 0.01 cent")
    @MainActor func roundTrip_A4() async throws {
        let originalFreq = try FrequencyCalculation.frequency(midiNote: 69, cents: 0.0)
        let result = FrequencyCalculation.midiNoteAndCents(frequency: originalFreq)
        #expect(result.midiNote == 69)
        #expect(abs(result.cents) < 0.01)
    }

    @Test("Round-trip: Middle C (MIDI 60) converts back within 0.01 cent")
    @MainActor func roundTrip_MiddleC() async throws {
        let originalFreq = try FrequencyCalculation.frequency(midiNote: 60, cents: 0.0)
        let result = FrequencyCalculation.midiNoteAndCents(frequency: originalFreq)
        #expect(result.midiNote == 60)
        #expect(abs(result.cents) < 0.01)
    }

    @Test("Round-trip: MIDI 60 + 25 cents converts back within 0.01 cent")
    @MainActor func roundTrip_withCentOffset() async throws {
        let originalFreq = try FrequencyCalculation.frequency(midiNote: 60, cents: 25.0)
        let result = FrequencyCalculation.midiNoteAndCents(frequency: originalFreq)
        #expect(result.midiNote == 60)
        #expect(abs(result.cents - 25.0) < 0.01)
    }

    @Test("Round-trip: MIDI 60 - 25 cents converts back within 0.01 cent")
    @MainActor func roundTrip_withNegativeCentOffset() async throws {
        let originalFreq = try FrequencyCalculation.frequency(midiNote: 60, cents: -25.0)
        let result = FrequencyCalculation.midiNoteAndCents(frequency: originalFreq)
        #expect(result.midiNote == 60)
        #expect(abs(result.cents - (-25.0)) < 0.01)
    }

    @Test("Round-trip: MIDI 45 + 73.5 cents converts back within 0.01 cent")
    @MainActor func roundTrip_arbitraryNoteAndCents() async throws {
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
    @MainActor func exactMidiNote_zeroCents() async throws {
        let freq = try FrequencyCalculation.frequency(midiNote: 69)
        let result = FrequencyCalculation.midiNoteAndCents(frequency: freq)
        #expect(result.midiNote == 69)
        #expect(abs(result.cents) < 0.01)
    }

    @Test("Exact MIDI notes across range return 0 cents")
    @MainActor func exactMidiNotes_acrossRange() async throws {
        for midiNote in [0, 21, 36, 48, 60, 69, 84, 96, 108, 127] {
            let freq = try FrequencyCalculation.frequency(midiNote: midiNote)
            let result = FrequencyCalculation.midiNoteAndCents(frequency: freq)
            #expect(result.midiNote == midiNote, "MIDI note \(midiNote) failed")
            #expect(abs(result.cents) < 0.01, "MIDI note \(midiNote) had \(result.cents) cents remainder")
        }
    }

    // MARK: - Half-Semitone Offsets (Subtask 1.3)

    @Test("Half-semitone offset (+50 cents) returns ~50 cents remainder")
    @MainActor func halfSemitoneOffset_positive() async throws {
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
    @MainActor func halfSemitoneOffset_negative() async throws {
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
    @MainActor func boundaryFrequency_lowestMidi() async throws {
        let freq = try FrequencyCalculation.frequency(midiNote: 0)
        let result = FrequencyCalculation.midiNoteAndCents(frequency: freq)
        #expect(result.midiNote == 0)
        #expect(abs(result.cents) < 0.01)
    }

    @Test("Highest MIDI note (127) frequency converts back correctly")
    @MainActor func boundaryFrequency_highestMidi() async throws {
        let freq = try FrequencyCalculation.frequency(midiNote: 127)
        let result = FrequencyCalculation.midiNoteAndCents(frequency: freq)
        #expect(result.midiNote == 127)
        #expect(abs(result.cents) < 0.01)
    }

    // MARK: - Non-440 Reference Pitches (Subtask 1.3)

    @Test("Round-trip with A442 reference pitch within 0.01 cent")
    @MainActor func roundTrip_referencePitch442() async throws {
        let freq = try FrequencyCalculation.frequency(midiNote: 60, cents: 30.0, referencePitch: 442.0)
        let result = FrequencyCalculation.midiNoteAndCents(frequency: freq, referencePitch: 442.0)
        #expect(result.midiNote == 60)
        #expect(abs(result.cents - 30.0) < 0.01)
    }

    @Test("Round-trip with A415 reference pitch within 0.01 cent")
    @MainActor func roundTrip_referencePitch415() async throws {
        let freq = try FrequencyCalculation.frequency(midiNote: 69, cents: -15.0, referencePitch: 415.0)
        let result = FrequencyCalculation.midiNoteAndCents(frequency: freq, referencePitch: 415.0)
        #expect(result.midiNote == 69)
        #expect(abs(result.cents - (-15.0)) < 0.01)
    }

    @Test("A4 at 442 Hz reference returns MIDI 69, 0 cents")
    @MainActor func referencePitch442_A4() async {
        let result = FrequencyCalculation.midiNoteAndCents(frequency: 442.0, referencePitch: 442.0)
        #expect(result.midiNote == 69)
        #expect(abs(result.cents) < 0.01)
    }

    // MARK: - Cents Range Validation

    @Test("Cents remainder is always in range -50 to +50")
    @MainActor func centsRemainderRange() async throws {
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
