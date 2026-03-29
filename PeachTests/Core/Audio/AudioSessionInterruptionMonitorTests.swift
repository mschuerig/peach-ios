import Foundation
import Testing
@testable import Peach

// MARK: - Mock Audio Interruption Observer

private final class MockAudioInterruptionObservingForMonitor: AudioInterruptionObserving {
    var setupCallCount = 0
    private var storedOnStopRequired: (() -> Void)?

    func setupObservers(
        notificationCenter: NotificationCenter,
        onStopRequired: @escaping () -> Void
    ) -> [NSObjectProtocol] {
        setupCallCount += 1
        storedOnStopRequired = onStopRequired
        return []
    }

    func simulateInterruption() {
        storedOnStopRequired?()
    }
}

// MARK: - Tests

@Suite("AudioSessionInterruptionMonitor")
struct AudioSessionInterruptionMonitorTests {

    // MARK: - Audio Interruption Observer Integration

    @Test("delegates audio interruption setup to injected observer")
    func delegatesToInjectedObserver() async {
        let nc = NotificationCenter()
        let mockObserver = MockAudioInterruptionObservingForMonitor()
        let _monitor = AudioSessionInterruptionMonitor(
            notificationCenter: nc,
            logger: .init(subsystem: "test", category: "test"),
            audioInterruptionObserver: mockObserver,
            onStopRequired: {}
        )

        #expect(mockObserver.setupCallCount == 1)
        _ = _monitor
    }

    @Test("injected observer interruption calls onStopRequired")
    func injectedObserverInterruptionCallsOnStopRequired() async {
        let nc = NotificationCenter()
        let mockObserver = MockAudioInterruptionObservingForMonitor()
        var stopCalled = false
        let _monitor = AudioSessionInterruptionMonitor(
            notificationCenter: nc,
            logger: .init(subsystem: "test", category: "test"),
            audioInterruptionObserver: mockObserver,
            onStopRequired: { stopCalled = true }
        )

        mockObserver.simulateInterruption()

        #expect(stopCalled)
        _ = _monitor
    }

    // MARK: - Background Notification Tests

    @Test("background notification calls onStopRequired when name is provided")
    func backgroundNotificationCallsOnStopRequired() async {
        let nc = NotificationCenter()
        let testNotification = Notification.Name("test.background")
        var stopCalled = false
        let _monitor = AudioSessionInterruptionMonitor(
            notificationCenter: nc,
            logger: .init(subsystem: "test", category: "test"),
            audioInterruptionObserver: NoOpAudioInterruptionObserver(),
            backgroundNotificationName: testNotification,
            onStopRequired: { stopCalled = true }
        )

        nc.post(name: testNotification, object: nil)

        await Task.yield()
        #expect(stopCalled)
        _ = _monitor
    }

    @Test("background notification does not call onStopRequired when name is nil")
    func backgroundNotificationDoesNotCallWhenNil() async {
        let nc = NotificationCenter()
        let testNotification = Notification.Name("test.background")
        var stopCalled = false
        let _monitor = AudioSessionInterruptionMonitor(
            notificationCenter: nc,
            logger: .init(subsystem: "test", category: "test"),
            audioInterruptionObserver: NoOpAudioInterruptionObserver(),
            onStopRequired: { stopCalled = true }
        )

        nc.post(name: testNotification, object: nil)

        await Task.yield()
        #expect(!stopCalled)
        _ = _monitor
    }

    // MARK: - Foreground Notification Tests

    @Test("foreground notification calls onStopRequired when name is provided")
    func foregroundNotificationCallsOnStopRequired() async {
        let nc = NotificationCenter()
        let testNotification = Notification.Name("test.foreground")
        var stopCalled = false
        let _monitor = AudioSessionInterruptionMonitor(
            notificationCenter: nc,
            logger: .init(subsystem: "test", category: "test"),
            audioInterruptionObserver: NoOpAudioInterruptionObserver(),
            foregroundNotificationName: testNotification,
            onStopRequired: { stopCalled = true }
        )

        nc.post(name: testNotification, object: nil)

        await Task.yield()
        #expect(stopCalled)
        _ = _monitor
    }

    @Test("foreground notification does not call onStopRequired when name is nil")
    func foregroundNotificationDoesNotCallWhenNil() async {
        let nc = NotificationCenter()
        let testNotification = Notification.Name("test.foreground")
        var stopCalled = false
        let _monitor = AudioSessionInterruptionMonitor(
            notificationCenter: nc,
            logger: .init(subsystem: "test", category: "test"),
            audioInterruptionObserver: NoOpAudioInterruptionObserver(),
            onStopRequired: { stopCalled = true }
        )

        nc.post(name: testNotification, object: nil)

        await Task.yield()
        #expect(!stopCalled)
        _ = _monitor
    }
}
