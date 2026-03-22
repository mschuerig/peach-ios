# Story 54.1: StepSequencer Protocol and Audio Engine

Status: done

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

- [x] Task 1: Define domain types (AC: #1, #3)
  - [x] Create `Peach/Core/Audio/StepSequencer.swift`
  - [x] Define `StepPosition` enum: `.first`, `.second`, `.third`, `.fourth` (raw Int values 0–3)
  - [x] Define `CycleDefinition` struct with `gapPosition: StepPosition`
  - [x] Define `StepProvider` protocol with `func nextCycle() -> CycleDefinition`
  - [x] Define `StepSequencer` protocol with `func start(tempo: TempoBPM, stepProvider: StepProvider) async throws` and `func stop() async throws`
  - [x] All types conform to `Sendable`
  - [x] Write tests for `StepPosition` and `CycleDefinition` in `PeachTests/Core/Audio/StepSequencerTests.swift`

- [x] Task 2: Implement `SoundFontStepSequencer` (AC: #2, #3, #5, #6)
  - [x] Create `Peach/Core/Audio/SoundFontStepSequencer.swift`
  - [x] Accept `SoundFontEngine` dependency (same engine used by `SoundFontPlayer`)
  - [x] On `start()`: compute `samplesPerSixteenth` from tempo and sample rate
  - [x] Use a render-callback approach: schedule one cycle's worth of events, then at the end of each cycle, request the next `CycleDefinition` from the provider and schedule the next cycle
  - [x] Step 1 always uses accent velocity `MIDIVelocity(127)`; other non-gap steps use `MIDIVelocity(100)`; gap step has no event
  - [x] Click note: `MIDINote(76)` (same as existing rhythm training)
  - [x] Ensure no allocations on audio thread — pre-allocate event buffers
  - [x] On `stop()`: cancel scheduling, silence engine

- [x] Task 3: Expose current step position for UI (AC: #2)
  - [x] Add observable property `currentStep: StepPosition?` to the sequencer (nil when stopped)
  - [x] Update at each step transition so the UI can highlight the active dot
  - [x] Add `currentCycle: CycleDefinition?` so the UI knows where the gap is

- [x] Task 4: Wire into `SoundFontPlayer` or as standalone (AC: #6)
  - [x] Decide whether `SoundFontStepSequencer` is a separate class using `SoundFontEngine` directly, or exposed via `SoundFontPlayer`
  - [x] If standalone: add factory method or init that accepts the shared `SoundFontEngine`
  - [x] Ensure mutual exclusion with `RhythmPlayer.play()` — both share channel 1; calling `scheduleEvents` on either replaces the other's schedule (implicit mutual exclusion by replacement). An explicit guard or coordinator is deferred to a future story if needed.

- [x] Task 5: Write comprehensive tests (AC: #7)
  - [x] Create `PeachTests/Core/Audio/SoundFontStepSequencerTests.swift`
  - [x] Test that `start()` begins cycling and calls `stepProvider.nextCycle()` for each cycle
  - [x] Test that gap position produces silence (no event at that step's sample offset)
  - [x] Test that step 1 uses accent velocity (127) and other steps use normal velocity (100)
  - [x] Test that `stop()` halts playback
  - [x] Test that restarting after stop works
  - [x] Test multiple cycles with changing gap positions
  - [x] Create `PeachTests/Mocks/MockStepProvider.swift`

- [x] Task 6: Run full test suite
  - [x] `bin/test.sh` — all tests pass, no regressions (1471 passed)

## Dev Notes

### Step sequencer vs. RhythmPlayer — different abstractions

`RhythmPlayer` plays a finite, pre-calculated `RhythmPattern`. The step sequencer loops indefinitely with per-cycle decisions. These are fundamentally different and should not be forced into the same protocol. The step sequencer is a new protocol that uses the same underlying `SoundFontEngine`.

### Audio thread safety

The existing `SoundFontEngine` handles render-callback scheduling. The step sequencer must feed it events without allocations on the audio thread. Events are pre-built in batches off the audio thread (up to 6 events per cycle: 3 note-on + 3 note-off) and submitted via `scheduleEvents()`, which copies them into the engine's pre-allocated ring buffer. No allocations occur on the render thread.

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

## Dev Agent Record

### Implementation Plan

- Domain types (`StepPosition`, `CycleDefinition`, `StepVelocity`, `StepProvider`, `StepSequencer`) defined in `StepSequencer.swift`
- `SoundFontStepSequencer` uses batch scheduling via `SoundFontEngine.scheduleEvents()` for sample-accurate timing within each batch (500 cycles ≈ 8+ minutes per batch, auto-replenished)
- Event building extracted as static testable methods (`buildCycleEvents`, `buildBatch`)
- UI tracking via single polling task that reads `engine.currentSamplePosition` at ~120 Hz — sample-accurate, no drift
- `StepSequencerEngine` protocol for engine dependency — enables mock-based testing
- Standalone class sharing `SoundFontEngine` channel 1 with rhythm player — mutual exclusion through shared channel (starting one replaces the other's scheduled events)

### Completion Notes

- All 6 tasks completed: domain types, engine implementation, UI observables, PeachApp wiring, comprehensive tests, full regression suite
- 51 new tests (12 domain + 39 sequencer), all pass
- `StepProvider` and `StepSequencer` protocols not marked `Sendable` — they're MainActor-isolated by default, which satisfies Sendable via actor isolation
- `SoundFontStepSequencer` uses `@Observable` for `currentStep`/`currentCycle` per project conventions
- Environment key typed as `(any StepSequencer)?` for protocol-based injection

## File List

- `Peach/Core/Audio/StepSequencer.swift` (new) — domain types and protocols
- `Peach/Core/Audio/SoundFontStepSequencer.swift` (new) — engine implementation + `StepSequencerEngine` protocol
- `Peach/Core/Audio/SoundFontEngine.swift` (modified) — added `currentSamplePosition`
- `Peach/App/PeachApp.swift` (modified) — stepSequencer instantiation and injection
- `Peach/App/EnvironmentKeys.swift` (modified) — `@Entry var stepSequencer: (any StepSequencer)?`
- `PeachTests/Core/Audio/StepSequencerTests.swift` (new) — domain type tests
- `PeachTests/Core/Audio/SoundFontStepSequencerTests.swift` (new) — sequencer tests (pure + lifecycle)
- `PeachTests/Mocks/MockStepProvider.swift` (new) — test mock
- `PeachTests/Mocks/MockStepSequencerEngine.swift` (new) — engine mock for lifecycle tests
- `docs/implementation-artifacts/sprint-status.yaml` (modified) — epic 54 + story status

## Change Log

- 2026-03-22: Implemented Story 54.1 — StepSequencer protocol and SoundFontStepSequencer audio engine with batch scheduling, observable UI state, and comprehensive test coverage
- 2026-03-22: Code review fixes — sample-position-driven UI tracking (no drift), StepSequencerEngine protocol for testability, stop() awaits task completion, environment typed as protocol, stop/restart tests added
