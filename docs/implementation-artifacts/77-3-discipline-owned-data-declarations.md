# Story 77.3: Discipline-owned data declarations

Status: ready-for-dev

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
**Then** it is moved into the appropriate feature directory. After this story, a grep in `Peach/Core/Data/` for any specific discipline name (`unisonPitch`, `intervalPitch`, `rhythm`, `timingOffset`, `continuousRhythm`) returns zero hits.

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

- [ ] Task 1: Audit (AC: 1)
  - [ ] 1.1 Read `Peach/Core/Data/` files (`CSVExportSchema.swift`, `CSVImportParser.swift`, `TrainingDataExporter.swift`, `TrainingDataImporter.swift`, `TrainingDataStore.swift`) and list every feature-specific reference.
  - [ ] 1.2 For each of the six disciplines, locate where its `csvColumns`, `csvTrainingType`, `parseCSVRow`, `recordType`, `feedRecords` are declared. Confirm they live in `Peach/Training/<Feature>/`.
  - [ ] 1.3 Locate any feature-specific record subtypes (e.g., subclasses of a base `Record` or per-discipline schema helpers).
  - [ ] 1.4 Record the inventory in Completion Notes with file paths.

- [ ] Task 2: Relocate (AC: 2)
  - [ ] 2.1 For each finding outside the feature directory, move the declaration into the appropriate feature directory.
  - [ ] 2.2 Update imports.

- [ ] Task 3: Verify (AC: 3, 4, 5)
  - [ ] 3.1 Grep `Peach/Core/Data/` for each specific discipline name. Expected: zero hits.
  - [ ] 3.2 Run all four test configurations.
  - [ ] 3.3 Build all four configurations; confirm zero new warnings.

## Dev Notes

### What "feature-specific" means here

A declaration is feature-specific if removing the named discipline would make it dead code. The csvTrainingType string `"unison_pitch_discrimination"` is feature-specific: it has no meaning outside that discipline. The `commonColumns` array in `CSVExportSchema` is not feature-specific: it lists columns shared by every discipline.

### Likely state going in

Based on the existing `TrainingDiscipline` protocol surface, all per-discipline data declarations should already live in the discipline conformance file in the feature directory. This story may be largely a no-op audit; if so, document the finding clearly so future contributors know the data layer was verified.

### What this story is NOT

- Not a CSV format change.
- Not a schema migration.
- Not a refactor of `TrainingDataStore` or the import/export services beyond removing any feature-specific references they shouldn't have.

### References

- Story 77.2 — same colocation principle applied to UI.
- `Peach/Core/Data/CSVExportSchema.swift`, `CSVImportParser.swift`, `TrainingDataExporter.swift`, `TrainingDataImporter.swift`, `TrainingDataStore.swift` — the audit targets.

## Change Log

- 2026-04-27: Drafted. Status → ready-for-dev.
