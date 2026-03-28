import Foundation

final class TrainingLifecycleCoordinator {
    let pitchDiscriminationSession: PitchDiscriminationSession?
    let pitchMatchingSession: PitchMatchingSession?
    let rhythmOffsetDetectionSession: RhythmOffsetDetectionSession?
    let continuousRhythmMatchingSession: ContinuousRhythmMatchingSession?
    let userSettings: (any UserSettings)?

    init(
        pitchDiscriminationSession: PitchDiscriminationSession? = nil,
        pitchMatchingSession: PitchMatchingSession? = nil,
        rhythmOffsetDetectionSession: RhythmOffsetDetectionSession? = nil,
        continuousRhythmMatchingSession: ContinuousRhythmMatchingSession? = nil,
        userSettings: (any UserSettings)? = nil
    ) {
        self.pitchDiscriminationSession = pitchDiscriminationSession
        self.pitchMatchingSession = pitchMatchingSession
        self.rhythmOffsetDetectionSession = rhythmOffsetDetectionSession
        self.continuousRhythmMatchingSession = continuousRhythmMatchingSession
        self.userSettings = userSettings
    }

    func startPitchDiscrimination(intervals: Set<DirectedInterval>) {
        guard let userSettings else { return }
        pitchDiscriminationSession?.start(settings: .from(userSettings, intervals: intervals))
    }

    func stopPitchDiscrimination() {
        pitchDiscriminationSession?.stop()
    }

    func startPitchMatching(intervals: Set<DirectedInterval>) {
        guard let userSettings else { return }
        pitchMatchingSession?.start(settings: .from(userSettings, intervals: intervals))
    }

    func stopPitchMatching() {
        pitchMatchingSession?.stop()
    }

    func startRhythmOffsetDetection() {
        guard let userSettings else { return }
        rhythmOffsetDetectionSession?.start(settings: .from(userSettings))
    }

    func stopRhythmOffsetDetection() {
        rhythmOffsetDetectionSession?.stop()
    }

    func startContinuousRhythmMatching() {
        guard let userSettings else { return }
        continuousRhythmMatchingSession?.start(settings: .from(userSettings))
    }

    func stopContinuousRhythmMatching() {
        continuousRhythmMatchingSession?.stop()
    }
}
