import Testing
import SwiftData
import Foundation
@testable import Peach

@Suite("Training Discipline Implementations")
struct TrainingDisciplineImplementationTests {

    // MARK: - Helpers

    private func makeTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: TrainingRecord.self,
            configurations: config
        )
    }

    private func makeStore() throws -> TrainingDataStore {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        return TrainingDataStore(modelContext: context)
    }

    private func fixedDate(minutesOffset: Double = 0) -> Date {
        Date(timeIntervalSinceReferenceDate: 794_394_000 + minutesOffset * 60)
    }

    private func envelope(for payload: any TrainingDisciplinePayload, timestamp: Date) throws -> TrainingRecord {
        try JSONEnvelope.encode(payload, timestamp: timestamp)
    }

    private func makeImportResult(
        pitchDiscriminations: [(timestamp: Date, payload: PitchDiscriminationPayload)] = [],
        pitchMatchings: [(timestamp: Date, payload: PitchMatchingPayload)] = [],
        timingOffsetDetections: [(timestamp: Date, payload: TimingOffsetDetectionPayload)] = [],
        continuousRhythmMatchings: [(timestamp: Date, payload: ContinuousRhythmMatchingPayload)] = []
    ) -> CSVImportParser.ImportResult {
        var payloads: [String: [(timestamp: Date, payload: any TrainingDisciplinePayload)]] = [:]
        if !pitchDiscriminations.isEmpty {
            payloads["pitchDiscrimination"] = pitchDiscriminations.map { ($0.timestamp, $0.payload as any TrainingDisciplinePayload) }
        }
        if !pitchMatchings.isEmpty {
            payloads["pitchMatching"] = pitchMatchings.map { ($0.timestamp, $0.payload as any TrainingDisciplinePayload) }
        }
        if !timingOffsetDetections.isEmpty {
            payloads["rhythmOffsetDetection"] = timingOffsetDetections.map { ($0.timestamp, $0.payload as any TrainingDisciplinePayload) }
        }
        if !continuousRhythmMatchings.isEmpty {
            payloads["continuousRhythmMatching"] = continuousRhythmMatchings.map { ($0.timestamp, $0.payload as any TrainingDisciplinePayload) }
        }
        return CSVImportParser.ImportResult(payloads: payloads, errors: [])
    }

    // MARK: - Payload Factories

    private func makePitchDiscriminationEntry(
        referenceNote: Int = 60,
        targetNote: Int = 64,
        centOffset: Double = 15.5,
        isCorrect: Bool = true,
        interval: Int = 0,
        tuningSystem: String = "equalTemperament",
        minutesOffset: Double = 0
    ) -> (timestamp: Date, payload: PitchDiscriminationPayload) {
        (
            fixedDate(minutesOffset: minutesOffset),
            PitchDiscriminationPayload(
                referenceNote: referenceNote,
                targetNote: targetNote,
                centOffset: centOffset,
                isCorrect: isCorrect,
                interval: interval,
                tuningSystem: tuningSystem
            )
        )
    }

    private func makePitchMatchingEntry(
        referenceNote: Int = 69,
        targetNote: Int = 72,
        initialCentOffset: Double = 25.0,
        userCentError: Double = 3.2,
        interval: Int = 0,
        tuningSystem: String = "equalTemperament",
        minutesOffset: Double = 0
    ) -> (timestamp: Date, payload: PitchMatchingPayload) {
        (
            fixedDate(minutesOffset: minutesOffset),
            PitchMatchingPayload(
                referenceNote: referenceNote,
                targetNote: targetNote,
                initialCentOffset: initialCentOffset,
                userCentError: userCentError,
                interval: interval,
                tuningSystem: tuningSystem
            )
        )
    }

    private func makeTimingOffsetDetectionEntry(
        tempoBPM: Int = 100,
        offsetMs: Double = 12.5,
        isCorrect: Bool = true,
        minutesOffset: Double = 0
    ) -> (timestamp: Date, payload: TimingOffsetDetectionPayload) {
        (
            fixedDate(minutesOffset: minutesOffset),
            TimingOffsetDetectionPayload(
                tempoBPM: tempoBPM,
                offsetMs: offsetMs,
                isCorrect: isCorrect
            )
        )
    }

