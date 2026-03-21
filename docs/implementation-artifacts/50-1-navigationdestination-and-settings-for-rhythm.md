# Story 50.1: NavigationDestination and Settings for Rhythm

Status: ready-for-dev

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

- [ ] Task 1: Add `.rhythmMatching` to `NavigationDestination` and wire in `StartScreen` (AC: #1, #2)
  - [ ] Add `case rhythmMatching` to `NavigationDestination` enum in `Peach/App/NavigationDestination.swift`
  - [ ] Add `.rhythmMatching` → `RhythmMatchingScreen()` case in `StartScreen.navigationDestination` handler (line 71–86)
  - [ ] Note: `.rhythmOffsetDetection` case already exists and is wired

- [ ] Task 2: Add `tempoBPM` to `SettingsKeys` (AC: #3)
  - [ ] Add `static let tempoBPM = "tempoBPM"` key name
  - [ ] Add `static let defaultTempoBPM: TempoBPM = TempoBPM(80)` default value
  - [ ] Add `static let minimumTempoBPM: TempoBPM = TempoBPM(60)` floor constant

- [ ] Task 3: Add `tempoBPM` to `UserSettings` protocol and `AppUserSettings` (AC: #4, #5)
  - [ ] Add `var tempoBPM: TempoBPM { get }` to `UserSettings` protocol in `Peach/Settings/UserSettings.swift`
  - [ ] Implement in `AppUserSettings` reading from `UserDefaults.standard.integer(forKey: SettingsKeys.tempoBPM)`, falling back to `SettingsKeys.defaultTempoBPM`
  - [ ] Apply clamping: `max(SettingsKeys.minimumTempoBPM, rawValue)` so values below 60 are clamped up
  - [ ] Handle the case where `UserDefaults` returns 0 (key not set) by using the default

- [ ] Task 4: Add `from(userSettings:)` factory methods to rhythm settings (AC: #6)
  - [ ] Add `static func from(_ userSettings: UserSettings) -> RhythmMatchingSettings` to `RhythmMatchingSettings`
  - [ ] Maps `userSettings.tempoBPM` → `tempo`, keeps `feedbackDuration` at default
  - [ ] Add `static func from(_ userSettings: UserSettings) -> RhythmOffsetDetectionSettings` to `RhythmOffsetDetectionSettings`
  - [ ] Maps `userSettings.tempoBPM` → `tempo`, keeps other params at defaults
  - [ ] Write tests in `PeachTests/Core/Training/RhythmMatchingSettingsTests.swift` (NEW)
  - [ ] Write tests in `PeachTests/Core/Training/RhythmOffsetDetectionSettingsTests.swift` (NEW)

- [ ] Task 5: Update rhythm screens to use `from(userSettings:)` (AC: #7)
  - [ ] In `RhythmMatchingScreen`: add `@Environment(\.userSettings) private var userSettings`
  - [ ] Change `session.start(settings: RhythmMatchingSettings())` → `session.start(settings: .from(userSettings))`
  - [ ] Apply same change in help sheet dismiss handler
  - [ ] In `RhythmOffsetDetectionScreen`: add `@Environment(\.userSettings) private var userSettings`
  - [ ] Change `session.start(settings: RhythmOffsetDetectionSettings())` → `session.start(settings: .from(userSettings))`
  - [ ] Apply same change in help sheet dismiss handler

- [ ] Task 6: Update `MockUserSettings` (AC: #8)
  - [ ] Add `var tempoBPM: TempoBPM = SettingsKeys.defaultTempoBPM` with `didSet { onSettingsChanged?() }`
  - [ ] Add `tempoBPM = SettingsKeys.defaultTempoBPM` to `reset()` method

- [ ] Task 7: Run full test suite
  - [ ] `bin/test.sh` — all tests pass, no regressions

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

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
