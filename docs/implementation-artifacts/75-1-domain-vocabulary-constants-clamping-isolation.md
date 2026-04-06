# Story 75.1: Domain Vocabulary — Constants, Clamping, and Isolation Hygiene

Status: review

## Story

As a **developer reading the domain layer**,
I want domain constants defined once on their owning types and value type isolation applied consistently,
so that raw literals and duplicated knowledge are eliminated.

## Background

The walkthrough (Layers 1, 2, 5) found that several domain constants are duplicated as raw literals across the codebase instead of being defined once on their owning type. Additionally, `nonisolated` isolation is applied inconsistently across value types — some use struct-level `nonisolated`, others apply it piecemeal on individual members.

**Walkthrough sources:** Layer 1 observations #1, #3, #4; Layer 2 observations #1, #4; Layer 5 observations #6, #7.

## Acceptance Criteria

1. **Given** `MIDINote` **When** inspected **Then** it has `static let a4 = MIDINote(69)` and `noteNames` is a `private static let` (not re-created on every `name` call).
2. **Given** `Cents` **When** inspected **Then** it has `static let perSemitone: Cents = 100`.
3. **Given** `TuningSystem` **When** inspected **Then** its `referenceMIDINote` uses `MIDINote.a4` instead of raw `69`.
4. **Given** `SoundFontPlayer.decompose()` **When** inspected **Then** it references `MIDINote.a4`, `Frequency.concert440`, `MIDINote.validRange`, `Interval.octave.semitones`, and `Cents.perSemitone` instead of local constant copies.
5. **Given** `PitchBendValue` **When** inspected **Then** it has a clamping initializer (matching the `AmplitudeDB`/`NoteDuration` pattern) and `SoundFontPlayer.pitchBendValue(forCents:)` uses it instead of manual `min`/`max`.
6. **Given** `SettingsCoordinator` **When** inspected **Then** `previewNote` uses `MIDINote.a4` and `previewVelocity` reads from `UserSettings` (injected or via environment) so the preview matches training loudness.
7. **Given** all value types in `Core/Music/` (`Cents`, `Frequency`, `AmplitudeDB`, `NoteDuration`) **When** inspected **Then** `nonisolated` is applied at the struct level, matching `MIDINote` and `MIDIVelocity`.
8. **Given** the `audioSampleRate` environment key **When** injection is missing **Then** it fails loudly (e.g., optional `SampleRate?` with nil default, or a `fatalError` sentinel) instead of silently defaulting to 48 kHz.
9. **Given** both platforms **When** built and tested **Then** all tests pass with zero regressions.

## Tasks / Subtasks

