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
    ///
    /// **Scope caveats.** The override is propagated only through
    /// structured-concurrency descendants of the calling task. Reads from
    /// `Task.detached { … }` or from an unstructured `Task { … }` spawned
    /// inside `body` do NOT observe the override; they fall through to the
    /// bootstrapped registry. If `body` returns a closure or `Task` handle
    /// that reads ``shared`` after `body` has returned, that read also
    /// happens outside the scope and likewise sees the bootstrapped
    /// registry. For async bodies use the `() async throws -> R` overload.
    static func withOverride<R>(
        disciplines: [any TrainingDiscipline],
        body: () throws -> R
    ) rethrows -> R {
        try TrainingDisciplineRegistry.$override.withValue(
            TrainingDisciplineRegistry(disciplines: disciplines),
            operation: body
        )
    }

    /// Async variant of ``withOverride(disciplines:body:)``. Awaits `body`
    /// inside the override scope so structured-concurrency descendants
    /// (`async let`, `TaskGroup`) run under the override. The caveats about
    /// `Task.detached` / unstructured `Task { … }` and post-scope reads still
    /// apply.
    static func withOverride<R>(
        disciplines: [any TrainingDiscipline],
        body: () async throws -> R
    ) async rethrows -> R {
        try await TrainingDisciplineRegistry.$override.withValue(
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
    ///
    /// This is race-free: a sibling test in another task observes its own
    /// task-local (typically nil, falling through to the bootstrapped
    /// instance), never this body's installed override. Story 77.10
    /// migrated tests off the previous `_replaceSharedForTesting` mechanism,
    /// which mutated the process-wide slot and was visible across tasks.
    ///
    /// **Scope caveats.** The override is propagated only through
    /// structured-concurrency descendants of the calling task. Reads from
    /// `Task.detached { … }` or from an unstructured `Task { … }` spawned
    /// inside `body` do NOT observe the override; they fall through to the
    /// bootstrapped registry. If `body` returns a closure or `Task` handle
    /// that reads ``shared`` after `body` has returned, that read also
    /// happens outside the scope and likewise sees the bootstrapped
    /// registry. For async bodies use the `() async throws -> R` overload.
    static func withOverride<R>(
        histories: [CSVHistory],
        body: () throws -> R
    ) rethrows -> R {
        try CSVHistoryRegistry.$override.withValue(
            CSVHistoryRegistry(histories: histories),
            operation: body
        )
    }

    /// Async variant of ``withOverride(histories:body:)``. Awaits `body`
    /// inside the override scope so structured-concurrency descendants
    /// (`async let`, `TaskGroup`) run under the override. The caveats about
    /// `Task.detached` / unstructured `Task { … }` and post-scope reads still
    /// apply.
    static func withOverride<R>(
        histories: [CSVHistory],
        body: () async throws -> R
    ) async rethrows -> R {
        try await CSVHistoryRegistry.$override.withValue(
            CSVHistoryRegistry(histories: histories),
            operation: body
        )
    }
}
