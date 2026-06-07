import Foundation
import AVFoundation
import Testing
@testable import Peach

/// Tests for `SoundFontEngine.rebuildAfterMediaReset()` (PF-057). When
/// `mediaserverd` crashes and respawns, every `AVAudioEngine` /
/// `AVAudioUnit*` / `AudioComponentInstance` reference held before the reset
/// is invalid. The rebuild method tears them down and constructs fresh
/// instances while keeping the same `SoundFontEngine` identity so injected
/// references stay valid.
@Suite("SoundFontEngine media-reset rebuild")
struct SoundFontEngineMediaResetTests {

    private static let channel0 = MIDIChannel(0)
    private static let channel1 = MIDIChannel(1)

    private func makeEngine() throws -> SoundFontEngine {
        try SoundFontEngine(
            sf2URL: TestSoundFont.url,
            audioSessionConfigurator: MockAudioSessionConfigurator(),
            notificationCenter: NotificationCenter()
        )
    }

    @Test("rebuildAfterMediaReset on a freshly initialized engine succeeds")
    func rebuildOnFreshEngineSucceeds() async throws {
        let engine = try makeEngine()

        try await engine.rebuildAfterMediaReset()

        try engine.ensureEngineRunning()
    }

    @Test("rebuildAfterMediaReset preserves channel topology")
    func rebuildPreservesChannels() async throws {
        let engine = try makeEngine()
        try engine.createChannel(Self.channel1)

        try await engine.rebuildAfterMediaReset()

        // Both channels survive — startNote on each is a no-throw operation.
        engine.startNote(MIDINote(60), velocity: MIDIVelocity(63), amplitudeDB: AmplitudeDB(0.0), pitchBend: .center, channel: Self.channel0)
        engine.startNote(MIDINote(60), velocity: MIDIVelocity(63), amplitudeDB: AmplitudeDB(0.0), pitchBend: .center, channel: Self.channel1)
        engine.stopNote(MIDINote(60), channel: Self.channel0)
        engine.stopNote(MIDINote(60), channel: Self.channel1)
    }

    @Test("rebuildAfterMediaReset reloads previously loaded presets")
    func rebuildReloadsPresets() async throws {
        let engine = try makeEngine()
        try await engine.loadPreset(SF2Preset(name: "Piano", program: 0, bank: 0), channel: Self.channel0)
        #expect(engine.loadedPresetCountForTesting == 1)

        try await engine.rebuildAfterMediaReset()

        #expect(engine.loadedPresetCountForTesting == 1)
    }

    @Test("rebuildAfterMediaReset reloads presets across multiple channels")
    func rebuildReloadsMultipleChannelPresets() async throws {
        let engine = try makeEngine()
        try engine.createChannel(Self.channel1)
        try await engine.loadPreset(SF2Preset(name: "Piano", program: 0, bank: 0), channel: Self.channel0)
        try await engine.loadPreset(SF2Preset(name: "Strings", program: 6, bank: 8), channel: Self.channel1)
        #expect(engine.loadedPresetCountForTesting == 2)

        try await engine.rebuildAfterMediaReset()

        #expect(engine.loadedPresetCountForTesting == 2)
    }

    @Test("engine remains usable after multiple consecutive rebuilds")
    func multipleConsecutiveRebuildsAreIdempotent() async throws {
        let engine = try makeEngine()
        try await engine.loadPreset(SF2Preset(name: "Piano", program: 0, bank: 0), channel: Self.channel0)

        try await engine.rebuildAfterMediaReset()
        try await engine.rebuildAfterMediaReset()
        try await engine.rebuildAfterMediaReset()

        try engine.ensureEngineRunning()
        #expect(engine.loadedPresetCountForTesting == 1)
    }

    @Test("rebuildAfterMediaReset replaces the underlying engine instance")
    func rebuildReplacesEngineInstance() async throws {
        let engine = try makeEngine()
        let oldEngineIdentity = engine.engineIdentityForTesting

        try await engine.rebuildAfterMediaReset()

        #expect(engine.engineIdentityForTesting != oldEngineIdentity)
    }

    @Test("rebuildAfterMediaReset replaces the sourceNode instance")
    func rebuildReplacesSourceNode() async throws {
        let engine = try makeEngine()
        let oldSourceNodeIdentity = engine.sourceNodeIdentityForTesting

        try await engine.rebuildAfterMediaReset()

        #expect(engine.sourceNodeIdentityForTesting != oldSourceNodeIdentity)
    }

    @Test("rebuildAfterMediaReset re-registers the configuration-change observer")
    func rebuildReRegistersConfigChangeObserver() async throws {
        let nc = NotificationCenter()
        let engine = try SoundFontEngine(
            sf2URL: TestSoundFont.url,
            audioSessionConfigurator: MockAudioSessionConfigurator(),
            notificationCenter: nc
        )
        try await engine.rebuildAfterMediaReset()
        let oldSourceNodeIdentity = engine.sourceNodeIdentityForTesting

        // Force SR-changed branch so the rewire identity change is observable.
        engine.forceStaleSourceSampleRateForTesting()
        engine.postSyntheticConfigurationChangeForTesting()

        await Task.yield()
        await Task.yield()
        try await Task.sleep(for: .milliseconds(50))

        // If the observer was not re-registered against the new engine, the
        // post would be ignored and the source node would remain unchanged.
        #expect(engine.sourceNodeIdentityForTesting != oldSourceNodeIdentity)
    }

    @Test("rebuildAfterMediaReset starts with zero pending-retry presets after a clean rebuild")
    func rebuildLeavesZeroPendingPresets() async throws {
        let engine = try makeEngine()
        try await engine.loadPreset(SF2Preset(name: "Piano", program: 0, bank: 0), channel: Self.channel0)

        try await engine.rebuildAfterMediaReset()

        #expect(engine.pendingPresetReloadCountForTesting == 0)
    }
}
