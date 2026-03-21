import Testing
import SwiftData
import Foundation
@testable import Peach

@Suite("TrainingDataExporter Tests")
struct TrainingDataExporterTests {

    // MARK: - Test Helpers

    private func makeTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: PitchDiscriminationRecord.self, PitchMatchingRecord.self, RhythmOffsetDetectionRecord.self, RhythmMatchingRecord.self, configurations: config)
    }

    private func fixedDate(minutesOffset: Double = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = DateComponents(year: 2026, month: 3, day: 4, hour: 10, minute: 0, second: 0)
        let base = calendar.date(from: components)!
        return base.addingTimeInterval(minutesOffset * 60)
    }

    private func makeStore() throws -> TrainingDataStore {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        return TrainingDataStore(modelContext: context)
    }

    // MARK: - Mixed Record Tests

    @Test("export with mixed comparison and pitch matching records produces correctly sorted CSV")
    func exportMixedRecords() async throws {
        let store = try makeStore()

        let comparison = PitchDiscriminationRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 1)
        )
        let pitchMatching = PitchMatchingRecord(
            referenceNote: 69, targetNote: 72, initialCentOffset: 25.0, userCentError: 3.2,
            interval: 3, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 0)
        )
        try store.save(comparison)
        try store.save(pitchMatching)

        let csv = try TrainingDataExporter.export(from: store)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        #expect(lines.count == 4)
        #expect(lines[0] == CSVExportSchemaV2.metadataLine)
        #expect(lines[1] == CSVExportSchemaV2.headerRow)
        #expect(!csv.hasSuffix("\n"))

        // Verify pitch matching row (earlier timestamp — first data row)
        let pmFields = lines[2].split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        #expect(pmFields[0] == "pitchMatching")
        #expect(pmFields[2] == "69")
        #expect(pmFields[3] == "A4")
        #expect(pmFields[10] == "25.0")
        #expect(pmFields[11] == "3.2")

        // Verify comparison row (later timestamp — second data row)
        let compFields = lines[3].split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        #expect(compFields[0] == "pitchDiscrimination")
        #expect(compFields[2] == "60")
        #expect(compFields[3] == "C4")
        #expect(compFields[8] == "15.5")
        #expect(compFields[9] == "true")
    }

    // MARK: - Comparison Only Tests

    @Test("export with only comparison records")
    func exportComparisonOnly() async throws {
        let store = try makeStore()

        let record = PitchDiscriminationRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: fixedDate()
        )
        try store.save(record)

        let csv = try TrainingDataExporter.export(from: store)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        #expect(lines.count == 3)
        #expect(lines[0] == CSVExportSchemaV2.metadataLine)
        #expect(lines[1] == CSVExportSchemaV2.headerRow)
        #expect(lines[2].hasPrefix("pitchDiscrimination"))
    }

    // MARK: - Pitch Matching Only Tests

    @Test("export with only pitch matching records")
    func exportPitchMatchingOnly() async throws {
        let store = try makeStore()

        let record = PitchMatchingRecord(
            referenceNote: 69, targetNote: 72, initialCentOffset: 25.0, userCentError: 3.2,
            interval: 3, tuningSystem: "equalTemperament", timestamp: fixedDate()
        )
        try store.save(record)

        let csv = try TrainingDataExporter.export(from: store)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        #expect(lines.count == 3)
        #expect(lines[0] == CSVExportSchemaV2.metadataLine)
        #expect(lines[1] == CSVExportSchemaV2.headerRow)
        #expect(lines[2].hasPrefix("pitchMatching"))
    }

    // MARK: - Empty Store Tests

    @Test("export with no records returns metadata line and header row")
    func exportEmptyStore() async throws {
        let store = try makeStore()

        let csv = try TrainingDataExporter.export(from: store)

        #expect(csv == CSVExportSchemaV2.metadataLine + "\n" + CSVExportSchemaV2.headerRow)
    }

    // MARK: - Timestamp Ordering Tests

    @Test("timestamp ordering across mixed record types")
    func timestampOrdering() async throws {
        let store = try makeStore()

        let pm1 = PitchMatchingRecord(
            referenceNote: 60, targetNote: 60, initialCentOffset: 10.0, userCentError: 1.0,
            interval: 0, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 0)
        )
        let comp1 = PitchDiscriminationRecord(
            referenceNote: 60, targetNote: 62, centOffset: 5.0, isCorrect: true,
            interval: 2, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 1)
        )
        let pm2 = PitchMatchingRecord(
            referenceNote: 64, targetNote: 64, initialCentOffset: 20.0, userCentError: -2.0,
            interval: 0, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 2)
        )
        let comp2 = PitchDiscriminationRecord(
            referenceNote: 67, targetNote: 72, centOffset: -10.0, isCorrect: false,
            interval: 5, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 3)
        )

        try store.save(pm1)
        try store.save(comp1)
        try store.save(pm2)
        try store.save(comp2)

        let csv = try TrainingDataExporter.export(from: store)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        #expect(lines.count == 6)
        #expect(lines[2].hasPrefix("pitchMatching"))
        #expect(lines[3].hasPrefix("pitchDiscrimination"))
        #expect(lines[4].hasPrefix("pitchMatching"))
        #expect(lines[5].hasPrefix("pitchDiscrimination"))
    }

    // MARK: - Stable Sort Tests

    @Test("records with same timestamp maintain stable insertion order")
    func sameTimestampStableOrder() async throws {
        let store = try makeStore()

        let timestamp = fixedDate()
        let comparison = PitchDiscriminationRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: timestamp
        )
        let pitchMatching = PitchMatchingRecord(
            referenceNote: 69, targetNote: 72, initialCentOffset: 25.0, userCentError: 3.2,
            interval: 3, tuningSystem: "equalTemperament", timestamp: timestamp
        )
        try store.save(comparison)
        try store.save(pitchMatching)

        let csv = try TrainingDataExporter.export(from: store)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        #expect(lines.count == 4)
        #expect(lines[2].hasPrefix("pitchDiscrimination"))
        #expect(lines[3].hasPrefix("pitchMatching"))
    }

    // MARK: - Header Row Tests

    @Test("CSV output starts with metadata line followed by header row")
    func csvStartsWithMetadataAndHeader() async throws {
        let store = try makeStore()

        let record = PitchDiscriminationRecord(
            referenceNote: 60, targetNote: 60, centOffset: 0.0, isCorrect: true,
            interval: 0, tuningSystem: "equalTemperament", timestamp: fixedDate()
        )
        try store.save(record)

        let csv = try TrainingDataExporter.export(from: store)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        #expect(!lines.isEmpty)
        #expect(lines[0] == CSVExportSchemaV2.metadataLine)
        #expect(lines[1] == CSVExportSchemaV2.headerRow)
    }

    // MARK: - Row Count Tests

    @Test("row count equals record count plus metadata and header")
    func rowCountEqualsRecordsPlusMetadataAndHeader() async throws {
        let store = try makeStore()

        let comp = PitchDiscriminationRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 0)
        )
        let pm1 = PitchMatchingRecord(
            referenceNote: 69, targetNote: 72, initialCentOffset: 25.0, userCentError: 3.2,
            interval: 3, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 1)
        )
        let pm2 = PitchMatchingRecord(
            referenceNote: 60, targetNote: 60, initialCentOffset: 10.0, userCentError: -1.5,
            interval: 0, tuningSystem: "justIntonation", timestamp: fixedDate(minutesOffset: 2)
        )

        try store.save(comp)
        try store.save(pm1)
        try store.save(pm2)

        let csv = try TrainingDataExporter.export(from: store)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        #expect(lines.count == 5)
    }

    // MARK: - Rhythm Record Tests

    @Test("export with rhythm offset detection records produces correct CSV")
    func exportRhythmOffsetDetection() async throws {
        let store = try makeStore()

        let record = RhythmOffsetDetectionRecord(
            tempoBPM: 120, offsetMs: -15.3, isCorrect: true, timestamp: fixedDate()
        )
        try store.save(record)

        let csv = try TrainingDataExporter.export(from: store)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        #expect(lines.count == 3)
        #expect(lines[0] == CSVExportSchemaV2.metadataLine)
        #expect(lines[1] == CSVExportSchemaV2.headerRow)
        #expect(lines[2].hasPrefix("rhythmOffsetDetection"))

        let fields = lines[2].split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        #expect(fields[12] == "120")
        #expect(fields[13] == "-15.3")
    }

    @Test("export with rhythm matching records produces correct CSV")
    func exportRhythmMatching() async throws {
        let store = try makeStore()

        let record = RhythmMatchingRecord(
            tempoBPM: 100, userOffsetMs: -8.5, timestamp: fixedDate()
        )
        try store.save(record)

        let csv = try TrainingDataExporter.export(from: store)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        #expect(lines.count == 3)
        #expect(lines[0] == CSVExportSchemaV2.metadataLine)
        #expect(lines[1] == CSVExportSchemaV2.headerRow)
        #expect(lines[2].hasPrefix("rhythmMatching"))

        let fields = lines[2].split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        #expect(fields[12] == "100")
        #expect(fields[14] == "-8.5")
    }

    @Test("export with all four record types produces correctly sorted CSV")
    func exportAllFourTypes() async throws {
        let store = try makeStore()

        let rhythmMatch = RhythmMatchingRecord(
            tempoBPM: 100, userOffsetMs: 5.0, timestamp: fixedDate(minutesOffset: 0)
        )
        let pitchDisc = PitchDiscriminationRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 1)
        )
        let rhythmOffset = RhythmOffsetDetectionRecord(
            tempoBPM: 120, offsetMs: -10.0, isCorrect: false, timestamp: fixedDate(minutesOffset: 2)
        )
        let pitchMatch = PitchMatchingRecord(
            referenceNote: 69, targetNote: 72, initialCentOffset: 25.0, userCentError: 3.2,
            interval: 3, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 3)
        )

        try store.save(rhythmMatch)
        try store.save(pitchDisc)
        try store.save(rhythmOffset)
        try store.save(pitchMatch)

        let csv = try TrainingDataExporter.export(from: store)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        #expect(lines.count == 6)
        #expect(lines[0] == CSVExportSchemaV2.metadataLine)
        #expect(lines[1] == CSVExportSchemaV2.headerRow)
        #expect(lines[2].hasPrefix("rhythmMatching"))
        #expect(lines[3].hasPrefix("pitchDiscrimination"))
        #expect(lines[4].hasPrefix("rhythmOffsetDetection"))
        #expect(lines[5].hasPrefix("pitchMatching"))
    }

    // MARK: - Round-Trip Test

    @Test("V2 export is importable by V2 parser")
    func v2ExportImportableByV2Parser() async throws {
        let store = try makeStore()

        let comparison = PitchDiscriminationRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 0)
        )
        try store.save(comparison)

        let csv = try TrainingDataExporter.export(from: store)
        let result = CSVImportParser.parse(csv)

        #expect(result.errors.isEmpty)
        #expect(result.pitchDiscriminations.count == 1)
    }

    // MARK: - V2 Comprehensive Tests

    @Test("V2 header contains all 15 columns")
    func v2HeaderInExport() async throws {
        let store = try makeStore()

        let record = RhythmOffsetDetectionRecord(
            tempoBPM: 120, offsetMs: 5.0, isCorrect: true, timestamp: fixedDate()
        )
        try store.save(record)

        let csv = try TrainingDataExporter.export(from: store)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let columns = lines[1].split(separator: ",").map(String.init)

        #expect(columns.count == 15)
        #expect(columns[12] == "tempoBPM")
        #expect(columns[13] == "offsetMs")
        #expect(columns[14] == "userOffsetMs")
    }

    @Test("rhythm-only export contains no pitch data")
    func rhythmOnlyExport() async throws {
        let store = try makeStore()

        let offset = RhythmOffsetDetectionRecord(
            tempoBPM: 120, offsetMs: -5.0, isCorrect: true, timestamp: fixedDate(minutesOffset: 0)
        )
        let matching = RhythmMatchingRecord(
            tempoBPM: 90, userOffsetMs: 3.2, timestamp: fixedDate(minutesOffset: 1)
        )
        try store.save(offset)
        try store.save(matching)

        let csv = try TrainingDataExporter.export(from: store)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        #expect(lines.count == 4)
        #expect(lines[2].hasPrefix("rhythmOffsetDetection"))
        #expect(lines[3].hasPrefix("rhythmMatching"))

        // Verify pitch columns are empty in rhythm rows
        let offsetFields = lines[2].split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        #expect(offsetFields[2] == "") // referenceNote
        #expect(offsetFields[6] == "") // interval
        #expect(offsetFields[8] == "") // centOffset

        let matchFields = lines[3].split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        #expect(matchFields[2] == "") // referenceNote
        #expect(matchFields[9] == "") // isCorrect
    }

    @Test("empty export with no records produces V2 metadata and header only")
    func emptyExportV2() async throws {
        let store = try makeStore()

        let csv = try TrainingDataExporter.export(from: store)

        #expect(csv == CSVExportSchemaV2.metadataLine + "\n" + CSVExportSchemaV2.headerRow)
    }

    @Test("all rows have exactly 15 fields matching V2 column count")
    func allRowsHave15Fields() async throws {
        let store = try makeStore()

        let pitchDisc = PitchDiscriminationRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 0)
        )
        let pitchMatch = PitchMatchingRecord(
            referenceNote: 69, targetNote: 72, initialCentOffset: 25.0, userCentError: 3.2,
            interval: 3, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 1)
        )
        let rhythmOffset = RhythmOffsetDetectionRecord(
            tempoBPM: 120, offsetMs: -10.0, isCorrect: false, timestamp: fixedDate(minutesOffset: 2)
        )
        let rhythmMatch = RhythmMatchingRecord(
            tempoBPM: 100, userOffsetMs: 5.0, timestamp: fixedDate(minutesOffset: 3)
        )

        try store.save(pitchDisc)
        try store.save(pitchMatch)
        try store.save(rhythmOffset)
        try store.save(rhythmMatch)

        let csv = try TrainingDataExporter.export(from: store)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        // Skip metadata and header, check all data rows
        for i in 2..<lines.count {
            let fields = lines[i].split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            #expect(fields.count == 15, "Row \(i) has \(fields.count) fields, expected 15")
        }
    }

    @Test("discriminator column contains correct training type for each record type")
    func discriminatorColumnCorrectness() async throws {
        let store = try makeStore()

        let pitchDisc = PitchDiscriminationRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 0)
        )
        let pitchMatch = PitchMatchingRecord(
            referenceNote: 69, targetNote: 72, initialCentOffset: 25.0, userCentError: 3.2,
            interval: 3, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 1)
        )
        let rhythmOffset = RhythmOffsetDetectionRecord(
            tempoBPM: 120, offsetMs: -10.0, isCorrect: false, timestamp: fixedDate(minutesOffset: 2)
        )
        let rhythmMatch = RhythmMatchingRecord(
            tempoBPM: 100, userOffsetMs: 5.0, timestamp: fixedDate(minutesOffset: 3)
        )

        try store.save(pitchDisc)
        try store.save(pitchMatch)
        try store.save(rhythmOffset)
        try store.save(rhythmMatch)

        let csv = try TrainingDataExporter.export(from: store)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        let discriminators = (2..<lines.count).map { i in
            lines[i].split(separator: ",", omittingEmptySubsequences: false).map(String.init)[0]
        }

        #expect(discriminators.contains("pitchDiscrimination"))
        #expect(discriminators.contains("pitchMatching"))
        #expect(discriminators.contains("rhythmOffsetDetection"))
        #expect(discriminators.contains("rhythmMatching"))
    }
}
