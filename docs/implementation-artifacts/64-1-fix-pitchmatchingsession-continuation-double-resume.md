# Story 64.1: Fix PitchMatchingSession Continuation Double-Resume

Status: ready-for-dev

## Story

As a **musician using a MIDI controller and on-screen slider simultaneously**,
I want the pitch matching session to handle concurrent input safely,
so that the app never crashes from a double-resume on `CheckedContinuation`.

## Acceptance Criteria

1. **Given** the session is in `.awaitingSliderTouch` state **When** `adjustPitch()` and `commitPitch()` are called concurrently (e.g., slider touch and MIDI pitch bend arrive at the same time) **Then** only one resumes the continuation; the other observes that state has already transitioned and is a no-op — no crash, no undefined behavior.

2. **Given** the session is in `.awaitingSliderTouch` state **When** `adjustPitch()` resumes the continuation **Then** `sliderTouchContinuation` is set to `nil` atomically with the state transition, preventing a second resume.

3. **Given** the session is in `.awaitingSliderTouch` state **When** `commitPitch()` resumes the continuation **Then** the same atomic guard applies — no second resume is possible from `adjustPitch()`.

4. **Given** the same fix pattern **When** applied **Then** the feedback task in `commitResult()` includes a `state == .showingFeedback` guard before calling `playNextTrial()`, matching the pattern used in `PitchDiscriminationSession` and `RhythmOffsetDetectionSession`.

5. **Given** the same feedback-task state guard gap exists in `ContinuousRhythmMatchingSession` **When** reviewed **Then** the same guard is added there as well.

6. **Given** the full test suite **When** run **Then** all existing tests pass with zero regressions.

## Tasks / Subtasks

- [ ] Task 1: Fix continuation double-resume in `PitchMatchingSession` (AC: #1, #2, #3)
  - [ ] 1.1 In both `adjustPitch()` and `commitPitch()`, extract the continuation-resume into a single private method (e.g., `resumeSliderContinuationIfNeeded()`) that checks `state == .awaitingSliderTouch`, transitions state, resumes the continuation, and nils it — all in one call site
  - [ ] 1.2 Both `adjustPitch()` and `commitPitch()` call this method instead of duplicating the check-transition-resume sequence
  - [ ] 1.3 Verify the method is idempotent: second call is a no-op because state is no longer `.awaitingSliderTouch`

- [ ] Task 2: Add missing feedback-task state guard in `PitchMatchingSession` (AC: #4)
  - [ ] 2.1 In `commitResult()`, change the feedback task from `guard !Task.isCancelled` to `guard state == .showingFeedback, !Task.isCancelled` before calling `playNextTrial()`
  - [ ] 2.2 Verify this matches the pattern in `PitchDiscriminationSession` and `RhythmOffsetDetectionSession`

- [ ] Task 3: Add missing feedback-task state guard in `ContinuousRhythmMatchingSession` (AC: #5)
  - [ ] 3.1 Locate the feedback task that sleeps then proceeds — add `guard !Task.isCancelled` (or the appropriate state guard for this session's state model, e.g., `isRunning`) before continuing

- [ ] Task 4: Write tests for continuation safety (AC: #1, #6)
  - [ ] 4.1 Test: call `adjustPitch()` and `commitPitch()` rapidly in sequence while in `.awaitingSliderTouch` — session transitions cleanly, no crash
  - [ ] 4.2 Test: call `commitPitch()` when already in `.playingTunable` (continuation already resumed) — no-op, no crash
  - [ ] 4.3 Test: `stop()` during `.showingFeedback` followed by feedback task completing — session stays idle, does not call `playNextTrial()`

- [ ] Task 5: Run full test suite (AC: #6)

## Dev Notes

### Root Cause

`PitchMatchingSession` has two public methods that can resume the same `sliderTouchContinuation`:
- `adjustPitch()` at line ~113: checks `state == .awaitingSliderTouch`, transitions to `.playingTunable`, resumes continuation
- `commitPitch()` at line ~127: same check, same transition, same resume

`CheckedContinuation` traps (fatal error) if resumed twice. On `@MainActor` these calls are serialized, but the MIDI listening task dispatches to MainActor via `Task { @MainActor in }` which can interleave with slider gesture handler events in the same run loop iteration.

### Fix Pattern

Extract a single `resumeSliderContinuationIfNeeded()` method:

```swift
private func resumeSliderContinuationIfNeeded() {
    guard state == .awaitingSliderTouch else { return }
    state = .playingTunable
    sliderTouchContinuation?.resume()
    sliderTouchContinuation = nil
}
```

Both `adjustPitch()` and `commitPitch()` call this. The state check ensures only one succeeds.

### Feedback Task Gap

The feedback task in `commitResult()` currently only checks `!Task.isCancelled`. If `stop()` is called during the feedback sleep, state becomes `.idle` and `settings` becomes `nil`. `playNextTrial()` silently returns (guard on `settings`), but the training loop is broken. Adding `state == .showingFeedback` as a guard matches the established pattern in the other two sessions.

### Source File Locations

| File | Path |
|------|------|
| PitchMatchingSession | `Peach/PitchMatching/PitchMatchingSession.swift` |
| ContinuousRhythmMatchingSession | `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift` |
| PitchDiscriminationSession (reference) | `Peach/PitchDiscrimination/PitchDiscriminationSession.swift` |
| RhythmOffsetDetectionSession (reference) | `Peach/RhythmOffsetDetection/RhythmOffsetDetectionSession.swift` |

### Pre-Existing Finding

This addresses CQ-4 (partially). The full actor isolation question remains open, but this story eliminates the concrete crash scenario.

### References

- [Source: docs/pre-existing-findings.md#CQ-4] — Actor isolation finding
- [Source: Peach/PitchMatching/PitchMatchingSession.swift] — Double-resume location
- [Source: Peach/PitchDiscrimination/PitchDiscriminationSession.swift] — Reference pattern for feedback guard
