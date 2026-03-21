# Story 49.2: RhythmMatchingScreen with Tap Button and Color Feedback

Status: review

## Story

As a **musician using Peach**,
I want a rhythm matching screen showing dots that light up with lead-in notes, a large Tap button, and color-coded feedback on my 4th dot,
so that I can train my ability to produce accurate timing.

## Acceptance Criteria

1. **Given** the Rhythm Matching Screen, **when** displayed, **then** it shows a summary stat line, 4 horizontal dots, and a full-width Tap button below (UX-DR13).

2. **Given** the 3 lead-in notes, **when** each plays, **then** the corresponding dot (1st, 2nd, 3rd) transitions from dim to lit instantly (UX-DR1).

3. **Given** the 4th dot position, **when** the user taps, **then** the 4th dot appears at the same fixed grid position as dots 1–3 **and** after the answer is recorded, the dot shows color feedback: green (precise), yellow (moderate), red (erratic) (FR82).

4. **Given** the Tap button, **when** displayed, **then** it is full-width, `.borderedProminent` style, "Tap" label, always enabled (UX-DR3).

5. **Given** the feedback line, **when** feedback is shown after tap, **then** it displays an arrow + signed percentage (e.g., "← 3% early" or "→ 8% late") (UX-DR8).

6. **Given** VoiceOver is active, **when** the Tap button is focused, **then** it reads "Tap" with hint "Tap at the correct moment to match the rhythm" (UX-DR10). **When** feedback is shown, **then** it announces "3 percent early" or "8 percent late".

7. **Given** landscape orientation or iPad, **when** the screen is displayed, **then** layout adapts appropriately (UX-DR14).

## Tasks / Subtasks

