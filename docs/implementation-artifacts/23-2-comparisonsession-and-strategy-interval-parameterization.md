# Story 23.2: ComparisonSession Start Rename and Strategy Interval Support

Status: review

## Story

As a **developer building interval training**,
I want `ComparisonSession.startTraining()` renamed to `start()`, reading `intervals` and `tuningSystem` from `userSettings`, `NextComparisonStrategy` to compute interval-aware targets using `MIDINote.transposed(by:)`, and `currentInterval`/`isIntervalMode` observable state,
So that comparison training works with any musical interval while unison (`[.prime]`) behaves identically to current behavior (FR66).

## Acceptance Criteria

1. **UserSettings gains `intervals` and `tuningSystem` properties**
   - **Given** `UserSettings` protocol has no `intervals` or `tuningSystem` properties
   - **When** `intervals: Set<Interval>` and `tuningSystem: TuningSystem` are added to the protocol
   - **Then** `AppUserSettings` returns hardcoded `[.perfectFifth]` for `intervals` and `.equalTemperament` for `tuningSystem` (no UserDefaults backing yet)
   - **And** `MockUserSettings` exposes both as mutable stored properties for test injection

2. **`startTraining()` renamed to `start()`**
   - **Given** `ComparisonSession` has a `startTraining()` method
   - **When** it is renamed to `start()`
   - **Then** it reads `intervals` and `tuningSystem` from the injected `userSettings`
   - **And** the interval set must be non-empty (enforced by precondition)

3. **Unison backward compatibility (FR66)**
   - **Given** a training session with `intervals: [.prime]`
   - **When** comparisons are generated
   - **Then** behavior is identical to pre-interval implementation — `targetNote.note == referenceNote`

4. **Interval-aware comparison generation**
   - **Given** a training session with `intervals: [.perfectFifth]`
   - **When** a comparison is generated
   - **Then** the strategy picks a reference note, then `targetNote.note = referenceNote.transposed(by: .perfectFifth)`
   - **And** `targetNote` is a `DetunedMIDINote` with the training cent offset applied
   - **And** reference note selection constrains the upper bound by `interval.semitones` to keep `targetNote.note` within MIDI range (0-127)

5. **NextComparisonStrategy gains interval and tuningSystem parameters**
   - **Given** `NextComparisonStrategy` protocol
   - **When** it gains `interval: Interval` and `tuningSystem: TuningSystem` parameters (no defaults)
   - **Then** `KazezNoteStrategy` computes `targetNote.note` from the interval via `transposed(by:)`

6. **Frequency computation uses tuningSystem from session**
   - **Given** the frequency computation for playback
   - **When** the session needs to play the reference and target notes
   - **Then** reference frequency uses `tuningSystem.frequency(for: referenceNote, referencePitch:)`
   - **And** target frequency uses `tuningSystem.frequency(for: targetNote, referencePitch:)` where `targetNote` is the `DetunedMIDINote`

7. **Observable `currentInterval` and `isIntervalMode` properties**
   - **Given** `ComparisonSession` has `currentInterval` and `isIntervalMode` properties
   - **When** `currentInterval` is `.prime`
   - **Then** `isIntervalMode` returns `false`
   - **When** `currentInterval` is `.perfectFifth`
   - **Then** `isIntervalMode` returns `true`

8. **CompletedComparison tuningSystem from session (not hardcoded)**
   - **Given** `CompletedComparison` now carries `tuningSystem`
   - **When** `ComparisonObserver` (TrainingDataStore) receives it
   - **Then** `tuningSystem` is the session's tuning system (from `userSettings`), not hardcoded `.equalTemperament`

## Tasks / Subtasks

