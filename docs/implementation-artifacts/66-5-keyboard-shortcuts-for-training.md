# Story 66.5: Keyboard Shortcuts for Training

Status: done

## Story

As a **musician using Peach on macOS**,
I want to control training with my keyboard,
so that I can train without reaching for the mouse/trackpad — matching the eyes-closed training philosophy.

## Acceptance Criteria

1. **Given** pitch comparison training is in `awaitingAnswer` state **When** the user presses the up arrow key or the localized "Higher" letter key (English: `H`, German: `H`) **Then** the "Higher" answer is submitted.

2. **Given** pitch comparison training is in `awaitingAnswer` state **When** the user presses the down arrow key or the localized "Lower" letter key (English: `L`, German: `T`) **Then** the "Lower" answer is submitted.

3. **Given** rhythm offset detection training is in `awaitingAnswer` state **When** the user presses the left arrow key or the localized "Early" letter key (English: `E`, German: `F`) **Then** the "Early" answer is submitted. **When** the user presses the right arrow key or the localized "Late" letter key (English: `L`, German: `S`) **Then** "Late" is submitted.

4. **Given** continuous rhythm matching training **When** the user presses the spacebar or return key **Then** it registers as a tap (same as tapping the tap button).

5. **Given** pitch matching training in `playingTunable` state **When** the user presses the spacebar or return key **Then** the pitch is committed (same as releasing the slider — this allows keyboard-only commit after mouse/trackpad slider adjustment). **When** the user presses the up/down arrow keys **Then** the pitch adjusts in fine steps.

6. **Given** any training screen **When** the user presses Escape **Then** training stops and returns to the Start Screen.

7. **Given** keyboard shortcuts **When** training is not in a state that accepts input (e.g., playing notes, showing feedback) **Then** the shortcuts are ignored (same guards as the UI buttons).

8. **Given** keyboard shortcuts with letter keys **When** the user holds Ctrl, Cmd, or Alt **Then** the shortcut is ignored (modifier keys indicate a system shortcut, not a training action). Shift is allowed.

9. **Given** the iOS build **When** tested **Then** behaviour is unchanged (keyboard shortcuts are additive, not replacing touch — iPad users with a hardware keyboard also benefit).

10. **Given** the full test suite **When** run **Then** all existing tests pass with zero regressions.

## Tasks / Subtasks

