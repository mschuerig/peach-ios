import Testing
@testable import Peach

/// Pure state transition tests for PitchDiscriminationSession.reduce.
/// No mocks, no async — tests the reducer as a pure function.
@Suite("PitchDiscriminationSession.reduce")
struct PitchDiscriminationReduceTests {

    typealias State = PitchDiscriminationSessionState
    typealias Event = PitchDiscriminationSession.Event
    typealias Effect = PitchDiscriminationSession.Effect

    private func reduce(_ state: State, _ event: Event) -> (State, [Effect]) {
        var s = state
        let effects = PitchDiscriminationSession.reduce(state: &s, event: event)
        return (s, effects)
    }

    // MARK: - Start

    @Test("idle + startRequested → playingReferenceNote, beginNextTrial")
    func startFromIdle() async {
        let (state, effects) = reduce(.idle, .startRequested)
        #expect(state == .playingReferenceNote)
        #expect(effects.count == 1)
        guard case .beginNextTrial = effects.first else {
            Issue.record("Expected .beginNextTrial")
            return
        }
    }

    @Test("non-idle + startRequested → no change")
    func startFromNonIdle() async {
        let (state, effects) = reduce(.playingReferenceNote, .startRequested)
        #expect(state == .playingReferenceNote)
        #expect(effects.isEmpty)
    }

    // MARK: - Reference Phase

    @Test("playingReferenceNote + referencePhaseCompleted → playingTargetNote, playTargetNote")
    func referencePhaseCompleted() async {
        let (state, effects) = reduce(.playingReferenceNote, .referencePhaseCompleted)
        #expect(state == .playingTargetNote)
        #expect(effects.count == 1)
        guard case .playTargetNote = effects.first else {
            Issue.record("Expected .playTargetNote")
            return
        }
    }

    // MARK: - Target Note

    @Test("playingTargetNote + targetNoteFinished → awaitingAnswer, no effects")
    func targetNoteFinished() async {
        let (state, effects) = reduce(.playingTargetNote, .targetNoteFinished)
        #expect(state == .awaitingAnswer)
        #expect(effects.isEmpty)
    }

    @Test("playingTargetNote + answerReceived → showingFeedback with stopNote, evaluateAnswer, scheduleFeedbackTimer")
    func earlyAnswerDuringTarget() async {
        let (state, effects) = reduce(.playingTargetNote, .answerReceived(isHigher: true))
        #expect(state == .showingFeedback)
        #expect(effects.count == 3)
        guard case .stopNote = effects[0] else {
            Issue.record("Expected .stopNote first")
            return
        }
        guard case .evaluateAnswer(let isHigher) = effects[1] else {
            Issue.record("Expected .evaluateAnswer second")
            return
        }
        #expect(isHigher == true)
        guard case .scheduleFeedbackTimer = effects[2] else {
            Issue.record("Expected .scheduleFeedbackTimer third")
            return
        }
    }

    // MARK: - Awaiting Answer

    @Test("awaitingAnswer + answerReceived → showingFeedback with evaluateAnswer, scheduleFeedbackTimer")
    func answerFromAwaiting() async {
        let (state, effects) = reduce(.awaitingAnswer, .answerReceived(isHigher: false))
        #expect(state == .showingFeedback)
        #expect(effects.count == 2)
        guard case .evaluateAnswer(let isHigher) = effects[0] else {
            Issue.record("Expected .evaluateAnswer first")
            return
        }
        #expect(isHigher == false)
        guard case .scheduleFeedbackTimer = effects[1] else {
            Issue.record("Expected .scheduleFeedbackTimer second")
            return
        }
    }

    // MARK: - Feedback

    @Test("showingFeedback + feedbackTimerFired → playingReferenceNote, beginNextTrial")
    func feedbackTimerFired() async {
        let (state, effects) = reduce(.showingFeedback, .feedbackTimerFired)
        #expect(state == .playingReferenceNote)
        #expect(effects.count == 1)
        guard case .beginNextTrial = effects.first else {
            Issue.record("Expected .beginNextTrial")
            return
        }
    }

    // MARK: - Stop

    @Test("any non-idle state + stopRequested → idle, stopAll")
    func stopFromNonIdle() async {
        for startState: State in [.playingReferenceNote, .playingTargetNote, .awaitingAnswer, .showingFeedback] {
            let (state, effects) = reduce(startState, .stopRequested)
            #expect(state == .idle)
            #expect(effects.count == 1)
            guard case .stopAll = effects.first else {
                Issue.record("Expected .stopAll from \(startState)")
                return
            }
        }
    }

    @Test("idle + stopRequested → no change, no effects")
    func stopFromIdle() async {
        let (state, effects) = reduce(.idle, .stopRequested)
        #expect(state == .idle)
        #expect(effects.isEmpty)
    }

    // MARK: - Audio Error

    @Test("any non-idle state + audioError → idle, stopAll")
    func audioErrorFromNonIdle() async {
        for startState: State in [.playingReferenceNote, .playingTargetNote, .awaitingAnswer, .showingFeedback] {
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
            (.idle, .referencePhaseCompleted),
            (.idle, .targetNoteFinished),
            (.idle, .feedbackTimerFired),
            (.playingReferenceNote, .answerReceived(isHigher: true)),
            (.playingReferenceNote, .feedbackTimerFired),
            (.awaitingAnswer, .referencePhaseCompleted),
            (.awaitingAnswer, .targetNoteFinished),
            (.showingFeedback, .answerReceived(isHigher: true)),
            (.showingFeedback, .referencePhaseCompleted),
        ]
        for (startState, event) in invalidCases {
            let (state, effects) = reduce(startState, event)
            #expect(state == startState, "State should not change for invalid transition \(startState) + \(event)")
            #expect(effects.isEmpty, "No effects for invalid transition \(startState) + \(event)")
        }
    }
}
