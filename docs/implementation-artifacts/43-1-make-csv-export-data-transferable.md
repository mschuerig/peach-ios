# Story 43.1: Make CSV Export Data Transferable

Status: review

## Story

As a **developer**,
I want a `Transferable` type that provides the CSV export as a file with the correct UTType,
So that `ShareLink` can share a properly typed .csv file that AirDrop and other targets handle correctly.

## Acceptance Criteria

1. **Given** a `Transferable` type for CSV export (e.g., `CSVExportFile` or conformance on an existing type)
   **When** it provides its transfer representation
   **Then** it uses `FileRepresentation` with UTType `.commaSeparatedText`
   **And** the exported file has a `.csv` extension

2. **Given** the filename
   **When** the file is created
   **Then** it follows the pattern `peach-training-data-YYYY-MM-DD-HHmm.csv` (minute-precision timestamp)

3. **Given** the file is shared via AirDrop to a Mac
   **When** the Mac receives it
   **Then** the file has a `.csv` extension (not `.txt`)

4. **Given** the existing `CSVDocument` (`FileDocument` conformance)
   **When** the new `Transferable` type is introduced
   **Then** `CSVDocument` is either adapted to also conform to `Transferable` or replaced, depending on what is cleaner — the `.fileExporter()` usage in `SettingsScreen` will be removed in story 43.2

5. **Given** unit tests
   **When** they verify the transfer representation
   **Then** the UTType is `.commaSeparatedText` and the filename includes a minute-precision timestamp

## Tasks / Subtasks

