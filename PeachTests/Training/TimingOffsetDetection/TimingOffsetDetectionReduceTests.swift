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

    @Test("idle + startRequested → playingPattern, beginNextTrial")
    func startFromIdle() async {
        let (state, effects) = reduce(.idle, .startRequested)
        #expect(state == .playingPattern)
        #expect(effects.count == 1)
        guard case .beginNextTrial = effects.first else {
            Issue.record("Expected .beginNextTrial")
            return
        }
    }

    // MARK: - Pattern Playback

    @Test("playingPattern + patternFinished → awaitingAnswer, no effects")
    func patternFinished() async {
        let (state, effects) = reduce(.playingPattern, .patternFinished)
        #expect(state == .awaitingAnswer)
        #expect(effects.isEmpty)
    }

    // MARK: - Answer

    @Test("awaitingAnswer + answerReceived → showingFeedback with evaluateAnswer, scheduleFeedbackTimer")
    func answerReceived() async {
        let (state, effects) = reduce(.awaitingAnswer, .answerReceived(direction: .early))
        #expect(state == .showingFeedback)
        #expect(effects.count == 2)
        guard case .evaluateAnswer(let dir) = effects[0] else {
            Issue.record("Expected .evaluateAnswer first")
            return
        }
        #expect(dir == .early)
        guard case .scheduleFeedbackTimer = effects[1] else {
            Issue.record("Expected .scheduleFeedbackTimer second")
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

    @Test("waitingForGrid + gridAlignmentReached → playingPattern, beginNextTrial")
    func gridAlignmentReached() async {
        let (state, effects) = reduce(.waitingForGrid, .gridAlignmentReached)
        #expect(state == .playingPattern)
        #expect(effects.count == 1)
        guard case .beginNextTrial = effects.first else {
            Issue.record("Expected .beginNextTrial")
            return
        }
    }

    // MARK: - Stop

    @Test("any non-idle state + stopRequested → idle, stopAll")
    func stopFromNonIdle() async {
        for startState: State in [.playingPattern, .awaitingAnswer, .showingFeedback, .waitingForGrid] {
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
        for startState: State in [.playingPattern, .awaitingAnswer, .showingFeedback, .waitingForGrid] {
            let (state, effects) = reduce(startState, .audioError)
            #expect(state == .idle)
            #expect(effects.count == 1)
            guard case .stopAll = effects.first else {
                Issue.record("Expected .stopAll on audioError from \(startState)")
                return
            }
        }
    }

    // MARK: - Invalid Transitions

    @Test("invalid transitions produce no state change and no effects")
    func invalidTransitions() async {
        let invalidCases: [(State, Event)] = [
            (.idle, .patternFinished),
            (.idle, .answerReceived(direction: .early)),
            (.idle, .feedbackTimerFired),
            (.idle, .gridAlignmentReached),
            (.playingPattern, .answerReceived(direction: .early)),
            (.playingPattern, .feedbackTimerFired),
            (.awaitingAnswer, .patternFinished),
            (.awaitingAnswer, .gridAlignmentReached),
            (.showingFeedback, .answerReceived(direction: .late)),
            (.showingFeedback, .gridAlignmentReached),
            (.waitingForGrid, .patternFinished),
            (.waitingForGrid, .answerReceived(direction: .late)),
        ]
        for (startState, event) in invalidCases {
            let (state, effects) = reduce(startState, event)
            #expect(state == startState, "State should not change for invalid transition \(startState) + \(event)")
            #expect(effects.isEmpty, "No effects for invalid transition \(startState) + \(event)")
        }
    }
}
