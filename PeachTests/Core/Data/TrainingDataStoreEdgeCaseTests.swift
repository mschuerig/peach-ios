import Testing
import SwiftData
import Foundation
@testable import Peach

/// Edge case and error handling tests for TrainingDataStore
@Suite("TrainingDataStore Edge Case Tests")
struct TrainingDataStoreEdgeCaseTests {

    // MARK: - Test Helpers

    private func makeTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: TrainingRecord.self, configurations: config)
    }

    private func envelope(for payload: any TrainingDisciplinePayload, timestamp: Date = Date()) throws -> TrainingRecord {
        try JSONEnvelope.encode(payload, timestamp: timestamp)
    }

    // MARK: - Edge Case Tests

    @Test("Save multiple records with identical data")
    func saveDuplicateData() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let payload = PitchDiscriminationPayload(referenceNote: 60, targetNote: 60, centOffset: 50.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament")

        try store.save(envelope(for: payload))
        try store.save(envelope(for: payload))

        let fetched = try store.fetchPayloads(PitchDiscriminationPayload.self)
        #expect(fetched.count == 2)
    }

    @Test("MIDI note boundaries are stored correctly")
    func midiNoteBoundaries() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let minPayload = PitchDiscriminationPayload(referenceNote: 0, targetNote: 0, centOffset: 10.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament")
        let maxPayload = PitchDiscriminationPayload(referenceNote: 127, targetNote: 127, centOffset: 20.0, isCorrect: false, interval: 0, tuningSystem: "equalTemperament")

        try store.save(envelope(for: minPayload))
        try store.save(envelope(for: maxPayload))

        let fetched = try store.fetchPayloads(PitchDiscriminationPayload.self)
        #expect(fetched.count == 2)
        #expect(fetched.contains { $0.payload.referenceNote == 0 })
        #expect(fetched.contains { $0.payload.referenceNote == 127 })
    }

    @Test("Fractional cent offsets are stored with precision")
    func fractionalCentPrecision() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let payload = PitchDiscriminationPayload(
            referenceNote: 60,
            targetNote: 60,
            centOffset: 12.3,
            isCorrect: true,
            interval: 0,
            tuningSystem: "equalTemperament"
        )

        try store.save(envelope(for: payload))

        let fetched = try store.fetchPayloads(PitchDiscriminationPayload.self)
        #expect(fetched.count == 1)
        #expect(fetched[0].payload.centOffset == 12.3)
    }

    // MARK: - Atomic Replace Tests

    @Test("replaceAllRecords inserts new records after deleting existing ones")
    func replaceAllRecordsInsertsAfterDelete() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let existing = PitchDiscriminationPayload(referenceNote: 60, targetNote: 60, centOffset: 10.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament")
        try store.save(envelope(for: existing))

        let newDiscrimination = PitchDiscriminationPayload(referenceNote: 72, targetNote: 72, centOffset: 20.0, isCorrect: false, interval: 0, tuningSystem: "equalTemperament")
        let newMatching = PitchMatchingPayload(referenceNote: 69, targetNote: 69, initialCentOffset: 30.0, userCentError: 5.0, interval: 0, tuningSystem: "equalTemperament")

        let envelopes: [TrainingRecord] = [
            try envelope(for: newDiscrimination),
            try envelope(for: newMatching),
        ]
        try store.replaceAllRecords(envelopes)

        let comparisons = try store.fetchPayloads(PitchDiscriminationPayload.self)
        let matchings = try store.fetchPayloads(PitchMatchingPayload.self)

        #expect(comparisons.count == 1)
        #expect(comparisons[0].payload.referenceNote == 72)
        #expect(matchings.count == 1)
        #expect(matchings[0].payload.referenceNote == 69)
    }

    @Test("replaceAllRecords with empty arrays clears all data")
    func replaceAllRecordsWithEmptyArrays() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let discrimination = PitchDiscriminationPayload(referenceNote: 60, targetNote: 60, centOffset: 10.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament")
        let matching = PitchMatchingPayload(referenceNote: 69, targetNote: 69, initialCentOffset: 30.0, userCentError: 5.0, interval: 0, tuningSystem: "equalTemperament")
        try store.save(envelope(for: discrimination))
        try store.save(envelope(for: matching))

        try store.replaceAllRecords([])

        #expect(try store.fetchPayloads(PitchDiscriminationPayload.self).isEmpty)
        #expect(try store.fetchPayloads(PitchMatchingPayload.self).isEmpty)
    }

    @Test("replaceAllRecords handles multiple records of both types")
    func replaceAllRecordsMultiple() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let discriminations = (0..<5).map { i in
            PitchDiscriminationPayload(referenceNote: 60 + i, targetNote: 60 + i, centOffset: Double(i) * 10, isCorrect: true, interval: 0, tuningSystem: "equalTemperament")
        }
        let matchings = (0..<3).map { i in
            PitchMatchingPayload(referenceNote: 69 + i, targetNote: 69 + i, initialCentOffset: Double(i) * 15, userCentError: Double(i), interval: 0, tuningSystem: "equalTemperament")
        }

        var envelopes: [TrainingRecord] = []
        for d in discriminations { envelopes.append(try envelope(for: d)) }
        for m in matchings { envelopes.append(try envelope(for: m)) }
        try store.replaceAllRecords(envelopes)

        #expect(try store.fetchPayloads(PitchDiscriminationPayload.self).count == 5)
        #expect(try store.fetchPayloads(PitchMatchingPayload.self).count == 3)
    }

    // MARK: - Cross-Discipline Fetch Isolation

    @Test("FetchPayloads returns only the requested discipline's rows when other disciplines are present")
    func fetchPayloadsIsolatesByDiscipline() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        try store.save(envelope(for: PitchDiscriminationPayload(referenceNote: 60, targetNote: 60, centOffset: 10.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament")))
        try store.save(envelope(for: PitchDiscriminationPayload(referenceNote: 62, targetNote: 62, centOffset: 12.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament")))
        try store.save(envelope(for: PitchMatchingPayload(referenceNote: 69, targetNote: 69, initialCentOffset: 30.0, userCentError: 5.0, interval: 0, tuningSystem: "equalTemperament")))

        let comparisons = try store.fetchPayloads(PitchDiscriminationPayload.self)
        let matchings = try store.fetchPayloads(PitchMatchingPayload.self)

        #expect(comparisons.count == 2)
        #expect(matchings.count == 1)
        #expect(matchings[0].payload.referenceNote == 69)
    }

    // MARK: - Decode Failure Isolation

    @Test("FetchPayloads skips a corrupt envelope without failing the whole fetch")
    func fetchPayloadsSkipsCorruptEnvelope() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let valid = PitchDiscriminationPayload(referenceNote: 60, targetNote: 60, centOffset: 10.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament")
        try store.save(envelope(for: valid))

        let corrupt = TrainingRecord(
            disciplineIdentifier: PitchDiscriminationPayload.disciplineIdentifier,
            timestamp: Date(),
            payloadVersion: PitchDiscriminationPayload.currentPayloadVersion,
            payloadData: Data("not valid json".utf8)
        )
        try store.save(corrupt)

        let fetched = try store.fetchPayloads(PitchDiscriminationPayload.self)
        #expect(fetched.count == 1)
        #expect(fetched[0].payload == valid)
    }

    // MARK: - Envelope Metadata Mismatch

    @Test("Decoding into the wrong payload type throws disciplineMismatch")
    func decodeRejectsDisciplineMismatch() async throws {
        let payload = PitchDiscriminationPayload(referenceNote: 60, targetNote: 60, centOffset: 10.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament")
        let env = try JSONEnvelope.encode(payload, timestamp: Date())

        #expect(throws: JSONEnvelopeError.self) {
            try JSONEnvelope.decode(PitchMatchingPayload.self, from: env)
        }
    }

    @Test("Decoding from a payload with an unsupported version throws unsupportedPayloadVersion")
    func decodeRejectsUnsupportedVersion() async throws {
        let payload = PitchDiscriminationPayload(referenceNote: 60, targetNote: 60, centOffset: 10.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament")
        let env = try JSONEnvelope.encode(payload, timestamp: Date())
        let bumped = TrainingRecord(
            disciplineIdentifier: env.disciplineIdentifier,
            timestamp: env.timestamp,
            payloadVersion: env.payloadVersion + 99,
            payloadData: env.payloadData
        )

        #expect(throws: JSONEnvelopeError.self) {
            try JSONEnvelope.decode(PitchDiscriminationPayload.self, from: bumped)
        }
    }

    @Test("DataStoreError cases have descriptive messages")
    func dataStoreErrorMessages() async {
        let saveError = Peach.DataStoreError.saveFailed("Test save error")
        let fetchError = Peach.DataStoreError.fetchFailed("Test fetch error")
        let deleteError = Peach.DataStoreError.deleteFailed("Test delete error")
        let contextError = Peach.DataStoreError.contextUnavailable

        switch saveError {
        case .saveFailed(let message):
            #expect(message == "Test save error")
        default:
            Issue.record("saveFailed case not matched")
        }

        switch fetchError {
        case .fetchFailed(let message):
            #expect(message == "Test fetch error")
        default:
            Issue.record("fetchFailed case not matched")
        }

        switch deleteError {
        case .deleteFailed(let message):
            #expect(message == "Test delete error")
        default:
            Issue.record("deleteFailed case not matched")
        }

        switch contextError {
        case .contextUnavailable:
            break
        default:
            Issue.record("contextUnavailable case not matched")
        }
    }
}
