# Story 52.1: CSV Export Schema v2

Status: ready-for-dev

## Story

As a **developer**,
I want a `CSVExportSchemaV2` that exports all four training types with a `trainingType` discriminator column,
so that rhythm training data can be exported alongside pitch data (FR100, FR101).

## Acceptance Criteria

1. **Given** `CSVExportSchemaV2`, **when** it formats export data, **then** each row includes a `trainingType` column with values: `pitchDiscrimination`, `pitchMatching`, `rhythmOffsetDetection`, `rhythmMatching`.

2. **Given** rhythm offset detection records, **when** exported, **then** type-specific columns include `tempoBPM`, `offsetMs`, `isCorrect`, `timestamp`.

3. **Given** rhythm matching records, **when** exported, **then** type-specific columns include `tempoBPM`, `userOffsetMs`, `timestamp`.

4. **Given** `TrainingDataExporter`, **when** updated, **then** it exports all four record types using the v2 schema.

5. **Given** unit tests, **when** they verify v2 export, **then** output CSV contains correct headers, discriminators, and type-specific columns for all four training types.

## Tasks / Subtasks

- [ ] Task 1: Create `CSVExportSchemaV2` (AC: 1, 2, 3)
  - [ ] Define `CSVExportSchemaV2` enum in `Peach/Core/Data/CSVExportSchemaV2.swift`
  - [ ] Set `formatVersion = 2`, reuse `metadataPrefix` from existing schema
  - [ ] Add `TrainingType` enum with four cases: `.pitchDiscrimination`, `.pitchMatching`, `.rhythmOffsetDetection`, `.rhythmMatching`
  - [ ] Define column layout: common columns + pitch-specific (empty for rhythm) + rhythm-specific (empty for pitch)
  - [ ] Write tests first in `PeachTests/Core/Data/CSVExportSchemaV2Tests.swift`

- [ ] Task 2: Extend `CSVRecordFormatter` with rhythm formatting (AC: 2, 3)
  - [ ] Add `static func format(_ record: RhythmOffsetDetectionRecord) -> String` using v2 column layout
  - [ ] Add `static func format(_ record: RhythmMatchingRecord) -> String` using v2 column layout
  - [ ] Pitch-specific columns are empty for rhythm rows; rhythm-specific columns are empty for pitch rows
  - [ ] Write tests first in `CSVRecordFormatterTests.swift`

- [ ] Task 3: Update `TrainingDataExporter` to export all four types (AC: 4)
  - [ ] Fetch `RhythmOffsetDetectionRecord` and `RhythmMatchingRecord` from store
  - [ ] Merge all four record type arrays into timestamp-sorted output
  - [ ] Use `CSVExportSchemaV2` metadata and header
  - [ ] Write tests first in `TrainingDataExporterTests.swift`

- [ ] Task 4: Write comprehensive tests (AC: 5)
  - [ ] Test v2 header contains all columns (common + pitch-specific + rhythm-specific)
  - [ ] Test mixed export: pitch + rhythm records interleaved by timestamp
  - [ ] Test rhythm-only export
  - [ ] Test empty export (header only)
  - [ ] Test round-trip: export produces valid CSV with correct discriminators

- [ ] Task 5: Run full test suite
  - [ ] `bin/test.sh` — zero regressions

## Dev Notes

### Existing architecture — what to reuse, what NOT to reinvent

The CSV export/import system already has a well-established chain-of-responsibility pattern. This story extends the **export side only** (import is story 52.2).

**Key files to modify or extend:**
- `Peach/Core/Data/CSVRecordFormatter.swift` — add two new `format()` overloads
- `Peach/Core/Data/TrainingDataExporter.swift` — fetch rhythm records and merge into output

**Key file to create:**
- `Peach/Core/Data/CSVExportSchemaV2.swift` — new schema enum (do NOT modify `CSVExportSchema.swift` — V1 must remain intact for backward compatibility)

**Do NOT modify:**
- `CSVExportSchema.swift` — V1 schema stays as-is
- `CSVImportParser.swift` — import changes belong to story 52.2
- `CSVImportParserV1.swift` — must remain untouched
- `TrainingDataImporter.swift` — import changes belong to story 52.2

### Column layout design

V2 extends V1's 12 columns with 3 rhythm-specific columns (indices 12–14). The first 12 columns are identical to V1 for maximum compatibility:

