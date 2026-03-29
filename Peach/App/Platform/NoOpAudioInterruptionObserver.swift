import Foundation

/// No-op audio interruption observer for macOS (no AVAudioSession).
struct NoOpAudioInterruptionObserver: AudioInterruptionObserving {
    func setupObservers(
        notificationCenter: NotificationCenter,
        onStopRequired: @escaping () -> Void
    ) -> [NSObjectProtocol] {
        []
    }
}
