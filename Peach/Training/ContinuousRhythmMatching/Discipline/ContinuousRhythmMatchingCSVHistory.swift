import Foundation

/// CSV identity timeline for ``ContinuousRhythmMatchingDiscipline``.
///
/// - v1, v2: did not exist. CSV v2 had a now-retired discipline named
///   `rhythmMatching` whose rows are inherited at v3 via
///   ``CSVHistoryEntry/previousTrainingType``.
/// - v3: introduced as `continuousRhythmMatching`. Carries the
///   `userOffsetMs → meanOffsetMs` value transform for v2 rows.
enum ContinuousRhythmMatchingCSVHistory {

    static let history = CSVHistory(entries: [
        CSVHistoryEntry(
            version: 3,
            trainingType: "continuousRhythmMatching",
            columns: [
                "tempoBPM", "meanOffsetMs",
                "meanOffsetMsPosition0", "meanOffsetMsPosition1",
                "meanOffsetMsPosition2", "meanOffsetMsPosition3",
            ],
            previousTrainingType: "rhythmMatching",
            valueTransformsFromPrevious: [
                .renameColumnWithFallback(from: "userOffsetMs", to: "meanOffsetMs"),
            ]
        ),
    ])
}
