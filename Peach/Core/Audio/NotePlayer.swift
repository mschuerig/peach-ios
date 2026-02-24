import Foundation

/// Errors that can occur during audio playback operations.
enum AudioError: Error {
    /// The audio engine failed to start.
    case engineStartFailed(String)

    /// The specified frequency is invalid (negative, zero, or outside audible range).
    case invalidFrequency(String)

    /// The specified duration is invalid (zero or negative).
    case invalidDuration(String)

    /// The specified velocity is invalid (outside 1-127 MIDI range).
    case invalidVelocity(String)

    /// The specified preset is invalid (program or bank outside valid MIDI range).
    case invalidPreset(String)

    /// The audio context or format could not be created.
    case contextUnavailable
}

/// A protocol for playing musical notes at specified frequencies.
///
/// Conforming types are responsible for generating audio output at precise frequencies.
/// The protocol is frequency-agnostic and has no concept of MIDI notes, cents, or musical context.
///
/// - Note: Implementations should ensure sub-10ms latency and frequency accuracy within 0.1 cent.
protocol NotePlayer {
    /// Plays a note at the specified frequency for the given duration.
    ///
    /// - Parameters:
    ///   - frequency: The frequency in Hz (must be positive and within audible range 20-20000 Hz)
    ///   - duration: The total duration of the note in seconds (must be positive)
    ///   - velocity: MIDI velocity (1-127); controls timbre/dynamics of the sampled instrument
    /// - Throws: `AudioError` if parameters are outside valid ranges
    func play(frequency: Double, duration: TimeInterval, velocity: UInt8) async throws

    /// Stops playback immediately.
    ///
    /// - Throws: `AudioError` if playback cannot be stopped gracefully
    func stop() async throws
}
