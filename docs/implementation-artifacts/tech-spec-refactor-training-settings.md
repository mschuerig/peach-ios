---
title: 'Refactor TrainingSettings into Session-Specific Types'
slug: 'refactor-training-settings'
created: '2026-03-10'
status: 'completed'
stepsCompleted: [1, 2, 3, 4]
tech_stack: ['Swift 6.2', 'SwiftUI', 'Swift Testing']
files_to_modify:
  - 'Peach/Core/Audio/AmplitudeDB.swift'
  - 'Peach/Core/Algorithm/NextPitchComparisonStrategy.swift'
  - 'Peach/Core/Algorithm/KazezNoteStrategy.swift'
  - 'Peach/Core/Training/TrainingConstants.swift'
  - 'Peach/Core/TrainingSession.swift'
  - 'Peach/PitchComparison/PitchComparisonSession.swift'
  - 'Peach/PitchMatching/PitchMatchingSession.swift'
  - 'Peach/PitchComparison/PitchComparisonScreen.swift'
  - 'Peach/PitchMatching/PitchMatchingScreen.swift'
  - 'Peach/Settings/SettingsScreen.swift'
  - 'Peach/App/PeachApp.swift'
  - 'Peach/App/EnvironmentKeys.swift'
  - 'Peach/Core/Audio/SoundFontNotePlayer.swift'
  - 'PeachTests/Core/Audio/AmplitudeDBTests.swift'
  - 'PeachTests/Mocks/MockUserSettings.swift'
  - 'PeachTests/PitchComparison/*.swift'
  - 'PeachTests/PitchMatching/PitchMatchingSessionTests.swift'
  - 'PeachTests/Core/Algorithm/KazezNoteStrategyTests.swift'
code_patterns:
  - 'Domain types wrap raw values with clamped validation'
  - 'Sessions are @Observable final classes with state machines'
  - 'PeachApp.swift is sole composition root'
  - '@Entry environment keys in App/EnvironmentKeys.swift'
  - 'Protocol-first design with mock injection for tests'
  - 'Factory methods return tuples in test suites'
test_patterns:
  - 'Swift Testing: @Test, @Suite, #expect'
  - 'Struct-based test suites, async test functions'
  - 'MockNotePlayer with instantPlayback, waitForState helper'
  - 'Fresh mocks per test via factory methods'
---

# Tech-Spec: Refactor TrainingSettings into Session-Specific Types

**Created:** 2026-03-10

## Overview

### Problem Statement

Training configuration is scattered and inconsistent across sessions. `PitchComparisonSession` and `PitchMatchingSession` mix three different patterns for accessing settings: (1) some values go through `TrainingSettings` (noteRange, referencePitch), (2) some are read live from `UserSettings` via computed properties (noteDuration, varyLoudness, intervals, tuningSystem), and (3) some are hardcoded constants on the session (maxLoudnessOffsetDB, initialCentOffsetRange, velocity, feedbackDuration). This makes sessions harder to test (they depend on `UserSettings` protocol), harder to reason about (which settings are snapshotted vs live?), and couples tunable parameters to session implementations.

Additionally, `AmplitudeDB` wraps `Float` which forces conversions when used in `Double`-based calculations.

### Solution

1. Change `AmplitudeDB` to wrap `Double`.
2. Replace the single `TrainingSettings` with two session-specific types: `PitchComparisonTrainingSettings` and `PitchMatchingTrainingSettings`. Each contains all tunable parameters for its session type — including constants that currently live on sessions or in `TrainingConstants`.
3. Each settings type has a `static func from(_ userSettings: UserSettings, intervals: Set<DirectedInterval>) -> Self` factory method. Screens call `session.start(settings: .from(userSettings, intervals: intervals))`.
4. Sessions receive settings via `start(settings:)` and never reference `UserSettings`. Tests pass settings directly.
5. Add `varyLoudness` support to `PitchMatchingSession`.
6. Move `previewDuration` to `SettingsScreen` and pass explicitly to `soundPreviewPlay()`.
7. Remove `TrainingConstants` enum (all values distributed to settings types or SettingsScreen).

### Scope

