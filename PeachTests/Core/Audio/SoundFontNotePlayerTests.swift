import Testing
import Foundation
@testable import Peach

@Suite("SoundFontNotePlayer Tests")
struct SoundFontNotePlayerTests {

    // MARK: - Protocol Conformance

    @Test("SoundFontNotePlayer conforms to NotePlayer protocol")
    @MainActor func conformsToNotePlayer() async throws {
        let player = try SoundFontNotePlayer()
        #expect(player is NotePlayer)
    }

    @Test("Initializes successfully with bundled SF2")
    @MainActor func initializesSuccessfully() async {
        #expect(throws: Never.self) {
            _ = try SoundFontNotePlayer()
        }
    }

    // MARK: - SF2 Loading

    @Test("Fails gracefully with missing SF2 file")
    @MainActor func failsWithMissingSF2() async {
        #expect(throws: AudioError.self) {
            _ = try SoundFontNotePlayer(sf2Name: "NonExistent")
        }
    }

    // MARK: - Play/Stop Lifecycle

    @Test("Play and stop lifecycle works without crash")
    @MainActor func playStopLifecycle() async throws {
        let player = try SoundFontNotePlayer()
        try await player.play(frequency: 440.0, duration: 0.1, amplitude: 0.5)
        try await player.stop()
    }

    @Test("Stop when nothing is playing does not throw")
    @MainActor func stopWhenIdle() async throws {
        let player = try SoundFontNotePlayer()
        try await player.stop()
    }

    @Test("Stop called twice rapidly is idempotent")
    @MainActor func stopTwice() async throws {
        let player = try SoundFontNotePlayer()
        try await player.stop()
        try await player.stop()
    }

    // MARK: - Pitch Bend Calculation

    @Test("Pitch bend for A4=440Hz at referencePitch=440 is center (8192)")
    @MainActor func pitchBend_A4_center() async {
        let result = FrequencyCalculation.midiNoteAndCents(frequency: 440.0)
        let bendValue = SoundFontNotePlayer.pitchBendValue(forCents: result.cents)
        #expect(bendValue == 8192)
    }

    @Test("Pitch bend for +50 cents is 10240")
    @MainActor func pitchBend_plus50cents() async {
        // +50 cents: 8192 + Int(50 * 8192.0 / 200.0) = 8192 + 2048 = 10240
        let bendValue = SoundFontNotePlayer.pitchBendValue(forCents: 50.0)
        #expect(bendValue == 10240)
    }

    @Test("Pitch bend for -50 cents is 6144")
    @MainActor func pitchBend_minus50cents() async {
        // -50 cents: 8192 + Int(-50 * 8192.0 / 200.0) = 8192 - 2048 = 6144
        let bendValue = SoundFontNotePlayer.pitchBendValue(forCents: -50.0)
        #expect(bendValue == 6144)
    }

    @Test("Pitch bend for 0 cents is center (8192)")
    @MainActor func pitchBend_zeroCents() async {
        let bendValue = SoundFontNotePlayer.pitchBendValue(forCents: 0.0)
        #expect(bendValue == 8192)
    }

    @Test("Pitch bend clamps to valid MIDI range 0...16383")
    @MainActor func pitchBend_clamped() async {
        // Extreme positive — should clamp to 16383
        let highBend = SoundFontNotePlayer.pitchBendValue(forCents: 500.0)
        #expect(highBend <= 16383)
        #expect(highBend >= 0)

        // Extreme negative — should clamp to 0
        let lowBend = SoundFontNotePlayer.pitchBendValue(forCents: -500.0)
        #expect(lowBend >= 0)
        #expect(lowBend <= 16383)
    }

    // MARK: - Amplitude to Velocity

    @Test("Amplitude 0.5 maps to velocity 63")
    @MainActor func amplitude_half() async {
        let velocity = SoundFontNotePlayer.midiVelocity(forAmplitude: 0.5)
        #expect(velocity == 63)
    }

    @Test("Amplitude 1.0 maps to velocity 127")
    @MainActor func amplitude_full() async {
        let velocity = SoundFontNotePlayer.midiVelocity(forAmplitude: 1.0)
        #expect(velocity == 127)
    }

    @Test("Amplitude 0.0 maps to velocity 1 (floor at 1, not 0)")
    @MainActor func amplitude_zero_floorsAt1() async {
        let velocity = SoundFontNotePlayer.midiVelocity(forAmplitude: 0.0)
        #expect(velocity == 1)
    }

    // MARK: - Preset Switching

    @Test("loadPreset to program 0 (piano) succeeds")
    @MainActor func loadPresetPiano() async throws {
        let player = try SoundFontNotePlayer()
        try await player.loadPreset(program: 0)
    }

    @Test("loadPreset to program 42 (cello) succeeds")
    @MainActor func loadPresetCello() async throws {
        let player = try SoundFontNotePlayer()
        // Player starts with program 42, so load something else first, then back
        try await player.loadPreset(program: 0)
        try await player.loadPreset(program: 42)
    }

    @Test("loadPreset with bank parameter loads bank variant")
    @MainActor func loadPresetBankVariant() async throws {
        let player = try SoundFontNotePlayer()
        try await player.loadPreset(program: 4, bank: 8) // Chorused Tine EP
    }

    @Test("Loading same preset twice is a no-op (no error)")
    @MainActor func loadSamePresetTwice() async throws {
        let player = try SoundFontNotePlayer()
        try await player.loadPreset(program: 0)
        try await player.loadPreset(program: 0) // should be skipped, no error
    }

    @Test("Play works after preset switch")
    @MainActor func playAfterPresetSwitch() async throws {
        let player = try SoundFontNotePlayer()
        try await player.loadPreset(program: 0) // switch to piano
        try await player.play(frequency: 440.0, duration: 0.1, amplitude: 0.5)
    }

    @Test("loadPreset throws for out-of-range program")
    @MainActor func loadPresetInvalidProgram() async throws {
        let player = try SoundFontNotePlayer()
        await #expect(throws: AudioError.self) {
            try await player.loadPreset(program: 999)
        }
    }

    @Test("loadPreset throws for negative program")
    @MainActor func loadPresetNegativeProgram() async throws {
        let player = try SoundFontNotePlayer()
        await #expect(throws: AudioError.self) {
            try await player.loadPreset(program: -1)
        }
    }

    @Test("loadPreset throws for out-of-range bank")
    @MainActor func loadPresetInvalidBank() async throws {
        let player = try SoundFontNotePlayer()
        await #expect(throws: AudioError.self) {
            try await player.loadPreset(program: 0, bank: 200)
        }
    }
}
