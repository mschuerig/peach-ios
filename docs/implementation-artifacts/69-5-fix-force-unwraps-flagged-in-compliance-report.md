# Story 69.5: Fix Force Unwraps Flagged in Compliance Report

Status: ready-for-dev

## Story

As a **developer ensuring crash safety**,
I want force unwraps in production code replaced with safe alternatives,
so that the app does not crash from unexpected nil values during App Store review.

## Acceptance Criteria

1. **Given** `PeachApp.swift` **When** loading the SoundFont bundle resource **Then** it uses `guard let` with a descriptive `fatalError` or graceful fallback instead of `!`.
2. **Given** `MIDIKitAdapter.swift` **When** accessing the continuation **Then** it uses safe unwrapping instead of implicitly unwrapped optionals.
3. **Given** the full test suite **When** run on both iOS and macOS **Then** all tests pass.

## Tasks / Subtasks

- [ ] Fix force unwrap in `PeachApp.swift` line 57 (AC: #1)
  - [ ] Current: `let sf2URL = Bundle.main.url(forResource: "Samples", withExtension: "sf2")!`
  - [ ] Replace with `guard let` + descriptive `fatalError("Required resource Samples.sf2 not found in bundle")`
  - [ ] A `fatalError` with a message is acceptable here because a missing bundle resource is a build/packaging error, not a runtime condition — but the message must explain what went wrong
- [ ] Fix implicitly unwrapped optional in `MIDIKitAdapter.swift` lines 26-27 (AC: #2)
  - [ ] Current pattern: `var cont: AsyncStream<MIDIInputEvent>.Continuation!` then assigned inside `AsyncStream` closure
  - [ ] Refactor to avoid IUO — use `AsyncStream.makeStream(of:)` factory method which returns `(stream, continuation)` tuple, eliminating the need for the IUO entirely
- [ ] Run tests: `bin/test.sh && bin/test.sh -p mac` (AC: #3)
- [ ] Build both platforms: `bin/build.sh && bin/build.sh -p mac`

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
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created
