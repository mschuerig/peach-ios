import Testing
import Foundation
@testable import Peach

@Suite("CSVFormatMigration")
struct CSVFormatMigrationTests {

    // MARK: - V1 to V2 Migration

    @Test("V1ToV2Migration maps pitchComparison to pitchDiscrimination")
    func v1ToV2RenamesTrainingType() async {
        let migration = V1ToV2Migration()
        let rows: [[String: String]] = [
            ["trainingType": "pitchComparison", "timestamp": "2026-03-03T14:30:00Z",
             "referenceNote": "60", "referenceNoteName": "C4", "targetNote": "64",
             "targetNoteName": "E4", "interval": "M3", "tuningSystem": "equalTemperament",
             "centOffset": "15.5", "isCorrect": "true", "initialCentOffset": "",
             "userCentError": ""],
        ]

        let migrated = migration.migrate(rows: rows)
        #expect(migrated.count == 1)
        #expect(migrated[0]["trainingType"] == "pitchDiscrimination")
    }

    @Test("V1ToV2Migration preserves pitchMatching training type unchanged")
    func v1ToV2PreservesPitchMatching() async {
        let migration = V1ToV2Migration()
        let rows: [[String: String]] = [
            ["trainingType": "pitchMatching", "timestamp": "2026-03-03T14:30:00Z",
             "referenceNote": "60", "referenceNoteName": "C4", "targetNote": "67",
             "targetNoteName": "G4", "interval": "P5", "tuningSystem": "equalTemperament",
             "centOffset": "", "isCorrect": "", "initialCentOffset": "25.0",
             "userCentError": "3.2"],
        ]

        let migrated = migration.migrate(rows: rows)
        #expect(migrated[0]["trainingType"] == "pitchMatching")
    }

    @Test("V1ToV2Migration adds empty rhythm columns")
    func v1ToV2AddsRhythmColumns() async {
        let migration = V1ToV2Migration()
        let rows: [[String: String]] = [
            ["trainingType": "pitchComparison", "timestamp": "2026-03-03T14:30:00Z",
             "referenceNote": "60", "referenceNoteName": "C4", "targetNote": "64",
             "targetNoteName": "E4", "interval": "M3", "tuningSystem": "equalTemperament",
             "centOffset": "15.5", "isCorrect": "true", "initialCentOffset": "",
             "userCentError": ""],
        ]

        let migrated = migration.migrate(rows: rows)
        #expect(migrated[0]["tempoBPM"] == "")
        #expect(migrated[0]["offsetMs"] == "")
        #expect(migrated[0]["userOffsetMs"] == "")
    }

    @Test("V1ToV2Migration has correct source and target versions")
    func v1ToV2Versions() async {
        let migration = V1ToV2Migration()
        #expect(migration.sourceVersion == 1)
        #expect(migration.targetVersion == 2)
    }

    // MARK: - V2 to V3 Migration

    @Test("V2ToV3Migration maps rhythmMatching to continuousRhythmMatching")
    func v2ToV3RenamesTrainingType() async {
        let migration = V2ToV3Migration()
        let rows: [[String: String]] = [
            ["trainingType": "rhythmMatching", "timestamp": "2026-03-03T14:30:00Z",
             "referenceNote": "", "referenceNoteName": "", "targetNote": "",
             "targetNoteName": "", "interval": "", "tuningSystem": "",
             "centOffset": "", "isCorrect": "", "initialCentOffset": "",
             "userCentError": "", "tempoBPM": "120", "offsetMs": "",
             "userOffsetMs": "5.3"],
        ]

        let migrated = migration.migrate(rows: rows)
        #expect(migrated[0]["trainingType"] == "continuousRhythmMatching")
    }

    @Test("V2ToV3Migration maps userOffsetMs to meanOffsetMs")
    func v2ToV3MapsUserOffsetToMeanOffset() async {
        let migration = V2ToV3Migration()
        let rows: [[String: String]] = [
            ["trainingType": "rhythmMatching", "timestamp": "2026-03-03T14:30:00Z",
             "referenceNote": "", "referenceNoteName": "", "targetNote": "",
             "targetNoteName": "", "interval": "", "tuningSystem": "",
             "centOffset": "", "isCorrect": "", "initialCentOffset": "",
             "userCentError": "", "tempoBPM": "120", "offsetMs": "",
             "userOffsetMs": "5.3"],
        ]

        let migrated = migration.migrate(rows: rows)
        #expect(migrated[0]["meanOffsetMs"] == "5.3")
        #expect(migrated[0]["meanOffsetMsPosition0"] == "")
        #expect(migrated[0]["meanOffsetMsPosition1"] == "")
        #expect(migrated[0]["meanOffsetMsPosition2"] == "")
        #expect(migrated[0]["meanOffsetMsPosition3"] == "")
        #expect(migrated[0]["userOffsetMs"] == nil)
    }

    @Test("V2ToV3Migration preserves pitch rows unchanged")
    func v2ToV3PreservesPitchRows() async {
        let migration = V2ToV3Migration()
        let rows: [[String: String]] = [
            ["trainingType": "pitchDiscrimination", "timestamp": "2026-03-03T14:30:00Z",
             "referenceNote": "60", "referenceNoteName": "C4", "targetNote": "64",
             "targetNoteName": "E4", "interval": "M3", "tuningSystem": "equalTemperament",
             "centOffset": "15.5", "isCorrect": "true", "initialCentOffset": "",
             "userCentError": "", "tempoBPM": "", "offsetMs": "",
             "userOffsetMs": ""],
        ]

        let migrated = migration.migrate(rows: rows)
        #expect(migrated[0]["trainingType"] == "pitchDiscrimination")
        #expect(migrated[0]["referenceNote"] == "60")
        #expect(migrated[0]["centOffset"] == "15.5")
        // userOffsetMs removed, new columns added as empty
        #expect(migrated[0]["meanOffsetMs"] == "")
        #expect(migrated[0]["userOffsetMs"] == nil)
    }

