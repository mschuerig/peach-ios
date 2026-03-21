# Story 48.3: RhythmOffsetDetectionScreen with Dot Visualization

Status: ready-for-dev

## Story

As a **musician using Peach**,
I want a rhythm comparison screen showing dots that light up with each note and Early/Late buttons to answer,
so that I can train my ability to detect timing deviations.

## Acceptance Criteria

1. **Given** the Rhythm Comparison Screen, **when** displayed, **then** it shows a summary stat line, 4 horizontal dots (~16pt diameter, ~24pt spacing), and side-by-side Early/Late buttons below (UX-DR12).

2. **Given** the dots, **when** a note plays, **then** the corresponding dot transitions from dim (opacity 0.2) to lit (opacity 1.0) instantly, matching the percussive attack (UX-DR1). **And** dots are `.accessibilityHidden(true)`.

3. **Given** the Early/Late buttons, **when** the pattern is playing, **then** both buttons are disabled. **When** the pattern completes (awaitingAnswer state), **then** both buttons are enabled (UX-DR2).

4. **Given** the buttons, **when** displayed, **then** they show directional arrows (SF Symbols `arrow.left` / `arrow.right`) with `.borderedProminent` style, each taking half the width.

5. **Given** the feedback line, **when** the user answers, **then** it shows checkmark/cross + current difficulty as percentage (e.g., "4%") (UX-DR8).

6. **Given** VoiceOver is active, **when** buttons are focused, **then** they read "Early" and "Late" respectively. **When** feedback is shown, **then** it announces "Correct, 4 percent" or "Incorrect, 4 percent" (UX-DR9).

7. **Given** landscape orientation or iPad, **when** the screen is displayed, **then** layout adapts appropriately (UX-DR14).

## Tasks / Subtasks

