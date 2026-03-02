# Story 30.3: Add Tuning System Indicator to Interval Training Screens

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **musician training intervals in Peach**,
I want to see which tuning system is active on the interval training screens,
so that I know whether I'm training with Equal Temperament or Just Intonation intervals.

## Acceptance Criteria

1. **Given** an interval comparison training session, **when** `isIntervalMode` is true, **then** the active tuning system's `displayName` is shown below the interval name
2. **Given** an interval pitch matching training session, **when** `isIntervalMode` is true, **then** the active tuning system's `displayName` is shown below the interval name
3. **Given** a unison (prime) training session, **when** `isIntervalMode` is false, **then** no tuning system indicator is shown
4. **Given** the tuning system indicator, **when** rendered, **then** it appears as secondary text (smaller font, secondary color) below the interval name
5. **Given** the tuning system indicator, **when** VoiceOver is active, **then** the interval name and tuning system are combined into a single accessible label
6. **Given** the app language is German, **when** viewing the tuning system indicator, **then** the tuning system name appears in German (existing `TuningSystem.displayName` localizations)
7. **Given** `ComparisonSession.sessionTuningSystem`, **when** read from a view, **then** it returns the tuning system captured at `start()`
8. **Given** `PitchMatchingSession.sessionTuningSystem`, **when** read from a view, **then** it returns the tuning system captured at `start()`

## Tasks / Subtasks

