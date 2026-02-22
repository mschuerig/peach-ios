# Story: Display Current Difficulty on Training Screen

Status: done

## Story

As a **musician using Peach**,
I want to see the current difficulty level (cent difference) and my session best during training,
So that I can understand how fine my pitch discrimination is being challenged and track my best performance within a session.

## Acceptance Criteria

1. **Given** the Training Screen is active, **When** a comparison is generated, **Then** the current cent difference is displayed at the top of the body area, above the Higher/Lower buttons, using secondary-styled text (`.footnote`, `.secondary` color) with the format `Current: X.X ¢`

2. **Given** the user answers a comparison correctly, **When** the cent difference of that comparison is smaller than the current session best (or no session best exists yet), **Then** the session best updates and displays as `Session best: X.X ¢` below the current difficulty line

3. **Given** training has just started, **When** no correct answer has been given yet, **Then** only the current difficulty line is shown (no session best line)

4. **Given** the difficulty display is visible, **When** the user is interacting with the Higher/Lower buttons, **Then** the display does not interfere with button taps, feedback indicator overlay, or the calm visual aesthetic of the Training Screen

5. **Given** VoiceOver is enabled, **When** the difficulty display is present, **Then** it reads as "Current difficulty: X.X cents" and "Session best: X.X cents" (full words, not abbreviations)

6. **Given** the user navigates away from the Training Screen and returns, **When** training restarts, **Then** the session best resets (session-scoped, not persisted)

## Tasks / Subtasks

