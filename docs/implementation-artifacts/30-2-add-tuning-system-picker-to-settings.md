# Story 30.2: Add Tuning System Picker to Settings

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **musician using Peach**,
I want to select between Equal Temperament and Just Intonation in the Settings screen,
so that I can train my ear with the tuning system that matches my musical context.

## Acceptance Criteria

1. **Given** the Settings screen, **when** viewing the Audio section, **then** a "Tuning System" Picker is visible below the "Vary Loudness" slider
2. **Given** the Tuning System Picker, **when** viewing the options, **then** both "Equal Temperament" and "Just Intonation" are listed with their localized display names
3. **Given** a fresh install (no UserDefaults entry), **when** opening Settings, **then** "Equal Temperament" is selected by default
4. **Given** the user selects "Just Intonation", **when** starting a new training session, **then** `ComparisonSession` and `PitchMatchingSession` read `.justIntonation` from `userSettings.tuningSystem`
5. **Given** the user selects a tuning system, **when** the app is killed and relaunched, **then** the selection persists via `@AppStorage`/`UserDefaults`
6. **Given** `AppUserSettings.tuningSystem`, **when** called, **then** it reads the live value from `UserDefaults` (no longer hardcoded to `.equalTemperament`)
7. **Given** an unknown or corrupted `tuningSystem` string in UserDefaults, **when** `AppUserSettings` reads it, **then** it falls back to `.equalTemperament`
8. **Given** the Tuning System Picker, **when** displayed in English and German, **then** display names and section footer text are properly localized
9. **Given** `TuningSystem` enum, **when** accessing `displayName`, **then** it returns a localized human-readable name ("Equal Temperament" / "Just Intonation")

## Tasks / Subtasks

