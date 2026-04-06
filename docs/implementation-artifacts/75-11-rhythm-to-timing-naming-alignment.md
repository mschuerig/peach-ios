# Story 75.11: Rhythm→Timing Naming Alignment

Status: done

## Story

As a **developer reading the codebase**,
I want type names to match the user-facing language,
so that "Compare Timing" in the UI and `RhythmOffset` in code don't create a mental translation layer.

## Background

The walkthrough (Layer 1) noted that domain types use `RhythmOffset`, `RhythmDirection`, `RhythmOffsetDetection*`, but the UI says "Compare Timing" and code comments reference "Timing State" and "Timing Feedback." The domain language shifted to "Timing" during implementation but the type-level rename never happened.

`ContinuousRhythmMatching*` types are NOT renamed — "Fill the Gap" is the user-facing name and "continuous rhythm matching" is the correct technical term for that mode. Only the `RhythmOffset*` family is affected.

**Walkthrough source:** Layer 1 observation #2.

## Acceptance Criteria

1. **Given** `RhythmOffset` **When** inspected **Then** it is renamed to `TimingOffset`.
2. **Given** `RhythmDirection` **When** inspected **Then** it is renamed to `TimingDirection`.
3. **Given** all `RhythmOffsetDetection*` types, files, and directories **When** inspected **Then** they use `TimingOffsetDetection*` (or equivalent agreed name that aligns with "Compare Timing").
4. **Given** CSV export/import **When** tested with existing data **Then** backward compatibility is preserved — CSV column names map correctly (the CSV format uses `trainingType` identifiers that may need a migration or alias).
5. **Given** localization keys **When** inspected **Then** they are updated where they reference internal type identifiers. User-facing strings that already say "Timing" remain unchanged.
6. **Given** `TrainingDisciplineID` cases **When** inspected **Then** they use the new naming.
7. **Given** both platforms **When** built and tested **Then** all tests pass with zero regressions.

## Tasks / Subtasks