**In Scope:**
- `AmplitudeDB`: `Float` → `Double`
- Two new settings types with all tunable parameters
- Factory methods on settings types to build from `UserSettings`
- Sessions receive settings at `start()`, remove `UserSettings` dependency from `init`
- `TrainingSession` protocol: remove `start(intervals:)` (each session gets its own typed `start(settings:)`)
- `varyLoudness` support for `PitchMatchingSession`
- `previewDuration` moved to `SettingsScreen`
- Remove `TrainingConstants` enum
- Update `NextPitchComparisonStrategy` to receive `PitchComparisonTrainingSettings`
- Add `@Entry var userSettings` environment key for screens
- Update all tests

**Out of Scope:**
- Changing session state machines
- New UI for settings
- Changing observer patterns
- Changing `NotePlayer` or audio layer

## Context for Development

### Codebase Patterns

- Domain types (`Cents`, `Frequency`, `NoteDuration`, `AmplitudeDB`, `UnitInterval`) wrap raw values with clamped validation in `init(_ rawValue:)`
- Sessions are `@Observable final class` with state machines and `os.Logger`
- `PeachApp.swift` is the sole composition root — all service instantiation happens there
- `@Entry` environment keys in `App/EnvironmentKeys.swift` — never co-located with domain types
- `UserSettings` protocol in `Settings/UserSettings.swift`; `AppUserSettings` reads `@AppStorage` under the hood
- `TrainingSession` protocol: `start(intervals:)`, `stop()`, `isIdle` — used by `PeachApp` to track `activeSession`
- `NextPitchComparisonStrategy` protocol + `KazezNoteStrategy` implementation in `Core/Algorithm/`
- Screens receive `intervals: Set<DirectedInterval>` as a view property from navigation
- `soundPreviewPlay` is an injected closure `(() async -> Void)?` in environment
- No SwiftUI imports in `Core/` files
- `private` by default; `internal` only when cross-file access needed
- `sampler.overallGain` (`AVAudioUnitSampler`) is `Float` — the one place where `AmplitudeDB` must convert to `Float` at the hardware boundary

### Files to Reference

| File | Purpose |
| ---- | ------- |
| `Peach/Core/Audio/AmplitudeDB.swift` | Domain type: `Float` → `Double`, range `-90.0...12.0` |
| `Peach/Core/Algorithm/NextPitchComparisonStrategy.swift` | Current `TrainingSettings` (L56-73) + strategy protocol |
| `Peach/Core/Algorithm/KazezNoteStrategy.swift` | Strategy impl, receives `TrainingSettings` |
| `Peach/Core/Training/TrainingConstants.swift` | `feedbackDuration` (400ms), `velocity` (63), `previewDuration` (2.0s) |
| `Peach/Core/TrainingSession.swift` | Protocol: `start(intervals:)`, `stop()`, `isIdle` |
| `Peach/Core/Audio/SoundFontNotePlayer.swift` | L178: `sampler.overallGain = amplitudeDB.rawValue` — needs `Float()` cast |
| `Peach/PitchComparison/PitchComparisonSession.swift` | 326 lines. Config: L38-59. `start()`: L111. `calculateTargetAmplitude`: L242-247 |
| `Peach/PitchMatching/PitchMatchingSession.swift` | 308 lines. Config: L203-214. `start()`: L91. `initialCentOffsetRange`: L56. `sliderFrequency`: L131-135 |
| `Peach/PitchComparison/PitchComparisonScreen.swift` | Calls `start(intervals:)` at L154, L159 |
| `Peach/PitchMatching/PitchMatchingScreen.swift` | Calls `start(intervals:)` at L139, L144 |
| `Peach/Settings/UserSettings.swift` | Protocol: noteRange, noteDuration, referencePitch, soundSource, varyLoudness, intervals, tuningSystem |
| `Peach/Settings/SettingsScreen.swift` | 361 lines. Preview uses `soundPreviewPlay` closure |
| `Peach/App/PeachApp.swift` | Composition root (202 lines). Creates sessions at L66-83. `soundPreviewPlay` closure at L98-109 |
| `Peach/App/EnvironmentKeys.swift` | Environment keys + preview stubs. Preview sessions use `PreviewUserSettings` |
| `PeachTests/Mocks/MockUserSettings.swift` | 16-line mock — still needed for `from()` factory tests |
| `PeachTests/PitchComparison/` | 10 test files, ~1850 lines total |
| `PeachTests/PitchMatching/PitchMatchingSessionTests.swift` | 1170 lines |
| `PeachTests/Core/Algorithm/KazezNoteStrategyTests.swift` | 477 lines |
| `PeachTests/Core/Audio/AmplitudeDBTests.swift` | 61 lines |

