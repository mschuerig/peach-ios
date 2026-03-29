#if os(iOS)
import AVFoundation
import os

/// Observes iOS audio interruptions (AVAudioSession) and route changes.
final class IOSAudioInterruptionObserver: AudioInterruptionObserving {

    private static let logger = Logger(subsystem: "com.peach.app", category: "AudioInterruption")

    private var onStopRequired: (() -> Void)?

    func setupObservers(
        notificationCenter: NotificationCenter,
        onStopRequired: @escaping () -> Void
    ) -> [NSObjectProtocol] {
        self.onStopRequired = onStopRequired

        let interruptionObserver = notificationCenter.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            Task { @MainActor [weak self] in
                self?.handleAudioInterruption(typeValue: typeValue)
            }
        }

        let routeChangeObserver = notificationCenter.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor [weak self] in
                self?.handleAudioRouteChange(reasonValue: reasonValue)
            }
        }

        return [interruptionObserver, routeChangeObserver]
    }

    // MARK: - Private

    private func handleAudioInterruption(typeValue: UInt?) {
        guard let typeValue,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            Self.logger.warning("Audio interruption notification received but could not parse type")
            return
        }

        switch type {
        case .began:
            Self.logger.info("Audio interruption began - stopping")
            onStopRequired?()
        case .ended:
            Self.logger.info("Audio interruption ended - remains stopped")
        @unknown default:
            Self.logger.warning("Unknown audio interruption type: \(typeValue)")
        }
    }

    private func handleAudioRouteChange(reasonValue: UInt?) {
        guard let reasonValue,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            Self.logger.warning("Audio route change notification received but could not parse reason")
            return
        }

        switch reason {
        case .oldDeviceUnavailable:
            Self.logger.warning("Audio device disconnected - stopping")
            onStopRequired?()
        case .newDeviceAvailable, .categoryChange, .override, .wakeFromSleep, .noSuitableRouteForCategory, .routeConfigurationChange, .unknown:
            Self.logger.info("Audio route changed (reason: \(reason.rawValue)) - continuing")
        @unknown default:
            Self.logger.warning("Unknown audio route change reason: \(reasonValue)")
        }
    }
}
#endif
