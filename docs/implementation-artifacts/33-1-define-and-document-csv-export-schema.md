# Story 33.1: Define and Document CSV Export Schema

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer**,
I want a well-defined CSV schema for training data export,
so that the format is clear, extensible, and spreadsheet-friendly.

## Acceptance Criteria

1. **Given** the export schema, **when** it is defined, **then** it uses a `trainingType` discriminator column with values `comparison` and `pitchMatching`, **and** common columns are: `trainingType`, `timestamp`, `referenceNote`, `referenceNoteName`, `targetNote`, `targetNoteName`, `interval`, `tuningSystem`, **and** comparison-specific columns are: `centOffset`, `isCorrect`, **and** pitch-matching-specific columns are: `initialCentOffset`, `userCentError`, **and** non-applicable cells are left empty.

2. **Given** the `timestamp` column, **when** a record is exported, **then** it uses ISO 8601 format (e.g., `2026-03-03T14:30:00Z`).

3. **Given** the `referenceNoteName` and `targetNoteName` columns, **when** a record is exported, **then** they contain human-readable note names (e.g., `C4`, `A#3`) alongside the MIDI numbers.

4. **Given** a future training type, **when** it is added to the app, **then** new type-specific columns can be appended without breaking existing exports.

## Tasks / Subtasks

