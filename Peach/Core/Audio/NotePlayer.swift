import Foundation

/// Errors that can occur during audio playback operations.
public enum AudioError: Error {
    /// The audio engine failed to start.
    /// - Parameter message: Detailed error context
    case engineStartFailed(String)

    /// Failed to attach an audio node to the engine.
    /// - Parameter message: Detailed error context
    case nodeAttachFailed(String)

    /// Audio rendering failed during playback.
    /// - Parameter message: Detailed error context
    case renderFailed(String)

    /// The specified frequency is invalid (negative, zero, or outside audible range).
    /// - Parameter message: Detailed error context including the invalid value
    case invalidFrequency(String)

    /// The specified duration is invalid (zero or negative).
    /// - Parameter message: Detailed error context including the invalid value
    case invalidDuration(String)

    /// The specified amplitude is invalid (outside 0.0-1.0 range).
    /// - Parameter message: Detailed error context including the invalid value
    case invalidAmplitude(String)

    /// The specified preset is invalid (program or bank outside valid MIDI range).
    /// - Parameter message: Detailed error context including the invalid value
    case invalidPreset(String)

    /// The audio context or format could not be created.
    case contextUnavailable
}

/// A protocol for playing musical notes at specified frequencies.
///
/// Conforming types are responsible for generating audio output at precise frequencies
/// with controlled envelopes to prevent audible artifacts. The protocol is frequency-agnostic
/// and has no concept of MIDI notes, cents, or musical context.
///
/// # Settings Integration (Epic 6)
///
/// The duration parameter enables configurable note length. In Epic 6, the Settings screen
/// will expose a note duration preference (stored in @AppStorage). TrainingSession will read
/// this value and pass it to NotePlayer.play(duration:) for each note.
///
/// Example future integration:
/// ```swift
/// @AppStorage("noteDuration") private var noteDuration: Double = 1.0
///
/// func playNote() async throws {
///     let frequency = try FrequencyCalculation.frequency(midiNote: note, referencePitch: referencePitch)
///     try await notePlayer.play(frequency: frequency, duration: noteDuration, amplitude: 0.5)
/// }
/// ```
///
/// - Note: Implementations should ensure sub-10ms latency and frequency accuracy within 0.1 cent.
@MainActor
public protocol NotePlayer {
    /// Plays a note at the specified frequency for the given duration.
    ///
    /// The duration parameter controls the total length of the note, including envelope
    /// (attack/release). The implementation ensures the envelope stays within the specified duration.
    ///
    /// # Examples
    /// ```swift
    /// // Play A4 (440 Hz) for 1 second at default amplitude
    /// try await player.play(frequency: 440.0, duration: 1.0, amplitude: 0.5)
    ///
    /// // Play a short note (100ms) for rapid training
    /// try await player.play(frequency: 523.25, duration: 0.1, amplitude: 0.5)
    ///
    /// // Play a long note (2 seconds) for careful listening
    /// try await player.play(frequency: 261.63, duration: 2.0, amplitude: 0.5)
    /// ```
    ///
    /// - Parameters:
    ///   - frequency: The frequency in Hz (must be positive and within audible range 20-20000 Hz)
    ///   - duration: The total duration of the note in seconds (must be positive)
    ///   - amplitude: The amplitude/volume (0.0 to 1.0, default: 0.5)
    /// - Throws: `AudioError.invalidFrequency` if parameters are outside valid ranges
    func play(frequency: Double, duration: TimeInterval, amplitude: Double) async throws

    /// Stops playback cleanly with a release envelope to prevent clicks.
    ///
    /// - Throws: `AudioError` if playback cannot be stopped gracefully
    func stop() async throws
}
