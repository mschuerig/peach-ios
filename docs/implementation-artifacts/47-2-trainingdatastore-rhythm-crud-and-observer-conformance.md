# Story 47.2: TrainingDataStore Rhythm CRUD and Observer Conformance

Status: ready-for-dev

## Story

As a **developer**,
I want `TrainingDataStore` extended with rhythm record CRUD and observer conformances,
So that rhythm results are automatically persisted when sessions notify observers.

## Acceptance Criteria

1. **Given** `TrainingDataStore`, **when** extended for rhythm, **then** it provides: `save(_ record: RhythmComparisonRecord) throws`, `save(_ record: RhythmMatchingRecord) throws`, `fetchAllRhythmComparisons() throws -> [RhythmComparisonRecord]`, `fetchAllRhythmMatchings() throws -> [RhythmMatchingRecord]`, `deleteAllRhythmComparisons() throws`, `deleteAllRhythmMatchings() throws`.

2. **Given** `TrainingDataStore` conforms to `RhythmComparisonObserver`, **when** `rhythmComparisonCompleted(_:)` is called, **then** a `RhythmComparisonRecord` is created from the result and saved.

3. **Given** `TrainingDataStore` conforms to `RhythmMatchingObserver`, **when** `rhythmMatchingCompleted(_:)` is called, **then** a `RhythmMatchingRecord` is created from the result and saved.

4. **Given** save errors, **when** they occur in observer methods, **then** they are logged via `os.Logger` at `.warning` level (not propagated — consistent with existing pitch observer error handling).

5. **Given** unit tests, **when** they verify CRUD operations, **then** save, fetch, and delete work correctly for both rhythm record types.

## Tasks / Subtasks

