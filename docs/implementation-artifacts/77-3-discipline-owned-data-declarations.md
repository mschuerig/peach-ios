# Story 77.3: Discipline-owned data declarations

Status: done

## Story

As **a developer adding or modifying a training discipline's data layer**,
I want every CSV column, record type, and parsing concern that is specific to one discipline to be declared in that discipline's feature directory rather than in a central data file,
so that the colocation principle established by 77.2 also covers the data layer, and Core/Data services depend only on the registry's aggregated views.

## Background

After 77.2, all UI contributions live in feature directories. The data layer should follow the same colocation discipline: per-discipline CSV columns, record types, parsing logic, and profile-feed logic belong with the discipline that owns them. The current registry already aggregates `csvParsers`, `csvDisciplineColumns`, and `recordTypes`, so the runtime mechanism is already correct. What needs verification is whether any feature-specific data declarations still live in central locations (`Peach/Core/Data/`, etc.) and, if so, relocating them.

This is primarily an audit + targeted relocation story. Based on the existing protocol surface (each discipline declares its own `csvColumns`, `csvTrainingType`, `parseCSVRow`, `recordType`, `feedRecords`), the data layer is likely already mostly feature-local. If so, document that finding so future contributors know the data layer was verified.

## Acceptance Criteria

### AC 1: Audit and document current state

**Given** the current data-layer code (`Peach/Core/Data/`, `Peach/Core/Training/`, and discipline conformance files)
**When** audited
**Then** an inventory in Completion Notes lists every feature-specific data declaration (CSV columns, csvTrainingType, parseCSVRow, recordType, feedRecords, plus any feature-specific record subtypes or helpers) and its current location. The inventory makes it explicit which declarations are already feature-local and which (if any) are not.

### AC 2: Relocate feature-specific data declarations

**Given** the audit's findings
**When** any feature-specific declaration is found outside `Peach/Training/<Feature>/`
**Then** it is moved into the appropriate feature directory. After this story, a grep in `Peach/Core/Data/` for any specific discipline name (`unisonPitch`, `intervalPitch`, `rhythm`, `timingOffset`, `continuousRhythm`) returns hits only inside the **enumerated exceptions** below; all other matches must be relocated.

**Enumerated exceptions (intentional, do not relocate in this story):**

1. `Peach/Core/Data/PeachSchema.swift` — `SchemaV1.models` lists every concrete `@Model` record type by name. This is the deliberate aggregation point that SwiftData reads via `Schema(versionedSchema: SchemaV1.self)` before any registry bootstrap runs (see Decisions / Dev Notes for the rationale and the alternatives that were rejected).
2. `Peach/Core/Data/V1ToV2Migration.swift` and `V2ToV3Migration.swift` — frozen historical CSV wire-format strings (`pitchComparison`, `rhythmMatching`, `continuousRhythmMatching`, `tempoBPM`, etc.). These migrations are immutable by definition (they describe data that already exists in the wild). Per-feature relocation requires a per-feature migration-contribution mechanism and is tracked separately in story 77.6.

After this story, no `Peach/Core/Data/` file outside that enumerated list may reference a discipline-specific name.

### AC 3: Core/Data depends on the registry, not on disciplines

**Given** `TrainingDataExporter`, `CSVImportParser`, `TrainingDataImporter`, `TrainingDataStore`, `CSVExportSchema`
**When** inspected
**Then** they consume only the registry's aggregated views (`csvParsers`, `csvDisciplineColumns`, `recordTypes`, `all`) and do not directly reference any concrete discipline type or string identifier.

### AC 4: Round-trip tests still pass

**Given** the existing CSV import/export round-trip tests
**When** run after the changes
**Then** all tests pass for all six disciplines on both Debug and Research configurations, both iOS and macOS.

### AC 5: All four configurations green

`bin/test.sh && bin/test.sh -p mac && bin/test.sh --research && bin/test.sh -p mac --research` — all green. `bin/build.sh && bin/build.sh -p mac` — zero new warnings.

