# Story 54.6: Start Screen and Navigation

Status: done

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

6. **Given** VoiceOver, **when** the button is focused, **then** it reads the training mode name via an accessibility label — consistent with existing Start Screen buttons.

## Tasks / Subtasks

- [x] Task 1: Add `NavigationDestination.continuousRhythmMatching` (AC: #1, #5)
  - [x] Add case to `NavigationDestination` enum
  - [x] Add `navigationDestination` handler in the appropriate view
  - [x] Route to `ContinuousRhythmMatchingScreen`

- [x] Task 2: Add Start Screen button (AC: #2, #3, #4, #6)
  - [x] Add `NavigationLink(value: .continuousRhythmMatching)` in the Rhythm section
  - [x] Choose appropriate icon (e.g., `metronome.fill`, `waveform.path`, or similar)
  - [x] Label: "Fill the Gap" (localized)
  - [x] Training mode: `.continuousRhythmMatching` for the card
  - [x] Ensure layout works in portrait and landscape

- [x] Task 3: Localize strings (AC: #2, #6)
  - [x] English: "Fill the Gap"
  - [x] German: "Lücke füllen" (or equivalent — verify with domain context)
  - [x] VoiceOver hint localized

- [x] Task 4: Run full test suite
  - [x] `bin/test.sh` — all tests pass, no regressions

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

## Dev Agent Record

### Completion Notes

- Added `.continuousRhythmMatching` case to `NavigationDestination` enum
- Added routing in `StartScreen.navigationDestination` switch to render `ContinuousRhythmMatchingScreen`
- Added 3rd button in Rhythm section with "Fill the Gap" label, `waveform.path` SF Symbol, `.continuousRhythmMatching` training discipline
- Layout naturally accommodates 3 buttons in both portrait (VStack) and landscape (HStack) — no grid adaptation needed since sections use VStack, not a fixed grid
- Added German localization "Lücke füllen" via `bin/add-localization.swift`
- VoiceOver accessibility label "Fill the Gap" set on the NavigationLink
- Environment injection already configured in `PeachApp.swift` (`.continuousRhythmMatchingSession` already injected)
- All 1571 tests pass, no regressions

## File List

- `Peach/App/NavigationDestination.swift` — added `.continuousRhythmMatching` case
- `Peach/Start/StartScreen.swift` — added navigation destination handler and rhythm section button
- `Peach/Resources/Localizable.xcstrings` — added "Fill the Gap" / "Lücke füllen" translation

## Change Log

- 2026-03-22: Implemented story 54.6 — added continuous rhythm matching navigation destination and start screen button
