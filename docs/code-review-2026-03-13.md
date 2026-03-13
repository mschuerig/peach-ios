# Code Review Fixes — 2026-03-13

Each fix is independent. Run one per context, commit separately.

**Usage:** Tell the agent: `Read docs/code-review-2026-03-13.md and execute fix H1` (or whichever ID).

---

## HIGH — Must Fix

### ✅ H1: Remove force unwraps (8 instances)

Replace `!` with `guard let` + early return or `preconditionFailure` with message.

| File | Line | Expression |
|------|------|-----------|
| `Peach/Core/Audio/TuningSystem.swift` | 46 | `Interval(rawValue: remainder)!` — use `guard let` + `preconditionFailure("Euclidean mod out of range")` |
| `Peach/Core/Profile/ProgressTimeline.swift` | 430 | `calendar.date(byAdding:)!` — `guard let` + `return []` |
| `Peach/PitchComparison/PitchComparisonSession.swift` | 186 | `settings.intervals.randomElement()!` — `guard let` + `return` |
| `Peach/PitchMatching/PitchMatchingSession.swift` | 238 | `settings.intervals.randomElement()!` — `guard let` + `return` |
| `Peach/Profile/ProgressChartView.swift` | 177 | `proxy.plotFrame!` — `guard let plotFrame` |
| `Peach/Profile/ProgressChartView.swift` | 528 | `zoneBuckets.first!` — `guard let first = zoneBuckets.first, let last = zoneBuckets.last` |
| `Peach/Profile/ProgressChartView.swift` | 529 | `zoneBuckets.last!` — same guard |
| `Peach/Profile/ProgressChartView.swift` | 530-531 | `.first!.mean` / `.last!.mean` — same guard |

> **Agent prompt:** Read `docs/project-context.md` and this fix description. Read each listed file at the listed line. Replace every `!` force unwrap with a `guard let` + early return (or `preconditionFailure` with a descriptive message where noted). Do not change any other code. Run `bin/test.sh` — all tests must pass. Commit with message: `Fix force unwraps: replace with guard-let across 5 files`

---

### ✅ H2: Return `Cents` instead of raw `Double` at API boundaries

Three places return raw `Double` for cent values. Change return types to `Cents`, unwrap `.rawValue` only where arithmetic needs it.

1. `Peach/Core/Audio/TuningSystem.swift:12` — `centOffset(for:) -> Double` → `-> Cents`. Also `totalCentOffset` (line 42). Unwrap in `frequency(for:referencePitch:)` for the `pow()` call.
2. `Peach/Core/Audio/SoundFontNotePlayer.swift:215` — `decompose() -> (note: UInt8, cents: Double)` → `cents: Cents`. Update callers in `SoundFontPlaybackHandle` (lines 51, 177) to use `.rawValue`.
3. `Peach/Core/Training/PitchMatchingTrainingSettings.swift:11` — `initialCentOffsetRange: ClosedRange<Double>` → `ClosedRange<Cents>`. Update default (line 23) and all call sites.

> **Agent prompt:** Read `docs/project-context.md` and this fix description. For each of the 3 changes, read the file, change the return type or property type to `Cents` (or `ClosedRange<Cents>`), then grep for all call sites and update them — unwrap to `.rawValue` only where raw arithmetic is needed. Run `bin/test.sh` — all tests must pass. Commit with message: `Use Cents domain type at API boundaries instead of raw Double`

---

### ✅ H3: Move service orchestration out of SettingsScreen

`SettingsScreen` coordinates multiple services directly. Move all coordination into closures defined in `PeachApp.swift`, injected via `@Entry` environment keys.

**What to move:**
- Lines 335-342: `resetAllTrainingData()` calls `dataStoreResetter` then `transferService.refreshExport()` — fold `refreshExport()` into the `dataStoreResetter` closure in `PeachApp.swift`
- Lines 112-117: `.onAppear` calls `transferService.refreshExport()` and inspects error — inject a closure that returns export readiness state
- Lines 141-155: `readFileForImport` + switch on result — inject an import-preparation closure
- Lines 344-355: `completeImport(mode:)` — inject an import-execution closure

**Files:** `Peach/Settings/SettingsScreen.swift`, `Peach/App/PeachApp.swift`, `Peach/App/EnvironmentKeys.swift`

