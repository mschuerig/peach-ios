# Story 50.1: NavigationDestination and Settings for Rhythm

Status: review

## Story

As a **developer**,
I want `NavigationDestination` to include rhythm cases and `AppUserSettings`/`UserSettings` to include a tempo property,
so that rhythm training can be navigated to and tempo can be configured.

## Acceptance Criteria

1. **Given** `NavigationDestination` enum, **when** extended, **then** it includes `.rhythmMatching` case with no parameters (tempo read from settings).

2. **Given** `ContentView` (via `StartScreen.navigationDestination`), **when** updated with navigation destination handling, **then** `.rhythmMatching` navigates to `RhythmMatchingScreen`.

3. **Given** `SettingsKeys`, **when** extended, **then** it includes a `tempoBPM` key with default `TempoBPM(80)`.

4. **Given** `UserSettings` protocol and `AppUserSettings`, **when** extended, **then** they include a `tempoBPM: TempoBPM` property backed by `@AppStorage`.

5. **Given** the tempo value, **when** set below the minimum floor, **then** it is clamped to `TempoBPM(60)` (FR85).

6. **Given** `RhythmMatchingSettings` and `RhythmOffsetDetectionSettings`, **when** both get `from(userSettings:)` factory methods, **then** they read `tempoBPM` from `UserSettings` instead of hardcoding the default.

7. **Given** `RhythmMatchingScreen` and `RhythmOffsetDetectionScreen`, **when** they start sessions, **then** they use the factory method with `@Environment(\.userSettings)` instead of default-constructed settings.

8. **Given** `MockUserSettings`, **when** updated, **then** it includes `tempoBPM` with a default matching `SettingsKeys.defaultTempoBPM`.

## Tasks / Subtasks

