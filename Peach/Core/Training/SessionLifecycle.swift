import Foundation
import os

final class SessionLifecycle {

    private let logger: Logger
    private var interruptionMonitor: AudioSessionInterruptionMonitor?
    private var trainingTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?

    var hasTrainingTask: Bool { trainingTask != nil }
    var hasFeedbackTask: Bool { feedbackTask != nil }

    init(
        logger: Logger,
        notificationCenter: NotificationCenter = .default,
        audioInterruptionObserver: AudioInterruptionObserving,
        backgroundNotificationName: Notification.Name? = nil,
        foregroundNotificationName: Notification.Name? = nil,
        onStopRequired: @escaping () -> Void
    ) {
        self.logger = logger
        self.interruptionMonitor = AudioSessionInterruptionMonitor(
            notificationCenter: notificationCenter,
            logger: logger,
            audioInterruptionObserver: audioInterruptionObserver,
            backgroundNotificationName: backgroundNotificationName,
            foregroundNotificationName: foregroundNotificationName,
            onStopRequired: onStopRequired
        )
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
