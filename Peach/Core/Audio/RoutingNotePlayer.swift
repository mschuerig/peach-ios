import Foundation

@MainActor
public final class RoutingNotePlayer: NotePlayer {

    private let sinePlayer: any NotePlayer
    private let soundFontPlayer: (any NotePlayer)?
    private var activePlayer: (any NotePlayer)?
    private var activeSource: String?

    init(sinePlayer: any NotePlayer, soundFontPlayer: (any NotePlayer)?) {
        self.sinePlayer = sinePlayer
        self.soundFontPlayer = soundFontPlayer
    }

    public func play(frequency: Double, duration: TimeInterval, amplitude: Double) async throws {
        let source = UserDefaults.standard.string(forKey: SettingsKeys.soundSource)
            ?? SettingsKeys.defaultSoundSource

        let player: any NotePlayer
        if source == "cello", let sfPlayer = soundFontPlayer {
            player = sfPlayer
        } else {
            player = sinePlayer
        }

        // Stop previous player if source changed between calls
        if let previousSource = activeSource, previousSource != source, let previous = activePlayer {
            try await previous.stop()
        }

        activeSource = source
        activePlayer = player
        try await player.play(frequency: frequency, duration: duration, amplitude: amplitude)
    }

    public func stop() async throws {
        if let player = activePlayer {
            try await player.stop()
            activePlayer = nil
            activeSource = nil
        }
    }
}
