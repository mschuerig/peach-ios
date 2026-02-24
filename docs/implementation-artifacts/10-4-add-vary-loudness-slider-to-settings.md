# Story 10.4: Add "Vary Loudness" Slider to Settings

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **musician**,
I want a "Vary Loudness" slider in the Settings screen,
So that I can control how much the volume varies between notes during training.

## Acceptance Criteria

1. **Given** the user navigates to the Settings screen, **When** the screen is displayed, **Then** a "Vary Loudness" slider is visible, labeled in the current locale (English: "Vary Loudness", German: localized equivalent).

2. **Given** the slider range is 0.0 (left) to 1.0 (right), **When** the slider is all the way to the left, **Then** the label or context communicates that there will be no loudness variation (e.g., "Off" minimum value label).

3. **Given** the slider is all the way to the right, **When** the user reads the label or context, **Then** it communicates maximum loudness variation (e.g., "Max" maximum value label).

4. **Given** the user adjusts the slider to any position, **When** the user leaves Settings, **Then** the value is persisted via `@AppStorage` using a new key in `SettingsKeys.swift`.

5. **Given** the app is restarted, **When** the user opens Settings, **Then** the slider reflects the previously saved value.

6. **Given** no value has been set (fresh install or existing user), **When** the slider is first displayed, **Then** it defaults to 0.0 (no loudness variation — existing behavior preserved).

## Tasks / Subtasks

