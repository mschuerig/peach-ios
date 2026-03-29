import Foundation
import Synchronization
import Testing
@testable import Peach

@Suite("SessionLifecycle")
struct SessionLifecycleTests {

    // MARK: - Factory

    private static func makeLifecycle(
        notificationCenter: NotificationCenter = NotificationCenter(),
        onStopRequired: @escaping () -> Void = {}
    ) -> SessionLifecycle {
        SessionLifecycle(
            logger: .init(subsystem: "test", category: "SessionLifecycleTests"),
            notificationCenter: notificationCenter,
            audioInterruptionObserver: NoOpAudioInterruptionObserver(),
            onStopRequired: onStopRequired
        )
    }

    // MARK: - cancelAllTasks

    @Test("cancelAllTasks cancels and nils both training and feedback tasks")
    func cancelAllTasksCancelsBothTasks() async {
        let lifecycle = Self.makeLifecycle()

        lifecycle.setTrainingTask(Task {
            try? await Task.sleep(for: .seconds(60))
        })
        lifecycle.setFeedbackTask(Task {
            try? await Task.sleep(for: .seconds(60))
        })

        #expect(lifecycle.hasTrainingTask)
        #expect(lifecycle.hasFeedbackTask)

        lifecycle.cancelAllTasks()

        #expect(!lifecycle.hasTrainingTask)
        #expect(!lifecycle.hasFeedbackTask)
    }

    // MARK: - setFeedbackTask replaces previous

    @Test("setFeedbackTask cancels previous task and starts new one")
    func setFeedbackTaskReplacesPrevious() async {
        let lifecycle = Self.makeLifecycle()
        let firstTaskCancelled = Mutex(false)

        lifecycle.setFeedbackTask(Task {
            do {
                try await Task.sleep(for: .seconds(60))
            } catch {
                firstTaskCancelled.withLock { $0 = true }
            }
        })

        try? await Task.sleep(for: .milliseconds(10))

        let secondTaskRan = Mutex(false)
        lifecycle.setFeedbackTask(Task {
            secondTaskRan.withLock { $0 = true }
        })

        try? await Task.sleep(for: .milliseconds(50))

        #expect(firstTaskCancelled.withLock { $0 })
        #expect(secondTaskRan.withLock { $0 })
    }

    // MARK: - setTrainingTask replaces previous

    @Test("setTrainingTask cancels previous task and starts new one")
    func setTrainingTaskReplacesPrevious() async {
        let lifecycle = Self.makeLifecycle()
        let firstTaskCancelled = Mutex(false)

        lifecycle.setTrainingTask(Task {
            do {
                try await Task.sleep(for: .seconds(60))
            } catch {
                firstTaskCancelled.withLock { $0 = true }
            }
        })

        try? await Task.sleep(for: .milliseconds(10))

        let secondTaskRan = Mutex(false)
        lifecycle.setTrainingTask(Task {
            secondTaskRan.withLock { $0 = true }
        })

        try? await Task.sleep(for: .milliseconds(50))

        #expect(firstTaskCancelled.withLock { $0 })
        #expect(secondTaskRan.withLock { $0 })
    }

    // MARK: - interruptionMonitor calls onStopRequired

    @Test("interruptionMonitor triggers onStopRequired via injected observer")
    func interruptionMonitorCallsOnStopRequired() async {
        let notificationCenter = NotificationCenter()
        let stopRequiredCalled = Mutex(false)
        let mockObserver = CallbackAudioInterruptionObserver()

        let lifecycle = SessionLifecycle(
            logger: .init(subsystem: "test", category: "SessionLifecycleTests"),
            notificationCenter: notificationCenter,
            audioInterruptionObserver: mockObserver,
            onStopRequired: { stopRequiredCalled.withLock { $0 = true } }
        )

        mockObserver.simulateInterruption()

        #expect(stopRequiredCalled.withLock { $0 })
        _ = lifecycle // keep alive
    }
}

// MARK: - Test Helpers

private final class CallbackAudioInterruptionObserver: AudioInterruptionObserving {
    private var storedOnStopRequired: (() -> Void)?

    func setupObservers(
        notificationCenter: NotificationCenter,
        onStopRequired: @escaping () -> Void
    ) -> [NSObjectProtocol] {
        storedOnStopRequired = onStopRequired
        return []
    }

    func simulateInterruption() {
        storedOnStopRequired?()
    }
}
