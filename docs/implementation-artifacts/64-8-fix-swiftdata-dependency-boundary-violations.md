# Story 64.8: Fix SwiftData Dependency Boundary Violations

Status: ready-for-dev

## Story

As a **developer maintaining Peach**,
I want `import SwiftData` to appear only in `Core/Data/` and `App/`,
so that the architectural rule "SwiftData is encapsulated" is enforced and `bin/check-dependencies.sh` passes clean.

## Acceptance Criteria

1. **Given** `bin/check-dependencies.sh` **When** run **Then** zero SwiftData violations are reported (currently 9).

2. **Given** `TrainingDiscipline` protocol in `Core/Training/` **When** reviewed **Then** it does not import SwiftData — the `recordType` property uses a type-erased wrapper or the protocol is split so the SwiftData-dependent part lives in `Core/Data/`.

3. **Given** `TrainingRecordPersisting` protocol in `Core/Ports/` **When** reviewed **Then** it does not import SwiftData — the generic constraint uses a protocol or type erasure instead of `some PersistentModel`.

4. **Given** the 6 discipline implementations in feature directories **When** reviewed **Then** none import SwiftData — record type references and CSV parsing that need `PersistentModel` are restructured to avoid the import.

5. **Given** the full test suite **When** run **Then** all existing tests pass with zero regressions.

## Tasks / Subtasks

- [ ] Task 1: Analyze the SwiftData dependency chain (AC: #1)
  - [ ] 1.1 Run `bin/check-dependencies.sh` and list all 9 violations
  - [ ] 1.2 Trace why each file needs SwiftData: `TrainingDiscipline.swift` uses `any PersistentModel.Type`, `TrainingRecordPersisting.swift` uses `some PersistentModel`, disciplines use record types that are `@Model`

- [ ] Task 2: Remove SwiftData from `Core/Ports/TrainingRecordPersisting.swift` (AC: #3)
  - [ ] 2.1 Replace `some PersistentModel` constraint with a protocol-based approach — define a marker protocol in Core (e.g., `TrainingRecord`) that the `@Model` types conform to, and use that as the generic constraint

- [ ] Task 3: Remove SwiftData from `Core/Training/TrainingDiscipline.swift` and `TrainingDisciplineRegistry.swift` (AC: #2)
  - [ ] 3.1 The `recordType: any PersistentModel.Type` property is used only by `TrainingDataStore` for bulk operations. Move this association to the data layer — e.g., a `TrainingDisciplineDataConfig` in `Core/Data/` that maps discipline IDs to their record types
  - [ ] 3.2 Remove the `import SwiftData` from both files

- [ ] Task 4: Remove SwiftData from discipline implementations (AC: #4)
  - [ ] 4.1 The disciplines import SwiftData because they reference `@Model` types in their `mergeImportRecords()`, `fetchExportRecords()`, and `feedRecords()` methods
  - [ ] 4.2 These methods interact with `TrainingDataStore` — restructure so the discipline provides parsing/formatting logic and the data layer handles the SwiftData types

- [ ] Task 5: Run `bin/check-dependencies.sh` and verify zero violations (AC: #1)

- [ ] Task 6: Run full test suite (AC: #5)

## Dev Notes

### Current Violations (9 files)

1. `Core/Training/TrainingDiscipline.swift` — `recordType: any PersistentModel.Type`
2. `Core/Training/TrainingDisciplineRegistry.swift` — accesses `recordType` from disciplines
3. `Core/Ports/TrainingRecordPersisting.swift` — `some PersistentModel` generic constraint
4. `PitchDiscrimination/UnisonPitchDiscriminationDiscipline.swift`
5. `PitchDiscrimination/IntervalPitchDiscriminationDiscipline.swift`
6. `PitchMatching/UnisonPitchMatchingDiscipline.swift`
7. `PitchMatching/IntervalPitchMatchingDiscipline.swift`
8. `RhythmOffsetDetection/RhythmOffsetDetectionDiscipline.swift`
9. `ContinuousRhythmMatching/ContinuousRhythmMatchingDiscipline.swift`

### Design Approach

The `TrainingDiscipline` protocol tries to do too much — it owns both domain logic (display config, statistics keys) AND data layer concerns (record types, CSV parsing). Splitting these concerns lets the domain protocol stay in `Core/Training/` without SwiftData, while data-layer concerns move to `Core/Data/`.

### Risk

This is a significant refactoring of a core protocol. Each step should be followed by a full test run. Do NOT batch all changes before testing.

### Source File Locations

| File | Path |
|------|------|
| TrainingDiscipline | `Peach/Core/Training/TrainingDiscipline.swift` |
| TrainingDisciplineRegistry | `Peach/Core/Training/TrainingDisciplineRegistry.swift` |
| TrainingRecordPersisting | `Peach/Core/Ports/TrainingRecordPersisting.swift` |
| All 6 disciplines | `Peach/{Feature}/{Discipline}.swift` |
| check-dependencies.sh | `bin/check-dependencies.sh` |

### References

- [Source: bin/check-dependencies.sh] — Dependency enforcement script
- [Source: Peach/Core/Training/TrainingDiscipline.swift] — Protocol with SwiftData dependency
- [Source: docs/project-context.md] — "SwiftData is encapsulated — import SwiftData only in Core/Data/ and App/"