> **Agent prompt:** Read `docs/project-context.md` and this fix description. Read `Peach/Settings/SettingsScreen.swift`, `Peach/App/PeachApp.swift`, and `Peach/App/EnvironmentKeys.swift` fully. The project rule is: "Views must not orchestrate services — if a view needs to coordinate multiple services, wrap that coordination in a closure or method owned by the composition root and inject it." For each of the 4 items listed, move the multi-service coordination into a closure defined in `PeachApp.swift`, add an `@Entry` environment key if needed, and reduce the view to calling one injected closure. Run `bin/test.sh` — all tests must pass. Commit with message: `Move service orchestration from SettingsScreen to composition root`

---

### ✅ H4: Fix incomplete profile reset

`Peach/App/PeachApp.swift:117-121` — the `dataStoreResetter` closure calls `profile.resetMatching()` but never `profile.reset()`. After "Reset All Training Data," comparison profile data stays stale in memory.

**Fix:** Add `profile.reset()` before `profile.resetMatching()` in the closure.

> **Agent prompt:** Read `docs/project-context.md` and this fix description. Read `Peach/App/PeachApp.swift` around line 117. Add `profile.reset()` before `profile.resetMatching()` in the `dataStoreResetter` closure. Run `bin/test.sh` — all tests must pass. Commit with message: `Fix incomplete profile reset: also reset comparison data on full reset`

---

### ✅ H5: Make data replacement atomic in TrainingDataImporter

`Peach/Core/Data/TrainingDataImporter.swift:40-49` — `replaceAll()` calls `deleteAll()` then saves records one-by-one. If any save fails after delete, all data is lost.

**Fix:** Add a batch-save method to `TrainingDataStore` that inserts all records and calls `modelContext.save()` once. Use it in `replaceAll()` so delete + insert is effectively atomic. Alternatively, wrap the whole operation in a transaction.

**Files:** `Peach/Core/Data/TrainingDataImporter.swift`, `Peach/Core/Data/TrainingDataStore.swift`

> **Agent prompt:** Read `docs/project-context.md` and this fix description. Read `Peach/Core/Data/TrainingDataImporter.swift` and `Peach/Core/Data/TrainingDataStore.swift` fully. Add a batch-save method to `TrainingDataStore` that inserts multiple records and calls `modelContext.save()` once at the end. Update `replaceAll()` in `TrainingDataImporter` to use it, so the delete + bulk insert is effectively one operation. Write tests for the new batch-save method. Run `bin/test.sh` — all tests must pass. Commit with message: `Make import replace-mode atomic to prevent data loss on partial failure`

---

### ✅ H6: Add missing `async` to ~75 @Test functions

Project rule: every `@Test` function must be `async`. Mechanical fix — add `async` to each signature.

| File | Count |
|------|-------|
| `PeachTests/Core/Algorithm/KazezNoteStrategyTests.swift` | 27 |
| `PeachTests/Start/StartScreenTests.swift` | 19 |
| `PeachTests/Settings/SettingsTests.swift` | 12 |
| `PeachTests/PitchComparison/PitchComparisonScreenLayoutTests.swift` | 8 |
| `PeachTests/Core/Training/PitchComparisonTests.swift` | 5 |
| `PeachTests/PitchComparison/PitchComparisonSessionDifficultyTests.swift` | 2 |
| `PeachTests/PitchComparison/PitchComparisonSessionLifecycleTests.swift` | 1 |
| `PeachTests/Core/Data/TrainingDataStoreEdgeCaseTests.swift` | 1 |

> **Agent prompt:** Read `docs/project-context.md` and this fix description. For each file listed, read it and find every `@Test` function that is NOT `async`. Add `async` to its signature: `func foo()` → `func foo() async`, `func foo() throws` → `func foo() async throws`. Do not change anything else. Run `bin/test.sh` — all tests must pass. Commit with message: `Add missing async to ~75 @Test functions per project rules`

---

### ✅ H7: Remove sleep/fixed delays in AudioSessionInterruptionMonitorTests

`PeachTests/Core/Audio/AudioSessionInterruptionMonitorTests.swift` — all 10 tests use `try await Task.sleep(for: .milliseconds(50))`. Notifications deliver synchronously, so the sleep is unnecessary.

