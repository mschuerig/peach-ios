# Inter-Thread Patterns for Audio

Crossing the boundary between non-realtime code and the render thread is the hardest part of audio programming. The patterns below are community-canonical (Bencina, Doumler, Tyson, Liljedahl, JUCE conventions). They are *not* Apple-documented; they are practitioner consensus.

## The Setup

You have:

- **Context A** — non-realtime. Main thread, a background dispatch queue, a Swift Task, an actor. Can block, allocate, lock, log, do I/O. Bounded in priority. Owns user-facing state and orchestration.
- **Context B** — the render thread. Real-time priority. Cannot block, allocate, lock with contention, or do I/O. Owns sample-by-sample state.

Data must flow A→B (parameter changes, MIDI events, mode switches) and sometimes B→A (level metering, "I processed your message", "I detected silence"). Information that flows in both directions does so via *two separate one-way mechanisms*. There is no single bidirectional primitive that is both safe and bounded-time.

## Pattern 1 — SPSC Lock-Free FIFO (A → B stream)

The canonical pattern for streaming events from a single producer (A) to a single consumer (B).

**Properties:**

- Single producer, single consumer. (Multi-producer needs different primitives.)
- Wait-free for both sides; the producer never blocks the consumer and vice versa.
- Preserves submission order.
- Bounded capacity; producer either blocks (acceptable on A side), drops oldest, or returns "queue full" (best for diagnostics).

**Reference implementations:**

- **TPCircularBuffer** (Michael Tyson) — battle-tested C/Obj-C lock-free ring buffer used in AudioKit and many shipping apps. Wrap in a thin Swift adapter; the buffer itself stays in C.
- **QueueWorld** (Ross Bencina) — C++ ; richer API with separate types for command and result queues.
- **JUCE `AbstractFifo`** — cross-platform C++ SPSC primitive used inside JUCE plugins.
- **A hand-rolled ring buffer** with atomic head/tail indices. ~40 lines of Swift over `UnsafeMutableBufferPointer<Element>`. Reasonable for trivial-element types.

**Operating shape:**

```
Producer (A):
  - construct an event (stack or pre-allocated pool)
  - publish via release-store on tail index
  - never block. If full, drop or fail with a counter.

Consumer (B), at start of render callback:
  - read all available events (head ≠ tail)
  - apply each event in submission order to render-thread state
  - acquire-load head/tail indices
  - then continue with normal rendering
```

**Use for:** any A→B stream where submission order matters and the producer cannot block. MIDI dispatch is the canonical example. Parameter automation, transport commands, voice triggers, all qualify.

## Pattern 2 — Atomic State Swap (A → B replacement)

Bencina's swap/exchange pattern. For replacing a whole state object (a signal graph, a parameter block, a tuning table, an impulse response) in O(1).

**Operating shape:**

```
Producer (A):
  - build a new state object off-line
  - atomic-exchange the pointer the consumer is reading
  - receive the old pointer back
  - defer reclaim of the old object (e.g., release after a grace period)

Consumer (B):
  - on each render cycle, atomic-load the pointer
  - read state through it
```

**Properties:**

