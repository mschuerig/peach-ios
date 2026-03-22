# Story 54.1: StepSequencer Protocol and Audio Engine

Status: backlog

## Story

As a **developer**,
I want a `StepSequencer` protocol and audio engine implementation that loops a 4-step cycle with callback-driven step configuration,
so that continuous rhythm training has sample-accurate, indefinitely looping playback with per-cycle gap selection.

## Acceptance Criteria

1. **Given** a `StepSequencer` protocol, **when** inspected, **then** it exposes `start(tempo:stepProvider:)` and `stop()` methods, where `StepProvider` supplies a `CycleDefinition` at the top of each 4-step loop.

2. **Given** `start()` is called with a tempo and step provider, **when** the sequencer runs, **then** it plays a continuous loop of 4 sixteenth notes at the given tempo, calling back to the step provider at each cycle boundary for the next `CycleDefinition`.

3. **Given** a `CycleDefinition` with a gap at position N, **when** the cycle plays, **then** step 1 plays at accent velocity (127), non-gap steps 2–4 play at normal velocity (100), and the gap step is pure silence (no MIDI event).

4. **Given** the sequencer is running, **when** `stop()` is called, **then** playback ceases immediately and the sequencer can be restarted.

5. **Given** the sequencer completes a cycle, **when** the next cycle begins, **then** it calls `stepProvider.nextCycle()` to get the gap position for the upcoming cycle — the decision happens before the cycle's audio renders, not during.

6. **Given** the underlying audio infrastructure, **when** the sequencer schedules events, **then** it reuses `SoundFontEngine` for sample-accurate MIDI event rendering on the audio thread, with no allocations or locks during rendering.

7. **Given** unit tests with a mock audio engine, **when** the sequencer is tested, **then** cycle timing, gap silence, accent velocity, and stop behavior are verified.

## Tasks / Subtasks

- [ ] Task 1: Define domain types (AC: #1, #3)
  - [ ] Create `Peach/Core/Audio/StepSequencer.swift`
  - [ ] Define `StepPosition` enum: `.first`, `.second`, `.third`, `.fourth` (raw Int values 0–3)
  - [ ] Define `CycleDefinition` struct with `gapPosition: StepPosition`
  - [ ] Define `StepProvider` protocol with `func nextCycle() -> CycleDefinition`
  - [ ] Define `StepSequencer` protocol with `func start(tempo: TempoBPM, stepProvider: StepProvider) async throws` and `func stop() async throws`
  - [ ] All types conform to `Sendable`
  - [ ] Write tests for `StepPosition` and `CycleDefinition` in `PeachTests/Core/Audio/StepSequencerTests.swift`

- [ ] Task 2: Implement `SoundFontStepSequencer` (AC: #2, #3, #5, #6)
  - [ ] Create `Peach/Core/Audio/SoundFontStepSequencer.swift`
  - [ ] Accept `SoundFontEngine` dependency (same engine used by `SoundFontPlayer`)
  - [ ] On `start()`: compute `samplesPerSixteenth` from tempo and sample rate
  - [ ] Use a render-callback approach: schedule one cycle's worth of events, then at the end of each cycle, request the next `CycleDefinition` from the provider and schedule the next cycle
  - [ ] Step 1 always uses accent velocity `MIDIVelocity(127)`; other non-gap steps use `MIDIVelocity(100)`; gap step has no event
  - [ ] Click note: `MIDINote(76)` (same as existing rhythm training)
  - [ ] Ensure no allocations on audio thread — pre-allocate event buffers
  - [ ] On `stop()`: cancel scheduling, silence engine

- [ ] Task 3: Expose current step position for UI (AC: #2)
  - [ ] Add observable property `currentStep: StepPosition?` to the sequencer (nil when stopped)
  - [ ] Update at each step transition so the UI can highlight the active dot
  - [ ] Add `currentCycle: CycleDefinition?` so the UI knows where the gap is

- [ ] Task 4: Wire into `SoundFontPlayer` or as standalone (AC: #6)
  - [ ] Decide whether `SoundFontStepSequencer` is a separate class using `SoundFontEngine` directly, or exposed via `SoundFontPlayer`
  - [ ] If standalone: add factory method or init that accepts the shared `SoundFontEngine`
  - [ ] Ensure mutual exclusion with `RhythmPlayer.play()` — cannot run a step sequencer and a pattern simultaneously on the same engine

- [ ] Task 5: Write comprehensive tests (AC: #7)
  - [ ] Create `PeachTests/Core/Audio/SoundFontStepSequencerTests.swift`
  - [ ] Test that `start()` begins cycling and calls `stepProvider.nextCycle()` for each cycle
  - [ ] Test that gap position produces silence (no event at that step's sample offset)
  - [ ] Test that step 1 uses accent velocity (127) and other steps use normal velocity (100)
  - [ ] Test that `stop()` halts playback
  - [ ] Test that restarting after stop works
  - [ ] Test multiple cycles with changing gap positions
  - [ ] Create `PeachTests/Mocks/MockStepProvider.swift`

- [ ] Task 6: Run full test suite
  - [ ] `bin/test.sh` — all tests pass, no regressions

## Dev Notes

### Step sequencer vs. RhythmPlayer — different abstractions

`RhythmPlayer` plays a finite, pre-calculated `RhythmPattern`. The step sequencer loops indefinitely with per-cycle decisions. These are fundamentally different and should not be forced into the same protocol. The step sequencer is a new protocol that uses the same underlying `SoundFontEngine`.

### Audio thread safety

The existing `SoundFontEngine` handles render-callback scheduling. The step sequencer must feed it events without allocations on the audio thread. Pre-allocate a fixed-size event buffer (max 4 events per cycle) and reuse it.

Gap selection (which step is the gap) is computed by the `StepProvider` on the main thread. The result is communicated to the audio thread via an atomic swap or similar lock-free mechanism — same pattern used in `SoundFontPlayer`.

### Velocity constants

```swift
enum StepVelocity {
    static let accent = MIDIVelocity(127)
    static let normal = MIDIVelocity(100)
}
```

Step 1 always gets accent. The gap gets silence. All other steps get normal.

### Cycle timing

At tempo T BPM, one sixteenth note = `60.0 / (T * 4)` seconds. One cycle = 4 sixteenths = `60.0 / T` seconds (one beat). The sequencer must schedule the next cycle's events before the current cycle finishes — ideally at the start of the current cycle, giving a full beat of lead time.

### What NOT to do

- Do NOT modify `RhythmPlayer` or `SoundFontPlayer` — the step sequencer is a new abstraction
- Do NOT create UI screens — that's Story 54.4
- Do NOT implement tap evaluation — that's Story 54.2
- Do NOT add settings — that's Story 54.3
- Do NOT use `ObservableObject` / `@Published` — use `@Observable` if needed
- Do NOT use Combine
- Do NOT add explicit `@MainActor` annotations — redundant with default isolation

### References

- [Source: Peach/Core/Audio/RhythmPlayer.swift — existing pattern protocol for comparison]
- [Source: Peach/Core/Audio/SoundFontPlayer.swift — SoundFontEngine usage patterns]
- [Source: Peach/Core/Audio/SoundFontEngine.swift — low-level audio scheduling]
- [Source: Peach/Core/Music/TempoBPM.swift — sixteenthNoteDuration]
- [Source: Peach/Core/Music/MIDINote.swift — MIDINote(76) click note]
- [Source: Peach/Core/Music/MIDIVelocity.swift — velocity type]
- [Source: docs/project-context.md — project rules and conventions]
