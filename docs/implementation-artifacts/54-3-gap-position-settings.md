# Story 54.3: Gap Position Settings

Status: backlog

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

- [ ] Task 1: Create `ContinuousRhythmMatchingSettings` (AC: #1, #5)
  - [ ] Create `Peach/Core/Training/ContinuousRhythmMatchingSettings.swift`
  - [ ] Properties: `tempo: TempoBPM`, `enabledGapPositions: Set<StepPosition>`
  - [ ] Default: all four positions enabled, tempo from `UserSettings`
  - [ ] `static func from(_ userSettings: UserSettings) -> ContinuousRhythmMatchingSettings`
  - [ ] Conform to `Sendable`
  - [ ] Write tests in `PeachTests/Core/Training/ContinuousRhythmMatchingSettingsTests.swift`

- [ ] Task 2: Add `@AppStorage` keys for gap positions (AC: #4)
  - [ ] Add gap position storage to `UserSettings` (or the appropriate settings store)
  - [ ] Encode `Set<StepPosition>` as a comma-separated string or JSON for `@AppStorage` compatibility
  - [ ] Write round-trip tests for encoding/decoding

- [ ] Task 3: Add gap position toggles to Settings Screen (AC: #2, #3)
  - [ ] Add a "Gap Positions" section to `SettingsScreen`
  - [ ] Four toggles labeled: "1 — Beat", "2 — E", "3 — And", "4 — A"
  - [ ] Enforce at least one enabled: disable the toggle for the last remaining position
  - [ ] Localize labels for English and German

- [ ] Task 4: Write tests (AC: #6)
  - [ ] Test default has all 4 positions enabled
  - [ ] Test `from(userSettings:)` reads tempo and gap positions
  - [ ] Test encoding/decoding round-trip
  - [ ] Test "at least one" enforcement logic

- [ ] Task 5: Run full test suite
  - [ ] `bin/test.sh` — all tests pass, no regressions

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
