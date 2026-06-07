import Foundation

/// No-op audio interruption observer for macOS (no AVAudioSession).
struct NoOpAudioInterruptionObserver: AudioInterruptionObserving {
    func setupObservers(
        notificationCenter: NotificationCenter,
        onStopRequired: @escaping () -> Void,
        onMediaServicesLost: @escaping () -> Void,
        onMediaServicesReset: @escaping () -> Void
    ) -> [NSObjectProtocol] {
        []
    }
}
