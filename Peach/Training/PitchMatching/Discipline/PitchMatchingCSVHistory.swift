import Foundation

/// CSV identity timeline shared by ``UnisonPitchMatchingDiscipline`` and
/// ``IntervalPitchMatchingDiscipline``: identifier and columns are unchanged
/// across CSV format versions, so a single entry at v1 is enough.
enum PitchMatchingCSVHistory {

    private static let columnsV1 = [
        "referenceNote", "referenceNoteName", "targetNote", "targetNoteName",
        "interval", "tuningSystem", "initialCentOffset", "userCentError",
    ]

    static let history = CSVHistory(entries: [
        CSVHistoryEntry(version: 1, trainingType: "pitchMatching", columns: columnsV1),
    ])
}
