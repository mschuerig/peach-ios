# Story 75.1: Domain Vocabulary — Constants, Clamping, and Isolation Hygiene

Status: ready-for-dev

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

- [ ] Task 1: Add missing domain constants (AC: #1, #2)
  - [ ] Add `static let a4 = MIDINote(69)` to `MIDINote`
  - [ ] Make `noteNames` a `private static let` in `MIDINote.name`
  - [ ] Add `static let perSemitone: Cents = 100` to `Cents`

- [ ] Task 2: Replace raw literals with domain constants (AC: #3, #4)
  - [ ] `TuningSystem.swift`: replace `private static let referenceMIDINote = 69` with `MIDINote.a4`
  - [ ] `SoundFontPlayer.decompose()`: replace all 5 local constants with domain type references
  - [ ] Search for any other raw `69` or `440.0` literals that should reference domain constants

- [ ] Task 3: Add PitchBendValue clamping initializer (AC: #5)
  - [ ] Add `init(clamping:)` to `PitchBendValue` matching the `AmplitudeDB`/`NoteDuration` pattern
  - [ ] Update `SoundFontPlayer.pitchBendValue(forCents:)` to use it

- [ ] Task 4: Fix SettingsCoordinator preview constants (AC: #6)
  - [ ] Replace `previewNote: MIDINote = 69` with `MIDINote.a4`
  - [ ] Replace hardcoded `previewVelocity = 63` with `settings.velocity` (requires injecting `UserSettings` into `SettingsCoordinator`)

- [ ] Task 5: Harmonize nonisolated on value types (AC: #7)
  - [ ] Add `nonisolated` at struct level on `Cents`, `Frequency`, `AmplitudeDB`, `NoteDuration`
  - [ ] Remove piecemeal `nonisolated` on individual members where the struct-level declaration covers them

- [ ] Task 6: Make audioSampleRate fail-loud (AC: #8)
  - [ ] Change `@Entry var audioSampleRate: SampleRate = .standard48000` to optional or sentinel
  - [ ] Update all consumers to handle the optional (or verify injection is never missed)

- [ ] Task 7: Build and test both platforms (AC: #9)
  - [ ] `bin/test.sh && bin/test.sh -p mac`

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
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-04-06: Story created from walkthrough observations
