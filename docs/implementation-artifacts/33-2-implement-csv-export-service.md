# Story 33.2: Implement CSV Export Service

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer**,
I want an export service that generates a CSV file from all training records,
so that the export logic is testable and decoupled from the UI.

## Acceptance Criteria

1. **Given** a `TrainingDataExporter` in `Core/Data/`, **when** `export(from:)` is called with a `TrainingDataStore`, **then** it queries all `ComparisonRecord`s and `PitchMatchingRecord`s, **and** generates a CSV string with headers and data rows, **and** rows are sorted by timestamp ascending.

2. **Given** the generated CSV, **when** opened in a spreadsheet application, **then** columns are correctly separated and parseable, **and** special characters in note names do not break parsing.

3. **Given** no training data exists, **when** `export(from:)` is called, **then** it returns only the header row.

4. **Given** the export service, **when** unit tests are run, **then** CSV generation is verified for both record types, mixed data, edge cases, and empty data.

## Tasks / Subtasks

- [x] Task 1: Create `TrainingDataExporter` enum in `Core/Data/` (AC: #1, #2, #3)
  - [x] 1.1 Add `static func export(from store: TrainingDataStore) throws -> String`
  - [x] 1.2 Fetch all comparisons and pitch matchings from the store
  - [x] 1.3 Merge both arrays into timestamped tuples, sort by timestamp ascending
  - [x] 1.4 Format each record using `CSVRecordFormatter.format(_:)`
  - [x] 1.5 Combine header row + data rows with `\n` line endings
  - [x] 1.6 Return header-only string when no records exist
- [x] Task 2: Write tests for `TrainingDataExporter` (AC: #1, #2, #3, #4)
  - [x] 2.1 Test export with mixed comparison and pitch matching records produces correctly sorted CSV
  - [x] 2.2 Test export with only comparison records
  - [x] 2.3 Test export with only pitch matching records
  - [x] 2.4 Test export with no records returns header row only
  - [x] 2.5 Test timestamp ordering across mixed record types
  - [x] 2.6 Test that CSV output starts with the correct header row
  - [x] 2.7 Test that row count equals record count + 1 (header)

## Dev Notes

### What This Story Is

A **service assembly** story. Creates the `TrainingDataExporter` that orchestrates fetching records from `TrainingDataStore` and formatting them using `CSVRecordFormatter` (both from story 33.1). The exporter merges both record types, sorts by timestamp, and produces a complete CSV string. No UI changes. Story 33.3 will use this service to power the share sheet.

### Design: `TrainingDataExporter`

A stateless `enum` with a single static method (same pattern as `CSVRecordFormatter` and `CSVExportSchema`):

```swift
enum TrainingDataExporter {
    static func export(from store: TrainingDataStore) throws -> String
}
```

**Why enum, not class/struct?** No state, no instances needed. Matches the existing `CSVExportSchema` and `CSVRecordFormatter` pattern in this epic.

**Why not `nonisolated`?** `TrainingDataStore.fetchAllComparisons()` and `fetchAllPitchMatchings()` are implicitly `@MainActor` (project uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`). The exporter calls these methods, so it must also be MainActor. Do **not** mark it `nonisolated` — it will fail to compile.

### Algorithm

1. `let comparisons = try store.fetchAllComparisons()` — already sorted by timestamp ascending
2. `let pitchMatchings = try store.fetchAllPitchMatchings()` — already sorted by timestamp ascending
3. Create a merged array of `(timestamp: Date, row: String)` tuples:
   - Map each `ComparisonRecord` to `(record.timestamp, CSVRecordFormatter.format(record))`
   - Map each `PitchMatchingRecord` to `(record.timestamp, CSVRecordFormatter.format(record))`
4. Sort merged array by `timestamp` ascending (both input arrays are pre-sorted, but after merging they need re-sorting)
5. Build result: `CSVExportSchema.headerRow` + `\n` + rows joined by `\n`
6. If no records: return `CSVExportSchema.headerRow` only (no trailing newline)

### Error Handling

- Propagate `DataStoreError.fetchFailed` from `TrainingDataStore` — do not catch or wrap it
- The caller (story 33.3's UI) will handle errors at the view level
- No new error types needed — `throws` is sufficient

### Formatting Rules (established in story 33.1)

- Line endings: `\n` (Unix-style)
- No BOM (UTF-8 without byte order mark)
- No trailing newline after last row
- RFC 4180 escaping handled by `CSVRecordFormatter.escapeField(_:)` (already implemented)

### Existing Types to Reuse (DO NOT RECREATE)

| Type | Location | Purpose |
|---|---|---|
| `CSVExportSchema` | `Peach/Core/Data/CSVExportSchema.swift` | `.headerRow` for CSV header |
| `CSVRecordFormatter` | `Peach/Core/Data/CSVRecordFormatter.swift` | `.format(_:)` for record rows |
| `TrainingDataStore` | `Peach/Core/Data/TrainingDataStore.swift` | `.fetchAllComparisons()`, `.fetchAllPitchMatchings()` |
| `ComparisonRecord` | `Peach/Core/Data/ComparisonRecord.swift` | SwiftData `@Model` |
| `PitchMatchingRecord` | `Peach/Core/Data/PitchMatchingRecord.swift` | SwiftData `@Model` |
| `DataStoreError` | `Peach/Core/Data/DataStoreError.swift` | Error type propagated from store |

### Files To Create

| File | Location | Purpose |
|---|---|---|
| `TrainingDataExporter.swift` | `Peach/Core/Data/` | Export service: fetch + merge + sort + format |
| `TrainingDataExporterTests.swift` | `PeachTests/Core/Data/` | Full test coverage |

### No Changes Required To

- `CSVExportSchema.swift` — used as-is for header
- `CSVRecordFormatter.swift` — used as-is for row formatting
- `TrainingDataStore.swift` — existing fetch methods are sufficient
- `ComparisonRecord.swift` / `PitchMatchingRecord.swift` — models unchanged
- `SettingsScreen.swift` — no UI changes (story 33.3)
- `PeachApp.swift` — no new environment injection needed (exporter is stateless)

### Testing

**TDD approach**: Write failing tests first, then implement.

**Test infrastructure** (existing pattern from `TrainingDataStoreTests`):
```swift
private func makeTestContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: ComparisonRecord.self, PitchMatchingRecord.self, configurations: config)
}
```

Create a `TrainingDataStore` with in-memory `ModelContext`, insert records, then call `TrainingDataExporter.export(from:)` and verify the CSV string output.

**Key test scenarios:**
- Mixed records (comparison + pitch matching) → verify interleaved timestamp sorting
- Single type only → verify correct output with empty fields for the other type
- Empty store → verify header-only output (just `CSVExportSchema.headerRow`)
- Row count = number of records + 1 (header row)
- First line is always the header row
- Records with same timestamp → deterministic ordering (stable sort)

**Test data creation**: Use `ComparisonRecord(...)` and `PitchMatchingRecord(...)` directly — same pattern as `CSVRecordFormatterTests`. Save to store via `store.save(_:)`, then export.

Run full test suite: `bin/test.sh`

### Project Structure Notes

- `TrainingDataExporter.swift` goes in `Core/Data/` — alongside the schema and formatter it orchestrates
- Default MainActor isolation (do not add `nonisolated`)
- No `import SwiftUI` or `import UIKit` — this is Core/ code
- `import Foundation` only if needed (for `Date`); may not be needed if only using types from the app module
- Test file mirrors source: `PeachTests/Core/Data/TrainingDataExporterTests.swift`

### Previous Story Intelligence (33.1)

**Learnings from story 33.1:**
- `CSVRecordFormatter` was initially marked `nonisolated` but failed to compile because `MIDINote.init(_:)`, `MIDINote.name`, and `Interval.abbreviation` were implicitly `@MainActor`. After code review, those types were made `nonisolated`. However, `TrainingDataExporter` calls `TrainingDataStore` which IS MainActor — so the exporter must stay MainActor.
- Tests for 33.1 did NOT need SwiftData containers — they created record instances directly without persisting. For 33.2, tests WILL need in-memory SwiftData containers because the exporter calls `store.fetchAllComparisons()` / `fetchAllPitchMatchings()`.
- The `fixedDate()` helper pattern from `CSVRecordFormatterTests` can be adapted for creating test records with controlled timestamps.

**Files created in 33.1** (your foundation):
- `Peach/Core/Data/CSVExportSchema.swift` — column definitions, header row
- `Peach/Core/Data/CSVRecordFormatter.swift` — record-to-row formatting
- `PeachTests/Core/Data/CSVExportSchemaTests.swift` — schema tests
- `PeachTests/Core/Data/CSVRecordFormatterTests.swift` — formatter tests

### References

- [Source: docs/planning-artifacts/epics.md#Epic 33, Story 33.2]
- [Source: docs/project-context.md — file placement, naming, testing rules, MainActor isolation]
- [Source: Peach/Core/Data/TrainingDataStore.swift — fetchAllComparisons(), fetchAllPitchMatchings()]
- [Source: Peach/Core/Data/CSVExportSchema.swift — headerRow]
- [Source: Peach/Core/Data/CSVRecordFormatter.swift — format(_:) methods]
- [Source: Peach/Core/Data/DataStoreError.swift — error types propagated]
- [Source: PeachTests/Core/Data/TrainingDataStoreTests.swift — in-memory SwiftData test pattern]
- [Source: PeachTests/Core/Data/CSVRecordFormatterTests.swift — test data creation pattern]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Initial build had a compile error: optional `Substring?` compared directly with `String` in `csvStartsWithHeader` test. Fixed by unwrapping via `lines` array indexing.

### Completion Notes List

- Created `TrainingDataExporter` as a stateless `enum` with a single `static func export(from:)` method, following the same pattern as `CSVExportSchema` and `CSVRecordFormatter`
- Implementation fetches both record types from `TrainingDataStore`, merges into timestamped tuples, sorts ascending, and formats using `CSVRecordFormatter`
- Empty store returns header-only string (no trailing newline)
- Errors propagate from `TrainingDataStore` — no wrapping or catching
- Implicitly `@MainActor` (not marked `nonisolated`) since it calls `TrainingDataStore` methods
- 7 tests cover all scenarios: mixed records, comparison-only, pitch-matching-only, empty store, timestamp ordering, header verification, row count
- All 857 tests pass (0 regressions)

### File List

- `Peach/Core/Data/TrainingDataExporter.swift` (new) — Export service: fetch + merge + sort + format
- `PeachTests/Core/Data/TrainingDataExporterTests.swift` (new) — 7 tests covering all ACs

## Change Log

- 2026-03-04: Implemented TrainingDataExporter service and full test suite (Story 33.2)
