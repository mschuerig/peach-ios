import Foundation

/// CSV identity timeline for ``ChromaticConstructionDiscipline``.
///
/// The discipline ships in the experimental cut without persistence — no
/// `@Model`, no exported rows, no imported rows. The single entry exists only
/// to satisfy ``CSVHistory``'s non-empty-entries precondition and to register
/// the discipline's wire-format `trainingType` for migration discovery,
/// matching the unconditional ``DisciplineBootstrap/allCSVHistories`` slot.
enum ChromaticConstructionCSVHistory {

    static let history = CSVHistory(entries: [
        CSVHistoryEntry(
            version: CSVExportSchema.formatVersion,
            trainingType: "chromaticConstruction",
            columns: []
        ),
    ])
}
