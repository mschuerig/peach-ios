# Story 51.3: Spectrogram Accuracy Thresholds — Research and Calibration

Status: review

## Story

As a **musician using Peach**,
I want the spectrogram accuracy thresholds to reflect what is actually achievable and perceptually meaningful at each tempo,
so that the color feedback (precise/moderate/erratic) gives me honest, encouraging, and musically valid information about my timing.

## Problem Statement

The current `SpectrogramThresholds` use fixed percentages of a sixteenth note (5% precise, 15% moderate). At fast tempos this produces thresholds below human motor resolution and even below device input latency:

| Tempo | Precise < (ms) | Moderate < (ms) | Reality |
|-------|----------------|-----------------|---------|
| 80 BPM | 9.4 | 28.1 | Borderline achievable for pros |
| 120 BPM | 6.25 | 18.75 | Below reliable motor precision |
| 160 BPM | 4.7 | 14.1 | Below touchscreen latency |
| 200 BPM | 3.75 | 11.25 | Physically impossible on a phone |

At slow tempos (40–60 BPM), the thresholds may be overly generous (37–56 ms for "moderate").

## Acceptance Criteria

1. **Given** research into timing precision, **when** thresholds are defined, **then** they account for the distinction between:
   - **Perception (JND)**: how small a timing deviation a listener can detect
   - **Production — single event**: tapping a single note on the beat (Peach's current rhythm offset detection mode)
   - **Production — steady-state entrainment**: tapping a continuous sequence of regular subdivisions (Peach's current rhythm matching mode, and the general drumming literature)

2. **Given** calibrated thresholds, **when** applied at any tempo from 40–200 BPM, **then** "precise" is achievable by a skilled musician on a mobile device, and "erratic" genuinely indicates poor timing — not device limitations.

3. **Given** the two rhythm training modes (offset detection = single tap, rhythm matching = tap sequence), **when** thresholds are evaluated, **then** the design explicitly decides whether both modes should share the same thresholds or whether production-mode differences warrant separate calibration.

4. **Given** finalized threshold values, **when** the story is complete, **then** `SpectrogramThresholds` is updated in code and the PRD is updated to document the chosen thresholds with rationale.

## Tasks / Subtasks

- [x] Task 1: Research — perception vs. production timing precision
  - [x] Gather published data on asynchrony JND (just-noticeable difference) for timing perception across tempo ranges
  - [x] Gather published data on single-event production precision (tap-to-beat synchronization) for professional, trained, and amateur musicians
  - [x] Gather published data on steady-state entrainment precision (continuous tapping / drumming) — note that variance is typically lower in steady state due to error correction
  - [x] Document iOS touchscreen input latency as a hard floor for any production threshold
  - [x] Summarize findings in a research section in this story's Dev Notes

- [x] Task 2: Design threshold model
  - [x] Decide between: (a) hybrid floor/ceiling on current relative model, (b) fully absolute thresholds, (c) per-mode thresholds (offset detection vs. rhythm matching)
  - [x] Define precise/moderate/erratic boundaries with rationale tied to research findings
  - [x] Validate that thresholds produce meaningful color distributions across the full 40–200 BPM range
  - [x] Document the decision and rationale

- [x] Task 3: Implement calibrated thresholds
  - [x] Update `SpectrogramThresholds` in `Peach/Core/Profile/SpectrogramData.swift`
  - [x] Update any tests in `SpectrogramDataTests.swift` that assert on threshold behavior
  - [x] Verify spectrogram rendering with new thresholds across tempo ranges

- [x] Task 4: Update PRD
  - [x] Update UX-DR4 in `docs/planning-artifacts/ux-design-specification.md` with the calibrated threshold values and rationale
  - [x] Reference the research findings that informed the decision

- [x] Task 5: Run full test suite
  - [x] `bin/test.sh` — zero regressions (1384 passed)

## Dev Notes

### Key distinction: perception vs. production

The literature distinguishes:

- **Perception (JND for asynchrony)**: ~10 ms under ideal lab conditions (Madison 2001, Madison & Merker 2004), ~15–25 ms in musical context. This sets a floor for offset detection thresholds — there's no point calling a deviation "erratic" if the user literally cannot hear it.
- **Single-event production**: Tapping one note to a beat. Higher variance than steady-state because there's no error-correction loop. Relevant to Peach's **rhythm offset detection** mode.
- **Steady-state entrainment**: Tapping a continuous sequence. Lower variance due to phase correction (each tap adjusts the next). Relevant to Peach's **rhythm matching** mode and to most drumming studies (Butterfield 2010, Friberg & Sundström 2002).

Professional drummers in steady-state: ~10–20 ms SD. Single-event production is typically worse.

### iOS input latency floor

Touchscreen input latency on iOS is ~8–16 ms depending on device and refresh rate. Any threshold below ~10 ms is measuring device jitter, not musical skill. This is a hard floor.

### Research summary (Task 1)

**Perception (JND — Just-Noticeable Difference for asynchrony):**
- Under ideal lab conditions: ~10 ms (Madison 2001, Madison & Merker 2004)
- In musical context with complex sounds: ~15–25 ms (Friberg & Sundström 2002)
- JND is relatively stable across the 40–200 BPM range — it is an absolute property of the auditory system, not tempo-relative
- Below ~10 ms, asynchrony is imperceptible; classifying it as "erratic" would be misleading

**Single-event production (tap-to-beat synchronization):**
- Professional musicians: SD ≈ 15–30 ms (Repp 2005, Repp & Su 2013)
- Trained/intermediate musicians: SD ≈ 25–40 ms
- Amateur/untrained: SD ≈ 40–60 ms
- Higher variance than steady-state due to absence of error-correction loop
- Relevant to Peach's rhythm offset detection mode

**Steady-state entrainment (continuous tapping / drumming):**
- Professional drummers: SD ≈ 10–20 ms (Butterfield 2010, Friberg & Sundström 2002)
- Trained musicians: SD ≈ 15–30 ms (Repp & Su 2013)
- Amateur: SD ≈ 30–50 ms
- Lower variance due to phase correction (each tap adjusts the next)
- Relevant to Peach's rhythm matching mode

**iOS touchscreen input latency (hard floor):**
- ProMotion (120 Hz) devices: ~8 ms
- Standard (60 Hz) devices: ~16 ms
- Effective hard floor for any production threshold: ~10–12 ms
- Any threshold below this measures device jitter, not musical skill

**Current model failure analysis (5% precise, 15% moderate):**

| Tempo | 16th (ms) | Precise < (ms) | Moderate < (ms) | Verdict |
|-------|-----------|-----------------|-----------------|---------|
| 40 BPM | 375 | 18.8 | 56.3 | Moderate ceiling too generous |
| 80 BPM | 187.5 | 9.4 | 28.1 | Precise at device latency boundary |
| 120 BPM | 125 | 6.3 | 18.8 | Precise below touch latency |
| 160 BPM | 93.75 | 4.7 | 14.1 | Both near/below human limits |
| 200 BPM | 75 | 3.8 | 11.3 | Both below human motor resolution |

### Preliminary recommendation from music domain expert (Adam)

Hybrid approach with floor and ceiling:
```
precise  = clamp(sixteenthMs * percentage, min: floor, max: ceiling)
moderate = clamp(sixteenthMs * percentage, min: floor, max: ceiling)
```

### Threshold design decision (Task 2)

**Model chosen: (a) Hybrid floor/ceiling on relative model.**

Both rhythm modes share the same thresholds. The spectrogram shows timing quality per tempo band — different color scales per mode would confuse the user. Mode separation is already handled by `TrainingDiscipline`.

**Parameters:**
- Base percentages: precise = 8%, moderate = 20% of sixteenth note duration
- Absolute floors: precise = 12 ms, moderate = 25 ms
- Absolute ceilings: precise = 30 ms, moderate = 50 ms

**Formula:**
```
thresholdMs = clamp(sixteenthMs × basePercent / 100, floor, ceiling)
effectivePercent = (thresholdMs / sixteenthMs) × 100
```

**Rationale for each parameter:**
- **8% precise base** — at medium tempos (100–120 BPM) produces 12–15 ms, matching pro drummer steady-state SD
- **20% moderate base** — at medium tempos produces 30–37 ms, matching trained-musician timing
- **12 ms precise floor** — above iOS touch latency (~8–16 ms), ensures "precise" is always achievable
- **25 ms moderate floor** — near musical-context JND (~15–25 ms), ensures meaningful perceptibility
- **30 ms precise ceiling** — good drummer's SD; prevents overly generous thresholds at slow tempos
- **50 ms moderate ceiling** — trained-amateur boundary; above this, timing is genuinely erratic

**Validation (all tempos produce meaningful color distributions):**

| Tempo | 16th (ms) | Precise < (ms) | Moderate < (ms) | Active clamp |
|-------|-----------|-----------------|-----------------|--------------|
| 40 BPM | 375 | 30.0 | 50.0 | moderate ceiling |
| 80 BPM | 187.5 | 15.0 | 37.5 | none |
| 120 BPM | 125 | 12.0 | 25.0 | both floors |
| 200 BPM | 75 | 12.0 | 25.0 | both floors |

### Current implementation

```swift
// Peach/Core/Profile/SpectrogramData.swift
struct SpectrogramThresholds: Sendable {
    let preciseUpperBound: Double   // percentage of sixteenth note
    let moderateUpperBound: Double  // percentage of sixteenth note

    static let `default` = SpectrogramThresholds(preciseUpperBound: 5.0, moderateUpperBound: 15.0)
}
```

### References

- [Source: Peach/Core/Profile/SpectrogramData.swift — SpectrogramThresholds, msToPercent]
- [Source: Peach/Core/Music/TempoBPM.swift — sixteenthNoteDuration]
- [Source: Peach/Core/Music/TempoRange.swift — slow/medium/fast ranges, midpointTempo]
- [Source: docs/planning-artifacts/ux-design-specification.md — UX-DR4 threshold spec]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None — clean implementation.

### Completion Notes List

- Researched timing perception (JND ~10–25ms), single-event production (SD ~15–60ms by skill), steady-state entrainment (SD ~10–50ms by skill), and iOS touch latency (~8–16ms)
- Designed hybrid floor/ceiling threshold model: base percentages (8%/20%) clamped to absolute floors (12ms/25ms) and ceilings (30ms/50ms)
- Both rhythm modes share thresholds — mode distinction captured by TrainingDiscipline, not color scale
- Redesigned `SpectrogramThresholds` from fixed percentages to tempo-aware model with `accuracyLevel(for:tempoRange:)` method
- Updated `RhythmSpectrogramView` call sites to pass `tempoRange`
- Rewrote threshold tests to validate floor/ceiling behavior across slow, medium, and fast tempo ranges
- Updated UX-DR4 in PRD with calibrated values, formula, and research rationale
- Full test suite: 1384 passed, zero regressions

### Change Log

- 2026-03-21: Implemented calibrated spectrogram thresholds with hybrid floor/ceiling model (story 51.3)

### File List

- Peach/Core/Profile/SpectrogramData.swift (modified — redesigned SpectrogramThresholds)
- Peach/Profile/RhythmSpectrogramView.swift (modified — pass tempoRange to accuracyLevel)
- PeachTests/Core/Profile/SpectrogramDataTests.swift (modified — new threshold tests)
- docs/planning-artifacts/ux-design-specification.md (modified — UX-DR4 calibrated thresholds)
- docs/implementation-artifacts/51-3-spectrogram-accuracy-thresholds.md (modified — story file)
- docs/implementation-artifacts/sprint-status.yaml (modified — status tracking)
