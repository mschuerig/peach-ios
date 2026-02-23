# Story 8.2: SF2 Preset Discovery and Instrument Selection

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **musician using Peach**,
I want to choose from all available instrument sounds in the bundled SoundFont,
So that I can train pitch discrimination with the timbre that matches my instrument or preference.

## Acceptance Criteria

1. **Given** the bundled GeneralUser GS SF2 file
   **When** the app starts
   **Then** a `SoundFontLibrary` discovers and enumerates all available presets from the SF2 file's PHDR metadata
   **And** the preset list (name, program number, bank) is available for the Settings UI

2. **Given** the SF2 PHDR (Preset Header) metadata
   **When** parsed
   **Then** each preset's name, program number, and bank number are extracted correctly
   **And** the terminal "EOP" sentinel record is excluded
   **And** drum kit presets (bank MSB 128 / percussion bank) are excluded
   **And** preset names are cleaned for display (null-padded bytes trimmed, leading/trailing whitespace removed)

3. **Given** the Settings Screen Sound Source picker
   **When** displayed
   **Then** it shows "Sine Wave" as the first option
   **And** it shows all discovered SF2 melodic presets as selectable options
   **And** each preset shows its cleaned display name (e.g., "Acoustic Grand Piano", "Cello", "Flute")
   **And** presets are ordered by General MIDI program number
   **And** the currently selected preset is visually indicated

4. **Given** the user selects an instrument preset in Settings
   **When** the selection is persisted
   **Then** the `soundSource` `@AppStorage` stores a value encoding the preset (e.g., `"sf2:0"` for Acoustic Grand Piano, `"sf2:42"` for Cello)
   **And** the next training note uses the selected instrument timbre
   **And** the previous hardcoded `"cello"` tag from story 8-1 is replaced by the general `"sf2:{program}"` scheme

5. **Given** the `SoundFontNotePlayer` from story 8-1
   **When** a different preset is selected via Settings
   **Then** it loads the new preset via `loadSoundBankInstrument()` without recreating the sampler or engine
   **And** pitch bend range is re-sent via RPN after preset change (some presets may reset it)
   **And** the preset switch takes effect on the next `play()` call

6. **Given** the `RoutingNotePlayer` from story 8-1
   **When** the `soundSource` setting starts with `"sf2:"`
   **Then** it parses the program number from the tag and instructs `SoundFontNotePlayer` to use that preset
   **When** the `soundSource` setting is `"sine"`
   **Then** it delegates to `SineWaveNotePlayer` (unchanged)

7. **Given** the app is launched with a previously selected preset that no longer exists in the SF2
   **When** the Settings Screen is displayed
   **Then** the selection falls back to the default sound source ("Sine Wave")
   **And** the stale setting value is cleared

8. **Given** the new code
   **When** unit tests are run
   **Then** PHDR parsing returns expected preset count and names for a known SF2 structure
   **And** the EOP sentinel and drum kits are excluded
   **And** preset name cleaning handles null bytes and whitespace
   **And** `SoundFontNotePlayer` preset switching works without errors
   **And** the full existing test suite continues to pass

## Tasks / Subtasks