### Technical Decisions

1. **Two types, not one**: `PitchComparisonTrainingSettings` and `PitchMatchingTrainingSettings` — keeps tests clean (no irrelevant parameters), allows modes to diverge independently.
2. **Factory methods on settings types**: `static func from(_ userSettings: UserSettings, intervals: Set<DirectedInterval>)` — settings types own the knowledge of how to build from `UserSettings`. Screens call `.from(userSettings, intervals: intervals)`. No logic leaks into views.
3. **Sessions decoupled from `UserSettings`**: `init()` no longer takes `userSettings:`. `start(settings:)` receives a fully-formed settings struct. Tests construct settings directly without mocking `UserSettings`.
4. **Constants become default parameter values**: `maxLoudnessOffsetDB = AmplitudeDB(10.0)`, `initialCentOffsetRange = -20.0...20.0`, `velocity = MIDIVelocity(63)`, `feedbackDuration = .milliseconds(400)` — tunable in tests, sensible defaults in production.
5. **`AmplitudeDB` wraps `Double`**: Eliminates Float↔Double conversions. Only `SoundFontNotePlayer.startNote()` converts to `Float` for `sampler.overallGain`.
6. **`maxLoudnessOffsetDB` increases from 5.0 to 10.0**: Design decision — wider loudness variation range.
7. **`TrainingSession` protocol**: Remove `start(intervals:)`. Keep `stop()` and `isIdle`. `PeachApp` only uses `activeSession` for stop/idle tracking.
8. **`UserSettings` environment key**: Add `@Entry var userSettings: any UserSettings` to `EnvironmentKeys.swift`. Screens use it to build settings via `.from(userSettings, intervals:)`.
9. **`previewDuration`**: Move to `SettingsScreen` as a `private static let`. Change `soundPreviewPlay` closure to accept `duration: TimeInterval`. `SettingsScreen` passes `2.0` explicitly.

## Implementation Plan

### Tasks

Tasks are ordered by dependency (lowest-level first). Each task should compile after completion.

- [x] **Task 1: Change `AmplitudeDB` from `Float` to `Double`**
  - File: `Peach/Core/Audio/AmplitudeDB.swift`
  - Action: Change `rawValue: Float` → `rawValue: Double`, `validRange: ClosedRange<Float>` → `ClosedRange<Double>`, `init(_ rawValue: Float)` → `init(_ rawValue: Double)`. Remove `ExpressibleByFloatLiteral` extension (now redundant — `Double` literal works directly). Update `ExpressibleByIntegerLiteral` to use `Double(value)`.
  - File: `Peach/Core/Audio/SoundFontNotePlayer.swift` L178
  - Action: Change `sampler.overallGain = amplitudeDB.rawValue` → `sampler.overallGain = Float(amplitudeDB.rawValue)`. This is the AVAudioEngine hardware boundary.
  - File: `PeachTests/Core/Audio/AmplitudeDBTests.swift`
  - Action: Update test expectations from `Float` to `Double` comparisons. Verify clamping still works.
  - File: `Peach/PitchComparison/PitchComparisonSession.swift` L244-245
  - Action: Remove `Float()` casts in `calculateTargetAmplitude` — no longer needed since `AmplitudeDB` is `Double`. Change: `let range = varyLoudness * maxLoudnessOffsetDB.rawValue` and `let offset = Double.random(in: -range...range)`.

