# Story 26.1: Delay targetNote Until Slider Touch

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **musician using Peach**,
I want the target note to play only when I first touch the pitch slider (not automatically after the reference note),
so that I have a moment of silence to internalize the reference pitch before the tunable note begins.

## Acceptance Criteria

### AC 1: New `awaitingSliderTouch` state after reference note
**Given** the reference note has finished playing
**When** the session transitions from `playingReference`
**Then** the state becomes `awaitingSliderTouch` (not `playingTunable`)
**And** no tunable note is playing yet
**And** `currentChallenge` is set (challenge was generated before reference note)

### AC 2: Slider is active during `awaitingSliderTouch`
**Given** the session is in `awaitingSliderTouch` state
**When** the slider evaluates its `isActive` condition
**Then** the slider is enabled and responds to touch
**And** the slider thumb is at center position (reset happened on activation)
**And** the slider opacity is 1.0 (fully visible)

### AC 3: First slider touch triggers tunable note playback
**Given** the session is in `awaitingSliderTouch` state
**When** the user first touches (drags) the slider
**Then** the tunable note begins playing at the initial detuned frequency
**And** the state transitions to `playingTunable`
**And** subsequent drag events adjust the pitch via `adjustPitch()` as before

### AC 4: Quick tap (touch + release) still produces a result
**Given** the session is in `awaitingSliderTouch` state
**When** the user taps the slider (DragGesture fires `onChanged` then `onEnded` immediately)
**Then** `adjustPitch` triggers the note start (transition to `playingTunable`)
**And** `commitPitch` processes the release and produces a `CompletedPitchMatching` result
**And** the session transitions to `showingFeedback`

### AC 5: Stop from `awaitingSliderTouch` is clean
**Given** the session is in `awaitingSliderTouch` state
**When** `stop()` is called (navigation away, interruption, background)
**Then** the session transitions to `idle`
**And** no tunable note was ever played
**And** all state is cleared (challenge, interval, frequencies)

### AC 6: Full training loop works with the new state
**Given** the new state machine: `idle` → `playingReference` → `awaitingSliderTouch` → `playingTunable` → `showingFeedback` → (loop)
**When** multiple challenges are completed in sequence
**Then** each cycle includes the `awaitingSliderTouch` pause
**And** the feedback auto-advance leads back to `playingReference` → `awaitingSliderTouch`
**And** audio interruptions, background, and route changes all stop cleanly from any state

### AC 7: Existing functionality preserved
**Given** the updated implementation
**When** the full test suite runs
**Then** all existing audio interruption, lifecycle, and route change tests pass (updated for new state)
**And** all comparison training tests are unaffected
**And** the pitch matching feedback indicator behavior is unchanged

## Tasks / Subtasks

- [ ] Task 1: Add `awaitingSliderTouch` state to `PitchMatchingSessionState` (AC: 1)
  - [ ] Add `case awaitingSliderTouch` to the enum
  - [ ] Add `pendingTunableFrequency: Frequency?` stored property to `PitchMatchingSession`
  - [ ] Write tests: session transitions to `awaitingSliderTouch` (not `playingTunable`) after reference note

- [ ] Task 2: Modify `playNextChallenge()` to stop at `awaitingSliderTouch` (AC: 1)
  - [ ] After reference note finishes: compute tunable frequency, store as `pendingTunableFrequency`
  - [ ] Set state to `.awaitingSliderTouch` instead of `.playingTunable`
  - [ ] Do NOT call `notePlayer.play(frequency:velocity:amplitudeDB:)` for the tunable note yet
  - [ ] Write tests: no tunable note play call while in `awaitingSliderTouch`

- [ ] Task 3: Add `startTunableNote()` private method (AC: 3)
  - [ ] Guard: only proceed if `pendingTunableFrequency` is set
  - [ ] Play tunable note using stored frequency, store returned `PlaybackHandle`
  - [ ] Clear `pendingTunableFrequency` after starting
  - [ ] Handle errors (CancellationError, AudioError) same as existing pattern

- [ ] Task 4: Modify `adjustPitch()` to trigger note start from `awaitingSliderTouch` (AC: 3, 4)
  - [ ] If `state == .awaitingSliderTouch`: transition to `.playingTunable`, call `startTunableNote()`
  - [ ] Existing `guard state == .playingTunable` continues to work for subsequent calls
  - [ ] Write tests: `adjustPitch` from `awaitingSliderTouch` starts tunable note and transitions state