| Index | Column | PitchDisc | PitchMatch | RhythmOffset | RhythmMatch |
|-------|--------|-----------|------------|--------------|-------------|
| 0 | trainingType | pitchDiscrimination | pitchMatching | rhythmOffsetDetection | rhythmMatching |
| 1 | timestamp | ISO 8601 | ISO 8601 | ISO 8601 | ISO 8601 |
| 2 | referenceNote | MIDI 0-127 | MIDI 0-127 | (empty) | (empty) |
| 3 | referenceNoteName | e.g. "C4" | e.g. "C4" | (empty) | (empty) |
| 4 | targetNote | MIDI 0-127 | MIDI 0-127 | (empty) | (empty) |
| 5 | targetNoteName | e.g. "E4" | e.g. "E4" | (empty) | (empty) |
| 6 | interval | abbreviation | abbreviation | (empty) | (empty) |
| 7 | tuningSystem | identifier | identifier | (empty) | (empty) |
| 8 | centOffset | Double | (empty) | (empty) | (empty) |
| 9 | isCorrect | true/false | (empty) | true/false | (empty) |
| 10 | initialCentOffset | (empty) | Double | (empty) | (empty) |
| 11 | userCentError | (empty) | Double | (empty) | (empty) |
| 12 | tempoBPM | (empty) | (empty) | Int | Int |
| 13 | offsetMs | (empty) | (empty) | Double | (empty) |
| 14 | userOffsetMs | (empty) | (empty) | (empty) | Double |

**Design rationale:**
- Column 9 (`isCorrect`) is reused by `rhythmOffsetDetection` — it has the same semantics (Boolean correctness flag)
- Columns 12–14 are rhythm-specific; empty for pitch rows
- Columns 2–8, 10–11 are pitch-specific; empty for rhythm rows
- `timestamp` (column 1) and `trainingType` (column 0) are shared by all types

### Record models — stored properties reference

**RhythmOffsetDetectionRecord** (`Peach/Core/Data/RhythmOffsetDetectionRecord.swift`):
- `tempoBPM: Int`
- `offsetMs: Double` (signed: negative = early, positive = late)
- `isCorrect: Bool`
- `timestamp: Date`

**RhythmMatchingRecord** (`Peach/Core/Data/RhythmMatchingRecord.swift`):
- `tempoBPM: Int`
- `userOffsetMs: Double` (signed: negative = early, positive = late)
- `timestamp: Date`

### TrainingDataStore fetch methods to use

- `store.fetchAllRhythmOffsetDetections() throws -> [RhythmOffsetDetectionRecord]`
- `store.fetchAllRhythmMatchings() throws -> [RhythmMatchingRecord]`

Both return records sorted by timestamp ascending — same pattern as pitch fetches.

### CSVRecordFormatter pattern to follow

Existing `format()` methods in `CSVRecordFormatter.swift` build a comma-separated row from fields in column order, using:
- `formatTimestamp(_ date: Date) -> String` — ISO 8601 without fractional seconds
- `formatDouble(_ value: Double) -> String` — ensures ".0" suffix on whole numbers
- `escapeField(_ field: String) -> String` — RFC 4180 quoting

Rhythm `format()` overloads follow the same pattern: pitch-specific fields are empty strings, rhythm-specific fields are populated. `isCorrect` for `rhythmOffsetDetection` uses the same `"\(record.isCorrect)"` format.

### TrainingDataExporter merge pattern

Currently merges pitch discrimination + pitch matching into `[(timestamp: Date, row: String)]`, sorts, joins. Extend to also fetch + format rhythm records into the same merged array. The v2 exporter uses `CSVExportSchemaV2.metadataLine` and `CSVExportSchemaV2.headerRow`.

### Testing patterns

Follow existing test conventions in `CSVExportSchemaTests.swift`, `CSVRecordFormatterTests.swift`, `TrainingDataExporterTests.swift`:
- Use `@Suite` / `@Test` with behavioral descriptions
- `async` test functions
- In-memory `ModelContainer` with `ModelConfiguration(isStoredInMemoryOnly: true)`
- Factory methods for test records

### Project Structure Notes

- New file: `Peach/Core/Data/CSVExportSchemaV2.swift`
- New test file: `PeachTests/Core/Data/CSVExportSchemaV2Tests.swift`
- Modified: `Peach/Core/Data/CSVRecordFormatter.swift`
- Modified: `Peach/Core/Data/TrainingDataExporter.swift`
- Modified: `PeachTests/Core/Data/CSVRecordFormatterTests.swift`
- Modified: `PeachTests/Core/Data/TrainingDataExporterTests.swift`
- All files in `Core/Data/` — correct placement per project-context.md

### References

- [Source: docs/planning-artifacts/epics.md — Epic 52, Story 52.1]
- [Source: docs/planning-artifacts/prd.md — FR100, FR101]
- [Source: Peach/Core/Data/CSVExportSchema.swift — V1 schema, column layout]
- [Source: Peach/Core/Data/CSVRecordFormatter.swift — format() pattern, timestamp/double formatting]
- [Source: Peach/Core/Data/TrainingDataExporter.swift — merge + sort + export pattern]
- [Source: Peach/Core/Data/RhythmOffsetDetectionRecord.swift — stored properties]
- [Source: Peach/Core/Data/RhythmMatchingRecord.swift — stored properties]
- [Source: Peach/Core/Data/TrainingDataStore.swift — fetchAllRhythmOffsetDetections(), fetchAllRhythmMatchings()]
- [Source: docs/project-context.md — testing rules, file placement, Swift 6.2 conventions]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
