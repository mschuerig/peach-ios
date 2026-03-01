# Story 27.2: Preset Crash Investigation Tests

Status: ready-for-dev

## Story

As a developer maintaining SoundFontNotePlayer,
I want a systematic test suite that iterates all SF2 presets across the MIDI note range with varied durations and velocities,
so that any preset-specific crashes (especially Grand Piano) are detected and root causes can be identified.

## Acceptance Criteria

1. A new test file `SoundFontPresetStressTests.swift` exists in `PeachTests/Core/Audio/`
2. The suite is gated by `.enabled(if: ProcessInfo.processInfo.environment["RUN_STRESS_TESTS"] != nil)` — skipped in regular test runs, enabled with `RUN_STRESS_TESTS=1`
3. Tests iterate all melodic presets discovered by `SoundFontLibrary` (261 presets from GeneralUser-GS.sf2)
4. For each preset, tests play notes across representative MIDI note values (boundary and mid-range)
5. Tests exercise multiple durations (short burst, normal, sustained) per preset
6. Tests exercise multiple velocity levels per preset
7. All tests use `SoundFontNotePlayer` directly (not mocks) — this is real audio hardware stress testing
8. Tests report which preset/note/duration combination causes a failure (if any), not just "test failed"
9. No existing tests are modified
10. Regular test suite still passes without `RUN_STRESS_TESTS`: `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`

## Tasks / Subtasks

