import Observation
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

struct NavigationRequest: Equatable {
    let destination: NavigationDestination
    private let id = UUID()

    static func == (lhs: NavigationRequest, rhs: NavigationRequest) -> Bool {
        lhs.id == rhs.id
    }
}

@Observable
final class TrainingLifecycleCoordinator {
    private let pitchDiscriminationSession: PitchDiscriminationSession
    private let pitchMatchingSession: PitchMatchingSession
    private let timingOffsetDetectionSession: TimingOffsetDetectionSession
    private let continuousRhythmMatchingSession: ContinuousRhythmMatchingSession
    private let userSettings: any UserSettings
    private let backgroundPolicy: BackgroundPolicy
    var activeSession: (any TrainingSession)?

    private(set) var resolvedNavigation: NavigationRequest?
    private var navigationTask: Task<Void, Never>?

    private(set) var currentTrainingDestination: NavigationDestination?
    private var wasActiveBeforeHelpSheet = false

    private static let logger = Logger(subsystem: "com.peach.app", category: "Lifecycle")

    init(
        pitchDiscriminationSession: PitchDiscriminationSession,
        pitchMatchingSession: PitchMatchingSession,
        timingOffsetDetectionSession: TimingOffsetDetectionSession,
        continuousRhythmMatchingSession: ContinuousRhythmMatchingSession,
        userSettings: any UserSettings,
        backgroundPolicy: BackgroundPolicy
    ) {
        self.pitchDiscriminationSession = pitchDiscriminationSession
        self.pitchMatchingSession = pitchMatchingSession
        self.timingOffsetDetectionSession = timingOffsetDetectionSession
        self.continuousRhythmMatchingSession = continuousRhythmMatchingSession
        self.userSettings = userSettings
        self.backgroundPolicy = backgroundPolicy
        self.autoStartSetting = userSettings.autoStartTraining
    }

    // MARK: - Computed Properties

    private func session(for destination: NavigationDestination) -> (any TrainingSession)? {
        switch destination {
        case .pitchDiscrimination: pitchDiscriminationSession
        case .pitchMatching: pitchMatchingSession
        case .timingOffsetDetection: timingOffsetDetectionSession
        case .continuousRhythmMatching: continuousRhythmMatchingSession
        case .settings, .profile: nil
        }
    }

    private var currentSession: (any TrainingSession)? {
        guard let destination = currentTrainingDestination else { return nil }
        return session(for: destination)
    }

    var isTrainingActive: Bool {
        guard let session = currentSession else { return false }
        return !session.isIdle
    }

    var shouldAutoStartTraining: Bool {
        backgroundPolicy.shouldAutoStartTraining || autoStartSetting
    }

    /// User preference for auto-starting training (macOS only, persisted via UserDefaults).
    /// On iOS, `backgroundPolicy.shouldAutoStartTraining` is always true, so this has no effect.
    var autoStartSetting: Bool

    // MARK: - Scene Phase

    func handleScenePhase(old: ScenePhase, new: ScenePhase) {
        let appPhase = AppScenePhase(new)
        if backgroundPolicy.shouldStopTraining(newPhase: appPhase) {
            Self.logger.info("App leaving active state (\(String(describing: new))) — stopping active session")
            stopCurrentSession()
        }
        if appPhase == .active && shouldAutoStartTraining
            && currentTrainingDestination != nil && !isTrainingActive {
            Self.logger.info("App returned to active — auto-restarting training")
            startCurrentSession()
        }
    }

    // MARK: - macOS App Activation (NSApplication notifications)

    func handleAppDeactivated() {
        Self.logger.info("App deactivated — stopping current session")
        stopCurrentSession()
    }

    func handleAppActivated() {
        guard shouldAutoStartTraining,
              currentTrainingDestination != nil,
              !isTrainingActive else { return }
        Self.logger.info("App activated — auto-restarting training")
        startCurrentSession()
    }

    // MARK: - Training Screen Lifecycle

    func trainingScreenAppeared(destination: NavigationDestination) {
        currentTrainingDestination = destination
        if shouldAutoStartTraining {
            startCurrentSession()
        }
    }

    func trainingScreenDisappeared() {
        stopCurrentSession()
        currentTrainingDestination = nil
    }

    func helpSheetPresented() {
        wasActiveBeforeHelpSheet = isTrainingActive
        stopCurrentSession()
    }

    func helpSheetDismissed() {
        if shouldAutoStartTraining || wasActiveBeforeHelpSheet {
            startCurrentSession()
        }
    }

    func toggleTraining() {
        if isTrainingActive {
            stopCurrentSession()
        } else {
            startCurrentSession()
        }
    }

    func startCurrentSession() {
        guard let destination = currentTrainingDestination else { return }
        switch destination {
        case .pitchDiscrimination(let isIntervalMode):
            let intervals: Set<DirectedInterval> = isIntervalMode ? userSettings.intervals : [.prime]
            pitchDiscriminationSession.start(settings: .from(userSettings, intervals: intervals))
        case .pitchMatching(let isIntervalMode):
            let intervals: Set<DirectedInterval> = isIntervalMode ? userSettings.intervals : [.prime]
            pitchMatchingSession.start(settings: .from(userSettings, intervals: intervals))
        case .timingOffsetDetection:
            timingOffsetDetectionSession.start(settings: .from(userSettings))
        case .continuousRhythmMatching:
            continuousRhythmMatchingSession.start(settings: .from(userSettings))
        case .settings, .profile:
            break
        }
    }

    func stopCurrentSession() {
        currentSession?.stop()
    }

    // MARK: - Menu Navigation

    func navigate(to destination: NavigationDestination) {
        navigationTask?.cancel()
        navigationTask = Task {
            if let session = activeSession, !session.isIdle {
                session.stop()
                await awaitIdle(of: session)
            }
            guard !Task.isCancelled else { return }
            Self.logger.info("Menu navigation resolved to \(String(describing: destination))")
            resolvedNavigation = NavigationRequest(destination: destination)
        }
    }

    private func awaitIdle(of session: any TrainingSession) async {
        while !session.isIdle {
            await withCheckedContinuation { continuation in
                withObservationTracking {
                    _ = session.isIdle
                } onChange: {
                    continuation.resume()
                }
            }
        }
    }
}
