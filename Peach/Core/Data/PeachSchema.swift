import SwiftData
import Foundation

// MARK: - SchemaV1

/// Captures the initial data model: a single ``TrainingRecord`` envelope.
///
/// All training data — across every discipline — is stored as a `TrainingRecord`
/// envelope carrying a JSON-encoded payload. New disciplines do not require
/// new SwiftData entities, so ``models`` lists exactly one type and is not
/// expected to grow as the app gains disciplines.
///
/// ## How to add V2
///
/// V2 is only needed if the envelope itself ever needs new SwiftData fields
/// (e.g., adding a SwiftData index over `disciplineIdentifier`). Per-discipline
/// payload-shape evolution does *not* require a SchemaV2 — disciplines bump
/// their payload's ``TrainingDisciplinePayload/currentPayloadVersion`` and
/// switch on it at decode time.
///
/// 1. Create a new `enum SchemaV2: VersionedSchema` below this one.
///    - Set `versionIdentifier` to `Schema.Version(2, 0, 0)`.
///    - Add an `extension SchemaV2 { @Model final class TrainingRecord … }`
///      with the modified envelope shape.
///    - Set `models` to reference the V2 envelope.
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
///
/// 3. Append `SchemaV2.self` to `PeachSchemaMigrationPlan.schemas`.
// CSV export format versioning (currently v3) and SwiftData schema versioning (currently v1)
// are independent tracks. CSV versions evolve through column renames and additions; the
// SwiftData schema only changes when the envelope itself does.
enum SchemaV1: VersionedSchema {
    nonisolated static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [TrainingRecord.self]
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
