import Foundation
import SwiftData

/// Single SwiftData envelope for all training records.
///
/// Every discipline persists into the same SwiftData entity. Each discipline
/// encodes its own JSON payload and writes the bytes to ``payloadData``;
/// SwiftData itself never sees discipline-specific schema, so adding or
/// evolving a discipline does not require a SwiftData schema migration.
///
/// ``disciplineIdentifier`` filters envelopes to a single discipline at fetch
/// time (`disciplineIdentifier == Self.Payload.disciplineIdentifier` in the
/// adapter); ``payloadVersion`` lets a discipline's adapter switch between
/// payload struct versions when its own schema evolves.
@Model
final class TrainingRecord {
    #Index<TrainingRecord>([\.disciplineIdentifier, \.timestamp])

    var disciplineIdentifier: String
    var timestamp: Date
    var payloadVersion: Int
    var payloadData: Data

    init(disciplineIdentifier: String, timestamp: Date, payloadVersion: Int, payloadData: Data) {
        self.disciplineIdentifier = disciplineIdentifier
        self.timestamp = timestamp
        self.payloadVersion = payloadVersion
        self.payloadData = payloadData
    }
}

extension TrainingRecord: Timestamped {}
