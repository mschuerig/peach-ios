# Story 75.10: Design Decision Documentation

Status: done

## Story

As a **developer reading non-obvious code**,
I want brief comments explaining intentional design choices,
so that asymmetries and unusual patterns are not mistaken for bugs.

## Background

The walkthrough (Layers 4, 5, 6) identified several intentional design decisions that are undocumented. A developer encountering these for the first time would reasonably question whether they are bugs. Brief comments prevent that confusion.

This story is documentation-only — no behavioral changes.

**Walkthrough sources:** Layer 4 observations #2, #5; Layer 5 observation #4; Layer 6 observations #5, #6.

## Acceptance Criteria

1. **Given** `PitchMatchingProfileAdapter` **When** inspected **Then** a comment explains why it routes all results (no `isCorrect` gate): pitch matching produces a continuous cent error on every attempt, unlike pitch discrimination which has a binary correct/incorrect outcome.
2. **Given** `ContinuousRhythmMatchingScreen`'s tap button **When** inspected **Then** a comment explains the `DragGesture(minimumDistance: 0)` choice: fires on touch-down for timing accuracy, with manually added accessibility traits as a documented design tradeoff.
3. **Given** `PeachSchema.swift` **When** inspected **Then** a comment explains that CSV format versioning (currently v3) and SwiftData schema versioning (currently v1) are independent tracks — CSV versions evolved through column renames and additions before the schema was versioned.
4. **Given** `HapticFeedbackManager` **When** inspected **Then** a comment explains why it only conforms to `PitchDiscriminationObserver` and `RhythmOffsetDetectionObserver` (2 of 4): matching modes (pitch matching, continuous rhythm matching) produce continuous accuracy rather than binary correct/incorrect, so there is no "incorrect answer" haptic to fire.
5. **Given** both platforms **When** built **Then** builds succeed (no test changes needed — documentation only).

## Tasks / Subtasks

- [x] Task 1: Document profile adapter asymmetry (AC: #1)
  - [x] Add comment to `PitchMatchingProfileAdapter` explaining why all results are routed
  - [x] Optionally add a brief note to `PitchDiscriminationProfileAdapter` for contrast

- [x] Task 2: Document DragGesture timing choice (AC: #2)
  - [x] Add comment above the `DragGesture(minimumDistance: 0)` in `ContinuousRhythmMatchingScreen`
  - [x] Note the intentional `.accessibilityAddTraits(.isButton)` and `.accessibilityAction(.default)`

- [x] Task 3: Document dual versioning tracks (AC: #3)
  - [x] Add comment to `PeachSchema.swift` near the migration plan explaining the CSV/SwiftData version independence

- [x] Task 4: Document haptic feedback mode coverage (AC: #4)
  - [x] Add comment to `HapticFeedbackManager` explaining the 2-of-4 conformance

- [x] Task 5: Build both platforms (AC: #5)
  - [x] `bin/build.sh && bin/build.sh -p mac`

## Dev Notes

### Source File Locations

| File | Change |
|------|--------|
| `Peach/Training/PitchMatching/PitchMatchingProfileAdapter.swift` | Comment: routes all results |
| `Peach/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingScreen.swift` | Comment: DragGesture timing |
| `Peach/Core/Data/PeachSchema.swift` | Comment: dual versioning tracks |
| `Peach/App/Platform/HapticFeedbackManager.swift` | Comment: 2-of-4 mode coverage |

### Comment Style

Keep comments brief — 1–3 lines. Example:

```swift
// Pitch matching has no binary correct/incorrect — every attempt produces a continuous
// cent error. All results are routed to the profile, unlike PitchDiscriminationProfileAdapter
// which only routes correct answers.
```

### What NOT to Change

- No behavioral changes — documentation only
- Do not add comments to code that is already self-explanatory
- Do not add doc comments to private implementation details — inline comments are appropriate

### References

- [Source: docs/walkthrough/4-data-and-profiles.md — observations #2, #5]
- [Source: docs/walkthrough/5-composition-root.md — observation #4]
- [Source: docs/walkthrough/6-screens-and-navigation.md — observations #5, #6]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6

### Debug Log References
N/A — documentation-only story, no debugging needed.

### Completion Notes List
- Added 3-line comment to `PitchMatchingProfileAdapter` explaining why all results are routed (no isCorrect gate) — continuous cent error, not binary outcome
- Added 3-line contrast comment to `PitchDiscriminationProfileAdapter` explaining why only correct answers update the profile
- Added 4-line comment above `DragGesture(minimumDistance: 0)` in `ContinuousRhythmMatchingScreen` explaining touch-down timing accuracy and manual accessibility traits
- Added 2-line comment above `SchemaV1` in `PeachSchema.swift` explaining CSV format v3 and SwiftData schema v1 are independent versioning tracks
- Added 3-line comment above `HapticFeedbackManager` class declaration explaining 2-of-4 observer conformance (only binary-outcome modes have haptic feedback)
- Both iOS and macOS builds succeed with no new warnings

### File List
- `Peach/Training/PitchMatching/PitchMatchingProfileAdapter.swift` (modified)
- `Peach/Training/PitchDiscrimination/PitchDiscriminationProfileAdapter.swift` (modified)
- `Peach/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingScreen.swift` (modified)
- `Peach/Core/Data/PeachSchema.swift` (modified)
- `Peach/App/Platform/HapticFeedbackManager.swift` (modified)

## Change Log

- 2026-04-06: Story created from walkthrough observations
- 2026-04-07: Implemented all 5 tasks — added design decision comments to 5 source files, both platforms build clean
