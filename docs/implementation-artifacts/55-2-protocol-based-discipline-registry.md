# Story 55.2: Protocol-Based Discipline Registry

Status: ready-for-dev

## Story

As a **developer maintaining Peach**,
I want training disciplines to be registered through a protocol-based registry instead of an exhaustive enum,
So that adding or removing a discipline is a single-point change (register or delete) with no modifications to shared infrastructure.

## Context

The `TrainingDiscipline` enum in `ProgressTimeline.swift` is the single largest coupling driver. Every `switch` on this enum — in `ProgressTimeline`, `TrainingDisciplineConfig`, `MetricPointMapper`, `StartScreen`, and their tests — must be updated when a discipline is added or removed. This caused ~17 files to change when RhythmMatching was removed. The fix is to replace the enum with a protocol-based dispatch, following the chain-of-responsibility pattern already validated in the CSV import parser architecture.

Beyond the enum, several "dispatcher" types exist solely to enumerate all discipline types and delegate to per-type logic: `MetricPointMapper`, `CSVRecordFormatter`, and parts of `TrainingDataExporter`/`TrainingDataImporter`. When each discipline declares its own record type, mapping, formatting, and deduplication logic, these central dispatchers become unnecessary.

## Acceptance Criteria

1. **`TrainingDiscipline` is a protocol, not an enum** -- Defines the contract for a training discipline: display metadata (name, icon, unit label), statistics keys, progress timeline configuration, record type, and data integration points.

2. **Each discipline declares its data integration** -- The protocol includes requirements for:
   - **Record type** -- The discipline's `PersistentModel` type (e.g., `PitchDiscriminationRecord.self`), so the store can fetch and delete without hardcoded type lists.
   - **Profile feeding** -- How to map stored records to `MetricPoint`s for `PerceptualProfile.Builder` (currently in `MetricPointMapper`).
   - **CSV formatting** -- How to format records to CSV rows (currently in `CSVRecordFormatter`).
   - **Duplicate detection** -- How to build deduplication keys for merge import (currently in `TrainingDataImporter`).

3. **Each discipline is a conforming type** -- Concrete structs (e.g., `UnisonPitchDiscriminationDiscipline`) conform to the protocol and are defined in their respective feature directories.

4. **A discipline registry exists** -- A central registry (e.g., `TrainingDisciplineRegistry`) allows disciplines to register themselves. The registry is the single place that knows which disciplines are active.

5. **`ProgressTimeline` uses the registry** -- No exhaustive switch on discipline cases. Timeline configuration is provided by each discipline's protocol conformance.

6. **`TrainingDisciplineConfig` is eliminated** -- Static properties per discipline are replaced by configuration provided through the protocol.

7. **`MetricPointMapper` is eliminated** -- Profile feeding is driven by registry iteration; each discipline feeds its own records. No central dispatcher needed.

8. **`CSVRecordFormatter` is eliminated** -- CSV formatting is provided by each discipline's protocol conformance. No central dispatcher needed.

9. **`TrainingDataExporter` is discipline-agnostic** -- Iterates registered disciplines, asks each to fetch and format its records. No per-type knowledge.

10. **`TrainingDataImporter` is discipline-agnostic** -- Iterates registered disciplines for both replace and merge modes. Each discipline provides its own duplicate detection logic.

11. **`TrainingDataStore` generic CRUD** -- Per-discipline `save` overloads, `fetchAll*`, and `deleteAll*` methods are replaced with generic methods:
    - `func save(_ record: some PersistentModel) throws`
    - `func fetchAll<T: PersistentModel>(_ type: T.Type) throws -> [T]`
    - `func deleteAll<T: PersistentModel>(_ type: T.Type) throws`
    - `deleteAll()` and `replaceAllRecords()` iterate registered discipline record types instead of hardcoding them.

12. **`StartScreen` uses the registry** -- Training buttons are generated from registered disciplines, not hardcoded per enum case.

13. **Adding a new discipline requires** -- (a) Creating the discipline conformance in the feature directory, (b) registering it. No modifications to `ProgressTimeline`, `TrainingDataStore`, `TrainingDataExporter`, `TrainingDataImporter`, `StartScreen`, or their tests.

14. **Removing a discipline requires** -- Deleting its files and removing its registration. No modifications to shared infrastructure.

15. **All existing tests pass** -- Full test suite passes with zero regressions.

## Tasks / Subtasks

- [ ] Task 1: Design the `TrainingDiscipline` protocol
  - [ ] Identify all capabilities currently spread across `TrainingDiscipline` enum switches, `MetricPointMapper`, `CSVRecordFormatter`, and `TrainingDataImporter`
  - [ ] Define protocol requirements that capture those capabilities
  - [ ] Determine what metadata each discipline must provide (name, icon, slug, statistics keys, config, record type, mapping, formatting, deduplication)

- [ ] Task 2: Create `TrainingDisciplineRegistry`
  - [ ] Implement a registry that holds registered discipline conformances
  - [ ] Define registration mechanism (static registration or init-time)

- [ ] Task 3: Create discipline conformances in feature directories
  - [ ] One conformance per discipline in its feature directory
  - [ ] Migrate display metadata, statistics keys, and config from current enum/switch sites
  - [ ] Migrate record-to-metric-point mapping from `MetricPointMapper`
  - [ ] Migrate record-to-CSV formatting from `CSVRecordFormatter`
  - [ ] Migrate duplicate key logic from `TrainingDataImporter`

