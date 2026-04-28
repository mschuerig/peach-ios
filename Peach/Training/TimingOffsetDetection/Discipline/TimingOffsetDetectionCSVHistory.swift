import Foundation

/// CSV identity timeline for ``TimingOffsetDetectionDiscipline``.
///
/// - v1: did not exist (CSV v1 had only pitch disciplines).
/// - v2: introduced as `rhythmOffsetDetection` with columns
///   `isCorrect`, `tempoBPM`, `offsetMs`.
/// - v3: unchanged from v2 — entry omitted.
enum TimingOffsetDetectionCSVHistory {

    static let history = CSVHistory(entries: [
        CSVHistoryEntry(
            version: 2,
            trainingType: "rhythmOffsetDetection",
            columns: ["isCorrect", "tempoBPM", "offsetMs"]
        ),
    ])
}
