---
title: 'Fix sound source reverting to default on app startup'
slug: 'fix-sound-source-startup-default'
created: '2026-03-21'
status: 'ready-for-dev'
stepsCompleted: [1, 2, 3, 4]
tech_stack: [SwiftUI, AppStorage/UserDefaults, AVAudioUnitSampler, SoundFontEngine]
files_to_modify: [Peach/App/PeachApp.swift]
code_patterns: ['@AppStorage for UserDefaults persistence', 'SoundFontLibrary.resolve() for preset lookup', 'Composition root in PeachApp.init()', 'validateSoundSource() ensures stored value is valid before use']
test_patterns: ['Manual verification — no unit test for app startup preset selection']
---

# Tech-Spec: Fix sound source reverting to default on app startup

**Created:** 2026-03-21

## Overview

### Problem Statement

On app launch, the `notePlayer` is initialized with the hardcoded default `"sf2:0:0"` instead of the user's saved sound source preference. The settings screen correctly displays the saved value, but audio playback uses the wrong instrument until the user manually re-selects their preference.

### Solution

Replace the hardcoded `SettingsKeys.defaultSoundSource` with the actual persisted UserDefaults value when resolving the initial preset in `PeachApp.init()`.

### Scope

**In Scope:**
- Fix the preset resolution line in `PeachApp.init()` to use the saved sound source value
- Verify the saved value is correctly used on startup

**Out of Scope:**
- Refactoring the `@AppStorage` pattern
- Changes to the settings screen
- Broader audio architecture changes

## Context for Development

### Codebase Patterns

- `@AppStorage(SettingsKeys.soundSource)` is the standard way to access the persisted sound source at runtime
- `SoundFontLibrary.resolve()` maps a `SoundSourceTag` to an `SF2Preset`, falling back to `defaultPreset` if not found
- `SettingsKeys.defaultSoundSource` is the hardcoded fallback `"sf2:0:0"`
- `SettingsKeys.validateSoundSource(against:)` (called on line 40 of PeachApp.swift) validates the stored value against available presets *before* the buggy line — so by line 45, UserDefaults is guaranteed to hold a valid value
- Composition root in `PeachApp.init()` constructs all dependencies using `State(wrappedValue:)`
- `.onChange(of: soundSource)` handler (lines 139-160) correctly rebuilds `notePlayer` and sessions when the user changes sound source at runtime

### Files to Reference

| File | Purpose |
| ---- | ------- |
| `Peach/App/PeachApp.swift:45` | **Bug location** — hardcodes `SettingsKeys.defaultSoundSource` instead of reading saved value |
| `Peach/App/PeachApp.swift:20` | `@AppStorage` declaration for `soundSource` |
| `Peach/App/PeachApp.swift:40` | `validateSoundSource()` call — ensures UserDefaults has a valid value before line 45 |
| `Peach/App/PeachApp.swift:139-160` | Working `.onChange` handler — correct pattern to replicate |
| `Peach/Settings/SettingsKeys.swift:10,22` | `soundSource` key name and `defaultSoundSource` constant |
| `Peach/Settings/SettingsKeys.swift:47-56` | `validateSoundSource()` — resets to default if stored value is invalid |
| `Peach/Core/Audio/SoundFontLibrary.swift:47-49` | `resolve()` — maps tag to SF2Preset, falls back to default |

### Technical Decisions

- Read the saved value directly from UserDefaults in init (`UserDefaults.standard.string(forKey:)`) rather than relying on `@AppStorage` property, since `@AppStorage` may not have synced during `init()`. This matches the pattern used by `validateSoundSource()` itself (line 51 of SettingsKeys.swift).

## Implementation Plan

### Tasks

- [ ] Task 1: Fix preset resolution in `PeachApp.init()`
  - File: `Peach/App/PeachApp.swift`
  - Action: On line 45, replace:
    ```swift
    let preset = soundFontLibrary.resolve(SoundSourceTag(rawValue: SettingsKeys.defaultSoundSource))
    ```
    with:
    ```swift
    let savedSource = UserDefaults.standard.string(forKey: SettingsKeys.soundSource) ?? SettingsKeys.defaultSoundSource
    let preset = soundFontLibrary.resolve(SoundSourceTag(rawValue: savedSource))
    ```
  - Notes: `validateSoundSource(against:)` on line 40 has already run, so the value in UserDefaults is guaranteed to be valid (or reset to default). No additional validation needed.

### Acceptance Criteria

- [ ] AC 1: Given a user has previously selected a non-default sound source (e.g., `"sf2:0:42"` Cello), when the app is launched, then the `notePlayer` plays using the saved sound source — not the default `"sf2:0:0"`.
- [ ] AC 2: Given a fresh install with no saved preference, when the app is launched, then the `notePlayer` uses the default `"sf2:0:0"` (Grand Piano).
- [ ] AC 3: Given a user has a saved sound source that was invalidated by `validateSoundSource()` (e.g., removed preset), when the app is launched, then the player uses the default `"sf2:0:0"` because validation already reset UserDefaults.

## Additional Context

### Dependencies

None — single-line change with no new dependencies.

### Testing Strategy

**Manual verification:**
1. Launch app with default settings — confirm Grand Piano plays
2. Change sound source to a different instrument (e.g., Cello) in Settings
3. Force-quit the app
4. Relaunch — confirm the selected instrument (Cello) plays immediately, not Grand Piano
5. Verify Settings screen still shows the correct selection

### Notes

- The `.onChange(of: soundSource)` handler already works correctly for runtime changes. This fix only addresses the initial startup value.
- The fix introduces one extra `let` binding (`savedSource`) for clarity. This keeps the resolve call clean and makes the intent obvious.
