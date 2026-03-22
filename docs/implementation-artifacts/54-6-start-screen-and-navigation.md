# Story 54.6: Start Screen and Navigation

Status: backlog

## Story

As a **musician using Peach**,
I want a dedicated button on the Start Screen to launch continuous rhythm matching training,
so that I can access the new training mode alongside existing modes.

## Acceptance Criteria

1. **Given** `NavigationDestination`, **when** inspected, **then** it includes a `.continuousRhythmMatching` case.

2. **Given** the Start Screen, **when** displayed, **then** a 7th training button appears in the Rhythm section labeled "Fill the Gap" (or equivalent) with an appropriate SF Symbol icon.

3. **Given** the 7th button, **when** tapped, **then** it navigates to `ContinuousRhythmMatchingScreen`.

4. **Given** the Start Screen layout, **when** displayed in portrait, **then** the Rhythm section accommodates 3 buttons (Rhythm Comparison, Rhythm Matching, Fill the Gap). **When** in landscape, **then** the grid layout adapts.

5. **Given** the `navigationDestination` modifier, **when** `.continuousRhythmMatching` is pushed, **then** `ContinuousRhythmMatchingScreen` is rendered with proper environment injection.

6. **Given** VoiceOver, **when** the button is focused, **then** it reads the training mode name with an appropriate hint.

## Tasks / Subtasks

- [ ] Task 1: Add `NavigationDestination.continuousRhythmMatching` (AC: #1, #5)
  - [ ] Add case to `NavigationDestination` enum
  - [ ] Add `navigationDestination` handler in the appropriate view
  - [ ] Route to `ContinuousRhythmMatchingScreen`

- [ ] Task 2: Add Start Screen button (AC: #2, #3, #4, #6)
  - [ ] Add `NavigationLink(value: .continuousRhythmMatching)` in the Rhythm section
  - [ ] Choose appropriate icon (e.g., `metronome.fill`, `waveform.path`, or similar)
  - [ ] Label: "Fill the Gap" (localized)
  - [ ] Training mode: `.continuousRhythmMatching` for the card
  - [ ] Ensure layout works in portrait and landscape

- [ ] Task 3: Localize strings (AC: #2, #6)
  - [ ] English: "Fill the Gap"
  - [ ] German: "Lücke füllen" (or equivalent — verify with domain context)
  - [ ] VoiceOver hint localized

- [ ] Task 4: Run full test suite
  - [ ] `bin/test.sh` — all tests pass, no regressions

## Dev Notes

### Button placement

The Start Screen currently has 6 buttons in 3 sections (Pitch, Intervals, Rhythm), each with 2 buttons. Adding a 7th button means the Rhythm section has 3 buttons. Check whether `StartScreen` layout handles odd counts in sections gracefully. If the current grid assumes pairs, this needs adaptation.

### Navigation title

The screen should have a navigation title. Use icon-based titles consistent with other training screens (Epic 53 pattern).

### What NOT to do

- Do NOT modify existing navigation destinations
- Do NOT restructure the Start Screen layout beyond accommodating the new button

### References

- [Source: Peach/Start/StartScreen.swift — Start Screen layout and button pattern]
- [Source: Peach/App/NavigationDestination.swift — navigation enum]
- [Source: Peach/App/PeachApp.swift — navigationDestination handlers]
- [Source: docs/project-context.md — project rules and conventions]
