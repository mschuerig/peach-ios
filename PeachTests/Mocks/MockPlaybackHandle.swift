import Foundation
@testable import Peach

/// Mock PlaybackHandle for testing note lifecycle management.
final class MockPlaybackHandle: PlaybackHandle {
    // MARK: - Test State Tracking

    var stopCallCount = 0
    var adjustFrequencyCallCount = 0
    var lastAdjustedFrequency: Double?
    var adjustFrequencyHistory: [Double] = []

    // MARK: - Error Injection

    var shouldThrowError = false
    var errorToThrow: AudioError = .engineStartFailed("Mock error")

    // MARK: - Callbacks

    var onStopCalled: (() -> Void)?
    var onAdjustFrequencyCalled: (() -> Void)?

    // MARK: - PlaybackHandle Protocol

    // Note: Unlike production SoundFontPlaybackHandle (which returns early on subsequent
    // stop() calls via `guard !hasStopped`), the mock intentionally tracks ALL calls —
    // including subsequent stops — so tests can verify call counts. The `hasStopped` flag
    // gates error injection only, not the tracking behavior.
    private var hasStopped = false

    func stop() async throws {
        stopCallCount += 1
        onStopCalled?()

        if shouldThrowError && !hasStopped {
            throw errorToThrow
        }

        hasStopped = true
    }

    func adjustFrequency(_ frequency: Double) async throws {
        adjustFrequencyCallCount += 1
        lastAdjustedFrequency = frequency
        adjustFrequencyHistory.append(frequency)
        onAdjustFrequencyCalled?()

        if shouldThrowError {
            throw errorToThrow
        }
    }

    // MARK: - Test Helpers

    var isStopped: Bool { hasStopped }

    func reset() {
        stopCallCount = 0
        adjustFrequencyCallCount = 0
        lastAdjustedFrequency = nil
        adjustFrequencyHistory = []
        shouldThrowError = false
        onStopCalled = nil
        onAdjustFrequencyCalled = nil
        hasStopped = false
    }
}