#if PEACH_RESEARCH
    private func makeContinuousRhythmMatchingEntry(
        tempoBPM: Int = 100,
        meanOffsetMs: Double = 8.5,
        position0: Double? = 5.0,
        position1: Double? = 10.0,
        position2: Double? = nil,
        position3: Double? = nil,
        minutesOffset: Double = 0
    ) -> (timestamp: Date, payload: ContinuousRhythmMatchingPayload) {
        (
            fixedDate(minutesOffset: minutesOffset),
            ContinuousRhythmMatchingPayload(
                tempoBPM: tempoBPM,
                meanOffsetMs: meanOffsetMs,
                meanOffsetMsPosition0: position0,
                meanOffsetMsPosition1: position1,
                meanOffsetMsPosition2: position2,
                meanOffsetMsPosition3: position3
            )
        )
    }
#endif

    // MARK: - Task 1.2: csvKeyValuePairs produces expected column values

    @Test("UnisonPitchDiscrimination csvKeyValuePairs produces correct columns")
    func unisonPitchDiscriminationCSVKeyValuePairs() async {
        let discipline = UnisonPitchDiscriminationDiscipline()
        let entry = makePitchDiscriminationEntry(referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true, interval: 0)

        let pairs = discipline.csvKeyValuePairs(for: entry.payload)
        let dict = Dictionary(uniqueKeysWithValues: pairs)

        #expect(dict["referenceNote"] == "60")
        #expect(dict["targetNote"] == "64")
        #expect(dict["centOffset"] == "15.5")
        #expect(dict["isCorrect"] == "true")
        #expect(dict["interval"] == "P1")
        #expect(dict["tuningSystem"] == "equalTemperament")
        #expect(dict["referenceNoteName"] != nil)
        #expect(dict["targetNoteName"] != nil)
    }

    @Test("IntervalPitchDiscrimination csvKeyValuePairs produces correct columns")
    func intervalPitchDiscriminationCSVKeyValuePairs() async {
        let discipline = IntervalPitchDiscriminationDiscipline()
        let entry = makePitchDiscriminationEntry(referenceNote: 60, targetNote: 67, centOffset: -8.3, isCorrect: false, interval: 7)

        let pairs = discipline.csvKeyValuePairs(for: entry.payload)
        let dict = Dictionary(uniqueKeysWithValues: pairs)

        #expect(dict["referenceNote"] == "60")
        #expect(dict["targetNote"] == "67")
        #expect(dict["centOffset"] == "-8.3")
        #expect(dict["isCorrect"] == "false")
        #expect(dict["interval"] == "P5")
        #expect(dict["tuningSystem"] == "equalTemperament")
    }

    @Test("UnisonPitchMatching csvKeyValuePairs produces correct columns")
    func unisonPitchMatchingCSVKeyValuePairs() async {
        let discipline = UnisonPitchMatchingDiscipline()
        let entry = makePitchMatchingEntry(referenceNote: 69, targetNote: 72, initialCentOffset: 25.0, userCentError: 3.2, interval: 0)

        let pairs = discipline.csvKeyValuePairs(for: entry.payload)
        let dict = Dictionary(uniqueKeysWithValues: pairs)

        #expect(dict["referenceNote"] == "69")
        #expect(dict["targetNote"] == "72")
        #expect(dict["initialCentOffset"] == "25.0")
        #expect(dict["userCentError"] == "3.2")
        #expect(dict["interval"] == "P1")
        #expect(dict["tuningSystem"] == "equalTemperament")
    }

    @Test("IntervalPitchMatching csvKeyValuePairs produces correct columns")
    func intervalPitchMatchingCSVKeyValuePairs() async {
        let discipline = IntervalPitchMatchingDiscipline()
        let entry = makePitchMatchingEntry(referenceNote: 60, targetNote: 67, initialCentOffset: -12.0, userCentError: 1.5, interval: 7)

        let pairs = discipline.csvKeyValuePairs(for: entry.payload)
        let dict = Dictionary(uniqueKeysWithValues: pairs)

        #expect(dict["referenceNote"] == "60")
        #expect(dict["targetNote"] == "67")
        #expect(dict["initialCentOffset"] == "-12.0")
        #expect(dict["userCentError"] == "1.5")
        #expect(dict["interval"] == "P5")
    }

    @Test("TimingOffsetDetection csvKeyValuePairs produces correct columns")
    func timingOffsetDetectionCSVKeyValuePairs() async {
        let discipline = TimingOffsetDetectionDiscipline()
        let entry = makeTimingOffsetDetectionEntry(tempoBPM: 120, offsetMs: -5.3, isCorrect: true)

        let pairs = discipline.csvKeyValuePairs(for: entry.payload)
        let dict = Dictionary(uniqueKeysWithValues: pairs)

        #expect(dict["tempoBPM"] == "120")
        #expect(dict["offsetMs"] == "-5.3")
        #expect(dict["isCorrect"] == "true")
    }

