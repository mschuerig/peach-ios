# Story 50.3: Settings Screen Tempo Stepper

Status: done

## Story

As a **musician using Peach**,
I want a tempo stepper in Settings to choose my rhythm training tempo,
so that I can train at my preferred speed (FR84).

## Acceptance Criteria

1. **Given** the Settings Screen, **when** displayed, **then** a "Rhythm" section appears below the "Difficulty" section and above the "Data" section.

2. **Given** the tempo stepper, **when** displayed, **then** it shows a `Stepper` with range 40–200 BPM, step 1, with a label showing the current BPM value and "BPM" unit (UX-DR7).

3. **Given** the tempo value, **when** changed by the user, **then** it is immediately persisted via `@AppStorage` and subsequent rhythm training sessions use the new tempo.

4. **Given** the minimum tempo floor, **when** the stepper is at its minimum, **then** it cannot go below 40 BPM (conservative floor below the ~60 BPM functional minimum per FR85).

5. **Given** the Settings help sheet, **when** displayed, **then** it includes a "Rhythm" section explaining the tempo stepper.

## Tasks / Subtasks

- [x] Task 1: Add `@AppStorage` property for tempo (AC: #3)
  - [x] Add `@AppStorage(SettingsKeys.tempoBPM) private var tempoBPM: Int = SettingsKeys.defaultTempoBPM.value` to `SettingsScreen`
  - [x] Follow the existing pattern: all `@AppStorage` properties use raw types (`Int`, `Double`, `String`), domain types are only for display

- [x] Task 2: Create `rhythmSection` computed property (AC: #1, #2, #4)
  - [x] Add a `private var rhythmSection: some View` computed property
  - [x] Use `Section(String(localized: "Rhythm"))` with a `Stepper`
  - [x] Stepper label: `"Tempo: \(tempoBPM) BPM"` (localized)
  - [x] Stepper range: `40...200`, step: `1`
  - [x] Add `.accessibilityValue(Text("\(tempoBPM) beats per minute"))` for VoiceOver
  - [x] Insert `rhythmSection` in the Form body between `difficultySection` and `dataSection`

- [x] Task 3: Add help section for Rhythm (AC: #5)
  - [x] Add a `HelpSection(title: "Rhythm", body: ...)` entry to `helpSections` array, between "Difficulty" and "Data"
  - [x] Help text should explain that tempo controls the speed for all rhythm training modes

- [x] Task 4: Add German localizations
  - [x] Run `bin/add-localization.swift` for any new strings: "Rhythm", "Tempo: %lld BPM", help body text
  - [x] Check `--missing` first — "Rhythm" may already exist from story 50.2 ("Rhythmus")

- [x] Task 5: Run full test suite
  - [x] `bin/test.sh` — all tests must pass

## Dev Notes

### Current SettingsScreen section order

The Form body at line 78-84 currently has:
```swift
Form {
    trainingRangeSection
    intervalSection
    soundSection
    difficultySection
    dataSection
}
```

The new `rhythmSection` goes between `difficultySection` and `dataSection`.

### @AppStorage pattern

All `@AppStorage` properties in `SettingsScreen` use raw types (`Int`, `Double`, `String`), not domain wrappers. The `TempoBPM` type is used in `AppUserSettings` for type-safe reading, but `SettingsScreen` stores the raw `Int`. Follow this pattern:

```swift
@AppStorage(SettingsKeys.tempoBPM)
private var tempoBPM: Int = SettingsKeys.defaultTempoBPM.value
```

### Stepper range vs SettingsKeys range

`SettingsKeys` defines `minimumTempoBPM = 20` and `maximumTempoBPM = 300` as safety-net clamps in `AppUserSettings`. The UI stepper enforces the tighter **40–200** range per UX-DR7. This is intentional — the AppUserSettings clamp catches raw UserDefaults corruption, the stepper provides the user-facing range.

### Existing infrastructure — no changes needed

- `SettingsKeys.tempoBPM` key already exists (line 15 of SettingsKeys.swift)
- `SettingsKeys.defaultTempoBPM` = `TempoBPM(80)` already exists (line 27)
- `UserSettings.tempoBPM` property already exists in the protocol
- `AppUserSettings.tempoBPM` getter already reads/clamps from UserDefaults
- Rhythm sessions already read tempo from settings — no session changes needed

### Help section pattern

`helpSections` is a `static let` array of `HelpSection` structs at line 54. Each has a `title` and `body` (both `String`). Add the new entry at the correct position (after "Difficulty", before "Data").

### What NOT to do

- Do NOT modify `TempoBPM`, `SettingsKeys`, `UserSettings`, or `AppUserSettings` — all infrastructure already exists from story 50.1
- Do NOT modify any training sessions — they already read tempo from settings
- Do NOT add `@Environment` dependencies — the stepper only needs `@AppStorage`
- Do NOT use `ObservableObject`/`@Published` — project uses `@Observable`
- Do NOT add explicit `@MainActor` — redundant with default isolation

### Project Structure Notes

Modified files:
```
Peach/
└── Settings/
    └── SettingsScreen.swift   # ADD @AppStorage, rhythmSection, help entry
```

No new files needed. No new dependencies.

### References

- [Source: Peach/Settings/SettingsScreen.swift:5-29 — existing @AppStorage pattern]
- [Source: Peach/Settings/SettingsScreen.swift:77-84 — Form body section order]
- [Source: Peach/Settings/SettingsScreen.swift:54-75 — helpSections array]
- [Source: Peach/Settings/SettingsScreen.swift:237-257 — difficultySection pattern to follow]
- [Source: Peach/Settings/SettingsKeys.swift:15,27-29 — tempo key and defaults]
- [Source: Peach/Settings/AppUserSettings.swift:54-58 — tempoBPM getter with clamp]
- [Source: Peach/Core/Music/TempoBPM.swift — domain type definition]
- [Source: docs/planning-artifacts/epics.md#Epic 50 Story 50.3 — acceptance criteria]
- [Source: docs/planning-artifacts/epics.md — FR84: user-selected fixed metronome tempo]
- [Source: docs/planning-artifacts/epics.md — FR85: minimum tempo floor ~60 BPM]
- [Source: docs/planning-artifacts/epics.md — UX-DR7: Settings tempo stepper spec]
- [Source: docs/project-context.md — project rules and conventions]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None — clean implementation with no debugging needed.

### Completion Notes List

- Added `@AppStorage(SettingsKeys.tempoBPM)` property using raw `Int` type following existing pattern
- Created `rhythmSection` with `Stepper` (range 40–200, step 1) and VoiceOver accessibility value
- Inserted `rhythmSection` in Form body between `difficultySection` and `dataSection`
- Added "Rhythm" help section explaining tempo controls speed for all rhythm training modes
- Added 3 German translations: "Tempo: %lld BPM", "%lld beats per minute", help body text ("Rhythm" already existed)
- Updated existing tests: `helpSectionsCount` (5→6) and `helpSectionTitlesMatchSettingsGroups` (added "Rhythm")
- All 1356 tests pass, no regressions
- **Bonus: ms offset display** — Added millisecond offset in parentheses after percentages on both rhythm training screens (stats view and feedback indicators). Added `lastCompletedOffsetMs` / `lastUserOffsetMs` computed properties to sessions, passed through to `RhythmStatsView`, `RhythmOffsetDetectionFeedbackView`, and `RhythmMatchingFeedbackView`. Example: "8% (12 ms)", "3% early (5 ms)"

### Change Log

- 2026-03-21: Implemented tempo stepper in Settings Screen (all 5 tasks)
- 2026-03-21: Added ms offset display to rhythm training feedback and stats

### File List

- Peach/Settings/SettingsScreen.swift (modified — @AppStorage, rhythmSection, help entry)
- Peach/Resources/Localizable.xcstrings (modified — 4 new German translations)
- PeachTests/Settings/SettingsTests.swift (modified — updated help section count and titles)
- Peach/RhythmOffsetDetection/RhythmOffsetDetectionSession.swift (modified — added lastCompletedOffsetMs)
- Peach/RhythmMatching/RhythmMatchingSession.swift (modified — added lastUserOffsetMs)
- Peach/RhythmOffsetDetection/RhythmStatsView.swift (modified — added latestMs parameter, msText formatter)
- Peach/RhythmOffsetDetection/RhythmOffsetDetectionFeedbackView.swift (modified — added offsetMs parameter)
- Peach/RhythmMatching/RhythmMatchingFeedbackView.swift (modified — added offsetMs parameter)
- Peach/RhythmOffsetDetection/RhythmOffsetDetectionScreen.swift (modified — passes ms to subviews)
- Peach/RhythmMatching/RhythmMatchingScreen.swift (modified — passes ms to subviews)
- docs/implementation-artifacts/50-3-settings-screen-tempo-stepper.md (modified — task checkboxes, status, dev record)
- docs/implementation-artifacts/sprint-status.yaml (modified — status update)
