import Foundation
@testable import Peach

final class MockStepSequencer: StepSequencer {
    // MARK: - Observable State

    var currentStep: StepPosition?
    var currentCycle: CycleDefinition?

    // MARK: - Timing State

    var currentSamplePosition: Int64 = 0
    var samplesPerStep: Int64 = 0
    var samplesPerCycle: Int64 = 0
    var sampleRate: SampleRate = .standard44100

    var timing: SequencerTiming {
        SequencerTiming(
            samplePosition: currentSamplePosition,
            samplesPerStep: samplesPerStep,
            samplesPerCycle: samplesPerCycle,
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
    var lastStepProvider: (any StepProvider)?
    var shouldThrowError = false
    var shouldThrowOnPlayImmediateNote = false
    var errorToThrow: AudioError = .engineStartFailed("Mock error")

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

    // MARK: - StepSequencer Protocol

    func start(tempo: TempoBPM, stepProvider: any StepProvider) async throws {
        startCallCount += 1
        lastTempo = tempo
        lastStepProvider = stepProvider

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
        currentStep = nil
        currentCycle = nil

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
        playImmediateNoteCallCount = 0
        lastPlayImmediateNoteVelocity = nil
        playImmediateNoteVelocities = []
        lastTempo = nil
        lastStepProvider = nil
        shouldThrowError = false
        shouldThrowOnPlayImmediateNote = false
        currentStep = nil
        currentCycle = nil
        currentSamplePosition = 0
        samplesPerStep = 0
        samplesPerCycle = 0
        sampleRate = .standard44100
        samplePositionForHostTimeOverride = nil
        onStartCalled = nil
        onStopCalled = nil
        onPlayImmediateNoteCalled = nil
        startWaiters.removeAll()
        stopWaiters.removeAll()
    }
}
