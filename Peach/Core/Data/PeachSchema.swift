import SwiftData
import Foundation

// WALKTHROUGH: PeachSchema defines concrete record models for all 4 training disciplines.
// Adding or changing a discipline requires modifying this file — Core depends on features.
// SwiftData's VersionedSchema requires all models in one place, but that's a framework
// constraint, not an architectural justification. This file belongs at the feature layer
// (or a shared data-definition layer), not in Core. Same violation as DuplicateKey.swift.

// MARK: - SchemaV1

/// Captures the initial data model (4 record types) as a versioned schema.
///
/// Each `@Model` class is nested inside the enum so the schema is frozen —
/// changes to the data model require a new schema version (e.g. `SchemaV2`).
/// Top-level typealiases in each record's original file keep call sites unchanged.
///
/// ## How to add V2
///
/// 1. Create a new `enum SchemaV2: VersionedSchema` below this one.
///    - Set `versionIdentifier` to `Schema.Version(2, 0, 0)`.
///    - Copy the nested `@Model` classes you need to change into `SchemaV2`
///      and apply your modifications there. Unchanged models can be referenced
///      from `SchemaV1` (e.g., `SchemaV1.RhythmOffsetDetectionRecord`).
///    - Set `models` to reference the V2 types (and any unchanged V1 types).
///
/// 2. Add a migration stage in `PeachSchemaMigrationPlan.stages`:
///    ```swift
///    static var stages: [MigrationStage] {
///        [migrateV1toV2]
///    }
///
///    static let migrateV1toV2 = MigrationStage.lightweight(
///        fromVersion: SchemaV1.self,
///        toVersion: SchemaV2.self
///    )
///    ```
///    Use `.custom` instead of `.lightweight` if the migration requires
///    data transformation (e.g., splitting a column, computing defaults).
///
/// 3. Append `SchemaV2.self` to `PeachSchemaMigrationPlan.schemas`:
///    ```swift
///    static var schemas: [any VersionedSchema.Type] {
///        [SchemaV1.self, SchemaV2.self]
///    }
///    ```
///
/// 4. Update the top-level typealiases in each record file to point at
///    the latest version (e.g., `typealias PitchDiscriminationRecord = SchemaV2.PitchDiscriminationRecord`).
enum SchemaV1: VersionedSchema {
    nonisolated static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            PitchDiscriminationRecord.self,
            PitchMatchingRecord.self,
            RhythmOffsetDetectionRecord.self,
            ContinuousRhythmMatchingRecord.self,
        ]
    }

    // MARK: - PitchDiscriminationRecord

    @Model
    final class PitchDiscriminationRecord {
        /// Reference note - always an exact MIDI note (0-127)
        var referenceNote: Int

        /// Target MIDI note (equals referenceNote for unison, different for intervals)
        var targetNote: Int

        /// Signed cent offset applied to target note (positive = higher, negative = lower)
        /// Fractional precision with 0.1 cent resolution
        var centOffset: Double

        /// Did the user answer correctly?
        var isCorrect: Bool

        /// When the discrimination was answered
        var timestamp: Date

        /// Interval between reference and target notes (stored as semitone count)
        var interval: Int

        /// Tuning system used for the discrimination (stored as string identifier)
        var tuningSystem: String

        init(referenceNote: Int, targetNote: Int, centOffset: Double, isCorrect: Bool, interval: Int, tuningSystem: String, timestamp: Date = Date()) {
            self.referenceNote = referenceNote
            self.targetNote = targetNote
            self.centOffset = centOffset
            self.isCorrect = isCorrect
            self.interval = interval
            self.tuningSystem = tuningSystem
            self.timestamp = timestamp
        }
    }

    // MARK: - PitchMatchingRecord

    @Model
    final class PitchMatchingRecord {
        var referenceNote: Int
        var targetNote: Int
        var initialCentOffset: Double
        var userCentError: Double
        var interval: Int
        var tuningSystem: String
        var timestamp: Date

        init(referenceNote: Int, targetNote: Int, initialCentOffset: Double, userCentError: Double, interval: Int, tuningSystem: String, timestamp: Date = Date()) {
            self.referenceNote = referenceNote
            self.targetNote = targetNote
            self.initialCentOffset = initialCentOffset
            self.userCentError = userCentError
            self.interval = interval
            self.tuningSystem = tuningSystem
            self.timestamp = timestamp
        }
    }

    // MARK: - RhythmOffsetDetectionRecord

    @Model
    final class RhythmOffsetDetectionRecord {
        var tempoBPM: Int

        /// Signed offset in milliseconds: negative = early, positive = late
        var offsetMs: Double

        var isCorrect: Bool
        var timestamp: Date

        init(tempoBPM: Int, offsetMs: Double, isCorrect: Bool, timestamp: Date = Date()) {
            self.tempoBPM = tempoBPM
            self.offsetMs = offsetMs
            self.isCorrect = isCorrect
            self.timestamp = timestamp
        }
    }

    // MARK: - ContinuousRhythmMatchingRecord

    @Model
    final class ContinuousRhythmMatchingRecord {
        var tempoBPM: Int
        var meanOffsetMs: Double
        var meanOffsetMsPosition0: Double?
        var meanOffsetMsPosition1: Double?
        var meanOffsetMsPosition2: Double?
        var meanOffsetMsPosition3: Double?
        var timestamp: Date

        init(
            tempoBPM: Int,
            meanOffsetMs: Double,
            meanOffsetMsPosition0: Double? = nil,
            meanOffsetMsPosition1: Double? = nil,
            meanOffsetMsPosition2: Double? = nil,
            meanOffsetMsPosition3: Double? = nil,
            timestamp: Date = Date()
        ) {
            self.tempoBPM = tempoBPM
            self.meanOffsetMs = meanOffsetMs
            self.meanOffsetMsPosition0 = meanOffsetMsPosition0
            self.meanOffsetMsPosition1 = meanOffsetMsPosition1
            self.meanOffsetMsPosition2 = meanOffsetMsPosition2
            self.meanOffsetMsPosition3 = meanOffsetMsPosition3
            self.timestamp = timestamp
        }
    }
}

// MARK: - Migration Plan

enum PeachSchemaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
