# Story 11.1: Rename Training Types and Files to Comparison

Status: done

## Story

As a **developer**,
I want all ambiguous "Training" names renamed to comparison-specific names,
so that the codebase clearly distinguishes comparison training from future training modes and the namespace is clean for pitch matching.

## Acceptance Criteria

1. `TrainingSession` (class) becomes `ComparisonSession` in all source, test, and doc references; file renamed `TrainingSession.swift` -> `ComparisonSession.swift`; test file renamed `TrainingSessionTests.swift` -> `ComparisonSessionTests.swift`
2. `TrainingState` (enum) becomes `ComparisonSessionState` in all references
3. `TrainingScreen` (struct) becomes `ComparisonScreen`; file renamed `TrainingScreen.swift` -> `ComparisonScreen.swift`; all references updated
4. `Peach/Training/` directory becomes `Peach/Comparison/`; `PeachTests/Training/` becomes `PeachTests/Comparison/`
5. `FeedbackIndicator` (struct) becomes `ComparisonFeedbackIndicator`; file renamed `FeedbackIndicator.swift` -> `ComparisonFeedbackIndicator.swift`
6. `NextNoteStrategy` (protocol) becomes `NextComparisonStrategy`; file renamed `NextNoteStrategy.swift` -> `NextComparisonStrategy.swift`; method `nextComparison()` keeps its current name (already correct)
7. These names remain UNCHANGED: `TrainingDataStore`, `TrainingSettings`, `ComparisonObserver`, `Comparison`, `CompletedComparison`, `PerceptualProfile`, `NotePlayer`, `HapticFeedbackManager`
8. `docs/project-context.md` references updated to new names
9. Full test suite passes with zero functional changes

## Tasks / Subtasks

