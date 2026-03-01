# Story 27.1: Decompose Play Method

Status: review

## Story

As a developer maintaining SoundFontNotePlayer,
I want the `play()` method decomposed into named sub-operations at a uniform abstraction level,
so that the method reads as a clear sequence of intent-revealing steps and each sub-operation can be understood and modified independently.

## Acceptance Criteria

1. `play()` reads as a short sequence of named calls — no inline implementation details remain in the body
2. Each extracted method has a single responsibility at a consistent abstraction level
3. No behavioral change — all existing `SoundFontNotePlayerTests` pass without modification
4. No new public API — all extracted methods are `private`
5. No new files — refactoring stays within `SoundFontNotePlayer.swift`

## Tasks / Subtasks

- [x] Task 1: Extract preset selection into private method (AC: #1, #2, #4)
  - [x] 1.1 Create `private func ensurePresetLoaded() async throws` that reads `userSettings.soundSource`, parses SF2 tag, calls `loadPreset`, and falls back to default on failure
  - [x] 1.2 Replace lines 109–118 in `play()` with single call
- [x] Task 2: Extract frequency validation into private method (AC: #1, #2, #4)
  - [x] 2.1 Create `private func validateFrequency(_ frequency: Frequency) throws` containing the guard + throw
  - [x] 2.2 Replace lines 120–127 in `play()` with single call
- [x] Task 3: Extract audio session configuration into private method (AC: #1, #2, #4)
  - [x] 3.1 Create `private func ensureAudioSessionConfigured() throws` containing the one-time AVAudioSession setup
  - [x] 3.2 Replace lines 129–135 in `play()` with single call
- [x] Task 4: Extract engine startup into private method (AC: #1, #2, #4)
  - [x] 4.1 Create `private func ensureEngineRunning() throws` containing the conditional `engine.start()`
  - [x] 4.2 Replace lines 137–139 in `play()` with single call
- [x] Task 5: Extract MIDI note-on sequence into private method (AC: #1, #2, #4)
  - [x] 5.1 Create `private func startNote(frequency: Frequency, velocity: MIDIVelocity, amplitudeDB: AmplitudeDB) -> UInt8` that decomposes frequency, sets gain, sends pitch bend, starts MIDI note, and returns the midiNote
  - [x] 5.2 Replace lines 141–150 in `play()` with single call
- [x] Task 6: Verify all tests pass (AC: #3)
  - [x] 6.1 Run full test suite: `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [x] 6.2 Confirm zero test modifications were needed

## Dev Notes

### Refactoring Target

File: `Peach/Core/Audio/SoundFontNotePlayer.swift` (lines 108–153)

The current `play()` method mixes seven operations at three different abstraction levels:

| Operation | Lines | Abstraction Level |
|---|---|---|
| Preset selection from settings | 109–118 | High (business logic) |
| Frequency validation | 120–127 | High (input validation) |
| Audio session configuration | 129–135 | Medium (infrastructure) |
| Engine startup | 137–139 | Medium (infrastructure) |
| Frequency decomposition + pitch bend | 141–143 | Low (math) |
| Volume/gain + MIDI note-on | 145–150 | Low (MIDI commands) |
| PlaybackHandle creation | 152 | Low (construction) |

After refactoring, `play()` should read approximately:

```swift
func play(frequency: Frequency, velocity: MIDIVelocity, amplitudeDB: AmplitudeDB) async throws -> PlaybackHandle {
    try await ensurePresetLoaded()
    try validateFrequency(frequency)
    try ensureAudioSessionConfigured()
    try ensureEngineRunning()
    let midiNote = startNote(frequency: frequency, velocity: velocity, amplitudeDB: amplitudeDB)
    return SoundFontPlaybackHandle(sampler: sampler, midiNote: midiNote, channel: Self.channel, stopPropagationDelay: stopPropagationDelay)
}
```

### Critical Constraints

- **Pure refactoring** — zero behavioral changes. The existing test suite is the safety net; do NOT modify any test.
- **Keep `loadPreset(program:bank:)` public** — it is called directly in tests and is part of the class API.
- Existing static helpers (`parseSF2Tag`, `pitchBendValue`, `decompose`) stay as-is — they are already well-extracted.
- `sendPitchBendRange()` already exists as a private helper — follow that naming and placement convention.
- Use `ensure*` naming for idempotent setup methods (consistent with Apple AVFoundation conventions).
- Method grouping: place new private methods in a new `// MARK: - Play Sub-operations` section after the existing `// MARK: - NotePlayer Protocol` section, before `// MARK: - MIDI Helpers`.

### Testing Standards

- Framework: **Swift Testing** (`@Test`, `#expect()`)
- Run: `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
- All tests must be `async`
- No `test` prefix on function names
- Existing tests in `PeachTests/Core/Audio/SoundFontNotePlayerTests.swift` (404 lines, 30+ tests) cover all sub-operations — they must all pass unchanged

### Project Structure Notes

- Single file change: `Peach/Core/Audio/SoundFontNotePlayer.swift`
- No cross-feature impact — `NotePlayer` protocol interface unchanged
- No new dependencies or imports

### References

- [Source: Peach/Core/Audio/SoundFontNotePlayer.swift#play()] — current implementation (lines 108–153)
- [Source: PeachTests/Core/Audio/SoundFontNotePlayerTests.swift] — full test coverage (404 lines)
- [Source: docs/project-context.md] — testing standards, concurrency rules
- [Source: docs/planning-artifacts/architecture.md] — NotePlayer protocol, PlaybackHandle pattern

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

No debug issues encountered.

### Completion Notes List

- Decomposed `play()` from 45 lines of mixed-abstraction inline code into 6 lines of intent-revealing named calls
- Extracted 5 private methods: `ensurePresetLoaded()`, `validateFrequency(_:)`, `ensureAudioSessionConfigured()`, `ensureEngineRunning()`, `startNote(frequency:velocity:amplitudeDB:)`
- Placed all new methods in `// MARK: - Play Sub-operations` section between NotePlayer Protocol and MIDI Helpers
- All extracted methods are `private` — no new public API
- Full test suite passes with zero test modifications — pure behavioral equivalence confirmed
- Single file changed — no new files created

### Change Log

- 2026-03-01: Decomposed `play()` into 5 named sub-operations at uniform abstraction level

### File List

- `Peach/Core/Audio/SoundFontNotePlayer.swift` (modified)
