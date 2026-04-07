import Testing
@testable import Peach

/// Pure state transition tests for PitchMatchingSession.reduce.
@Suite("PitchMatchingSession.reduce")
struct PitchMatchingReduceTests {

    typealias State = PitchMatchingSessionState
    typealias Event = PitchMatchingSession.Event
    typealias Effect = PitchMatchingSession.Effect

    private func reduce(_ state: State, _ event: Event) -> (State, [Effect]) {
        var s = state
        let effects = PitchMatchingSession.reduce(state: &s, event: event)
        return (s, effects)
    }

    // MARK: - Start

    @Test("idle + startRequested → playingReference, beginNextTrial")
    func startFromIdle() async {
        let (state, effects) = reduce(.idle, .startRequested)
        #expect(state == .playingReference)
        #expect(effects.count == 1)
        guard case .beginNextTrial = effects.first else {
            Issue.record("Expected .beginNextTrial")
            return
        }
    }

    // MARK: - Reference Note

    @Test("playingReference + referenceNoteFinished → awaitingSliderTouch, no effects")
    func referenceFinished() async {
        let (state, effects) = reduce(.playingReference, .referenceNoteFinished)
        #expect(state == .awaitingSliderTouch)
        #expect(effects.isEmpty)
    }

    // MARK: - Slider Touch

    @Test("awaitingSliderTouch + sliderTouched → playingTunable, startTunablePlayback")
    func sliderTouched() async {
        let (state, effects) = reduce(.awaitingSliderTouch, .sliderTouched)
        #expect(state == .playingTunable)
        #expect(effects.count == 1)
        guard case .startTunablePlayback = effects.first else {
            Issue.record("Expected .startTunablePlayback")
            return
        }
    }

    // MARK: - Pitch Commit

    @Test("awaitingSliderTouch + pitchCommitted → showingFeedback (early commit)")
    func earlyCommit() async {
        let freq = Frequency(440.0)
        let (state, effects) = reduce(.awaitingSliderTouch, .pitchCommitted(userFrequency: freq))
        #expect(state == .showingFeedback)
        #expect(effects.count == 2)
        guard case .evaluateResult(let f) = effects[0] else {
            Issue.record("Expected .evaluateResult first")
            return
        }
        #expect(f == freq)
        guard case .scheduleFeedbackTimer = effects[1] else {
            Issue.record("Expected .scheduleFeedbackTimer second")
            return
        }
    }

    @Test("playingTunable + pitchCommitted → showingFeedback with stopPlayback")
    func normalCommit() async {
        let freq = Frequency(440.0)
        let (state, effects) = reduce(.playingTunable, .pitchCommitted(userFrequency: freq))
        #expect(state == .showingFeedback)
        #expect(effects.count == 3)
        guard case .stopPlayback = effects[0] else {
            Issue.record("Expected .stopPlayback first")
            return
        }
        guard case .evaluateResult(let f) = effects[1] else {
            Issue.record("Expected .evaluateResult second")
            return
        }
        #expect(f == freq)
        guard case .scheduleFeedbackTimer = effects[2] else {
            Issue.record("Expected .scheduleFeedbackTimer third")
            return
        }
    }

    // MARK: - Feedback

    @Test("showingFeedback + feedbackTimerFired → playingReference, beginNextTrial")
    func feedbackTimerFired() async {
        let (state, effects) = reduce(.showingFeedback, .feedbackTimerFired)
        #expect(state == .playingReference)
        #expect(effects.count == 1)
        guard case .beginNextTrial = effects.first else {
            Issue.record("Expected .beginNextTrial")
            return
        }
    }

    // MARK: - Stop

    @Test("any non-idle state + stopRequested → idle, stopAll")
    func stopFromNonIdle() async {
        for startState: State in [.playingReference, .awaitingSliderTouch, .playingTunable, .showingFeedback] {
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
        for startState: State in [.playingReference, .awaitingSliderTouch, .playingTunable, .showingFeedback] {
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
            (.idle, .referenceNoteFinished),
            (.idle, .sliderTouched),
            (.idle, .feedbackTimerFired),
            (.playingReference, .sliderTouched),
            (.playingReference, .pitchCommitted(userFrequency: Frequency(440.0))),
            (.playingTunable, .referenceNoteFinished),
            (.playingTunable, .sliderTouched),
            (.showingFeedback, .sliderTouched),
            (.showingFeedback, .pitchCommitted(userFrequency: Frequency(440.0))),
        ]
        for (startState, event) in invalidCases {
            let (state, effects) = reduce(startState, event)
            #expect(state == startState, "State should not change for invalid transition \(startState) + \(event)")
            #expect(effects.isEmpty, "No effects for invalid transition \(startState) + \(event)")
        }
    }
}
