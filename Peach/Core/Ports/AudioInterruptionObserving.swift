import Foundation

/// Observes platform-specific audio interruptions and route changes.
///
/// iOS: monitors AVAudioSession interruption and route change notifications.
/// macOS: no audio session interruptions to observe.
protocol AudioInterruptionObserving {
    /// Sets up audio interruption observers.
    /// - Parameters:
    ///   - notificationCenter: The notification center to observe.
    ///   - onStopRequired: Called when an audio interruption requires stopping playback.
    /// - Returns: Notification observer tokens that must be retained for the observers to remain active.
    func setupObservers(
        notificationCenter: NotificationCenter,
        onStopRequired: @escaping () -> Void
    ) -> [NSObjectProtocol]
}
