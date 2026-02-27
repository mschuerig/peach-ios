# 11. Risks and Technical Debt

## Architectural Risks

### R-1: Convergence Chain Lost on Restart

**Severity:** Medium
**Status:** Open

The Kazez convergence chain (`lastComparison` in `TrainingSession`) is not persisted. On every app restart, the algorithm bootstraps difficulty from neighbor-weighted profile data instead of continuing from the exact point where the user left off. This means returning users experience wider intervals for the first few comparisons as the chain re-converges.

**Mitigation options:** Persist last cent offset to UserDefaults or SwiftData. Seed the chain on launch.

### R-2: Profile Accumulates All History

**Severity:** Medium
**Status:** Open

`PerceptualProfile` uses Welford's algorithm across the entire comparison history with equal weight. As a user improves over weeks/months, old data drags the statistics. The profile may not reflect current ability.

**Mitigation options:** Rolling window (last N comparisons per note), exponential decay weighting, or periodic profile snapshots.

### R-3: `fatalError()` in App Initialization

**Severity:** High
**Status:** Open

`PeachApp.init()` calls `fatalError()` if `ModelContainer`, `SoundFontNotePlayer`, or `dataStore.fetchAll()` fails. A corrupted SwiftData store or audio entitlement issue causes an instant crash with no recovery path.

**Mitigation options:** Fallback error state UI, retry logic, or graceful degradation (e.g., run without audio, show error screen).

### R-4: Seamless Playback May Inflate Difficulty Numbers

**Severity:** Low
**Status:** Under investigation

Peach plays comparison tones back-to-back without a gap. This may make pitch differences easier to detect than in apps that separate tones with silence, meaning Peach's difficulty numbers could overstate actual discrimination ability.

**Impact:** Training may be less effective if the task is artificially easier. Numbers are not comparable to other ear training apps.

## Technical Debt

### High Priority

| Item | Description | Location |
|---|---|---|
| ~~**Mock in production**~~ | ~~Resolved (Story 20.9) — `MockHapticFeedbackManager` moved to test target. Preview stubs in `EnvironmentKeys.swift` are minimal and private.~~ | — |
| **`precondition()` for validation** | `FrequencyCalculation.swift:60` uses `precondition` instead of `guard`/`throw`. Crashes in debug on bad MIDI input instead of using the existing `AudioError` type. | `FrequencyCalculation.swift:60` |

### Medium Priority

| Item | Description | Location |
|---|---|---|
| **Settings screen violates "views are thin"** | `SettingsScreen.resetAllTrainingData()` orchestrates a multi-service reset. SwiftData import removed (Story 20.10) — `TrainingDataStore` now injected via `@Environment`. Reset logic could still be extracted to a coordinator. | `SettingsScreen.swift` |
| ~~**Reset doesn't clear difficulty**~~ | ~~Resolved (Story 20.8) — `ComparisonSession` stores `[Resettable]` dependencies; `resetTrainingData()` resets all.~~ | — |
| **`ComparisonRecordStoring` incomplete** | Protocol defines only `save`/`fetchAll`, but `TrainingDataStore` also exposes `delete`/`deleteAll`. Callers bypass the protocol for deletion. | `ComparisonRecordStoring.swift` |
| **Fire-and-forget Tasks** | Three locations spawn untracked `Task`s that could outlive their context (stop audio, early note2 stop, delayed haptic). | `ComparisonSession.swift`, `HapticFeedbackManager.swift` |

### Low Priority

| Item | Description | Location |
|---|---|---|
| ~~**`nonisolated(unsafe)` env keys**~~ | ~~Resolved — replaced with `@Entry` macro under Swift 6.2 + default MainActor isolation.~~ | — |
| ~~**Environment key boilerplate**~~ | ~~Resolved — `@Entry` macro eliminates boilerplate.~~ | — |
| **`hasTrainingData` duplicated** | `ProfileScreen` and `ProfilePreviewView` independently check `profile.overallMean != nil`. Should be a computed property on `PerceptualProfile`. | `ProfileScreen.swift:86`, `ProfilePreviewView.swift:27` |
| **Dead code** | `ContentView.previousScenePhase` is written but never read. | `ContentView.swift:15,37` |
| **Redundant `note2` field** | `ComparisonRecord` stores `note1` and `note2` separately, but they are always equal (per domain rules). | `ComparisonRecord.swift` |
| **Polling loop** | `runTrainingLoop()` spin-waits with 100ms sleep to detect state changes. The training flow is otherwise event-driven. | `ComparisonSession.swift` |

## UX Gaps

| Item | Priority | Description |
|---|---|---|
| **No onboarding** | High | New users have no guided introduction. Concepts like "cents" are unexplained. |
| **Profile visualization uninterpretable** | High | Confidence band with log-scale Y-axis is technically correct but practically useless for users. |
| **No progress over time** | Medium | No temporal visualization. `TrendAnalyzer` computes trends but they are only visible on the Profile screen. |
| **No difficulty display** | Medium | During training, the user has no visibility into current cent difference or session best. |
| ~~**Feedback icon flicker**~~ | ~~Medium~~ | ~~Resolved — fixed feedback icon briefly showing previous icon before updating.~~ |
| **No session acknowledgment** | Medium | No summary when stopping training. No sense of duration or progress. |
| **No iPad haptics** | Low | iPads lack a Taptic Engine. Wrong-answer feedback is visual only on iPad. |

## Full Details

For complete descriptions, root cause analysis, and proposed fixes for all items, see [future-work.md](../implementation-artifacts/future-work.md).
