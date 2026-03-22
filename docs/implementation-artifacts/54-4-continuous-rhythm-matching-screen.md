# Story 54.4: Continuous Rhythm Matching Screen

Status: done

## Story

As a **musician using Peach**,
I want a training screen with four dots that show my position in the beat cycle and which note is the gap, plus a tap button to fill the gap,
so that I can train my rhythmic timing in a continuous, groove-locked flow.

## Acceptance Criteria

1. **Given** the Continuous Rhythm Matching Screen, **when** displayed, **then** it shows four horizontal dots and a full-width Tap button below (FR111).

2. **Given** the four dots, **when** the sequencer advances through steps, **then** the current step's dot is highlighted (filled/bright), and dots for completed steps dim back down — the highlight sweeps through the four positions cyclically.

3. **Given** the gap position for the current cycle, **when** the dots are displayed, **then** the gap dot is rendered as an outline circle while non-gap dots are filled. The gap outline updates at the start of each cycle, not mid-cycle (FR111).

4. **Given** the step-1 dot, **when** displayed, **then** it is visually bolder/larger than dots 2–4, reflecting the beat-1 accent (FR111).

5. **Given** the Tap button, **when** displayed, **then** it is full-width, `.borderedProminent`, always visually active — never disabled or dimmed (FR108).

6. **Given** the user taps, **when** inside the evaluation window, **then** brief visual feedback appears on the gap dot (green/yellow/red color based on timing accuracy, same bands as existing rhythm matching).

7. **Given** the user taps, **when** outside the evaluation window, **then** no visual feedback occurs — the tap is silently ignored by the session.

8. **Given** a trial completes (16 cycles), **when** the result is available, **then** a stats summary updates showing the trial's hit rate and mean offset.

9. **Given** `onAppear`, **when** the screen loads, **then** the step sequencer starts immediately — no waiting for user interaction.

10. **Given** `onDisappear` or interruption, **when** the screen exits, **then** the session stops and any incomplete trial is discarded.

11. **Given** VoiceOver is active, **when** the Tap button is focused, **then** it reads "Tap" with hint "Tap to fill the gap in the rhythm".

12. **Given** landscape orientation or iPad, **when** the screen is displayed, **then** layout adapts appropriately.

## Tasks / Subtasks

