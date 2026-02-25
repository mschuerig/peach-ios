import Testing
import Foundation
@testable import Peach

@Suite("SoundFontNotePlayer Tests")
struct SoundFontNotePlayerTests {

    // MARK: - Protocol Conformance

    @Test("SoundFontNotePlayer conforms to NotePlayer protocol")
    func conformsToNotePlayer() async throws {
        let player = try SoundFontNotePlayer()
        #expect(player is NotePlayer)
    }

    @Test("Initializes successfully with bundled SF2")
    func initializesSuccessfully() async {
        #expect(throws: Never.self) {
            _ = try SoundFontNotePlayer()
        }
    }

    // MARK: - SF2 Loading

    @Test("Fails gracefully with missing SF2 file")
    func failsWithMissingSF2() async {
        #expect(throws: AudioError.self) {
            _ = try SoundFontNotePlayer(sf2Name: "NonExistent")
        }
    }

    // MARK: - Play/Stop Lifecycle

    @Test("Play returns a PlaybackHandle and convenience method completes without crash")
    func playReturnsHandle() async throws {
        let player = try SoundFontNotePlayer()
        let handle = try await player.play(frequency: 440.0, velocity: 63, amplitudeDB: 0.0)
        try await handle.stop()
    }

    @Test("Fixed-duration convenience method works without crash")
    func fixedDurationConvenienceMethod() async throws {
        let player = try SoundFontNotePlayer()
        try await player.play(frequency: 440.0, duration: 0.1, velocity: 63, amplitudeDB: 0.0)
    }

    @Test("PlaybackHandle stop is idempotent")
    func handleStopIdempotent() async throws {
        let player = try SoundFontNotePlayer()
        let handle = try await player.play(frequency: 440.0, velocity: 63, amplitudeDB: 0.0)
        try await handle.stop()
        try await handle.stop()
        try await handle.stop()
    }

    // MARK: - Pitch Bend Calculation

    @Test("Pitch bend for A4=440Hz at referencePitch=440 is center (8192)")
    func pitchBend_A4_center() async {
        let result = FrequencyCalculation.midiNoteAndCents(frequency: 440.0)
        let bendValue = SoundFontNotePlayer.pitchBendValue(forCents: result.cents)
        #expect(bendValue == 8192)
    }

    @Test("Pitch bend for +50 cents is 10240")
    func pitchBend_plus50cents() async {
        // +50 cents: 8192 + Int(50 * 8192.0 / 200.0) = 8192 + 2048 = 10240
        let bendValue = SoundFontNotePlayer.pitchBendValue(forCents: 50.0)
        #expect(bendValue == 10240)
    }

    @Test("Pitch bend for -50 cents is 6144")
    func pitchBend_minus50cents() async {
        // -50 cents: 8192 + Int(-50 * 8192.0 / 200.0) = 8192 - 2048 = 6144
        let bendValue = SoundFontNotePlayer.pitchBendValue(forCents: -50.0)
        #expect(bendValue == 6144)
    }

    @Test("Pitch bend for 0 cents is center (8192)")
    func pitchBend_zeroCents() async {
        let bendValue = SoundFontNotePlayer.pitchBendValue(forCents: 0.0)
        #expect(bendValue == 8192)
    }

    @Test("Pitch bend clamps to valid MIDI range 0...16383")
    func pitchBend_clamped() async {
        // Extreme positive — should clamp to 16383
        let highBend = SoundFontNotePlayer.pitchBendValue(forCents: 500.0)
        #expect(highBend <= 16383)
        #expect(highBend >= 0)

        // Extreme negative — should clamp to 0
        let lowBend = SoundFontNotePlayer.pitchBendValue(forCents: -500.0)
        #expect(lowBend >= 0)
        #expect(lowBend <= 16383)
    }

    // MARK: - Velocity Validation

    @Test("Velocity 0 is rejected with invalidVelocity error")
    func velocity0_rejected() async throws {
        let player = try SoundFontNotePlayer()
        let error = await #expect(throws: AudioError.self) {
            try await player.play(frequency: 440.0, duration: 0.1, velocity: 0, amplitudeDB: 0.0)
        }
        guard case .invalidVelocity = error else {
            Issue.record("Expected invalidVelocity but got \(String(describing: error))")
            return
        }
    }

    @Test("Velocity 128 is rejected with invalidVelocity error")
    func velocity128_rejected() async throws {
        let player = try SoundFontNotePlayer()
        let error = await #expect(throws: AudioError.self) {
            try await player.play(frequency: 440.0, duration: 0.1, velocity: 128, amplitudeDB: 0.0)
        }
        guard case .invalidVelocity = error else {
            Issue.record("Expected invalidVelocity but got \(String(describing: error))")
            return
        }
    }

    @Test("Velocity 127 is accepted")
    func velocity127_accepted() async throws {
        let player = try SoundFontNotePlayer()
        try await player.play(frequency: 440.0, duration: 0.1, velocity: 127, amplitudeDB: 0.0)
    }

    @Test("Velocity within range plays successfully")
    func velocityWithinRange_plays() async throws {
        let player = try SoundFontNotePlayer()
        try await player.play(frequency: 440.0, duration: 0.1, velocity: 63, amplitudeDB: 0.0)
    }

    // MARK: - Amplitude Validation

    @Test("amplitudeDB 0.0 (default) plays successfully")
    func amplitudeDB_default_playsSuccessfully() async throws {
        let player = try SoundFontNotePlayer()
        try await player.play(frequency: 440.0, duration: 0.1, velocity: 63, amplitudeDB: 0.0)
    }

    @Test("amplitudeDB positive offset accepted")
    func amplitudeDB_positiveOffset_accepted() async throws {
        let player = try SoundFontNotePlayer()
        try await player.play(frequency: 440.0, duration: 0.1, velocity: 63, amplitudeDB: 2.0)
    }

    @Test("amplitudeDB negative offset accepted")
    func amplitudeDB_negativeOffset_accepted() async throws {
        let player = try SoundFontNotePlayer()
        try await player.play(frequency: 440.0, duration: 0.1, velocity: 63, amplitudeDB: -2.0)
    }

    @Test("amplitudeDB at minimum boundary (-90.0) accepted")
    func amplitudeDB_atMinimumBoundary_accepted() async throws {
        let player = try SoundFontNotePlayer()
        try await player.play(frequency: 440.0, duration: 0.1, velocity: 63, amplitudeDB: -90.0)
    }

    @Test("amplitudeDB at maximum boundary (12.0) accepted")
    func amplitudeDB_atMaximumBoundary_accepted() async throws {
        let player = try SoundFontNotePlayer()
        try await player.play(frequency: 440.0, duration: 0.1, velocity: 63, amplitudeDB: 12.0)
    }

    @Test("amplitudeDB below minimum (-91.0) rejected with invalidAmplitude")
    func amplitudeDB_belowMinimum_rejected() async throws {
        let player = try SoundFontNotePlayer()
        let error = await #expect(throws: AudioError.self) {
            try await player.play(frequency: 440.0, duration: 0.1, velocity: 63, amplitudeDB: -91.0)
        }
        guard case .invalidAmplitude = error else {
            Issue.record("Expected invalidAmplitude but got \(String(describing: error))")
            return
        }
    }

    @Test("amplitudeDB above maximum (13.0) rejected with invalidAmplitude")
    func amplitudeDB_aboveMaximum_rejected() async throws {
        let player = try SoundFontNotePlayer()
        let error = await #expect(throws: AudioError.self) {
            try await player.play(frequency: 440.0, duration: 0.1, velocity: 63, amplitudeDB: 13.0)
        }
        guard case .invalidAmplitude = error else {
            Issue.record("Expected invalidAmplitude but got \(String(describing: error))")
            return
        }
    }

    // MARK: - Preset Switching

    @Test("loadPreset to program 0 (piano) succeeds")
    func loadPresetPiano() async throws {
        let player = try SoundFontNotePlayer()
        try await player.loadPreset(program: 0)
    }

    @Test("loadPreset to program 42 (cello) succeeds")
    func loadPresetCello() async throws {
        let player = try SoundFontNotePlayer()
        // Player starts with program 42, so load something else first, then back
        try await player.loadPreset(program: 0)
        try await player.loadPreset(program: 42)
    }

    @Test("loadPreset with bank parameter loads bank variant")
    func loadPresetBankVariant() async throws {
        let player = try SoundFontNotePlayer()
        try await player.loadPreset(program: 4, bank: 8) // Chorused Tine EP
    }

    @Test("Loading same preset twice is a no-op (no error)")
    func loadSamePresetTwice() async throws {
        let player = try SoundFontNotePlayer()
        try await player.loadPreset(program: 0)
        try await player.loadPreset(program: 0) // should be skipped, no error
    }

    @Test("Play works after preset switch")
    func playAfterPresetSwitch() async throws {
        let player = try SoundFontNotePlayer()
        try await player.loadPreset(program: 0) // switch to piano
        try await player.play(frequency: 440.0, duration: 0.1, velocity: 63, amplitudeDB: 0.0)
    }

    @Test("loadPreset throws for out-of-range program")
    func loadPresetInvalidProgram() async throws {
        let player = try SoundFontNotePlayer()
        await #expect(throws: AudioError.self) {
            try await player.loadPreset(program: 999)
        }
    }

    @Test("loadPreset throws for negative program")
    func loadPresetNegativeProgram() async throws {
        let player = try SoundFontNotePlayer()
        await #expect(throws: AudioError.self) {
            try await player.loadPreset(program: -1)
        }
    }

    @Test("loadPreset throws for out-of-range bank")
    func loadPresetInvalidBank() async throws {
        let player = try SoundFontNotePlayer()
        await #expect(throws: AudioError.self) {
            try await player.loadPreset(program: 0, bank: 200)
        }
    }

    // MARK: - SF2 Tag Parsing

    @Test("parseSF2Tag parses valid sf2 tag correctly")
    func parseSF2Tag_validTag() async {
        let result = SoundFontNotePlayer.parseSF2Tag(from: "sf2:0:42")
        #expect(result?.bank == 0)
        #expect(result?.program == 42)
    }

    @Test("parseSF2Tag parses bank 8 program 80 (Sine Wave)")
    func parseSF2Tag_sineWavePreset() async {
        let result = SoundFontNotePlayer.parseSF2Tag(from: "sf2:8:80")
        #expect(result?.bank == 8)
        #expect(result?.program == 80)
    }

    @Test("parseSF2Tag returns nil for 'sine' tag")
    func parseSF2Tag_sineTag() async {
        let result = SoundFontNotePlayer.parseSF2Tag(from: "sine")
        #expect(result == nil)
    }

    @Test("parseSF2Tag returns nil for legacy 'cello' tag")
    func parseSF2Tag_celloTag() async {
        let result = SoundFontNotePlayer.parseSF2Tag(from: "cello")
        #expect(result == nil)
    }

    @Test("parseSF2Tag returns nil for malformed tags")
    func parseSF2Tag_malformedTags() async {
        #expect(SoundFontNotePlayer.parseSF2Tag(from: "sf2:abc") == nil)
        #expect(SoundFontNotePlayer.parseSF2Tag(from: "sf2:") == nil)
        #expect(SoundFontNotePlayer.parseSF2Tag(from: "") == nil)
        #expect(SoundFontNotePlayer.parseSF2Tag(from: "unknown") == nil)
    }

    // MARK: - Preset Selection from UserDefaults

    @Test("play reads UserDefaults soundSource and uses the selected preset")
    func playReadsSoundSource() async throws {
        defer { UserDefaults.standard.removeObject(forKey: SettingsKeys.soundSource) }
        let player = try SoundFontNotePlayer()
        UserDefaults.standard.set("sf2:0:0", forKey: SettingsKeys.soundSource)
        try await player.play(frequency: 440.0, duration: 0.1, velocity: 63, amplitudeDB: 0.0)
    }

    @Test("play falls back to default preset for unparseable soundSource")
    func playFallsBackForUnparseableSource() async throws {
        defer { UserDefaults.standard.removeObject(forKey: SettingsKeys.soundSource) }
        let player = try SoundFontNotePlayer()
        UserDefaults.standard.set("garbage", forKey: SettingsKeys.soundSource)
        try await player.play(frequency: 440.0, duration: 0.1, velocity: 63, amplitudeDB: 0.0)
    }

    @Test("play falls back to default preset when loadPreset fails for invalid program")
    func playFallsBackOnLoadFailure() async throws {
        defer { UserDefaults.standard.removeObject(forKey: SettingsKeys.soundSource) }
        let player = try SoundFontNotePlayer()
        UserDefaults.standard.set("sf2:0:999", forKey: SettingsKeys.soundSource)
        try await player.play(frequency: 440.0, duration: 0.1, velocity: 63, amplitudeDB: 0.0)
    }

    @Test("play falls back to default preset for legacy 'cello' tag")
    func playFallsBackForLegacyCelloTag() async throws {
        defer { UserDefaults.standard.removeObject(forKey: SettingsKeys.soundSource) }
        let player = try SoundFontNotePlayer()
        UserDefaults.standard.set("cello", forKey: SettingsKeys.soundSource)
        try await player.play(frequency: 440.0, duration: 0.1, velocity: 63, amplitudeDB: 0.0)
    }
}