- [x] Task 1: Add localized shortcut key strings (AC: #1, #2, #3, #8)
  - [x] 1.1 Add localized key strings to `Localizable.xcstrings` matching the web app's conventions:
    - English: Higher=`H`, Lower=`L`, Early=`E`, Late=`L`
    - German: Higher=`H`, Lower=`T`, Early=`F`, Late=`S`
  - [x] 1.2 Read the localized key at runtime to determine the letter shortcut

- [x] Task 2: Add keyboard shortcuts to pitch comparison (AC: #1, #2, #7, #8)
  - [x] 2.1 In `PitchDiscriminationScreen`, add `.onKeyPress(.upArrow)` and `.onKeyPress(.downArrow)` modifiers
  - [x] 2.2 Add `.onKeyPress` for the localized letter keys (`H`/`L` in English, `H`/`T` in German)
  - [x] 2.3 Guard on session state being `awaitingAnswer` before calling `answerHigher()` / `answerLower()`
  - [x] 2.4 Ignore letter keys when Ctrl, Cmd, or Alt are held (AC: #8)
  - [x] 2.5 Same shortcuts work for interval pitch comparison (same screen)

- [x] Task 3: Add keyboard shortcuts to rhythm offset detection (AC: #3, #7, #8)
  - [x] 3.1 In `RhythmOffsetDetectionScreen`, add `.onKeyPress(.leftArrow)` for Early and `.onKeyPress(.rightArrow)` for Late
  - [x] 3.2 Add `.onKeyPress` for the localized letter keys (`E`/`L` in English, `F`/`S` in German)
  - [x] 3.3 Guard on appropriate session state
  - [x] 3.4 Ignore letter keys when Ctrl, Cmd, or Alt are held

- [x] Task 4: Add keyboard shortcuts to continuous rhythm matching (AC: #4, #7)
  - [x] 4.1 In `ContinuousRhythmMatchingScreen`, add `.onKeyPress(.space)` and `.onKeyPress(.return)` for tap
  - [x] 4.2 Guard on session accepting taps

- [x] Task 5: Add keyboard shortcuts to pitch matching (AC: #5, #7)
  - [x] 5.1 In `PitchMatchingScreen`, add `.onKeyPress(.space)` and `.onKeyPress(.return)` for commit
  - [x] 5.2 Add `.onKeyPress(.upArrow)` and `.onKeyPress(.downArrow)` for fine pitch adjustment
  - [x] 5.3 Guard on state being `playingTunable`

- [x] Task 6: Add Escape to stop training (AC: #6)
  - [x] 6.1 Add `.onKeyPress(.escape)` to each training screen that calls `session.stop()` and navigates back

- [x] Task 7: Verify iOS unchanged (AC: #9) and run tests (AC: #10)

## Dev Notes

### SwiftUI `.onKeyPress` Availability

`.onKeyPress` is available on macOS 14.0+ and iOS 17.0+. Since Peach targets iOS 26 / macOS 26, this API is available. On iOS, hardware keyboard users will also benefit from these shortcuts (iPad with keyboard).

### Shortcut Summary

These match the keyboard shortcuts used in the Peach web app (`../peach-web`).

| Context | Key | Letter (en) | Letter (de) | Action |
|---------|-----|-------------|-------------|--------|
| Pitch comparison | ↑ | H | H | Higher |
| Pitch comparison | ↓ | L | T | Lower |
| Rhythm offset detection | ← | E | F | Early |
| Rhythm offset detection | → | L | S | Late |
| Continuous rhythm matching | Space / Return | — | — | Tap |
| Pitch matching | ↑ / ↓ | — | — | Adjust pitch |
| Pitch matching | Space / Return | — | — | Commit pitch |
| All training | Escape | — | — | Stop and return to Start |

### Web App Reference

The localized letter shortcuts are defined in the Peach web app at:
- `../peach-web/web/locales/en/main.ftl` — English keys
- `../peach-web/web/locales/de/main.ftl` — German keys

The German mnemonics: **H**öher (Higher), **T**iefer (Lower), **F**rüh (Early), **S**pät (Late).

### Modifier Key Handling

Following the web app pattern: letter-key shortcuts are ignored when Ctrl, Cmd (Meta), or Alt are held — these indicate system shortcuts. Shift is allowed (case-insensitive matching). Arrow keys and Space/Return are always handled regardless of modifiers.

### Alternative Considered

Menu bar commands with keyboard equivalents (Cmd+↑, etc.) were considered but rejected — training shortcuts should be single-key for speed, and menu bar commands are for app-level actions (story 66.7).

## Dev Agent Record

### Implementation Plan
- Added 4 localized shortcut key entries (shortcut.higher, shortcut.lower, shortcut.early, shortcut.late) to Localizable.xcstrings with English and German translations
- Used `.onKeyPress` SwiftUI modifier on each training screen's top-level VStack
- Arrow keys use the no-argument `.onKeyPress(_ key:)` overload; letter keys use `.onKeyPress(characters: .letters, phases: .down)` with modifier filtering
- Escape key uses `@Environment(\.dismiss)` to pop the NavigationStack
- Pitch matching fine adjustment tracks `currentPitchValue` state, updated by both slider callbacks and keyboard arrows, reset on each new trial via `.onChange(of: state)`
- Fine step of 0.05 (~1 cent at the default ±20 cent range)
- State guards reuse existing `buttonsEnabled` computed properties where available

### Completion Notes
- All 7 tasks completed. 4 training screens enhanced with keyboard shortcuts
- Localized letter keys: H/L (en), H/T (de) for pitch; E/L (en), F/S (de) for rhythm — matching the web app
- Arrow keys always handled regardless of modifiers; letter keys ignore Cmd/Ctrl/Alt (Shift allowed for case-insensitive matching)
- Continuous rhythm matching: Space/Return triggers tap with no state guard (same as touch button — session internally guards)
- iOS: 1645 tests pass, macOS: 1613 tests pass — zero regressions

## File List

- `Peach/Resources/Localizable.xcstrings` — Added shortcut.higher, shortcut.lower, shortcut.early, shortcut.late entries with en/de translations
- `Peach/PitchDiscrimination/PitchDiscriminationScreen.swift` — Added keyboard shortcuts (↑↓ arrows, localized letter keys, Escape)
- `Peach/RhythmOffsetDetection/RhythmOffsetDetectionScreen.swift` — Added keyboard shortcuts (←→ arrows, localized letter keys, Escape)
- `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingScreen.swift` — Added keyboard shortcuts (Space/Return for tap, Escape)
- `Peach/PitchMatching/PitchMatchingScreen.swift` — Added keyboard shortcuts (↑↓ for fine pitch, Space/Return for commit, Escape), pitch value tracking

## Change Log

- 2026-03-28: Implemented keyboard shortcuts for all training screens (story 66.5)
