import Foundation

/// CSV identity timeline shared by ``UnisonPitchDiscriminationDiscipline`` and
/// ``IntervalPitchDiscriminationDiscipline``: same wire-format identifier and
/// columns at every version.
///
/// - v1: identifier was `pitchComparison`.
/// - v2: renamed to `pitchDiscrimination` (no column change).
/// - v3: unchanged from v2 — entry omitted.
enum PitchDiscriminationCSVHistory {

    private static let columnsV1AndV2 = [
        "referenceNote", "referenceNoteName", "targetNote", "targetNoteName",
        "interval", "tuningSystem", "centOffset", "isCorrect",
    ]

    static let history = CSVHistory(entries: [
        CSVHistoryEntry(version: 1, trainingType: "pitchComparison", columns: columnsV1AndV2),
        CSVHistoryEntry(version: 2, trainingType: "pitchDiscrimination", columns: columnsV1AndV2),
    ])
}
