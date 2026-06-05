import Foundation
import os

// Explicit @MainActor: workaround in the family of swiftlang/swift#88173
// and #85663 (default-isolation + isolated deinit + -O fragility).
// Without it, Research-config test builds fail with
// "Deinit is marked isolated, but containing class is not isolated to an actor".
@MainActor
final class AudioSessionInterruptionMonitor {

    private let notificationCenter: NotificationCenter
    private let logger: Logger
    private let onStopRequired: () -> Void
    private let audioInterruptionObserver: AudioInterruptionObserving

    private var observerTokens: [NSObjectProtocol] = []

    init(
        notificationCenter: NotificationCenter = .default,
        logger: Logger,
        audioInterruptionObserver: AudioInterruptionObserving,
        onStopRequired: @escaping () -> Void
    ) {
        self.notificationCenter = notificationCenter
        self.logger = logger
        self.onStopRequired = onStopRequired
        self.audioInterruptionObserver = audioInterruptionObserver

        self.observerTokens = audioInterruptionObserver.setupObservers(
            notificationCenter: notificationCenter,
            onStopRequired: onStopRequired
        )

        logger.info("Audio interruption observers setup complete")
    }

    isolated deinit {
        for observer in observerTokens {
            notificationCenter.removeObserver(observer)
        }
    }

}