- [ ] Task 5: Modify `commitPitch()` to handle edge case from `awaitingSliderTouch` (AC: 4)
  - [ ] If `state == .awaitingSliderTouch`: transition to `.playingTunable`, call `startTunableNote()`
  - [ ] The `commitResult` call proceeds to compute cent error and show feedback
  - [ ] Write test: quick tap from `awaitingSliderTouch` produces valid result

- [ ] Task 6: Update `stop()` to handle `awaitingSliderTouch` (AC: 5)
  - [ ] Clear `pendingTunableFrequency` in `stop()`
  - [ ] Existing stop logic already handles all other cleanup
  - [ ] Write tests: stop from `awaitingSliderTouch` transitions to idle, no note played

- [ ] Task 7: Update `PitchMatchingScreen` slider activation (AC: 2)
  - [ ] Change `isActive` from `state == .playingTunable` to `state == .awaitingSliderTouch || state == .playingTunable`
  - [ ] No changes needed to `VerticalPitchSlider` itself (it receives `isActive` boolean)
  - [ ] Feedback overlay condition (`state == .showingFeedback`) is unchanged

- [ ] Task 8: Update existing tests for new state flow (AC: 6, 7)
  - [ ] Tests that `waitForState(.playingTunable)`: change to wait for `.awaitingSliderTouch`, then call `adjustPitch(0.0)` to trigger transition
  - [ ] State transition tests: update expected sequence to include `awaitingSliderTouch`
  - [ ] Audio interruption tests: add stop from `awaitingSliderTouch` coverage
  - [ ] Full cycle test: update sequence

- [ ] Task 9: Run full test suite (AC: 7)
  - [ ] `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [ ] All tests pass with zero regressions

## Dev Notes

### Developer Context — Critical Implementation Intelligence

This story modifies the `PitchMatchingSession` state machine to insert a pause between the reference note finishing and the tunable note starting. Currently, the tunable note auto-plays immediately after the reference note. After this change, the tunable note only starts when the user first touches the pitch slider. This gives the user time to internalize the reference pitch before the detunable note begins.

**Scope of change:** ~3 source files modified, ~1 test file updated. Low-medium complexity — the main challenge is updating ~20 existing tests that expect the old state flow.

**What this story changes:**
- `PitchMatchingSession`: Add `awaitingSliderTouch` state, modify `playNextChallenge()`, `adjustPitch()`, `commitPitch()`, `stop()`
- `PitchMatchingScreen`: Update slider `isActive` condition to include new state
- `PitchMatchingSessionTests`: Update state expectations throughout

**What this story does NOT change:**
- `VerticalPitchSlider` — receives `isActive` boolean, no internal changes
- `PitchMatchingFeedbackIndicator` — feedback display logic unchanged
- `ComparisonSession` — entirely separate training mode, untouched
- `NotePlayer` / `PlaybackHandle` — protocol unchanged
- Data models, profiles, observers — all unchanged
- Settings, navigation, other screens — untouched

### State Machine Change

**Current flow:**
```
idle → playingReference → playingTunable → showingFeedback → (loop)
                          ↑ target note auto-plays
```

**New flow:**
```
idle → playingReference → awaitingSliderTouch → playingTunable → showingFeedback → (loop)
                          ↑ silence, slider active   ↑ user touches slider, note starts
