# Story 54.8: CSV Export/Import

Status: backlog

## Story

As a **musician using Peach**,
I want my continuous rhythm matching data included in CSV exports and importable from CSV files,
so that my training data is portable and backed up alongside all other training records.

## Acceptance Criteria

1. **Given** `CSVExportSchemaV2`, **when** extended, **then** it supports a `continuousRhythmMatching` training type with columns for: `tempoBPM`, `meanOffsetMs`, `hitRate`, `cycleCount`, `timestamp`.

2. **Given** `CSVImportParserV2`, **when** it encounters a `continuousRhythmMatching` row, **then** it parses it into a `ContinuousRhythmMatchingRecord` with validation.

3. **Given** export, **when** the user exports data, **then** all `ContinuousRhythmMatchingRecord` entries are included in the CSV alongside existing training types.

4. **Given** import with merge, **when** duplicate detection runs, **then** continuous rhythm matching records are deduplicated by `timestamp + tempoBPM + trainingType`.

5. **Given** a V2 CSV without `continuousRhythmMatching` rows, **when** imported, **then** it imports successfully — the new type is optional.

6. **Given** unit tests, **when** export/import round-trip is tested, **then** continuous rhythm matching records survive the cycle intact.

## Tasks / Subtasks

- [ ] Task 1: Extend `CSVExportSchemaV2` (AC: #1, #3)
  - [ ] Add `TrainingType.continuousRhythmMatching` case with CSV value `"continuousRhythmMatching"`
  - [ ] Define column mapping for continuous rhythm matching fields
  - [ ] Extend export logic to include `ContinuousRhythmMatchingRecord` entries
  - [ ] Write export tests

- [ ] Task 2: Extend `CSVImportParserV2` (AC: #2, #4, #5)
  - [ ] Add `parseContinuousRhythmMatchingRow()` method
  - [ ] Validate: `tempoBPM` positive integer, `meanOffsetMs` valid float, `hitRate` 0.0–1.0, `cycleCount` positive integer
  - [ ] Add to row type detection switch
  - [ ] Extend deduplication logic
  - [ ] Write import tests including malformed row handling

- [ ] Task 3: Round-trip test (AC: #6)
  - [ ] Export continuous rhythm matching records → import → verify equality
  - [ ] Test mixed export with all training types

- [ ] Task 4: Run full test suite
  - [ ] `bin/test.sh` — all tests pass, no regressions

## Dev Notes

### CSV column layout

Follow the existing V2 pattern where type-specific fields reuse or extend the column set. Continuous rhythm matching needs fewer columns than per-gap data since we store aggregates:

- `trainingType`: `"continuousRhythmMatching"`
- `timestamp`: ISO 8601
- `tempoBPM`: integer
- `meanOffsetMs`: float (signed)
- `hitRate`: float (0.0–1.0)
- `cycleCount`: integer (always 16 for v1, but store explicitly for future flexibility)

Gap position breakdown is NOT exported per-row — it's detailed data that stays on-device. The aggregate stats are sufficient for backup/restore.

### Chain of responsibility pattern

The import parser uses chain of responsibility (ADR-6). The new training type is additive — add a new case to the existing V2 parser, no changes to V1 parser.

### What NOT to do

- Do NOT modify V1 parser
- Do NOT change existing V2 column layout for other training types
- Do NOT export per-gap detail data — only aggregates

### References

- [Source: Peach/Core/Data/CSVExportSchemaV2.swift — export schema]
- [Source: Peach/Core/Data/CSVImportParserV2.swift — import parser]
- [Source: Peach/Core/Data/ContinuousRhythmMatchingRecord.swift — from Story 54.5]
- [Source: docs/planning-artifacts/rhythm-training-spec.md — ADR-6 CSV format]
- [Source: docs/project-context.md — project rules and conventions]
