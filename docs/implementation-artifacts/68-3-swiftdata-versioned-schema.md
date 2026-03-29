# Story 68.3: SwiftData Versioned Schema and Migration Plan

Status: review

## Story

As a **developer evolving the data model**,
I want a VersionedSchema and SchemaMigrationPlan in place,
so that future schema changes don't crash existing installs.

## Acceptance Criteria

1. **Given** the current schema (4 models) **When** defined as SchemaV1 **Then** a VersionedSchema conformance captures all model properties exactly.

2. **Given** the migration plan **When** configured **Then** it has `schemas = [SchemaV1.self]` and `stages = []` (no migrations yet).

3. **Given** `PeachApp.swift` **When** creating the ModelContainer **Then** it uses the SchemaMigrationPlan instead of the bare model list.

4. **Given** a user upgrading from the current version **When** opening the app **Then** all existing records are intact with no data loss.

5. **Given** the schema file **When** read by a developer **Then** it contains a comment block explaining how to add V2.

6. **Given** the full test suite **When** run on both platforms **Then** all tests pass including new round-trip verification tests.

## Tasks / Subtasks

- [x] Task 1: Create `SchemaV1` VersionedSchema (AC: #1)
  - [x] 1.1 Create `Peach/Core/Data/PeachSchema.swift`
  - [x] 1.2 Define `enum SchemaV1: VersionedSchema` with `versionIdentifier` and `models` array containing all 4 @Model types
  - [x] 1.3 The models property must reference the actual model classes: `PitchDiscriminationRecord.self`, `PitchMatchingRecord.self`, `RhythmOffsetDetectionRecord.self`, `ContinuousRhythmMatchingRecord.self`

- [x] Task 2: Create `PeachSchemaMigrationPlan` (AC: #2, #5)
  - [x] 2.1 Define `enum PeachSchemaMigrationPlan: SchemaMigrationPlan` with `schemas = [SchemaV1.self]` and `stages: [MigrationStage] = []`
  - [x] 2.2 Add a documentation comment block explaining how to add V2: create a new `SchemaV2` with the updated models, add a migration stage, and append to the `schemas` array

- [x] Task 3: Wire migration plan into `PeachApp.swift` (AC: #3, #4)
  - [x] 3.1 Replace the bare model list with `Schema(versionedSchema: SchemaV1.self)` + `ModelContainer(for: schema, migrationPlan: PeachSchemaMigrationPlan.self)`
  - [x] 3.2 Verify the container initializer signature -- use the `Schema`-based initializer that accepts a migration plan
  - [x] 3.3 Update `PreviewDefaults.swift` if it creates its own ModelContainer

- [x] Task 4: Tests (AC: #6)
  - [x] 4.1 Add a test verifying `SchemaV1.models` contains exactly 4 model types
  - [x] 4.2 Add a test verifying `PeachSchemaMigrationPlan.schemas` contains `[SchemaV1.self]`
  - [x] 4.3 Add a round-trip test: create a ModelContainer with the migration plan, insert one record of each type, fetch them back, verify all properties are intact
  - [x] 4.4 Verify all existing `TrainingDataStore` tests still pass (they create their own containers)
  - [x] 4.5 Run `bin/test.sh && bin/test.sh -p mac`

## Dev Notes

### Current ModelContainer Setup

In `PeachApp.swift` (line 46-51), the container is created with a bare model list:

```swift
let container = try ModelContainer(
    for: PitchDiscriminationRecord.self,
    PitchMatchingRecord.self,
    RhythmOffsetDetectionRecord.self,
    ContinuousRhythmMatchingRecord.self
)
```

This works for the initial release but provides no migration path. Adding a property to any `@Model` without a migration plan will cause a crash on upgrade.

### The 4 @Model Types

1. **PitchDiscriminationRecord** -- `referenceNote: Int`, `targetNote: Int`, `centOffset: Double`, `isCorrect: Bool`, `timestamp: Date`, `interval: Int`, `tuningSystem: String`

2. **PitchMatchingRecord** -- `referenceNote: Int`, `targetNote: Int`, `initialCentOffset: Double`, `userCentError: Double`, `interval: Int`, `tuningSystem: String`, `timestamp: Date`

3. **RhythmOffsetDetectionRecord** -- `tempoBPM: Int`, `offsetMs: Double`, `isCorrect: Bool`, `timestamp: Date`

4. **ContinuousRhythmMatchingRecord** -- `tempoBPM: Int`, `meanOffsetMs: Double`, `meanOffsetMsPosition0-3: Double?`, `timestamp: Date`

### VersionedSchema Pattern

The `VersionedSchema` conformance requires a `static var versionIdentifier` (a `Schema.Version`) and `static var models: [any PersistentModel.Type]`. For V1, the models are the current @Model classes as-is. When V2 is needed, the V2 enum will contain nested model definitions that mirror the updated schema, and a `MigrationStage` (lightweight or custom) will describe the transformation.

### Preview Container

`PreviewDefaults.swift` creates a preview container. It should also be updated to use the migration plan for consistency, or at minimum use the same model list. Check whether it uses an in-memory configuration that might need adjustment.

### Project Structure Notes

- New file: `Peach/Core/Data/PeachSchema.swift` -- contains both `SchemaV1` and `PeachSchemaMigrationPlan`
- Modified: `Peach/App/PeachApp.swift` -- container initialization
- Modified: `Peach/App/PreviewDefaults.swift` -- preview container if applicable
- New test file: `PeachTests/Core/Data/PeachSchemaTests.swift`

### References

- [Source: Peach/App/PeachApp.swift lines 46-51 -- current ModelContainer creation with bare model list]
- [Source: Peach/Core/Data/PitchDiscriminationRecord.swift -- @Model with 7 stored properties]
- [Source: Peach/Core/Data/PitchMatchingRecord.swift -- @Model with 7 stored properties]
- [Source: Peach/Core/Data/RhythmOffsetDetectionRecord.swift -- @Model with 4 stored properties]
- [Source: Peach/Core/Data/ContinuousRhythmMatchingRecord.swift -- @Model with 7 stored properties (4 optional)]
- [Source: Peach/App/PreviewDefaults.swift -- preview environment setup]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6

### Debug Log References
None required.

### Completion Notes List
- Created `SchemaV1` VersionedSchema capturing all 4 @Model types with version 1.0.0
- Created `PeachSchemaMigrationPlan` with single schema and empty stages
- Added comprehensive V2 migration documentation comment on SchemaV1
- Used `Schema(versionedSchema:)` initializer (the `ModelContainer` API requires a `Schema` object, not a raw `VersionedSchema.Type`)
- Updated `PeachApp.swift`, `PreviewDefaults.swift`, and `TrainingDataTransferService.preview()` to use schema-based container
- All 7 new tests pass: schema verification (1), migration plan verification (2), round-trip tests for all 4 record types (4)
- Full suite: 1665 iOS tests pass, 1658 macOS tests pass

### File List
- `Peach/Core/Data/PeachSchema.swift` (new) — SchemaV1 and PeachSchemaMigrationPlan
- `Peach/App/PeachApp.swift` (modified) — ModelContainer uses Schema + migration plan
- `Peach/App/PreviewDefaults.swift` (modified) — SettingsCoordinator.stub uses Schema + migration plan
- `Peach/Core/Data/TrainingDataTransferService.swift` (modified) — preview() uses Schema + migration plan
- `PeachTests/Core/Data/PeachSchemaTests.swift` (new) — 7 tests: schema, migration plan, round-trips

## Change Log

- 2026-03-29: Story created
- 2026-03-29: Implemented VersionedSchema, migration plan, wired into app, all tests pass
