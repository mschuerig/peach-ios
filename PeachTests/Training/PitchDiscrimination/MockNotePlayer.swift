import Foundation
@testable import Peach

final class MockNotePlayer: NotePlayer {
    // MARK: - Test State Tracking

    var playCallCount = 0
    var stopAllCallCount = 0
    var lastFrequency: Double?
    var lastDuration: Duration?
    var lastVelocity: UInt8?
    var lastAmplitudeDB: Double?
    var playHistory: [(frequency: Double, duration: Duration, velocity: UInt8, amplitudeDB: Double)] = []
    var shouldThrowError = false
    var errorToThrow: AudioError = .engineStartFailed("Mock error")

    // MARK: - Handle Tracking

    var lastHandle: MockPlaybackHandle?
    var handleHistory: [MockPlaybackHandle] = []

    // MARK: - Test Control (Fully Synchronous)

    var instantPlayback: Bool = true
    var simulatedPlaybackDuration: Duration = .milliseconds(10)
    var onPlayCalled: (() -> Void)?
    var onStopAllCalled: (() -> Void)?

    // MARK: - Continuation-Based Wait

    private var playCountWaiters: [(minCount: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var stopAllWaiters: [CheckedContinuation<Void, Never>] = []

    func waitForPlay(minCount: Int = 1) async {
        if playCallCount >= minCount { return }
        await withCheckedContinuation { continuation in
            playCountWaiters.append((minCount: minCount, continuation: continuation))
        }
    }

    func waitForStopAll() async {
        if stopAllCallCount > 0 { return }
        await withCheckedContinuation { continuation in
            stopAllWaiters.append(continuation)
        }
    }

    // MARK: - NotePlayer Protocol (Primary — returns handle)

    func play(frequency: Frequency, velocity: MIDIVelocity, amplitudeDB: AmplitudeDB) async throws -> PlaybackHandle {
        playCallCount += 1
        lastFrequency = frequency.rawValue
        lastVelocity = velocity.rawValue
        lastAmplitudeDB = amplitudeDB.rawValue

        onPlayCalled?()

        let satisfied = playCountWaiters.filter { playCallCount >= $0.minCount }
        playCountWaiters.removeAll { playCallCount >= $0.minCount }
        for entry in satisfied {
            entry.continuation.resume()
        }

        if shouldThrowError {
            throw errorToThrow
        }

        let handle = MockPlaybackHandle()
        lastHandle = handle
        handleHistory.append(handle)
        return handle
    }

    // MARK: - NotePlayer Protocol (Convenience — fixed-duration with instantPlayback)

    func play(frequency: Frequency, duration: Duration, velocity: MIDIVelocity, amplitudeDB: AmplitudeDB) async throws {
        lastDuration = duration
        playHistory.append((frequency: frequency.rawValue, duration: duration, velocity: velocity.rawValue, amplitudeDB: amplitudeDB.rawValue))

        let handle = try await play(frequency: frequency, velocity: velocity, amplitudeDB: amplitudeDB)

        do {
            if !instantPlayback {
                try await Task.sleep(for: simulatedPlaybackDuration)
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

        let waiters = stopAllWaiters
        stopAllWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
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
        playCountWaiters.removeAll()
        stopAllWaiters.removeAll()
    }
}
