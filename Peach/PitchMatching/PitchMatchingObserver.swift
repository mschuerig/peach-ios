import Foundation

/// Observer protocol for pitch matching completion events
///
/// Observers are notified when a pitch matching exercise is completed during training.
/// This allows decoupling PitchMatchingSession from specific implementations
/// of data storage and profile updates.
///
/// ## Conforming Types
/// - TrainingDataStore: Persists pitch matching results
/// - PerceptualProfile: Updates pitch matching accuracy statistics
protocol PitchMatchingObserver {
    /// Called when a pitch matching exercise is completed
    ///
    /// - Parameter result: The completed pitch matching with user's accuracy
    func pitchMatchingCompleted(_ result: CompletedPitchMatchingTrial)
}
