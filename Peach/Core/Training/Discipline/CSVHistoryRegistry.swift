import Foundation
import Synchronization

/// Catalog of every known ``CSVHistory``, available to the CSV migration
/// runner regardless of which disciplines are active for parsing in the
/// current build.
///
/// The migration runner cannot rely on ``TrainingDisciplineRegistry/shared``:
/// a non-research build excludes timing disciplines from the parser registry,
/// but a v2 CSV containing `rhythmMatching` rows must still be migrated to
/// v3 shape (the row will simply fail dispatch downstream if no parser
/// exists). Histories therefore live in a separate, build-flag-independent
/// registry that the App layer bootstraps with the union of all known
/// histories at startup.
final class CSVHistoryRegistry: Sendable {

    private static let _shared = Mutex<CSVHistoryRegistry?>(nil)

    /// The bootstrapped registry instance.
    ///
    /// Accessing this before ``bootstrap(histories:)`` has been called traps.
    static var shared: CSVHistoryRegistry {
        _shared.withLock { registry in
            guard let registry else {
                preconditionFailure("CSVHistoryRegistry.shared accessed before bootstrap(histories:)")
            }
            return registry
        }
    }

    /// Must be called exactly once at app startup before any access to
    /// ``shared``.
    static func bootstrap(histories: [CSVHistory]) {
        _shared.withLock { registry in
            precondition(registry == nil, "CSVHistoryRegistry.bootstrap(histories:) called more than once")
            registry = CSVHistoryRegistry(histories: histories)
        }
    }

    #if DEBUG
    /// Atomically replaces the shared registry. DEBUG-only; for use by
    /// SwiftUI preview helpers and tests that need a known catalog.
    static func _replaceSharedForTesting(histories: [CSVHistory]) {
        _shared.withLock { registry in
            registry = CSVHistoryRegistry(histories: histories)
        }
    }
    #endif

    let histories: [CSVHistory]

    init(histories: [CSVHistory]) {
        self.histories = histories
    }
}
