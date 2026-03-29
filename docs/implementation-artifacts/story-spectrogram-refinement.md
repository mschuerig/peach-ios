# Story: Spectrogram Refinement — More Tempo Bands, Finer Color Gradations

Status: draft

## Story

As a musician reviewing my rhythm training progress,
I want the spectrogram to show more tempo bands and a finer color gradient,
so that I can see detailed accuracy patterns across a wider range of tempos instead of a coarse 3×3 grid.

## Background

The current spectrogram uses 3 tempo ranges (slow 40–79, medium 80–119, fast 120–200 BPM) and 3 accuracy colors (green/yellow/red). This is too coarse to reveal meaningful patterns — a user training at 90 BPM and 110 BPM sees both lumped into "medium." Similarly, the jump from green to yellow to red hides gradual improvement.

This story also addresses the open question from future-work.md about whether continuous rhythm matching needs different thresholds than discrete modes. Since the spectrogram is shared across all rhythm disciplines, the refined thresholds should work for both.

**Source:** future-work.md "Evaluate Spectrogram Color Thresholds for Continuous Rhythm Matching" + user request for more tempo bands and colors.

## Acceptance Criteria

1. **More tempo bands:** Replace the 3 coarse ranges with finer-grained bands (e.g., 5–7 bands covering 40–200 BPM). Each band should be narrow enough that tempos within it feel perceptually similar. The `TempoRange` enum/type and its `range(for:)` lookup must be updated, and all existing consumers must continue to work.

2. **More color gradations:** Replace the 3-color scheme (green/yellow/red) with a finer gradient (e.g., 5 levels). The visual progression should communicate accuracy intuitively — from excellent through poor. The `SpectrogramAccuracyLevel` enum and `SpectrogramThresholds` must be updated with new breakpoints.

3. **Threshold floor/ceiling model preserved:** The hybrid model (base percentage clamped by absolute ms floor and ceiling) must be retained. New threshold breakpoints should respect the 12 ms floor (touch latency) and scale sensibly across all tempo bands.

4. **Continuous rhythm matching compatibility:** The refined thresholds must produce sensible classifications for continuous rhythm matching data (which tends toward tighter offsets from longer sequences). No mode-specific threshold branching — one unified threshold set.

5. **Existing tests updated:** All `SpectrogramDataTests` must be updated to reflect the new bands and thresholds. No test deletions — adapt assertions to new values.

6. **Visual regression check:** The spectrogram view must render correctly with the new band count. Cell sizing logic (`max(20, min(36, ...))`) may need adjustment for more rows. Y-axis labels must remain readable.

7. **Accessibility:** VoiceOver column summaries must use the new accuracy level names.

## Tasks / Subtasks

- [ ] Task 1: Define new tempo bands (AC: #1)
  - [ ] Decide on band boundaries (e.g., 40–59, 60–79, 80–99, 100–119, 120–149, 150–200 or similar)
  - [ ] Update `TempoRange` in `Peach/Core/Music/TempoRange.swift` — cases, `bpmRange`, `midpointBPM`, `range(for:)` lookup
  - [ ] Verify all `TempoRange` consumers compile and behave correctly

- [ ] Task 2: Define new color gradations and thresholds (AC: #2, #3, #4)
  - [ ] Add new cases to `SpectrogramAccuracyLevel` in `SpectrogramData.swift`
  - [ ] Define new threshold breakpoints in `SpectrogramThresholds` (base percentages, floors, ceilings for each level)
  - [ ] Update `accuracyLevel(meanPercent:sixteenthNoteMs:)` classification logic
  - [ ] Update `cellColor(for:)` in `RhythmSpectrogramView.swift` with new colors

- [ ] Task 3: Update spectrogram view layout (AC: #6, #7)
  - [ ] Adjust cell sizing for more rows
  - [ ] Verify Y-axis label readability with more bands
  - [ ] Update VoiceOver summary text with new level names

- [ ] Task 4: Update tests (AC: #5)
  - [ ] Update `SpectrogramDataTests` threshold assertions for new breakpoints
  - [ ] Update tempo range tests if any exist
  - [ ] Add test cases for new accuracy levels and band boundaries

## Dev Notes

### Architecture — This Is Mostly Constants

The spectrogram system is well-parameterized. The core changes are:

1. **`TempoRange`** (`Peach/Core/Music/TempoRange.swift`): An enum with 3 cases. Add more cases, update `bpmRange`, `midpointBPM`, `sixteenthNoteDuration`, and the static `range(for:)` method. The `Comparable` conformance sorts by midpoint — ensure new cases maintain correct ordering.

2. **`SpectrogramThresholds`** (`Peach/Core/Profile/SpectrogramData.swift`, lines 22–44): Currently has `preciseBase`/`moderateBase` pairs. Expand to more levels. Each level needs a base percent, floor ms, and ceiling ms.

3. **`SpectrogramAccuracyLevel`** (`Peach/Core/Profile/SpectrogramData.swift`): Currently `.precise`, `.moderate`, `.erratic`. Add intermediate levels.

4. **`cellColor(for:)`** (`Peach/Profile/RhythmSpectrogramView.swift`, lines 211–218): Map new levels to colors.

### Consumers of `TempoRange` That Must Be Verified

- `SpectrogramData.compute()` — groups metrics by tempo range
- `PerceptualProfile.Builder` / `feedRecords()` in rhythm disciplines — uses `TempoRange.range(for:)` to bucket records
- `RhythmSpectrogramView` — renders rows per trained range
- `TrainingDisciplineConfig` — stores trained tempo ranges
- Any tests using `TempoRange` values

### What NOT to Change

- The `RhythmOffset` domain model, store adapters, or CSV import/export — those are unrelated
- The `ProgressTimeline` bucketing (X-axis) — only the Y-axis and colors change
- The floor/ceiling clamping formula — keep the mechanism, just add more breakpoints

### Project Structure Notes

- All threshold constants stay in `Peach/Core/Profile/SpectrogramData.swift`
- All color mappings stay in `Peach/Profile/RhythmSpectrogramView.swift`
- Tempo bands stay in `Peach/Core/Music/TempoRange.swift`
- No new files needed

### References

- [Source: docs/implementation-artifacts/future-work.md#Evaluate Spectrogram Color Thresholds]
- [Source: Peach/Core/Profile/SpectrogramData.swift — threshold definitions]
- [Source: Peach/Core/Music/TempoRange.swift — tempo range enum]
- [Source: Peach/Profile/RhythmSpectrogramView.swift — color mapping and cell layout]
- [Source: PeachTests/Core/Profile/SpectrogramDataTests.swift — 17 existing tests]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
