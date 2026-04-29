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

/// A decoded payload paired with the envelope's stored timestamp.
///
/// Used as the return shape of payload-typed fetches so call sites can use
/// `.timestamp` and `.payload` accessors rather than tuple destructuring,
/// and so two `TimestampedPayload` values can be compared with `==` in tests.
struct TimestampedPayload<P: TrainingDisciplinePayload>: Sendable {
    let timestamp: Date
    let payload: P
}

extension TimestampedPayload: Equatable where P: Equatable {}

/// Shared helpers operating on the heterogeneous payload map that
/// ``CSVImportParser/ImportResult`` exposes.
enum TrainingDisciplinePayloads {
    /// Typed extraction at the existential→concrete boundary: returns
    /// `(timestamp, payload)` entries for the given training type, casting
    /// each payload to `P` and skipping ones that don't match. Disciplines
    /// pass their own `csvTrainingType` and `Payload` type; the parser
    /// produced these with the same `P`, so the cast is total in practice.
    static func typedEntries<P: TrainingDisciplinePayload>(
        from parseResult: CSVImportParser.ImportResult,
        forTrainingType trainingType: String,
        ofType _: P.Type
    ) -> [(timestamp: Date, payload: P)] {
        (parseResult.payloads[trainingType] ?? []).compactMap { entry in
            (entry.payload as? P).map { (entry.timestamp, $0) }
        }
    }
}