- [x] **Task 2: Create `PitchComparisonTrainingSettings`**
  - File: `Peach/Core/Training/PitchComparisonTrainingSettings.swift` (new file)
  - Action: Create struct with all pitch comparison tunable parameters:
    ```swift
    struct PitchComparisonTrainingSettings {
        var noteRange: NoteRange
        var referencePitch: Frequency
        var intervals: Set<DirectedInterval>
        var tuningSystem: TuningSystem
        var noteDuration: NoteDuration
        var varyLoudness: UnitInterval
        var minCentDifference: Cents
        var maxCentDifference: Cents
        var maxLoudnessOffsetDB: AmplitudeDB
        var velocity: MIDIVelocity
        var feedbackDuration: Duration

        init(
            noteRange: NoteRange = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84)),
            referencePitch: Frequency,
            intervals: Set<DirectedInterval>,
            tuningSystem: TuningSystem = .equalTemperament,
            noteDuration: NoteDuration = NoteDuration(0.75),
            varyLoudness: UnitInterval = UnitInterval(0.0),
            minCentDifference: Cents = Cents(0.1),
            maxCentDifference: Cents = Cents(100.0),
            maxLoudnessOffsetDB: AmplitudeDB = AmplitudeDB(10.0),
            velocity: MIDIVelocity = MIDIVelocity(63),
            feedbackDuration: Duration = .milliseconds(400)
        )
    }
    ```
  - Notes: File placement in `Core/Training/` per codebase convention (shared training domain type). `import Foundation` only. No SwiftUI. Default values match current behavior except `maxLoudnessOffsetDB` which changes from 5.0 to 10.0.

- [x] **Task 3: Create `PitchMatchingTrainingSettings`**
  - File: `Peach/Core/Training/PitchMatchingTrainingSettings.swift` (new file)
  - Action: Create struct with all pitch matching tunable parameters:
    ```swift
    struct PitchMatchingTrainingSettings {
        var noteRange: NoteRange
        var referencePitch: Frequency
        var intervals: Set<DirectedInterval>
        var tuningSystem: TuningSystem
        var noteDuration: NoteDuration
        var varyLoudness: UnitInterval
        var maxLoudnessOffsetDB: AmplitudeDB
        var initialCentOffsetRange: ClosedRange<Double>
        var velocity: MIDIVelocity
        var feedbackDuration: Duration

        init(
            noteRange: NoteRange = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84)),
            referencePitch: Frequency,
            intervals: Set<DirectedInterval>,
            tuningSystem: TuningSystem = .equalTemperament,
            noteDuration: NoteDuration = NoteDuration(0.75),
            varyLoudness: UnitInterval = UnitInterval(0.0),
            maxLoudnessOffsetDB: AmplitudeDB = AmplitudeDB(10.0),
            initialCentOffsetRange: ClosedRange<Double> = -20.0...20.0,
            velocity: MIDIVelocity = MIDIVelocity(63),
            feedbackDuration: Duration = .milliseconds(400)
        )
    }
    ```
  - Notes: `initialCentOffsetRange` replaces the static constant on `PitchMatchingSession`. `maxInitialCentOffset` computed property: `Cents(initialCentOffsetRange.upperBound)`.

- [x] **Task 4: Add `from(UserSettings)` factory methods**
  - File: `Peach/Core/Training/PitchComparisonTrainingSettings.swift`
  - Action: Add factory method:
    ```swift
    static func from(_ userSettings: UserSettings, intervals: Set<DirectedInterval>) -> PitchComparisonTrainingSettings {
        PitchComparisonTrainingSettings(
            noteRange: userSettings.noteRange,
            referencePitch: userSettings.referencePitch,
            intervals: intervals,
            tuningSystem: userSettings.tuningSystem,
            noteDuration: userSettings.noteDuration,
            varyLoudness: userSettings.varyLoudness
        )
    }
    ```
  - File: `Peach/Core/Training/PitchMatchingTrainingSettings.swift`
  - Action: Add equivalent factory method.
  - Notes: Factory methods only set user-configurable parameters; constants (`maxLoudnessOffsetDB`, `velocity`, `feedbackDuration`, `minCentDifference`, `maxCentDifference`, `initialCentOffsetRange`) keep their defaults.

- [x] **Task 5: Update `TrainingSession` protocol**
  - File: `Peach/Core/TrainingSession.swift`
  - Action: Remove `start(intervals:)` from the protocol. Keep `stop()` and `isIdle`. The protocol becomes:
    ```swift
    protocol TrainingSession: AnyObject {
        func stop()
        var isIdle: Bool { get }
    }
    ```
  - Notes: `PeachApp` only uses `activeSession` for `stop()` and `isIdle` tracking.

