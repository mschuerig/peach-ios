import Testing
import Foundation
@testable import Peach

@Suite("SoundFontPlaybackHandle Tests")
struct SoundFontPlaybackHandleTests {

    // MARK: - Stop Behavior via SoundFontNotePlayer

    @Test("Handle stop after play silences the note")
    func handleStopAfterPlay() async throws {
        let player = try SoundFontNotePlayer()
        let handle = try await player.play(frequency: 440.0, velocity: 63, amplitudeDB: 0.0)
        try await handle.stop()
    }

    @Test("Handle stop is idempotent — multiple calls do not crash")
    func handleStopIdempotent() async throws {
        let player = try SoundFontNotePlayer()
        let handle = try await player.play(frequency: 440.0, velocity: 63, amplitudeDB: 0.0)
        try await handle.stop()
        try await handle.stop()
        try await handle.stop()
    }

    // MARK: - adjustFrequency Behavior

    @Test("adjustFrequency does not crash for valid frequency")
    func adjustFrequencyValid() async throws {
        let player = try SoundFontNotePlayer()
        let handle = try await player.play(frequency: 440.0, velocity: 63, amplitudeDB: 0.0)
        try await handle.adjustFrequency(880.0)
        try await handle.stop()
    }

    @Test("adjustFrequency after stop is a no-op")
    func adjustFrequencyAfterStop() async throws {
        let player = try SoundFontNotePlayer()
        let handle = try await player.play(frequency: 440.0, velocity: 63, amplitudeDB: 0.0)
        try await handle.stop()
        try await handle.adjustFrequency(880.0)
    }

    @Test("Multiple adjustFrequency calls succeed")
    func multipleAdjustFrequencyCalls() async throws {
        let player = try SoundFontNotePlayer()
        let handle = try await player.play(frequency: 440.0, velocity: 63, amplitudeDB: 0.0)
        try await handle.adjustFrequency(450.0)
        try await handle.adjustFrequency(430.0)
        try await handle.adjustFrequency(440.0)
        try await handle.stop()
    }
}
