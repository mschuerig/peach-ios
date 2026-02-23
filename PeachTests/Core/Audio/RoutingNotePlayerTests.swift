import Testing
import Foundation
@testable import Peach

@Suite("RoutingNotePlayer Tests")
struct RoutingNotePlayerTests {

    // MARK: - Routing to Sine

    @Test("Routes to sine player when soundSource setting is 'sine'")
    @MainActor func routesToSine() async throws {
        defer { UserDefaults.standard.removeObject(forKey: SettingsKeys.soundSource) }
        let sine = MockNotePlayer()
        let router = RoutingNotePlayer(sinePlayer: sine, soundFontPlayer: nil)
        UserDefaults.standard.set("sine", forKey: SettingsKeys.soundSource)

        try await router.play(frequency: 440.0, duration: 0.1, amplitude: 0.5)

        #expect(sine.playCallCount == 1)
    }

    // MARK: - Routing to SF2 Presets

    @Test("Routes to SoundFontNotePlayer when soundSource is 'sf2:0:0'")
    @MainActor func routesToSF2Piano() async throws {
        defer { UserDefaults.standard.removeObject(forKey: SettingsKeys.soundSource) }
        let sine = MockNotePlayer()
        let sfPlayer = try SoundFontNotePlayer()
        let router = RoutingNotePlayer(sinePlayer: sine, soundFontPlayer: sfPlayer)
        UserDefaults.standard.set("sf2:0:0", forKey: SettingsKeys.soundSource)

        try await router.play(frequency: 440.0, duration: 0.1, amplitude: 0.5)

        #expect(sine.playCallCount == 0)
    }

    @Test("Routes to SoundFontNotePlayer when soundSource is 'sf2:0:42'")
    @MainActor func routesToSF2Cello() async throws {
        defer { UserDefaults.standard.removeObject(forKey: SettingsKeys.soundSource) }
        let sine = MockNotePlayer()
        let sfPlayer = try SoundFontNotePlayer()
        let router = RoutingNotePlayer(sinePlayer: sine, soundFontPlayer: sfPlayer)
        UserDefaults.standard.set("sf2:0:42", forKey: SettingsKeys.soundSource)

        try await router.play(frequency: 440.0, duration: 0.1, amplitude: 0.5)

        #expect(sine.playCallCount == 0)
    }

    // MARK: - Fallback to Sine

    @Test("Falls back to sine when SoundFontNotePlayer is nil")
    @MainActor func fallsBackToSine() async throws {
        defer { UserDefaults.standard.removeObject(forKey: SettingsKeys.soundSource) }
        let sine = MockNotePlayer()
        let router = RoutingNotePlayer(sinePlayer: sine, soundFontPlayer: nil)
        UserDefaults.standard.set("sf2:0:42", forKey: SettingsKeys.soundSource)

        try await router.play(frequency: 440.0, duration: 0.1, amplitude: 0.5)

        #expect(sine.playCallCount == 1)
    }

    @Test("Falls back to sine for unknown source tag")
    @MainActor func fallsBackForUnknownTag() async throws {
        defer { UserDefaults.standard.removeObject(forKey: SettingsKeys.soundSource) }
        let sine = MockNotePlayer()
        let router = RoutingNotePlayer(sinePlayer: sine, soundFontPlayer: nil)
        UserDefaults.standard.set("unknown", forKey: SettingsKeys.soundSource)

        try await router.play(frequency: 440.0, duration: 0.1, amplitude: 0.5)

        #expect(sine.playCallCount == 1)
    }

    @Test("Falls back to sine for malformed sf2 tag")
    @MainActor func fallsBackForMalformedTag() async throws {
        defer { UserDefaults.standard.removeObject(forKey: SettingsKeys.soundSource) }
        let sine = MockNotePlayer()
        let router = RoutingNotePlayer(sinePlayer: sine, soundFontPlayer: nil)
        UserDefaults.standard.set("sf2:abc", forKey: SettingsKeys.soundSource)

        try await router.play(frequency: 440.0, duration: 0.1, amplitude: 0.5)

        #expect(sine.playCallCount == 1)
    }

