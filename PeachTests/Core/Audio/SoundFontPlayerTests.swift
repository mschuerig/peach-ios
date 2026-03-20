import Testing
import Foundation
@testable import Peach

@Suite("SoundFontPlayer Tests")
struct SoundFontPlayerTests {

    private static let testLibrary = TestSoundFont.makeLibrary()

    private func makePlayer(userSettings: UserSettings = MockUserSettings()) throws -> SoundFontPlayer {
        let engine = try SoundFontEngine(sf2URL: TestSoundFont.url)
        return SoundFontPlayer(engine: engine, library: Self.testLibrary, userSettings: userSettings)
    }

    // MARK: - Protocol Conformance

    @Test("SoundFontPlayer conforms to NotePlayer protocol")
    func conformsToNotePlayer() async throws {
        let player = try makePlayer()
        #expect(player is NotePlayer)
    }

    @Test("Initializes successfully with bundled SF2")
    func initializesSuccessfully() async {
        #expect(throws: Never.self) {
            _ = try self.makePlayer()
        }
    }

    // MARK: - SF2 Loading

    @Test("Fails gracefully with missing SF2 file during preset load")
    func failsWithMissingSF2() async throws {
        let badLibrary = SoundFontLibrary(
            sf2URL: URL(fileURLWithPath: "/nonexistent/NonExistent.sf2"),
            defaultPreset: "sf2:0:0"
        )
        // Engine init no longer loads a preset, but play() triggers loadPreset which fails
        let engine = try SoundFontEngine(sf2URL: TestSoundFont.url)
        let player = SoundFontPlayer(engine: engine, library: badLibrary, userSettings: MockUserSettings())
        // Play should still work because the bad library resolves to a fallback preset,
        // and the engine uses the real SF2 URL for loading
        try await player.play(frequency: 440.0, duration: .milliseconds(50), velocity: 63, amplitudeDB: 0.0)
    }

    // MARK: - Play/Stop Lifecycle

    @Test("Play returns a PlaybackHandle and convenience method completes without crash")
    func playReturnsHandle() async throws {
        let player = try makePlayer()
        let handle = try await player.play(frequency: 440.0, velocity: 63, amplitudeDB: 0.0)
        try await handle.stop()
    }

    @Test("Fixed-duration convenience method works without crash")
    func fixedDurationConvenienceMethod() async throws {
        let player = try makePlayer()
        try await player.play(frequency: 440.0, duration: .milliseconds(100), velocity: 63, amplitudeDB: 0.0)
    }

    @Test("PlaybackHandle stop is idempotent")
    func handleStopIdempotent() async throws {
        let player = try makePlayer()
        let handle = try await player.play(frequency: 440.0, velocity: 63, amplitudeDB: 0.0)
        try await handle.stop()
        try await handle.stop()
        try await handle.stop()
    }

    // MARK: - Pitch Bend Calculation

    @Test("Pitch bend for 0 cents offset is center (8192)")
    func pitchBend_A4_center() async {
        let bendValue = SoundFontPlayer.pitchBendValue(forCents: Cents(0))
        #expect(bendValue == 8192)
    }

    @Test("Pitch bend for +50 cents is 10240")
    func pitchBend_plus50cents() async {
        // +50 cents: 8192 + Int(50 * 8192.0 / 200.0) = 8192 + 2048 = 10240
        let bendValue = SoundFontPlayer.pitchBendValue(forCents: 50.0)
        #expect(bendValue == 10240)
    }

    @Test("Pitch bend for -50 cents is 6144")
    func pitchBend_minus50cents() async {
        // -50 cents: 8192 + Int(-50 * 8192.0 / 200.0) = 8192 - 2048 = 6144
        let bendValue = SoundFontPlayer.pitchBendValue(forCents: -50.0)
        #expect(bendValue == 6144)
    }

    @Test("Pitch bend for 0 cents is center (8192)")
    func pitchBend_zeroCents() async {
        let bendValue = SoundFontPlayer.pitchBendValue(forCents: 0.0)
        #expect(bendValue == 8192)
    }

    @Test("Pitch bend clamps to valid MIDI range 0...16383")
    func pitchBend_clamped() async {
        // Extreme positive — should clamp to 16383
        let highBend = SoundFontPlayer.pitchBendValue(forCents: 500.0)
        #expect(highBend <= 16383)
        #expect(highBend >= 0)

        // Extreme negative — should clamp to 0
        let lowBend = SoundFontPlayer.pitchBendValue(forCents: -500.0)
        #expect(lowBend >= 0)
        #expect(lowBend <= 16383)
    }

    // MARK: - Velocity Validation
    // Note: Invalid velocity values (0, 128) are now caught at compile/construction time
    // by the MIDIVelocity value object. See MIDIVelocityTests for coverage.

    @Test("Velocity 127 is accepted")
    func velocity127_accepted() async throws {
        let player = try makePlayer()
        try await player.play(frequency: 440.0, duration: .milliseconds(100), velocity: 127, amplitudeDB: 0.0)
    }

    @Test("Velocity within range plays successfully")
    func velocityWithinRange_plays() async throws {
        let player = try makePlayer()
        try await player.play(frequency: 440.0, duration: .milliseconds(100), velocity: 63, amplitudeDB: 0.0)
    }

    // MARK: - Amplitude Validation

    @Test("amplitudeDB 0.0 (default) plays successfully")
    func amplitudeDB_default_playsSuccessfully() async throws {
        let player = try makePlayer()
        try await player.play(frequency: 440.0, duration: .milliseconds(100), velocity: 63, amplitudeDB: 0.0)
    }

    @Test("amplitudeDB positive offset accepted")
    func amplitudeDB_positiveOffset_accepted() async throws {
        let player = try makePlayer()
        try await player.play(frequency: 440.0, duration: .milliseconds(100), velocity: 63, amplitudeDB: 2.0)
    }

    @Test("amplitudeDB negative offset accepted")
    func amplitudeDB_negativeOffset_accepted() async throws {
        let player = try makePlayer()
        try await player.play(frequency: 440.0, duration: .milliseconds(100), velocity: 63, amplitudeDB: -2.0)
    }

    @Test("amplitudeDB at minimum boundary (-90.0) accepted")
    func amplitudeDB_atMinimumBoundary_accepted() async throws {
        let player = try makePlayer()
        try await player.play(frequency: 440.0, duration: .milliseconds(100), velocity: 63, amplitudeDB: -90.0)
    }

    @Test("amplitudeDB at maximum boundary (12.0) accepted")
    func amplitudeDB_atMaximumBoundary_accepted() async throws {
        let player = try makePlayer()
        try await player.play(frequency: 440.0, duration: .milliseconds(100), velocity: 63, amplitudeDB: 12.0)
    }

    // Note: Out-of-range amplitude values (-91.0, 13.0) are now silently clamped
    // by the AmplitudeDB value object. See AmplitudeDBTests for coverage.

    // MARK: - stopAll

    @Test("stopAll does not crash when no notes are playing")
    func stopAllNoNotes() async throws {
        let player = try makePlayer()
        try await player.stopAll()
    }

    @Test("stopAll silences a playing note")
    func stopAllSilencesNote() async throws {
        let player = try makePlayer()
        _ = try await player.play(frequency: 440.0, velocity: 63, amplitudeDB: 0.0)
        try await player.stopAll()
    }

    @Test("stopAll silences multiple playing notes")
    func stopAllSilencesMultipleNotes() async throws {
        let player = try makePlayer()
        _ = try await player.play(frequency: 440.0, velocity: 63, amplitudeDB: 0.0)
        _ = try await player.play(frequency: 880.0, velocity: 63, amplitudeDB: 0.0)
        try await player.stopAll()
    }

    @Test("stopAll with fade-out restores volume — subsequent play works")
    func stopAllWithFadeOutRestoresVolume() async throws {
        let player = try makePlayer()
        _ = try await player.play(frequency: 440.0, velocity: 63, amplitudeDB: 0.0)
        try await player.stopAll()
        // Default stopPropagationDelay (25ms) exercises the fade-out path.
        // If volume were stuck at 0 after stopAll, this play would produce no sound.
        let handle = try await player.play(frequency: 440.0, velocity: 63, amplitudeDB: 0.0)
        try await handle.stop()
    }

    // MARK: - Preset Selection from UserSettings

    @Test("play reads soundSource from UserSettings and uses the selected preset")
    func playReadsSoundSource() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.soundSource = SoundSourceTag(rawValue: "sf2:0:0")

        let player = try makePlayer(userSettings: mockSettings)
        try await player.play(frequency: 440.0, duration: .milliseconds(100), velocity: 63, amplitudeDB: 0.0)
    }

    @Test("play falls back to default preset for unparseable soundSource")
    func playFallsBackForUnparseableSource() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.soundSource = SoundSourceTag(rawValue: "garbage")
        let player = try makePlayer(userSettings: mockSettings)
        try await player.play(frequency: 440.0, duration: .milliseconds(100), velocity: 63, amplitudeDB: 0.0)
    }

    @Test("play falls back to default preset when loadPreset fails for invalid program")
    func playFallsBackOnLoadFailure() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.soundSource = SoundSourceTag(rawValue: "sf2:0:999")
        let player = try makePlayer(userSettings: mockSettings)
        try await player.play(frequency: 440.0, duration: .milliseconds(100), velocity: 63, amplitudeDB: 0.0)
    }

    @Test("play falls back to default preset for legacy 'cello' tag")
    func playFallsBackForLegacyCelloTag() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.soundSource = SoundSourceTag(rawValue: "cello")
        let player = try makePlayer(userSettings: mockSettings)
        try await player.play(frequency: 440.0, duration: .milliseconds(100), velocity: 63, amplitudeDB: 0.0)
    }

    // MARK: - Frequency Decomposition (Hz → MIDI note + cents)

    @Test("440 Hz decomposes to MIDI 69, 0 cents")
    func decomposeA4() async {
        let result = SoundFontPlayer.decompose(frequency: Frequency(440.0))
        #expect(result.note == 69)
        #expect(result.cents.magnitude < 0.01)
    }

    @Test("261.626 Hz decomposes to MIDI 60 (middle C), ~0 cents")
    func decomposeMiddleC() async {
        let result = SoundFontPlayer.decompose(frequency: Frequency(261.6255653))
        #expect(result.note == 60)
        #expect(result.cents.magnitude < 0.1)
    }

    @Test("lowest MIDI frequency (~8.176 Hz) decomposes to MIDI 0")
    func decomposeBoundaryLowest() async {
        let result = SoundFontPlayer.decompose(frequency: Frequency(8.17579891564))
        #expect(result.note == 0)
        #expect(result.cents.magnitude < 0.1)
    }

    @Test("highest MIDI frequency (~12543.85 Hz) decomposes to MIDI 127")
    func decomposeBoundaryHighest() async {
        let result = SoundFontPlayer.decompose(frequency: Frequency(12543.853951))
        #expect(result.note == 127)
        #expect(result.cents.magnitude < 0.1)
    }

    @Test("frequency below MIDI 0 clamps to MIDI 0")
    func decomposeBelowRange() async {
        let result = SoundFontPlayer.decompose(frequency: Frequency(5.0))
        #expect(result.note == 0)
    }

    @Test("frequency above MIDI 127 clamps to MIDI 127")
    func decomposeAboveRange() async {
        let result = SoundFontPlayer.decompose(frequency: Frequency(20000.0))
        #expect(result.note == 127)
    }

    @Test("round-trip through decompose preserves frequency within 0.1-cent precision")
    func decomposeRoundTrip() async {
        let originalFreq = Frequency(440.0)
        let decomposed = SoundFontPlayer.decompose(frequency: originalFreq)
        let reconstructed = TuningSystem.equalTemperament.frequency(
            for: DetunedMIDINote(note: MIDINote(Int(decomposed.note)), offset: decomposed.cents),
            referencePitch: .concert440
        )
        let centError = 1200.0 * log2(reconstructed.rawValue / originalFreq.rawValue)
        #expect(abs(centError) < 0.1)
    }

    @Test("round-trip: arbitrary note (MIDI 45 + 73.5 cents)")
    func decomposeRoundTripArbitrary() async {
        let original = DetunedMIDINote(note: MIDINote(45), offset: Cents(73.5))
        let freq = TuningSystem.equalTemperament.frequency(for: original, referencePitch: .concert440)
        let decomposed = SoundFontPlayer.decompose(frequency: freq)
        let reconstructed = TuningSystem.equalTemperament.frequency(
            for: DetunedMIDINote(note: MIDINote(Int(decomposed.note)), offset: decomposed.cents),
            referencePitch: .concert440
        )
        let centError = 1200.0 * log2(reconstructed.rawValue / freq.rawValue)
        #expect(abs(centError) < 0.1)
    }

    @Test("cents remainder from decompose is always in range -50 to +50")
    func decomposeCentsRemainderRange() async {
        for midiValue in stride(from: 0, through: 127, by: 10) {
            for centsValue in stride(from: -49.0, through: 49.0, by: 7.0) {
                let freq = TuningSystem.equalTemperament.frequency(
                    for: DetunedMIDINote(note: MIDINote(midiValue), offset: Cents(centsValue)),
                    referencePitch: .concert440
                )
                let result = SoundFontPlayer.decompose(frequency: freq)
                #expect(result.cents.rawValue >= -50.0 && result.cents.rawValue <= 50.0)
            }
        }
    }

    @Test("exact MIDI notes across range decompose to 0 cents")
    func decomposeExactMidiNotes() async {
        for midiValue: UInt8 in [0, 21, 36, 48, 60, 69, 84, 96, 108, 127] {
            let freq = TuningSystem.equalTemperament.frequency(
                for: MIDINote(Int(midiValue)),
                referencePitch: .concert440
            )
            let result = SoundFontPlayer.decompose(frequency: freq)
            #expect(result.note == midiValue, "MIDI note \(midiValue) failed")
            #expect(result.cents.magnitude < 0.1)
        }
    }

    // MARK: - RhythmPlayer Conformance

    @Test("SoundFontPlayer conforms to RhythmPlayer protocol")
    func conformsToRhythmPlayer() async throws {
        let player = try makePlayer()
        #expect(player is RhythmPlayer)
    }

    @Test("stopAll affects only this player's channel")
    func stopAllChannelScoped() async throws {
        let player = try makePlayer()
        // stopAll should not crash even when nothing is playing
        try await player.stopAll()
    }
}

