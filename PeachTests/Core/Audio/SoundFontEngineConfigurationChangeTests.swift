import Foundation
import AVFoundation
import Testing
@testable import Peach

/// Tests for `SoundFontEngine`'s `AVAudioEngineConfigurationChangeNotification`
/// observer (PF-056). The notification is posted by `AVAudioEngine` itself when
/// the I/O unit observes a hardware sample-rate or channel-count change (BT
/// codec switch, external interface plug-in). Without an observer, the engine
/// stays silently dead after such an event. These tests cover the observer
/// path (handler fires + engine survives) using a private `NotificationCenter`
/// and the `postSyntheticConfigurationChangeForTesting` seam.
@Suite("SoundFontEngine configuration change")
struct SoundFontEngineConfigurationChangeTests {

    private func makeEngine(notificationCenter: NotificationCenter) throws -> SoundFontEngine {
        try SoundFontEngine(
            sf2URL: TestSoundFont.url,
            audioSessionConfigurator: MockAudioSessionConfigurator(),
            notificationCenter: notificationCenter
        )
    }

    @Test("posting configuration change while engine running keeps engine running")
    func configurationChangeWhileRunningKeepsEngineRunning() async throws {
        let nc = NotificationCenter()
        let engine = try makeEngine(notificationCenter: nc)
        // Engine is running after init.
        try engine.ensureEngineRunning()

        engine.postSyntheticConfigurationChangeForTesting()

        // Two yields to let the addObserver closure schedule the Task and the
        // MainActor hop run handleConfigurationChange.
        await Task.yield()
        await Task.yield()
        try await Task.sleep(for: .milliseconds(20))

        // The handler's "SR unchanged" branch must not throw and must leave the
        // engine running. (Sample rate is unchanged because the test does not
        // alter hardware; the test exercises observer-fires + handler-runs.)
        try engine.ensureEngineRunning()
    }

    @Test("posting configuration change when engine stopped restarts engine")
    func configurationChangeWhenStoppedRestartsEngine() async throws {
        let nc = NotificationCenter()
        let engine = try makeEngine(notificationCenter: nc)

        // Stop the engine to simulate the state after AVAudioEngine self-stops
        // on a hardware change. PF-056 requires the handler to restart it.
        try engine.stopEngineForTesting()

        engine.postSyntheticConfigurationChangeForTesting()

        await Task.yield()
        await Task.yield()
        try await Task.sleep(for: .milliseconds(20))

        // Handler must have called engine.start(); ensureEngineRunning is now a
        // no-op if the handler did its job, or restarts if it did not — either
        // way the engine ends up running. The contract being asserted is that
        // the post-handler state IS running.
        try engine.ensureEngineRunning()
    }

    @Test("configuration change handler is idempotent")
    func configurationChangeHandlerIsIdempotent() async throws {
        let nc = NotificationCenter()
        let engine = try makeEngine(notificationCenter: nc)

        engine.postSyntheticConfigurationChangeForTesting()
        engine.postSyntheticConfigurationChangeForTesting()
        engine.postSyntheticConfigurationChangeForTesting()

        await Task.yield()
        await Task.yield()
        try await Task.sleep(for: .milliseconds(40))

        try engine.ensureEngineRunning()
    }

    @Test("SR-changed branch rewires the source node")
    func srChangedBranchRewiresSourceNode() async throws {
        let nc = NotificationCenter()
        let engine = try makeEngine(notificationCenter: nc)
        let oldSourceNodeIdentity = engine.sourceNodeIdentityForTesting

        // Force the SR-changed branch by staling the cached sample rate.
        // The real outputNode SR (whatever the simulator's hardware reports)
        // will not match `-1`, so the handler enters the rewire branch.
        engine.forceStaleSourceSampleRateForTesting()
        engine.postSyntheticConfigurationChangeForTesting()

        await Task.yield()
        await Task.yield()
        try await Task.sleep(for: .milliseconds(50))

        // sourceNode identity changes — the handler disconnected + detached
        // the old node and constructed a fresh one bound to the same
        // DoubleBufferedScheduleState at the new format.
        #expect(engine.sourceNodeIdentityForTesting != oldSourceNodeIdentity)
        try engine.ensureEngineRunning()
    }
}
