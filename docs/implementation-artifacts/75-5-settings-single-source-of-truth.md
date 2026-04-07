# Story 75.5: Settings — Single Source of Truth

Status: done

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

- [x] Task 1: Audit current defaults for drift (AC: #1)
  - [x] Compare every `@AppStorage` default in `SettingsScreen` against `SettingsKeys`
  - [x] Compare every `AppUserSettings` fallback against `SettingsKeys`
  - [x] Document any mismatches found

- [x] Task 2: Design single-source approach (AC: #1, #4)
  - [x] Option A: `@AppStorage` properties in `SettingsScreen` use `SettingsKeys.defaultX` for their defaults, and `AppUserSettings` does the same
  - [x] Option B: Replace `@AppStorage` in `SettingsScreen` with bindings to an `@Observable` settings object that wraps `UserDefaults` with `SettingsKeys` defaults — evaluated, rejected in favor of Option A (less churn)
  - [x] Choose the approach that minimizes churn while guaranteeing single source

- [x] Task 3: Implement chosen approach (AC: #2, #3)
  - [x] Update `SettingsScreen` to eliminate duplicated defaults
  - [x] Update `AppUserSettings` to reference `SettingsKeys` defaults
  - [x] Verify `IntervalSelection` and `GapPositionEncoding` (custom encoded settings) also use single-source defaults

- [x] Task 4: Build and test both platforms (AC: #5)
  - [x] `bin/test.sh && bin/test.sh -p mac`

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
Claude Opus 4.6

### Debug Log References
None required.

### Completion Notes List
- **Audit (Task 1):** Found 3 mismatches: (1) `noteGap` in SettingsScreen used hardcoded `0.0` instead of SettingsKeys reference, (2) `intervals` default lived on `IntervalSelection.default` instead of SettingsKeys, (3) `autoStartTraining` had no explicit default in SettingsKeys (relied on implicit `UserDefaults.bool` returning `false`).
- **Design (Task 2):** Chose Option A — keep `@AppStorage` with SettingsKeys references. Added `defaultNoteGapSeconds` raw-value companion (because `Duration` lacks `RawRepresentable`), `defaultIntervalSelection`, and `defaultAutoStartTraining` to SettingsKeys.
- **Implementation (Task 3):** Fixed SettingsScreen `noteGap` and `intervalSelection` defaults, updated AppUserSettings `intervals` fallback and `autoStartTraining` to use SettingsKeys. Updated `IntervalSelection.default` to forward to SettingsKeys. Also fixed `autoStartTraining` hardcoded `false` in `PeachCommands`, `PreviewDefaults` (StubUserSettings), and `MockUserSettings`.
- **Tests (Task 4):** Added 5 new tests verifying single-source defaults. Updated 3 existing test assertions. All 1722 iOS + 1715 macOS tests pass.

### File List
- `Peach/Settings/SettingsKeys.swift` — added `defaultNoteGapSeconds`, `defaultIntervalSelection`, `defaultAutoStartTraining`; refactored `defaultNoteGap` to derive from raw value
- `Peach/Settings/SettingsScreen.swift` — fixed `noteGap` and `intervalSelection` defaults to reference SettingsKeys
- `Peach/Settings/AppUserSettings.swift` — updated `intervals` fallback and `autoStartTraining` to reference SettingsKeys
- `Peach/Settings/IntervalSelection.swift` — `.default` now forwards to `SettingsKeys.defaultIntervalSelection`
- `Peach/App/PeachCommands.swift` — `autoStartTraining` default references SettingsKeys
- `Peach/App/PreviewDefaults.swift` — `StubUserSettings.autoStartTraining` references SettingsKeys
- `PeachTests/Mocks/MockUserSettings.swift` — `autoStartTraining` default and reset reference SettingsKeys
- `PeachTests/Settings/SettingsTests.swift` — added 4 single-source-of-truth tests
- `PeachTests/Settings/AppUserSettingsTests.swift` — added `autoStartTraining` default test, updated `intervals` assertions
- `docs/implementation-artifacts/sprint-status.yaml` — status updated
- `docs/implementation-artifacts/75-5-settings-single-source-of-truth.md` — story file updated

## Change Log

- 2026-04-06: Story created from walkthrough observations
- 2026-04-07: Implemented single-source defaults — centralized noteGap, intervalSelection, and autoStartTraining defaults into SettingsKeys; fixed all consumers