- [x] **Task 6: Update `NextPitchComparisonStrategy` and `KazezNoteStrategy`**
  - File: `Peach/Core/Algorithm/NextPitchComparisonStrategy.swift`
  - Action: Change `settings: TrainingSettings` → `settings: PitchComparisonTrainingSettings` in protocol method signature. **Delete the `TrainingSettings` struct** (L56-73) — it's replaced by the two new types. Update doc comments.
  - File: `Peach/Core/Algorithm/KazezNoteStrategy.swift`
  - Action: Change parameter type to `PitchComparisonTrainingSettings`. No logic changes needed — `settings.noteRange`, `settings.referencePitch`, `settings.minCentDifference`, `settings.maxCentDifference` all exist on the new type.
  - File: `PeachTests/Core/Algorithm/KazezNoteStrategyTests.swift`
  - Action: Replace all `TrainingSettings(...)` with `PitchComparisonTrainingSettings(...)`. Add required `intervals:` parameter.

- [x] **Task 7: Refactor `PitchComparisonSession`**
  - File: `Peach/PitchComparison/PitchComparisonSession.swift`
  - Action — Remove `UserSettings` dependency:
    - Remove `private let userSettings: UserSettings` (L38)
    - Remove `userSettings:` from `init()` parameter
    - Remove computed properties: `currentSettings` (L40-45), `currentNoteDuration` (L47-49), `currentVaryLoudness` (L51-53)
    - Remove constants: `maxLoudnessOffsetDB` (L55), `velocity` (L57), `feedbackDuration` (L59)
  - Action — Add stored settings:
    - Add `private var settings: PitchComparisonTrainingSettings?` to training state
  - Action — Change `start()` signature:
    - `func start(settings: PitchComparisonTrainingSettings)` — stores settings, replaces `sessionIntervals` and `sessionTuningSystem` with `settings.intervals` and `settings.tuningSystem`
    - Remove `sessionIntervals` and `sessionTuningSystem` stored properties — read from `settings!` instead
  - Action — Update `playNextPitchComparison()`:
    - Read `settings!.intervals.randomElement()!` instead of `sessionIntervals`
    - Read `settings!.noteDuration.rawValue` instead of `currentNoteDuration`
    - Pass `settings!` directly to strategy and to `playPitchComparisonNotes`
  - Action — Update `calculateTargetAmplitude`:
    - Read `settings!.varyLoudness.rawValue` and `settings!.maxLoudnessOffsetDB.rawValue` instead of properties
    - With `AmplitudeDB` now `Double`, simplify: `let range = varyLoudness * settings!.maxLoudnessOffsetDB.rawValue`
  - Action — Update `playPitchComparisonNotes`:
    - `velocity` → `settings!.velocity`
    - `settings.referencePitch` already passed via settings parameter
  - Action — Update `transitionToFeedback`:
    - `feedbackDuration` → `settings!.feedbackDuration`
  - Action — Update `stop()`:
    - Clear `settings = nil` instead of clearing `sessionIntervals` and `sessionTuningSystem`
    - `sessionTuningSystem` is `private(set)` and read by views — replace with computed property: `var sessionTuningSystem: TuningSystem { settings?.tuningSystem ?? .equalTemperament }`

- [x] **Task 8: Refactor `PitchMatchingSession`**
  - File: `Peach/PitchMatching/PitchMatchingSession.swift`
  - Action — Remove `UserSettings` dependency:
    - Remove `private let userSettings: UserSettings` (L32) and `userSettings:` from `init()`
    - Remove `currentSettings` (L205-210), `currentNoteDuration` (L212-214)
    - Remove `initialCentOffsetRange` (L56), `maxInitialCentOffset` (L57), `velocity` (L59), `feedbackDuration` (L60)
  - Action — Add stored settings:
    - `private var settings: PitchMatchingTrainingSettings?`
  - Action — Change `start()`:
    - `func start(settings: PitchMatchingTrainingSettings)` — stores settings
    - Remove `sessionIntervals` and `sessionTuningSystem` stored properties — read from `settings!`
    - `sessionTuningSystem` is `private(set)` — replace with computed: `var sessionTuningSystem: TuningSystem { settings?.tuningSystem ?? .equalTemperament }`
  - Action — Add `varyLoudness` support:
    - Add `calculateTargetAmplitude()` method (same logic as comparison session, reading from `settings!`)
    - In `playNextChallenge()`: calculate amplitude for reference note (always `AmplitudeDB(0.0)`) and tunable note (apply varyLoudness offset)
    - Pass calculated amplitude to `notePlayer.play()` calls
  - Action — Update `sliderFrequency(for:)`:
    - `Self.initialCentOffsetRange.upperBound` → `settings!.initialCentOffsetRange.upperBound`
    - `challenge.initialCentOffset.rawValue + value * settings!.initialCentOffsetRange.upperBound`
  - Action — Update `generateChallenge`:
    - Takes `settings: PitchMatchingTrainingSettings` instead of `settings: TrainingSettings`
    - `Self.initialCentOffsetRange` → `settings.initialCentOffsetRange`
  - Action — Update `stop()`:
    - Clear `settings = nil`
  - Action — Update `commitResult`:
    - `feedbackDuration` → `settings!.feedbackDuration`

