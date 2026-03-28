# Story 64.10: Add Tests for Untested Critical Paths

Status: review

## Story

As a **developer maintaining Peach**,
I want critical data-layer and adapter code to have dedicated unit tests,
so that regressions in CSV parsing, duplicate detection, observer routing, and settings bridging are caught before they reach users.

## Acceptance Criteria

1. **Given** each of the 6 discipline implementations **When** tested **Then** dedicated tests exist for: `csvKeyValuePairs()` output, `parseCSVRow()` round-trip, `mergeImportRecords()` with and without duplicates, `fetchExportRecords()` filtering (e.g., unison vs. interval).

2. **Given** each of the 8 observer adapters **When** tested **Then** dedicated tests verify: observer method routes domain results to the correct `PerceptualProfile` statistics key, and store adapter creates the correct `@Model` record.

3. **Given** `AppUserSettings` **When** tested **Then** tests verify: default values match `SettingsKeys` defaults, validation clamps out-of-range values, `noteRange` respects minimum span.

4. **Given** `TrainingDisciplineRegistry` **When** tested **Then** tests verify: all discipline IDs are registered, CSV column names don't overlap, parser dispatch by training type string is correct.

5. **Given** the full test suite **When** run **Then** all tests pass.

## Tasks / Subtasks

- [x] Task 1: Write discipline implementation tests (AC: #1)
  - [x] 1.1 Create test files for each discipline or a shared `TrainingDisciplineTests.swift` that iterates all 6
  - [x] 1.2 Test `csvKeyValuePairs()` produces expected column values for a known record
  - [x] 1.3 Test `parseCSVRow()` round-trip: export a record to CSV fields, parse back, verify equality
  - [x] 1.4 Test `mergeImportRecords()` skips duplicates and imports non-duplicates
  - [x] 1.5 Test `fetchExportRecords()` filtering: unison discipline only returns interval=0 records, interval discipline only returns interval>0 records

- [x] Task 2: Write observer adapter tests (AC: #2)
  - [x] 2.1 For each profile adapter (4 total): create test verifying that calling the observer method updates `PerceptualProfile` with the correct `StatisticsKey`
  - [x] 2.2 For each store adapter (4 total): create test verifying that calling the observer method creates and saves the correct record type in a mock or in-memory store

- [x] Task 3: Write `AppUserSettings` tests (AC: #3)
  - [x] 3.1 Create `AppUserSettingsTests.swift` in `PeachTests/Settings/`
  - [x] 3.2 Test default values for all properties (noteRange, noteDuration, referencePitch, soundSource, varyLoudness, intervals, tuningSystem, noteGap, tempoBPM, enabledGapPositions)
  - [x] 3.3 Test that out-of-range UserDefaults values are clamped or rejected

- [x] Task 4: Write `TrainingDisciplineRegistry` tests (AC: #4)
  - [x] 4.1 Create `TrainingDisciplineRegistryTests.swift` in `PeachTests/Core/Training/`
  - [x] 4.2 Test: all `TrainingDisciplineID.allCases` are registered
  - [x] 4.3 Test: no CSV column name overlaps between disciplines (excluding common columns)
  - [x] 4.4 Test: each discipline's CSV training type string resolves to the correct parser

- [x] Task 5: Run full test suite (AC: #5)

## Dev Notes

### Coverage Gaps Identified

The adversarial review found ~29 production files without dedicated tests. This story addresses the highest-risk subset:

| Component | Risk | Why |
|-----------|------|-----|
| Discipline implementations (6) | High | CSV parsing, duplicate detection, record filtering |
| Observer adapters (8) | Medium | Route domain results to profile/store — silent misrouting is invisible |
| AppUserSettings | Medium | Bridges UserDefaults to domain types — validation gaps affect all training |
| TrainingDisciplineRegistry | Medium | Column overlap or parser dispatch errors break import/export |

### What This Story Does NOT Cover

- `ContentView`, `PeachApp` (composition root — tested implicitly by integration tests)
- `NavigationDestination`, `CentsFormatting`, `InfoScreen` (low risk, UI-only)
- Full CSV round-trip integration test (partially exists in `TrainingDataExporterTests`)

### Test Organization

Follow existing conventions:
- `PeachTests/Core/Training/TrainingDisciplineRegistryTests.swift`
- `PeachTests/Settings/AppUserSettingsTests.swift`
- Adapter tests can go in the feature test directories alongside existing mock files
- Discipline tests can go in feature test directories or a shared `Core/Training/` location

### References

- [Source: Peach/PitchDiscrimination/UnisonPitchDiscriminationDiscipline.swift] — Example discipline
- [Source: Peach/PitchDiscrimination/PitchDiscriminationProfileAdapter.swift] — Example adapter
- [Source: Peach/Settings/AppUserSettings.swift] — Settings bridge
- [Source: Peach/Core/Training/TrainingDisciplineRegistry.swift] — Registry

## Dev Agent Record

### Implementation Plan

- Task 1: Created `TrainingDisciplineImplementationTests.swift` covering all 6 disciplines: csvKeyValuePairs, parseCSVRow round-trip, mergeImportRecords duplicate detection, and fetchExportRecords interval filtering (unison vs interval).
- Task 2: Created `ObserverAdapterTests.swift` with MockProfileUpdating and MockRecordPersisting. Tests all 4 profile adapters (correct StatisticsKey routing, incorrect answer skipping) and all 4 store adapters (correct record creation).
- Task 3: Created `AppUserSettingsTests.swift` testing all 10 properties against defaults and validation/clamping for out-of-range values (noteRange span, tempoBPM min/max/zero, invalid tuningSystem, invalid intervals).
- Task 4: Created `TrainingDisciplineRegistryTests.swift` testing all discipline IDs registered, no common column declarations, shared columns present in deduped list, parser dispatch by training type, and distinct record types.

### Completion Notes

All 5 tasks complete. Added 49 new tests across 4 test files. Full test suite passes (1597 tests).

## File List

- PeachTests/Core/Training/TrainingDisciplineImplementationTests.swift (new)
- PeachTests/Core/Training/ObserverAdapterTests.swift (new)
- PeachTests/Core/Training/TrainingDisciplineRegistryTests.swift (new)
- PeachTests/Settings/AppUserSettingsTests.swift (new)

## Change Log

- 2026-03-28: Implemented all tasks — 4 new test files, 49 tests covering discipline implementations, observer adapters, AppUserSettings, and TrainingDisciplineRegistry
