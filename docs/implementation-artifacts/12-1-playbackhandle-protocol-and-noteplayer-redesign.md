# Story 12.1: PlaybackHandle Protocol and NotePlayer Redesign

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer**,
I want the audio layer redesigned around a PlaybackHandle pattern where callers own the notes they start,
So that the audio engine supports both fixed-duration and indefinite playback with explicit note lifecycle management.

## Acceptance Criteria

1. **PlaybackHandle protocol created** — `PlaybackHandle` defines `func stop() async throws` (first call sends noteOff, subsequent calls are no-ops) and `func adjustFrequency(_ frequency: Double) async throws` (adjusts pitch of the playing note in real time, caller passes absolute Hz). File located at `Core/Audio/PlaybackHandle.swift`.

2. **NotePlayer protocol redesigned** — Primary method becomes `func play(frequency: Double, velocity: UInt8, amplitudeDB: Float) async throws -> PlaybackHandle` which returns immediately after note onset. `stop()` is removed from the `NotePlayer` protocol — stopping is done through the handle only. A default extension provides `func play(frequency: Double, duration: TimeInterval, velocity: UInt8, amplitudeDB: Float) async throws` that internally uses the handle (play → sleep → stop).

3. **SoundFontNotePlayer updated** — `play(frequency:velocity:amplitudeDB:)` returns a `SoundFontPlaybackHandle` that wraps the MIDI note and sampler reference. `SoundFontPlaybackHandle` implements `stop()` by sending MIDI noteOff (idempotent). `SoundFontPlaybackHandle` implements `adjustFrequency()` by computing the relative pitch bend from the base MIDI note to the target Hz and applying it via the sampler's pitch bend API. `SoundFontPlaybackHandle.swift` located at `Core/Audio/SoundFontPlaybackHandle.swift`.

4. **MockNotePlayer updated** — `play(frequency:velocity:amplitudeDB:)` returns a `MockPlaybackHandle`. `MockPlaybackHandle` tracks `stopCallCount`, `adjustFrequencyCallCount`, `lastAdjustedFrequency`. Supports `instantPlayback` mode and `shouldThrowError` injection. `MockPlaybackHandle.swift` located in the test target.

5. **Backward compatibility preserved** — The fixed-duration convenience method via default protocol extension allows existing comparison training call sites to continue using `play(frequency:duration:velocity:amplitudeDB:)` without any call-site changes. The convenience method delegates to the handle internally.

6. **All tests pass** — All existing tests pass. New tests verify: PlaybackHandle stop idempotency, adjustFrequency updates, MockPlaybackHandle tracking, fixed-duration convenience method behavior.

## Tasks / Subtasks

