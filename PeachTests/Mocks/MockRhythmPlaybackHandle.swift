import Foundation
@testable import Peach

final class MockRhythmPlaybackHandle: RhythmPlaybackHandle {
    // MARK: - Test State Tracking

    var stopCallCount = 0
    var shouldThrowError = false
    var errorToThrow: AudioError = .engineStartFailed("Mock error")

    // MARK: - Callbacks

    var onStopCalled: (() -> Void)?

    // MARK: - RhythmPlaybackHandle Protocol

    func stop() async throws {
        stopCallCount += 1
        onStopCalled?()
        if shouldThrowError {
            throw errorToThrow
        }
    }

    // MARK: - Test Helpers

    func reset() {
        stopCallCount = 0
        shouldThrowError = false
        onStopCalled = nil
    }
}
