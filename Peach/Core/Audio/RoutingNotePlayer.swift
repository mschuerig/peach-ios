import Foundation

@MainActor
final class RoutingNotePlayer: NotePlayer {

    private let sinePlayer: any NotePlayer
    private let soundFontPlayer: SoundFontNotePlayer?
    private var activePlayer: (any NotePlayer)?
    private var activeSource: String?

    init(sinePlayer: any NotePlayer, soundFontPlayer: SoundFontNotePlayer?) {
        self.sinePlayer = sinePlayer
        self.soundFontPlayer = soundFontPlayer
    }

    func play(frequency: Double, duration: TimeInterval, amplitude: Double) async throws {
        let source = UserDefaults.standard.string(forKey: SettingsKeys.soundSource)
            ?? SettingsKeys.defaultSoundSource

        let player: any NotePlayer
        if let (bank, program) = Self.parseSF2Tag(from: source), let sfPlayer = soundFontPlayer {
            do {
                try await sfPlayer.loadPreset(program: program, bank: bank)
                player = sfPlayer
            } catch {
                player = sinePlayer
            }
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

    func stop() async throws {
        if let player = activePlayer {
            try await player.stop()
            activePlayer = nil
            activeSource = nil
        }
    }

    private static func parseSF2Tag(from source: String) -> (bank: Int, program: Int)? {
        // Migrate legacy "cello" tag from story 8-1
        if source == "cello" { return (bank: 0, program: 42) }
        guard source.hasPrefix("sf2:") else { return nil }
        let parts = source.dropFirst(4).split(separator: ":")
        guard parts.count == 2,
              let bank = Int(parts[0]),
              let program = Int(parts[1]) else { return nil }
        return (bank: bank, program: program)
    }
}
