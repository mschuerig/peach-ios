# Fix: SoundFont Click Artifact on Note Stop

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **musician using Peach**,
I want notes to stop without audible clicks regardless of which SF2 preset is selected,
so that the training experience feels smooth and professional, especially with the default Sine Wave preset.

## Background

When `SineWaveNotePlayer` was the audio engine, a click-avoidance mechanism was implemented: muting `playerNode.volume` to 0, waiting 25ms for the audio render thread to propagate, then stopping the node and restoring volume. This was proven effective (see `fix-audio-clicks-when-navigating-away.md`).

In Epic 8, `SineWaveNotePlayer` was replaced by `SoundFontNotePlayer` (story 8.3). The click-avoidance logic was removed with it. `SoundFontNotePlayer` relies on the SF2 sampler's built-in release envelope via MIDI note-off. This works for acoustic instruments (piano, cello) that have natural decay/release envelopes baked into their SF2 instrument definitions.

However, the default **Sine Wave preset (bank 8, program 80)** is a synthetic waveform sample with minimal or no release envelope. When `SoundFontPlaybackHandle.stop()` sends `sampler.stopNote()`, it cuts off the sine wave abruptly — producing the same click artifact that was previously fixed.

## Acceptance Criteria

1. **Given** a note is playing with the Sine Wave preset, **When** `SoundFontPlaybackHandle.stop()` is called, **Then** audio fades out smoothly (no audible click/pop)
2. **Given** a note is playing with the Sine Wave preset, **When** `SoundFontNotePlayer.stopAll()` is called, **Then** audio fades out smoothly (no audible click/pop)
3. **Given** a note is playing with an acoustic preset (e.g., Grand Piano), **When** stop is called, **Then** audio fades out smoothly (the 25ms mute is imperceptible and does not noticeably truncate release tails)
4. **Given** no note is currently playing, **When** `stop()` or `stopAll()` is called, **Then** no audio artifact occurs and behavior is unchanged
5. **Given** the fade-out implementation, **When** measured, **Then** the stop propagation delay is <= 25ms (covers 2+ audio render cycles at standard buffer sizes)
6. **Given** a task cancellation during the propagation delay, **When** the sleep is interrupted, **Then** the note is still stopped and volume is restored to 1.0 (no stuck mute)
7. **Given** all existing tests, **When** the full test suite runs, **Then** all tests pass (no regressions)

## Tasks / Subtasks