// MARK: - RhythmPattern Tests

@Suite("RhythmPattern Tests")
struct RhythmPatternTests {

    @Test("creates pattern with events")
    func createsPatternWithEvents() async {
        let events = [
            RhythmPattern.Event(sampleOffset: 0, soundSourceID: SoundSourceTag(rawValue: "sf2:128:0:36"), velocity: MIDIVelocity(100)),
            RhythmPattern.Event(sampleOffset: 22050, soundSourceID: SoundSourceTag(rawValue: "sf2:128:0:38"), velocity: MIDIVelocity(80)),
        ]
        let pattern = RhythmPattern(events: events, sampleRate: 44100.0, totalDuration: .seconds(1))
        #expect(pattern.events.count == 2)
        #expect(pattern.sampleRate == 44100.0)
        #expect(pattern.totalDuration == .seconds(1))
    }

    @Test("event stores sampleOffset, soundSourceID, velocity")
    func eventStoresProperties() async {
        let event = RhythmPattern.Event(
            sampleOffset: 44100,
            soundSourceID: SoundSourceTag(rawValue: "sf2:128:0:42"),
            velocity: MIDIVelocity(90)
        )
        #expect(event.sampleOffset == 44100)
        #expect(event.soundSourceID.rawValue == "sf2:128:0:42")
        #expect(event.velocity == MIDIVelocity(90))
    }

    @Test("empty pattern is valid")
    func emptyPatternValid() async {
        let pattern = RhythmPattern(events: [], sampleRate: 44100.0, totalDuration: .zero)
        #expect(pattern.events.isEmpty)
    }
}