- [ ] Task 4: Make `TrainingDataStore` generic
  - [ ] Replace per-discipline `save` overloads with `save(_ record: some PersistentModel)`
  - [ ] Replace per-discipline `fetchAll*` with `fetchAll<T: PersistentModel>(_ type: T.Type)` (no sort — callers handle ordering)
  - [ ] Replace per-discipline `deleteAll*` with `deleteAll<T: PersistentModel>(_ type: T.Type)`
  - [ ] Rewrite `deleteAll()` to iterate registered discipline record types
  - [ ] Rewrite `replaceAllRecords()` to accept type-erased record groups
  - [ ] Update tests

- [ ] Task 5: Migrate `ProgressTimeline` to registry-based dispatch
  - [ ] Replace enum switches with protocol-based lookups
  - [ ] Update tests

- [ ] Task 6: Eliminate `MetricPointMapper`
  - [ ] Move per-discipline mapping logic into discipline conformances
  - [ ] Replace callers with registry iteration
  - [ ] Delete `MetricPointMapper.swift`
  - [ ] Update tests

- [ ] Task 7: Eliminate `CSVRecordFormatter`
  - [ ] Move per-discipline formatting logic into discipline conformances
  - [ ] Replace callers with registry iteration
  - [ ] Delete `CSVRecordFormatter.swift`
  - [ ] Update tests

- [ ] Task 8: Make `TrainingDataExporter` discipline-agnostic
  - [ ] Iterate registered disciplines to fetch and format records
  - [ ] Update tests

- [ ] Task 9: Make `TrainingDataImporter` discipline-agnostic
  - [ ] Iterate registered disciplines for replace and merge modes
  - [ ] Move duplicate key types into discipline conformances
  - [ ] Update tests

- [ ] Task 10: Migrate `StartScreen` to registry-based rendering
  - [ ] Generate training buttons from registered disciplines
  - [ ] Update tests

- [ ] Task 11: Remove `TrainingDisciplineConfig`
  - [ ] Move per-discipline config into discipline conformances
  - [ ] Update tests

- [ ] Task 12: Remove the `TrainingDiscipline` enum
  - [ ] Delete enum definition
  - [ ] Remove all remaining switch sites
  - [ ] Update tests

- [ ] Task 13: Run full test suite
  - [ ] All tests pass, zero regressions

## Dev Notes

### Critical Design Decisions

- **Protocol, not plugin architecture** -- This is compile-time registration, not runtime discovery. Disciplines are known at compile time; the goal is reducing coupling, not enabling dynamic loading.
- **Dependency on Story 55.1** -- This story assumes observer adapters are already extracted. The discipline protocol may include factory methods for creating adapters, but the port protocols (`ProfileUpdating`, `TrainingRecordPersisting`) must exist first.
- **Navigation integration** -- `NavigationDestination` enum cases for disciplines may also become registry-driven, or may remain as-is if the navigation coupling is tolerable (3 files). This is a design decision to be made during implementation.
- **Validated pattern** -- The chain-of-responsibility pattern for CSV import parsers was explicitly approved as "the kind of architecture we should always be using." This story applies the same principle to the discipline registry.
- **Store ordering contract** -- `fetchAll` returns records in arbitrary order. `PerceptualProfile.Builder.finalize()` sorts internally; `TrainingDataExporter` sorts the merged output by timestamp. No caller depends on store-level ordering.
- **Dispatchers disappear** -- `MetricPointMapper` and `CSVRecordFormatter` exist only because they are the central place that enumerates discipline types. When each discipline owns its mapping and formatting, the dispatchers have no remaining purpose and are deleted.

### Existing Code to Reference

- **`ProgressTimeline.swift`** -- `TrainingDiscipline` enum definition and all switch sites for `config`, `statisticsKeys`, `slug`. [Source: Peach/Core/Profile/ProgressTimeline.swift]
- **`TrainingDisciplineConfig.swift`** -- Static properties per discipline (display name, unit label, baseline). [Source: Peach/Core/Profile/TrainingDisciplineConfig.swift]
- **`MetricPointMapper.swift`** -- `feedAllRecords` and per-discipline `feed*` methods — mapping logic to move into discipline conformances. [Source: Peach/App/MetricPointMapper.swift]
- **`CSVRecordFormatter.swift`** -- Per-discipline `format` methods — formatting logic to move into discipline conformances. [Source: Peach/Core/Data/CSVRecordFormatter.swift]
- **`TrainingDataExporter.swift`** -- Fetches all record types and merges formatted rows. [Source: Peach/Core/Data/TrainingDataExporter.swift]
- **`TrainingDataImporter.swift`** -- Per-discipline duplicate keys and merge logic. [Source: Peach/Core/Data/TrainingDataImporter.swift]
- **`TrainingDataStore.swift`** -- Per-discipline CRUD methods, `deleteAll`, `replaceAllRecords`. [Source: Peach/Core/Data/TrainingDataStore.swift]
- **`StartScreen.swift`** -- Hardcoded training buttons with per-discipline navigation. [Source: Peach/Start/StartScreen.swift]
- **`CSVImportParser.swift`** -- Chain-of-responsibility pattern to reference as the model for this registry design. [Source: Peach/Core/Data/CSVImportParser.swift]