**Fix:** Replace `try await Task.sleep(for: .milliseconds(50))` + `await Task.yield()` with just `await Task.yield()` in all 10 tests.

> **Agent prompt:** Read `docs/project-context.md` and this fix description. Read `PeachTests/Core/Audio/AudioSessionInterruptionMonitorTests.swift`. In every test, remove the `try await Task.sleep(for: .milliseconds(50))` line and keep only `await Task.yield()`. If removing the sleep also removes the only `try`, update the function signature from `async throws` to `async`. Run `bin/test.sh` — all tests must pass. Commit with message: `Remove unnecessary sleep delays from AudioSessionInterruptionMonitorTests`

---

### ✅ H8: Stop `@Model` types leaking through non-storage interfaces

`Peach/Core/Data/TrainingDataTransferService.swift:7` — callback `onDataChanged: ([PitchComparisonRecord], [PitchMatchingRecord]) -> Void` exposes SwiftData `@Model` classes to consumers. Also `PitchComparisonRecordStoring` protocol (lines 11-12) binds to `@Model` type.

**Fix:** Have `onDataChanged` signal a simple `Void` callback (or count), and have consumers re-fetch through `TrainingDataStore`. Or define lightweight domain value types for the callback.

This is the most architecturally involved fix — read both files and their consumers carefully before changing.

> **Agent prompt:** Read `docs/project-context.md` and this fix description. Read `Peach/Core/Data/TrainingDataTransferService.swift` and `Peach/Core/Data/PitchComparisonRecordStoring.swift` fully. Grep for all consumers of `onDataChanged` and `PitchComparisonRecordStoring`. Design the minimal change to stop `@Model` types from appearing in these interfaces — prefer simplifying `onDataChanged` to a `() -> Void` signal so consumers re-fetch through `TrainingDataStore`. Update all affected files. Run `bin/test.sh` — all tests must pass. Commit with message: `Encapsulate @Model types behind TrainingDataStore boundary`

---

## LOW — Consider Improving

### ✅ L1: Tighten access control (3 spots — 3 of 3 done)

- ✅ `Peach/Core/Audio/SoundFontLibrary.swift:8` — `availablePresets` → `private(set)` (not fully `private` — tests read it)
- ✅ `Peach/Core/Profile/PerceptualProfile.swift:152-174` — `PerceptualNote` properties → `private(set)` (done in `4191edf`)
- ✅ `Peach/PitchMatching/PitchMatchingSession.swift:53` — `referenceFrequency` already `private(set)` (not fully `private` — tests read it)

> **Agent prompt:** Read `docs/project-context.md` and this fix description. For each listed property, read the file, grep to confirm no cross-file usage, then tighten access as specified. Run `bin/test.sh` — all tests must pass. Commit with message: `Tighten access control on internal-only properties`

---

### ✅ L2: Use `Duration` instead of `TimeInterval` for constants

`Peach/Core/Profile/ProgressTimeline.swift:129-138` — change `recentThreshold`, `weekThreshold`, `monthThreshold`, `secondsPerDay` from `TimeInterval` to `Duration`. Convert to `TimeInterval` at point of use.

> **Agent prompt:** Read `docs/project-context.md` and this fix description. Read `Peach/Core/Profile/ProgressTimeline.swift`. Change the 4 listed constants from `TimeInterval` to `Duration`. Grep for each usage and convert to `TimeInterval` at the arithmetic site (e.g., via a `.timeIntervalSeconds` extension or `.components`). Run `bin/test.sh` — all tests must pass. Commit with message: `Use Swift Duration for ProgressTimeline time constants`

---

### ✅ L3: Replace deprecated toolbar placements

- `Peach/Settings/SettingsScreen.swift:85` — `.navigationBarTrailing` → `.topBarTrailing`
- `Peach/Start/StartScreen.swift:50,58` — `.navigationBarLeading`/`.navigationBarTrailing` → `.topBarLeading`/`.topBarTrailing`

> **Agent prompt:** Read `docs/project-context.md` and this fix description. In each listed file at the listed lines, replace `.navigationBarTrailing` with `.topBarTrailing` and `.navigationBarLeading` with `.topBarLeading`. Run `bin/test.sh` — all tests must pass. Commit with message: `Replace deprecated navigationBar toolbar placements with topBar`

---

