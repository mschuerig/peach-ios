import Foundation
@testable import Peach

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

    private var hasStopped = false

    func stop() async throws {
        stopCallCount += 1
        onStopCalled?()

        if shouldThrowError && !hasStopped {
            throw errorToThrow
        }

        hasStopped = true
    }

    func adjustFrequency(_ frequency: Frequency) async throws {
        adjustFrequencyCallCount += 1
        lastAdjustedFrequency = frequency.rawValue
        adjustFrequencyHistory.append(frequency.rawValue)
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