- [x] Task 1: Add `sessionBestCentDifference` tracking to `TrainingSession` (AC: #2, #3, #6)
  - [x] Add `sessionBestCentDifference: Double?` observable property (nil until first correct answer)
  - [x] Update `handleAnswer()` to track smallest cent difference on correct answers
  - [x] Reset session best in `stop()` (session-scoped lifecycle)
  - [x] Write unit tests for session best tracking

- [x] Task 2: Create `DifficultyDisplayView` component (AC: #1, #2, #3, #4)
  - [x] Create `Peach/Training/DifficultyDisplayView.swift`
  - [x] Display current difficulty formatted as `Current: X.X ¢` (one decimal place)
  - [x] Conditionally display session best as `Session best: X.X ¢`
  - [x] Use `.footnote` font, `.secondary` foreground style
  - [x] Left-aligned, compact layout
  - [x] No animations on value changes

- [x] Task 3: Integrate into `TrainingScreen` layout (AC: #1, #4)
  - [x] Add `DifficultyDisplayView` at the top of the body `VStack`/`HStack`
  - [x] Bind to `trainingSession.currentDifficulty` and `trainingSession.sessionBestCentDifference`
  - [x] Ensure layout does not push buttons down significantly or interfere with feedback overlay
  - [x] Verify in landscape (compact height) layout

- [x] Task 4: Accessibility (AC: #5)
  - [x] Add `.accessibilityLabel` with full text: "Current difficulty: X.X cents"
  - [x] Add `.accessibilityLabel` for session best: "Session best: X.X cents"
  - [x] Test with VoiceOver

- [x] Task 5: Verify visual integration (AC: #4)
  - [x] Test in portrait and landscape on iPhone
  - [x] Test on iPad
  - [x] Test in light and dark mode
  - [x] Verify feedback indicator overlay still renders correctly
  - [x] Verify difficulty display is visually subordinate to Higher/Lower buttons

## Dev Notes

### UX Design

**Placement:** Top of the Training Screen body, above the Higher/Lower buttons. The display sits in the "information zone" above the "action zone."

**Visual Design:**

```
┌─────────────────────────────────┐
│  Training            ⚙️  📊    │  ← nav bar (existing)
├─────────────────────────────────┤
│                                 │
│    Current: 4.2 ¢               │  ← NEW: difficulty display
│    Session best: 2.1 ¢          │     secondary text, muted color
│                                 │
├─────────────────────────────────┤
│                                 │
│         ▲  Higher               │  ← existing button
│                                 │
│                                 │
├─────────────────────────────────┤
│                                 │
│         ▼  Lower                │  ← existing button
│                                 │
│                                 │
└─────────────────────────────────┘
```

**Design Decisions:**
- **Typography**: `.footnote` for current difficulty, `.caption2` for session best. `.secondary` foreground color. Dashboard instrument reading, not a headline.
- **"¢" symbol** instead of spelling out "cents" — compact, universally understood in music theory. Same term in English and German, no localization issue.
- **Left-aligned** — reads naturally, doesn't fight for center-screen attention (that belongs to the feedback indicator overlay).
- **No animation** on number changes. Values update quietly. Animating would create a visual event every 2-3 seconds, violating the "calm" Training Screen principle.
- **Session best** only appears after the user gets at least one correct answer. Before that, only "Current: 100.0 ¢" is shown. Avoids a confusing empty state.
- **Landscape mode**: Difficulty display sits above the `HStack` of buttons, not to the side. Consistent spatial hierarchy: info on top, actions below.

**UX Constraints (from existing UX spec):**
- Training Screen must remain "radically simple" — no stats overload, no progress bars
- Display must not compete with Higher/Lower buttons (the buttons own the screen)
- Calm visual aesthetic preserved — the display is a footnote, not a headline
- Eyes-closed training unaffected — display is visual-only, no haptic or audio component

### Technical Notes

**Expose current difficulty from TrainingSession:**
- `currentComparison` is currently `private`. Add a public computed property:
  ```swift
  var currentDifficulty: Double? {
      currentComparison?.centDifference
  }
  ```
- This preserves encapsulation while exposing only the needed value.

**Session best tracking:**
- `sessionBestCentDifference: Double?` — starts nil, updated on correct answers when `centDifference < sessionBest` (or session best is nil)
- Reset in `stop()` alongside other session state

**Related Code:**
- `Peach/Training/TrainingScreen.swift` — layout integration point
- `Peach/Training/TrainingSession.swift` — `currentComparison` has cent difference, add session best tracking
- `Peach/Training/Comparison.swift` — `centDifference` property

**Source:** `docs/implementation-artifacts/future-work.md` — "Display Current Difficulty on Training Screen" (lines 318-336)

## Dev Agent Record

### Implementation Plan

- Task 1: Added `currentDifficulty` computed property and `sessionBestCentDifference` observable property to `TrainingSession`. Session best tracks smallest cent difference on correct answers and resets in `stop()`.
- Task 2: Created `DifficultyDisplayView` with `.footnote`/`.caption2` fonts, `.secondary` foreground, left-aligned, no animations. Static methods extracted for formatting and accessibility labels (testable without SwiftUI views).
- Task 3: Integrated `DifficultyDisplayView` at top of Training Screen body VStack, above the button group. Refactored duplicated `higherButton`/`lowerButton` into a single `answerButton(direction:)` method using a private `AnswerDirection` enum.
- Task 4: Accessibility labels use full words ("Current difficulty: X.X cents", "Session best: X.X cents") via `.accessibilityLabel` modifiers.
- Task 5: Layout verified — difficulty display sits above buttons in both portrait (VStack) and landscape (HStack), feedback overlay is unaffected.

### Completion Notes

All 5 tasks implemented and tested. 14 new unit tests added (8 for session best tracking, 6 for DifficultyDisplayView formatting/accessibility). Full test suite passes with no regressions. Additionally deduplicated TrainingScreen Higher/Lower button code as requested by user.

## File List

- `Peach/Training/TrainingSession.swift` — modified (added `currentDifficulty`, `sessionBestCentDifference`, session best tracking in `handleAnswer()`, reset in `stop()`)
- `Peach/Training/DifficultyDisplayView.swift` — new (difficulty display component with formatting and accessibility)
- `Peach/Training/TrainingScreen.swift` — modified (integrated DifficultyDisplayView, refactored duplicate button code into `answerButton(direction:)`)
- `PeachTests/Training/TrainingSessionDifficultyTests.swift` — new (8 tests for currentDifficulty and sessionBestCentDifference)
- `PeachTests/Training/DifficultyDisplayViewTests.swift` — new (6 tests for formatting and accessibility labels)
- `Peach/Resources/Localizable.xcstrings` — modified (added "Current: %@ ¢" and "Session best: %@ ¢" string catalog entries with German translations)

## Change Log

- 2026-02-22: Implemented "Display Current Difficulty on Training Screen" story — added difficulty display with session best tracking, accessibility labels, and refactored button duplication
- 2026-02-22: Code review fixes — replaced force unwrap with optional binding (H1), added German translations for display and accessibility strings (M2/M3), localized VoiceOver labels via Text() (M3), moved @MainActor to struct level in tests (M4), added Localizable.xcstrings to File List (M1)
