import Foundation
@testable import Peach

final class MockRhythmPlayer: RhythmPlayer {
    // MARK: - Test State Tracking

    var playCallCount = 0
    var stopAllCallCount = 0
    var lastPattern: RhythmPattern?
    var shouldThrowError = false
    var errorToThrow: AudioError = .engineStartFailed("Mock error")
    var instantPlayback = true

    // MARK: - Handle Tracking

    var lastHandle: MockRhythmPlaybackHandle?
    var handleHistory: [MockRhythmPlaybackHandle] = []

    // MARK: - Callbacks

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

    // MARK: - RhythmPlayer Protocol

    func play(_ pattern: RhythmPattern) async throws -> RhythmPlaybackHandle {
        playCallCount += 1
        lastPattern = pattern

        onPlayCalled?()

        let satisfied = playCountWaiters.filter { playCallCount >= $0.minCount }
        playCountWaiters.removeAll { playCallCount >= $0.minCount }
        for entry in satisfied {
            entry.continuation.resume()
        }

        if shouldThrowError {
            throw errorToThrow
        }

        let handle = MockRhythmPlaybackHandle()
        lastHandle = handle
        handleHistory.append(handle)
        return handle
    }

    func stopAll() async throws {
        stopAllCallCount += 1
        onStopAllCalled?()

        let waiters = stopAllWaiters
        stopAllWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }

        if shouldThrowError {
            throw errorToThrow
        }
    }

    // MARK: - Test Helpers

    func reset() {
        playCallCount = 0
        stopAllCallCount = 0
        lastPattern = nil
        shouldThrowError = false
        onPlayCalled = nil
        onStopAllCalled = nil
        lastHandle = nil
        handleHistory = []
        playCountWaiters.removeAll()
        stopAllWaiters.removeAll()
    }
}