- [x] Task 1: Expose `sessionTuningSystem` on ComparisonSession (AC: #7)
  - [x] 1.1 Write failing test: `sessionTuningSystem is equalTemperament by default`
  - [x] 1.2 Write failing test: `sessionTuningSystem reflects userSettings after start`
  - [x] 1.3 Change `private var sessionTuningSystem` to `private(set) var sessionTuningSystem` in ComparisonSession.swift
  - [x] 1.4 Verify tests pass
- [x] Task 2: Expose `sessionTuningSystem` on PitchMatchingSession (AC: #8)
  - [x] 2.1 Write failing test: `sessionTuningSystem is equalTemperament by default`
  - [x] 2.2 Write failing test: `sessionTuningSystem reflects userSettings after start`
  - [x] 2.3 Change `private var sessionTuningSystem` to `private(set) var sessionTuningSystem` in PitchMatchingSession.swift
  - [x] 2.4 Verify tests pass
- [x] Task 3: Add tuning system indicator to ComparisonScreen (AC: #1, #3, #4, #5)
  - [x] 3.1 Wrap existing interval `Text` and new tuning system `Text` in a `VStack(spacing: 2)`
  - [x] 3.2 Add `Text(comparisonSession.sessionTuningSystem.displayName)` with `.font(.caption)` and `.foregroundStyle(.secondary)`
  - [x] 3.3 Update `.accessibilityLabel` to include tuning system name
  - [x] 3.4 Verify indicator only appears when `isIntervalMode` is true (existing guard)
- [x] Task 4: Add tuning system indicator to PitchMatchingScreen (AC: #2, #3, #4, #5)
  - [x] 4.1 Wrap existing interval `Text` and new tuning system `Text` in a `VStack(spacing: 2)`
  - [x] 4.2 Add `Text(pitchMatchingSession.sessionTuningSystem.displayName)` with `.font(.caption)` and `.foregroundStyle(.secondary)`
  - [x] 4.3 Update `.accessibilityLabel` to include tuning system name
  - [x] 4.4 Verify indicator only appears when `isIntervalMode` is true (existing guard)
- [x] Task 5: Run full test suite and verify (AC: all)
  - [x] 5.1 Run `bin/test.sh` — all existing + new tests must pass
  - [x] 5.2 Run `bin/build.sh` — no warnings or errors
  - [x] 5.3 Run `bin/check-dependencies.sh` — no dependency violations

## Dev Notes

### Technical Requirements

**What this story IS:**
- Change access level of `sessionTuningSystem` from `private` to `private(set)` on both `ComparisonSession` and `PitchMatchingSession` (1 keyword change each)
- Add a tuning system `Text` label below the existing interval name on `ComparisonScreen` and `PitchMatchingScreen` (~5 lines each)
- Update accessibility labels to include the tuning system
- Write ~4 new tests for property visibility

**What this story is NOT:**
- No changes to `TuningSystem.swift` — `displayName` already exists and is already localized (EN + DE)
- No new localized strings — `TuningSystem.displayName` uses `String(localized:)` which is already in `Localizable.xcstrings`
- No changes to `UserSettings`, `AppUserSettings`, `SettingsKeys`, or `SettingsScreen`
- No changes to `PeachApp.swift` or `EnvironmentKeys.swift`
- No changes to training logic, note selection, or frequency computation
- No changes to `TrainingSession` protocol
- No new files, no new types, no new protocols

### Architecture Compliance

**Views remain thin:** The views simply read `session.sessionTuningSystem.displayName` — a computed property on an `@Observable` object that's already injected via `@Environment`. No new business logic in views.

**No cross-feature coupling:** Both screens access their own session's `sessionTuningSystem`. `ComparisonScreen` reads from `ComparisonSession`, `PitchMatchingScreen` reads from `PitchMatchingSession`. No new cross-feature imports.

**Dependency direction preserved:**
- `ComparisonScreen` (Comparison/) already depends on `ComparisonSession` (Comparison/) — no change
- `PitchMatchingScreen` (PitchMatching/) already depends on `PitchMatchingSession` (PitchMatching/) — no change
- `TuningSystem.displayName` (Core/Audio/) is already used by `SettingsScreen` — views reading Core/ types is established pattern

**`isIntervalMode` gating:** The tuning system indicator shares the existing `isIntervalMode` guard, meaning it only appears for interval-based training. For unison training (prime), tuning system makes no audible difference, so hiding the indicator is correct.

### Library & Framework Requirements

**No new dependencies.** This story only uses:
- `Text`, `VStack`, `Font.caption`, `.foregroundStyle(.secondary)` — all SwiftUI, already imported
- `TuningSystem.displayName` — already exists in Core/Audio/

### File Structure Requirements

**4 files modified, 0 files created:**

| File | Action | What Changes |
|------|--------|-------------|
| `Peach/Comparison/ComparisonSession.swift` | Modify | Change `private var sessionTuningSystem` to `private(set) var sessionTuningSystem` |
| `Peach/PitchMatching/PitchMatchingSession.swift` | Modify | Change `private var sessionTuningSystem` to `private(set) var sessionTuningSystem` |
| `Peach/Comparison/ComparisonScreen.swift` | Modify | Add tuning system label below interval name (lines 33-37) |
| `Peach/PitchMatching/PitchMatchingScreen.swift` | Modify | Add tuning system label below interval name (lines 14-19) |

**2 test files modified:**

| File | Action | What Changes |
|------|--------|-------------|
| `PeachTests/Comparison/ComparisonSessionTests.swift` | Modify | Add 2 tests for `sessionTuningSystem` visibility |
| `PeachTests/PitchMatching/PitchMatchingSessionTests.swift` | Modify | Add 2 tests for `sessionTuningSystem` visibility |

**Do not touch these files:**
- `Peach/Core/Audio/TuningSystem.swift` — `displayName` already exists, already localized
- `Peach/Resources/Localizable.xcstrings` — no new localized strings needed
- `Peach/Settings/SettingsScreen.swift` — no changes to the picker
- `Peach/App/PeachApp.swift` — no wiring changes
- `Peach/App/EnvironmentKeys.swift` — no new environment keys
- `Peach/Core/TrainingSession.swift` — protocol doesn't need to expose tuning system

### Testing Requirements

**Framework:** Swift Testing (`import Testing`, `@Test`, `@Suite`, `#expect`) — never XCTest.

**All `@Test` functions must be `async`.** No `test` prefix on function names.

**New tests in `ComparisonSessionTests.swift`:**

```swift
@Test("sessionTuningSystem is equalTemperament by default")
func sessionTuningSystemDefault() async {
    let (session, _, _, _, _) = makeComparisonSession()
    #expect(session.sessionTuningSystem == .equalTemperament)
}

@Test("sessionTuningSystem reflects userSettings after start")
func sessionTuningSystemFromSettings() async {
    let (session, notePlayer, _, _, mockSettings) = makeComparisonSession()
    notePlayer.instantPlayback = true
    mockSettings.tuningSystem = .justIntonation
    session.start(intervals: [.prime])
    #expect(session.sessionTuningSystem == .justIntonation)
    session.stop()
}
```

**New tests in `PitchMatchingSessionTests.swift`:**

```swift
@Test("sessionTuningSystem is equalTemperament by default")
func sessionTuningSystemDefault() async {
    let (session, _, _) = makePitchMatchingSession()
    #expect(session.sessionTuningSystem == .equalTemperament)
}

@Test("sessionTuningSystem reflects userSettings after start")
func sessionTuningSystemFromSettings() async {
    let (session, notePlayer, mockSettings) = makePitchMatchingSession()
    notePlayer.instantPlayback = true
    mockSettings.tuningSystem = .justIntonation
    session.start(intervals: [.prime])
    #expect(session.sessionTuningSystem == .justIntonation)
    session.stop()
}
```

**Note on factory method tuples:** The exact tuple destructuring shape depends on what the existing `makeComparisonSession()` and `makePitchMatchingSession()` factory methods return. Verify the current return type before writing tests. The `mockSettings` element must be the `MockUserSettings` instance to set `tuningSystem`.

**Run full suite:** `bin/test.sh` — all tests must pass before committing.

### Implementation Guidance

**ComparisonScreen.swift — wrap interval display in VStack (lines 33-37):**

Replace:
```swift
if comparisonSession.isIntervalMode, let interval = comparisonSession.currentInterval {
    Text(interval.displayName)
        .font(.title3)
        .accessibilityLabel(String(localized: "Target interval: \(interval.displayName)"))
}
```

With:
```swift
if comparisonSession.isIntervalMode, let interval = comparisonSession.currentInterval {
    VStack(spacing: 2) {
        Text(interval.displayName)
            .font(.title3)
        Text(comparisonSession.sessionTuningSystem.displayName)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "Target interval: \(interval.displayName), \(comparisonSession.sessionTuningSystem.displayName)"))
}
```

**PitchMatchingScreen.swift — wrap interval display in VStack (lines 14-19):**

Replace:
```swift
if pitchMatchingSession.isIntervalMode, let interval = pitchMatchingSession.currentInterval {
    Text(interval.displayName)
        .font(.title3)
        .padding(.horizontal)
        .accessibilityLabel(String(localized: "Target interval: \(interval.displayName)"))
}
```

With:
```swift
if pitchMatchingSession.isIntervalMode, let interval = pitchMatchingSession.currentInterval {
    VStack(spacing: 2) {
        Text(interval.displayName)
            .font(.title3)
        Text(pitchMatchingSession.sessionTuningSystem.displayName)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .padding(.horizontal)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "Target interval: \(interval.displayName), \(pitchMatchingSession.sessionTuningSystem.displayName)"))
}
```

**ComparisonSession.swift — change access level (line 69):**

```swift
// Before:
private var sessionTuningSystem: TuningSystem = .equalTemperament

// After:
private(set) var sessionTuningSystem: TuningSystem = .equalTemperament
```

**PitchMatchingSession.swift — change access level (line 37):**

```swift
// Before:
private var sessionTuningSystem: TuningSystem = .equalTemperament

// After:
private(set) var sessionTuningSystem: TuningSystem = .equalTemperament
```

### Previous Story Intelligence

**Story 30.2 (Add Tuning System Picker to Settings) — direct predecessor:**
- Added `displayName` to `TuningSystem` — this is exactly the property we'll read from views
- Added `@AppStorage`-backed picker in Settings — the user-facing selection mechanism
- `AppUserSettings.tuningSystem` now reads live from UserDefaults — sessions pick this up at `start()`
- 787 tests passed after implementation
- Debug note: `displayName` tests must use `String(localized:)` comparison, not hardcoded English strings (simulator may run in German locale)

**Story 30.1 (Add Just Intonation Tuning System Case):**
- Added `.justIntonation` case with cent offsets — the second tuning system option
- `storageIdentifier` values: `"equalTemperament"`, `"justIntonation"`

**Story 23.4 (Training Screen Interval Label and Observer Verification):**
- Added the interval `displayName` Text to both training screens — the exact pattern we're extending
- Established the `isIntervalMode` gating pattern we'll reuse

**Key pattern from ComparisonSession:** `sessionTuningSystem` is captured at `start()` from `userSettings.tuningSystem` and reset to `.equalTemperament` on `stop()`. The view reads it while training is active.

### Git Intelligence

**Recent commits (Epic 30):**
```
94c2b42 Review story 30.2: Add Tuning System Picker to Settings
d45b5ad Implement story 30.2: Add Tuning System Picker to Settings
69ffc2c Review story 30.1: Add Just Intonation Tuning System Case
dc5e307 Implement story 30.1: Add Just Intonation Tuning System Case
```

**Commit format:** `{Verb} story {id}: {Description}`

**Current test count:** 787 tests passing (as of story 30.2 completion).

### Project Structure Notes

- `ComparisonScreen.swift` lives in `Peach/Comparison/` (175 lines) — interval label at lines 33-37
- `PitchMatchingScreen.swift` lives in `Peach/PitchMatching/` (85 lines) — interval label at lines 14-19
- `ComparisonSession.swift` lives in `Peach/Comparison/` — `sessionTuningSystem` at line 69
- `PitchMatchingSession.swift` lives in `Peach/PitchMatching/` — `sessionTuningSystem` at line 37
- Test files mirror source: `PeachTests/Comparison/ComparisonSessionTests.swift`, `PeachTests/PitchMatching/PitchMatchingSessionTests.swift`
- No conflicts with project structure detected

### References

- [Source: docs/implementation-artifacts/30-2-add-tuning-system-picker-to-settings.md] — Previous story: displayName, Settings picker, AppUserSettings live read
- [Source: docs/implementation-artifacts/30-1-add-tuning-system-case.md] — JI case implementation, storageIdentifier values
- [Source: Peach/Core/Audio/TuningSystem.swift] — `displayName` computed property (lines 54-58), already localized
- [Source: Peach/Comparison/ComparisonScreen.swift] — Interval name display (lines 33-37), pattern to extend
- [Source: Peach/PitchMatching/PitchMatchingScreen.swift] — Interval name display (lines 14-19), pattern to extend
- [Source: Peach/Comparison/ComparisonSession.swift] — `sessionTuningSystem` private property (line 69)
- [Source: Peach/PitchMatching/PitchMatchingSession.swift] — `sessionTuningSystem` private property (line 37)
- [Source: Peach/Core/TrainingSession.swift] — Protocol (no tuningSystem exposure needed)
- [Source: docs/project-context.md] — Swift 6.2, Swift Testing, TDD, @Observable, view rules, dependency direction

## Change Log

- 2026-03-02: Implemented story 30.3 — exposed `sessionTuningSystem` on both sessions, added tuning system indicator to both training screens with accessibility support, 4 new tests added (791 total passing)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

No debug issues encountered. Implementation followed the story spec exactly.

### Completion Notes List

- Task 1: Changed `private var sessionTuningSystem` to `private(set) var sessionTuningSystem` in `ComparisonSession.swift`. Added 2 tests verifying default value and settings reflection after `start()`.
- Task 2: Changed `private var sessionTuningSystem` to `private(set) var sessionTuningSystem` in `PitchMatchingSession.swift`. Added 2 tests verifying default value and settings reflection after `start()`.
- Task 3: Wrapped interval display in `ComparisonScreen` with `VStack(spacing: 2)`, added tuning system `Text` with `.font(.caption)` and `.foregroundStyle(.secondary)`, combined accessibility label. Indicator gated by existing `isIntervalMode` check.
- Task 4: Wrapped interval display in `PitchMatchingScreen` with `VStack(spacing: 2)`, added tuning system `Text` with `.font(.caption)` and `.foregroundStyle(.secondary)`, combined accessibility label. Indicator gated by existing `isIntervalMode` check.
- Task 5: 791 tests pass, build succeeds, no dependency violations.

### File List

- Peach/Comparison/ComparisonSession.swift (modified — `private` → `private(set)` for `sessionTuningSystem`)
- Peach/PitchMatching/PitchMatchingSession.swift (modified — `private` → `private(set)` for `sessionTuningSystem`)
- Peach/Comparison/ComparisonScreen.swift (modified — added tuning system indicator below interval name)
- Peach/PitchMatching/PitchMatchingScreen.swift (modified — added tuning system indicator below interval name)
- PeachTests/Comparison/ComparisonSessionTests.swift (modified — added 2 tuning system visibility tests)
- PeachTests/PitchMatching/PitchMatchingSessionTests.swift (modified — added 2 tuning system visibility tests)
- docs/implementation-artifacts/sprint-status.yaml (modified — story status tracking)
- docs/implementation-artifacts/30-3-add-tuning-system-indicator-to-interval-training-screens.md (modified — task checkboxes, dev record, status)
