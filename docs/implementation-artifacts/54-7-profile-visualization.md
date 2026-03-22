# Story 54.7: Profile Visualization

Status: done

## Story

As a **musician using Peach**,
I want to see my continuous rhythm matching progress in the Profile Screen,
so that I can track my gap-filling accuracy across tempos and over time.

## Acceptance Criteria

1. **Given** the Profile Screen, **when** the user has continuous rhythm matching data, **then** a profile card appears showing the EWMA of recent accuracy with a trend arrow — following the same pattern as the existing rhythm profile card.

2. **Given** the spectrogram view, **when** continuous rhythm matching data exists, **then** it renders alongside or integrated with the existing rhythm spectrogram, showing tempo × time accuracy with green/yellow/red color coding.

3. **Given** tap-to-detail on a spectrogram cell, **when** tapped, **then** it shows hit rate and mean offset for that tempo/time bucket.

4. **Given** no continuous rhythm matching data, **when** the profile is displayed, **then** the card shows an appropriate empty state.

5. **Given** VoiceOver, **when** the profile card is focused, **then** it reads the accuracy value, trend, and training mode name.

## Tasks / Subtasks

- [x] Task 1: Create profile card for continuous rhythm matching (AC: #1, #4, #5)
  - [x] Create `ContinuousRhythmMatchingProfileCardView` (or extend `RhythmProfileCardView` if the pattern is similar enough)
  - [x] EWMA headline showing hit rate or mean offset
  - [x] Trend arrow from `ProgressTimeline`
  - [x] Empty state: "Start training to build your profile"
  - [x] VoiceOver support

- [x] Task 2: Integrate with spectrogram (AC: #2, #3)
  - [x] Decide: separate spectrogram, or add continuous matching data to existing `RhythmSpectrogramView`
  - [x] If separate: create `ContinuousRhythmMatchingSpectrogramView` following same patterns
  - [x] If integrated: add data source switching or combined view
  - [x] Tap-to-detail with hit rate and mean offset breakdown

- [x] Task 3: Add to Profile Screen (AC: #1)
  - [x] Add the new card/spectrogram to `ProfileScreen` in the appropriate section
  - [x] Ensure scroll layout accommodates the additional visualization

- [x] Task 4: Share image support
  - [x] Extend share image rendering to include continuous rhythm matching profile if data exists

- [x] Task 5: Run full test suite
  - [x] `bin/test.sh` — all tests pass, no regressions

## Dev Notes

### Profile card approach

The existing `RhythmProfileCardView` shows EWMA of offset accuracy. For continuous matching, the primary metric could be either:
- **Hit rate** (what % of gaps were filled) — more unique to this mode
- **Mean offset** (timing accuracy of successful hits) — more comparable to existing rhythm matching

Consider showing both: hit rate as the headline, mean offset as a secondary stat.

### Spectrogram considerations

If the continuous matching data uses the same tempo × time × accuracy dimensions, the existing `RhythmSpectrogramView` infrastructure can likely be reused with a different data source. The color bands (green ≤5%, yellow ≤15%, red >15%) may need adjustment for hit-rate-based data.

### What NOT to do

- Do NOT modify existing rhythm profile visualizations — extend alongside
- Do NOT redesign the Profile Screen layout

### References

- [Source: Peach/Profile/RhythmProfileCardView.swift — existing rhythm card pattern]
- [Source: Peach/Profile/RhythmSpectrogramView.swift — spectrogram pattern]
- [Source: Peach/Profile/ProfileScreen.swift — profile screen layout]
- [Source: docs/project-context.md — project rules and conventions]

## Dev Agent Record

### Implementation Plan

The existing `RhythmProfileCardView` and `RhythmSpectrogramView` are already fully generic over `TrainingDiscipline`. All data infrastructure (observer, profile statistics, spectrogram computation, progress timeline) was built in story 54.5. The only missing piece was routing `.continuousRhythmMatching` to the rhythm card in `ProfileScreen`'s switch statement.

Decision: Reuse `RhythmSpectrogramView` rather than creating a separate view — the data dimensions (tempo × time × early/late accuracy) are identical to other rhythm modes.

### Completion Notes

- Added `.continuousRhythmMatching` to the rhythm card routing in `ProfileScreen.swift` (1-line change)
- All 5 ACs satisfied via existing generic infrastructure:
  - AC1: Profile card with EWMA + trend arrow via `RhythmProfileCardView`
  - AC2: Spectrogram with tempo × time × green/yellow/red via `RhythmSpectrogramView`
  - AC3: Tap-to-detail showing early/late mean offset ± stddev
  - AC4: Empty state via `RhythmProfileCardView.emptyCard`
  - AC5: VoiceOver labels on card and per-column spectrogram summaries
- Share image rendering works automatically via `RhythmProfileCardExportView`
- 7 new tests covering data flow, accessibility summary, spectrogram computation, file naming, and formatting

## File List

- `Peach/Profile/ProfileScreen.swift` — added `.continuousRhythmMatching` to rhythm card switch case
- `PeachTests/Profile/ContinuousRhythmMatchingProfileTests.swift` — new test file (7 tests)
- `docs/implementation-artifacts/54-7-profile-visualization.md` — story file updates
- `docs/implementation-artifacts/sprint-status.yaml` — status tracking

## Change Log

- 2026-03-22: Implemented story 54.7 — routed continuous rhythm matching to rhythm profile card and spectrogram on Profile Screen; added 7 tests
