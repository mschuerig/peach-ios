import Foundation
@testable import Peach

/// Test mock that captures the `onStopRequired` callback for programmatic triggering.
///
/// Use `simulateInterruption()` to fire `onStopRequired` — this replaces posting
/// real `AVAudioSession` notifications, making audio-interruption tests cross-platform.
final class MockAudioInterruptionObserver: AudioInterruptionObserving {
    private var storedOnStopRequired: (() -> Void)?

    func setupObservers(
        notificationCenter: NotificationCenter,
        onStopRequired: @escaping () -> Void
    ) -> [NSObjectProtocol] {
        storedOnStopRequired = onStopRequired
        return []
    }

    /// Simulates an audio interruption that requires stopping playback.
    func simulateInterruption() {
        storedOnStopRequired?()
    }
}
