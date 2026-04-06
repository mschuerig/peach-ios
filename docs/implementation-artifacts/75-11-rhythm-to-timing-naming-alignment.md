# Story 75.11: Rhythm→Timing Naming Alignment

Status: ready-for-dev

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

- [ ] Task 1: Define the naming mapping (AC: #1, #2, #3)
  - [ ] `RhythmOffset` → `TimingOffset`
  - [ ] `RhythmDirection` → `TimingDirection`
  - [ ] `RhythmOffsetDetection*` → decide: `TimingOffsetDetection*` or `TimingComparison*` or just `TimingDetection*`
  - [ ] Document the mapping before starting renames

- [ ] Task 2: Rename domain types in Core/Music/ (AC: #1, #2)
  - [ ] Rename `RhythmOffset` → `TimingOffset` (type, file, all references)
  - [ ] Rename `RhythmDirection` → `TimingDirection` (type, file, all references)
  - [ ] Update `WelfordMeasurement` conformance on the renamed type

- [ ] Task 3: Rename RhythmOffsetDetection feature types (AC: #3)
  - [ ] Rename session, screen, observer, store adapter, profile adapter, discipline, trial, settings, feedback view, dot view, stats view
  - [ ] Rename directory and file names
  - [ ] Update `NavigationDestination` case
  - [ ] Update `TrainingDisciplineID` case

- [ ] Task 4: Preserve CSV backward compatibility (AC: #4)
  - [ ] Check `trainingType` column values in CSV export — if they use the old name, add a migration or alias in the CSV import parser
  - [ ] Test import of a CSV exported with the old naming

- [ ] Task 5: Update localization (AC: #5)
  - [ ] Search for localization keys referencing old names
  - [ ] Update keys where they reference type identifiers
  - [ ] Verify user-facing strings are unaffected (they already say "Timing")

- [ ] Task 6: Update tests (AC: #7)
  - [ ] Rename test files and test classes
  - [ ] Update all test references

- [ ] Task 7: Build and test both platforms (AC: #7)
  - [ ] `bin/test.sh && bin/test.sh -p mac`

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
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-04-06: Story created from walkthrough observations