- [x] Task 1: Create `ContinuousRhythmMatchingDotView` (AC: #2, #3, #4)
  - [x] Create `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingDotView.swift`
  - [x] Four dots in a horizontal row
  - [x] Dot 1 larger/bolder than dots 2–4 (e.g., diameter 20 vs 16, or heavier stroke)
  - [x] Active step: highlighted (full opacity, filled)
  - [x] Gap step: outline circle (stroke only, no fill) when not the active step; when active and gap, show outline at full opacity
  - [x] Non-gap, non-active steps: filled at low opacity (0.2)
  - [x] Gap outline updates only at cycle boundary (driven by session's `currentGapPosition`)
  - [x] Optional: feedback color on gap dot after a hit (green/yellow/red, brief flash)
  - [x] `accessibilityHidden(true)` — dots are visual accompaniment
  - [x] Write tests in `PeachTests/ContinuousRhythmMatching/ContinuousRhythmMatchingDotViewTests.swift`

- [x] Task 2: Create `ContinuousRhythmMatchingScreen` (AC: #1, #5, #8, #9, #10, #11, #12)
  - [x] Create `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingScreen.swift`
  - [x] `@Environment(\.continuousRhythmMatchingSession)` for session access
  - [x] Layout: `VStack` with stats header → `ContinuousRhythmMatchingDotView` → Tap button
  - [x] Tap button: full-width, `.borderedProminent`, "Tap" label, always active
  - [x] Tap action: `session.handleTap()`
  - [x] Stats area: show latest trial hit rate and mean offset (from `session.lastTrialResult`)
  - [x] Cycle progress indicator: subtle display of current cycle count within trial (e.g., "4/16")
  - [x] `onAppear`: `session.start(settings: ContinuousRhythmMatchingSettings.from(userSettings))`
  - [x] `onDisappear`: `session.stop()`
  - [x] VoiceOver: Tap button label "Tap", hint "Tap to fill the gap in the rhythm"
  - [x] Compact height adaptation (same pattern as `RhythmMatchingScreen`)
  - [x] Help sheet with stop/restart behavior
  - [x] Toolbar: Help, Settings, Profile icons

- [x] Task 3: Create feedback overlay for gap hits (AC: #6, #7)
  - [x] When session reports a hit: briefly color the gap dot green/yellow/red
  - [x] Use same color bands as `RhythmMatchingDotView`: green (≤5%), yellow (5–15%), red (>15%)
  - [x] Feedback duration: brief flash (~200ms), not the full 400ms used in discrete mode
  - [x] On miss or out-of-window tap: no visual change

- [x] Task 4: Write help content (AC: #11)
  - [x] Static `helpSections: [HelpSection]`
  - [x] Sections: Goal ("A continuous stream of notes plays — fill the gap"), Controls ("Tap when the outlined note should sound"), Feedback ("Dot colors show timing accuracy")
  - [x] Localized strings

- [x] Task 5: Run full test suite
  - [x] `bin/test.sh` — all tests pass, no regressions

## File List

- `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingDotView.swift` (new)
- `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingScreen.swift` (new)
- `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift` (modified — added feedback state)
- `Peach/Core/Training/CompletedContinuousRhythmMatchingTrial.swift` (modified — added computed properties)
- `PeachTests/ContinuousRhythmMatching/ContinuousRhythmMatchingDotViewTests.swift` (new)
- `PeachTests/ContinuousRhythmMatching/ContinuousRhythmMatchingScreenTests.swift` (new)
- `PeachTests/Core/Training/CompletedContinuousRhythmMatchingTrialTests.swift` (modified — added tests)

## Dev Agent Record

### Implementation Plan
- Created `ContinuousRhythmMatchingDotView` with four-dot horizontal layout: beat-1 dot is 22pt (vs 16pt for others), gap dot rendered as outline, active step at full opacity, inactive at 0.2. Feedback color flash on gap dot uses same bands as `RhythmMatchingFeedbackView`.
- Created `ContinuousRhythmMatchingScreen` following `RhythmMatchingScreen` pattern: VStack with stats header, dot view, full-width tap button. Session starts on `onAppear`, stops on `onDisappear`. Help sheet stops/restarts session. Toolbar has Help, Settings, Profile icons.
- Added `lastHitOffsetPercentage`, `showFeedback`, and 200ms auto-clear feedback to `ContinuousRhythmMatchingSession`.
- Added `hitCount`, `hitRate`, `meanOffsetPercentage`, `meanOffsetMs` computed properties to `CompletedContinuousRhythmMatchingTrial`.
- Stats header shows hit rate and mean offset from last trial, plus cycle progress (e.g., "4/16").

### Completion Notes
All 5 tasks completed. 1558 tests pass (16 new). All 12 acceptance criteria satisfied.

## Change Log

- 2026-03-22: Implemented ContinuousRhythmMatchingScreen and ContinuousRhythmMatchingDotView with feedback overlay and help content

## Dev Notes

### Dot visualization — step sequencer mental model

The four dots represent the four steps of the sequencer. Unlike the existing `RhythmDotView` (which lights up sequentially and resets), these dots cycle continuously:

```
Cycle N:   [●] [○] [●] [●]    ← gap at position 2
Step 1:    [◉] [○] [·] [·]    ← step 1 highlighted (bold, accent)
Step 2:    [·] [○] [·] [·]    ← step 2 highlighted — but position 2 is the gap, so it's an outlined circle at full opacity
Step 3:    [·] [○] [●] [·]    ← step 3 highlighted
Step 4:    [·] [○] [·] [●]    ← step 4 highlighted
Cycle N+1: [●] [●] [●] [○]    ← gap moves to position 4 at cycle boundary
```

### No feedback line / arrow

Unlike `RhythmMatchingScreen` which shows "← 3% early" text feedback, the continuous mode uses only dot-color feedback. The text would be too distracting in a continuous flow. The stats area shows aggregate data per trial, not per-gap feedback.

### Immediate start, no lead-in

The sequencer starts on `onAppear`. The first cycle plays immediately. The user can start tapping as soon as they hear and see the pattern. No separate "listen" phase — the accent on beat 1 orients the user naturally.

### What NOT to do

- Do NOT reuse `RhythmMatchingDotView` — the visual behavior is fundamentally different (continuous cycling vs. sequential light-up)
- Do NOT add navigation destination — that's Story 54.6
- Do NOT show per-gap text feedback — only dot colors and aggregate stats
- Do NOT add haptic feedback — no binary correct/incorrect in this mode
- Do NOT use `ObservableObject` / `@Published` / Combine

### References

- [Source: Peach/RhythmMatching/RhythmMatchingScreen.swift — existing screen pattern to reference]
- [Source: Peach/RhythmMatching/RhythmMatchingDotView.swift — existing dot view for reference]
- [Source: Peach/RhythmMatching/RhythmMatchingFeedbackView.swift — color band thresholds]
- [Source: Peach/RhythmOffsetDetection/RhythmStatsView.swift — stats display pattern]
- [Source: Peach/App/HelpContentView.swift — help sheet component]
- [Source: docs/project-context.md — project rules and conventions]
