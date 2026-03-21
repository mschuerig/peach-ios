import Foundation

/// Protocol for pitch comparison selection strategies in adaptive training
///
/// Defines the contract for algorithms that select the next pitch comparison
/// based on the user's perceptual profile and training settings.
///
/// # Architecture Boundary
///
/// NextPitchDiscriminationStrategy reads from TrainingProfile and PitchDiscriminationSettings,
/// and returns a PitchDiscriminationTrial value type. It has no concept of:
/// - Audio playback (NotePlayer's responsibility)
/// - Data persistence (TrainingDataStore's responsibility)
/// - Profile updates (TrainingProfile's responsibility)
/// - UI rendering (SwiftUI's responsibility)
///
/// # Usage
///
/// The default implementation (`KazezNoteStrategy`) is injected into PitchDiscriminationSession
/// in `PeachApp.swift` (Story 9.1).
/// ```swift
/// let strategy: NextPitchDiscriminationStrategy = KazezNoteStrategy()
/// let trial = strategy.nextPitchDiscriminationTrial(profile: profile, settings: settings, lastTrial: nil, interval: .prime)
/// ```
protocol NextPitchDiscriminationStrategy {
    /// Selects the next pitch comparison based on user's perceptual profile and settings
    ///
    /// Stateless selection - all inputs passed via parameters, output depends only on inputs.
    ///
    /// - Parameters:
    ///   - profile: User's perceptual profile with training statistics
    ///   - settings: Training configuration (note range, difficulty bounds, reference pitch)
    ///   - lastTrial: The most recently completed pitch comparison (nil on first comparison)
    ///   - interval: The directed musical interval to apply between reference and target note.
    ///     `.prime` produces unison (target == reference); other intervals transpose the target
    ///     by the interval's semitone count via `MIDINote.transposed(by:)`.
    /// - Returns: A PitchDiscriminationTrial ready to be played by NotePlayer
    func nextPitchDiscriminationTrial(
        profile: TrainingProfile,
        settings: PitchDiscriminationSettings,
        lastTrial: CompletedPitchDiscriminationTrial?,
        interval: DirectedInterval
    ) -> PitchDiscriminationTrial
}
