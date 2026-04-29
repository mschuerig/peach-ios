import Foundation
import Synchronization

/// Central registry of active training disciplines.
///
/// Core defines the registry mechanism; the App layer owns the policy of which
/// concrete disciplines exist and registers them via ``bootstrap(disciplines:)``
/// at app startup.
final class TrainingDisciplineRegistry: Sendable {

    private static let _bootstrapped = Mutex<TrainingDisciplineRegistry?>(nil)

    #if DEBUG
    /// Task-local override for ``shared``. DEBUG-only — release builds have
    /// no override mechanism, so ``shared`` always returns the bootstrapped
    /// instance.
    ///
    /// When non-nil for the current task, ``shared`` returns this instead of
    /// the bootstrapped instance. Tests use ``RegistryTestSupport``'s
    /// `withOverride(disciplines:body:)` helper to install a non-canonical
    /// registry for the duration of one test, leaving sibling tests in
    /// concurrent tasks unaffected.
    @TaskLocal
    static var override: TrainingDisciplineRegistry? = nil
    #endif

    /// The registry visible to call sites.
    ///
    /// In DEBUG builds, returns the task-local ``override`` if one is active
    /// for the current task; otherwise returns the bootstrapped instance.
    /// In release builds, always returns the bootstrapped instance.
    /// Accessing this before ``bootstrap(disciplines:)`` has been called and
    /// outside any override scope traps.
    static var shared: TrainingDisciplineRegistry {
        #if DEBUG
        if let override { return override }
        #endif
        return _bootstrapped.withLock { registry in
            guard let registry else {
                preconditionFailure("TrainingDisciplineRegistry.shared accessed before bootstrap(disciplines:)")
            }
            return registry
        }
    }

    /// Must be called exactly once at app startup before any access to ``shared``.
    static func bootstrap(disciplines: [any TrainingDiscipline]) {
        _bootstrapped.withLock { registry in
            precondition(registry == nil, "TrainingDisciplineRegistry.bootstrap(disciplines:) called more than once")
            registry = TrainingDisciplineRegistry(disciplines: disciplines)
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
    /// override via ``RegistryTestSupport``'s `withOverride(disciplines:body:)`.
    /// See story 77.10 (`docs/implementation-artifacts/77-10-test-isolation-for-shared-registries.md`).
    static func _replaceSharedForPreviewSupport(disciplines: [any TrainingDiscipline]) {
        _bootstrapped.withLock { registry in
            registry = TrainingDisciplineRegistry(disciplines: disciplines)
        }
    }
    #endif

    /// All registered disciplines in display order.
    let all: [any TrainingDiscipline]

    /// Categories that have at least one registered discipline, in
    /// ``TrainingCategory/allCases`` order.
    ///
    /// A category whose ``disciplines(in:)`` would return an empty array
    /// is omitted, so consumers can iterate this list and render a section
    /// per category without separate emptiness checks.
    let activeCategories: [TrainingCategory]

    /// Lookup by ID.
    private let byID: [TrainingDisciplineID: any TrainingDiscipline]

    init(disciplines: [any TrainingDiscipline]) {
        precondition(!disciplines.isEmpty, "TrainingDisciplineRegistry requires at least one discipline")

        var byID: [TrainingDisciplineID: any TrainingDiscipline] = [:]
        for discipline in disciplines {
            let previous = byID.updateValue(discipline, forKey: discipline.id)
            precondition(previous == nil, "Duplicate discipline registered for id \(discipline.id)")
        }
        self.all = disciplines
        self.byID = byID

        var seenCategories: Set<TrainingCategory> = []
        var heroByCategory: [TrainingCategory: TrainingDisciplineID] = [:]
        for discipline in disciplines {
            seenCategories.insert(discipline.category)
            if discipline.config.isHero {
                if let existing = heroByCategory[discipline.category] {
                    preconditionFailure(
                        "Multiple hero disciplines registered for category \(discipline.category): \(existing) and \(discipline.id)"
                    )
                }
                heroByCategory[discipline.category] = discipline.id
            }
        }
        self.activeCategories = TrainingCategory.allCases.filter(seenCategories.contains)

        let commonColumnSet = Set(CSVExportSchema.commonColumns)
        var parsers: [String: any TrainingDiscipline] = [:]
        var columns: [String] = []
        var seenColumns = Set<String>()
        for discipline in disciplines {
            if parsers[discipline.csvTrainingType] == nil {
                parsers[discipline.csvTrainingType] = discipline
            }
            for column in discipline.csvColumns where seenColumns.insert(column).inserted {
                assert(!commonColumnSet.contains(column),
                       "Discipline '\(discipline.csvTrainingType)' must not declare common column '\(column)'")
                columns.append(column)
            }
        }
        self.csvParsers = parsers
        self.csvDisciplineColumns = columns
    }

    /// Disciplines registered under the given category, preserving registration order.
    func disciplines(in category: TrainingCategory) -> [any TrainingDiscipline] {
        all.filter { $0.category == category }
    }

    subscript(_ id: TrainingDisciplineID) -> any TrainingDiscipline {
        guard let discipline = byID[id] else {
            preconditionFailure("No discipline registered for id \(id)")
        }
        return discipline
    }

    /// Feeds all registered disciplines' records into a profile builder.
    func feedAllRecords(from store: TrainingDataStore, into builder: PerceptualProfile.Builder) throws {
        for discipline in all {
            try discipline.feedRecords(from: store, into: builder)
        }
    }

    /// Lookup: one discipline per CSV training type (first registered wins).
    /// Used by the import parser to dispatch row parsing by training type string.
    let csvParsers: [String: any TrainingDiscipline]

    /// All unique discipline-specific CSV columns, in registration order (deduplicated).
    let csvDisciplineColumns: [String]
}
