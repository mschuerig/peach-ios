import Foundation
@testable import Peach

/// Mock NotePlayer for testing ComparisonSession
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

    // MARK: - Handle Tracking

    var lastHandle: MockPlaybackHandle?
    var handleHistory: [MockPlaybackHandle] = []

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

    // MARK: - NotePlayer Protocol (Primary — returns handle)

    func play(frequency: Double, velocity: UInt8, amplitudeDB: Float) async throws -> PlaybackHandle {
        playCallCount += 1
        lastFrequency = frequency
        lastVelocity = velocity
        lastAmplitudeDB = amplitudeDB

        onPlayCalled?()

        if shouldThrowError {
            throw errorToThrow
        }

        let handle = MockPlaybackHandle()
        lastHandle = handle
        handleHistory.append(handle)
        return handle
    }

    // MARK: - NotePlayer Protocol (Convenience — fixed-duration with instantPlayback)

    func play(frequency: Double, duration: TimeInterval, velocity: UInt8, amplitudeDB: Float) async throws {
        lastDuration = duration
        playHistory.append((frequency: frequency, duration: duration, velocity: velocity, amplitudeDB: amplitudeDB))

        let handle = try await play(frequency: frequency, velocity: velocity, amplitudeDB: amplitudeDB)

        do {
            if !instantPlayback {
                try await Task.sleep(for: .milliseconds(Int(simulatedPlaybackDuration * 1000)))
            }
            try await handle.stop()
        } catch {
            try? await handle.stop()
            throw error
        }
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
        lastHandle = nil
        handleHistory = []
    }
}
