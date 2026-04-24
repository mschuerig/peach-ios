# Story 69.5: Fix Force Unwraps Flagged in Compliance Report

Status: done

## Story

As a **developer ensuring crash safety**,
I want force unwraps in production code replaced with safe alternatives,
so that the app does not crash from unexpected nil values during App Store review.

## Acceptance Criteria

1. **Given** `PeachApp.swift` **When** loading the SoundFont bundle resource **Then** it uses `guard let` with a descriptive `fatalError` or graceful fallback instead of `!`.
2. **Given** `MIDIKitAdapter.swift` **When** accessing the continuation **Then** it uses safe unwrapping instead of implicitly unwrapped optionals.
3. **Given** the full test suite **When** run on both iOS and macOS **Then** all tests pass.

## Tasks / Subtasks

- [x] Fix force unwrap in `PeachApp.swift` line 57 (AC: #1)
  - [x] Current: `let sf2URL = Bundle.main.url(forResource: "Samples", withExtension: "sf2")!`
  - [x] Replace with `guard let` + descriptive `fatalError("Required resource Samples.sf2 not found in bundle")`
  - [x] A `fatalError` with a message is acceptable here because a missing bundle resource is a build/packaging error, not a runtime condition — but the message must explain what went wrong
- [x] Fix implicitly unwrapped optional in `MIDIKitAdapter.swift` lines 26-27 (AC: #2)
  - [x] Current pattern: `var cont: AsyncStream<MIDIInputEvent>.Continuation!` then assigned inside `AsyncStream` closure
  - [x] Refactor to avoid IUO — use `AsyncStream.makeStream(of:)` factory method which returns `(stream, continuation)` tuple, eliminating the need for the IUO entirely
- [x] Run tests: `bin/test.sh && bin/test.sh -p mac` (AC: #3)
- [x] Build both platforms: `bin/build.sh && bin/build.sh -p mac`

## Dev Notes

**PeachApp.swift fix** — The force unwrap on line 57 is inside a `do/catch` block that already has `fatalError` for other init failures. Using `guard let ... else { fatalError(...) }` is consistent with the existing error handling pattern and adds a descriptive message.

**MIDIKitAdapter.swift fix** — The `AsyncStream.makeStream(of:)` API (available since Swift 5.9) returns a `(stream: AsyncStream<T>, continuation: AsyncStream<T>.Continuation)` tuple. This eliminates the IUO pattern entirely:
```swift
let (stream, continuation) = AsyncStream.makeStream(of: MIDIInputEvent.self)
self.continuation = continuation
self.sharedEvents = stream.share()
```

The compliance report also mentions `self.gridOrigin!` in `RhythmOffsetDetectionSession.swift:199` (guarded, low risk) and `rawBuffer.baseAddress!` in `SoundFontEngine.swift:250` (low-level audio, acceptable). These are out of scope per the ACs but could be addressed opportunistically.

### Project Structure Notes

- `Peach/App/PeachApp.swift` — composition root, line 57
- `Peach/Core/Audio/MIDIKitAdapter.swift` — MIDI adapter, lines 26-29

### References

- `docs/reports/appstore-review-2026-03-28.md` — Warning: Guideline 7, force unwraps
- `docs/project-context.md` — Rule: "No force unwrapping (`!`)"

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6

### Debug Log References
- iOS test run: 1769 passed, 1 failed (PF-004 pre-existing flaky test)
- macOS test run: 1763 passed, 0 failed
- Both platform builds successful

### Completion Notes List
- Replaced force unwrap `Bundle.main.url(...)!` in `PeachApp.swift:setupSoundFontInfrastructure()` with `guard let` + descriptive `fatalError("Required resource Samples.sf2 not found in bundle")`
- Replaced IUO pattern `var cont: AsyncStream<...>.Continuation!` in `MIDIKitAdapter.init()` with `AsyncStream.makeStream(of:)` factory method, eliminating the implicitly unwrapped optional entirely
- Removed redundant `let continuation = self.continuation` local variable since the tuple destructure already provides a local `continuation` for closure capture

### File List
- Peach/App/PeachApp.swift (modified)
- Peach/Core/Audio/MIDIKitAdapter.swift (modified)

## Change Log

- 2026-03-29: Story created
- 2026-04-24: Implementation complete — replaced force unwrap and IUO with safe alternatives
