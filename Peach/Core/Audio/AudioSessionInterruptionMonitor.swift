import Foundation
import AVFoundation
import os

final class AudioSessionInterruptionMonitor {

    private let notificationCenter: NotificationCenter
    private let logger: Logger
    private let onStopRequired: () -> Void

    private var audioInterruptionObserver: NSObjectProtocol?
    private var audioRouteChangeObserver: NSObjectProtocol?
    private var backgroundObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?

    init(
        notificationCenter: NotificationCenter = .default,
        logger: Logger,
        backgroundNotificationName: Notification.Name? = nil,
        foregroundNotificationName: Notification.Name? = nil,
        onStopRequired: @escaping () -> Void
    ) {
        self.notificationCenter = notificationCenter
        self.logger = logger
        self.onStopRequired = onStopRequired

        setupObservers(
            backgroundNotificationName: backgroundNotificationName,
            foregroundNotificationName: foregroundNotificationName
        )
    }

    isolated deinit {
        if let observer = audioInterruptionObserver {
            notificationCenter.removeObserver(observer)
        }
        if let observer = audioRouteChangeObserver {
            notificationCenter.removeObserver(observer)
        }
        if let observer = backgroundObserver {
            notificationCenter.removeObserver(observer)
        }
        if let observer = foregroundObserver {
            notificationCenter.removeObserver(observer)
        }
    }

    // MARK: - Private

    private func setupObservers(
        backgroundNotificationName: Notification.Name?,
        foregroundNotificationName: Notification.Name?
    ) {
        audioInterruptionObserver = notificationCenter.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            Task { @MainActor [weak self] in
                self?.handleAudioInterruption(typeValue: typeValue)
            }
        }

        audioRouteChangeObserver = notificationCenter.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor [weak self] in
                self?.handleAudioRouteChange(reasonValue: reasonValue)
            }
        }

        if let backgroundNotificationName {
            backgroundObserver = notificationCenter.addObserver(
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
            foregroundObserver = notificationCenter.addObserver(
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

    private func handleAudioInterruption(typeValue: UInt?) {
        guard let typeValue = typeValue,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            logger.warning("Audio interruption notification received but could not parse type")
            return
        }

        switch type {
        case .began:
            logger.info("Audio interruption began - stopping")
            onStopRequired()
        case .ended:
            logger.info("Audio interruption ended - remains stopped")
        @unknown default:
            logger.warning("Unknown audio interruption type: \(typeValue)")
        }
    }

    private func handleAudioRouteChange(reasonValue: UInt?) {
        guard let reasonValue = reasonValue,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            logger.warning("Audio route change notification received but could not parse reason")
            return
        }

        switch reason {
        case .oldDeviceUnavailable:
            logger.warning("Audio device disconnected - stopping")
            onStopRequired()
        case .newDeviceAvailable, .categoryChange, .override, .wakeFromSleep, .noSuitableRouteForCategory, .routeConfigurationChange, .unknown:
            logger.info("Audio route changed (reason: \(reason.rawValue)) - continuing")
        @unknown default:
            logger.warning("Unknown audio route change reason: \(reasonValue)")
        }
    }
}