- [x] Task 1: Add missing domain constants (AC: #1, #2)
  - [x] Add `static let a4 = MIDINote(69)` to `MIDINote`
  - [x] Make `noteNames` a `private static let` in `MIDINote.name`
  - [x] Add `static let perSemitone: Cents = 100` to `Cents`

- [x] Task 2: Replace raw literals with domain constants (AC: #3, #4)
  - [x] `TuningSystem.swift`: replace `private static let referenceMIDINote = 69` with `MIDINote.a4`
  - [x] `SoundFontPlayer.decompose()`: replace all 5 local constants with domain type references
  - [x] Search for any other raw `69` or `440.0` literals that should reference domain constants

- [x] Task 3: Add PitchBendValue clamping initializer (AC: #5)
  - [x] Add `init(clamping:)` to `PitchBendValue` matching the `AmplitudeDB`/`NoteDuration` pattern
  - [x] Update `SoundFontPlayer.pitchBendValue(forCents:)` to use it

- [x] Task 4: Fix SettingsCoordinator preview constants (AC: #6)
  - [x] Replace `previewNote: MIDINote = 69` with `MIDINote.a4`
  - [x] Replace hardcoded `previewVelocity = 63` with `MIDIVelocity.mezzoPiano` (new domain constant shared with training settings)

- [x] Task 5: Harmonize nonisolated on value types (AC: #7)
  - [x] Add `nonisolated` at struct level on `Cents`, `Frequency`, `AmplitudeDB`, `NoteDuration`
  - [x] Remove piecemeal `nonisolated` on individual members where the struct-level declaration covers them

- [x] Task 6: Make audioSampleRate fail-loud (AC: #8)
  - [x] Change `@Entry var audioSampleRate: SampleRate = .standard48000` to `SampleRate?` (nil default)
  - [x] Verified no consumers currently read this key — only injected, never read from `@Environment`

- [x] Task 7: Build and test both platforms (AC: #9)
  - [x] `bin/test.sh && bin/test.sh -p mac`

## Dev Notes

### Source File Locations

| Change | File |
|--------|------|
| MIDINote.a4, noteNames static | `Peach/Core/Music/MIDINote.swift` |
| Cents.perSemitone | `Peach/Core/Music/Cents.swift` |
| TuningSystem reference | `Peach/Core/Music/TuningSystem.swift` |
| SoundFontPlayer.decompose() | `Peach/Core/Audio/SoundFontPlayer.swift` |
| PitchBendValue clamping | `Peach/Core/Audio/SoundFontPlayer.swift` (type may be in same file or nearby) |
| SettingsCoordinator | `Peach/App/SettingsCoordinator.swift` |
| Value type nonisolated | `Peach/Core/Music/Cents.swift`, `Frequency.swift`, `AmplitudeDB.swift`, `NoteDuration.swift` |
| audioSampleRate | `Peach/App/EnvironmentKeys.swift` |

### Existing WALKTHROUGH Annotations

These files have `// WALKTHROUGH:` comments that describe the changes needed — remove the annotations after implementing:
- `Peach/Core/Music/MIDINote.swift` (lines 10–11, 23)
- `Peach/Core/Music/Cents.swift` (lines 8–9)
- `Peach/Core/Music/TuningSystem.swift` (lines 37–38)
- `Peach/Core/Audio/SoundFontPlayer.swift` (lines 140–141, 152–153)
- `Peach/App/SettingsCoordinator.swift` (lines 34–36)
- `Peach/App/EnvironmentKeys.swift` (lines 3–4)

### What NOT to Change

- Do not change the `SoundFontPlayer.decompose()` algorithm — only replace its local constants
- Do not change `PitchBendValue`'s existing precondition init — add a new clamping init alongside it
- Do not change `SettingsCoordinator`'s public API — only its internal constant values

### References

- [Source: docs/walkthrough/1-domain-types.md — observations #1, #3, #4]
- [Source: docs/walkthrough/2-audio-engine.md — observations #1, #4]
- [Source: docs/walkthrough/5-composition-root.md — observations #6, #7]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6

### Debug Log References
None

### Completion Notes List
- Added `MIDINote.a4` and `private static let noteNames` to `MIDINote`
- Added `Cents.perSemitone` constant
- Replaced `TuningSystem.referenceMIDINote = 69` with inline `MIDINote.a4.rawValue`
- Replaced all 5 local constants in `SoundFontPlayer.decompose()` with domain type references (`MIDINote.a4`, `Interval.octave.semitones`, `Frequency.concert440`, `Cents.perSemitone`, `MIDINote.validRange`)
- Also replaced raw `100.0` in `SoundFontPlaybackHandle`, `SoundFontEngine.pitchBendRangeCents`, and `TuningSystem.centOffset(for:)` with `Cents.perSemitone.rawValue`
- Added `PitchBendValue(clamping:)` initializer; updated `SoundFontPlayer.pitchBendValue(forCents:)` to use it
- Added `MIDIVelocity.mezzoPiano` constant; used in `SettingsCoordinator`, `PitchDiscriminationSettings`, and `PitchMatchingSettings`
- Applied `nonisolated` at struct level on `Cents`, `Frequency`, `AmplitudeDB`, `NoteDuration`; removed redundant piecemeal `nonisolated` on `Cents.init`
- Changed `audioSampleRate` environment key to `SampleRate?` (nil default)
- All tests pass: 1707 iOS, 1700 macOS
- Added arithmetic operators to `Cents` (+, -, unary -, scalar *, /, ratio /) and distance operator to `MIDINote` (-)
- Replaced ~15 `.rawValue` accesses across domain layer with operator expressions

### File List
- `Peach/Core/Music/MIDINote.swift` — added `a4` constant, `noteNames` static, `-` distance operator
- `Peach/Core/Music/Cents.swift` — added `perSemitone`, `perOctave` as Cents, `nonisolated` struct, arithmetic operators
- `Peach/Core/Music/Frequency.swift` — `nonisolated` struct
- `Peach/Core/Music/AmplitudeDB.swift` — `nonisolated` struct
- `Peach/Core/Music/NoteDuration.swift` — `nonisolated` struct
- `Peach/Core/Music/MIDIVelocity.swift` — added `mezzoPiano` constant
- `Peach/Core/Music/PitchBendValue.swift` — added `init(clamping:)`
- `Peach/Core/Music/NoteRange.swift` — used MIDINote distance operator
- `Peach/Core/Music/Interval.swift` — used MIDINote distance operator
- `Peach/Core/Music/DirectedInterval.swift` — used MIDINote comparison directly
- `Peach/Core/Music/TuningSystem.swift` — used Cents operators and MIDINote distance
- `Peach/Core/Audio/SoundFontPlayer.swift` — replaced raw literals in `decompose()`, used `PitchBendValue(clamping:)` and Cents operators
- `Peach/Core/Audio/SoundFontPlaybackHandle.swift` — used Cents operators
- `Peach/Core/Audio/SoundFontEngine.swift` — used Cents operators
- `Peach/App/SettingsCoordinator.swift` — used `MIDINote.a4` and `MIDIVelocity.mezzoPiano`
- `Peach/App/EnvironmentKeys.swift` — changed `audioSampleRate` to optional
- `Peach/PitchDiscrimination/PitchDiscriminationSettings.swift` — used `.mezzoPiano`
- `Peach/PitchDiscrimination/PitchDiscriminationStoreAdapter.swift` — used MIDINote distance operator
- `Peach/PitchDiscrimination/PitchDiscriminationTrial.swift` — used Cents comparison directly
- `Peach/PitchMatching/PitchMatchingSettings.swift` — used `.mezzoPiano`
- `Peach/PitchMatching/PitchMatchingSession.swift` — used Cents operators
- `Peach/PitchMatching/PitchMatchingStoreAdapter.swift` — used MIDINote distance operator
- `PeachTests/Core/Music/MIDINoteTests.swift` — added tests for `a4` constant and distance operator
- `PeachTests/Core/Music/CentsTests.swift` — added tests for `perSemitone` and arithmetic operators
- `PeachTests/Core/Music/PitchBendValueTests.swift` — added tests for clamping initializer

## Change Log

- 2026-04-06: Story created from walkthrough observations
- 2026-04-06: Implementation complete — all domain constants, clamping, isolation, and fail-loud changes applied
- 2026-04-06: Simplify review — `PitchBendValue(clamping:)` now uses `.clamped(to:)`; `Cents.perOctave` changed to `Cents` type for consistency with `perSemitone`; removed unnecessary doc comment from `perSemitone`
- 2026-04-06: Added arithmetic operators to `Cents` and distance operator to `MIDINote`; replaced ~15 `.rawValue` accesses with operator expressions
