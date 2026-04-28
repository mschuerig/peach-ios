import Testing
import SwiftData
import Foundation
@testable import Peach

@Suite("PeachSchema")
struct PeachSchemaTests {

    @Test("SchemaV1 contains exactly one envelope model type")
    func schemaV1ContainsEnvelope() async {
        let models = SchemaV1.models
        #expect(models.count == 1)
        #expect(String(describing: models[0]) == String(describing: TrainingRecord.self))
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

    @Test("Round-trip: insert and fetch envelope through schema")
    func roundTripEnvelope() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let payload = PitchDiscriminationPayload(
            referenceNote: 60,
            targetNote: 62,
            centOffset: 15.5,
            isCorrect: true,
            interval: 2,
            tuningSystem: "equalTemperament"
        )
        let envelope = try JSONEnvelope.encode(payload, timestamp: Date())
        context.insert(envelope)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<TrainingRecord>())
        #expect(fetched.count == 1)
        #expect(fetched[0].disciplineIdentifier == PitchDiscriminationPayload.disciplineIdentifier)

        let decoded = try JSONEnvelope.decode(PitchDiscriminationPayload.self, from: fetched[0])
        #expect(decoded == payload)
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
