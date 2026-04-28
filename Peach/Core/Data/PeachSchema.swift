import SwiftData
import Foundation

// MARK: - SchemaV1

/// Captures the initial data model (4 record types) as a versioned schema.
///
/// Each `@Model` class is nested inside the enum (via per-feature
/// `extension SchemaV1 { @Model final class … }` declarations colocated
/// with the owning discipline) so the schema is frozen — changes to the
/// data model require a new schema version (e.g. `SchemaV2`).
/// Top-level typealiases in each record's feature file keep call sites unchanged.
///
/// ## How to add V2
///
/// 1. Create a new `enum SchemaV2: VersionedSchema` below this one.
///    - Set `versionIdentifier` to `Schema.Version(2, 0, 0)`.
///    - In each feature directory whose record changes, add an
///      `extension SchemaV2 { @Model final class … }` with the modified shape.
///      Unchanged models can be referenced from `SchemaV1`
///      (e.g., `SchemaV1.RhythmOffsetDetectionRecord`).
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
// CSV export format versioning (currently v3) and SwiftData schema versioning (currently v1)
// are independent tracks. CSV versions evolved through column renames and additions before
// the SwiftData schema was versioned — they do not need to stay in sync.
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
