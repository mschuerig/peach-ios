import Foundation

/// A handle representing ownership of a playing note.
///
/// Callers receive a `PlaybackHandle` from `NotePlayer.play()` and use it to
/// control the note's lifecycle: stopping playback or adjusting pitch in real time.
///
/// - Note: `stop()` is idempotent — the first call sends noteOff, subsequent calls are no-ops.
protocol PlaybackHandle {
    /// Stops the playing note.
    ///
    /// The first call sends noteOff to the audio engine. Subsequent calls are no-ops.
    ///
    /// - Throws: `AudioError` if the noteOff message cannot be delivered
    func stop() async throws

    /// Adjusts the frequency of the playing note in real time.
    ///
    /// - Parameter frequency: The target frequency in Hz (absolute, not relative)
    /// - Throws: `AudioError` if the pitch adjustment cannot be applied
    func adjustFrequency(_ frequency: Double) async throws
}
