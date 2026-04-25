import SwiftData
import Foundation
import Synchronization

/// Central registry of active training disciplines.
///
/// Core defines the registry mechanism; the App layer owns the policy of which
/// concrete disciplines exist and registers them via ``bootstrap(disciplines:)``
/// at app startup.
final class TrainingDisciplineRegistry: Sendable {

    private static let _shared = Mutex<TrainingDisciplineRegistry?>(nil)

    /// The bootstrapped registry instance.
    ///
    /// Accessing this before ``bootstrap(disciplines:)`` has been called traps.
    /// The App layer must call `bootstrap` as the first step of `PeachApp.init()`,
    /// before any view code or session construction reads `.shared`.
    static var shared: TrainingDisciplineRegistry {
        _shared.withLock { registry in
            guard let registry else {
                preconditionFailure("TrainingDisciplineRegistry.shared accessed before bootstrap(disciplines:)")
            }
            return registry
        }
    }

    /// Initializes the shared registry with the App-provided concrete disciplines.
    /// Must be called exactly once at app startup before any access to ``shared``.
    static func bootstrap(disciplines: [any TrainingDiscipline]) {
        _shared.withLock { registry in
            precondition(registry == nil, "TrainingDisciplineRegistry.bootstrap(disciplines:) called more than once")
            registry = TrainingDisciplineRegistry(disciplines: disciplines)
        }
    }

    /// All registered disciplines in display order.
    let all: [any TrainingDiscipline]

    /// Lookup by ID.
    private let byID: [TrainingDisciplineID: any TrainingDiscipline]

    init(disciplines: [any TrainingDiscipline]) {
        self.all = disciplines
        self.byID = Dictionary(uniqueKeysWithValues: disciplines.map { ($0.id, $0) })

        let commonColumnSet = Set(CSVExportSchema.commonColumns)
        var parsers: [String: any TrainingDiscipline] = [:]
        var columns: [String] = []
        var seenColumns = Set<String>()
        var seenRecordTypes = Set<ObjectIdentifier>()
        var distinctRecordTypes: [any PersistentModel.Type] = []
        for discipline in disciplines {
            if parsers[discipline.csvTrainingType] == nil {
                parsers[discipline.csvTrainingType] = discipline
            }
            for column in discipline.csvColumns where seenColumns.insert(column).inserted {
                assert(!commonColumnSet.contains(column),
                       "Discipline '\(discipline.csvTrainingType)' must not declare common column '\(column)'")
                columns.append(column)
            }
            if seenRecordTypes.insert(ObjectIdentifier(discipline.recordType)).inserted {
                distinctRecordTypes.append(discipline.recordType)
            }
        }
        self.csvParsers = parsers
        self.csvDisciplineColumns = columns
        self.recordTypes = distinctRecordTypes
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

    /// The distinct record types across all registered disciplines (deduplicated).
    let recordTypes: [any PersistentModel.Type]

    /// Lookup: one discipline per CSV training type (first registered wins).
    /// Used by the import parser to dispatch row parsing by training type string.
    let csvParsers: [String: any TrainingDiscipline]

    /// All unique discipline-specific CSV columns, in registration order (deduplicated).
    let csvDisciplineColumns: [String]
}
