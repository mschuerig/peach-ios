#if os(iOS)
import Foundation
import Testing
import AVFoundation
import UIKit
@testable import Peach

@Suite("AudioSessionInterruptionMonitor")
struct AudioSessionInterruptionMonitorTests {

    // MARK: - Audio Interruption Tests

    @Test("Interruption began calls onStopRequired")
    func interruptionBeganCallsOnStopRequired() async {
        let nc = NotificationCenter()
        var stopCalled = false
        let _monitor = AudioSessionInterruptionMonitor(
            notificationCenter: nc,
            logger: .init(subsystem: "test", category: "test"),
            onStopRequired: { stopCalled = true }
        )

        nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )

        await Task.yield()
        #expect(stopCalled)
        _ = _monitor
    }

    @Test("Interruption ended does not call onStopRequired")
    func interruptionEndedDoesNotCallOnStopRequired() async {
        let nc = NotificationCenter()
        var stopCalled = false
        let _monitor = AudioSessionInterruptionMonitor(
            notificationCenter: nc,
            logger: .init(subsystem: "test", category: "test"),
            onStopRequired: { stopCalled = true }
        )

        nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue]
        )

        await Task.yield()
        #expect(!stopCalled)
        _ = _monitor
    }

    @Test("Nil interruption type does not call onStopRequired")
    func nilInterruptionTypeDoesNotCallOnStopRequired() async {
        let nc = NotificationCenter()
        var stopCalled = false
        let _monitor = AudioSessionInterruptionMonitor(
            notificationCenter: nc,
            logger: .init(subsystem: "test", category: "test"),
            onStopRequired: { stopCalled = true }
        )

        nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: nil
        )

        await Task.yield()
        #expect(!stopCalled)
        _ = _monitor
    }

    // MARK: - Route Change Tests

    @Test("Route change oldDeviceUnavailable calls onStopRequired")
    func routeChangeOldDeviceUnavailableCallsOnStopRequired() async {
        let nc = NotificationCenter()
        var stopCalled = false
        let _monitor = AudioSessionInterruptionMonitor(
            notificationCenter: nc,
            logger: .init(subsystem: "test", category: "test"),
            onStopRequired: { stopCalled = true }
        )

        nc.post(
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue]
        )

        await Task.yield()
        #expect(stopCalled)
        _ = _monitor
    }

    @Test("Non-stop route changes do not call onStopRequired")
    func nonStopRouteChangesDoNotCallOnStopRequired() async {
        let nc = NotificationCenter()
        var stopCalled = false
        let _monitor = AudioSessionInterruptionMonitor(
            notificationCenter: nc,
            logger: .init(subsystem: "test", category: "test"),
            onStopRequired: { stopCalled = true }
        )

        nc.post(
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue]
        )

        await Task.yield()
        #expect(!stopCalled)
        _ = _monitor
    }

    @Test("Nil route change reason does not call onStopRequired")
    func nilRouteChangeReasonDoesNotCallOnStopRequired() async {
        let nc = NotificationCenter()
        var stopCalled = false
        let _monitor = AudioSessionInterruptionMonitor(
            notificationCenter: nc,
            logger: .init(subsystem: "test", category: "test"),
            onStopRequired: { stopCalled = true }
        )

        nc.post(
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: nil
        )

        await Task.yield()
        #expect(!stopCalled)
        _ = _monitor
    }

    // MARK: - Background Notification Tests

    @Test("Background notification calls onStopRequired when backgroundNotificationName is provided")
    func backgroundNotificationCallsOnStopRequiredWhenEnabled() async {
        let nc = NotificationCenter()
        var stopCalled = false
        let _monitor = AudioSessionInterruptionMonitor(
            notificationCenter: nc,
            logger: .init(subsystem: "test", category: "test"),
            backgroundNotificationName: UIApplication.didEnterBackgroundNotification,
            onStopRequired: { stopCalled = true }
        )

        nc.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        await Task.yield()
        #expect(stopCalled)
        _ = _monitor
    }

    @Test("Background notification does not call onStopRequired when backgroundNotificationName is nil")
    func backgroundNotificationDoesNotCallOnStopRequiredWhenDisabled() async {
        let nc = NotificationCenter()
        var stopCalled = false
        let _monitor = AudioSessionInterruptionMonitor(
            notificationCenter: nc,
            logger: .init(subsystem: "test", category: "test"),
            onStopRequired: { stopCalled = true }
        )

        nc.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        await Task.yield()
        #expect(!stopCalled)
        _ = _monitor
    }

    // MARK: - Foreground Notification Tests

    @Test("Foreground notification calls onStopRequired when foregroundNotificationName is provided")
    func foregroundNotificationCallsOnStopRequiredWhenEnabled() async {
        let nc = NotificationCenter()
        var stopCalled = false
        let _monitor = AudioSessionInterruptionMonitor(
            notificationCenter: nc,
            logger: .init(subsystem: "test", category: "test"),
            foregroundNotificationName: UIApplication.willEnterForegroundNotification,
            onStopRequired: { stopCalled = true }
        )

        nc.post(name: UIApplication.willEnterForegroundNotification, object: nil)

        await Task.yield()
        #expect(stopCalled)
        _ = _monitor
    }

    @Test("Foreground notification does not call onStopRequired when foregroundNotificationName is nil")
    func foregroundNotificationDoesNotCallOnStopRequiredWhenDisabled() async {
        let nc = NotificationCenter()
        var stopCalled = false
        let _monitor = AudioSessionInterruptionMonitor(
            notificationCenter: nc,
            logger: .init(subsystem: "test", category: "test"),
            onStopRequired: { stopCalled = true }
        )

        nc.post(name: UIApplication.willEnterForegroundNotification, object: nil)

        await Task.yield()
        #expect(!stopCalled)
        _ = _monitor
    }
}
#endif

