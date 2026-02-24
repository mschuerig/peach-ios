import Foundation
@testable import Peach

/// Mock NotePlayer for testing TrainingSession
final class MockNotePlayer: NotePlayer {
    // MARK: - Test State Tracking

    var playCallCount = 0
    var stopCallCount = 0
    var lastFrequency: Double?
    var lastDuration: TimeInterval?
    var lastVelocity: UInt8?
    var lastAmplitudeDB: Float?
    var playHistory: [(frequency: Double, duration: TimeInterval, velocity: UInt8, amplitudeDB: Float)] = []
    var shouldThrowError = false
    var errorToThrow: AudioError = .engineStartFailed("Mock error")

    // MARK: - Test Control (Fully Synchronous)

    /// If true, play() completes instantly without any delays (default: true for deterministic tests)
    var instantPlayback: Bool = true

    /// Simulated playback duration in seconds (only used if instantPlayback = false)
    var simulatedPlaybackDuration: TimeInterval = 0.01

    /// Callback invoked when play() is called (before any delays)
    /// Allows tests to synchronously respond to play events
    var onPlayCalled: (() -> Void)?

    /// Callback invoked when stop() is called
    var onStopCalled: (() -> Void)?

    // MARK: - NotePlayer Protocol

    func play(frequency: Double, duration: TimeInterval, velocity: UInt8, amplitudeDB: Float) async throws {
        playCallCount += 1
        lastFrequency = frequency
        lastDuration = duration
        lastVelocity = velocity
        lastAmplitudeDB = amplitudeDB
        playHistory.append((frequency: frequency, duration: duration, velocity: velocity, amplitudeDB: amplitudeDB))

        // Invoke callback synchronously before any delays
        onPlayCalled?()

        if shouldThrowError {
            throw errorToThrow
        }

        // Only add delay if not using instant playback
        if !instantPlayback {
            try await Task.sleep(for: .milliseconds(Int(simulatedPlaybackDuration * 1000)))
        }
        // Otherwise complete immediately - no artificial timing
    }

    func stop() async throws {
        stopCallCount += 1
        onStopCalled?()
    }

    // MARK: - Test Helpers

    func reset() {
        playCallCount = 0
        stopCallCount = 0
        lastFrequency = nil
        lastDuration = nil
        lastVelocity = nil
        lastAmplitudeDB = nil
        playHistory = []
        shouldThrowError = false
        onPlayCalled = nil
        onStopCalled = nil
    }
}
