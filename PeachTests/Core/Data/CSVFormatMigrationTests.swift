import Testing
import Foundation
@testable import Peach

/// Tests the discipline-derived migration chain. There are no per-version
/// migration structs to test directly: the chain reads each registered
/// discipline's ``CSVHistory`` and derives the operations for every step.
@Suite("CSVMigrationChain")
struct CSVFormatMigrationTests {

    // MARK: - V1 → V2

    @Test("v1→v2 renames pitchComparison to pitchDiscrimination")
    func v1ToV2RenamesPitchComparison() async throws {
        let rows: [[String: String]] = [
            ["trainingType": "pitchComparison", "centOffset": "15.5", "isCorrect": "true"],
        ]
        let migrated = try #require(CSVMigrationChain.migrate(from: 1, to: 2, rows: rows))
        #expect(migrated.count == 1)
        #expect(migrated[0]["trainingType"] == "pitchDiscrimination")
    }

    @Test("v1→v2 leaves pitchMatching unchanged")
    func v1ToV2LeavesPitchMatchingUnchanged() async throws {
        let rows: [[String: String]] = [
            ["trainingType": "pitchMatching", "initialCentOffset": "25.0"],
        ]
        let migrated = try #require(CSVMigrationChain.migrate(from: 1, to: 2, rows: rows))
        #expect(migrated[0]["trainingType"] == "pitchMatching")
        #expect(migrated[0]["initialCentOffset"] == "25.0")
    }

    @Test("v1→v2 preserves discipline-specific column values")
    func v1ToV2PreservesColumnValues() async throws {
        let rows: [[String: String]] = [
            ["trainingType": "pitchComparison", "centOffset": "15.5", "referenceNote": "60"],
        ]
        let migrated = try #require(CSVMigrationChain.migrate(from: 1, to: 2, rows: rows))
        #expect(migrated[0]["centOffset"] == "15.5")
        #expect(migrated[0]["referenceNote"] == "60")
    }

    // MARK: - V2 → V3

    @Test("v2→v3 renames rhythmMatching to continuousRhythmMatching")
    func v2ToV3RenamesRhythmMatching() async throws {
        let rows: [[String: String]] = [
            ["trainingType": "rhythmMatching", "tempoBPM": "120", "userOffsetMs": "5.3"],
        ]
        let migrated = try #require(CSVMigrationChain.migrate(from: 2, to: 3, rows: rows))
        #expect(migrated[0]["trainingType"] == "continuousRhythmMatching")
    }

    @Test("v2→v3 renames userOffsetMs column to meanOffsetMs with fallback")
    func v2ToV3RenamesUserOffsetMs() async throws {
        let rows: [[String: String]] = [
            ["trainingType": "rhythmMatching", "tempoBPM": "120", "userOffsetMs": "5.3"],
        ]
        let migrated = try #require(CSVMigrationChain.migrate(from: 2, to: 3, rows: rows))
        #expect(migrated[0]["meanOffsetMs"] == "5.3")
        #expect(migrated[0]["userOffsetMs"] == nil)
    }

    @Test("v2→v3 preserves existing meanOffsetMs over userOffsetMs fallback")
    func v2ToV3PreservesExistingMeanOffsetMs() async throws {
        let rows: [[String: String]] = [
            ["trainingType": "rhythmMatching", "userOffsetMs": "5.3", "meanOffsetMs": "9.9"],
        ]
        let migrated = try #require(CSVMigrationChain.migrate(from: 2, to: 3, rows: rows))
        #expect(migrated[0]["meanOffsetMs"] == "9.9")
        #expect(migrated[0]["userOffsetMs"] == nil)
    }

    @Test("v2→v3 leaves pitchDiscrimination trainingType unchanged")
    func v2ToV3LeavesPitchDiscriminationUnchanged() async throws {
        let rows: [[String: String]] = [
            ["trainingType": "pitchDiscrimination", "centOffset": "15.5"],
        ]
        let migrated = try #require(CSVMigrationChain.migrate(from: 2, to: 3, rows: rows))
        #expect(migrated[0]["trainingType"] == "pitchDiscrimination")
        #expect(migrated[0]["centOffset"] == "15.5")
    }

#if PEACH_RESEARCH
    @Test("v2→v3 leaves rhythmOffsetDetection trainingType unchanged")
    func v2ToV3LeavesTimingOffsetDetectionUnchanged() async throws {
        let rows: [[String: String]] = [
            ["trainingType": "rhythmOffsetDetection", "tempoBPM": "120", "offsetMs": "5.3"],
        ]
        let migrated = try #require(CSVMigrationChain.migrate(from: 2, to: 3, rows: rows))
        #expect(migrated[0]["trainingType"] == "rhythmOffsetDetection")
    }
#endif

    // MARK: - Chain

    @Test("chain v1→v3 renames pitchComparison and applies userOffsetMs transform")
    func chainV1ToV3() async throws {
        let rows: [[String: String]] = [
            ["trainingType": "pitchComparison", "centOffset": "15.5"],
        ]
        let migrated = try #require(CSVMigrationChain.migrate(from: 1, to: 3, rows: rows))
        #expect(migrated[0]["trainingType"] == "pitchDiscrimination")
        #expect(migrated[0]["centOffset"] == "15.5")
        #expect(migrated[0]["userOffsetMs"] == nil)
        #expect(migrated[0]["meanOffsetMs"] == "")
    }

    @Test("chain with sourceVersion equal to targetVersion returns rows unchanged")
    func chainNoOp() async throws {
        let rows: [[String: String]] = [
            ["trainingType": "pitchDiscrimination", "foo": "bar"],
        ]
        let migrated = try #require(CSVMigrationChain.migrate(from: 3, to: 3, rows: rows))
        #expect(migrated[0]["trainingType"] == "pitchDiscrimination")
        #expect(migrated[0]["foo"] == "bar")
    }

    @Test("chain with sourceVersion below 1 returns nil")
    func chainBelowMinSourceVersion() async {
        let migrated = CSVMigrationChain.migrate(from: 0, to: 3, rows: [])
        #expect(migrated == nil)
    }

    @Test("chain with sourceVersion above targetVersion returns nil")
    func chainSourceAboveTarget() async {
        let migrated = CSVMigrationChain.migrate(from: 4, to: 3, rows: [])
        #expect(migrated == nil)
    }

    @Test("chain handles empty rows")
    func chainEmptyRows() async throws {
        let migrated = try #require(CSVMigrationChain.migrate(from: 1, to: 3, rows: []))
        #expect(migrated.isEmpty)
    }

    @Test("chain handles row missing trainingType")
    func chainMissingTrainingType() async throws {
        let rows: [[String: String]] = [
            ["timestamp": "2026-03-03T14:30:00Z", "userOffsetMs": "5.3"],
        ]
        let migrated = try #require(CSVMigrationChain.migrate(from: 2, to: 3, rows: rows))
        // Value transforms still run globally, so userOffsetMs becomes meanOffsetMs.
        #expect(migrated[0]["trainingType"] == nil)
        #expect(migrated[0]["meanOffsetMs"] == "5.3")
        #expect(migrated[0]["userOffsetMs"] == nil)
    }
}
