import AVFoundation
import Foundation

/// A `PlaybackHandle` implementation that wraps a MIDI note playing on an `AVAudioUnitSampler`.
///
/// Created by `SoundFontNotePlayer` when a note is started. The handle owns the note's
/// lifecycle: calling `stop()` sends MIDI noteOff, and `adjustFrequency()` applies pitch bend.
final class SoundFontPlaybackHandle: PlaybackHandle {

    // MARK: - State

    private let sampler: AVAudioUnitSampler
    private let midiNote: UInt8
    private let channel: UInt8
    private var hasStopped = false

    // MARK: - Initialization

    init(sampler: AVAudioUnitSampler, midiNote: UInt8, channel: UInt8) {
        self.sampler = sampler
        self.midiNote = midiNote
        self.channel = channel
    }

    // MARK: - PlaybackHandle Protocol

    func stop() async throws {
        guard !hasStopped else { return }
        hasStopped = true
        sampler.stopNote(midiNote, onChannel: channel)
        sampler.sendPitchBend(SoundFontNotePlayer.pitchBendCenter, onChannel: channel)
    }

    func adjustFrequency(_ frequency: Double) async throws {
        guard !hasStopped else { return }

        guard SoundFontNotePlayer.validFrequencyRange.contains(frequency) else {
            throw AudioError.invalidFrequency(
                "Frequency \(frequency) Hz is outside valid range \(SoundFontNotePlayer.validFrequencyRange)"
            )
        }

        let conversion = FrequencyCalculation.midiNoteAndCents(frequency: frequency)
        let targetMidi = Double(conversion.midiNote) + conversion.cents / 100.0
        let baseMidi = Double(midiNote)
        let centDifference = (targetMidi - baseMidi) * 100.0

        guard abs(centDifference) <= 200.0 else {
            throw AudioError.invalidFrequency(
                "Target frequency \(frequency) Hz is \(Int(centDifference)) cents from base MIDI note \(midiNote), exceeding ±200 cent pitch bend range"
            )
        }

        let bendValue = SoundFontNotePlayer.pitchBendValue(forCents: centDifference)
        sampler.sendPitchBend(bendValue, onChannel: channel)
    }
}
