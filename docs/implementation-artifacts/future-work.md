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

**Priority:** Medium
**Category:** State Management
**Date Added:** 2026-02-18

**Issue:**
The Kazez convergence chain (the current difficulty level / last cent offset) is not persisted. When the app restarts, `TrainingSession` has no `lastComparison`, so the difficulty resets. The `PerceptualProfile` rebuilds from stored `ComparisonRecord`s and bootstraps via neighbor-weighted difficulty, but the actual position in the convergence chain is lost.

**Impact:**
- Returning users experience an abrupt jump back to wider intervals on every app launch
- Serious users who train daily will find this jarring and disruptive to their flow
- The adaptive algorithm effectively restarts its convergence each session, wasting early comparisons re-converging to the user's actual level

**Potential Solutions:**
- Persist `lastComparison` (or just the last cent offset) to UserDefaults or SwiftData
- On launch, seed the chain from the persisted value instead of bootstrapping from scratch
- Consider whether the profile's bootstrapped difficulty is "close enough" or whether exact chain continuity matters

**Related Code:**
- `Peach/Training/TrainingSession.swift` — `lastComparison` property
- `Peach/Core/Algorithm/AdaptiveNoteStrategy.swift` — `nextComparison()` cold start path
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

### Redesign Profile Graph for Interpretability

**Priority:** High
**Category:** User Experience
**Date Added:** 2026-02-18

**Issue:**
The Profile Screen's confidence band chart (piano keyboard + AreaMark with log-scale Y-axis showing cent thresholds and standard deviations) is not helpful even for the developer. The visualization is technically accurate but practically uninterpretable — users cannot derive meaningful insight about their pitch discrimination ability from looking at it.

**Impact:**
- The profile is the primary way users understand their progress, and it currently fails at this job
- Musicians will not understand what the confidence band represents
- Log-scale Y-axis is unintuitive for non-technical users
- No translation of data into actionable musical feedback
- The summary statistics (mean, stdDev, trend) use technical terminology

**Potential Solutions:**
- Rethink the visualization from scratch — what do users actually want to know?
- Consider bar chart per note (simpler), heat map, or qualitative ratings
- Use musical note names prominently
- Provide plain-language interpretive text ("You can hear differences of X cents around these notes")
- Consider a simplified default view with an optional detailed/advanced view

**Related Code:**
- `Peach/Profile/ProfileScreen.swift` — current visualization
- `Peach/Profile/ConfidenceBandView.swift` — Swift Charts AreaMark implementation
- `Peach/Profile/PianoKeyboardView.swift` — Canvas-rendered keyboard

### Tap-to-Inspect Note Detail on Profile Graph

**Priority:** Medium
**Category:** User Experience
**Date Added:** 2026-02-18

**Issue:**
There is no way to get detailed information about a specific note's training data. When looking at the profile graph, the user should be able to tap on a point/note to see detailed statistics for that particular note.

**Desired Behavior:**
- Tap on a note in the profile visualization to see a detail view or popover
- Show per-note statistics: number of comparisons, mean threshold, standard deviation, trend, recent history
- Translate into musician-friendly language where possible

**Related Code:**
- `Peach/Profile/ProfileScreen.swift` — profile UI
- `Peach/Core/Profile/PerceptualProfile.swift` — per-note `NoteProfile` data (mean, stdDev, count)

### Show Progress Over Time

**Priority:** Medium
**Category:** User Experience
**Date Added:** 2026-02-18

**Issue:**
There is no way to see how pitch discrimination ability has improved (or declined) over time. The `TrendAnalyzer` computes a simple improving/stable/declining trend from bisecting historical records, but there is no temporal visualization — no chart showing threshold convergence across days/weeks, no profile snapshots, no historical comparison.

This was identified as a Phase 2 feature in the original PRD brainstorming but has not been designed or implemented.

**Desired Behavior:**
- A view (accessible from the Profile screen or Start screen) that shows improvement over time
- Could be a line chart of average threshold per day/week
- Could show per-note improvement trajectories
- Should answer the user's question: "Am I getting better?"

**Related Code:**
- `Peach/Core/Data/ComparisonRecord.swift` — has `timestamp` field for temporal queries
- `Peach/Core/Profile/TrendAnalyzer.swift` — existing trend computation (bisection approach)
- `Peach/Profile/ProfileScreen.swift` — likely home for temporal visualization

### No Sense of Session or Progress Acknowledgment

**Priority:** Medium
**Category:** User Experience
**Date Added:** 2026-02-18

**Issue:**
The training loop runs indefinitely with no session boundaries, progress milestones, or acknowledgment of effort. While the "training, not testing" philosophy deliberately avoids gamification, there is currently no feedback at all about training duration, improvement over time, or encouragement to return.

**Impact:**
- Users have no sense of how long they've trained or whether it's "enough"
- No motivation loop to encourage daily practice habits
- The TrendAnalyzer computes improving/stable/declining trends but this data is only visible if the user navigates to the Profile screen
- Missed opportunity to reinforce the value of consistent practice

**Potential Solutions:**
- Subtle session summary when the user stops training ("You trained for 5 minutes, completed 47 comparisons")
- Periodic gentle progress nudges surfaced on the Start Screen ("Your accuracy improved 12% this week")
- Optional daily practice reminders (notifications)
- Keep it minimal and informational — acknowledge effort without gamifying it

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

### Swappable Sound Sources (Instrument Timbres)

**Priority:** Medium
**Category:** Audio / Training Effectiveness
**Date Added:** 2026-02-18

**Issue:**
The app currently uses only sine wave tones for pitch comparisons. While precise and deterministic, sine waves lack the harmonic content of real instruments. Musicians train their ears on timbres — a violinist needs to hear pitch differences in violin-like tones, not pure sine waves.