- O(1) update regardless of state size.
- Consumer never sees a partially-updated state.
- Old state must outlive the last render cycle that used it — *don't dealloc immediately*. Either:
  - Reference-count it and let the render thread's final deref drop it (but be careful who runs the deinit), or
  - Use a deferred-reclaim mechanism (Tyson's AEManagedValue, hazard pointers, RCU-style epoch reclamation).

**Use for:** large state that changes occasionally (preset switch, voice-graph reconfiguration, tuning table swap, IR change). Not for high-frequency event streams; use the FIFO for those.

**Caveat:** This pattern works on objects *you own and can pointer-swap*. It does NOT directly apply to internal voice/CC state inside a closed-source AU (e.g. `AVAudioUnitSampler`). For those, swap is for *your* state around the AU, not the AU's internal state.

**Doumler's RCU framing:** the same pattern as Linux's Read-Copy-Update. Real-time threads read the current state via a pointer load (no lock). Updates publish a new copy and defer reclaim of the old. See his ADC talk "Thread Synchronisation in Real-Time Audio Processing With RCU".

## Pattern 3 — Second Queue for B → A Acknowledgement

When A needs to know "did the render thread process my message", you need a *return path*. Never poll/block on the A side; the canonical answer is a second SPSC FIFO going the other way.

**Operating shape:**

```
A → B FIFO carries commands.
B → A FIFO carries acknowledgements / results / events.

A:
  - submit command with a unique ID (or sequence number)
  - continue doing other work
  - periodically drain the B→A queue and match acks to outstanding commands

B (render thread):
  - process commands from A→B in submission order
  - for each command requiring ack, post an ack message to B→A
  - never block on B→A; if it's full, drop the ack (and define what that means)
```

**Properties:**

- Both sides are non-blocking.
- A learns about B's state via *push*, never *poll*.
- Ack pattern naturally supports request/reply, sequence acknowledgement, and progress notifications.

**Use for:** "main thread needs to know the audio thread is done with the previous configuration", level metering (B periodically pushes RMS/peak; A samples for UI), silence detection, "I'm done preparing the next clip", AUv3 parameter automation capture.

Bencina, QueueWorld README: "inter-thread communication for real-time audio applications where mutexes are not an option due to priority inversion. … `QwSpscUnorderedResultQueue` for returning results from a server thread to a client."

## Pattern 4 — Atomic Flag with `exchange(false)`

A one-shot signal: "do this on the next cycle". The producer atomically sets a flag; the consumer atomic-exchanges it to `false` and acts if it was `true`.

```swift
let needsReset = Atomic<Bool>(false)

// A:
needsReset.store(true, ordering: .relaxed)

// B (start of render cycle):
if needsReset.exchange(false, ordering: .relaxed) {
    performReset()
}
```

**Properties:**

- Wait-free on both sides.
- Cheap and obvious.
- **Idempotent** — setting twice in rapid succession is the same as setting once.

### The Critical Anti-Pattern

If you have an **in-band event stream** (Pattern 1 FIFO carrying MIDI events) AND a **parallel atomic flag** (Pattern 4 carrying "do X on next cycle") going to the same consumer, **they have no ordering relationship with each other**.

Concrete failure mode:

```
Time t1: A submits noteOn(60) via Pattern 1 FIFO.
Time t2: A sets `needsAllNotesOff = true` via Pattern 4 flag.
Time t3: B render cycle begins.
       Reads flag: true → dispatches CC#123 All Notes Off.
       Reads FIFO: noteOn(60) → dispatches startNote(60).
Result: noteOn dispatched AFTER CC#123. Audible.

Same sequence in inverted A-side order:

Time t1: A sets `needsAllNotesOff = true` via Pattern 4 flag.
Time t2: A submits noteOn(60) via Pattern 1 FIFO.
Time t3: B render cycle begins.
       Reads flag: true → dispatches CC#123.
       Reads FIFO: noteOn(60) → dispatches startNote(60).
Result: same B-side order despite different A-side order.

A-side submission order has no relationship to B-side application order
when the two A→B channels are uncoordinated. If you need the reset to be
"before the next noteOn", the reset must travel in the same FIFO behind
the noteOn — not in a parallel channel.
```

**Rule:** If two A→B mechanisms target the same consumer state and the order between their effects matters, they must share a single ordering primitive. Either:

- Put everything in the FIFO (so the reset is a "reset" event scheduled in submission order).
- Define which one logically precedes the other and never violate that order (brittle).

When this constraint is violated, intermittent races appear that look like "the OS dropped a message". They didn't; the architecture had no answer to "in what order does this consumer see them".

## Pattern Selection Guide

| You want to | Use |
|---|---|
| Stream MIDI / parameter events main → render | **Pattern 1** (SPSC FIFO) |
| Replace a whole state object (preset, graph, IR table) | **Pattern 2** (atomic swap + deferred reclaim) |
| Let the main thread know the render thread saw something | **Pattern 3** (second SPSC FIFO render → main) |
| Trigger a one-off render-side action | **Pattern 4** (atomic flag) — but only if no in-band path exists for the same logical event |

If you find yourself reaching for Pattern 4 alongside Pattern 1 targeting the same consumer, **stop**. The pattern you actually want is Pattern 1 with the trigger message *in the queue*.

## Why Polling From the Main Thread Is Wrong

There is a tempting alternative: the main thread submits a command, then *polls* a render-thread variable until it sees the command was processed.

Why this is wrong:

1. **Polling burns CPU on the main thread.** That CPU comes out of UI responsiveness.
2. **Bounded-time polling requires a bounded-time guarantee from the render thread**, which it doesn't owe you. The render thread runs when its deadline says it runs.
3. **Polling intrinsically makes the main thread depend on render-thread state visibility**, hard to test and easy to deadlock.
4. **The canonical alternative is cheap.** A second SPSC FIFO with an ack message is small and deterministic.

Doumler, on the dual: "This wait loop should never run on the audio thread; the audio thread should only ever call `try_lock()` and fall back to an alternative strategy on failure." By symmetry: the main thread shouldn't wait-loop on the audio thread either. Both sides communicate by push, never pull.

## Sendability and Swift

The lock-free primitives are typically implemented in C or with Swift `Atomic`. To pass them safely across Swift Concurrency boundaries:

- The buffer is `Sendable` as a value type wrapping an `UnsafeMutableBufferPointer` if you take responsibility for its uniqueness (typically `@unchecked Sendable` with a documented invariant).
- The producer and consumer roles must each be confined to one isolation domain — typically producer on `@MainActor` (or a specific actor), consumer on a `nonisolated` callback bound to the render thread.
- Don't try to model the render thread as an actor. It has no Swift Concurrency executor.

## Library Choices

For Apple-platform Swift code:

- **TPCircularBuffer** — pure C; thin Swift adapter. Battle-tested. The de-facto answer for SPSC FIFO on iOS.
- **AEManagedValue** — Pattern 2 (atomic state swap) on iOS. Uses deferred reclaim via periodic main-thread polling (acceptable on the non-realtime side).
- **Swift's `Atomic<T>`** (Swift 6+) — individual flags and indices.
- **Hand-rolled** — fine for simple cases. ~40 LOC over `UnsafeMutableBufferPointer`.
- **JUCE's `AbstractFifo`** — when sharing code with a JUCE plugin build.

Avoid:

- Combine `PassthroughSubject` for audio events. Not RT-safe; uses internal locking.
- `AsyncStream` for events to the render thread. The render thread is not a Swift Concurrency consumer.
- `DispatchQueue` (`async` or `sync`) for crossing into the render thread. The audio thread is not a dispatch queue. `DispatchQueue` is fine for *non-realtime* coordination on the A side.

## Cross-Reference to Other Platforms

The patterns above are universal across audio platforms:

- **JUCE** (C++, cross-platform) — `AbstractFifo` + atomic params; same Pattern 1 / Pattern 2 split.
- **CLAP** (newer open standard) — bakes Pattern 2 (atomic swap) into parameter automation via `clap_event_param_value`.
- **VST3 (Steinberg)** — `IAudioProcessor::process` is the render-thread contract; same four rules.
- **AAX (Avid Pro Tools)** — render-thread contract with the same RT-safety expectations.
- **iPlug2, RACK (VCV), SuperCollider** — same patterns under the hood.

When borrowing patterns across stacks, the data structures translate cleanly; only the API surface differs.
