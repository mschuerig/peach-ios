# Future Work & Technical Considerations

This document tracks design decisions to revisit, architectural improvements, and technical debt items discovered during development.

## Algorithm & Design

### ~~Investigate Signed Mean in Perceptual Profile~~ (RESOLVED)

**Status:** Resolved — 2026-02-22
**Resolution:** Implemented via `hotfix-investigate-signed-mean.md`. Replaced signed centOffset with unsigned `centDifference` in `comparisonCompleted()` and profile loading (`abs()` on stored records). Removed `abs()` wrappers from `weakSpots()`, `averageThreshold()`, `computeStats()`, and `ConfidenceBandData.prepare()`. Mean now always represents the unsigned detection threshold. Directional bias tracking deferred as a separate future enhancement if needed.

### Investigate Whether Seamless Playback Makes Pitch Comparison Easier

**Priority:** Medium
**Category:** Algorithm Design / Calibration
**Date Added:** 2026-02-17

**Observation:**
After implementing chain-based Kazez convergence, the algorithm quickly converges to sub-2-cent differences. However, the user consistently achieves much finer discrimination in Peach than in InTune (a reference app), where they typically plateau around 5 cents and only occasionally reach below 3 cents.

**Hypothesis:**
Peach plays the two comparison tones seamlessly (back-to-back without a gap), which may make pitch differences perceptually easier to detect than when tones are separated by silence. This could mean the difficulty levels in Peach are not directly comparable to those in apps that use gaps between tones.

**Impact:**
- Peach's difficulty numbers may overstate the user's actual pitch discrimination ability
- Comparison with other ear training apps may be misleading
- The training may be less effective if the task is artificially easier

**Investigation Areas:**
- Compare perceptual difficulty of seamless vs. gap-separated tone pairs at the same cent difference
- Research psychoacoustic literature on the effect of inter-stimulus intervals on pitch discrimination
- Consider adding a configurable gap between tones as an advanced setting
- Evaluate whether the current approach is still valuable for training (even if "easier")

**Related Code:**
- `Peach/Core/Audio/SineWaveNotePlayer.swift` — tone generation and playback
- `Peach/Training/TrainingSession.swift` — playback sequencing

### ~~AdaptiveNoteStrategy: Slow Difficulty Convergence~~ (RESOLVED)

**Status:** Resolved — 2026-02-15
**Resolution:** Kazez sqrt(P) formulas integrated into `AdaptiveNoteStrategy` via `hotfix-integrate-kazez-into-adaptive-strategy.md`. Fixed factors replaced with `N = P × [1 - 0.05 × √P]` (correct) and `N = P × [1 + 0.09 × √P]` (incorrect).

### ~~Weighted Effective Difficulty: Convergence Still Too Slow~~ (RESOLVED)

**Status:** Resolved — 2026-02-17
**Resolution:** Implemented via `hotfix-tune-kazez-convergence.md`:
1. Kazez correct-answer coefficient increased from 0.05 to 0.08 — single correct from 100 cents now gives 20.0 (was 50.0)
2. Neighbor filtering: only Kazez-refined notes (`currentDifficulty != defaultDifficulty`) contribute to bootstrapping, preventing 100-cent anchoring

---

## Technical Debt

### ~~Audio Clicks When Navigating Away During Playback~~ (RESOLVED)

**Status:** Resolved — 2026-02-22
**Resolution:** `SineWaveNotePlayer.stop()` now sets `playerNode.volume = 0`, waits 25ms (covering 2+ render cycles at 44.1kHz) for the audio render thread to propagate the silence, then calls `playerNode.stop()` and restores volume. This eliminates the waveform discontinuity that caused audible clicks.

### ~~Reset All Data Should Also Reset Difficulty~~ (RESOLVED)

**Status:** Resolved — 2026-02-22
**Resolution:** Implemented via `reset-all-data.md`. `SettingsScreen.resetAllTrainingData()` now calls `trainingSession.resetTrainingData()`, which clears `lastCompletedComparison` (Kazez convergence chain), `sessionBestCentDifference`, and resets both the `PerceptualProfile` (including per-note `currentDifficulty`) and `TrendAnalyzer`.

### Extract Environment Keys to Shared Locations

**Priority:** Low
**Category:** Code Organization
**Date Added:** 2026-02-17
**Source:** Story 6.1 code review (finding L1)

