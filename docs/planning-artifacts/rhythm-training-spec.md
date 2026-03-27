# Rhythm Training Modes — Feature Spec

## Pre-work

- **PerceptualProfile cleanup:** Remove stale MIDI-note-indexed comparison tracking, normalize naming conventions, prepare class for multi-mode extension. Must complete before rhythm implementation.

## Mode 1: Rhythm Comparison (Judgment/Detection)

- 4 sixteenth notes played with a sharp-attack non-pitched tone at user's chosen metronome tempo
- 4th note offset early or late by current difficulty amount
- User judges: "Early" or "Late"
- Adaptive difficulty tracks early and late separately — independent Kazez-equivalent difficulty tracks, independent exercise selection per direction

## Mode 2: Rhythm Matching (Production/Accuracy)

- 3 sixteenth notes played, user taps the 4th at the correct moment
- Tap and MIDI input supported. Clap detection (audio input) documented as future enhancement
- Separate mean/stdDev tracked for early vs. late errors

## Visualization During Training

- Non-informative dots only. Dots light up in sequence as accompaniment — no positional encoding, no target zones, no ghost dots
- Mode 1: 4 dots appear with each note
- Mode 2: 3 dots with notes, 4th dot appears on user input at same fixed grid position. Color feedback (green/yellow/red) shown after answer

## Difficulty Model (2D)

- **Axis 1:** Time offset (adaptive, tracked separately for early and late at the statistics layer)
- **Axis 2:** Metronome tempo (user-selected in settings, not adaptive)
- Both axes tracked and profiled from day one
- Minimum tempo floor: ~60 BPM
- Per-tempo statistics: mean, stdDev, sampleCount, currentDifficulty — split by early/late

## Units

- **User-facing:** % of one sixteenth note duration (e.g., "4% early", "11% late")
- **Internal storage:** `tempoBPM` (Int) + `offsetMs` (Double, signed: negative=early, positive=late)
- Conversion: `percent = (offsetMs / sixteenthDurationMs) * 100`

## Perceptual Profile Visualization

- **Profile card headline:** EWMA of most recent time bucket's combined accuracy across all tempos, with trend arrow (↑ → ↓)
- **Detail chart: Spectrogram-style display**
  - X-axis: progression over time (same bucketing as pitch charts — session/day/month by density)
  - Y-axis: tempos the user has actually trained at (no empty rows for unused tempos)
  - Cell color: green (precise) → yellow (moderate) → red (erratic)
  - Empty/transparent cells where no training occurred at that tempo in that period
  - Early/late breakdown available on tap into a cell, not encoded in the spectrogram itself

## Audio Timing & Playback Model

- **Sub-millisecond precision required.** Render-callback-level scheduling using `AudioTimeStamp.mSampleTime` for sample-accurate note placement (~0.005ms jitter)
- **Unified audio model across all training modes.** Build the new sample-accurate scheduling engine as the foundation for rhythm training. Evaluate whether the existing `NotePlayer` interface can be reimplemented as a thin convenience layer on top
- A few convenience methods that delegate to "schedule now" is fine and desirable if it keeps pitch training call sites simple. If the wrapper requires contorted code, drop it — pitch training adopts the new API directly. Litmus test: does the wrapper *localize* complexity or *create* it?
- Pre-calculate all note timing before playback; no allocations or locks on audio thread
- `AVAudioSession.setPreferredIOBufferDuration(0.005)` for minimum buffer on modern devices
- Reuse SoundFontNotePlayer infrastructure with bank 2 percussion presets
- Validate actual playback jitter on target devices

## Data Storage

- `RhythmOffsetDetectionRecord`: tempoBPM, offsetMs (signed), isCorrect, timestamp
- `RhythmMatchingRecord`: tempoBPM, userOffsetMs, timestamp (inputMethod field reserved for future)
- Single record per exercise — early/late distinction derived from sign of offsetMs at the statistics layer
- Stored via `TrainingDataStore` following existing patterns

## Export/Import

- Bump to CSV format version 2
- New `trainingType` values: `rhythmOffsetDetection`, `rhythmMatching`
- Type-specific columns for rhythm fields
- V1 parser unchanged; new V2 parser handles all types (chain-of-responsibility pattern)
- Merge deduplication key: timestamp + tempoBPM + trainingType

## Architecture Decision Records

### ADR-1: Asymmetric Early/Late Statistics

**Context:** Rhythm offset detection is perceptually asymmetric — humans detect early deviations more readily than late ones at the same absolute offset.

**Decision:** Track early and late as independent statistical profiles with separate summary statistics (mean, stdDev, currentDifficulty) and independent adaptive progression. Raw data storage is unified — a single record per exercise with a signed `offsetMs` field. The early/late split happens at the statistics layer by partitioning records on the sign of the offset.

**Alternatives considered:**
- Symmetric tracking (single combined difficulty): Simpler, but masks real asymmetry. A user at 80% combined might be 95% late / 65% early.
- Symmetric tracking with post-hoc analysis: Loses the ability to adapt exercise selection per direction.

**Trade-offs accepted:** More complex adaptive algorithm (must decide which direction to serve next). Worth it because the asymmetry is the core psychoacoustic reality.

### ADR-2: User-Selected Tempo (Not Adaptive)

**Context:** Tempo is the second difficulty axis. Should the system adapt tempo automatically, or should the user choose?

