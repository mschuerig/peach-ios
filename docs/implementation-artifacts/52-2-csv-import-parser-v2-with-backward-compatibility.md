# Story 52.2: CSV Import Parser v2 with Backward Compatibility

Status: ready-for-dev

## Story

As a **developer**,
I want a `CSVImportParserV2` that imports all four training types and maintains V1 backward compatibility,
so that users can import rhythm data and existing pitch exports remain importable (FR102).

## Acceptance Criteria

1. **Given** `CSVImportParserV2` conforms to `CSVVersionedParser`, **when** inspected, **then** it has `supportedVersion: 2`.

2. **Given** a v2 CSV file with all four training types, **when** imported, **then** it correctly parses `pitchDiscrimination`, `pitchMatching`, `rhythmOffsetDetection`, and `rhythmMatching` records.

3. **Given** a v1 CSV file (pitch records only), **when** imported, **then** the existing V1 parser handles it — V1 records remain importable (FR102).

4. **Given** `CSVImportParser`, **when** updated, **then** it registers the V2 parser in the chain alongside V1.

5. **Given** deduplication, **when** importing records that already exist, **then** rhythm records are deduplicated by timestamp + tempo + training type (FR103), **and** pitch records continue to use existing deduplication logic.

6. **Given** `TrainingDataImporter`, **when** updated, **then** it imports rhythm records with deduplication through the V2 parser.

7. **Given** unit tests, **when** they verify V2 import, **then** all four training types parse correctly, V1 backward compatibility is confirmed, and deduplication works.

## Tasks / Subtasks

- [ ] Task 1: Create `CSVImportParserV2` (AC: 1, 2)
  - [ ] Create `Peach/Core/Data/CSVImportParserV2.swift` as `nonisolated struct CSVImportParserV2: CSVVersionedParser`
  - [ ] Set `supportedVersion = 2`
  - [ ] Validate header against `CSVExportSchemaV2.allColumns` (15 columns)
  - [ ] Parse rows by `trainingType` discriminator (column 0): dispatch to pitch or rhythm parsing
  - [ ] Pitch rows: parse columns 2–11 identically to V1 (reuse `parseISO8601`, `abbreviationToRawValue` — extract shared helpers if needed)
  - [ ] Rhythm offset detection rows: parse `tempoBPM` (col 12, Int), `offsetMs` (col 13, Double), `isCorrect` (col 9, Bool), `timestamp` (col 1)
  - [ ] Rhythm matching rows: parse `tempoBPM` (col 12, Int), `userOffsetMs` (col 14, Double), `timestamp` (col 1)
  - [ ] Validate that pitch-specific columns are empty for rhythm rows and vice versa
  - [ ] Write tests first in `PeachTests/Core/Data/CSVImportParserV2Tests.swift`

- [ ] Task 2: Extend `CSVImportParser.ImportResult` for rhythm records (AC: 2, 6)
  - [ ] Add `rhythmOffsetDetections: [RhythmOffsetDetectionRecord]` to `ImportResult`
  - [ ] Add `rhythmMatchings: [RhythmMatchingRecord]` to `ImportResult`
  - [ ] Update all existing `ImportResult` construction sites (V1 parser, `CSVImportParser.parse()` error paths) to pass empty arrays for new fields

- [ ] Task 3: Register V2 parser in `CSVImportParser` (AC: 3, 4)
  - [ ] Add `CSVImportParserV2()` to `CSVImportParser.parsers` array
  - [ ] Verify V1 files still route to `CSVImportParserV1` (version dispatch is already correct)

- [ ] Task 4: Extend `TrainingDataImporter` for rhythm records (AC: 5, 6)
  - [ ] Add `rhythmOffsetDetectionsImported`, `rhythmOffsetDetectionsSkipped`, `rhythmMatchingsImported`, `rhythmMatchingsSkipped` to `ImportSummary`
  - [ ] Update `totalImported` and `totalSkipped` computed properties
  - [ ] **Replace mode:** Update `replaceAll` to pass rhythm records to `store.replaceAllRecords()` — extend the method signature to accept rhythm arrays
  - [ ] **Merge mode:** Fetch existing rhythm records, build `DuplicateKey` entries using `timestamp + tempoBPM + trainingType`, deduplicate and save new records
  - [ ] Add `rhythmOffsetDetection` and `rhythmMatching` cases to `TrainingType` constants

- [ ] Task 5: Update `TrainingDataStore.replaceAllRecords` signature (AC: 6)
  - [ ] Add `rhythmOffsetDetections` and `rhythmMatchings` parameters (default to empty arrays for backward compatibility)
  - [ ] Insert rhythm records in the transaction alongside pitch records

