import Foundation

/// Shared constants for training session behavior.
///
/// These are perceptual design decisions that affect both pitch comparison
/// and pitch matching sessions. Extracted here for discoverability and
/// single-source-of-truth tuning.
enum TrainingConstants {
    /// Duration the feedback indicator displays after each attempt.
    ///
    /// 0.4s is a perceptual learning design decision: long enough to register,
    /// short enough to maintain flow.
    static let feedbackDuration: Duration = .milliseconds(400)

    /// MIDI velocity used for all training note playback.
    ///
    /// 63 is approximately mezzo-piano -- loud enough to hear clearly
    /// without fatiguing the listener during extended sessions.
    static let velocity: MIDIVelocity = 63
}
