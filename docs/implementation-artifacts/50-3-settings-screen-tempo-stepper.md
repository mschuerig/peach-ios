# Story 50.3: Settings Screen Tempo Stepper

Status: ready-for-dev

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

- [ ] Task 1: Add `@AppStorage` property for tempo (AC: #3)
  - [ ] Add `@AppStorage(SettingsKeys.tempoBPM) private var tempoBPM: Int = SettingsKeys.defaultTempoBPM.value` to `SettingsScreen`
  - [ ] Follow the existing pattern: all `@AppStorage` properties use raw types (`Int`, `Double`, `String`), domain types are only for display

- [ ] Task 2: Create `rhythmSection` computed property (AC: #1, #2, #4)
  - [ ] Add a `private var rhythmSection: some View` computed property
  - [ ] Use `Section(String(localized: "Rhythm"))` with a `Stepper`
  - [ ] Stepper label: `"Tempo: \(tempoBPM) BPM"` (localized)
  - [ ] Stepper range: `40...200`, step: `1`
  - [ ] Add `.accessibilityValue(Text("\(tempoBPM) beats per minute"))` for VoiceOver
  - [ ] Insert `rhythmSection` in the Form body between `difficultySection` and `dataSection`

- [ ] Task 3: Add help section for Rhythm (AC: #5)
  - [ ] Add a `HelpSection(title: "Rhythm", body: ...)` entry to `helpSections` array, between "Difficulty" and "Data"
  - [ ] Help text should explain that tempo controls the speed for all rhythm training modes

- [ ] Task 4: Add German localizations
  - [ ] Run `bin/add-localization.swift` for any new strings: "Rhythm", "Tempo: %lld BPM", help body text
  - [ ] Check `--missing` first — "Rhythm" may already exist from story 50.2 ("Rhythmus")

- [ ] Task 5: Run full test suite
  - [ ] `bin/test.sh` — all tests must pass

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

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
