import Testing
import SwiftData
import Foundation
@testable import Peach

@Suite("TrainingRecord Tests")
struct TrainingRecordTests {

    // MARK: - Test Helpers

    private func makeTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: TrainingRecord.self, configurations: config)
    }

    // MARK: - Envelope Field Storage

    @Test("Stores all envelope fields")
    func storesAllFields() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let timestamp = Date()
        let payload = Data([0x7B, 0x7D]) // "{}"
        let envelope = TrainingRecord(
            disciplineIdentifier: "pitchDiscrimination",
            timestamp: timestamp,
            payloadVersion: 1,
            payloadData: payload
        )

        context.insert(envelope)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<TrainingRecord>())
        #expect(fetched.count == 1)
        #expect(fetched[0].disciplineIdentifier == "pitchDiscrimination")
        #expect(abs(fetched[0].timestamp.timeIntervalSince(timestamp)) < 0.001)
        #expect(fetched[0].payloadVersion == 1)
        #expect(fetched[0].payloadData == payload)
    }

    @Test("TrainingRecord conforms to Timestamped")
    func conformsToTimestamped() async {
        let timestamp = Date()
        let envelope = TrainingRecord(
            disciplineIdentifier: "x",
            timestamp: timestamp,
            payloadVersion: 1,
            payloadData: Data()
        )

        let timestamped: any Timestamped = envelope
        #expect(abs(timestamped.timestamp.timeIntervalSince(timestamp)) < 0.001)
    }

    // MARK: - JSONEnvelope Round-Trip

    private struct DummyPayload: TrainingDisciplinePayload, Equatable {
        static let disciplineIdentifier = "dummy"
        static let currentPayloadVersion = 1

        let answer: Int
        let label: String
    }

    @Test("JSONEnvelope encodes payload into envelope with discipline identifier and version")
    func encodesPayload() async throws {
        let timestamp = Date()
        let payload = DummyPayload(answer: 42, label: "hi")

        let envelope = try JSONEnvelope.encode(payload, timestamp: timestamp)

        #expect(envelope.disciplineIdentifier == DummyPayload.disciplineIdentifier)
        #expect(envelope.payloadVersion == DummyPayload.currentPayloadVersion)
        #expect(abs(envelope.timestamp.timeIntervalSince(timestamp)) < 0.001)
        #expect(!envelope.payloadData.isEmpty)
    }

    @Test("JSONEnvelope round-trip preserves payload contents")
    func roundTripPreservesPayload() async throws {
        let payload = DummyPayload(answer: 42, label: "hi")
        let envelope = try JSONEnvelope.encode(payload, timestamp: Date())

        let decoded = try JSONEnvelope.decode(DummyPayload.self, from: envelope)

        #expect(decoded == payload)
    }

    @Test("JSONEnvelope produces deterministic output via sorted keys")
    func deterministicOutput() async throws {
        let payload = DummyPayload(answer: 1, label: "x")
        let timestamp = Date()

        let first = try JSONEnvelope.encode(payload, timestamp: timestamp)
        let second = try JSONEnvelope.encode(payload, timestamp: timestamp)

        #expect(first.payloadData == second.payloadData)
    }
}