- [ ] Task 1: Create PlaybackHandle protocol (AC: #1)
  - [ ] 1.1 Create `Peach/Core/Audio/PlaybackHandle.swift` with `stop()` and `adjustFrequency(_:)` methods
  - [ ] 1.2 Write tests for PlaybackHandle stop idempotency contract (via MockPlaybackHandle)

- [ ] Task 2: Redesign NotePlayer protocol (AC: #2)
  - [ ] 2.1 Change primary `play()` to return `PlaybackHandle` (remove `duration` param)
  - [ ] 2.2 Remove `stop()` from NotePlayer protocol
  - [ ] 2.3 Add default extension with fixed-duration convenience method (play → sleep → stop)

- [ ] Task 3: Create SoundFontPlaybackHandle (AC: #3)
  - [ ] 3.1 Create `Peach/Core/Audio/SoundFontPlaybackHandle.swift` wrapping MIDI note + sampler
  - [ ] 3.2 Implement idempotent `stop()` — first call sends noteOff, subsequent calls are no-ops
  - [ ] 3.3 Implement `adjustFrequency(_:)` — compute pitch bend from base MIDI note to target Hz
  - [ ] 3.4 Write tests for SoundFontPlaybackHandle stop/adjustFrequency behavior

- [ ] Task 4: Update SoundFontNotePlayer (AC: #3)
  - [ ] 4.1 Refactor `play()` to return `SoundFontPlaybackHandle` immediately after note onset
  - [ ] 4.2 Move note-off logic out of `play()` defer block into handle's `stop()`
  - [ ] 4.3 Remove `stop()` method from SoundFontNotePlayer
  - [ ] 4.4 Preserve preset-switching-on-every-play behavior (read UserDefaults.soundSource)
  - [ ] 4.5 Preserve audio session setup and engine restart logic
  - [ ] 4.6 Update all existing SoundFontNotePlayer tests

- [ ] Task 5: Create MockPlaybackHandle and update MockNotePlayer (AC: #4)
  - [ ] 5.1 Create `PeachTests/Mocks/MockPlaybackHandle.swift` with call tracking
  - [ ] 5.2 Update MockNotePlayer to return MockPlaybackHandle from `play()`
  - [ ] 5.3 Preserve `instantPlayback` mode and `onPlayCalled` callback semantics
  - [ ] 5.4 Ensure `playHistory` still tracks all calls with parameters

- [ ] Task 6: Verify backward compatibility (AC: #5, #6)
  - [ ] 6.1 Confirm ComparisonSession uses the convenience method — no call-site changes needed
  - [ ] 6.2 Run full test suite — all existing tests must pass
  - [ ] 6.3 Write new tests for: handle stop idempotency, adjustFrequency tracking, convenience method delegates to handle

## Dev Notes

### Architecture Patterns and Constraints

- **Protocol-first design**: PlaybackHandle is a protocol (not a concrete class) for testability. SoundFontNotePlayer returns SoundFontPlaybackHandle; MockNotePlayer returns MockPlaybackHandle. [Source: docs/planning-artifacts/architecture.md#Audio-Architecture]
- **Async/await throughout**: All PlaybackHandle methods are `async throws` to align with Swift 6.2 and the existing NotePlayer contract. [Source: docs/project-context.md#Swift-6.2-Concurrency]
- **MainActor default isolation**: All code implicitly @MainActor per Swift 6.2 project settings — do NOT add explicit @MainActor annotations. Use `nonisolated` only when the compiler requires it. [Source: docs/project-context.md#Swift-6.2-Concurrency]
- **No deinit safety for v0.2**: All code paths explicitly call `stop()` on handles. Deinit-based cleanup may be added later. [Source: docs/planning-artifacts/architecture.md#PlaybackHandle-Protocol-Design]
- **Sendable consideration**: If PlaybackHandle crosses isolation boundaries, ensure Sendable conformance. Given MainActor default, this may not be needed initially.

### Current NotePlayer Implementation Details

**Current `NotePlayer` protocol** (`Peach/Core/Audio/NotePlayer.swift`):
```swift
protocol NotePlayer {
    func play(frequency: Double, duration: TimeInterval, velocity: UInt8, amplitudeDB: Float) async throws
    func stop() async throws
}
```

**Current `SoundFontNotePlayer.play()` flow** (`Peach/Core/Audio/SoundFontNotePlayer.swift`):
1. Reads UserDefaults.soundSource, loads preset if different (with 20ms settle delay)
2. Validates inputs (frequency, duration, velocity, amplitudeDB)
3. Converts frequency to MIDI note + cents via `FrequencyCalculation`
4. Applies pitch bend to sampler
5. Calls `sampler.startNote()` with MIDI note + velocity
6. Awaits `Task.sleep(for: .seconds(duration))`
7. In `defer`: calls `sampler.stopNote()` + resets pitch bend to center (8192)

**Current `SoundFontNotePlayer.stop()`**: Stops `currentNote` immediately, resets pitch bend. Does NOT interrupt the `Task.sleep` in `play()`.

**State tracked by SoundFontNotePlayer:**
- `currentNote: UInt8?` — last started MIDI note
- `isSessionConfigured: Bool` — one-time audio session setup
- `loadedProgram: Int`, `loadedBank: Int` — cache of current preset

### What Changes in the Redesign

| Component | Before | After |
|-----------|--------|-------|
| `NotePlayer.play()` | Blocks for full duration, includes noteOff in defer | Returns `PlaybackHandle` immediately after onset |
| `NotePlayer.stop()` | Protocol method on NotePlayer | Removed — stopping via handle only |
| Fixed-duration play | Only option | Default extension convenience method |
| Note ownership | Implicit (SoundFontNotePlayer tracks currentNote) | Explicit (handle owns the note) |
| Pitch adjustment | Not supported | `handle.adjustFrequency(_:)` |
| SoundFontNotePlayer | Manages full note lifecycle | Creates handle, delegates lifecycle to it |

### Pitch Bend Implementation for adjustFrequency()

- SoundFontNotePlayer already has `pitchBendValue(forCents:)` static method (converts cents to 0-16383 MIDI value, center 8192)
- Pitch bend range is ±2 semitones (±200 cents), set via MIDI controllers 101/100/6/38 at init
- `adjustFrequency()` must: (1) compute target MIDI note + cents from Hz, (2) compute cent difference from base note, (3) apply pitch bend
- Use `FrequencyCalculation.swift` for all Hz→MIDI conversions (never reimplement)

### ComparisonSession Call Sites (No Changes Expected)

**Current usage in `ComparisonSession`** (`Peach/Comparison/ComparisonSession.swift`):
- Lines ~418-430: `try await notePlayer.play(frequency: freq, duration: noteDuration, velocity: velocity, amplitudeDB: 0.0)` — uses fixed-duration, will use convenience extension
- Lines ~268-274: `Task { try? await notePlayer.stop() }` — fire-and-forget stop during note 2. **This will continue to work** because the convenience method manages its own handle. However, the fire-and-forget `notePlayer.stop()` calls must be removed or adapted since `stop()` no longer exists on NotePlayer.

**CRITICAL**: While the convenience method preserves the `play(duration:)` call sites, the `notePlayer.stop()` calls in ComparisonSession MUST be addressed. These currently stop playing mid-note during interruptions. Options:
- ComparisonSession tracks `currentHandle` for interruption cleanup (as described in AC)
- Or the convenience method exposes a cancellation mechanism

**Recommendation**: Follow the AC exactly — ComparisonSession holds `currentHandle: PlaybackHandle?`. When using the convenience method for normal playback, handle tracking is optional. For interruption cleanup, call `currentHandle?.stop()`.

### MockNotePlayer Contract Preservation

**Current MockNotePlayer** (`PeachTests/Comparison/MockNotePlayer.swift`) key features to preserve:
- `playCallCount`, `stopCallCount`, `lastFrequency/Duration/Velocity/AmplitudeDB`
- `playHistory: [(frequency, duration, velocity, amplitudeDB)]`
- `instantPlayback: Bool = true` — zero-time by default for deterministic tests
- `simulatedPlaybackDuration: TimeInterval = 0.01` — only used when `instantPlayback = false`
- `onPlayCalled: (() -> Void)?` — synchronous callback BEFORE delays
- `onStopCalled: (() -> Void)?` — synchronous callback
- `shouldThrowError`, `errorToThrow` — error injection
- `reset()` method to clear all state

**Updated MockNotePlayer must**:
- Return `MockPlaybackHandle` from `play(frequency:velocity:amplitudeDB:)`
- Track the new parameter signature (no duration in primary method)
- `MockPlaybackHandle` must have its own `stopCallCount`, `adjustFrequencyCallCount`, `lastAdjustedFrequency`
- The existing `instantPlayback` semantics must be maintained for the convenience method path

### Testing Approach

- **36 existing SoundFontNotePlayer tests** cover: conformance, init, play/stop lifecycle, pitch bend, velocity/amplitude validation, preset switching, SF2 tag parsing, UserDefaults integration
- **Numerous ComparisonSession test files** use MockNotePlayer with `instantPlayback = true`
- Test helpers in `ComparisonTestHelpers.swift`: `makeComparisonSession()` fixture factory, `waitForState()`, `waitForPlayCallCount()`
- **New tests needed**: PlaybackHandle stop idempotency, adjustFrequency tracking, MockPlaybackHandle call tracking, convenience method delegates to handle
- **Framework**: Swift Testing (`@Test`, `#expect`) — NEVER XCTest

### Project Structure Notes

- `PlaybackHandle.swift` → `Peach/Core/Audio/PlaybackHandle.swift` (new protocol)
- `SoundFontPlaybackHandle.swift` → `Peach/Core/Audio/SoundFontPlaybackHandle.swift` (new implementation)
- `NotePlayer.swift` → `Peach/Core/Audio/NotePlayer.swift` (modified protocol + extension)
- `SoundFontNotePlayer.swift` → `Peach/Core/Audio/SoundFontNotePlayer.swift` (modified)
- `MockNotePlayer.swift` → `PeachTests/Comparison/MockNotePlayer.swift` (modified)
- `MockPlaybackHandle.swift` → `PeachTests/Mocks/MockPlaybackHandle.swift` (new)
- No new directories needed — all paths already exist

### References

- [Source: docs/planning-artifacts/architecture.md#PlaybackHandle-Protocol-Design]
- [Source: docs/planning-artifacts/architecture.md#Audio-Architecture]
- [Source: docs/planning-artifacts/epics.md#Epic-12-Story-12.1]
- [Source: docs/project-context.md#AVAudioEngine]
- [Source: docs/project-context.md#Testing-Rules]
- [Source: docs/project-context.md#Swift-6.2-Concurrency]
- [Source: Peach/Core/Audio/NotePlayer.swift — current protocol definition]
- [Source: Peach/Core/Audio/SoundFontNotePlayer.swift — current implementation with pitchBendValue, preset loading, defer cleanup]
- [Source: PeachTests/Comparison/MockNotePlayer.swift — mock contract with instantPlayback, callbacks, history tracking]
- [Source: Peach/Comparison/ComparisonSession.swift — notePlayer.play() and notePlayer.stop() call sites]
- [Source: docs/implementation-artifacts/11-1-rename-training-types-and-files-to-comparison.md — previous story learnings]

## Dev Agent Record

### Agent Model Used

(to be filled during implementation)

### Debug Log References

### Completion Notes List

### File List