    @Test("Falls back to sine when preset load fails for out-of-range program")
    @MainActor func fallsBackToSineForInvalidPreset() async throws {
        defer { UserDefaults.standard.removeObject(forKey: SettingsKeys.soundSource) }
        let sine = MockNotePlayer()
        let sfPlayer = try SoundFontNotePlayer()
        let router = RoutingNotePlayer(sinePlayer: sine, soundFontPlayer: sfPlayer)
        UserDefaults.standard.set("sf2:0:999", forKey: SettingsKeys.soundSource)

        try await router.play(frequency: 440.0, duration: 0.1, amplitude: 0.5)

        #expect(sine.playCallCount == 1)
    }

    // MARK: - Legacy Migration

    @Test("Legacy 'cello' tag routes to SoundFontNotePlayer as program 42")
    @MainActor func legacyCelloTagRoutes() async throws {
        defer { UserDefaults.standard.removeObject(forKey: SettingsKeys.soundSource) }
        let sine = MockNotePlayer()
        let sfPlayer = try SoundFontNotePlayer()
        let router = RoutingNotePlayer(sinePlayer: sine, soundFontPlayer: sfPlayer)
        UserDefaults.standard.set("cello", forKey: SettingsKeys.soundSource)

        try await router.play(frequency: 440.0, duration: 0.1, amplitude: 0.5)

        #expect(sine.playCallCount == 0)
    }

    // MARK: - Setting Change Between Calls

    @Test("Setting change between calls routes to new player")
    @MainActor func settingChangeBetweenCalls() async throws {
        defer { UserDefaults.standard.removeObject(forKey: SettingsKeys.soundSource) }
        let sine = MockNotePlayer()
        let sfPlayer = try SoundFontNotePlayer()
        let router = RoutingNotePlayer(sinePlayer: sine, soundFontPlayer: sfPlayer)

        UserDefaults.standard.set("sine", forKey: SettingsKeys.soundSource)
        try await router.play(frequency: 440.0, duration: 0.1, amplitude: 0.5)
        #expect(sine.playCallCount == 1)

        UserDefaults.standard.set("sf2:0:0", forKey: SettingsKeys.soundSource)
        try await router.play(frequency: 440.0, duration: 0.1, amplitude: 0.5)
        #expect(sine.playCallCount == 1) // still 1, second call went to SF2
    }

    @Test("Stops previous player when source changes between calls")
    @MainActor func stopsOldPlayerOnSourceChange() async throws {
        defer { UserDefaults.standard.removeObject(forKey: SettingsKeys.soundSource) }
        let sine = MockNotePlayer()
        let sfPlayer = try SoundFontNotePlayer()
        let router = RoutingNotePlayer(sinePlayer: sine, soundFontPlayer: sfPlayer)

        UserDefaults.standard.set("sine", forKey: SettingsKeys.soundSource)
        try await router.play(frequency: 440.0, duration: 0.1, amplitude: 0.5)
        #expect(sine.stopCallCount == 0)

        UserDefaults.standard.set("sf2:0:42", forKey: SettingsKeys.soundSource)
        try await router.play(frequency: 440.0, duration: 0.1, amplitude: 0.5)
        #expect(sine.stopCallCount == 1)
    }

    // MARK: - Stop

    @Test("Stop stops the currently active player")
    @MainActor func stopStopsActivePlayer() async throws {
        defer { UserDefaults.standard.removeObject(forKey: SettingsKeys.soundSource) }
        let sine = MockNotePlayer()
        let router = RoutingNotePlayer(sinePlayer: sine, soundFontPlayer: nil)
        UserDefaults.standard.set("sine", forKey: SettingsKeys.soundSource)

        try await router.play(frequency: 440.0, duration: 0.1, amplitude: 0.5)
        try await router.stop()

        #expect(sine.stopCallCount == 1)
    }

    @Test("Stop when no player has been activated does not crash")
    @MainActor func stopWhenNoActivePlayer() async throws {
        let sine = MockNotePlayer()
        let router = RoutingNotePlayer(sinePlayer: sine, soundFontPlayer: nil)

        try await router.stop()

        #expect(sine.stopCallCount == 0)
    }

    // MARK: - Protocol Conformance

    @Test("RoutingNotePlayer conforms to NotePlayer protocol")
    @MainActor func conformsToNotePlayer() {
        let router = RoutingNotePlayer(sinePlayer: MockNotePlayer(), soundFontPlayer: nil)
        #expect(router is NotePlayer)
    }
}
