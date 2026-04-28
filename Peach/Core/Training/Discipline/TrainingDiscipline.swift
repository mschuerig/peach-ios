import Foundation

/// Defines the contract for a training discipline: display metadata, statistics configuration,
/// payload type, data integration points (profile feeding, CSV formatting, duplicate detection),
/// and CSV column ownership (export/import).
///
/// Each discipline is a conforming struct defined in its respective feature directory.
/// The ``TrainingDisciplineRegistry`` is the single place that knows which disciplines are active.
///
/// View-producing requirements live on the App-layer refinement
/// ``TrainingDisciplineUI``; Core stays Foundation-only so Core/Data services
/// (`TrainingDataExporter`, `CSVImportParser`, `TrainingDataStore`) can consume
/// the registry without pulling SwiftUI into the data layer.
protocol TrainingDiscipline: Sendable {
    /// Stable identifier for this discipline.
    var id: TrainingDisciplineID { get }

    /// Display partition for grouping in lists and menus. Each discipline
    /// belongs to exactly one category.
    var category: TrainingCategory { get }

    /// Display and statistics configuration (name, unit label, baseline, EWMA parameters).
    var config: TrainingDisciplineConfig { get }

    /// The statistics keys this discipline contributes to the profile.
    /// Pitch disciplines return a single key; rhythm disciplines return tempo × direction permutations.
    var statisticsKeys: [StatisticsKey] { get }

    /// Help sections shown when the user opens the help sheet for this discipline.
    var helpSections: [HelpSection] { get }

    /// Routing target for navigating to this discipline's training screen.
    var navigationDestination: NavigationDestination { get }

    /// Feeds stored payloads into a profile builder for initial profile construction.
    func feedRecords(from store: TrainingDataStore, into builder: PerceptualProfile.Builder) throws

    // MARK: - CSV Column Ownership

    /// The training type string used in CSV export/import (e.g., "pitchDiscrimination").
    /// This is a stable wire-format identifier shared with other apps (e.g., peach-web)
    /// and must not change when internal type names are renamed.
    var csvTrainingType: String { get }

    /// Column names specific to this discipline (excluding common columns: trainingType, timestamp).
    var csvColumns: [String] { get }

    /// CSV format history: the format versions this discipline appeared in,
    /// the trainingType identifier and columns at each version, and any
    /// value transforms attached to a version's introduction.
    /// The migration runner derives v → v+1 operations from these snapshots.
    var csvHistory: CSVHistory { get }

    /// Produces key-value pairs from a payload for CSV export.
    /// Keys are column names from ``csvColumns``.
    func csvKeyValuePairs(for payload: any TrainingDisciplinePayload) -> [(String, String)]

    /// Parses a CSV row into a `(timestamp, payload)` pair using named column lookup.
    func parseCSVRow(
        fields: [String],
        columnIndex: [String: Int],
        rowNumber: Int
    ) -> Result<(timestamp: Date, payload: any TrainingDisciplinePayload), CSVImportError>

    /// Fetches this discipline's payloads for export, sorted by timestamp.
    func fetchExportRecords(from store: TrainingDataStore) throws -> [(timestamp: Date, payload: any TrainingDisciplinePayload)]

    /// Returns this discipline's parsed payloads from a CSV import result.
    func parsedRecords(from parseResult: CSVImportParser.ImportResult) -> [(timestamp: Date, payload: any TrainingDisciplinePayload)]

    /// Merges imported payloads, skipping duplicates that already exist in the store.
    /// Reads existing payloads from `store` for duplicate detection; encodes new
    /// payloads into envelopes and inserts them through `scope`.
    func mergeImportRecords(
        from parseResult: CSVImportParser.ImportResult,
        existingIn store: TrainingDataStore,
        into scope: TrainingDataStore.TransactionScope
    ) throws -> (imported: Int, skipped: Int)
}
