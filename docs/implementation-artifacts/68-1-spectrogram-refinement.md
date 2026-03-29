# Story 68.1: Spectrogram Refinement — More Tempo Bands, Finer Color Gradations

Status: review

## Story

As a **musician reviewing rhythm training progress**,
I want the spectrogram to show more tempo bands and a finer color gradient,
so that I can see detailed accuracy patterns instead of a coarse grid.

## Acceptance Criteria

1. **Given** the spectrogram Y-axis **When** displaying tempo bands **Then** it uses 5-7 finer-grained bands covering 40-200 BPM instead of the current 3.

2. **Given** the spectrogram cells **When** classifying accuracy **Then** it uses 5 color gradations instead of 3.

3. **Given** the threshold model **When** computing accuracy levels **Then** the hybrid floor/ceiling clamping is preserved and the 12 ms floor (touch latency) is respected.

4. **Given** continuous rhythm matching data **When** displayed in the spectrogram **Then** it produces sensible classifications without mode-specific threshold branching.

5. **Given** the full test suite **When** run on both platforms **Then** all SpectrogramDataTests are updated and pass.

## Tasks / Subtasks

- [x] Task 1: Refine `TempoRange` to support finer-grained bands (AC: #1)
  - [x] 1.1 Add new static ranges to `TempoRange` (e.g., 5-7 bands spanning 40-200 BPM) and a new `spectrogramRanges` static property, keeping `defaultRanges` unchanged for backward compatibility with session logic
  - [x] 1.2 Update `TempoRange.displayName` to cover the new ranges (localized)
  - [x] 1.3 Update `TempoRange.midpointTempo` for the new narrower ranges
  - [x] 1.4 Update `SpectrogramData.compute()` to iterate `spectrogramRanges` instead of `defaultRanges`
  - [x] 1.5 Verify rhythm discipline profile adapters continue to use `defaultRanges` for session-level grouping

- [x] Task 2: Expand `SpectrogramAccuracyLevel` to 5 gradations (AC: #2)
  - [x] 2.1 Add two additional levels (e.g., `excellent`, `precise`, `moderate`, `loose`, `erratic`) to `SpectrogramAccuracyLevel`
  - [x] 2.2 Update `SpectrogramThresholds` with 4 boundary definitions (base percent + floor/ceiling for each) while preserving the hybrid clamping model
  - [x] 2.3 Update `SpectrogramThresholds.accuracyLevel(for:tempoRange:)` to evaluate 4 thresholds instead of 2

- [x] Task 3: Update view layer for new bands and colors (AC: #2)
  - [x] 3.1 Update `RhythmSpectrogramView.cellColor(for:)` with 5 distinct colors in a perceptually linear gradient
  - [x] 3.2 Update the legend to show all 5 gradation labels
  - [x] 3.3 Update `columnAccessibilityLabel` to use the new level names
  - [x] 3.4 Verify `cellSize(columnCount:rangeCount:)` still produces usable sizes with more rows

- [x] Task 4: Validate threshold behavior for continuous rhythm matching (AC: #3, #4)
  - [x] 4.1 Confirm that the unified threshold set produces sensible classifications for both rhythmOffsetDetection and continuousRhythmMatching data across all new tempo bands
  - [x] 4.2 Ensure the 12 ms precise floor is still effective for fast tempo bands

- [x] Task 5: Update and extend tests (AC: #5)
  - [x] 5.1 Update `SpectrogramDataTests` — adapt all existing threshold tests to the new 5-level scheme
  - [x] 5.2 Add tests for new tempo band midpoints and boundary conditions
  - [x] 5.3 Add test verifying `trainedRanges` correctly filters with finer-grained ranges
  - [x] 5.4 Add test for continuous rhythm matching mode producing valid classifications
  - [x] 5.5 Update `TempoRangeTests` if `defaultRanges` count assertion changes
  - [x] 5.6 Run `bin/test.sh && bin/test.sh -p mac`

## Dev Notes

### Current Architecture

The spectrogram has three layers:

1. **Data model** (`SpectrogramData.swift`): Pure computation. Iterates `TempoRange.defaultRanges` (currently 3: slow 40-79, medium 80-119, fast 120-200) and time buckets. Each cell gets a `meanAccuracyPercent` expressed as percentage of one sixteenth note at the range's midpoint tempo.

2. **Threshold classification** (`SpectrogramThresholds`): Hybrid model using base percentages of sixteenth note duration, clamped by absolute ms floor/ceiling. Currently 2 boundaries (precise/moderate) yielding 3 levels. The 12 ms precise floor ensures the "precise" band never demands sub-touch-latency accuracy.

3. **View** (`RhythmSpectrogramView.swift`): Renders grid with Y-axis = tempo ranges (top = fastest), X-axis = time buckets. Color mapping: green/yellow/red for precise/moderate/erratic.

**Key design decision:** The finer tempo bands should be a new `spectrogramRanges` array, not a replacement of `defaultRanges`. Session-level logic (adaptive strategies, profile adapters in `RhythmOffsetDetectionDiscipline`, `ContinuousRhythmMatchingDiscipline`) groups statistics by the 3 coarse ranges via `StatisticsKey.rhythm(mode, range, direction)`. The spectrogram must re-bucket from the same underlying `MetricPoint` data using the finer ranges.

This means `SpectrogramData.compute()` needs to iterate the finer ranges and look up metrics using the coarse range that contains each fine range's midpoint, or query metrics directly from the profile using fine-grained keys. The cleaner approach is to add fine-grained `StatisticsKey` entries in the discipline definitions, but that is a larger change. The simpler approach: map each fine range to its enclosing coarse range and re-filter the coarse range's metrics by actual BPM. Since `MetricPoint` stores raw ms values (not BPM), and the spectrogram data currently filters by time bucket but not by BPM within a coarse range, the BPM information would need to come from the record-level data. Evaluate whether `MetricPoint` needs a tempo field or whether the coarse-to-fine mapping is sufficient.

### Project Structure Notes

- All threshold and data model changes stay in `Peach/Core/Profile/SpectrogramData.swift`
- Tempo range additions go in `Peach/Core/Music/TempoRange.swift`
- View changes in `Peach/Profile/RhythmSpectrogramView.swift`
- Tests in `PeachTests/Core/Profile/SpectrogramDataTests.swift` and `PeachTests/Core/Music/TempoRangeTests.swift`

### References

- [Source: Peach/Core/Profile/SpectrogramData.swift -- SpectrogramThresholds (3 levels, hybrid floor/ceiling), SpectrogramData.compute() iterates TempoRange.defaultRanges]
- [Source: Peach/Core/Music/TempoRange.swift -- slow 40-79, medium 80-119, fast 120-200, defaultRanges array of 3]
- [Source: Peach/Profile/RhythmSpectrogramView.swift -- cellColor maps 3 levels to green/yellow/red, legend shows 3 items]
- [Source: PeachTests/Core/Profile/SpectrogramDataTests.swift -- 15+ tests covering thresholds, midpoints, cell computation]
- [Source: Peach/RhythmOffsetDetection/RhythmOffsetDetectionDiscipline.swift -- uses TempoRange.defaultRanges for StatisticsKey]
- [Source: Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingDiscipline.swift -- uses TempoRange.defaultRanges for StatisticsKey]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6
### Debug Log References
### Completion Notes List
- Implemented 6 fine-grained spectrogram ranges (40-59, 60-79, 80-99, 100-119, 120-159, 160-200) via `TempoRange.spectrogramRanges`, aligned with coarse `defaultRanges` boundaries
- Added `enclosingDefaultRange` to map fine ranges to coarse ranges for data lookup
- Redesigned `SpectrogramThresholds` with `Boundary` struct; 4 boundaries yield 5 levels: excellent/precise/moderate/loose/erratic
- Updated `SpectrogramData.compute()` to iterate fine ranges, looking up metrics from the enclosing coarse range
- Updated view with 5-color gradient (teal/green/yellow/orange/red), 5 legend items, and accessibility labels
- Updated `RhythmTimingFeedbackIndicator.feedbackColor` for new accuracy levels
- Added German translations for "excellent"/"Excellent"/"loose"/"Loose"
- All 1658 iOS and 1651 macOS tests pass; 8 new tests added, multiple existing tests updated

### File List
- Peach/Core/Music/TempoRange.swift
- Peach/Core/Profile/SpectrogramData.swift
- Peach/Profile/RhythmSpectrogramView.swift
- Peach/ContinuousRhythmMatching/RhythmTimingFeedbackIndicator.swift
- Peach/Resources/Localizable.xcstrings
- PeachTests/Core/Music/TempoRangeTests.swift
- PeachTests/Core/Profile/SpectrogramDataTests.swift
- PeachTests/ContinuousRhythmMatching/RhythmTimingFeedbackIndicatorTests.swift
- PeachTests/Profile/ContinuousRhythmMatchingProfileTests.swift

## Change Log

- 2026-03-29: Story created
- 2026-03-29: Implementation complete — 6 fine tempo bands, 5 accuracy levels, all tests green on both platforms
