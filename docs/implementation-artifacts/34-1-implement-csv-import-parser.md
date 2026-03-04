# Story 34.1: Implement CSV Import Parser

Status: review

## Story

As a **developer**,
I want a parser that reads the export CSV format and converts rows back to record objects,
So that import logic is testable and decoupled from the UI.

## Acceptance Criteria

1. **Given** a valid CSV file matching the export schema **When** it is parsed **Then** each row is mapped to the correct record type based on the `trainingType` column **And** `ComparisonRecord` fields are populated: referenceNote, targetNote, centOffset, isCorrect, interval, tuningSystem, timestamp **And** `PitchMatchingRecord` fields are populated: referenceNote, targetNote, initialCentOffset, userCentError, interval, tuningSystem, timestamp

2. **Given** a CSV with invalid headers **When** it is parsed **Then** a descriptive validation error is returned

3. **Given** a CSV with rows containing invalid data (out-of-range MIDI notes, non-numeric cent values, etc.) **When** it is parsed **Then** invalid rows are collected as errors with row numbers **And** valid rows are still parsed successfully

4. **Given** the parser **When** unit tests are run **Then** parsing is verified for valid data, missing columns, invalid values, empty files, and mixed record types

## Tasks / Subtasks

- [x] Task 1: Define CSVImportError type (AC: #2, #3)
  - [x] 1.1 Write tests for error type construction and descriptive messages
  - [x] 1.2 Create `CSVImportError` enum in `Peach/Core/Data/CSVImportError.swift`
  - [x] 1.3 Cases: `invalidHeader(expected:actual:)`, `invalidRowData(row:column:value:reason:)`
- [x] Task 2: Define CSVImportResult type (AC: #1, #3)
  - [x] 2.1 Write tests for result type holding both records and errors
  - [x] 2.2 Create `CSVImportResult` struct in `CSVImportParser.swift` (nested type)
  - [x] 2.3 Fields: `comparisons: [ComparisonRecord]`, `pitchMatchings: [PitchMatchingRecord]`, `errors: [CSVImportError]`
- [x] Task 3: Implement header validation (AC: #2)
  - [x] 3.1 Write tests: valid header passes, missing column fails, extra column fails, wrong order fails
  - [x] 3.2 Implement `validateHeader(_:)` comparing against `CSVExportSchema.allColumns`
- [x] Task 4: Implement RFC 4180 CSV line parsing (AC: #1, #3)
  - [x] 4.1 Write tests: unescaped fields, quoted fields with commas, quoted fields with embedded quotes, fields with newlines
  - [x] 4.2 Implement `parseCSVLine(_:)` returning `[String]` handling RFC 4180 escaping
- [x] Task 5: Implement field-level parsing and validation (AC: #1, #3)
  - [x] 5.1 Write tests: valid/invalid training type, timestamp, MIDI notes (0-127), doubles, booleans, interval abbreviations, tuning system identifiers
  - [x] 5.2 Implement interval abbreviation reverse lookup (abbreviation string to `Int` raw value)
  - [x] 5.3 Implement field parsers for each column type
- [x] Task 6: Implement row-to-record conversion (AC: #1, #3)
  - [x] 6.1 Write tests: valid comparison row, valid pitch matching row, row with wrong column count, row with invalid field, type-specific empty field validation
  - [x] 6.2 Implement `parseRow(_:rowNumber:)` dispatching by trainingType to build ComparisonRecord or PitchMatchingRecord
- [x] Task 7: Implement top-level parse method (AC: #1, #2, #3, #4)
  - [x] 7.1 Write tests: complete valid CSV with mixed types, header-only CSV, invalid header CSV, CSV with mix of valid/invalid rows, empty string input
  - [x] 7.2 Implement `CSVImportParser.parse(_:) -> CSVImportResult`
  - [x] 7.3 Verify all rows processed even when some fail (error collection, not early abort)
- [x] Task 8: Run full test suite (AC: #4)
  - [x] 8.1 Run `bin/test.sh` and verify zero regressions

## Dev Notes

### Architecture Pattern

`CSVImportParser` is the inverse of `CSVRecordFormatter` + `TrainingDataExporter`. Follow the same stateless enum pattern:

```
nonisolated enum CSVImportParser {
    static func parse(_ csvContent: String) -> CSVImportResult
}
```

The parser is **pure computation** — no I/O, no SwiftData, no side effects. It returns parsed record objects and collected errors. The caller (story 34.2) handles persistence through `TrainingDataStore`.

**Do NOT mark as `nonisolated`** unless the compiler requires it. Default MainActor isolation applies project-wide (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`). However, since this parser does not call any MainActor-isolated types and only works with strings and record construction, `nonisolated` is appropriate here — the record model inits and `CSVExportSchema` are all `nonisolated`.

**Lesson from story 33.1:** `CSVRecordFormatter` was initially `nonisolated` but broke because it called `MIDINote.name` and `Interval.abbreviation` (MainActor). The *import* parser does NOT need note names or interval names — it only needs `Interval(rawValue:)` which is `nonisolated`. So `nonisolated enum CSVImportParser` should compile cleanly.

### CSV Format Reference

The parser reads the exact format `TrainingDataExporter` produces. 12 columns in fixed order:

```
trainingType,timestamp,referenceNote,referenceNoteName,targetNote,targetNoteName,interval,tuningSystem,centOffset,isCorrect,initialCentOffset,userCentError
```

- `trainingType`: `"comparison"` or `"pitchMatching"` (discriminator)
- `timestamp`: ISO 8601 UTC with `Z` suffix (e.g., `2026-03-03T14:30:00Z`)
- `referenceNote`, `targetNote`: MIDI integers 0-127
- `referenceNoteName`, `targetNoteName`: **display-only, ignore on import** (e.g., `C4`, `A#3`)
- `interval`: abbreviation string — must reverse-map to semitone count (see table below)
- `tuningSystem`: `"equalTemperament"` or `"justIntonation"` — validate via `TuningSystem.fromStorageIdentifier(_:)`
- `centOffset`, `isCorrect`: comparison-only (empty for pitchMatching)
- `initialCentOffset`, `userCentError`: pitchMatching-only (empty for comparison)

**Interval abbreviation to rawValue mapping:**

| Abbreviation | rawValue | Abbreviation | rawValue |
|---|---|---|---|
| P1 | 0 | P5 | 7 |
| m2 | 1 | m6 | 8 |
| M2 | 2 | M6 | 9 |
| m3 | 3 | m7 | 10 |
| M3 | 4 | M7 | 11 |
| P4 | 5 | P8 | 12 |
| d5 | 6 | | |

Build a reverse lookup from `Interval.allCases` mapping `abbreviation` to `rawValue`. Since `Interval` is `nonisolated`, this works without actor isolation issues.

### RFC 4180 Escaping (Must Handle on Import)

The export uses `CSVRecordFormatter.escapeField(_:)` which wraps fields containing `,`, `"`, or `\n` in double quotes and doubles internal quotes. The import parser must reverse this:
- If field starts and ends with `"`: strip outer quotes, replace `""` with `"`
- Handle newlines within quoted fields (field spans multiple lines)
- Unquoted fields: use as-is

### Field Validation Rules

| Field | Type | Valid Range | Invalid Example |
|---|---|---|---|
| trainingType | String | `"comparison"`, `"pitchMatching"` | `"unknown"` |
| timestamp | Date | ISO 8601 UTC with Z | `"2026-03-03"`, `"not-a-date"` |
| referenceNote | Int | 0-127 | `128`, `-1`, `"abc"` |
| targetNote | Int | 0-127 | `999`, `""` |
| interval | String | 13 valid abbreviations | `"P6"`, `""` |
| tuningSystem | String | `"equalTemperament"`, `"justIntonation"` | `"pythagorean"` |
| centOffset | Double | any double (comparison only) | `"abc"` |
| isCorrect | Bool | `"true"`, `"false"` (comparison only) | `"True"`, `"1"` |
| initialCentOffset | Double | any double (pitchMatching only) | `"abc"` |
| userCentError | Double | any double (pitchMatching only) | `"abc"` |

**Type-specific empty field rules:**
- Comparison rows: `initialCentOffset` and `userCentError` MUST be empty
- PitchMatching rows: `centOffset` and `isCorrect` MUST be empty

### Error Collection Strategy

The parser MUST NOT abort on the first invalid row. It collects errors with row numbers (row 1 = first data row after header) and continues parsing. The `CSVImportResult` contains both successfully parsed records and the error list.

### Existing Code to Reuse (Do NOT Reinvent)

| What | Where | How to Use |
|---|---|---|
| Column names & order | `CSVExportSchema.allColumns` | Validate header exactly |
| Training type values | `CSVExportSchema.TrainingType.comparison.csvValue` / `.pitchMatching.csvValue` | Match trainingType field |
| Interval reverse lookup | `Interval.allCases` + `.abbreviation` + `.rawValue` | Build `[String: Int]` dictionary |
| Tuning system validation | `TuningSystem.fromStorageIdentifier(_:)` | Validate tuningSystem field, returns nil for invalid |
| Record constructors | `ComparisonRecord(referenceNote:targetNote:centOffset:isCorrect:interval:tuningSystem:timestamp:)` | Build from parsed fields |
| Record constructors | `PitchMatchingRecord(referenceNote:targetNote:initialCentOffset:userCentError:interval:tuningSystem:timestamp:)` | Build from parsed fields |

### Testing Patterns

Follow the Swift Testing conventions from the export tests:

```swift
@Suite("CSVImportParser")
struct CSVImportParserTests {
    // Helper to build a CSV string from header + rows
    private func makeCSV(_ rows: [String]) -> String {
        ([CSVExportSchema.headerRow] + rows).joined(separator: "\n")
    }

    @Test("parses valid comparison record")
    func parsesValidComparison() async { ... }
}
```

- **No XCTest** — only `@Test`, `@Suite`, `#expect()`
- **All test functions `async`** — even if logic is synchronous
- **No `test` prefix** — use behavioral names
- **Struct-based suites** — no classes, no setUp/tearDown
- Test file: `PeachTests/Core/Data/CSVImportParserTests.swift`

### File Locations

| New File | Path |
|---|---|
| CSVImportParser.swift | `Peach/Core/Data/CSVImportParser.swift` |
| CSVImportError.swift | `Peach/Core/Data/CSVImportError.swift` |
| CSVImportParserTests.swift | `PeachTests/Core/Data/CSVImportParserTests.swift` |

**No modifications to existing files required.** The parser is self-contained.

### Project Structure Notes

- Follows `Core/Data/` placement consistent with `CSVExportSchema`, `CSVRecordFormatter`, `TrainingDataExporter`
- Test file mirrors source at `PeachTests/Core/Data/`
- No new dependencies, no environment keys, no composition root changes (parser is a pure utility)

### References

- [Source: Peach/Core/Data/CSVExportSchema.swift] — Column definitions and header row
- [Source: Peach/Core/Data/CSVRecordFormatter.swift] — Export format details and RFC 4180 escaping
- [Source: Peach/Core/Data/TrainingDataExporter.swift] — Export service pattern to mirror
- [Source: Peach/Core/Data/ComparisonRecord.swift] — Data model with init signature
- [Source: Peach/Core/Data/PitchMatchingRecord.swift] — Data model with init signature
- [Source: Peach/Core/Audio/Interval.swift] — Interval enum with abbreviation and rawValue
- [Source: Peach/Core/Audio/TuningSystem.swift:77-83] — `fromStorageIdentifier(_:)` for validation
- [Source: docs/planning-artifacts/epics.md#Epic 34] — Epic and story definitions
- [Source: docs/project-context.md] — TDD workflow, testing conventions, commit format

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Concurrency fix: Removed `Sendable` from `CSVImportParser.Result` since `@Model` classes are not `Sendable`
- Concurrency fix: Used inline tuning system validation instead of calling MainActor-isolated `TuningSystem.fromStorageIdentifier(_:)` from `nonisolated` context
- Concurrency fix: Replaced `ISO8601DateFormatter` static property with `Date.ISO8601FormatStyle` to avoid non-Sendable static state

### Completion Notes List

- Implemented `CSVImportError` enum with `invalidHeader` and `invalidRowData` cases, conforming to `LocalizedError`
- Implemented `CSVImportParser` as `nonisolated enum` with nested `Result` struct
- Header validation compares against `CSVExportSchema.allColumns` exactly
- RFC 4180 CSV line parser handles quoted fields with commas, embedded quotes, and newlines
- Field-level validation for all 12 columns: training type, timestamp (ISO 8601), MIDI notes (0-127), interval abbreviations, tuning system identifiers, doubles, booleans
- Type-specific empty field enforcement: comparison rows must have empty pitchMatching fields and vice versa
- Interval abbreviation reverse lookup built from `Interval.allCases`
- Error collection strategy: continues parsing after invalid rows, collecting errors with row numbers
- 72 tests covering all ACs: valid data, invalid headers, invalid fields, edge cases (MIDI 0/127), mixed record types, empty input
- Full suite: 899 tests, zero regressions

### File List

- `Peach/Core/Data/CSVImportError.swift` (new)
- `Peach/Core/Data/CSVImportParser.swift` (new)
- `PeachTests/Core/Data/CSVImportParserTests.swift` (new)

### Change Log

- 2026-03-04: Implemented CSV import parser with error types, header validation, RFC 4180 parsing, field-level validation, row-to-record conversion, and comprehensive tests (72 new tests)
