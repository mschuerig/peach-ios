import Foundation
@preconcurrency import SwiftData

enum CSVImportParser {

    struct ImportResult {
        var records: [String: [any PersistentModel]]
        var errors: [CSVImportError]

        var isEmpty: Bool {
            records.values.allSatisfy { $0.isEmpty }
        }

        var totalRecordCount: Int {
            records.values.reduce(0) { $0 + $1.count }
        }
    }

    static func parse(_ csvContent: String) -> ImportResult {
        let lines = CSVParserHelpers.splitIntoLines(csvContent)

        guard let firstLine = lines.first, !firstLine.isEmpty else {
            return ImportResult(records: [:], errors: [.missingVersion])
        }

        guard firstLine.hasPrefix(CSVExportSchema.metadataPrefix) else {
            return ImportResult(records: [:], errors: [.missingVersion])
        }

        let versionString = String(firstLine.dropFirst(CSVExportSchema.metadataPrefix.count))
        guard let version = Int(versionString) else {
            return ImportResult(records: [:], errors: [.invalidFormatMetadata(line: firstLine)])
        }

        let currentVersion = CSVExportSchema.formatVersion

        guard version >= 1, version <= currentVersion else {
            return ImportResult(records: [:], errors: [.unsupportedVersion(version: version)])
        }

        let remainingLines = Array(lines.dropFirst())

        if version < currentVersion {
            return parseMigratedLines(remainingLines, fromVersion: version)
        }

        return parseLines(remainingLines)
    }

    // MARK: - Migration

    private static func parseMigratedLines(_ lines: [String], fromVersion: Int) -> ImportResult {
        guard let headerLine = lines.first, !headerLine.isEmpty else {
            return ImportResult(records: [:], errors: [.invalidHeader(expected: "(header)", actual: "(empty)")])
        }

        let headerColumns = CSVParserHelpers.parseCSVLine(headerLine)
        let dataLines = lines.dropFirst()

        var rowDicts: [[String: String]] = []
        for line in dataLines where !line.isEmpty {
            let fields = CSVParserHelpers.parseCSVLine(line)
            var dict: [String: String] = [:]
            for (index, column) in headerColumns.enumerated() where index < fields.count {
                dict[column] = fields[index]
            }
            rowDicts.append(dict)
        }

        let migratedRows = CSVMigrationChain.migrate(
            from: fromVersion,
            to: CSVExportSchema.formatVersion,
            rows: rowDicts
        )

        let currentColumns = CSVExportSchema.allColumns
        let headerRow = currentColumns.map { CSVParserHelpers.escapeField($0) }.joined(separator: ",")

        var reconstructedLines = [headerRow]
        for dict in migratedRows {
            let fields = currentColumns.map { CSVParserHelpers.escapeField(dict[$0] ?? "") }
            reconstructedLines.append(fields.joined(separator: ","))
        }

        return parseLines(reconstructedLines)
    }

    // MARK: - Line Parsing

    private static func parseLines(_ lines: [String]) -> ImportResult {
        var records: [String: [any PersistentModel]] = [:]
        var errors: [CSVImportError] = []

        guard let headerLine = lines.first, !headerLine.isEmpty else {
            errors.append(.invalidHeader(expected: CSVExportSchema.headerRow, actual: "(empty)"))
            return ImportResult(records: [:], errors: errors)
        }

        let headerColumns = CSVParserHelpers.parseCSVLine(headerLine)
        let expectedColumns = CSVExportSchema.allColumns

        if headerColumns.count != expectedColumns.count {
            errors.append(.invalidHeader(
                expected: "\(expectedColumns.count) columns",
                actual: "\(headerColumns.count) columns"
            ))
            return ImportResult(records: [:], errors: errors)
        }

        for (index, expectedColumn) in expectedColumns.enumerated() {
            if headerColumns[index] != expectedColumn {
                errors.append(.invalidHeader(expected: expectedColumn, actual: headerColumns[index]))
                return ImportResult(records: [:], errors: errors)
            }
        }

        let columnIndex = Dictionary(uniqueKeysWithValues: headerColumns.enumerated().map { ($1, $0) })
        let registry = TrainingDisciplineRegistry.shared

        let dataLines = lines.dropFirst()
        for (index, line) in dataLines.enumerated() {
            if line.isEmpty { continue }
            let rowNumber = index + 1
            let fields = CSVParserHelpers.parseCSVLine(line)

            guard fields.count == expectedColumns.count else {
                errors.append(.invalidRowData(
                    row: rowNumber,
                    column: "row",
                    value: "\(fields.count) fields",
                    reason: "expected \(expectedColumns.count) fields"
                ))
                continue
            }

            guard let trainingTypeIdx = columnIndex["trainingType"] else { continue }
            let trainingType = fields[trainingTypeIdx]

            guard let discipline = registry.csvParsers[trainingType] else {
                let validTypes = registry.csvParsers.keys.sorted().joined(separator: "', '")
                errors.append(.invalidRowData(
                    row: rowNumber,
                    column: "trainingType",
                    value: trainingType,
                    reason: "must be '\(validTypes)'"
                ))
                continue
            }

            switch discipline.parseCSVRow(fields: fields, columnIndex: columnIndex, rowNumber: rowNumber) {
            case .success(let record):
                records[trainingType, default: []].append(record)
            case .failure(let error):
                errors.append(error)
            }
        }

        return ImportResult(records: records, errors: errors)
    }
}
