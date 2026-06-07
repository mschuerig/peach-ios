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
    ///   - onMediaServicesLost: Called when `mediaserverd` has died. The receiver
    ///     should log and mark a "rebuild pending" state; rebuilding before
    ///     `mediaserverd` respawns would fail. iOS-only signal; the macOS no-op
    ///     never invokes this closure.
    ///   - onMediaServicesReset: Called when `mediaserverd` has respawned. The
    ///     receiver must stop any active session via the lifecycle coordinator
    ///     and tear down + rebuild the audio engine (every `AVAudioEngine` /
    ///     `AVAudioUnit*` / `AudioComponentInstance` held before the reset is
    ///     invalid). iOS-only signal; the macOS no-op never invokes this closure.
    /// - Returns: Notification observer tokens that must be retained for the observers to remain active.
    func setupObservers(
        notificationCenter: NotificationCenter,
        onStopRequired: @escaping () -> Void,
        onMediaServicesLost: @escaping () -> Void,
        onMediaServicesReset: @escaping () -> Void
    ) -> [NSObjectProtocol]
}