### ✅ L4: Replace `DateFormatter` with `Date.FormatStyle`

- `Peach/Settings/CSVDocument.swift:28`
- `Peach/Core/Profile/GranularityZoneConfig.swift:24-28,39-43,54-58`
- `Peach/Profile/ProgressChartView.swift:447-463`

> **Agent prompt:** Read `docs/project-context.md` and this fix description. Read each listed file. Replace `DateFormatter` usage with the modern `Date.FormatStyle` / `.formatted()` API. Remove the static `DateFormatter` properties. Ensure locale behavior is preserved. Run `bin/test.sh` — all tests must pass. Commit with message: `Modernize DateFormatter usage to Date.FormatStyle`

---

### L5: DRY — deduplicate SF2 tag parsing

`Peach/Core/Audio/SoundFontNotePlayer.swift:196-204` and `Peach/Core/Audio/SoundFontLibrary.swift:34-41` both parse `"sf2:bank:program"`. Move to `SoundSourceID` as a computed property.

> **Agent prompt:** Read `docs/project-context.md` and this fix description. Read both files and `Peach/Core/Audio/SoundSourceID.swift`. Add a computed property to `SoundSourceID` (e.g., `var sf2Components: (bank: Int, program: Int)?`) that parses the `"sf2:bank:program"` format. Update both call sites to use it. Run `bin/test.sh` — all tests must pass. Commit with message: `Extract shared SF2 tag parsing into SoundSourceID`

---

### L6: DRY — extract bucket aggregation helper

`Peach/Core/Profile/ProgressTimeline.swift:400-417,469-486,535-552` — identical mean/stddev/TimeBucket construction triplicated. Extract `private func makeBucket(...)`.

> **Agent prompt:** Read `docs/project-context.md` and this fix description. Read `Peach/Core/Profile/ProgressTimeline.swift` at the three listed ranges. Extract the common mean/stddev/TimeBucket construction into a single `private` helper method. Replace all three copies with calls to the helper. Run `bin/test.sh` — all tests must pass. Commit with message: `Extract duplicated bucket aggregation into helper method`

---

### L7: Extract large view bodies into subviews

- `Peach/Settings/SettingsScreen.swift` body ~108 lines
- `Peach/PitchComparison/PitchComparisonScreen.swift` body ~110 lines
- `Peach/PitchMatching/PitchMatchingScreen.swift` body ~100 lines

> **Agent prompt:** Read `docs/project-context.md` and this fix description. Read each listed file. Extract toolbar content, sheet/alert modifier chains, and stats headers into private `@ViewBuilder` methods or subviews so that each `body` is under ~40 lines. Keep extractions in the same file. Run `bin/test.sh` — all tests must pass. Commit with message: `Extract subviews from oversized view bodies`

---

### L8: Add missing mock contract elements

7 mocks missing callback hooks, error injection, or `reset()`:

| Mock | Missing |
|------|---------|
| `PeachTests/Mocks/MockUserSettings.swift` | `reset()`, callback hooks |
| `PeachTests/PitchComparison/MockNextPitchComparisonStrategy.swift` | callback hooks |
| `PeachTests/PitchComparison/MockHapticFeedbackManager.swift` | error injection |
| `PeachTests/PitchComparison/MockTrainingDataStore.swift` | callback hooks |
| `PeachTests/Profile/MockPitchComparisonProfile.swift` | callback hooks, error injection |
| `PeachTests/PitchMatching/MockPitchMatchingObserver.swift` | callback hooks |
| `PeachTests/PitchMatching/MockPitchMatchingProfile.swift` | callback hooks |

> **Agent prompt:** Read `docs/project-context.md` (mock contract rules, lines 128-135) and this fix description. Read `PeachTests/PitchComparison/MockNotePlayer.swift` as the reference implementation for full contract compliance. For each listed mock, read it and add the missing elements following the same patterns. Run `bin/test.sh` — all tests must pass. Commit with message: `Complete mock contract compliance across test mocks`

---

### L9: Rename `PianoKeyboardView.swift` → `PianoKeyboardLayout.swift`

File contains `struct PianoKeyboardLayout`, not a View.

