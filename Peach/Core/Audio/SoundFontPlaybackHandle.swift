import AVFoundation
import Foundation

final class SoundFontPlaybackHandle: PlaybackHandle {

    // MARK: - State

    private let sampler: AVAudioUnitSampler
    private let midiNote: UInt8
    private let channel: UInt8
    private let stopPropagationDelay: Duration
    private var hasStopped = false

    // MARK: - Initialization

    init(sampler: AVAudioUnitSampler, midiNote: UInt8, channel: UInt8, stopPropagationDelay: Duration) {
        self.sampler = sampler
        self.midiNote = midiNote
        self.channel = channel
        self.stopPropagationDelay = stopPropagationDelay
    }

    // MARK: - PlaybackHandle Protocol

    func stop() async throws {
        guard !hasStopped else { return }
        hasStopped = true
        if stopPropagationDelay > .zero {
            sampler.volume = 0
            try? await Task.sleep(for: stopPropagationDelay)
        }
        sampler.stopNote(midiNote, onChannel: channel)
        sampler.sendPitchBend(SoundFontNotePlayer.pitchBendCenter, onChannel: channel)
        if stopPropagationDelay > .zero {
            sampler.volume = 1.0
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

        let pitch = Pitch(frequency: frequency, referencePitch: .concert440)
        let targetMidi = Double(pitch.note.rawValue) + pitch.cents.rawValue / 100.0
        let baseMidi = Double(midiNote)
        let centDifference = (targetMidi - baseMidi) * 100.0

        guard abs(centDifference) <= 200.0 else {
            throw AudioError.invalidFrequency(
                "Target frequency \(freq) Hz is \(Int(centDifference)) cents from base MIDI note \(midiNote), exceeding ±200 cent pitch bend range"
            )
        }

        let bendValue = SoundFontNotePlayer.pitchBendValue(forCents: Cents(centDifference))
        sampler.sendPitchBend(bendValue, onChannel: channel)
    }
}
