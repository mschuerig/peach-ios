# Story 60.1: Fix Audio Session Configuration Order

Status: done

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

- [x] Task 1: Reorder `configureAudioSession()` (AC: 1)
  - [x] 1.1 Move `setPreferredIOBufferDuration(0.005)` into `configureAudioSession()`, before `setActive(true)`
  - [x] 1.2 Remove the standalone `setPreferredIOBufferDuration` call from `init` (line 112)
- [x] Task 2: Add buffer duration logging (AC: 2)
  - [x] 2.1 After `setActive(true)`, log `session.ioBufferDuration * 1000` at `.info` level
- [x] Task 3: Run test suite (AC: 3)
  - [x] 3.1 Run full test suite, verify zero regressions

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

## Dev Agent Record

### Implementation Plan

Reorder `configureAudioSession()` to call `setPreferredIOBufferDuration(0.005)` before `setActive(true)` per Apple QA1631. Remove redundant standalone call from `init`. Add `.info`-level log of actual buffer duration after activation.

### Completion Notes

- Moved `setPreferredIOBufferDuration(0.005)` into `configureAudioSession()` before `setActive(true)` — follows Apple QA1631 guidance
- Removed standalone `setPreferredIOBufferDuration` call from `init` (was called after activation, preference may have been silently ignored)
- Added static `audioSessionLogger` and `.info` log: "Requested 5ms buffer, got X.Xms" after `setActive(true)`
- Full test suite: 1472 tests passed, zero regressions

## File List

- `Peach/Core/Audio/SoundFontEngine.swift` — modified (reordered buffer preference, removed duplicate call, added logging)
- `docs/implementation-artifacts/60-1-fix-audio-session-configuration-order.md` — updated status and dev record
- `docs/implementation-artifacts/sprint-status.yaml` — status updated to review

## Change Log

- 2026-03-24: Implemented story 60.1 — fixed audio session configuration order and added buffer duration logging
