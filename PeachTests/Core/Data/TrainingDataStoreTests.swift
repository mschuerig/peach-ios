import Testing
import SwiftData
import Foundation
@testable import Peach

/// Core CRUD and persistence tests for TrainingDataStore
@Suite("TrainingDataStore Tests")
struct TrainingDataStoreTests {

    // MARK: - Test Helpers

    private func makeTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: PitchDiscriminationRecord.self, PitchMatchingRecord.self, RhythmOffsetDetectionRecord.self, RhythmMatchingRecord.self, ContinuousRhythmMatchingRecord.self, configurations: config)
    }

    private func makeFileBasedContainer() throws -> ModelContainer {
        let tempDir = FileManager.default.temporaryDirectory
        let config = ModelConfiguration(url: tempDir.appendingPathComponent("test-\(UUID().uuidString).store"))
        return try ModelContainer(for: PitchDiscriminationRecord.self, PitchMatchingRecord.self, RhythmOffsetDetectionRecord.self, RhythmMatchingRecord.self, ContinuousRhythmMatchingRecord.self, configurations: config)
    }

    // MARK: - Save and Fetch Tests

    @Test("Save and retrieve a single record")
    func saveAndRetrieveSingleRecord() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let record = PitchDiscriminationRecord(
            referenceNote: 60,
            targetNote: 60,
            centOffset: 50.0,
            isCorrect: true,
            interval: 0,
            tuningSystem: "equalTemperament",
            timestamp: Date()
        )

        try store.save(record)

        let fetched = try store.fetchAllPitchDiscriminations()

        #expect(fetched.count == 1)
        #expect(fetched[0].referenceNote == 60)
        #expect(fetched[0].targetNote == 60)
        #expect(fetched[0].centOffset == 50.0)
        #expect(fetched[0].isCorrect == true)
        #expect(fetched[0].interval == 0)
        #expect(fetched[0].tuningSystem == "equalTemperament")
    }

    @Test("FetchAll returns multiple records in timestamp order")
    func fetchMultipleRecordsInOrder() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let now = Date()
        let record1 = PitchDiscriminationRecord(referenceNote: 60, targetNote: 60, centOffset: 10.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament", timestamp: now.addingTimeInterval(-60))
        let record2 = PitchDiscriminationRecord(referenceNote: 62, targetNote: 62, centOffset: 20.0, isCorrect: false, interval: 0, tuningSystem: "equalTemperament", timestamp: now.addingTimeInterval(-30))
        let record3 = PitchDiscriminationRecord(referenceNote: 64, targetNote: 64, centOffset: 30.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament", timestamp: now)

        try store.save(record1)
        try store.save(record2)
        try store.save(record3)

        let fetched = try store.fetchAllPitchDiscriminations()

        #expect(fetched.count == 3)
        #expect(fetched[0].referenceNote == 60)
        #expect(fetched[1].referenceNote == 62)
        #expect(fetched[2].referenceNote == 64)
    }

    @Test("All fields remain intact after save and retrieval")
    func allFieldsIntact() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let timestamp = Date()
        let record = PitchDiscriminationRecord(
            referenceNote: 72,
            targetNote: 72,
            centOffset: 123.45,
            isCorrect: false,
            interval: 0,
            tuningSystem: "equalTemperament",
            timestamp: timestamp
        )

        try store.save(record)

        let fetched = try store.fetchAllPitchDiscriminations()

        #expect(fetched.count == 1)
        let retrieved = fetched[0]
        #expect(retrieved.referenceNote == 72)
        #expect(retrieved.targetNote == 72)
        #expect(retrieved.centOffset == 123.45)
        #expect(retrieved.isCorrect == false)
        #expect(retrieved.interval == 0)
        #expect(retrieved.tuningSystem == "equalTemperament")
        #expect(abs(retrieved.timestamp.timeIntervalSince(timestamp)) < 0.001)
    }

    // MARK: - Delete Tests

    @Test("Delete removes record")
    func deleteRecord() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let record = PitchDiscriminationRecord(referenceNote: 60, targetNote: 60, centOffset: 10.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament")
        try store.save(record)

        var fetched = try store.fetchAllPitchDiscriminations()
        #expect(fetched.count == 1)

        try store.delete(record)

        fetched = try store.fetchAllPitchDiscriminations()
        #expect(fetched.isEmpty)
    }

    @Test("Delete only removes specified record")
    func deleteSpecificRecord() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let record1 = PitchDiscriminationRecord(referenceNote: 60, targetNote: 60, centOffset: 10.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament")
        let record2 = PitchDiscriminationRecord(referenceNote: 62, targetNote: 62, centOffset: 20.0, isCorrect: false, interval: 0, tuningSystem: "equalTemperament")
        try store.save(record1)
        try store.save(record2)

        try store.delete(record1)

        let fetched = try store.fetchAllPitchDiscriminations()
        #expect(fetched.count == 1)
        #expect(fetched[0].referenceNote == 62)
    }

    // MARK: - Persistence Tests

    @Test("Records persist across context recreation (simulated restart)")
    func persistenceAcrossRestart() async throws {
        let container = try makeFileBasedContainer()

        do {
            let context1 = ModelContext(container)
            let store1 = TrainingDataStore(modelContext: context1)

            let record = PitchDiscriminationRecord(
                referenceNote: 69,
                targetNote: 69,
                centOffset: 75.0,
                isCorrect: true,
                interval: 0,
                tuningSystem: "equalTemperament"
            )
            try store1.save(record)
        }

        let context2 = ModelContext(container)
        let store2 = TrainingDataStore(modelContext: context2)

        let fetched = try store2.fetchAllPitchDiscriminations()

        #expect(fetched.count == 1)
        #expect(fetched[0].referenceNote == 69)
        #expect(fetched[0].centOffset == 75.0)
    }

    // MARK: - Atomic Write Tests

    @Test("Atomic write behavior - successful save is complete")
    func atomicWriteSuccess() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let record = PitchDiscriminationRecord(referenceNote: 60, targetNote: 60, centOffset: 10.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament")
        try store.save(record)

        let fetched = try store.fetchAllPitchDiscriminations()
        #expect(fetched.count == 1)
        #expect(fetched[0].referenceNote == 60)
        #expect(fetched[0].targetNote == 60)
        #expect(fetched[0].centOffset == 10.0)
        #expect(fetched[0].isCorrect == true)
    }

    // MARK: - Empty Store Tests

    @Test("FetchAll returns empty array when no records exist")
    func fetchFromEmptyStore() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let fetched = try store.fetchAllPitchDiscriminations()

        #expect(fetched.isEmpty)
    }

    // MARK: - Pitch Matching Save and Fetch Tests

    @Test("Save and retrieve a single pitch matching record")
    func saveAndRetrievePitchMatchingRecord() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let record = PitchMatchingRecord(
            referenceNote: 69,
            targetNote: 69,
            initialCentOffset: 42.5,
            userCentError: -12.3,
            interval: 0,
            tuningSystem: "equalTemperament"
        )

        try store.save(record)

        let fetched = try store.fetchAllPitchMatchings()

        #expect(fetched.count == 1)
        #expect(fetched[0].referenceNote == 69)
        #expect(fetched[0].targetNote == 69)
        #expect(fetched[0].initialCentOffset == 42.5)
        #expect(fetched[0].userCentError == -12.3)
    }

    @Test("FetchAllPitchMatching returns records in timestamp order")
    func fetchPitchMatchingInOrder() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let now = Date()
        let record1 = PitchMatchingRecord(referenceNote: 60, targetNote: 60, initialCentOffset: 10.0, userCentError: 5.0, interval: 0, tuningSystem: "equalTemperament", timestamp: now.addingTimeInterval(-60))
        let record2 = PitchMatchingRecord(referenceNote: 64, targetNote: 64, initialCentOffset: 20.0, userCentError: -3.0, interval: 0, tuningSystem: "equalTemperament", timestamp: now.addingTimeInterval(-30))
        let record3 = PitchMatchingRecord(referenceNote: 72, targetNote: 72, initialCentOffset: 30.0, userCentError: 1.5, interval: 0, tuningSystem: "equalTemperament", timestamp: now)

        try store.save(record1)
        try store.save(record2)
        try store.save(record3)

        let fetched = try store.fetchAllPitchMatchings()

        #expect(fetched.count == 3)
        #expect(fetched[0].referenceNote == 60)
        #expect(fetched[1].referenceNote == 64)
        #expect(fetched[2].referenceNote == 72)
    }

    @Test("FetchAllPitchMatching returns empty array when no records exist")
    func fetchPitchMatchingFromEmptyStore() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let fetched = try store.fetchAllPitchMatchings()

        #expect(fetched.isEmpty)
    }

    // MARK: - Delete All Tests

    @Test("DeleteAll removes both comparison and pitch matching records")
    func deleteAllRemovesBothTypes() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let comparisonRecord = PitchDiscriminationRecord(referenceNote: 60, targetNote: 60, centOffset: 10.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament")
        try store.save(comparisonRecord)

        let pitchRecord1 = PitchMatchingRecord(referenceNote: 60, targetNote: 60, initialCentOffset: 10.0, userCentError: 5.0, interval: 0, tuningSystem: "equalTemperament")
        let pitchRecord2 = PitchMatchingRecord(referenceNote: 64, targetNote: 64, initialCentOffset: 20.0, userCentError: -3.0, interval: 0, tuningSystem: "equalTemperament")
        try store.save(pitchRecord1)
        try store.save(pitchRecord2)

        try store.deleteAll()

        let comparisonFetched = try store.fetchAllPitchDiscriminations()
        #expect(comparisonFetched.isEmpty)

        let pitchFetched = try store.fetchAllPitchMatchings()
        #expect(pitchFetched.isEmpty)
    }

    // MARK: - PitchMatchingObserver Conformance Tests

    @Test("PitchMatchingObserver conformance saves record with all fields via observer")
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

        store.pitchMatchingCompleted(completed)

        let fetched = try store.fetchAllPitchMatchings()

        #expect(fetched.count == 1)
        #expect(fetched[0].referenceNote == 69)
        #expect(fetched[0].targetNote == 69)
        #expect(fetched[0].initialCentOffset == 42.5)
        #expect(fetched[0].userCentError == -12.3)
        #expect(fetched[0].interval == 0)
        #expect(fetched[0].tuningSystem == "equalTemperament")
        #expect(abs(fetched[0].timestamp.timeIntervalSince(timestamp)) < 0.001)
    }

    @Test("PitchMatchingObserver saves multiple records from repeated calls")
    func pitchMatchingObserverSavesMultiple() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let completed = CompletedPitchMatchingTrial(
            referenceNote: 69,
            targetNote: 69,
            initialCentOffset: 42.5,
            userCentError: -12.3,
            tuningSystem: .equalTemperament
        )

        store.pitchMatchingCompleted(completed)
        store.pitchMatchingCompleted(completed)

        let fetched = try store.fetchAllPitchMatchings()
        #expect(fetched.count == 2)
    }

    // MARK: - PitchDiscriminationObserver Conformance Tests

    @Test("PitchDiscriminationObserver conformance saves record with derived interval and tuningSystem")
    func comparisonObserverSaves() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let timestamp = Date()
        let comparison = PitchDiscriminationTrial(
            referenceNote: 60,
            targetNote: DetunedMIDINote(note: 60, offset: Cents(25.0))
        )
        let completed = CompletedPitchDiscriminationTrial(
            trial: comparison,
            userAnsweredHigher: true,
            tuningSystem: .equalTemperament,
            timestamp: timestamp
        )

        store.pitchDiscriminationCompleted(completed)

        let fetched = try store.fetchAllPitchDiscriminations()

        #expect(fetched.count == 1)
        #expect(fetched[0].referenceNote == 60)
        #expect(fetched[0].targetNote == 60)
        #expect(fetched[0].centOffset == 25.0)
        #expect(fetched[0].isCorrect == true)
        #expect(fetched[0].interval == 0)
        #expect(fetched[0].tuningSystem == "equalTemperament")
        #expect(abs(fetched[0].timestamp.timeIntervalSince(timestamp)) < 0.001)
    }

    // MARK: - Interval Context Verification (Story 23.4)

    @Test("PitchDiscriminationObserver persists correct interval and tuningSystem for non-prime interval")
    func comparisonObserverWithInterval() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let comparison = PitchDiscriminationTrial(
            referenceNote: MIDINote(60),
            targetNote: DetunedMIDINote(note: MIDINote(67), offset: Cents(25.0))
        )
        let completed = CompletedPitchDiscriminationTrial(
            trial: comparison,
            userAnsweredHigher: true,
            tuningSystem: .equalTemperament
        )

        store.pitchDiscriminationCompleted(completed)

        let fetched = try store.fetchAllPitchDiscriminations()
        #expect(fetched.count == 1)
        #expect(fetched[0].referenceNote == 60)
        #expect(fetched[0].targetNote == 67)
        #expect(fetched[0].interval == 7)
        #expect(fetched[0].tuningSystem == "equalTemperament")
        #expect(fetched[0].centOffset == 25.0)
    }

    @Test("PitchMatchingObserver persists correct interval and tuningSystem for non-prime interval")
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

        store.pitchMatchingCompleted(completed)

        let fetched = try store.fetchAllPitchMatchings()
        #expect(fetched.count == 1)
        #expect(fetched[0].referenceNote == 60)
        #expect(fetched[0].targetNote == 67)
        #expect(fetched[0].interval == 7)
        #expect(fetched[0].tuningSystem == "equalTemperament")
        #expect(fetched[0].initialCentOffset == 30.0)
        #expect(fetched[0].userCentError == -5.0)
    }

    // MARK: - Pitch Matching Atomic Write Tests

    @Test("Pitch matching atomic write - successful save is complete")
    func pitchMatchingAtomicWriteSuccess() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let record = PitchMatchingRecord(referenceNote: 60, targetNote: 60, initialCentOffset: 10.0, userCentError: 5.0, interval: 0, tuningSystem: "equalTemperament")
        try store.save(record)

        let fetched = try store.fetchAllPitchMatchings()
        #expect(fetched.count == 1)
        #expect(fetched[0].referenceNote == 60)
        #expect(fetched[0].targetNote == 60)
        #expect(fetched[0].initialCentOffset == 10.0)
        #expect(fetched[0].userCentError == 5.0)
    }

    // MARK: - Rhythm Offset Detection CRUD Tests

    @Test("Save and retrieve a single rhythm offset detection record")
    func saveAndRetrieveRhythmOffsetDetectionRecord() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let timestamp = Date()
        let record = RhythmOffsetDetectionRecord(tempoBPM: 120, offsetMs: -15.5, isCorrect: true, timestamp: timestamp)

        try store.save(record)

        let fetched = try store.fetchAllRhythmOffsetDetections()

        #expect(fetched.count == 1)
        #expect(fetched[0].tempoBPM == 120)
        #expect(fetched[0].offsetMs == -15.5)
        #expect(fetched[0].isCorrect == true)
        #expect(abs(fetched[0].timestamp.timeIntervalSince(timestamp)) < 0.001)
    }

    @Test("Save and retrieve a single rhythm matching record")
    func saveAndRetrieveRhythmMatchingRecord() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let timestamp = Date()
        let record = RhythmMatchingRecord(tempoBPM: 90, userOffsetMs: 8.3, timestamp: timestamp)

        try store.save(record)

        let fetched = try store.fetchAllRhythmMatchings()

        #expect(fetched.count == 1)
        #expect(fetched[0].tempoBPM == 90)
        #expect(fetched[0].userOffsetMs == 8.3)
        #expect(abs(fetched[0].timestamp.timeIntervalSince(timestamp)) < 0.001)
    }

    @Test("FetchAllRhythmOffsetDetections returns records in timestamp order")
    func fetchRhythmOffsetDetectionsInOrder() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let now = Date()
        let record1 = RhythmOffsetDetectionRecord(tempoBPM: 100, offsetMs: -10.0, isCorrect: true, timestamp: now.addingTimeInterval(-60))
        let record2 = RhythmOffsetDetectionRecord(tempoBPM: 120, offsetMs: 5.0, isCorrect: false, timestamp: now.addingTimeInterval(-30))
        let record3 = RhythmOffsetDetectionRecord(tempoBPM: 140, offsetMs: -3.0, isCorrect: true, timestamp: now)

        try store.save(record1)
        try store.save(record2)
        try store.save(record3)

        let fetched = try store.fetchAllRhythmOffsetDetections()

        #expect(fetched.count == 3)
        #expect(fetched[0].tempoBPM == 100)
        #expect(fetched[1].tempoBPM == 120)
        #expect(fetched[2].tempoBPM == 140)
    }

    @Test("FetchAllRhythmMatchings returns records in timestamp order")
    func fetchRhythmMatchingsInOrder() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let now = Date()
        let record1 = RhythmMatchingRecord(tempoBPM: 80, userOffsetMs: -5.0, timestamp: now.addingTimeInterval(-60))
        let record2 = RhythmMatchingRecord(tempoBPM: 100, userOffsetMs: 2.0, timestamp: now.addingTimeInterval(-30))
        let record3 = RhythmMatchingRecord(tempoBPM: 120, userOffsetMs: 0.5, timestamp: now)

        try store.save(record1)
        try store.save(record2)
        try store.save(record3)

        let fetched = try store.fetchAllRhythmMatchings()

        #expect(fetched.count == 3)
        #expect(fetched[0].tempoBPM == 80)
        #expect(fetched[1].tempoBPM == 100)
        #expect(fetched[2].tempoBPM == 120)
    }

    @Test("deleteAllRhythmOffsetDetections deletes only rhythm offset detection records")
    func deleteAllRhythmOffsetDetectionsOnly() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let pitchRecord = PitchDiscriminationRecord(referenceNote: 60, targetNote: 60, centOffset: 10.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament")
        try store.save(pitchRecord)

        let rhythmCompRecord = RhythmOffsetDetectionRecord(tempoBPM: 120, offsetMs: -5.0, isCorrect: true)
        try store.save(rhythmCompRecord)

        let rhythmMatchRecord = RhythmMatchingRecord(tempoBPM: 100, userOffsetMs: 3.0)
        try store.save(rhythmMatchRecord)

        try store.deleteAllRhythmOffsetDetections()

        let rhythmComps = try store.fetchAllRhythmOffsetDetections()
        #expect(rhythmComps.isEmpty)

        let pitchComps = try store.fetchAllPitchDiscriminations()
        #expect(pitchComps.count == 1)

        let rhythmMatchings = try store.fetchAllRhythmMatchings()
        #expect(rhythmMatchings.count == 1)
    }

    @Test("deleteAllRhythmMatchings deletes only rhythm matching records")
    func deleteAllRhythmMatchingsOnly() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let pitchRecord = PitchMatchingRecord(referenceNote: 60, targetNote: 60, initialCentOffset: 10.0, userCentError: 5.0, interval: 0, tuningSystem: "equalTemperament")
        try store.save(pitchRecord)

        let rhythmCompRecord = RhythmOffsetDetectionRecord(tempoBPM: 120, offsetMs: -5.0, isCorrect: true)
        try store.save(rhythmCompRecord)

        let rhythmMatchRecord = RhythmMatchingRecord(tempoBPM: 100, userOffsetMs: 3.0)
        try store.save(rhythmMatchRecord)

        try store.deleteAllRhythmMatchings()

        let rhythmMatchings = try store.fetchAllRhythmMatchings()
        #expect(rhythmMatchings.isEmpty)

        let pitchMatchings = try store.fetchAllPitchMatchings()
        #expect(pitchMatchings.count == 1)

        let rhythmComps = try store.fetchAllRhythmOffsetDetections()
        #expect(rhythmComps.count == 1)
    }

    // MARK: - Rhythm Observer Conformance Tests

    @Test("RhythmOffsetDetectionObserver conformance saves record with correct fields")
    func rhythmOffsetDetectionObserverSaves() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let timestamp = Date()
        let completed = CompletedRhythmOffsetDetectionTrial(
            tempo: TempoBPM(120),
            offset: RhythmOffset(.milliseconds(-15)),
            isCorrect: true,
            timestamp: timestamp
        )

        store.rhythmOffsetDetectionCompleted(completed)

        let fetched = try store.fetchAllRhythmOffsetDetections()

        #expect(fetched.count == 1)
        #expect(fetched[0].tempoBPM == 120)
        #expect(fetched[0].offsetMs == -15.0)
        #expect(fetched[0].isCorrect == true)
        #expect(abs(fetched[0].timestamp.timeIntervalSince(timestamp)) < 0.001)
    }

    @Test("RhythmMatchingObserver conformance saves record with correct fields")
    func rhythmMatchingObserverSaves() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let timestamp = Date()
        let completed = CompletedRhythmMatchingTrial(
            tempo: TempoBPM(90),
            expectedOffset: RhythmOffset(.milliseconds(10)),
            userOffset: RhythmOffset(.milliseconds(8)),
            timestamp: timestamp
        )

        store.rhythmMatchingCompleted(completed)

        let fetched = try store.fetchAllRhythmMatchings()

        #expect(fetched.count == 1)
        #expect(fetched[0].tempoBPM == 90)
        #expect(fetched[0].userOffsetMs == 8.0)
        #expect(abs(fetched[0].timestamp.timeIntervalSince(timestamp)) < 0.001)
    }

    // MARK: - Continuous Rhythm Matching CRUD Tests

    @Test("Save and retrieve a single continuous rhythm matching record")
    func saveAndRetrieveContinuousRhythmMatchingRecord() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let timestamp = Date()
        let record = ContinuousRhythmMatchingRecord(
            tempoBPM: 120,
            meanOffsetMs: -8.5,
            meanOffsetMsPosition0: -5.0,
            timestamp: timestamp
        )

        try store.save(record)

        let fetched = try store.fetchAllContinuousRhythmMatchings()

        #expect(fetched.count == 1)
        #expect(fetched[0].tempoBPM == 120)
        #expect(fetched[0].meanOffsetMs == -8.5)
        #expect(abs(fetched[0].timestamp.timeIntervalSince(timestamp)) < 0.001)
    }

    @Test("FetchAllContinuousRhythmMatchings returns records in timestamp order")
    func fetchContinuousRhythmMatchingsInOrder() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let now = Date()
        let record1 = ContinuousRhythmMatchingRecord(tempoBPM: 80, meanOffsetMs: -5.0, timestamp: now.addingTimeInterval(-60))
        let record2 = ContinuousRhythmMatchingRecord(tempoBPM: 100, meanOffsetMs: 2.0, timestamp: now.addingTimeInterval(-30))
        let record3 = ContinuousRhythmMatchingRecord(tempoBPM: 120, meanOffsetMs: 0.5, timestamp: now)

        try store.save(record1)
        try store.save(record2)
        try store.save(record3)

        let fetched = try store.fetchAllContinuousRhythmMatchings()

        #expect(fetched.count == 3)
        #expect(fetched[0].tempoBPM == 80)
        #expect(fetched[1].tempoBPM == 100)
        #expect(fetched[2].tempoBPM == 120)
    }

    @Test("deleteAllContinuousRhythmMatchings deletes only continuous rhythm matching records")
    func deleteAllContinuousRhythmMatchingsOnly() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let continuousRecord = ContinuousRhythmMatchingRecord(tempoBPM: 120, meanOffsetMs: -5.0)
        try store.save(continuousRecord)

        let rhythmMatchRecord = RhythmMatchingRecord(tempoBPM: 100, userOffsetMs: 3.0)
        try store.save(rhythmMatchRecord)

        try store.deleteAllContinuousRhythmMatchings()

        let continuous = try store.fetchAllContinuousRhythmMatchings()
        #expect(continuous.isEmpty)

        let rhythmMatchings = try store.fetchAllRhythmMatchings()
        #expect(rhythmMatchings.count == 1)
    }

    @Test("deleteAll removes continuous rhythm matching records too")
    func deleteAllIncludesContinuousRhythmMatching() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let record = ContinuousRhythmMatchingRecord(tempoBPM: 120, meanOffsetMs: -5.0)
        try store.save(record)

        try store.deleteAll()

        let fetched = try store.fetchAllContinuousRhythmMatchings()
        #expect(fetched.isEmpty)
    }

    // MARK: - ContinuousRhythmMatchingObserver Conformance Tests

    @Test("ContinuousRhythmMatchingObserver conformance saves record with correct fields")
    func continuousRhythmMatchingObserverSaves() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let timestamp = Date()
        let gapResults = [
            GapResult(position: .first, offset: RhythmOffset(.milliseconds(-10))),
            GapResult(position: .third, offset: RhythmOffset(.milliseconds(5))),
            GapResult(position: .first, offset: RhythmOffset(.milliseconds(-8))),
        ]
        let trial = CompletedContinuousRhythmMatchingTrial(
            tempo: TempoBPM(120),
            gapResults: gapResults,
            timestamp: timestamp
        )

        store.continuousRhythmMatchingCompleted(trial)

        let fetched = try store.fetchAllContinuousRhythmMatchings()

        #expect(fetched.count == 1)
        #expect(fetched[0].tempoBPM == 120)
        #expect(abs(fetched[0].timestamp.timeIntervalSince(timestamp)) < 0.001)

        // Position 0 (.first): mean of -10 and -8 = -9.0
        #expect(fetched[0].meanOffsetMsPosition0 != nil)
        #expect(abs(fetched[0].meanOffsetMsPosition0! - (-9.0)) < 0.001)
        // Position 1 (.second): not used
        #expect(fetched[0].meanOffsetMsPosition1 == nil)
        // Position 2 (.third): single value 5.0
        #expect(fetched[0].meanOffsetMsPosition2 != nil)
        #expect(abs(fetched[0].meanOffsetMsPosition2! - 5.0) < 0.001)
        // Position 3 (.fourth): not used
        #expect(fetched[0].meanOffsetMsPosition3 == nil)
    }
}
