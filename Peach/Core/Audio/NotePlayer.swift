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

    /// The specified amplitude is invalid (outside -90.0 to +12.0 dB range).
    case invalidAmplitude(String)

    /// The audio context or format could not be created.
    case contextUnavailable
}

/// A protocol for playing musical notes at specified frequencies.
///
/// Conforming types are responsible for generating audio output at precise frequencies.
/// The protocol is frequency-agnostic and has no concept of MIDI notes, cents, or musical context.
///
/// The primary method returns a `PlaybackHandle` that the caller uses to control the note's
/// lifecycle. A fixed-duration convenience method is provided via default extension.
///
/// - Note: Implementations should ensure sub-10ms latency and frequency accuracy within 0.1 cent.
protocol NotePlayer {
    /// Plays a note at the specified frequency and returns a handle for lifecycle control.
    ///
    /// Returns immediately after note onset. The caller owns the returned handle and is
    /// responsible for calling `stop()` on it when the note should end.
    ///
    /// - Parameters:
    ///   - frequency: The frequency in Hz (must be positive and within audible range 20-20000 Hz)
    ///   - velocity: MIDI velocity (1-127); controls timbre/dynamics of the sampled instrument
    ///   - amplitudeDB: dB offset for sound volume (-90.0 to +12.0, 0.0 = no change)
    /// - Returns: A `PlaybackHandle` for controlling the playing note
    /// - Throws: `AudioError` if parameters are outside valid ranges
    func play(frequency: Double, velocity: UInt8, amplitudeDB: Float) async throws -> PlaybackHandle

    /// Plays a note at the specified frequency for a fixed duration.
    ///
    /// A default implementation is provided that acquires a handle, sleeps, then stops.
    /// Declared in the protocol to enable dynamic dispatch for mock overrides in tests.
    ///
    /// - Parameters:
    ///   - frequency: The frequency in Hz (must be positive and within audible range 20-20000 Hz)
    ///   - duration: The total duration of the note in seconds (must be positive)
    ///   - velocity: MIDI velocity (1-127); controls timbre/dynamics of the sampled instrument
    ///   - amplitudeDB: dB offset for sound volume (-90.0 to +12.0, 0.0 = no change)
    /// - Throws: `AudioError` if parameters are outside valid ranges
    func play(frequency: Double, duration: TimeInterval, velocity: UInt8, amplitudeDB: Float) async throws
}

extension NotePlayer {
    /// Plays a note at the specified frequency for a fixed duration.
    ///
    /// Convenience method that internally acquires a handle, sleeps for the duration,
    /// then stops the note. Handles cancellation gracefully via the handle's idempotent stop.
    ///
    /// - Parameters:
    ///   - frequency: The frequency in Hz (must be positive and within audible range 20-20000 Hz)
    ///   - duration: The total duration of the note in seconds (must be positive)
    ///   - velocity: MIDI velocity (1-127); controls timbre/dynamics of the sampled instrument
    ///   - amplitudeDB: dB offset for sound volume (-90.0 to +12.0, 0.0 = no change)
    /// - Throws: `AudioError` if parameters are outside valid ranges
    func play(frequency: Double, duration: TimeInterval, velocity: UInt8, amplitudeDB: Float) async throws {
        let handle = try await play(frequency: frequency, velocity: velocity, amplitudeDB: amplitudeDB)
        do {
            try await Task.sleep(for: .seconds(duration))
            try await handle.stop()
        } catch {
            try? await handle.stop()
            throw error
        }
    }

    /// Stops playback immediately (backward-compatible no-op).
    ///
    /// Retained during transition to PlaybackHandle-based lifecycle.
    /// Stopping is done through the handle; this method exists only so that
    /// existing call sites compile without changes until they are migrated.
    func stop() async throws {
        // No-op — stopping is managed through PlaybackHandle
    }
}