- [x] Task 1: Define the naming mapping (AC: #1, #2, #3)
  - [x] `RhythmOffset` → `TimingOffset`
  - [x] `RhythmDirection` → `TimingDirection`
  - [x] `RhythmOffsetDetection*` → `TimingOffsetDetection*`
  - [x] Document the mapping before starting renames

- [x] Task 2: Rename domain types in Core/Music/ (AC: #1, #2)
  - [x] Rename `RhythmOffset` → `TimingOffset` (type, file, all references)
  - [x] Rename `RhythmDirection` → `TimingDirection` (type, file, all references)
  - [x] Update `WelfordMeasurement` conformance on the renamed type

- [x] Task 3: Rename RhythmOffsetDetection feature types (AC: #3)
  - [x] Rename session, screen, observer, store adapter, profile adapter, discipline, trial, settings, feedback view, dot view, stats view
  - [x] Rename directory and file names
  - [x] Update `NavigationDestination` case
  - [x] Update `TrainingDisciplineID` case

- [x] Task 4: Preserve CSV backward compatibility (AC: #4)
  - [x] `csvTrainingType = "rhythmOffsetDetection"` preserved as stable wire format (shared with peach-web)
  - [x] All CSV string literals kept unchanged — no alias mechanism needed

- [x] Task 5: Update localization (AC: #5)
  - [x] Search for localization keys referencing old names
  - [x] Auto-generated comments updated from `RhythmOffsetDetectionScreen` → `TimingOffsetDetectionScreen`
  - [x] User-facing strings unaffected (already say "Timing")

- [x] Task 6: Update tests (AC: #7)
  - [x] Rename test files and test classes
  - [x] Update all test references

- [x] Task 7: Build and test both platforms (AC: #7)
  - [x] iOS: 1711 tests passed
  - [x] macOS: 1704 tests passed

## Dev Notes

### Scope — What Gets Renamed

**Renamed:**
- `RhythmOffset` → `TimingOffset`
- `RhythmDirection` → `TimingDirection`
- `RhythmOffsetDetection*` (session, screen, observer, store adapter, profile adapter, discipline, trial, settings, feedback view, dot view, stats view, CSV parser)
- `RhythmOffsetDetectionRecord` (SwiftData model — but see note below)

**NOT renamed:**
- `ContinuousRhythmMatching*` — different mode, "rhythm matching" is correct
- `RhythmPlayer`, `RhythmPlaybackHandle`, `RhythmPattern` — these are audio layer types about playing rhythmic patterns, not about the "Compare Timing" training mode
- `TempoRange`, `TempoBPM` — tempo types are shared between both rhythm modes

### SwiftData Record Rename Caution

`RhythmOffsetDetectionRecord` is a `@Model` class in `PeachSchema`. Renaming it changes the SwiftData model name. This may require a schema migration (even though it's just a rename). Test carefully:
- Does SwiftData match models by class name or by the schema declaration?
- If migration is needed, add a `SchemaV2` with a migration step

### CSV Backward Compatibility

The CSV `trainingType` column likely stores `"rhythmOffsetDetection"`. After rename, new exports would write `"timingOffsetDetection"`. The import parser must accept both. Add the old name as an alias in the CSV parser lookup.

### References

- [Source: docs/walkthrough/1-domain-types.md — observation #2]
- [Source: Peach/Core/Music/RhythmOffset.swift — WALKTHROUGH annotation]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6

### Completion Notes List
- SwiftData model `RhythmOffsetDetectionRecord` kept as-is inside `SchemaV1` to avoid schema migration; typealias `TimingOffsetDetectionRecord = SchemaV1.RhythmOffsetDetectionRecord` bridges the rename
- CSV wire format string `"rhythmOffsetDetection"` preserved unchanged (stable identifier shared with peach-web)
- `TrainingDisciplineID.timingOffsetDetection` raw value changed to `"timing-offset-detection"`
- ~60 source files and ~30 test files updated across the rename

### File List
**Core domain types renamed:**
- `Peach/Core/Music/TimingOffset.swift` (was RhythmOffset.swift)
- `Peach/Core/Music/TimingDirection.swift` (was RhythmDirection.swift)

**Core infrastructure updated:**
- `Peach/Core/Data/TimingOffsetDetectionRecord.swift` (typealias, was RhythmOffsetDetectionRecord.swift)
- `Peach/Core/Data/TrainingDataStore.swift`
- `Peach/Core/Data/DuplicateKey.swift`
- `Peach/Core/Profile/StatisticsKey.swift`
- `Peach/Core/Profile/SpectrogramData.swift`
- `Peach/Core/Profile/WelfordAccumulator.swift`
- `Peach/Core/Training/TrainingDisciplineID.swift`
- `Peach/Core/Training/TrainingDisciplineRegistry.swift`
- `Peach/Core/Algorithm/NextTimingOffsetDetectionStrategy.swift`
- `Peach/Core/Algorithm/AdaptiveTimingOffsetDetectionStrategy.swift`

**Feature directory renamed:** `Peach/Training/TimingOffsetDetection/` (was RhythmOffsetDetection/)

**App layer updated:**
- `Peach/App/NavigationDestination.swift`
- `Peach/App/EnvironmentKeys.swift`
- `Peach/App/PeachApp.swift`
- `Peach/App/TrainingLifecycleCoordinator.swift`
- `Peach/App/PreviewDefaults.swift`
- `Peach/App/PeachCommands.swift`
- `Peach/App/Platform/HapticFeedbackManager.swift`
- `Peach/App/Platform/NoOpHapticFeedbackManager.swift`
- `Peach/Start/StartScreen.swift`
- `Peach/Profile/ProfileScreen.swift`
- `Peach/Training/ContinuousRhythmMatching/` (TimingOffset/TimingDirection refs)

## Change Log

- 2026-04-06: Story created from walkthrough observations
- 2026-04-06: Implementation complete — all renames applied, both platforms green