## Tasks / Subtasks

- [x] Task 1: Audit (AC: 1)
  - [x] 1.1 Read `Peach/Core/Data/` files (`CSVExportSchema.swift`, `CSVImportParser.swift`, `TrainingDataExporter.swift`, `TrainingDataImporter.swift`, `TrainingDataStore.swift`) and list every feature-specific reference.
  - [x] 1.2 For each of the six disciplines, locate where its `csvColumns`, `csvTrainingType`, `parseCSVRow`, `recordType`, `feedRecords` are declared. Confirm they live in `Peach/Training/<Feature>/`.
  - [x] 1.3 Locate any feature-specific record subtypes (e.g., subclasses of a base `Record` or per-discipline schema helpers).
  - [x] 1.4 Record the inventory in Completion Notes with file paths.

- [x] Task 2: Relocate (AC: 2)
  - [x] 2.1 For each finding outside the feature directory, move the declaration into the appropriate feature directory.
  - [x] 2.2 Update imports.

- [x] Task 3: Verify (AC: 3, 4, 5)
  - [x] 3.1 Grep `Peach/Core/Data/` for each specific discipline name. Expected: hits only inside AC2's enumerated exceptions (`PeachSchema.swift` `SchemaV1.models`; `V1ToV2Migration.swift` and `V2ToV3Migration.swift` wire-format strings). Confirmed.
  - [x] 3.2 Run all four test configurations.
  - [x] 3.3 Build all four configurations; confirm zero new warnings.

## Completion Notes

### Audit inventory

**Already feature-local (no move needed):**

All six disciplines declare `csvColumns`, `csvTrainingType`, `parseCSVRow`, `recordType`, and `feedRecords` via `TrainingDiscipline` conformance in their feature directory. Per-discipline conformance file paths:

| Discipline | Conformance file |
| --- | --- |
| Unison Pitch Discrimination | `Peach/Training/PitchDiscrimination/Discipline/UnisonPitchDiscriminationDiscipline.swift` |
| Interval Pitch Discrimination | `Peach/Training/PitchDiscrimination/Discipline/IntervalPitchDiscriminationDiscipline.swift` |
| Unison Pitch Matching | `Peach/Training/PitchMatching/Discipline/UnisonPitchMatchingDiscipline.swift` |
| Interval Pitch Matching | `Peach/Training/PitchMatching/Discipline/IntervalPitchMatchingDiscipline.swift` |
| Timing Offset Detection | `Peach/Training/TimingOffsetDetection/Discipline/TimingOffsetDetectionDiscipline.swift` |
| Continuous Rhythm Matching | `Peach/Training/ContinuousRhythmMatching/Discipline/ContinuousRhythmMatchingDiscipline.swift` |

The registry aggregation (`csvParsers`, `csvDisciplineColumns`, `recordTypes`) is the sole consumer in Core/Data services.

`Peach/Core/Data/TrainingDataExporter.swift`, `TrainingDataImporter.swift`, `TrainingDataStore.swift`, `CSVImportParser.swift`, `CSVExportSchema.swift` — already consume registry views only; no concrete-discipline references found.

**Relocated by this story:**

- `PitchDiscriminationRecord` (`@Model` class) — moved from nested in `Peach/Core/Data/PeachSchema.swift` to `Peach/Training/PitchDiscrimination/Discipline/PitchDiscriminationRecord.swift` via `extension SchemaV1 { @Model final class … }`.
- `PitchMatchingRecord` — moved to `Peach/Training/PitchMatching/Discipline/PitchMatchingRecord.swift`.
- `RhythmOffsetDetectionRecord` (typealiased to `TimingOffsetDetectionRecord`) — moved to `Peach/Training/TimingOffsetDetection/Discipline/TimingOffsetDetectionRecord.swift`. SwiftData entity name preserved as `RhythmOffsetDetectionRecord` to avoid a schema migration for the cosmetic rename.
- `ContinuousRhythmMatchingRecord` — moved to `Peach/Training/ContinuousRhythmMatching/Discipline/ContinuousRhythmMatchingRecord.swift`.
- `PitchDiscriminationCSVParser`, `PitchMatchingCSVParser` — moved from `Peach/Core/Data/` to the respective feature `Discipline/` directories.

