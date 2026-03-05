---
title: 'Extract Training Data Transfer Logic from SettingsScreen'
slug: 'extract-settings-transfer-logic'
created: '2026-03-05'
status: 'done'
stepsCompleted: [1, 2, 3, 4]
tech_stack: ['Swift 6.2', 'SwiftUI', 'SwiftData', 'Swift Testing']
files_to_modify: ['Peach/Core/Data/TrainingDataTransferService.swift (new)', 'PeachTests/Core/Data/TrainingDataTransferServiceTests.swift (new)', 'Peach/Settings/SettingsScreen.swift', 'Peach/App/PeachApp.swift', 'Peach/App/EnvironmentKeys.swift', 'Peach/Settings/SettingsKeys.swift', 'PeachTests/Settings/SettingsKeysTests.swift (new)']
code_patterns: ['stateless enum services (CSVImportParser, TrainingDataImporter, TrainingDataExporter)', '@Entry environment injection', 'environment closures for composition-root-owned orchestration', 'protocol-first design', 'nonisolated for pure enums in Core/', '@Observable final class for stateful services']
test_patterns: ['struct-based @Suite', 'factory methods for fixtures', 'in-memory ModelContainer', 'real TrainingDataStore (not mocked) for integration-style tests', '@Test with behavioral descriptions', 'async test functions']
---

# Tech-Spec: Extract Training Data Transfer Logic from SettingsScreen

**Created:** 2026-03-05

## Overview

### Problem Statement

`SettingsScreen.swift` (379 lines) violates the project's "views are thin" and "views contain zero business logic" rules. It contains substantial import/export orchestration: file I/O with security-scoped URL access, CSV parsing, error message formatting, import mode dispatch, export document caching, and a duplicated sound source validation fallback. This logic is untestable in its current form and creates coupling between the view and data transfer concerns.

### Solution

1. **Create a `TrainingDataTransferService`** in `Core/Data/` that owns the full import/export workflow — file reading, CSV parsing, error formatting, import dispatch, and export document creation. The view calls one method and receives a result.
2. **Fix the duplicated sound source validation** by moving fallback logic into a static function on `SettingsKeys`, called once in `PeachApp.init()`.
3. **Both changes get tests.** Two separate commits: one for import/export extraction, one for sound source validation.

### Scope

**In Scope:**
- Extract `handleFileSelection`, `performImport`, `importSummaryMessage`, `refreshExportDocument` into `TrainingDataTransferService`
- Move post-import profile/trend/timeline rebuild from `PeachApp` closure into the service
- Extract sound source validation/fallback into `SettingsKeys.validateSoundSource(against:)`
- Remove duplicated `validatedSoundSource` binding and `.onAppear` fallback from `SettingsScreen`
- Remove unused `trainingDataExportAction` environment key
- Tests for the extracted service and the validation function
- Wire new service in `PeachApp.swift` composition root, inject via `@Environment`

**Out of Scope:**
- Changing CSV format or import/export behavior
- Refactoring other SettingsScreen sections (training range, intervals, difficulty)
- Changing `resetAllTrainingData` (borderline, but thin enough to leave)
- UI changes — the screen should look and behave identically

## Context for Development

### Codebase Patterns

- **Stateless enum services:** `CSVImportParser`, `TrainingDataImporter`, `TrainingDataExporter` are all `enum` types with only static methods, no stored state. They live in `Core/Data/` and are marked `nonisolated` when they have no MainActor dependencies.
- **Composition root orchestration:** `PeachApp.swift` currently injects environment closures that capture `[dataStore, profile, trendAnalyzer, thresholdTimeline]`. The `trainingDataImportAction` closure (PeachApp lines 94-109) not only calls `TrainingDataImporter.importData` but also rebuilds `PerceptualProfile`, `TrendAnalyzer`, and `ThresholdTimeline` from all records post-import.
- **Environment closure pattern:** `EnvironmentKeys.swift` defines optional closure types like `(() throws -> CSVDocument?)?` and `((CSVImportParser.ImportResult, TrainingDataImporter.ImportMode) throws -> TrainingDataImporter.ImportSummary)?`. These get replaced by the new service.
- **`CSVDocument`** lives in `Settings/` (not `Core/`) because it imports SwiftUI for `FileDocument` conformance. The new service in `Core/Data/` cannot import SwiftUI, so it returns raw CSV strings. The view wraps the string in `CSVDocument`.
- **`SoundSourceProvider`** protocol in `Core/Audio/` with a single concrete impl `SoundFontLibrary`. `SettingsScreen` accesses it via `@Environment(\.soundSourceProvider)`.
- **`SettingsKeys`** in `Settings/` centralizes all `@AppStorage` key names and defaults.
- **`trainingDataExportAction`** environment key is defined and wired in `PeachApp` but no longer consumed by any view — superseded by `csvExportDocumentAction`. Will be removed.