**Issue:**
`PerceptualProfileKey` and its `EnvironmentValues` extension are defined in `Peach/Profile/ProfileScreen.swift` (lines 131-149), but `@Environment(\.perceptualProfile)` is used across multiple features: Settings, Start, and Profile. This couples unrelated feature modules to a specific View file for infrastructure plumbing.

**Impact:**
- `SettingsScreen` implicitly depends on `ProfileScreen.swift` for the environment key definition
- `ProfilePreviewView` (Start feature) has the same hidden dependency
- If `ProfileScreen.swift` were ever moved or split, the environment key would need to be relocated

**Proposed Fix:**
Move environment key definitions next to their corresponding types:
- `PerceptualProfileKey` → `Peach/Core/Profile/PerceptualProfile.swift` (alongside the class, matching the `TrendAnalyzerKey` pattern in `TrendAnalyzer.swift`)

**Related Code:**
- `Peach/Profile/ProfileScreen.swift:131-149` — current location of `PerceptualProfileKey`
- `Peach/Core/Profile/TrendAnalyzer.swift:92-108` — reference pattern (key defined alongside type)
- `Peach/Settings/SettingsScreen.swift:24` — consumer of `\.perceptualProfile`
- `Peach/Start/ProfilePreviewView.swift:7` — consumer of `\.perceptualProfile`

### Consider Rolling Window for Profile Data

**Priority:** Medium
**Category:** Algorithm Design
**Date Added:** 2026-02-18

**Issue:**
The `PerceptualProfile` currently accumulates all historical `ComparisonRecord`s with equal weight using Welford's online algorithm. As a user improves over weeks/months, old data from when they were less skilled continues to drag the profile statistics. The profile may not reflect the user's *current* ability.

**Potential Approaches:**
- Only consider the last N comparisons per note (e.g., N=20 or N=100) when computing mean and stdDev
- Use exponential decay weighting so recent results count more
- The algorithm (`AdaptiveNoteStrategy`) should also respect this window — difficulty should reflect current ability, not lifetime average

**Impact:**
- Profile statistics would more accurately represent current skill level
- Weak spot identification would be more responsive to recent training
- Would require changes to `PerceptualProfile` (currently uses incremental Welford's, which doesn't support windowing without storing raw values)
- May need to store recent comparisons per note or switch to a different statistical approach

**Related Code:**
- `Peach/Core/Profile/PerceptualProfile.swift` — Welford's algorithm, `weakSpots()`
- `Peach/Core/Algorithm/AdaptiveNoteStrategy.swift` — uses profile for difficulty selection
- `Peach/Core/Data/ComparisonRecord.swift` — stored records

### Convergence Chain State Not Persisted Across App Restarts

**Priority:** Low
**Category:** State Management
**Date Added:** 2026-02-18

**Issue:**
The Kazez convergence chain (the current difficulty level / last cent offset) is not persisted. When the app restarts, `TrainingSession` has no `lastComparison`, so the difficulty resets. The `PerceptualProfile` rebuilds from stored `ComparisonRecord`s and bootstraps via neighbor-weighted difficulty, but the actual position in the convergence chain is lost.

**Assessment (2026-02-24):** The Kazez algorithm converges quickly (a few comparisons), so the practical impact is minimal. The bootstrapped difficulty from the profile is close enough that users won't notice a significant disruption. Deprioritized from Medium to Low.

**Related Code:**
- `Peach/Training/TrainingSession.swift` — `lastComparison` property
- `Peach/Core/Algorithm/KazezNoteStrategy.swift` — `nextComparison()` cold start path
- `Peach/Core/Profile/PerceptualProfile.swift` — neighbor-weighted bootstrapping

---

## UX & Onboarding

### No First-Run Onboarding Experience

**Priority:** High
**Category:** User Experience
**Date Added:** 2026-02-18

**Issue:**
There is no guided onboarding for new users. A musician downloading Peach sees the Start Screen with an empty profile preview and can tap "Start Training" — but nothing explains what will happen, what the controls mean, or what "cents" are in the context of pitch discrimination.

**Impact:**
- Musicians may not understand the task format (two sequential tones, tap Higher/Lower)
- The concept of "cents" as a unit of pitch difference is unfamiliar to many musicians who think in terms of "sharp/flat" or "in tune/out of tune"
- The profile visualization (confidence band, log scale) is meaningless without context
- Risk of immediate abandonment if the first experience feels confusing

**Potential Solutions:**
- A brief first-run walkthrough (2-3 screens) explaining the training concept
- Contextual tooltips on first use of each screen
- Musician-friendly language throughout ("pitch accuracy" instead of "cent threshold")
- An introductory training round with wider intervals and explanatory overlays

