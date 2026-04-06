import Foundation
import os

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
        backgroundNotificationName: Notification.Name? = nil,
        foregroundNotificationName: Notification.Name? = nil,
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

        for name in [backgroundNotificationName, foregroundNotificationName].compactMap({ $0 }) {
            let token = notificationCenter.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.onStopRequired()
                }
            }
            observerTokens.append(token)
        }

        logger.info("Audio interruption observers setup complete")
    }

    isolated deinit {
        for observer in observerTokens {
            notificationCenter.removeObserver(observer)
        }
    }

}
