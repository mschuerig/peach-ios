---
title: 'Pitch Comparison Note Gap Setting'
slug: 'pitch-comparison-note-gap'
created: '2026-03-15'
status: 'completed'
stepsCompleted: [1, 2, 3, 4]
tech_stack: ['Swift 6.2', 'SwiftUI', '@Observable', '@AppStorage', 'Swift Testing']
files_to_modify: ['Peach/Settings/SettingsKeys.swift', 'Peach/Settings/UserSettings.swift', 'Peach/Settings/AppUserSettings.swift', 'Peach/Core/Training/PitchComparisonTrainingSettings.swift', 'Peach/PitchComparison/PitchComparisonSession.swift', 'Peach/Settings/SettingsScreen.swift', 'PeachTests/Mocks/MockUserSettings.swift', 'PeachTests/Core/Training/PitchComparisonTrainingSettingsTests.swift', 'PeachTests/Settings/SettingsTests.swift', 'PeachTests/PitchComparison/PitchComparisonSessionTests.swift']
code_patterns: ['@AppStorage keys in SettingsKeys enum', 'UserSettings protocol + AppUserSettings impl + MockUserSettings mock', 'PitchComparisonTrainingSettings value-type snapshot with factory method from(userSettings, intervals:)', 'Duration for all timing values', 'SettingsScreen sections as computed properties', 'Swift Testing with @Test/@Suite/#expect, async test functions']
test_patterns: ['@Suite struct-based test suites', '@Test("behavioral description") async functions', 'MockUserSettings for settings injection', 'Factory methods returning tuples for session tests', 'In-memory ModelContainer for SwiftData tests']
---

# Tech-Spec: Pitch Comparison Note Gap Setting

**Created:** 2026-03-15

## Overview

### Problem Statement

In pitch comparison training, the reference and target notes play back-to-back with no silence between them. Users may want a configurable pause to better process each note before hearing the next.

### Solution

Add a configurable gap (0.0–5.0s, default 0.0, step 0.1) that inserts a silence between note 1 and note 2 in pitch comparison training. Surfaced in Settings in its own "Pitch Comparison" section.

### Scope

**In Scope:**
- New `noteGap` field in `PitchComparisonTrainingSettings` (using `Duration`)
- New `@AppStorage` key + `UserSettings` protocol property + `AppUserSettings` implementation
- Delay in `PitchComparisonSession` between `.playingNote1` completion and `.playingNote2` start
- New "Pitch Comparison" section in `SettingsScreen` with the gap stepper
- Localization (English + German)

**Out of Scope:**
- Pitch matching training (already has a natural gap via slider interaction)
- Any other pitch-comparison-specific settings in the new section (just the gap for now)

## Context for Development

### Codebase Patterns

- Settings use `@AppStorage` with keys centralized in `SettingsKeys.swift` as static string constants with corresponding default values
- `UserSettings` protocol abstracts settings access; `AppUserSettings` reads from `UserDefaults.standard` with fallbacks to `SettingsKeys` defaults
- `MockUserSettings` mirrors all `UserSettings` properties with `didSet { onSettingsChanged?() }` pattern and a `reset()` method
- `PitchComparisonTrainingSettings` is a value-type snapshot with an `init` providing defaults and a `static func from(_ userSettings:, intervals:)` factory that maps user-configurable values while keeping algorithm constants at defaults
- `Duration` is used for timing values in settings structs (e.g., `feedbackDuration: Duration = .milliseconds(400)`)
- `@AppStorage` stores `Double` for duration-like values (e.g., `noteDuration`)
- `SettingsScreen` sections are computed view properties (`trainingRangeSection`, `intervalSection`, `soundSection`, `difficultySection`, `dataSection`)
- `PitchComparisonSession.playPitchComparisonNotes()` plays note 1, then immediately plays note 2 with no delay (lines 231–240)

### Files to Reference

| File | Purpose |
| ---- | ------- |
| `Peach/Settings/SettingsKeys.swift` | Add `noteGap` key + default value |
| `Peach/Settings/UserSettings.swift` | Add `noteGap` protocol property |
| `Peach/Settings/AppUserSettings.swift` | Add `noteGap` computed property reading from UserDefaults |
| `Peach/Core/Training/PitchComparisonTrainingSettings.swift` | Add `noteGap: Duration` field, update init + factory |
| `Peach/PitchComparison/PitchComparisonSession.swift` | Insert `Task.sleep` between note 1 and note 2 |
| `Peach/Settings/SettingsScreen.swift` | Add "Pitch Comparison" section with gap stepper |
| `PeachTests/Mocks/MockUserSettings.swift` | Add `noteGap` property |
| `PeachTests/Core/Training/PitchComparisonTrainingSettingsTests.swift` | Test new default + factory mapping |
| `PeachTests/Settings/SettingsTests.swift` | Test new key, default, AppUserSettings read |
| `PeachTests/PitchComparison/PitchComparisonSessionTests.swift` | Test gap delay between notes |

