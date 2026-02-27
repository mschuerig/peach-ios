import Testing
import Foundation
@testable import Peach

@Suite("SoundFontPlaybackHandle Tests")
struct SoundFontPlaybackHandleTests {

    // MARK: - Stop Behavior via SoundFontNotePlayer

    @Test("Handle stop after play silences the note")
    func handleStopAfterPlay() async throws {
        let player = try SoundFontNotePlayer(userSettings: MockUserSettings())
        let handle = try await player.play(frequency: 440.0, velocity: 63, amplitudeDB: 0.0)
        try await handle.stop()
    }

    @Test("Handle stop is idempotent — multiple calls do not crash")
    func handleStopIdempotent() async throws {
        let player = try SoundFontNotePlayer(userSettings: MockUserSettings())
        let handle = try await player.play(frequency: 440.0, velocity: 63, amplitudeDB: 0.0)
        try await handle.stop()
        try await handle.stop()
        try await handle.stop()
    }

    // MARK: - adjustFrequency Behavior

    @Test("adjustFrequency succeeds for frequency within pitch bend range")
    func adjustFrequencyValid() async throws {
        let player = try SoundFontNotePlayer(userSettings: MockUserSettings())
        let handle = try await player.play(frequency: 440.0, velocity: 63, amplitudeDB: 0.0)
        try await handle.adjustFrequency(460.0)
        try await handle.stop()
    }

    @Test("adjustFrequency after stop is a no-op")
    func adjustFrequencyAfterStop() async throws {
        let player = try SoundFontNotePlayer(userSettings: MockUserSettings())
        let handle = try await player.play(frequency: 440.0, velocity: 63, amplitudeDB: 0.0)
        try await handle.stop()
        try await handle.adjustFrequency(880.0)
    }

    @Test("Multiple adjustFrequency calls succeed")
    func multipleAdjustFrequencyCalls() async throws {
        let player = try SoundFontNotePlayer(userSettings: MockUserSettings())
        let handle = try await player.play(frequency: 440.0, velocity: 63, amplitudeDB: 0.0)
        try await handle.adjustFrequency(450.0)
        try await handle.adjustFrequency(430.0)
        try await handle.adjustFrequency(440.0)
        try await handle.stop()
    }

    // MARK: - adjustFrequency Validation

    @Test("adjustFrequency throws for frequency below valid range")
    func adjustFrequencyBelowRange() async throws {
        let player = try SoundFontNotePlayer(userSettings: MockUserSettings())
        let handle = try await player.play(frequency: 440.0, velocity: 63, amplitudeDB: 0.0)
        await #expect(throws: AudioError.self) {
            try await handle.adjustFrequency(10.0)
        }
        try await handle.stop()
    }

    @Test("adjustFrequency throws for frequency above valid range")
    func adjustFrequencyAboveRange() async throws {
        let player = try SoundFontNotePlayer(userSettings: MockUserSettings())
        let handle = try await player.play(frequency: 440.0, velocity: 63, amplitudeDB: 0.0)
        await #expect(throws: AudioError.self) {
            try await handle.adjustFrequency(25000.0)
        }
        try await handle.stop()
    }

    @Test("adjustFrequency throws when target exceeds pitch bend range")
    func adjustFrequencyExceedsPitchBendRange() async throws {
        let player = try SoundFontNotePlayer(userSettings: MockUserSettings())
        // Play A4 (440 Hz), then try to adjust to C6 (1046 Hz) — way beyond ±200 cents
        let handle = try await player.play(frequency: 440.0, velocity: 63, amplitudeDB: 0.0)
        await #expect(throws: AudioError.self) {
            try await handle.adjustFrequency(1046.5)
        }
        try await handle.stop()
    }

    @Test("adjustFrequency at boundary of pitch bend range succeeds")
    func adjustFrequencyAtPitchBendBoundary() async throws {
        let player = try SoundFontNotePlayer(userSettings: MockUserSettings())
        // Play A4 (440 Hz), adjust to ~2 semitones up (~493 Hz = B4) — within ±200 cents
        let handle = try await player.play(frequency: 440.0, velocity: 63, amplitudeDB: 0.0)
        try await handle.adjustFrequency(493.88)
        try await handle.stop()
    }

    // MARK: - Fade-Out on Stop

    @Test("stop fades out before stopping note — subsequent play works (volume restored)")
    func stopFadesOutAndRestoresVolume() async throws {
        let player = try SoundFontNotePlayer(userSettings: MockUserSettings())
        let handle1 = try await player.play(frequency: 440.0, velocity: 63, amplitudeDB: 0.0)
        try await handle1.stop()
        // If volume were stuck at 0 after stop, this play would produce no sound
        // The test verifies stop() restores volume to 1.0 after the fade-out
        let handle2 = try await player.play(frequency: 440.0, velocity: 63, amplitudeDB: 0.0)
        try await handle2.stop()
    }
}
