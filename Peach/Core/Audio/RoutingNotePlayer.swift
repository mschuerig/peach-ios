import Foundation

@MainActor
public final class RoutingNotePlayer: NotePlayer {

    private let sinePlayer: any NotePlayer
    private let soundFontPlayer: (any NotePlayer)?
    private var activePlayer: (any NotePlayer)?

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

        activePlayer = player
        try await player.play(frequency: frequency, duration: duration, amplitude: amplitude)
    }

    public func stop() async throws {
        if let player = activePlayer {
            try await player.stop()
        }
    }
}
