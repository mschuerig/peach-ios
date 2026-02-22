import Testing
import Foundation
@testable import Peach

/// Tests for frequency calculation, AudioError, and SineWaveNotePlayer initialization and reference pitch
@Suite("SineWaveNotePlayer Tests")
struct SineWaveNotePlayerTests {

    // MARK: - Frequency Calculation Tests

    @Test("Frequency calculation: Middle C (MIDI 60) at 0 cents should be ~261.626 Hz")
    func frequencyCalculation_MiddleC() throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 60, cents: 0.0)
        #expect(abs(frequency - 261.626) < 0.01)
    }

    @Test("Frequency calculation: A4 (MIDI 69) at 0 cents should be 440.0 Hz")
    func frequencyCalculation_A4() throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 69, cents: 0.0)
        #expect(abs(frequency - 440.0) < 0.001)
    }

    @Test("Frequency calculation: MIDI 60 at +50 cents should be ~268.9 Hz")
    func frequencyCalculation_HalfStep() throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 60, cents: 50.0)
        #expect(abs(frequency - 268.9) < 0.5)
    }

    @Test("Frequency calculation: 0.1 cent precision verification")
    func frequencyCalculation_SubCentPrecision() throws {
        let freq1 = try FrequencyCalculation.frequency(midiNote: 69, cents: 0.0)
        let freq2 = try FrequencyCalculation.frequency(midiNote: 69, cents: 0.1)

        #expect(freq1 != freq2)
        #expect(abs(freq2 - freq1) < 0.1)
    }

    @Test("Frequency calculation: Custom reference pitch (442 Hz)")
    func frequencyCalculation_CustomReferencePitch() throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 69, cents: 0.0, referencePitch: 442.0)
        #expect(abs(frequency - 442.0) < 0.001)
    }

    @Test("Frequency calculation: MIDI note 0 (C-1, ~8.18 Hz)")
    func frequencyCalculation_MIDI0() throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 0, cents: 0.0)
        #expect(abs(frequency - 8.18) < 0.1)
    }

    @Test("Frequency calculation: MIDI note 127 (G9, ~12543 Hz)")
    func frequencyCalculation_MIDI127() throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 127, cents: 0.0)
        #expect(abs(frequency - 12543.0) < 1.0)
    }

    @Test("Frequency calculation: Negative cent offset (-50 cents)")
    func frequencyCalculation_NegativeCents() throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 60, cents: -50.0)
        #expect(frequency < 261.626)
        #expect(abs(frequency - 254.2) < 1.0)
    }

    @Test("Frequency calculation: Extreme positive cent offset (+100 cents)")
    func frequencyCalculation_ExtremeCents() throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 60, cents: 100.0)
        let cSharp = try FrequencyCalculation.frequency(midiNote: 61, cents: 0.0)
        #expect(abs(frequency - cSharp) < 0.01)
    }

    // MARK: - AudioError Tests

    @Test("AudioError cases are properly defined")
    func audioError_CasesExist() {
        let error1: AudioError = .engineStartFailed("test")
        let error2: AudioError = .nodeAttachFailed("test")
        let error3: AudioError = .renderFailed("test")
        let error4: AudioError = .invalidFrequency("test")
        let error5: AudioError = .contextUnavailable

        #expect(error1 as Error is AudioError)
        #expect(error2 as Error is AudioError)
        #expect(error3 as Error is AudioError)
        #expect(error4 as Error is AudioError)
        #expect(error5 as Error is AudioError)
    }

    // MARK: - SineWaveNotePlayer Initialization

    @Test("SineWaveNotePlayer conforms to NotePlayer protocol")
    @MainActor
    func sineWaveNotePlayer_ProtocolConformance() throws {
        let player = try SineWaveNotePlayer()
        #expect(player is NotePlayer)
    }

    @Test("SineWaveNotePlayer initializes without throwing")
    @MainActor
    func sineWaveNotePlayer_InitializesSuccessfully() {
        #expect(throws: Never.self) {
            _ = try SineWaveNotePlayer()
        }
    }

    @Test("SineWaveNotePlayer can be created and destroyed cleanly")
    @MainActor
    func sineWaveNotePlayer_Lifecycle() throws {
        let player = try SineWaveNotePlayer()
        #expect(player is SineWaveNotePlayer)
    }

    // MARK: - Reference Pitch Configuration Tests (Story 2.2)

    @Test("Reference Pitch: Default (no parameter) uses A4=440Hz")
    func referencePitch_Default_440Hz() throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 69, cents: 0.0)
        #expect(abs(frequency - 440.0) < 0.001)
    }

    @Test("Reference Pitch: Baroque tuning (A4=442Hz)")
    func referencePitch_Baroque_442Hz() throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 69, cents: 0.0, referencePitch: 442.0)
        #expect(abs(frequency - 442.0) < 0.001)
    }

    @Test("Reference Pitch: Alternative tuning (A4=432Hz)")
    func referencePitch_Alternative_432Hz() throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 69, cents: 0.0, referencePitch: 432.0)
        #expect(abs(frequency - 432.0) < 0.001)
    }

    @Test("Reference Pitch: Historical tuning (A4=415Hz)")
    func referencePitch_Historical_415Hz() throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 69, cents: 0.0, referencePitch: 415.0)
        #expect(abs(frequency - 415.0) < 0.001)
    }

    @Test("Reference Pitch: Middle C at different reference pitches")
    func referencePitch_MiddleC_VariousTunings() throws {
        let c4_at_440 = try FrequencyCalculation.frequency(midiNote: 60, cents: 0.0, referencePitch: 440.0)
        #expect(abs(c4_at_440 - 261.626) < 0.01)

        let c4_at_442 = try FrequencyCalculation.frequency(midiNote: 60, cents: 0.0, referencePitch: 442.0)
        let expectedC4_442 = 261.626 * (442.0 / 440.0)
        #expect(abs(c4_at_442 - expectedC4_442) < 0.01)

        let c4_at_432 = try FrequencyCalculation.frequency(midiNote: 60, cents: 0.0, referencePitch: 432.0)
        let expectedC4_432 = 261.626 * (432.0 / 440.0)
        #expect(abs(c4_at_432 - expectedC4_432) < 0.01)
    }

    @Test("Reference Pitch: Cent offset with custom reference pitch (combined calculation)")
    func referencePitch_WithCentOffset() throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 69, cents: 50.0, referencePitch: 442.0)
        let expected = 442.0 * pow(2.0, 50.0 / 1200.0)
        #expect(abs(frequency - expected) < 0.01)
    }

    @Test("Reference Pitch: Fractional cent precision with custom reference pitch")
    func referencePitch_FractionalCent() throws {
        let freq1 = try FrequencyCalculation.frequency(midiNote: 69, cents: 0.0, referencePitch: 442.0)
        let freq2 = try FrequencyCalculation.frequency(midiNote: 69, cents: 0.1, referencePitch: 442.0)

        #expect(freq1 != freq2)
        #expect(abs(freq2 - freq1) < 0.1)
    }

    @Test("Reference Pitch: Negative cent offset with custom reference pitch")
    func referencePitch_NegativeCentOffset() throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 69, cents: -25.0, referencePitch: 432.0)
        let expected = 432.0 * pow(2.0, -25.0 / 1200.0)
        #expect(abs(frequency - expected) < 0.01)
    }

    // MARK: - Reference Pitch Validation Tests (HIGH-2 Fix)

    @Test("Reference Pitch: Too low (< 380 Hz) throws error")
    func referencePitch_TooLow_ThrowsError() async throws {
        #expect(throws: AudioError.self) {
            _ = try FrequencyCalculation.frequency(midiNote: 69, cents: 0.0, referencePitch: 350.0)
        }
    }

    @Test("Reference Pitch: Too high (> 500 Hz) throws error")
    func referencePitch_TooHigh_ThrowsError() async throws {
        #expect(throws: AudioError.self) {
            _ = try FrequencyCalculation.frequency(midiNote: 69, cents: 0.0, referencePitch: 550.0)
        }
    }

    @Test("Reference Pitch: Edge case - exactly 380 Hz (valid)")
    func referencePitch_EdgeLow_Valid() throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 69, cents: 0.0, referencePitch: 380.0)
        #expect(abs(frequency - 380.0) < 0.001)
    }

    @Test("Reference Pitch: Edge case - exactly 500 Hz (valid)")
    func referencePitch_EdgeHigh_Valid() throws {
        let frequency = try FrequencyCalculation.frequency(midiNote: 69, cents: 0.0, referencePitch: 500.0)
        #expect(abs(frequency - 500.0) < 0.001)
    }

    // MARK: - Stop Behavior Tests (Audio Click Fix)

    @Test("Stop when nothing is playing should not throw")
    @MainActor func stop_whenIdle_doesNotThrow() async throws {
        let player = try SineWaveNotePlayer()
        try await player.stop()
    }

    @Test("Stop called twice rapidly should be idempotent")
    @MainActor func stop_calledTwice_isIdempotent() async throws {
        let player = try SineWaveNotePlayer()
        try await player.stop()
        try await player.stop()
    }
}
