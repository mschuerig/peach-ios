import Foundation

/// Placeholder payload for the experimental cut of the Chromatic Construction
/// discipline. `TrainingDiscipline` requires an `associatedtype Payload`; this
/// empty struct satisfies the protocol without committing to a persistence
/// schema. No record carrying this payload is ever written to the store in
/// this cut — `feedRecords`, `fetchExportRecords`, and `parsedRecords` all
/// short-circuit to empty results on the discipline conformance.
nonisolated struct ChromaticConstructionPayload: TrainingDisciplinePayload {
    static let disciplineIdentifier = "chromaticConstruction"
    static let currentPayloadVersion = 1
}
