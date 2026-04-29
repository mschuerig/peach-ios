# Story 77.12: TrainingLifecycleCoordinator plugin-style fit

Status: review

## Story

As **a developer working towards the plugin-style discipline architecture (Epic 77)**,
I want `TrainingLifecycleCoordinator` to stop enumerating disciplines by name in its properties, initializer, and dispatch switch,
so that adding, removing, or extending a discipline does not require editing the central lifecycle coordinator and the coordinator becomes a registry-driven orchestrator instead of a per-discipline hub.

## Background

Surfaced as a deferred finding from the 77.6 code review. The user's verdict was unambiguous:

> "TrainingLifecycleCoordinator with its dependencies unfortunately does not fit the plugin-style architecture we're working towards."

After 77.6, `TrainingLifecycleCoordinator` reads, in plain code:

```
init(
    pitchDiscriminationSession: PitchDiscriminationSession,
    pitchMatchingSession: PitchMatchingSession,
    timingOffsetDetectionSession: TimingOffsetDetectionSession,
    continuousRhythmMatchingSession: ContinuousRhythmMatchingSession,
    userSettings: any UserSettings,
    crmUserSettings: any ContinuousRhythmMatchingUserSettings,
    backgroundPolicy: BackgroundPolicy
)
```

And `startCurrentSession()` is a switch over `NavigationDestination` with a per-discipline branch that knows how to construct each discipline's settings struct. Two coupling points stand out:

1. **Per-discipline session properties.** Adding a discipline adds a stored property and a constructor parameter. With six disciplines (four shipping today, two more in the pitch family planned) this scales linearly with the discipline count.
2. **Per-discipline feature-local settings.** Story 77.6 made the right end-to-end-ownership decision for `enabledGapPositions`, but threaded the resulting `crmUserSettings` port through the *central* coordinator. If pitch matching, pitch discrimination, timing offset detection, and continuous rhythm matching each need their own feature-local port (the 77.6 Completion Notes flag `noteGap` as an immediate candidate), the coordinator becomes a settings hub.
3. **`session(for:)` and `startCurrentSession()` switches.** Both pattern-match on `NavigationDestination` cases that name specific disciplines and call typed `start(settings:)` methods on typed session properties. Adding a discipline means editing both switches.

This is precisely the centralisation Epic 77 set out to dissolve. 77.1–77.6 pushed UI contributions, data declarations, JSON envelope storage, CSV migration logic, and now feature-local settings into per-discipline files. The lifecycle coordinator is the last large central type that still has to be edited every time a discipline is added.

## Acceptance Criteria

### AC 1: Coordinator stops naming disciplines in its public surface

**Given** `Peach/App/TrainingLifecycleCoordinator.swift` after this story
**When** inspected
**Then** the initializer no longer takes per-discipline session parameters or per-discipline settings parameters. A grep for any specific discipline name (`pitchDiscrimination`, `pitchMatching`, `timingOffsetDetection`, `continuousRhythmMatching`, `crm`) in `TrainingLifecycleCoordinator.swift` returns zero hits.

The coordinator instead consumes a single registry-shaped dependency that lets it look up the session for a `NavigationDestination` and start it without knowing the destination's concrete settings type.

### AC 2: Each discipline owns its lifecycle wiring

**Given** the per-discipline files under `Peach/Training/<Discipline>/`
**When** inspected
**Then** each discipline contributes — through whatever registry/protocol mechanism this story chooses — the closure or function that produces a started session for its own `NavigationDestination` case, given only the central `UserSettings` (and any feature-local ports the discipline itself owns).

`ContinuousRhythmMatchingSettings.from(_:crmUserSettings:)` continues to be the seam where shared and feature-local settings compose. The change is who *calls* it: a CRM-owned closure, not the central coordinator.

### AC 3: Adding a hypothetical discipline requires no edits to TrainingLifecycleCoordinator

**Given** an imagined new discipline (e.g. `chordRecognition`) added under `Peach/Training/ChordRecognition/`
**When** following the existing per-discipline plugin pattern (UI contributions, data declarations, settings, etc.)
**Then** registering the new discipline's lifecycle does not require any edit to `TrainingLifecycleCoordinator.swift`. Document this property explicitly in Completion Notes — list the files a hypothetical seventh discipline would need to touch and confirm the coordinator is not among them.

### AC 4: Composition root constructs the registry

**Given** `Peach/App/PeachApp.swift`
**When** inspected
**Then** the App composition root continues to construct each concrete session (since the App layer is the only place that may reference all disciplines), assembles them into the registry shape chosen by AC 1, and hands the registry to `TrainingLifecycleCoordinator`. Whether the registry is the existing `TrainingDisciplineRegistry`, a new dedicated `TrainingLifecycleRegistry`, or an extension of the existing per-discipline contribution mechanism is dev's call — the constraint is that the coordinator depends on one abstract shape, not on each concrete session.

