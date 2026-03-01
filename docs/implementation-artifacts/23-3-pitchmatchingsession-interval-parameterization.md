# Story 23.3: PitchMatchingSession Start Rename, Interval Support, and Protocol Update

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer building interval training**,
I want `PitchMatchingSession.startPitchMatching()` renamed to `start()`, reading `intervals` and `tuningSystem` from `userSettings`, interval-aware challenge generation using `MIDINote.transposed(by:)`, `currentInterval`/`isIntervalMode` observable state, and `start()` pulled up into the `TrainingSession` protocol,
So that pitch matching training works with any musical interval while unison (`[.prime]`) behaves identically to current behavior (FR66), and both session types share a common start interface.

## Acceptance Criteria

1. **`startPitchMatching()` renamed to `start()` with interval context**
   - **Given** `PitchMatchingSession` has a `startPitchMatching()` method
   - **When** it is renamed to `start()`
   - **Then** it reads `intervals` and `tuningSystem` from the injected `userSettings`
   - **And** the interval set must be non-empty (enforced by precondition)

2. **Unison backward compatibility (FR66)**
   - **Given** a pitch matching session with `intervals: [.prime]`
   - **When** a challenge is generated
   - **Then** `targetNote == referenceNote` — identical to pre-interval behavior

3. **Interval-aware challenge generation**
   - **Given** a pitch matching session with `intervals: [.perfectFifth]`
   - **When** a challenge is generated
   - **Then** `targetNote = referenceNote.transposed(by: .perfectFifth)`
   - **And** `initialCentOffset` is applied relative to the target note
   - **And** reference note selection constrains the upper bound by `interval.semitones`

4. **Reference note frequency for playback uses session tuningSystem**
   - **Given** the reference note frequency for playback
   - **When** the session computes it
   - **Then** it uses `sessionTuningSystem.frequency(for: referenceNote, referencePitch:)`

5. **Tunable note starts at detuned target note**
   - **Given** the detuned starting frequency for the tunable note
   - **When** the session computes it
   - **Then** it uses `sessionTuningSystem.frequency(for: DetunedMIDINote(note: targetNote, offset: Cents(initialCentOffset)), referencePitch:)`

6. **`userCentError` measures deviation from correct target frequency**
   - **Given** `userCentError` represents deviation from the correct interval pitch
   - **When** the session computes it
   - **Then** it measures cents between user's final frequency and the correct target frequency (FR64)
   - **And** the slider anchor (`referenceFrequency`) is set to the target note's frequency

7. **`CompletedPitchMatching` carries session tuningSystem**
   - **Given** `CompletedPitchMatching` carries `tuningSystem`
   - **When** `PitchMatchingObserver` (TrainingDataStore) receives it
   - **Then** `tuningSystem` is the session's tuning system (from `userSettings`), not hardcoded `.equalTemperament`

8. **Observable `currentInterval` and `isIntervalMode` properties**
   - **Given** `PitchMatchingSession` has `currentInterval` and `isIntervalMode` properties
   - **When** `currentInterval` is `.prime`
   - **Then** `isIntervalMode` returns `false`
   - **When** `currentInterval` is `.perfectFifth`
   - **Then** `isIntervalMode` returns `true`

9. **`TrainingSession` protocol gains `start()`**
   - **Given** `TrainingSession` protocol currently requires `stop()` and `isIdle`
   - **When** `start()` is added to the protocol
   - **Then** both `ComparisonSession` and `PitchMatchingSession` satisfy the requirement through their renamed `start()` methods
   - **And** any holder of a `TrainingSession` reference can call `start()` without knowing the concrete type

## Tasks / Subtasks

