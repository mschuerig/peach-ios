# Story 10.3: Add Amplitude Parameter to NotePlayer

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer**,
I want `NotePlayer.play` to accept an amplitude parameter that controls sound volume independently of velocity,
So that the audio engine can play notes at different loudness levels for the Vary Loudness feature.

## Acceptance Criteria

1. **Given** the `NotePlayer` protocol declares `play(frequency:duration:velocity:)`, **When** the amplitude parameter is added, **Then** the signature becomes `play(frequency:duration:velocity:amplitudeDB:)` where `amplitudeDB: Float` controls sound volume via `AVAudioUnitSampler.masterGain` (dB, -90.0 to +12.0, default 0.0).

2. **Given** `amplitudeDB` is passed as `0.0` (the neutral default), **When** a note is played, **Then** the note plays at unchanged volume (`masterGain = 0.0`), so existing callers are unaffected.

3. **Given** `SoundFontNotePlayer` receives an `amplitudeDB` value, **When** a note is played, **Then** `sampler.masterGain` is set to `amplitudeDB` before `sampler.startNote(...)`, controlling output gain independently of MIDI velocity.

4. **Given** an `amplitudeDB` value outside the range -90.0...12.0 is provided, **When** `play` is called, **Then** `AudioError.invalidAmplitude` is thrown.

5. **Given** `MockNotePlayer` is used in tests, **When** a note is played with an `amplitudeDB` value, **Then** the mock captures the value in `lastAmplitudeDB` and the `playHistory` tuple for test verification.

6. **Given** all existing tests pass before the change, **When** the amplitude parameter is added, **Then** all existing tests pass with `amplitudeDB: 0.0` at all call sites and no audible behavior changes.

## Tasks / Subtasks

