import Foundation
import Synchronization

/// Catalog of every known ``CSVHistory``, available to the CSV migration
/// runner regardless of which disciplines are active for parsing in the
/// current build.
///
/// The migration runner cannot rely on ``TrainingDisciplineRegistry/shared``:
/// a non-research build excludes Continuous Rhythm Matching from the parser
/// registry, but a v2 CSV containing `rhythmMatching` rows must still be
/// migrated to v3 shape (the row will simply fail dispatch downstream if no
/// parser exists). Histories therefore live in a separate, build-flag-
/// independent registry that the App layer bootstraps with the union of all
/// known histories at startup.
final class CSVHistoryRegistry: Sendable {

    private static let _bootstrapped = Mutex<CSVHistoryRegistry?>(nil)

    #if DEBUG
    /// Task-local override for ``shared``. DEBUG-only — release builds have
    /// no override mechanism, so ``shared`` always returns the bootstrapped
    /// instance.
    ///
    /// When non-nil for the current task, ``shared`` returns this instead of
    /// the bootstrapped instance. Tests use ``RegistryTestSupport``'s
    /// `withOverride(histories:body:)` helper to install a non-canonical
    /// catalog for the duration of one test, leaving sibling tests in
    /// concurrent tasks unaffected.
    @TaskLocal
    static var override: CSVHistoryRegistry? = nil
    #endif

    /// The registry visible to call sites.
    ///
    /// In DEBUG builds, returns the task-local ``override`` if one is active
    /// for the current task; otherwise returns the bootstrapped instance.
    /// In release builds, always returns the bootstrapped instance.
    /// Accessing this before ``bootstrap(histories:)`` has been called and
    /// outside any override scope traps.
    static var shared: CSVHistoryRegistry {
        #if DEBUG
        if let override { return override }
        #endif
        return _bootstrapped.withLock { registry in
            guard let registry else {
                preconditionFailure("CSVHistoryRegistry.shared accessed before bootstrap(histories:)")
            }
            return registry
        }
    }

    /// Must be called exactly once at app startup before any access to
    /// ``shared``.
    static func bootstrap(histories: [CSVHistory]) {
        _bootstrapped.withLock { registry in
            precondition(registry == nil, "CSVHistoryRegistry.bootstrap(histories:) called more than once")
            registry = CSVHistoryRegistry(histories: histories)
        }
    }

    #if DEBUG
    /// Atomically replaces the bootstrapped registry slot. **Preview support
    /// only.** SwiftUI may render previews repeatedly in the same process,
    /// and a preview render does not enter an explicit `Task` whose locals
    /// can host a `withValue` scope, so previews need to re-write the
    /// process-wide slot to ensure ``shared`` returns a populated registry.
    ///
    /// Tests must NOT call this — mutating the bootstrapped slot races with
    /// tests in concurrently-executing tasks. Tests scope a per-task
    /// override via `$override.withValue { ... }`.
    /// See story 77.10 (`docs/implementation-artifacts/77-10-test-isolation-for-shared-registries.md`).
    static func _replaceSharedForPreviewSupport(histories: [CSVHistory]) {
        _bootstrapped.withLock { registry in
            registry = CSVHistoryRegistry(histories: histories)
        }
    }
    #endif

    let histories: [CSVHistory]

    init(histories: [CSVHistory]) {
        self.histories = histories
    }
}
