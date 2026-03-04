# Story 34.3: Add Import UI with Replace/Merge Choice

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **musician using Peach**,
I want to import training data from a CSV file and choose whether to replace or merge,
So that I can restore backups or combine data from multiple devices.

## Acceptance Criteria

1. **Given** the Settings Screen data section **When** it is displayed **Then** an "Import Training Data" button is visible

2. **Given** the user taps "Import Training Data" **When** the file picker appears **Then** it filters for CSV files

3. **Given** a CSV file is selected **When** it is validated successfully **Then** a choice dialog appears: "Replace All Data" vs "Merge with Existing Data" **And** the "Replace All Data" option warns that existing data will be permanently deleted

4. **Given** the user confirms their choice **When** the import completes **Then** a summary is shown: number of records imported, skipped, and errors **And** the perceptual profile is rebuilt from the updated data

5. **Given** the CSV file contains validation errors **When** it is imported **Then** the user sees a clear error message describing the issue

## Tasks / Subtasks

- [x] Task 1: Add `rebuild(from:)` methods to TrendAnalyzer and ThresholdTimeline (AC: #4)
  - [x] 1.1 Write tests: TrendAnalyzer.rebuild(from:) produces same state as init(records:)
  - [x] 1.2 Write tests: ThresholdTimeline.rebuild(from:) produces same state as init(records:)
  - [x] 1.3 Implement `TrendAnalyzer.rebuild(from records: [ComparisonRecord])` — reset + re-feed
  - [x] 1.4 Implement `ThresholdTimeline.rebuild(from records: [ComparisonRecord])` — reset + re-feed

- [x] Task 2: Add `trainingDataImportAction` environment entry (AC: #4)
  - [x] 2.1 Add `@Entry var trainingDataImportAction: ((CSVImportParser.ImportResult, TrainingDataImporter.ImportMode) throws -> TrainingDataImporter.ImportSummary)? = nil` in `EnvironmentKeys.swift`
  - [x] 2.2 Wire closure in `PeachApp.swift` that calls `TrainingDataImporter.importData`, then rebuilds profile, trend analyzer, and threshold timeline from updated store data

- [x] Task 3: Add import UI to SettingsScreen (AC: #1, #2, #3, #4, #5)
  - [x] 3.1 Add `@Environment(\.trainingDataImportAction)` dependency
  - [x] 3.2 Add state variables: `@State private var showFileImporter = false`, `@State private var importParseResult: CSVImportParser.ImportResult?`, `@State private var showImportModeChoice = false`, `@State private var showImportSummary = false`, `@State private var importSummary: TrainingDataImporter.ImportSummary?`, `@State private var showImportError = false`, `@State private var importErrorMessage = ""`
  - [x] 3.3 Add "Import Training Data" button to `dataSection` (between export and reset)
  - [x] 3.4 Add `.fileImporter(isPresented:allowedContentTypes:)` modifier for `.commaSeparatedText`
  - [x] 3.5 Implement file reading with security-scoped resource access (`startAccessingSecurityScopedResource` / `stopAccessingSecurityScopedResource`)
  - [x] 3.6 Parse CSV with `CSVImportParser.parse()` and validate result
  - [x] 3.7 Add `.confirmationDialog` for Replace vs Merge choice with destructive warning on Replace
  - [x] 3.8 Call import action closure and store summary result
  - [x] 3.9 Show summary alert with imported/skipped/error counts
  - [x] 3.10 Re-prepare export after successful import (`prepareExport()`)

- [x] Task 4: Add localized strings (AC: #1, #3, #4, #5)
  - [x] 4.1 Add all import-related strings via `bin/add-localization.py --batch`

- [x] Task 5: Write tests (AC: #1, #2, #3, #4, #5)
  - [x] 5.1 Test import action closure: replace mode imports records and rebuilds profile
  - [x] 5.2 Test import action closure: merge mode imports non-duplicates and rebuilds profile
  - [x] 5.3 Test import action closure: profile is rebuilt from ALL store records (not just imported)
  - [x] 5.4 Test TrendAnalyzer.rebuild(from:) matches fresh init behavior
  - [x] 5.5 Test ThresholdTimeline.rebuild(from:) matches fresh init behavior

- [x] Task 6: Run full test suite
  - [x] 6.1 Run `bin/test.sh` and verify zero regressions

## Dev Notes

### What This Story Is

A **UI integration** story. Adds an "Import Training Data" button to the Settings screen that presents a file picker for CSV files, lets the user choose between replace and merge modes, executes the import, and displays a summary. The heavy lifting (parsing and import logic) is already done by `CSVImportParser` (story 34.1) and `TrainingDataImporter` (story 34.2). This story wires those services to the UI and handles post-import state rebuilding.

### Import Flow

```
User taps "Import Training Data"
  → .fileImporter opens (filters .commaSeparatedText)
  → User selects CSV file
  → Read file with security-scoped access
  → CSVImportParser.parse(csvString)         [story 34.1, already done]
  → If zero valid records + errors → show error alert, stop
  → Show confirmationDialog: "Replace All Data" / "Merge with Existing Data"
  → User picks mode
  → trainingDataImportAction(parseResult, mode)  [environment closure]
     → TrainingDataImporter.importData()      [story 34.2, already done]
     → Rebuild profile, trend analyzer, threshold timeline from store
  → Show summary alert (imported / skipped / errors)
  → Re-prepare export item (new data available)
```

### Environment Injection Pattern

Follow the existing `trainingDataExportAction` pattern — inject a closure via `@Environment`:

**EnvironmentKeys.swift:**
```swift
@Entry var trainingDataImportAction: ((CSVImportParser.ImportResult, TrainingDataImporter.ImportMode) throws -> TrainingDataImporter.ImportSummary)? = nil
```

**PeachApp.swift:**
```swift
.environment(\.trainingDataImportAction, { [dataStore, profile, trendAnalyzer, thresholdTimeline] parseResult, mode in
    let summary = try TrainingDataImporter.importData(parseResult, mode: mode, into: dataStore)
    // Rebuild in-memory state from updated store
    let allComparisons = try dataStore.fetchAllComparisons()
    let allPitchMatchings = try dataStore.fetchAllPitchMatchings()
    profile.reset()
    profile.resetMatching()
    for record in allComparisons {
        profile.update(note: MIDINote(record.referenceNote), centOffset: abs(record.centOffset), isCorrect: record.isCorrect)
    }
    for record in allPitchMatchings {
        profile.updateMatching(note: MIDINote(record.referenceNote), centError: record.userCentError)
    }
    trendAnalyzer.rebuild(from: allComparisons)
    thresholdTimeline.rebuild(from: allComparisons)
    return summary
})
```

**Why rebuild ALL in-memory state:** After replace mode, all old data is gone. After merge mode, new records were added. In both cases, the profile, trend analyzer, and threshold timeline must reflect the current store contents. The simplest correct approach is: reset everything, then re-feed all records from the store (same logic as `PeachApp.loadPerceptualProfile` at app init).

### Adding `rebuild(from:)` Methods

Both `TrendAnalyzer` and `ThresholdTimeline` support `init(records:)` but not post-construction rebuilding. Add `rebuild(from:)` to each:

**TrendAnalyzer:**
```swift
func rebuild(from records: [ComparisonRecord]) {
    absOffsets = records.map { abs($0.centOffset) }
    recompute()
}
```

**ThresholdTimeline:**
```swift
func rebuild(from records: [ComparisonRecord]) {
    dataPoints = records.map {
        TimelineDataPoint(
            timestamp: $0.timestamp,
            centOffset: abs($0.centOffset),
            isCorrect: $0.isCorrect,
            referenceNote: $0.referenceNote
        )
    }
    recomputeAggregatedPoints()
}
```

Both methods reuse the existing private `recompute`/`recomputeAggregatedPoints` methods — no new logic needed.

### File Importer Usage

Use SwiftUI's `.fileImporter()` modifier:

```swift
.fileImporter(
    isPresented: $showFileImporter,
    allowedContentTypes: [.commaSeparatedText]
) { result in
    handleFileSelection(result)
}
```

**Security-scoped resource access is required** when reading files from the file picker:
```swift
private func handleFileSelection(_ result: Result<URL, Error>) {
    switch result {
    case .success(let url):
        guard url.startAccessingSecurityScopedResource() else {
            importErrorMessage = "Could not access the selected file."
            showImportError = true
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let csvString = try String(contentsOf: url, encoding: .utf8)
            let parseResult = CSVImportParser.parse(csvString)
            if parseResult.comparisons.isEmpty && parseResult.pitchMatchings.isEmpty {
                // No valid records — show error with parse error details
                importErrorMessage = "The file contains no valid training data."
                showImportError = true
                return
            }
            importParseResult = parseResult
            showImportModeChoice = true
        } catch {
            importErrorMessage = "Could not read the selected file."
            showImportError = true
        }
    case .failure:
        // User cancelled or system error — silently ignore cancellation
        break
    }
}
```

**Needs `import UniformTypeIdentifiers`** in `SettingsScreen.swift` for `.commaSeparatedText`.

### Replace vs Merge Choice Dialog

```swift
.confirmationDialog(
    "Import Training Data",
    isPresented: $showImportModeChoice,
    titleVisibility: .visible
) {
    Button("Replace All Data", role: .destructive) {
        performImport(mode: .replace)
    }
    Button("Merge with Existing Data") {
        performImport(mode: .merge)
    }
} message: {
    Text("Replace deletes all existing data first. Merge keeps existing data and skips duplicates.")
}
```

### Summary Alert

After import completes, show the `ImportSummary`:

```swift
.alert("Import Complete", isPresented: $showImportSummary) {
    Button("OK") { }
} message: {
    if let summary = importSummary {
        Text("\(summary.totalImported) records imported, \(summary.totalSkipped) duplicates skipped, \(summary.parseErrorCount) errors.")
    }
}
```

### SettingsScreen Data Section Changes

Add the import button between export and reset:

```swift
private var dataSection: some View {
    Section("Data") {
        // Export (existing)
        if let csvExportItem { ... } else { ... }

        // Import (NEW)
        Button {
            showFileImporter = true
        } label: {
            Label("Import Training Data", systemImage: "square.and.arrow.down")
        }

        // Reset (existing)
        Button("Reset All Training Data", role: .destructive) { ... }
    }
}
```

### Localization Strings

| English | German |
|---|---|
| Import Training Data | Trainingsdaten importieren |
| Replace All Data | Alle Daten ersetzen |
| Merge with Existing Data | Mit vorhandenen Daten zusammenführen |
| Replace deletes all existing data first. Merge keeps existing data and skips duplicates. | „Ersetzen" löscht alle vorhandenen Daten. „Zusammenführen" behält vorhandene Daten und überspringt Duplikate. |
| Import Complete | Import abgeschlossen |
| %lld records imported, %lld duplicates skipped, %lld errors. | %lld Datensätze importiert, %lld Duplikate übersprungen, %lld Fehler. |
| Could not access the selected file. | Auf die ausgewählte Datei konnte nicht zugegriffen werden. |
| Could not read the selected file. | Die ausgewählte Datei konnte nicht gelesen werden. |
| The file contains no valid training data. | Die Datei enthält keine gültigen Trainingsdaten. |
| Import Failed | Import fehlgeschlagen |

### Existing Code to Reuse (Do NOT Reinvent)

| What | Where | How to Use |
|---|---|---|
| Parse CSV string | `CSVImportParser.parse(_ csvContent: String) -> ImportResult` | Read file, pass string |
| ImportResult type | `CSVImportParser.ImportResult` — `comparisons`, `pitchMatchings`, `errors` | Check for valid records, pass to importer |
| Import records | `TrainingDataImporter.importData(_:mode:into:) throws -> ImportSummary` | Called by environment closure |
| ImportMode enum | `TrainingDataImporter.ImportMode` — `.replace`, `.merge` | Pass user's choice |
| ImportSummary type | `TrainingDataImporter.ImportSummary` — `totalImported`, `totalSkipped`, `parseErrorCount` | Display in summary alert |
| Export action pattern | `trainingDataExportAction` in `EnvironmentKeys.swift` | Mirror for import action |
| Data store resetter pattern | `dataStoreResetter` in `EnvironmentKeys.swift` + `PeachApp.swift` | Pattern for closure wiring with captures |
| Profile rebuild logic | `PeachApp.loadPerceptualProfile()` | Same loop: reset + re-feed records |
| Profile reset | `PerceptualProfile.reset()` + `.resetMatching()` | Clear before rebuild |
| Fetch all records | `TrainingDataStore.fetchAllComparisons()` + `.fetchAllPitchMatchings()` | Get records for profile rebuild |
| Export prep | `prepareExport()` in `SettingsScreen` | Call after import to refresh export button |

### Files To Create

None — all code goes into existing files.

### Files To Modify

| File | Change |
|---|---|
| `Peach/Core/Profile/TrendAnalyzer.swift` | Add `rebuild(from:)` method |
| `Peach/Core/Profile/ThresholdTimeline.swift` | Add `rebuild(from:)` method |
| `Peach/App/EnvironmentKeys.swift` | Add `trainingDataImportAction` entry |
| `Peach/App/PeachApp.swift` | Wire import closure with profile/trend/timeline rebuild |
| `Peach/Settings/SettingsScreen.swift` | Add import button, file importer, dialogs, state variables |
| `Peach/Resources/Localizable.xcstrings` | German translations for import strings |

### Test Files To Modify

| File | Change |
|---|---|
| `PeachTests/Core/Profile/TrendAnalyzerTests.swift` | Add rebuild(from:) tests |
| `PeachTests/Core/Profile/ThresholdTimelineTests.swift` | Add rebuild(from:) tests |

### No Changes Required To

- `CSVImportParser.swift` — used as-is
- `TrainingDataImporter.swift` — used as-is
- `TrainingDataStore.swift` — existing methods sufficient
- `ComparisonRecord.swift` / `PitchMatchingRecord.swift` — models unchanged
- `CSVExportItem.swift` — unrelated to import
- Any session, strategy, or domain type files

### Testing Strategy

**Testable parts:**
1. `TrendAnalyzer.rebuild(from:)` — verify it produces same `trend` as fresh `init(records:)`
2. `ThresholdTimeline.rebuild(from:)` — verify it produces same `aggregatedPoints` as fresh `init(records:)`
3. Integration test for the import action closure: create in-memory SwiftData store, wire the closure, call it, verify profile/trend/timeline state matches expected

**Not unit-testable (SwiftUI presentation):**
- `.fileImporter` presentation and file selection
- `.confirmationDialog` presentation and button taps
- `.alert` presentation with summary text
- These are verified by code inspection and manual testing

Follow the same approach as story 33.3 where UI-only behavior was documented as "verified by code inspection."

### Project Structure Notes

- No new files created — all changes go into existing files
- `import UniformTypeIdentifiers` needed in `SettingsScreen.swift` for `.commaSeparatedText`
- The import action closure captures `dataStore`, `profile`, `trendAnalyzer`, `thresholdTimeline` from PeachApp — follows the exact pattern of `dataStoreResetter` which captures `[dataStore, comparisonSession, profile]`
- `CSVImportParser.parse()` is `nonisolated` — can be called from any context. Calling it directly in the view is fine (it's pure computation on the CSV string)
- `TrainingDataImporter.importData()` is MainActor-isolated — called within the environment closure which runs on MainActor

### Previous Story Intelligence (34.1 and 34.2)

**From story 34.1:**
- `CSVImportParser.ImportResult` (not `Result` — renamed to avoid shadowing `Swift.Result`) contains `comparisons`, `pitchMatchings`, `errors`
- Parser handles CRLF line endings and RFC 4180 escaping — the UI does not need to normalize
- Parser is `nonisolated` — safe to call directly in view code

**From story 34.2:**
- `TrainingDataImporter.importData()` is NOT `nonisolated` — it calls `TrainingDataStore` methods
- `ImportSummary.parseErrorCount` comes from `ImportResult.errors.count` — the importer passes it through so the UI gets a complete summary without needing to hold the parse result
- Intra-file duplicates are handled by the importer (newly inserted keys are added to the duplicate set)
- Both `ImportMode` and `ImportSummary` are nested inside `TrainingDataImporter`
- Test suite was at 917 tests after story 34.2

**From story 33.3 (Export UI — the pattern to mirror):**
- `CSVExportItem` Transferable type with `FileRepresentation` in `Settings/`
- `trainingDataExportAction` closure injected via `@Entry` + PeachApp wiring
- Export prepared on `.onAppear`; `csvExportItem` invalidated after reset
- 5 tests for the export item; UI presentation verified by code inspection
- Code review caught: POSIX locale for DateFormatter, error handling not silently disabling UI

### Git Intelligence

Recent commits: story 34.1 (parser), 34.2 (merge logic), quick spec for CSV export fix. Standard workflow: create → implement → review. Test suite at 917 tests. Commit format: `{Verb} story {id}: {description}`.

### References

- [Source: Peach/Core/Data/CSVImportParser.swift] — `parse()` method and `ImportResult` type
- [Source: Peach/Core/Data/TrainingDataImporter.swift] — `importData()`, `ImportMode`, `ImportSummary`
- [Source: Peach/Settings/SettingsScreen.swift:155-208] — Existing data section with export and reset
- [Source: Peach/App/EnvironmentKeys.swift] — `@Entry` pattern for closures
- [Source: Peach/App/PeachApp.swift:81-88] — Closure wiring with captures
- [Source: Peach/App/PeachApp.swift:115-134] — `loadPerceptualProfile` rebuild logic to mirror
- [Source: Peach/Core/Profile/PerceptualProfile.swift:105-146] — `reset()`, `resetMatching()`, `update()`, `updateMatching()`
- [Source: Peach/Core/Profile/TrendAnalyzer.swift:19-58] — `init(records:)`, `reset()`, private `recompute()`
- [Source: Peach/Core/Profile/ThresholdTimeline.swift:18-46] — `init(records:)`, `reset()`, private `recomputeAggregatedPoints()`
- [Source: Peach/Settings/CSVExportItem.swift] — Transferable pattern reference
- [Source: docs/implementation-artifacts/34-1-implement-csv-import-parser.md] — Parser story learnings
- [Source: docs/implementation-artifacts/34-2-implement-merge-logic-with-duplicate-detection.md] — Importer story learnings
- [Source: docs/implementation-artifacts/33-3-add-export-ui-to-settings-screen.md] — Export UI pattern to mirror
- [Source: docs/planning-artifacts/epics.md#Epic 34, Story 34.3] — Acceptance criteria source
- [Source: docs/project-context.md] — TDD workflow, testing conventions, environment injection rules

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None needed — clean implementation.

### Completion Notes List

- Task 1: Added `rebuild(from:)` to both TrendAnalyzer and ThresholdTimeline. Both methods reuse existing private recompute methods, matching the init(records:) pattern exactly.
- Task 2: Added `trainingDataImportAction` environment entry following the existing `trainingDataExportAction` pattern. Closure captures dataStore, profile, trendAnalyzer, thresholdTimeline and rebuilds all in-memory state after import.
- Task 3: Added full import UI flow to SettingsScreen: file picker (.commaSeparatedText), security-scoped resource access, CSV parsing/validation, replace/merge confirmation dialog, import execution, summary alert, and error handling. Import button placed between export and reset in data section.
- Task 4: Added 10 German localization strings for all import-related UI text.
- Task 5: Wrote 11 new tests: 3 for TrendAnalyzer.rebuild, 3 for ThresholdTimeline.rebuild, 5 integration tests for the import action closure.
- Task 6: Full test suite passes — 928 tests (was 917, +11 new).

### Change Log

- 2026-03-04: Implemented story 34.3 — Import UI with replace/merge choice. Added rebuild methods, environment wiring, full import flow in SettingsScreen, localization, and tests.

### File List

- Peach/Core/Profile/TrendAnalyzer.swift (modified — added rebuild(from:))
- Peach/Core/Profile/ThresholdTimeline.swift (modified — added rebuild(from:))
- Peach/App/EnvironmentKeys.swift (modified — added trainingDataImportAction entry)
- Peach/App/PeachApp.swift (modified — wired import closure with profile/trend/timeline rebuild)
- Peach/Settings/SettingsScreen.swift (modified — added import button, file importer, dialogs, action methods)
- Peach/Resources/Localizable.xcstrings (modified — added 10 German translations)
- PeachTests/Profile/TrendAnalyzerTests.swift (modified — added 3 rebuild tests)
- PeachTests/Core/Profile/ThresholdTimelineTests.swift (modified — added 3 rebuild tests)
- PeachTests/Settings/TrainingDataImportActionTests.swift (new — 5 import action integration tests)