- [x] Task 1: Add `.rhythmMatching` to `NavigationDestination` and wire in `StartScreen` (AC: #1, #2)
  - [x] Add `case rhythmMatching` to `NavigationDestination` enum in `Peach/App/NavigationDestination.swift`
  - [x] Add `.rhythmMatching` → `RhythmMatchingScreen()` case in `StartScreen.navigationDestination` handler (line 71–86)
  - [x] Note: `.rhythmOffsetDetection` case already exists and is wired

- [x] Task 2: Add `tempoBPM` to `SettingsKeys` (AC: #3)
  - [x] Add `static let tempoBPM = "tempoBPM"` key name
  - [x] Add `static let defaultTempoBPM: TempoBPM = TempoBPM(80)` default value
  - [x] Add `static let minimumTempoBPM: TempoBPM = TempoBPM(60)` floor constant

- [x] Task 3: Add `tempoBPM` to `UserSettings` protocol and `AppUserSettings` (AC: #4, #5)
  - [x] Add `var tempoBPM: TempoBPM { get }` to `UserSettings` protocol in `Peach/Settings/UserSettings.swift`
  - [x] Implement in `AppUserSettings` reading from `UserDefaults.standard.integer(forKey: SettingsKeys.tempoBPM)`, falling back to `SettingsKeys.defaultTempoBPM`
  - [x] Apply clamping: `max(SettingsKeys.minimumTempoBPM, rawValue)` so values below 60 are clamped up
  - [x] Handle the case where `UserDefaults` returns 0 (key not set) by using the default

- [x] Task 4: Add `from(userSettings:)` factory methods to rhythm settings (AC: #6)
  - [x] Add `static func from(_ userSettings: UserSettings) -> RhythmMatchingSettings` to `RhythmMatchingSettings`
  - [x] Maps `userSettings.tempoBPM` → `tempo`, keeps `feedbackDuration` at default
  - [x] Add `static func from(_ userSettings: UserSettings) -> RhythmOffsetDetectionSettings` to `RhythmOffsetDetectionSettings`
  - [x] Maps `userSettings.tempoBPM` → `tempo`, keeps other params at defaults
  - [x] Write tests in `PeachTests/Core/Training/RhythmMatchingSettingsTests.swift` (EXTENDED)
  - [x] Write tests in `PeachTests/Core/Training/RhythmOffsetDetectionSettingsTests.swift` (NEW)

- [x] Task 5: Update rhythm screens to use `from(userSettings:)` (AC: #7)
  - [x] In `RhythmMatchingScreen`: add `@Environment(\.userSettings) private var userSettings`
  - [x] Change `session.start(settings: RhythmMatchingSettings())` → `session.start(settings: .from(userSettings))`
  - [x] Apply same change in help sheet dismiss handler
  - [x] In `RhythmOffsetDetectionScreen`: add `@Environment(\.userSettings) private var userSettings`
  - [x] Change `session.start(settings: RhythmOffsetDetectionSettings())` → `session.start(settings: .from(userSettings))`
  - [x] Apply same change in help sheet dismiss handler

- [x] Task 6: Update `MockUserSettings` (AC: #8)
  - [x] Add `var tempoBPM: TempoBPM = SettingsKeys.defaultTempoBPM` with `didSet { onSettingsChanged?() }`
  - [x] Add `tempoBPM = SettingsKeys.defaultTempoBPM` to `reset()` method

- [x] Task 7: Run full test suite
  - [x] `bin/test.sh` — all 1356 tests pass, no regressions

## Dev Notes

### NavigationDestination — only add `.rhythmMatching`

`.rhythmOffsetDetection` already exists in the enum (added in Epic 48). Only `.rhythmMatching` is missing. The `.rhythmPOC` case will be removed in Story 50.2 when the Start Screen is redesigned — do NOT remove it in this story.

### UserSettings pattern — follow existing convention

`AppUserSettings` reads from `UserDefaults.standard` directly (not `@AppStorage`). Each property is a computed `var` with a `get` that reads, applies defaults/clamping, and returns the domain type. Follow the exact same pattern for `tempoBPM`.

**Clamping logic:** `UserDefaults.integer(forKey:)` returns `0` when the key doesn't exist. Treat `0` as "not set" and return the default. For any positive value below 60, clamp to 60.

```swift
var tempoBPM: TempoBPM {
    let raw = UserDefaults.standard.integer(forKey: SettingsKeys.tempoBPM)
    guard raw > 0 else { return SettingsKeys.defaultTempoBPM }
    return max(SettingsKeys.minimumTempoBPM, TempoBPM(raw))
}
```

### Factory method pattern — simpler than pitch settings

Pitch settings factory methods take `(userSettings, intervals:)` because intervals come from `@AppStorage` in the view. Rhythm settings only need `(userSettings)` since tempo is the only user-configurable parameter. The factory reads `userSettings.tempoBPM` and keeps all other settings at defaults.

```swift
// RhythmMatchingSettings
static func from(_ userSettings: UserSettings) -> RhythmMatchingSettings {
    RhythmMatchingSettings(tempo: userSettings.tempoBPM)
}

// RhythmOffsetDetectionSettings
static func from(_ userSettings: UserSettings) -> RhythmOffsetDetectionSettings {
    RhythmOffsetDetectionSettings(tempo: userSettings.tempoBPM)
}
```

### Screen updates — mirror pitch screen pattern

Both `PitchDiscriminationScreen` and `PitchMatchingScreen` use `@Environment(\.userSettings)` and call `.from(userSettings, intervals:)`. Rhythm screens should follow the same pattern with `.from(userSettings)`. Update both `onAppear` and help sheet dismiss restart.

### SettingsScreen Stepper is Story 50.3

Do NOT add any UI to `SettingsScreen` in this story. The tempo stepper is Story 50.3. This story only adds the data layer and navigation plumbing.

### What NOT to do

- Do NOT remove `.rhythmPOC` case or `RhythmPOCScreen` — that cleanup is Story 50.2
- Do NOT add a "Rhythm" section or buttons to Start Screen — that's Story 50.2
- Do NOT add a Stepper to Settings Screen — that's Story 50.3
- Do NOT use `@AppStorage` in `AppUserSettings` — it reads from `UserDefaults.standard` directly
- Do NOT use `ObservableObject` / `@Published` — project uses `@Observable`
- Do NOT add explicit `@MainActor` — redundant with default isolation
- Do NOT create `Utils/` or `Helpers/` directories
- Do NOT use `public` or `open` access control

### Project Structure Notes

Modified files:
```
Peach/
├── App/
│   └── NavigationDestination.swift              # ADD .rhythmMatching case
├── Start/
│   └── StartScreen.swift                        # ADD .rhythmMatching → RhythmMatchingScreen() in destination handler
├── Settings/
│   ├── SettingsKeys.swift                       # ADD tempoBPM key, default, minimum
│   ├── UserSettings.swift                       # ADD tempoBPM property to protocol
│   └── AppUserSettings.swift                    # ADD tempoBPM computed property with clamping
├── Core/Training/
│   ├── RhythmMatchingSettings.swift             # ADD from(userSettings:) factory method
│   └── RhythmOffsetDetectionSettings.swift      # ADD from(userSettings:) factory method
├── RhythmMatching/
│   └── RhythmMatchingScreen.swift               # ADD userSettings environment, use factory
├── RhythmOffsetDetection/
│   └── RhythmOffsetDetectionScreen.swift        # ADD userSettings environment, use factory

PeachTests/
├── Mocks/
│   └── MockUserSettings.swift                   # ADD tempoBPM property
├── Core/Training/
│   ├── RhythmMatchingSettingsTests.swift        # NEW — factory method tests
│   └── RhythmOffsetDetectionSettingsTests.swift # NEW — factory method tests
```

### References

- [Source: Peach/App/NavigationDestination.swift — enum to extend]
- [Source: Peach/Start/StartScreen.swift:71-86 — navigation destination handler to extend]
- [Source: Peach/Settings/SettingsKeys.swift — key registry to extend]
- [Source: Peach/Settings/UserSettings.swift — protocol to extend]
- [Source: Peach/Settings/AppUserSettings.swift — implementation to extend]
- [Source: Peach/Core/Training/RhythmMatchingSettings.swift — add factory method]
- [Source: Peach/Core/Training/RhythmOffsetDetectionSettings.swift — add factory method]
- [Source: Peach/Core/Training/PitchMatchingSettings.swift:39-48 — factory method pattern to follow]
- [Source: Peach/PitchMatching/PitchMatchingScreen.swift:74,80 — screen pattern using from(userSettings)]
- [Source: Peach/RhythmMatching/RhythmMatchingScreen.swift — screen to update]
- [Source: Peach/RhythmOffsetDetection/RhythmOffsetDetectionScreen.swift — screen to update]
- [Source: PeachTests/Mocks/MockUserSettings.swift — mock to extend]
- [Source: Peach/Core/Music/TempoBPM.swift — domain type for tempo]
- [Source: docs/planning-artifacts/epics.md#Epic 50 Story 50.1 — acceptance criteria]
- [Source: docs/project-context.md — project rules and conventions]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Build initially failed due to `PreviewUserSettings` in `EnvironmentKeys.swift` missing `tempoBPM` — fixed by adding the property.

### Completion Notes List

- Added `.rhythmMatching` case to `NavigationDestination` and wired it to `RhythmMatchingScreen` in `StartScreen`
- Added `tempoBPM` key, default (80 BPM), and minimum (60 BPM) to `SettingsKeys`
- Extended `UserSettings` protocol with `tempoBPM: TempoBPM` property
- Implemented `tempoBPM` in `AppUserSettings` with clamping logic (0 → default, <60 → 60)
- Added `from(_ userSettings:)` factory methods to both `RhythmMatchingSettings` and `RhythmOffsetDetectionSettings`
- Updated both rhythm screens to use `@Environment(\.userSettings)` and factory methods instead of default-constructed settings
- Updated `MockUserSettings` and `PreviewUserSettings` with `tempoBPM` property
- Added factory method tests to `RhythmMatchingSettingsTests` and created new `RhythmOffsetDetectionSettingsTests`
- All 1356 tests pass

### Change Log

- 2026-03-21: Implemented story 50.1 — navigation destination, settings layer, and factory methods for rhythm tempo

### File List

- Peach/App/NavigationDestination.swift (modified)
- Peach/App/EnvironmentKeys.swift (modified)
- Peach/Start/StartScreen.swift (modified)
- Peach/Settings/SettingsKeys.swift (modified)
- Peach/Settings/UserSettings.swift (modified)
- Peach/Settings/AppUserSettings.swift (modified)
- Peach/Core/Training/RhythmMatchingSettings.swift (modified)
- Peach/Core/Training/RhythmOffsetDetectionSettings.swift (modified)
- Peach/RhythmMatching/RhythmMatchingScreen.swift (modified)
- Peach/RhythmOffsetDetection/RhythmOffsetDetectionScreen.swift (modified)
- PeachTests/Mocks/MockUserSettings.swift (modified)
- PeachTests/Core/Training/RhythmMatchingSettingsTests.swift (modified)
- PeachTests/Core/Training/RhythmOffsetDetectionSettingsTests.swift (new)