- [ ] Task 6: Update `TrainingDataTransferService` for rhythm-aware import (AC: 2)
  - [ ] Update `readFileForImport` empty-check to also consider rhythm records (currently only checks pitch)
  - [ ] Update `formatImportSummary` to include rhythm record counts

- [ ] Task 7: Write comprehensive tests (AC: 7)
  - [ ] V2 parser: all four training types parse correctly from well-formed CSV
  - [ ] V2 parser: invalid rhythm fields produce appropriate errors
  - [ ] V2 parser: pitch-specific columns must be empty for rhythm rows (and vice versa)
  - [ ] V2 parser: empty rows are skipped
  - [ ] V1 backward compatibility: V1 files still import via V1 parser
  - [ ] V2 parser rejects V1 headers (column count mismatch)
  - [ ] Merge deduplication: rhythm records with same timestamp+tempo+type are skipped
  - [ ] Replace mode: rhythm records are inserted alongside pitch records
  - [ ] Round-trip: export V2 then import V2 produces identical records
  - [ ] Integration: `TrainingDataTransferService.readFileForImport` recognizes rhythm-only files as valid

- [ ] Task 8: Run full test suite
  - [ ] `bin/test.sh` — zero regressions

## Dev Notes

### Architecture — chain of responsibility pattern

The CSV import system uses a **chain-of-responsibility** pattern. `CSVFormatVersionReader` reads the format version from the metadata line, `CSVImportParser` dispatches to the correct `CSVVersionedParser` implementation. Adding V2 support is **additive**: create a new conformance, register it in the `parsers` array. No changes to V1 parser or dispatch logic needed.

Key dispatch code in `CSVImportParser.swift:21`:
```swift
guard let parser = parsers.first(where: { $0.supportedVersion == version }) else { ... }
```

### Files to create

- `Peach/Core/Data/CSVImportParserV2.swift` — new V2 parser conforming to `CSVVersionedParser`
- `PeachTests/Core/Data/CSVImportParserV2Tests.swift` — V2 parser tests

### Files to modify

- `Peach/Core/Data/CSVImportParser.swift` — add rhythm fields to `ImportResult`, register V2 parser
- `Peach/Core/Data/TrainingDataImporter.swift` — add rhythm import/merge/dedup logic, extend `ImportSummary`
- `Peach/Core/Data/TrainingDataStore.swift` — extend `replaceAllRecords` signature to accept rhythm arrays
- `Peach/Core/Data/TrainingDataTransferService.swift` — rhythm-aware empty check and summary formatting
- `PeachTests/Core/Data/CSVImportParserTests.swift` — update for new `ImportResult` fields
- `PeachTests/Core/Data/TrainingDataImporterTests.swift` — rhythm import/merge/dedup tests

### Do NOT modify

- `CSVImportParserV1.swift` — V1 parser must remain unchanged (only update `ImportResult` construction to include empty rhythm arrays)
- `CSVExportSchema.swift` — V1 export schema stays as-is
- `CSVExportSchemaV2.swift` — already complete from story 52.1
- `CSVRecordFormatter.swift` — export-only, no changes needed
- `TrainingDataExporter.swift` — export-only, no changes needed

### V2 column layout reference (from story 52.1)

15 columns total. The V2 header is `CSVExportSchemaV2.allColumns`:

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

### Rhythm record models (stored properties)

**RhythmOffsetDetectionRecord** (`Peach/Core/Data/RhythmOffsetDetectionRecord.swift`):
- `tempoBPM: Int`
- `offsetMs: Double` (signed: negative = early, positive = late)
- `isCorrect: Bool`
- `timestamp: Date`

**RhythmMatchingRecord** (`Peach/Core/Data/RhythmMatchingRecord.swift`):
- `tempoBPM: Int`
- `userOffsetMs: Double` (signed: negative = early, positive = late)
- `timestamp: Date`

### Deduplication design for rhythm records (FR103)

Pitch records use `DuplicateKey(timestamp, referenceNote, targetNote, trainingType)`. Rhythm records have no `referenceNote`/`targetNote` — use `DuplicateKey(timestamp, tempoBPM, trainingType)` instead.

**Option A (recommended):** Create a separate `RhythmDuplicateKey` struct with `timestampSeconds: Int64`, `tempoBPM: Int`, `trainingType: String`. This avoids forcing rhythm-irrelevant fields into the existing key.

**Option B:** Extend existing `DuplicateKey` to make `referenceNote`/`targetNote` optional. This adds complexity to pitch dedup for no benefit.

### `replaceAllRecords` — critical fix from 47.2 review

Current signature only accepts pitch arrays but **deletes all four record types** (lines 88–91 of `TrainingDataStore.swift`). This means a "replace" import silently destroys rhythm data. The fix: extend the signature to also accept and re-insert rhythm arrays:

