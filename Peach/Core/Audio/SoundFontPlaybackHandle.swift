import AVFoundation
import Foundation

final class SoundFontPlaybackHandle: PlaybackHandle {

    // MARK: - State

    private let engine: SoundFontEngine
    private let channel: SoundFontEngine.ChannelID
    private let midiNote: MIDINote
    private let stopPropagationDelay: Duration
    private var hasStopped = false

    // MARK: - Initialization

    init(engine: SoundFontEngine, channel: SoundFontEngine.ChannelID, midiNote: MIDINote, stopPropagationDelay: Duration) {
        self.engine = engine
        self.channel = channel
        self.midiNote = midiNote
        self.stopPropagationDelay = stopPropagationDelay
    }

    // MARK: - PlaybackHandle Protocol

    func stop() async throws {
        guard !hasStopped else { return }
        hasStopped = true
        if stopPropagationDelay > .zero {
            engine.muteForFade()
            try? await Task.sleep(for: stopPropagationDelay)
        }
        engine.stopNote(midiNote, channel: channel)
        engine.sendPitchBend(.center, channel: channel)
        if stopPropagationDelay > .zero {
            engine.restoreAfterFade()
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