- [x] **Task 9: Add `UserSettings` environment key and update screens**
  - File: `Peach/App/EnvironmentKeys.swift`
  - Action: Add `@Entry var userSettings: any UserSettings = PreviewUserSettings()` to the core environment keys section.
  - File: `Peach/App/PeachApp.swift`
  - Action: Wire `AppUserSettings()` into environment: `.environment(\.userSettings, userSettings)`. Store the `userSettings` instance as `@State`. Remove `userSettings:` from `createPitchComparisonSession` and `createPitchMatchingSession` helper methods.
  - File: `Peach/PitchComparison/PitchComparisonScreen.swift`
  - Action: Add `@Environment(\.userSettings) private var userSettings`. Change `pitchComparisonSession.start(intervals: intervals)` → `pitchComparisonSession.start(settings: .from(userSettings, intervals: intervals))` at both call sites (L154, L159).
  - File: `Peach/PitchMatching/PitchMatchingScreen.swift`
  - Action: Same pattern. Add `@Environment(\.userSettings)`. Change both `start(intervals:)` calls to `start(settings: .from(userSettings, intervals: intervals))`.

- [x] **Task 10: Update preview stubs in `EnvironmentKeys.swift`**
  - File: `Peach/App/EnvironmentKeys.swift`
  - Action: Update `PreviewPitchComparisonStrategy` to use `PitchComparisonTrainingSettings` instead of `TrainingSettings`. Remove `userSettings:` from preview session constructors. Remove `PreviewUserSettings` class if no longer needed (check: still needed for `@Entry var userSettings` default).

- [x] **Task 11: Move `previewDuration` to `SettingsScreen`**
  - File: `Peach/Settings/SettingsScreen.swift`
  - Action: Add `private static let previewDuration: TimeInterval = 2.0`. Use it when calling `soundPreviewPlay`.
  - File: `Peach/App/EnvironmentKeys.swift`
  - Action: Change `soundPreviewPlay` type from `(() async -> Void)?` to `((TimeInterval) async -> Void)?`.
  - File: `Peach/App/PeachApp.swift`
  - Action: Update `soundPreviewPlay` closure to accept `duration: TimeInterval` parameter. Replace `TrainingConstants.previewDuration` with the parameter. Replace `TrainingConstants.velocity` with `MIDIVelocity(63)` literal (or keep as-is until Task 12).

- [x] **Task 12: Remove `TrainingConstants`**
  - File: `Peach/Core/Training/TrainingConstants.swift`
  - Action: Delete file. All values have been distributed:
    - `feedbackDuration` → default parameter in both settings types
    - `velocity` → default parameter in both settings types
    - `previewDuration` → `SettingsScreen.previewDuration`
  - File: `Peach/App/PeachApp.swift`
  - Action: Replace any remaining `TrainingConstants.velocity` reference in `soundPreviewPlay` with `MIDIVelocity(63)`.

