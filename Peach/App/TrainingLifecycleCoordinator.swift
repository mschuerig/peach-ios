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

struct ResolvedNavigation: Equatable {
    let destination: NavigationDestination
    private let id = UUID()

    static func == (lhs: ResolvedNavigation, rhs: ResolvedNavigation) -> Bool {
        lhs.id == rhs.id
    }
}

@Observable
final class TrainingLifecycleCoordinator {
    private let pitchDiscriminationSession: PitchDiscriminationSession
    private let pitchMatchingSession: PitchMatchingSession
    private let rhythmOffsetDetectionSession: RhythmOffsetDetectionSession
    private let continuousRhythmMatchingSession: ContinuousRhythmMatchingSession
    private let userSettings: any UserSettings
    private let backgroundPolicy: BackgroundPolicy
    var activeSession: (any TrainingSession)?

    private(set) var resolvedNavigation: ResolvedNavigation?
    private var navigationTask: Task<Void, Never>?

    private(set) var currentTrainingDestination: NavigationDestination?
    private var wasActiveBeforeHelpSheet = false

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
        self.autoStartSetting = userSettings.autoStartTraining
    }

    // MARK: - Computed Properties

    var isTrainingActive: Bool {
        guard let destination = currentTrainingDestination else { return false }
        switch destination {
        case .pitchDiscrimination: return !pitchDiscriminationSession.isIdle
        case .pitchMatching: return !pitchMatchingSession.isIdle
        case .rhythmOffsetDetection: return !rhythmOffsetDetectionSession.isIdle
        case .continuousRhythmMatching: return !continuousRhythmMatchingSession.isIdle
        case .settings, .profile: return false
        }
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
        case .rhythmOffsetDetection:
            rhythmOffsetDetectionSession.start(settings: .from(userSettings))
        case .continuousRhythmMatching:
            continuousRhythmMatchingSession.start(settings: .from(userSettings))
        case .settings, .profile:
            break
        }
    }

    func stopCurrentSession() {
        guard let destination = currentTrainingDestination else { return }
        switch destination {
        case .pitchDiscrimination: pitchDiscriminationSession.stop()
        case .pitchMatching: pitchMatchingSession.stop()
        case .rhythmOffsetDetection: rhythmOffsetDetectionSession.stop()
        case .continuousRhythmMatching: continuousRhythmMatchingSession.stop()
        case .settings, .profile: break
        }
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
            resolvedNavigation = ResolvedNavigation(destination: destination)
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