> **Agent prompt:** Read `docs/project-context.md` and this fix description. Use `git mv Peach/Profile/PianoKeyboardView.swift Peach/Profile/PianoKeyboardLayout.swift`. Grep for any imports or references to the old filename. Run `bin/test.sh` — all tests must pass. Commit with message: `Rename PianoKeyboardView.swift to match its contents`

---

### L10: Remove unused `@State previousScenePhase`

`Peach/App/ContentView.swift:14` — written but never read.

> **Agent prompt:** Read `docs/project-context.md` and this fix description. Read `Peach/App/ContentView.swift`. Remove the `@State private var previousScenePhase` property and the line that writes to it. Run `bin/test.sh` — all tests must pass. Commit with message: `Remove unused previousScenePhase state property`

---

### L11: Remove `throws` from `Resettable.reset()` if no conformer throws

`Peach/Core/Training/Resettable.swift:3` — audit all conformers first.

> **Agent prompt:** Read `docs/project-context.md` and this fix description. Grep for all types conforming to `Resettable`. Check if any conformer's `reset()` method actually throws. If none do, remove `throws` from the protocol declaration and update all call sites that use `try` with `Resettable.reset()`. Run `bin/test.sh` — all tests must pass. Commit with message: `Remove unnecessary throws from Resettable.reset()`

---

### L12: Fix cross-feature reference in ProgressSparklineView

`Peach/Start/ProgressSparklineView.swift:54` references `TrainingStatsView.formattedCents()` from `App/`. Move `formattedCents` to an extension on `Cents` in `Core/`.

> **Agent prompt:** Read `docs/project-context.md` and this fix description. Read `Peach/App/TrainingStatsView.swift` to find `formattedCents`. Move that method to an extension on `Cents` in `Peach/Core/Audio/Cents.swift`. Update all call sites (grep for `formattedCents`). Run `bin/test.sh` — all tests must pass. Commit with message: `Move formattedCents to Cents extension to fix cross-feature coupling`

---

### L13: Centralize Duration→TimeInterval conversion

`Peach/App/PeachApp.swift:106` uses manual attosecond arithmetic. Create a small `Duration` extension producing `TimeInterval`.

> **Agent prompt:** Read `docs/project-context.md` and this fix description. Read `Peach/App/PeachApp.swift` around line 106. Create a `Duration` extension (in the same file or a sensible Core/ location) with a `var timeInterval: TimeInterval` computed property. Replace the manual arithmetic. Grep for any other manual Duration→TimeInterval conversions. Run `bin/test.sh` — all tests must pass. Commit with message: `Add Duration.timeInterval extension to replace manual conversion`

---

### ✅ L14: Fix flaky PitchComparisonSessionLifecycleTests

*(moved — see below)*

---

### L15: Review PerceptualProfile training-mode asymmetries

`PerceptualProfile` grew unevenly as pitch matching was added alongside pitch comparison. A thorough review is needed to decide which asymmetries are intentional design choices and which are gaps to close.

**Known asymmetries:**

| Dimension | Pitch Comparison | Pitch Matching |
|-----------|-----------------|----------------|
| Data granularity | Per-note (128-slot array) | Global aggregate only (3 scalars) |
| Stats naming | `overallMean` / `overallStdDev` | `matchingMean` / `matchingStdDev` |
| Weak spot detection | `weakSpots(count:)` | None |
| Difficulty tracking | `setDifficulty(note:difficulty:)` | None |
| Correctness metric | `isCorrect` flag tracked | Not tracked |
| Range filtering | `averageThreshold(noteRange:)` | None |
| Reset | `reset()` clears comparison only | `resetMatching()` clears matching only |
| Full reset | Requires **two** calls: `reset()` + `resetMatching()` — no single method |
| Test coverage | ~300 lines, extensive edge cases | ~80 lines, 8 tests |

**Reset coordination risk:** Every call site that resets "all" profile data must remember to call both methods. Currently `PeachApp.swift` (dataStoreResetter, onDataChanged) does this correctly, but there is no compile-time guard.

**Possible actions (decide per item):**

1. **Rename `reset()` → `resetComparison()`** and add a `resetAll()` that calls both — eliminates the misleading bare `reset()` name
2. **Add `rebuild(from:)` method** that atomically replaces all state from persisted records (mirrors `ProgressTimeline.rebuild()`)
3. **Add per-note matching stats** if future UX needs them (defer if not needed now)
4. **Align stats naming** — e.g., `comparisonMean`/`matchingMean` instead of `overallMean`/`matchingMean`
5. **Expand matching test coverage** to match comparison depth

