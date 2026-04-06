# Story 75.9: Core Dependency Direction — DuplicateKey and Data Store

Status: done

## Story

As a **developer maintaining the Core layer**,
I want Core free of knowledge about specific training disciplines,
so that adding a discipline doesn't force changes to Core files.

## Background

The walkthrough (Layers 3, 4) found three dependency-direction violations in the data layer:

1. `DuplicateKey.swift` lives in `Core/Data/` but has convenience inits referencing concrete discipline record types and free functions calling discipline-specific fetch methods.
2. `PitchDiscriminationRecordStoring` is an orphaned protocol — only PitchDiscrimination has a narrow storing protocol; the other 3 disciplines use `TrainingRecordPersisting` directly.
3. `TrainingDataStore` has 4 per-type convenience fetch methods (`fetchAllPitchDiscriminations()`, etc.) that hardcode concrete record types with timestamp sorting.

Note: `PeachSchema` defining all record models in Core was already evaluated in Story 64.8 and accepted as a documented SwiftData constraint. This story does NOT revisit that decision.

**Walkthrough sources:** Layer 3 observation #1; Layer 4 observations #1, #7.

## Acceptance Criteria

1. **Given** `DuplicateKey.swift` **When** inspected **Then** it lives near the discipline types or in a shared import/export area, not in `Core/Data/`.
2. **Given** `PitchDiscriminationRecordStoring` **When** inspected **Then** it is removed. `PitchDiscriminationStoreAdapter` uses `TrainingRecordPersisting` directly (matching the other 3 disciplines).
3. **Given** `TrainingDataStore` **When** inspected **Then** the 4 per-type convenience fetch methods (`fetchAllPitchDiscriminations()`, `fetchAllPitchMatchings()`, `fetchAllRhythmOffsetDetections()`, `fetchAllContinuousRhythmMatchings()`) are replaced by a single generic sorted fetch, e.g., `fetchAllSorted<T: PersistentModel & Timestamped>(_ type: T.Type) -> [T]`.
4. **Given** all callers of the removed fetch methods **When** inspected **Then** they use the generic replacement.
5. **Given** both platforms **When** built and tested **Then** all tests pass with zero regressions.

## Tasks / Subtasks

