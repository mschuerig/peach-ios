import Testing
import SwiftData
@testable import Peach

@Suite("PeachSchema")
struct PeachSchemaTests {

    @Test("SchemaV1 contains exactly 4 model types")
    func schemaV1ContainsAllModels() async {
        let models = SchemaV1.models
        #expect(models.count == 4)

        let typeNames = Set(models.map { String(describing: $0) })
        #expect(typeNames.contains(String(describing: PitchDiscriminationRecord.self)))
        #expect(typeNames.contains(String(describing: PitchMatchingRecord.self)))
        #expect(typeNames.contains(String(describing: TimingOffsetDetectionRecord.self)))
        #expect(typeNames.contains(String(describing: ContinuousRhythmMatchingRecord.self)))
    }

    @Test("PeachSchemaMigrationPlan has SchemaV1 as only schema")
    func migrationPlanContainsSchemaV1() async {
        let schemas = PeachSchemaMigrationPlan.schemas
        #expect(schemas.count == 1)
        #expect(schemas.first == SchemaV1.self)
    }

    @Test("PeachSchemaMigrationPlan has no migration stages")
    func migrationPlanHasNoStages() async {
        #expect(PeachSchemaMigrationPlan.stages.isEmpty)
    }

    @Test("round-trip: insert and fetch PitchDiscriminationRecord")
    func roundTripPitchDiscrimination() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let record = PitchDiscriminationRecord(
            referenceNote: 60,
            targetNote: 62,
            centOffset: 15.5,
            isCorrect: true,
            interval: 2,
            tuningSystem: "equalTemperament"
        )
        context.insert(record)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<PitchDiscriminationRecord>())
        #expect(fetched.count == 1)
        #expect(fetched[0].referenceNote == 60)
        #expect(fetched[0].targetNote == 62)
        #expect(fetched[0].centOffset == 15.5)
        #expect(fetched[0].isCorrect == true)
        #expect(fetched[0].interval == 2)
        #expect(fetched[0].tuningSystem == "equalTemperament")
    }

    @Test("round-trip: insert and fetch PitchMatchingRecord")
    func roundTripPitchMatching() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let record = PitchMatchingRecord(
            referenceNote: 60,
            targetNote: 67,
            initialCentOffset: 30.0,
            userCentError: 2.5,
            interval: 7,
            tuningSystem: "equalTemperament"
        )
        context.insert(record)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<PitchMatchingRecord>())
        #expect(fetched.count == 1)
        #expect(fetched[0].referenceNote == 60)
        #expect(fetched[0].targetNote == 67)
        #expect(fetched[0].initialCentOffset == 30.0)
        #expect(fetched[0].userCentError == 2.5)
    }

    @Test("round-trip: insert and fetch TimingOffsetDetectionRecord")
    func roundTripTimingOffsetDetection() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let record = TimingOffsetDetectionRecord(
            tempoBPM: 120,
            offsetMs: 25.0,
            isCorrect: false
        )
        context.insert(record)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<TimingOffsetDetectionRecord>())
        #expect(fetched.count == 1)
        #expect(fetched[0].tempoBPM == 120)
        #expect(fetched[0].offsetMs == 25.0)
        #expect(fetched[0].isCorrect == false)
    }

    @Test("round-trip: insert and fetch ContinuousRhythmMatchingRecord")
    func roundTripContinuousRhythmMatching() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let record = ContinuousRhythmMatchingRecord(
            tempoBPM: 90,
            meanOffsetMs: 12.3,
            meanOffsetMsPosition0: 10.0,
            meanOffsetMsPosition1: 11.0,
            meanOffsetMsPosition2: 13.0,
            meanOffsetMsPosition3: 15.0
        )
        context.insert(record)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<ContinuousRhythmMatchingRecord>())
        #expect(fetched.count == 1)
        #expect(fetched[0].tempoBPM == 90)
        #expect(fetched[0].meanOffsetMs == 12.3)
        #expect(fetched[0].meanOffsetMsPosition0 == 10.0)
        #expect(fetched[0].meanOffsetMsPosition1 == 11.0)
        #expect(fetched[0].meanOffsetMsPosition2 == 13.0)
        #expect(fetched[0].meanOffsetMsPosition3 == 15.0)
    }

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let schema = Schema(versionedSchema: SchemaV1.self)
        return try ModelContainer(
            for: schema,
            migrationPlan: PeachSchemaMigrationPlan.self,
            configurations: config
        )
    }
}
