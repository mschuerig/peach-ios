---
title: 'Fix MIDI stream exhaustion on navigation'
type: 'bugfix'
created: '2026-03-29'
status: 'done'
baseline_commit: 'a24c9da'
context: []
---

# Fix MIDI stream exhaustion on navigation

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** MIDI input only works the first time a training screen is opened. After navigating away and returning, MIDI events stop flowing. This affects all MIDI-enabled training modes on both iOS and macOS. The root cause is that `MIDIKitAdapter` creates a single `AsyncStream` in `init()`, and once a `for await` loop is cancelled (on screen disappear), the stream is consumed and cannot be iterated again.

**Approach:** Change the `MIDIInput.events` property from returning a stored single-use stream to vending a fresh `AsyncStream` per caller, backed by a broadcast pattern. The adapter maintains a set of active continuations and fans out each MIDI event to all of them.

## Boundaries & Constraints

**Always:** Keep `MIDIInput` protocol signature unchanged (`var events: AsyncStream<MIDIInputEvent> { get }`). The fix must be internal to the adapter and mock — consumers must not change.

**Ask First:** Changing the `MIDIInput` protocol if the current approach proves insufficient.

**Never:** Do not change training session or screen lifecycle code. Do not introduce Combine or third-party reactive frameworks.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| First iteration | Screen appears, starts `for await` | MIDI events flow normally | N/A |
| Re-iteration after cancel | Navigate away (task cancelled), return | Fresh `for await` receives new events | N/A |
| Multiple concurrent listeners | Two sessions iterate simultaneously | Both receive all events | N/A |
| Listener cancelled while others active | One task cancelled, another running | Surviving listener unaffected, cancelled continuation removed | N/A |
| No listeners | Events arrive with no active `for await` | Events dropped silently (no crash) | N/A |

</frozen-after-approval>

## Code Map

- `Peach/Core/Ports/MIDIInput.swift` -- Protocol updated: `events` returns `any AsyncSequence<MIDIInputEvent, Never> & Sendable`
- `Peach/Core/Audio/MIDIKitAdapter.swift` -- Use `AsyncAlgorithms.share()` on single `AsyncStream`
- `PeachTests/Mocks/MockMIDIInput.swift` -- Broadcast pattern for test finish+re-iterate support, remove `reset()`
- `PeachTests/Mocks/MockMIDIInputTests.swift` -- Update tests for re-iteration behavior
- `Peach.xcodeproj/project.pbxproj` -- Add `swift-async-algorithms` dependency

## Tasks & Acceptance

**Execution:**
- [x] `Peach/Core/Ports/MIDIInput.swift` -- Change `events` return type to `any AsyncSequence<MIDIInputEvent, Never> & Sendable` to accommodate shared sequence type.
- [x] `Peach/Core/Audio/MIDIKitAdapter.swift` -- Use `stream.share()` from `AsyncAlgorithms` to create a multi-consumer shared sequence. Remove custom broadcaster.
- [x] `PeachTests/Mocks/MockMIDIInput.swift` -- Broadcast pattern for test finish+re-iterate. Remove `reset()`.
- [x] `PeachTests/Mocks/MockMIDIInputTests.swift` -- Replace `resetRestoresState` test with `reIterationAfterFinish` and `concurrentListeners`.

**Acceptance Criteria:**
- Given a training screen was opened and MIDI worked, when the user navigates away and returns, then MIDI events flow again without app restart.
- Given two training screens iterate `events` concurrently, when a MIDI event arrives, then both receive it.

## Verification

**Commands:**
- `bin/test.sh -s MockMIDIInputTests` -- expected: all tests pass
- `bin/build.sh` -- expected: no errors
- `bin/build.sh -p mac` -- expected: no errors

**Manual checks:**
- Connect a MIDI controller, open a pitch matching training, navigate away, return — MIDI pitch bend still works.
