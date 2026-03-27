# Story 64.3: Make Merge-Mode Import Transactional

Status: ready-for-dev

## Story

As a **user importing training data**,
I want merge-mode imports to either fully succeed or fully roll back,
so that a failure partway through doesn't leave my database in a half-imported state.

## Acceptance Criteria

1. **Given** a merge-mode import with records for 4 disciplines **When** discipline C throws an error during save **Then** records from disciplines A and B are not persisted — the entire import is rolled back.

2. **Given** a merge-mode import **When** all disciplines import successfully **Then** all records are persisted atomically.

3. **Given** `TrainingDataImporter.mergeRecords()` **When** wrapping the merge in a transaction **Then** each discipline's `mergeImportRecords()` operates within the same `modelContext.transaction {}` block.

4. **Given** `DuplicateKey` timestamp precision **When** building duplicate keys **Then** timestamps use millisecond precision (`Int64(timestamp.timeIntervalSinceReferenceDate * 1000)`) instead of second precision, preventing false-positive duplicate detection for records created less than 1 second apart.

5. **Given** the full test suite **When** run **Then** all existing tests pass with zero regressions.

## Tasks / Subtasks

- [ ] Task 1: Wrap merge imports in a transaction (AC: #1, #2, #3)
  - [ ] 1.1 Read `TrainingDataImporter.swift` and `TrainingDataStore.swift`
  - [ ] 1.2 Add a method to `TrainingDataStore` that accepts a closure and runs it inside `modelContext.transaction { }` (similar to `replaceAllRecords` but generic)
  - [ ] 1.3 Refactor `mergeRecords()` to execute all discipline merges inside this single transaction
  - [ ] 1.4 If any discipline throws, the transaction rolls back and the error propagates to the caller

- [ ] Task 2: Fix duplicate-key timestamp precision (AC: #4)
  - [ ] 2.1 In `DuplicateKey.swift`, change `PitchDuplicateKey.timestampSeconds` and `RhythmDuplicateKey.timestampSeconds` to use millisecond precision: `Int64(timestamp.timeIntervalSinceReferenceDate * 1000)`
  - [ ] 2.2 Rename the property to `timestampMillis` for clarity
  - [ ] 2.3 Update all initializers and usages

- [ ] Task 3: Write tests (AC: #1, #4, #5)
  - [ ] 3.1 Test: merge import where second discipline save throws — verify first discipline's records are NOT in the store (transaction rollback)
  - [ ] 3.2 Test: two records 500ms apart with same (referenceNote, targetNote, trainingType) — both are imported (not falsely deduplicated)
  - [ ] 3.3 Test: two records at the exact same millisecond with same key fields — correctly deduplicated

- [ ] Task 4: Run full test suite (AC: #5)

## Dev Notes

### Current Problem

`TrainingDataImporter.mergeRecords()` iterates disciplines in a loop, calling `discipline.mergeImportRecords(from:into:)` for each. Each call saves records individually via `store.save()`. If discipline C throws after A and B have saved, A and B's records are persisted but the user sees an error. There's no way to know which records were imported.

### Transaction Approach

`TrainingDataStore` already uses `modelContext.transaction` in `replaceAllRecords()`. The merge path needs the same pattern. The simplest approach: add a `withinTransaction(_ work: () throws -> T) throws -> T` method on `TrainingDataStore` that wraps the closure in `modelContext.transaction`.

### Timestamp Precision

`DuplicateKey` uses `Int64(timestamp.timeIntervalSinceReferenceDate)` — integer seconds. For rapid training (e.g., rhythm training at 120 BPM), multiple records per second are common. Two records at timestamps 1000.1 and 1000.6 both become key 1000, causing the second to be falsely skipped in merge mode.

### Source File Locations

| File | Path |
|------|------|
| TrainingDataImporter | `Peach/Core/Data/TrainingDataImporter.swift` |
| TrainingDataStore | `Peach/Core/Data/TrainingDataStore.swift` |
| DuplicateKey | `Peach/Core/Data/DuplicateKey.swift` |

### References

- [Source: Peach/Core/Data/TrainingDataImporter.swift] — mergeRecords loop
- [Source: Peach/Core/Data/DuplicateKey.swift] — timestamp truncation
- [Source: Peach/Core/Data/TrainingDataStore.swift] — existing transaction pattern in replaceAllRecords
