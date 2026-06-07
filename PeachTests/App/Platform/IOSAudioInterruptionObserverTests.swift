#if os(iOS)
import AVFoundation
import Testing
@testable import Peach

/// Unit tests for `IOSAudioInterruptionObserver` — the concrete iOS implementation
/// that filters AVAudioSession interruption and route-change notifications.
@Suite("IOSAudioInterruptionObserver")
struct IOSAudioInterruptionObserverTests {

    // MARK: - Audio Interruption

    @Test("Interruption began calls onStopRequired")
    func interruptionBeganCallsOnStopRequired() async {
        let f = makeFixture()

        f.nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )

        try? await Task.sleep(for: .milliseconds(50))
        #expect(f.stopCalled())
        _ = f.observer
    }

    @Test("Interruption ended does not call onStopRequired")
    func interruptionEndedDoesNotCallOnStopRequired() async {
        let f = makeFixture()

        f.nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue]
        )

        try? await Task.sleep(for: .milliseconds(50))
        #expect(!f.stopCalled())
        _ = f.observer
    }

    @Test("Nil interruption type does not call onStopRequired")
    func nilInterruptionTypeDoesNotCallOnStopRequired() async {
        let f = makeFixture()

        f.nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: nil
        )

        try? await Task.sleep(for: .milliseconds(50))
        #expect(!f.stopCalled())
        _ = f.observer
    }

    // MARK: - Audio Interruption Reason Filter (PF-055)

    @Test("Interruption began with reason appWasSuspended does not call onStopRequired")
    func interruptionBeganAppWasSuspendedDoesNotCallOnStopRequired() async {
        let f = makeFixture()

        f.nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue,
                AVAudioSessionInterruptionReasonKey: UInt(1) // rawValue of deprecated .appWasSuspended
            ]
        )

        try? await Task.sleep(for: .milliseconds(50))
        #expect(!f.stopCalled())
        _ = f.observer
    }

    @Test("Interruption began with reason default calls onStopRequired")
    func interruptionBeganDefaultCallsOnStopRequired() async {
        let f = makeFixture()

        f.nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue,
                AVAudioSessionInterruptionReasonKey: AVAudioSession.InterruptionReason.default.rawValue
            ]
        )

        try? await Task.sleep(for: .milliseconds(50))
        #expect(f.stopCalled())
        _ = f.observer
    }

    @Test("Interruption began with reason builtInMicMuted calls onStopRequired")
    func interruptionBeganBuiltInMicMutedCallsOnStopRequired() async {
        let f = makeFixture()

        f.nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue,
                AVAudioSessionInterruptionReasonKey: AVAudioSession.InterruptionReason.builtInMicMuted.rawValue
            ]
        )

        try? await Task.sleep(for: .milliseconds(50))
        #expect(f.stopCalled())
        _ = f.observer
    }

    // MARK: - Route Change

    @Test("Route change oldDeviceUnavailable calls onStopRequired")
    func routeChangeOldDeviceUnavailableCallsOnStopRequired() async {
        let f = makeFixture()

        f.nc.post(
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue]
        )

        try? await Task.sleep(for: .milliseconds(50))
        #expect(f.stopCalled())
        _ = f.observer
    }

    @Test("Non-stop route changes do not call onStopRequired")
    func nonStopRouteChangesDoNotCallOnStopRequired() async {
        let f = makeFixture()

        f.nc.post(
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue]
        )

        try? await Task.sleep(for: .milliseconds(50))
        #expect(!f.stopCalled())
        _ = f.observer
    }

    @Test("Nil route change reason does not call onStopRequired")
    func nilRouteChangeReasonDoesNotCallOnStopRequired() async {
        let f = makeFixture()

        f.nc.post(
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: nil
        )

        try? await Task.sleep(for: .milliseconds(50))
        #expect(!f.stopCalled())
        _ = f.observer
    }

    // MARK: - Token Management

    @Test("setupObservers returns exactly four tokens")
    func setupObserversReturnsFourTokens() {
        let nc = NotificationCenter()
        let observer = IOSAudioInterruptionObserver()
        let tokens = observer.setupObservers(
            notificationCenter: nc,
            onStopRequired: {},
            onMediaServicesLost: {},
            onMediaServicesReset: {}
        )
        #expect(tokens.count == 4)
    }

    // MARK: - Media Services Reset (PF-057)

    @Test("mediaServicesWereResetNotification calls onMediaServicesReset")
    func mediaServicesResetFiresClosure() async {
        let nc = NotificationCenter()
        let observer = IOSAudioInterruptionObserver()
        var resetCalled = false
        let tokens = observer.setupObservers(
            notificationCenter: nc,
            onStopRequired: {},
            onMediaServicesLost: {},
            onMediaServicesReset: { resetCalled = true }
        )

        nc.post(
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: nil
        )

        try? await Task.sleep(for: .milliseconds(50))
        #expect(resetCalled)
        _ = tokens
        _ = observer
    }

    @Test("mediaServicesWereLostNotification calls onMediaServicesLost")
    func mediaServicesLostFiresClosure() async {
        let nc = NotificationCenter()
        let observer = IOSAudioInterruptionObserver()
        var lostCalled = false
        let tokens = observer.setupObservers(
            notificationCenter: nc,
            onStopRequired: {},
            onMediaServicesLost: { lostCalled = true },
            onMediaServicesReset: {}
        )

        nc.post(
            name: AVAudioSession.mediaServicesWereLostNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: nil
        )

        try? await Task.sleep(for: .milliseconds(50))
        #expect(lostCalled)
        _ = tokens
        _ = observer
    }

    @Test("lost-then-reset fires both closures in order")
    func lostThenResetFiresBothInOrder() async {
        let nc = NotificationCenter()
        let observer = IOSAudioInterruptionObserver()
        var sequence: [String] = []
        let tokens = observer.setupObservers(
            notificationCenter: nc,
            onStopRequired: {},
            onMediaServicesLost: { sequence.append("lost") },
            onMediaServicesReset: { sequence.append("reset") }
        )

        nc.post(
            name: AVAudioSession.mediaServicesWereLostNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: nil
        )
        try? await Task.sleep(for: .milliseconds(30))
        nc.post(
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: nil
        )
        try? await Task.sleep(for: .milliseconds(50))

        #expect(sequence == ["lost", "reset"])
        _ = tokens
        _ = observer
    }

    // MARK: - Helpers

    private struct Fixture {
        let nc: NotificationCenter
        let observer: IOSAudioInterruptionObserver
        let tokens: [NSObjectProtocol]
        let stopCalled: () -> Bool
    }

    /// Creates a fixture with a private NotificationCenter and a wired-up observer.
    /// The fixture retains the observer to prevent deallocation (closures use `[weak self]`).
    private func makeFixture() -> Fixture {
        let nc = NotificationCenter()
        var stopped = false
        let observer = IOSAudioInterruptionObserver()
        let tokens = observer.setupObservers(
            notificationCenter: nc,
            onStopRequired: { stopped = true },
            onMediaServicesLost: {},
            onMediaServicesReset: {}
        )
        return Fixture(nc: nc, observer: observer, tokens: tokens, stopCalled: { stopped })
    }
}
#endif
