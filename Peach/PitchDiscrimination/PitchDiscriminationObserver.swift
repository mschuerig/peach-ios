import Foundation

/// Observer protocol for pitch discrimination completion events
///
/// Observers are notified when a pitch discrimination is completed during training.
/// This allows decoupling PitchDiscriminationSession from specific implementations
/// of data storage, analytics, and feedback mechanisms.
///
/// ## Conforming Types
/// - TrainingDataStore: Persists pitch discrimination results
/// - PerceptualProfile: Updates detection threshold statistics
/// - ProgressTimeline: Tracks accuracy trends and timeline data per training discipline
/// - HapticFeedbackManager: Provides haptic feedback
///
/// ## Usage
/// ```swift
/// extension TrainingDataStore: PitchDiscriminationObserver {
///     func pitchDiscriminationCompleted(_ completed: CompletedPitchDiscriminationTrial) {
///         let record = PitchDiscriminationRecord(...)
///         try? save(record)
///     }
/// }
/// ```
protocol PitchDiscriminationObserver {
    /// Called when a pitch discrimination is completed during training
    ///
    /// - Parameter completed: The completed pitch discrimination with user's answer and result
    func pitchDiscriminationCompleted(_ completed: CompletedPitchDiscriminationTrial)
}