### Files to Reference

| File | Purpose |
| ---- | ------- |
| `Peach/Settings/SettingsScreen.swift` | Source of logic to extract — `handleFileSelection` (lines 306-337), `performImport` (339-351), `importSummaryMessage` (353-363), `refreshExportDocument` (365-371), `validatedSoundSource` (229-242), `.onAppear` validation (109-113) |
| `Peach/App/PeachApp.swift` | Composition root — closures at lines 86-109 contain export, import, and post-import rebuild logic |
| `Peach/App/EnvironmentKeys.swift` | Environment keys: `csvExportDocumentAction`, `trainingDataImportAction`, `trainingDataExportAction` (unused), `dataStoreResetter` |
| `Peach/Core/Data/TrainingDataStore.swift` | Data accessor — service depends on `fetchAllComparisons()`, `fetchAllPitchMatchings()`, `deleteAll()`, `save()` |
| `Peach/Core/Data/CSVImportParser.swift` | `nonisolated enum` — `parse(_ csvContent: String) -> ImportResult` |
| `Peach/Core/Data/TrainingDataImporter.swift` | `enum` — `importData(_:mode:into:) throws -> ImportSummary` |
| `Peach/Core/Data/TrainingDataExporter.swift` | `enum` — `export(from:) throws -> String` |
| `Peach/Settings/CSVDocument.swift` | `FileDocument` wrapper — `init(csvString:)`, `exportFileName() -> String` |
| `Peach/Core/Audio/SoundSourceProvider.swift` | Protocol — `availableSources: [SoundSourceID]` |
| `Peach/Settings/SettingsKeys.swift` | Key names and defaults — `defaultSoundSource`, `soundSource` key |
| `PeachTests/Core/Data/TrainingDataImporterTests.swift` | Test pattern reference — struct suite, factory methods, in-memory `ModelContainer`, real `TrainingDataStore` |

### Technical Decisions

- **`TrainingDataTransferService` as a `final class` with `@Observable`** — holds cached export CSV string, exposes it reactively to the view. Instantiated once in `PeachApp.swift`, injected via `@Environment`.
- **Service does NOT import SwiftUI** — returns `String?` for export (not `CSVDocument`). The view wraps the string in `CSVDocument`. This keeps the service in `Core/Data/` legally.
- **Post-import rebuild moves into service** — the `trainingDataImportAction` closure logic (profile reset + rebuild, trend rebuild, timeline rebuild from all records) moves into the service's `performImport` method. The service receives `PerceptualProfile`, `TrendAnalyzer`, `ThresholdTimeline` as init dependencies.
- **Import flow returns result types, not side-effects** — the service methods return structured results (`FileImportResult`, `ImportSummary`). The view maps results to UI state (alerts, error messages). This keeps the service testable without UI.
- **Sound source validation: `SettingsKeys.validateSoundSource(against:)`** — static function that reads/writes `UserDefaults.standard` directly. Called once in `PeachApp.init()`. Testable with a mock `SoundSourceProvider` and a custom `UserDefaults` suite.
- **Remove dead code** — `trainingDataExportAction` environment key and its `PeachApp` wiring are unused, removed in commit 1.

## Implementation Plan

### Tasks

#### Commit 1: Extract TrainingDataTransferService

