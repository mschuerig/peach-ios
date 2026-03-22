import SwiftData
import Foundation

/// Central registry of all active training disciplines.
///
/// The registry is the single place that knows which disciplines are active.
/// Adding a discipline: create a conformance and register it.
/// Removing a discipline: delete its files and remove its registration.
final class TrainingDisciplineRegistry: Sendable {

    static let shared = TrainingDisciplineRegistry()

    /// All registered disciplines in display order.
    let all: [any TrainingDiscipline]

    /// Lookup by ID.
    private let byID: [TrainingDisciplineID: any TrainingDiscipline]

    private init() {
        let disciplines: [any TrainingDiscipline] = [
            UnisonPitchDiscriminationDiscipline(),
            IntervalPitchDiscriminationDiscipline(),
            UnisonPitchMatchingDiscipline(),
            IntervalPitchMatchingDiscipline(),
            RhythmOffsetDetectionDiscipline(),
            ContinuousRhythmMatchingDiscipline(),
        ]
        self.all = disciplines
        self.byID = Dictionary(uniqueKeysWithValues: disciplines.map { ($0.id, $0) })
    }

    subscript(_ id: TrainingDisciplineID) -> any TrainingDiscipline {
        byID[id]!
    }

    /// Feeds all registered disciplines' records into a profile builder.
    func feedAllRecords(from store: TrainingDataStore, into builder: PerceptualProfile.Builder) throws {
        for discipline in all {
            try discipline.feedRecords(from: store, into: builder)
        }
    }

    /// The distinct record types across all registered disciplines (deduplicated).
    var recordTypes: [any PersistentModel.Type] {
        var seen = Set<ObjectIdentifier>()
        return all.compactMap { discipline in
            let typeID = ObjectIdentifier(discipline.recordType)
            guard seen.insert(typeID).inserted else { return nil }
            return discipline.recordType
        }
    }
}