**Impact:**
- Training with sine waves may not transfer fully to real instrument contexts
- The app feels clinical rather than musical to the target audience
- Limits the app's credibility and usefulness for serious musicians

**Potential Solutions:**
- The `NotePlayer` protocol already supports swappable implementations
- Add sampled instrument sound sources (piano, strings, woodwinds, brass)
- Start with a single high-quality piano sample as an alternative to sine waves
- Allow users to select their preferred sound source in Settings (the UI slot already exists)

**Related Code:**
- `Peach/Core/Audio/NotePlayer.swift` — protocol definition
- `Peach/Core/Audio/SineWaveNotePlayer.swift` — current implementation
- `Peach/Settings/SettingsScreen.swift` — sound source setting (currently sine-only)

*(Additional deferred features and nice-to-haves will be tracked here)*

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

#### U5: Polling Loop in Training Session

**Priority:** Low
**Category:** Safety / Efficiency

**Issue:**
`TrainingSession.runTrainingLoop()` at lines 318-321 spin-waits with `Task.sleep(for: .milliseconds(100))` to detect state changes. The entire training flow is otherwise event-driven (play note -> await answer -> show feedback -> next comparison). This is architecturally inconsistent and wastes CPU.

**Proposed Fix:**
The `Task` could simply `await` on the event-driven chain and exit when cancelled, eliminating the polling loop.

**Related Code:**
- `Peach/Training/TrainingSession.swift:310-324`

### Separation of Concerns

#### S1: Mock Classes Ship in Production Binary

**Priority:** High
**Category:** Code Organization / Binary Size

**Issue:**
`MockHapticFeedbackManager` (`HapticFeedbackManager.swift:65-86`) lives in the main Peach target, not `PeachTests`. It's a full `@MainActor final class` with test tracking (`incorrectFeedbackCount`, `reset()`). Additionally, `MockNotePlayerForPreview` and `MockDataStoreForPreview` are defined in `TrainingScreen.swift:182-199`. All three compile into the shipping app.

**Proposed Fix:**
Move `MockHapticFeedbackManager` to `PeachTests`. Wrap preview mocks in `#if DEBUG` guards or move them to a dedicated preview target.

**Related Code:**
- `Peach/Training/HapticFeedbackManager.swift:61-86`
- `Peach/Training/TrainingScreen.swift:180-199`

#### S2: `SettingsScreen` Creates Services and Orchestrates Business Logic

**Priority:** Medium
**Category:** Architecture / View Responsibility

**Issue:**
`SettingsScreen.resetAllTrainingData()` at line 125 directly instantiates `TrainingDataStore(modelContext:)`, then calls `dataStore.deleteAll()`, `profile.reset()`, and `trendAnalyzer.reset()` in sequence. This violates two of the project's own hard rules: *"All service instantiation happens in PeachApp.swift"* and *"Views contain zero business logic."* This is an orchestration operation disguised as a button action.

**Proposed Fix:**
Create a reset method on `TrainingSession` or a dedicated reset coordinator injected via environment. The view should call a single method, not orchestrate a multi-service operation.

**Related Code:**
- `Peach/Settings/SettingsScreen.swift:123-135`
- See also existing item "Reset All Data Should Also Reset Difficulty"

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

#### D1: `makeTrainingSession()` Fixture Duplicated Across 6 Test Files

**Priority:** Medium
**Category:** Test Maintenance

**Issue:**
Near-identical `makeTrainingSession()` factory methods appear in `TrainingSessionTests`, `TrainingSessionIntegrationTests`, `TrainingSessionLifecycleTests`, `TrainingSessionSettingsTests`, `TrainingSessionAudioInterruptionTests`, and `TrainingSessionUserDefaultsTests`. `TrainingTestHelpers.swift` exists but doesn't include this factory. Six copies means six places to update when `TrainingSession`'s initializer changes.

**Proposed Fix:**
Extract to `TrainingTestHelpers.swift` as a shared factory.

**Related Code:**
- `PeachTests/Training/TrainingTestHelpers.swift`
- All six `TrainingSession*Tests.swift` files

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

#### O2: `KazezNoteStrategy` Ignores User-Configured Note Range

**Priority:** Medium
**Category:** Bug / Settings

**Issue:**
`KazezNoteStrategy` hardcodes C3-C5 (MIDI 48-72) at lines 35-36, ignoring the `settings.noteRangeMin/Max` values passed to `nextComparison()`. If a user changes their range in Settings, this strategy will still select notes outside it. Currently only `AdaptiveNoteStrategy` is wired in production, but this is a latent bug if `KazezNoteStrategy` is ever used with user-configured ranges.

**Proposed Fix:**
Use `settings.noteRangeMin/Max` instead of hardcoded constants, or document that this strategy is evaluation-only and intentionally ignores settings.

**Related Code:**
- `Peach/Core/Algorithm/KazezNoteStrategy.swift:35-36, 66`

#### O3: `ComparisonRecord` Stores Redundant `note1` and `note2`

**Priority:** Low
**Category:** Data Model / Waste

**Issue:**
Per the domain rules (`note2 = same MIDI note as note1`), both notes are always identical. The model stores two `Int` fields for one value. Every record written to SwiftData carries this redundancy, and nothing validates or catches a divergence.

**Proposed Fix:**
Consider reducing to a single `note` field if the domain rule holds permanently, or add a validation assertion. Assess SwiftData migration impact before changing.

**Related Code:**
- `Peach/Core/Data/ComparisonRecord.swift`
- `Peach/Training/Comparison.swift` — always sets `note1 == note2`