### Technical Decisions

- Use Swift `Duration` for the gap value in `PitchComparisonTrainingSettings` (consistent with `feedbackDuration`)
- Store as `Double` (seconds) in `@AppStorage` (consistent with `noteDuration` storage pattern)
- New property name: `noteGap` throughout the stack (`SettingsKeys.noteGap`, `UserSettings.noteGap`, `PitchComparisonTrainingSettings.noteGap`)
- Default `0.0` seconds — preserves current behavior (no gap)
- Place in a new "Pitch Comparison" section in SettingsScreen to clearly indicate this setting only applies to pitch comparison training
- The gap delay uses `Task.sleep(for:)` between note 1 completion and note 2 start, with cancellation/idle checks before and after
- `PitchMatchingTrainingSettings` is NOT modified — pitch matching has a natural gap via slider interaction

## Implementation Plan

### Tasks

- [x] Task 1: Add `noteGap` key and default to `SettingsKeys`
  - File: `Peach/Settings/SettingsKeys.swift`
  - Action: Add `static let noteGap = "noteGap"` in the key names section. Add `static let defaultNoteGap: Double = 0.0` in the default values section.

- [x] Task 2: Add `noteGap` to `UserSettings` protocol
  - File: `Peach/Settings/UserSettings.swift`
  - Action: Add `var noteGap: Double { get }` to the protocol. Use `Double` (not `Duration`) since this is the storage/settings layer — conversion to `Duration` happens in `PitchComparisonTrainingSettings`.

- [x] Task 3: Implement `noteGap` in `AppUserSettings`
  - File: `Peach/Settings/AppUserSettings.swift`
  - Action: Add computed property `var noteGap: Double { UserDefaults.standard.object(forKey: SettingsKeys.noteGap) as? Double ?? SettingsKeys.defaultNoteGap }`. Follow the same pattern as `noteDuration`.

- [x] Task 4: Add `noteGap` to `MockUserSettings`
  - File: `PeachTests/Mocks/MockUserSettings.swift`
  - Action: Add `var noteGap: Double = SettingsKeys.defaultNoteGap { didSet { onSettingsChanged?() } }`. Add `noteGap = SettingsKeys.defaultNoteGap` to the `reset()` method.

- [x] Task 5: Add `noteGap` field to `PitchComparisonTrainingSettings`
  - File: `Peach/Core/Training/PitchComparisonTrainingSettings.swift`
  - Action: Add `var noteGap: Duration` field. Add `noteGap: Duration = .zero` parameter to `init`. Add `noteGap: .seconds(userSettings.noteGap)` to the `from(_:intervals:)` factory method.

- [x] Task 6: Insert gap delay in `PitchComparisonSession`
  - File: `Peach/PitchComparison/PitchComparisonSession.swift`
  - Action: In `playPitchComparisonNotes()`, after note 1 finishes playing (line 232) and after the idle/cancellation guard (line 237), insert a conditional gap delay before `state = .playingNote2` (line 239):
    ```swift
    if settings.noteGap > .zero {
        try await Task.sleep(for: settings.noteGap)
        guard state != .idle && !Task.isCancelled else {
            logger.info("Training stopped during note gap, aborting comparison")
            return
        }
    }
    ```

- [x] Task 7: Add "Pitch Comparison" section to `SettingsScreen`
  - File: `Peach/Settings/SettingsScreen.swift`
  - Action:
    1. Add `@AppStorage(SettingsKeys.noteGap) private var noteGap: Double = SettingsKeys.defaultNoteGap` to the existing `@AppStorage` declarations.
    2. Add a new `pitchComparisonSection` computed property with a `Section` titled "Pitch Comparison" containing a `Stepper` for the gap: `Stepper("Note Gap: \(noteGap, specifier: "%.1f")s", value: $noteGap, in: 0.0...5.0, step: 0.1)`.
    3. Insert `pitchComparisonSection` in the `body` Form between `soundSection` and `difficultySection`.

- [x] Task 8: Add localization strings
  - Action: Use `bin/add-localization.py` to add German translations for the new UI strings:
    - "Pitch Comparison" section header → German: "Tonhöhenvergleich"
    - "Note Gap: %.1fs" stepper label → German: "Pause: %.1fs" (Note: the stepper label uses string interpolation, so localize accordingly via String Catalog)

