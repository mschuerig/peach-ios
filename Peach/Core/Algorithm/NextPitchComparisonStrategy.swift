import Foundation

/// Protocol for pitch comparison selection strategies in adaptive training
///
/// Defines the contract for algorithms that select the next pitch comparison
/// based on the user's perceptual profile and training settings.
///
/// # Architecture Boundary
///
/// NextPitchComparisonStrategy reads from TrainingProfile and PitchComparisonTrainingSettings,
/// and returns a PitchComparison value type. It has no concept of:
/// - Audio playback (NotePlayer's responsibility)
/// - Data persistence (TrainingDataStore's responsibility)
/// - Profile updates (TrainingProfile's responsibility)
/// - UI rendering (SwiftUI's responsibility)
///
/// # Usage
///
/// The default implementation (`KazezNoteStrategy`) is injected into PitchComparisonSession
/// in `PeachApp.swift` (Story 9.1).
/// ```swift
/// let strategy: NextPitchComparisonStrategy = KazezNoteStrategy()
/// let pitchComparison = strategy.nextPitchComparison(profile: profile, settings: settings, lastPitchComparison: nil, interval: .prime)
/// ```
protocol NextPitchComparisonStrategy {
    /// Selects the next pitch comparison based on user's perceptual profile and settings
    ///
    /// Stateless selection - all inputs passed via parameters, output depends only on inputs.
    ///
    /// - Parameters:
    ///   - profile: User's perceptual profile with training statistics
    ///   - settings: Training configuration (note range, difficulty bounds, reference pitch)
    ///   - lastPitchComparison: The most recently completed pitch comparison (nil on first comparison)
    ///   - interval: The directed musical interval to apply between reference and target note.
    ///     `.prime` produces unison (target == reference); other intervals transpose the target
    ///     by the interval's semitone count via `MIDINote.transposed(by:)`.
    /// - Returns: A PitchComparison ready to be played by NotePlayer
    func nextPitchComparison(
        profile: TrainingProfile,
        settings: PitchComparisonTrainingSettings,
        lastPitchComparison: CompletedPitchComparison?,
        interval: DirectedInterval
    ) -> PitchComparison
}