- [x] Task 1: Move DuplicateKey.swift (AC: #1)
  - [x] Identify the best location (e.g., a shared `Training/` area or `Settings/Import/`)
  - [x] Move the file and update any imports
  - [x] Remove the `// WALKTHROUGH:` annotation from the file

- [x] Task 2: Remove PitchDiscriminationRecordStoring (AC: #2)
  - [x] Find all conformers and callers
  - [x] Replace with `TrainingRecordPersisting` usage
  - [x] Delete the protocol file

- [x] Task 3: Create generic sorted fetch (AC: #3, #4)
  - [x] Define a `Timestamped` protocol with `var timestamp: Date { get }` (or use an existing sort descriptor approach)
  - [x] Conform all 4 record types to `Timestamped`
  - [x] Add `fetchAllSorted<T: PersistentModel & Timestamped>(_ type: T.Type) -> [T]` to `TrainingDataStore`
  - [x] Replace the 4 per-type methods with calls to the generic one
  - [x] Update all callers (discipline `feedRecords` methods, export pipeline)

- [x] Task 4: Build and test both platforms (AC: #5)
  - [x] `bin/test.sh && bin/test.sh -p mac`

## Dev Notes

### Source File Locations

| File | Role |
|------|------|
| `Peach/Core/Data/DuplicateKey.swift` | Move out of Core |
| `Peach/Core/Data/TrainingDataStore.swift` | Replace per-type fetches |
| `Peach/PitchDiscrimination/PitchDiscriminationRecordStoring.swift` | Remove |
| `Peach/Core/Data/PeachSchema.swift` | Record types need `Timestamped` conformance |

### Existing WALKTHROUGH Annotations

- `Peach/Core/Data/DuplicateKey.swift` (lines 3–4)
- `Peach/Core/Data/TrainingDataStore.swift` (lines 115–116)

### Callers of Per-Type Fetch Methods

The per-type fetch methods are called by:
- Each discipline's `feedRecords(from:into:)` method (needs sorted data for profile replay)
- The CSV export pipeline (`TrainingDataExporter`)
- Possibly the merge/import pipeline

All callers just need `[T]` sorted by timestamp — the generic version serves them all.

### SwiftData Generic Fetch Constraint

`ModelContext.fetch(FetchDescriptor<T>)` requires `T: PersistentModel`. The generic sorted fetch adds a `& Timestamped` constraint. Verify that SwiftData's macro-generated code doesn't interfere with adding protocol conformance to `@Model` classes (Story 64.8 noted that conformances must be added via extensions).

### What NOT to Change

- Do not change `PeachSchema` or move record model definitions (accepted exception per 64.8)
- Do not change the generic `fetchAll<T>(_ type: T.Type)` method — keep it for unsorted fetches
- Do not change `TrainingRecordPersisting` protocol itself

### References

- [Source: docs/walkthrough/3-training-sessions.md — observation #1]
- [Source: docs/walkthrough/4-data-and-profiles.md — observations #1, #7]
- [Source: docs/implementation-artifacts/64-8-fix-swiftdata-dependency-boundary-violations.md — accepted exception context]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6

### Debug Log References
- SwiftData generic `SortDescriptor(\.timestamp)` fails with `KeyPath<T, Date>` not conforming to `Sendable` for generic `T`. Workaround: fetch unsorted via `FetchDescriptor<T>()` then sort in-memory with `.sorted { $0.timestamp < $1.timestamp }`.

### Completion Notes List
- Task 1: Moved `DuplicateKey.swift` from `Core/Data/` to `Core/Training/` (shared training infrastructure). No WALKTHROUGH annotations were present (already cleaned up).
- Task 2: Deleted `PitchDiscriminationRecordStoring.swift`. Removed protocol conformance from `MockTrainingDataStore` and `StubPitchDiscriminationDataStore`. `PitchDiscriminationStoreAdapter` already used `TrainingRecordPersisting` — no change needed.
- Task 3: Created `Timestamped` protocol in `Core/Data/Timestamped.swift`. Added conformance to all 4 record types via extensions in their typealias files. Added `fetchAllSorted<T: PersistentModel & Timestamped>` to `TrainingDataStore`, replacing the 4 per-type methods. Updated all callers across 6 discipline files, 1 duplicate key builder file, and 5 test files.
- Task 4: Both platforms pass — iOS: 1717 tests, macOS: 1710 tests.

### File List
- `Peach/Core/Training/DuplicateKey.swift` — moved from `Peach/Core/Data/DuplicateKey.swift`, updated to use `fetchAllSorted`
- `Peach/Core/Data/PitchDiscriminationRecordStoring.swift` — deleted
- `Peach/Core/Data/Timestamped.swift` — new protocol
- `Peach/Core/Data/TrainingDataStore.swift` — replaced 4 per-type fetches with `fetchAllSorted`
- `Peach/Core/Data/PitchDiscriminationRecord.swift` — added `Timestamped` conformance
- `Peach/Core/Data/PitchMatchingRecord.swift` — added `Timestamped` conformance
- `Peach/Core/Data/TimingOffsetDetectionRecord.swift` — added `Timestamped` conformance
- `Peach/Core/Data/ContinuousRhythmMatchingRecord.swift` — added `Timestamped` conformance
- `Peach/Training/PitchDiscrimination/UnisonPitchDiscriminationDiscipline.swift` — updated to use `fetchAllSorted`
- `Peach/Training/PitchDiscrimination/IntervalPitchDiscriminationDiscipline.swift` — updated to use `fetchAllSorted`
- `Peach/Training/PitchMatching/UnisonPitchMatchingDiscipline.swift` — updated to use `fetchAllSorted`
- `Peach/Training/PitchMatching/IntervalPitchMatchingDiscipline.swift` — updated to use `fetchAllSorted`
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionDiscipline.swift` — updated to use `fetchAllSorted`
- `Peach/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingDiscipline.swift` — updated to use `fetchAllSorted`
- `Peach/App/PreviewDefaults.swift` — simplified `StubPitchDiscriminationDataStore`
- `PeachTests/Training/PitchDiscrimination/MockTrainingDataStore.swift` — removed `PitchDiscriminationRecordStoring` conformance
- `PeachTests/Core/Training/DuplicateKeyTests.swift` — new tests for duplicate key types
- `PeachTests/Core/Data/TrainingDataStoreTests.swift` — updated to use `fetchAllSorted`
- `PeachTests/Core/Data/TrainingDataStoreEdgeCaseTests.swift` — updated to use `fetchAllSorted`
- `PeachTests/Core/Data/TrainingDataImporterTests.swift` — updated to use `fetchAllSorted`
- `PeachTests/Settings/TrainingDataImportActionTests.swift` — updated to use `fetchAllSorted`
- `PeachTests/Core/Data/TrainingDataTransferServiceTests.swift` — updated to use `fetchAllSorted`

## Change Log

- 2026-04-06: Story created from walkthrough observations
- 2026-04-06: Implementation complete — all 3 dependency violations resolved