```

### Critical Implementation Details

**`playNextChallenge()` modification (lines 209-260 of PitchMatchingSession.swift):**

The current code after reference note finishes:
```swift
// CURRENT: plays tunable note immediately
state = .playingTunable
let handle = try await notePlayer.play(
    frequency: tunableFrequency,
    velocity: velocity,
    amplitudeDB: AmplitudeDB(0.0)
)
currentHandle = handle
```

Change to:
```swift
// NEW: store frequency, wait for user touch
self.pendingTunableFrequency = tunableFrequency
state = .awaitingSliderTouch
// Do NOT play the tunable note yet — wait for adjustPitch/commitPitch trigger
```

**`adjustPitch()` modification (line 99-106):**

Add transition logic at the top:
```swift
func adjustPitch(_ value: Double) {
    if state == .awaitingSliderTouch {
        state = .playingTunable
        startTunableNote()
    }
    guard state == .playingTunable, let referenceFrequency else { return }
    // ... existing frequency computation and handle adjustment
}
```

**`startTunableNote()` new private method:**
```swift
private func startTunableNote() {
    guard let frequency = pendingTunableFrequency else { return }
    pendingTunableFrequency = nil
    Task {
        do {
            let handle = try await notePlayer.play(
                frequency: frequency,
                velocity: velocity,
                amplitudeDB: AmplitudeDB(0.0)
            )
            guard state != .idle && !Task.isCancelled else {
                Task { try? await handle.stop() }
                return
            }
            currentHandle = handle
        } catch is CancellationError {
            logger.info("Tunable note start cancelled")
        } catch let error as AudioError {
            logger.error("Audio error starting tunable note: \(error.localizedDescription)")
            stop()
        } catch {
            logger.error("Unexpected error starting tunable note: \(error.localizedDescription)")
            stop()
        }
    }
}
```

**Timing consideration:** `startTunableNote()` spawns an async Task. The `notePlayer.play()` call returns quickly (note starts within milliseconds). The first `adjustPitch` call's handle adjustment may be a no-op (handle not yet assigned), but subsequent drag events will have the handle. This is acceptable because the initial cent offset is already applied to the tunable frequency.

**`stop()` modification:** Add `pendingTunableFrequency = nil` to the cleanup.

**PitchMatchingScreen slider activation:**
```swift
// CURRENT:
VerticalPitchSlider(
    isActive: pitchMatchingSession.state == .playingTunable,
    ...
)

