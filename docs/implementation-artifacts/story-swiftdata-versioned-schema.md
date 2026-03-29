# Story: Add SwiftData VersionedSchema and SchemaMigrationPlan

Status: draft

## Story

As a developer evolving the data model,
I want a VersionedSchema and SchemaMigrationPlan in place,
so that future schema changes (renames, deletions, type changes) don't crash existing installs.

## Background

The project has 4 `@Model` classes and no schema versioning. All schema changes so far have been purely additive (new models), which SwiftData handles via lightweight migration. However, the first non-additive change — renaming a property, changing a type, or removing a field — will cause a runtime crash with no recovery path on devices that have existing data.

This is a safety net story: it introduces the versioning infrastructure without changing the schema itself. Once in place, any future schema evolution becomes a safe, tested migration stage instead of a potential data-loss crash.

**Source:** future-work.md "Add SwiftData VersionedSchema and SchemaMigrationPlan"

## Acceptance Criteria

1. **SchemaV1 defined:** A `VersionedSchema` conformance captures the current schema (all 4 models with their exact current properties) as V1. The model definitions inside the versioned schema must match the live `@Model` classes exactly.

2. **SchemaMigrationPlan defined:** A `SchemaMigrationPlan` conformance exists with an empty `stages` array (no migrations yet — V1 is the only version). The plan is wired into `ModelContainer` initialization.

3. **ModelContainer uses the migration plan:** `PeachApp.swift` creates the `ModelContainer` with the `SchemaMigrationPlan`, replacing the current bare model list.

4. **Existing data preserved:** The migration plan with a single V1 schema and no stages must open existing databases without data loss. A user upgrading from the current version (no versioning) to the versioned version must see all their records intact.

5. **Tests verify round-trip:** A test creates records with the versioned container, verifies they persist and load correctly. An additional test verifies the migration plan's `stages` and `schemas` are configured correctly.

6. **Developer documentation:** A comment block in the schema file explains how to add V2: copy V1 models into a new `SchemaV2`, add a `MigrationStage`, append to `stages`.

## Tasks / Subtasks

- [ ] Task 1: Define SchemaV1 (AC: #1)
  - [ ] Create `Peach/Core/Data/PeachSchemaVersioning.swift`
  - [ ] Define `enum SchemaV1: VersionedSchema` with all 4 model classes as nested types
  - [ ] Each nested model must mirror the live `@Model` class properties exactly

- [ ] Task 2: Define SchemaMigrationPlan (AC: #2)
  - [ ] Define `enum PeachMigrationPlan: SchemaMigrationPlan` in the same file
  - [ ] Set `schemas = [SchemaV1.self]`
  - [ ] Set `stages: [MigrationStage] = []`

- [ ] Task 3: Wire into ModelContainer (AC: #3)
  - [ ] Update `PeachApp.swift` to use `ModelContainer(for: SchemaV1.models, migrationPlan: PeachMigrationPlan.self)`
  - [ ] Remove the current bare model list from `ModelContainer(for:)`

- [ ] Task 4: Add developer guide comment (AC: #6)
  - [ ] Add a comment block explaining the V2 workflow: copy models, add migration stage, register in plan

- [ ] Task 5: Tests (AC: #4, #5)
  - [ ] Test that the migration plan has exactly 1 schema and 0 stages
  - [ ] Test that creating and fetching records works with the versioned container
  - [ ] Test all 4 model types round-trip through the versioned container

## Dev Notes

### Current Schema (V1) — 4 Models

**PitchDiscriminationRecord:**
- `referenceNote: Int`, `targetNote: Int`, `centOffset: Double`, `isCorrect: Bool`, `timestamp: Date`, `interval: Int`, `tuningSystem: String`

**PitchMatchingRecord:**
- `referenceNote: Int`, `targetNote: Int`, `initialCentOffset: Double`, `userCentError: Double`, `interval: Int`, `tuningSystem: String`, `timestamp: Date`

**RhythmOffsetDetectionRecord:**
- `tempoBPM: Int`, `offsetMs: Double`, `isCorrect: Bool`, `timestamp: Date`

**ContinuousRhythmMatchingRecord:**
- `tempoBPM: Int`, `meanOffsetMs: Double`, `meanOffsetMsPosition0: Double?`, `meanOffsetMsPosition1: Double?`, `meanOffsetMsPosition2: Double?`, `meanOffsetMsPosition3: Double?`, `timestamp: Date`

### Current ModelContainer Creation

In `PeachApp.swift` (lines 46–51):
```swift
let container = try ModelContainer(
    for: PitchDiscriminationRecord.self,
    PitchMatchingRecord.self,
    RhythmOffsetDetectionRecord.self,
    ContinuousRhythmMatchingRecord.self
)
```

This will be replaced with the versioned equivalent.

### Important: VersionedSchema Model Duplication

SwiftData's `VersionedSchema` requires nested `@Model` classes inside each schema version enum. These are **duplicates** of the live model classes — they describe the schema at that point in time. The live `@Model` classes in `Core/Data/` remain the authoritative runtime types. When adding V2 later, you copy V1's nested models into V2 and make the modifications there, leaving V1 frozen.

### File Placement

- `Peach/Core/Data/PeachSchemaVersioning.swift` — new file, lives alongside the model files in `Core/Data/`
- `import SwiftData` is already allowed in `Core/Data/` per dependency rules

### What NOT to Change

- The live `@Model` classes — they remain unchanged and are the runtime types
- `TrainingDataStore` — no changes needed, it works through `ModelContext`
- CSV import/export — independent versioning system, unrelated
- Test model containers — tests using `ModelConfiguration(isStoredInMemoryOnly: true)` will need updating to use the migration plan too

### References

- [Source: docs/implementation-artifacts/future-work.md#Add SwiftData VersionedSchema]
- [Source: Peach/App/PeachApp.swift lines 46–51 — current ModelContainer init]
- [Source: Peach/Core/Data/PitchDiscriminationRecord.swift]
- [Source: Peach/Core/Data/PitchMatchingRecord.swift]
- [Source: Peach/Core/Data/RhythmOffsetDetectionRecord.swift]
- [Source: Peach/Core/Data/ContinuousRhythmMatchingRecord.swift]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
