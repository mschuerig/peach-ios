# Future Work & Technical Considerations

This document tracks design decisions to revisit, architectural improvements, and technical debt items discovered during development.

## Algorithm & Design

### Investigate Whether Seamless Playback Makes Pitch Comparison Easier

**Priority:** Medium
**Category:** Algorithm Design / Calibration
**Date Added:** 2026-02-17

**Observation:**
After implementing chain-based Kazez convergence, the algorithm quickly converges to sub-2-cent differences. However, the user consistently achieves much finer discrimination in Peach than in InTune (a reference app), where they typically plateau around 5 cents and only occasionally reach below 3 cents.

**Hypothesis:**
Peach plays the two comparison tones seamlessly (back-to-back without a gap), which may make pitch differences perceptually easier to detect than when tones are separated by silence. This could mean the difficulty levels in Peach are not directly comparable to those in apps that use gaps between tones.

**Impact:**
- Peach's difficulty numbers may overstate the user's actual pitch discrimination ability
- Comparison with other ear training apps may be misleading
- The training may be less effective if the task is artificially easier

**Investigation Areas:**
- Compare perceptual difficulty of seamless vs. gap-separated tone pairs at the same cent difference
- Research psychoacoustic literature on the effect of inter-stimulus intervals on pitch discrimination
- Consider adding a configurable gap between tones as an advanced setting
- Evaluate whether the current approach is still valuable for training (even if "easier")

**Related Code:**
- `Peach/Core/Audio/SineWaveNotePlayer.swift` — tone generation and playback
- `Peach/Training/TrainingSession.swift` — playback sequencing

---

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

### Evaluate Spectrogram Color Thresholds for Continuous Rhythm Matching

**Priority:** Low
**Category:** Algorithm Design / Calibration
**Date Added:** 2026-03-22

**Observation:**
The spectrogram color bands (green/yellow/red) use `SpectrogramThresholds.default`, which was designed for rhythm offset detection and rhythm matching. Story 54.7's dev notes flagged that thresholds "may need adjustment for hit-rate-based data." The implementation maps `meanOffsetMs` (same unit as other rhythm modes), so the current thresholds are numerically reasonable — but no explicit evaluation was performed.

**Impact:**
- If hit rate is later threaded into the spectrogram (see AC#3 of story 54.7), the thresholds will need revisiting since hit rate is a percentage, not milliseconds
- Even for offset data, continuous matching may have different accuracy distributions than discrete matching (longer sequences, fatigue effects)

**Action:**
- When hit rate is added to the profile path, define appropriate threshold bands for percentage-based data
- Consider whether offset thresholds need mode-specific tuning based on user data

**Related Code:**
- `Peach/Profile/RhythmSpectrogramView.swift` — threshold usage
- `Peach/Core/Profile/SpectrogramData.swift` — threshold definitions

---

### Low-Latency Tap Sound for Continuous Rhythm Matching

**Priority:** Medium
**Category:** Audio Architecture
**Date Added:** 2026-03-23

**Observation:**
Story 57.1 added auditory tap feedback using `AVAudioUnitSampler.startNote()` called from the MainActor. The tap sound works but has noticeable latency and jitter compared to the pre-scheduled pattern notes. The pattern notes are sample-accurate because they're dispatched inline during the render callback via `SoundFontEngine`'s pre-allocated schedule buffer. The tap sound takes a longer path: SwiftUI gesture → MainActor → `startNote()` API → audio render thread.

**Impact:**
- Tap sound feels slightly delayed relative to the actual tap, undermining the "judge timing by ear" goal
- Jitter varies depending on MainActor load, making the feedback inconsistent
- Pattern notes remain sample-accurate and unaffected

**Root Cause:**
`SoundFontEngine.scheduleEvents()` replaces the entire schedule buffer, so it can't be used to inject a single immediate event alongside the running pattern. The current `immediateNoteOn` path bypasses the schedule entirely, trading sample accuracy for non-interference.

**Potential Approach:**
Redesign `SoundFontEngine`'s scheduling to support **appending** events into the running schedule buffer (e.g., a lock-free ring buffer or a secondary "immediate" event slot checked by the render callback). This would allow tap notes to be dispatched at `currentSamplePosition` with the same sample-accurate timing as pattern notes, without disturbing the pre-scheduled batch.

**Related Code:**
- `Peach/Core/Audio/SoundFontEngine.swift` — schedule buffer, render callback
- `Peach/Core/Audio/SoundFontStepSequencer.swift` — `playImmediateNote(velocity:)`
- `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift` — `handleTap()`

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

### Add SwiftData VersionedSchema and SchemaMigrationPlan

**Priority:** Medium
**Category:** Data Infrastructure
**Date Added:** 2026-03-20

**Issue:**
The project has no `VersionedSchema` or `SchemaMigrationPlan`. All schema changes so far have been purely additive (new models), which SwiftData handles via lightweight migration. However, any future change that modifies or removes a field on an existing model will cause a runtime crash on existing installs with no recovery path.

**Impact:**
- Adding, renaming, or removing a property on any `@Model` class will fail without a migration plan
- No safety net for schema evolution — the first non-additive change will be a crash discovered at runtime

**Action:**
- Introduce `VersionedSchema` conformances for the current schema (v1)
- Add a `SchemaMigrationPlan` with lightweight migration stages
- Do this before any story that modifies existing model properties

---

### Dynamic Type Support for Grid Toggle Cells

**Priority:** Low
**Category:** Accessibility
**Date Added:** 2026-03-24

**Observation:**
`GridToggleRow` and `IntervalSelectorView` both use `.frame(width: 32, height: 32)` for toggle cells. These fixed dimensions ignore the user's Dynamic Type setting — with large accessibility font sizes, the `.caption2` text can overflow the frame and get clipped.

**Impact:**
- Users with large accessibility text sizes see clipped or illegible labels in both the gap position selector and the interval selector grid
- Pre-existing pattern inherited from `IntervalSelectorView`; `GridToggleRow` copied the same approach per spec

**Potential Approach:**
- Use `@ScaledMetric` for the frame dimensions so they scale with Dynamic Type
- Ensure the `HStack`/`Grid` layout still fits on screen at larger sizes (may need `ScrollView(.horizontal)`)

**Related Code:**
- `Peach/Settings/GridToggleRow.swift` — `.frame(width: 32, height: 32)`
- `Peach/Settings/IntervalSelectorView.swift` — same pattern at line 53

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