- [ ] Task 1: Add observable properties to `RhythmOffsetDetectionSession` (AC: #2, #5)
  - [ ] Add `private(set) var litDotCount: Int = 0` — incremented at each note onset during `playingPattern`
  - [ ] Make `lastCompletedTrial` accessible: add `var lastCompletedOffsetPercentage: Double?` computed property
  - [ ] Add `private(set) var sessionBestOffsetPercentage: Double?` — smallest percentage answered correctly
  - [ ] Update `playNextTrial()` to animate `litDotCount`: reset to 0 before play, increment at each sixteenth-note interval using `Task.sleep(for:)` between increments
  - [ ] Reset `litDotCount` to 0 in `stop()` and when starting new trial
  - [ ] Update `sessionBestOffsetPercentage` in `handleAnswer()` when answer is correct

- [ ] Task 2: Create `RhythmDotView` subview (AC: #1, #2)
  - [ ] Create `Peach/RhythmOffsetDetection/RhythmDotView.swift`
  - [ ] `struct RhythmDotView: View` with `let litCount: Int` parameter (0-4)
  - [ ] 4 horizontal circles, ~16pt diameter, ~24pt spacing
  - [ ] Each dot: opacity 1.0 if index < litCount, else opacity 0.2
  - [ ] No animation (instant transition matching percussive attack)
  - [ ] `.accessibilityHidden(true)` on the entire view

- [ ] Task 3: Create `RhythmOffsetDetectionFeedbackView` subview (AC: #5, #6)
  - [ ] Create `Peach/RhythmOffsetDetection/RhythmOffsetDetectionFeedbackView.swift`
  - [ ] Shows checkmark/cross icon + difficulty percentage text (e.g., "4%")
  - [ ] Parameters: `isCorrect: Bool?`, `offsetPercentage: Double?`
  - [ ] VoiceOver: announces "Correct, 4 percent" or "Incorrect, 4 percent"
  - [ ] Hidden placeholder when `isCorrect == nil` (same pattern as `PitchDiscriminationFeedbackIndicator`)

- [ ] Task 4: Create `RhythmOffsetDetectionScreen` (AC: #1, #3, #4, #6, #7)
  - [ ] Create `Peach/RhythmOffsetDetection/RhythmOffsetDetectionScreen.swift`
  - [ ] `@Environment(\.rhythmOffsetDetectionSession)` — already wired in PeachApp
  - [ ] `@Environment(\.progressTimeline)` — for trend display
  - [ ] `@Environment(\.accessibilityReduceMotion)` — for feedback animation
  - [ ] `@Environment(\.verticalSizeClass)` — for landscape adaptation
  - [ ] `@State private var showHelpSheet = false`
  - [ ] Layout: `VStack` with stats header + dots + answer buttons
  - [ ] Stats header: `HStack` with summary stats (latest %, session best %, trend) + feedback indicator
  - [ ] Answer buttons: side-by-side `HStack`, each `.borderedProminent`, half width
  - [ ] Buttons: SF Symbols `arrow.left` ("Early") and `arrow.right` ("Late")
  - [ ] Buttons disabled unless `session.state == .awaitingAnswer`
  - [ ] Button action: `session.handleAnswer(direction: .early/.late)`
  - [ ] Lifecycle: `onAppear` → stop + start, `onDisappear` → stop
  - [ ] Help sheet: stops/restarts training on show/dismiss
  - [ ] Toolbar: help button + settings + profile navigation links
  - [ ] Landscape: buttons side-by-side (same in both orientations since they're already side-by-side)

- [ ] Task 5: Create rhythm-specific summary stat view (AC: #1)
  - [ ] Create `Peach/RhythmOffsetDetection/RhythmStatsView.swift` (or adapt inline in screen)
  - [ ] Display latest offset percentage and session best as "X%" format
  - [ ] Include trend arrow from `progressTimeline.trend(for: .rhythmOffsetDetection)`
  - [ ] Accessibility: "Latest result: 4 percent" / "Best result: 2 percent"
  - [ ] Hidden when no data yet (same opacity pattern as `TrainingStatsView`)

- [ ] Task 6: Add `NavigationDestination.rhythmOffsetDetection` (AC: #1)
  - [ ] Add `case rhythmOffsetDetection` to `NavigationDestination` enum
  - [ ] Add routing in `StartScreen.swift` `.navigationDestination(for:)` switch: `case .rhythmOffsetDetection: RhythmOffsetDetectionScreen()`
  - [ ] Do NOT add Start Screen button yet (that's Epic 50)

- [ ] Task 7: Add help sections for rhythm training (AC: #1)
  - [ ] Define `static let helpSections: [HelpSection]` on `RhythmOffsetDetectionScreen`
  - [ ] Sections: Goal, Controls, Feedback, Difficulty — adapted for rhythm context

- [ ] Task 8: Write tests (AC: all)
  - [ ] Test `RhythmDotView` layout parameters (static methods)
  - [ ] Test `RhythmOffsetDetectionFeedbackView` accessibility labels (static methods)
  - [ ] Test session `litDotCount` increments during pattern playback
  - [ ] Test session `sessionBestOffsetPercentage` updates on correct answer
  - [ ] Test session `lastCompletedOffsetPercentage` returns correct value
  - [ ] Test buttons enabled/disabled based on session state (static helper)

- [ ] Task 9: Run full test suite
  - [ ] `bin/test.sh` — all tests pass, no regressions

## Dev Notes

### Pattern to follow: `PitchDiscriminationScreen`

Mirror `PitchDiscriminationScreen` structure exactly. Key correspondences:

| PitchDiscrimination | RhythmOffsetDetection |
|---|---|
| `PitchDiscriminationScreen` | `RhythmOffsetDetectionScreen` |
| `PitchDiscriminationFeedbackIndicator` | `RhythmOffsetDetectionFeedbackView` |
| `TrainingStatsView` (cents) | `RhythmStatsView` (percentage) |
| Higher/Lower buttons | Early/Late buttons |
| `handleAnswer(isHigher:)` | `handleAnswer(direction: .early/.late)` |
| `pitchDiscriminationSession.state == .playingNote2 \|\| .awaitingAnswer` | `session.state == .awaitingAnswer` only |
| No dot visualization | `RhythmDotView` with `litDotCount` |

### Dot animation via `litDotCount`

The session must expose `litDotCount: Int` (0-4) so the screen can render dot states. In `playNextTrial()`, after `rhythmPlayer.play(pattern)` returns:

```swift
litDotCount = 0
let handle = try await rhythmPlayer.play(pattern)
currentHandle = handle

// Animate dots at note onset times
let sixteenthDuration = settings.tempo.sixteenthNoteDuration
for i in 0..<4 {
    guard state != .idle && !Task.isCancelled else { return }
    litDotCount = i + 1
    if i < 3 {
        try await Task.sleep(for: sixteenthDuration)
    }
}
// Wait remaining time for 4th note to ring
// (offset may shift it slightly, but duration is minimal)
try await Task.sleep(for: sixteenthDuration)
```

This replaces the current single `Task.sleep(for: pattern.totalDuration)` with incremental sleeps. The total sleep time remains the same (~4 sixteenth notes).

Reset `litDotCount = 0` in `stop()` and at the start of each new trial.

### Stats display differences from pitch

`TrainingStatsView` is hardcoded to `Cents` type. Rhythm uses percentage. Create a minimal `RhythmStatsView` or inline the stats in the screen:

- "Latest: X%" (from `session.lastCompletedOffsetPercentage`)
- "Best: X%" (from `session.sessionBestOffsetPercentage`)
- Trend arrow from `progressTimeline.trend(for: .rhythmOffsetDetection)`

Format percentages with no decimal places (e.g., "4%", not "4.0%"). Use `String(format: "%.0f%%", value)` or a formatting helper.

### Session properties to add

The session's `lastCompletedTrial` is currently `private`. Add public computed properties:

```swift
var lastCompletedOffsetPercentage: Double? {
    guard let trial = lastCompletedTrial else { return nil }
    return trial.offset.percentageOfSixteenthNote(at: trial.tempo)
}
```

For session best, track as a stored property updated in `handleAnswer()`:

```swift
private(set) var sessionBestOffsetPercentage: Double? = nil

// In handleAnswer(), after recording the trial:
if isCorrect {
    let pct = trial.offset.percentageOfSixteenthNote(at: trial.tempo)
    if let best = sessionBestOffsetPercentage {
        sessionBestOffsetPercentage = min(best, pct)
    } else {
        sessionBestOffsetPercentage = pct
    }
}
```

Reset `sessionBestOffsetPercentage = nil` in `stop()`.

### Feedback view combines icon + text

Unlike `PitchDiscriminationFeedbackIndicator` (icon only), the rhythm feedback view shows both an icon and the difficulty percentage:

```
checkmark.circle.fill  4%    ← feedback line
```

VoiceOver reads this as a single element: "Correct, 4 percent" or "Incorrect, 4 percent".

### Settings construction

`RhythmOffsetDetectionSettings` has no `from(userSettings)` factory (no user-configurable settings yet; tempo stepper is Epic 50). Use default constructor:

```swift
session.start(settings: RhythmOffsetDetectionSettings())
```

### Button layout

Both Early and Late buttons are always side-by-side (unlike pitch buttons which switch to VStack in portrait). Each takes half the width. Use `HStack(spacing: 8)` with each button getting `.frame(maxWidth: .infinity, maxHeight: .infinity)`.

- Early button: `arrow.left` SF Symbol + "Early" text
- Late button: `arrow.right` SF Symbol + "Late" text
- Both `.borderedProminent` style
- Disabled unless `session.state == .awaitingAnswer`

### Landscape/iPad adaptation (UX-DR14)

For landscape (compact height), reduce button icon and text sizes. Extract layout parameters to `static` methods for testability (same pattern as `PitchDiscriminationScreen`):

```swift
static func buttonIconSize(isCompact: Bool) -> CGFloat
static func buttonMinHeight(isCompact: Bool) -> CGFloat
static func buttonTextFont(isCompact: Bool) -> Font
```

### NavigationDestination

Add `case rhythmOffsetDetection` (no parameters). Wire in `StartScreen.swift`:

```swift
case .rhythmOffsetDetection:
    RhythmOffsetDetectionScreen()
```

Do NOT add a button to the Start Screen — that's Epic 50 (Story 50.1/50.2).

### What NOT to do

- Do NOT create a Start Screen button for rhythm (Epic 50)
- Do NOT add a tempo stepper to Settings (Epic 50, Story 50.3)
- Do NOT use `ObservableObject` / `@Published` — use `@Observable`
- Do NOT add explicit `@MainActor` annotations — redundant with default isolation
- Do NOT use Combine
- Do NOT import UIKit in view files
- Do NOT create `Utils/` or `Helpers/` directories
- Do NOT reuse `TrainingStatsView` — it's hardcoded to `Cents`
- Do NOT add animation to dot transitions — percussive attack means instant (opacity change, no `.animation`)
- Do NOT make buttons enabled during `playingPattern` — only during `awaitingAnswer`
- Do NOT re-create existing mocks (`MockRhythmPlayer`, `MockNextRhythmOffsetDetectionStrategy`, `MockRhythmOffsetDetectionObserver`)

### Project Structure Notes

New files:
```
Peach/
├── RhythmOffsetDetection/
│   ├── RhythmOffsetDetectionScreen.swift        # NEW — main screen
│   ├── RhythmDotView.swift                      # NEW — 4-dot visualization
│   ├── RhythmOffsetDetectionFeedbackView.swift  # NEW — checkmark + percentage
│   └── RhythmStatsView.swift                    # NEW — rhythm stats (optional, may inline)
│   └── RhythmOffsetDetectionSession.swift       # MODIFIED — add litDotCount, stats properties

Peach/
├── App/
│   └── NavigationDestination.swift              # MODIFIED — add .rhythmOffsetDetection case
├── Start/
│   └── StartScreen.swift                        # MODIFIED — add routing case

PeachTests/
├── RhythmOffsetDetection/
│   └── RhythmOffsetDetectionSessionTests.swift  # MODIFIED — test new properties
│   └── RhythmDotViewTests.swift                 # NEW (if layout static methods)
│   └── RhythmOffsetDetectionFeedbackViewTests.swift  # NEW (if static label methods)
```

### References

- [Source: Peach/PitchDiscrimination/PitchDiscriminationScreen.swift — primary screen pattern to mirror]
- [Source: Peach/PitchDiscrimination/PitchDiscriminationFeedbackIndicator.swift — feedback indicator pattern]
- [Source: Peach/App/TrainingStatsView.swift — stats display pattern (uses Cents, not reusable)]
- [Source: Peach/RhythmOffsetDetection/RhythmOffsetDetectionSession.swift — session state machine, needs litDotCount + stats properties]
- [Source: Peach/Core/Training/RhythmOffsetDetectionSettings.swift — settings type, use default constructor]
- [Source: Peach/App/NavigationDestination.swift — add .rhythmOffsetDetection case]
- [Source: Peach/Start/StartScreen.swift:71-84 — add routing case to .navigationDestination switch]
- [Source: Peach/App/EnvironmentKeys.swift — session already wired as @Entry]
- [Source: Peach/App/PeachApp.swift — session already created and injected]
- [Source: Peach/Core/Music/RhythmOffset.swift — percentageOfSixteenthNote(at:), direction]
- [Source: Peach/Core/Music/RhythmDirection.swift — .early, .late]
- [Source: Peach/Core/Profile/ProgressTimeline.swift — .rhythmOffsetDetection discipline for trend]
- [Source: docs/planning-artifacts/epics.md#Story 48.3 — acceptance criteria]
- [Source: docs/planning-artifacts/epics.md#UX Design Requirements — UX-DR1, UX-DR2, UX-DR8, UX-DR9, UX-DR12, UX-DR14]
- [Source: docs/project-context.md — project rules and conventions]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
