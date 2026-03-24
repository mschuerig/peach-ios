# Story 60.3: Unify Clock Domains to Audio Sample Position

Status: done

## Story

As a user tapping along to the rhythm,
I want my tap timing to be measured against the audio engine's actual playback position,
so that the hit/miss detection and offset calculation are jitter-free and accurate.

## Acceptance Criteria

### AC 1: handleTap uses sample position

**Given** `ContinuousRhythmMatchingSession.handleTap()`
**When** it determines the current cycle and gap position
**Then** it reads `currentSamplePosition` from the step sequencer instead of using `CACurrentMediaTime()`

### AC 2: Offset calculation in sample domain

**Given** `ContinuousRhythmMatchingSession.handleTap()`
**When** it calculates the tap offset from the gap
**Then** the offset is computed in the sample domain (`tapSamplePosition - gapSampleOffset`) and converted to seconds via `sampleRate`, with no wall-clock time involved

### AC 3: Step sequencer exposes timing constants

**Given** `SoundFontStepSequencer`
**When** queried by the session
**Then** it exposes `samplesPerStep` and `samplesPerCycle` (or equivalent) so the session can convert sample positions to cycle/step indices

### AC 4: Wall-clock timing removed

**Given** `ContinuousRhythmMatchingSession`
**When** the clock domain unification is complete
**Then** `sequencerStartTime`, `sixteenthDuration`, `cycleDuration`, and the `currentTime` closure are removed — all timing uses sample positions

### AC 5: Tracking loop uses sample position

**Given** `evaluatePlaybackPosition()` (the ~120Hz tracking loop)
**When** it determines the current step and cycle for UI updates
**Then** it also uses `currentSamplePosition` instead of wall-clock elapsed time

### AC 6: Tests updated

**Given** existing unit tests for `ContinuousRhythmMatchingSession`
**When** updated for the new timing model
**Then** they mock `currentSamplePosition` instead of `currentTime()`, and all assertions remain equivalent

### AC 7: No regressions

**Given** the full test suite
**When** run
**Then** all tests pass with zero regressions

## Tasks / Subtasks

- [x] Task 1: Expose timing constants from StepSequencer (AC: 3)
  - [x] 1.1 Add `samplesPerStep: Int64` and `samplesPerCycle: Int64` readable properties to `StepSequencer` protocol
  - [x] 1.2 Implement in `SoundFontStepSequencer` — store the computed values from `start()` as instance state
  - [x] 1.3 Also expose `sampleRate: SampleRate` on the protocol (or reuse existing `StepSequencerEngine.sampleRate`)
- [x] Task 2: Refactor handleTap to use sample position (AC: 1, 2)
  - [x] 2.1 Replace `let tapTime = currentTime()` with `let tapSamplePosition = stepSequencer.currentSamplePosition`
  - [x] 2.2 Replace `let elapsed = tapTime - sequencerStartTime` / `let playingCycleIndex = Int(elapsed / cycleDuration)` with `let playingCycleIndex = Int(tapSamplePosition / stepSequencer.samplesPerCycle)`
  - [x] 2.3 Replace gap offset calculation: `let gapSampleOffset = Int64(playingCycleIndex * 4 + gapPosition.rawValue) * stepSequencer.samplesPerStep`; `let offsetSamples = tapSamplePosition - gapSampleOffset`; `let offset = Double(offsetSamples) / sampleRate.rawValue`
  - [x] 2.4 Replace window half: `let windowHalfSamples = stepSequencer.samplesPerStep / 2`
- [x] Task 3: Refactor evaluatePlaybackPosition (AC: 5)
  - [x] 3.1 Replace wall-clock elapsed time with `stepSequencer.currentSamplePosition` for step/cycle derivation
  - [x] 3.2 Verify UI tracking loop remains responsive (~120Hz polling is unchanged)
- [x] Task 4: Remove wall-clock state (AC: 4)
  - [x] 4.1 Remove `sequencerStartTime`, `sixteenthDuration`, `cycleDuration` instance properties
  - [x] 4.2 Remove `currentTime` closure from init and all usage
  - [x] 4.3 Remove `QuartzCore` import if `CACurrentMediaTime` was the only reason for it
- [x] Task 5: Update tests (AC: 6, 7)
  - [x] 5.1 Update `MockStepSequencer` (or equivalent) to provide controllable `currentSamplePosition`, `samplesPerStep`, `samplesPerCycle`
  - [x] 5.2 Rewrite handleTap tests to set sample position instead of `currentTime` mock
  - [x] 5.3 Rewrite evaluatePlaybackPosition tests similarly
  - [x] 5.4 Run full test suite, verify zero regressions

