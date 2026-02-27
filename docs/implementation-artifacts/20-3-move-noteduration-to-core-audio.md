# Story 20.3: Move NoteDuration to Core/Audio/

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer maintaining Peach**,
I want `NoteDuration` moved from `Settings/` to `Core/Audio/`,
So that all audio domain value types are co-located in `Core/Audio/`, the `UserSettings` protocol references only `Core/` types, and no Core/ consumer depends on Settings/.

## Acceptance Criteria

1. **`NoteDuration.swift` lives in `Core/Audio/`** -- `Peach/Settings/NoteDuration.swift` is moved to `Peach/Core/Audio/NoteDuration.swift`. The original file no longer exists in `Peach/Settings/`.

2. **`NoteDurationTests.swift` lives in test mirror** -- `PeachTests/Settings/NoteDurationTests.swift` is moved to `PeachTests/Core/Audio/NoteDurationTests.swift`.

3. **`UserSettings` protocol references only Core/ types** -- After the move, every type in the `UserSettings` protocol signature (`SoundSourceID`, `NoteDuration`, `MIDINote`, `Frequency`, `UnitInterval`) is defined in `Core/`. The dependency direction is correct: Settings/ depends on Core/, not the reverse.

4. **Zero code changes required** -- Single-module app; types resolved by name, not directory path.

5. **All existing tests pass** -- Full test suite passes with zero regressions and zero code changes.

## Tasks / Subtasks

- [ ] Task 1: Move production file (AC: #1)
  - [ ] `git mv Peach/Settings/NoteDuration.swift Peach/Core/Audio/NoteDuration.swift`

- [ ] Task 2: Move test file (AC: #2)
  - [ ] `git mv PeachTests/Settings/NoteDurationTests.swift PeachTests/Core/Audio/NoteDurationTests.swift`

- [ ] Task 3: Verify dependency direction (AC: #3)
  - [ ] Confirm all types in `UserSettings` protocol are now defined in `Core/`
  - [ ] Confirm no Core/ file references any type defined in Settings/

- [ ] Task 4: Run full test suite (AC: #4, #5)
  - [ ] `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [ ] All tests pass, zero regressions, zero code changes

## Dev Notes

### Critical Design Decisions

- **`NoteDuration` is a domain value type** -- It represents note duration in seconds (0.3–3.0 range) with clamping validation. It is structurally identical to other audio domain types already in `Core/Audio/` (`MIDINote`, `Frequency`, `Cents`, `AmplitudeDB`, `MIDIVelocity`, `SoundSourceID`). It has no Settings-specific logic.
- **This completes the story 20.1 oversight** -- Story 20.1 moved shared domain types to `Core/Training/` but missed `NoteDuration` in `Settings/`. Story 20.2 moved `SoundSourceID` from `Settings/` to `Core/Audio/`. This story completes the pattern by moving the last remaining domain type out of `Settings/`.
- **After this move, `UserSettings` protocol depends only on Core/ types** -- `SoundSourceID` (Core/Audio/), `NoteDuration` (Core/Audio/), `MIDINote` (Core/Audio/), `Frequency` (Core/Audio/), `UnitInterval` (Core/). The dependency direction is fully correct: Settings/ → Core/.

### Architecture & Integration

**Moved files (content unchanged):**
- `Peach/Settings/NoteDuration.swift` → `Peach/Core/Audio/NoteDuration.swift`
- `PeachTests/Settings/NoteDurationTests.swift` → `PeachTests/Core/Audio/NoteDurationTests.swift`

**No modified files.** All consumers reference `NoteDuration` by name only.

### Existing Code to Reference

- **`NoteDuration.swift`** -- Pure value type, ~33 lines. `struct NoteDuration: Hashable, Comparable, Sendable` with `rawValue: Double`, clamping init, `ExpressibleByFloatLiteral`, `ExpressibleByIntegerLiteral`. Uses `clamped(to:)` utility. [Source: Peach/Settings/NoteDuration.swift]
- **`UserSettings.swift`** -- Protocol exposing `var noteDuration: NoteDuration`. After this move, all types in the protocol signature live in Core/. [Source: Peach/Settings/UserSettings.swift]
- **`ComparisonSession.swift`** -- Reads `currentNoteDuration` computed property (delegates to `userSettings.noteDuration`). [Source: Peach/Comparison/ComparisonSession.swift]
- **`PitchMatchingSession.swift`** -- Reads `currentNoteDuration` computed property (delegates to `userSettings.noteDuration`). [Source: Peach/PitchMatching/PitchMatchingSession.swift]
- **`AppUserSettings.swift`** -- Implementation of `UserSettings`, reads `noteDuration` from `UserDefaults`. [Source: Peach/Settings/AppUserSettings.swift]
- **`SoundSourceID.swift`** -- Analogous type already moved to `Core/Audio/` in story 20.2. Follow the exact same move pattern. [Source: Peach/Core/Audio/SoundSourceID.swift]

### Previous Story Intelligence

Story 20.2 (Move SoundSourceID to Core/Audio/) is the direct precedent:
- Pure `git mv` for production file and test file — zero code changes
- Xcode objectVersion 77 file-system-synchronized groups handle the move automatically
- Single-module app resolves types by name, not directory path
- 588 tests passed with zero regressions
- Code review found only informational items (L-level)

### Testing Approach

- **No new tests** -- Pure file move with no behavioral change.
- **Run full suite** to confirm the compiler resolves `NoteDuration` at its new path.
- Existing `NoteDurationTests.swift` (7 tests: construction, clamping, literals, comparable, hashable) moves alongside the production file.

### Risk Assessment

- **Extremely low risk** -- Identical pattern to stories 20.1 and 20.2, both completed successfully with zero issues. Single-module app means file location does not affect compilation.

### Project Structure Notes

- `Core/Audio/` already contains: `MIDINote.swift`, `Frequency.swift`, `Cents.swift`, `AmplitudeDB.swift`, `MIDIVelocity.swift`, `SoundSourceID.swift`, `SoundFontNotePlayer.swift`, `SF2PresetParser.swift`, `NotePlayer.swift`, `PlaybackHandle.swift`, `FrequencyCalculation.swift`
- Adding `NoteDuration.swift` co-locates it with the other audio domain value types
- `PeachTests/Core/Audio/` already contains `SoundSourceIDTests.swift` (moved in 20.2)

### References

- [Source: docs/planning-artifacts/epics.md -- Epic 20: Right Direction — Dependency Inversion Cleanup]
- [Source: docs/implementation-artifacts/20-2-move-soundsourceid-to-core.md -- Analogous SoundSourceID move]
- [Source: docs/project-context.md -- File Placement decision tree: "Protocol or service used across features → Core/{subdomain}/"]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
