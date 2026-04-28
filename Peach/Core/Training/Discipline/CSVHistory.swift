import Foundation

/// A discipline's CSV identity over time: the format versions it appeared in,
/// the `trainingType` identifier it used at each version, the columns it owned,
/// and any per-step value transforms.
///
/// Snapshots, not deltas. The migration runner derives the operations needed for
/// a step (v → v+1) by looking at entries whose ``CSVHistoryEntry/version`` equals
/// `v+1`: the trainingType change since the previous entry, plus any value
/// transforms attached to that entry.
///
/// A discipline that did not yet exist at a version simply has no entry below it.
/// A discipline whose CSV identity did not change between two consecutive versions
/// only needs one entry at the version where it last changed.
struct CSVHistory: Sendable, Equatable {
    let entries: [CSVHistoryEntry]

    init(entries: [CSVHistoryEntry]) {
        precondition(!entries.isEmpty, "CSVHistory must have at least one entry")
        precondition(
            entries.map(\.version) == entries.map(\.version).sorted(),
            "CSVHistory entries must be ordered by ascending version"
        )
        precondition(
            Set(entries.map(\.version)).count == entries.count,
            "CSVHistory must not contain duplicate versions"
        )
        self.entries = entries
    }

    /// The entry whose ``CSVHistoryEntry/version`` equals `version`, or `nil`.
    func entry(at version: Int) -> CSVHistoryEntry? {
        entries.first { $0.version == version }
    }

    /// The most recent entry with version ≤ `version`, or `nil` if the
    /// discipline did not yet exist at that version.
    func effectiveEntry(at version: Int) -> CSVHistoryEntry? {
        entries.last { $0.version <= version }
    }
}

struct CSVHistoryEntry: Sendable, Equatable {
    /// CSV format version this snapshot describes.
    let version: Int
    /// `trainingType` wire-format identifier at this version.
    let trainingType: String
    /// Discipline-specific columns at this version (excluding common columns).
    let columns: [String]
    /// Identifier this discipline replaces at this version. Used when a
    /// discipline is *introduced* and inherits rows from a now-retired
    /// identifier (e.g., `rhythmMatching` → `continuousRhythmMatching` at v3).
    let previousTrainingType: String?
    /// Value transforms that ran during the (previous → this) step. Applied
    /// globally to all rows in the step. Empty for the common case where a
    /// header diff (column add/drop) is enough.
    let valueTransformsFromPrevious: [CSVValueTransform]

    init(
        version: Int,
        trainingType: String,
        columns: [String],
        previousTrainingType: String? = nil,
        valueTransformsFromPrevious: [CSVValueTransform] = []
    ) {
        self.version = version
        self.trainingType = trainingType
        self.columns = columns
        self.previousTrainingType = previousTrainingType
        self.valueTransformsFromPrevious = valueTransformsFromPrevious
    }
}

/// A column-level value transform applied during a single (v → v+1) step.
///
/// Each case operates on the row dictionary directly. Transforms apply to all
/// rows in the step — column ownership is the discipline's, but column data
/// lives in every row uniformly.
enum CSVValueTransform: Sendable, Equatable {
    /// Move the value from `from` to `to`, preserving any pre-existing `to`
    /// value. The `from` key is removed from the row in either case.
    case renameColumnWithFallback(from: String, to: String)

    func apply(to row: [String: String]) -> [String: String] {
        var result = row
        switch self {
        case let .renameColumnWithFallback(from, to):
            let fromValue = result.removeValue(forKey: from) ?? ""
            result[to] = result[to] ?? fromValue
        }
        return result
    }
}
