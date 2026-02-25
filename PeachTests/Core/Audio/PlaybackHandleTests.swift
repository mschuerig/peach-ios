import Testing
import Foundation
@testable import Peach

@Suite("PlaybackHandle Tests")
struct PlaybackHandleTests {

    // MARK: - Stop Idempotency

    @Test("stop() first call increments stop count")
    func stopFirstCall() async throws {
        let handle = MockPlaybackHandle()
        try await handle.stop()
        #expect(handle.stopCallCount == 1)
        #expect(handle.isStopped == true)
    }

    @Test("stop() is idempotent — subsequent calls are no-ops")
    func stopIdempotency() async throws {
        let handle = MockPlaybackHandle()
        try await handle.stop()
        try await handle.stop()
        try await handle.stop()
        #expect(handle.stopCallCount == 3)
        #expect(handle.isStopped == true)
    }

    // MARK: - adjustFrequency

    @Test("adjustFrequency updates lastAdjustedFrequency")
    func adjustFrequencyTracking() async throws {
        let handle = MockPlaybackHandle()
        try await handle.adjustFrequency(880.0)
        #expect(handle.adjustFrequencyCallCount == 1)
        #expect(handle.lastAdjustedFrequency == 880.0)
    }

    @Test("adjustFrequency tracks call history")
    func adjustFrequencyHistory() async throws {
        let handle = MockPlaybackHandle()
        try await handle.adjustFrequency(440.0)
        try await handle.adjustFrequency(880.0)
        try await handle.adjustFrequency(220.0)
        #expect(handle.adjustFrequencyCallCount == 3)
        #expect(handle.adjustFrequencyHistory == [440.0, 880.0, 220.0])
    }

    // MARK: - Error Injection

    @Test("stop() throws when error injection is enabled on first call")
    func stopThrowsOnError() async throws {
        let handle = MockPlaybackHandle()
        handle.shouldThrowError = true
        await #expect(throws: AudioError.self) {
            try await handle.stop()
        }
    }

    @Test("adjustFrequency throws when error injection is enabled")
    func adjustFrequencyThrowsOnError() async throws {
        let handle = MockPlaybackHandle()
        handle.shouldThrowError = true
        await #expect(throws: AudioError.self) {
            try await handle.adjustFrequency(440.0)
        }
    }

    // MARK: - Callbacks

    @Test("onStopCalled callback fires on stop")
    func stopCallback() async throws {
        let handle = MockPlaybackHandle()
        var callbackFired = false
        handle.onStopCalled = { callbackFired = true }
        try await handle.stop()
        #expect(callbackFired == true)
    }

    @Test("onAdjustFrequencyCalled callback fires on adjustFrequency")
    func adjustFrequencyCallback() async throws {
        let handle = MockPlaybackHandle()
        var callbackFired = false
        handle.onAdjustFrequencyCalled = { callbackFired = true }
        try await handle.adjustFrequency(440.0)
        #expect(callbackFired == true)
    }

    // MARK: - Reset

    @Test("reset clears all state")
    func resetClearsState() async throws {
        let handle = MockPlaybackHandle()
        try await handle.stop()
        try await handle.adjustFrequency(440.0)
        handle.reset()
        #expect(handle.stopCallCount == 0)
        #expect(handle.adjustFrequencyCallCount == 0)
        #expect(handle.lastAdjustedFrequency == nil)
        #expect(handle.adjustFrequencyHistory.isEmpty)
        #expect(handle.isStopped == false)
    }
}