- [ ] Task 1: Implement SF2 PHDR metadata parser (AC: #1, #2, #8)
  - [ ] 1.1 Create `Peach/Core/Audio/SF2PresetParser.swift` — a lightweight struct that reads only the PHDR chunk from an SF2 file
  - [ ] 1.2 Parse the RIFF/sfbk container: locate the `pdta` sub-chunk, then locate the `phdr` sub-chunk within it
  - [ ] 1.3 Read 38-byte PHDR records: extract `achPresetName` (20 ASCII bytes, null-padded), `wPreset` (UInt16, program number), `wBank` (UInt16, bank number)
  - [ ] 1.4 Exclude the terminal EOP (End Of Presets) sentinel record (always the last 38-byte record)
  - [ ] 1.5 Return `[SF2Preset]` where `SF2Preset` is a value type with `name: String`, `program: Int`, `bank: Int`
  - [ ] 1.6 Create `PeachTests/Core/Audio/SF2PresetParserTests.swift` — test with the bundled GeneralUser GS SF2

- [ ] Task 2: Implement SoundFontLibrary (AC: #1, #7, #8)
  - [ ] 2.1 Create `Peach/Core/Audio/SoundFontLibrary.swift` — discovers SF2 files and enumerates their presets
  - [ ] 2.2 Scan app bundle for `.sf2` files on init
  - [ ] 2.3 Parse each SF2 via `SF2PresetParser`, cache the preset list
  - [ ] 2.4 Filter out drum kits (bank MSB 128 / bank number >= 128)
  - [ ] 2.5 Sort presets by program number for display
  - [ ] 2.6 Expose `var availablePresets: [SF2Preset]` for the Settings UI
  - [ ] 2.7 Expose `func preset(forTag tag: String) -> SF2Preset?` to resolve a setting tag like `"sf2:42"` back to a preset
  - [ ] 2.8 Create `PeachTests/Core/Audio/SoundFontLibraryTests.swift`

- [ ] Task 3: Generalize SoundFontNotePlayer for configurable presets (AC: #5, #8)
  - [ ] 3.1 Add `func loadPreset(program: Int, bankMSB: Int, bankLSB: Int) throws` to `SoundFontNotePlayer`
  - [ ] 3.2 After loading a new preset, re-send RPN pitch bend range messages (preset change may reset sampler state)
  - [ ] 3.3 Track the currently loaded preset to avoid redundant reloads on consecutive `play()` calls with the same preset
  - [ ] 3.4 Update tests to cover preset switching

- [ ] Task 4: Update RoutingNotePlayer for dynamic preset tags (AC: #6, #8)
  - [ ] 4.1 Replace hardcoded `"cello"` routing with `"sf2:{program}"` pattern parsing
  - [ ] 4.2 On `play()`, if setting starts with `"sf2:"` — parse program number, call `soundFontPlayer.loadPreset()` if changed, then delegate `play()`
  - [ ] 4.3 Update `RoutingNotePlayerTests` for new tag format

- [ ] Task 5: Update Settings UI with dynamic instrument list (AC: #3, #4, #7)
  - [ ] 5.1 Inject `SoundFontLibrary` into `SettingsScreen` via SwiftUI `@Environment`
  - [ ] 5.2 Replace the static "Sine Wave" / "Cello" picker with a dynamic list: "Sine Wave" first, then all presets from `SoundFontLibrary.availablePresets`
  - [ ] 5.3 Each preset option tagged as `"sf2:{program}"` (e.g., `"sf2:0"`, `"sf2:42"`)
  - [ ] 5.4 Handle fallback: if stored setting tag doesn't match any available preset, reset to `"sine"`
  - [ ] 5.5 Add localized section header for the instrument list (English + German)
  - [ ] 5.6 Migrate the old `"cello"` setting value to `"sf2:42"` for users who set it in story 8-1

- [ ] Task 6: Wire SoundFontLibrary in PeachApp.swift (AC: #1)
  - [ ] 6.1 Create `SoundFontLibrary` in `PeachApp.swift` init
  - [ ] 6.2 Create `EnvironmentKey` for `SoundFontLibrary` and inject via `.environment()`
  - [ ] 6.3 Pass `SoundFontLibrary` reference to `RoutingNotePlayer` if needed for preset resolution

- [ ] Task 7: Update project-context.md (housekeeping)
  - [ ] 7.1 Add `SF2PresetParser`, `SoundFontLibrary` to project structure
  - [ ] 7.2 Document `soundSource` tag format: `"sine"` or `"sf2:{program}"`
  - [ ] 7.3 Note that `SoundFontLibrary` is read-only at runtime — preset list computed once at startup

## Dev Notes

### Technical Requirements

- **SF2 PHDR binary format**: The SF2 file is a RIFF container. Structure: `RIFF` -> `sfbk` -> `pdta` (preset data) sub-chunk -> `phdr` (preset headers). Each PHDR record is exactly 38 bytes:
  ```
  Offset  Size  Field
  0       20    achPresetName   (ASCII, null-padded)
  20      2     wPreset         (UInt16 LE — MIDI program number)
  22      2     wBank           (UInt16 LE — MIDI bank number)
  24      2     wPresetBagNdx   (UInt16 LE — index, not needed for enumeration)
  26      4     dwLibrary       (UInt32 LE — reserved)
  30      4     dwGenre         (UInt32 LE — reserved)
  34      4     dwMorphology    (UInt32 LE — reserved)
  ```
  The last record is always "EOP" (End of Presets) — a sentinel that must be excluded from the preset list.
  [Source: SF2 Specification v2.01, Section 7.2]

- **RIFF chunk navigation**: Use `FileHandle` or `Data` to read the binary SF2 file. Navigate RIFF chunks by reading 4-byte chunk IDs and 4-byte sizes. Pseudocode:
  ```
  1. Read RIFF header, verify "RIFF" + "sfbk"
  2. Scan top-level LIST chunks for "pdta"
  3. Within pdta, scan sub-chunks for "phdr"
  4. Read phdr data as array of 38-byte records
  5. Drop the last record (EOP sentinel)
  ```

- **Drum kit filtering**: General MIDI drum kits use bank MSB 128 (percussion bank). Filter these out — they are not meaningful for pitch training. In GeneralUser GS, drum presets have `wBank >= 128`.

- **Preset name cleaning**: SF2 names are 20-byte ASCII fields padded with null (`\0`) bytes. Clean by: (1) replace null bytes, (2) trim whitespace from both ends. Some SF2 files use non-ASCII characters — handle gracefully by replacing undecodable bytes.

- **`loadSoundBankInstrument()` for preset switching**: This method can be called multiple times on the same `AVAudioUnitSampler` instance without recreating it. Each call loads a different preset from the same (or different) SF2 file. However, calling it while a note is playing may cause artifacts — ensure `stopNote()` is called first.

- **Preset tag format**: The `soundSource` `@AppStorage` stores strings. For SF2 presets, use `"sf2:{program}"` format (e.g., `"sf2:0"` for piano, `"sf2:42"` for cello). This is extensible to future multi-SF2 support (e.g., `"sf2:filename:program"`).

- **GeneralUser GS preset count**: The full GeneralUser GS SF2 contains 261 melodic presets + 13 drum kits. After filtering drums, expect ~261 melodic presets. The Settings UI should handle this list length gracefully (scrollable picker or list).

### Architecture Compliance

- **`SoundFontLibrary` is a read-only service**: Created once at startup, parses SF2 metadata, provides preset list. No mutation after init. Fits naturally as an `@Environment` injectable following the project's dependency injection pattern [Source: docs/project-context.md — "When Adding New Components"]
- **New `EnvironmentKey` for `SoundFontLibrary`**: Define alongside the type in `SoundFontLibrary.swift` following the pattern from `TrendAnalyzer.swift`. Wire in `PeachApp.swift` [Source: docs/project-context.md — "New injectable service -> create EnvironmentKey"]
- **SF2PresetParser is a pure struct**: No state, no dependencies — just a static function that takes a `URL` and returns `[SF2Preset]`. Easy to test. Lives in `Core/Audio/` alongside the other audio types
- **Views remain thin**: `SettingsScreen` reads `SoundFontLibrary.availablePresets` for display, writes the selection to `@AppStorage`. No business logic in the view [Source: docs/project-context.md — "Views contain zero business logic"]
- **Zero third-party dependencies**: The PHDR parser is a custom implementation (~60-80 lines) reading binary data with Foundation's `Data` API. No bradhowes/SF2Lib, no AudioKit [Source: docs/project-context.md — "Zero third-party dependencies"]
- **@MainActor isolation**: `SoundFontLibrary` should be `@MainActor` since it's accessed from views via `@Environment`. `SF2PresetParser` can be `nonisolated` (pure function, no shared state)

### Library & Framework Requirements

- **Foundation** — `Data`, `FileHandle` for binary SF2 parsing
- **AVFoundation / AVFAudio** — `AVAudioUnitSampler.loadSoundBankInstrument()` for preset switching
- No new dependencies.

### File Structure Requirements

**New files:**
```
Peach/Core/Audio/
├── SF2PresetParser.swift          # Lightweight PHDR binary parser
└── SoundFontLibrary.swift         # SF2 discovery + preset enumeration + EnvironmentKey

PeachTests/Core/Audio/
├── SF2PresetParserTests.swift     # PHDR parsing, EOP exclusion, name cleaning
└── SoundFontLibraryTests.swift    # Preset enumeration, drum filtering, tag resolution
```

**Modified files:**
```
Peach/Core/Audio/SoundFontNotePlayer.swift   # Add loadPreset() for dynamic preset switching
Peach/Core/Audio/RoutingNotePlayer.swift     # Parse "sf2:{program}" tags, replace "cello" routing
Peach/Settings/SettingsScreen.swift           # Dynamic instrument picker from SoundFontLibrary
Peach/App/PeachApp.swift                      # Create + inject SoundFontLibrary
docs/project-context.md                       # Add new types, document tag format
```

**Modified test files:**
```
PeachTests/Core/Audio/SoundFontNotePlayerTests.swift  # Add preset switching tests
PeachTests/Core/Audio/RoutingNotePlayerTests.swift     # Update for sf2: tag format
```

### Testing Requirements

- **SF2PresetParser** (`SF2PresetParserTests.swift`):
  - Parses GeneralUser GS SF2 and returns non-empty preset list
  - Preset count matches expected (~261 melodic + 13 drums before filtering)
  - Known presets found by name (e.g., "Acoustic Grand Piano" at program 0, "Cello" at program 42)
  - EOP sentinel record is not in the result
  - Preset names have no trailing null bytes or whitespace
  - Returns empty array or throws for invalid/missing file

- **SoundFontLibrary** (`SoundFontLibraryTests.swift`):
  - Discovers SF2 from bundle and enumerates presets
  - Drum kits filtered out (no bank >= 128 presets in result)
  - Presets sorted by program number
  - `preset(forTag: "sf2:42")` returns Cello preset
  - `preset(forTag: "sf2:999")` returns nil
  - `preset(forTag: "sine")` returns nil (not an SF2 tag)

- **SoundFontNotePlayer preset switching** (extend existing tests):
  - `loadPreset(program: 0)` succeeds (piano)
  - `loadPreset(program: 42)` succeeds (cello)
  - Loading a preset after `play()` works without crash
  - Pitch bend range survives preset change (re-sent via RPN)

- **RoutingNotePlayer** (update existing tests):
  - `"sf2:0"` routes to SoundFontNotePlayer
  - `"sf2:42"` routes to SoundFontNotePlayer
  - `"sine"` routes to SineWaveNotePlayer
  - Old `"cello"` tag handled gracefully (migration or fallback)

- **All tests `@MainActor async`** per project testing rules

### Previous Story Intelligence

**From story 8-1 (prerequisite):**
- `SoundFontNotePlayer` exists with hardcoded Cello preset — this story generalizes it
- `RoutingNotePlayer` exists with `"sine"` / `"cello"` routing — this story replaces `"cello"` with `"sf2:{program}"`
- `FrequencyCalculation.midiNoteAndCents()` exists — reused without changes
- Settings picker has "Sine Wave" and "Cello" — this story replaces with dynamic list
- PeachApp already wires `RoutingNotePlayer` — this story adds `SoundFontLibrary` to the composition root

**From `infra-sf2-build-download-cache` (done):**
- GeneralUser GS SF2 bundled in app — `SF2PresetParser` reads this same file
- Access: `Bundle.main.url(forResource: "GeneralUser-GS", withExtension: "sf2")`
[Source: docs/implementation-artifacts/infra-sf2-build-download-cache.md]

### Git Intelligence

This story builds directly on story 8-1. The SF2 file is already bundled; the PHDR parser reads the same binary file that `AVAudioUnitSampler` loads. No new build infrastructure needed.

### Project Structure Notes

- `SF2PresetParser` and `SoundFontLibrary` live in `Peach/Core/Audio/` — they are audio-domain types, not generic utilities
- `SoundFontLibrary` follows the same pattern as other injected services: `EnvironmentKey` defined alongside the type, wired in `PeachApp.swift`
- No new directories needed

### References

- [Source: docs/planning-artifacts/research/technical-sampled-instrument-noteplayer-research-2026-02-23.md#instrument-auto-discovery] — SF2 PHDR parsing, 38-byte record format, preset enumeration flow
- [Source: docs/planning-artifacts/research/technical-sampled-instrument-noteplayer-research-2026-02-23.md#system-design] — SoundFontLibrary design, preset-based instrument selection
- [Source: SF2 Specification v2.01, Section 7.2] — PHDR chunk format (via research doc reference)
- [Source: docs/project-context.md] — Environment injection pattern, @MainActor requirements, testing rules
- [Source: docs/implementation-artifacts/8-1-implement-soundfont-noteplayer.md] — Prerequisite story: SoundFontNotePlayer, RoutingNotePlayer, FrequencyCalculation extensions

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