- [ ] Task 1: Add rhythm CRUD methods to `TrainingDataStore` (AC: #1)
  - [ ] `save(_ record: RhythmComparisonRecord) throws`
  - [ ] `save(_ record: RhythmMatchingRecord) throws`
  - [ ] `fetchAllRhythmComparisons() throws -> [RhythmComparisonRecord]`
  - [ ] `fetchAllRhythmMatchings() throws -> [RhythmMatchingRecord]`
  - [ ] `deleteAllRhythmComparisons() throws`
  - [ ] `deleteAllRhythmMatchings() throws`

- [ ] Task 2: Add `RhythmComparisonObserver` conformance (AC: #2, #4)
  - [ ] Extension on `TrainingDataStore` conforming to `RhythmComparisonObserver`
  - [ ] Convert `CompletedRhythmComparison` → `RhythmComparisonRecord` and save
  - [ ] Log errors at `.warning` level, do not propagate

- [ ] Task 3: Add `RhythmMatchingObserver` conformance (AC: #3, #4)
  - [ ] Extension on `TrainingDataStore` conforming to `RhythmMatchingObserver`
  - [ ] Convert `CompletedRhythmMatching` → `RhythmMatchingRecord` and save
  - [ ] Log errors at `.warning` level, do not propagate

- [ ] Task 4: Write tests for rhythm CRUD and observer conformances (AC: #5)
  - [ ] Test save and fetch for `RhythmComparisonRecord`
  - [ ] Test save and fetch for `RhythmMatchingRecord`
  - [ ] Test `deleteAllRhythmComparisons` deletes only rhythm comparison records
  - [ ] Test `deleteAllRhythmMatchings` deletes only rhythm matching records
  - [ ] Test `rhythmComparisonCompleted` creates and persists correct record
  - [ ] Test `rhythmMatchingCompleted` creates and persists correct record
  - [ ] Test fetch returns records sorted by timestamp (oldest first)

- [ ] Task 5: Run full test suite
  - [ ] `bin/test.sh` — all tests pass, no regressions

## Dev Notes

### Follow the existing pitch CRUD pattern exactly

All six new methods mirror the pitch CRUD pattern already in `TrainingDataStore.swift`:

```swift
// Save pattern (same as save(_ record: PitchComparisonRecord)):
func save(_ record: RhythmComparisonRecord) throws {
    modelContext.insert(record)
    do { try modelContext.save() }
    catch { throw DataStoreError.saveFailed("Failed to save RhythmComparisonRecord: \(error.localizedDescription)") }
}

// Fetch pattern (same as fetchAllPitchComparisons):
func fetchAllRhythmComparisons() throws -> [RhythmComparisonRecord] {
    let descriptor = FetchDescriptor<RhythmComparisonRecord>(
        sortBy: [SortDescriptor(\.timestamp, order: .forward)]
    )
    do { return try modelContext.fetch(descriptor) }
    catch { throw DataStoreError.fetchFailed("Failed to fetch rhythm comparison records: \(error.localizedDescription)") }
}

// Batch delete pattern:
func deleteAllRhythmComparisons() throws {
    do {
        try modelContext.transaction {
            try modelContext.delete(model: RhythmComparisonRecord.self)
        }
    } catch {
        throw DataStoreError.deleteFailed("Failed to delete all rhythm comparison records: \(error.localizedDescription)")
    }
}
```

### Domain type → raw type conversion for observer conformances

The observer methods convert domain types to raw persistence types. Key conversions:

| Domain type | Raw type | Conversion |
|---|---|---|
| `result.tempo` (`TempoBPM`) | `Int` | `result.tempo.value` |
| `result.offset` (`RhythmOffset`) | `Double` (ms) | `result.offset.duration / .milliseconds(1)` |
| `result.userOffset` (`RhythmOffset`) | `Double` (ms) | `result.userOffset.duration / .milliseconds(1)` |
| `result.isCorrect` (`Bool`) | `Bool` | Direct |
| `result.timestamp` (`Date`) | `Date` | Direct |

`Duration / Duration` returns `Double` in Swift — `offset.duration / .milliseconds(1)` gives signed milliseconds directly.

### RhythmComparisonObserver conformance

```swift
extension TrainingDataStore: RhythmComparisonObserver {
    func rhythmComparisonCompleted(_ result: CompletedRhythmComparison) {
        let record = RhythmComparisonRecord(
            tempoBPM: result.tempo.value,
            offsetMs: result.offset.duration / .milliseconds(1),
            isCorrect: result.isCorrect,
            timestamp: result.timestamp
        )
        do {
            try save(record)
        } catch let error as DataStoreError {
            Self.logger.warning("Rhythm comparison save error: \(error.localizedDescription)")
        } catch {
            Self.logger.warning("Rhythm comparison unexpected error: \(error.localizedDescription)")
        }
    }
}
```

### RhythmMatchingObserver conformance

```swift
extension TrainingDataStore: RhythmMatchingObserver {
    func rhythmMatchingCompleted(_ result: CompletedRhythmMatching) {
        let record = RhythmMatchingRecord(
            tempoBPM: result.tempo.value,
            userOffsetMs: result.userOffset.duration / .milliseconds(1),
            timestamp: result.timestamp
        )
        do {
            try save(record)
        } catch let error as DataStoreError {
            Self.logger.warning("Rhythm matching save error: \(error.localizedDescription)")
        } catch {
            Self.logger.warning("Rhythm matching unexpected error: \(error.localizedDescription)")
        }
    }
}
```

Note: `CompletedRhythmMatching.expectedOffset` is NOT stored — only `userOffset` is persisted (the record has no `expectedOffsetMs` field).

### Test infrastructure

Use the same in-memory container pattern from existing tests:

```swift
private func makeTestContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: PitchComparisonRecord.self,
        PitchMatchingRecord.self,
        RhythmComparisonRecord.self,
        RhythmMatchingRecord.self,
        configurations: config
    )
}
```

All four model types must be in the schema — SwiftData requires the full schema even if a test only exercises one type.

### File placement

- CRUD methods and observer conformances go in `Peach/Core/Data/TrainingDataStore.swift` — add new MARK sections following the existing pattern
- Tests go in `PeachTests/Core/Data/TrainingDataStoreTests.swift` — add to existing test suite

### deleteAll() already handles rhythm records

`deleteAll()` (line 61) already deletes `RhythmComparisonRecord` and `RhythmMatchingRecord` — this was added in story 47.1's review. The new per-type delete methods (`deleteAllRhythmComparisons`, `deleteAllRhythmMatchings`) provide granular deletion needed by story 47.3's `resetRhythm()`.

### What NOT to do

- Do NOT modify `deleteAll()` — it already handles all four record types
- Do NOT modify `replaceAllRecords()` — rhythm record import is not in scope
- Do NOT add `RhythmProfile` conformance to `PerceptualProfile` — that's story 47.3
- Do NOT update `MockTrainingDataStore` — that's needed when sessions are wired up (epic 48)
- Do NOT wire observers in `PeachApp.swift` — that happens when rhythm sessions exist (epic 48)
- Do NOT use domain types (`TempoBPM`, `RhythmOffset`) in SwiftData stored properties
- Do NOT create `Utils/` or `Helpers/` directories

### Project Structure Notes

- All changes in `Peach/Core/Data/TrainingDataStore.swift` — no new files for the implementation
- Tests added to existing `PeachTests/Core/Data/TrainingDataStoreTests.swift`
- No new directories needed

### References

- [Source: Peach/Core/Data/TrainingDataStore.swift — existing CRUD and observer pattern to follow]
- [Source: Peach/Core/Data/RhythmComparisonRecord.swift — SwiftData model (story 47.1)]
- [Source: Peach/Core/Data/RhythmMatchingRecord.swift — SwiftData model (story 47.1)]
- [Source: Peach/Core/Training/RhythmComparisonObserver.swift — observer protocol]
- [Source: Peach/Core/Training/RhythmMatchingObserver.swift — observer protocol]
- [Source: Peach/Core/Training/CompletedRhythmComparison.swift — result type with TempoBPM, RhythmOffset, isCorrect, timestamp]
- [Source: Peach/Core/Training/CompletedRhythmMatching.swift — result type with TempoBPM, expectedOffset, userOffset, timestamp]
- [Source: Peach/Core/Music/RhythmOffset.swift — domain type wrapping Duration, `.duration` property]
- [Source: Peach/Core/Music/TempoBPM.swift — domain type, `.value` for raw Int]
- [Source: PeachTests/Core/Data/TrainingDataStoreTests.swift — existing test patterns]
- [Source: docs/planning-artifacts/epics.md#Epic 47: Remember Every Beat]
- [Source: docs/project-context.md — project rules and conventions]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
