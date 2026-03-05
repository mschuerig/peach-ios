---
title: 'Add logging to PitchMatchingSession'
slug: 'pitch-matching-session-logging'
created: '2026-03-05'
status: 'ready-for-dev'
stepsCompleted: [1, 2, 3, 4]
tech_stack: ['Swift 6.2', 'os.Logger']
files_to_modify: ['Peach/PitchMatching/PitchMatchingSession.swift']
code_patterns: ['os.Logger with subsystem/category', 'logger.info for lifecycle events']
test_patterns: []
---

# Tech-Spec: Add logging to PitchMatchingSession

**Created:** 2026-03-05

## Overview

### Problem Statement

PitchMatchingSession lacks lifecycle logging for challenge generation and result capture. PitchComparisonSession has detailed logging throughout its training loop, making debugging straightforward. PitchMatchingSession only logs errors and stop/start guards, making it hard to trace training flow.

### Solution

Add `logger.info` calls to PitchMatchingSession for challenge details and commit results, mirroring PitchComparisonSession's logging style and detail level.

### Scope

**In Scope:**
- Log challenge details when a new challenge is generated (reference note, target note, initial cent offset, frequencies)
- Log commit results when the user submits their pitch match (user cent error)

**Out of Scope:**
- Per-slider-adjustment logging (too noisy)
- Test changes (logging doesn't affect observable behavior)
- Any behavioral changes to the session

## Context for Development

### Codebase Patterns

- Logger is already initialized: `private let logger = Logger(subsystem: "com.peach.app", category: "PitchMatchingSession")`
- PitchComparisonSession uses `logger.info` for lifecycle events, `logger.warning` for unexpected state, `logger.error` for failures
- Log messages include interpolated values with descriptive labels (e.g., `ref=\(note.rawValue) \(freq)Hz`)
- Reference log line from PitchComparisonSession (line 257):
  ```swift
  logger.info("PitchComparison: ref=\(pitchComparison.referenceNote.rawValue) \(freq1.rawValue)Hz @0.0dB, target \(freq2.rawValue)Hz @\(amplitudeDB.rawValue)dB, offset=\(pitchComparison.targetNote.offset.rawValue), higher=\(pitchComparison.isTargetHigher)")
  ```

### Files to Reference

| File | Purpose |
| ---- | ------- |
| `Peach/PitchMatching/PitchMatchingSession.swift` | Target file — add logging here |
| `Peach/PitchComparison/PitchComparisonSession.swift` | Reference for logging style |

### Technical Decisions

- Use the same log format style as PitchComparisonSession for consistency
- No logging in `adjustPitch()` — it fires on every slider movement and would flood the log
- Log the challenge after frequency computation so all values are available in a single log line

## Implementation Plan

### Tasks

- [ ] Task 1: Add `logger.info("Starting training loop")` in `start()`
  - File: `Peach/PitchMatching/PitchMatchingSession.swift`
  - Action: Insert `logger.info("Starting training loop")` after the `sessionTuningSystem` assignment (line 96), before the `trainingTask` assignment
  - Notes: Matches PitchComparisonSession `start()` at line 121

- [ ] Task 2: Add challenge detail logging in `playNextChallenge()`
  - File: `Peach/PitchMatching/PitchMatchingSession.swift`
  - Action: Insert a `logger.info` call after `self.referenceFrequency = targetFreq.rawValue` (line 252), logging: reference note, target note, initial cent offset, reference frequency, and target frequency
  - Notes: Format: `logger.info("Challenge: ref=\(challenge.referenceNote.rawValue) \(refFreq.rawValue)Hz, target=\(challenge.targetNote.rawValue) \(targetFreq.rawValue)Hz, initialOffset=\(challenge.initialCentOffset)cents")`

- [ ] Task 3: Add result logging in `commitResult()`
  - File: `Peach/PitchMatching/PitchMatchingSession.swift`
  - Action: Insert a `logger.info` call after computing `userCentError` (line 144), logging: reference note, target note, initial cent offset, and user cent error
  - Notes: Format: `logger.info("Result: ref=\(challenge.referenceNote.rawValue), target=\(challenge.targetNote.rawValue), initialOffset=\(challenge.initialCentOffset)cents, userCentError=\(userCentError)cents")`

### Acceptance Criteria

- [ ] AC 1: Given a pitch matching session is idle, when `start(intervals:)` is called with valid intervals, then an info log "Starting training loop" is emitted before the training task begins
- [ ] AC 2: Given a new challenge is generated in `playNextChallenge()`, when frequencies are computed, then an info log is emitted containing: reference note raw value, target note raw value, initial cent offset, reference frequency in Hz, and target frequency in Hz
- [ ] AC 3: Given the user commits a pitch in `commitResult()`, when user cent error is computed, then an info log is emitted containing: reference note raw value, target note raw value, initial cent offset, and user cent error in cents

## Additional Context

### Dependencies

None — only uses the existing `os.Logger` already initialized in the file.

### Testing Strategy

No test changes needed. Logging is a non-observable side effect that doesn't change session behavior or state transitions. Verify manually via Console.app or Xcode console during a pitch matching training session.

### Notes

This is a purely additive change with zero risk to existing behavior.
