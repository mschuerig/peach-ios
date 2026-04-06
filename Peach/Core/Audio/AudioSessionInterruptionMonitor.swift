import Foundation
import os

final class AudioSessionInterruptionMonitor {

    private let notificationCenter: NotificationCenter
    private let logger: Logger
    private let onStopRequired: () -> Void
    private let audioInterruptionObserver: AudioInterruptionObserving

    private var audioObserverTokens: [NSObjectProtocol] = []
    private var backgroundObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?

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

        self.audioObserverTokens = audioInterruptionObserver.setupObservers(
            notificationCenter: notificationCenter,
            onStopRequired: onStopRequired
        )

        // WALKTHROUGH: backgroundObserver and foregroundObserver have identical handlers —
        // both just call onStopRequired(). Simplify to a single [Notification.Name] parameter
        // (e.g. lifecycleNotificationNames) and register one observer per name in a loop.
        // The foreground stop may also be redundant: if we already stopped on background,
        // there's nothing left to stop on return.
        if let backgroundNotificationName {
            self.backgroundObserver = notificationCenter.addObserver(
                forName: backgroundNotificationName,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.onStopRequired()
                }
            }
        }

        if let foregroundNotificationName {
            self.foregroundObserver = notificationCenter.addObserver(
                forName: foregroundNotificationName,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.onStopRequired()
                }
            }
        }

        logger.info("Audio interruption observers setup complete")
    }

    isolated deinit {
        for observer in audioObserverTokens {
            notificationCenter.removeObserver(observer)
        }
        if let observer = backgroundObserver {
            notificationCenter.removeObserver(observer)
        }
        if let observer = foregroundObserver {
            notificationCenter.removeObserver(observer)
        }
    }

}