- [ ] Task 1: Add session-level interval state and observable properties (AC: #8)
  - [ ] Add `private var sessionIntervals: Set<Interval> = []` to internal state
  - [ ] Add `private var sessionTuningSystem: TuningSystem = .equalTemperament` to internal state
  - [ ] Add `private(set) var currentInterval: Interval? = nil` observable property
  - [ ] Add computed `var isIntervalMode: Bool { currentInterval != nil && currentInterval != .prime }`
  - [ ] Clear all interval state in `stop()`: `currentInterval = nil`, `sessionIntervals = []`, `sessionTuningSystem = .equalTemperament`
  - [ ] Write tests for `currentInterval` and `isIntervalMode` with `.prime` vs `.perfectFifth`

- [ ] Task 2: Rename `startPitchMatching()` to `start()` and read interval context (AC: #1)
  - [ ] Rename `func startPitchMatching()` to `func start()` in `PitchMatchingSession.swift`
  - [ ] Update logger warning message from `"startPitchMatching() called..."` to `"start() called..."`
  - [ ] At start of `start()`, read `userSettings.intervals` and `userSettings.tuningSystem`, store as session-level state
  - [ ] Add precondition: `precondition(!userSettings.intervals.isEmpty, "intervals must not be empty")`
  - [ ] Select a random interval from the set on each challenge: `let interval = sessionIntervals.randomElement()!`
  - [ ] Store as `currentInterval` (observable, for UI in Story 23.4)
  - [ ] Pass selected interval to `generateChallenge(settings:interval:)`
  - [ ] Update `PitchMatchingScreen.swift` line 51: change `.startPitchMatching()` to `.start()`
  - [ ] Write tests verifying `start()` reads intervals from userSettings

- [ ] Task 3: Update `generateChallenge()` for interval-aware challenge generation (AC: #2, #3)
  - [ ] Add `interval: Interval` parameter to `generateChallenge(settings:interval:)`
  - [ ] Constrain reference note upper bound: `let maxNote = MIDINote(min(settings.noteRangeMax.rawValue, 127 - interval.semitones))`
  - [ ] Compute target note: `let targetNote = note.transposed(by: interval)`
  - [ ] Return `PitchMatchingChallenge(referenceNote: note, targetNote: targetNote, initialCentOffset: offset)`
  - [ ] When `interval == .prime`: `transposed(by: .prime)` returns same note — behavior identical to current
  - [ ] Write tests for unison path (`.prime`), interval path (`.perfectFifth`), and MIDI range constraint

- [ ] Task 4: Replace hardcoded `.equalTemperament` with session tuningSystem and fix target note anchor (AC: #4, #5, #6, #7)
  - [ ] In `playNextChallenge()` line 187: `TuningSystem.equalTemperament.frequency(for: challenge.referenceNote, ...)` → `sessionTuningSystem.frequency(for: challenge.referenceNote, ...)`
  - [ ] Store TARGET note frequency (not reference note frequency) as `referenceFrequency` anchor:
    - Compute: `let targetFreq = sessionTuningSystem.frequency(for: challenge.targetNote, referencePitch: settings.referencePitch)`
    - Store: `self.referenceFrequency = targetFreq.rawValue`
    - For unison: targetNote == referenceNote, so value unchanged
  - [ ] In `playNextChallenge()` line 201-202: use `challenge.targetNote` instead of `challenge.referenceNote` for the detuned tunable note:
    - `sessionTuningSystem.frequency(for: DetunedMIDINote(note: challenge.targetNote, offset: Cents(challenge.initialCentOffset)), referencePitch: settings.referencePitch)`
  - [ ] In `commitResult()` line 118: `tuningSystem: .equalTemperament` → `tuningSystem: sessionTuningSystem`
  - [ ] `userCentError` formula `1200.0 * log2(userFrequency / referenceFrequency)` now correctly measures error relative to target frequency because `referenceFrequency` stores the target note frequency
  - [ ] Write tests verifying tuningSystem flows through to `CompletedPitchMatching` and frequency computation

- [ ] Task 5: Add `start()` to `TrainingSession` protocol (AC: #9)
  - [ ] Add `func start()` to `TrainingSession` protocol in `Peach/Core/TrainingSession.swift`
  - [ ] Both `ComparisonSession.start()` and `PitchMatchingSession.start()` already satisfy this
  - [ ] Write test: call `start()` through `TrainingSession` protocol reference for both session types
  - [ ] Write test: call `start()` + verify session is not idle, then `stop()` through protocol

- [ ] Task 6: Rename all `startPitchMatching()` call sites in tests (AC: #1)
  - [ ] `PitchMatchingSessionTests.swift` — 44 occurrences of `startPitchMatching` → `start`
  - [ ] `TrainingSessionTests.swift` — 2 occurrences: lines 35, 56 → `session.start()`
  - [ ] Update test descriptions that reference `startPitchMatching` (e.g., `@Test("startPitchMatching transitions...")` → `@Test("start transitions...")`)
  - [ ] Set `mockSettings.intervals = [.prime]` in test helper default (already set from Story 23.2)

- [ ] Task 7: Run full test suite and commit (AC: all)
  - [ ] Run: `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [ ] Run: `tools/check-dependencies.sh`
  - [ ] All tests pass, no dependency violations

## Dev Notes

### Current State of Each Type (Read These Files First)

| Type | File | Current State |
|------|------|---------------|
| `PitchMatchingSession` | `Peach/PitchMatching/PitchMatchingSession.swift` | `@Observable final class`, state machine, `startPitchMatching()` at line 74, hardcoded `.equalTemperament` at lines 118, 187, 201 |
| `PitchMatchingScreen` | `Peach/PitchMatching/PitchMatchingScreen.swift` | Calls `pitchMatchingSession.startPitchMatching()` at line 51 |
| `TrainingSession` | `Peach/Core/TrainingSession.swift` | Protocol with `stop()` and `isIdle` — does NOT have `start()` yet |
| `PitchMatchingChallenge` | `Peach/PitchMatching/PitchMatchingChallenge.swift` | Struct: `referenceNote: MIDINote`, `targetNote: MIDINote`, `initialCentOffset: Double` — already has `targetNote` (set equal to `referenceNote` for unison) |
| `CompletedPitchMatching` | `Peach/Core/Training/CompletedPitchMatching.swift` | Struct: `referenceNote`, `targetNote`, `initialCentOffset`, `userCentError`, `tuningSystem`, `timestamp` — already has `targetNote` and `tuningSystem` (from Story 23.1) |
| `UserSettings` | `Peach/Settings/UserSettings.swift` | Protocol with 8 properties including `intervals: Set<Interval>` and `tuningSystem: TuningSystem` (added in Story 23.2) |
| `MockUserSettings` | `PeachTests/Mocks/MockUserSettings.swift` | Mutable stored properties, defaults to `intervals: [.prime]`, `tuningSystem: .equalTemperament` (from Story 23.2) |
| `ComparisonSession` | `Peach/Comparison/ComparisonSession.swift` | Already has `start()` (renamed in Story 23.2), `currentInterval`, `isIntervalMode`, `sessionIntervals`, `sessionTuningSystem` |
| `EnvironmentKeys` | `Peach/App/EnvironmentKeys.swift` | Has `PreviewUserSettings` with `intervals: [.perfectFifth]` and `tuningSystem: .equalTemperament` (from Story 23.2) |

### Hardcoded `.equalTemperament` Locations to Fix

Three places in `PitchMatchingSession.swift` currently hardcode `.equalTemperament`:

1. **Line 118** (`commitResult`): `CompletedPitchMatching(..., tuningSystem: .equalTemperament)`
2. **Line 187** (`playNextChallenge`): `TuningSystem.equalTemperament.frequency(for: challenge.referenceNote, referencePitch: ...)`
3. **Line 201** (`playNextChallenge`): `TuningSystem.equalTemperament.frequency(for: DetunedMIDINote(note: challenge.referenceNote, ...), referencePitch: ...)`

All three must use the session-level `sessionTuningSystem` read from `userSettings.tuningSystem` during `start()`.

### Critical: `referenceFrequency` Anchor Change for Intervals

The stored `referenceFrequency` property serves as the slider anchor — the frequency the user is trying to match. `adjustPitch` and `commitPitch` compute frequencies relative to this anchor.

**Current behavior (unison):**
```swift
let refFreq = TuningSystem.equalTemperament.frequency(for: challenge.referenceNote, ...)
self.referenceFrequency = refFreq.rawValue  // anchor = reference note frequency
```
User tries to tune to reference note → slider center = reference frequency. Correct for unison.

**New behavior (intervals):**
```swift
let refFreq = sessionTuningSystem.frequency(for: challenge.referenceNote, ...)
// Reference note frequency is for playback only — NOT the anchor
let targetFreq = sessionTuningSystem.frequency(for: challenge.targetNote, ...)
self.referenceFrequency = targetFreq.rawValue  // anchor = target note frequency
```
User tries to tune to target note → slider center = target frequency. For unison: `targetNote == referenceNote`, so `targetFreq == refFreq` — behavior identical.

This single change ensures:
- `adjustPitch(0.0)` → target note frequency (slider center = correct answer)
- `commitPitch(0.0)` → 0 cent error relative to target note
- `userCentError = 1200 * log2(userFreq / referenceFrequency)` correctly measures error against target
- **No changes needed to `adjustPitch`, `commitPitch`, or `commitResult` formulas**

### Tunable Note Frequency Change

**Current (line 201-202):**
```swift
let tunableFrequency = TuningSystem.equalTemperament.frequency(
    for: DetunedMIDINote(note: challenge.referenceNote, offset: Cents(challenge.initialCentOffset)),
    referencePitch: settings.referencePitch)
```

**New:**
```swift
let tunableFrequency = sessionTuningSystem.frequency(
    for: DetunedMIDINote(note: challenge.targetNote, offset: Cents(challenge.initialCentOffset)),
    referencePitch: settings.referencePitch)
```

Uses `challenge.targetNote` instead of `challenge.referenceNote`. For unison: identical (same note). For intervals: the tunable note starts detuned from the target note (e.g., perfect fifth + random offset), which is what the user hears and must tune back to the exact target.

### How Interval Selection Works (Same Pattern as ComparisonSession)

`PitchMatchingSession.start()` reads `userSettings.intervals` (a `Set<Interval>`). On each new challenge:
1. Pick a random interval from the set: `let interval = sessionIntervals.randomElement()!` (set guaranteed non-empty by precondition)
2. Store as `currentInterval` (observable, for UI in Story 23.4)
3. Pass to `generateChallenge(settings: settings, interval: interval)`

### MIDI Range Constraint (Same Pattern as KazezNoteStrategy)

`MIDINote.transposed(by:)` has a precondition: result must be in 0-127. The challenge generator must prevent selecting a reference note that would cause overflow:

```swift
let maxNote = MIDINote(min(settings.noteRangeMax.rawValue, 127 - interval.semitones))
let note = MIDINote.random(in: settings.noteRangeMin...maxNote)
let targetNote = note.transposed(by: interval)
```

Also ensure `maxNote >= settings.noteRangeMin` — if the range is too narrow for the interval, the `MIDINote.random(in:)` precondition will catch it. No special handling needed.

### Session State Storage Pattern (Mirror ComparisonSession)

`PitchMatchingSession` needs to store interval context during an active session:

```swift
// MARK: - Internal State (add to existing)
private var sessionIntervals: Set<Interval> = []
private var sessionTuningSystem: TuningSystem = .equalTemperament
```

Observable state for UI:
```swift
// MARK: - Observable State (add to existing)
private(set) var currentInterval: Interval? = nil
```

Computed:
```swift
var isIntervalMode: Bool { currentInterval != nil && currentInterval != .prime }
```

Clear in `stop()`:
```swift
currentInterval = nil
sessionIntervals = []
sessionTuningSystem = .equalTemperament
```

### `TrainingSession` Protocol Update

**Current:**
```swift
protocol TrainingSession: AnyObject {
    func stop()
    var isIdle: Bool { get }
}
```

**New:**
```swift
protocol TrainingSession: AnyObject {
    func start()
    func stop()
    var isIdle: Bool { get }
}
```

Both `ComparisonSession.start()` (Story 23.2) and `PitchMatchingSession.start()` (this story) already satisfy this. `PeachApp.swift` uses `activeSession?.stop()` — no `start()` calls through the protocol yet, but the shared interface enables future generic handling.

### Call Sites for `startPitchMatching()` (Must Rename to `start()`)

**Production code (1 site):**
- `PitchMatchingScreen.swift` line 51: `pitchMatchingSession.startPitchMatching()` → `pitchMatchingSession.start()`

**Test files (all must rename `startPitchMatching()` → `start()`):**
- `PitchMatchingSessionTests.swift` — 44 occurrences
- `TrainingSessionTests.swift` — 2 occurrences

Total: ~49 occurrences across production + tests. Use find-and-replace.

### Existing Test Backward Compatibility

`MockUserSettings` already defaults to `intervals: [.prime]` and `tuningSystem: .equalTemperament` (set in Story 23.2). This ensures **all existing tests continue to work unchanged** with unison behavior — the only code change in tests is the method rename.

### Testing Strategy

1. **TDD workflow**: Write failing tests first for each new behavior
2. **Unison backward compatibility**: Existing tests with `MockUserSettings` defaults (`intervals: [.prime]`) must pass unchanged after rename
3. **New interval tests**:
   - Verify `start()` reads intervals from userSettings and stores session state
   - Verify `generateChallenge()` with `.perfectFifth` produces `targetNote == referenceNote + 7 semitones`
   - Verify MIDI range constraint prevents overflow on transposition
   - Verify `currentInterval` and `isIntervalMode` reflect the selected interval
   - Verify slider anchor (`referenceFrequency`) is set to target note frequency for intervals
   - Verify `userCentError` at slider center (value 0.0) is 0 for intervals (error relative to target)
   - Verify `CompletedPitchMatching.tuningSystem` uses session tuningSystem (not hardcoded)
   - Verify `start()` callable through `TrainingSession` protocol for both session types
   - Verify interval state cleared on `stop()`
4. **Run full suite**: `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
5. **Run dependency check**: `tools/check-dependencies.sh`

### Learnings from Story 23.2 (ComparisonSession — Apply Same Patterns)

From Story 23.2 implementation and code review:
- `sessionTuningSystem` cleanup in `stop()` was a code review finding — include from the start
- `PreviewComparisonStrategy` in `EnvironmentKeys.swift` needed updating for protocol conformance — no equivalent needed here (PitchMatchingSession has no strategy protocol)
- MockUserSettings defaults `[.prime]` ensures backward compatibility — already in place
- Strategy protocol intentionally omits `tuningSystem` (logical world) — PitchMatchingSession has no strategy, so not applicable
- All 3 hardcoded `.equalTemperament` locations must be replaced — same pattern applies here

### Project Structure Notes

All changes stay within established directories:
- `Peach/PitchMatching/PitchMatchingSession.swift` — rename, interval context, observable state, session tuningSystem, anchor change
- `Peach/PitchMatching/PitchMatchingScreen.swift` — `start()` call update
- `Peach/Core/TrainingSession.swift` — add `start()` to protocol
- `PeachTests/PitchMatching/PitchMatchingSessionTests.swift` — rename calls, new interval tests
- `PeachTests/Core/TrainingSessionTests.swift` — rename calls, new protocol tests

No new files. No new directories. No cross-feature coupling. No changes to `EnvironmentKeys.swift` (preview stubs already conform).

### References

- [Source: docs/planning-artifacts/epics.md#Story 23.3] — Full acceptance criteria
- [Source: docs/planning-artifacts/epics.md#Epic 23] — Epic context and all stories overview
- [Source: docs/project-context.md#Testing Rules] — Swift Testing, TDD workflow
- [Source: docs/project-context.md#Critical Don't-Miss Rules] — MIDI range, TuningSystem bridge
- [Source: docs/implementation-artifacts/23-2-comparisonsession-and-strategy-interval-parameterization.md] — Previous story learnings and patterns to mirror
- [Source: Peach/PitchMatching/PitchMatchingSession.swift] — Current implementation with hardcoded `.equalTemperament`
- [Source: Peach/Core/TrainingSession.swift] — Current protocol (stop + isIdle, no start)
- [Source: Peach/Core/Audio/Interval.swift] — `Interval` enum, `MIDINote.transposed(by:)`
- [Source: Peach/Settings/UserSettings.swift] — Protocol with `intervals` and `tuningSystem` (from Story 23.2)
- [Source: Peach/Comparison/ComparisonSession.swift] — Reference implementation of interval parameterization pattern

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
