# Fix: Feedback Icon Flicker on Correctness Change

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **musician using Peach**,
I want the feedback icon to transition cleanly between correct and incorrect states,
so that I see only the current result without a distracting flash of the previous icon.

## Acceptance Criteria

1. **Given** the user answers correctly after a previous incorrect answer
   **When** the feedback icon appears
   **Then** only the thumbs-up (green) icon is visible — no flash of the previous thumbs-down icon

2. **Given** the user answers incorrectly after a previous correct answer
   **When** the feedback icon appears
   **Then** only the thumbs-down (red) icon is visible — no flash of the previous thumbs-up icon

3. **Given** the user answers with the same correctness as the previous answer
   **When** the feedback icon appears
   **Then** the icon displays normally with no visual glitch

4. **Given** the user answers the very first comparison of a session
   **When** the feedback icon appears
   **Then** the icon displays normally (no previous state to flash)

5. **Given** Reduce Motion is enabled in system accessibility settings
   **When** the feedback icon appears or disappears
   **Then** the transition is instant (no animation) and no flicker occurs

6. **Given** any answer during training
   **When** the feedback icon is shown
   **Then** the feedback duration remains ~400ms and the training loop timing is unchanged

7. **Given** the fix is applied
   **When** the full test suite runs
   **Then** all existing tests pass with no regressions

## Tasks / Subtasks