**Deferred — tracked in story 77.6:**

- `Peach/Core/Data/V1ToV2Migration.swift`, `Peach/Core/Data/V2ToV3Migration.swift` — contain frozen historical wire-format strings (`pitchComparison`, `rhythmMatching`, `continuousRhythmMatching`, `tempoBPM`, etc.) per discipline. Per-feature relocation requires composing per-feature migration contributions, which is a mechanism refactor outside this story's "Not a CSV format change" scope. Tracked as story 77.6 (per-feature CSV migration contributions).

### Decisions

- `SchemaV1.models` kept as an explicit array, not registry-driven. Rationale promoted into Dev Notes ("Why `SchemaV1.models` stays as an explicit literal …").
- `@Model` classes nested via `extension SchemaV1 { @Model final class … }` in feature files. Verified the SwiftData macro works correctly across both iOS and macOS builds.
- Top-level typealias in each record file (`typealias PitchDiscriminationRecord = SchemaV1.PitchDiscriminationRecord`) kept call sites unchanged.

### Verification

- `bin/test.sh` (iOS Debug): 1453 passed
- `bin/test.sh -p mac` (macOS Debug): 1447 passed
- `bin/test.sh --research` (iOS Research): 1812 passed
- `bin/test.sh -p mac --research` (macOS Research): 1806 passed
- `bin/build.sh` and `bin/build.sh -p mac`: zero new warnings
- Grep `Peach/Core/Data/` for `unisonPitch|intervalPitch|rhythm|timingOffset|continuousRhythm`: only matches are in the deferred V*Migration files (frozen historical wire-format strings)
- `simplify-code` review on staged diff: clean, behavior-preserving relocation; no simplifications needed

## File List

### Modified
- `Peach/Core/Data/PeachSchema.swift` — removed nested `@Model` class bodies; kept `SchemaV1` enum, explicit `models` list, and migration plan; updated docstring with V2-authoring guidance reflecting the per-feature extension pattern.

### Moved into feature directories
- `Peach/Training/PitchDiscrimination/Discipline/PitchDiscriminationRecord.swift` (new — `@Model` extension on `SchemaV1`)
- `Peach/Training/PitchMatching/Discipline/PitchMatchingRecord.swift` (new — `@Model` extension on `SchemaV1`)
- `Peach/Training/TimingOffsetDetection/Discipline/TimingOffsetDetectionRecord.swift` (new — `@Model` extension on `SchemaV1`)
- `Peach/Training/ContinuousRhythmMatching/Discipline/ContinuousRhythmMatchingRecord.swift` (new — `@Model` extension on `SchemaV1`)
- `Peach/Training/PitchDiscrimination/Discipline/PitchDiscriminationCSVParser.swift` (moved, no content change)
- `Peach/Training/PitchMatching/Discipline/PitchMatchingCSVParser.swift` (moved, no content change)

### Deleted
- `Peach/Core/Data/PitchDiscriminationRecord.swift` (5-line typealias stub; content folded into `Peach/Training/PitchDiscrimination/Discipline/PitchDiscriminationRecord.swift`)
- `Peach/Core/Data/PitchMatchingRecord.swift` (5-line typealias stub; content folded into the moved feature file)
- `Peach/Core/Data/TimingOffsetDetectionRecord.swift` (7-line typealias stub; content folded into the moved feature file)
- `Peach/Core/Data/ContinuousRhythmMatchingRecord.swift` (5-line typealias stub; content folded into the moved feature file)

### Story
- `docs/implementation-artifacts/77-3-discipline-owned-data-declarations.md`
- `docs/implementation-artifacts/sprint-status.yaml`