- [x] Task 1: Add `AudioError.invalidAmplitude` to error enum (AC: #4)
  - [x] Add `case invalidAmplitude(String)` to `AudioError` in `Peach/Core/Audio/NotePlayer.swift`
  - [x] Add doc comment: "The specified amplitude is invalid (outside -90.0 to +12.0 dB range)."

- [x] Task 2: Update `NotePlayer` protocol signature (AC: #1)
  - [x] Change `play(frequency: Double, duration: TimeInterval, velocity: UInt8)` to `play(frequency: Double, duration: TimeInterval, velocity: UInt8, amplitudeDB: Float)`
  - [x] Update doc comment to document `amplitudeDB` parameter: dB offset for sound volume (-90.0 to +12.0, 0.0 = no change)
  - [x] Note: Swift protocols do not support default parameter values — all call sites must pass `amplitudeDB` explicitly

- [x] Task 3: Update `MockNotePlayer` to track amplitude (AC: #5)
  - [x] Add `var lastAmplitudeDB: Float?` property
  - [x] Change `playHistory` tuple from `(frequency: Double, duration: TimeInterval, velocity: UInt8)` to `(frequency: Double, duration: TimeInterval, velocity: UInt8, amplitudeDB: Float)`
  - [x] Update `play` method signature to include `amplitudeDB: Float`; capture to `lastAmplitudeDB` and append to `playHistory`
  - [x] Update `reset()`: add `lastAmplitudeDB = nil`

- [x] Task 4: Update `MockNotePlayerForPreview` in `TrainingScreen.swift` (AC: #1)
  - [x] Change `play(frequency:duration:velocity:)` to `play(frequency:duration:velocity:amplitudeDB:)` with `amplitudeDB: Float` parameter

- [x] Task 5: Write failing tests for amplitude validation and behavior (AC: #1, #2, #3, #4) — TDD: write these BEFORE implementation
  - [x] `amplitudeDB_default_playsSuccessfully` — `amplitudeDB: 0.0` plays without error
  - [x] `amplitudeDB_positiveOffset_accepted` — `amplitudeDB: 2.0` plays without error
  - [x] `amplitudeDB_negativeOffset_accepted` — `amplitudeDB: -2.0` plays without error
  - [x] `amplitudeDB_atMinimumBoundary_accepted` — `amplitudeDB: -90.0` plays without error
  - [x] `amplitudeDB_atMaximumBoundary_accepted` — `amplitudeDB: 12.0` plays without error
  - [x] `amplitudeDB_belowMinimum_rejected` — `amplitudeDB: -91.0` throws `AudioError.invalidAmplitude`
  - [x] `amplitudeDB_aboveMaximum_rejected` — `amplitudeDB: 13.0` throws `AudioError.invalidAmplitude`

- [x] Task 6: Implement `SoundFontNotePlayer.play()` amplitude support (AC: #1, #2, #3, #4)
  - [x] Add `amplitudeDB: Float` parameter to `play()` signature
  - [x] Add validation: `guard (-90.0...12.0).contains(amplitudeDB)` → throw `AudioError.invalidAmplitude`
  - [x] Add `sampler.masterGain = amplitudeDB` before the `sampler.startNote(...)` call (after pitch bend, before startNote)
  - [x] No changes needed in `stop()` or `loadPreset()` or `defer` block — `masterGain` is set before every `startNote` so no reset is required

- [x] Task 7: Update `TrainingSession` to pass amplitude (AC: #2)
  - [x] Update both `notePlayer.play(...)` calls (note1 at line ~401 and note2 at line ~412) to pass `amplitudeDB: 0.0`
  - [x] Note: Story 10.5 will change note2's `amplitudeDB` to a computed offset; for now both notes use `0.0`

- [x] Task 8: Update all existing test call sites (AC: #6)
  - [x] `SoundFontNotePlayerTests`: add `amplitudeDB: 0.0` to every `player.play(...)` call (~10 call sites)
  - [x] `TrainingSessionIntegrationTests`: add test `passesDefaultAmplitude` verifying `mockPlayer.lastAmplitudeDB == 0.0`
  - [x] `FrequencyCalculationTests`: add `AudioError.invalidAmplitude("test")` case to `audioError_CasesExist` if it enumerates error cases

- [x] Task 9: Run full test suite and verify (AC: #6)
  - [x] Run: `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [x] All tests must pass with zero failures
  - [x] Verify no compilation warnings related to the new parameter

## Dev Notes

### Mechanism: `AVAudioUnitSampler.masterGain`

Story 10.1 research confirmed `masterGain` as the correct mechanism. Key properties:

| Property | Unit | Range | Default |
|---|---|---|---|
| `sampler.masterGain` | dB (Float) | -90.0 to +12.0 | 0.0 |

- **Built-in** — no audio graph changes required
- **dB-native** — the ±2 dB offset needed by Story 10.5 maps directly
- **Independent of MIDI velocity** — velocity controls timbre/dynamics in SF2 samples; `masterGain` controls output gain
- **Thread-safe** — it's an Audio Unit parameter, safe to set from any thread
- **No artifacts** — changing gain after `stopNote` and before `startNote` has no overlapping audio
- **Zero latency** — parameter changes take effect immediately

### Parameter Name: `amplitudeDB` (not `amplitude`)

The old "amplitude" parameter (0.0–1.0 linear) was renamed to "velocity" in Story 10.2. The new parameter is named `amplitudeDB` (not `amplitude`) because:
1. `amplitudeDB` self-documents the unit (dB), preventing confusion with the old linear parameter
2. The `DB` suffix follows audio programming conventions for distinguishing dB from linear scales
3. Default value `0.0` means "no change" — callers pass `0.0` for unchanged volume

### Implementation Strategy

In `SoundFontNotePlayer.play()`, set `masterGain` before starting the note:

```swift
func play(frequency: Double, duration: TimeInterval, velocity: UInt8, amplitudeDB: Float) async throws {
    // ... existing preset loading and validation ...

    // Validate amplitude range (matches masterGain's documented range)
    guard (-90.0...12.0).contains(amplitudeDB) else {
        throw AudioError.invalidAmplitude(
            "Amplitude \(amplitudeDB) dB is outside valid range -90.0...12.0"
        )
    }

    // ... existing audio session + engine start ...

    // Set volume offset (independent of MIDI velocity)
    sampler.masterGain = amplitudeDB

    // Apply pitch bend before starting note (existing)
    sampler.sendPitchBend(bendValue, onChannel: Self.channel)
    sampler.startNote(midiNote, withVelocity: velocity, onChannel: Self.channel)
    // ...
}
```

**No reset of `masterGain` needed** in `stop()`, `defer`, or `loadPreset()` — it is set explicitly before every `startNote`, so stale values cannot affect subsequent plays.

### Complete File Change Map (7 files)

| File | Type | Changes |
|---|---|---|
| `Peach/Core/Audio/NotePlayer.swift` | Protocol + enum | Add `invalidAmplitude` error case, add `amplitudeDB: Float` to protocol |
| `Peach/Core/Audio/SoundFontNotePlayer.swift` | Implementation | Add parameter, validate, set `sampler.masterGain` |
| `Peach/Training/TrainingSession.swift` | Orchestrator | Pass `amplitudeDB: 0.0` at both `play()` calls |
| `Peach/Training/TrainingScreen.swift` | Preview mock | Update mock signature |
| `PeachTests/Training/MockNotePlayer.swift` | Test mock | Add `lastAmplitudeDB`, update tuple, update `reset()` |
| `PeachTests/Core/Audio/SoundFontNotePlayerTests.swift` | Tests | Add 7 amplitude tests, update ~10 existing `play()` calls |
| `PeachTests/Training/TrainingSessionIntegrationTests.swift` | Tests | Add `passesDefaultAmplitude` test |

### Validation Placement

Amplitude validation goes AFTER velocity validation and BEFORE the audio session configuration block, keeping the validation order consistent: frequency → duration → velocity → amplitude.

### Protocol Limitation: No Default Parameter Values

Swift protocols cannot declare default parameter values. Since `TrainingSession` calls `notePlayer.play(...)` through the `NotePlayer` protocol type, every call site must explicitly pass `amplitudeDB`. There is no way to make it optional at the protocol level. This is acceptable — there are only 2 call sites in `TrainingSession` and the preview mock.

### Previous Story (10.2) Intelligence

Story 10.2 completed a clean rename/retype:
- `amplitude: Double` → `velocity: UInt8` throughout the codebase
- `midiVelocity(forAmplitude:)` helper deleted; velocity passed directly
- All tests pass, zero "amplitude" references remain in Swift files
- The codebase is clean and ready for the new `amplitudeDB` parameter

Key patterns established in 10.2 that apply here:
- Parameter validation uses `guard ... else { throw AudioError... }` pattern
- Error messages include the invalid value and valid range
- Mock captures parameter via `last{Param}` property and `playHistory` tuple
- Preview mock in TrainingScreen.swift must also be updated

### Git Intelligence

Recent commits show the 10.2 work was clean and followed the established pattern:
- `df32cac` Fix code review findings for 10-2-rename-amplitude-to-velocity
- `ba8a983` Implement story 10.2: Rename amplitude to velocity throughout codebase
- `c42eb31` Add story 10.2: Rename amplitude to velocity

### Project Structure Notes

- No new files created — all changes are to existing files
- No new dependencies or imports needed
- `sampler.masterGain` is already available on the existing `AVAudioUnitSampler` instance
- No audio graph topology changes (same `sampler → mainMixerNode → outputNode`)
- No localization changes (this is a developer-facing API change)

### References

- [Source: docs/implementation-artifacts/10-1-volume-control-findings.md] — masterGain research: mechanism, range, thread safety, gotchas
- [Source: docs/implementation-artifacts/10-1-research-volume-control-in-avaudiounitsampler.md] — Story 10.1 completion notes and code sketch
- [Source: docs/implementation-artifacts/10-2-rename-amplitude-to-velocity.md] — Previous story learnings and file change patterns
- [Source: docs/planning-artifacts/epics.md#Story 10.3] — Acceptance criteria and epic context
- [Source: docs/project-context.md#AVAudioEngine] — SoundFontNotePlayer rules, NotePlayer protocol boundary
- [Source: docs/project-context.md#Testing Rules] — Swift Testing framework, mock contract, TDD workflow
- [Source: Peach/Core/Audio/NotePlayer.swift] — Current protocol with velocity parameter (post-10.2)
- [Source: Peach/Core/Audio/SoundFontNotePlayer.swift] — Current implementation (masterGain not yet used)
- [Source: Peach/Training/TrainingSession.swift:401,412] — Two play() call sites to update
- [Source: PeachTests/Training/MockNotePlayer.swift] — Mock tracking properties to extend

## Change Log

- 2026-02-24: Implemented story 10.3 — added `amplitudeDB: Float` parameter to `NotePlayer` protocol and all implementations/call sites; added `AudioError.invalidAmplitude`; added 7 amplitude validation tests + 1 integration test; all tests pass (Date: 2026-02-24)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (claude-opus-4-6)

### Debug Log References

No debug issues encountered. Clean implementation following existing patterns from story 10.2.

### Completion Notes List

- Added `AudioError.invalidAmplitude(String)` error case with doc comment
- Extended `NotePlayer` protocol signature: `play(frequency:duration:velocity:amplitudeDB:)`
- Updated `SoundFontNotePlayer.play()`: validates amplitude range (-90.0...12.0), sets `sampler.masterGain = amplitudeDB` before `startNote`
- Updated `MockNotePlayer`: added `lastAmplitudeDB` property, extended `playHistory` tuple, updated `reset()`
- Updated `MockNotePlayerForPreview` in `TrainingScreen.swift`
- Updated `TrainingSession`: both `notePlayer.play()` calls now pass `amplitudeDB: 0.0`
- Added 7 amplitude validation tests in `SoundFontNotePlayerTests` (boundary, valid, invalid)
- Added `passesDefaultAmplitude` integration test in `TrainingSessionIntegrationTests`
- Updated `audioError_CasesExist` test in `FrequencyCalculationTests` for new error case
- Updated all existing `play()` call sites in tests with `amplitudeDB: 0.0`
- Full test suite passes with zero failures

### File List

- Peach/Core/Audio/NotePlayer.swift (modified — added `invalidAmplitude` error case, added `amplitudeDB` to protocol)
- Peach/Core/Audio/SoundFontNotePlayer.swift (modified — added `amplitudeDB` parameter, validation, `masterGain` assignment)
- Peach/Training/TrainingSession.swift (modified — pass `amplitudeDB: 0.0` at both `play()` calls)
- Peach/Training/TrainingScreen.swift (modified — updated preview mock signature)
- PeachTests/Training/MockNotePlayer.swift (modified — added `lastAmplitudeDB`, extended `playHistory` tuple, updated `reset()`)
- PeachTests/Core/Audio/SoundFontNotePlayerTests.swift (modified — added 7 amplitude tests, updated ~10 existing `play()` calls)
- PeachTests/Core/Audio/FrequencyCalculationTests.swift (modified — added `invalidAmplitude` to error case test)
- PeachTests/Training/TrainingSessionIntegrationTests.swift (modified — added `passesDefaultAmplitude` test)
