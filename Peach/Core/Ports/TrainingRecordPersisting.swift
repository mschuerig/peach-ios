import SwiftData

/// Port protocol for persisting training records.
///
/// Discipline-specific adapters map their trial results to records and delegate
/// persistence to this protocol, keeping the data store free of discipline knowledge.
protocol TrainingRecordPersisting {
    func save(_ record: some PersistentModel) throws
}
