import Testing
import Foundation
@testable import Peach

/// Defensive coverage against silent JSON-key drift across discipline payloads.
///
/// Each test builds a payload, encodes it through ``JSONEnvelope`` into a
/// ``TrainingRecord``, decodes it back, and asserts equality.
@Suite("Payload Round-Trip Tests")
struct PayloadRoundTripTests {

    @Test("PitchDiscriminationPayload round-trips through TrainingRecord")
    func pitchDiscriminationRoundTrip() async throws {
        let timestamp = Date()
        let payload = PitchDiscriminationPayload(
            referenceNote: 60,
            targetNote: 67,
            centOffset: 25.0,
            isCorrect: true,
            interval: 7,
            tuningSystem: "equalTemperament"
        )

        let envelope = try JSONEnvelope.encode(payload, timestamp: timestamp)
        #expect(envelope.disciplineIdentifier == PitchDiscriminationPayload.disciplineIdentifier)
        #expect(envelope.payloadVersion == PitchDiscriminationPayload.currentPayloadVersion)
        #expect(envelope.timestamp == timestamp)

        let decoded = try JSONEnvelope.decode(PitchDiscriminationPayload.self, from: envelope)
        #expect(decoded == payload)
    }

    /// Locks the on-disk JSON key set so a property rename surfaces here, not as silent data loss.
    @Test("PitchDiscriminationPayload encodes the expected JSON keys")
    func pitchDiscriminationJSONKeys() async throws {
        let payload = PitchDiscriminationPayload(
            referenceNote: 60, targetNote: 67, centOffset: 25.0,
            isCorrect: true, interval: 7, tuningSystem: "equalTemperament"
        )
        let keys = try jsonKeys(of: payload)
        #expect(keys == ["referenceNote", "targetNote", "centOffset", "isCorrect", "interval", "tuningSystem"])
    }

    @Test("PitchMatchingPayload round-trips through TrainingRecord")
    func pitchMatchingRoundTrip() async throws {
        let timestamp = Date()
        let payload = PitchMatchingPayload(
            referenceNote: 69,
            targetNote: 76,
            initialCentOffset: 42.5,
            userCentError: -12.3,
            interval: 7,
            tuningSystem: "equalTemperament"
        )

        let envelope = try JSONEnvelope.encode(payload, timestamp: timestamp)
        #expect(envelope.disciplineIdentifier == PitchMatchingPayload.disciplineIdentifier)
        #expect(envelope.payloadVersion == PitchMatchingPayload.currentPayloadVersion)

        let decoded = try JSONEnvelope.decode(PitchMatchingPayload.self, from: envelope)
        #expect(decoded == payload)
    }

    @Test("PitchMatchingPayload encodes the expected JSON keys")
    func pitchMatchingJSONKeys() async throws {
        let payload = PitchMatchingPayload(
            referenceNote: 69, targetNote: 76, initialCentOffset: 42.5,
            userCentError: -12.3, interval: 7, tuningSystem: "equalTemperament"
        )
        let keys = try jsonKeys(of: payload)
        #expect(keys == ["referenceNote", "targetNote", "initialCentOffset", "userCentError", "interval", "tuningSystem"])
    }

    @Test("TimingOffsetDetectionPayload round-trips through TrainingRecord")
    func timingOffsetDetectionRoundTrip() async throws {
        let timestamp = Date()
        let payload = TimingOffsetDetectionPayload(
            tempoBPM: 120,
            offsetMs: -15.3,
            isCorrect: true
        )

        let envelope = try JSONEnvelope.encode(payload, timestamp: timestamp)
        #expect(envelope.disciplineIdentifier == TimingOffsetDetectionPayload.disciplineIdentifier)
        #expect(envelope.payloadVersion == TimingOffsetDetectionPayload.currentPayloadVersion)

        let decoded = try JSONEnvelope.decode(TimingOffsetDetectionPayload.self, from: envelope)
        #expect(decoded == payload)
    }

    @Test("TimingOffsetDetectionPayload encodes the expected JSON keys")
    func timingOffsetDetectionJSONKeys() async throws {
        let payload = TimingOffsetDetectionPayload(tempoBPM: 120, offsetMs: -15.3, isCorrect: true)
        let keys = try jsonKeys(of: payload)
        #expect(keys == ["tempoBPM", "offsetMs", "isCorrect"])
    }

    @Test("ContinuousRhythmMatchingPayload round-trips through TrainingRecord")
    func continuousRhythmMatchingRoundTrip() async throws {
        let timestamp = Date()
        let payload = ContinuousRhythmMatchingPayload(
            tempoBPM: 120,
            meanOffsetMs: -8.5,
            meanOffsetMsPosition0: -5.2,
            meanOffsetMsPosition1: nil,
            meanOffsetMsPosition2: 3.1,
            meanOffsetMsPosition3: nil
        )

        let envelope = try JSONEnvelope.encode(payload, timestamp: timestamp)
        #expect(envelope.disciplineIdentifier == ContinuousRhythmMatchingPayload.disciplineIdentifier)
        #expect(envelope.payloadVersion == ContinuousRhythmMatchingPayload.currentPayloadVersion)

        let decoded = try JSONEnvelope.decode(ContinuousRhythmMatchingPayload.self, from: envelope)
        #expect(decoded == payload)
    }

    /// Encoded with every optional populated to lock the full key set. The synthesized `Codable`
    /// implementation writes `null` (not omitted keys) for nil optionals, so all six keys appear
    /// regardless of which positions have values.
    @Test("ContinuousRhythmMatchingPayload encodes the expected JSON keys")
    func continuousRhythmMatchingJSONKeys() async throws {
        let payload = ContinuousRhythmMatchingPayload(
            tempoBPM: 120,
            meanOffsetMs: -8.5,
            meanOffsetMsPosition0: -5.2,
            meanOffsetMsPosition1: -2.0,
            meanOffsetMsPosition2: 3.1,
            meanOffsetMsPosition3: 7.4
        )
        let keys = try jsonKeys(of: payload)
        #expect(keys == [
            "tempoBPM", "meanOffsetMs",
            "meanOffsetMsPosition0", "meanOffsetMsPosition1",
            "meanOffsetMsPosition2", "meanOffsetMsPosition3"
        ])
    }

    private func jsonKeys<P: TrainingDisciplinePayload>(of payload: P) throws -> Set<String> {
        let envelope = try JSONEnvelope.encode(payload, timestamp: Date())
        let object = try JSONSerialization.jsonObject(with: envelope.payloadData)
        guard let dict = object as? [String: Any] else { return [] }
        return Set(dict.keys)
    }
}
