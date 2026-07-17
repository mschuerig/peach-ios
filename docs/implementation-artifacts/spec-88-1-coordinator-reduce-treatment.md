---
title: 'Story 88.1: Give TrainingLifecycleCoordinator the reduce() treatment'
type: 'refactor'
created: '2026-07-17'
status: 'done'
baseline_commit: '9cd5ae51'
review_loop_iteration: 0
context: ['docs/implementation-artifacts/epic-88-context.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `TrainingLifecycleCoordinator`'s suspension / pause / resume / auto-start logic is "a state chart written in prose" spread across ~15 imperative methods and shared helpers (`suspendForeground`, `releaseForeground`, `discardLingeringPausedSession`, `stopCurrentSession`). It is the most bug-prone spot in the app: four open PF entries (049, 050, 079, 051) live in the interleavings between scene-phase, help-sheet, Settings-window, audio-interruption, and sound-source events, and those interleavings are only exercised indirectly.

**Approach:** Extract the *decision* layer into a pure `static func reduce(state:event:context:) -> [Effect]` mirroring `PitchDiscriminationSession`'s event/effect split (Story 75.13). Every input method becomes a thin `send(event, context:)` call; all session/navigation/media work stays imperative in effect interpreters (the hardened async machinery — `awaitIdle`, `SingleShotResumerBox`, the media-rebuild Task — is preserved unchanged as effect implementations). The coordinator stays the single authority on *when* sessions transition; sessions keep mechanism. The one deliberate behaviour change is the PF-079 guard fix.

## Boundaries & Constraints

**Always:**
- Observable behaviour is unchanged **except** the PF-079 fix (see matrix row 3): the `!isForegroundSuspended` auto-restart guard, today `#if os(macOS)`, now applies on iOS too — expressed as reduce logic, not a compile-time branch.
- All existing coordinator tests stay green (behavioural suite in `TrainingLifecycleCoordinatorTests.swift`). Their assertions define the preserved behaviour.
- `reduce` is pure: `static`, no `self`, mutates only the passed `inout State`, reads only `event` + `context`. Async and side effects live only in effect interpreters.
- The reducer folds in `foregroundSuspensions`, `pausedDestination`, `currentTrainingDestination`, `autoStartSetting`, and `mediaRebuildPending`. `activeSession`, `navigationTask`, and `resolvedNavigation` remain effect-runtime concerns (not Equatable pure state).
- Invalid (state, event) pairs are no-ops that log a warning (never crash), matching `PitchDiscriminationSession.send`.
- Catalog hygiene: remove PF-049, PF-050, PF-079 from `deferred-work.md`, cited in the commit; re-disposition PF-051.

**Ask First:**
- **PF-051 disposition.** It concerns per-sub-state pause/resume coverage of the *sessions* (`PauseResumeContractTests`), which is orthogonal to the coordinator reducer. Proposed: keep OPEN with an updated note (the coordinator matrix does not satisfy it). Confirm at approval whether to instead add the session sub-state suite here (scope expansion).
- Any change to the navigation subsystem's internal async machinery (`awaitIdle` / `SingleShotResumerBox` / `navigationTask` cancellation) beyond wrapping it as a `.navigate` effect — expected untouched.

**Never:**
- No change to `TrainingSession`, `TrainingLifecycleRegistry`, `BackgroundPolicy`, or any session state machine.
- No new observable behaviour beyond PF-079; no reordering of effects that alters stop/pause/start sequencing.
- No `async` on `reduce` or on the `send`/`interpret` layer; no eager preloading.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| PF-049: interruption behind help sheet (iOS) | Help sheet open (`.helpWindow` suspended, session paused); `audioStopRequired` fires; user dismisses help | Stop discards paused + stops current (`pausedDestination` cleared); on dismiss `foregroundSuspensions` empties, `currentTrainingDestination` survives → auto-start per policy. Framing was outdated (no `pausedSession.resume()` no-op remains) | N/A |
| PF-050: background behind help sheet (iOS) | Help open + paused; app backgrounds then returns active; user dismisses later | Background stops (documented trial downgrade); return active does **nothing** (suspension guard now applies on iOS); dismiss auto-starts once, cold | N/A |
| PF-079: return-active behind help sheet (iOS) | Session active, help open, app returned to `.active`, still suspended | No auto-restart while suspended — no audio behind the sheet | N/A |
| Multi-owner suspend/release (PF-075) | Settings + Help both open, closed in either order | Pause on first reason, reconcile only after the last reason clears; unchanged | N/A |
| Invalid transition | e.g. `helpDismissed` with no suspension held | No-op, warning logged, no effects | N/A |
| Launch `@AppStorage` sync | `soundSourceChanged` while all idle | No session stops; silent | N/A |

</frozen-after-approval>

## Code Map

- `Peach/App/TrainingLifecycleCoordinator.swift` -- the rewrite target. Add `State` (struct, `Equatable`), nested `Event`/`Effect` enums, `Context` (`foregroundSessionIsIdle: Bool`), `static func reduce(state:event:context:)`, `send`/`interpret`. Each of the 18 input methods (`handleScenePhase`, `handleApp{Activated,Deactivated}`, `trainingScreen{Appeared,Disappeared}`, `startScreenAppeared`, `help{Presented,Dismissed}`, `pauseForegroundSession`/`reconcileForegroundSession`, `toggleTraining`, `startCurrentSession`, `handleAudioStopRequired`, `handleMediaServices{Lost,Reset}`, `handleSoundSourceChanged`, `navigate`) builds a `Context` and calls `send`. Effect interpreters keep today's imperative bodies (`awaitIdle`/`SingleShotResumerBox` lines 396–538 preserved verbatim as the `.navigate` interpreter; media-rebuild Task as `.rebuildMediaInfrastructure`).
- `Peach/App/Training/TrainingLifecycleRegistry.swift` -- unchanged; `contribution(for:)`, `all`, `Contribution{session,start,reconcile}` are the effect sinks.
- `Peach/Core/Ports/BackgroundPolicy.swift` -- unchanged; edge computes `shouldStop`/`policyAutoStart` and passes into events/state (`.scenePhaseChanged(phase:shouldStop:)`; `policyAutoStart` immutable in `State`).
- `PeachTests/App/TrainingLifecycleCoordinatorTests.swift` -- existing behavioural suite stays; keep `MockTrainingSession`, `makeMockFixture`/`makeTwoMockFixture`, `waitUntil*` helpers.
- `PeachTests/App/TrainingLifecycleReduceTests.swift` -- **new**; pure `(State,Event,Context)→(State,[Effect])` matrix, mirroring `PitchDiscriminationReduceTests.swift`.
- `docs/project-context.md` -- line 91 routing bullet (note the reduce structure; PF-079 guard now cross-platform).
- `docs/implementation-artifacts/deferred-work.md` -- PF-049 (164), PF-050 (174), PF-051 (184), PF-079 (439).

## Tasks & Acceptance

**Execution:**
- [x] `TrainingLifecycleCoordinator.swift` -- confirm the recorded PF-049/050/079 framings still hold against HEAD (Design Notes), then introduce `State`/`Event`/`Effect`/`Context` + `reduce` + `send` + `interpret`; port every input method to `send`; keep all effect bodies imperative and the async machinery verbatim -- the single structural change of the story
- [x] `TrainingLifecycleCoordinator.swift` -- apply the PF-079 fix inside `reduce`: the scene-phase / app-activation auto-start transition is suppressed whenever `foregroundSuspensions` is non-empty, on **both** platforms (delete the `#if os(macOS)` guard) -- closes PF-050 and PF-079
- [x] `PeachTests/App/TrainingLifecycleReduceTests.swift` -- exhaustive state×event matrix: every event from every reachable `State` asserts resulting state + `[Effect]`; explicit cases for each PF-049/050/079 interleaving; invalid-transition table (no-op) -- the exhaustive coverage that closes the interleaving gap
- [x] `PeachTests/App/TrainingLifecycleCoordinatorTests.swift` -- run unchanged; adjust only if a helper signature moved -- behavioural regression net (ran unchanged: 176 pass)
- [x] `docs/project-context.md` -- update line 91 (coordinator is a reduce state machine; PF-079 guard cross-platform)
- [x] `docs/planning-artifacts/architecture.md` -- add the reduce-split note (§ coordinator) and the cross-platform auto-restart-suppression fact (boy-scout doc sync alongside project-context)
- [x] `docs/implementation-artifacts/deferred-work.md` -- remove PF-049, PF-050, PF-079; re-disposition PF-051 per the Ask-First outcome (kept OPEN, session-level)

**Acceptance Criteria:**
- Given any (state, event) pair, when dispatched through `send`, then the resulting state and emitted effects match the reduce matrix, and invalid pairs produce no effects and log a warning
- Given the app returns to `.active` on iOS while a Help sheet suspends the foreground session, when scene phase resolves, then training does **not** auto-restart until the sheet is dismissed (no audio behind the sheet)
- Given every existing behavioural test in `TrainingLifecycleCoordinatorTests.swift`, when run on iOS and macOS, then all pass unchanged
- Given `reduce`, when inspected, then it is `static`, references no `self`/registry/policy, and all async work resides in effect interpreters

## Design Notes

**Verified framing (Task-1 evidence, 2026-07-17).** Traced against HEAD (`9cd5ae51`):
- **PF-049 is outdated.** Its `pausedSession.resume()` no-op path predates PF-075's multi-owner rewrite. Today, an `audioStopRequired` behind an open iOS help sheet routes `handleAudioStopRequired → stopCurrentSession → discardLingeringPausedSession` (stops the paused session, clears `pausedDestination`) then stops current. The help sheet is a `.sheet` (no `onDisappear`), so `currentTrainingDestination` survives; `helpSheetDismissed → releaseForeground` finds suspensions empty + destination present + session idle → `startCurrentSession()` (iOS auto-start). It already resolves as PF-049's proposed fix. The matrix pins it.
- **PF-079 is a one-line fix** with wide test value: the `#if os(macOS)` around the `isForegroundSuspended` guard in `handleScenePhase` (lines 116–121) and the equivalent in `handleAppActivated`. Dropping it stops the iOS auto-restart-behind-sheet.
- **PF-050 follows from PF-079**: with the guard cross-platform, background→return no longer restarts behind the sheet; the paused trial is discarded on background (accepted, documented downgrade — user-initiated backgrounding has its own stop semantics), and dismiss auto-starts once.

**Shape** (mirrors `PitchDiscriminationSession.swift`; State is a *struct* here, not an enum, because coordinator state is a product of several fields):
```swift
struct State: Equatable {
    let policyAutoStart: Bool          // BackgroundPolicy.shouldAutoStartTraining, fixed at init
    var currentTrainingDestination: NavigationDestination?
    var pausedDestination: NavigationDestination?
    var foregroundSuspensions: Set<ForegroundSuspensionReason>
    var autoStartSetting: Bool
    var mediaRebuildPending: Bool
    var shouldAutoStart: Bool { policyAutoStart || autoStartSetting }
}
enum Event { case scenePhaseChanged(AppScenePhase, shouldStop: Bool), trainingScreenAppeared(NavigationDestination), helpDismissed, /* … */ }
enum Effect { case startSession(NavigationDestination), stopSession(NavigationDestination), pauseSession(NavigationDestination), reconcileSession(NavigationDestination), stopAllNonIdle, navigate(NavigationDestination), rebuildMediaInfrastructure, log(String) }
struct Context { let foregroundSessionIsIdle: Bool }   // read at the edge from registry.contribution(for: state.currentTrainingDestination)
```
Deviation from the reference (honest): reduce takes a `Context` (the reference's is `(state:event:)`) because the coordinator orchestrates *external* sessions whose idle-ness it must query; the session owned its own state. `Context` stays minimal (one field). Effect interpreters read `activeSession`/registry at the edge; the `.navigate` and `.rebuildMediaInfrastructure` interpreters retain today's async bodies verbatim and feed completion back via `send` where they already do (media-reset clears `mediaRebuildPending`).

**Implementation notes (2026-07-17).**
- `stopCurrentSession()` was kept as a public method (`.stopRequested` event) — it has no app caller but the behavioural suite drives it directly (4 call sites). `navigate`'s pre-flight `discardLingeringPausedSession` moved from inside the async task to the synchronous reduce (`.navigationRequested` → discard + `.navigate`), since `pausedDestination` is now pure state; the activeSession-stop + `awaitIdle` + `resolvedNavigation` resolution stay in the `.navigate` interpreter unchanged. No navigation test regressed.
- The invalid-transition warning was scoped: unlike a session's enum state, the coordinator's product state has no genuinely-invalid transitions (every event is a valid command that conditionally emits), so `send` warns only for the four events that should always emit (`navigationRequested`, `trainingScreenAppeared`, `mediaServices{Lost,Reset}`); the frequently-idempotent lifecycle ticks are expected no-ops. Never-crash is structural (total switch).
- Observation granularity coarsened intentionally: the folded fields live under one `state` struct, so a mutation of any invalidates all `state`-derived reader properties (`currentTrainingDestination`, `isForegroundSuspended`, …). All such readers are cheap menu/overlay reads — no hot path — so over-invalidation is harmless.
- Result: full suite green on both platforms (2263 iOS / 2250 macOS), `archlint` + `check-dependencies` clean. Acceptance criterion "`rebuildCoordinators()`/identity stability" analogue here — identity stability of sessions/coordinator/monitor across a sound-source change — is inherited from 88.2 and untouched; the reduce rewrite replaces no instances.

**Review round (2026-07-17).** Blind Hunter + Edge Case Hunter, both tasked to diff every reduce case against the imperative original at `9cd5ae51`, confirmed behaviour-preservation across all ~20 methods (effect calls, ordering, the `pausedDestination==current` double-stop, `Context` substitution, media-reset unconditional clear, `awaitIdle` verbatim) except the intended PF-079 change. Two patches taken: (1) the invalid-transition warning's must-emit set narrowed to the only two events that unconditionally emit (`navigationRequested`, `mediaServicesReset`) — a duplicate `mediaServicesLost` and a re-`trainingScreenAppeared` on the current destination behind a window legitimately reduce to `[]` and were false-warning; (2) restored the edge-known scene-phase stop log and an app-activation log (observability of the bug-prone component). Added tests: reverse multi-owner release order, benign duplicate `mediaServicesLost`.

**Simplify pass + frozen-line deviation (2026-07-17, human-approved).** Two simplify reviewers independently found that after patch (1) the invalid-transition warning was provably dead (its two must-emit events always append an effect, so the empty-effects guard can never hold) — the "warn on invalid transition" concept, borrowed from `PitchDiscriminationSession.send`, does not fit the coordinator's *product* state, which has no genuinely-invalid transitions. Per Michael's decision, the warning machinery (`isExpectedNoOp`, the `previous = state` copy, the warning block) was removed; `send` collapses to context→reduce→interpret. This **deviates from the frozen "Always" line** *"Invalid (state, event) pairs are no-ops that log a warning (never crash)"* — that line assumed session-style invalid transitions that don't exist here. The never-crash half is preserved structurally (total switch). Also applied: `makeContext` now reuses the existing `currentSession` accessor instead of re-open-coding the registry lookup. Rejected (pre-existing + not reachable through the paired present/dismiss UI wiring, and out of the frozen "PF-079 only" behaviour scope): the unguarded `Set.remove` in `foregroundReleased` and the resume-branch suspension guard — a same-destination re-appear never fires while that destination is suspended (help=sheet, macOS Settings=separate window, neither re-appears). Diagnostic-only divergences (soundSource log count, dropped conditional restart logs, `@Observable` coarsening, navigate `[weak self]`) accepted as harmless.

## Verification

**Commands:**
- `bin/test.sh && bin/test.sh -p mac` -- expected: full suite green on both platforms (never in parallel), including the new reduce matrix
- `bin/build.sh && bin/build.sh -p mac` -- expected: no errors/warnings
- `archlint Peach/` and `bin/check-dependencies.sh` -- expected: clean

**Manual checks (if no CLI):**
- iOS: start training, open Help, background the app, return — no audio plays behind the Help sheet; dismiss Help — training starts once
- iOS: start training, open Help, trigger an interruption (incoming call / disconnect AirPods), dismiss Help — training auto-starts (no dead screen)

## Suggested Review Order

**The decision core — the pure state machine**

- Entry point: the whole story is this pure reducer; read it against the original's imperative methods
  [`TrainingLifecycleCoordinator.swift:178`](../../Peach/App/TrainingLifecycleCoordinator.swift#L178)

- The PF-079 fix lives here: the `!isForegroundSuspended` auto-restart guard now applies on both platforms
  [`TrainingLifecycleCoordinator.swift:182`](../../Peach/App/TrainingLifecycleCoordinator.swift#L182)

- Pure helpers the reducer folds through — discard-paused / start / stop, where the double-stop originates
  [`TrainingLifecycleCoordinator.swift:312`](../../Peach/App/TrainingLifecycleCoordinator.swift#L312)

- State/Event/Effect/Context types — State is a struct (product state), not an enum
  [`TrainingLifecycleCoordinator.swift:119`](../../Peach/App/TrainingLifecycleCoordinator.swift#L119)

**The imperative edge — dispatch and effect interpretation**

- `send` collapsed to context→reduce→interpret (no dead warning); `makeContext` reads the one edge fact
  [`TrainingLifecycleCoordinator.swift:340`](../../Peach/App/TrainingLifecycleCoordinator.swift#L340)

- The interpreter maps effects to session/registry calls; async machinery stays here
  [`TrainingLifecycleCoordinator.swift:351`](../../Peach/App/TrainingLifecycleCoordinator.swift#L351)

- Navigation effect: the hardened `awaitIdle`/`SingleShotResumerBox` path, preserved verbatim
  [`TrainingLifecycleCoordinator.swift:501`](../../Peach/App/TrainingLifecycleCoordinator.swift#L501)

- Thin input methods funnel to `send`; edge-known logs restored (scene-phase stop, app activation)
  [`TrainingLifecycleCoordinator.swift:372`](../../Peach/App/TrainingLifecycleCoordinator.swift#L372)

**Tests — the exhaustive matrix and the PF interleavings**

- PF-079 pinned: return-active while suspended emits no start effect
  [`TrainingLifecycleReduceTests.swift:65`](../../PeachTests/App/TrainingLifecycleReduceTests.swift#L65)

- PF-049 and PF-050/079 interleavings as explicit multi-step reductions
  [`TrainingLifecycleReduceTests.swift:355`](../../PeachTests/App/TrainingLifecycleReduceTests.swift#L355)
