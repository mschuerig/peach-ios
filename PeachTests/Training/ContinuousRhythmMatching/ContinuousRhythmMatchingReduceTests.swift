import Testing
@testable import Peach

/// Pure state transition tests for ContinuousRhythmMatchingSession.reduce.
@Suite("ContinuousRhythmMatchingSession.reduce")
struct ContinuousRhythmMatchingReduceTests {

    typealias State = ContinuousRhythmMatchingSessionState
    typealias Event = ContinuousRhythmMatchingSession.Event
    typealias Effect = ContinuousRhythmMatchingSession.Effect

    private func reduce(_ state: State, _ event: Event) -> (State, [Effect]) {
        var s = state
        let effects = ContinuousRhythmMatchingSession.reduce(state: &s, event: event)
        return (s, effects)
    }

    private let testSettings = ContinuousRhythmMatchingSettings(tempo: TempoBPM(120))

    // MARK: - Start

    @Test("idle + startRequested → running, startSequencer + startMIDIListening")
    func startFromIdle() async {
        let (state, effects) = reduce(.idle, .startRequested(testSettings))
        #expect(state == .running)
        #expect(effects.count == 2)
        guard case .startSequencer = effects[0] else {
            Issue.record("Expected .startSequencer first")
            return
        }
        guard case .startMIDIListening = effects[1] else {
            Issue.record("Expected .startMIDIListening second")
            return
        }
    }

    // MARK: - Sequencer Ready

    @Test("running + sequencerReady → running, startTrackingLoop")
    func sequencerReady() async {
        let (state, effects) = reduce(.running, .sequencerReady)
        #expect(state == .running)
        #expect(effects.count == 1)
        guard case .startTrackingLoop = effects.first else {
            Issue.record("Expected .startTrackingLoop")
            return
        }
    }

    // MARK: - Tap Hit

    @Test("running + tapHit → running with playTapSound, recordGapResult, advanceCycleCount, showHitFeedback")
    func tapHit() async {
        let result = GapResult(position: .second, offset: TimingOffset(.milliseconds(5)))
        let (state, effects) = reduce(.running, .tapHit(result))
        #expect(state == .running)
        #expect(effects.count == 4)
        guard case .playTapSound(let pos) = effects[0] else {
            Issue.record("Expected .playTapSound first")
            return
        }
        #expect(pos == .second)
        guard case .recordGapResult = effects[1] else {
            Issue.record("Expected .recordGapResult second")
            return
        }
        guard case .advanceCycleCount = effects[2] else {
            Issue.record("Expected .advanceCycleCount third")
            return
        }
        guard case .showHitFeedback = effects[3] else {
            Issue.record("Expected .showHitFeedback fourth")
            return
        }
    }

    @Test("tapHit on first position produces first position in playTapSound")
    func tapHitAccent() async {
        let result = GapResult(position: .first, offset: TimingOffset(.milliseconds(0)))
        let (_, effects) = reduce(.running, .tapHit(result))
        guard case .playTapSound(let pos) = effects[0] else {
            Issue.record("Expected .playTapSound")
            return
        }
        #expect(pos == .first)
    }

    // MARK: - Cycle Missed

    @Test("running + cycleMissed → running, advanceCycleCount")
    func cycleMissed() async {
        let (state, effects) = reduce(.running, .cycleMissed)
        #expect(state == .running)
        #expect(effects.count == 1)
        guard case .advanceCycleCount = effects.first else {
            Issue.record("Expected .advanceCycleCount")
            return
        }
    }

    // MARK: - Trial Completed

    @Test("running + trialCompleted → running, completeTrial")
    func trialCompleted() async {
        let (state, effects) = reduce(.running, .trialCompleted)
        #expect(state == .running)
        #expect(effects.count == 1)
        guard case .completeTrial = effects.first else {
            Issue.record("Expected .completeTrial")
            return
        }
    }

    // MARK: - Stop

    @Test("running + stopRequested → idle, stopAll")
    func stopFromRunning() async {
        let (state, effects) = reduce(.running, .stopRequested)
        #expect(state == .idle)
        #expect(effects.count == 1)
        guard case .stopAll = effects.first else {
            Issue.record("Expected .stopAll")
            return
        }
    }

    @Test("idle + stopRequested → no change")
    func stopFromIdle() async {
        let (state, effects) = reduce(.idle, .stopRequested)
        #expect(state == .idle)
        #expect(effects.isEmpty)
    }

    // MARK: - Audio Error

    @Test("running + audioError → idle, stopAll")
    func audioError() async {
        let (state, effects) = reduce(.running, .audioError)
        #expect(state == .idle)
        #expect(effects.count == 1)
        guard case .stopAll = effects.first else {
            Issue.record("Expected .stopAll")
            return
        }
    }

    // MARK: - Invalid Transitions

    @Test("invalid transitions produce no state change and no effects")
    func invalidTransitions() async {
        let invalidCases: [(State, Event)] = [
            (.idle, .sequencerReady),
            (.idle, .tapHit(GapResult(position: .first, offset: TimingOffset(.milliseconds(0))))),
            (.idle, .cycleMissed),
            (.idle, .trialCompleted),
        ]
        for (startState, event) in invalidCases {
            let (state, effects) = reduce(startState, event)
            #expect(state == startState, "State should not change for invalid transition \(startState) + \(event)")
            #expect(effects.isEmpty, "No effects for invalid transition \(startState) + \(event)")
        }
    }
}
