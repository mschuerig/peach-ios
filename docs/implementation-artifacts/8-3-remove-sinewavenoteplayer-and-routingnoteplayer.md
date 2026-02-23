# Story 8.3: Remove SineWaveNotePlayer and RoutingNotePlayer

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer maintaining Peach**,
I want to remove `SineWaveNotePlayer` and `RoutingNotePlayer` in favor of `SoundFontNotePlayer` as the sole `NotePlayer` implementation,
So that the audio subsystem has a single code path, fewer moving parts, and no dead fallback code.

## Acceptance Criteria

1. **Given** the codebase after this story
   **When** I search for `SineWaveNotePlayer`
   **Then** no production code references it
   **And** `Peach/Core/Audio/SineWaveNotePlayer.swift` has been deleted

2. **Given** the codebase after this story
   **When** I search for `RoutingNotePlayer`
   **Then** no production code references it
   **And** `Peach/Core/Audio/RoutingNotePlayer.swift` has been deleted

3. **Given** `SoundFontNotePlayer` as the sole `NotePlayer` implementation
   **When** `play(frequency:duration:amplitude:)` is called
   **Then** it reads the current `soundSource` from `UserDefaults` (key: `SettingsKeys.soundSource`)
   **And** parses the `"sf2:{bank}:{program}"` tag to determine the target preset
   **And** calls `loadPreset(program:bank:)` if the preset differs from the currently loaded one
   **And** plays the note using the selected preset
   **And** if the tag is unparseable or the preset load fails, it falls back to the default sound source (`sf2:8:80`)

4. **Given** `SettingsKeys.defaultSoundSource`
   **When** the app is launched for the first time (no stored preference)
   **Then** the default sound source is `"sf2:8:80"` (SF2 Sine Wave preset)

5. **Given** an existing user whose stored `soundSource` is `"sine"`
   **When** the Settings Screen appears
   **Then** the value is migrated to `"sf2:8:80"` and persisted

6. **Given** the Settings Screen instrument picker
   **When** displayed
   **Then** it shows only SF2 presets from `SoundFontLibrary.availablePresets`
   **And** there is no separate hardcoded "Sine Wave" entry (the SF2 "Sine Wave" preset at `sf2:8:80` appears naturally in the alphabetically sorted list)
   **And** the currently selected preset is visually indicated

7. **Given** `PeachApp.swift`
   **When** the app initializes
   **Then** it creates only a `SoundFontNotePlayer` (no `SineWaveNotePlayer`, no `RoutingNotePlayer`)
   **And** passes it directly as the `NotePlayer` to `TrainingSession`

8. **Given** the `NotePlayer` protocol and `AudioError` enum
   **When** reviewed after this story
   **Then** the `public` access modifier is removed (changed to `internal`) since all conformers are now internal
   **And** the protocol doc comments no longer reference `SineWaveNotePlayer`

9. **Given** the test suite
   **When** all tests are run
   **Then** `SineWaveNotePlayerTests.swift` and `SineWaveNotePlayerPlaybackTests.swift` have been deleted
   **And** `RoutingNotePlayerTests.swift` has been deleted
   **And** any `FrequencyCalculation` tests that lived in `SineWaveNotePlayerTests.swift` have been relocated (not lost)
   **And** `SoundFontNotePlayerTests` covers the absorbed preset-selection-from-UserDefaults logic
   **And** the full remaining test suite passes

10. **Given** `docs/project-context.md`
    **When** reviewed after this story
    **Then** it no longer references `SineWaveNotePlayer` or `RoutingNotePlayer`
    **And** the audio architecture section describes `SoundFontNotePlayer` as the sole `NotePlayer` implementation
    **And** the `soundSource` tag format documentation is updated (no more `"sine"` tag)

## Tasks / Subtasks

