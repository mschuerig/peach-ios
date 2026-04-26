import SwiftData
import Foundation

/// Defines the contract for a training discipline: display metadata, statistics configuration,
/// record type, data integration points (profile feeding, CSV formatting, duplicate detection),
/// and CSV column ownership (export/import).
///
/// Each discipline is a conforming struct defined in its respective feature directory.
/// The ``TrainingDisciplineRegistry`` is the single place that knows which disciplines are active.
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

    /// The SwiftData model type this discipline persists.
    var recordType: any PersistentModel.Type { get }

    /// Help sections shown when the user opens the help sheet for this discipline.
    var helpSections: [HelpSection] { get }

    /// Routing target for navigating to this discipline's training screen.
    var navigationDestination: NavigationDestination { get }

    // MARK: - UI Contributions
    //
    // Disciplines are statically-compiled plugins: each one contributes the
    // pieces of UI it owns rather than letting screens gate fragments by
    // category. The App layer maps these enum-typed identifiers to concrete
    // SwiftUI views and ``HelpSection`` values, keeping Core decoupled from
    // SwiftUI. Aggregating screens deduplicate equal contributions across the
    // registered set, so a category-scoped contribution (e.g. rhythm tempo)
    // can be declared by every discipline in that category and still appear
    // exactly once.

    /// The profile card this discipline renders on ``ProfileScreen``.
    var profileCard: ProfileCardKind { get }

    /// Settings sections this discipline contributes to ``SettingsScreen``.
    /// Default: none. Each section is rendered between the always-on common
    /// sections in stable order.
    var settingsContributions: [SettingsSectionKind] { get }

    /// Scoped help sections this discipline contributes to the profile help
    /// sheet. Default: none. Sections describing a shared visualization
    /// (e.g. the rhythm spectrogram) are typically declared by every
    /// discipline that uses the visualization; the screen deduplicates.
    var profileHelpContributions: [ProfileHelpKind] { get }

    /// Feeds stored records into a profile builder for initial profile construction.
    func feedRecords(from store: TrainingDataStore, into builder: PerceptualProfile.Builder) throws

    // MARK: - CSV Column Ownership

    /// The training type string used in CSV export/import (e.g., "pitchDiscrimination").
    /// This is a stable wire-format identifier shared with other apps (e.g., peach-web)
    /// and must not change when internal type names are renamed.
    var csvTrainingType: String { get }

    /// Column names specific to this discipline (excluding common columns: trainingType, timestamp).
    var csvColumns: [String] { get }

    /// Produces key-value pairs from a record for CSV export.
    /// Keys are column names from ``csvColumns``.
    func csvKeyValuePairs(for record: any PersistentModel) -> [(String, String)]

    /// Parses a CSV row into a record using named column lookup.
    func parseCSVRow(fields: [String], columnIndex: [String: Int], rowNumber: Int) -> Result<any PersistentModel, CSVImportError>

    /// Fetches this discipline's records for export, sorted by timestamp.
    func fetchExportRecords(from store: TrainingDataStore) throws -> [(timestamp: Date, record: any PersistentModel)]

    /// Returns this discipline's parsed records from a CSV import result.
    func parsedRecords(from parseResult: CSVImportParser.ImportResult) -> [any PersistentModel]

    /// Merges imported records, skipping duplicates that already exist in the store.
    /// Reads existing records from `store` for duplicate detection; writes new records through `scope`.
    func mergeImportRecords(
        from parseResult: CSVImportParser.ImportResult,
        existingIn store: TrainingDataStore,
        into scope: TrainingDataStore.TransactionScope
    ) throws -> (imported: Int, skipped: Int)
}

extension TrainingDiscipline {
    var profileCard: ProfileCardKind { .progressChart }
    var settingsContributions: [SettingsSectionKind] { [] }
    var profileHelpContributions: [ProfileHelpKind] { [] }
}
