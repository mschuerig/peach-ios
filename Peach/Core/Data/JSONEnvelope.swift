import Foundation

/// Errors raised when an envelope's metadata doesn't match the requested payload type.
enum JSONEnvelopeError: Error, Equatable {
    case disciplineMismatch(expected: String, actual: String)
    case unsupportedPayloadVersion(discipline: String, expected: Int, actual: Int)
}

/// Encodes/decodes payload structs to/from ``TrainingRecord`` envelopes.
///
/// Centralizes the JSON encoder configuration so all payloads share the same
/// deterministic key ordering, which keeps stored bytes stable across builds.
/// Encoder/decoder instances are constructed per call: `JSONEncoder`/`JSONDecoder`
/// are non-`Sendable` reference types, so a shared static would be unsafe across
/// concurrent contexts. Allocation cost is negligible compared to the encode work.
enum JSONEnvelope {
    static func encode<P: TrainingDisciplinePayload>(_ payload: P, timestamp: Date) throws -> TrainingRecord {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(payload)
        return TrainingRecord(
            disciplineIdentifier: P.disciplineIdentifier,
            timestamp: timestamp,
            payloadVersion: P.currentPayloadVersion,
            payloadData: data
        )
    }

    static func decode<P: TrainingDisciplinePayload>(_ type: P.Type, from envelope: TrainingRecord) throws -> P {
        guard envelope.disciplineIdentifier == P.disciplineIdentifier else {
            throw JSONEnvelopeError.disciplineMismatch(
                expected: P.disciplineIdentifier,
                actual: envelope.disciplineIdentifier
            )
        }
        guard envelope.payloadVersion == P.currentPayloadVersion else {
            throw JSONEnvelopeError.unsupportedPayloadVersion(
                discipline: P.disciplineIdentifier,
                expected: P.currentPayloadVersion,
                actual: envelope.payloadVersion
            )
        }
        let decoder = JSONDecoder()
        return try decoder.decode(P.self, from: envelope.payloadData)
    }
}
