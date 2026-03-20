import AVFoundation
import Foundation

final class SoundFontPlaybackHandle: PlaybackHandle {

    // MARK: - State

    private let engine: SoundFontEngine
    private let midiNote: MIDINote
    private let stopPropagationDelay: Duration
    private var hasStopped = false

    // MARK: - Initialization

    init(engine: SoundFontEngine, midiNote: MIDINote, stopPropagationDelay: Duration) {
        self.engine = engine
        self.midiNote = midiNote
        self.stopPropagationDelay = stopPropagationDelay
    }

    // MARK: - PlaybackHandle Protocol

    func stop() async throws {
        guard !hasStopped else { return }
        hasStopped = true
        if stopPropagationDelay > .zero {
            engine.sampler.volume = 0
            try? await Task.sleep(for: stopPropagationDelay)
        }
        engine.stopNote(midiNote)
        engine.sendPitchBend(.center)
        if stopPropagationDelay > .zero {
            engine.sampler.volume = 1.0
        }
    }

    func adjustFrequency(_ frequency: Frequency) async throws {
        guard !hasStopped else { return }

        let freq = frequency.rawValue

        guard SoundFontNotePlayer.validFrequencyRange.contains(freq) else {
            throw AudioError.invalidFrequency(
                "Frequency \(freq) Hz is outside valid range \(SoundFontNotePlayer.validFrequencyRange)"
            )
        }

        let decomposed = SoundFontNotePlayer.decompose(frequency: frequency)
        let targetMidi = Double(decomposed.note) + decomposed.cents.rawValue / 100.0
        let baseMidi = Double(midiNote.rawValue)
        let centDifference = (targetMidi - baseMidi) * 100.0

        guard abs(centDifference) <= SoundFontEngine.pitchBendRangeCents else {
            throw AudioError.invalidFrequency(
                "Target frequency \(freq) Hz is \(Int(centDifference)) cents from base MIDI note \(midiNote.rawValue), exceeding ±\(Int(SoundFontEngine.pitchBendRangeCents)) cent pitch bend range"
            )
        }

        let bendValue = SoundFontNotePlayer.pitchBendValue(forCents: Cents(centDifference))
        engine.sendPitchBend(bendValue)
    }
}