    @Test("V2ToV3Migration preserves rhythmOffsetDetection training type")
    func v2ToV3PreservesRhythmOffsetDetection() async {
        let migration = V2ToV3Migration()
        let rows: [[String: String]] = [
            ["trainingType": "rhythmOffsetDetection", "timestamp": "2026-03-03T14:30:00Z",
             "referenceNote": "", "referenceNoteName": "", "targetNote": "",
             "targetNoteName": "", "interval": "", "tuningSystem": "",
             "centOffset": "", "isCorrect": "true", "initialCentOffset": "",
             "userCentError": "", "tempoBPM": "120", "offsetMs": "5.3",
             "userOffsetMs": ""],
        ]

        let migrated = migration.migrate(rows: rows)
        #expect(migrated[0]["trainingType"] == "rhythmOffsetDetection")
    }

    @Test("V2ToV3Migration has correct source and target versions")
    func v2ToV3Versions() async {
        let migration = V2ToV3Migration()
        #expect(migration.sourceVersion == 2)
        #expect(migration.targetVersion == 3)
    }

    // MARK: - Migration Chain

    @Test("migration chain applies v1 through v3 sequentially")
    func chainAppliesSequentially() async {
        let rows: [[String: String]] = [
            ["trainingType": "pitchComparison", "timestamp": "2026-03-03T14:30:00Z",
             "referenceNote": "60", "referenceNoteName": "C4", "targetNote": "64",
             "targetNoteName": "E4", "interval": "M3", "tuningSystem": "equalTemperament",
             "centOffset": "15.5", "isCorrect": "true", "initialCentOffset": "",
             "userCentError": ""],
        ]

        let migrated = CSVMigrationChain.migrate(from: 1, to: 3, rows: rows)
        // V1→V2: pitchComparison→pitchDiscrimination, adds rhythm columns
        // V2→V3: removes userOffsetMs, adds meanOffsetMs + positions
        #expect(migrated[0]["trainingType"] == "pitchDiscrimination")
        #expect(migrated[0]["meanOffsetMs"] == "")
        #expect(migrated[0]["meanOffsetMsPosition0"] == "")
        #expect(migrated[0]["userOffsetMs"] == nil)
    }

    @Test("migration chain from v2 to v3 applies only one migration")
    func chainV2ToV3() async {
        let rows: [[String: String]] = [
            ["trainingType": "pitchDiscrimination", "timestamp": "2026-03-03T14:30:00Z",
             "referenceNote": "60", "referenceNoteName": "C4", "targetNote": "64",
             "targetNoteName": "E4", "interval": "M3", "tuningSystem": "equalTemperament",
             "centOffset": "15.5", "isCorrect": "true", "initialCentOffset": "",
             "userCentError": "", "tempoBPM": "", "offsetMs": "",
             "userOffsetMs": ""],
        ]

        let migrated = CSVMigrationChain.migrate(from: 2, to: 3, rows: rows)
        #expect(migrated[0]["trainingType"] == "pitchDiscrimination")
        #expect(migrated[0]["meanOffsetMs"] == "")
        #expect(migrated[0]["userOffsetMs"] == nil)
    }

    @Test("migration chain with same source and target returns rows unchanged")
    func chainNoOp() async {
        let rows: [[String: String]] = [
            ["trainingType": "pitchDiscrimination", "foo": "bar"],
        ]

        let migrated = CSVMigrationChain.migrate(from: 3, to: 3, rows: rows)
        #expect(migrated[0]["trainingType"] == "pitchDiscrimination")
        #expect(migrated[0]["foo"] == "bar")
    }

    // MARK: - Individual Migration Edge Cases

    @Test("V1ToV2Migration handles empty rows array")
    func v1ToV2EmptyRows() async {
        let migration = V1ToV2Migration()
        let migrated = migration.migrate(rows: [])
        #expect(migrated.isEmpty)
    }

    @Test("V2ToV3Migration handles empty rows array")
    func v2ToV3EmptyRows() async {
        let migration = V2ToV3Migration()
        let migrated = migration.migrate(rows: [])
        #expect(migrated.isEmpty)
    }

    @Test("V1ToV2Migration handles missing trainingType gracefully")
    func v1ToV2MissingTrainingType() async {
        let migration = V1ToV2Migration()
        let rows: [[String: String]] = [
            ["timestamp": "2026-03-03T14:30:00Z", "referenceNote": "60"],
        ]

        let migrated = migration.migrate(rows: rows)
        #expect(migrated.count == 1)
        // No trainingType key — should still add rhythm columns
        #expect(migrated[0]["tempoBPM"] == "")
    }

    @Test("V2ToV3Migration handles missing userOffsetMs gracefully")
    func v2ToV3MissingUserOffsetMs() async {
        let migration = V2ToV3Migration()
        let rows: [[String: String]] = [
            ["trainingType": "pitchDiscrimination", "timestamp": "2026-03-03T14:30:00Z"],
        ]

        let migrated = migration.migrate(rows: rows)
        #expect(migrated[0]["meanOffsetMs"] == "")
        #expect(migrated[0]["userOffsetMs"] == nil)
    }
}
