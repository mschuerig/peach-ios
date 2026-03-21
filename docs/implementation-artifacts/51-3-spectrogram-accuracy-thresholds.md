# Story 51.3: Spectrogram Accuracy Thresholds — Research and Calibration

Status: ready-for-dev

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

- [ ] Task 1: Research — perception vs. production timing precision
  - [ ] Gather published data on asynchrony JND (just-noticeable difference) for timing perception across tempo ranges
  - [ ] Gather published data on single-event production precision (tap-to-beat synchronization) for professional, trained, and amateur musicians
  - [ ] Gather published data on steady-state entrainment precision (continuous tapping / drumming) — note that variance is typically lower in steady state due to error correction
  - [ ] Document iOS touchscreen input latency as a hard floor for any production threshold
  - [ ] Summarize findings in a research section in this story's Dev Notes

- [ ] Task 2: Design threshold model
  - [ ] Decide between: (a) hybrid floor/ceiling on current relative model, (b) fully absolute thresholds, (c) per-mode thresholds (offset detection vs. rhythm matching)
  - [ ] Define precise/moderate/erratic boundaries with rationale tied to research findings
  - [ ] Validate that thresholds produce meaningful color distributions across the full 40–200 BPM range
  - [ ] Document the decision and rationale

- [ ] Task 3: Implement calibrated thresholds
  - [ ] Update `SpectrogramThresholds` in `Peach/Core/Profile/SpectrogramData.swift`
  - [ ] Update any tests in `SpectrogramDataTests.swift` that assert on threshold behavior
  - [ ] Verify spectrogram rendering with new thresholds across tempo ranges

- [ ] Task 4: Update PRD
  - [ ] Update UX-DR4 in `docs/planning-artifacts/ux-design-specification.md` with the calibrated threshold values and rationale
  - [ ] Reference the research findings that informed the decision

- [ ] Task 5: Run full test suite
  - [ ] `bin/test.sh` — zero regressions

## Dev Notes

### Key distinction: perception vs. production

The literature distinguishes:

- **Perception (JND for asynchrony)**: ~10 ms under ideal lab conditions (Madison 2001, Madison & Merker 2004), ~15–25 ms in musical context. This sets a floor for offset detection thresholds — there's no point calling a deviation "erratic" if the user literally cannot hear it.
- **Single-event production**: Tapping one note to a beat. Higher variance than steady-state because there's no error-correction loop. Relevant to Peach's **rhythm offset detection** mode.
- **Steady-state entrainment**: Tapping a continuous sequence. Lower variance due to phase correction (each tap adjusts the next). Relevant to Peach's **rhythm matching** mode and to most drumming studies (Butterfield 2010, Friberg & Sundström 2002).

Professional drummers in steady-state: ~10–20 ms SD. Single-event production is typically worse.

### iOS input latency floor

Touchscreen input latency on iOS is ~8–16 ms depending on device and refresh rate. Any threshold below ~10 ms is measuring device jitter, not musical skill. This is a hard floor.

### Preliminary recommendation from music domain expert (Adam)

Hybrid approach with floor and ceiling:
```
precise  = clamp(sixteenthMs * percentage, min: floor, max: ceiling)
moderate = clamp(sixteenthMs * percentage, min: floor, max: ceiling)
```

Exact values TBD pending full research in Task 1.

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

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
