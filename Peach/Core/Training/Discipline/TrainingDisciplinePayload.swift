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
    /// each payload to `P`.
    ///
    /// Caller-side invariant: `trainingType` must be the discipline's
    /// `csvTrainingType` and `P` must be that discipline's `Payload` —
    /// the parser keys entries by `trainingType` and produces them with
    /// the matching `P`. A cast mismatch indicates a programmer error
    /// (a stale or mispaired call site) and triggers `assertionFailure`
    /// in debug; in release builds the offending entry is skipped.
    static func typedEntries<P: TrainingDisciplinePayload>(
        from parseResult: CSVImportParser.ImportResult,
        forTrainingType trainingType: String,
        ofType _: P.Type
    ) -> [(timestamp: Date, payload: P)] {
        (parseResult.payloads[trainingType] ?? []).compactMap { entry in
            guard let payload = entry.payload as? P else {
                assertionFailure(
                    "typedEntries: trainingType '\(trainingType)' carries a payload not of type \(P.self)"
                )
                return nil
            }
            return (entry.timestamp, payload)
        }
    }
}