- [ ] Task 1: Create `CSVExportSchema` enum in `Core/Data/` (AC: #1, #4)
  - [ ] 1.1 Define column name constants for all 12 columns in canonical order
  - [ ] 1.2 Define `TrainingType` nested enum with `comparison` and `pitchMatching` cases and `csvValue` property
  - [ ] 1.3 Add `headerRow` static property returning the full CSV header string
  - [ ] 1.4 Add `commonColumns` and type-specific column grouping properties for documentation
- [ ] Task 2: Create `CSVRecordFormatter` in `Core/Data/` (AC: #1, #2, #3)
  - [ ] 2.1 Add `format(_ record: ComparisonRecord) -> String` method producing a CSV row
  - [ ] 2.2 Add `format(_ record: PitchMatchingRecord) -> String` method producing a CSV row
  - [ ] 2.3 Timestamp formatting: ISO 8601 with `Date.ISO8601FormatStyle` (UTC timezone)
  - [ ] 2.4 Note name formatting: `MIDINote(rawValue:).name` for human-readable names
  - [ ] 2.5 Interval formatting: `Interval(rawValue:)?.abbreviation` (e.g., `M3`)
  - [ ] 2.6 Tuning system formatting: use storage identifier directly (e.g., `equalTemperament`)
  - [ ] 2.7 Leave non-applicable columns empty (trailing commas for empty fields)
- [ ] Task 3: Write tests for schema and formatter (AC: #1, #2, #3, #4)
  - [ ] 3.1 Test `headerRow` contains all 12 column names in correct order
  - [ ] 3.2 Test `ComparisonRecord` formatting produces correct CSV row with empty pitch-matching fields
  - [ ] 3.3 Test `PitchMatchingRecord` formatting produces correct CSV row with empty comparison fields
  - [ ] 3.4 Test timestamp formatting is ISO 8601 UTC
  - [ ] 3.5 Test note name formatting (edge cases: MIDI 0 → `C-1`, MIDI 127 → `G9`)
  - [ ] 3.6 Test interval abbreviation formatting
  - [ ] 3.7 Test that fields containing commas or quotes are properly escaped (RFC 4180)
  - [ ] 3.8 Test extensibility: adding a column after existing ones doesn't break header order

## Dev Notes

### What This Story Is

A **schema definition and row formatter** story. Creates the types that define the CSV export format and format individual records into CSV rows. Story 33.2 will build the full export service on top of this foundation. No UI changes.

### CSV Column Specification

The canonical column order (all rows must follow this):

| # | Column Name | Type | Source | Applicable To |
|---|---|---|---|---|
| 1 | `trainingType` | String | Discriminator | All |
| 2 | `timestamp` | String | `record.timestamp` → ISO 8601 | All |
| 3 | `referenceNote` | Int | `record.referenceNote` (MIDI number) | All |
| 4 | `referenceNoteName` | String | `MIDINote(record.referenceNote).name` | All |
| 5 | `targetNote` | Int | `record.targetNote` (MIDI number) | All |
| 6 | `targetNoteName` | String | `MIDINote(record.targetNote).name` | All |
| 7 | `interval` | String | `Interval(rawValue: record.interval)?.abbreviation` | All |
| 8 | `tuningSystem` | String | `record.tuningSystem` (storage identifier) | All |
| 9 | `centOffset` | Double | `record.centOffset` | Comparison only |
| 10 | `isCorrect` | Bool | `record.isCorrect` → `true`/`false` | Comparison only |
| 11 | `initialCentOffset` | Double | `record.initialCentOffset` | PitchMatching only |
| 12 | `userCentError` | Double | `record.userCentError` | PitchMatching only |

### Example CSV Output

```csv
trainingType,timestamp,referenceNote,referenceNoteName,targetNote,targetNoteName,interval,tuningSystem,centOffset,isCorrect,initialCentOffset,userCentError
comparison,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,15.5,true,,
comparison,2026-03-03T14:30:05Z,69,A4,62,D4,P5,justIntonation,-8.3,false,,
pitchMatching,2026-03-03T14:31:00Z,60,C4,67,G4,P5,equalTemperament,,,25.0,3.2
```

### Data Model Field Mapping

**ComparisonRecord** (`Core/Data/ComparisonRecord.swift`):
- `referenceNote: Int` — MIDI number (0–127)
- `targetNote: Int` — MIDI number (0–127)
- `centOffset: Double` — signed cents on target note (0.1 cent resolution)
- `isCorrect: Bool` — user answer correctness
- `interval: Int` — `Interval.rawValue` (semitone count 0–12)
- `tuningSystem: String` — `TuningSystem.storageIdentifier` (e.g., `"equalTemperament"`)
- `timestamp: Date` — when the comparison was answered

**PitchMatchingRecord** (`Core/Data/PitchMatchingRecord.swift`):
- `referenceNote: Int` — MIDI number (0–127)
- `targetNote: Int` — MIDI number (0–127)
- `initialCentOffset: Double` — how detuned the target started
- `userCentError: Double` — how far off the user's final tuning was
- `interval: Int` — `Interval.rawValue` (semitone count 0–12)
- `tuningSystem: String` — `TuningSystem.storageIdentifier`
- `timestamp: Date` — when the match was completed

### Formatting Rules

1. **Timestamps**: Use `Date.ISO8601FormatStyle()` — produces UTC strings like `2026-03-03T14:30:00Z`
2. **Note names**: `MIDINote(rawValue:).name` — sharp notation, Scientific Pitch Notation octaves (C4 = MIDI 60)
3. **Intervals**: `Interval(rawValue:)?.abbreviation` — compact standard notation (P1, m2, M2, m3, M3, P4, d5, P5, m6, M6, m7, M7, P8)
4. **Tuning system**: Use `TuningSystem.storageIdentifier` directly — machine-readable, round-trippable via `TuningSystem.fromStorageIdentifier(_:)`
5. **Booleans**: `true`/`false` (lowercase)
6. **Empty fields**: Leave blank between commas (e.g., `,,`)
7. **RFC 4180 compliance**: If any field value contains a comma, quote, or newline, wrap the field in double quotes and escape internal quotes by doubling them. Note names (`C#4`) and current data values don't require this, but the formatter must handle it for correctness.
8. **No BOM**: UTF-8 without byte order mark
9. **Line endings**: `\n` (Unix-style)

### Extensibility Design

New training types can be added by:
1. Adding a new case to `CSVExportSchema.TrainingType`
2. Appending new type-specific columns **after** existing ones (columns 13+)
3. Adding a new `format(_ record: NewRecord) -> String` method
4. Existing exports remain parseable — old columns are unchanged, new columns appear only at the end

### Implementation Approach

**`CSVExportSchema`** — a `nonisolated` enum (no instances, just namespace):
- Column name constants as `static let` properties
- `headerRow: String` — all column names joined by commas
- `TrainingType` nested enum with `.csvValue` for the discriminator string

**`CSVRecordFormatter`** — a `nonisolated` enum (stateless formatter):
- Uses `CSVExportSchema` for column order consistency
- `format(_ record: ComparisonRecord) -> String` — maps record fields to CSV row, leaves pitch-matching columns empty
- `format(_ record: PitchMatchingRecord) -> String` — maps record fields to CSV row, leaves comparison columns empty
- Private helper for RFC 4180 field escaping

Both types are `nonisolated` (pure functions, no state, no MainActor needed). Place in `Core/Data/` alongside the record models.

### Key File: TrainingDataStore

`Peach/Core/Data/TrainingDataStore.swift` — provides `fetchAllComparisons()` and `fetchAllPitchMatchings()` (both return records sorted by timestamp ascending). Story 33.2 will use these to feed records into the formatter.

### Files To Create

| File | Location | Purpose |
|---|---|---|
| `CSVExportSchema.swift` | `Peach/Core/Data/` | Column definitions, header row, training type enum |
| `CSVRecordFormatter.swift` | `Peach/Core/Data/` | Record-to-CSV-row formatting |
| `CSVExportSchemaTests.swift` | `PeachTests/Core/Data/` | Schema structure tests |
| `CSVRecordFormatterTests.swift` | `PeachTests/Core/Data/` | Record formatting tests |

### No Changes Required To

- `TrainingDataStore.swift` — no new fetch methods needed
- `ComparisonRecord.swift` / `PitchMatchingRecord.swift` — models unchanged
- `SettingsScreen.swift` — no UI changes (story 33.3 adds the button)
- Any view or session files

### Testing

**TDD approach**: Write failing tests first for each formatter method, then implement.

**Test data**: Create `ComparisonRecord` and `PitchMatchingRecord` instances using SwiftData in-memory containers (existing test pattern — see `PeachTests/Core/Data/`).

**Edge cases to test**:
- MIDI note 0 → `"C-1"`, MIDI note 127 → `"G9"`
- Zero cent offset → `"0.0"`
- Negative cent offset → `"-8.3"`
- `isCorrect` true/false → `"true"`/`"false"`
- All 13 interval abbreviations
- Both tuning system identifiers
- Empty/missing interval (if `Interval(rawValue:)` returns nil) → empty string

Run full test suite: `bin/test.sh`

### Project Structure Notes

- New files go in `Core/Data/` — alongside the record models they format
- `nonisolated` enums — pure functions, no framework imports needed
- No SwiftUI, UIKit, or AVFoundation imports in Core/ files
- Test files mirror source structure in `PeachTests/Core/Data/`

### References

- [Source: docs/planning-artifacts/epics.md#Epic 33, Story 33.1]
- [Source: docs/project-context.md — file placement, naming, testing rules]
- [Source: Peach/Core/Data/ComparisonRecord.swift — comparison model fields]
- [Source: Peach/Core/Data/PitchMatchingRecord.swift — pitch matching model fields]
- [Source: Peach/Core/Audio/MIDINote.swift — note name formatting]
- [Source: Peach/Core/Audio/Interval.swift — interval abbreviations]
- [Source: Peach/Core/Audio/TuningSystem.swift — storage identifiers]
- [Source: Peach/Core/Data/TrainingDataStore.swift — fetch methods]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
