import Foundation

nonisolated enum CSVImportError: Error, LocalizedError, Sendable {
    case invalidHeader(expected: String, actual: String)
    case invalidRowData(row: Int, column: String, value: String, reason: String)

    nonisolated var errorDescription: String? {
        switch self {
        case .invalidHeader(let expected, let actual):
            "Invalid header: expected column '\(expected)' but found '\(actual)'"
        case .invalidRowData(let row, let column, let value, let reason):
            "Row \(row), column '\(column)': invalid value '\(value)' — \(reason)"
        }
    }
}