**Files:** `Peach/Core/Profile/PerceptualProfile.swift`, `Peach/Core/Profile/PitchComparisonProfile.swift`, `Peach/Core/Profile/PitchMatchingProfile.swift`, `Peach/App/PeachApp.swift`

> **Agent prompt:** Read `docs/project-context.md` and this fix description. Read `Peach/Core/Profile/PerceptualProfile.swift`, `PitchComparisonProfile.swift`, and `PitchMatchingProfile.swift` fully. Read `Peach/App/PeachApp.swift` for reset coordination. For each of the 5 possible actions listed, discuss with the user whether to proceed — these are design decisions, not mechanical fixes. Implement only what is agreed upon. Run `bin/test.sh` — all tests must pass.

---

### ✅ L14: Fix flaky PitchComparisonSessionLifecycleTests

3 tests in `PeachTests/PitchComparison/PitchComparisonSessionLifecycleTests.swift` fail intermittently: `stopCallsStopAll`, `stopTransitionsToIdleAndCancelsTraining`, `simulatedOnDisappearTriggersStop`.

**Root cause:** `start()` spawns an internal `Task` that calls `play()`. These tests call `waitForPlayCallCount(f.mockPlayer, 1)` which polls with a timeout. Under load the spawned task may not reach `play()` before the timeout expires.

**Fix:** Replace the polling-based `waitForPlayCallCount` with a continuation-based approach — have the mock signal an `AsyncStream` or resume a `CheckedContinuation` from its `onPlayCalled` callback, and have the test `await` that signal directly. This eliminates the race entirely.

**Files:** `PeachTests/PitchComparison/PitchComparisonSessionLifecycleTests.swift`, test helpers (`waitForPlayCallCount`)

> **Agent prompt:** Read `docs/project-context.md` and this fix description. Read `PeachTests/PitchComparison/PitchComparisonSessionLifecycleTests.swift` fully. Find the `waitForPlayCallCount` helper and all tests that use it. Replace the polling-based wait with a continuation-based synchronization: add an `async` method to the mock (e.g., `waitForPlay()`) that uses `CheckedContinuation` or `AsyncStream`, signalled from `onPlayCalled`. Update the 3 flaky tests to `await` the signal instead of polling. Ensure no test uses `Task.sleep` for synchronization. Run `bin/test.sh` — all tests must pass. Commit with message: `Fix flaky lifecycle tests: replace polling with continuation-based sync`

---

### ✅ L16: Fix flaky PitchComparisonSessionTests (same root cause as L14)

2 tests in `PeachTests/PitchComparison/PitchComparisonSessionTests.swift` fail intermittently: `transitionsFromNote1ToNote2`, `stopTransitionsToIdle`.

---

### ✅ L17: Fix flaky PitchComparisonSessionResetTests

`PeachTests/PitchComparison/PitchComparisonSessionResetTests.swift` — `resetTrainingDataStopsActiveTraining()` fails intermittently (observed during L2 fix run). Likely same polling-based root cause as L14/L16.

**Root cause:** Same as L14 — these tests use `waitForPlayCallCount(f.mockPlayer, ...)` which polls with a timeout. Under load the spawned task may not reach `play()` before the timeout expires.

**Note:** L14 is already done, but its fix only covered `PitchComparisonSessionLifecycleTests`. These two tests in `PitchComparisonSessionTests` still use the old polling helper.

**Fix:** Apply the same continuation-based approach from L14 to these 2 tests.

**Files:** `PeachTests/PitchComparison/PitchComparisonSessionTests.swift`

> **Agent prompt:** Read `docs/project-context.md` and this fix description. Read `PeachTests/PitchComparison/PitchComparisonSessionLifecycleTests.swift` to see the continuation-based pattern applied in L14. Read `PeachTests/PitchComparison/PitchComparisonSessionTests.swift` and apply the same pattern to `transitionsFromNote1ToNote2` and `stopTransitionsToIdle`, replacing `waitForPlayCallCount` with the continuation-based sync. Run `bin/test.sh` — all tests must pass. Commit with message: `Fix flaky PitchComparisonSessionTests: use continuation-based sync`
