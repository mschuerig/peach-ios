import Foundation
@testable import Peach

final class MockStepSequencer: StepSequencer {
    // MARK: - Observable State

    var currentStep: StepPosition?
    var currentCycle: CycleDefinition?

    // MARK: - Test State Tracking

    var startCallCount = 0
    var stopCallCount = 0
    var lastTempo: TempoBPM?
    var lastStepProvider: (any StepProvider)?
    var shouldThrowError = false
    var errorToThrow: AudioError = .engineStartFailed("Mock error")

    // MARK: - Callbacks

    var onStartCalled: (() -> Void)?
    var onStopCalled: (() -> Void)?

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
        lastTempo = nil
        lastStepProvider = nil
        shouldThrowError = false
        currentStep = nil
        currentCycle = nil
        onStartCalled = nil
        onStopCalled = nil
        startWaiters.removeAll()
        stopWaiters.removeAll()
    }
}