// NEW:
VerticalPitchSlider(
    isActive: pitchMatchingSession.state == .awaitingSliderTouch || pitchMatchingSession.state == .playingTunable,
    ...
)
```

**VerticalPitchSlider `onChange(of: isActive)` — thumb reset:**
The slider resets the thumb to center when `isActive` changes from false to true. With the new flow, this happens when transitioning to `awaitingSliderTouch` (correct timing — reference note just finished, new challenge ready).

### Test Update Strategy

Most existing tests use `waitForState(session, .playingTunable)` to reach the "ready for user interaction" state. With the new design:

**Pattern A — Tests that need `awaitingSliderTouch` (challenge generation, reference note tests):**
```swift
// Change from:
try await waitForState(session, .playingTunable)
// To:
try await waitForState(session, .awaitingSliderTouch)
```

**Pattern B — Tests that need `playingTunable` (adjustPitch, commitPitch, handle tests):**
```swift
// Change from:
try await waitForState(session, .playingTunable)
// To:
try await waitForState(session, .awaitingSliderTouch)
session.adjustPitch(0.0)  // triggers transition to playingTunable
try await Task.sleep(for: .milliseconds(50))  // allow async note start
```

**Tests to update (by category):**
- Challenge generation tests (2): wait for `.awaitingSliderTouch` instead — challenge is set by then
- Reference note frequency test (1): wait for `.awaitingSliderTouch` — reference was already played
- Auto-transition test (1): rename/update to test `.awaitingSliderTouch` transition
- Tunable note frequency test (1): trigger transition first, then verify
- adjustPitch tests (4): trigger transition first
- commitPitch tests (6): trigger transition first
- stop tests (4): add `awaitingSliderTouch` coverage
- Guard condition tests (2): update
- Interval tests (8): mostly wait for `.awaitingSliderTouch`
- Full cycle test (1): update state sequence
- Interruption tests (5+): add `awaitingSliderTouch` coverage
- Lifecycle tests (4+): add `awaitingSliderTouch` coverage

### Architecture Compliance

1. **State transitions are guarded** — new state has explicit guards; never skip states [Source: docs/project-context.md#State Management]
2. **`PitchMatchingSession` is the state machine** — all transition logic stays in the session, not in views [Source: docs/project-context.md#Architectural Boundaries]
3. **Views are thin** — `PitchMatchingScreen` only reads state, no business logic change [Source: docs/project-context.md#SwiftUI View Rules]
4. **Protocol boundary respected** — `NotePlayer` knows only frequencies; timing change is session-level [Source: docs/project-context.md#Audio Protocol]
5. **Observer pattern unchanged** — `PitchMatchingObserver` still notified only on `commitResult` [Source: docs/project-context.md#State Management]
6. **No cross-feature coupling** — change is contained within `PitchMatching/` directory [Source: docs/project-context.md#Dependency Direction Rules]

### Library/Framework Requirements

- **Swift 6.2** with strict concurrency — `PitchMatchingSessionState` gains one new case (enum, `Sendable` by value)
- **SwiftUI** — no new APIs used; `isActive` condition update is trivial
- **No new dependencies** — zero third-party packages
- **No SwiftData changes** — no model changes
- **No localization changes** — no new user-facing strings

### File Structure — Files to Modify

| File | Change | Why |
|------|--------|-----|
| `Peach/PitchMatching/PitchMatchingSession.swift` | Add state, modify flow, add method | Core state machine change |
| `Peach/PitchMatching/PitchMatchingScreen.swift` | Update `isActive` condition | Slider activation for new state |
| `PeachTests/PitchMatching/PitchMatchingSessionTests.swift` | Update state expectations, add new tests | Test coverage for new flow |

**Files NOT to modify:**
- `Peach/PitchMatching/VerticalPitchSlider.swift` — receives `isActive` boolean, no changes
- `Peach/PitchMatching/PitchMatchingFeedbackIndicator.swift` — feedback logic unchanged
- `Peach/PitchMatching/PitchMatchingChallenge.swift` — value type unchanged
- `Peach/PitchMatching/CompletedPitchMatching.swift` — value type unchanged
- `Peach/PitchMatching/PitchMatchingObserver.swift` — protocol unchanged
- `Peach/PitchMatching/PitchMatchingProfile.swift` — profile logic unchanged
- `Peach/Core/Audio/NotePlayer.swift` — protocol unchanged
- `Peach/Core/Audio/PlaybackHandle.swift` — protocol unchanged
- `Peach/Comparison/` — entirely separate training mode
- `Peach/Settings/`, `Peach/Start/`, `Peach/Profile/` — untouched
- `Peach/App/PeachApp.swift` — no new services to wire
- Data models, localization — unchanged

### Testing Requirements

**TDD approach — write failing tests first:**

1. **New state transition tests:**
   - `awaitingSliderTouch` reached after reference note (not `playingTunable`)
   - No `notePlayer.play` handle call while in `awaitingSliderTouch`
   - `adjustPitch` from `awaitingSliderTouch` transitions to `playingTunable` and starts note
   - `commitPitch` from `awaitingSliderTouch` triggers note + produces result
   - `stop()` from `awaitingSliderTouch` → `idle`, no tunable note played

2. **Updated existing tests:**
   - All tests waiting for `.playingTunable` updated to new pattern
   - State cycle test: `idle → playingReference → awaitingSliderTouch → playingTunable → showingFeedback`
   - Audio interruption from `awaitingSliderTouch` stops cleanly
   - Background notification from `awaitingSliderTouch` stops cleanly

3. **Test execution:** `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`

### Previous Story Intelligence (Story 25.2)

From story 25.2 implementation:
- `IntervalSelection` wrapper type for `@AppStorage` — not relevant to this story
- `@AppStorage` pattern established — not relevant
- Code review found: use consistent short form `.prime` — already adopted
- **Commit pattern:** `Add story X.Y: Title` → `Implement story X.Y: Title` → `Fix code review findings for story X.Y and mark done`

### Git Intelligence

Recent commits:
```
8d429a5 Fix code review findings for story 25.2 and mark done
82cb129 Implement story 25.2: Interval Selector on Settings Screen
84801ef Add story 25.2: Interval Selector on Settings Screen
b12314f Fix code review findings for story 25.1 and mark done
45ccd14 Implement story 25.1: Direction Enum and DirectedInterval
```

### Project Structure Notes

- All changes within `Peach/PitchMatching/` and `PeachTests/PitchMatching/`
- No new files created
- No new directories needed
- No cross-feature coupling introduced

### References

- [Source: Peach/PitchMatching/PitchMatchingSession.swift] — Current state machine with 4 states, `playNextChallenge()` at line 209
- [Source: Peach/PitchMatching/PitchMatchingScreen.swift] — Slider activation at line 22: `isActive: pitchMatchingSession.state == .playingTunable`
- [Source: Peach/PitchMatching/VerticalPitchSlider.swift] — DragGesture with `minimumDistance: 0`, `onChange(of: isActive)` resets thumb
- [Source: PeachTests/PitchMatching/PitchMatchingSessionTests.swift] — 40+ tests using `waitForState(.playingTunable)` pattern
- [Source: docs/project-context.md#State Management] — State transitions are guarded, preconditions enforced
- [Source: docs/project-context.md#Testing Rules] — Swift Testing, TDD, full suite before commit
- [Source: docs/implementation-artifacts/sprint-status.yaml#Epic 26] — "targetNote plays only when user first touches slider, not auto after referenceNote"

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
