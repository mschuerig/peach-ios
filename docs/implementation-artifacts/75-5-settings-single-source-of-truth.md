# Story 75.5: Settings — Single Source of Truth

Status: ready-for-dev

## Story

As a **developer modifying settings**,
I want setting keys, defaults, and types defined in exactly one place,
so that adding or changing a setting cannot cause the UI and session to disagree.

## Background

The walkthrough (Layer 6) found that settings have three sources of truth: `SettingsKeys` (key names + defaults), `@AppStorage` declarations in `SettingsScreen` (with defaults that must match), and `AppUserSettings` (with defaults that must match). If any default drifts, the UI and session will disagree on the setting value.

`SettingsScreen` defines 11 `@AppStorage` properties with default values that duplicate `SettingsKeys`. `AppUserSettings` reads the same keys from `UserDefaults` with its own default fallbacks. Adding a new setting requires updating all three places.

**Walkthrough source:** Layer 6 observation #3.

## Acceptance Criteria

1. **Given** any setting **When** its default value is defined **Then** it exists in exactly one place — `SettingsKeys` (or a replacement single source).
2. **Given** `SettingsScreen` **When** inspected **Then** its `@AppStorage` properties do not declare defaults that could drift from `SettingsKeys`. They either use a shared default or are initialized from the single source.
3. **Given** `AppUserSettings` **When** inspected **Then** it reads defaults from `SettingsKeys` rather than defining its own fallback values.
4. **Given** a developer **When** adding a new setting **Then** they define the key and default in one place, and both the UI and session automatically use it.
5. **Given** both platforms **When** built and tested **Then** all tests pass and all settings behave identically to before.

## Tasks / Subtasks

- [ ] Task 1: Audit current defaults for drift (AC: #1)
  - [ ] Compare every `@AppStorage` default in `SettingsScreen` against `SettingsKeys`
  - [ ] Compare every `AppUserSettings` fallback against `SettingsKeys`
  - [ ] Document any mismatches found

- [ ] Task 2: Design single-source approach (AC: #1, #4)
  - [ ] Option A: `@AppStorage` properties in `SettingsScreen` use `SettingsKeys.defaultX` for their defaults, and `AppUserSettings` does the same
  - [ ] Option B: Replace `@AppStorage` in `SettingsScreen` with bindings to an `@Observable` settings object that wraps `UserDefaults` with `SettingsKeys` defaults
  - [ ] Choose the approach that minimizes churn while guaranteeing single source

- [ ] Task 3: Implement chosen approach (AC: #2, #3)
  - [ ] Update `SettingsScreen` to eliminate duplicated defaults
  - [ ] Update `AppUserSettings` to reference `SettingsKeys` defaults
  - [ ] Verify `IntervalSelection` and `GapPositionEncoding` (custom encoded settings) also use single-source defaults

- [ ] Task 4: Build and test both platforms (AC: #5)
  - [ ] `bin/test.sh && bin/test.sh -p mac`

## Dev Notes

### Source File Locations

| File | Role |
|------|------|
| `Peach/Settings/SettingsScreen.swift` (367 lines) | 11 `@AppStorage` properties with defaults |
| `Peach/Settings/SettingsKeys.swift` (65 lines) | Key names and default values |
| `Peach/Settings/AppUserSettings.swift` (81 lines) | `UserDefaults` reader with fallbacks |
| `Peach/Settings/IntervalSelection.swift` | JSON-encoded `Set<DirectedInterval>` |
| `Peach/Settings/GapPositionEncoding.swift` | Comma-separated encoding |

### The Three Current Sources

1. **`SettingsKeys`**: `static let defaultMinNote = 48`, `static let defaultMaxNote = 84`, etc.
2. **`SettingsScreen`**: `@AppStorage(SettingsKeys.minNote) private var minNote = SettingsKeys.defaultMinNote` — this is already referencing `SettingsKeys` for *some* defaults, but check all 11.
3. **`AppUserSettings`**: `var noteRange: NoteRange { let min = defaults.integer(forKey: SettingsKeys.minNote); ... }` — uses its own validation/fallback logic.

The fix may be simpler than expected if most `@AppStorage` defaults already reference `SettingsKeys`. The audit (Task 1) will reveal the actual scope.

### What NOT to Change

- Do not change the `UserSettings` protocol or its consumers
- Do not change the settings UI layout or behavior
- Do not migrate away from `@AppStorage` unless necessary — it provides automatic SwiftUI view updates

### References

- [Source: docs/walkthrough/6-screens-and-navigation.md — observation #3]

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-04-06: Story created from walkthrough observations