- [x] Task 1: Write failing test reproducing the flicker (AC: #1, #2)
  - [x] 1.1 Add test verifying FeedbackIndicator shows correct icon immediately on correctness change
  - [x] 1.2 Add test verifying no stale icon state persists between feedback cycles
- [x] Task 2: Fix feedback overlay rendering in TrainingScreen (AC: #1-#6)
  - [x] 2.1 Replace `.opacity()` toggle with conditional `if` + `.transition(.opacity)` pattern
  - [x] 2.2 Move `.animation()` modifier to overlay container
  - [x] 2.3 Verify Reduce Motion behavior (AC: #5)
- [x] Task 3: Run full test suite and verify no regressions (AC: #7)

## Dev Notes

### Root Cause Analysis

The `FeedbackIndicator` overlay in `TrainingScreen.swift` (lines 46-53) uses a permanent view with `.opacity()` toggling:

```swift
.overlay {
    FeedbackIndicator(
        isCorrect: trainingSession.isLastAnswerCorrect,
        iconSize: Self.feedbackIconSize(isCompact: isCompactHeight)
    )
    .opacity(trainingSession.showFeedback ? 1 : 0)
    .animation(Self.feedbackAnimation(reduceMotion: reduceMotion), value: trainingSession.showFeedback)
}
```

The `FeedbackIndicator` view **always exists in the view tree**, even when invisible (opacity 0). It renders whichever icon `isLastAnswerCorrect` dictates. Between feedback cycles:

1. `showFeedback = false` (line 291 of TrainingSession.swift) — opacity animates toward 0
2. `isLastAnswerCorrect` retains the **previous** value (never reset to nil between comparisons)
3. When the next answer arrives, `isLastAnswerCorrect` changes and `showFeedback` becomes true simultaneously
4. SwiftUI may render a frame where the **old icon** is visible at low opacity before the new icon takes over, because the view was never removed — only hidden

The `.animation(value: showFeedback)` modifier only animates changes when `showFeedback` changes. The icon swap (driven by `isLastAnswerCorrect`) is **not animated** and happens instantly, but the opacity animation from the previous cycle may still be in flight.

### Recommended Fix

Replace the permanent-view + opacity pattern with a **conditional rendering + transition** pattern:

```swift
.overlay {
    if trainingSession.showFeedback {
        FeedbackIndicator(
            isCorrect: trainingSession.isLastAnswerCorrect,
            iconSize: Self.feedbackIconSize(isCompact: isCompactHeight)
        )
        .transition(.opacity)
    }
}
.animation(Self.feedbackAnimation(reduceMotion: reduceMotion), value: trainingSession.showFeedback)
```

**Why this works:**
- When `showFeedback` is false, the `FeedbackIndicator` is **completely removed** from the view tree (not just hidden)
- When `showFeedback` becomes true, a **fresh** `FeedbackIndicator` is inserted with the current `isLastAnswerCorrect` value
- `.transition(.opacity)` provides the same fade-in/fade-out effect as the manual `.opacity()` approach
- No stale icon state is possible because the view is recreated each cycle
- `.animation()` on the overlay container drives the transition animation
- Reduce Motion: when `feedbackAnimation()` returns `nil`, the transition is instant — same behavior as before

**No changes needed in `TrainingSession.swift`** — the state management is correct. The fix is purely in the view layer.

### Architecture Constraints

- **Views are thin** — this fix changes only rendering, no business logic [Source: docs/project-context.md#Framework-Specific Rules]
- **TrainingSession is the state machine** — feedback state (`showFeedback`, `isLastAnswerCorrect`) stays in TrainingSession [Source: docs/project-context.md#State Management]
- **Reduce Motion respected** — `feedbackAnimation(reduceMotion:)` returns nil when enabled [Source: docs/planning-artifacts/epics.md#Reduce Motion]
- **Feedback duration is 0.4 seconds** — do not change `feedbackDuration` in TrainingSession [Source: docs/project-context.md#Domain Rules]

### Files to Modify

| File | Change |
|------|--------|
| `Peach/Training/TrainingScreen.swift` | Replace overlay opacity pattern with conditional `if` + `.transition(.opacity)` |

### Files NOT to Modify

| File | Reason |
|------|--------|
| `Peach/Training/FeedbackIndicator.swift` | Component is correct — the bug is in how it's hosted |
| `Peach/Training/TrainingSession.swift` | State management is correct — `showFeedback` and `isLastAnswerCorrect` work as designed |

### Testing Strategy

- **Unit test:** Verify that when `showFeedback` toggles, the FeedbackIndicator content matches the current `isLastAnswerCorrect` (not a stale value). Test through `TrainingScreen` layout static methods or by verifying `TrainingSession` state contracts.
- **Regression:** Full test suite must pass — `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
- **Manual verification:** Rapidly answer alternating correct/incorrect during training; confirm no icon flash on correctness changes.

### Project Structure Notes

- Single file change in `Peach/Training/TrainingScreen.swift` (lines 46-53)
- No new files, no new dependencies, no protocol changes
- Follows existing SwiftUI patterns used elsewhere in the project

### References

- [Source: Peach/Training/TrainingScreen.swift#L46-L53] — Current overlay implementation (bug location)
- [Source: Peach/Training/TrainingSession.swift#L279-L295] — handleAnswer() sets feedback state
- [Source: Peach/Training/TrainingSession.swift#L287-L295] — feedbackTask clears showFeedback after 400ms
- [Source: Peach/Training/FeedbackIndicator.swift#L28-L36] — Icon rendering based on isCorrect
- [Source: docs/project-context.md#Framework-Specific Rules] — SwiftUI view patterns
- [Source: docs/planning-artifacts/ux-design-specification.md#L700-L720] — Feedback indicator spec: `.transition(.opacity)` for appearance/disappearance
- [Source: docs/planning-artifacts/epics.md#L101] — Feedback indicator: SF Symbols thumbs up/down, ~300-500ms duration

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

### Completion Notes List

- ✅ Task 1: Created `TrainingScreenFeedbackTests.swift` with 7 tests verifying feedback state contract — correctness transitions (incorrect→correct, correct→incorrect, same→same), no stale state between cycles, clean first-answer behavior, and Reduce Motion animation behavior. Tests confirm the state layer in `TrainingSession` is correct; the flicker was purely a view-rendering artifact. **TDD note:** These tests verify the state contract but would also pass without the view-layer fix, since the flicker was a SwiftUI rendering artifact (permanent view + opacity toggle) not a state bug. A true "failing test" for the visual flicker is not achievable with unit tests — manual verification or snapshot tests would be needed to guard the view-layer fix directly.
- ✅ Task 2: Replaced permanent-view + `.opacity()` toggle with conditional `if` + `.transition(.opacity)` pattern in `TrainingScreen.swift`. Moved `.animation()` modifier from `FeedbackIndicator` to the overlay container. When `showFeedback` is false, the `FeedbackIndicator` is now completely removed from the view tree (not just hidden), eliminating any possibility of a stale icon flash. Reduce Motion behavior preserved — `feedbackAnimation(reduceMotion:)` returns `nil` for instant transitions.
- ✅ Task 3: Full test suite passes with zero regressions.

### File List

- `Peach/Training/TrainingScreen.swift` — Modified: replaced overlay opacity pattern with conditional rendering + transition
- `Peach/Training/FeedbackIndicator.swift` — Modified: updated doc comment usage example to reflect new conditional rendering pattern
- `PeachTests/Training/TrainingScreenFeedbackTests.swift` — New: 7 tests for feedback state contract and Reduce Motion

### Change Log

- 2026-02-22: Fixed feedback icon flicker by replacing permanent-view opacity toggle with conditional `if` + `.transition(.opacity)` pattern in TrainingScreen overlay
- 2026-02-22: Code review fixes — added AC3 test (consecutive same-correctness), fixed `@MainActor async` on Reduce Motion tests, updated stale FeedbackIndicator doc comment, added TDD limitation note