#if PEACH_RESEARCH
    @Test("ContinuousRhythmMatching csvKeyValuePairs produces correct columns")
    func continuousRhythmMatchingCSVKeyValuePairs() async {
        let discipline = ContinuousRhythmMatchingDiscipline()
        let entry = makeContinuousRhythmMatchingEntry(tempoBPM: 90, meanOffsetMs: 7.2, position0: 5.0, position1: 10.0, position2: nil, position3: nil)

        let pairs = discipline.csvKeyValuePairs(for: entry.payload)
        let dict = Dictionary(uniqueKeysWithValues: pairs)

        #expect(dict["tempoBPM"] == "90")
        #expect(dict["meanOffsetMs"] == "7.2")
        #expect(dict["meanOffsetMsPosition0"] == "5.0")
        #expect(dict["meanOffsetMsPosition1"] == "10.0")
        #expect(dict["meanOffsetMsPosition2"] == "")
        #expect(dict["meanOffsetMsPosition3"] == "")
    }
#endif

    // MARK: - Task 1.3: parseCSVRow round-trip

    @Test("UnisonPitchDiscrimination round-trip: csvKeyValuePairs then parseCSVRow produces equal payload")
    func unisonPitchDiscriminationRoundTrip() async throws {
        let discipline = UnisonPitchDiscriminationDiscipline()
        let original = makePitchDiscriminationEntry(referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true, interval: 0)

        let (fields, columnIndex) = try buildCSVFields(
            trainingType: "pitchDiscrimination", timestamp: original.timestamp,
            pairs: discipline.csvKeyValuePairs(for: original.payload))

        let parsed = try discipline.parseCSVRow(fields: fields, columnIndex: columnIndex, rowNumber: 1).get()

        #expect(parsed.payload.referenceNote == original.payload.referenceNote)
        #expect(parsed.payload.targetNote == original.payload.targetNote)
        #expect(parsed.payload.centOffset == original.payload.centOffset)
        #expect(parsed.payload.isCorrect == original.payload.isCorrect)
        #expect(parsed.payload.interval == original.payload.interval)
        #expect(parsed.payload.tuningSystem == original.payload.tuningSystem)
        #expect(parsed.timestamp == original.timestamp)
    }

    @Test("IntervalPitchDiscrimination round-trip: csvKeyValuePairs then parseCSVRow produces equal payload")
    func intervalPitchDiscriminationRoundTrip() async throws {
        let discipline = IntervalPitchDiscriminationDiscipline()
        let original = makePitchDiscriminationEntry(referenceNote: 60, targetNote: 67, centOffset: -8.3, isCorrect: false, interval: 7)

        let (fields, columnIndex) = try buildCSVFields(
            trainingType: "pitchDiscrimination", timestamp: original.timestamp,
            pairs: discipline.csvKeyValuePairs(for: original.payload))

        let parsed = try discipline.parseCSVRow(fields: fields, columnIndex: columnIndex, rowNumber: 1).get()

        #expect(parsed.payload.referenceNote == original.payload.referenceNote)
        #expect(parsed.payload.targetNote == original.payload.targetNote)
        #expect(parsed.payload.centOffset == original.payload.centOffset)
        #expect(parsed.payload.isCorrect == original.payload.isCorrect)
        #expect(parsed.payload.interval == original.payload.interval)
        #expect(parsed.payload.tuningSystem == original.payload.tuningSystem)
        #expect(parsed.timestamp == original.timestamp)
    }

    @Test("UnisonPitchMatching round-trip: csvKeyValuePairs then parseCSVRow produces equal payload")
    func unisonPitchMatchingRoundTrip() async throws {
        let discipline = UnisonPitchMatchingDiscipline()
        let original = makePitchMatchingEntry(referenceNote: 69, targetNote: 72, initialCentOffset: 25.0, userCentError: 3.2, interval: 0)

        let (fields, columnIndex) = try buildCSVFields(
            trainingType: "pitchMatching", timestamp: original.timestamp,
            pairs: discipline.csvKeyValuePairs(for: original.payload))

        let parsed = try discipline.parseCSVRow(fields: fields, columnIndex: columnIndex, rowNumber: 1).get()

        #expect(parsed.payload.referenceNote == original.payload.referenceNote)
        #expect(parsed.payload.targetNote == original.payload.targetNote)
        #expect(parsed.payload.initialCentOffset == original.payload.initialCentOffset)
        #expect(parsed.payload.userCentError == original.payload.userCentError)
        #expect(parsed.payload.interval == original.payload.interval)
        #expect(parsed.payload.tuningSystem == original.payload.tuningSystem)
        #expect(parsed.timestamp == original.timestamp)
    }

    @Test("IntervalPitchMatching round-trip: csvKeyValuePairs then parseCSVRow produces equal payload")
    func intervalPitchMatchingRoundTrip() async throws {
        let discipline = IntervalPitchMatchingDiscipline()
        let original = makePitchMatchingEntry(referenceNote: 60, targetNote: 67, initialCentOffset: -12.0, userCentError: 1.5, interval: 7)

        let (fields, columnIndex) = try buildCSVFields(
            trainingType: "pitchMatching", timestamp: original.timestamp,
            pairs: discipline.csvKeyValuePairs(for: original.payload))

        let parsed = try discipline.parseCSVRow(fields: fields, columnIndex: columnIndex, rowNumber: 1).get()

        #expect(parsed.payload.referenceNote == original.payload.referenceNote)
        #expect(parsed.payload.targetNote == original.payload.targetNote)
        #expect(parsed.payload.initialCentOffset == original.payload.initialCentOffset)
        #expect(parsed.payload.userCentError == original.payload.userCentError)
        #expect(parsed.payload.interval == original.payload.interval)
        #expect(parsed.payload.tuningSystem == original.payload.tuningSystem)
        #expect(parsed.timestamp == original.timestamp)
    }

    @Test("TimingOffsetDetection round-trip: csvKeyValuePairs then parseCSVRow produces equal payload")
    func timingOffsetDetectionRoundTrip() async throws {
        let discipline = TimingOffsetDetectionDiscipline()
        let original = makeTimingOffsetDetectionEntry(tempoBPM: 120, offsetMs: -5.3, isCorrect: true)

        let (fields, columnIndex) = try buildCSVFields(
            trainingType: "rhythmOffsetDetection", timestamp: original.timestamp,
            pairs: discipline.csvKeyValuePairs(for: original.payload))

        let parsed = try discipline.parseCSVRow(fields: fields, columnIndex: columnIndex, rowNumber: 1).get()

        #expect(parsed.payload.tempoBPM == original.payload.tempoBPM)
        #expect(parsed.payload.offsetMs == original.payload.offsetMs)
        #expect(parsed.payload.isCorrect == original.payload.isCorrect)
        #expect(parsed.timestamp == original.timestamp)
    }