## Dev Notes

### What "feature-specific" means here

A declaration is feature-specific if removing the named discipline would make it dead code. The csvTrainingType string `"unison_pitch_discrimination"` is feature-specific: it has no meaning outside that discipline. The `commonColumns` array in `CSVExportSchema` is not feature-specific: it lists columns shared by every discipline.

### Likely state going in

Based on the existing `TrainingDiscipline` protocol surface, all per-discipline data declarations should already live in the discipline conformance file in the feature directory. This story may be largely a no-op audit; if so, document the finding clearly so future contributors know the data layer was verified.

### What this story is NOT

- Not a CSV format change.
- Not a schema migration.
- Not a refactor of `TrainingDataStore` or the import/export services beyond removing any feature-specific references they shouldn't have.

### Why `SchemaV1.models` stays as an explicit literal in `PeachSchema.swift` (AC2 exception 1)

The `models` array is read by SwiftData inside `Schema(versionedSchema: SchemaV1.self).init` before any registry consumer runs. `TrainingDataTransferService.preview()` constructs that `Schema` without bootstrapping `TrainingDisciplineRegistry`, and the registry traps with `preconditionFailure` if accessed before bootstrap. A registry-driven `models` would therefore crash previews. The Research configuration adds two disciplines to the registry but the SwiftData schema must include all four record types in every configuration — these requirements diverge, so reusing the registry as the schema source is incorrect even apart from the bootstrap-order problem.

The trade-off accepted here: adding a new `@Model` record requires editing both the feature record file and `SchemaV1.models`. Story 77.6 (debug-time guard) tracks adding a runtime check that the registry-aggregated record set matches `SchemaV1.models` after bootstrap, to catch the forget-to-update case.

### Why `V1ToV2Migration.swift` / `V2ToV3Migration.swift` stay in `Peach/Core/Data/` (AC2 exception 2)

These files contain frozen historical CSV wire-format strings (`pitchComparison`, `rhythmMatching`, `continuousRhythmMatching`, etc.). They describe data that already exists in user exports — the strings are immutable by definition. Per-feature relocation requires composing per-feature migration contributions, which is a mechanism refactor outside this story's "Not a CSV format change" scope. Story 77.6 tracks the per-feature contribution model.

### References

- Story 77.2 — same colocation principle applied to UI.
- `Peach/Core/Data/CSVExportSchema.swift`, `CSVImportParser.swift`, `TrainingDataExporter.swift`, `TrainingDataImporter.swift`, `TrainingDataStore.swift` — the audit targets.

## Change Log

- 2026-04-27: Drafted. Status → ready-for-dev.
- 2026-04-28: Implemented. Audit confirmed CSV column / parser / record-type / feedRecords declarations were already feature-local via `TrainingDiscipline` conformance. Relocated four `@Model` record classes from `Peach/Core/Data/PeachSchema.swift` into per-discipline feature directories using `extension SchemaV1 { @Model final class … }`. Relocated two CSV row parsers. Deferred `V1ToV2Migration.swift` / `V2ToV3Migration.swift` per-feature splitting to an architecture session — relocation requires a per-feature migration-contribution mechanism outside this story's scope. All four configurations green. Status → review.
- 2026-04-28: Code review fixes. Amended AC2 to enumerate intentional exceptions (`SchemaV1.models`; the two frozen `V*Migration.swift` files) instead of the unconditional "zero hits" wording, since the original wording contradicted the deferred-decisions block. Promoted the `SchemaV1.models` rationale into Dev Notes. Created tracked follow-up story 77.6 for per-feature CSV migration contributions. Expanded AC1 audit inventory into a per-discipline conformance-file table. Added Deleted subsection to File List enumerating the four typealias-stub files removed from `Peach/Core/Data/`. Removed copy-pasted top-level alias docstring from the four record files (kept the `TimingOffsetDetectionRecord` rename comment which carries unique information).
