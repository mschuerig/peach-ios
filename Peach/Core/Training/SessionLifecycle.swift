import Foundation
import os

/// Owns task cancellation for a training session. Audio-interruption observation
/// moved to `AppAudioInfrastructureMonitor` (Story 85.8) — the centralized
/// observer routes session stops via `TrainingLifecycleCoordinator`.
final class SessionLifecycle {

    private let logger: Logger
    private var trainingTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?

    var hasTrainingTask: Bool { trainingTask != nil }
    var hasFeedbackTask: Bool { feedbackTask != nil }

    init(logger: Logger) {
        self.logger = logger
    }

    // MARK: - Training Task

    func setTrainingTask(_ task: Task<Void, Never>) {
        trainingTask?.cancel()
        trainingTask = task
    }

    func cancelTrainingTask() {
        trainingTask?.cancel()
        trainingTask = nil
    }

    // MARK: - Feedback Task

    func setFeedbackTask(_ task: Task<Void, Never>) {
        feedbackTask?.cancel()
        feedbackTask = task
    }

    func cancelFeedbackTask() {
        feedbackTask?.cancel()
        feedbackTask = nil
    }

    // MARK: - Bulk Operations

    func cancelAllTasks() {
        cancelTrainingTask()
        cancelFeedbackTask()
    }
}
