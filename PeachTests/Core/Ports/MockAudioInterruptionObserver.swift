import Foundation
@testable import Peach

/// Test mock that captures the `AudioInterruptionObserving` callbacks for
/// programmatic triggering, replacing real `AVAudioSession` notifications.
final class MockAudioInterruptionObserver: AudioInterruptionObserving {
    private var storedOnStopRequired: (() -> Void)?
    private var storedOnMediaServicesLost: (() -> Void)?
    private var storedOnMediaServicesReset: (() -> Void)?

    func setupObservers(
        notificationCenter: NotificationCenter,
        onStopRequired: @escaping () -> Void,
        onMediaServicesLost: @escaping () -> Void,
        onMediaServicesReset: @escaping () -> Void
    ) -> [NSObjectProtocol] {
        storedOnStopRequired = onStopRequired
        storedOnMediaServicesLost = onMediaServicesLost
        storedOnMediaServicesReset = onMediaServicesReset
        return []
    }

    /// Simulates an audio interruption that requires stopping playback.
    func simulateInterruption() {
        storedOnStopRequired?()
    }

    /// Simulates `mediaServicesWereLostNotification` firing.
    func simulateMediaServicesLost() {
        storedOnMediaServicesLost?()
    }

    /// Simulates `mediaServicesWereResetNotification` firing.
    func simulateMediaServicesReset() {
        storedOnMediaServicesReset?()
    }
}
