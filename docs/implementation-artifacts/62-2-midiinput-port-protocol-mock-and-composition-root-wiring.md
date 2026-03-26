# Story 62.2: MIDIInput Port Protocol, Mock, and Composition Root Wiring

Status: done

## Story

As a **developer**,
I want a `MIDIInput` port protocol with a mock and composition root wiring,
So that training sessions can consume MIDI events through the standard environment injection pattern and domain logic is fully testable without hardware.

## Acceptance Criteria

1. **Given** `Core/Ports/MIDIInput.swift` **When** defined **Then** the protocol declares `var events: AsyncStream<MIDIInputEvent> { get }` and `var isConnected: Bool { get }`

2. **Given** `PeachTests/Mocks/MockMIDIInput.swift` **When** created **Then** it conforms to `MIDIInput` **And** it follows the project mock contract: supports yielding events on demand, tracks `isConnected`, provides `reset()`, and allows test-controlled event sequences

3. **Given** `App/EnvironmentKeys.swift` **When** the `@Entry` is added **Then** it declares `var midiInput: (any MIDIInput)?` with `nil` default (not all sessions need MIDI)

4. **Given** the full test suite **When** run **Then** all existing tests pass with zero regressions

## Tasks / Subtasks

- [x] Task 1: Create `MIDIInput` port protocol (AC: #1)
  - [x] 1.1 Create `Peach/Core/Ports/MIDIInput.swift`
  - [x] 1.2 Define `protocol MIDIInput` with `var events: AsyncStream<MIDIInputEvent> { get }` and `var isConnected: Bool { get }`
  - [x] 1.3 Protocol must be `nonisolated` — Core/Ports protocols do not require MainActor isolation
- [x] Task 2: Create `MockMIDIInput` (AC: #2)
  - [x] 2.1 Create `PeachTests/Mocks/MockMIDIInput.swift` (NOT `PeachTests/Core/Ports/` — epic AC has wrong path; project convention is `PeachTests/Mocks/`)
  - [x] 2.2 Follow the mock contract from `MockStepSequencer` pattern: `final class`, call tracking, callbacks, `reset()`
  - [x] 2.3 Implement `events` as `AsyncStream<MIDIInputEvent>` backed by an `AsyncStream.Continuation` stored as a property, so tests can yield events on demand via `send(_ event:)` and `finish()`
  - [x] 2.4 Implement `isConnected` as a mutable `Bool` property (default `true`) — tests set directly
  - [x] 2.5 Provide `reset()` to clear state
- [x] Task 3: Write tests for `MockMIDIInput` (AC: #2)
  - [x] 3.1 Create `PeachTests/Mocks/MockMIDIInputTests.swift`
  - [x] 3.2 Test yielding events via `send()` and consuming via `for await` loop
  - [x] 3.3 Test `finish()` terminates the stream
  - [x] 3.4 Test `isConnected` default and mutation
  - [x] 3.5 Test `reset()` resets state
- [x] Task 4: Add `@Entry` to EnvironmentKeys (AC: #3)
  - [x] 4.1 In `Peach/App/EnvironmentKeys.swift`, add `@Entry var midiInput: (any MIDIInput)? = nil` in the Core Environment Keys section
  - [x] 4.2 No preview stub needed — `nil` default means "no MIDI available"
- [x] Task 5: Verify no regressions (AC: #4)
  - [x] 5.1 Run full test suite via `bin/test.sh`
  - [x] 5.2 Verify build succeeds via `bin/build.sh` — no new warnings
  - [x] 5.3 Confirm no changes to PeachApp.swift — wiring the production instance is story 62.3

## Dev Notes

### Architecture Context

This is story 2 of 4 in the MIDI input epic. It creates the **port protocol** and **mock** — the architectural seam between domain logic and external MIDI hardware. Story 62.3 creates the production MIDIKit adapter; story 62.4 consumes the protocol in `ContinuousRhythmMatchingSession`.

The `MIDIInput` protocol follows the same pattern as all existing port protocols in `Core/Ports/`:
- `NotePlayer` — audio playback abstraction
- `StepSequencer` — rhythm sequencer abstraction
- `RhythmPlayer` — rhythm pattern playback
- `HapticFeedback` — haptic feedback abstraction

All are defined in `Core/Ports/`, have mocks in `PeachTests/Mocks/`, and are wired via `@Entry` in `EnvironmentKeys.swift`.

### Port Protocol Design

The protocol has exactly two members:

```swift
protocol MIDIInput {
    var events: AsyncStream<MIDIInputEvent> { get }
    var isConnected: Bool { get }
}
```

- `events` — `AsyncStream<MIDIInputEvent>` that yields events as they arrive. Consumers iterate with `for await event in midiInput.events`. The stream is infinite (lives as long as the adapter) and never finishes during normal operation.
- `isConnected` — reflects whether any MIDI source is currently available. Used for UI status indication in future stories (not consumed yet in 62.4, but part of FR116).

Key design decisions:
- **`AsyncStream`, not `AsyncThrowingStream`** — MIDI input never errors; disconnection is communicated via `isConnected`, not stream failure.
- **Optional in environment (`(any MIDIInput)?`)** — not all training modes consume MIDI; `nil` means MIDI unavailable. Sessions that accept MIDI will check for `nil` before subscribing.
- **No `start()`/`stop()` methods** — the stream is always available; consumers subscribe/unsubscribe by iterating or cancelling their `Task`.

### `MIDIInputEvent` Already Exists

Created in story 62.1 at `Peach/Core/Music/MIDIInputEvent.swift`:

```swift
nonisolated enum MIDIInputEvent: Hashable, Sendable {
    case noteOn(note: MIDINote, velocity: MIDIVelocity, timestamp: UInt64)
    case noteOff(note: MIDINote, velocity: MIDIVelocity, timestamp: UInt64)
    case pitchBend(value: PitchBendValue, channel: MIDIChannel, timestamp: UInt64)
}
```

Do NOT redefine or modify this type. The protocol uses it as-is.

### Mock Design

`MockMIDIInput` must support **test-controlled event injection**. The key pattern: store an `AsyncStream.Continuation` as a property so tests can call `send(_ event:)` at any point during the test.

```swift
final class MockMIDIInput: MIDIInput {
    // Stream + continuation pair
    var events: AsyncStream<MIDIInputEvent> { stream }

    // Test controls
    var isConnected: Bool = true
    func send(_ event: MIDIInputEvent) { ... }
    func finish() { ... }
    func reset() { ... }
}
```

Construction pattern: create the `AsyncStream` and capture the continuation in `init()`. The `send()` method yields events into the continuation. The `finish()` method terminates the stream.

**Important:** After `finish()` + `reset()`, a new stream must be created so the mock is reusable across test phases. Implement `reset()` to reinitialize the stream/continuation pair.

Follow existing mock conventions from `MockStepSequencer.swift`:
- `final class` (not struct — needs mutable state and reference identity)
- `@testable import Peach`
- Call tracking where applicable
- `reset()` method
- No `@MainActor` annotation on the mock class itself (mocks are classes, default MainActor applies)

### `@Entry` Pattern

Add to the Core Environment Keys section in `EnvironmentKeys.swift`:

```swift
@Entry var midiInput: (any MIDIInput)? = nil
```

This follows the pattern of `rhythmPlayer` and `stepSequencer` which are also optional:
```swift
@Entry var rhythmPlayer: (any RhythmPlayer)? = nil
@Entry var stepSequencer: (any StepSequencer)? = nil
```

No `PreviewMIDIInput` stub needed — the `nil` default handles previews naturally.

### File Placement

| File | Location | Rationale |
|------|----------|-----------|
| `MIDIInput.swift` | `Peach/Core/Ports/` | Port protocol alongside `StepSequencer`, `NotePlayer`, etc. |
| `MockMIDIInput.swift` | `PeachTests/Mocks/` | Mock alongside `MockStepSequencer`, `MockNotePlayer`, etc. |
| `MockMIDIInputTests.swift` | `PeachTests/Mocks/` | Tests for the mock itself |
| `EnvironmentKeys.swift` | `Peach/App/` | Existing file — add one `@Entry` line |

**Note:** The epic AC says `PeachTests/Core/Ports/MockMIDIInput.swift` — this is incorrect. The project convention is `PeachTests/Mocks/` for all mocks. No mock files exist in `PeachTests/Core/Ports/`.

### What NOT To Do

- Do NOT import `MIDIKitIO` anywhere — this story is pure protocol + mock. MIDIKit is only used in story 62.3.
- Do NOT wire anything in `PeachApp.swift` — story 62.3 creates the production adapter and injects it. This story only adds the `@Entry` with `nil` default.
- Do NOT consume `MIDIInput` in any session — story 62.4 integrates it into `ContinuousRhythmMatchingSession`.
- Do NOT add `import SwiftUI` to `Core/Ports/MIDIInput.swift` — Core/ is framework-free.
- Do NOT add `start()`/`stop()` methods to the protocol — the stream lifecycle is managed by iteration/cancellation, not explicit calls.
- Do NOT create `PeachTests/Core/Ports/` directory — mocks go in `PeachTests/Mocks/`.

### Pattern Reference

Follow the exact pattern of existing `Core/Ports/` protocols:
- No `import` statements needed (or just `import Foundation` if `AsyncStream` requires it — check if it's available without import)
- No `@MainActor` annotation on protocol
- Protocol has no default implementations
- Mock is `final class` in `PeachTests/Mocks/`

For mock structure, reference `MockStepSequencer.swift` — it's the closest analog (protocol with async members, test state tracking, reset).

### Previous Story Intelligence

From story 62.1 completion:
- `MIDIInputEvent` is `nonisolated enum` conforming to `Hashable, Sendable` — the protocol's `AsyncStream` element type
- `MIDIChannel` domain type was added (range 0-15) during code review — used in `.pitchBend` case
- `MIDIVelocity` got `nonisolated` keyword added (boy scout fix) — all `Core/Music/` types are now consistent
- 1483 tests pass as of story 62.1 completion
- MIDIKit v0.11.0 pinned with `upToNextMinorVersion` (0.x safety)

### Git Intelligence

Recent commits show the MIDI epic is actively in progress:
- `d99d2b2` — Code review fixes for 62.1 (MIDIChannel, version pinning, velocity-0 AC)
- `f0ad811` — Story 62.1 implementation
- `ce5781c` — Story 62.1 creation
- `a0e1b68` — Epic breakdown
- `73b286e` — MIDI technical research

### References

- [Source: docs/planning-artifacts/epics.md#Epic 62, Story 62.2] — AC and epic context
- [Source: docs/planning-artifacts/research/technical-midi-input-ios-research-2026-03-26.md] — Port protocol design, AsyncStream pattern, testing strategy
- [Source: docs/project-context.md] — File placement, Core/Ports conventions, mock contract, @Entry pattern
- [Source: docs/implementation-artifacts/62-1-add-midikit-dependency-and-define-midi-input-event-types.md] — Previous story learnings and file list
- FR117 (AsyncStream of typed MIDIInputEvent), FR120 (MIDIInput port protocol in Core/Ports/), FR122 (composition root wiring via @Entry), FR128 (testable via mock)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Initial test run crashed Clone 1 simulator due to `MIDIVelocity(0)` in noteOff test event — `MIDIVelocity` range is 1-127, not 0-127. Fixed by using `MIDIVelocity(64)` for noteOff release velocity.

### Completion Notes List

- Created `MIDIInput` nonisolated protocol in `Core/Ports/` with `events: AsyncStream<MIDIInputEvent>` and `isConnected: Bool` — follows existing port protocol pattern (no imports, no `@MainActor`)
- Created `MockMIDIInput` as `final class` with `AsyncStream.Continuation`-backed event injection: `send(_:)`, `finish()`, `reset()` — reset reinitializes stream/continuation pair for reusability
- Used `nonisolated(unsafe)` for stream/continuation storage and `nonisolated` for `send`/`finish`/`events` to satisfy `nonisolated` protocol conformance while maintaining mutable state
- 5 tests covering: event yielding via send/for-await, stream termination via finish, isConnected default/mutation, reset restoring fresh state with working new stream
- Added `@Entry var midiInput: (any MIDIInput)? = nil` in EnvironmentKeys Core section — no preview stub needed
- No changes to PeachApp.swift — production wiring deferred to story 62.3
- All 1488 tests pass (1483 existing + 5 new), build clean (no new warnings)

### Change Log

- 2026-03-26: Implemented story 62.2 — MIDIInput port protocol, MockMIDIInput, tests, and @Entry environment key

### File List

- Peach/Core/Ports/MIDIInput.swift (new)
- PeachTests/Mocks/MockMIDIInput.swift (new)
- PeachTests/Mocks/MockMIDIInputTests.swift (new)
- Peach/App/EnvironmentKeys.swift (modified — added `@Entry var midiInput`)
