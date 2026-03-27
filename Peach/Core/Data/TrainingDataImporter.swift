import Foundation
import SwiftData

enum TrainingDataImporter {

    enum ImportMode {
        case replace
        case merge
    }

    struct ImportSummary {
        let perDiscipline: [TrainingDisciplineID: (imported: Int, skipped: Int)]
        let parseErrorCount: Int

        var totalImported: Int {
            perDiscipline.values.reduce(0) { $0 + $1.imported }
        }

        var totalSkipped: Int {
            perDiscipline.values.reduce(0) { $0 + $1.skipped }
        }

        func imported(for id: TrainingDisciplineID) -> Int {
            perDiscipline[id]?.imported ?? 0
        }

        func skipped(for id: TrainingDisciplineID) -> Int {
            perDiscipline[id]?.skipped ?? 0
        }
    }

    static func importData(
        _ parseResult: CSVImportParser.ImportResult,
        mode: ImportMode,
        into store: TrainingDataStore
    ) throws -> ImportSummary {
        switch mode {
        case .replace:
            return try replaceAll(parseResult, into: store)
        case .merge:
            return try mergeRecords(parseResult, into: store)
        }
    }

    // MARK: - Replace Mode

    private static func replaceAll(
        _ parseResult: CSVImportParser.ImportResult,
        into store: TrainingDataStore
    ) throws -> ImportSummary {
        var allRecords: [any PersistentModel] = []
        var perDiscipline: [TrainingDisciplineID: (imported: Int, skipped: Int)] = [:]

        for discipline in TrainingDisciplineRegistry.shared.all {
            let records = discipline.parsedRecords(from: parseResult)
            allRecords.append(contentsOf: records)
            perDiscipline[discipline.id] = (imported: records.count, skipped: 0)
        }

        try store.replaceAllRecords(allRecords)
        return ImportSummary(perDiscipline: perDiscipline, parseErrorCount: parseResult.errors.count)
    }

    // MARK: - Merge Mode

    private static func mergeRecords(
        _ parseResult: CSVImportParser.ImportResult,
        into store: TrainingDataStore
    ) throws -> ImportSummary {
        var perDiscipline: [TrainingDisciplineID: (imported: Int, skipped: Int)] = [:]

        try store.withinTransaction { scope in
            for discipline in TrainingDisciplineRegistry.shared.all {
                let result = try discipline.mergeImportRecords(from: parseResult, existingIn: store, into: scope)
                perDiscipline[discipline.id] = result
            }
        }

        return ImportSummary(perDiscipline: perDiscipline, parseErrorCount: parseResult.errors.count)
    }
}
