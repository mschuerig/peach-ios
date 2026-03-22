# Story 54.3: Gap Position Settings

Status: done

## Story

As a **musician using Peach**,
I want to select which gap positions (1–4) are enabled for continuous rhythm matching,
so that I can focus my training on specific subdivisions within the beat.

## Acceptance Criteria

1. **Given** `ContinuousRhythmMatchingSettings`, **when** inspected, **then** it has `enabledGapPositions: Set<StepPosition>` (default: all four enabled) and `tempo: TempoBPM`.

2. **Given** the Settings Screen, **when** the user navigates to it, **then** a "Gap Positions" section is visible with toggles for positions 1–4, labeled with their musical function (e.g., "Beat", "E", "And", "A").

3. **Given** the gap position toggles, **when** the user disables a position, **then** it is removed from the enabled set; **when** all other positions are disabled, **then** the last remaining position cannot be disabled (at least one must be enabled).

4. **Given** the settings are persisted via `@AppStorage`, **when** the app restarts, **then** the enabled gap positions are restored.

5. **Given** `ContinuousRhythmMatchingSettings.from(_ userSettings:)`, **when** called, **then** it reads the user's tempo and gap position preferences from `UserSettings`.

6. **Given** unit tests, **when** settings serialization and validation are tested, **then** encoding/decoding of `Set<StepPosition>` round-trips correctly and the "at least one" invariant holds.

## Tasks / Subtasks

- [x] Task 1: Create `ContinuousRhythmMatchingSettings` (AC: #1, #5)
  - [x] Create `Peach/Core/Training/ContinuousRhythmMatchingSettings.swift`
  - [x] Properties: `tempo: TempoBPM`, `enabledGapPositions: Set<StepPosition>`
  - [x] Default: all four positions enabled, tempo from `UserSettings`
  - [x] `static func from(_ userSettings: UserSettings) -> ContinuousRhythmMatchingSettings`
  - [x] Conform to `Sendable`
  - [x] Write tests in `PeachTests/Core/Training/ContinuousRhythmMatchingSettingsTests.swift`

- [x] Task 2: Add `@AppStorage` keys for gap positions (AC: #4)
  - [x] Add gap position storage to `UserSettings` (or the appropriate settings store)
  - [x] Encode `Set<StepPosition>` as a comma-separated string or JSON for `@AppStorage` compatibility
  - [x] Write round-trip tests for encoding/decoding

- [x] Task 3: Add gap position toggles to Settings Screen (AC: #2, #3)
  - [x] Add a "Gap Positions" section to `SettingsScreen`
  - [x] Four toggles labeled: "1 — Beat", "2 — E", "3 — And", "4 — A"
  - [x] Enforce at least one enabled: disable the toggle for the last remaining position
  - [x] Localize labels for English and German

- [x] Task 4: Write tests (AC: #6)
  - [x] Test default has all 4 positions enabled
  - [x] Test `from(userSettings:)` reads tempo and gap positions
  - [x] Test encoding/decoding round-trip
  - [x] Test "at least one" enforcement logic

- [x] Task 5: Run full test suite
  - [x] `bin/test.sh` — all tests pass, no regressions

## Dev Notes

### Gap position labels

The four 16th-note positions within a beat have standard syllabic names in music pedagogy:

| Position | Syllable | Musical weight |
|----------|----------|----------------|
| 1 | Beat (downbeat) | Strongest |
| 2 | E | Weak |
| 3 | And | Moderate |
| 4 | A | Weak |

These labels appear in the settings toggles. German equivalents: the syllables are the same in German music pedagogy ("Beat"/"E"/"And"/"A" or "Eins"/"E"/"Und"/"A" — check with domain expert).

### `@AppStorage` encoding

`Set<StepPosition>` can't be stored directly in `@AppStorage`. Encode as a sorted comma-separated string of raw values: `"0,1,2,3"` for all four, `"0,2"` for positions 1 and 3.

### At-least-one enforcement

This is a UI concern, not a model concern. The settings struct accepts any non-empty set. The toggle UI disables the last remaining toggle.

### What NOT to do

- Do NOT create the training screen — that's Story 54.4
- Do NOT modify existing rhythm matching settings — this is a new settings type
- Do NOT create complex settings hierarchies — keep it flat

### References

- [Source: Peach/Core/Training/RhythmMatchingSettings.swift — existing settings pattern]
- [Source: Peach/Core/Training/RhythmOffsetDetectionSettings.swift — settings with from(userSettings:)]
- [Source: Peach/Settings/SettingsScreen.swift — settings UI patterns]
- [Source: Peach/Core/Audio/StepSequencer.swift — StepPosition type from Story 54.1]
- [Source: docs/project-context.md — project rules and conventions]

## Dev Agent Record

### Implementation Plan

- `ContinuousRhythmMatchingSettings` already existed from story 54.2 with `enabledGapPositions` property but `from(userSettings:)` did not read gap positions
- Added `enabledGapPositions` to `UserSettings` protocol, `AppUserSettings`, `MockUserSettings`, and `PreviewUserSettings`
- Created `GapPositionEncoding` utility for encoding/decoding `Set<StepPosition>` to/from comma-separated strings for `@AppStorage`
- Added `@AppStorage` key in `SettingsKeys` with default of all four positions
- Updated `ContinuousRhythmMatchingSettings.from(userSettings:)` to pass gap positions through
- Added "Gap Positions" section to `SettingsScreen` with four toggles and at-least-one enforcement
- German localization for all new strings

### Completion Notes

- All 1525 tests pass (1 new test added, plus encoding tests in new suite)
- Dependency check: no new violations (pre-existing HapticFeedbackManager UIKit import)
- Followed existing settings patterns (encode to string for @AppStorage, decode in AppUserSettings)

## File List

- Peach/Core/Training/ContinuousRhythmMatchingSettings.swift (modified — `from(userSettings:)` now reads gap positions)
- Peach/Settings/UserSettings.swift (modified — added `enabledGapPositions` property)
- Peach/Settings/SettingsKeys.swift (modified — added `enabledGapPositions` key and default)
- Peach/Settings/AppUserSettings.swift (modified — added `enabledGapPositions` computed property)
- Peach/Settings/GapPositionEncoding.swift (new — encode/decode `Set<StepPosition>` for `@AppStorage`)
- Peach/Settings/SettingsScreen.swift (modified — added gap positions section with toggles)
- Peach/App/EnvironmentKeys.swift (modified — added `enabledGapPositions` to `PreviewUserSettings`)
- Peach/Resources/Localizable.xcstrings (modified — added 7 German translations)
- PeachTests/Core/Training/ContinuousRhythmMatchingSettingsTests.swift (modified — added gap position tests)
- PeachTests/Settings/GapPositionEncodingTests.swift (new — encoding/decoding round-trip tests)
- PeachTests/Mocks/MockUserSettings.swift (modified — added `enabledGapPositions` property)

## Change Log

- 2026-03-22: Implemented story 54.3 — gap position settings with UI toggles, persistence, and localization
