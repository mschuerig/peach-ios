# Story 54.7: Profile Visualization

Status: backlog

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

- [ ] Task 1: Create profile card for continuous rhythm matching (AC: #1, #4, #5)
  - [ ] Create `ContinuousRhythmMatchingProfileCardView` (or extend `RhythmProfileCardView` if the pattern is similar enough)
  - [ ] EWMA headline showing hit rate or mean offset
  - [ ] Trend arrow from `ProgressTimeline`
  - [ ] Empty state: "Start training to build your profile"
  - [ ] VoiceOver support

- [ ] Task 2: Integrate with spectrogram (AC: #2, #3)
  - [ ] Decide: separate spectrogram, or add continuous matching data to existing `RhythmSpectrogramView`
  - [ ] If separate: create `ContinuousRhythmMatchingSpectrogramView` following same patterns
  - [ ] If integrated: add data source switching or combined view
  - [ ] Tap-to-detail with hit rate and mean offset breakdown

- [ ] Task 3: Add to Profile Screen (AC: #1)
  - [ ] Add the new card/spectrogram to `ProfileScreen` in the appropriate section
  - [ ] Ensure scroll layout accommodates the additional visualization

- [ ] Task 4: Share image support
  - [ ] Extend share image rendering to include continuous rhythm matching profile if data exists

- [ ] Task 5: Run full test suite
  - [ ] `bin/test.sh` — all tests pass, no regressions

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
