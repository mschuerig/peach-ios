import Foundation
@testable import Peach

extension TrainingDisciplineRegistry {
    /// Runs `body` with the given disciplines installed as the task-local
    /// ``TrainingDisciplineRegistry/override`` on ``shared``. Outside this
    /// scope (and in concurrently-executing tasks), ``shared`` returns the
    /// bootstrapped registry unchanged.
    ///
    /// This is race-free: a sibling test in another task observes its own
    /// task-local (typically nil, falling through to the bootstrapped
    /// instance), never this body's installed override. Story 77.10
    /// migrated tests off the previous `_replaceSharedForTesting` mechanism,
    /// which mutated the process-wide slot and was visible across tasks.
    static func withOverride<R>(
        disciplines: [any TrainingDiscipline],
        body: () throws -> R
    ) rethrows -> R {
        try TrainingDisciplineRegistry.$override.withValue(
            TrainingDisciplineRegistry(disciplines: disciplines),
            operation: body
        )
    }
}

extension CSVHistoryRegistry {
    /// Runs `body` with the given histories installed as the task-local
    /// ``CSVHistoryRegistry/override`` on ``shared``. Outside this scope
    /// (and in concurrently-executing tasks), ``shared`` returns the
    /// bootstrapped registry unchanged. Symmetric counterpart of
    /// ``TrainingDisciplineRegistry/withOverride(disciplines:body:)``.
    static func withOverride<R>(
        histories: [CSVHistory],
        body: () throws -> R
    ) rethrows -> R {
        try CSVHistoryRegistry.$override.withValue(
            CSVHistoryRegistry(histories: histories),
            operation: body
        )
    }
}
