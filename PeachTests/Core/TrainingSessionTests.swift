import Foundation
import Testing
@testable import Peach

@Suite("TrainingSession Protocol")
struct TrainingSessionTests {

    @Test("PitchComparisonSession conforms to TrainingSession")
    func pitchComparisonSessionConformsToTrainingSession() async {
        let fixture = makePitchComparisonSession()
        let trainingSession: TrainingSession = fixture.session
        #expect(trainingSession.isIdle)
    }

    @Test("PitchMatchingSession conforms to TrainingSession")
    func pitchMatchingSessionConformsToTrainingSession() async {
        let (session, _, _, _) = makePitchMatchingSession()
        let trainingSession: TrainingSession = session
        #expect(trainingSession.isIdle)
    }

    @Test("PitchComparisonSession.isIdle returns false when active")
    func pitchComparisonSessionIsIdleFalseWhenActive() async throws {
        let fixture = makePitchComparisonSession()
        fixture.session.start(settings: defaultTestSettings)
        try await waitForState(fixture.session, .awaitingAnswer)
        let trainingSession: TrainingSession = fixture.session
        #expect(!trainingSession.isIdle)
        trainingSession.stop()
    }

    @Test("PitchMatchingSession.isIdle returns false when active")
    func pitchMatchingSessionIsIdleFalseWhenActive() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)
        let trainingSession: TrainingSession = session
        #expect(!trainingSession.isIdle)
        trainingSession.stop()
    }

    @Test("stop() through TrainingSession protocol stops PitchComparisonSession")
    func stopThroughProtocolStopsPitchComparisonSession() async throws {
        let fixture = makePitchComparisonSession()
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
