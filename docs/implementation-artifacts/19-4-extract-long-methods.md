# Story 19.4: Extract Long Methods

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer maintaining Peach**,
I want the three long methods (`PeachApp.init()`, `ComparisonSession.handleAnswer()`, `ComparisonSession.playNextComparison()`) broken into smaller, named helper methods,
So that each method does one thing, the code is easier to read and navigate, and the former inline comments become self-documenting method names.

## Acceptance Criteria

1. **`PeachApp.init()` extracted** -- The ~70-line init is split into named methods. Each comment-delimited section (create model container, create dependencies, populate profile, create sessions) becomes a method whose name replaces the comment.

2. **`ComparisonSession.handleAnswer()` extracted** -- The ~60-line method is split into helpers: stopping note 2 if playing, tracking session best, transitioning to feedback state with the delayed next-comparison scheduling.

3. **`ComparisonSession.playNextComparison()` extracted** -- The ~70-line method is split into helpers: calculating note 2 amplitude from loudness variation, and playing the comparison note pair (note 1 then note 2 with state checks).

4. **No `REVIEW:` comments remain on extracted methods** -- The three REVIEW comments (`PeachApp.swift:18`, `ComparisonSession.swift:241`, `ComparisonSession.swift:376`) are resolved and removed.

5. **All existing tests pass** -- Full test suite passes with zero regressions. No behavioral changes — pure structural refactoring.

## Tasks / Subtasks

