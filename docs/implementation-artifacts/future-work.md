# Future Work & Technical Considerations

This document tracks design decisions to revisit, architectural improvements, and technical debt items discovered during development.

## Algorithm & Design

### Tap Latency Measurement and Compensation for Rhythm Matching

**Priority:** Low
**Category:** Algorithm Design / Calibration
**Date Added:** 2026-03-21

**Observation:**
In rhythm matching mode, the measured timing error includes a systematic late bias from touch input latency (~8–16 ms depending on device and refresh rate). The user entrains to reference clicks (which all share the same audio output latency, so the pulse is consistent), but their tap is registered late relative to when their finger physically struck the screen.

Rhythm offset detection is unaffected — all clicks traverse the same audio path, preserving relative timing, and the user's judgment is binary.

**Impact:**
- **Trends are unaffected** — a consistent bias shifts all values equally, so improvement tracking works correctly
- **Absolute values have a late bias** — a user perfectly on the beat would see ~8–16 ms late instead of 0 ms, which could erode trust in the feedback
- **Threshold classification is slightly unfair** — the bias eats into the "precise" band (12 ms floor), meaning some genuinely precise taps are classified as moderate

**Potential Approaches:**
1. **Simple:** subtract `AVAudioSession.outputLatency` (available API) from measured timing — partial correction, no user action required
2. **Better:** optional calibration tap sequence — user taps along to 8–16 clicks, system measures the systematic offset and stores it as a per-device correction
3. **Apply in `RhythmMatchingSession`** — subtract the calibrated offset before recording the timing error

**Why not now:**
The primary value of rhythm training is trend tracking (improvement over time), which is unaffected by a constant bias. The spectrogram thresholds (story 51.3) already account for device latency by setting a 12 ms floor for the "precise" band. Compensation becomes more important if Peach ever displays absolute timing values prominently or compares across devices.

---

## Data & Infrastructure

### Batch/Streaming Fetch for Discipline Registry Operations

**Priority:** Low
**Category:** Performance
**Date Added:** 2026-03-23

**Observation:**
After story 55.2 (protocol-based discipline registry), disciplines that share a record type (e.g., UnisonPitchDiscrimination and IntervalPitchDiscrimination both use `PitchDiscriminationRecord`) each fetch *all* records of that type independently and filter in-memory. This doubles the fetches for shared types during profile building and export. During merge import, `buildPitchDuplicateKeys()` is called once per pitch discipline (4 times), each fetching all PitchDiscrimination + PitchMatching records — ~12 SwiftData fetches vs ~4 previously.

**Impact:**
- Not a correctness issue — each discipline correctly filters to its own records
- Performance overhead scales with record count; negligible at current volumes but will grow
- Compounds with the long-standing concern about unbounded `fetchAll` calls (no pagination or streaming)

**Potential Approaches:**
1. **Shared fetch context:** pass a pre-fetched record cache into batch operations (`feedAllRecords`, `export`, `mergeImport`) so each record type is fetched once
2. **Streaming/batched fetch:** introduce a `FetchDescriptor` with `fetchLimit`/`fetchOffset` or SwiftData's `enumerate()` for memory-bounded iteration — addresses both the duplication and the unbounded-fetch concern in one design

**Related Code:**
- `Peach/Core/Training/TrainingDisciplineRegistry.swift` — `feedAllRecords()`
- `Peach/Core/Data/DuplicateKey.swift` — `buildPitchDuplicateKeys()`, `buildRhythmDuplicateKeys()`
- All 6 discipline conformances (`feedRecords`, `fetchAndFormatRecords`, `mergeImportRecords`)

---

### macOS Audio Device Disconnect Handling

**Priority:** Low
**Category:** Platform Support
**Date Added:** 2026-03-28

**Observation:**
`AudioSessionInterruptionMonitor` uses `AVAudioSession.routeChangeNotification` to detect audio device disconnects (e.g., headphones unplugged) on iOS and automatically stop playback. On macOS, `AVAudioSession` does not exist, so after the `#if os(iOS)` guards introduced in story 66.1, there is no equivalent device-change monitoring.

**Impact:**
- On macOS, unplugging headphones or switching audio output devices mid-training will not trigger an automatic playback stop
- Audio may route to unexpected output (e.g., built-in speakers after unplugging headphones) without the user being notified
- iOS behavior is unaffected

**Potential Approach:**
- Use CoreAudio's `AudioObjectAddPropertyListener` on `kAudioHardwarePropertyDefaultOutputDevice` to detect output device changes on macOS
- Wire the callback into `AudioSessionInterruptionMonitor` via a `#if os(macOS)` block that calls the existing `onStopRequired` closure

**Related Code:**
- `Peach/Core/Audio/AudioSessionInterruptionMonitor.swift` — `setupObservers()`, `#if os(iOS)` at line 54

---

## Visualization

### Progress Chart Band Draws Across Untrained Gaps

**Priority:** Low
**Category:** Visualization / Chart Rendering
**Date Added:** 2026-03-29

**Observation:**
The stddev band (AreaMark) in `ProgressChartView` draws continuously across time periods where no training occurred. `ProgressTimeline.allGranularityBuckets` correctly omits months/days with no data, but `lineDataWithSessionBridge(for:)` produces a flat `[LinePoint]` array with sequential integer positions, erasing gap information. Swift Charts' LineMark and AreaMark then interpolate across what are actually untrained time periods.

**Impact:**
- The confidence band visually implies the user trained during periods they didn't
- Misleading for users with sporadic training schedules
- Purely cosmetic — no data corruption or algorithmic impact

**Potential Approach:**
- Add segment identification to `LinePoint`, detect calendar gaps between consecutive buckets, and render each segment as a separate series so Swift Charts breaks the visual connection at gaps

**Related Code:**
- `Peach/Profile/ProgressChartView.swift` — `lineDataWithSessionBridge(for:)`, `stddevBand`
- `Peach/Profile/ProgressTimeline.swift` — `allGranularityBuckets`

---

## UX & Onboarding

### No First-Run Onboarding Experience

**Priority:** High
**Category:** User Experience
**Date Added:** 2026-02-18

**Issue:**
There is no guided onboarding for new users. A musician downloading Peach sees the Start Screen with an empty profile preview and can tap "Start Training" — but nothing explains what will happen, what the controls mean, or what "cents" are in the context of pitch discrimination.

**Impact:**
- Musicians may not understand the task format (two sequential tones, tap Higher/Lower)
- The concept of "cents" as a unit of pitch difference is unfamiliar to many musicians who think in terms of "sharp/flat" or "in tune/out of tune"
- The profile visualization (confidence band, log scale) is meaningless without context
- Risk of immediate abandonment if the first experience feels confusing

**Potential Solutions:**
- A brief first-run walkthrough (2-3 screens) explaining the training concept
- Contextual tooltips on first use of each screen
- Musician-friendly language throughout ("pitch accuracy" instead of "cent threshold")
- An introductory training round with wider intervals and explanatory overlays