### ~~Redesign Profile Graph for Interpretability~~ (RESOLVED)

**Status:** Resolved — 2026-02-24
**Resolution:** Implemented via story 9.2 (`9-2-rethink-profile-display-and-progress-tracking.md`). The old confidence band chart (piano keyboard + AreaMark with log-scale Y-axis) was replaced with `ThresholdTimelineView` — a scrollable line chart showing rolling mean threshold over time with standard deviation band — and `SummaryStatisticsView` with plain-language statistics. Includes tap-to-inspect per time period (date, mean threshold, correct/total count).

### Tap-to-Inspect Note Detail on Profile Graph

**Priority:** Medium
**Category:** User Experience
**Date Added:** 2026-02-18

**Partial Resolution (2026-02-24):** Story 9.2 added tap-to-inspect per time period in `ThresholdTimelineView` (shows date, mean threshold, correct/total count). However, the original request for per-individual-note statistics remains unaddressed — there is no way to tap a specific note and see its mean, stdDev, count, and trend.

**Remaining Work:**
- Per-note detail view or popover showing individual note statistics
- Per-note `NoteProfile` data (mean, stdDev, count) from `PerceptualProfile` is available but not surfaced in the UI

**Related Code:**
- `Peach/Profile/ThresholdTimelineView.swift` — current tap-to-inspect (per period)
- `Peach/Core/Profile/PerceptualProfile.swift` — per-note `NoteProfile` data

### ~~Show Progress Over Time~~ (RESOLVED)

**Status:** Resolved — 2026-02-24
**Resolution:** Implemented via story 9.2 (`9-2-rethink-profile-display-and-progress-tracking.md`). `ThresholdTimelineView` shows a scrollable line chart of rolling mean threshold over time with standard deviation band, directly answering "Am I getting better?" The Profile Screen now centers on temporal progression rather than static per-note statistics.

### ~~No Sense of Session or Progress Acknowledgment~~ (RESOLVED)

**Status:** Resolved — 2026-02-24
**Resolution:** Implemented via `DifficultyDisplayView` (story `display-current-difficulty-on-training-screen.md`) showing current cent difference and session best during training, plus story 9.2's `ThresholdTimelineView` and `SummaryStatisticsView` on the Profile Screen providing progress context. Users now see live difficulty feedback during training and temporal improvement trends on the Profile Screen.

### ~~Display Current Difficulty on Training Screen~~ (RESOLVED)

**Status:** Resolved — 2026-02-22
**Resolution:** Implemented via `display-current-difficulty-on-training-screen.md`. Added `DifficultyDisplayView` showing current cent difference and session best at top of Training Screen body, with `.footnote`/`.caption2` secondary styling, full accessibility labels, and German translations.

### ~~Feedback Icon Flicker on Correctness Change~~ (RESOLVED)

**Status:** Resolved — 2026-02-22
**Resolution:** Implemented via `fix-feedback-icon-flicker-on-correctness-change.md`. Fixed by ensuring `isLastAnswerCorrect` is always set before `showFeedback` becomes `true`, and `showFeedback` is cleared before the next comparison begins. The animation is now driven solely by `showFeedback` value changes, preventing stale icon content from flashing during transitions.

### Haptic Feedback Unavailable on iPad

**Priority:** Low
**Category:** User Experience / Platform
**Date Added:** 2026-02-18

**Issue:**
Wrong-answer feedback uses `UIImpactFeedbackGenerator` for haptic response. iPads do not have a Taptic Engine, so this feedback channel is completely absent on iPad.

**Impact:**
- iPad users receive only the visual feedback indicator for wrong answers — no tactile reinforcement
- The feedback experience is inconsistent across device types
- May reduce the effectiveness of the training feedback loop on iPad

**Potential Solutions:**
- Add a subtle visual reinforcement (e.g., screen flash, shake animation) as a complement to haptics
- Consider an optional audio feedback cue (short error tone) that works on all devices
- Respect the "Reduce Motion" accessibility setting for any visual alternatives
- Detect haptic capability and adapt feedback strategy accordingly

**Related Code:**
- `Peach/Training/HapticFeedbackManager.swift` — haptic implementation
- `Peach/Training/FeedbackIndicator.swift` — visual feedback

---

## Future Enhancements

### ~~Swappable Sound Sources (Instrument Timbres)~~ (IN PROGRESS)

