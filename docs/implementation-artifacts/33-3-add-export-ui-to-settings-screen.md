# Story 33.3: Add Export UI to Settings Screen

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **musician using Peach**,
I want to export my training data from the Settings screen,
so that I can analyze my progress in a spreadsheet.

## Acceptance Criteria

1. **Given** the Settings Screen data section, **when** it is displayed, **then** an "Export Training Data" button is visible.

2. **Given** training data exists, **when** the user taps "Export Training Data", **then** a system share sheet appears with a CSV file, **and** the filename follows the pattern `peach-training-data-YYYY-MM-DD.csv`.

3. **Given** no training data exists, **when** the export button is displayed, **then** it is disabled or shows a message indicating no data to export.

4. **Given** the share sheet, **when** the user selects a sharing target (Files, AirDrop, etc.), **then** the CSV file is shared successfully.

## Tasks / Subtasks

- [ ] Task 1: Create `CSVExportItem` Transferable type in `Settings/` (AC: #2, #4)
  - [ ] 1.1 Define `struct CSVExportItem: Transferable` with `csvString: String` and `fileName: String`
  - [ ] 1.2 Implement `FileRepresentation` for `.commaSeparatedText` content type
  - [ ] 1.3 In the exporting closure, write csvString to temp file and return `SentTransferredFile`
- [ ] Task 2: Add `trainingDataExportAction` environment entry (AC: #1, #2)
  - [ ] 2.1 Add `@Entry var trainingDataExportAction: (() throws -> String)? = nil` in `EnvironmentKeys.swift`
  - [ ] 2.2 Wire closure in `PeachApp.swift` that calls `TrainingDataExporter.export(from: dataStore)`
- [ ] Task 3: Add export UI to SettingsScreen data section (AC: #1, #2, #3, #4)
  - [ ] 3.1 Add `@Environment(\.trainingDataExportAction)` dependency
  - [ ] 3.2 Add `@State private var csvExportItem: CSVExportItem?` for prepared export
  - [ ] 3.3 Add `@State private var showExportError = false` for error handling
  - [ ] 3.4 Prepare export on `.onAppear` — call export action, check if CSV has data rows, create `CSVExportItem` if yes
  - [ ] 3.5 In data section: render `ShareLink` when `csvExportItem` is set, disabled `Button` when nil
  - [ ] 3.6 Invalidate `csvExportItem = nil` after reset (in `resetAllTrainingData()`)
  - [ ] 3.7 Add error alert for export failure
- [ ] Task 4: Add localized strings (AC: #1)
  - [ ] 4.1 "Export Training Data" → German: "Trainingsdaten exportieren"
  - [ ] 4.2 "Export Failed" → German: "Export fehlgeschlagen"
  - [ ] 4.3 "Could not export training data. Please try again." → German: "Trainingsdaten konnten nicht exportiert werden. Bitte versuche es erneut."
- [ ] Task 5: Write tests (AC: #1, #2, #3)
  - [ ] 5.1 Test `CSVExportItem` file representation writes correct content to disk
  - [ ] 5.2 Test export preparation: CSV with data rows → `CSVExportItem` created
  - [ ] 5.3 Test export preparation: header-only CSV → `CSVExportItem` is nil (button disabled)
  - [ ] 5.4 Test filename format matches `peach-training-data-YYYY-MM-DD.csv`
  - [ ] 5.5 Test invalidation after reset → `CSVExportItem` becomes nil

## Dev Notes

### What This Story Is

A **UI integration** story. Adds an "Export Training Data" button to the Settings screen that presents a system share sheet with a CSV file. The heavy lifting (CSV generation) is already done by `TrainingDataExporter` (story 33.2) and `CSVRecordFormatter` (story 33.1). This story wires the export service to the UI using SwiftUI's `ShareLink` with a `Transferable` type.

### Design: ShareLink with Transferable (Pure SwiftUI)

Use SwiftUI's `ShareLink` with a custom `Transferable` type. This avoids UIKit in views and is the Apple-recommended approach for iOS 16+.

**`CSVExportItem`** — a lightweight struct conforming to `Transferable`:
```swift
struct CSVExportItem: Transferable {
    let csvString: String
    let fileName: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { item in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(item.fileName)
            try item.csvString.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
    }
}
```

**Why this approach?**
- **Pure SwiftUI** — no UIKit in views (project rule). `ShareLink` is a SwiftUI view component.
- **`FileRepresentation`** — shares as a `.csv` file (not a URL or raw text). Recipients see a proper CSV file with the correct filename.
- **`Sendable` by default** — `CSVExportItem` stores only `String` properties, which are `Sendable`. The `FileRepresentation` exporting closure is `@Sendable`, which works because it only accesses `Sendable` properties + `FileManager`.
- **Content type `.commaSeparatedText`** — the system UTType for CSV (`public.comma-separated-values-text`). Share sheet recipients recognize it as a spreadsheet-compatible file.

### Data Flow

1. **On Settings appear** → call injected `trainingDataExportAction` closure → get CSV string
2. **Check for data** → if CSV string equals `CSVExportSchema.headerRow` (header only, no data rows) → set `csvExportItem = nil` → button renders disabled
3. **If data exists** → create `CSVExportItem(csvString:fileName:)` → store in `@State` → `ShareLink` renders enabled
4. **User taps ShareLink** → system calls `FileRepresentation` exporting closure → CSV written to temp file → share sheet presented
5. **User shares via Files/AirDrop/etc.** → system handles delivery
6. **After reset** → `csvExportItem = nil` → re-prepare (will find no data → stays nil → button disabled)

### Filename Generation

Pattern: `peach-training-data-YYYY-MM-DD.csv`

```swift
private func exportFileName() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return "peach-training-data-\(formatter.string(from: Date())).csv"
}
```

Generate the filename when preparing the export (on appear), not in the `FileRepresentation` closure. This ensures the date reflects when the user opened Settings, not when the system processes the share.

### Detecting "No Data" (AC #3)

Compare the export result against the header-only string:
```swift
let csv = try exportAction()
let hasData = csv != CSVExportSchema.headerRow
```

`TrainingDataExporter.export(from:)` returns `CSVExportSchema.headerRow` (no trailing newline) when the store is empty. This is already tested in story 33.2.

**Why not add a `recordCount()` to TrainingDataStore?** The export closure already produces the CSV string. Comparing against the header-only case is zero-cost and avoids adding a new method to the store just for a UI concern.

### Environment Injection Pattern

Follow the existing `dataStoreResetter` pattern — inject a closure via `@Environment`:

**EnvironmentKeys.swift:**
```swift
@Entry var trainingDataExportAction: (() throws -> String)? = nil
```

**PeachApp.swift:**
```swift
.environment(\.trainingDataExportAction, { [dataStore] in
    try TrainingDataExporter.export(from: dataStore)
})
```

**Why return `String` (not `URL`)?** The view needs the CSV string to check for data presence (header-only vs. has rows). Writing to a temp file happens in the `Transferable` exporting closure, not in the view. This keeps the view thin — it only stores the string and delegates file I/O to the Transferable.

### SettingsScreen Changes

Add to `dataSection`:
```swift
private var dataSection: some View {
    Section("Data") {
        if let csvExportItem {
            ShareLink(
                item: csvExportItem,
                preview: SharePreview("Peach Training Data", image: Image(systemName: "doc.text"))
            ) {
                Label("Export Training Data", systemImage: "square.and.arrow.up")
            }
        } else {
            Label("Export Training Data", systemImage: "square.and.arrow.up")
                .foregroundStyle(.secondary)
        }

        Button("Reset All Training Data", role: .destructive) {
            showResetConfirmation = true
        }
        // ... existing confirmation dialog
    }
}
```

**Export preparation on appear:**
```swift
.onAppear {
    // ... existing sound source validation
    prepareExport()
}

private func prepareExport() {
    do {
        guard let csv = try trainingDataExportAction?() else { return }
        if csv != CSVExportSchema.headerRow {
            csvExportItem = CSVExportItem(csvString: csv, fileName: exportFileName())
        } else {
            csvExportItem = nil
        }
    } catch {
        csvExportItem = nil
    }
}
```

**After reset, invalidate:**
```swift
private func resetAllTrainingData() {
    do {
        try dataStoreResetter?()
        csvExportItem = nil  // ← Add this line
    } catch {
        showResetError = true
    }
}
```

### Import Considerations

`CSVExportItem.swift` needs:
```swift
import CoreTransferable
import UniformTypeIdentifiers
```

`SettingsScreen.swift` already imports `SwiftUI` which re-exports `CoreTransferable`. No new imports needed there. However, it will reference `CSVExportSchema.headerRow` — this type is in `Core/Data/`, which is accessible within the same module (single-module app, internal access).

### Existing Types to Reuse (DO NOT RECREATE)

| Type | Location | Purpose |
|---|---|---|
| `TrainingDataExporter` | `Peach/Core/Data/TrainingDataExporter.swift` | `.export(from:)` → CSV string |
| `CSVExportSchema` | `Peach/Core/Data/CSVExportSchema.swift` | `.headerRow` for empty-data check |
| `TrainingDataStore` | `Peach/Core/Data/TrainingDataStore.swift` | Data source (accessed via injected closure) |
| `DataStoreError` | `Peach/Core/Data/DataStoreError.swift` | Error type propagated from store |

### Files To Create

| File | Location | Purpose |
|---|---|---|
| `CSVExportItem.swift` | `Peach/Settings/` | Transferable type for CSV file sharing |
| `CSVExportItemTests.swift` | `PeachTests/Settings/` | Tests for Transferable and filename |

### Files To Modify

| File | Location | Change |
|---|---|---|
| `SettingsScreen.swift` | `Peach/Settings/` | Add export button/ShareLink to data section |
| `EnvironmentKeys.swift` | `Peach/App/` | Add `trainingDataExportAction` entry |
| `PeachApp.swift` | `Peach/App/` | Wire export closure |
| `Localizable.xcstrings` | `Peach/` | Add German translations for new strings |

### No Changes Required To

- `TrainingDataExporter.swift` — used as-is via injected closure
- `CSVExportSchema.swift` — `headerRow` referenced directly for empty check
- `CSVRecordFormatter.swift` — called by TrainingDataExporter internally
- `TrainingDataStore.swift` — no new methods needed
- `ComparisonRecord.swift` / `PitchMatchingRecord.swift` — models unchanged
- Any session, profile, or training files

### Testing

**TDD approach**: Write failing tests first, then implement.

**`CSVExportItemTests`** — test the Transferable type:
1. **File content test**: Create `CSVExportItem` with known CSV string and filename, call the file representation export, verify the temp file contains the exact CSV string
2. **Filename test**: Verify `exportFileName()` produces `peach-training-data-YYYY-MM-DD.csv` format with today's date
3. **Empty CSV handling**: Verify that header-only CSV string is correctly detected as "no data"

**Integration verification** (manual or lightweight):
- Export with data → ShareLink tappable → share sheet shows CSV file
- Export with no data → button disabled/greyed out
- Reset data → export button becomes disabled
- Share to Files → file saved with correct name and content

**Note on testing Transferable**: Testing `FileRepresentation` directly requires calling the transfer representation's export closure. Create the `CSVExportItem`, then manually invoke the file writing logic (which is the same code path). Alternatively, extract the file-writing logic into a testable static method.

Run full test suite: `bin/test.sh`

### Project Structure Notes

- `CSVExportItem.swift` in `Settings/` — it's a UI-layer type (Transferable for ShareLink), not a Core type
- No `import SwiftUI` in `CSVExportItem.swift` — use `import CoreTransferable` and `import UniformTypeIdentifiers`
- Default MainActor isolation applies to SettingsScreen changes (do not add explicit `@MainActor`)
- `CSVExportItem` must be `Sendable` — guaranteed by storing only `String` properties
- New `@Entry` goes in `App/EnvironmentKeys.swift` (project convention)
- Export closure wired in `PeachApp.swift` (composition root)

### Previous Story Intelligence (33.1 and 33.2)

**Key learnings from stories 33.1 and 33.2:**
- `CSVRecordFormatter` was initially marked `nonisolated` but failed because `MIDINote.init(_:)` and other types were `@MainActor`. After review, those types were made `nonisolated`. The `TrainingDataExporter` stays MainActor because it calls `TrainingDataStore`.
- `TrainingDataExporter.export(from:)` returns `CSVExportSchema.headerRow` exactly (no trailing newline) when no records exist. This is the reliable check for "no data".
- The `TrainingDataExporter` is a stateless `enum` with a single `static func` — no instantiation needed.
- All 858 tests pass after stories 33.1 and 33.2. No regressions.

**Files created in 33.1 and 33.2** (your foundation):
- `Peach/Core/Data/CSVExportSchema.swift` — column definitions, header row
- `Peach/Core/Data/CSVRecordFormatter.swift` — record-to-row formatting
- `Peach/Core/Data/TrainingDataExporter.swift` — fetch + merge + sort + format
- `PeachTests/Core/Data/CSVExportSchemaTests.swift` — 7 tests
- `PeachTests/Core/Data/CSVRecordFormatterTests.swift` — 14 tests
- `PeachTests/Core/Data/TrainingDataExporterTests.swift` — 8 tests

### Git Intelligence

Recent commits follow the pattern: `{Verb} story {id}: {description}`. The last 5 commits are all in epic 33 (CSV export). The codebase is stable with 858 passing tests.

### Localization

Add to `Localizable.xcstrings` using `bin/add-localization.py`:
- `"Export Training Data"` → `"Trainingsdaten exportieren"`
- `"Export Failed"` → `"Export fehlgeschlagen"`
- `"Could not export training data. Please try again."` → `"Trainingsdaten konnten nicht exportiert werden. Bitte versuche es erneut."`
- `"Peach Training Data"` — keep English (it's a SharePreview title, appears in system UI as file metadata)

### References

- [Source: docs/planning-artifacts/epics.md#Epic 33, Story 33.3]
- [Source: docs/project-context.md — file placement, naming, testing rules, MainActor isolation, environment injection patterns]
- [Source: Peach/Core/Data/TrainingDataExporter.swift — export(from:) static method]
- [Source: Peach/Core/Data/CSVExportSchema.swift — headerRow for empty-data detection]
- [Source: Peach/Settings/SettingsScreen.swift — dataSection, dataStoreResetter pattern]
- [Source: Peach/App/EnvironmentKeys.swift — @Entry pattern for environment dependencies]
- [Source: Peach/App/PeachApp.swift — composition root, closure wiring pattern]
- [Source: docs/implementation-artifacts/33-2-implement-csv-export-service.md — previous story learnings]
- [Source: docs/implementation-artifacts/33-1-define-and-document-csv-export-schema.md — schema and formatter details]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