- [x] **Task 13: Update all tests**
  - File: `PeachTests/PitchComparison/*.swift` (10 files, ~1850 lines)
  - Action: In all factory methods that create `PitchComparisonSession`:
    - Remove `userSettings:` parameter from session init
    - Remove `MockUserSettings` creation
    - In test helper that calls `start()`, change to `start(settings: PitchComparisonTrainingSettings(referencePitch: Frequency(440.0), intervals: [.prime]))` (or with appropriate test values)
    - Where tests verified settings behavior (e.g., `PitchComparisonSessionSettingsTests`, `PitchComparisonSessionUserDefaultsTests`), update to pass settings directly to `start()` — these tests become simpler (no mock setup needed)
  - File: `PeachTests/PitchComparison/PitchComparisonSessionLoudnessTests.swift`
  - Action: Update to use `PitchComparisonTrainingSettings` with explicit `varyLoudness` and `maxLoudnessOffsetDB` values. Verify `maxLoudnessOffsetDB` default is now `AmplitudeDB(10.0)`.
  - File: `PeachTests/PitchMatching/PitchMatchingSessionTests.swift` (1170 lines)
  - Action: Same refactor pattern. Remove `MockUserSettings` from factory. Pass `PitchMatchingTrainingSettings` to `start()`. Add new tests for varyLoudness in matching session.
  - File: `PeachTests/Core/Algorithm/KazezNoteStrategyTests.swift` (477 lines)
  - Action: Replace `TrainingSettings(...)` with `PitchComparisonTrainingSettings(referencePitch: ..., intervals: ..., ...)`.
  - Notes: `MockUserSettings` should be kept for testing the `from()` factory methods on the settings types.

- [x] **Task 14: Create settings type tests**
  - File: `PeachTests/Core/Training/PitchComparisonTrainingSettingsTests.swift` (new file)
  - Action: Test default values, test `from(userSettings:intervals:)` factory maps correctly.
  - File: `PeachTests/Core/Training/PitchMatchingTrainingSettingsTests.swift` (new file)
  - Action: Same pattern.

- [x] **Task 15: Update `project-context.md`**
  - File: `docs/project-context.md`
  - Action: Update references to `TrainingSettings` → describe the two new types. Update `TrainingConstants` references (removed). Add `PitchComparisonTrainingSettings` and `PitchMatchingTrainingSettings` to the domain types list. Update session documentation to reflect that sessions receive settings via `start()` and don't depend on `UserSettings`. Update the "Settings read live" note — settings are now snapshot at start time.

### Acceptance Criteria

**AmplitudeDB:**
- [x] AC 1: Given `AmplitudeDB(5.0)`, when accessing `rawValue`, then it returns `Double(5.0)` (not `Float`).
- [x] AC 2: Given `AmplitudeDB(-100.0)`, when accessing `rawValue`, then it returns `-90.0` (clamped, as `Double`).
- [x] AC 3: Given `SoundFontNotePlayer` playing a note with `AmplitudeDB(3.0)`, when `startNote` executes, then `sampler.overallGain` receives `Float(3.0)`.

**PitchComparisonTrainingSettings:**
- [x] AC 4: Given default `PitchComparisonTrainingSettings(referencePitch: Frequency(440.0), intervals: [.prime])`, when checking defaults, then `maxLoudnessOffsetDB == AmplitudeDB(10.0)`, `velocity == MIDIVelocity(63)`, `feedbackDuration == .milliseconds(400)`, `minCentDifference == Cents(0.1)`, `maxCentDifference == Cents(100.0)`.
- [x] AC 5: Given a `MockUserSettings` with custom values, when calling `.from(userSettings, intervals: [.up(.perfectFifth)])`, then the settings reflect all user-configurable values and intervals.

**PitchMatchingTrainingSettings:**
- [x] AC 6: Given default `PitchMatchingTrainingSettings(referencePitch: Frequency(440.0), intervals: [.prime])`, when checking defaults, then `maxLoudnessOffsetDB == AmplitudeDB(10.0)`, `initialCentOffsetRange == -20.0...20.0`, `velocity == MIDIVelocity(63)`, `feedbackDuration == .milliseconds(400)`.
- [x] AC 7: Given a `MockUserSettings`, when calling `.from(userSettings, intervals:)`, then settings map correctly.

**PitchComparisonSession decoupling:**
- [x] AC 8: Given a `PitchComparisonSession` created without `userSettings:` parameter, when calling `start(settings: PitchComparisonTrainingSettings(...))`, then the session starts and uses the provided settings for note generation, loudness variation, and timing.
- [x] AC 9: Given a running `PitchComparisonSession`, when the session generates a comparison, then it reads `noteDuration`, `velocity`, `varyLoudness`, and `maxLoudnessOffsetDB` from the stored settings (not from any `UserSettings` instance).
- [x] AC 10: Given `PitchComparisonTrainingSettings` with `varyLoudness: UnitInterval(0.8)` and `maxLoudnessOffsetDB: AmplitudeDB(10.0)`, when generating a comparison, then the target note amplitude is randomized within `±8.0 dB`.

