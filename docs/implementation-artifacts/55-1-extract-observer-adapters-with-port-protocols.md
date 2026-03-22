# Story 55.1: Extract Observer Adapters with Port Protocols

Status: review

## Story

As a **developer maintaining Peach**,
I want `PerceptualProfile` and `TrainingDataStore` to have zero knowledge of specific training disciplines,
So that adding or removing a discipline never requires modifying core infrastructure files or their tests.

## Context

Removing the RhythmMatching discipline (commit 96b0cb9) required modifying 39 non-deleted files. A significant portion of that blast radius comes from `PerceptualProfile` and `TrainingDataStore` each conforming to every per-discipline observer protocol. These conformances are pure mapping logic — they convert a discipline-specific trial result into a generic operation (`update` for profile, `save` for store). That mapping belongs with the discipline, not with core.

## Acceptance Criteria

1. **Port protocol `ProfileUpdating` exists** -- `Core/Training/ProfileUpdating.swift` defines a protocol with `func update(_ key: StatisticsKey, timestamp: Date, value: Double)`.

2. **Port protocol `TrainingRecordPersisting` exists** -- `Core/Training/TrainingRecordPersisting.swift` defines a protocol with `func save(_ record: some PersistentModel) throws`.

3. **`PerceptualProfile` conforms to `ProfileUpdating`** -- The existing private `update` method becomes the protocol requirement. No other changes to `PerceptualProfile`.

4. **`TrainingDataStore` conforms to `TrainingRecordPersisting`** -- The four identical `save` overloads are replaced with a single generic `save(_ record: some PersistentModel) throws` method that is the protocol requirement.

5. **`PerceptualProfile` has zero observer conformances** -- All `extension PerceptualProfile: *Observer` blocks are removed from `PerceptualProfile.swift`.

6. **`TrainingDataStore` has zero observer conformances** -- All `extension TrainingDataStore: *Observer` blocks are removed from `TrainingDataStore.swift`.

7. **Profile adapters exist in feature directories** -- Each discipline directory contains a `*ProfileAdapter.swift` that conforms to the discipline's observer protocol and delegates to `ProfileUpdating`. The mapping logic is identical to the removed `PerceptualProfile` extensions:
   - `Peach/PitchDiscrimination/PitchDiscriminationProfileAdapter.swift`
   - `Peach/PitchMatching/PitchMatchingProfileAdapter.swift`
   - `Peach/RhythmOffsetDetection/RhythmOffsetDetectionProfileAdapter.swift`
   - `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingProfileAdapter.swift`

8. **Store adapters exist in feature directories** -- Each discipline directory contains a `*StoreAdapter.swift` that conforms to the discipline's observer protocol and delegates to `TrainingRecordPersisting`. The mapping logic is identical to the removed `TrainingDataStore` extensions:
   - `Peach/PitchDiscrimination/PitchDiscriminationStoreAdapter.swift`
   - `Peach/PitchMatching/PitchMatchingStoreAdapter.swift`
   - `Peach/RhythmOffsetDetection/RhythmOffsetDetectionStoreAdapter.swift`
   - `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingStoreAdapter.swift`

9. **`PeachApp` wires adapters** -- Session factory methods create adapters (e.g., `PitchDiscriminationProfileAdapter(profile: profile)`) and pass them in the observers array instead of passing `profile` and `dataStore` directly.

10. **Per-discipline types move out of `Core/Training/`** -- Observer protocols, completed trial types, and settings types move to their respective feature directories:
    - `PitchDiscriminationObserver`, `PitchDiscriminationSettings`, `PitchDiscriminationTrial` → `Peach/PitchDiscrimination/`
    - `PitchMatchingObserver`, `PitchMatchingSettings`, `CompletedPitchMatchingTrial` → `Peach/PitchMatching/`
    - `RhythmOffsetDetectionObserver`, `RhythmOffsetDetectionSettings`, `CompletedRhythmOffsetDetectionTrial` → `Peach/RhythmOffsetDetection/`
    - `ContinuousRhythmMatchingObserver`, `ContinuousRhythmMatchingSettings`, `CompletedContinuousRhythmMatchingTrial` → `Peach/ContinuousRhythmMatching/`

11. **`Core/Training/` contains only domain-generic types** -- After the move, `Core/Training/` contains `Resettable.swift`, `ProfileUpdating.swift`, `TrainingRecordPersisting.swift`, and no discipline-specific files.

12. **All existing tests pass** -- Full test suite passes with zero regressions. Adapter tests may be added in the feature test directories.

## Tasks / Subtasks

