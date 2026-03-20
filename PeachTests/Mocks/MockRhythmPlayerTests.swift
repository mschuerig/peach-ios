import Testing
import Foundation
@testable import Peach

@Suite("MockRhythmPlayer Contract Tests")
struct MockRhythmPlayerTests {

    // MARK: - Play Tracking

    @Test("tracks play call count")
    func tracksPlayCallCount() async throws {
        let mock = MockRhythmPlayer()
        let pattern = makePattern()
        _ = try await mock.play(pattern)
        _ = try await mock.play(pattern)
        #expect(mock.playCallCount == 2)
    }

    @Test("captures last pattern")
    func capturesLastPattern() async throws {
        let mock = MockRhythmPlayer()
        let pattern = makePattern(eventCount: 3)
        _ = try await mock.play(pattern)
        #expect(mock.lastPattern?.events.count == 3)
    }

    @Test("tracks handle history")
    func tracksHandleHistory() async throws {
        let mock = MockRhythmPlayer()
        _ = try await mock.play(makePattern())
        _ = try await mock.play(makePattern())
        #expect(mock.handleHistory.count == 2)
    }

    // MARK: - StopAll Tracking

    @Test("tracks stopAll call count")
    func tracksStopAllCallCount() async throws {
        let mock = MockRhythmPlayer()
        try await mock.stopAll()
        try await mock.stopAll()
        #expect(mock.stopAllCallCount == 2)
    }

    // MARK: - Error Injection

    @Test("throws error when shouldThrowError is set")
    func throwsOnPlay() async {
        let mock = MockRhythmPlayer()
        mock.shouldThrowError = true
        await #expect(throws: AudioError.self) {
            _ = try await mock.play(makePattern())
        }
    }

    @Test("throws error on stopAll when shouldThrowError is set")
    func throwsOnStopAll() async {
        let mock = MockRhythmPlayer()
        mock.shouldThrowError = true
        await #expect(throws: AudioError.self) {
            try await mock.stopAll()
        }
    }

    // MARK: - Callbacks

    @Test("fires onPlayCalled callback")
    func firesOnPlayCalled() async throws {
        let mock = MockRhythmPlayer()
        var callbackFired = false
        mock.onPlayCalled = { callbackFired = true }
        _ = try await mock.play(makePattern())
        #expect(callbackFired)
    }

    @Test("fires onStopAllCalled callback")
    func firesOnStopAllCalled() async throws {
        let mock = MockRhythmPlayer()
        var callbackFired = false
        mock.onStopAllCalled = { callbackFired = true }
        try await mock.stopAll()
        #expect(callbackFired)
    }

    // MARK: - Reset

    @Test("reset clears all state")
    func resetClearsState() async throws {
        let mock = MockRhythmPlayer()
        _ = try await mock.play(makePattern())
        try await mock.stopAll()
        mock.reset()
        #expect(mock.playCallCount == 0)
        #expect(mock.stopAllCallCount == 0)
        #expect(mock.lastPattern == nil)
        #expect(mock.handleHistory.isEmpty)
    }

    // MARK: - Helpers

    private func makePattern(eventCount: Int = 1) -> RhythmPattern {
        let events = (0..<eventCount).map { i in
            RhythmPattern.Event(
                sampleOffset: Int64(i * 22050),
                soundSourceID: SoundSourceTag(rawValue: "sf2:128:0:36"),
                velocity: MIDIVelocity(100)
            )
        }
        return RhythmPattern(events: events, sampleRate: 44100.0, totalDuration: .seconds(1))
    }
}

@Suite("MockRhythmPlaybackHandle Contract Tests")
struct MockRhythmPlaybackHandleTests {

    @Test("tracks stop call count")
    func tracksStopCallCount() async throws {
        let handle = MockRhythmPlaybackHandle()
        try await handle.stop()
        try await handle.stop()
        #expect(handle.stopCallCount == 2)
    }

    @Test("throws error when shouldThrowError is set")
    func throwsOnStop() async {
        let handle = MockRhythmPlaybackHandle()
        handle.shouldThrowError = true
        await #expect(throws: AudioError.self) {
            try await handle.stop()
        }
    }

    @Test("fires onStopCalled callback")
    func firesCallback() async throws {
        let handle = MockRhythmPlaybackHandle()
        var callbackFired = false
        handle.onStopCalled = { callbackFired = true }
        try await handle.stop()
        #expect(callbackFired)
    }

    @Test("reset clears all state")
    func resetClearsState() async throws {
        let handle = MockRhythmPlaybackHandle()
        try await handle.stop()
        handle.reset()
        #expect(handle.stopCallCount == 0)
    }
}
