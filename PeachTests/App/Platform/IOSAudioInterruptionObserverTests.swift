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

    @Test("setupObservers returns exactly two tokens")
    func setupObserversReturnsTwoTokens() {
        let nc = NotificationCenter()
        let observer = IOSAudioInterruptionObserver()
        let tokens = observer.setupObservers(notificationCenter: nc, onStopRequired: {})
        #expect(tokens.count == 2)
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
        let tokens = observer.setupObservers(notificationCenter: nc) {
            stopped = true
        }
        return Fixture(nc: nc, observer: observer, tokens: tokens, stopCalled: { stopped })
    }
}
#endif
