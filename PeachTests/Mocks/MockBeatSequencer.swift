import Foundation
@testable import Peach

final class MockBeatSequencer: BeatSequencer {
    // MARK: - Observable State

    var currentBeat: Beat?

    // MARK: - Timing State

    var currentSamplePosition: Int64 = 0
    var samplesPerBeat: Int64 = 0
    var sampleRate: SampleRate = .standard44100

    var timing: SequencerTiming {
        SequencerTiming(
            samplePosition: currentSamplePosition,
            samplesPerBeat: samplesPerBeat,
            sampleRate: sampleRate
        )
    }

    // MARK: - Host Time Conversion

    var samplePositionForHostTimeOverride: Int64?

    func samplePosition(forHostTime hostTime: UInt64) -> Int64 {
        samplePositionForHostTimeOverride ?? currentSamplePosition
    }

    // MARK: - Test State Tracking

    var startCallCount = 0
    var stopCallCount = 0
    var playImmediateNoteCallCount = 0
    var lastPlayImmediateNoteVelocity: MIDIVelocity?
    var playImmediateNoteVelocities: [MIDIVelocity] = []
    var lastTempo: TempoBPM?
    var lastBeatProvider: (any BeatProvider)?
    var shouldThrowError = false
    var shouldThrowOnPlayImmediateNote = false
    var errorToThrow: AudioError = .engineStartFailed("Mock error")

    /// Interleaved start/stop event log for serialization-ordering tests.
    /// Each entry carries the call's monotonic index plus identifying info
    /// (the beat provider for `start`). Tests that need to assert "stop of A
    /// completed before start of B" inspect this log directly.
    enum CallEvent: Equatable {
        /// Start was called. `providerTypeName` identifies which session.
        case start(providerTypeName: String)
        /// Stop was called.
        case stop
    }
    private(set) var callLog: [CallEvent] = []

    // MARK: - Callbacks

    var onStartCalled: (() -> Void)?
    var onStopCalled: (() -> Void)?
    var onPlayImmediateNoteCalled: (() -> Void)?

    // MARK: - Continuation-Based Wait

    private var startWaiters: [(minCount: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var stopWaiters: [CheckedContinuation<Void, Never>] = []

    func waitForStart(minCount: Int = 1) async {
        if startCallCount >= minCount { return }
        await withCheckedContinuation { continuation in
            startWaiters.append((minCount: minCount, continuation: continuation))
        }
    }

    func waitForStop() async {
        if stopCallCount > 0 { return }
        await withCheckedContinuation { continuation in
            stopWaiters.append(continuation)
        }
    }

    // MARK: - BeatSequencer Protocol

    func start(tempo: TempoBPM, beatProvider: any BeatProvider) async throws {
        startCallCount += 1
        lastTempo = tempo
        lastBeatProvider = beatProvider
        callLog.append(.start(providerTypeName: String(describing: type(of: beatProvider))))

        // `currentSamplePosition` is intentionally NOT reset here. This mirrors
        // the production sequencer: `SoundFontEngine` bumps the generation on
        // `scheduleEvents` and the render thread observes the reset to 0 on its
        // next callback, NOT synchronously on `start()` return. Tests that need
        // to simulate a stale pre-start value pre-set it on the mock, then call
        // `flushDeferredReset()` to model the render-thread reset.
        // See PF-011 audit in Story 85.3.

        onStartCalled?()

        let satisfied = startWaiters.filter { startCallCount >= $0.minCount }
        startWaiters.removeAll { startCallCount >= $0.minCount }
        for entry in satisfied {
            entry.continuation.resume()
        }

        if shouldThrowError {
            throw errorToThrow
        }
    }

    /// Drops `currentSamplePosition` to 0, simulating the render thread's
    /// deferred reset observed on the next callback after `start()` /
    /// `scheduleEvents()` bump the generation. Test-only.
    func flushDeferredReset() {
        currentSamplePosition = 0
    }

    func playImmediateNote(velocity: MIDIVelocity) throws {
        playImmediateNoteCallCount += 1
        lastPlayImmediateNoteVelocity = velocity
        playImmediateNoteVelocities.append(velocity)

        onPlayImmediateNoteCalled?()

        if shouldThrowOnPlayImmediateNote {
            throw errorToThrow
        }
    }

    func stop() async throws {
        stopCallCount += 1
        currentBeat = nil
        callLog.append(.stop)

        onStopCalled?()

        let waiters = stopWaiters
        stopWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }

        if shouldThrowError {
            throw errorToThrow
        }
    }

    // MARK: - Test Helpers

    func reset() {
        startCallCount = 0
        stopCallCount = 0
        callLog = []
        playImmediateNoteCallCount = 0
        lastPlayImmediateNoteVelocity = nil
        playImmediateNoteVelocities = []
        lastTempo = nil
        lastBeatProvider = nil
        shouldThrowError = false
        shouldThrowOnPlayImmediateNote = false
        currentBeat = nil
        currentSamplePosition = 0
        samplesPerBeat = 0
        sampleRate = .standard44100
        samplePositionForHostTimeOverride = nil
        onStartCalled = nil
        onStopCalled = nil
        onPlayImmediateNoteCalled = nil
        startWaiters.removeAll()
        stopWaiters.removeAll()
    }
}