**Decision:** User selects a fixed tempo in settings. The system tracks per-tempo statistics but does not change tempo between exercises.

**Alternatives considered:**
- Adaptive tempo bands: Jarring UX — breaks rhythmic entrainment, doesn't reflect real musical practice.
- Progressive tempo suggestion: Adds UX complexity; can be layered on later without architectural changes since per-tempo data is already stored.

**Trade-offs accepted:** The user might neglect certain tempo ranges. Mitigated by the spectrogram visualization making gaps visible.

### ADR-3: Spectrogram-Style Profile Visualization

**Context:** Need to display a 2D profile (tempo x accuracy) over time — effectively 3 dimensions.

**Decision:** Spectrogram display — X: time buckets, Y: trained tempos, color: green->red accuracy. Same time-bucketing logic as pitch charts.

**Alternatives considered:**
- EWMA line chart with tempo filter toggles: Requires interaction to see the full picture. Fails the "at a glance" requirement.
- Spider/radar chart: Hard to read with many tempos, doesn't show progression over time.
- Heat map with fixed tempo grid: Wastes space on untrained tempos.
- Separate line chart per tempo: Doesn't scale, loses the comparative view.

**Trade-offs accepted:** New visualization component to build (can't reuse `ProgressChartView`). Musicians already read spectrogram-like displays intuitively.

### ADR-4: Unified Sample-Accurate Audio Model

**Context:** Rhythm training requires sample-accurate scheduling. The current `NotePlayer` / `SoundFontNotePlayer` interface (imperative `startNote()` calls from the main thread) works well for pitch training but cannot deliver the timing precision rhythm needs.

**Decision:** Build the new sample-accurate scheduling model as the foundation. Design it as a lower-level engine capable of precise, pre-scheduled playback. Then evaluate whether the existing `NotePlayer` interface can be reimplemented as a thin convenience layer on top.

**Goal:** A single audio playback model serving all training modes. A thin convenience wrapper (a few methods that delegate to "schedule now") is fine and desirable if it keeps pitch training call sites simple. If the wrapper requires contorted code to bridge two fundamentally different mental models, drop it — pitch training adopts the new API directly. The litmus test is whether the wrapper *localizes* complexity or *creates* it.

**Alternatives considered:**
- Separate audio paths (keep current for pitch, new engine for rhythm): Two codepaths to maintain, divergence risk over time.
- Extend current interface (add scheduling methods to NotePlayer): Bolting precise scheduling onto an imperative fire-and-forget API leads to an incoherent abstraction.

**Trade-offs accepted:** The existing `NotePlayer` interface may not map cleanly onto the new model. The evaluation happens during implementation, not upfront.

### ADR-5: Percentage of Sixteenth Note as User-Facing Unit

**Context:** Need a unit for rhythm accuracy that is musically meaningful and tempo-independent.

**Decision:** Express offset as percentage of one sixteenth note duration. Store internally as `tempoBPM` + `offsetMs` (signed).

**Alternatives considered:**
- Raw milliseconds: Precise but musically meaningless without tempo context.
- Musical subdivision fractions ("within a 64th note"): Discrete/stepped, assumes familiarity with subdivision terminology.
- Normalized ratio (0.0-1.0): Too abstract for display.

**Trade-offs accepted:** "Percentage" is slightly less musical than subdivision language, but it's continuous, precise, intuitive to non-musicians, and trivially convertible.

### ADR-6: CSV Format Version 2 with Additive Schema

**Context:** New training types need to be stored and included in export/import.

**Decision:** Bump to format version 2. New `trainingType` discriminator values (`rhythmOffsetDetection`, `rhythmMatching`) with type-specific columns. V1 parser remains untouched; V2 parser handles all types.

**Alternatives considered:**
- Separate CSV files per training type: Complicates import/export UX and breaks unified timeline.
- V1 format extension: Violates the versioned parser contract.
- Switch to JSON: Breaks compatibility with existing exports and loses human-readability.

**Trade-offs accepted:** New V2 exports are not backwards-compatible with older app versions — acceptable for a format bump. This follows the chain-of-responsibility pattern already in place.

### ADR-7: Tap-Only Input for V1

> **Superseded by Epic 62** (2026-03): MIDI input implemented for both rhythm matching (62.4) and pitch matching (62.5). MIDI note-on serves as tap input; MIDI pitch bend drives the pitch slider. Results are recorded identically to tap input — no `inputMethod` discriminator was needed. Clap detection remains deferred.

**Context:** Mode 2 could support tap, clap (audio input), and MIDI. Each adds implementation complexity.

**Decision:** Ship with tap input only. Reserve `inputMethod` field in data model for future.

**Alternatives considered:**
- All three from day one: Clap detection requires mic permission flow, onset detection algorithm, and per-method latency calibration. High scope risk.
- Tap + MIDI: MIDI infra exists, but adds testing matrix and edge cases.

**Trade-offs accepted:** Users with MIDI controllers can't use them yet. The data model is ready for expansion when these are added.

## Future Enhancements (Documented, Not In Scope)

- Clap detection (audio input) for Mode 2
- Per-input-method latency calibration (when clap detection added)
- Subdivisions beyond sixteenth notes (eighth, triplet)
- Softer-attack sounds as additional difficulty lever
- Progressive tempo suggestions based on mastery
