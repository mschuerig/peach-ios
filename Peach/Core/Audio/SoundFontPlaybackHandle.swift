import AVFoundation
import Foundation

final class SoundFontPlaybackHandle: PlaybackHandle {

    // MARK: - State

    private weak var player: SoundFontPlayer?
    private let engine: SoundFontEngine
    private let channel: MIDIChannel
    private let midiNote: MIDINote
    private let fadeOutDuration: Duration
    private var hasStopped = false

    // MARK: - Initialization

    init(player: SoundFontPlayer, engine: SoundFontEngine, channel: MIDIChannel, midiNote: MIDINote, fadeOutDuration: Duration) {
        self.player = player
        self.engine = engine
        self.channel = channel
        self.midiNote = midiNote
        self.fadeOutDuration = fadeOutDuration
    }

    // MARK: - PlaybackHandle Protocol

    func stop() async throws {
        guard !hasStopped else { return }
        hasStopped = true
        if let player {
            // Chain through the player's serial audio queue so a subsequent
            // play() awaits this stop's mute/restore window and cannot land
            // its noteOn during the global volume==0 phase. Pass the play-time
            // fadeOutDuration: this note fades with the policy it was played
            // under, regardless of any setPreset since.
            await player.scheduleNoteStop(midiNote: midiNote, fadeOutDuration: fadeOutDuration).value
        } else {
            // Player deallocated (test fixtures, app teardown). Fall back to
            // a direct stop — no chain, but no contending plays either.
            if fadeOutDuration > .zero {
                engine.muteForFade()
                try? await Task.sleep(for: fadeOutDuration)
            }
            engine.stopNote(midiNote, channel: channel)
            engine.sendPitchBend(.center, channel: channel)
            if fadeOutDuration > .zero {
                engine.restoreAfterFade()
            }
        }
    }

    func adjustFrequency(_ frequency: Frequency) async throws {
        guard !hasStopped else { return }

        let freq = frequency.rawValue

        guard SoundFontPlayer.validFrequencyRange.contains(freq) else {
            throw AudioError.invalidFrequency(
                "Frequency \(freq) Hz is outside valid range \(SoundFontPlayer.validFrequencyRange)"
            )
        }

        let decomposed = SoundFontPlayer.decompose(frequency: frequency)
        let targetMidi = Double(decomposed.note) + decomposed.cents / Cents.perSemitone
        let baseMidi = Double(midiNote.rawValue)
        let centDifference = (targetMidi - baseMidi) * Cents.perSemitone

        guard centDifference.magnitude <= SoundFontEngine.pitchBendRangeCents else {
            throw AudioError.invalidFrequency(
                "Target frequency \(freq) Hz is \(Int(centDifference.rawValue)) cents from base MIDI note \(midiNote.rawValue), exceeding ±\(Int(SoundFontEngine.pitchBendRangeCents)) cent pitch bend range"
            )
        }

        let bendValue = SoundFontPlayer.pitchBendValue(forCents: centDifference)
        engine.sendPitchBend(bendValue, channel: channel)
    }
}
