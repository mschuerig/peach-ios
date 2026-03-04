# Story 34.2: Implement Merge Logic with Duplicate Detection

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer**,
I want merge and replace strategies for imported data,
So that users can choose how to combine imported data with existing records.

## Acceptance Criteria

1. **Given** a duplicate is defined as a record matching on `timestamp` + `referenceNote` + `targetNote` + `trainingType` **When** merge mode is selected **Then** only non-duplicate records are inserted **And** existing records are not modified

2. **Given** replace mode is selected **When** import is executed **Then** all existing training data is deleted **And** all imported records are inserted

3. **Given** an import operation completes **When** the result is returned **Then** it includes a summary: records imported, records skipped (duplicates), records with errors

4. **Given** the merge and replace logic **When** unit tests are run **Then** both modes are verified including edge cases: empty import, all duplicates, mixed valid/invalid rows

## Tasks / Subtasks

- [x] Task 1: Define ImportMode enum (AC: #1, #2)
  - [x] 1.1 Write tests for ImportMode cases
  - [x] 1.2 Create `ImportMode` enum in `TrainingDataImporter.swift` with `.replace` and `.merge` cases

- [x] Task 2: Define ImportSummary result type (AC: #3)
  - [x] 2.1 Write tests for ImportSummary construction and computed properties
  - [x] 2.2 Create `ImportSummary` struct with fields: `comparisonsImported`, `pitchMatchingsImported`, `comparisonsSkipped`, `pitchMatchingsSkipped`, `parseErrors` count
  - [x] 2.3 Add computed property `totalImported` and `totalSkipped`

- [x] Task 3: Implement replace mode (AC: #2, #3)
  - [x] 3.1 Write tests: replace with records deletes all existing and inserts all imported; replace with empty import deletes all existing; replace propagates store errors
  - [x] 3.2 Implement `TrainingDataImporter.importData(_:mode:into:) throws -> ImportSummary` for `.replace` mode
  - [x] 3.3 Call `store.deleteAll()` then save all parsed comparison and pitch matching records

- [x] Task 4: Implement duplicate detection for merge mode (AC: #1)
  - [x] 4.1 Write tests: duplicate detected by timestamp+referenceNote+targetNote+trainingType; non-duplicate inserted; existing records not modified
  - [x] 4.2 Define `DuplicateKey` private struct (Hashable) containing the four discriminator fields
  - [x] 4.3 Build a `Set<DuplicateKey>` from existing records fetched via `store.fetchAllComparisons()` and `store.fetchAllPitchMatchings()`
  - [x] 4.4 Filter imported records against duplicate set

- [x] Task 5: Implement merge mode (AC: #1, #3)
  - [x] 5.1 Write tests: merge inserts only non-duplicates; merge with all duplicates imports zero; merge with no duplicates imports all; merge with mixed duplicates reports correct counts
  - [x] 5.2 Implement `.merge` mode in `importData` method using duplicate detection from Task 4

- [x] Task 6: Edge case tests (AC: #4)
  - [x] 6.1 Write test: empty import (no records) returns zero summary for both modes
  - [x] 6.2 Write test: import with only parse errors returns error count in summary
  - [x] 6.3 Write test: records with identical timestamps but different training types are NOT duplicates
  - [x] 6.4 Write test: records with identical timestamps and training type but different notes are NOT duplicates

- [x] Task 7: Run full test suite (AC: #4)
  - [x] 7.1 Run `bin/test.sh` and verify zero regressions

## Dev Notes

### Architecture Pattern

`TrainingDataImporter` mirrors the `TrainingDataExporter` pattern — a stateless `nonisolated enum` with a single static method:

```swift
enum TrainingDataImporter {
    static func importData(
        _ parseResult: CSVImportParser.ImportResult,
        mode: ImportMode,
        into store: TrainingDataStore
    ) throws -> ImportSummary
}
```

**CRITICAL:** This enum is NOT `nonisolated`. Unlike the parser (pure computation), the importer calls `TrainingDataStore` methods which are `@MainActor`-isolated. Since the project uses default MainActor isolation, the enum and its static method are implicitly `@MainActor` — do NOT add explicit `@MainActor` or `nonisolated`.

**Lesson from story 34.1:** The `CSVImportParser` was correctly `nonisolated` because it does pure string parsing. The importer does I/O through `TrainingDataStore`, so it must stay on MainActor. Do not copy the `nonisolated` pattern from the parser.

### Import Flow (called by story 34.3 UI)

```
User selects CSV file
  → CSVImportParser.parse(csvString)           [story 34.1, already done]
  → Returns ImportResult (records + errors)
  → UI shows error summary if any parse errors
  → User chooses Replace or Merge
  → TrainingDataImporter.importData(result, mode: .merge/.replace, into: store)  [THIS STORY]
  → Returns ImportSummary
  → UI displays summary
```

### Duplicate Detection Strategy

A record is a duplicate if ALL four fields match an existing record:
- `timestamp` (Date — exact match)
- `referenceNote` (Int)
- `targetNote` (Int)
- `trainingType` (comparison vs pitchMatching — implicit from record type)

**Implementation approach:**
1. Fetch all existing records: `store.fetchAllComparisons()` + `store.fetchAllPitchMatchings()`
2. Build a `Set<DuplicateKey>` from existing records
3. For each imported record, construct its `DuplicateKey` and check membership
4. Insert only non-members

```swift
private struct DuplicateKey: Hashable {
    let timestamp: Date
    let referenceNote: Int
    let targetNote: Int
    let trainingType: String  // "comparison" or "pitchMatching"
}
```

**Why fetch-then-filter (not SwiftData predicates per record):**
- Records count is in the hundreds to low thousands (acceptable for in-memory)
- A single fetch + Set lookup is O(n+m) vs O(n*m) for per-record predicate queries
- Matches the existing `TrainingDataExporter` pattern which fetches all records into memory
- Avoids complex SwiftData predicate construction for compound keys

### Replace Mode

Replace is straightforward:
1. Call `store.deleteAll()` — atomic transaction deletes all ComparisonRecord and PitchMatchingRecord
2. Save each imported record via `store.save()`
3. Return summary with all imported counts, zero skipped

**Note:** `deleteAll()` already uses a transaction for atomicity. However, the subsequent saves are individual. If a save fails mid-import in replace mode, some records will be lost. For MVP this is acceptable — a future enhancement could wrap the entire operation in a transaction.

### Merge Mode

1. Fetch all existing records
2. Build duplicate key set
3. For each imported comparison: check duplicate set → skip or save
4. For each imported pitch matching: check duplicate set → skip or save
5. Return summary with imported and skipped counts

### ImportSummary Type

```swift
struct ImportSummary {
    let comparisonsImported: Int
    let pitchMatchingsImported: Int
    let comparisonsSkipped: Int
    let pitchMatchingsSkipped: Int
    let parseErrorCount: Int

    var totalImported: Int { comparisonsImported + pitchMatchingsImported }
    var totalSkipped: Int { comparisonsSkipped + pitchMatchingsSkipped }
}
```

The `parseErrorCount` comes from the `CSVImportParser.ImportResult.errors.count` — passed through so the UI can show a complete summary without needing to hold onto the parse result separately.

### ImportMode Type

```swift
enum ImportMode {
    case replace
    case merge
}
```

Both types are nested inside `TrainingDataImporter` to keep the API surface contained:
```swift
enum TrainingDataImporter {
    enum ImportMode { case replace, merge }
    struct ImportSummary { ... }
    static func importData(...) throws -> ImportSummary
}
```

### Existing Code to Reuse (Do NOT Reinvent)

| What | Where | How to Use |
|---|---|---|
| Parse result with records + errors | `CSVImportParser.ImportResult` | Input to `importData()` |
| Delete all records atomically | `TrainingDataStore.deleteAll()` | Replace mode |
| Save individual records | `TrainingDataStore.save(_:)` (both overloads) | Insert records |
| Fetch all comparisons | `TrainingDataStore.fetchAllComparisons()` | Build duplicate set for merge |
| Fetch all pitch matchings | `TrainingDataStore.fetchAllPitchMatchings()` | Build duplicate set for merge |
| ComparisonRecord init | `ComparisonRecord(referenceNote:targetNote:centOffset:isCorrect:interval:tuningSystem:timestamp:)` | Already constructed by parser |
| PitchMatchingRecord init | `PitchMatchingRecord(referenceNote:targetNote:initialCentOffset:userCentError:interval:tuningSystem:timestamp:)` | Already constructed by parser |

### Testing Patterns

Follow the `TrainingDataExporterTests` pattern — use **real SwiftData in-memory containers**, not mocks:

```swift
@Suite("TrainingDataImporter")
struct TrainingDataImporterTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: ComparisonRecord.self, PitchMatchingRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeStore() -> TrainingDataStore {
        TrainingDataStore(modelContext: container.mainContext)
    }

    private func fixedDate(minutesOffset: Double = 0) -> Date {
        Date(timeIntervalSinceReferenceDate: 794_394_000 + minutesOffset * 60)
    }

    @Test("replace mode deletes existing and inserts all imported")
    func replaceModeDeletesAndInserts() async throws { ... }
}
```

**Why real SwiftData, not MockTrainingDataStore:**
- The importer's correctness depends on actual persistence behavior (deduplication, fetch-after-save)
- MockTrainingDataStore doesn't implement `delete()` or `deleteAll()`
- The exporter tests already establish this pattern successfully
- In-memory SwiftData is fast and deterministic

**All test functions must be `async`** — even if the logic is synchronous (project convention).

**Test file:** `PeachTests/Core/Data/TrainingDataImporterTests.swift`

### File Locations

| New File | Path |
|---|---|
| TrainingDataImporter.swift | `Peach/Core/Data/TrainingDataImporter.swift` |
| TrainingDataImporterTests.swift | `PeachTests/Core/Data/TrainingDataImporterTests.swift` |

**No modifications to existing files required.** The importer is self-contained — it uses `TrainingDataStore`, `CSVImportParser.ImportResult`, and the record types, all through their existing public APIs.

### Project Structure Notes

- Follows `Core/Data/` placement consistent with `CSVImportParser`, `TrainingDataExporter`, `TrainingDataStore`
- Test file mirrors source at `PeachTests/Core/Data/`
- No new dependencies, no environment keys, no composition root changes
- The importer is a pure service utility — it does not need to be injected via `@Environment` (story 34.3 will call it directly from the import action handler)

### Previous Story Intelligence (34.1)

Key learnings from story 34.1 that impact this story:

1. **`CSVImportParser.ImportResult`** (not `Result` — renamed during code review to avoid shadowing `Swift.Result`) contains `comparisons: [ComparisonRecord]`, `pitchMatchings: [PitchMatchingRecord]`, `errors: [CSVImportError]`
2. **`TuningSystem.init?(identifier:)`** was renamed from `fromStorageIdentifier` in 34.1 — use the new name
3. **Records from parser are already fully constructed** — the parser builds `ComparisonRecord` and `PitchMatchingRecord` instances with all fields populated. The importer just needs to save them.
4. **Parser handles CRLF line endings** — the importer doesn't need to worry about line ending normalization
5. **ISO 8601 timestamps with fractional seconds** — the parser handles these; timestamps in records are `Date` objects for exact comparison
6. **Test suite is at 899 tests** — ensure no regressions

### Git Intelligence

Recent commits show the standard workflow:
- `Create story X.Y` → `Implement story X.Y` → `Review story X.Y`
- Story 34.1 added 3 new files (parser, error type, tests) and modified 5 existing files (TuningSystem rename)
- Code review caught: `Result` naming collision, access control (private for internal methods), CRLF handling via `unicodeScalars`, fractional-second ISO 8601 support

### References

- [Source: Peach/Core/Data/CSVImportParser.swift] — Parser with ImportResult type
- [Source: Peach/Core/Data/CSVImportError.swift] — Error types for parse failures
- [Source: Peach/Core/Data/TrainingDataStore.swift] — All CRUD methods including deleteAll()
- [Source: Peach/Core/Data/TrainingDataExporter.swift] — Mirror pattern for importer
- [Source: Peach/Core/Data/ComparisonRecord.swift] — Data model fields
- [Source: Peach/Core/Data/PitchMatchingRecord.swift] — Data model fields
- [Source: PeachTests/Core/Data/TrainingDataExporterTests.swift] — Test pattern with real SwiftData
- [Source: docs/planning-artifacts/epics.md#Epic 34] — Epic and story definitions
- [Source: docs/project-context.md] — TDD workflow, testing conventions, commit format
- [Source: docs/implementation-artifacts/34-1-implement-csv-import-parser.md] — Previous story learnings

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None — implementation was straightforward with no blocking issues.

### Completion Notes List

- Implemented `TrainingDataImporter` enum with nested `ImportMode` and `ImportSummary` types
- Replace mode: calls `store.deleteAll()` then saves all imported records
- Merge mode: builds `Set<DuplicateKey>` from existing records (fetch-then-filter O(n+m) approach), filters imported records against set, inserts only non-duplicates
- `DuplicateKey` is a private Hashable struct matching on timestamp + referenceNote + targetNote + trainingType
- Newly inserted keys are added to the duplicate set to handle duplicates within the import file itself
- Parse error count passed through from `ImportResult.errors.count` for UI summary
- 18 new tests covering: ImportMode cases, ImportSummary fields/computed properties, replace mode (with records, empty, errors), merge mode (non-duplicates, all duplicates, no duplicates, mixed, existing not modified), edge cases (empty import both modes, only errors, same timestamp different type, same timestamp different notes)
- Full test suite: 917 tests pass, zero regressions (was 899)

### Change Log

- 2026-03-04: Implemented story 34.2 — TrainingDataImporter with merge/replace modes and duplicate detection
- 2026-03-04: Code review fixes — replaced magic strings with TrainingType constants, added intra-file dedup test, removed weak ImportMode test, simplified makeStore() helper, added non-atomicity comment on replace mode

### File List

- `Peach/Core/Data/TrainingDataImporter.swift` (new)
- `PeachTests/Core/Data/TrainingDataImporterTests.swift` (new)
- `docs/implementation-artifacts/34-2-implement-merge-logic-with-duplicate-detection.md` (modified)
- `docs/implementation-artifacts/sprint-status.yaml` (modified)
