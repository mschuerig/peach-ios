import SwiftData

// MARK: - SchemaV1

/// Captures the initial data model (4 record types) as a versioned schema.
///
/// ## How to add V2
///
/// 1. Create a new `enum SchemaV2: VersionedSchema` below this one.
///    - Set `versionIdentifier` to `Schema.Version(2, 0, 0)`.
///    - Define nested `@Model` classes that mirror the updated schema
///      (e.g., `SchemaV2.PitchDiscriminationRecord` with any new/renamed properties).
///    - Set `models` to reference those nested types.
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