#if PEACH_RESEARCH
    @Test("ContinuousRhythmMatching round-trip: csvKeyValuePairs then parseCSVRow produces equal payload")
    func continuousRhythmMatchingRoundTrip() async throws {
        let discipline = ContinuousRhythmMatchingDiscipline()
        let original = makeContinuousRhythmMatchingEntry(tempoBPM: 90, meanOffsetMs: 7.2, position0: 5.0, position1: 10.0, position2: nil, position3: nil)

        let (fields, columnIndex) = try buildCSVFields(
            trainingType: "continuousRhythmMatching", timestamp: original.timestamp,
            pairs: discipline.csvKeyValuePairs(for: original.payload))

        let parsed = try discipline.parseCSVRow(fields: fields, columnIndex: columnIndex, rowNumber: 1).get()

        #expect(parsed.payload.tempoBPM == original.payload.tempoBPM)
        #expect(parsed.payload.meanOffsetMs == original.payload.meanOffsetMs)
        #expect(parsed.payload.meanOffsetMsPosition0 == original.payload.meanOffsetMsPosition0)
        #expect(parsed.payload.meanOffsetMsPosition1 == original.payload.meanOffsetMsPosition1)
        #expect(parsed.payload.meanOffsetMsPosition2 == original.payload.meanOffsetMsPosition2)
        #expect(parsed.payload.meanOffsetMsPosition3 == original.payload.meanOffsetMsPosition3)
        #expect(parsed.timestamp == original.timestamp)
    }
