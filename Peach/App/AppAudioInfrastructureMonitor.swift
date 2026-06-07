import Foundation
import os

/// App-scoped audio infrastructure observer.
///
/// One instance per app lifetime, wired at composition root. Routes the three
/// iOS audio-lifecycle notifications to the lifecycle coordinator:
///
/// - `interruptionNotification` + `routeChangeNotification`.`oldDeviceUnavailable`
///   → `coordinator.handleAudioStopRequired()` (after the iOS observer's
///   `.appWasSuspended` filter)
/// - `mediaServicesWereResetNotification` → `coordinator.handleMediaServicesReset()`
/// - `mediaServicesWereLostNotification` → `coordinator.handleMediaServicesLost()`
///
/// On macOS the underlying observer is a no-op and these closures never fire.
// Explicit @MainActor: workaround in the family of swiftlang/swift#88173
// and #85663 (default-isolation + isolated deinit + -O fragility).
// Without it, Research-config test builds fail with
// "Deinit is marked isolated, but containing class is not isolated to an actor".
@MainActor
final class AppAudioInfrastructureMonitor {

    private static let logger = Logger(subsystem: "com.peach.app", category: "AudioInfrastructureMonitor")

    private let notificationCenter: NotificationCenter
    private let observer: AudioInterruptionObserving
    private var observerTokens: [NSObjectProtocol] = []

    init(
        notificationCenter: NotificationCenter = .default,
        observer: AudioInterruptionObserving,
        coordinator: TrainingLifecycleCoordinator
    ) {
        self.notificationCenter = notificationCenter
        self.observer = observer

        self.observerTokens = observer.setupObservers(
            notificationCenter: notificationCenter,
            onStopRequired: { [weak coordinator] in coordinator?.handleAudioStopRequired() },
            onMediaServicesLost: { [weak coordinator] in coordinator?.handleMediaServicesLost() },
            onMediaServicesReset: { [weak coordinator] in coordinator?.handleMediaServicesReset() }
        )

        Self.logger.info("App-scoped audio infrastructure monitor installed")
    }

    isolated deinit {
        for token in observerTokens {
            notificationCenter.removeObserver(token)
        }
    }
}
