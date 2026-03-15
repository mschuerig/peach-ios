# Story 43.2: Replace File Exporter with ShareLink in Settings

Status: ready-for-dev

## Story

As a **musician using Peach**,
I want to share my training data from the Settings screen via the system share sheet,
So that I can send it via AirDrop, save to Files, email, or use any other sharing destination.

## Acceptance Criteria

1. **Given** the Settings Screen data section
   **When** it is displayed
   **Then** the "Export Training Data" button is present with its existing icon (`square.and.arrow.up`)

2. **Given** training data exists
   **When** the user taps "Export Training Data"
   **Then** the system share sheet appears with a .csv file attachment
   **And** the share sheet includes destinations like AirDrop, Files, Messages, Mail

3. **Given** no training data exists
   **When** the export button is displayed
   **Then** it is disabled (same behavior as current implementation)

4. **Given** the user selects "Save to Files" in the share sheet
   **When** iCloud Drive is available
   **Then** the user can save the CSV to iCloud (same capability as the current `.fileExporter()`)

5. **Given** the current `.fileExporter()` modifier on `SettingsScreen`
   **When** this story is implemented
   **Then** the `.fileExporter()` modifier and its associated state (`showExporter`) are removed
   **And** replaced with a `ShareLink` using the `Transferable` type from story 43.1

6. **Given** the import functionality (`.fileImporter()`)
   **When** the export is changed to `ShareLink`
   **Then** the import is unchanged — `.fileImporter()` remains as-is

7. **Given** the `TrainingDataTransferService`
   **When** the export path changes to `ShareLink`
   **Then** any state or methods that existed solely to support `.fileExporter()` are cleaned up if no longer needed

## Tasks / Subtasks