- [x] Task 1: Add `varyLoudness` key to `SettingsKeys.swift` (AC: #4, #6)
  - [x] Add `static let varyLoudness = "varyLoudness"` key constant
  - [x] Add `static let defaultVaryLoudness: Double = 0.0` default value
  - [x] Place in the existing `@AppStorage Key Names` and `Default Values` MARK sections

- [x] Task 2: Add "Vary Loudness" Slider to `SettingsScreen.swift` (AC: #1, #2, #3, #4, #5, #6)
  - [x] Add `@AppStorage(SettingsKeys.varyLoudness) private var varyLoudness: Double = SettingsKeys.defaultVaryLoudness` property alongside existing `@AppStorage` properties
  - [x] Add a `Slider` to the `audioSection` computed property, below the existing Reference Pitch stepper
  - [x] Use SwiftUI `Slider(value:in:)` with `minimumValueLabel` ("Off") and `maximumValueLabel` ("Max")
  - [x] The slider label `Text("Vary Loudness")` serves as accessibility label
  - [x] Range: `0...1`, continuous (no `step` parameter)
  - [x] No additional logic needed — `@AppStorage` handles persistence automatically

- [x] Task 3: Add localization strings to `Localizable.xcstrings` (AC: #1)
  - [x] Ensure "Vary Loudness" has German translation (e.g., "Lautstärke variieren")
  - [x] Ensure "Off" has German translation ("Aus")
  - [x] Ensure "Max" has German translation ("Max")
  - [x] Xcode extracts string literals from SwiftUI `Text()` automatically — build the project, then fill in German translations in the string catalog

- [x] Task 4: Run full test suite and verify (AC: all)
  - [x] Run: `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [x] All tests must pass with zero failures
  - [x] No new tests needed — this story adds only thin UI (SwiftUI `Slider` + `@AppStorage`) with no business logic; the setting's consumption and testable behavior arrive in Story 10.5

## Dev Notes

### Slider Precedent: Natural vs. Mechanical (Removed)

A `Slider` for `naturalVsMechanical` previously existed in the Settings screen for the `AdaptiveNoteStrategy`. It was removed in Story 9.1 when `KazezNoteStrategy` was promoted to the sole default strategy. The key still exists in `SettingsKeys.swift` but is no longer displayed. No `Slider` component currently exists in the codebase — all Settings controls are `Stepper` or `Picker`.

SwiftUI `Slider` pattern to follow:

```swift
Slider(value: $varyLoudness, in: 0...1) {
    Text("Vary Loudness")
} minimumValueLabel: {
    Text("Off")
} maximumValueLabel: {
    Text("Max")
}
```

The `Text("Vary Loudness")` label is used by VoiceOver for accessibility. The `minimumValueLabel` and `maximumValueLabel` communicate the slider's meaning at each extreme (AC #2, #3).

### Placement: Audio Section

Add the slider to the existing `audioSection` computed property in `SettingsScreen.swift`, below the Reference Pitch stepper. The Audio section groups audio-related settings (duration, pitch, now loudness variation). Do NOT create a new section for a single slider.

### @AppStorage Pattern (Established)

Follow the exact pattern used by existing settings:

1. Key constant in `SettingsKeys.swift` → `static let varyLoudness = "varyLoudness"`
2. Default value in `SettingsKeys.swift` → `static let defaultVaryLoudness: Double = 0.0`
3. `@AppStorage` property in `SettingsScreen.swift` → bound directly to the Slider
4. Persistence is automatic — no save button, no manual UserDefaults writes

The value will be consumed by `TrainingSession` in Story 10.5 via `UserDefaults.standard.object(forKey: SettingsKeys.varyLoudness)` following the same live-read pattern as other settings.

### Default Value: 0.0 (Critical)

Default MUST be `0.0` (no loudness variation). This preserves existing behavior for:
- Fresh installs (no key in UserDefaults)
- Existing users upgrading (no key in UserDefaults)

At `0.0`, Story 10.5 will compute `±(0.0 × 2.0) = ±0.0 dB` offset — no audible change.

### No New Tests Needed

This story adds zero business logic:
- `SettingsKeys` constants are trivial declarations
- `Slider` binding to `@AppStorage` is framework-guaranteed
- Persistence behavior is `@AppStorage`'s responsibility
- No validation logic (slider range is enforced by SwiftUI `in:` parameter)

The full test suite must pass to verify no regressions. Testable behavior for this setting arrives in Story 10.5 when `TrainingSession` reads and applies the value.

### Localization: String Catalogs

The project uses `Localizable.xcstrings` (String Catalogs). SwiftUI `Text("...")` literals are automatically extracted by Xcode during build. After adding the Slider:

1. Build the project in Xcode
2. Open `Localizable.xcstrings`
3. New strings ("Vary Loudness", "Off", "Max") will appear as needing translation
4. Add German translations

Note: "Off" and "Max" may already exist in the catalog if used elsewhere — check before adding duplicates.

### Complete File Change Map (3 files)

| File | Type | Changes |
|---|---|---|
| `Peach/Settings/SettingsKeys.swift` | Constants | Add `varyLoudness` key + `defaultVaryLoudness` default |
| `Peach/Settings/SettingsScreen.swift` | View | Add `@AppStorage` property, add `Slider` to `audioSection` |
| `Peach/Resources/Localizable.xcstrings` | Localization | Add/verify "Vary Loudness", "Off", "Max" with German translations |

### Previous Story (10.3) Intelligence

Story 10.3 added `amplitudeDB: Float` parameter to `NotePlayer.play()`. Key facts for continuity:
- `amplitudeDB` range: -90.0 to +12.0 dB (0.0 = no change)
- `TrainingSession` currently passes hardcoded `amplitudeDB: 0.0` at both play() calls
- Story 10.5 will replace the hardcoded `0.0` for note2 with a computed offset based on this story's slider value
- The formula: `±(varyLoudness × maxOffset)` dB where `maxOffset` = 2.0 dB initially
- At slider = 1.0: max offset ±2.0 dB, well within the -90.0...+12.0 valid range

### Git Intelligence

Recent commits show clean Epic 10 progression:
- `ead72b5` Fix code review findings for 10-3-add-amplitude-parameter-to-noteplayer
- `7cb7e08` Implement story 10.3: Add amplitude parameter to NotePlayer
- `df32cac` Fix code review findings for 10-2-rename-amplitude-to-velocity
- `ba8a983` Implement story 10.2: Rename amplitude to velocity throughout codebase

Pattern: story file committed first ("Add story X.Y"), then implementation ("Implement story X.Y"), then review fixes if needed.

### Project Structure Notes

- No new files created — all changes are to existing files
- No new dependencies or imports needed
- No architecture changes — follows established `@AppStorage` pattern exactly
- No audio graph or TrainingSession changes (those come in Story 10.5)
- Slider is a standard SwiftUI component — no custom UI needed

### References

- [Source: docs/planning-artifacts/epics.md#Story 10.4] — Acceptance criteria and epic context
- [Source: docs/planning-artifacts/epics.md#Story 10.5] — How the slider value will be consumed (±sliderValue × maxOffset dB)
- [Source: docs/implementation-artifacts/10-3-add-amplitude-parameter-to-noteplayer.md] — Previous story: amplitudeDB parameter, masterGain mechanism
- [Source: docs/project-context.md#Framework-Specific Rules] — @AppStorage pattern, SettingsKeys centralization, views are thin
- [Source: docs/project-context.md#Testing Rules] — All new code requires tests, full suite before commit
- [Source: docs/planning-artifacts/ux-design-specification.md#Settings] — Continuous slider for training behavior settings
- [Source: Peach/Settings/SettingsKeys.swift] — Existing key constants and defaults pattern
- [Source: Peach/Settings/SettingsScreen.swift] — Current Settings form with Stepper/Picker controls, audioSection placement
- [Source: Peach/Training/TrainingSession.swift:121-136] — Live settings read pattern via UserDefaults.standard

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (claude-opus-4-6)

### Debug Log References

None — clean implementation with no issues.

### Completion Notes List

- Added `varyLoudness` key and `defaultVaryLoudness: 0.0` default to `SettingsKeys.swift`, following the established pattern
- Added `@AppStorage` property and `Slider(value:in:0...1)` with "Off"/"Max" labels to `audioSection` in `SettingsScreen.swift`, below Reference Pitch stepper
- Added German translations to `Localizable.xcstrings`: "Vary Loudness" → "Lautstärke variieren", "Off" → "Aus", "Max" → "Max"
- Default 0.0 preserves existing behavior for fresh installs and upgrading users
- Full test suite passes with zero failures — no regressions

### Change Log

- 2026-02-25: Implemented story 10.4 — Added "Vary Loudness" slider to Settings screen with @AppStorage persistence, "Off"/"Max" range labels, and German localization
- 2026-02-25: Code review fixes — Corrected Localizable.xcstrings path in Dev Notes file change map; added translator context comments to "Off", "Max", "Vary Loudness" localization entries

### File List

- Peach/Settings/SettingsKeys.swift (modified — added varyLoudness key + defaultVaryLoudness)
- Peach/Settings/SettingsScreen.swift (modified — added @AppStorage property + Slider in audioSection)
- Peach/Resources/Localizable.xcstrings (modified — added "Vary Loudness", "Off", "Max" with German translations)
