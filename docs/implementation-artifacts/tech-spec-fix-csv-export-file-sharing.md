---
title: 'Fix CSV Export File Sharing'
slug: 'fix-csv-export-file-sharing'
created: '2026-03-04'
status: 'ready-for-dev'
stepsCompleted: [1, 2, 3, 4]
tech_stack: ['Swift 6.2', 'SwiftUI', 'UniformTypeIdentifiers']
files_to_modify: ['Peach/Settings/SettingsScreen.swift', 'Peach/Settings/CSVExportItem.swift', 'PeachTests/Settings/CSVExportItemTests.swift']
code_patterns: ['@State for UI state', '@Environment for dependency injection', '.fileExporter modifier', 'FileDocument protocol']
test_patterns: ['Swift Testing (@Test, @Suite, #expect)', 'async test functions', 'temp file cleanup in tests']
---

# Tech-Spec: Fix CSV Export File Sharing

**Created:** 2026-03-04

## Overview

### Problem Statement

The CSV export uses `ShareLink` with a `Transferable` `FileRepresentation`. This causes two issues: (1) AirDrop delivers the file with a `.txt` extension and a generic name instead of the intended `peach-training-data-YYYY-MM-DD.csv`, and (2) sharing directly to apps like Numbers does nothing — the user must first save to Files, then open from there.

### Solution

Replace the `ShareLink` + `CSVExportItem` (Transferable) approach with a `.fileExporter` modifier, which gives proper control over filename and extension and produces a real file URL that apps can open directly.

### Scope

**In Scope:**
- Replace `ShareLink` with `.fileExporter` modifier for CSV export
- Ensure `.csv` extension is preserved in all sharing scenarios
- Ensure meaningful filename (`peach-training-data-YYYY-MM-DD.csv`)
- Remove `CSVExportItem` Transferable type (no longer needed)

**Out of Scope:**
- Import UI (story 34.3)
- Changing the CSV format itself
- Adding new export options or formats

## Context for Development

### Codebase Patterns

- Settings screen uses `@Environment` closures for actions (e.g., `trainingDataExportAction: (() throws -> String)?`) wired in `PeachApp.swift`
- Export is eagerly prepared on `.onAppear` via `prepareExport()`, storing result in `@State`
- `CSVExportItem` is a `Transferable` struct with `FileRepresentation` — writes CSV string to temp file
- `CSVExportItem.exportFileName()` generates `peach-training-data-YYYY-MM-DD.csv`
- No `FileDocument` or `.fileExporter` usage exists in the project yet
- Project uses default MainActor isolation — do NOT add explicit `@MainActor`
- `nonisolated` is needed on `FileDocument` protocol conformance methods (`init(configuration:)`, `fileWrapper(configuration:)`) since the protocol is not MainActor-isolated

### Files to Reference

| File | Purpose |
| ---- | ------- |
| `Peach/Settings/SettingsScreen.swift` | Contains `ShareLink`, `prepareExport()`, `@State csvExportItem` — main file to modify |
| `Peach/Settings/CSVExportItem.swift` | `Transferable` type to replace with `FileDocument` conformance |
| `PeachTests/Settings/CSVExportItemTests.swift` | 5 tests for filename pattern and file writing — adapt for new type |
| `Peach/App/EnvironmentKeys.swift` | `trainingDataExportAction` environment key (no changes needed) |
| `Peach/App/PeachApp.swift` | Wires export action (no changes needed) |

### Technical Decisions

- Use `.fileExporter` instead of `ShareLink` + `Transferable` to resolve AirDrop filename/extension issues and direct-to-app sharing failures.
- Create a `CSVDocument` struct conforming to `FileDocument` (replaces `CSVExportItem`). `FileDocument` is the standard SwiftUI protocol for `.fileExporter`.
- The export button becomes a regular `Button` that sets `@State private var showExporter = true`, triggering the `.fileExporter` sheet.
- Keep the `exportFileName()` helper for the default filename.

## Implementation Plan

### Tasks

- [ ] Task 1: Replace `CSVExportItem` with `CSVDocument` conforming to `FileDocument`
  - File: `Peach/Settings/CSVExportItem.swift` (rename to `CSVDocument.swift`)
  - Action: Replace `Transferable` conformance with `FileDocument` conformance
  - Details:
    - Remove `import CoreTransferable`, keep `import UniformTypeIdentifiers` and add `import SwiftUI` (for `FileDocument`)
    - Rename struct from `CSVExportItem` to `CSVDocument`
    - Add `static var readableContentTypes: [UTType] { [.commaSeparatedText] }` (required by `FileDocument`)
    - Add `nonisolated init(configuration: ReadConfiguration) throws` — read `configuration.file.regularFileContents` into `csvString`, set `fileName` to default
    - Add `nonisolated func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper` — return `FileWrapper(regularFileWithContents: csvString.data(using: .utf8)!)`
    - Keep `csvString` and `fileName` properties
    - Keep `static func exportFileName() -> String` unchanged
    - Remove `Transferable` conformance, `transferRepresentation`, and `writeToTemporaryFile()` method