- [x] Task 1: Extract `PeachApp.init()` into named methods (AC: #1, #4)
  - [x] Extract `createModelContainer() -> ModelContainer` (lines ~20-23)
  - [x] Extract `loadPerceptualProfile(from: TrainingDataStore) -> PerceptualProfile` (lines ~35-52, loads comparison and matching records)
  - [x] Extract `createComparisonSession(notePlayer:strategy:profile:dataStore:trendAnalyzer:thresholdTimeline:) -> ComparisonSession` (lines ~65-76)
  - [x] Extract `createPitchMatchingSession(notePlayer:profile:dataStore:) -> PitchMatchingSession` (lines ~78-85)
  - [x] Remove REVIEW comment at line 18
  - [x] Keep error handling `catch` in init (fatal error is appropriate for app startup)

- [x] Task 2: Extract `ComparisonSession.handleAnswer()` (AC: #2, #4)
  - [x] Extract `stopNote2IfPlaying()` — stops current note2 playback if user answers during playback (lines ~254-261)
  - [x] Extract `trackSessionBest(_ completed: CompletedComparison)` — updates sessionBestCentDifference on correct answers (lines ~270-278)
  - [x] Extract `transitionToFeedback(_ completed: CompletedComparison)` — sets feedback state, schedules next comparison after delay (lines ~283-300)
  - [x] Remove REVIEW comment at line 241

- [x] Task 3: Extract `ComparisonSession.playNextComparison()` (AC: #3, #4)
  - [x] Extract `calculateNote2Amplitude(varyLoudness: Double) -> AmplitudeDB` — random loudness offset calculation (lines ~392-397)
  - [x] Extract `playComparisonNotes(comparison:settings:noteDuration:amplitudeDB:) async` — plays note 1, checks state, plays note 2, checks state, transitions to awaitingAnswer (lines ~399-432)
  - [x] Keep audio error handling in `playNextComparison()` (wraps the extracted call)
  - [x] Remove REVIEW comment at line 376

- [x] Task 4: Run full test suite and verify (AC: #5)
  - [x] Run `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [x] All tests pass, zero regressions

## Dev Notes

### Critical Design Decisions

- **Pure structural refactoring** -- No logic changes, no new features, no API changes. Every extracted method is `private`. The observable public API of `ComparisonSession` and `PeachApp` does not change.
- **Extracted methods are `private`** -- None of the helpers need to be called from outside their class. Keep them `private` to maintain encapsulation.
- **`async` propagation** -- `playComparisonNotes(...)` must be `async` since it awaits note playback. `stopNote2IfPlaying()` is synchronous (fires a Task internally). Check existing patterns carefully.
- **Error handling stays in the caller** -- `playNextComparison()` wraps its body in `do/catch` for `AudioError`. The extracted `playComparisonNotes()` throws; the caller catches. Don't duplicate error handling.
- **PeachApp methods may need `throws`** -- `createModelContainer()` and `loadPerceptualProfile()` involve SwiftData operations that can throw. The enclosing `do/catch` in `init()` already handles this.
- **Don't over-extract** -- Only extract where the plan specifies. Don't create tiny one-line methods. The goal is to make the comment-delimited sections into named methods, not to decompose every line.

### Architecture & Integration

**Modified files (2 only):**
- `Peach/App/PeachApp.swift` — extract init sections into methods
- `Peach/Comparison/ComparisonSession.swift` — extract handleAnswer and playNextComparison sections

**No new files.** No test changes. No protocol changes.

### Extraction Map

#### PeachApp.init() → 4 extracted methods

| Current Section (Comment) | Extracted Method | Lines (approx) |
|---------------------------|-----------------|-----------------|
| `// Create model container` | `createModelContainer()` | 20-23 |
| `// Create and populate perceptual profile` | `loadPerceptualProfile(from:)` | 35-52 |
| `// Create training session with observer pattern` | `createComparisonSession(...)` | 65-76 |
| `// Create pitch matching session` | `createPitchMatchingSession(...)` | 78-85 |

Sections that stay inline in init (too small or tightly coupled):
- Create dependencies (SoundFontLibrary, NotePlayer) — only 3-5 lines
- Create trend analyzer / threshold timeline — only 2-3 lines each
- Create strategy — 2 lines

#### ComparisonSession.handleAnswer() → 3 extracted methods

| Current Section | Extracted Method | Lines (approx) |
|----------------|-----------------|-----------------|
| Stop note 2 if playing during answer | `stopNote2IfPlaying()` | 254-261 |
| Track session best on correct answers | `trackSessionBest(_:)` | 270-278 |
| Set feedback state + schedule next | `transitionToFeedback(_:)` | 283-300 |

#### ComparisonSession.playNextComparison() → 2 extracted methods

| Current Section | Extracted Method | Lines (approx) |
|----------------|-----------------|-----------------|
| Calculate note 2 amplitude offset | `calculateNote2Amplitude(varyLoudness:)` | 392-397 |
| Play note pair with state checks | `playComparisonNotes(...)` | 399-432 |

### Existing Code to Reference

- **`PeachApp.swift:17-89`** -- Full init with comment-delimited sections. [Source: Peach/App/PeachApp.swift]
- **`ComparisonSession.swift:240-301`** -- handleAnswer method. [Source: Peach/Comparison/ComparisonSession.swift]
- **`ComparisonSession.swift:375-443`** -- playNextComparison method. [Source: Peach/Comparison/ComparisonSession.swift]

### Testing Approach

- **No new tests** -- Pure refactoring with no behavioral changes
- **No test modifications** -- Extracted methods are all `private`; tests interact via the same public API
- **Run full suite** to confirm zero regressions

### Previous Story Learnings (from 19.3)

- **UserSettings now injected** -- `ComparisonSession` and `PitchMatchingSession` accept `UserSettings` as a dependency (from Story 19.3). The extracted methods in `playNextComparison()` will read settings from `self.userSettings` instead of `UserDefaults.standard`.
- **`PeachApp.init()` creates `AppUserSettings`** -- The extracted `createComparisonSession()` and `createPitchMatchingSession()` methods will accept `userSettings` as a parameter.

### Git Intelligence

Commit message: `Implement story 19.4: Extract long methods`

### Project Structure Notes

- Only 2 files modified
- No new files or directories
- No test changes expected

### References

- [Source: Peach/App/PeachApp.swift:18 -- REVIEW comment]
- [Source: Peach/Comparison/ComparisonSession.swift:241 -- REVIEW comment]
- [Source: Peach/Comparison/ComparisonSession.swift:376 -- REVIEW comment]
- [Source: docs/project-context.md -- Code Quality rules]
- [Source: docs/implementation-artifacts/19-3-usersettings-wrapper-for-userdefaults.md -- Prerequisite story]

## Change Log

- 2026-02-26: Story created by BMAD create-story workflow from Epic 19 code review plan.
- 2026-02-27: Story implemented — extracted 9 methods across 2 files, all 586 tests pass.

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None — clean implementation with no issues.

### Completion Notes List

- Extracted `PeachApp.init()` into 4 private static factory methods: `createModelContainer()`, `loadPerceptualProfile(from:)`, `createComparisonSession(...)`, `createPitchMatchingSession(...)`. Methods are `static` because they're called from a struct initializer before `self` is available.
- Extracted `ComparisonSession.handleAnswer()` into 3 private helpers: `stopNote2IfPlaying()`, `trackSessionBest(_:)`, `transitionToFeedback(_:)`. The `handleAnswer` body is now 12 lines of clear, sequential steps.
- Extracted `ComparisonSession.playNextComparison()` into 2 private helpers: `calculateNote2Amplitude(varyLoudness:)` and `playComparisonNotes(comparison:settings:noteDuration:amplitudeDB:) async throws`. Error handling stays in the caller as specified.
- REVIEW comments were already absent from the codebase (AC #4 pre-satisfied).
- All 586 tests pass with zero regressions.

### File List

- `Peach/App/PeachApp.swift` — extracted init into 4 static factory methods
- `Peach/Comparison/ComparisonSession.swift` — extracted handleAnswer into 3 helpers, playNextComparison into 2 helpers
- `docs/implementation-artifacts/sprint-status.yaml` — status updated
- `docs/implementation-artifacts/19-4-extract-long-methods.md` — story file updated
