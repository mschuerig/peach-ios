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
            for: PitchDiscriminationRecord.self,
            PitchMatchingRecord.self,
            TimingOffsetDetectionRecord.self,
            ContinuousRhythmMatchingRecord.self,
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

    private func makeImportResult(
        pitchDiscriminations: [PitchDiscriminationRecord] = [],
        pitchMatchings: [PitchMatchingRecord] = [],
        timingOffsetDetections: [TimingOffsetDetectionRecord] = [],
        continuousRhythmMatchings: [ContinuousRhythmMatchingRecord] = []
    ) -> CSVImportParser.ImportResult {
        var records: [String: [any PersistentModel]] = [:]
        if !pitchDiscriminations.isEmpty { records["pitchDiscrimination"] = pitchDiscriminations }
        if !pitchMatchings.isEmpty { records["pitchMatching"] = pitchMatchings }
        if !timingOffsetDetections.isEmpty { records["rhythmOffsetDetection"] = timingOffsetDetections }
        if !continuousRhythmMatchings.isEmpty { records["continuousRhythmMatching"] = continuousRhythmMatchings }
        return CSVImportParser.ImportResult(records: records, errors: [])
    }

    // MARK: - Record Factories

    private func makePitchDiscriminationRecord(
        referenceNote: Int = 60,
        targetNote: Int = 64,
        centOffset: Double = 15.5,
        isCorrect: Bool = true,
        interval: Int = 0,
        tuningSystem: String = "equalTemperament",
        minutesOffset: Double = 0
    ) -> PitchDiscriminationRecord {
        PitchDiscriminationRecord(
            referenceNote: referenceNote,
            targetNote: targetNote,
            centOffset: centOffset,
            isCorrect: isCorrect,
            interval: interval,
            tuningSystem: tuningSystem,
            timestamp: fixedDate(minutesOffset: minutesOffset)
        )
    }

    private func makePitchMatchingRecord(
        referenceNote: Int = 69,
        targetNote: Int = 72,
        initialCentOffset: Double = 25.0,
        userCentError: Double = 3.2,
        interval: Int = 0,
        tuningSystem: String = "equalTemperament",
        minutesOffset: Double = 0
    ) -> PitchMatchingRecord {
        PitchMatchingRecord(
            referenceNote: referenceNote,
            targetNote: targetNote,
            initialCentOffset: initialCentOffset,
            userCentError: userCentError,
            interval: interval,
            tuningSystem: tuningSystem,
            timestamp: fixedDate(minutesOffset: minutesOffset)
        )
    }

    private func makeTimingOffsetDetectionRecord(
        tempoBPM: Int = 100,
        offsetMs: Double = 12.5,
        isCorrect: Bool = true,
        minutesOffset: Double = 0
    ) -> TimingOffsetDetectionRecord {
        TimingOffsetDetectionRecord(
            tempoBPM: tempoBPM,
            offsetMs: offsetMs,
            isCorrect: isCorrect,
            timestamp: fixedDate(minutesOffset: minutesOffset)
        )
    }

    private func makeContinuousRhythmMatchingRecord(
        tempoBPM: Int = 100,
        meanOffsetMs: Double = 8.5,
        position0: Double? = 5.0,
        position1: Double? = 10.0,
        position2: Double? = nil,
        position3: Double? = nil,
        minutesOffset: Double = 0
    ) -> ContinuousRhythmMatchingRecord {
        ContinuousRhythmMatchingRecord(
            tempoBPM: tempoBPM,
            meanOffsetMs: meanOffsetMs,
            meanOffsetMsPosition0: position0,
            meanOffsetMsPosition1: position1,
            meanOffsetMsPosition2: position2,
            meanOffsetMsPosition3: position3,
            timestamp: fixedDate(minutesOffset: minutesOffset)
        )
    }

    // MARK: - Task 1.2: csvKeyValuePairs produces expected column values

    @Test("UnisonPitchDiscrimination csvKeyValuePairs produces correct columns")
    func unisonPitchDiscriminationCSVKeyValuePairs() async {
        let discipline = UnisonPitchDiscriminationDiscipline()
        let record = makePitchDiscriminationRecord(referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true, interval: 0)

        let pairs = discipline.csvKeyValuePairs(for: record)
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
        let record = makePitchDiscriminationRecord(referenceNote: 60, targetNote: 67, centOffset: -8.3, isCorrect: false, interval: 7)

        let pairs = discipline.csvKeyValuePairs(for: record)
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
        let record = makePitchMatchingRecord(referenceNote: 69, targetNote: 72, initialCentOffset: 25.0, userCentError: 3.2, interval: 0)

        let pairs = discipline.csvKeyValuePairs(for: record)
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
        let record = makePitchMatchingRecord(referenceNote: 60, targetNote: 67, initialCentOffset: -12.0, userCentError: 1.5, interval: 7)

        let pairs = discipline.csvKeyValuePairs(for: record)
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
        let record = makeTimingOffsetDetectionRecord(tempoBPM: 120, offsetMs: -5.3, isCorrect: true)

        let pairs = discipline.csvKeyValuePairs(for: record)
        let dict = Dictionary(uniqueKeysWithValues: pairs)

        #expect(dict["tempoBPM"] == "120")
        #expect(dict["offsetMs"] == "-5.3")
        #expect(dict["isCorrect"] == "true")
    }

    @Test("ContinuousRhythmMatching csvKeyValuePairs produces correct columns")
    func continuousRhythmMatchingCSVKeyValuePairs() async {
        let discipline = ContinuousRhythmMatchingDiscipline()
        let record = makeContinuousRhythmMatchingRecord(tempoBPM: 90, meanOffsetMs: 7.2, position0: 5.0, position1: 10.0, position2: nil, position3: nil)

        let pairs = discipline.csvKeyValuePairs(for: record)
        let dict = Dictionary(uniqueKeysWithValues: pairs)

        #expect(dict["tempoBPM"] == "90")
        #expect(dict["meanOffsetMs"] == "7.2")
        #expect(dict["meanOffsetMsPosition0"] == "5.0")
        #expect(dict["meanOffsetMsPosition1"] == "10.0")
        #expect(dict["meanOffsetMsPosition2"] == "")
        #expect(dict["meanOffsetMsPosition3"] == "")
    }

    // MARK: - Task 1.3: parseCSVRow round-trip

    private func buildCSVFields(
        trainingType: String,
        timestamp: Date,
        pairs: [(String, String)]
    ) throws -> (fields: [String], columnIndex: [String: Int]) {
        let allColumns = CSVExportSchema.allColumns
        let columnIndex = CSVExportSchema.columnIndex

        var fields = Array(repeating: "", count: allColumns.count)
        let typeIdx = try #require(columnIndex["trainingType"])
        let tsIdx = try #require(columnIndex["timestamp"])
        fields[typeIdx] = trainingType
        fields[tsIdx] = CSVParserHelpers.formatTimestamp(timestamp)
        for (key, value) in pairs {
            if let idx = columnIndex[key] { fields[idx] = value }
        }
        return (fields, columnIndex)
    }

    @Test("UnisonPitchDiscrimination round-trip: csvKeyValuePairs then parseCSVRow produces equal record")
    func unisonPitchDiscriminationRoundTrip() async throws {
        let discipline = UnisonPitchDiscriminationDiscipline()
        let original = makePitchDiscriminationRecord(referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true, interval: 0)

        let (fields, columnIndex) = try buildCSVFields(
            trainingType: "pitchDiscrimination", timestamp: original.timestamp,
            pairs: discipline.csvKeyValuePairs(for: original))

        let parsed = try #require(try discipline.parseCSVRow(fields: fields, columnIndex: columnIndex, rowNumber: 1).get() as? PitchDiscriminationRecord)

        #expect(parsed.referenceNote == original.referenceNote)
        #expect(parsed.targetNote == original.targetNote)
        #expect(parsed.centOffset == original.centOffset)
        #expect(parsed.isCorrect == original.isCorrect)
        #expect(parsed.interval == original.interval)
        #expect(parsed.tuningSystem == original.tuningSystem)
        #expect(parsed.timestamp == original.timestamp)
    }

    @Test("IntervalPitchDiscrimination round-trip: csvKeyValuePairs then parseCSVRow produces equal record")
    func intervalPitchDiscriminationRoundTrip() async throws {
        let discipline = IntervalPitchDiscriminationDiscipline()
        let original = makePitchDiscriminationRecord(referenceNote: 60, targetNote: 67, centOffset: -8.3, isCorrect: false, interval: 7)

        let (fields, columnIndex) = try buildCSVFields(
            trainingType: "pitchDiscrimination", timestamp: original.timestamp,
            pairs: discipline.csvKeyValuePairs(for: original))

        let parsed = try #require(try discipline.parseCSVRow(fields: fields, columnIndex: columnIndex, rowNumber: 1).get() as? PitchDiscriminationRecord)

        #expect(parsed.referenceNote == original.referenceNote)
        #expect(parsed.targetNote == original.targetNote)
        #expect(parsed.centOffset == original.centOffset)
        #expect(parsed.isCorrect == original.isCorrect)
        #expect(parsed.interval == original.interval)
        #expect(parsed.tuningSystem == original.tuningSystem)
        #expect(parsed.timestamp == original.timestamp)
    }

    @Test("UnisonPitchMatching round-trip: csvKeyValuePairs then parseCSVRow produces equal record")
    func unisonPitchMatchingRoundTrip() async throws {
        let discipline = UnisonPitchMatchingDiscipline()
        let original = makePitchMatchingRecord(referenceNote: 69, targetNote: 72, initialCentOffset: 25.0, userCentError: 3.2, interval: 0)

        let (fields, columnIndex) = try buildCSVFields(
            trainingType: "pitchMatching", timestamp: original.timestamp,
            pairs: discipline.csvKeyValuePairs(for: original))

        let parsed = try #require(try discipline.parseCSVRow(fields: fields, columnIndex: columnIndex, rowNumber: 1).get() as? PitchMatchingRecord)

        #expect(parsed.referenceNote == original.referenceNote)
        #expect(parsed.targetNote == original.targetNote)
        #expect(parsed.initialCentOffset == original.initialCentOffset)
        #expect(parsed.userCentError == original.userCentError)
        #expect(parsed.interval == original.interval)
        #expect(parsed.tuningSystem == original.tuningSystem)
        #expect(parsed.timestamp == original.timestamp)
    }

    @Test("IntervalPitchMatching round-trip: csvKeyValuePairs then parseCSVRow produces equal record")
    func intervalPitchMatchingRoundTrip() async throws {
        let discipline = IntervalPitchMatchingDiscipline()
        let original = makePitchMatchingRecord(referenceNote: 60, targetNote: 67, initialCentOffset: -12.0, userCentError: 1.5, interval: 7)

        let (fields, columnIndex) = try buildCSVFields(
            trainingType: "pitchMatching", timestamp: original.timestamp,
            pairs: discipline.csvKeyValuePairs(for: original))

        let parsed = try #require(try discipline.parseCSVRow(fields: fields, columnIndex: columnIndex, rowNumber: 1).get() as? PitchMatchingRecord)

        #expect(parsed.referenceNote == original.referenceNote)
        #expect(parsed.targetNote == original.targetNote)
        #expect(parsed.initialCentOffset == original.initialCentOffset)
        #expect(parsed.userCentError == original.userCentError)
        #expect(parsed.interval == original.interval)
        #expect(parsed.tuningSystem == original.tuningSystem)
        #expect(parsed.timestamp == original.timestamp)
    }

    @Test("TimingOffsetDetection round-trip: csvKeyValuePairs then parseCSVRow produces equal record")
    func timingOffsetDetectionRoundTrip() async throws {
        let discipline = TimingOffsetDetectionDiscipline()
        let original = makeTimingOffsetDetectionRecord(tempoBPM: 120, offsetMs: -5.3, isCorrect: true)

        let (fields, columnIndex) = try buildCSVFields(
            trainingType: "rhythmOffsetDetection", timestamp: original.timestamp,
            pairs: discipline.csvKeyValuePairs(for: original))

        let parsed = try #require(try discipline.parseCSVRow(fields: fields, columnIndex: columnIndex, rowNumber: 1).get() as? TimingOffsetDetectionRecord)

        #expect(parsed.tempoBPM == original.tempoBPM)
        #expect(parsed.offsetMs == original.offsetMs)
        #expect(parsed.isCorrect == original.isCorrect)
        #expect(parsed.timestamp == original.timestamp)
    }

    @Test("ContinuousRhythmMatching round-trip: csvKeyValuePairs then parseCSVRow produces equal record")
    func continuousRhythmMatchingRoundTrip() async throws {
        let discipline = ContinuousRhythmMatchingDiscipline()
        let original = makeContinuousRhythmMatchingRecord(tempoBPM: 90, meanOffsetMs: 7.2, position0: 5.0, position1: 10.0, position2: nil, position3: nil)

        let (fields, columnIndex) = try buildCSVFields(
            trainingType: "continuousRhythmMatching", timestamp: original.timestamp,
            pairs: discipline.csvKeyValuePairs(for: original))

        let parsed = try #require(try discipline.parseCSVRow(fields: fields, columnIndex: columnIndex, rowNumber: 1).get() as? ContinuousRhythmMatchingRecord)

        #expect(parsed.tempoBPM == original.tempoBPM)
        #expect(parsed.meanOffsetMs == original.meanOffsetMs)
        #expect(parsed.meanOffsetMsPosition0 == original.meanOffsetMsPosition0)
        #expect(parsed.meanOffsetMsPosition1 == original.meanOffsetMsPosition1)
        #expect(parsed.meanOffsetMsPosition2 == original.meanOffsetMsPosition2)
        #expect(parsed.meanOffsetMsPosition3 == original.meanOffsetMsPosition3)
        #expect(parsed.timestamp == original.timestamp)
    }

    // MARK: - Task 1.4: mergeImportRecords skips duplicates, imports non-duplicates

    @Test("UnisonPitchDiscrimination mergeImportRecords skips duplicates and imports new records")
    func unisonPitchDiscriminationMergeDuplicates() async throws {
        let store = try makeStore()
        let discipline = UnisonPitchDiscriminationDiscipline()

        let existing = makePitchDiscriminationRecord(referenceNote: 60, targetNote: 64, interval: 0, minutesOffset: 0)
        try store.save(existing)

        let duplicate = makePitchDiscriminationRecord(referenceNote: 60, targetNote: 64, interval: 0, minutesOffset: 0)
        let newRecord = makePitchDiscriminationRecord(referenceNote: 60, targetNote: 64, interval: 0, minutesOffset: 5)

        let importResult = makeImportResult(pitchDiscriminations: [duplicate, newRecord])

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

        let unisonRecord = makePitchDiscriminationRecord(interval: 0, minutesOffset: 0)
        let intervalRecord = makePitchDiscriminationRecord(interval: 7, minutesOffset: 1)

        let importResult = makeImportResult(pitchDiscriminations: [unisonRecord, intervalRecord])

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

        let existing = makePitchMatchingRecord(referenceNote: 69, targetNote: 72, interval: 0, minutesOffset: 0)
        try store.save(existing)

        let duplicate = makePitchMatchingRecord(referenceNote: 69, targetNote: 72, interval: 0, minutesOffset: 0)
        let newRecord = makePitchMatchingRecord(referenceNote: 69, targetNote: 72, interval: 0, minutesOffset: 5)

        let importResult = makeImportResult(pitchMatchings: [duplicate, newRecord])

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

        let existing = makePitchMatchingRecord(referenceNote: 60, targetNote: 67, interval: 7, minutesOffset: 0)
        try store.save(existing)

        let unisonRecord = makePitchMatchingRecord(interval: 0, minutesOffset: 1)
        let duplicate = makePitchMatchingRecord(referenceNote: 60, targetNote: 67, interval: 7, minutesOffset: 0)
        let newRecord = makePitchMatchingRecord(referenceNote: 60, targetNote: 67, interval: 7, minutesOffset: 5)

        let importResult = makeImportResult(pitchMatchings: [unisonRecord, duplicate, newRecord])

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

        let existing = makeTimingOffsetDetectionRecord(tempoBPM: 100, minutesOffset: 0)
        try store.save(existing)

        let duplicate = makeTimingOffsetDetectionRecord(tempoBPM: 100, minutesOffset: 0)
        let newRecord = makeTimingOffsetDetectionRecord(tempoBPM: 100, minutesOffset: 5)

        let importResult = makeImportResult(timingOffsetDetections: [duplicate, newRecord])

        var mergeResult: (imported: Int, skipped: Int) = (0, 0)
        try store.withinTransaction { scope in
            mergeResult = try discipline.mergeImportRecords(from: importResult, existingIn: store, into: scope)
        }

        #expect(mergeResult.imported == 1)
        #expect(mergeResult.skipped == 1)
    }

    @Test("ContinuousRhythmMatching mergeImportRecords skips duplicates and imports new records")
    func continuousRhythmMatchingMergeDuplicates() async throws {
        let store = try makeStore()
        let discipline = ContinuousRhythmMatchingDiscipline()

        let existing = makeContinuousRhythmMatchingRecord(tempoBPM: 100, minutesOffset: 0)
        try store.save(existing)

        let duplicate = makeContinuousRhythmMatchingRecord(tempoBPM: 100, minutesOffset: 0)
        let newRecord = makeContinuousRhythmMatchingRecord(tempoBPM: 100, minutesOffset: 5)

        let importResult = makeImportResult(continuousRhythmMatchings: [duplicate, newRecord])

        var mergeResult: (imported: Int, skipped: Int) = (0, 0)
        try store.withinTransaction { scope in
            mergeResult = try discipline.mergeImportRecords(from: importResult, existingIn: store, into: scope)
        }

        #expect(mergeResult.imported == 1)
        #expect(mergeResult.skipped == 1)
    }

    // MARK: - Task 1.5: fetchExportRecords filtering

    @Test("UnisonPitchDiscrimination fetchExportRecords returns only interval==0 records")
    func unisonPitchDiscriminationFetchFiltering() async throws {
        let store = try makeStore()
        let discipline = UnisonPitchDiscriminationDiscipline()

        try store.save(makePitchDiscriminationRecord(interval: 0, minutesOffset: 0))
        try store.save(makePitchDiscriminationRecord(interval: 7, minutesOffset: 1))
        try store.save(makePitchDiscriminationRecord(interval: 0, minutesOffset: 2))

        let records = try discipline.fetchExportRecords(from: store)
        #expect(records.count == 2)
    }

    @Test("IntervalPitchDiscrimination fetchExportRecords returns only interval!=0 records")
    func intervalPitchDiscriminationFetchFiltering() async throws {
        let store = try makeStore()
        let discipline = IntervalPitchDiscriminationDiscipline()

        try store.save(makePitchDiscriminationRecord(interval: 0, minutesOffset: 0))
        try store.save(makePitchDiscriminationRecord(interval: 7, minutesOffset: 1))
        try store.save(makePitchDiscriminationRecord(interval: 4, minutesOffset: 2))

        let records = try discipline.fetchExportRecords(from: store)
        #expect(records.count == 2)
    }

    @Test("UnisonPitchMatching fetchExportRecords returns only interval==0 records")
    func unisonPitchMatchingFetchFiltering() async throws {
        let store = try makeStore()
        let discipline = UnisonPitchMatchingDiscipline()

        try store.save(makePitchMatchingRecord(interval: 0, minutesOffset: 0))
        try store.save(makePitchMatchingRecord(interval: 3, minutesOffset: 1))

        let records = try discipline.fetchExportRecords(from: store)
        #expect(records.count == 1)
    }

    @Test("IntervalPitchMatching fetchExportRecords returns only interval!=0 records")
    func intervalPitchMatchingFetchFiltering() async throws {
        let store = try makeStore()
        let discipline = IntervalPitchMatchingDiscipline()

        try store.save(makePitchMatchingRecord(interval: 0, minutesOffset: 0))
        try store.save(makePitchMatchingRecord(interval: 3, minutesOffset: 1))
        try store.save(makePitchMatchingRecord(interval: 5, minutesOffset: 2))

        let records = try discipline.fetchExportRecords(from: store)
        #expect(records.count == 2)
    }

    @Test("TimingOffsetDetection fetchExportRecords returns all records")
    func timingOffsetDetectionFetchAll() async throws {
        let store = try makeStore()
        let discipline = TimingOffsetDetectionDiscipline()

        try store.save(makeTimingOffsetDetectionRecord(minutesOffset: 0))
        try store.save(makeTimingOffsetDetectionRecord(minutesOffset: 1))

        let records = try discipline.fetchExportRecords(from: store)
        #expect(records.count == 2)
    }

    @Test("ContinuousRhythmMatching fetchExportRecords returns all records")
    func continuousRhythmMatchingFetchAll() async throws {
        let store = try makeStore()
        let discipline = ContinuousRhythmMatchingDiscipline()

        try store.save(makeContinuousRhythmMatchingRecord(minutesOffset: 0))
        try store.save(makeContinuousRhythmMatchingRecord(minutesOffset: 1))

        let records = try discipline.fetchExportRecords(from: store)
        #expect(records.count == 2)
    }
}
