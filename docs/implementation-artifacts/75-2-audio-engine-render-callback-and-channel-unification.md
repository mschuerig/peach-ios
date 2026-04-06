# Story 75.2: Audio Engine — Render Callback Extraction and Channel Unification

Status: ready-for-dev

## Story

As a **developer reading the audio layer**,
I want `SoundFontEngine.init()` decomposed and internal types unified with domain types,
so that the audio engine is easier to understand and maintain.

## Background

The walkthrough (Layer 2) found that `SoundFontEngine.init()` is 133 lines with a 95-line render callback closure nested inside. `ChannelID` duplicates `MIDIChannel`. `SoundFontStepSequencer` has static methods that should be instance methods. `AudioSessionInterruptionMonitor` has duplicate observer registrations.

**Walkthrough sources:** Layer 2 observations #2, #3, #5; Layer 3 observation #2.

## Acceptance Criteria

1. **Given** `SoundFontEngine` **When** inspected **Then** `ChannelID` is replaced by `MIDIChannel` from `Core/Music/`.
2. **Given** `SoundFontEngine.init()` **When** inspected **Then** the render callback closure (~95 lines) is extracted to a `private static func` that captures only the shared state and constants it needs.
3. **Given** `SoundFontEngine` **When** inspected **Then** the "write to inactive slot, copy MIDI blocks, bump generation" pattern shared by `createChannel()` and `scheduleEvents()` is extracted to a shared helper method.
4. **Given** `SoundFontStepSequencer` **When** inspected **Then** `buildBatch` and `buildCycleEvents` are instance methods. Parameters that are already available on `self` (`cyclesPerBatch`, `samplesPerStep`, `channel`) are read from properties instead of passed as arguments.
5. **Given** `AudioSessionInterruptionMonitor` **When** inspected **Then** the identical background and foreground observer registrations are unified — a single method iterates notification names and registers the same handler.
6. **Given** both platforms **When** built and tested **Then** all tests pass with zero regressions.

## Tasks / Subtasks

- [ ] Task 1: Replace ChannelID with MIDIChannel (AC: #1)
  - [ ] Remove `ChannelID` nested struct from `SoundFontEngine`
  - [ ] Replace all `ChannelID` references with `MIDIChannel`
  - [ ] Verify preconditions and ranges are identical (both UInt8, 0–15)

- [ ] Task 2: Extract render callback from init (AC: #2)
  - [ ] Create a `private static func makeRenderCallback(shared:...)` returning the closure
  - [ ] Move the ~95-line `AVAudioSourceNode` callback body into the static method
  - [ ] Verify it captures only `shared` state and `Self` constants (no `self` capture)

- [ ] Task 3: Extract schedule-swap helper (AC: #3)
  - [ ] Identify the shared pattern in `createChannel()` and `scheduleEvents()`
  - [ ] Extract to a private method (e.g., `swapScheduleSlot(prepare:)`)

- [ ] Task 4: Convert SoundFontStepSequencer statics to instance methods (AC: #4)
  - [ ] Change `buildBatch` and `buildCycleEvents` from `static` to instance methods
  - [ ] Remove parameters that are already available as properties
  - [ ] Store `noteOffDelaySamples` as a property if not already

- [ ] Task 5: Simplify AudioSessionInterruptionMonitor (AC: #5)
  - [ ] Replace separate `backgroundObserver`/`foregroundObserver` with a single loop
  - [ ] Evaluate whether the foreground stop observer is redundant (both call `onStopRequired`)

- [ ] Task 6: Build and test both platforms (AC: #6)
  - [ ] `bin/test.sh && bin/test.sh -p mac`

## Dev Notes

### Source File Locations

| Change | File |
|--------|------|
| ChannelID → MIDIChannel | `Peach/Core/Audio/SoundFontEngine.swift` |
| Render callback extraction | `Peach/Core/Audio/SoundFontEngine.swift` |
| Schedule-swap helper | `Peach/Core/Audio/SoundFontEngine.swift` |
| Static → instance methods | `Peach/Core/Audio/SoundFontStepSequencer.swift` |
| Monitor simplification | `Peach/Core/Audio/AudioSessionInterruptionMonitor.swift` |

### Existing WALKTHROUGH Annotations

- `Peach/Core/Audio/SoundFontEngine.swift` (lines 176–177: ChannelID, lines 235–236: init)
- `Peach/Core/Audio/SoundFontStepSequencer.swift` (lines 185–186)
- `Peach/Core/Audio/AudioSessionInterruptionMonitor.swift` (lines 33–34)

### Critical: Real-Time Audio Thread Safety

The render callback runs on the real-time audio thread. When extracting it:
- Do NOT introduce any allocations, locks, or Objective-C message sends
- Preserve the atomic acquire-load/release-store semantics for generation counter
- Preserve the SPSC ring buffer access pattern for immediate events
- Test audio playback manually after changes — subtle timing regressions won't show in unit tests

### What NOT to Change

- Do not change the double-buffered scheduling algorithm
- Do not change the ring buffer implementation
- Do not change `SoundFontStepSequencer`'s public API or batch scheduling behavior

### References

- [Source: docs/walkthrough/2-audio-engine.md — observations #2, #3, #5]
- [Source: docs/walkthrough/3-training-sessions.md — observation #2]

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-04-06: Story created from walkthrough observations
