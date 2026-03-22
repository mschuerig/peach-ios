import SwiftData
import Foundation

/// Defines the contract for a training discipline: display metadata, statistics configuration,
/// record type, and data integration points (profile feeding, CSV formatting, duplicate detection).
///
/// Each discipline is a conforming struct defined in its respective feature directory.
/// The ``TrainingDisciplineRegistry`` is the single place that knows which disciplines are active.
protocol TrainingDiscipline: Sendable {
    /// Stable identifier for this discipline.
    var id: TrainingDisciplineID { get }

    /// Display and statistics configuration (name, unit label, baseline, EWMA parameters).
    var config: TrainingDisciplineConfig { get }

    /// The statistics keys this discipline contributes to the profile.
    /// Pitch disciplines return a single key; rhythm disciplines return tempo × direction permutations.
    var statisticsKeys: [StatisticsKey] { get }

    /// The SwiftData model type this discipline persists.
    var recordType: any PersistentModel.Type { get }

    /// Feeds stored records into a profile builder for initial profile construction.
    func feedRecords(from store: TrainingDataStore, into builder: PerceptualProfile.Builder) throws

    /// Fetches and formats this discipline's records as CSV rows for export.
    func fetchAndFormatRecords(from store: TrainingDataStore) throws -> [(timestamp: Date, row: String)]

    /// Returns this discipline's parsed records from a CSV import result.
    func parsedRecords(from parseResult: CSVImportParser.ImportResult) -> [any PersistentModel]

    /// Merges imported records, skipping duplicates that already exist in the store.
    func mergeImportRecords(
        from parseResult: CSVImportParser.ImportResult,
        into store: TrainingDataStore
    ) throws -> (imported: Int, skipped: Int)
}