```swift
func replaceAllRecords(
    pitchDiscriminations: [PitchDiscriminationRecord],
    pitchMatchings: [PitchMatchingRecord],
    rhythmOffsetDetections: [RhythmOffsetDetectionRecord] = [],
    rhythmMatchings: [RhythmMatchingRecord] = []
) throws
```

Default empty arrays preserve backward compatibility with existing call sites.

### `TrainingDataTransferService.readFileForImport` — rhythm-aware empty check

Currently at line 77, the empty check is:
```swift
if parseResult.pitchDiscriminations.isEmpty && parseResult.pitchMatchings.isEmpty
```

Must also check rhythm arrays — a rhythm-only V2 file is valid even with zero pitch records.

### `TrainingDataTransferService.formatImportSummary` — rhythm counts

Currently shows only total imported/skipped. After adding rhythm fields to `ImportSummary`, `totalImported` and `totalSkipped` should automatically include rhythm counts if the computed properties are updated.

### V1 parser shared helpers — extraction consideration

`CSVImportParserV1` contains private helpers: `parseCSVLine`, `parseISO8601`, `abbreviationToRawValue`. V2 needs the same. Two options:

1. **Duplicate in V2** — simple, no V1 changes, but code duplication
2. **Extract to shared enum** (e.g., `CSVParserHelpers`) — cleaner, but modifies the V1 file

Prefer option 2 only if the duplication is substantial. `parseCSVLine` is ~40 lines and would benefit from sharing. `parseISO8601` is 4 lines. Consider extracting `parseCSVLine` and `parseISO8601` to a shared `CSVParserHelpers` enum in a new file `Peach/Core/Data/CSVParserHelpers.swift`, then have both V1 and V2 call through to it. This is not a refactoring-for-refactoring's-sake — it prevents divergent CSV parsing bugs.

### Testing patterns

Follow existing conventions in `CSVImportParserV1Tests.swift` and `TrainingDataImporterTests.swift`:
- `@Suite` / `@Test` with behavioral descriptions
- `async` test functions
- In-memory `ModelContainer` with `ModelConfiguration(isStoredInMemoryOnly: true)`
- Factory methods for test records
- Build CSV strings manually to test specific edge cases

### TrainingDataStore fetch methods for rhythm merge

- `store.fetchAllRhythmOffsetDetections() throws -> [RhythmOffsetDetectionRecord]`
- `store.fetchAllRhythmMatchings() throws -> [RhythmMatchingRecord]`
- `store.save(_ record: RhythmOffsetDetectionRecord) throws`
- `store.save(_ record: RhythmMatchingRecord) throws`

### Previous story intelligence (52.1)

- 52.1 extended pitch `format()` methods to produce 15-column V2 rows (3 empty rhythm fields appended)
- V2 export uses `CSVExportSchemaV2.metadataLine` (`# peach-export-format:2`) and `CSVExportSchemaV2.headerRow`
- Round-trip test confirmed V1 parser rejects V2 format — this is expected and correct
- Full suite: 1403 tests pass

### Project Structure Notes

- All new files in `Core/Data/` — correct placement per project-context.md
- No SwiftUI imports needed — pure data layer work
- All types are `nonisolated` enums/structs (matching V1 pattern)
- `Sendable` conformance is natural via value types

### References

- [Source: docs/planning-artifacts/epics.md — Epic 52, Story 52.2]
- [Source: docs/planning-artifacts/prd.md — FR100, FR101, FR102, FR103]
- [Source: docs/implementation-artifacts/52-1-csv-export-schema-v2.md — previous story context]
- [Source: Peach/Core/Data/CSVVersionedParser.swift — protocol to conform to]
- [Source: Peach/Core/Data/CSVImportParser.swift — dispatcher to register in]
- [Source: Peach/Core/Data/CSVImportParserV1.swift — V1 parser pattern to follow]
- [Source: Peach/Core/Data/CSVExportSchemaV2.swift — V2 column layout and TrainingType enum]
- [Source: Peach/Core/Data/TrainingDataImporter.swift — merge/dedup/replace logic to extend]
- [Source: Peach/Core/Data/TrainingDataStore.swift — replaceAllRecords, rhythm fetch/save methods]
- [Source: Peach/Core/Data/TrainingDataTransferService.swift — readFileForImport empty check, formatImportSummary]
- [Source: Peach/Core/Data/CSVImportError.swift — error types for invalid rows]
- [Source: Peach/Core/Data/RhythmOffsetDetectionRecord.swift — stored properties]
- [Source: Peach/Core/Data/RhythmMatchingRecord.swift — stored properties]
- [Source: docs/project-context.md — testing rules, file placement, Swift 6.2 conventions]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
