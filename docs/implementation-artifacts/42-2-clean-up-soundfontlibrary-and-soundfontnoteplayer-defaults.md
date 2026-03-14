# Story 42.2: Clean Up SoundFontLibrary and SoundFontNotePlayer Defaults

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer**,
I want SoundFontLibrary to work with a single explicitly provided SF2 file and SoundFontNotePlayer to receive all configuration explicitly,
so that the audio code does not depend on a specific SF2's bank structure or hardcoded preset defaults.

## Acceptance Criteria

1. **Given** `SoundFontLibrary`, **when** initialized, **then** it accepts an explicit SF2 URL (no scanning for all `.sf2` files in the bundle) **and** it discovers presets only from that single SF2 file.

2. **Given** `SoundFontNotePlayer`, **when** initialized, **then** it does not use default arguments for `sf2Name` — the caller must provide it explicitly **and** the default preset (program and bank) is provided explicitly at init, not hardcoded as constants **and** the hardcoded `defaultPresetProgram = 80` and `defaultPresetBank = 8` are removed.

3. **Given** the app's composition root (`PeachApp` or environment setup), **when** it creates the SoundFontNotePlayer, **then** it provides the SF2 filename and default preset explicitly **and** changing which SF2 or default preset is used requires changing only the composition root, not the library or player.

4. **Given** the existing test suite, **when** all tests are run after the refactor, **then** all tests pass — behavior is unchanged, only the wiring is explicit.

## Tasks / Subtasks