- [x] Task 1: Create port protocols (AC: #1, #2)
  - [x] Create `Peach/Core/Training/ProfileUpdating.swift`
  - [x] Create `Peach/Core/Data/TrainingRecordPersisting.swift` (moved to Core/Data/ to comply with SwiftData import rule)

- [x] Task 2: Conform core types to port protocols (AC: #3, #4)
  - [x] Make `PerceptualProfile.update` internal and conform to `ProfileUpdating`
  - [x] Replace four `TrainingDataStore.save` overloads with one generic method conforming to `TrainingRecordPersisting`

- [x] Task 3: Create profile adapters (AC: #7)
  - [x] Create adapters in each feature directory with mapping logic from current `PerceptualProfile` extensions

- [x] Task 4: Create store adapters (AC: #8)
  - [x] Create adapters in each feature directory with mapping logic from current `TrainingDataStore` extensions

- [x] Task 5: Update `PeachApp` wiring (AC: #9)
  - [x] Replace direct `profile`/`dataStore` observer usage with adapter instances

- [x] Task 6: Remove observer conformances from core types (AC: #5, #6)
  - [x] Remove all `extension PerceptualProfile: *Observer` blocks
  - [x] Remove all `extension TrainingDataStore: *Observer` blocks

- [x] Task 7: Move discipline-specific types out of `Core/Training/` (AC: #10, #11)
  - [x] Move observer protocols, completed trial types, and settings types to feature directories
  - [x] No import path changes needed (single-module app)

- [x] Task 8: Run full test suite (AC: #12)
  - [x] All 1496 tests pass, zero regressions

## Dev Agent Record

### Implementation Plan
Ports-and-adapters refactoring: created ProfileUpdating and TrainingRecordPersisting port protocols, created 8 adapter structs (4 profile + 4 store) in feature directories, rewired PeachApp composition root to use adapters, removed all observer conformances from PerceptualProfile and TrainingDataStore, moved 12 discipline-specific files from Core/Training/ to feature directories.

### Debug Log
- TrainingRecordPersisting initially placed in Core/Training/ but `import SwiftData` violated the dependency rule (only Core/Data/ may import SwiftData). Moved to Core/Data/.
- PeachApp `createPitchMatchingSession` was using implicit return; adding adapter variables required explicit `return`.
- EnvironmentKeys.swift default `pitchDiscriminationSession` was passing `profile` in observer array; fixed to use only `dataStore`.
- 11 test files updated to route observer calls through adapters instead of calling observer methods directly on PerceptualProfile/TrainingDataStore.

### Completion Notes
All 12 acceptance criteria satisfied:
- AC #1-2: Port protocols exist (ProfileUpdating in Core/Training/, TrainingRecordPersisting in Core/Data/)
- AC #3-4: Core types conform to port protocols
- AC #5-6: Zero observer conformances on PerceptualProfile and TrainingDataStore
- AC #7-8: 8 adapters in 4 feature directories
- AC #9: PeachApp wires adapters in all 4 session factory methods
- AC #10: 12 discipline-specific files moved to feature directories
- AC #11: Core/Training/ contains only Resettable.swift and ProfileUpdating.swift (domain-generic)
- AC #12: All 1496 tests pass

## File List

### New Files
- Peach/Core/Training/ProfileUpdating.swift
- Peach/Core/Data/TrainingRecordPersisting.swift
- Peach/PitchDiscrimination/PitchDiscriminationProfileAdapter.swift
- Peach/PitchDiscrimination/PitchDiscriminationStoreAdapter.swift
- Peach/PitchMatching/PitchMatchingProfileAdapter.swift
- Peach/PitchMatching/PitchMatchingStoreAdapter.swift
- Peach/RhythmOffsetDetection/RhythmOffsetDetectionProfileAdapter.swift
- Peach/RhythmOffsetDetection/RhythmOffsetDetectionStoreAdapter.swift
- Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingProfileAdapter.swift
- Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingStoreAdapter.swift

### Modified Files
- Peach/Core/Profile/PerceptualProfile.swift (removed observer conformances, made update internal, added ProfileUpdating conformance)
- Peach/Core/Data/TrainingDataStore.swift (removed observer conformances, replaced 4 save overloads with 1 generic, added TrainingRecordPersisting conformance)
- Peach/App/PeachApp.swift (wired adapters in all 4 session factory methods)
- Peach/App/EnvironmentKeys.swift (removed profile from preview observer array)
- PeachTests/Core/Profile/PerceptualProfileTests.swift (use adapters)
- PeachTests/Core/Profile/PitchMatchingProfileTests.swift (use adapters)
- PeachTests/Core/Profile/ProgressTimelineTests.swift (use adapters)
- PeachTests/Core/Data/TrainingDataStoreTests.swift (use adapters)
- PeachTests/PitchDiscrimination/PitchDiscriminationTestHelpers.swift (use adapter)
- PeachTests/PitchDiscrimination/PitchDiscriminationSessionIntegrationTests.swift (use adapter)
- PeachTests/PitchDiscrimination/PitchDiscriminationSessionResetTests.swift (use adapters)
- PeachTests/PitchDiscrimination/PitchDiscriminationSessionTests.swift (use adapter)
- PeachTests/PitchDiscrimination/PitchDiscriminationSessionUserDefaultsTests.swift (use adapter)
- PeachTests/Core/Algorithm/KazezNoteStrategyTests.swift (use adapters)
- PeachTests/Core/Algorithm/AdaptiveRhythmOffsetDetectionStrategyTests.swift (use adapters)
- PeachTests/Settings/SettingsTests.swift (use adapters)
- PeachTests/Profile/ProfileScreenTests.swift (use adapter)
- docs/implementation-artifacts/sprint-status.yaml (status updates)
- docs/planning-artifacts/epics.md (added Epic 55)

### Moved Files (Core/Training/ → feature directories)
- PitchDiscriminationObserver.swift → Peach/PitchDiscrimination/
- PitchDiscriminationSettings.swift → Peach/PitchDiscrimination/
- PitchDiscriminationTrial.swift → Peach/PitchDiscrimination/
- PitchMatchingObserver.swift → Peach/PitchMatching/
- PitchMatchingSettings.swift → Peach/PitchMatching/
- CompletedPitchMatchingTrial.swift → Peach/PitchMatching/
- RhythmOffsetDetectionObserver.swift → Peach/RhythmOffsetDetection/
- RhythmOffsetDetectionSettings.swift → Peach/RhythmOffsetDetection/
- CompletedRhythmOffsetDetectionTrial.swift → Peach/RhythmOffsetDetection/
- ContinuousRhythmMatchingObserver.swift → Peach/ContinuousRhythmMatching/
- ContinuousRhythmMatchingSettings.swift → Peach/ContinuousRhythmMatching/
- CompletedContinuousRhythmMatchingTrial.swift → Peach/ContinuousRhythmMatching/

## Change Log

- 2026-03-22: Implemented story 55.1 — extracted observer adapters with port protocols

## Dev Notes

### Critical Design Decisions

- **Ports-and-adapters architecture** -- `Core/Training/` defines the ports (`ProfileUpdating`, `TrainingRecordPersisting`). Feature directories contain the adapters. Core never imports features; features depend on core protocols. This is the same dependency inversion already established with the CSV import parser chain-of-responsibility pattern.
- **Adapters are thin** -- Each adapter is a struct holding a reference to the port protocol, with a single method that maps trial → generic operation. No business logic beyond the mapping.
- **`computePositionMeanOffsets` helper** -- The `TrainingDataStore` extension for `ContinuousRhythmMatchingObserver` uses a private helper `computePositionMeanOffsets(from:)`. This helper should move with the store adapter to the `ContinuousRhythmMatching/` directory.
- **`TrainingRecordPersisting.save` is fully generic** -- All four current `save` overloads are identical (`modelContext.insert` in a transaction). The port protocol uses `func save(_ record: some PersistentModel) throws` — no per-type overloads.

### Contracts

- **`TrainingRecordPersisting.save`** -- Persists a single record. No ordering guarantees.
- **`TrainingDataStore.fetchAll`** -- Returns records in arbitrary order. The store is a bag, not a sequence. Callers must not assume any ordering.
- **`ProfileUpdating.update`** -- Timestamps must be monotonically ascending. This is naturally satisfied during live training (events arrive in real time). For bulk loading (init/import), use `PerceptualProfile.Builder` instead, which accepts unordered points and sorts internally via `finalize()`.

### Existing Code to Reference

- **`PerceptualProfile.swift:67`** -- `private func update(_ key: StatisticsKey, timestamp: Date, value: Double)` — becomes the `ProfileUpdating` protocol requirement. [Source: Peach/Core/Profile/PerceptualProfile.swift]
- **`TrainingDataStore.swift:20,114,147,183`** -- Four identical `save` overloads, each doing `modelContext.insert(record)` in a transaction. [Source: Peach/Core/Data/TrainingDataStore.swift]
- **`PerceptualProfile.swift:83-135`** -- Four observer conformance extensions containing mapping logic that moves to adapters. [Source: Peach/Core/Profile/PerceptualProfile.swift]
- **`TrainingDataStore.swift:218-310`** -- Four observer conformance extensions containing mapping logic that moves to adapters. [Source: Peach/Core/Data/TrainingDataStore.swift]
