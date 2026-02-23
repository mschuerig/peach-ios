import Testing
import Foundation
@testable import Peach

@Suite("RoutingNotePlayer Tests")
struct RoutingNotePlayerTests {

    // MARK: - Routing to Sine

    @Test("Routes to sine player when soundSource setting is 'sine'")
    @MainActor func routesToSine() async throws {
        let sine = MockNotePlayer()
        let cello = MockNotePlayer()
        let router = RoutingNotePlayer(sinePlayer: sine, soundFontPlayer: cello)
        UserDefaults.standard.set("sine", forKey: SettingsKeys.soundSource)

        try await router.play(frequency: 440.0, duration: 0.1, amplitude: 0.5)

        #expect(sine.playCallCount == 1)
        #expect(cello.playCallCount == 0)
    }

    // MARK: - Routing to Cello

    @Test("Routes to cello player when soundSource setting is 'cello'")
    @MainActor func routesToCello() async throws {
        let sine = MockNotePlayer()
        let cello = MockNotePlayer()
        let router = RoutingNotePlayer(sinePlayer: sine, soundFontPlayer: cello)
        UserDefaults.standard.set("cello", forKey: SettingsKeys.soundSource)

        try await router.play(frequency: 440.0, duration: 0.1, amplitude: 0.5)

        #expect(sine.playCallCount == 0)
        #expect(cello.playCallCount == 1)
    }

    // MARK: - Fallback to Sine

    @Test("Falls back to sine when SoundFontNotePlayer is nil")
    @MainActor func fallsBackToSine() async throws {
        let sine = MockNotePlayer()
        let router = RoutingNotePlayer(sinePlayer: sine, soundFontPlayer: nil)
        UserDefaults.standard.set("cello", forKey: SettingsKeys.soundSource)

        try await router.play(frequency: 440.0, duration: 0.1, amplitude: 0.5)

        #expect(sine.playCallCount == 1)
    }

    // MARK: - Setting Change Between Calls

    @Test("Setting change between calls routes to new player")
    @MainActor func settingChangeBetweenCalls() async throws {
        let sine = MockNotePlayer()
        let cello = MockNotePlayer()
        let router = RoutingNotePlayer(sinePlayer: sine, soundFontPlayer: cello)

        UserDefaults.standard.set("sine", forKey: SettingsKeys.soundSource)
        try await router.play(frequency: 440.0, duration: 0.1, amplitude: 0.5)
        #expect(sine.playCallCount == 1)
        #expect(cello.playCallCount == 0)

        UserDefaults.standard.set("cello", forKey: SettingsKeys.soundSource)
        try await router.play(frequency: 440.0, duration: 0.1, amplitude: 0.5)
        #expect(sine.playCallCount == 1)
        #expect(cello.playCallCount == 1)
    }

    // MARK: - Stop

    @Test("Stop stops the currently active player")
    @MainActor func stopStopsActivePlayer() async throws {
        let sine = MockNotePlayer()
        let cello = MockNotePlayer()
        let router = RoutingNotePlayer(sinePlayer: sine, soundFontPlayer: cello)
        UserDefaults.standard.set("sine", forKey: SettingsKeys.soundSource)

        try await router.play(frequency: 440.0, duration: 0.1, amplitude: 0.5)
        try await router.stop()

        #expect(sine.stopCallCount == 1)
        #expect(cello.stopCallCount == 0)
    }

    @Test("Stop when no player has been activated does not crash")
    @MainActor func stopWhenNoActivePlayer() async throws {
        let sine = MockNotePlayer()
        let cello = MockNotePlayer()
        let router = RoutingNotePlayer(sinePlayer: sine, soundFontPlayer: cello)

        try await router.stop()

        #expect(sine.stopCallCount == 0)
        #expect(cello.stopCallCount == 0)
    }

    // MARK: - Protocol Conformance

    @Test("RoutingNotePlayer conforms to NotePlayer protocol")
    @MainActor func conformsToNotePlayer() {
        let router = RoutingNotePlayer(sinePlayer: MockNotePlayer(), soundFontPlayer: nil)
        #expect(router is NotePlayer)
    }
}