#endif

    // MARK: - Task 1.4: mergeImportRecords skips duplicates, imports non-duplicates

    @Test("UnisonPitchDiscrimination mergeImportRecords skips duplicates and imports new records")
    func unisonPitchDiscriminationMergeDuplicates() async throws {
        let store = try makeStore()
        let discipline = UnisonPitchDiscriminationDiscipline()

        let existing = makePitchDiscriminationEntry(referenceNote: 60, targetNote: 64, interval: 0, minutesOffset: 0)
        try store.save(envelope(for: existing.payload, timestamp: existing.timestamp))

        let duplicate = makePitchDiscriminationEntry(referenceNote: 60, targetNote: 64, interval: 0, minutesOffset: 0)
        let newEntry = makePitchDiscriminationEntry(referenceNote: 60, targetNote: 64, interval: 0, minutesOffset: 5)

        let importResult = makeImportResult(pitchDiscriminations: [duplicate, newEntry])

        var mergeResult: (imported: Int, skipped: Int) = (0, 0)
        try store.withinTransaction { scope in
            mergeResult = try discipline.mergeImportRecords(from: importResult, existingIn: store, into: scope)
        }

        #expect(mergeResult.imported == 1)
        #expect(mergeResult.skipped == 1)
    }

    @Test("IntervalPitchDiscrimination mergeImportRecords filters only interval records")
    func intervalPitchDiscriminationMergeFilters() async throws {
        let store = try makeStore()
        let discipline = IntervalPitchDiscriminationDiscipline()

        let unisonEntry = makePitchDiscriminationEntry(interval: 0, minutesOffset: 0)
        let intervalEntry = makePitchDiscriminationEntry(interval: 7, minutesOffset: 1)

        let importResult = makeImportResult(pitchDiscriminations: [unisonEntry, intervalEntry])

        var mergeResult: (imported: Int, skipped: Int) = (0, 0)
        try store.withinTransaction { scope in
            mergeResult = try discipline.mergeImportRecords(from: importResult, existingIn: store, into: scope)
        }

        #expect(mergeResult.imported == 1)
        #expect(mergeResult.skipped == 0)
    }

    @Test("UnisonPitchMatching mergeImportRecords skips duplicates and imports new records")
    func unisonPitchMatchingMergeDuplicates() async throws {
        let store = try makeStore()
        let discipline = UnisonPitchMatchingDiscipline()

        let existing = makePitchMatchingEntry(referenceNote: 69, targetNote: 72, interval: 0, minutesOffset: 0)
        try store.save(envelope(for: existing.payload, timestamp: existing.timestamp))

        let duplicate = makePitchMatchingEntry(referenceNote: 69, targetNote: 72, interval: 0, minutesOffset: 0)
        let newEntry = makePitchMatchingEntry(referenceNote: 69, targetNote: 72, interval: 0, minutesOffset: 5)

        let importResult = makeImportResult(pitchMatchings: [duplicate, newEntry])

        var mergeResult: (imported: Int, skipped: Int) = (0, 0)
        try store.withinTransaction { scope in
            mergeResult = try discipline.mergeImportRecords(from: importResult, existingIn: store, into: scope)
        }

        #expect(mergeResult.imported == 1)
        #expect(mergeResult.skipped == 1)
    }

    @Test("IntervalPitchMatching mergeImportRecords filters only interval records and skips duplicates")
    func intervalPitchMatchingMergeDuplicatesAndFilters() async throws {
        let store = try makeStore()
        let discipline = IntervalPitchMatchingDiscipline()

        let existing = makePitchMatchingEntry(referenceNote: 60, targetNote: 67, interval: 7, minutesOffset: 0)
        try store.save(envelope(for: existing.payload, timestamp: existing.timestamp))

        let unisonEntry = makePitchMatchingEntry(interval: 0, minutesOffset: 1)
        let duplicate = makePitchMatchingEntry(referenceNote: 60, targetNote: 67, interval: 7, minutesOffset: 0)
        let newEntry = makePitchMatchingEntry(referenceNote: 60, targetNote: 67, interval: 7, minutesOffset: 5)

        let importResult = makeImportResult(pitchMatchings: [unisonEntry, duplicate, newEntry])

        var mergeResult: (imported: Int, skipped: Int) = (0, 0)
        try store.withinTransaction { scope in
            mergeResult = try discipline.mergeImportRecords(from: importResult, existingIn: store, into: scope)
        }

        #expect(mergeResult.imported == 1)
        #expect(mergeResult.skipped == 1)
    }

    @Test("TimingOffsetDetection mergeImportRecords skips duplicates and imports new records")
    func timingOffsetDetectionMergeDuplicates() async throws {
        let store = try makeStore()
        let discipline = TimingOffsetDetectionDiscipline()

        let existing = makeTimingOffsetDetectionEntry(tempoBPM: 100, minutesOffset: 0)
        try store.save(envelope(for: existing.payload, timestamp: existing.timestamp))

        let duplicate = makeTimingOffsetDetectionEntry(tempoBPM: 100, minutesOffset: 0)
        let newEntry = makeTimingOffsetDetectionEntry(tempoBPM: 100, minutesOffset: 5)

        let importResult = makeImportResult(timingOffsetDetections: [duplicate, newEntry])

        var mergeResult: (imported: Int, skipped: Int) = (0, 0)
        try store.withinTransaction { scope in
            mergeResult = try discipline.mergeImportRecords(from: importResult, existingIn: store, into: scope)
        }

        #expect(mergeResult.imported == 1)
        #expect(mergeResult.skipped == 1)
    }

