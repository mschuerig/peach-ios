import Testing
import Foundation
@testable import Peach

@Suite("NotePlayer Convenience Method Tests")
struct NotePlayerConvenienceTests {

    @Test("Convenience method calls primary play and returns handle that gets stopped")
    func convenienceMethodDelegatesToHandle() async throws {
        let mock = MockNotePlayer()
        let player: NotePlayer = mock

        try await player.play(frequency: 440.0, duration: 0.01, velocity: 63, amplitudeDB: 0.0)

        #expect(mock.playCallCount == 1)
        #expect(mock.lastFrequency == 440.0)
        #expect(mock.lastVelocity == 63)
        #expect(mock.lastAmplitudeDB == 0.0)
        #expect(mock.lastDuration == 0.01)

        // Handle should have been stopped by the convenience method
        #expect(mock.lastHandle != nil)
        #expect(mock.lastHandle?.stopCallCount == 1)
    }

    @Test("Convenience method tracks duration in play history")
    func convenienceMethodTracksDuration() async throws {
        let mock = MockNotePlayer()
        let player: NotePlayer = mock

        try await player.play(frequency: 440.0, duration: 0.5, velocity: 63, amplitudeDB: 0.0)
        try await player.play(frequency: 880.0, duration: 0.3, velocity: 100, amplitudeDB: -2.0)

        #expect(mock.playHistory.count == 2)
        #expect(mock.playHistory[0].frequency == 440.0)
        #expect(mock.playHistory[0].duration == 0.5)
        #expect(mock.playHistory[1].frequency == 880.0)
        #expect(mock.playHistory[1].duration == 0.3)
    }

    @Test("Convenience method stops handle on error")
    func convenienceMethodStopsHandleOnCancellation() async throws {
        let mock = MockNotePlayer()

        let task = Task {
            try await mock.play(frequency: 440.0, duration: 10.0, velocity: 63, amplitudeDB: 0.0)
        }

        // Wait for play to start
        while mock.playCallCount == 0 {
            try await Task.sleep(for: .milliseconds(1))
        }

        task.cancel()
        _ = await task.result

        // Handle should have been stopped during cancellation cleanup
        #expect(mock.lastHandle?.stopCallCount == 1)
    }

    // MARK: - Duration Validation (uses ExtensionOnlyNotePlayer to test the default extension)

    @Test("Duration zero throws invalidDuration error")
    func durationZeroThrows() async throws {
        let stub = ExtensionOnlyNotePlayer()

        await #expect(throws: AudioError.self) {
            try await stub.play(frequency: 440.0, duration: 0.0, velocity: 63, amplitudeDB: 0.0)
        }
        #expect(stub.playCallCount == 0)
    }

    @Test("Negative duration throws invalidDuration error")
    func negativeDurationThrows() async throws {
        let stub = ExtensionOnlyNotePlayer()

        await #expect(throws: AudioError.self) {
            try await stub.play(frequency: 440.0, duration: -1.0, velocity: 63, amplitudeDB: 0.0)
        }
        #expect(stub.playCallCount == 0)
    }
}

/// Minimal NotePlayer that does NOT override the convenience method,
/// so the default extension (with duration validation) is exercised.
private final class ExtensionOnlyNotePlayer: NotePlayer {
    var playCallCount = 0

    func play(frequency: Frequency, velocity: MIDIVelocity, amplitudeDB: AmplitudeDB) async throws -> PlaybackHandle {
        playCallCount += 1
        return MockPlaybackHandle()
    }

    func stopAll() async throws {}
}