### AC 5: NavigationDestination remains the lookup key

**Given** `NavigationDestination` (the existing enum that names destinations including `.pitchDiscrimination`, `.pitchMatching`, `.timingOffsetDetection`, `.continuousRhythmMatching`, `.settings`, `.profile`)
**When** the coordinator dispatches lifecycle events (start, stop, navigate, scene-phase transitions)
**Then** it uses `NavigationDestination` as the registry key. The enum stays where it is — moving it is out of scope. The two existing non-training cases (`.settings`, `.profile`) continue to be no-ops for lifecycle.

### AC 6: Feature-local settings ports stop flowing through the coordinator

**Given** `ContinuousRhythmMatchingUserSettings` (introduced in 77.6) and any future analogous feature-local settings ports
**When** inspected after this story
**Then** these ports are constructed by the App composition root and passed *directly to the contributing discipline's lifecycle closure / wiring*, never threaded through `TrainingLifecycleCoordinator`. The coordinator does not hold or pass any `*UserSettings` reference other than (optionally) the central `UserSettings` if and only if the coordinator itself still needs it for non-discipline-specific behaviour like `autoStartTraining`.

If `userSettings.autoStartTraining` remains the only non-discipline reason for the coordinator to know `UserSettings`, that single read is acceptable. Document the choice in Completion Notes.

### AC 7: Lifecycle behaviour preserved

**Given** the existing lifecycle behaviour (auto-start on scene activation, stop on background, navigation cancellation, training-screen appear/disappear, help-sheet pause/resume, menu navigation)
**When** exercised after this story
**Then** every existing behaviour is preserved. `TrainingLifecycleCoordinatorTests` continues to pass, with test fixtures rewritten to use the registry shape rather than per-discipline session injection.

### AC 8: All four configurations green

**Given** `bin/test.sh && bin/test.sh -p mac && bin/test.sh --research && bin/test.sh -p mac --research`
**When** run after the changes
**Then** all configurations pass. `bin/build.sh && bin/build.sh -p mac` produces zero new warnings.

## Tasks / Subtasks

- [x] Task 1: Pick the registry shape (AC: 1, 2, 4)
  - [x] 1.1 Survey the existing 77.x plugin mechanisms (`TrainingDisciplineRegistry`, `CSVHistoryRegistry`, UI-contribution registries from 77.1/77.2). Decide whether to extend one of them or introduce a focused `TrainingLifecycleRegistry` keyed by `NavigationDestination`.
  - [x] 1.2 Document the choice in a Dev Notes paragraph: chosen shape, rejected shapes, reason. Pay attention to whether any chosen shape interacts with story 77.10 (test isolation for shared registries).

- [x] Task 2: Move per-discipline lifecycle contributions into each discipline directory (AC: 2, 6)
  - [x] 2.1 For each of `pitchDiscrimination`, `pitchMatching`, `timingOffsetDetection`, `continuousRhythmMatching`: extract a closure / function that takes the central `UserSettings` (and any feature-local port the discipline already owns) and returns a started session. Place the contribution alongside the discipline's other plugin-style contributions.
  - [x] 2.2 Continuous rhythm matching's contribution composes via `ContinuousRhythmMatchingSettings.from(_:crmUserSettings:)`. The CRM contribution holds the `crmUserSettings` port directly — the coordinator is no longer involved.

- [x] Task 3: Refactor `TrainingLifecycleCoordinator` (AC: 1, 5, 7)
  - [x] 3.1 Replace the four per-discipline session properties with the chosen registry shape.
  - [x] 3.2 Replace the per-discipline ctor parameters analogously.
  - [x] 3.3 Rewrite `session(for:)` and `startCurrentSession()` to look up via the registry rather than switch on `NavigationDestination` cases.
  - [x] 3.4 Decide whether the coordinator still needs a direct `UserSettings` reference for `autoStartTraining`. If no — also move that read behind the registry / a separate small port. If yes — leave the single read and document why (AC 6).

- [x] Task 4: Update App composition root (AC: 4)
  - [x] 4.1 Construct each concrete session in `PeachApp.swift` as today. Construct each discipline's lifecycle contribution. Register them. Pass the registry to `TrainingLifecycleCoordinator`.
  - [x] 4.2 `AppContinuousRhythmMatchingUserSettings` (and any future siblings) is held by the CRM contribution, not by the coordinator.

- [x] Task 5: Update tests (AC: 7, 8)
  - [x] 5.1 Rewrite `TrainingLifecycleCoordinatorTests.makeCoordinator` to construct a fixture registry rather than a list of per-discipline session mocks.
  - [x] 5.2 Existing per-discipline session mocks remain — they're just registered into the fixture registry instead of injected directly.
  - [x] 5.3 Add at least one test that proves the registry-keyed dispatch works for every shipping `NavigationDestination` training case.