## Dev Notes

### Key Files

| File | Role |
|------|------|
| `Peach/Core/Audio/SoundFontStepSequencer.swift` | **Modify** — expose `samplesPerStep`, `samplesPerCycle` as readable properties |
| `Peach/Core/Audio/StepSequencer.swift` | **Modify** — add timing constant requirements to `StepSequencer` protocol |
| `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift` | **Modify** — rewrite `handleTap()` and `evaluatePlaybackPosition()` to use sample positions; remove wall-clock state |
| `PeachTests/ContinuousRhythmMatching/ContinuousRhythmMatchingSessionTests.swift` | **Modify** — update mocks and assertions for sample-position-based timing |

### Context

The current timing model uses two different clocks:
- **Audio domain:** `samplePosition` (incremented by the render thread, monotonic, jitter-free)
- **UI domain:** `CACurrentMediaTime()` (system wall clock, can drift from audio clock)

The `sequencerStartTime` is captured via `CACurrentMediaTime()` *after* an `await` chain that includes a 20ms `loadPreset` sleep, creating a systematic offset between the wall-clock timestamp and the audio engine's actual start position.

After this fix, the session uses only `currentSamplePosition` — the same clock domain as the scheduled MIDI events. The offset calculation becomes a simple integer subtraction in sample space, eliminating all drift and jitter.

### Testing Approach

The mock step sequencer should allow tests to set `currentSamplePosition` to precise values. For example, to simulate a tap exactly on the gap:

```swift
// Gap at step 2 of cycle 0:
// gapSampleOffset = (0 * 4 + 2) * samplesPerStep = 2 * 11025 = 22050
mock.currentSamplePosition = 22050  // exactly on the gap
session.handleTap()
// Expect: hit with 0ms offset
```

### References

- [Architecture amendment v0.6](../planning-artifacts/architecture.md) — Single clock domain constraint
- [Technical research report](../planning-artifacts/research/technical-ios-audio-latency-rhythm-training-research-2026-03-24.md) — Fix 3

## Dev Agent Record

### Implementation Plan

Unified `ContinuousRhythmMatchingSession` timing from two clock domains (wall-clock via `CACurrentMediaTime()` + audio sample position) to a single clock domain (audio sample position only). The approach:
1. Extended `StepSequencer` protocol with `currentSamplePosition`, `samplesPerStep`, `samplesPerCycle`, `sampleRate`
2. `SoundFontStepSequencer` stores computed timing values as instance state (previously local to `start()`)
3. `handleTap()` and `evaluatePlaybackPosition()` rewritten as pure integer arithmetic in sample space
4. Wall-clock state (`sequencerStartTime`, `sixteenthDuration`, `cycleDuration`, `currentTime` closure) and `QuartzCore` import removed
5. Tests rewritten to control `MockStepSequencer.currentSamplePosition` directly instead of a `currentTime` closure

### Completion Notes

All 7 acceptance criteria satisfied. The offset calculation is now a simple integer subtraction (`tapSamplePosition - gapSampleOffset`) converted to seconds via `sampleRate`, eliminating all drift and jitter between the audio and UI clock domains. All 1472 tests pass with zero regressions.

## File List

- `Peach/Core/Audio/StepSequencer.swift` — Modified: added `currentSamplePosition`, `samplesPerStep`, `samplesPerCycle`, `sampleRate` to protocol
- `Peach/Core/Audio/SoundFontStepSequencer.swift` — Modified: stored timing constants as instance state, exposed via protocol
- `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift` — Modified: rewrote `handleTap()` and `evaluatePlaybackPosition()` to sample domain; removed wall-clock state and `QuartzCore` import
- `Peach/App/EnvironmentKeys.swift` — Modified: updated `PreviewStepSequencer` for new protocol requirements
- `PeachTests/Mocks/MockStepSequencer.swift` — Modified: added controllable timing properties
- `PeachTests/ContinuousRhythmMatching/ContinuousRhythmMatchingSessionTests.swift` — Modified: rewrote all tests to use sample positions
- `docs/implementation-artifacts/sprint-status.yaml` — Modified: status update

## Change Log

- 2026-03-24: Unified clock domains — all timing in ContinuousRhythmMatchingSession now uses audio sample positions instead of wall-clock time