- [x] Task 1: Absorb preset routing logic into SoundFontNotePlayer (AC: #3)
  - [x] 1.1 In `SoundFontNotePlayer.play()`, read `UserDefaults` key `SettingsKeys.soundSource` to determine the target preset before playing
  - [x] 1.2 Parse `"sf2:{bank}:{program}"` tag; if unparseable or load fails, fall back to default preset (bank 8, program 80 — Sine Wave)
  - [x] 1.3 Call `loadPreset(program:bank:)` only when the target differs from the currently loaded preset (existing skip-if-same logic)
  - [x] 1.4 Migrate legacy `"cello"` tag handling into `SoundFontNotePlayer` (map to bank 0, program 42)
  - [x] 1.5 Add/update tests for the new preset-selection-from-UserDefaults logic

- [x] Task 2: Delete SineWaveNotePlayer (AC: #1, #9)
  - [x] 2.1 Delete `Peach/Core/Audio/SineWaveNotePlayer.swift`
  - [x] 2.2 Delete `PeachTests/Core/Audio/SineWaveNotePlayerTests.swift`
  - [x] 2.3 Delete `PeachTests/Core/Audio/SineWaveNotePlayerPlaybackTests.swift`
  - [x] 2.4 Relocate any `FrequencyCalculation` tests from those files into `PeachTests/Core/Audio/FrequencyCalculationTests.swift` (create if needed, or add to existing `SoundFontNotePlayerTests`)

- [x] Task 3: Delete RoutingNotePlayer (AC: #2, #9)
  - [x] 3.1 Delete `Peach/Core/Audio/RoutingNotePlayer.swift`
  - [x] 3.2 Delete `PeachTests/Core/Audio/RoutingNotePlayerTests.swift`

- [x] Task 4: Simplify PeachApp composition root (AC: #7)
  - [x] 4.1 Remove `SineWaveNotePlayer` instantiation from `PeachApp.init()`
  - [x] 4.2 Remove `RoutingNotePlayer` construction
  - [x] 4.3 Pass `SoundFontNotePlayer` directly as `any NotePlayer` to `TrainingSession`
  - [x] 4.4 Remove the `SoundFontNotePlayer?` optional pattern — it is now required (if SF2 init fails, app cannot function)

- [x] Task 5: Update Settings UI and defaults (AC: #4, #5, #6)
  - [x] 5.1 Change `SettingsKeys.defaultSoundSource` from `"sine"` to `"sf2:8:80"`
  - [x] 5.2 Remove the hardcoded `Text("Sine Wave").tag("sine")` from the instrument picker — the SF2 "Sine Wave" preset appears via `soundFontLibrary.availablePresets`
  - [x] 5.3 Update the `.onAppear` migration logic: migrate `"sine"` to `"sf2:8:80"` (in addition to existing `"cello"` → `"sf2:0:42"`)
  - [x] 5.4 Update `validatedSoundSource` binding: replace `"sine"` fallback with `SettingsKeys.defaultSoundSource`
  - [x] 5.5 Update any related Settings tests

- [x] Task 6: Clean up NotePlayer protocol and AudioError (AC: #8)
  - [x] 6.1 Change `NotePlayer` protocol from `public` to `internal`
  - [x] 6.2 Change `AudioError` enum from `public` to `internal`
  - [x] 6.3 Remove doc comments referencing `SineWaveNotePlayer` from the protocol
  - [x] 6.4 Remove the `AudioError.renderFailed` and `AudioError.nodeAttachFailed` cases if they are no longer used by any code (they were only used by `SineWaveNotePlayer`)

- [x] Task 7: Update project-context.md (AC: #10)
  - [x] 7.1 Remove all references to `SineWaveNotePlayer` and `RoutingNotePlayer`
  - [x] 7.2 Describe `SoundFontNotePlayer` as the sole `NotePlayer` implementation
  - [x] 7.3 Update `soundSource` tag format: only `"sf2:{bank}:{program}"` (no `"sine"` tag)
  - [x] 7.4 Note that `SoundFontNotePlayer` reads the current sound source from UserDefaults on each `play()` call

- [x] Task 8: Verify full test suite passes (AC: #9)
  - [x] 8.1 Run full test suite and confirm zero failures
  - [x] 8.2 Confirm no orphaned references to deleted types

## Dev Notes

### Technical Requirements

- **Preset routing absorption**: The key behavior from `RoutingNotePlayer` that moves into `SoundFontNotePlayer.play()` is: (1) read `UserDefaults` for `soundSource`, (2) parse the `"sf2:{bank}:{program}"` tag, (3) call `loadPreset` if preset changed. This is ~15 lines of logic. The `parseSF2Tag` helper can be moved as-is.

- **No more fallback to sine**: If `SoundFontNotePlayer` init fails, the app cannot play notes at all. This is acceptable because: (a) the SF2 file is bundled in the app — if it's missing, the app is corrupted; (b) `SineWaveNotePlayer` also used `AVAudioEngine`, so it would fail under the same conditions; (c) a non-functional fallback is worse than a clear failure.

- **Default preset**: The SF2 "Sine Wave" preset is at bank 8, program 80, tag `"sf2:8:80"`. This maintains behavioral continuity for new users — they still hear a sine wave by default.

- **Migration**: Users with `soundSource == "sine"` need migration to `"sf2:8:80"`. Users with `soundSource == "cello"` already migrate to `"sf2:0:42"` (from story 8.2). Both migrations should be handled.

- **AudioError cleanup**: With `SineWaveNotePlayer` gone, check if `renderFailed` and `nodeAttachFailed` are still used. If not, remove them — dead enum cases are dead code.

### Architecture Compliance

- **Single NotePlayer implementation**: `SoundFontNotePlayer` is the sole concrete `NotePlayer`. The protocol remains for testability (`MockNotePlayer` in tests). [Source: docs/project-context.md — "NotePlayer protocol"]
- **No `public` access**: All production types become `internal`. [Source: docs/project-context.md — "Never use public access"]
- **UserDefaults coupling**: `SoundFontNotePlayer` reading `UserDefaults` in `play()` matches the existing pattern from `RoutingNotePlayer`. The alternative (injecting a preset-selection dependency) would be over-engineering for a single setting read.

### Library & Framework Requirements

- No new dependencies. Net reduction in code.

### File Structure Requirements

**Deleted files:**
```
Peach/Core/Audio/SineWaveNotePlayer.swift
Peach/Core/Audio/RoutingNotePlayer.swift
PeachTests/Core/Audio/SineWaveNotePlayerTests.swift
PeachTests/Core/Audio/SineWaveNotePlayerPlaybackTests.swift
PeachTests/Core/Audio/RoutingNotePlayerTests.swift
```

**Modified files:**
```
Peach/Core/Audio/SoundFontNotePlayer.swift    # Absorb preset routing logic
Peach/Core/Audio/NotePlayer.swift              # Remove public, clean up docs
Peach/Settings/SettingsScreen.swift            # Remove "Sine Wave" entry, update migration
Peach/Settings/SettingsKeys.swift              # Change default to "sf2:8:80"
Peach/App/PeachApp.swift                       # Simplify to single player
docs/project-context.md                        # Update architecture docs
```

**Potentially new file:**
```
PeachTests/Core/Audio/FrequencyCalculationTests.swift  # If relocating tests from deleted SineWaveNotePlayerTests
```

**Modified test files:**
```
PeachTests/Core/Audio/SoundFontNotePlayerTests.swift   # Add preset-routing tests
PeachTests/Settings/SettingsTests.swift                 # Update for new default, migration
```

### Testing Requirements

- **Relocated tests**: `FrequencyCalculation` tests currently in `SineWaveNotePlayerTests.swift` must not be lost — relocate to a dedicated file or into `SoundFontNotePlayerTests`
- **New tests**: Verify `SoundFontNotePlayer.play()` reads UserDefaults and switches preset accordingly
- **Migration tests**: Verify `"sine"` → `"sf2:8:80"` migration in Settings
- **Default tests**: Verify new default sound source is `"sf2:8:80"`
- **All tests `@MainActor async`** per project testing rules

### Previous Story Intelligence

**From story 8-1:**
- `SoundFontNotePlayer` created with `AVAudioUnitSampler`, `loadPreset`, pitch bend, MIDI note-on/off
- `RoutingNotePlayer` created as the router between sine and SF2 — this story removes it
- `FrequencyCalculation.midiNoteAndCents()` — unchanged, still used by `SoundFontNotePlayer`

**From story 8-2:**
- `SoundFontLibrary` discovers presets, provides `availablePresets` for Settings UI — stays as-is
- `SettingsScreen` has instrument picker with "Sine Wave" hardcoded + dynamic SF2 list — this story removes the hardcoded entry
- `RoutingNotePlayer` parses `"sf2:{bank}:{program}"` tags — this logic moves into `SoundFontNotePlayer`
- `validatedSoundSource` binding falls back to `"sine"` — this story changes fallback to `"sf2:8:80"`

### Git Intelligence

This is a removal/simplification story. Net line count will decrease significantly (~300+ lines of production code, ~100+ lines of tests). Branch name: `8-3-remove-sinewavenoteplayer-and-routingnoteplayer`.

### Project Structure Notes

- No new directories needed
- Deleted files reduce the `Peach/Core/Audio/` directory from 7 files to 5
- Test directory similarly shrinks

### References

- [Source: docs/implementation-artifacts/8-1-implement-soundfont-noteplayer.md] — Original SoundFontNotePlayer and RoutingNotePlayer implementation
- [Source: docs/implementation-artifacts/8-2-sf2-preset-discovery-and-instrument-selection.md] — SoundFontLibrary, dynamic preset picker, tag format
- [Source: docs/project-context.md] — Architecture rules, access level policy, testing conventions

## Dev Agent Record

### Implementation Notes

- Absorbed `RoutingNotePlayer.parseSF2Tag()` into `SoundFontNotePlayer` as a `static` method for testability
- Changed default preset from Cello (bank 0, program 42) to Sine Wave (bank 8, program 80) in SoundFontNotePlayer init
- Added UserDefaults soundSource reading at the start of `play()` — reads tag, parses it, and calls `loadPreset` if preset changed; falls back to default on parse failure or load error
- Relocated all FrequencyCalculation, AudioError, and Reference Pitch tests from `SineWaveNotePlayerTests.swift` to `FrequencyCalculationTests.swift` — no tests lost
- Removed `AudioError.renderFailed` and `AudioError.nodeAttachFailed` (only used by deleted SineWaveNotePlayer); updated MockNotePlayer default error to `.engineStartFailed`
- Simplified `PeachApp.init()` from 3 players (SineWaveNotePlayer + SoundFontNotePlayer? + RoutingNotePlayer) to 1 (SoundFontNotePlayer)
- Settings migration handles "sine" → "sf2:8:80" and "cello" → "sf2:0:42"

### Completion Notes

All 8 tasks completed. All 10 acceptance criteria satisfied. Full test suite passes with zero failures. Net reduction in code: deleted 5 files (~500 lines of production code, ~400 lines of tests). Audio subsystem now has a single code path through SoundFontNotePlayer.

## File List

**Deleted:**
- Peach/Core/Audio/SineWaveNotePlayer.swift
- Peach/Core/Audio/RoutingNotePlayer.swift
- PeachTests/Core/Audio/SineWaveNotePlayerTests.swift
- PeachTests/Core/Audio/SineWaveNotePlayerPlaybackTests.swift
- PeachTests/Core/Audio/RoutingNotePlayerTests.swift

**Modified:**
- Peach/Core/Audio/SoundFontNotePlayer.swift
- Peach/Core/Audio/NotePlayer.swift
- Peach/Settings/SettingsScreen.swift
- Peach/Settings/SettingsKeys.swift
- Peach/App/PeachApp.swift
- Peach/Resources/Localizable.xcstrings
- PeachTests/Core/Audio/SoundFontNotePlayerTests.swift
- PeachTests/Core/Audio/FrequencyCalculationTests.swift
- PeachTests/Settings/SettingsTests.swift
- PeachTests/Training/MockNotePlayer.swift
- PeachTests/Training/TrainingSessionTests.swift
- docs/project-context.md
- docs/implementation-artifacts/sprint-status.yaml

## Change Log

- 2026-02-23: Implemented story 8.3 — Removed SineWaveNotePlayer and RoutingNotePlayer; SoundFontNotePlayer is now the sole NotePlayer implementation with absorbed preset routing logic
- 2026-02-23: Code review — Fixed 6 issues: (H1) added @MainActor async to 22 relocated FrequencyCalculation tests, (H2) updated 8 stale SineWaveNotePlayer references in architecture.md, (M1) added Localizable.xcstrings to File List, (M2) removed redundant import AVFAudio, (M3) removed legacy "cello" tag handling from parseSF2Tag, (M4) removed stale "Sine Wave" localization entry. Updated cello tag test expectations. All tests pass.