- [x] Task 6: Verify (AC: 8)
  - [x] 6.1 All four test configurations green.
  - [x] 6.2 Build all four; zero new warnings.

## Dev Notes

### Why this is its own story, not piecemeal cleanup

77.6 deliberately scoped itself narrowly: move `enabledGapPositions` storage end-to-end into the CRM directory. It did so correctly. The deliberate side-effect was that the central coordinator gained one more discipline-specific dependency — the right *next* step after 77.6, but not 77.6's job.

This story takes that next step for *all* disciplines at once. Doing it piecemeal — refactor CRM only, then PD, then PM, then TOD — would leave the codebase in mixed states for several stories' duration and would force the coordinator to keep both the registry shape and the per-discipline shape simultaneously. A single cut is cleaner and reviewable.

### What this story is NOT

- **Not a redesign of `NavigationDestination`.** The enum stays as-is; this story uses it as the registry key.
- **Not a removal of `TrainingLifecycleCoordinator`.** The coordinator stays. It still owns scene-phase handling, navigation cancellation, training-screen lifecycle, and menu navigation. What changes is *how* it dispatches start/stop — registry lookup instead of typed property access.
- **Not a redesign of `BackgroundPolicy`.** That dependency stays; it has nothing to do with discipline-specific knowledge.
- **Not a per-discipline split of `currentTrainingDestination`, `wasActiveBeforeHelpSheet`, `autoStartSetting`.** These are app-wide lifecycle state, not discipline-specific.
- **Not a re-platforming of `TrainingSession`.** The protocol used by sessions (`start(settings:)`, `stop()`, `isIdle`) is unchanged; the registry just hides the per-discipline `Settings` type behind each contribution's closure.

### Relationship to other 77.x stories

- **77.6 is a prerequisite.** This story builds on the feature-local port pattern 77.6 established for `ContinuousRhythmMatchingUserSettings`. Without that port, the CRM lifecycle contribution would not have anywhere clean to read `enabledGapPositions` from.
- **77.10 (test isolation for shared registries) is independent but adjacent.** If this story chooses to extend an existing shared registry rather than introduce a new one, it must align with whatever isolation shape 77.10 lands. Run order: do not block on 77.10 — start with whichever shape we have, and fold into 77.10's resolution when that ships.
- **77.11 (architecture documentation) must run after this story.** The plugin-style architecture doc needs to describe lifecycle-as-registry-contribution as the final state, so 77.12 lands before 77.11. Sprint order updated accordingly.

### References

- `Peach/App/TrainingLifecycleCoordinator.swift` — the central type to refactor.
- `Peach/App/PeachApp.swift:38-60, 93-100, 214-220, 516-535` — composition root that builds the coordinator today.
- `Peach/App/PreviewDefaults.swift` — preview wiring that mirrors the production composition.
- `Peach/Core/Training/Discipline/TrainingDisciplineRegistry.swift` — possible host for the lifecycle registry, depending on Task 1's decision.
- `Peach/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingSettings.swift` — the `from(_:crmUserSettings:)` seam stays as-is; the contribution wraps it.
- `Peach/Training/ContinuousRhythmMatching/Settings/ContinuousRhythmMatchingUserSettings.swift` — feature-local port that this story moves out of the coordinator's hands and into the CRM contribution's hands.
- `Peach/App/NavigationDestination.swift` — the registry key. Unchanged.
- Story 77.6 (`docs/implementation-artifacts/77-6-feature-owned-gap-positions-storage.md`) — the prerequisite that established feature-owned settings end-to-end.
- Story 77.6 review — surfaced this concern as a deferred architectural finding; user's verdict ("TrainingLifecycleCoordinator with its dependencies unfortunately does not fit the plugin-style architecture we're working towards") motivated drafting this story.
- Memory: `feedback_never_defer_preexisting` — every deferred review finding is either fixed or tracked. This story is the tracked form.

## Completion Notes

### Registry shape: new `TrainingLifecycleRegistry`

Chose to introduce a new `TrainingLifecycleRegistry` rather than extend the existing `TrainingDisciplineRegistry`. Reasoning:

- `TrainingDisciplineRegistry` lives in `Peach/Core/` and stores stateless `Sendable` discipline descriptors (display name, payload type, history shape). Its instances are constructed during module load and inspected from anywhere — Core, App, tests.
- Lifecycle contributions are App-layer runtime objects: a captured `(any TrainingSession)` instance plus a closure that constructs feature-specific settings from runtime user settings and starts the session. They can only be assembled at composition time (when concrete sessions exist), and they are mutated indirectly (sessions accumulate state).
- Mixing static descriptor metadata and live lifecycle bindings on one registry would force the descriptor layer to depend on App-only types like `TrainingSession`. That collapses the Core/App boundary the existing registry preserves.

