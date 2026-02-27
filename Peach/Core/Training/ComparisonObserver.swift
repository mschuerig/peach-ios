import Foundation

/// Observer protocol for comparison completion events
///
/// Observers are notified when a comparison is completed during training.
/// This allows decoupling ComparisonSession from specific implementations
/// of data storage, analytics, and feedback mechanisms.
///
/// ## Conforming Types
/// - TrainingDataStore: Persists comparison results
/// - PerceptualProfile: Updates detection threshold statistics
/// - HapticFeedbackManager: Provides haptic feedback
///
/// ## Usage
/// ```swift
/// extension TrainingDataStore: ComparisonObserver {
///     func comparisonCompleted(_ completed: CompletedComparison) {
///         let record = ComparisonRecord(...)
///         try? save(record)
///     }
/// }
/// ```
protocol ComparisonObserver {
    /// Called when a comparison is completed during training
    ///
    /// - Parameter completed: The completed comparison with user's answer and result
    func comparisonCompleted(_ completed: CompletedComparison)
}
