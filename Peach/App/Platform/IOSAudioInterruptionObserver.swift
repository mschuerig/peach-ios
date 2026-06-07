#if os(iOS)
import AVFoundation
import os

/// Observes iOS audio interruptions (AVAudioSession) and route changes.
final class IOSAudioInterruptionObserver: AudioInterruptionObserving {

    private static let logger = Logger(subsystem: "com.peach.app", category: "AudioInterruption")

    /// Raw value of `AVAudioSession.InterruptionReason.appWasSuspended` — used
    /// to compare without naming the deprecated enum case (the case is marked
    /// deprecated on iOS 16+ with the note "wasSuspended reason no longer
    /// present"; see PF-055 / PF-066).
    private static let appWasSuspendedReasonRawValue: UInt = 1

    private var onStopRequired: (() -> Void)?
    private var onMediaServicesLost: (() -> Void)?
    private var onMediaServicesReset: (() -> Void)?

    func setupObservers(
        notificationCenter: NotificationCenter,
        onStopRequired: @escaping () -> Void,
        onMediaServicesLost: @escaping () -> Void,
        onMediaServicesReset: @escaping () -> Void
    ) -> [NSObjectProtocol] {
        self.onStopRequired = onStopRequired
        self.onMediaServicesLost = onMediaServicesLost
        self.onMediaServicesReset = onMediaServicesReset

        let interruptionObserver = notificationCenter.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let reasonValue = notification.userInfo?[AVAudioSessionInterruptionReasonKey] as? UInt
            Task { @MainActor [weak self] in
                self?.handleAudioInterruption(typeValue: typeValue, reasonValue: reasonValue)
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

        // PF-057: AVAudioSession.mediaServicesWereResetNotification posts when
        // mediaserverd respawns after a crash. Every AVAudioEngine /
        // AVAudioUnit / AudioComponentInstance held before the reset is
        // invalid. The receiver tears down + rebuilds the audio infrastructure.
        let mediaResetObserver = notificationCenter.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: AVAudioSession.sharedInstance(),
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                Self.logger.notice("Media services were reset — invoking recovery")
                self?.onMediaServicesReset?()
            }
        }

        // PF-057 companion: AVAudioSession.mediaServicesWereLostNotification
        // posts when mediaserverd has died. Rebuilding before respawn would
        // fail — the receiver logs and marks a "rebuild pending" state that
        // the Reset handler consumes when it fires.
        let mediaLostObserver = notificationCenter.addObserver(
            forName: AVAudioSession.mediaServicesWereLostNotification,
            object: AVAudioSession.sharedInstance(),
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                Self.logger.warning("Media services were lost — awaiting reset")
                self?.onMediaServicesLost?()
            }
        }

        return [interruptionObserver, routeChangeObserver, mediaResetObserver, mediaLostObserver]
    }

    // MARK: - Private

    private func handleAudioInterruption(typeValue: UInt?, reasonValue: UInt?) {
        guard let typeValue,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            Self.logger.warning("Audio interruption notification received but could not parse type")
            return
        }

        switch type {
        case .began:
            // Ignore `.appWasSuspended` synthesized interruptions (PF-055 / PF-066).
            if reasonValue == Self.appWasSuspendedReasonRawValue {
                Self.logger.info("Audio interruption began with reason appWasSuspended - ignoring (iOS-synthesized for suspended app)")
                return
            }
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
