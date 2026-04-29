import Testing
import Foundation
import SwiftData
@testable import Peach

/// Direct unit tests for the four helpers that bridge the
/// `any TrainingDiscipline` existential boundary added by Story 77.8:
/// ``TrainingDiscipline/parseCSVRowErased(fields:columnIndex:rowNumber:)``,
/// ``TrainingDiscipline/csvRows(from:)``,
/// ``TrainingDiscipline/parsedRecordEnvelopes(from:)``, and
/// ``TrainingDisciplinePayloads/typedEntries(from:forTrainingType:ofType:)``.
@Suite("TrainingDiscipline existential helpers")
struct TrainingDisciplineExistentialHelpersTests {

    // MARK: - Fixtures

    private func makeImportResult(
        _ payloads: [String: [(timestamp: Date, payload: any TrainingDisciplinePayload)]]
    ) -> CSVImportParser.ImportResult {
        CSVImportParser.ImportResult(payloads: payloads, errors: [])
    }

    private func pitchPayload(centOffset: Double = 5.0, interval: Int = 0) -> PitchDiscriminationPayload {
        PitchDiscriminationPayload(
            referenceNote: 60,
            targetNote: 64,
            centOffset: centOffset,
            isCorrect: true,
            interval: interval,
            tuningSystem: "equalTemperament"
        )
    }

    private func makeInMemoryStore() throws -> TrainingDataStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TrainingRecord.self, configurations: config)
        return TrainingDataStore(modelContext: ModelContext(container))
    }

    // MARK: - typedEntries

    @Test("typedEntries returns typed pairs for matching trainingType + Payload")
    func typedEntriesHappyPath() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let payload = pitchPayload()
        let result = makeImportResult([
            "pitchDiscrimination": [(date, payload as any TrainingDisciplinePayload)]
        ])

        let entries = TrainingDisciplinePayloads.typedEntries(
            from: result, forTrainingType: "pitchDiscrimination", ofType: PitchDiscriminationPayload.self)

        #expect(entries.count == 1)
        #expect(entries.first?.timestamp == date)
        #expect(entries.first?.payload.centOffset == 5.0)
    }

    @Test("typedEntries returns empty when trainingType is absent from payload map")
    func typedEntriesAbsentKey() {
        let result = makeImportResult([:])

        let entries = TrainingDisciplinePayloads.typedEntries(
            from: result, forTrainingType: "pitchDiscrimination", ofType: PitchDiscriminationPayload.self)

        #expect(entries.isEmpty)
    }

    @Test("typedEntries preserves entry order")
    func typedEntriesPreservesOrder() {
        let dates = (0..<3).map { Date(timeIntervalSinceReferenceDate: Double($0) * 60) }
        let payloads = (0..<3).map { pitchPayload(centOffset: Double($0)) }
        let result = makeImportResult([
            "pitchDiscrimination": zip(dates, payloads).map { ($0, $1 as any TrainingDisciplinePayload) }
        ])

        let entries = TrainingDisciplinePayloads.typedEntries(
            from: result, forTrainingType: "pitchDiscrimination", ofType: PitchDiscriminationPayload.self)

        #expect(entries.map(\.payload.centOffset) == [0.0, 1.0, 2.0])
    }

    // MARK: - parseCSVRowErased

    @Test("parseCSVRowErased upcasts the discipline's typed result into the existential")
    func parseCSVRowErasedHappyPath() throws {
        let discipline = UnisonPitchDiscriminationDiscipline()
        let timestamp = Date(timeIntervalSinceReferenceDate: 12_345)
        let pairs = discipline.csvKeyValuePairs(for: pitchPayload(centOffset: 7.5, interval: 0))
        let (fields, columnIndex) = try buildCSVFields(
            trainingType: discipline.csvTrainingType, timestamp: timestamp, pairs: pairs)

        let erased = discipline.parseCSVRowErased(fields: fields, columnIndex: columnIndex, rowNumber: 1)
        let value = try erased.get()

        let typed = try #require(value.payload as? PitchDiscriminationPayload)
        #expect(typed.centOffset == 7.5)
    }

    @Test("parseCSVRowErased propagates the discipline's failure result unchanged")
    func parseCSVRowErasedFailurePath() {
        let discipline = UnisonPitchDiscriminationDiscipline()
        // Empty fields → parser cannot find required columns
        let result = discipline.parseCSVRowErased(fields: [], columnIndex: [:], rowNumber: 7)

        switch result {
        case .success:
            Issue.record("expected failure on empty fields")
        case .failure:
            break // any CSVImportError is fine; we're verifying the failure path is preserved
        }
    }

    // MARK: - csvRows

    @Test("csvRows pairs each fetched payload with its csvKeyValuePairs row in fetch order")
    func csvRowsHappyPath() throws {
        let store = try makeInMemoryStore()
        let discipline = UnisonPitchDiscriminationDiscipline()

        let p1 = pitchPayload(centOffset: 1.0, interval: 0)
        let p2 = pitchPayload(centOffset: 2.0, interval: 0)
        let t1 = Date(timeIntervalSinceReferenceDate: 0)
        let t2 = Date(timeIntervalSinceReferenceDate: 60)
        try store.save(JSONEnvelope.encode(p1, timestamp: t1))
        try store.save(JSONEnvelope.encode(p2, timestamp: t2))

        let rows = try discipline.csvRows(from: store)

        #expect(rows.count == 2)
        // Ascending timestamp order is the discipline's fetchExportRecords contract.
        #expect(rows[0].timestamp == t1)
        #expect(rows[1].timestamp == t2)
        #expect(Dictionary(uniqueKeysWithValues: rows[0].pairs)
                == Dictionary(uniqueKeysWithValues: discipline.csvKeyValuePairs(for: p1)))
        #expect(Dictionary(uniqueKeysWithValues: rows[1].pairs)
                == Dictionary(uniqueKeysWithValues: discipline.csvKeyValuePairs(for: p2)))
    }

    @Test("csvRows returns empty when the store has no exportable records")
    func csvRowsEmpty() throws {
        let store = try makeInMemoryStore()
        let discipline = UnisonPitchDiscriminationDiscipline()

        let rows = try discipline.csvRows(from: store)

        #expect(rows.isEmpty)
    }

    // MARK: - parsedRecordEnvelopes

    @Test("parsedRecordEnvelopes encodes one envelope per parsed record, in order")
    func parsedRecordEnvelopesHappyPath() throws {
        let discipline = UnisonPitchDiscriminationDiscipline()
        let dates = (0..<3).map { Date(timeIntervalSinceReferenceDate: Double($0) * 60) }
        let payloads = (0..<3).map { pitchPayload(centOffset: Double($0), interval: 0) }
        let result = makeImportResult([
            "pitchDiscrimination": zip(dates, payloads).map { ($0, $1 as any TrainingDisciplinePayload) }
        ])

        let envelopes = try discipline.parsedRecordEnvelopes(from: result)

        #expect(envelopes.count == 3)
        #expect(envelopes.map(\.timestamp) == dates)
        for env in envelopes {
            #expect(env.disciplineIdentifier == PitchDiscriminationPayload.disciplineIdentifier)
        }
    }

    @Test("parsedRecordEnvelopes returns empty for a discipline with no parsed entries")
    func parsedRecordEnvelopesEmpty() throws {
        let discipline = UnisonPitchDiscriminationDiscipline()
        let envelopes = try discipline.parsedRecordEnvelopes(from: makeImportResult([:]))
        #expect(envelopes.isEmpty)
    }
}