- [x] Task 1: Rename directories (AC: #4)
  - [x] `git mv Peach/Training Peach/Comparison`
  - [x] `git mv PeachTests/Training PeachTests/Comparison`
- [x] Task 2: Rename source files (AC: #1, #3, #5, #6)
  - [x] `git mv Peach/Comparison/TrainingSession.swift Peach/Comparison/ComparisonSession.swift`
  - [x] `git mv Peach/Comparison/TrainingScreen.swift Peach/Comparison/ComparisonScreen.swift`
  - [x] `git mv Peach/Comparison/FeedbackIndicator.swift Peach/Comparison/ComparisonFeedbackIndicator.swift`
  - [x] `git mv Peach/Core/Algorithm/NextNoteStrategy.swift Peach/Core/Algorithm/NextComparisonStrategy.swift`
- [x] Task 3: Rename test files (AC: #1, #3)
  - [x] `git mv` all `TrainingSession*.swift` test files to `ComparisonSession*.swift`
  - [x] `git mv` all `TrainingScreen*.swift` test files to `ComparisonScreen*.swift`
- [x] Task 4: Find-and-replace type names in all .swift files (AC: #1, #2, #3, #5, #6)
  - [x] `TrainingSession` -> `ComparisonSession` (exclude `TrainingDataStore` references)
  - [x] `TrainingState` -> `ComparisonSessionState`
  - [x] `TrainingScreen` -> `ComparisonScreen`
  - [x] `FeedbackIndicator` -> `ComparisonFeedbackIndicator`
  - [x] `NextNoteStrategy` -> `NextComparisonStrategy`
- [x] Task 5: Update environment key (AC: #1)
  - [x] Rename `@Entry var trainingSession` -> `@Entry var comparisonSession` in environment extension
  - [x] Update all `@Environment(\.trainingSession)` -> `@Environment(\.comparisonSession)` usages
  - [x] Update `@State private var trainingSession` -> `@State private var comparisonSession` in PeachApp.swift
- [x] Task 6: Update Xcode project file (AC: #4)
  - [x] Removed `Training/.gitkeep` from `PBXFileSystemSynchronizedBuildFileExceptionSet` in `project.pbxproj`
- [x] Task 7: Update documentation (AC: #8)
  - [x] Update all old name references in `docs/project-context.md`
- [x] Task 8: Verify (AC: #9)
  - [x] Run full test suite: `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [x] All tests pass with zero functional changes

## Dev Notes

### Pure Refactoring Scope

This is a mechanical rename operation with NO functional changes. The purpose is to disambiguate "Training" (which will mean multiple modes in v0.2) from "Comparison" (the specific higher/lower training mode from v0.1).

### Rename Map

| Old Name | New Name | Scope |
|----------|----------|-------|
| `TrainingSession` | `ComparisonSession` | class, file, env key, all refs |
| `TrainingState` | `ComparisonSessionState` | enum, all refs |
| `TrainingScreen` | `ComparisonScreen` | struct, file, all refs |
| `FeedbackIndicator` | `ComparisonFeedbackIndicator` | struct, file, all refs |
| `NextNoteStrategy` | `NextComparisonStrategy` | protocol, file, all refs |
| `Training/` | `Comparison/` | source dir, test dir |

### Names That MUST NOT Change

`TrainingDataStore`, `TrainingSettings`, `ComparisonObserver`, `Comparison`, `CompletedComparison`, `PerceptualProfile`, `NotePlayer`, `HapticFeedbackManager` -- these are not ambiguous or are already comparison-specific.

### Critical Anti-Pattern: Do NOT Use Partial String Replace

When replacing `TrainingSession`, ensure you do NOT accidentally transform:
- `TrainingDataStore` -> ~~`ComparisonDataStore`~~ (WRONG)
- `TrainingSettings` -> ~~`ComparisonSettings`~~ (WRONG)
- `TrainingTestHelpers` -> this file can keep its name or be renamed to `ComparisonTestHelpers`; either is acceptable

**Safe approach:** Replace whole-word occurrences. When replacing `TrainingSession`, match `TrainingSession` as a complete token, not as a substring of other identifiers.

### Method Name: Already Correct

The protocol method is already `nextComparison(profile:settings:lastComparison:)`. No method rename needed -- only the protocol name changes from `NextNoteStrategy` to `NextComparisonStrategy`.

### Recommended Execution Order

1. **Directories first** -- `git mv` the `Training/` directories to `Comparison/`
2. **Files second** -- `git mv` individual files within the new directories
3. **Type names third** -- find-and-replace in all `.swift` files
4. **Environment key fourth** -- rename `trainingSession` -> `comparisonSession` in environment extension and all usages
5. **Xcode project fifth** -- update `.pbxproj` exception list
6. **Documentation last** -- update `docs/project-context.md`
7. **Build and test** -- full suite must pass

### Source Files Affected (12 files)

**Files to rename AND update contents:**
- `Peach/Comparison/ComparisonSession.swift` (was TrainingSession.swift) -- class def, enum def, logger, comments
- `Peach/Comparison/ComparisonScreen.swift` (was TrainingScreen.swift) -- struct def, @Entry env key, logger, preview
- `Peach/Comparison/ComparisonFeedbackIndicator.swift` (was FeedbackIndicator.swift) -- struct def, previews, comments
- `Peach/Core/Algorithm/NextComparisonStrategy.swift` (was NextNoteStrategy.swift) -- protocol def, comments

**Files to update contents only (no rename):**
- `Peach/App/PeachApp.swift` -- `@State private var trainingSession: TrainingSession` -> `comparisonSession: ComparisonSession`; constructor; environment injection
- `Peach/Start/StartScreen.swift` -- `TrainingScreen()` -> `ComparisonScreen()`
- `Peach/Comparison/ComparisonObserver.swift` -- comment referencing TrainingSession
- `Peach/Core/Data/ComparisonRecordStoring.swift` -- comment referencing TrainingSession
- `Peach/Core/Algorithm/KazezNoteStrategy.swift` -- `NextNoteStrategy` conformance -> `NextComparisonStrategy`; comments
- `Peach/Core/Algorithm/AdaptiveNoteStrategy.swift` -- `NextNoteStrategy` conformance -> `NextComparisonStrategy`; comments
- `Peach/Core/Audio/FrequencyCalculation.swift` -- comment referencing TrainingSession
- `Peach/Comparison/Comparison.swift` -- if it references NextNoteStrategy

### Test Files Affected (18 files in PeachTests/Comparison/)

**Files to rename AND update contents (13):**
- `ComparisonSessionTests.swift` (was TrainingSessionTests.swift)
- `ComparisonSessionLifecycleTests.swift` (was TrainingSessionLifecycleTests.swift)
- `ComparisonSessionIntegrationTests.swift` (was TrainingSessionIntegrationTests.swift)
- `ComparisonSessionResetTests.swift` (was TrainingSessionResetTests.swift)
- `ComparisonSessionFeedbackTests.swift` (was TrainingSessionFeedbackTests.swift)
- `ComparisonSessionUserDefaultsTests.swift` (was TrainingSessionUserDefaultsTests.swift)
- `ComparisonSessionSettingsTests.swift` (was TrainingSessionSettingsTests.swift)
- `ComparisonSessionDifficultyTests.swift` (was TrainingSessionDifficultyTests.swift)
- `ComparisonSessionLoudnessTests.swift` (was TrainingSessionLoudnessTests.swift)
- `ComparisonSessionAudioInterruptionTests.swift` (was TrainingSessionAudioInterruptionTests.swift)
- `ComparisonScreenLayoutTests.swift` (was TrainingScreenLayoutTests.swift)
- `ComparisonScreenFeedbackTests.swift` (was TrainingScreenFeedbackTests.swift)
- `ComparisonScreenAccessibilityTests.swift` (was TrainingScreenAccessibilityTests.swift)

**Files to update contents only (no file rename, 5):**
- `MockNextNoteStrategy.swift` -- rename conformance to `NextComparisonStrategy`; rename class to `MockNextComparisonStrategy`
- `MockTrainingDataStore.swift` -- comment ref only
- `MockNotePlayer.swift` -- comment ref only
- `TrainingTestHelpers.swift` -- references to TrainingSession, TrainingState, NextNoteStrategy; consider renaming to `ComparisonTestHelpers.swift`
- `DifficultyDisplayViewTests.swift` -- moved with directory, check for any refs

**Test files outside Training/ to update:**
- `PeachTests/Start/StartScreenTests.swift` -- `TrainingSession` refs
- `PeachTests/Core/Algorithm/KazezNoteStrategyTests.swift` -- `NextNoteStrategy` ref
- `PeachTests/Core/Algorithm/AdaptiveNoteStrategyTests.swift` -- `NextNoteStrategy` refs
- `PeachTests/Core/Algorithm/AdaptiveNoteStrategyRegionalTests.swift` -- `NextNoteStrategy` ref

### Xcode Project File

`Peach.xcodeproj/project.pbxproj` uses automatic file discovery (Xcode 16+ `PBXFileSystemSynchronizedBuildFileExceptionSet`). Only one line needs updating:
- Line 45: `Training/.gitkeep` -> `Comparison/.gitkeep`

File renames via `git mv` will be automatically detected by Xcode.

### Previous Story Intelligence (Story 10.5)

- Pattern: `@AppStorage` settings read live on each comparison (not cached)
- Test helper factory: `makeTrainingSession()` returns tuple with mocks -- rename to `makeComparisonSession()`
- Constants as stored properties alongside `velocity`, `feedbackDuration`
- Logger category strings: update `"TrainingSession"` -> `"ComparisonSession"` and `"TrainingScreen"` -> `"ComparisonScreen"`

### Project Structure Notes

- All paths follow the file placement rules in project-context.md
- `Core/Algorithm/NextComparisonStrategy.swift` stays in Core because the protocol is used across features
- `Comparison/ComparisonSession.swift` stays in the feature directory as the feature's state machine
- Mirror structure maintained: `PeachTests/Comparison/` mirrors `Peach/Comparison/`

### References

- [Source: docs/planning-artifacts/epics.md#Epic 11, Story 11.1]
- [Source: docs/project-context.md#Critical Implementation Rules]
- [Source: docs/planning-artifacts/architecture.md#Code Structure]
- [Source: Peach/Training/TrainingSession.swift - class and enum definitions]
- [Source: Peach/Core/Algorithm/NextNoteStrategy.swift - protocol definition]
- [Source: Peach/Training/TrainingScreen.swift - @Entry environment key at line 163]
- [Source: Peach/App/PeachApp.swift - @State trainingSession at line 8]
- [Source: Peach.xcodeproj/project.pbxproj - Training/.gitkeep exception at line 45]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Task 6 (Xcode project): Removed `Training/.gitkeep` from `PBXFileSystemSynchronizedBuildFileExceptionSet` in `project.pbxproj`.
- Task 8 (Verify): First test run had one flaky failure (`audioInterruption_Began_StopsFromPlayingNote2`) — pre-existing timing sensitivity, not related to rename. Subsequent runs pass cleanly.

### Completion Notes List

- Pure mechanical rename, zero functional changes
- Renamed 2 directories, 4 source files, 15 test files (13 session/screen + TrainingTestHelpers + MockNextNoteStrategy)
- Replaced 6 type/variable patterns across all .swift files: `TrainingSession`→`ComparisonSession`, `trainingSession`→`comparisonSession`, `TrainingState`→`ComparisonSessionState`, `TrainingScreen`→`ComparisonScreen`, `FeedbackIndicator`→`ComparisonFeedbackIndicator`, `NextNoteStrategy`→`NextComparisonStrategy`
- Verified `TrainingDataStore`, `TrainingSettings`, and all AC #7 names remain unchanged
- Updated 12 references in `docs/project-context.md`
- Full test suite passes: ** TEST SUCCEEDED **

### Change Log

- 2026-02-25: Renamed all ambiguous Training types/files to Comparison-specific names for v0.2 namespace clarity
- 2026-02-25: Code review fixes — corrected Task 6 narrative (pbxproj was modified, not a no-op), fixed File List (removed false AdaptiveNoteStrategyRegionalTests entry, added 6 missing files), updated test descriptions from "Training Screen" to "Comparison Screen" in StartScreenTests

### File List

**Renamed (directories):**
- `Peach/Training/` → `Peach/Comparison/`
- `PeachTests/Training/` → `PeachTests/Comparison/`

**Renamed (source files):**
- `Peach/Comparison/ComparisonSession.swift` (was TrainingSession.swift)
- `Peach/Comparison/ComparisonScreen.swift` (was TrainingScreen.swift)
- `Peach/Comparison/ComparisonFeedbackIndicator.swift` (was FeedbackIndicator.swift)
- `Peach/Core/Algorithm/NextComparisonStrategy.swift` (was NextNoteStrategy.swift)

**Renamed (test files):**
- `PeachTests/Comparison/ComparisonSessionTests.swift` (was TrainingSessionTests.swift)
- `PeachTests/Comparison/ComparisonSessionLifecycleTests.swift` (was TrainingSessionLifecycleTests.swift)
- `PeachTests/Comparison/ComparisonSessionIntegrationTests.swift` (was TrainingSessionIntegrationTests.swift)
- `PeachTests/Comparison/ComparisonSessionResetTests.swift` (was TrainingSessionResetTests.swift)
- `PeachTests/Comparison/ComparisonSessionFeedbackTests.swift` (was TrainingSessionFeedbackTests.swift)
- `PeachTests/Comparison/ComparisonSessionUserDefaultsTests.swift` (was TrainingSessionUserDefaultsTests.swift)
- `PeachTests/Comparison/ComparisonSessionSettingsTests.swift` (was TrainingSessionSettingsTests.swift)
- `PeachTests/Comparison/ComparisonSessionDifficultyTests.swift` (was TrainingSessionDifficultyTests.swift)
- `PeachTests/Comparison/ComparisonSessionLoudnessTests.swift` (was TrainingSessionLoudnessTests.swift)
- `PeachTests/Comparison/ComparisonSessionAudioInterruptionTests.swift` (was TrainingSessionAudioInterruptionTests.swift)
- `PeachTests/Comparison/ComparisonScreenLayoutTests.swift` (was TrainingScreenLayoutTests.swift)
- `PeachTests/Comparison/ComparisonScreenFeedbackTests.swift` (was TrainingScreenFeedbackTests.swift)
- `PeachTests/Comparison/ComparisonScreenAccessibilityTests.swift` (was TrainingScreenAccessibilityTests.swift)
- `PeachTests/Comparison/ComparisonTestHelpers.swift` (was TrainingTestHelpers.swift)
- `PeachTests/Comparison/MockNextComparisonStrategy.swift` (was MockNextNoteStrategy.swift)

**Moved with directory (no content changes):**
- `Peach/Comparison/.gitkeep`
- `Peach/Comparison/DifficultyDisplayView.swift`
- `Peach/Comparison/HapticFeedbackManager.swift`
- `PeachTests/Comparison/.gitkeep`
- `PeachTests/Comparison/DifficultyDisplayViewTests.swift`

**Modified (contents only — source):**
- `Peach.xcodeproj/project.pbxproj`
- `Peach/App/PeachApp.swift`
- `Peach/App/ContentView.swift`
- `Peach/Start/StartScreen.swift`
- `Peach/Settings/SettingsScreen.swift`
- `Peach/Comparison/ComparisonObserver.swift`
- `Peach/Comparison/Comparison.swift`
- `Peach/Core/Data/ComparisonRecordStoring.swift`
- `Peach/Core/Algorithm/KazezNoteStrategy.swift`
- `Peach/Core/Algorithm/AdaptiveNoteStrategy.swift`
- `Peach/Core/Audio/FrequencyCalculation.swift`

**Modified (contents only — test):**
- `PeachTests/Comparison/MockTrainingDataStore.swift`
- `PeachTests/Comparison/MockNotePlayer.swift`
- `PeachTests/Start/StartScreenTests.swift`
- `PeachTests/Core/Algorithm/KazezNoteStrategyTests.swift`
- `PeachTests/Core/Algorithm/AdaptiveNoteStrategyTests.swift`

**Modified (documentation):**
- `docs/project-context.md`
- `docs/implementation-artifacts/sprint-status.yaml`
- `docs/implementation-artifacts/11-1-rename-training-types-and-files-to-comparison.md`
