import Testing
@testable import Peach

/// Pure state transition tests for TimingOffsetDetectionSession.reduce.
@Suite("TimingOffsetDetectionSession.reduce")
struct TimingOffsetDetectionReduceTests {

    typealias State = TimingOffsetDetectionSessionState
    typealias Event = TimingOffsetDetectionSession.Event
    typealias Effect = TimingOffsetDetectionSession.Effect

    private func reduce(_ state: State, _ event: Event) -> (State, [Effect]) {
        var s = state
        let effects = TimingOffsetDetectionSession.reduce(state: &s, event: event)
        return (s, effects)
    }

    // MARK: - Start

    @Test("idle + startRequested → playingPatternLoop, beginNextTrial")
    func startFromIdle() async {
        let (state, effects) = reduce(.idle, .startRequested)
        #expect(state == .playingPatternLoop)
        #expect(effects.count == 1)
        guard case .beginNextTrial = effects.first else {
            Issue.record("Expected .beginNextTrial")
            return
        }
    }

    // MARK: - Answer (mid-loop)

    @Test("playingPatternLoop + answerReceived → showingFeedback with stopSequencer, evaluateAnswer, scheduleFeedbackTimer (mechanism before policy)")
    func answerReceivedFromLoop() async {
        let (state, effects) = reduce(.playingPatternLoop, .answerReceived(direction: .early))
        #expect(state == .showingFeedback)
        #expect(effects.count == 3)
        guard case .stopSequencer = effects[0] else {
            Issue.record("Expected .stopSequencer first (audio mechanism ordered ahead of result policy)")
            return
        }
        guard case .evaluateAnswer(let dir) = effects[1] else {
            Issue.record("Expected .evaluateAnswer second")
            return
        }
        #expect(dir == .early)
        guard case .scheduleFeedbackTimer = effects[2] else {
            Issue.record("Expected .scheduleFeedbackTimer third")
            return
        }
    }

    // MARK: - Feedback → Grid Wait

    @Test("showingFeedback + feedbackTimerFired → waitingForGrid, no effects")
    func feedbackTimerFired() async {
        let (state, effects) = reduce(.showingFeedback, .feedbackTimerFired)
        #expect(state == .waitingForGrid)
        #expect(effects.isEmpty)
    }

    @Test("waitingForGrid + gridAlignmentReached → playingPatternLoop, beginNextTrial")
    func gridAlignmentReached() async {
        let (state, effects) = reduce(.waitingForGrid, .gridAlignmentReached)
        #expect(state == .playingPatternLoop)
        #expect(effects.count == 1)
        guard case .beginNextTrial = effects.first else {
            Issue.record("Expected .beginNextTrial")
            return
        }
    }

    // MARK: - Stop

    @Test("any non-idle state + stopRequested → idle, stopAll")
    func stopFromNonIdle() async {
        for startState: State in [.playingPatternLoop, .showingFeedback, .waitingForGrid] {
            let (state, effects) = reduce(startState, .stopRequested)
            #expect(state == .idle)
            #expect(effects.count == 1)
            guard case .stopAll = effects.first else {
                Issue.record("Expected .stopAll from \(startState)")
                return
            }
        }
    }

    @Test("idle + stopRequested → no change")
    func stopFromIdle() async {
        let (state, effects) = reduce(.idle, .stopRequested)
        #expect(state == .idle)
        #expect(effects.isEmpty)
    }

    // MARK: - Audio Error

    @Test("any non-idle state + audioError → idle, stopAll")
    func audioErrorFromNonIdle() async {
        for startState: State in [.playingPatternLoop, .showingFeedback, .waitingForGrid] {
            let (state, effects) = reduce(startState, .audioError)
            #expect(state == .idle)
            #expect(effects.count == 1)
            guard case .stopAll = effects.first else {
                Issue.record("Expected .stopAll on audioError from \(startState)")
                return
            }
        }
    }

    @Test("idle + audioError → no change, no effects (spurious errors from already-stopped sessions are absorbed silently)")
    func audioErrorFromIdle() async {
        let (state, effects) = reduce(.idle, .audioError)
        #expect(state == .idle)
        #expect(effects.isEmpty)
    }

    // MARK: - Repetition Cap

    @Test("playingPatternLoop + repetitionCapReached → awaitingAnswer, stopSequencerAtCap")
    func repetitionCapFromLoop() async {
        let (state, effects) = reduce(.playingPatternLoop, .repetitionCapReached)
        // State exits the audio-playing phase into a silent awaiting-answer phase; the
        // transition itself is the idempotence latch (further polls see `state !=
        // .playingPatternLoop` and the cap check at the top of `evaluatePlaybackPosition`
        // returns early).
        #expect(state == .awaitingAnswer)
        #expect(effects.count == 1)
        guard case .stopSequencerAtCap = effects.first else {
            Issue.record("Expected .stopSequencerAtCap")
            return
        }
    }

    @Test("awaitingAnswer + answerReceived → showingFeedback, full answer effect list")
    func answerFromAwaitingAnswer() async {
        let (state, effects) = reduce(.awaitingAnswer, .answerReceived(direction: .early))
        #expect(state == .showingFeedback)
        #expect(effects.count == 3)
        guard case .stopSequencer = effects[0] else {
            Issue.record("Expected first effect to be .stopSequencer")
            return
        }
        guard case .evaluateAnswer(let direction) = effects[1], direction == .early else {
            Issue.record("Expected second effect to be .evaluateAnswer(.early)")
            return
        }
        guard case .scheduleFeedbackTimer = effects[2] else {
            Issue.record("Expected third effect to be .scheduleFeedbackTimer")
            return
        }
    }

    @Test("repetitionCapReached outside playingPatternLoop is a no-op")
    func repetitionCapOutsideLoopIsNoOp() async {
        // I/O matrix row: spurious cap event outside the audio-playing phase. After the cap
        // transition the session is already in `.awaitingAnswer`, so another cap event there
        // must also be a no-op.
        for startState: State in [.idle, .awaitingAnswer, .showingFeedback, .waitingForGrid] {
            let (state, effects) = reduce(startState, .repetitionCapReached)
            #expect(state == startState, "State must not change for spurious cap in \(startState)")
            #expect(effects.isEmpty, "No effects for spurious cap in \(startState)")
        }
    }

    // MARK: - Invalid Transitions

    @Test("invalid transitions produce no state change and no effects")
    func invalidTransitions() async {
        let invalidCases: [(State, Event)] = [
            (.idle, .answerReceived(direction: .early)),
            (.idle, .feedbackTimerFired),
            (.idle, .gridAlignmentReached),
            (.playingPatternLoop, .feedbackTimerFired),
            (.playingPatternLoop, .gridAlignmentReached),
            (.showingFeedback, .answerReceived(direction: .late)),
            (.showingFeedback, .gridAlignmentReached),
            (.waitingForGrid, .answerReceived(direction: .late)),
        ]
        for (startState, event) in invalidCases {
            let (state, effects) = reduce(startState, event)
            #expect(state == startState, "State should not change for invalid transition \(startState) + \(event)")
            #expect(effects.isEmpty, "No effects for invalid transition \(startState) + \(event)")
        }
    }
}