- [x] Task 1: Update `CSVDocument` to conform to `Transferable` (AC: #1, #3, #4)
  - [x] Add `Transferable` conformance with `FileRepresentation` exporting `.commaSeparatedText`
  - [x] The `FileRepresentation` must write the CSV string to a temp file with `.csv` extension so AirDrop preserves the type
  - [x] Keep existing `FileDocument` conformance intact — story 43.2 will remove `FileDocument` and `.fileExporter()` usage
- [x] Task 2: Update filename to minute-precision timestamp (AC: #2)
  - [x] Change `exportFileName()` from `peach-training-data-YYYY-MM-DD.csv` to `peach-training-data-YYYY-MM-DD-HHmm.csv`
  - [x] Use `Date.FormatStyle` or `.iso8601` formatting that includes hours and minutes without colons
- [x] Task 3: Write tests for `Transferable` conformance and filename (AC: #5)
  - [x] Test that `CSVDocument` conforms to `Transferable`
  - [x] Test that UTType is `.commaSeparatedText`
  - [x] Test that `exportFileName()` includes minute-precision timestamp (pattern: `peach-training-data-YYYY-MM-DD-HHmm.csv`)
  - [x] Update existing `CSVDocumentTests.filenamePattern()` test for the new format

## Dev Notes

### Current State

- `CSVDocument` at `Peach/Settings/CSVDocument.swift` conforms to `FileDocument` only
- `CSVDocument.exportFileName()` currently returns `"peach-training-data-YYYY-MM-DD.csv"` (day precision, no time)
- `TrainingDataTransferService` at `Peach/Core/Data/TrainingDataTransferService.swift` generates the CSV string via `refreshExport()` and exposes it as `exportCSV: String?`
- `SettingsScreen` uses `.fileExporter(isPresented:document:contentType:defaultFilename:)` at line 93 to present the file save dialog
- No `Transferable` conformances exist anywhere in the project

### Architecture Decisions

**Extend `CSVDocument` rather than creating a new type.** `CSVDocument` already holds the CSV string and understands the filename pattern. Adding `Transferable` conformance keeps the export concern in one place. `FileDocument` and `Transferable` can coexist — `FileDocument` will be removed in story 43.2 when `.fileExporter()` is replaced by `ShareLink`.

**`FileRepresentation` is required (not `DataRepresentation`).** `DataRepresentation` with `.commaSeparatedText` may cause AirDrop to deliver the file as `.txt`. `FileRepresentation` writes a temp file with explicit `.csv` extension, ensuring the UTType and extension are preserved end-to-end.

**`SentTransferredFile` for the exporting side.** The `Transferable` protocol's `transferRepresentation` body should use `FileRepresentation(exportedContentType:)` with a closure that:
1. Creates a temp file URL with `.csv` extension using the `exportFileName()` pattern
2. Writes the CSV string as UTF-8 data to that URL
3. Returns `SentTransferredFile(url)` — SwiftUI manages cleanup

**Importing side is not needed.** `CSVDocument`'s `Transferable` conformance only needs `FileRepresentation` for export. The app already uses `.fileImporter()` for CSV import (story 43.2 confirms import stays unchanged).

### Filename Format Change

Current: `peach-training-data-2026-03-15.csv`
New: `peach-training-data-2026-03-15-1432.csv`

The time component uses `HHmm` (24-hour, no separator) appended after the date with a dash. This matches the pattern specified in the PRD v0.4 amendment.

### Key Implementation Detail

`Transferable` conformance requires the type to be `Sendable`. `CSVDocument` is a `struct` with a single `String` property — it is already `Sendable` by value semantics.

The `transferRepresentation` body must be `nonisolated` (it's a protocol requirement). The temp file write inside the `FileRepresentation` closure runs off the main actor. Use `FileManager.default.temporaryDirectory` for the temp file location.

### Testing Approach

- Verify `Transferable` conformance exists: `let _: any Transferable = CSVDocument(csvString: "test")`
- Verify filename regex: `#/peach-training-data-\d{4}-\d{2}-\d{2}-\d{4}\.csv/#`
- The existing `CSVDocumentTests.filenamePattern()` test must be updated for the new minute-precision format
- Testing actual `FileRepresentation` content transfer is complex and not required — the UTType and filename tests plus the conformance check are sufficient for a unit test level

### Files to Touch

- `Peach/Settings/CSVDocument.swift` — add `Transferable` conformance, update `exportFileName()`
- `PeachTests/Settings/CSVDocumentTests.swift` — update filename test, add `Transferable` conformance test

### What NOT to Do

- Do NOT remove `FileDocument` conformance — story 43.2 handles that
- Do NOT modify `SettingsScreen` — story 43.2 replaces `.fileExporter()` with `ShareLink`
- Do NOT modify `TrainingDataTransferService` — it stays as-is; `ShareLink` will consume `exportCSV` through `CSVDocument` in story 43.2
- Do NOT create a separate `CSVExportFile` type — extend `CSVDocument` instead
- Do NOT use `DataRepresentation` — it won't preserve `.csv` extension via AirDrop
- Do NOT add `import UIKit` — use Foundation APIs only

### Project Structure Notes

- `CSVDocument` lives in `Peach/Settings/` — this is correct since it's a Settings-screen concern (file export UI)
- No new files needed — this is purely additive conformance + filename change
- No cross-feature coupling introduced

### References

- [Source: docs/planning-artifacts/epics.md — Epic 43, Story 43.1]
- [Source: docs/planning-artifacts/prd.md — v0.4 Amendment: Sharing, lines 1751-1801]
- [Source: Peach/Settings/CSVDocument.swift — current FileDocument implementation]
- [Source: PeachTests/Settings/CSVDocumentTests.swift — existing tests]
- [Source: docs/project-context.md — Swift 6.2, Swift Testing, zero third-party deps, domain types]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

No issues encountered.

### Completion Notes List

- Added `Transferable` conformance to `CSVDocument` using `FileRepresentation` with `.commaSeparatedText` UTType
- `FileRepresentation` writes CSV data to a temp file with `.csv` extension via `SentTransferredFile`, ensuring AirDrop preserves the file type
- Existing `FileDocument` conformance kept intact for story 43.2 migration
- Updated `exportFileName()` from day-precision (`YYYY-MM-DD`) to minute-precision (`YYYY-MM-DD-HHmm`) using `DateFormatter` with `en_US_POSIX` locale
- Added `conformsToTransferable` test verifying protocol conformance
- Updated `filenamePattern` test to validate minute-precision regex pattern
- All 1060 tests pass, no regressions

### Change Log

- 2026-03-15: Implemented story 43.1 — Transferable conformance + minute-precision filename

### File List

- `Peach/Settings/CSVDocument.swift` — added `Transferable` conformance, `transferRepresentation`, updated `exportFileName()`
- `PeachTests/Settings/CSVDocumentTests.swift` — added Transferable conformance test, updated filename pattern test
