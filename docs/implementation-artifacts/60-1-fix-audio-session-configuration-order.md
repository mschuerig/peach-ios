# Story 60.1: Fix Audio Session Configuration Order

Status: ready-for-dev

## Story

As a user tapping along to the rhythm,
I want the audio engine to use the shortest possible buffer duration,
so that the delay between my tap and the sound is minimized.

## Acceptance Criteria

### AC 1: Buffer preference before activation

**Given** `SoundFontEngine.configureAudioSession()`
**When** it configures the audio session
**Then** `setPreferredIOBufferDuration(0.005)` is called *before* `setActive(true)`, and the separate `setPreferredIOBufferDuration` call in `init` is removed

### AC 2: Log actual buffer duration

**Given** the audio session is activated
**When** the engine starts
**Then** the actual `ioBufferDuration` is logged (e.g., "Requested 5ms buffer, got Xms") so we can verify the preference was honored

### AC 3: No regressions

**Given** the full test suite
**When** run
**Then** all tests pass with zero regressions

## Tasks / Subtasks

- [ ] Task 1: Reorder `configureAudioSession()` (AC: 1)
  - [ ] 1.1 Move `setPreferredIOBufferDuration(0.005)` into `configureAudioSession()`, before `setActive(true)`
  - [ ] 1.2 Remove the standalone `setPreferredIOBufferDuration` call from `init` (line 112)
- [ ] Task 2: Add buffer duration logging (AC: 2)
  - [ ] 2.1 After `setActive(true)`, log `session.ioBufferDuration * 1000` at `.info` level
- [ ] Task 3: Run test suite (AC: 3)
  - [ ] 3.1 Run full test suite, verify zero regressions

## Dev Notes

### Key Files

| File | Role |
|------|------|
| `Peach/Core/Audio/SoundFontEngine.swift:111-113` | **Modify** — remove standalone `setPreferredIOBufferDuration` call |
| `Peach/Core/Audio/SoundFontEngine.swift:325-329` | **Modify** — reorder `configureAudioSession()` and add logging |

### Context

Apple's documentation (QA1631) states that `setPreferredIOBufferDuration` should be called *before* `setActive(true)`. The current code calls it *after* activation, which may cause the preference to be silently ignored, falling back to the ~20ms default.

After this fix, check the logged actual buffer duration on a real device. If it reports ~5ms, the fix is working. If it reports ~20ms, further investigation is needed (e.g., another app or system service overriding the preference, or an iOS 18+ regression).

### References

- [Architecture amendment v0.6](../planning-artifacts/architecture.md) — Audio session configuration order constraint
- [Technical research report](../planning-artifacts/research/technical-ios-audio-latency-rhythm-training-research-2026-03-24.md) — Fix 2