- [x] Task 1: Create `TrainingDataTransferService` in `Peach/Core/Data/TrainingDataTransferService.swift`
  - File: `Peach/Core/Data/TrainingDataTransferService.swift` (new)
  - Action: Create a `final class TrainingDataTransferService` with `@Observable` macro.
  - **Init dependencies:** `dataStore: TrainingDataStore`, `profile: PerceptualProfile`, `trendAnalyzer: TrendAnalyzer`, `thresholdTimeline: ThresholdTimeline`
  - **Stored property:** `private(set) var exportCSV: String?` — cached export string, `nil` when no data exists
  - **Methods:**
    - `refreshExport()` — calls `TrainingDataExporter.export(from: dataStore)`, stores result in `exportCSV` (or `nil` if only header row). Catches errors and stores in an `exportError: Error?` property.
    - `readFileForImport(url: URL) -> FileReadResult` — handles security-scoped resource access, reads file contents, calls `CSVImportParser.parse()`, validates result. Returns a `FileReadResult` enum: `.success(CSVImportParser.ImportResult)` or `.failure(String)` (localized error message). This extracts `SettingsScreen.handleFileSelection` logic minus the URL picker result handling.
    - `performImport(parseResult: CSVImportParser.ImportResult, mode: TrainingDataImporter.ImportMode) throws -> TrainingDataImporter.ImportSummary` — calls `TrainingDataImporter.importData`, then rebuilds profile/trend/timeline from all records (moves logic from PeachApp lines 94-108), then calls `refreshExport()`.
    - `formatImportSummary(_ summary: TrainingDataImporter.ImportSummary) -> String` — extracts `importSummaryMessage` from SettingsScreen. Returns localized string.
  - **Nested type:** `enum FileReadResult { case success(CSVImportParser.ImportResult), failure(String) }`
  - Notes: No `import SwiftUI`. The class is implicitly `@MainActor` (project default). `@Observable` because `exportCSV` needs to drive view reactivity.

- [x] Task 2: Write tests for `TrainingDataTransferService`
  - File: `PeachTests/Core/Data/TrainingDataTransferServiceTests.swift` (new)
  - Action: Create `@Suite("TrainingDataTransferService")` struct with tests:
    - `refreshExport` returns CSV string when records exist
    - `refreshExport` returns nil when store is empty
    - `readFileForImport` returns success with valid CSV file (write a temp file to disk)
    - `readFileForImport` returns failure message for empty data file
    - `readFileForImport` returns failure with error details for parse-only-errors file
    - `performImport` with replace mode returns correct summary
    - `performImport` with merge mode returns correct summary
    - `performImport` rebuilds profile after import (verify profile state changed)
    - `performImport` refreshes export CSV after import
    - `formatImportSummary` with only imported records
    - `formatImportSummary` with skipped duplicates
    - `formatImportSummary` with parse errors
  - Notes: Use in-memory `ModelContainer` + real `TrainingDataStore` (same pattern as `TrainingDataImporterTests`). Create real `PerceptualProfile`, `TrendAnalyzer`, `ThresholdTimeline` instances — these are lightweight value-like objects that don't need mocking.

- [x] Task 3: Add `@Entry` for `TrainingDataTransferService` in `EnvironmentKeys.swift`
  - File: `Peach/App/EnvironmentKeys.swift`
  - Action: Add `@Entry var trainingDataTransferService: TrainingDataTransferService = TrainingDataTransferService(dataStore: TrainingDataStore(modelContext: ...), ...)` — the default needs a valid preview stub. Since `TrainingDataTransferService` requires init dependencies, create a minimal static factory `TrainingDataTransferService.preview()` or use an inline construction with preview stubs.
  - **Also remove:** `@Entry var trainingDataExportAction`, `@Entry var csvExportDocumentAction`, `@Entry var trainingDataImportAction` — all three replaced by the service.
  - Notes: Keep `dataStoreResetter` — it's still used by `resetAllTrainingData` in the view.

- [x] Task 4: Wire `TrainingDataTransferService` in `PeachApp.swift`
  - File: `Peach/App/PeachApp.swift`
  - Action:
    - Create `TrainingDataTransferService` instance in `init()`, passing `dataStore`, `profile`, `trendAnalyzer`, `thresholdTimeline`.
    - Store as `@State private var transferService: TrainingDataTransferService`.
    - Inject via `.environment(\.trainingDataTransferService, transferService)`.
    - **Remove:** the `csvExportDocumentAction` closure (lines 89-93), the `trainingDataImportAction` closure (lines 94-109), and the `trainingDataExportAction` closure (lines 86-88).

