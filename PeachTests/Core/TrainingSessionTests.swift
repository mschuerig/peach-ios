import Foundation
import Testing
@testable import Peach

@Suite("TrainingSession Protocol")
struct TrainingSessionTests {

    @Test("ComparisonSession conforms to TrainingSession")
    func comparisonSessionConformsToTrainingSession() async {
        let fixture = makeComparisonSession()
        let trainingSession: TrainingSession = fixture.session
        #expect(trainingSession.isIdle)
    }

    @Test("PitchMatchingSession conforms to TrainingSession")
    func pitchMatchingSessionConformsToTrainingSession() async {
        let (session, _, _, _, _) = makePitchMatchingSession()
        let trainingSession: TrainingSession = session
        #expect(trainingSession.isIdle)
    }

    @Test("ComparisonSession.isIdle returns false when active")
    func comparisonSessionIsIdleFalseWhenActive() async throws {
        let fixture = makeComparisonSession()
        fixture.session.start()
        try await waitForState(fixture.session, .awaitingAnswer)
        let trainingSession: TrainingSession = fixture.session
        #expect(!trainingSession.isIdle)
        trainingSession.stop()
    }

    @Test("PitchMatchingSession.isIdle returns false when active")
    func pitchMatchingSessionIsIdleFalseWhenActive() async throws {
        let (session, _, _, _, _) = makePitchMatchingSession()
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)
        let trainingSession: TrainingSession = session
        #expect(!trainingSession.isIdle)
        trainingSession.stop()
    }

    @Test("stop() through TrainingSession protocol stops ComparisonSession")
    func stopThroughProtocolStopsComparisonSession() async throws {
        let fixture = makeComparisonSession()
        fixture.session.start()
        try await waitForState(fixture.session, .awaitingAnswer)
        let trainingSession: TrainingSession = fixture.session
        trainingSession.stop()
        #expect(fixture.session.state == .idle)
    }

    @Test("stop() through TrainingSession protocol stops PitchMatchingSession")
    func stopThroughProtocolStopsPitchMatchingSession() async throws {
        let (session, _, _, _, _) = makePitchMatchingSession()
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)
        let trainingSession: TrainingSession = session
        trainingSession.stop()
        #expect(session.state == .idle)
    }
}