**PitchMatchingSession decoupling:**
- [x] AC 11: Given a `PitchMatchingSession` created without `userSettings:` parameter, when calling `start(settings: PitchMatchingTrainingSettings(...))`, then the session starts and uses provided settings.
- [x] AC 12: Given `PitchMatchingTrainingSettings` with custom `initialCentOffsetRange: -30.0...30.0`, when generating a challenge, then the initial offset is within `±30.0` cents.

**PitchMatchingSession varyLoudness:**
- [x] AC 13: Given `PitchMatchingTrainingSettings` with `varyLoudness: UnitInterval(0.0)`, when playing a challenge, then both reference and tunable notes play at `AmplitudeDB(0.0)`.
- [x] AC 14: Given `PitchMatchingTrainingSettings` with `varyLoudness: UnitInterval(1.0)` and `maxLoudnessOffsetDB: AmplitudeDB(10.0)`, when playing a challenge, then the reference note plays at `AmplitudeDB(0.0)` and the tunable note plays at a randomized amplitude within `±10.0 dB`.

**TrainingSession protocol:**
- [x] AC 15: Given the `TrainingSession` protocol, when inspecting its requirements, then it only declares `stop()` and `isIdle` (no `start` method).

**Preview duration:**
- [x] AC 16: Given the `SettingsScreen`, when triggering sound preview, then it passes `2.0` seconds to the `soundPreviewPlay` closure.

**Integration:**
- [x] AC 17: Given the full app, when navigating to pitch comparison training, then the screen builds settings from `UserSettings` via `.from()` and passes them to `start()`.
- [x] AC 18: Given the full app, when navigating to pitch matching training, then the screen builds settings from `UserSettings` via `.from()` and passes them to `start()`.
- [x] AC 19: Given the full test suite, when running all tests, then all tests pass.

## Additional Context

### Dependencies

None — pure refactoring with one behavioral addition (varyLoudness for matching).

### Testing Strategy

**Unit tests (update existing):**
- `AmplitudeDBTests` — verify `Double` rawValue and clamping
- `KazezNoteStrategyTests` — use `PitchComparisonTrainingSettings` instead of `TrainingSettings`
- All `PitchComparisonSession*Tests` (10 files) — remove `MockUserSettings`, pass settings to `start()`
- `PitchMatchingSessionTests` — same refactor, plus new varyLoudness tests

**Unit tests (new):**
- `PitchComparisonTrainingSettingsTests` — default values, `from()` factory
- `PitchMatchingTrainingSettingsTests` — default values, `from()` factory

**Manual testing:**
- Verify pitch comparison training starts and plays correctly
- Verify pitch matching training starts and plays correctly
- Verify vary loudness slider affects both training modes
- Verify sound preview in settings still works

### Notes

- **High-risk area**: `sliderFrequency(for:)` in `PitchMatchingSession` — uses `initialCentOffsetRange.upperBound` for frequency calculation. Must read from stored settings, not a static property. If settings are nil (session not started), guard against it.
- **`settings!` force unwraps**: Both sessions will force-unwrap `settings` in their training loops. This is safe because `start()` sets it before any loop code runs, and `stop()` clears it when the loop is done. The precondition is: training loop methods are only called when settings is non-nil. An alternative is to use `guard let settings else { return }` for defense.
- **`sessionTuningSystem` public access**: Both sessions expose `sessionTuningSystem` as `private(set)`. After refactoring, this becomes a computed property reading from optional settings. When idle (settings == nil), it returns `.equalTemperament` as the default.
- **`MockUserSettings` retention**: Keep for testing `from()` factory methods. No longer needed in session tests.
- **Future consideration**: If more training modes are added, each would get its own settings type following this same pattern.

## Review Notes
- Adversarial review completed
- Findings: 11 total, 1 fixed (F1: sound preview captured fresh AppUserSettings instead of injected instance), 10 skipped (intentional/noise/acceptable)
- Resolution approach: selective fix
- Additional change: `previewDuration` and `soundPreviewPlay` closure use `Duration` instead of `TimeInterval` per user request