- [x] Task 1: Change `SoundFontLibrary.init(bundle:)` to `SoundFontLibrary.init(sf2URL:)` (AC: #1)
  - [x] 1.1 Replace `init(bundle: Bundle = .main)` with `init(sf2URL: URL)` — accept a single SF2 file URL, no bundle scan
  - [x] 1.2 Remove `bundle.urls(forResourcesWithExtension: "sf2", subdirectory: nil)` loop; parse presets only from the provided `sf2URL`
  - [x] 1.3 Keep filtering (bank < 120, program < 120), sorting, and `SoundSourceProvider` conformance unchanged
  - [x] 1.4 Update `SoundFontLibraryTests` to construct with an explicit URL (resolve from test bundle)
- [x] Task 2: Make `SoundFontNotePlayer` init fully explicit (AC: #2)
  - [x] 2.1 Remove default value for `sf2Name` parameter — change `sf2Name: String = "GeneralUser-GS"` to `sf2Name: String` (required)
  - [x] 2.2 Add `defaultProgram: Int` and `defaultBank: Int` parameters to init (no defaults)
  - [x] 2.3 Remove `private static let defaultPresetProgram: Int = 80` and `private static let defaultPresetBank: Int = 8`
  - [x] 2.4 Use the new init parameters to set `loadedProgram`/`loadedBank` and for the initial `loadSoundBankInstrument` call
  - [x] 2.5 Replace all references to `Self.defaultPresetProgram` / `Self.defaultPresetBank` in `ensurePresetLoaded()` with the stored init values (store as instance properties)
- [x] Task 3: Update composition root and environment defaults (AC: #3)
  - [x] 3.1 In `PeachApp.init()`: pass `sf2Name`, `defaultProgram`, and `defaultBank` explicitly to `SoundFontNotePlayer`
  - [x] 3.2 In `PeachApp.init()`: pass explicit SF2 URL to `SoundFontLibrary` (resolve from `Bundle.main`)
  - [x] 3.3 In `EnvironmentKeys.swift`: update `SoundFontLibrary()` default to pass an explicit URL (for preview stubs, this can use a dummy/empty path or remain as-is if previews don't need real SF2 data)
- [x] Task 4: Update all test call sites (AC: #4)
  - [x] 4.1 Update `SoundFontNotePlayerTests` — pass explicit `sf2Name`, `defaultProgram`, `defaultBank` in all `SoundFontNotePlayer(...)` calls
  - [x] 4.2 Update `SoundFontPresetStressTests` — pass explicit SF2 URL to `SoundFontLibrary`
  - [x] 4.3 Verify `MockUserSettings` needs no changes (it does not — it doesn't mock NotePlayer init)
  - [x] 4.4 Run full test suite with `bin/test.sh` and confirm all tests pass

## Dev Notes

### What This Story IS

A **wiring refactor** — no behavioral changes. The same SF2 file is loaded, the same presets are discovered, the same default preset is used. The only difference is that all these values are provided explicitly by the caller instead of hardcoded inside the library/player.

### What This Story Is NOT

- Does NOT change which SF2 file is bundled (still `GeneralUser-GS.sf2`)
- Does NOT change the default preset (still Sine Wave: bank 8, program 80)
- Does NOT add or remove presets
- Does NOT touch `SF2PresetParser`, `SoundSourceProvider` protocol, `SoundSourceID`, or `SoundFontPlaybackHandle`
- Does NOT change `SettingsKeys.defaultSoundSource` (`"sf2:8:80"`)

### Current State Analysis

**`SoundFontLibrary` (Peach/Core/Audio/SoundFontLibrary.swift):**
- Line 11: `init(bundle: Bundle = .main)` — scans ALL `.sf2` files in the bundle
- Lines 14–25: `bundle.urls(forResourcesWithExtension: "sf2", subdirectory: nil)` loops over every SF2 found
- This is over-general: the app always bundles exactly one SF2 file

**`SoundFontNotePlayer` (Peach/Core/Audio/SoundFontNotePlayer.swift):**
- Line 40–42: Hardcoded defaults:
  ```swift
  private static let defaultPresetProgram: Int = 80
  private static let defaultPresetBank: Int = 8
  ```
- Line 54: `init(sf2Name: String = "GeneralUser-GS", ...)` — default arg hides the dependency
- Lines 64–65: Init uses `Self.defaultPresetProgram` / `Self.defaultPresetBank` for initial state
- Lines 71–76: Init calls `loadSoundBankInstrument` with these hardcoded values
- Lines 138–148: `ensurePresetLoaded()` falls back to `Self.defaultPresetProgram` / `Self.defaultPresetBank`

**Composition Root (Peach/App/PeachApp.swift):**
- Line 30: `let soundFontLibrary = SoundFontLibrary()` — no explicit URL
- Line 36: `try SoundFontNotePlayer(userSettings: userSettings, stopPropagationDelay: .zero)` — relies on default `sf2Name`

**Environment Defaults (Peach/App/EnvironmentKeys.swift):**
- Line 6: `@Entry var soundSourceProvider: any SoundSourceProvider = SoundFontLibrary()` — preview default

### Refactoring Approach

1. **`SoundFontLibrary`**: Change init to accept `sf2URL: URL`. Remove bundle scan loop. Parse presets from the single URL.

2. **`SoundFontNotePlayer`**: Remove static constants. Add `defaultProgram: Int` and `defaultBank: Int` as init params. Store as private instance properties (e.g., `private let fallbackProgram: Int`, `private let fallbackBank: Int`). Use these in `ensurePresetLoaded()` fallback path. Remove default value from `sf2Name`.

3. **`PeachApp.init()`**: Resolve SF2 URL from bundle, pass to both `SoundFontLibrary(sf2URL:)` and `SoundFontNotePlayer(sf2Name:..., defaultProgram:80, defaultBank:8, ...)`. The SF2 filename and default preset values live ONLY here.

4. **`EnvironmentKeys.swift`**: The `SoundFontLibrary()` preview default will no longer compile without a URL. Options:
   - Create a simple empty `SoundSourceProvider` stub for previews (like `PreviewNotePlayer` pattern)
   - Or resolve a URL from the main bundle for previews too
   - Preferred: Replace with a lightweight preview stub since previews don't need real SF2 parsing

### Test Impact

- **`SoundFontLibraryTests`**: All tests create `SoundFontLibrary()` with default bundle. Change to resolve URL from test bundle: `Bundle(for: SoundFontLibraryTests.self)` won't work (it's a struct). Use `Bundle.main.url(forResource: "GeneralUser-GS", withExtension: "sf2")!` since test host includes the bundle resources.
- **`SoundFontNotePlayerTests`**: All tests create `SoundFontNotePlayer(userSettings: MockUserSettings())`. Add explicit `sf2Name: "GeneralUser-GS"`, `defaultProgram: 80`, `defaultBank: 8`. Consider a test factory method to reduce repetition.
- **`SoundFontPresetStressTests`**: Same pattern as library tests.
- **`MockUserSettings`**: No changes needed — it mocks `UserSettings`, not `NotePlayer` init.

### Previous Story Intelligence (42.1)

Story 42.1 was a shell script story (no Swift changes). Key context:
- Multiple SF2 files now download to `.cache/` but only `GeneralUser-GS.sf2` is bundled in Xcode
- The custom SF2 assembly (replacing GeneralUser GS piano with FluidR3_GM piano) is a **future** story — this story prepares the code to accept any SF2 without assumptions

### Git Intelligence

Recent commits are all story 42.1 (shell script). No Swift code has changed in the last 5 commits. The codebase is clean and stable.

### Project Structure Notes

- `SoundFontLibrary.swift` → `Peach/Core/Audio/SoundFontLibrary.swift`
- `SoundFontNotePlayer.swift` → `Peach/Core/Audio/SoundFontNotePlayer.swift`
- `PeachApp.swift` → `Peach/App/PeachApp.swift`
- `EnvironmentKeys.swift` → `Peach/App/EnvironmentKeys.swift`
- `SoundFontLibraryTests.swift` → `PeachTests/Core/Audio/SoundFontLibraryTests.swift`
- `SoundFontNotePlayerTests.swift` → `PeachTests/Core/Audio/SoundFontNotePlayerTests.swift`
- `SoundFontPresetStressTests.swift` → `PeachTests/Core/Audio/SoundFontPresetStressTests.swift`
- `MockUserSettings.swift` → `PeachTests/Mocks/MockUserSettings.swift` (no changes expected)
- No new files should be created — this is purely a refactor of existing files

### References

- [Source: docs/planning-artifacts/epics.md#Epic 42, Story 42.2]
- [Source: Peach/Core/Audio/SoundFontLibrary.swift] — current bundle-scanning init
- [Source: Peach/Core/Audio/SoundFontNotePlayer.swift] — hardcoded defaults at lines 40-42, default arg at line 54
- [Source: Peach/App/PeachApp.swift] — composition root at lines 30, 36
- [Source: Peach/App/EnvironmentKeys.swift] — preview default at line 6
- [Source: docs/project-context.md#AVAudioEngine] — SoundFontNotePlayer and SoundFontLibrary architecture
- [Source: docs/implementation-artifacts/42-1-extend-download-script-for-multiple-soundfont-sources.md] — previous story context

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None — clean implementation with no issues.

### Completion Notes List

#### Round 1–2 (initial wiring refactor)
- Replaced `SoundFontLibrary.init(bundle:)` with `init(sf2URL:)` — removed bundle scan loop
- Removed `SoundFontLibrary.preset(forTag:)`, `_availableSources`, and `displayName(for:)`
- Introduced `SoundFontNotePlayer.Configuration` struct, removed `parseSF2Tag`
- All test files updated with `testConfig`/`makePlayer()` factories

#### Round 3 (Stairway to Heaven pattern)
- `SoundSourceID` changed from `struct` to `protocol` with `rawValue: String` and `displayName: String` — fully opaque, no format awareness
- `SF2Preset` now conforms to `SoundSourceID` — `rawValue` computes `"sf2:bank:program"`, `displayName` returns `name`
- Removed `SF2Preset.sourceID` computed property, `SoundSourceID.sf2Components`, and `ExpressibleByStringLiteral` conformance
- `SoundSourceProvider` protocol uses `availableSources: [any SoundSourceID]` — consumers see opaque IDs only
- `SoundFontLibrary` exposes `sf2URL`, accepts `defaultPreset: String` at init, owns `resolve(_ rawValue:) -> (bank, program)` with full fallback logic
- `SoundFontNotePlayer` takes `SoundFontLibrary` directly (not behind a protocol) — delegates all preset resolution to `library.resolve()`
- Removed `SoundFontNotePlayer.Configuration` struct — player init takes `library`, `userSettings`, `stopPropagationDelay`
- `UserSettings.soundSource` changed from `SoundSourceID` to `String` — @AppStorage stores strings, no wrapper needed
- `AppUserSettings`, `MockUserSettings`, `PreviewUserSettings` updated to return `String`
- `EnvironmentKeys.swift`: reintroduced `PreviewSoundSourceProvider` (empty stub), eliminated "GeneralUser-GS" literal
- `SettingsScreen`: uses `source.displayName` and `source.rawValue` via `SoundSourceID` protocol
- `SettingsKeys.validateSoundSource`: uses `availableSources` + `rawValue` matching
- `SoundSourceIDTests` rewritten to test protocol contract via `SF2Preset`
- `SoundFontLibraryTests` adds `resolve()` tests (valid, garbage, unknown, empty)
- All test factories use `SoundFontLibrary` directly instead of `Configuration`
- `SoundFontPresetStressTests` uses `Set<String>` raw values instead of `Set<SoundSourceID>`
- "GeneralUser-GS" string appears ONLY in `PeachApp.swift` (composition root)
- Full test suite: 1054 passed, 1 pre-existing flaky failure (`ProgressTimelineTests/ewmaHalflife`) unrelated to this story

### Change Log

- 2026-03-14: Implemented story 42.2 — explicit wiring refactor + SF2Preset/SoundSourceProvider design cleanup
- 2026-03-15: Applied Stairway to Heaven pattern — SoundSourceID as protocol, direct library dependency, opaque sound source IDs

### File List

- Peach/Core/Audio/SoundSourceID.swift (rewritten — struct → protocol with `rawValue` + `displayName`)
- Peach/Core/Audio/SF2PresetParser.swift (modified — `SF2Preset` conforms to `SoundSourceID`, removed `sourceID` property)
- Peach/Core/Audio/SoundSourceProvider.swift (modified — `availableSources: [any SoundSourceID]`)
- Peach/Core/Audio/SoundFontLibrary.swift (modified — exposes `sf2URL`, `init(sf2URL:defaultPreset:)`, `resolve()`)
- Peach/Core/Audio/SoundFontNotePlayer.swift (modified — takes `SoundFontLibrary` directly, removed `Configuration`)
- Peach/App/PeachApp.swift (modified — only place with "GeneralUser-GS", passes library to player)
- Peach/App/EnvironmentKeys.swift (modified — `PreviewSoundSourceProvider` stub, `soundSource` as `String`)
- Peach/Settings/UserSettings.swift (modified — `soundSource: String`)
- Peach/Settings/AppUserSettings.swift (modified — returns `String`)
- Peach/Settings/SettingsScreen.swift (modified — `availableSources`, `displayName`/`rawValue`)
- Peach/Settings/SettingsKeys.swift (modified — `availableSources` + `rawValue` matching)
- PeachTests/Core/Audio/SoundSourceIDTests.swift (rewritten — tests protocol contract via SF2Preset)
- PeachTests/Core/Audio/SoundFontLibraryTests.swift (modified — `resolve()` tests, `rawValue`/`displayName`)
- PeachTests/Core/Audio/SoundFontNotePlayerTests.swift (modified — `testLibrary` + `makePlayer()`)
- PeachTests/Core/Audio/SoundFontPlaybackHandleTests.swift (modified — `testLibrary` + `makePlayer()`)
- PeachTests/Core/Audio/SoundFontPresetStressTests.swift (modified — `Set<String>` raw values)
- PeachTests/Core/Audio/SF2PresetParserTests.swift (modified — `rawValue` instead of `sourceID`)
- PeachTests/Settings/SettingsKeysTests.swift (modified — `MockSoundSourceProvider` with `availableSources`)
- PeachTests/Mocks/MockUserSettings.swift (modified — `soundSource: String`)
- docs/implementation-artifacts/42-2-clean-up-soundfontlibrary-and-soundfontnoteplayer-defaults.md (modified)