**Status:** Being addressed by Epic 8 — 2026-02-23
**Stories:** `8-1-implement-soundfont-noteplayer.md` (SoundFontNotePlayer with fixed Cello preset), `8-2-sf2-preset-discovery-and-instrument-selection.md` (dynamic preset discovery and Settings UI for all ~261 GeneralUser GS instruments)

### SF2 Pruning Pipeline (Idea)

**Priority:** None — idea only, may never be implemented
**Category:** Audio / Build Tooling
**Date Added:** 2026-02-23

**Idea:**
The bundled GeneralUser GS SF2 contains 261 melodic presets + 13 drum kits (~30 MB). For an ear training app, most of these presets are unnecessary (e.g., "SFX", "Telephone Ring", "Helicopter"). A pruning pipeline would trim the SF2 to ~15-20 key instruments relevant to pitch training (piano, strings, woodwinds, brass, guitar), reducing bundle size and decluttering the instrument picker.

**Why this may not be needed:**
- 30 MB is small enough that pruning isn't urgent for bundle size
- Story 8-2 already filters drum kits; the full melodic list is browsable in Settings
- Users may enjoy access to unusual timbres for variety
- Pruning requires Polyphone (GUI tool) and a documented runbook — one-time manual effort with no automation path via standard macOS tools