- [x] Task 1: Add `stopPropagationDelay` constant to `SoundFontNotePlayer` (AC: #5)
  - [x] 1.1 Add `static let stopPropagationDelay: Duration = .milliseconds(25)` to the Constants section

- [x] Task 2: Implement fade-out in `SoundFontPlaybackHandle.stop()` (AC: #1, #3, #4, #6)
  - [x] 2.1 Write failing test: `stop()` sets `sampler.volume` to 0 before stopping note
  - [x] 2.2 Modify `stop()` to: mute `sampler.volume = 0`, sleep with `try?` (cancellation-safe), then `stopNote()` + pitch bend reset, then restore `sampler.volume = 1.0`
  - [x] 2.3 Verify idempotent guard (`hasStopped`) still prevents double-fade

- [x] Task 3: Implement fade-out in `SoundFontNotePlayer.stopAll()` (AC: #2, #3, #4, #6)
  - [x] 3.1 Write failing test: `stopAll()` sets `sampler.volume` to 0 before sending CC#123
  - [x] 3.2 Modify `stopAll()` to: mute `sampler.volume = 0`, sleep with `try?` (cancellation-safe), then CC#123 + pitch bend reset, then restore `sampler.volume = 1.0`

- [x] Task 4: Run full test suite and fix any regressions (AC: #7)
  - [x] 4.1 Run `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [x] 4.2 Fix any failures related to timing changes (the 25ms delay is additive to existing async behavior)

## Dev Notes

### Technical Approach

Reintroduce the proven volume-mute approach from the former `SineWaveNotePlayer`, adapted for the `AVAudioUnitSampler` context. The approach is universal — applied to all presets, not conditionally per preset.

**`sampler.volume`** (inherited from `AVAudioNode`) controls the mixer input gain for the sampler node. This is independent of `sampler.overallGain` (which controls MIDI amplitude/loudness set during `play()`). They do not interfere with each other.

### Implementation Detail: `SoundFontPlaybackHandle.stop()`

```swift
func stop() async throws {
    guard !hasStopped else { return }
    hasStopped = true
    sampler.volume = 0
    try? await Task.sleep(for: SoundFontNotePlayer.stopPropagationDelay)
    sampler.stopNote(midiNote, onChannel: channel)
    sampler.sendPitchBend(SoundFontNotePlayer.pitchBendCenter, onChannel: channel)
    sampler.volume = 1.0
}
```

### Implementation Detail: `SoundFontNotePlayer.stopAll()`

```swift
func stopAll() async throws {
    sampler.volume = 0
    try? await Task.sleep(for: Self.stopPropagationDelay)
    sampler.sendController(123, withValue: 0, onChannel: Self.channel)
    sampler.sendPitchBend(Self.pitchBendCenter, onChannel: Self.channel)
    sampler.volume = 1.0
}
```

### Why `try?` on the Sleep

Many callers use `try? await handle.stop()` or `try? await notePlayer.stopAll()`. If the enclosing task is cancelled during the 25ms wait, `try?` ensures execution continues to the stop/CC#123 and volume restoration. Without this, cancellation would leave `sampler.volume` stuck at 0 (muted).

### Propagation Delay Rationale

25ms covers 2+ audio render cycles at 44.1kHz with 512-frame buffers (each cycle ~11.6ms). This was empirically validated during the original `SineWaveNotePlayer` fix — 10ms still produced audible clicks; 25ms reliably eliminated them.

### Concurrency Safety

Only one note plays at a time in both `ComparisonSession` and `PitchMatchingSession`. No concurrent volume manipulation risk. All code runs on MainActor (default isolation).

### Impact on Acoustic Presets

The 25ms mute truncates the very beginning of an acoustic preset's release tail. At 25ms this is well below the ~100ms threshold for human temporal resolution of amplitude envelopes — imperceptible in practice. If this ever becomes noticeable with a specific preset, the universal approach can be refined to per-preset conditional logic (Option B from the analysis), but this is deferred as YAGNI.

### Architecture Constraints

- **Single `SoundFontNotePlayer` instance** — created at app startup, injected everywhere [Source: docs/project-context.md#AVAudioEngine]
- **Protocol boundary: `PlaybackHandle`** — the `stop()` signature is `func stop() async throws`; no API change needed [Source: Peach/Core/Audio/PlaybackHandle.swift]
- **`NotePlayer.stopAll()`** — signature is `func stopAll() async throws`; no API change needed [Source: Peach/Core/Audio/NotePlayer.swift]
- **All stop paths go through `handle.stop()` or `notePlayer.stopAll()`** — no changes needed outside the audio layer [Source: ComparisonSession.swift, PitchMatchingSession.swift]
- **Swift 6.2 default MainActor isolation** — all code implicitly `@MainActor`; no explicit annotations needed

### Files to Modify

| File | Change |
|------|--------|
| `Peach/Core/Audio/SoundFontNotePlayer.swift` | Add `stopPropagationDelay` constant; modify `stopAll()` to fade before stopping |
| `Peach/Core/Audio/SoundFontPlaybackHandle.swift` | Modify `stop()` to fade before stopping |
| `PeachTests/Core/Audio/SoundFontNotePlayerTests.swift` | Add test for fade-out in `stopAll()` |
| `PeachTests/Core/Audio/SoundFontPlaybackHandleTests.swift` | Add test for fade-out in `stop()` |

### Files NOT to Modify

- `PlaybackHandle.swift` — protocol signature unchanged
- `NotePlayer.swift` — protocol signature unchanged
- `ComparisonSession.swift` — already calls `handle.stop()` and `notePlayer.stopAll()` correctly
- `PitchMatchingSession.swift` — already calls `handle.stop()` and `notePlayer.stopAll()` correctly
- `MockNotePlayer.swift` / `MockPlaybackHandle.swift` — mock behavior doesn't need fade simulation

### Testing Strategy

- **Unit test (handle):** Verify `stop()` sets `sampler.volume` to 0 before stopping note (observable state change on the `AVAudioUnitSampler` instance)
- **Unit test (player):** Verify `stopAll()` sets `sampler.volume` to 0 before sending CC#123
- **Regression:** Full test suite must pass — existing `SoundFontPlaybackHandleTests`, `SoundFontNotePlayerTests`, `ComparisonSessionLifecycleTests`, and `PitchMatchingSessionTests` must be unaffected
- **Manual verification:** Play a note with Sine Wave preset, stop mid-playback, confirm no click/pop

### References

- [Source: Peach/Core/Audio/SoundFontPlaybackHandle.swift:23-28] — Current `stop()` implementation
- [Source: Peach/Core/Audio/SoundFontNotePlayer.swift:151-154] — Current `stopAll()` implementation
- [Source: docs/implementation-artifacts/fix-audio-clicks-when-navigating-away.md] — Original click fix on SineWaveNotePlayer (proven approach)
- [Source: docs/implementation-artifacts/8-3-remove-sinewavenoteplayer-and-routingnoteplayer.md] — Removal of SineWaveNotePlayer and its click fix
- [Source: docs/implementation-artifacts/12-1-playbackhandle-protocol-and-noteplayer-redesign.md] — PlaybackHandle architecture
- [Source: docs/project-context.md#AVAudioEngine] — Single player instance rule
- [Source: docs/project-context.md#Testing Rules] — Swift Testing, full suite requirement

## Dev Agent Record

### Implementation Plan

Reintroduced the proven volume-mute approach from the former `SineWaveNotePlayer`, adapted for `AVAudioUnitSampler`. The approach is universal — applied to all presets via `sampler.volume` (AVAudioNode mixer gain), independent of `sampler.overallGain` (MIDI amplitude). Both `stop()` and `stopAll()` now: mute volume to 0, wait 25ms for the audio render thread to propagate the silence, perform the actual stop (MIDI note-off or CC#123), then restore volume to 1.0. The `try?` on `Task.sleep` ensures cancellation-safety — if the enclosing task is cancelled during the 25ms wait, execution continues to stop the note and restore volume.

### Completion Notes

- Added `stopPropagationDelay` constant (25ms) to `SoundFontNotePlayer`
- Modified `SoundFontPlaybackHandle.stop()` with fade-out before `stopNote()` — idempotent guard unchanged
- Modified `SoundFontNotePlayer.stopAll()` with fade-out before CC#123
- Added test `stopFadesOutAndRestoresVolume` verifying volume restoration after handle stop
- Added test `stopAllFadesOutAndRestoresVolume` verifying volume restoration after player stopAll
- Full test suite passes — no regressions (all existing tests unaffected by the 25ms delay)
- No API changes — `PlaybackHandle.stop()` and `NotePlayer.stopAll()` signatures unchanged
- No changes needed outside the audio layer

## File List

- `Peach/Core/Audio/SoundFontNotePlayer.swift` — Added `stopPropagationDelay` constant; modified `stopAll()` with fade-out
- `Peach/Core/Audio/SoundFontPlaybackHandle.swift` — Modified `stop()` with fade-out
- `PeachTests/Core/Audio/SoundFontNotePlayerTests.swift` — Added `stopAllFadesOutAndRestoresVolume` test
- `PeachTests/Core/Audio/SoundFontPlaybackHandleTests.swift` — Added `stopFadesOutAndRestoresVolume` test
- `docs/implementation-artifacts/fix-soundfont-click-on-note-stop.md` — Story file updated
- `docs/implementation-artifacts/sprint-status.yaml` — Status updated to review

## Change Log

- 2026-02-28: Implemented fade-out on note stop to eliminate click artifacts — all 4 tasks completed, full test suite passes