- [x] Task 1: Add `intervals` and `tuningSystem` to `UserSettings` protocol (AC: #1)
  - [x] Add `var intervals: Set<Interval> { get }` to protocol in `Peach/Settings/UserSettings.swift`
  - [x] Add `var tuningSystem: TuningSystem { get }` to protocol in `Peach/Settings/UserSettings.swift`
  - [x] In `AppUserSettings`, return hardcoded `Set<Interval>([.perfectFifth])` and `.equalTemperament`
  - [x] In `MockUserSettings`, add mutable stored properties with defaults `Set<Interval>([.prime])` and `.equalTemperament`
  - [x] Write tests verifying `AppUserSettings` returns expected hardcoded values
  - [x] Write tests verifying `MockUserSettings` allows test injection

- [x] Task 2: Add `interval` and `tuningSystem` parameters to `NextComparisonStrategy` (AC: #5)
  - [x] Update protocol signature: `nextComparison(profile:settings:lastComparison:interval:tuningSystem:) -> Comparison`
  - [x] Update `KazezNoteStrategy.nextComparison()` to accept `interval: Interval` and `tuningSystem: TuningSystem`
  - [x] When `interval == .prime`: behavior unchanged — `targetNote = DetunedMIDINote(note: referenceNote, offset: Cents(signed))`
  - [x] When `interval != .prime`: `targetNote = DetunedMIDINote(note: referenceNote.transposed(by: interval), offset: Cents(signed))`
  - [x] Constrain reference note upper bound: `noteRangeMax - interval.semitones` to prevent MIDI overflow on transposition
  - [x] Update `MockNextComparisonStrategy` to accept and track the new parameters
  - [x] Write tests for unison path (`.prime`), interval path (`.perfectFifth`), and MIDI range constraint

- [x] Task 3: Rename `startTraining()` to `start()` and read interval context from `userSettings` (AC: #2)
  - [x] Rename `func startTraining()` to `func start()` in `ComparisonSession.swift`
  - [x] At start of `start()`, read `userSettings.intervals` and `userSettings.tuningSystem`, store as session-level state
  - [x] Add precondition: `precondition(!userSettings.intervals.isEmpty, "intervals must not be empty")`
  - [x] Select a random interval from the set on each comparison (store as `currentInterval`)
  - [x] Pass selected interval and tuningSystem to `strategy.nextComparison()`
  - [x] Update `ComparisonScreen.swift` line 77: change `comparisonSession.startTraining()` to `comparisonSession.start()`
  - [x] Write tests verifying `start()` reads intervals from userSettings

- [x] Task 4: Add `currentInterval` and `isIntervalMode` observable state (AC: #7)
  - [x] Add `private(set) var currentInterval: Interval? = nil` observable property
  - [x] Add computed `var isIntervalMode: Bool { currentInterval != nil && currentInterval != .prime }`
  - [x] Set `currentInterval` when each comparison is generated (the randomly selected interval)
  - [x] Clear `currentInterval = nil` in `stop()` (alongside other state resets)
  - [x] Write tests for `currentInterval` and `isIntervalMode` with `.prime` vs `.perfectFifth`

- [x] Task 5: Replace hardcoded `.equalTemperament` with session tuningSystem (AC: #6, #8)
  - [x] Store `tuningSystem` as private session state (read from `userSettings` in `start()`)
  - [x] In `playComparisonNotes()` lines 233-234: use stored `tuningSystem` instead of `.equalTemperament`
  - [x] In `handleAnswer()` line 126: use stored `tuningSystem` instead of `.equalTemperament`
  - [x] Write tests verifying tuningSystem flows through to `CompletedComparison` and frequency computation

- [x] Task 6: Update all `startTraining()` call sites in tests (AC: #2)
  - [x] Rename all `f.session.startTraining()` / `session.startTraining()` to `f.session.start()` / `session.start()` across all test files
  - [x] Update test descriptions that reference `startTraining` (e.g., `@Test("startTraining transitions...")` → `@Test("start transitions...")`)
  - [x] Set `mockSettings.intervals = [.prime]` in test helpers for backward-compatible unison behavior
  - [x] Write new test: interval comparison with `.perfectFifth` verifies `targetNote.note == referenceNote.transposed(by: .perfectFifth)`

- [x] Task 7: Run full test suite and commit (AC: all)
  - [x] Run: `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [x] Run: `tools/check-dependencies.sh`
  - [x] All tests pass, no dependency violations

## Dev Notes

### Current State of Each Type (Read These Files First)

| Type | File | Current State |
|------|------|---------------|
| `UserSettings` | `Peach/Settings/UserSettings.swift` | Protocol with 6 properties: `noteRangeMin`, `noteRangeMax`, `noteDuration`, `referencePitch`, `soundSource`, `varyLoudness` — no `intervals` or `tuningSystem` |
| `AppUserSettings` | `Peach/Settings/AppUserSettings.swift` | Computed properties reading from `UserDefaults.standard` with `SettingsKeys` defaults |
| `MockUserSettings` | `PeachTests/Mocks/MockUserSettings.swift` | Mutable stored properties with `SettingsKeys` defaults |
| `ComparisonSession` | `Peach/Comparison/ComparisonSession.swift` | `@Observable final class`, state machine, `startTraining()` at line 100, hardcoded `.equalTemperament` at lines 126, 233, 234 |
| `NextComparisonStrategy` | `Peach/Core/Algorithm/NextComparisonStrategy.swift` | Protocol with `nextComparison(profile:settings:lastComparison:)` — no interval/tuningSystem params |
| `KazezNoteStrategy` | `Peach/Core/Algorithm/KazezNoteStrategy.swift` | `targetNote = DetunedMIDINote(note: referenceNote, offset:)` — always same note as reference (unison) |
| `MockNextComparisonStrategy` | `PeachTests/Comparison/MockNextComparisonStrategy.swift` | Cycles through pre-loaded comparisons array, tracks call params |
| `ComparisonScreen` | `Peach/Comparison/ComparisonScreen.swift` | Calls `comparisonSession.startTraining()` at line 77 |
| `TrainingSession` | `Peach/Core/TrainingSession.swift` | Protocol: `stop()`, `isIdle` — does NOT have `start()` (that's Story 23.3) |

### Hardcoded `.equalTemperament` Locations to Fix

Three places in `ComparisonSession.swift` currently hardcode `.equalTemperament`:

1. **Line 126** (`handleAnswer`): `CompletedComparison(comparison: comparison, userAnsweredHigher: isHigher, tuningSystem: .equalTemperament)`
2. **Line 233** (`playComparisonNotes`): `comparison.referenceFrequency(tuningSystem: .equalTemperament, referencePitch: settings.referencePitch)`
3. **Line 234** (`playComparisonNotes`): `comparison.targetFrequency(tuningSystem: .equalTemperament, referencePitch: settings.referencePitch)`

All three must use the session-level `tuningSystem` read from `userSettings.tuningSystem` during `start()`.

### How Interval Selection Works

`ComparisonSession.start()` reads `userSettings.intervals` (a `Set<Interval>`). On each new comparison:
1. Pick a random interval from the set: `let interval = intervals.randomElement()!` (set is guaranteed non-empty by precondition)
2. Store as `currentInterval` (observable, for UI in Story 23.4)
3. Pass to `strategy.nextComparison(..., interval: interval, tuningSystem: tuningSystem)`

The strategy is responsible for using the interval to compute the target note.

### KazezNoteStrategy Change (Critical)

**Current behavior** (unison only):
```swift
let note = MIDINote.random(in: settings.noteRangeMin...settings.noteRangeMax)
return Comparison(
    referenceNote: note,
    targetNote: DetunedMIDINote(note: note, offset: Cents(signed))
)
```

**New behavior** (interval-aware):
```swift
// Constrain upper bound to prevent MIDI overflow after transposition
let maxNote = min(settings.noteRangeMax, MIDINote(127 - interval.semitones))
let note = MIDINote.random(in: settings.noteRangeMin...maxNote)
let targetBaseNote = note.transposed(by: interval)
return Comparison(
    referenceNote: note,
    targetNote: DetunedMIDINote(note: targetBaseNote, offset: Cents(signed))
)
```

When `interval == .prime`, `transposed(by: .prime)` returns the same note (semitones = 0), so **unison behavior is identical** — the target note is the reference note with a cent offset applied. This satisfies FR66.

When `interval == .perfectFifth` (7 semitones), the target base note is 7 semitones above the reference. The cent offset is the training difficulty applied to this transposed note.

### MIDI Range Constraint (Critical)

`MIDINote.transposed(by:)` has a precondition: result must be in 0-127. The strategy must prevent selecting a reference note that would cause overflow:

- If `interval == .perfectFifth` (7 semitones) and `noteRangeMax == 84` (C6): `maxNote = min(84, 127-7) = min(84, 120) = 84` — no change needed
- If `noteRangeMax == 124` and `interval == .perfectFifth`: `maxNote = min(124, 120) = 120` — constrained!

Use `min(settings.noteRangeMax.rawValue, 127 - interval.semitones)` then wrap in `MIDINote()`.

Also ensure `maxNote >= settings.noteRangeMin` — if the range is too narrow for the interval, the precondition in `MIDINote.random(in:)` will catch it. This is an edge case that doesn't need special handling beyond the existing precondition.

### Session State Storage Pattern

`ComparisonSession` needs to store interval context during an active session:

```swift
// MARK: - Training State
private var currentComparison: Comparison?
private var lastCompletedComparison: CompletedComparison?
private var trainingTask: Task<Void, Never>?
private var feedbackTask: Task<Void, Never>?
// Add:
private var sessionIntervals: Set<Interval> = []   // Read from userSettings in start()
private var sessionTuningSystem: TuningSystem = .equalTemperament  // Read from userSettings in start()
```

Observable state for UI:
```swift
// MARK: - Observable State
private(set) var state: ComparisonSessionState = .idle
private(set) var showFeedback: Bool = false
private(set) var isLastAnswerCorrect: Bool? = nil
private(set) var sessionBestCentDifference: Double? = nil
// Add:
private(set) var currentInterval: Interval? = nil
```

Clear in `stop()`:
```swift
currentInterval = nil
sessionIntervals = []
```

### MockNextComparisonStrategy Update

The mock must accept the new parameters:
```swift
func nextComparison(
    profile: PitchDiscriminationProfile,
    settings: TrainingSettings,
    lastComparison: CompletedComparison?,
    interval: Interval,
    tuningSystem: TuningSystem
) -> Comparison
```

Add tracking properties: `var lastReceivedInterval: Interval?` and `var lastReceivedTuningSystem: TuningSystem?`.

The mock's pre-loaded comparisons array already provides complete `Comparison` objects, so the interval/tuningSystem parameters only need to be recorded for test verification.

### MockUserSettings Defaults for Tests

Set `MockUserSettings` defaults to `intervals: Set<Interval>([.prime])` and `tuningSystem: .equalTemperament`. This ensures **all existing tests continue to work unchanged** with unison behavior — no need to update every test fixture.

The test helper `makeComparisonSession()` already accepts a `MockUserSettings`, so tests that want intervals just set `mockSettings.intervals = [.perfectFifth]` before calling `start()`.

### `AppUserSettings` Hardcoded Values

Per the AC, `AppUserSettings` returns hardcoded values (no `@AppStorage` / UserDefaults yet — that's a future epic):
- `intervals`: `Set<Interval>([.perfectFifth])` — the app will train perfect fifths by default
- `tuningSystem`: `.equalTemperament`

No new `SettingsKeys` constants needed since these aren't UserDefaults-backed.

### Call Sites for `startTraining()` (Must Rename to `start()`)

**Production code (1 site):**
- `ComparisonScreen.swift` line 77: `comparisonSession.startTraining()` → `comparisonSession.start()`

**Test files (all must rename `startTraining()` → `start()`):**
- `ComparisonSessionTests.swift` — ~10 calls
- `ComparisonSessionLifecycleTests.swift` — ~13 calls
- `ComparisonSessionSettingsTests.swift` — ~4 calls
- `ComparisonSessionIntegrationTests.swift` — ~11 calls
- `ComparisonSessionFeedbackTests.swift` — ~6 calls
- `ComparisonSessionUserDefaultsTests.swift` — ~4 calls
- `ComparisonSessionResetTests.swift` — ~1 call
- `ComparisonSessionDifficultyTests.swift` — ~7 calls
- `ComparisonSessionAudioInterruptionTests.swift` — ~11 calls
- `ComparisonSessionLoudnessTests.swift` — ~6 calls
- `ComparisonScreenFeedbackTests.swift` — ~5 calls
- `TrainingSessionTests.swift` — ~2 calls

Total: ~80 call sites. Use find-and-replace.

### `TrainingSession` Protocol — Do NOT Modify Yet

`TrainingSession` protocol (in `Peach/Core/TrainingSession.swift`) currently has `stop()` and `isIdle`. Adding `start()` is **Story 23.3's scope** (after `PitchMatchingSession` is also renamed). Do not add `start()` to the protocol in this story.

### Frequency Computation — No Changes to `Comparison` Methods

`Comparison.referenceFrequency(tuningSystem:referencePitch:)` and `.targetFrequency(tuningSystem:referencePitch:)` already accept explicit `tuningSystem` parameters (added in Story 23.1). The only change is that `ComparisonSession` now passes `sessionTuningSystem` instead of `.equalTemperament`.

### Testing Strategy

1. **TDD workflow**: Write failing tests first for each new behavior
2. **Unison backward compatibility**: Existing tests with `MockUserSettings` defaults (`intervals: [.prime]`) must pass unchanged
3. **New interval tests**:
   - Verify `nextComparison()` with `.perfectFifth` produces `targetNote.note == referenceNote + 7`
   - Verify MIDI range constraint prevents overflow
   - Verify `currentInterval` and `isIntervalMode` reflect the selected interval
   - Verify `CompletedComparison.tuningSystem` uses session tuningSystem (not hardcoded)
4. **Run full suite**: `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
5. **Run dependency check**: `tools/check-dependencies.sh`

### Project Structure Notes

All changes stay within established directories:
- `Peach/Settings/UserSettings.swift` — protocol update
- `Peach/Settings/AppUserSettings.swift` — hardcoded new properties
- `Peach/Core/Algorithm/NextComparisonStrategy.swift` — protocol signature update
- `Peach/Core/Algorithm/KazezNoteStrategy.swift` — interval-aware target computation
- `Peach/Comparison/ComparisonSession.swift` — rename, interval context, observable state
- `Peach/Comparison/ComparisonScreen.swift` — `start()` call update
- `PeachTests/Mocks/MockUserSettings.swift` — new mutable properties
- `PeachTests/Comparison/MockNextComparisonStrategy.swift` — new parameters
- `PeachTests/Comparison/ComparisonTestHelpers.swift` — potentially update defaults
- Test files: rename `startTraining()` → `start()` across all Comparison test files

No new files. No new directories. No cross-feature coupling.

### References

- [Source: docs/planning-artifacts/epics.md#Story 23.2] — Full acceptance criteria
- [Source: docs/planning-artifacts/epics.md#Epic 23] — Epic context and all stories overview
- [Source: docs/project-context.md#SwiftData] — TrainingDataStore patterns
- [Source: docs/project-context.md#Testing Rules] — Swift Testing, TDD workflow
- [Source: docs/project-context.md#Critical Don't-Miss Rules] — MIDI range, TuningSystem bridge
- [Source: docs/implementation-artifacts/23-1-data-model-and-value-type-updates-for-interval-context.md] — Previous story learnings and file list
- [Source: Peach/Comparison/ComparisonSession.swift] — Current implementation with hardcoded `.equalTemperament`
- [Source: Peach/Core/Algorithm/KazezNoteStrategy.swift] — Current unison-only strategy
- [Source: Peach/Core/Audio/Interval.swift] — `Interval` enum, `MIDINote.transposed(by:)`
- [Source: Peach/Settings/UserSettings.swift] — Current protocol (6 properties, no intervals/tuningSystem)
- [Source: Peach/App/PeachApp.swift] — Composition root, no changes needed

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None — clean implementation, no debugging required.

### Completion Notes List

- Added `intervals: Set<Interval>` and `tuningSystem: TuningSystem` to `UserSettings` protocol with hardcoded values in `AppUserSettings` and mutable defaults in `MockUserSettings`
- Updated `NextComparisonStrategy` protocol with `interval` and `tuningSystem` parameters; `KazezNoteStrategy` now computes interval-aware target notes via `MIDINote.transposed(by:)` with MIDI range constraint
- Renamed `startTraining()` to `start()` across production and ~80 test call sites; `start()` now reads `intervals` and `tuningSystem` from `userSettings` with non-empty precondition
- Added `currentInterval` (observable) and `isIntervalMode` (computed) properties to `ComparisonSession`; cleared on `stop()`
- Replaced all 3 hardcoded `.equalTemperament` references in `ComparisonSession` with session-level `sessionTuningSystem`
- Updated `PreviewComparisonStrategy` and `PreviewUserSettings` in `EnvironmentKeys.swift` for protocol conformance
- All existing tests pass unchanged (unison backward compatibility via `MockUserSettings` defaults `[.prime]`)
- Added 15 new tests: 4 for UserSettings, 4 for KazezNoteStrategy interval/MIDI range, 11 for ComparisonSession interval context
- Full test suite passes, no dependency violations

### Change Log

- 2026-03-01: Implemented story 23.2 — ComparisonSession interval parameterization with start() rename, strategy interval support, observable interval state, and session tuningSystem

### File List

- Peach/Settings/UserSettings.swift (modified — added `intervals` and `tuningSystem` properties)
- Peach/Settings/AppUserSettings.swift (modified — hardcoded interval/tuningSystem getters)
- Peach/Core/Algorithm/NextComparisonStrategy.swift (modified — added `interval` and `tuningSystem` parameters)
- Peach/Core/Algorithm/KazezNoteStrategy.swift (modified — interval-aware target computation with MIDI range constraint)
- Peach/Comparison/ComparisonSession.swift (modified — `start()` rename, interval context, observable state, session tuningSystem)
- Peach/Comparison/ComparisonScreen.swift (modified — `start()` call)
- Peach/App/EnvironmentKeys.swift (modified — `PreviewUserSettings` and `PreviewComparisonStrategy` protocol conformance)
- PeachTests/Mocks/MockUserSettings.swift (modified — mutable `intervals` and `tuningSystem`)
- PeachTests/Comparison/MockNextComparisonStrategy.swift (modified — new parameters and tracking)
- PeachTests/Comparison/ComparisonTestHelpers.swift (unchanged — no modifications needed)
- PeachTests/Settings/SettingsTests.swift (modified — 4 new tests for UserSettings)
- PeachTests/Core/Algorithm/KazezNoteStrategyTests.swift (modified — updated all calls, 4 new interval tests)
- PeachTests/Comparison/ComparisonSessionTests.swift (modified — renamed test, 11 new interval context tests)
- PeachTests/Comparison/ComparisonSessionIntegrationTests.swift (modified — updated nextComparison call)
- PeachTests/Comparison/ComparisonSessionResetTests.swift (modified — updated nextComparison calls and start() rename)
- PeachTests/Comparison/ComparisonSessionLifecycleTests.swift (modified — start() rename)
- PeachTests/Comparison/ComparisonSessionSettingsTests.swift (modified — start() rename)
- PeachTests/Comparison/ComparisonSessionFeedbackTests.swift (modified — start() rename)
- PeachTests/Comparison/ComparisonSessionDifficultyTests.swift (modified — start() rename)
- PeachTests/Comparison/ComparisonSessionLoudnessTests.swift (modified — start() rename)
- PeachTests/Comparison/ComparisonSessionAudioInterruptionTests.swift (modified — start() rename)
- PeachTests/Comparison/ComparisonSessionUserDefaultsTests.swift (modified — start() rename)
- PeachTests/Comparison/ComparisonScreenFeedbackTests.swift (modified — start() rename)
- PeachTests/Core/TrainingSessionTests.swift (modified — start() rename)
