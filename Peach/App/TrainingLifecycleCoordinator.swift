import SwiftUI
import os

extension AppScenePhase {
    init(_ scenePhase: ScenePhase) {
        switch scenePhase {
        case .active: self = .active
        case .inactive: self = .inactive
        case .background: self = .background
        @unknown default: self = .inactive
        }
    }
}

final class TrainingLifecycleCoordinator {
    private let pitchDiscriminationSession: PitchDiscriminationSession
    private let pitchMatchingSession: PitchMatchingSession
    private let rhythmOffsetDetectionSession: RhythmOffsetDetectionSession
    private let continuousRhythmMatchingSession: ContinuousRhythmMatchingSession
    private let userSettings: any UserSettings
    private let backgroundPolicy: BackgroundPolicy
    var activeSession: (any TrainingSession)?

    private static let logger = Logger(subsystem: "com.peach.app", category: "Lifecycle")

    init(
        pitchDiscriminationSession: PitchDiscriminationSession,
        pitchMatchingSession: PitchMatchingSession,
        rhythmOffsetDetectionSession: RhythmOffsetDetectionSession,
        continuousRhythmMatchingSession: ContinuousRhythmMatchingSession,
        userSettings: any UserSettings,
        backgroundPolicy: BackgroundPolicy
    ) {
        self.pitchDiscriminationSession = pitchDiscriminationSession
        self.pitchMatchingSession = pitchMatchingSession
        self.rhythmOffsetDetectionSession = rhythmOffsetDetectionSession
        self.continuousRhythmMatchingSession = continuousRhythmMatchingSession
        self.userSettings = userSettings
        self.backgroundPolicy = backgroundPolicy
    }

    // MARK: - Scene Phase

    func handleScenePhase(old: ScenePhase, new: ScenePhase, clearNavigation: () -> Void) {
        let appPhase = AppScenePhase(new)
        if backgroundPolicy.shouldStopTraining(newPhase: appPhase) {
            Self.logger.info("App leaving active state (\(String(describing: new))) — stopping active session")
            activeSession?.stop()
        }
        if new == .active && (old == .background || old == .inactive) {
            Self.logger.info("App returned to active from \(String(describing: old)) — clearing navigation")
            clearNavigation()
        }
    }

    // MARK: - Pitch Discrimination

    func startPitchDiscrimination(intervals: Set<DirectedInterval>) {
        pitchDiscriminationSession.start(settings: .from(userSettings, intervals: intervals))
    }

    func stopPitchDiscrimination() {
        pitchDiscriminationSession.stop()
    }

    // MARK: - Pitch Matching

    func startPitchMatching(intervals: Set<DirectedInterval>) {
        pitchMatchingSession.start(settings: .from(userSettings, intervals: intervals))
    }

    func stopPitchMatching() {
        pitchMatchingSession.stop()
    }

    // MARK: - Rhythm Offset Detection

    func startRhythmOffsetDetection() {
        rhythmOffsetDetectionSession.start(settings: .from(userSettings))
    }

    func stopRhythmOffsetDetection() {
        rhythmOffsetDetectionSession.stop()
    }

    // MARK: - Continuous Rhythm Matching

    func startContinuousRhythmMatching() {
        continuousRhythmMatchingSession.start(settings: .from(userSettings))
    }

    func stopContinuousRhythmMatching() {
        continuousRhythmMatchingSession.stop()
    }
}
