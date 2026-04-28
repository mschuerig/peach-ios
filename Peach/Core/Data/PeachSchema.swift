import SwiftData
import Foundation

// MARK: - SchemaV1

/// The current data model: a single ``TrainingRecord`` envelope.
///
/// All training data — across every discipline — is stored as a `TrainingRecord`
/// envelope carrying a JSON-encoded payload. New disciplines do not require
/// new SwiftData entities, so ``models`` lists exactly one type and is not
/// expected to grow as the app gains disciplines.
///
/// The version is `(2, 0, 0)` because story 77.4 replaced an earlier per-discipline
/// `@Model` schema with this envelope. Pre-77.4 stores at version `(1, 0, 0)` are
/// schema-incompatible; the bootstrap path in `PeachApp.setupDataStore` wipes the
/// store on incompatibility rather than attempting an automatic migration —
/// pre-release data is not preserved. CSV export/import is the supported migration path.
///
/// ## How to add V3
///
/// V3 is only needed if the envelope itself ever needs new SwiftData fields.
/// Per-discipline payload-shape evolution does *not* require a SchemaV3 — disciplines
/// bump their payload's ``TrainingDisciplinePayload/currentPayloadVersion`` and
/// switch on it at decode time.
///
/// 1. Create a new `enum SchemaV3: VersionedSchema` below this one.
///    - Set `versionIdentifier` to `Schema.Version(3, 0, 0)`.
///    - Add an `extension SchemaV3 { @Model final class TrainingRecord … }`
///      with the modified envelope shape.
///    - Set `models` to reference the V3 envelope.
///
/// 2. Add a migration stage in `PeachSchemaMigrationPlan.stages`:
///    ```swift
///    static var stages: [MigrationStage] {
///        [migrateV2toV3]
///    }
///
///    static let migrateV2toV3 = MigrationStage.lightweight(
///        fromVersion: SchemaV1.self,
///        toVersion: SchemaV3.self
///    )
///    ```
///
/// 3. Append `SchemaV3.self` to `PeachSchemaMigrationPlan.schemas`.
// CSV export format versioning (currently v3) and SwiftData schema versioning (currently v2)
// are independent tracks. CSV versions evolve through column renames and additions; the
// SwiftData schema only changes when the envelope itself does.
enum SchemaV1: VersionedSchema {
    nonisolated static let versionIdentifier = Schema.Version(2, 0, 0)

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
