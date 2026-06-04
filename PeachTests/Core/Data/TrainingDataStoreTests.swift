import Testing
import SwiftData
import Foundation
@testable import Peach

/// Core CRUD and persistence tests for TrainingDataStore (envelope-only API).
@Suite("TrainingDataStore Tests")
struct TrainingDataStoreTests {

    // MARK: - Test Helpers

    private func makeTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: TrainingRecord.self, configurations: config)
    }

    private func makeFileBasedContainer() throws -> ModelContainer {
        let tempDir = FileManager.default.temporaryDirectory
        let config = ModelConfiguration(url: tempDir.appendingPathComponent("test-\(UUID().uuidString).store"))
        return try ModelContainer(for: TrainingRecord.self, configurations: config)
    }

    private func envelope(
        for payload: any TrainingDisciplinePayload,
        timestamp: Date = Date()
    ) throws -> TrainingRecord {
        try JSONEnvelope.encode(payload, timestamp: timestamp)
    }

    // MARK: - Save and Fetch Tests

    @Test("Save and retrieve a single payload")
    func saveAndRetrieveSinglePayload() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let payload = PitchDiscriminationPayload(
            referenceNote: 60,
            targetNote: 60,
            centOffset: 50.0,
            isCorrect: true,
            interval: 0,
            tuningSystem: "equalTemperament"
        )
        try store.save(try envelope(for: payload))

        let fetched = try store.fetchPayloads(PitchDiscriminationPayload.self)

        #expect(fetched.count == 1)
        #expect(fetched[0].payload == payload)
    }

    @Test("FetchPayloads returns multiple payloads in timestamp order")
    func fetchMultiplePayloadsInOrder() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let now = Date()
        try store.save(try envelope(for: PitchDiscriminationPayload(referenceNote: 60, targetNote: 60, centOffset: 10.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament"), timestamp: now.addingTimeInterval(-60)))
        try store.save(try envelope(for: PitchDiscriminationPayload(referenceNote: 62, targetNote: 62, centOffset: 20.0, isCorrect: false, interval: 0, tuningSystem: "equalTemperament"), timestamp: now.addingTimeInterval(-30)))
        try store.save(try envelope(for: PitchDiscriminationPayload(referenceNote: 64, targetNote: 64, centOffset: 30.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament"), timestamp: now))

        let fetched = try store.fetchPayloads(PitchDiscriminationPayload.self)

        #expect(fetched.count == 3)
        #expect(fetched[0].payload.referenceNote == 60)
        #expect(fetched[1].payload.referenceNote == 62)
        #expect(fetched[2].payload.referenceNote == 64)
    }

    @Test("All payload fields remain intact after save and retrieval")
    func allFieldsIntact() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let timestamp = Date()
        let payload = PitchDiscriminationPayload(
            referenceNote: 72,
            targetNote: 72,
            centOffset: 123.45,
            isCorrect: false,
            interval: 0,
            tuningSystem: "equalTemperament"
        )

        try store.save(try envelope(for: payload, timestamp: timestamp))

        let fetched = try store.fetchPayloads(PitchDiscriminationPayload.self)
        #expect(fetched.count == 1)
        #expect(fetched[0].payload == payload)
        #expect(abs(fetched[0].timestamp.timeIntervalSince(timestamp)) < 0.001)
    }

    // MARK: - Persistence

    @Test("Records persist across context recreation (simulated restart)")
    func persistenceAcrossRestart() async throws {
        let container = try makeFileBasedContainer()

        do {
            let context1 = ModelContext(container)
            let store1 = TrainingDataStore(modelContext: context1)
            let payload = PitchDiscriminationPayload(
                referenceNote: 69,
                targetNote: 69,
                centOffset: 75.0,
                isCorrect: true,
                interval: 0,
                tuningSystem: "equalTemperament"
            )
            try store1.save(try envelope(for: payload))
        }

        let context2 = ModelContext(container)
        let store2 = TrainingDataStore(modelContext: context2)
        let fetched = try store2.fetchPayloads(PitchDiscriminationPayload.self)

        #expect(fetched.count == 1)
        #expect(fetched[0].payload.referenceNote == 69)
        #expect(fetched[0].payload.centOffset == 75.0)
    }

    // MARK: - Empty Store

    @Test("FetchPayloads returns empty array when no envelopes exist")
    func fetchFromEmptyStore() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let fetched = try store.fetchPayloads(PitchDiscriminationPayload.self)
        #expect(fetched.isEmpty)
    }

    // MARK: - Pitch Matching

    @Test("Save and retrieve a single pitch matching payload")
    func saveAndRetrievePitchMatching() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let payload = PitchMatchingPayload(
            referenceNote: 69,
            targetNote: 69,
            initialCentOffset: 42.5,
            userCentError: -12.3,
            interval: 0,
            tuningSystem: "equalTemperament"
        )
        try store.save(try envelope(for: payload))

        let fetched = try store.fetchPayloads(PitchMatchingPayload.self)
        #expect(fetched.count == 1)
        #expect(fetched[0].payload == payload)
    }

    @Test("FetchPayloads PitchMatchingPayload returns multiple payloads in timestamp order")
    func fetchPitchMatchingPayloadsInOrder() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let now = Date()
        try store.save(try envelope(for: PitchMatchingPayload(referenceNote: 60, targetNote: 60, initialCentOffset: 10.0, userCentError: 1.0, interval: 0, tuningSystem: "equalTemperament"), timestamp: now.addingTimeInterval(-60)))
        try store.save(try envelope(for: PitchMatchingPayload(referenceNote: 62, targetNote: 62, initialCentOffset: 20.0, userCentError: 2.0, interval: 0, tuningSystem: "equalTemperament"), timestamp: now.addingTimeInterval(-30)))
        try store.save(try envelope(for: PitchMatchingPayload(referenceNote: 64, targetNote: 64, initialCentOffset: 30.0, userCentError: 3.0, interval: 0, tuningSystem: "equalTemperament"), timestamp: now))

        let fetched = try store.fetchPayloads(PitchMatchingPayload.self)
        #expect(fetched.count == 3)
        #expect(fetched[0].payload.referenceNote == 60)
        #expect(fetched[1].payload.referenceNote == 62)
        #expect(fetched[2].payload.referenceNote == 64)
    }

    @Test("FetchPayloads PitchMatchingPayload returns empty array when no envelopes exist")
    func fetchPitchMatchingFromEmptyStore() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let fetched = try store.fetchPayloads(PitchMatchingPayload.self)
        #expect(fetched.isEmpty)
    }

    // MARK: - DeleteAll

    @Test("DeleteAll removes envelopes for all disciplines")
    func deleteAllRemovesAllDisciplines() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        try store.save(try envelope(for: PitchDiscriminationPayload(referenceNote: 60, targetNote: 60, centOffset: 10.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament")))
        try store.save(try envelope(for: PitchMatchingPayload(referenceNote: 60, targetNote: 60, initialCentOffset: 10.0, userCentError: 5.0, interval: 0, tuningSystem: "equalTemperament")))
        try store.save(try envelope(for: PitchMatchingPayload(referenceNote: 64, targetNote: 64, initialCentOffset: 20.0, userCentError: -3.0, interval: 0, tuningSystem: "equalTemperament")))

        try store.deleteAll()

        #expect(try store.fetchPayloads(PitchDiscriminationPayload.self).isEmpty)
        #expect(try store.fetchPayloads(PitchMatchingPayload.self).isEmpty)
    }

    // MARK: - Adapter (Observer) Conformance

    @Test("PitchMatchingStoreAdapter saves payload via store")
    func pitchMatchingObserverSaves() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let timestamp = Date()
        let completed = CompletedPitchMatchingTrial(
            referenceNote: 69,
            targetNote: 69,
            initialCentOffset: 42.5,
            userCentError: -12.3,
            tuningSystem: .equalTemperament,
            timestamp: timestamp
        )

        PitchMatchingStoreAdapter(store: store).pitchMatchingCompleted(completed)

        let fetched = try store.fetchPayloads(PitchMatchingPayload.self)
        #expect(fetched.count == 1)
        #expect(fetched[0].payload.referenceNote == 69)
        #expect(fetched[0].payload.targetNote == 69)
        #expect(fetched[0].payload.initialCentOffset == 42.5)
        #expect(fetched[0].payload.userCentError == -12.3)
        #expect(fetched[0].payload.interval == 0)
        #expect(fetched[0].payload.tuningSystem == "equalTemperament")
        #expect(abs(fetched[0].timestamp.timeIntervalSince(timestamp)) < 0.001)
    }

    @Test("PitchDiscriminationStoreAdapter saves payload via store with derived interval")
    func pitchDiscriminationObserverSaves() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let timestamp = Date()
        let trial = PitchDiscriminationTrial(
            referenceNote: 60,
            targetNote: DetunedMIDINote(note: 60, offset: Cents(25.0))
        )
        let completed = CompletedPitchDiscriminationTrial(
            trial: trial,
            userAnsweredHigher: true,
            tuningSystem: .equalTemperament,
            timestamp: timestamp
        )

        PitchDiscriminationStoreAdapter(store: store).pitchDiscriminationCompleted(completed)

        let fetched = try store.fetchPayloads(PitchDiscriminationPayload.self)
        #expect(fetched.count == 1)
        #expect(fetched[0].payload.referenceNote == 60)
        #expect(fetched[0].payload.targetNote == 60)
        #expect(fetched[0].payload.centOffset == 25.0)
        #expect(fetched[0].payload.isCorrect == true)
        #expect(fetched[0].payload.interval == 0)
        #expect(fetched[0].payload.tuningSystem == "equalTemperament")
        #expect(abs(fetched[0].timestamp.timeIntervalSince(timestamp)) < 0.001)
    }

    @Test("PitchDiscriminationStoreAdapter persists correct interval for non-prime")
    func discriminationObserverWithInterval() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let trial = PitchDiscriminationTrial(
            referenceNote: MIDINote(60),
            targetNote: DetunedMIDINote(note: MIDINote(67), offset: Cents(25.0))
        )
        let completed = CompletedPitchDiscriminationTrial(
            trial: trial,
            userAnsweredHigher: true,
            tuningSystem: .equalTemperament
        )

        PitchDiscriminationStoreAdapter(store: store).pitchDiscriminationCompleted(completed)

        let fetched = try store.fetchPayloads(PitchDiscriminationPayload.self)
        #expect(fetched.count == 1)
        #expect(fetched[0].payload.referenceNote == 60)
        #expect(fetched[0].payload.targetNote == 67)
        #expect(fetched[0].payload.interval == 7)
        #expect(fetched[0].payload.tuningSystem == "equalTemperament")
        #expect(fetched[0].payload.centOffset == 25.0)
    }

    @Test("PitchMatchingStoreAdapter persists correct interval for non-prime")
    func pitchMatchingObserverWithInterval() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let completed = CompletedPitchMatchingTrial(
            referenceNote: MIDINote(60),
            targetNote: MIDINote(60).transposed(by: .up(.perfectFifth)),
            initialCentOffset: 30.0,
            userCentError: -5.0,
            tuningSystem: .equalTemperament
        )

        PitchMatchingStoreAdapter(store: store).pitchMatchingCompleted(completed)

        let fetched = try store.fetchPayloads(PitchMatchingPayload.self)
        #expect(fetched.count == 1)
        #expect(fetched[0].payload.referenceNote == 60)
        #expect(fetched[0].payload.targetNote == 67)
        #expect(fetched[0].payload.interval == 7)
        #expect(fetched[0].payload.tuningSystem == "equalTemperament")
        #expect(fetched[0].payload.initialCentOffset == 30.0)
        #expect(fetched[0].payload.userCentError == -5.0)
    }

    // MARK: - Timing Offset Detection

    @Test("Save and retrieve a single timing offset detection payload")
    func saveAndRetrieveTimingOffsetDetection() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let timestamp = Date()
        let payload = TimingOffsetDetectionPayload(tempoBPM: 120, offsetMs: -15.5, isCorrect: true)
        try store.save(try envelope(for: payload, timestamp: timestamp))

        let fetched = try store.fetchPayloads(TimingOffsetDetectionPayload.self)
        #expect(fetched.count == 1)
        #expect(fetched[0].payload == payload)
        #expect(abs(fetched[0].timestamp.timeIntervalSince(timestamp)) < 0.001)
    }

    @Test("DeleteAll removes timing offset detection envelopes too")
    func deleteAllRemovesTimingOffsetDetection() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        try store.save(try envelope(for: PitchDiscriminationPayload(referenceNote: 60, targetNote: 60, centOffset: 10.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament")))
        try store.save(try envelope(for: TimingOffsetDetectionPayload(tempoBPM: 120, offsetMs: -5.0, isCorrect: true)))

        try store.deleteAll()

        #expect(try store.fetchPayloads(TimingOffsetDetectionPayload.self).isEmpty)
        #expect(try store.fetchPayloads(PitchDiscriminationPayload.self).isEmpty)
    }

    @Test("TimingOffsetDetectionStoreAdapter saves payload via store")
    func timingOffsetDetectionObserverSaves() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let timestamp = Date()
        let completed = CompletedTimingOffsetDetectionTrial(
            tempo: TempoBPM(120),
            offset: TimingOffset(.milliseconds(-15)),
            isCorrect: true,
            timestamp: timestamp
        )

        TimingOffsetDetectionStoreAdapter(store: store).timingOffsetDetectionCompleted(completed)

        let fetched = try store.fetchPayloads(TimingOffsetDetectionPayload.self)
        #expect(fetched.count == 1)
        #expect(fetched[0].payload.tempoBPM == 120)
        #expect(fetched[0].payload.offsetMs == -15.0)
        #expect(fetched[0].payload.isCorrect == true)
        #expect(abs(fetched[0].timestamp.timeIntervalSince(timestamp)) < 0.001)
    }

#if PEACH_RESEARCH
    // MARK: - Continuous Rhythm Matching

    @Test("Save and retrieve a single continuous rhythm matching payload")
    func saveAndRetrieveContinuousRhythmMatching() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let timestamp = Date()
        let payload = ContinuousRhythmMatchingPayload(
            tempoBPM: 120,
            meanOffsetMs: -8.5,
            meanOffsetMsPosition0: -5.0,
            meanOffsetMsPosition1: nil,
            meanOffsetMsPosition2: nil,
            meanOffsetMsPosition3: nil
        )
        try store.save(try envelope(for: payload, timestamp: timestamp))

        let fetched = try store.fetchPayloads(ContinuousRhythmMatchingPayload.self)
        #expect(fetched.count == 1)
        #expect(fetched[0].payload == payload)
    }

    @Test("ContinuousRhythmMatchingStoreAdapter saves payload via store with computed positions")
    func continuousRhythmMatchingObserverSaves() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let timestamp = Date()
        let gapResults = [
            GapResult(position: .first, offset: TimingOffset(.milliseconds(-10))),
            GapResult(position: .third, offset: TimingOffset(.milliseconds(5))),
            GapResult(position: .first, offset: TimingOffset(.milliseconds(-8))),
        ]
        let trial = CompletedContinuousRhythmMatchingTrial(
            tempo: TempoBPM(120),
            gapResults: gapResults,
            timestamp: timestamp
        )

        ContinuousRhythmMatchingStoreAdapter(store: store).continuousRhythmMatchingCompleted(trial)

        let fetched = try store.fetchPayloads(ContinuousRhythmMatchingPayload.self)
        #expect(fetched.count == 1)
        #expect(fetched[0].payload.tempoBPM == 120)
        #expect(abs(fetched[0].timestamp.timeIntervalSince(timestamp)) < 0.001)

        let pos0 = try #require(fetched[0].payload.meanOffsetMsPosition0)
        #expect(abs(pos0 - (-9.0)) < 0.001)
        #expect(fetched[0].payload.meanOffsetMsPosition1 == nil)
        let pos2 = try #require(fetched[0].payload.meanOffsetMsPosition2)
        #expect(abs(pos2 - 5.0) < 0.001)
        #expect(fetched[0].payload.meanOffsetMsPosition3 == nil)
    }
