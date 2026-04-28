import Foundation

/// A discipline's serializable record payload.
///
/// Each discipline's payload struct conforms to this protocol. The payload's
/// fields define the JSON shape persisted inside ``TrainingRecord/payloadData``.
///
/// `disciplineIdentifier` is the routing key SwiftData fetches filter by;
/// `currentPayloadVersion` lets a discipline's adapter migrate older payload
/// versions on read when its own schema evolves.
protocol TrainingDisciplinePayload: Codable, Sendable {
    static var disciplineIdentifier: String { get }
    static var currentPayloadVersion: Int { get }
}