- [ ] Task 1: Create `SoundFontPresetStressTests.swift` with environment gate (AC: #1, #2, #9)
  - [ ] 1.1 Create file at `PeachTests/Core/Audio/SoundFontPresetStressTests.swift`
  - [ ] 1.2 Import `Testing`, `Foundation`, `@testable import Peach`
  - [ ] 1.3 Define `@Suite("SoundFont Preset Stress Tests", .enabled(if: ProcessInfo.processInfo.environment["RUN_STRESS_TESTS"] != nil))`

- [ ] Task 2: Implement per-preset play-and-stop smoke test (AC: #3, #7, #8)
  - [ ] 2.1 Use `SoundFontLibrary().availablePresets` to get all 261 melodic presets
  - [ ] 2.2 For each preset, load via `loadPreset(program:bank:)` and play a single note (A4 = 440 Hz, velocity 63, 0.1s duration)
  - [ ] 2.3 Use `@Test(arguments:)` with `SF2Preset` array for per-case reporting including preset name, bank, and program
  - [ ] 2.4 Stop note via `PlaybackHandle.stop()` and verify no crash

- [ ] Task 3: Implement MIDI note range sweep per preset (AC: #4, #7, #8)
  - [ ] 3.1 For a representative subset of presets (Grand Piano bank 0 program 0, Sine Wave bank 8 program 80, and ~5 others spanning bank/program range), play notes at MIDI values: 0, 21, 36, 48, 60, 69, 84, 96, 108, 127
  - [ ] 3.2 Each note: play at velocity 63, 0.1s duration, verify no crash
  - [ ] 3.3 Descriptive failure messages: "Preset '{name}' (bank {b}, program {p}) crashed at MIDI note {n}"

- [ ] Task 4: Implement duration variation tests (AC: #5, #7, #8)
  - [ ] 4.1 For Grand Piano (bank 0, program 0) and 2-3 other presets, play A4 with durations: 0.01s (10ms burst), 0.1s (normal), 0.5s (sustained)
  - [ ] 4.2 Verify no crash at each duration
  - [ ] 4.3 Descriptive failure messages including preset and duration

- [ ] Task 5: Implement velocity variation tests (AC: #6, #7, #8)
  - [ ] 5.1 For Grand Piano and 2-3 other presets, play A4 at velocities: 1 (pianissimo), 63 (mezzo), 127 (fortissimo)
  - [ ] 5.2 Verify no crash at each velocity
  - [ ] 5.3 Descriptive failure messages including preset and velocity

- [ ] Task 6: Implement rapid preset switching stress test (AC: #7, #8)
  - [ ] 6.1 Load 10+ presets in rapid succession (no play between loads) — verify `loadPreset` doesn't crash
  - [ ] 6.2 Load preset, play note, stop, switch preset, play note, stop — repeat for 5+ different presets in sequence

- [ ] Task 7: Run full test suite and verify (AC: #9, #10)
  - [ ] 7.1 Run without env var: `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'` — stress tests must be skipped
  - [ ] 7.2 Run with env var: `RUN_STRESS_TESTS=1 xcodebuild test ...` — stress tests must execute
  - [ ] 7.3 Confirm zero existing test modifications
  - [ ] 7.4 Document any presets that fail (crash root cause analysis)

## Dev Notes

### Investigation Context

This story creates a diagnostic test suite to systematically stress-test all SF2 presets in GeneralUser-GS.sf2. The sprint status describes the goal as finding the "Grand Piano crash root cause." No actual crash has been confirmed in the codebase — this is **proactive crash detection** across the full preset space.

Currently only 4 presets are tested in `SoundFontNotePlayerTests.swift`:
- Program 0 (Grand Piano) — `loadPreset` only, no play-through-sweep
- Program 42 (Cello) — `loadPreset` only
- Bank 8, Program 4 (Chorused Tine EP) — `loadPreset` only
- Bank 8, Program 80 (Sine Wave) — default, most play tests use this

The remaining 257 melodic presets have zero test coverage for play/stop lifecycle.

### SoundFontNotePlayer Architecture

**File:** `Peach/Core/Audio/SoundFontNotePlayer.swift` (223 lines)

Key methods to exercise:
- `loadPreset(program:bank:)` — calls `sampler.loadSoundBankInstrument()` with 20ms settle delay
- `play(frequency:velocity:amplitudeDB:)` → `PlaybackHandle` — full pipeline: preset load, frequency validation, audio session, engine start, MIDI note-on
- `play(frequency:duration:velocity:amplitudeDB:)` — convenience wrapper with `Task.sleep` duration
- `stopAll()` — CC#123 all-notes-off with fade-out

**Crash risk surface:**
- `sampler.loadSoundBankInstrument(at:program:bankMSB:bankLSB:)` — Apple's API, known to crash with malformed SF2 or unsupported preset indices
- `sampler.startNote(_:withVelocity:onChannel:)` — could crash if preset has no sample zone for the given MIDI note
- Rapid preset switching — audio graph may not settle in 20ms for all presets

**SF2 file:** GeneralUser-GS.sf2 (32 MB, 287 total presets, 261 melodic after filtering bank >= 120 and program >= 120)

### Test Design Approach

Use real `SoundFontNotePlayer` instances (not mocks) — this is hardware-level stress testing. Tests must run on the iOS Simulator where AVAudioEngine is available.

**Environment gating:** The entire `@Suite` uses `.enabled(if: ProcessInfo.processInfo.environment["RUN_STRESS_TESTS"] != nil)`. Regular `xcodebuild test` skips all stress tests. Run explicitly with:
```
RUN_STRESS_TESTS=1 xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'
```

**Preset discovery:** Use `SoundFontLibrary().availablePresets` directly — no wrapper needed. `SoundFontLibrary` discovers, filters (bank < 120, program < 120), and sorts presets at init.

**Parameterized vs. loop approach:** Swift Testing supports `@Test(arguments:)` for parameterized tests, which gives per-case reporting. However, with 261 presets x multiple notes, the test count could be very high. Balance:
- Use `@Test(arguments:)` for the per-preset smoke test (261 test cases — acceptable, each gets its own pass/fail)
- Use inner loops for note range / duration / velocity sweeps within focused tests (reduces test case explosion)

**Timing:** Each preset load has 20ms settle delay. With 261 presets, the smoke test alone takes ~5.2s minimum. With note sweeps and duration tests, total runtime may reach several minutes. This is acceptable — the suite only runs on explicit request.

**Disable `stopPropagationDelay`:** Pass `stopPropagationDelay: .zero` when creating the player for stress tests — the 25ms fade-out per note would add significant time with hundreds of play/stop cycles and is not relevant to crash detection.

### Previous Story Intelligence (27.1)

Story 27.1 decomposed `play()` into 5 named sub-operations:
- `ensurePresetLoaded()` — reads `userSettings.soundSource`, parses SF2 tag, calls `loadPreset`
- `validateFrequency(_:)` — guard against out-of-range Hz
- `ensureAudioSessionConfigured()` — one-time AVAudioSession setup
- `ensureEngineRunning()` — conditional `engine.start()`
- `startNote(frequency:velocity:amplitudeDB:)` — decompose frequency, set gain, send pitch bend, MIDI note-on

All extracted methods are `private`. No behavioral change. All existing tests pass unchanged.

**Relevant learnings from 27.1:**
- Single file change pattern works well for SoundFontNotePlayer modifications
- The `// MARK: - Play Sub-operations` section is between NotePlayer Protocol and MIDI Helpers
- `loadPreset(program:bank:)` is `public` — callable directly in tests
- `MockUserSettings` is available for controlling `soundSource` in tests

### Git Intelligence

Recent commits (most relevant):
- `9afe10e` — Implement story 27.1: Decompose Play Method (current HEAD)
- Focus on SoundFontNotePlayer refactoring — no behavioral changes
- All 48 tests in `SoundFontNotePlayerTests.swift` pass

### Critical Constraints

- **Swift Testing only** — `@Test`, `@Suite`, `#expect()`; no XCTest
- **Every `@Test` must be `async`** — default MainActor isolation
- **No `test` prefix on function names** — `@Test` attribute marks the test
- **Run full suite:** `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
- **Test file placement:** `PeachTests/Core/Audio/SoundFontPresetStressTests.swift`
- **No modifications to existing test files** — this is additive only
- **No new source files** — only test files
- **`SoundFontLibrary` init takes `bundle: Bundle = .main`** — usable directly in tests
- **`SoundFontNotePlayer` init takes `userSettings: UserSettings`** — use `MockUserSettings()`
- **Value types:** `SF2Preset` is `Sendable, Equatable, Hashable` — safe for parameterized tests
- **`loadPreset` skips if same preset already loaded** — the `guard program != loadedProgram || bank != loadedBank` check means re-loading the default preset requires loading something else first

### Project Structure Notes

- New file: `PeachTests/Core/Audio/SoundFontPresetStressTests.swift` — mirrors source structure
- No cross-feature impact — tests only exercise `Core/Audio/` types
- No new dependencies or imports beyond `Testing`, `Foundation`, `@testable import Peach`

### References

- [Source: Peach/Core/Audio/SoundFontNotePlayer.swift] — play/loadPreset implementation (223 lines)
- [Source: Peach/Core/Audio/SoundFontPlaybackHandle.swift] — stop/adjustFrequency (65 lines)
- [Source: Peach/Core/Audio/SF2PresetParser.swift] — SF2 PHDR parsing (177 lines)
- [Source: Peach/Core/Audio/SoundFontLibrary.swift] — preset discovery, filtering, sorting (55 lines)
- [Source: Peach/Core/Audio/NotePlayer.swift] — protocol + AudioError enum
- [Source: PeachTests/Core/Audio/SoundFontNotePlayerTests.swift] — existing 48 tests (405 lines)
- [Source: docs/project-context.md] — testing standards, concurrency rules, naming conventions
- [Source: docs/implementation-artifacts/27-1-decompose-play-method.md] — previous story context

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
