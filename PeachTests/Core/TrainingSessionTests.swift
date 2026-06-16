import Foundation
import Testing
@testable import Peach

@Suite("TrainingSession Protocol")
struct TrainingSessionTests {

    @Test("PitchDiscriminationSession conforms to TrainingSession")
    func pitchDiscriminationSessionConformsToTrainingSession() async {
        let fixture = makePitchDiscriminationSession()
        let trainingSession: TrainingSession = fixture.session
        #expect(trainingSession.isIdle)
    }

    @Test("PitchMatchingSession conforms to TrainingSession")
    func pitchMatchingSessionConformsToTrainingSession() async {
        let (session, _, _, _) = makePitchMatchingSession()
        let trainingSession: TrainingSession = session
        #expect(trainingSession.isIdle)
    }

    @Test("PitchDiscriminationSession.isIdle returns false when active")
    func pitchDiscriminationSessionIsIdleFalseWhenActive() async throws {
        let fixture = makePitchDiscriminationSession()
        fixture.session.start(settings: defaultTestSettings)
        try await waitForState(fixture.session, .awaitingAnswer)
        let trainingSession: TrainingSession = fixture.session
        #expect(trainingSession.isIdle == false)
        trainingSession.stop()
    }

    @Test("PitchMatchingSession.isIdle returns false when active")
    func pitchMatchingSessionIsIdleFalseWhenActive() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)
        let trainingSession: TrainingSession = session
        #expect(trainingSession.isIdle == false)
        trainingSession.stop()
    }

    @Test("stop() through TrainingSession protocol stops PitchDiscriminationSession")
    func stopThroughProtocolStopsPitchDiscriminationSession() async throws {
        let fixture = makePitchDiscriminationSession()
        fixture.session.start(settings: defaultTestSettings)
        try await waitForState(fixture.session, .awaitingAnswer)
        let trainingSession: TrainingSession = fixture.session
        trainingSession.stop()
        #expect(fixture.session.state == .idle)
    }

    @Test("stop() through TrainingSession protocol stops PitchMatchingSession")
    func stopThroughProtocolStopsPitchMatchingSession() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)
        let trainingSession: TrainingSession = session
        trainingSession.stop()
        #expect(session.state == .idle)
    }
}
