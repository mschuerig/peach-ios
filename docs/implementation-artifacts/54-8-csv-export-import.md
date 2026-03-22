# Story 54.8: CSV Export/Import

Status: review

## Story

As a **musician using Peach**,
I want my continuous rhythm matching data included in CSV exports and importable from CSV files,
so that my training data is portable and backed up alongside all other training records.

## Acceptance Criteria

1. **Given** `CSVExportSchemaV2`, **when** extended, **then** it supports a `continuousRhythmMatching` training type with columns for: `tempoBPM`, `meanOffsetMs`, `timestamp`.

2. **Given** `CSVImportParserV2`, **when** it encounters a `continuousRhythmMatching` row, **then** it parses it into a `ContinuousRhythmMatchingRecord` with validation.

3. **Given** export, **when** the user exports data, **then** all `ContinuousRhythmMatchingRecord` entries are included in the CSV alongside existing training types.

4. **Given** import with merge, **when** duplicate detection runs, **then** continuous rhythm matching records are deduplicated by `timestamp + tempoBPM + trainingType`.

5. **Given** a V2 CSV without `continuousRhythmMatching` rows, **when** imported, **then** it imports successfully — the new type is optional.

6. **Given** unit tests, **when** export/import round-trip is tested, **then** continuous rhythm matching records survive the cycle intact.

## Tasks / Subtasks

- [x] Task 1: Extend `CSVExportSchemaV2` (AC: #1, #3)
  - [x] Add `TrainingType.continuousRhythmMatching` case with CSV value `"continuousRhythmMatching"`
  - [x] Define column mapping for continuous rhythm matching fields
  - [x] Extend export logic to include `ContinuousRhythmMatchingRecord` entries
  - [x] Write export tests

- [x] Task 2: Extend `CSVImportParserV2` (AC: #2, #4, #5)
  - [x] Add `parseContinuousRhythmMatchingRow()` method
  - [x] Validate: `tempoBPM` positive integer, `meanOffsetMs` valid float
  - [x] Add to row type detection switch
  - [x] Extend deduplication logic
  - [x] Write import tests including malformed row handling

- [x] Task 3: Round-trip test (AC: #6)
  - [x] Export continuous rhythm matching records → import → verify equality
  - [x] Test mixed export with all training types

- [x] Task 4: Run full test suite
  - [x] `bin/test.sh` — all tests pass, no regressions (1585 tests)

## Dev Notes

### CSV column layout

Follow the existing V2 pattern where type-specific fields reuse or extend the column set. Continuous rhythm matching needs fewer columns than per-gap data since we store aggregates:

- `trainingType`: `"continuousRhythmMatching"`
- `timestamp`: ISO 8601
- `tempoBPM`: integer (reuses existing column at index 12)
- `meanOffsetMs`: float (signed, new column at index 15)

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

## Dev Agent Record

### Design Decisions

1. **Extended V2 schema from 15 to 16 columns** — Added `meanOffsetMs` (index 15). Continuous rhythm matching reuses `tempoBPM` at existing index 12. All formatters produce 16-field rows with empty strings for unused columns. `hitRate` and `cycleCount` are not exported — they were removed from the data model in story 54.7 code review.

2. **Deduplication uses `RhythmDuplicateKey` with `continuousRhythmMatching` training type** — Follows existing pattern for rhythm offset detection and rhythm matching: key on `timestamp + tempoBPM + trainingType`.

3. **Imported records get empty `gapPositionBreakdownJSON`** — Gap position breakdown is on-device only (not exported per dev notes), so imported records have `Data()` for this field.

### File List

| File | Action |
|------|--------|
| `Peach/Core/Data/CSVExportSchemaV2.swift` | Modified — 16 columns, `continuousRhythmMatching` type |
| `Peach/Core/Data/CSVRecordFormatter.swift` | Modified — all formatters produce 16 fields, added continuous formatter |
| `Peach/Core/Data/CSVImportParser.swift` | Modified — `ImportResult` includes `continuousRhythmMatchings` |
| `Peach/Core/Data/CSVImportParserV1.swift` | Modified — updated `ImportResult` constructions |
| `Peach/Core/Data/CSVImportParserV2.swift` | Modified — added `parseContinuousRhythmMatchingRow()`, cross-type validation |
| `Peach/Core/Data/TrainingDataExporter.swift` | Modified — exports continuous rhythm matching records |
| `Peach/Core/Data/TrainingDataImporter.swift` | Modified — import/merge/replace for continuous rhythm matching |
| `Peach/Core/Data/TrainingDataTransferService.swift` | Modified — preview container, file validation |
| `PeachTests/Core/Data/CSVExportSchemaV2Tests.swift` | Modified — 16-column tests |
| `PeachTests/Core/Data/CSVImportParserTests.swift` | Modified — 16-column V2 rows, round-trip tests |
| `PeachTests/Core/Data/CSVImportParserV2Tests.swift` | Modified — continuous rhythm matching parser tests |
| `PeachTests/Core/Data/CSVRecordFormatterTests.swift` | Modified — 16-column assertions |
| `PeachTests/Core/Data/TrainingDataExporterTests.swift` | Modified — column count update |
| `PeachTests/Core/Data/TrainingDataImporterTests.swift` | Modified — updated summaries |
| `PeachTests/Core/Data/TrainingDataTransferServiceTests.swift` | Modified — updated ImportResult/ImportSummary |
| `PeachTests/Settings/TrainingDataImportActionTests.swift` | Modified — updated ImportResult |

### Change Log

| Change | Reason |
|--------|--------|
| Extended V2 CSV from 15→16 columns | Added `meanOffsetMs` column for continuous rhythm matching |
| Added `parseContinuousRhythmMatchingRow()` | AC #2 — parse and validate continuous rhythm matching rows |
| Added deduplication for continuous rhythm matching | AC #4 — merge mode deduplicates by timestamp+tempoBPM+trainingType |
| Added round-trip test with all 5 training types | AC #6 — export→import cycle preserves all fields |
