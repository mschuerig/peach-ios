# Story 66.8: macOS Testing and Layout Polish

Status: draft

## Story

As a **musician using Peach on macOS**,
I want the app to look and work correctly in a Mac window,
so that the experience feels polished and native rather than a phone app on a desktop.

## Acceptance Criteria

1. **Given** the macOS build **When** the app window is resized **Then** all screens adapt fluidly without layout breaks, clipping, or awkward whitespace.

2. **Given** the macOS build **When** the app window is at its minimum size **Then** all content remains usable (no controls cut off, no text truncated).

3. **Given** the Start Screen on macOS **When** displayed **Then** training cards, navigation buttons, and sparklines render correctly in a desktop-width window.

4. **Given** each training screen on macOS **When** a full training session is run **Then** all interactions work: starting, answering, feedback display, session statistics. No crashes or visual glitches.

5. **Given** the Profile Screen on macOS **When** displayed with training data **Then** charts render correctly, tap-to-expand interaction works, and the layout is appropriate for a desktop window.

6. **Given** the Settings Screen on macOS **When** all settings are changed **Then** they persist and take effect (sound source, tuning system, intervals, etc.).

7. **Given** MIDI input on macOS **When** a MIDI controller is connected **Then** MIDIKit detects the device and MIDI events flow into training sessions.

8. **Given** audio playback on macOS **When** training is active **Then** latency is acceptable for ear training (< 20ms perceived onset latency).

9. **Given** the full test suite on iOS Simulator **When** run **Then** all tests pass with zero regressions.

## Tasks / Subtasks

- [ ] Task 1: Window sizing (AC: #1, #2)
  - [ ] 1.1 Set a sensible default window size (e.g., 800x600 or content-adaptive)
  - [ ] 1.2 Set a minimum window size that keeps all content usable
  - [ ] 1.3 Test resizing from minimum to fullscreen — check all screens
  - [ ] 1.4 Use `.frame(minWidth:minHeight:)` on the `WindowGroup` content if needed

- [ ] Task 2: Layout audit per screen (AC: #3, #4, #5, #6)
  - [ ] 2.1 Start Screen — verify card grid, sparklines, navigation buttons
  - [ ] 2.2 Pitch Comparison Screen — verify Higher/Lower buttons, feedback indicator, note labels
  - [ ] 2.3 Pitch Matching Screen — verify slider interaction with mouse/trackpad, feedback display
  - [ ] 2.4 Rhythm Offset Detection Screen — verify Early/Late buttons, dot visualization
  - [ ] 2.5 Continuous Rhythm Matching Screen — verify tap button, dot visualization
  - [ ] 2.6 Profile Screen — verify charts, cold-start state, tap interaction
  - [ ] 2.7 Settings Screen — verify all form sections, sound source picker, interval selector
  - [ ] 2.8 Info Screen — verify help content, dismiss button

- [ ] Task 3: Fix layout issues found (AC: #1–#6)
  - [ ] 3.1 `verticalSizeClass` on macOS: verify it returns `.regular` — the compact layouts should not trigger
  - [ ] 3.2 Fix any spacing, alignment, or sizing issues found during audit
  - [ ] 3.3 Ensure the pitch matching slider works well with mouse drag (not just touch)

- [ ] Task 4: Audio and MIDI verification (AC: #7, #8)
  - [ ] 4.1 Test audio playback — all 4 training modes
  - [ ] 4.2 Measure perceived latency — should be < 20ms
  - [ ] 4.3 Connect a MIDI controller and test input in rhythm matching and pitch matching

- [ ] Task 5: Run full iOS test suite (AC: #9)

## Dev Notes

### Window Sizing

SwiftUI on macOS uses content-adaptive window sizing by default. If the content is designed for phone/tablet widths, the window may be too narrow. Options:
- `.frame(minWidth: 500, minHeight: 400)` on the root view
- `.defaultSize(width: 800, height: 600)` on the `WindowGroup` (macOS 13+)

### Size Classes on macOS

`verticalSizeClass` returns `.regular` on macOS. `horizontalSizeClass` returns `.regular` on macOS. This means the "regular" (non-compact) layouts will be used, which is correct — these are the iPad-like layouts that should work well in a desktop window.

### Pitch Matching Slider

The vertical pitch slider was designed for touch. Verify:
- Mouse drag works smoothly
- Scroll wheel does NOT accidentally adjust the slider
- Click-to-set works intuitively

### Known Non-Issues

- Navigation: NavigationStack works on macOS (hub-and-spoke pattern is fine)
- Charts: Swift Charts renders identically on macOS
- TipKit: Available on macOS 14+ (targeting macOS 26)
- @AppStorage: Identical cross-platform behaviour (uses UserDefaults on both)

### This Is The Last Story

This story depends on all prior stories (66.1–66.7) being complete. It's the integration test and polish pass before the macOS version is shippable.
