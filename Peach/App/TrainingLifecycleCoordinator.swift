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
    private let registry: TrainingLifecycleRegistry
    private let backgroundPolicy: BackgroundPolicy
    var activeSession: (any TrainingSession)?

    private(set) var resolvedNavigation: NavigationRequest?
    private var navigationTask: Task<Void, Never>?

    private(set) var currentTrainingDestination: NavigationDestination?

    /// Destination whose session was paused by a transient lifecycle event
    /// (training-screen disappear, help-sheet present). Tracking the
    /// destination instead of the session instance avoids coupling to the
    /// registry's instance-identity guarantee.
    private var pausedDestination: NavigationDestination?

    private static let logger = Logger(subsystem: "com.peach.app", category: "Lifecycle")

    init(
        registry: TrainingLifecycleRegistry,
        backgroundPolicy: BackgroundPolicy,
        initialAutoStartSetting: Bool
    ) {
        self.registry = registry
        self.backgroundPolicy = backgroundPolicy
        self.autoStartSetting = initialAutoStartSetting
    }

    // MARK: - Computed Properties

    private var currentSession: (any TrainingSession)? {
        guard let destination = currentTrainingDestination else { return nil }
        return registry.contribution(for: destination)?.session
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
        if pausedDestination == destination {
            currentTrainingDestination = destination
            registry.contribution(for: destination)?.session.resume()
            pausedDestination = nil
        } else {
            discardLingeringPausedSession()
            currentTrainingDestination = destination
            if shouldAutoStartTraining {
                startCurrentSession()
            }
        }
    }

    func trainingScreenDisappeared() {
        guard let destination = currentTrainingDestination,
              let session = registry.contribution(for: destination)?.session,
              !session.isIdle else {
            currentTrainingDestination = nil
            return
        }
        discardLingeringPausedSession()
        pausedDestination = destination
        session.pause()
        currentTrainingDestination = nil
    }

    /// Pop-to-Start signal — nav-push and nav-pop produce identical
    /// `onDisappear` events at the modifier level, so without this hook a
    /// paused session would linger until another lifecycle event arrived.
    func startScreenAppeared() {
        discardLingeringPausedSession()
    }

    func helpSheetPresented() {
        guard let destination = currentTrainingDestination,
              let session = registry.contribution(for: destination)?.session,
              !session.isIdle else { return }
        discardLingeringPausedSession()
        pausedDestination = destination
        session.pause()
    }

    func helpSheetDismissed() {
        if let pausedDest = pausedDestination,
           let paused = registry.contribution(for: pausedDest)?.session {
            paused.resume()
            pausedDestination = nil
        } else if shouldAutoStartTraining {
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
        discardLingeringPausedSession()
        registry.contribution(for: destination)?.start()
    }

    func stopCurrentSession() {
        discardLingeringPausedSession()
        currentSession?.stop()
    }

    /// Stops any session paused for a no-longer-current destination. Idempotent.
    private func discardLingeringPausedSession() {
        guard let dest = pausedDestination,
              let paused = registry.contribution(for: dest)?.session else {
            pausedDestination = nil
            return
        }
        paused.stop()
        pausedDestination = nil
    }

    // MARK: - Menu Navigation

    func navigate(to destination: NavigationDestination) {
        navigationTask?.cancel()
        navigationTask = Task {
            discardLingeringPausedSession()
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