- [x] Task 1: Create `RhythmMatchingFeedbackView` — signed-offset feedback indicator (AC: #5, #6)
  - [x] Create `Peach/RhythmMatching/RhythmMatchingFeedbackView.swift`
  - [x] Input: `offsetPercentage: Double?` (signed: negative = early, positive = late)
  - [x] Display: arrow + signed percentage text — "← 3% early" or "→ 8% late" or "On the beat"
  - [x] Arrow symbol: `arrow.left` (early/negative), `arrow.right` (late/positive), `circle.fill` (zero)
  - [x] Color bands: green (≤5%), yellow (5–15%), red (>15%) — matching spectrogram thresholds
  - [x] Static helper methods for testability: `feedbackText()`, `arrowSymbolName()`, `feedbackColor()`, `band()`, `accessibilityLabel()`
  - [x] Accessibility: combined element reading "3 percent early" or "8 percent late" or "On the beat"
  - [x] Nil state: hidden placeholder preserving layout (same pattern as `PitchMatchingFeedbackIndicator`)
  - [x] Write tests in `PeachTests/RhythmMatching/RhythmMatchingFeedbackViewTests.swift`

- [x] Task 2: Create `RhythmMatchingDotView` — 4-dot visualization with color feedback on 4th dot (AC: #2, #3)
  - [x] Create `Peach/RhythmMatching/RhythmMatchingDotView.swift`
  - [x] Input: `litCount: Int` (0–4), `fourthDotColor: Color?` (nil = default `.primary`, set after feedback)
  - [x] Dots 1–3: same as `RhythmDotView` — dim (0.2 opacity) when unlit, full opacity when lit, `.primary` color
  - [x] Dot 4: same dim/lit behavior, but when `fourthDotColor` is non-nil, fill with that color instead of `.primary`
  - [x] Color mapping: green (precise ≤5%), yellow (moderate 5–15%), red (erratic >15%) — use static method
  - [x] Static layout constants: `dotDiameter = 16`, `dotSpacing = 24` (matching `RhythmDotView`)
  - [x] `accessibilityHidden(true)` — dots are non-informative accompaniment
  - [x] Write tests in `PeachTests/RhythmMatching/RhythmMatchingDotViewTests.swift`

- [x] Task 3: Create `RhythmMatchingScreen` — main screen assembly (AC: #1, #4, #7)
  - [x] Create `Peach/RhythmMatching/RhythmMatchingScreen.swift`
  - [x] `@Environment(\.rhythmMatchingSession)` for session access
  - [x] `@Environment(\.progressTimeline)` for trend data
  - [x] `@Environment(\.accessibilityReduceMotion)` for animation control
  - [x] `@Environment(\.verticalSizeClass)` for compact height adaptation
  - [x] Layout: `VStack` with `statsHeader` → `RhythmMatchingDotView` → Tap button
  - [x] Stats header: `RhythmStatsView` (reuse from RhythmOffsetDetection) with `latestValue: abs(session.lastUserOffsetPercentage)`, `sessionBest: nil` (no session best for matching), `trend: progressTimeline.trend(for: .rhythmMatching)`
  - [x] Feedback indicator: `RhythmMatchingFeedbackView(offsetPercentage: session.lastUserOffsetPercentage)` with opacity tied to `session.showFeedback`
  - [x] Tap button: full-width, `.borderedProminent`, label "Tap", **always enabled** (UX-DR3)
  - [x] Tap action: `session.handleTap()`
  - [x] Tap button VoiceOver: label "Tap", hint "Tap at the correct moment to match the rhythm"
  - [x] `onAppear`: `session.stop()` then `session.start(settings: RhythmMatchingSettings())`
  - [x] `onDisappear`: `session.stop()`
  - [x] Help sheet with `HelpContentView` — stop session on show, restart on dismiss
  - [x] Toolbar: Help, Settings, Profile icons (mirror `RhythmOffsetDetectionScreen`)
  - [x] Navigation title: "Rhythm" with `.inline` display mode
  - [x] Compact height adaptation: button icon size, min height, text font (static methods for testability)

- [x] Task 4: Compute `fourthDotColor` from session state (AC: #3)
  - [x] In `RhythmMatchingScreen`, derive `fourthDotColor` from `session.lastUserOffsetPercentage` when `session.showFeedback` is true
  - [x] Use `RhythmMatchingDotView.dotColor(forPercentage:)` static method
  - [x] Pass `nil` when not showing feedback (4th dot uses default color on tap, then color on feedback)

- [x] Task 5: Write help content sections (AC: #1)
  - [x] Static `helpSections: [HelpSection]` on `RhythmMatchingScreen`
  - [x] Sections: Goal ("3 clicks play, you tap the 4th"), Controls ("Tap button is always active"), Feedback ("Arrow and percentage show how close you were")
  - [x] Localized strings using `String(localized:)`

- [x] Task 6: Run full test suite
  - [x] `bin/test.sh` — all tests pass, no regressions

## Dev Notes

### Mirror `RhythmOffsetDetectionScreen` — with key differences

`RhythmMatchingScreen` follows the same structural patterns as `RhythmOffsetDetectionScreen` but with these critical differences:

| RhythmOffsetDetectionScreen | RhythmMatchingScreen |
|---|---|
| Two buttons: Early / Late | One button: Tap (full-width) |
| Buttons disabled when not `awaitingAnswer` | Button **always enabled** (UX-DR3) |
| `RhythmOffsetDetectionFeedbackView` (checkmark/X) | `RhythmMatchingFeedbackView` (arrow + signed %) |
| `RhythmDotView` (4 dots, all `.primary`) | `RhythmMatchingDotView` (4 dots, 4th gets color) |
| `sessionBest` stat shown | No `sessionBest` (no concept of "best" in matching) |
| Binary correct/incorrect | Continuous signed offset |

### Color feedback on 4th dot (FR82)

The 4th dot shows color feedback after the tap is recorded:
- **Green** (system): `abs(percentage) ≤ 5` — precise timing
- **Yellow** (system): `abs(percentage) > 5 && ≤ 15` — moderate
- **Red** (system): `abs(percentage) > 15` — erratic

These thresholds match the spectrogram color bands from UX spec. Use a static method so thresholds are defined once and testable.

### Feedback display pattern (UX-DR8)

Arrow + signed percentage, parallel to `PitchMatchingFeedbackIndicator`:
- Negative offset (early): `"← 3% early"` — `arrow.left` symbol
- Positive offset (late): `"→ 8% late"` — `arrow.right` symbol
- Zero: `"On the beat"` — `circle.fill` symbol
- Color follows same bands as dot color (green/yellow/red)

### Tap button — always enabled

Unlike the Early/Late buttons in `RhythmOffsetDetectionScreen` which are disabled when state ≠ `awaitingAnswer`, the Tap button is **always enabled** (UX-DR3). The session's `handleTap()` already guards against wrong states. The button being always enabled is a deliberate UX choice — tapping during lead-in is ignored by the session, but the button should never look disabled.

### Reuse `RhythmStatsView` from RhythmOffsetDetection

`RhythmStatsView` takes `latestValue`, `sessionBest`, and `trend`. For rhythm matching:
- `latestValue`: `abs(session.lastUserOffsetPercentage)` — use absolute value for stats display
- `sessionBest`: `nil` — rhythm matching has no "best" concept
- `trend`: `progressTimeline.trend(for: .rhythmMatching)`

### `RhythmMatchingDotView` vs `RhythmDotView`

Cannot reuse `RhythmDotView` directly because the 4th dot needs color feedback. Create `RhythmMatchingDotView` with an additional `fourthDotColor: Color?` parameter. Dots 1–3 behave identically to `RhythmDotView`.

### Session observable properties consumed by screen

From `RhythmMatchingSession` (Story 49.1):
- `state: RhythmMatchingSessionState` — not directly needed for button enable/disable (always enabled)
- `showFeedback: Bool` — controls feedback indicator opacity and 4th dot color visibility
- `litDotCount: Int` — 0–4, drives dot visualization
- `lastUserOffsetPercentage: Double?` — signed percentage for feedback display and dot color

### Help content pattern

Follow `RhythmOffsetDetectionScreen.helpSections` pattern — array of `HelpSection` structs with localized title/body. Help sheet stops session on present, restarts on dismiss.

### Compact height adaptation

Extract layout parameters to static methods (same pattern as `RhythmOffsetDetectionScreen`):
- `buttonIconSize(isCompact:)` — icon size in tap button
- `buttonMinHeight(isCompact:)` — minimum button height
- `buttonTextFont(isCompact:)` — button label font

### What NOT to do

- Do NOT create a `NavigationDestination.rhythmMatching` case — that's Epic 50
- Do NOT add a Start Screen button — that's Epic 50
- Do NOT add a tempo stepper to Settings — that's Epic 50
- Do NOT add haptic feedback on tap — rhythm matching has no binary correct/incorrect
- Do NOT disable the Tap button during lead-in — it is **always enabled** (UX-DR3)
- Do NOT use `ObservableObject` / `@Published` — use `@Observable` (already done in session)
- Do NOT add explicit `@MainActor` — redundant with default isolation
- Do NOT use Combine
- Do NOT modify `RhythmDotView` — create `RhythmMatchingDotView` separately
- Do NOT create a `from(userSettings:)` factory on `RhythmMatchingSettings` — tempo stepper doesn't exist yet

### Project Structure Notes

New files:
```
Peach/
├── RhythmMatching/
│   ├── RhythmMatchingSession.swift               # EXISTS (Story 49.1)
│   ├── RhythmMatchingScreen.swift                 # NEW
│   ├── RhythmMatchingDotView.swift                # NEW
│   └── RhythmMatchingFeedbackView.swift           # NEW

PeachTests/
├── RhythmMatching/
│   ├── RhythmMatchingSessionTests.swift           # EXISTS (Story 49.1)
│   ├── RhythmMatchingDotViewTests.swift           # NEW
│   └── RhythmMatchingFeedbackViewTests.swift      # NEW
```

No existing files modified — this story is purely additive.

### References

- [Source: Peach/RhythmOffsetDetection/RhythmOffsetDetectionScreen.swift — primary screen pattern to mirror]
- [Source: Peach/RhythmOffsetDetection/RhythmDotView.swift — dot visualization to adapt]
- [Source: Peach/RhythmOffsetDetection/RhythmOffsetDetectionFeedbackView.swift — feedback pattern (binary)]
- [Source: Peach/RhythmOffsetDetection/RhythmStatsView.swift — reuse for stats header]
- [Source: Peach/PitchMatching/PitchMatchingFeedbackIndicator.swift — signed-offset feedback pattern to mirror]
- [Source: Peach/RhythmMatching/RhythmMatchingSession.swift — session with observable state]
- [Source: Peach/App/HelpContentView.swift — help sheet component]
- [Source: Peach/Core/Profile/TrainingDisciplineConfig.swift:75 — .rhythmMatching for trend]
- [Source: docs/planning-artifacts/ux-design-specification.md:2012-2029 — Rhythm Tap Button spec]
- [Source: docs/planning-artifacts/ux-design-specification.md:2041-2047 — Color band thresholds]
- [Source: docs/planning-artifacts/ux-design-specification.md:2136-2145 — Feedback pattern: arrow + signed deviation]
- [Source: docs/planning-artifacts/epics.md#Epic 49 Story 49.2 — acceptance criteria]
- [Source: docs/project-context.md — project rules and conventions]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

### Completion Notes List

- Created `RhythmMatchingFeedbackView` with signed-offset display (arrow + percentage), 3-band color coding (green/yellow/red), and full accessibility support
- Created `RhythmMatchingDotView` with 4th-dot color feedback, matching `RhythmDotView` layout constants
- Created `RhythmMatchingScreen` mirroring `RhythmOffsetDetectionScreen` with key differences: single always-enabled Tap button, no sessionBest, continuous signed offset feedback
- fourthDotColor computed from session state using `RhythmMatchingDotView.dotColor(forPercentage:)` static method, nil when not showing feedback
- 3 help sections with localized content (Goal, Controls, Feedback)
- 29 new tests across 2 test files (20 for FeedbackView, 9 for DotView)
- All 1348 tests pass, no regressions

### File List

- Peach/RhythmMatching/RhythmMatchingFeedbackView.swift (NEW)
- Peach/RhythmMatching/RhythmMatchingDotView.swift (NEW)
- Peach/RhythmMatching/RhythmMatchingScreen.swift (NEW)
- PeachTests/RhythmMatching/RhythmMatchingFeedbackViewTests.swift (NEW)
- PeachTests/RhythmMatching/RhythmMatchingDotViewTests.swift (NEW)

## Change Log

- 2026-03-21: Implemented story 49.2 — RhythmMatchingScreen with tap button, dot visualization with 4th-dot color feedback, signed-offset feedback view, and help content