- [x] Task 5: Refactor `SettingsScreen` to use `TrainingDataTransferService`
  - File: `Peach/Settings/SettingsScreen.swift`
  - Action:
    - **Add:** `@Environment(\.trainingDataTransferService) private var transferService`
    - **Remove:** `@Environment(\.csvExportDocumentAction)`, `@Environment(\.trainingDataImportAction)`
    - **Remove methods:** `handleFileSelection`, `performImport`, `importSummaryMessage`, `refreshExportDocument`
    - **Remove state:** `@State private var csvDocument: CSVDocument?` — derive from `transferService.exportCSV` instead
    - **Update `.onAppear`:** call `transferService.refreshExport()` (remove sound source validation — that's commit 2)
    - **Update `dataSection`:** export button uses `transferService.exportCSV != nil` for disabled state; creates `CSVDocument(csvString:)` inline for the `fileExporter`
    - **Update `.fileImporter` handler:** call `transferService.readFileForImport(url:)`, switch on `FileReadResult` to set either `importParseResult`/`showImportModeChoice` or `importErrorMessage`/`showImportError`
    - **Update import confirmation buttons:** call `transferService.performImport(parseResult:mode:)`, handle result to set `importSummary`/`showImportSummary` or error state. Use `transferService.formatImportSummary()` in the alert message.
    - **Update `resetAllTrainingData`:** add `transferService.refreshExport()` call after reset (replacing the removed `refreshExportDocument()`).
    - **Keep:** all `@State` UI flags (`showExporter`, `showImportModeChoice`, etc.), `importParseResult` (still needed between file read and mode choice). The `fileImporter` result handler shrinks to: extract URL from result, call service, map result to UI state.
  - Notes: The `.fileImporter` closure receives `Result<URL, Error>`. The `.failure` case is still handled in the view (just `break`). The `.success` case extracts the URL and delegates to the service.

- [x] Task 6: Run full test suite and verify
  - Action: Run `bin/test.sh`, verify all tests pass including the new `TrainingDataTransferServiceTests`.

#### Commit 2: Extract Sound Source Validation

- [x] Task 7: Add `SettingsKeys.validateSoundSource(against:userDefaults:)` static function
  - File: `Peach/Settings/SettingsKeys.swift`
  - Action: Add a static function:
    ```
    static func validateSoundSource(
        against provider: some SoundSourceProvider,
        userDefaults: UserDefaults = .standard
    ) {
        let current = userDefaults.string(forKey: soundSource) ?? defaultSoundSource
        if !provider.availableSources.contains(where: { $0.rawValue == current }) {
            userDefaults.set(defaultSoundSource, forKey: soundSource)
        }
    }
    ```
  - Notes: Takes `UserDefaults` parameter for testability. Reads the raw key, not `@AppStorage`. The `SoundSourceProvider` parameter uses `some` (opaque type) to accept both `SoundFontLibrary` and test mocks.

- [x] Task 8: Write tests for `validateSoundSource`
  - File: `PeachTests/Settings/SettingsKeysTests.swift` (new)
  - Action: Create `@Suite("SettingsKeys")` struct with:
    - A `MockSoundSourceProvider` (private to test file) returning configurable `availableSources`
    - Test: valid source is not changed
    - Test: invalid source is reset to default
    - Test: missing key (nil) is set to default
  - Notes: Use a custom `UserDefaults(suiteName:)` per test to avoid polluting real defaults. Remove suite in test cleanup.

- [x] Task 9: Call `validateSoundSource` in `PeachApp.init()` and clean up `SettingsScreen`
  - File: `Peach/App/PeachApp.swift`
  - Action: Add `SettingsKeys.validateSoundSource(against: soundFontLibrary)` in `init()`, after `SoundFontLibrary` is created (after line 27).
  - File: `Peach/Settings/SettingsScreen.swift`
  - Action:
    - **Remove** the `validatedSoundSource` computed property (lines 229-242).
    - **Replace** `Picker` selection from `validatedSoundSource` to `$soundSource` (direct binding).
    - **Remove** the sound source validation from `.onAppear` (lines 110-112). The `.onAppear` should only contain `transferService.refreshExport()` after commit 1.

- [x] Task 10: Run full test suite and verify
  - Action: Run `bin/test.sh`, verify all tests pass including the new `SettingsKeysTests`.

### Acceptance Criteria

#### Export Extraction

- [x] AC 1: Given the app has training data, when SettingsScreen appears, then `transferService.exportCSV` is non-nil and the Export button is enabled.
- [x] AC 2: Given the app has no training data, when SettingsScreen appears, then `transferService.exportCSV` is nil and the Export button is disabled.
- [x] AC 3: Given the user taps Export, when the file exporter is presented, then a `CSVDocument` is created from `transferService.exportCSV` with the correct filename.

#### Import Extraction

- [x] AC 4: Given the user selects a valid CSV file, when `transferService.readFileForImport(url:)` is called, then it returns `.success` with parsed comparisons and pitch matchings.
- [x] AC 5: Given the user selects a file with no valid records (only parse errors), when `readFileForImport` is called, then it returns `.failure` with a message containing up to 5 error descriptions.
- [x] AC 6: Given the user selects a file with no valid records and no errors, when `readFileForImport` is called, then it returns `.failure` with "The file contains no valid training data."
- [x] AC 7: Given a successful file read, when the user chooses Replace mode, then `performImport` deletes existing data, imports new records, rebuilds profile/trend/timeline, refreshes export, and returns a summary.
- [x] AC 8: Given a successful file read, when the user chooses Merge mode, then `performImport` keeps existing data, imports non-duplicate records, rebuilds profile/trend/timeline, refreshes export, and returns a summary.
- [x] AC 9: Given an import summary with 10 imported, 3 skipped, 2 errors, when `formatImportSummary` is called, then it returns "10 records imported, 3 duplicates skipped, 2 errors."

#### Sound Source Validation

- [x] AC 10: Given `soundSource` in UserDefaults is "sf2:99:99" (not in available sources), when `SettingsKeys.validateSoundSource(against:)` runs, then `soundSource` is reset to `defaultSoundSource`.
- [x] AC 11: Given `soundSource` in UserDefaults is "sf2:8:80" (a valid source), when `SettingsKeys.validateSoundSource(against:)` runs, then `soundSource` is unchanged.
- [x] AC 12: Given `soundSource` is not set in UserDefaults, when `SettingsKeys.validateSoundSource(against:)` runs, then `soundSource` is set to `defaultSoundSource`.

#### Cleanup

- [x] AC 13: Given the refactoring is complete, then `SettingsScreen` no longer contains `handleFileSelection`, `performImport`, `importSummaryMessage`, `refreshExportDocument`, or `validatedSoundSource`.
- [x] AC 14: Given the refactoring is complete, then `EnvironmentKeys.swift` no longer contains `trainingDataExportAction`, `csvExportDocumentAction`, or `trainingDataImportAction`.
- [x] AC 15: Given the refactoring is complete, then `SettingsScreen` has no business logic beyond UI state management — all data operations are delegated to `TrainingDataTransferService` or environment closures.

## Additional Context

### Dependencies

- Existing `CSVImportParser`, `TrainingDataImporter`, `CSVDocument`, `TrainingDataExporter` types remain unchanged
- `TrainingDataStore` API remains unchanged
- `PerceptualProfile`, `TrendAnalyzer`, `ThresholdTimeline` APIs remain unchanged (`.reset()`, `.resetMatching()`, `.rebuild(from:)`, `.update()`, `.updateMatching()`)

### Testing Strategy

- **`TrainingDataTransferServiceTests`:** in-memory `ModelContainer` + real `TrainingDataStore` (same pattern as `TrainingDataImporterTests`). Real `PerceptualProfile`, `TrendAnalyzer`, `ThresholdTimeline` — lightweight, no mocking needed. Temp files on disk for `readFileForImport` tests.
- **`SettingsKeysTests`:** custom `UserDefaults(suiteName:)` per test for isolation. Private `MockSoundSourceProvider` in test file.
- Full test suite must pass before each commit.
- Manual smoke test: export, import (replace + merge), reset — verify identical behavior to before.

### Notes

- `resetAllTrainingData` stays in the view — it's one closure call with a `do/catch`. Could be moved to the service in future but is out of scope.
- `CSVDocument.exportFileName()` stays in `Settings/` — it's a view-layer concern.
- The `dataStoreResetter` environment closure stays — it's used by `resetAllTrainingData` and involves `ComparisonSession.resetTrainingData()` which the transfer service doesn't need to know about.
- After this refactoring, `SettingsScreen` should drop from ~379 lines to ~280 lines, with zero business logic methods.

## Review Notes
- Adversarial review completed
- Findings: 12 total, 5 fixed, 7 skipped (noise)
- Resolution approach: auto-fix
- Fixed: export error alerting, localization fragments, try! in preview, security-scoped resource guard, UserDefaults test cleanup
