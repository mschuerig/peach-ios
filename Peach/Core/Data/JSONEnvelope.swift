import Foundation

/// Encodes/decodes payload structs to/from ``TrainingRecord`` envelopes.
///
/// Centralizes the JSON encoder configuration so all payloads share the same
/// deterministic key ordering, which keeps stored bytes stable across builds.
enum JSONEnvelope {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder = JSONDecoder()

    static func encode<P: TrainingDisciplinePayload>(_ payload: P, timestamp: Date) throws -> TrainingRecord {
        let data = try encoder.encode(payload)
        return TrainingRecord(
            disciplineIdentifier: P.disciplineIdentifier,
            timestamp: timestamp,
            payloadVersion: P.currentPayloadVersion,
            payloadData: data
        )
    }

    static func decode<P: TrainingDisciplinePayload>(_ type: P.Type, from envelope: TrainingRecord) throws -> P {
        try decoder.decode(P.self, from: envelope.payloadData)
    }
}