- [x] Task 9: Add help section for Pitch Comparison
  - File: `Peach/Settings/SettingsScreen.swift`
  - Action: Add a new `HelpSection` to `helpSections` array (insert after "Sound", before "Difficulty") with title "Pitch Comparison" and body explaining the note gap setting. Update help section tests accordingly.

- [x] Task 10: Write tests for settings layer
  - File: `PeachTests/Settings/SettingsTests.swift`
  - Action: Add tests:
    - `noteGap key is defined as string constant` — `#expect(SettingsKeys.noteGap == "noteGap")`
    - `defaultNoteGap is zero` — `#expect(SettingsKeys.defaultNoteGap == 0.0)`
    - `AppUserSettings returns default noteGap when no UserDefaults entry` — remove key, read, expect 0.0
    - `AppUserSettings reads persisted noteGap from UserDefaults` — set 2.5, read, expect 2.5
    - Update `helpSectionsCount` test to expect 6 sections
    - Update `helpSectionTitlesMatchSettingsGroups` test to include "Pitch Comparison"

- [x] Task 11: Write tests for `PitchComparisonTrainingSettings`
  - File: `PeachTests/Core/Training/PitchComparisonTrainingSettingsTests.swift`
  - Action: Add tests:
    - In `defaultValues()`: add `#expect(settings.noteGap == .zero)`
    - In `fromUserSettings()`: set `mockSettings.noteGap = 1.5`, verify `settings.noteGap == .seconds(1.5)`
    - In `fromUserSettingsKeepsDefaults()`: verify `noteGap` is NOT a kept default (it's user-configurable)

- [x] Task 12: Write tests for gap in `PitchComparisonSession`
  - File: `PeachTests/PitchComparison/PitchComparisonSessionTests.swift`
  - Action: Add tests:
    - `plays notes without gap when noteGap is zero` — start with `noteGap: .zero`, verify note 2 plays immediately after note 1 (check `notePlayer.playCallCount == 2` without timing assertions)
    - `stops during note gap aborts comparison` — start with a non-zero `noteGap`, stop the session during the gap, verify state returns to `.idle`

### Acceptance Criteria

- [x] AC 1: Given default settings (noteGap = 0.0), when a pitch comparison plays, then note 2 starts immediately after note 1 finishes (no behavioral change from current behavior).
- [x] AC 2: Given noteGap is set to 1.5s, when a pitch comparison plays, then there is a 1.5-second silence between note 1 ending and note 2 starting.
- [x] AC 3: Given noteGap is set to a non-zero value, when the user stops training during the gap, then the session transitions to idle and no note 2 plays.
- [x] AC 4: Given the Settings screen is open, when the user scrolls to the "Pitch Comparison" section, then a "Note Gap" stepper is visible with range 0.0–5.0s and 0.1s step increment.
- [x] AC 5: Given the user changes the Note Gap setting, when they start a new pitch comparison training, then the configured gap is applied between notes.
- [x] AC 6: Given the Settings screen is open, when the user taps the help button, then the "Pitch Comparison" help section explains the note gap setting.
- [x] AC 7: Given the app language is German, when the Settings screen is displayed, then the "Pitch Comparison" section and "Note Gap" stepper labels are shown in German.

## Additional Context

### Dependencies

None — purely additive feature, no external dependencies.

### Testing Strategy

**Unit tests:**
- `SettingsTests`: key constant, default value, `AppUserSettings` read/fallback, help section count/titles
- `PitchComparisonTrainingSettingsTests`: default `noteGap` is `.zero`, factory maps `userSettings.noteGap` to `Duration`
- `PitchComparisonSessionTests`: gap is skipped when `.zero`, session can be stopped during gap

**Manual testing:**
- Verify stepper appears in Settings under "Pitch Comparison" section
- Set gap to 0.0 and confirm notes play back-to-back (unchanged behavior)
- Set gap to 2.0s and confirm audible silence between notes
- Stop training during the gap and confirm clean transition to idle
- Switch to German and confirm localized labels
- Verify pitch matching training is unaffected by the noteGap setting

### Notes

- The `noteGap` property uses `Duration` on the `UserSettings` protocol (converted from `Double` in `AppUserSettings`), and flows directly into `PitchComparisonTrainingSettings`.
- The gap introduces a new cancellation point in `playPitchComparisonNotes()`. The guard pattern after `Task.sleep` is identical to the existing guard after note 1 playback.
- `CancellationError` handling was added to `playNextPitchComparison()` to properly handle task cancellation during the gap sleep.
- Future consideration: if more pitch-comparison-specific settings are added later, the "Pitch Comparison" section in `SettingsScreen` provides a natural home for them.

## Review Notes
- Adversarial review completed
- Findings: 10 total, 5 fixed, 5 skipped (3 noise, 2 low-impact)
- Resolution approach: walk-through