#endif

    // MARK: - Transaction Rollback

    @Test("withinTransaction rolls back all inserts when closure throws")
    func transactionRollbackOnError() async throws {
        let container = try makeFileBasedContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let committed = PitchDiscriminationPayload(
            referenceNote: 60, targetNote: 64, centOffset: 10.0, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament"
        )
        try store.save(try envelope(for: committed))
        #expect(try store.fetchPayloads(PitchDiscriminationPayload.self).count == 1)

        struct TestError: Error {}
        do {
            try store.withinTransaction { scope in
                let pitchEnvelope = try JSONEnvelope.encode(
                    PitchDiscriminationPayload(
                        referenceNote: 72, targetNote: 76, centOffset: 5.0, isCorrect: false,
                        interval: 4, tuningSystem: "equalTemperament"
                    ),
                    timestamp: Date()
                )
                scope.insert(pitchEnvelope)
                let matchingEnvelope = try JSONEnvelope.encode(
                    PitchMatchingPayload(
                        referenceNote: 69, targetNote: 72, initialCentOffset: 25.0, userCentError: 3.2,
                        interval: 3, tuningSystem: "equalTemperament"
                    ),
                    timestamp: Date()
                )
                scope.insert(matchingEnvelope)
                throw TestError()
            }
        } catch {
            #expect(error is TestError)
        }

        let comparisons = try store.fetchPayloads(PitchDiscriminationPayload.self)
        let matchings = try store.fetchPayloads(PitchMatchingPayload.self)
        #expect(comparisons.count == 1)
        #expect(comparisons[0].payload.referenceNote == 60)
        #expect(matchings.count == 0)
    }
}