- [ ] Task 1: Replace export button with `ShareLink` in `SettingsScreen` (AC: #1, #2, #3, #5)
  - [ ] Remove `@State private var showExporter = false` state variable
  - [ ] Remove `.fileExporter()` modifier (lines 93-98)
  - [ ] Replace the export `Button` in `dataSection` with a `ShareLink` that uses `CSVDocument` as the `Transferable` item
  - [ ] The `ShareLink` label must be `Label("Export Training Data", systemImage: "square.and.arrow.up")` (identical to current button)
  - [ ] Disable the `ShareLink` when `transferService.exportCSV == nil`
  - [ ] Keep the `.foregroundStyle` modifier for the disabled appearance
- [ ] Task 2: Stabilize filename across share-sheet retries (AC: #2)
  - [ ] Add a stored `exportDate: Date` property to `CSVDocument` (defaulting to `Date()`)
  - [ ] Update `transferRepresentation` to use `document.exportDate` instead of generating a new date on each call
  - [ ] This prevents the filename from changing if the user retries or shares to multiple targets
- [ ] Task 3: Remove `FileDocument` conformance from `CSVDocument` (AC: #5, #7)
  - [ ] Remove `FileDocument` conformance and all its associated methods (`readableContentTypes`, `init(configuration:)`, `fileWrapper(configuration:)`)
  - [ ] Remove `import UniformTypeIdentifiers` if no longer needed (check if `Transferable` requires it — `.commaSeparatedText` comes from `UniformTypeIdentifiers`)
  - [ ] Keep `import UniformTypeIdentifiers` since `UTType.commaSeparatedText` requires it
- [ ] Task 4: Clean up `SettingsScreen` state and `refreshExport` environment key (AC: #5, #7)
  - [ ] Remove `@State private var showExportError = false` and the "Export Failed" alert (system share sheet handles errors internally)
  - [ ] Remove `@Environment(\.refreshExport) private var refreshExport`
  - [ ] Replace `.onAppear { if refreshExport?() == true { showExportError = true } }` with `.onAppear { transferService.refreshExport() }` — the view already has `transferService` via `@Environment`, so the `refreshExport` closure (which only wraps a single-method call) is redundant
  - [ ] Remove `@Entry var refreshExport` from `EnvironmentKeys.swift`
  - [ ] Remove `.environment(\.refreshExport, ...)` wiring in `PeachApp.swift`
- [ ] Task 6: Update tests (AC: #1–#7)
  - [ ] Remove `conformsToFileDocument` test from `CSVDocumentTests.swift`
  - [ ] Update `readableContentTypes` test (this was a `FileDocument` requirement — remove it)
  - [ ] Add test verifying `exportDate` property is captured at construction time and used in filename
  - [ ] Verify all existing CSVDocument tests still pass after `FileDocument` removal
- [ ] Task 7: Run full test suite and verify no regressions

## Dev Notes

### Current Implementation (What Changes)

**SettingsScreen.swift** (`Peach/Settings/SettingsScreen.swift`):
- Line 44: `@State private var showExporter = false` — REMOVE
- Line 45: `@State private var showExportError = false` — REMOVE (share sheet handles errors)
- Lines 93-98: `.fileExporter(...)` modifier — REMOVE entirely
- Line 36: `@Environment(\.refreshExport)` — REMOVE (call `transferService.refreshExport()` directly)
- Line 92: `.onAppear { if refreshExport?() == true { showExportError = true } }` — REPLACE with `.onAppear { transferService.refreshExport() }`
- Lines 273-283: Export `Button` in `dataSection` — REPLACE with `ShareLink`
- Lines 111-113: "Export Failed" alert — REMOVE

**CSVDocument.swift** (`Peach/Settings/CSVDocument.swift`):
- Lines 4-26: `FileDocument` conformance (readableContentTypes, init(configuration:), fileWrapper) — REMOVE
- Line 4: Change `struct CSVDocument: FileDocument, Transferable` to `struct CSVDocument: Transferable`
- Add `let exportDate: Date` property with default `Date()`
- Update `transferRepresentation` to use `document.exportDate` in `exportFileName(for:)`

### ShareLink Implementation Pattern

The `ShareLink` replaces both the `Button` and `.fileExporter()`. The pattern is:

```swift
if let csvString = transferService.exportCSV {
    ShareLink(
        item: CSVDocument(csvString: csvString),
        preview: SharePreview("Peach Training Data")
    ) {
        Label("Export Training Data", systemImage: "square.and.arrow.up")
    }
} else {
    Label("Export Training Data", systemImage: "square.and.arrow.up")
        .foregroundStyle(.secondary)
}
```

`ShareLink` requires a non-optional `Transferable` item, so use conditional content: show the `ShareLink` when `exportCSV` is available, otherwise show a disabled-styled label. The `SharePreview("Peach Training Data")` provides a clean title in the share sheet instead of a raw filename.

### Export Date Stabilization (Design Note from 43.1 Review)

From the code review of story 43.1: `CSVDocument.transferRepresentation` calls `exportFileName()` at transfer time, generating a new timestamp on each invocation. When the share sheet retries or the user shares to multiple targets, the filename would change.

**Fix:** Add `let exportDate: Date` to `CSVDocument`. The `transferRepresentation` closure uses `exportFileName(for: document.exportDate)` to produce a stable filename. The `CSVDocument` is constructed with the current date when the user taps export.

### Refresh Export Timing

Currently, `refreshExport` is called in two places:
1. `.onAppear` of SettingsScreen — ensures CSV is fresh when screen opens
2. On the export button tap — refreshes just before showing file exporter

With `ShareLink`, the tap-time refresh is no longer needed — `ShareLink` reads the item from the view body. Call `transferService.refreshExport()` directly in `.onAppear` to populate `exportCSV`. The `refreshExport` environment closure (which only wraps this single-method call) is removed entirely — the view already has `transferService` via `@Environment`, so the extra indirection violates the "minimize environment surface" rule. If `exportCSV` is nil after refresh (no data), the conditional content shows a disabled label instead of a `ShareLink`.

### What NOT to Do

- Do NOT modify `.fileImporter()` — import stays exactly as-is
- Do NOT modify `TrainingDataTransferService.refreshExport()` or `exportCSV` — the service API stays the same
- Do NOT create new files — this is purely modifications to existing files
- Do NOT add `import UIKit` — `ShareLink` is pure SwiftUI
- Do NOT add Combine — use the existing `@Observable` pattern
- Do NOT remove `import UniformTypeIdentifiers` from CSVDocument — `UTType.commaSeparatedText` requires it
- Do NOT add explicit `@MainActor` annotations — default isolation handles this

### Project Structure Notes

- All changes are within existing files — no new files created
- No cross-feature coupling introduced
- `CSVDocument` stays in `Peach/Settings/` — it's a Settings-screen concern
- `TrainingDataTransferService` stays in `Peach/Core/Data/` — no changes needed
- Dependency direction rules are respected: Settings/ does not reference other features

### References

- [Source: docs/planning-artifacts/epics.md — Epic 43, Story 43.2, lines 4283-4319]
- [Source: docs/planning-artifacts/ux-design-specification.md — v0.4 Amendment, lines 1753-1806]
- [Source: docs/implementation-artifacts/43-1-make-csv-export-data-transferable.md — Previous story context and design note]
- [Source: Peach/Settings/SettingsScreen.swift — Current .fileExporter() implementation, lines 93-98]
- [Source: Peach/Settings/CSVDocument.swift — Current FileDocument + Transferable conformance]
- [Source: Peach/Core/Data/TrainingDataTransferService.swift — Export service, exportCSV property]
- [Source: Peach/App/EnvironmentKeys.swift — refreshExport, trainingDataTransferService keys]
- [Source: docs/project-context.md — Swift 6.2, SwiftUI, zero third-party deps, testing rules]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