**If pursued:**
- Use [Polyphone](https://www.polyphone.io/) to delete unwanted presets, rename remaining ones for clarity, "Remove unused elements" to strip orphaned samples
- Document steps in `tools/build-sf2.md` runbook
- Output: lean `peach-instruments.sf2` replacing the full GeneralUser GS
- Consider a Phase 2 custom SF2 assembled from lossless sources (Salamander Piano, Iowa MIS, SSO) for higher quality

**Related Research:**
- [Source: docs/planning-artifacts/research/technical-sampled-instrument-noteplayer-research-2026-02-23.md#sf2-pruning-pipeline]
- [Source: docs/planning-artifacts/research/technical-sampled-instrument-noteplayer-research-2026-02-23.md#recommended-sample-strategy]

### User-Provided SF2 Import (Idea)

**Priority:** None — idea only, may never be implemented
**Category:** Audio / User Content
**Date Added:** 2026-02-23

**Idea:**
Allow users to import their own SF2 SoundFont files into the app, enabling training with custom instrument samples (e.g., a recording of their own instrument, a specialty SoundFont from the community). Imported SF2 presets would appear alongside bundled instruments in the Settings picker.

**Why this may not be needed:**
- The bundled GeneralUser GS already covers 261 instruments — most users won't need more
- SF2 import adds significant complexity: file handling, crash recovery, storage management
- `AVAudioUnitSampler` can crash on malformed SF2 files with no way to catch the exception — this is a real stability risk for user-provided content
- The feature serves a niche audience (users who own or create custom SoundFonts)

**If pursued:**
- Import via iOS share sheet or Files app integration
- Copy imported SF2 to app's documents directory
- Parse PHDR metadata to enumerate presets (reuse `SF2PresetParser` from story 8-2)
- **Crash recovery via sentinel pattern**: Before loading a user SF2, write `"loading_sf2": "filename.sf2"` to UserDefaults. On success, clear sentinel. On next app launch, if sentinel exists, the previous load crashed — offer to remove the offending file
- `SoundFontLibrary` would scan both app bundle and documents directory for SF2 files

**Related Research:**
- [Source: docs/planning-artifacts/research/technical-sampled-instrument-noteplayer-research-2026-02-23.md#crash-recovery-for-user-provided-sf2]
- [Source: docs/planning-artifacts/research/technical-sampled-instrument-noteplayer-research-2026-02-23.md#instrument-auto-discovery]

---

## Adversarial Review Findings (2026-02-22)

Whole-project adversarial review focusing on unsafe practices, unwanted dependencies, separation of concerns, and duplication.

### Unsafe Practices

#### U1: `fatalError()` in App Initialization

**Priority:** High
**Category:** Safety / Crash Risk

**Issue:**
`PeachApp.swift:57` calls `fatalError("Failed to initialize app: \(error)")` if `ModelContainer`, `SineWaveNotePlayer`, or `dataStore.fetchAll()` fails at launch. No recovery UI, no retry, no graceful degradation. A corrupted SwiftData store or audio entitlement issue on a fresh install results in an instant crash with no user-facing explanation.

**Proposed Fix:**
Replace with a fallback error state that shows an error screen or retries initialization.

**Related Code:**
- `Peach/App/PeachApp.swift:56-58`

#### U2: `precondition()` for MIDI Note Validation

**Priority:** High
**Category:** Safety / Crash Risk

**Issue:**
`FrequencyCalculation.swift:60` uses `precondition(midiNote >= 0 && midiNote <= 127, ...)` for MIDI note validation. `precondition` is stripped under `-Ounchecked` optimization. More importantly, `AudioError.invalidFrequency` already exists as a typed error — the validation should `guard`/`throw` instead of trapping. A bad MIDI note from a corrupt `ComparisonRecord` would crash the app in debug.

**Proposed Fix:**
Replace `precondition` with `guard ... else { throw AudioError.invalidFrequency(...) }`.

**Related Code:**
- `Peach/Core/Audio/FrequencyCalculation.swift:60`
- `Peach/Core/Audio/NotePlayer.swift` — `AudioError` enum

#### U3: `nonisolated(unsafe)` Environment Key Pattern

**Priority:** Medium
**Category:** Safety / Concurrency

**Issue:**
Three environment keys use `nonisolated(unsafe)` with `MainActor.assumeIsolated()`: `TrainingSessionKey` (`TrainingScreen.swift:152`), `PerceptualProfileKey` (`ProfileScreen.swift:149`), and `TrendAnalyzerKey` (`TrendAnalyzer.swift:93`). This tells the compiler "trust me" about actor isolation. If an `EnvironmentKey.defaultValue` is ever accessed off the main thread (e.g., during SwiftUI internal diffing on a background queue), it's undefined behavior.

**Proposed Fix:**
Investigate whether Swift 6.0+ provides a safe pattern for `@MainActor` environment key defaults, or use a lazy optional pattern that avoids the unsafe annotation. See also the existing item "Extract Environment Keys to Shared Locations" for the duplication aspect.

**Related Code:**
- `Peach/Training/TrainingScreen.swift:151-171`
- `Peach/Profile/ProfileScreen.swift:148-157`
- `Peach/Core/Profile/TrendAnalyzer.swift:92-101`

#### U4: Fire-and-Forget `Task`s Without Tracking

**Priority:** Medium
**Category:** Safety / Resource Leaks

**Issue:**
Three locations spawn untracked `Task`s that could outlive their owning context:
- `TrainingSession.stop()` at line 286 — `notePlayer.stop()` in a fire-and-forget Task
- `TrainingSession.handleAnswer()` at line 239 — stopping note2 early
- `HapticFeedbackManager.playIncorrectFeedback()` at line 41 — second haptic impact after 50ms delay

If the session or manager is stopped and deallocated quickly, these orphan tasks may execute after cleanup. Rapid incorrect answers could also accumulate untracked haptic tasks.

**Proposed Fix:**
Store task references for cancellation in `deinit`/`stop()`, or use structured concurrency.

**Related Code:**
- `Peach/Training/TrainingSession.swift:239, 286`
- `Peach/Training/HapticFeedbackManager.swift:41-44`

#### ~~U5: Polling Loop in Training Session~~ (RESOLVED)

**Status:** Resolved — 2026-02-24
**Resolution:** The polling loop was removed. `TrainingSession` now uses a purely event-driven chain (`playNextComparison()` → `startPlayingNote1()` → `startPlayingNote2()` → `handleAnswer()` → feedback → loop) with no spin-waiting.

### Separation of Concerns

#### S1: Mock Classes Ship in Production Binary

**Priority:** Medium (downgraded from High — partial fix applied)
**Category:** Code Organization / Binary Size

**Issue:**
`MockHapticFeedbackManager` (`HapticFeedbackManager.swift`) lives in the main Peach target, not `PeachTests`. It's a full `@MainActor final class` with test tracking (`incorrectFeedbackCount`, `reset()`). `MockNotePlayerForPreview` remains in `TrainingScreen.swift` but is scoped to preview.

**Partial Resolution (2026-02-24):** `MockDataStoreForPreview` was removed. `MockNotePlayerForPreview` is now scoped to `#Preview` blocks (compile-time dead code in release). Only `MockHapticFeedbackManager` remains as a full production-compiled mock.

**Remaining Fix:**
Move `MockHapticFeedbackManager` to `PeachTests`.

**Related Code:**
- `Peach/Training/HapticFeedbackManager.swift` — `MockHapticFeedbackManager` still in production target

#### ~~S2: `SettingsScreen` Creates Services and Orchestrates Business Logic~~ (RESOLVED)

**Status:** Resolved — 2026-02-24
**Resolution:** `SettingsScreen.resetAllTrainingData()` now delegates to `trainingSession.resetTrainingData()`, which centrally orchestrates clearing the convergence chain, session best, profile, trend analyzer, and threshold timeline. The view calls a single method instead of orchestrating multi-service operations.

#### S3: `ComparisonRecordStoring` Protocol Is Incomplete

**Priority:** Medium
**Category:** Architecture / Abstraction Leak

**Issue:**
The protocol defines only `save()` and `fetchAll()` (`ComparisonRecordStoring.swift:8-17`), but `TrainingDataStore` also exposes `delete(_:)` and `deleteAll()`. `SettingsScreen` calls `deleteAll()` directly on the concrete `TrainingDataStore` type, bypassing the protocol entirely. The protocol creates a false sense of decoupling when real callers need methods it doesn't declare.

**Proposed Fix:**
Add `delete(_:)` and `deleteAll()` to the protocol, or acknowledge the protocol is intentionally narrow and route deletion through a different mechanism.

**Related Code:**
- `Peach/Core/Data/ComparisonRecordStoring.swift`
- `Peach/Core/Data/TrainingDataStore.swift`
- `Peach/Settings/SettingsScreen.swift:125-127`

### Duplication

#### ~~D1: `makeTrainingSession()` Fixture Duplicated Across Test Files~~ (RESOLVED)

**Status:** Resolved — 2026-02-24
**Resolution:** Extracted shared `TrainingSessionFixture` struct and `makeTrainingSession()` factory into `TrainingTestHelpers.swift`. All 8 test files (TrainingSessionTests, IntegrationTests, LifecycleTests, DifficultyTests, SettingsTests, AudioInterruptionTests, FeedbackTests, TrainingScreenFeedbackTests) now use the shared factory. The factory supports optional `comparisons`, `settingsOverride`, `noteDurationOverride`, `includeHaptic`, and `notificationCenter` parameters to cover all test scenarios.

#### D2: `nonisolated(unsafe)` Environment Key Boilerplate Repeated 3 Times

**Priority:** Low
**Category:** Code Organization

**Issue:**
The identical 8-line pattern (`nonisolated(unsafe) static var defaultValue = { ... MainActor.assumeIsolated { ... } }()`) is copy-pasted in `TrainingScreen.swift`, `ProfileScreen.swift`, and `TrendAnalyzer.swift`. This is both duplication and an unsafe pattern (see U3).

**Proposed Fix:**
Extract to a generic helper or macro. See also existing item "Extract Environment Keys to Shared Locations."

#### ~~D3: Kazez Formula Coefficients Differ Without Documentation~~ (RESOLVED)

**Status:** Resolved — 2026-02-22
**Resolution:** The difference is intentional by design. `KazezNoteStrategy` (0.05) implements the original Kazez algorithm which tracks a single global difficulty. `AdaptiveNoteStrategy` (0.08) tracks difficulty across a range of notes, which changes convergence behavior and requires a more aggressive narrowing coefficient to avoid stalling. The divergence is a deliberate tuning decision, not an inconsistency.

#### D4: `hasTrainingData` Check Duplicated Across Views

**Priority:** Low
**Category:** Code Organization

**Issue:**
Both `ProfileScreen.swift:86` and `ProfilePreviewView.swift:27` independently check `profile.overallMean != nil` to determine if training data exists. This semantic question ("has the user trained?") should be a single computed property on `PerceptualProfile`.

**Proposed Fix:**
Add a `hasData` computed property to `PerceptualProfile` and use it from both views.

**Related Code:**
- `Peach/Profile/ProfileScreen.swift:86`
- `Peach/Start/ProfilePreviewView.swift:27`
- `Peach/Core/Profile/PerceptualProfile.swift`

### Other

#### O1: Dead Code — `ContentView.previousScenePhase`

**Priority:** Low
**Category:** Dead Code

**Issue:**
`ContentView.swift:15` declares `@State private var previousScenePhase: ScenePhase?`. It is written to on line 37 but never read anywhere.

**Proposed Fix:**
Remove the property and the assignment.

**Related Code:**
- `Peach/App/ContentView.swift:15, 37`

#### ~~O2: `KazezNoteStrategy` Ignores User-Configured Note Range~~ (RESOLVED)

**Status:** Resolved — 2026-02-24
**Resolution:** Fixed during story 9.1 (`9-1-promote-kazeznotestrategy-to-default.md`). `KazezNoteStrategy.nextComparison()` now uses `settings.noteRangeMin...settings.noteRangeMax` instead of hardcoded MIDI 48-72.