#if PEACH_RESEARCH
    @Test("ContinuousRhythmMatching mergeImportRecords skips duplicates and imports new records")
    func continuousRhythmMatchingMergeDuplicates() async throws {
        let store = try makeStore()
        let discipline = ContinuousRhythmMatchingDiscipline()

        let existing = makeContinuousRhythmMatchingEntry(tempoBPM: 100, minutesOffset: 0)
        try store.save(envelope(for: existing.payload, timestamp: existing.timestamp))

        let duplicate = makeContinuousRhythmMatchingEntry(tempoBPM: 100, minutesOffset: 0)
        let newEntry = makeContinuousRhythmMatchingEntry(tempoBPM: 100, minutesOffset: 5)

        let importResult = makeImportResult(continuousRhythmMatchings: [duplicate, newEntry])

        var mergeResult: (imported: Int, skipped: Int) = (0, 0)
        try store.withinTransaction { scope in
            mergeResult = try discipline.mergeImportRecords(from: importResult, existingIn: store, into: scope)
        }

        #expect(mergeResult.imported == 1)
        #expect(mergeResult.skipped == 1)
    }
#endif

    // MARK: - Task 1.5: fetchExportRecords filtering

    @Test("UnisonPitchDiscrimination fetchExportRecords returns only interval==0 records")
    func unisonPitchDiscriminationFetchFiltering() async throws {
        let store = try makeStore()
        let discipline = UnisonPitchDiscriminationDiscipline()

        try store.save(envelope(for: makePitchDiscriminationEntry(interval: 0, minutesOffset: 0).payload, timestamp: fixedDate(minutesOffset: 0)))
        try store.save(envelope(for: makePitchDiscriminationEntry(interval: 7, minutesOffset: 1).payload, timestamp: fixedDate(minutesOffset: 1)))
        try store.save(envelope(for: makePitchDiscriminationEntry(interval: 0, minutesOffset: 2).payload, timestamp: fixedDate(minutesOffset: 2)))

        let records = try discipline.fetchExportRecords(from: store)
        #expect(records.count == 2)
    }

    @Test("IntervalPitchDiscrimination fetchExportRecords returns only interval!=0 records")
    func intervalPitchDiscriminationFetchFiltering() async throws {
        let store = try makeStore()
        let discipline = IntervalPitchDiscriminationDiscipline()

        try store.save(envelope(for: makePitchDiscriminationEntry(interval: 0, minutesOffset: 0).payload, timestamp: fixedDate(minutesOffset: 0)))
        try store.save(envelope(for: makePitchDiscriminationEntry(interval: 7, minutesOffset: 1).payload, timestamp: fixedDate(minutesOffset: 1)))
        try store.save(envelope(for: makePitchDiscriminationEntry(interval: 4, minutesOffset: 2).payload, timestamp: fixedDate(minutesOffset: 2)))

        let records = try discipline.fetchExportRecords(from: store)
        #expect(records.count == 2)
    }

    @Test("UnisonPitchMatching fetchExportRecords returns only interval==0 records")
    func unisonPitchMatchingFetchFiltering() async throws {
        let store = try makeStore()
        let discipline = UnisonPitchMatchingDiscipline()

        try store.save(envelope(for: makePitchMatchingEntry(interval: 0, minutesOffset: 0).payload, timestamp: fixedDate(minutesOffset: 0)))
        try store.save(envelope(for: makePitchMatchingEntry(interval: 3, minutesOffset: 1).payload, timestamp: fixedDate(minutesOffset: 1)))

        let records = try discipline.fetchExportRecords(from: store)
        #expect(records.count == 1)
    }

    @Test("IntervalPitchMatching fetchExportRecords returns only interval!=0 records")
    func intervalPitchMatchingFetchFiltering() async throws {
        let store = try makeStore()
        let discipline = IntervalPitchMatchingDiscipline()

        try store.save(envelope(for: makePitchMatchingEntry(interval: 0, minutesOffset: 0).payload, timestamp: fixedDate(minutesOffset: 0)))
        try store.save(envelope(for: makePitchMatchingEntry(interval: 3, minutesOffset: 1).payload, timestamp: fixedDate(minutesOffset: 1)))
        try store.save(envelope(for: makePitchMatchingEntry(interval: 5, minutesOffset: 2).payload, timestamp: fixedDate(minutesOffset: 2)))

        let records = try discipline.fetchExportRecords(from: store)
        #expect(records.count == 2)
    }

    @Test("TimingOffsetDetection fetchExportRecords returns all records")
    func timingOffsetDetectionFetchAll() async throws {
        let store = try makeStore()
        let discipline = TimingOffsetDetectionDiscipline()

        try store.save(envelope(for: makeTimingOffsetDetectionEntry(minutesOffset: 0).payload, timestamp: fixedDate(minutesOffset: 0)))
        try store.save(envelope(for: makeTimingOffsetDetectionEntry(minutesOffset: 1).payload, timestamp: fixedDate(minutesOffset: 1)))

        let records = try discipline.fetchExportRecords(from: store)
        #expect(records.count == 2)
    }

#if PEACH_RESEARCH
    @Test("ContinuousRhythmMatching fetchExportRecords returns all records")
    func continuousRhythmMatchingFetchAll() async throws {
        let store = try makeStore()
        let discipline = ContinuousRhythmMatchingDiscipline()

        try store.save(envelope(for: makeContinuousRhythmMatchingEntry(minutesOffset: 0).payload, timestamp: fixedDate(minutesOffset: 0)))
        try store.save(envelope(for: makeContinuousRhythmMatchingEntry(minutesOffset: 1).payload, timestamp: fixedDate(minutesOffset: 1)))

        let records = try discipline.fetchExportRecords(from: store)
        #expect(records.count == 2)
    }
#endif
}
