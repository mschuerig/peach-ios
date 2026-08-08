import Foundation
@testable import Peach

/// Empty payload type for synthetic test fixtures: the disciplines that use
/// this never produce or parse records, so the payload's shape is irrelevant —
/// only the protocol conformance is.
struct SyntheticPayload: TrainingDisciplinePayload {
    static let disciplineIdentifier = "synthetic"
    static let currentPayloadVersion = 1
}

/// Synthetic discipline fixture for exercising registry algorithms over
/// arbitrary category mixes without depending on the real bootstrap list.
struct SyntheticDiscipline: TrainingDiscipline, Sendable {
    let id: TrainingDisciplineID
    let category: TrainingCategory
    var isHero: Bool = false

    var config: TrainingDisciplineConfig {
        TrainingDisciplineConfig(
            displayName: id.slug,
            shortLabel: id.slug,
            systemImageName: "questionmark",
            isHero: isHero,
            helpDescription: "",
            unitLabel: "u",
            unitSymbol: "u",
            optimalBaseline: 0,
            statistics: .default
        )
    }

    var statisticsKeys: [StatisticsKey] { [.pitch(id)] }

    var helpSections: [HelpSection] { [] }

    var navigationDestination: NavigationDestination { .profile }

    var csvTrainingType: String { id.slug }

    var csvColumns: [String] { ["__synthetic_\(id.slug)"] }

    var csvHistory: CSVHistory {
        CSVHistory(entries: [
            CSVHistoryEntry(version: 1, trainingType: id.slug, columns: ["__synthetic_\(id.slug)"]),
        ])
    }

    func feedRecords(from store: TrainingDataStore, into builder: PerceptualProfile.Builder) throws {}

    func csvKeyValuePairs(for payload: SyntheticPayload) -> [(String, String)] { [] }

    func parseCSVRow(
        fields: [String],
        columnIndex: [String: Int],
        rowNumber: Int
    ) -> Result<(timestamp: Date, payload: SyntheticPayload), CSVImportError> {
        .failure(.invalidRowData(row: rowNumber, column: "synthetic", value: "", reason: "synthetic"))
    }

    func fetchExportRecords(from store: TrainingDataStore) throws -> [(timestamp: Date, payload: SyntheticPayload)] { [] }

    func parsedRecords(from parseResult: CSVImportParser.ImportResult) -> [(timestamp: Date, payload: SyntheticPayload)] { [] }

    func mergeImportRecords(
        from parseResult: CSVImportParser.ImportResult,
        existingIn store: TrainingDataStore,
        into scope: TrainingDataStore.TransactionScope
    ) throws -> (imported: Int, skipped: Int) { (0, 0) }
}