- [ ] Task 2: Update `SettingsScreen` to use `.fileExporter` instead of `ShareLink`
  - File: `Peach/Settings/SettingsScreen.swift`
  - Action: Replace `ShareLink` with `Button` + `.fileExporter` modifier
  - Details:
    - Replace `@State private var csvExportItem: CSVExportItem?` with `@State private var csvDocument: CSVDocument?` and `@State private var showExporter = false`
    - Replace `dataSection`'s `ShareLink` block with a `Button("Export Training Data")` that calls `prepareExport()` and sets `showExporter = true`
    - The button should be disabled when there's no data (keep the grayed-out label for empty state)
    - Add `.fileExporter(isPresented: $showExporter, document: csvDocument, contentType: .commaSeparatedText, defaultFilename: CSVDocument.exportFileName())` modifier to the `Form` or section
    - Handle the `.fileExporter` result closure for error handling
    - Update `prepareExport()` to create `CSVDocument` instead of `CSVExportItem`
    - Update `resetAllTrainingData()` to nil out `csvDocument`
    - Remove eager `prepareExport()` from `.onAppear` — prepare on button tap instead

- [ ] Task 3: Update tests for `CSVDocument`
  - File: `PeachTests/Settings/CSVExportItemTests.swift` (rename to `CSVDocumentTests.swift`)
  - Action: Adapt existing tests for the new `FileDocument` API
  - Details:
    - Rename suite from `CSVExportItem` to `CSVDocument`
    - Update tests to use `CSVDocument` instead of `CSVExportItem`
    - Replace `writeToTemporaryFile` tests with `fileWrapper(configuration:)` tests — verify the returned `FileWrapper` contains the correct CSV data
    - Keep filename pattern test (`exportFileName()` is unchanged)
    - Add test: `CSVDocument` `readableContentTypes` contains `.commaSeparatedText`
    - Add test: round-trip — create `CSVDocument` with string, write via `fileWrapper`, read back via `init(configuration:)`, verify content matches

- [ ] Task 4: Verify no other references to `CSVExportItem` remain
  - Action: Search codebase for `CSVExportItem` references after rename
  - Verify: Zero references remain outside of git history

### Acceptance Criteria

- [ ] AC 1: Given the user taps "Export Training Data", when the file exporter is presented and the user saves to Files, then the saved file has the name `peach-training-data-YYYY-MM-DD.csv` with `.csv` extension
- [ ] AC 2: Given the user taps "Export Training Data", when the file exporter is presented and the user sends via AirDrop, then the received file has `.csv` extension and the meaningful filename
- [ ] AC 3: Given there is no training data, when the settings screen appears, then the export button is visually disabled/grayed out
- [ ] AC 4: Given the user resets all training data, when the data section updates, then the export button becomes disabled
- [ ] AC 5: Given the export file is saved, when opened in Numbers or another spreadsheet app, then the data loads correctly as CSV
- [ ] AC 6: Given all existing tests are run after the change, when the test suite completes, then zero regressions occur

## Additional Context

### Dependencies

- No new dependencies. Uses built-in `SwiftUI.FileDocument` and `UniformTypeIdentifiers.UTType.commaSeparatedText`.

### Testing Strategy

- **Unit tests:** Verify `CSVDocument` conforms to `FileDocument`, produces correct `FileWrapper` content, round-trips correctly, and generates the expected filename pattern.
- **Manual testing:** Export via AirDrop to Mac — verify `.csv` extension and filename. Open exported file in Numbers directly from the file exporter — verify it works without saving to Files first. Test empty data state (button disabled). Test after reset (button disabled).

### Notes

- `FileDocument` protocol methods (`init(configuration:)` and `fileWrapper(configuration:)`) must be marked `nonisolated` due to the project's default MainActor isolation. The protocol is not actor-isolated, so the compiler will require this.
- The `.fileExporter` `defaultFilename` parameter controls the suggested filename in the save dialog. Unlike `ShareLink`, this filename is reliably preserved across AirDrop and other sharing methods.
- AC 2 (AirDrop) and AC 5 (Numbers) require manual verification — they cannot be automated in unit tests.