#if os(macOS)
import AppKit
import Foundation
import Testing
@testable import Peach

@Suite("AudioSessionInterruptionMonitor macOS")
struct AudioSessionInterruptionMonitorMacOSTests {

    @Test("macOS resignActive notification calls onStopRequired when backgroundNotificationName is provided")
    func resignActiveCallsOnStopRequired() async {
        let nc = NotificationCenter()
        var stopCalled = false
        let _monitor = AudioSessionInterruptionMonitor(
            notificationCenter: nc,
            logger: .init(subsystem: "test", category: "test"),
            backgroundNotificationName: NSApplication.didResignActiveNotification,
            onStopRequired: { stopCalled = true }
        )

        nc.post(name: NSApplication.didResignActiveNotification, object: nil)

        await Task.yield()
        #expect(stopCalled)
        _ = _monitor
    }

    @Test("macOS becomeActive notification calls onStopRequired when foregroundNotificationName is provided")
    func becomeActiveCallsOnStopRequired() async {
        let nc = NotificationCenter()
        var stopCalled = false
        let _monitor = AudioSessionInterruptionMonitor(
            notificationCenter: nc,
            logger: .init(subsystem: "test", category: "test"),
            foregroundNotificationName: NSApplication.didBecomeActiveNotification,
            onStopRequired: { stopCalled = true }
        )

        nc.post(name: NSApplication.didBecomeActiveNotification, object: nil)

        await Task.yield()
        #expect(stopCalled)
        _ = _monitor
    }

    @Test("macOS resignActive notification does not call onStopRequired when backgroundNotificationName is nil")
    func resignActiveDoesNotCallOnStopRequiredWhenDisabled() async {
        let nc = NotificationCenter()
        var stopCalled = false
        let _monitor = AudioSessionInterruptionMonitor(
            notificationCenter: nc,
            logger: .init(subsystem: "test", category: "test"),
            onStopRequired: { stopCalled = true }
        )

        nc.post(name: NSApplication.didResignActiveNotification, object: nil)

        await Task.yield()
        #expect(!stopCalled)
        _ = _monitor
    }
}
#endif
