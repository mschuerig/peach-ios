# Story 64.10: Add Tests for Untested Critical Paths

Status: ready-for-dev

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

- [ ] Task 1: Write discipline implementation tests (AC: #1)
  - [ ] 1.1 Create test files for each discipline or a shared `TrainingDisciplineTests.swift` that iterates all 6
  - [ ] 1.2 Test `csvKeyValuePairs()` produces expected column values for a known record
  - [ ] 1.3 Test `parseCSVRow()` round-trip: export a record to CSV fields, parse back, verify equality
  - [ ] 1.4 Test `mergeImportRecords()` skips duplicates and imports non-duplicates
  - [ ] 1.5 Test `fetchExportRecords()` filtering: unison discipline only returns interval=0 records, interval discipline only returns interval>0 records

- [ ] Task 2: Write observer adapter tests (AC: #2)
  - [ ] 2.1 For each profile adapter (4 total): create test verifying that calling the observer method updates `PerceptualProfile` with the correct `StatisticsKey`
  - [ ] 2.2 For each store adapter (4 total): create test verifying that calling the observer method creates and saves the correct record type in a mock or in-memory store

- [ ] Task 3: Write `AppUserSettings` tests (AC: #3)
  - [ ] 3.1 Create `AppUserSettingsTests.swift` in `PeachTests/Settings/`
  - [ ] 3.2 Test default values for all properties (noteRange, noteDuration, referencePitch, soundSource, varyLoudness, intervals, tuningSystem, noteGap, tempoBPM, enabledGapPositions)
  - [ ] 3.3 Test that out-of-range UserDefaults values are clamped or rejected

- [ ] Task 4: Write `TrainingDisciplineRegistry` tests (AC: #4)
  - [ ] 4.1 Create `TrainingDisciplineRegistryTests.swift` in `PeachTests/Core/Training/`
  - [ ] 4.2 Test: all `TrainingDisciplineID.allCases` are registered
  - [ ] 4.3 Test: no CSV column name overlaps between disciplines (excluding common columns)
  - [ ] 4.4 Test: each discipline's CSV training type string resolves to the correct parser

- [ ] Task 5: Run full test suite (AC: #5)

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