- [x] Task 1: Add `displayName` to `TuningSystem` and write tests (AC: #9)
  - [x] 1.1 Write failing test: `displayName returns localized name for equalTemperament`
  - [x] 1.2 Write failing test: `displayName returns localized name for justIntonation`
  - [x] 1.3 Write failing test: `all cases have non-empty displayName`
  - [x] 1.4 Implement `displayName` computed property in `TuningSystem.swift` using `String(localized:)`
- [x] Task 2: Add `tuningSystem` key to `SettingsKeys` and write tests (AC: #3)
  - [x] 2.1 Write failing test: `tuningSystem key is defined as string constant`
  - [x] 2.2 Write failing test: `defaultTuningSystem is equalTemperament`
  - [x] 2.3 Add `static let tuningSystem = "tuningSystem"` and `static let defaultTuningSystem = "equalTemperament"` to `SettingsKeys`
- [x] Task 3: Make `AppUserSettings.tuningSystem` read from UserDefaults and write tests (AC: #4, #6, #7)
  - [x] 3.1 Update existing test: `appUserSettingsTuningSystemHardcoded` → rename to `appUserSettingsTuningSystemDefault` and verify it returns `.equalTemperament` when no UserDefaults entry exists
  - [x] 3.2 Write failing test: `AppUserSettings reads persisted tuningSystem from UserDefaults`
  - [x] 3.3 Write failing test: `AppUserSettings falls back to equalTemperament on invalid string`
  - [x] 3.4 Implement live UserDefaults read in `AppUserSettings.tuningSystem`
- [x] Task 4: Add Tuning System Picker to SettingsScreen (AC: #1, #2, #5)
  - [x] 4.1 Add `@AppStorage(SettingsKeys.tuningSystem)` property to `SettingsScreen`
  - [x] 4.2 Add Picker to `audioSection` after the Vary Loudness slider
  - [x] 4.3 Add section footer with localized description text
- [x] Task 5: Add German localizations (AC: #8)
  - [x] 5.1 Use `bin/add-localization.py` to add all new German translations
- [x] Task 6: Run full test suite and verify (AC: all)
  - [x] 6.1 Run `bin/test.sh` — all existing + new tests must pass
  - [x] 6.2 Run `bin/build.sh` — no warnings or errors
  - [x] 6.3 Run `bin/check-dependencies.sh` — no dependency violations

## Dev Notes

### Technical Requirements

**What this story IS:**
- Add a `displayName` computed property to `TuningSystem` (2 localized strings)
- Add a `tuningSystem` key + default to `SettingsKeys` (2 lines)
- Replace the hardcoded `.equalTemperament` in `AppUserSettings` with a live `UserDefaults` read (~5 lines)
- Add a `Picker` + `@AppStorage` to `SettingsScreen` (~15 lines)
- Add German translations for 4 new localized strings
- Write ~8 new tests, update 1 existing test

**What this story is NOT:**
- No changes to `UserSettings` protocol — it already declares `var tuningSystem: TuningSystem { get }`
- No changes to `MockUserSettings` — it already has `var tuningSystem: TuningSystem = .equalTemperament`
- No changes to `PeachApp.swift` — `AppUserSettings` is already injected and sessions already read `tuningSystem`
- No changes to `ComparisonSession`, `PitchMatchingSession`, or any training logic — they already read `userSettings.tuningSystem` on `start()`
- No changes to `EnvironmentKeys.swift` — no new environment dependencies needed
- No new files, no new types, no new protocols

**The tuning system is already plumbed through the entire app.** Story 23.2 added `tuningSystem` to `UserSettings` and both sessions. The only missing piece is:
1. A UI picker in Settings
2. A `UserDefaults` backing store in `AppUserSettings`
3. Localized display names on `TuningSystem`

### Architecture Compliance

**FR55 governs this story:**
> FR55: System supports multiple tuning systems beyond 12-TET; adding a new tuning system requires no changes to interval or training logic.

This story completes the FR55 user-facing chain. Story 30.1 added the `.justIntonation` case with cent offsets. This story exposes the choice to the user. Together they validate that adding a tuning system required changes only to `TuningSystem.swift`, `SettingsKeys.swift`, `AppUserSettings.swift`, `SettingsScreen.swift`, and their tests — zero training/interval logic changes.

**Settings propagation flow (already implemented):**
1. User picks "Just Intonation" in Settings → `@AppStorage` writes `"justIntonation"` to `UserDefaults`
2. User starts training → `ComparisonSession.start()` reads `userSettings.tuningSystem`
3. `AppUserSettings.tuningSystem` reads `"justIntonation"` from `UserDefaults` → returns `.justIntonation`
4. Session uses `.justIntonation` for all frequency calculations during the training run

**Dependency direction preserved:**
- `TuningSystem.swift` (Core/Audio/) uses only `Foundation` (`String(localized:)`) — no SwiftUI
- `SettingsScreen.swift` (Settings/) reads `TuningSystem.allCases` and `.displayName` — this is fine, views can read Core/ types
- No cross-feature coupling introduced

### Library & Framework Requirements

**No new dependencies.** This story adds:
- `String(localized:)` calls in `TuningSystem.swift` — `Foundation` already imported
- `@AppStorage` + `Picker` in `SettingsScreen.swift` — `SwiftUI` already imported
- Zero third-party dependencies

### File Structure Requirements

**5 files modified, 0 files created:**

| File | Action | What Changes |
|------|--------|-------------|
| `Peach/Core/Audio/TuningSystem.swift` | Modify | Add `displayName` computed property |
| `Peach/Settings/SettingsKeys.swift` | Modify | Add `tuningSystem` key and `defaultTuningSystem` constant |
| `Peach/Settings/AppUserSettings.swift` | Modify | Replace hardcoded `.equalTemperament` with `UserDefaults` read |
| `Peach/Settings/SettingsScreen.swift` | Modify | Add `@AppStorage` property and Picker in audioSection |
| `Peach/Resources/Localizable.xcstrings` | Modify | Add German translations (via `bin/add-localization.py`) |

**2 test files modified:**

| File | Action | What Changes |
|------|--------|-------------|
| `PeachTests/Core/Audio/TuningSystemTests.swift` | Modify | Add `displayName` tests |
| `PeachTests/Settings/SettingsTests.swift` | Modify | Update tuning system test, add persistence and fallback tests |

**Do not touch these files:**
- `Peach/Settings/UserSettings.swift` — already has `tuningSystem` property
- `PeachTests/Mocks/MockUserSettings.swift` — already has mutable `tuningSystem`
- `Peach/App/PeachApp.swift` — no wiring changes needed
- `Peach/App/EnvironmentKeys.swift` — no new environment keys
- Any file in `Peach/Comparison/`, `Peach/PitchMatching/`, `Peach/Core/Training/`, `Peach/Core/Data/`, `Peach/Core/Algorithm/`

### Testing Requirements

**Framework:** Swift Testing (`import Testing`, `@Test`, `@Suite`, `#expect`) — never XCTest.

**All `@Test` functions must be `async`.** No `test` prefix on function names.

**New tests in `TuningSystemTests.swift`:**

```swift
// MARK: - Display Names

@Test("displayName returns Equal Temperament for equalTemperament")
func displayNameEqualTemperament() async {
    #expect(TuningSystem.equalTemperament.displayName == "Equal Temperament")
}

@Test("displayName returns Just Intonation for justIntonation")
func displayNameJustIntonation() async {
    #expect(TuningSystem.justIntonation.displayName == "Just Intonation")
}

@Test("all cases have non-empty displayName")
func allCasesHaveDisplayName() async {
    for system in TuningSystem.allCases {
        #expect(!system.displayName.isEmpty)
    }
}
```

**New/updated tests in `SettingsTests.swift`:**

```swift
// Update existing test (currently at line 67-71):
@Test("AppUserSettings returns equalTemperament when no UserDefaults entry")
func appUserSettingsTuningSystemDefault() async {
    UserDefaults.standard.removeObject(forKey: SettingsKeys.tuningSystem)
    let settings = AppUserSettings()
    #expect(settings.tuningSystem == .equalTemperament)
}

// New tests:
@Test("tuningSystem key is defined as string constant")
func tuningSystemKeyDefined() async {
    #expect(SettingsKeys.tuningSystem == "tuningSystem")
}

@Test("defaultTuningSystem is equalTemperament storage identifier")
func defaultTuningSystemValue() async {
    #expect(SettingsKeys.defaultTuningSystem == "equalTemperament")
}

@Test("AppUserSettings reads persisted tuningSystem from UserDefaults")
func appUserSettingsReadsPersistedTuningSystem() async {
    defer { UserDefaults.standard.removeObject(forKey: SettingsKeys.tuningSystem) }
    UserDefaults.standard.set("justIntonation", forKey: SettingsKeys.tuningSystem)
    let settings = AppUserSettings()
    #expect(settings.tuningSystem == .justIntonation)
}

@Test("AppUserSettings falls back to equalTemperament on invalid tuningSystem string")
func appUserSettingsTuningSystemFallbackOnInvalid() async {
    defer { UserDefaults.standard.removeObject(forKey: SettingsKeys.tuningSystem) }
    UserDefaults.standard.set("pythagorean", forKey: SettingsKeys.tuningSystem)
    let settings = AppUserSettings()
    #expect(settings.tuningSystem == .equalTemperament)
}
```

**Existing test to update:**
- `appUserSettingsTuningSystemHardcoded()` (line 67-71) → rename to `appUserSettingsTuningSystemDefault()`, add `UserDefaults.standard.removeObject(forKey:)` cleanup to ensure it tests the no-entry case explicitly

**Run full suite:** `bin/test.sh` — all tests must pass before committing.

### Implementation Guidance

**`TuningSystem.displayName` — follow `Interval.name` pattern:**

```swift
// In TuningSystem.swift, add after storageIdentifier section:

// MARK: - Display

var displayName: String {
    switch self {
    case .equalTemperament: String(localized: "Equal Temperament")
    case .justIntonation: String(localized: "Just Intonation")
    }
}
```

**`SettingsKeys` additions:**

```swift
// Add to key names section:
static let tuningSystem = "tuningSystem"

// Add to defaults section:
static let defaultTuningSystem: String = "equalTemperament"
```

**`AppUserSettings.tuningSystem` — follow `soundSource` read pattern:**

```swift
var tuningSystem: TuningSystem {
    guard let raw = UserDefaults.standard.string(forKey: SettingsKeys.tuningSystem),
          let system = TuningSystem.fromStorageIdentifier(raw) else {
        return .equalTemperament
    }
    return system
}
```

**`SettingsScreen` Picker — follow `instrumentSection` pattern but simpler:**

```swift
// Add @AppStorage property (after existing @AppStorage declarations):
@AppStorage(SettingsKeys.tuningSystem)
private var tuningSystemIdentifier: String = SettingsKeys.defaultTuningSystem

// Add Picker at end of audioSection, after the Vary Loudness VStack:
Picker(String(localized: "Tuning System"), selection: $tuningSystemIdentifier) {
    ForEach(TuningSystem.allCases, id: \.self) { system in
        Text(system.displayName).tag(system.storageIdentifier)
    }
}
```

No validated binding is needed (unlike `soundSource`). `TuningSystem.allCases` is a compile-time constant — there's no possibility of a selected value being missing from the list. The `fromStorageIdentifier` fallback in `AppUserSettings` handles any corruption.

### Localization Requirements

**4 new localized strings needed:**

| English Key | German Translation |
|---|---|
| `"Equal Temperament"` | `"Gleichstufige Stimmung"` |
| `"Just Intonation"` | `"Reine Stimmung"` |
| `"Tuning System"` | `"Stimmung"` |
| `"Select how intervals are tuned. Equal Temperament divides the octave into 12 equal steps. Just Intonation uses pure frequency ratios."` | `"Wähle die Stimmung für Intervalle. Die gleichstufige Stimmung teilt die Oktave in 12 gleiche Schritte. Reine Stimmung verwendet reine Frequenzverhältnisse."` |

**Add via script:**
```bash
bin/add-localization.py --batch translations.json
```

Where `translations.json` contains the key-value pairs above. Or use single commands:
```bash
bin/add-localization.py "Equal Temperament" "Gleichstufige Stimmung"
bin/add-localization.py "Just Intonation" "Reine Stimmung"
bin/add-localization.py "Tuning System" "Stimmung"
bin/add-localization.py "Select how intervals are tuned. Equal Temperament divides the octave into 12 equal steps. Just Intonation uses pure frequency ratios." "Wähle die Stimmung für Intervalle. Die gleichstufige Stimmung teilt die Oktave in 12 gleiche Schritte. Reine Stimmung verwendet reine Frequenzverhältnisse."
```

### Previous Story Intelligence

**Story 30.1 (Add Just Intonation Tuning System Case) — direct predecessor:**
- Added `case justIntonation` with 13 cent offset constants — the tuning system this picker exposes
- Validated FR55: zero changes outside `TuningSystem.swift` and its tests
- Added `storageIdentifier` and `fromStorageIdentifier` mappings for `"justIntonation"` — these are the exact values the Settings picker stores/reads
- All 780 tests passed after implementation

**Story 23.2 (ComparisonSession Start Rename and Strategy Interval Support) — foundation:**
- Added `tuningSystem: TuningSystem` to `UserSettings` protocol
- `AppUserSettings` returns hardcoded `.equalTemperament` — THIS is what we're replacing
- `MockUserSettings` already has mutable `tuningSystem` property
- Both sessions read `userSettings.tuningSystem` on `start()` — the live read path is already wired
- Story 23.2 explicitly noted: "Future Epic: Extend SettingsScreen to let users choose tuningSystem"

**Key pattern from story 25.2 (Interval Selector):**
- Added `IntervalSelectorView` with `@AppStorage` binding using serialized string
- `IntervalSelection` wraps `Set<DirectedInterval>` with `RawRepresentable` (JSON serialization)
- The tuning system picker is much simpler — just a `String` `storageIdentifier`, no custom wrapper type needed

### Git Intelligence

**Recent commits (Epic 28-30 chain):**
```
69ffc2c Review story 30.1: Add Just Intonation Tuning System Case
dc5e307 Implement story 30.1: Add Just Intonation Tuning System Case
312ce88 Add story 30.1: Add Just Intonation Tuning System Case
e915d9e Review story 29.1: Research Tuning Systems Used by Musicians in Practice
65e6485 Implement story 29.1: Research Tuning Systems Used by Musicians in Practice
```

**Commit format:** `{Verb} story {id}: {Description}`

**Current test count:** 780 tests passing (as of story 30.1 completion).

### Project Structure Notes

- `TuningSystem.swift` lives in `Peach/Core/Audio/` (69 lines) — only `Foundation` imported, no SwiftUI
- `SettingsScreen.swift` lives in `Peach/Settings/` (169 lines) — existing sections: intervals, noteRange, audio, instrument, data
- `SettingsKeys.swift` lives in `Peach/Settings/` (40 lines) — centralized key/default enum
- `AppUserSettings.swift` lives in `Peach/Settings/` (40 lines) — reads `UserDefaults.standard`
- Test files mirror source structure: `PeachTests/Core/Audio/TuningSystemTests.swift`, `PeachTests/Settings/SettingsTests.swift`
- No conflicts with project structure detected

### References

- [Source: docs/implementation-artifacts/30-1-add-tuning-system-case.md] — Previous story: JI case implementation, storageIdentifier values, FR55 validation
- [Source: docs/planning-artifacts/architecture.md#FR54-FR55] — TuningSystem designed as enum for Settings picker via CaseIterable
- [Source: docs/planning-artifacts/epics.md#Story-23.2] — Original action item: "Future Epic: Extend SettingsScreen to let users choose tuningSystem"
- [Source: Peach/Core/Audio/TuningSystem.swift] — Current enum (69 lines, 2 cases, storageIdentifier ready)
- [Source: Peach/Settings/SettingsScreen.swift] — Current Settings UI (169 lines, instrumentSection Picker as pattern)
- [Source: Peach/Settings/SettingsKeys.swift] — Current keys (40 lines, no tuningSystem key yet)
- [Source: Peach/Settings/AppUserSettings.swift] — Current hardcoded `.equalTemperament` at line 36-38
- [Source: Peach/Settings/UserSettings.swift] — Protocol already declares `var tuningSystem: TuningSystem { get }`
- [Source: PeachTests/Settings/SettingsTests.swift] — Current test verifying hardcoded behavior at line 67-71
- [Source: Peach/Core/Audio/Interval.swift] — `name` property pattern using `String(localized:)` for displayName reference
- [Source: docs/project-context.md] — Swift 6.2, Swift Testing, TDD, @AppStorage keys in SettingsKeys, dependency direction rules

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- displayName tests initially failed because they compared against hardcoded English strings; simulator runs in German locale, so `String(localized:)` returns German. Fixed by comparing against `String(localized:)` in tests (matching existing DirectedInterval test pattern).

### Completion Notes List

- Task 1: Added `displayName` computed property to `TuningSystem` with `String(localized:)` for both cases. Added 3 tests.
- Task 2: Added `tuningSystem` key and `defaultTuningSystem` constant to `SettingsKeys`. Added 2 tests.
- Task 3: Replaced hardcoded `.equalTemperament` in `AppUserSettings.tuningSystem` with live `UserDefaults` read using `fromStorageIdentifier`. Renamed existing test, added 2 new tests (persistence + fallback).
- Task 4: Added `@AppStorage(SettingsKeys.tuningSystem)` property and `Picker` to `audioSection` in `SettingsScreen`. Added section footer with localized description.
- Task 5: Added 4 German translations via `bin/add-localization.py`.
- Task 6: Full suite (787 tests) passes, build clean, no dependency violations.

### Change Log

- 2026-03-02: Implemented story 30.2 — Added Tuning System Picker to Settings screen, enabling users to select between Equal Temperament and Just Intonation. Added displayName to TuningSystem, live UserDefaults persistence in AppUserSettings, @AppStorage-backed Picker in SettingsScreen, German localizations, and 7 new tests (1 updated).

### File List

- Peach/Core/Audio/TuningSystem.swift (modified — added `displayName` computed property)
- Peach/Settings/SettingsKeys.swift (modified — added `tuningSystem` key and `defaultTuningSystem` constant)
- Peach/Settings/AppUserSettings.swift (modified — replaced hardcoded `.equalTemperament` with UserDefaults read)
- Peach/Settings/SettingsScreen.swift (modified — added `@AppStorage` property, Picker in audioSection, footer text)
- Peach/Resources/Localizable.xcstrings (modified — 4 new German translations)
- PeachTests/Core/Audio/TuningSystemTests.swift (modified — added 3 displayName tests)
- PeachTests/Settings/SettingsTests.swift (modified — renamed 1 test, added 4 new tests)
- docs/implementation-artifacts/sprint-status.yaml (modified — status updated)
- docs/implementation-artifacts/30-2-add-tuning-system-picker-to-settings.md (modified — task checkboxes, dev record)
