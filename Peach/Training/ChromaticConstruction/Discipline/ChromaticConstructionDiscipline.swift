import Foundation
import SwiftUI

/// Experimental-cut conformance: no statistics, no help content, no profile
/// card override, no settings sections. The discipline registers a Start
/// screen card and a routing destination; everything else inherits the
/// ``TrainingDisciplineUI`` defaults or returns an empty result. Persistence
/// is fully deferred — `feedRecords` and every CSV method short-circuits.
struct ChromaticConstructionDiscipline: TrainingDisciplineUI, Sendable {

    let id = TrainingDisciplineID.chromaticConstruction

    let category: TrainingCategory = .intervals

    let config = TrainingDisciplineConfig(
        displayName: String(localized: "Walk the Steps"),
        shortLabel: String(localized: "Walk"),
        systemImageName: "stairs",
        isHero: false,
        helpDescription: String(localized: "Walk step by step from a lower anchor to an upper anchor in equal cent steps."),
        unitLabel: String(localized: "cents"),
        unitSymbol: String(localized: "¢"),
        optimalBaseline: 0.0,
        statistics: .default
    )

    var statisticsKeys: [StatisticsKey] { [] }

    var helpSections: [HelpSection] { [] }

    let navigationDestination: NavigationDestination = .chromaticConstruction

    // MARK: - Profile feeding (no-op: no records persisted)

    func feedRecords(from store: TrainingDataStore, into builder: PerceptualProfile.Builder) throws {
        // No-op: the experimental cut writes no records.
    }

    // MARK: - CSV (no-op stub conformance)

    let csvTrainingType = "chromaticConstruction"

    let csvColumns: [String] = []

    var csvHistory: CSVHistory { ChromaticConstructionCSVHistory.history }

    func csvKeyValuePairs(for payload: ChromaticConstructionPayload) -> [(String, String)] { [] }

    func parseCSVRow(
        fields: [String],
        columnIndex: [String: Int],
        rowNumber: Int
    ) -> Result<(timestamp: Date, payload: ChromaticConstructionPayload), CSVImportError> {
        .failure(.invalidRowData(
            row: rowNumber,
            column: "row",
            value: "",
            reason: "chromatic-construction has no CSV columns in the experimental cut"
        ))
    }

    func fetchExportRecords(from store: TrainingDataStore) throws -> [(timestamp: Date, payload: ChromaticConstructionPayload)] { [] }

    func parsedRecords(from parseResult: CSVImportParser.ImportResult) -> [(timestamp: Date, payload: ChromaticConstructionPayload)] { [] }

    func mergeImportRecords(
        from parseResult: CSVImportParser.ImportResult,
        existingIn store: TrainingDataStore,
        into scope: TrainingDataStore.TransactionScope
    ) throws -> (imported: Int, skipped: Int) {
        (imported: 0, skipped: 0)
    }
}