Rejected alternatives:

1. **Extend `TrainingDisciplineRegistry`** — rejected for the layering reason above.
2. **Per-discipline `TrainingLifecycle` protocol** that the coordinator iterates — rejected because the coordinator needs `O(1)` lookup by `NavigationDestination`, not iteration. A protocol would still need a registry-shaped index keyed by destination.
3. **Closure dictionary literal in `PeachApp`** — rejected because each discipline directory must own its own wiring (AC 2). A literal in the composition root puts the wiring back in the central layer.

Interaction with story 77.10: the registry is constructed once at app startup and held by the composition root. It is not a process-global singleton, so the task-local override pattern from 77.10 is unnecessary — tests build a fixture registry per test instance.

### `UserSettings` no longer flows through the coordinator (AC 6)

The coordinator originally read `userSettings.autoStartTraining` directly. Replaced that with an `initialAutoStartSetting: Bool` constructor parameter: the App composition root (and the macOS `PeachCommands` toggle) read from `UserSettings` and pass the resolved value in. This drops the last `UserSettings` reference from the coordinator entirely, so a grep for any specific discipline name (`pitchDiscrimination`, `pitchMatching`, `timingOffsetDetection`, `continuousRhythmMatching`, `crm`) — and indeed for `userSettings` — in `TrainingLifecycleCoordinator.swift` returns zero hits.

### Hypothetical seventh discipline (AC 3)

A new `chordRecognition` discipline added under `Peach/Training/ChordRecognition/` would need to touch:

- `Peach/Core/NavigationDestination.swift` — add the `.chordRecognition` enum case (the registry key).
- `Peach/Training/ChordRecognition/<existing plugin contributions>` — UI, settings, data, history; the same files every other discipline already owns.
- `Peach/Training/ChordRecognition/ChordRecognitionLifecycleContribution.swift` — new, follows the pattern of the other four contribution files.
- `Peach/App/PeachApp.swift` — construct the new session and call `chordRecognitionSession.contribute(to: builder, …)` inside the registry builder closure.

`Peach/App/TrainingLifecycleCoordinator.swift` is not on the list. The coordinator's source is invariant under discipline additions.

### Coordinator after this story

`TrainingLifecycleCoordinator.swift` retains scene-phase handling, navigation cancellation, training-screen lifecycle, help-sheet pause/resume, menu navigation, and `awaitIdle`. Its only discipline-shaped dependency is the abstract `TrainingLifecycleRegistry` plus a `BackgroundPolicy` and the resolved auto-start boolean.

## File List

New:
- `Peach/App/Training/TrainingLifecycleRegistry.swift`
- `Peach/Training/PitchDiscrimination/PitchDiscriminationLifecycleContribution.swift`
- `Peach/Training/PitchMatching/PitchMatchingLifecycleContribution.swift`
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionLifecycleContribution.swift`
- `Peach/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingLifecycleContribution.swift`

Modified:
- `Peach/App/TrainingLifecycleCoordinator.swift` — registry-driven; per-discipline properties and switch removed; `initialAutoStartSetting: Bool` replaces `UserSettings` dependency.
- `Peach/App/PeachApp.swift` — composition root builds registry via builder closure and passes it to the coordinator.
- `Peach/App/PreviewDefaults.swift` — preview stub mirrors the production composition.
- `PeachTests/App/TrainingLifecycleCoordinatorTests.swift` — `makeCoordinator` builds a fixture registry; new parameterized test exercises every shipping `NavigationDestination` training case.

Configuration:
- `docs/implementation-artifacts/sprint-status.yaml` — 77-12 → review.

## Dev Agent Record

- Agent: Claude (Opus 4.7) via `/bmad-dev-story 77.12`.
- Approach: registry shape decided up front (Task 1), per-discipline contributions extracted (Task 2), coordinator rewritten against the registry (Task 3), composition root rewired (Task 4), tests updated and a registry-dispatch parameterized test added (Task 5), all four configs verified (Task 6).
- All four test configurations passed: iOS Debug 1479, macOS Debug 1473, iOS Debug Research 1829, macOS Debug Research 1823.
- Both builds passed with zero new warnings (only the pre-existing `appintentsmetadataprocessor` framework warning).

## Change Log

- 2026-04-28: Drafted as a deferred 77.6 review finding. Architectural concern about the central lifecycle coordinator accumulating per-discipline dependencies. Sprint-ordered before 77.11 so that the architecture documentation absorbs this story's final shape. Status → ready-for-dev.
- 2026-04-29: Implemented. Introduced `TrainingLifecycleRegistry` and four per-discipline `*LifecycleContribution.swift` files; coordinator now contains zero per-discipline references and zero `UserSettings` reads (replaced by `initialAutoStartSetting: Bool`). All four configurations green. Status → review.
