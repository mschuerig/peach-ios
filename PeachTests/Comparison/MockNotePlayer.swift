import Foundation
@testable import Peach

final class MockNotePlayer: NotePlayer {
    // MARK: - Test State Tracking

    var playCallCount = 0
    var stopAllCallCount = 0
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

    var instantPlayback: Bool = true
    var simulatedPlaybackDuration: TimeInterval = 0.01
    var onPlayCalled: (() -> Void)?
    var onStopAllCalled: (() -> Void)?

    // MARK: - NotePlayer Protocol (Primary — returns handle)

    func play(frequency: Frequency, velocity: MIDIVelocity, amplitudeDB: AmplitudeDB) async throws -> PlaybackHandle {
        playCallCount += 1
        lastFrequency = frequency.rawValue
        lastVelocity = velocity.rawValue
        lastAmplitudeDB = amplitudeDB.rawValue

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

    func play(frequency: Frequency, duration: TimeInterval, velocity: MIDIVelocity, amplitudeDB: AmplitudeDB) async throws {
        lastDuration = duration
        playHistory.append((frequency: frequency.rawValue, duration: duration, velocity: velocity.rawValue, amplitudeDB: amplitudeDB.rawValue))

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

    func stopAll() async throws {
        stopAllCallCount += 1
        onStopAllCalled?()
    }

    // MARK: - Test Helpers

    func reset() {
        playCallCount = 0
        stopAllCallCount = 0
        lastFrequency = nil
        lastDuration = nil
        lastVelocity = nil
        lastAmplitudeDB = nil
        playHistory = []
        shouldThrowError = false
        onPlayCalled = nil
        onStopAllCalled = nil
        lastHandle = nil
        handleHistory = []
    }
}
