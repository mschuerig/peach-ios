# Story: Display Current Difficulty on Training Screen

Status: draft

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

- [ ] Task 1: Add `sessionBestCentDifference` tracking to `TrainingSession` (AC: #2, #3, #6)
  - [ ] Add `sessionBestCentDifference: Double?` observable property (nil until first correct answer)
  - [ ] Update `handleAnswer()` to track smallest cent difference on correct answers
  - [ ] Reset session best in `stop()` (session-scoped lifecycle)
  - [ ] Write unit tests for session best tracking

- [ ] Task 2: Create `DifficultyDisplayView` component (AC: #1, #2, #3, #4)
  - [ ] Create `Peach/Training/DifficultyDisplayView.swift`
  - [ ] Display current difficulty formatted as `Current: X.X ¢` (one decimal place)
  - [ ] Conditionally display session best as `Session best: X.X ¢`
  - [ ] Use `.footnote` font, `.secondary` foreground style
  - [ ] Left-aligned, compact layout
  - [ ] No animations on value changes

- [ ] Task 3: Integrate into `TrainingScreen` layout (AC: #1, #4)
  - [ ] Add `DifficultyDisplayView` at the top of the body `VStack`/`HStack`
  - [ ] Bind to `trainingSession.currentDifficulty` and `trainingSession.sessionBestCentDifference`
  - [ ] Ensure layout does not push buttons down significantly or interfere with feedback overlay
  - [ ] Verify in landscape (compact height) layout

- [ ] Task 4: Accessibility (AC: #5)
  - [ ] Add `.accessibilityLabel` with full text: "Current difficulty: X.X cents"
  - [ ] Add `.accessibilityLabel` for session best: "Session best: X.X cents"
  - [ ] Test with VoiceOver

- [ ] Task 5: Verify visual integration (AC: #4)
  - [ ] Test in portrait and landscape on iPhone
  - [ ] Test on iPad
  - [ ] Test in light and dark mode
  - [ ] Verify feedback indicator overlay still renders correctly
  - [ ] Verify difficulty display is visually subordinate to Higher/Lower buttons

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
