---
title: 'Story 85.3: Audit and harden the sequencer @Observable + Task concurrency contract'
type: 'cleanup'
created: '2026-06-05'
status: 'done'
baseline_commit: 'c52fa597'
context:
  - '{project-root}/docs/implementation-artifacts/deferred-work.md'
closes:
  - 'PF-011'
  - 'PF-013'
  - 'PF-047'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem.** PF-011 consolidates one concrete production-reachable race and one set of unverified concurrency invariants under a shared root cause: the sequencer's `@Observable`-plus-background-`Task` shape has accumulated cross-discipline sharers (CRM, TOD) and cross-task mutators without an explicit Sendable / actor-isolation contract. The strict-concurrency build is clean only because `BeatProvider` is not `Sendable` — strict concurrency isn't catching what it can't see.

The concrete reachable risk:

- **Stale `samplePosition` at new-trial start (Story 80.2 surface).** Between `beatSequencer.start(...)` returning on the main actor and the render thread resetting `engine.currentSamplePosition` to 0, the polling task may sample a stale large value. With `maxRepetitions == 1` and an unlucky 8 ms tick at the boundary, `completedCycles` already meets the cap before any audio is heard, immediately firing `.repetitionCapReached`. Reachable in production today; Epic 84 (which added TOD as a second sharer of the sequencer instance) raised the probability.

The unverified static shape:

- `BeatProvider` is not `Sendable`. The sequencer mutates `currentBeat` from a background `Task`. `ContinuousRhythmMatchingSession.gapPositions` is written from the sequencer's polling Task. Two independent adversarial reviewers (Blind hunter + Edge case hunter) flagged this as a latent data-race surface. Currently invisible to strict concurrency.
- **Cross-discipline serialization invariant.** TOD and CRM both call `beatSequencer.start(tempo:beatProvider:)` on the shared singleton. `TrainingLifecycleCoordinator` already serializes activations, but no test pins this contract — a future coordinator refactor could break it silently.
- **`SequencerEngine` conformance contract is unverified (PF-013).** Folded into this story because the audit reads the same surfaces: the only `SequencerEngine` conformers are `SoundFontEngine` (render-thread reset of `samplePosition` after a generation-change fence) and `MockSequencerEngine` (synchronous reset on `scheduleEvents()` / `clearSchedule()`). The semantics differ — observably so during the trial-start race the audit is investigating. The audit decides which Mock/Real divergences are load-bearing enough to pin by conformance tests, rather than designing a speculative contract suite in the abstract.
- **`TrainingLifecycleCoordinator.awaitIdle` read-then-suspend race (PF-047).** Folded into this story because the audit reads the same surface — `awaitIdle` is the mechanism behind the cross-discipline serialization invariant the audit is pinning. `awaitIdle` checks `!session.isIdle`, then installs a one-shot `withObservationTracking` observer; if `isIdle` flips between the check and the observer install, the loop suspends forever on a mutation that already happened. Not reachable today (real sessions transition to `isIdle` asynchronously through audio teardown), but structurally fragile. The catalog's three options — (a) re-check inside the observation block; (b) restructure with the newer `Observation` `observe { ... }` API; (c) document the synchronous-flip-forbidden caller contract — have meaningfully different concurrency-primitive implications, and the audit's concurrency consult is the right context to pick.

**Adjacent surface (audit-decides, PF-054).** Story 85.1 v2 (filed 2026-06-06) cataloged three uncoordinated MIDI dispatch paths into the shared `AVAudioUnitSampler`: (1) direct MainActor dispatch (`startNote`/`stopNote`/`sendController`/`sendPitchBend`); (2) sample-accurate scheduled queue drained by the render thread; (3) render-thread flag-driven `needsAllNotesOff` reset. The audit will inevitably read this surface when mapping `SoundFontEngine`'s Sendable contract. PF-054 is **not in 85.3's `closes:` list** — its resolution candidates include a substantial unification refactor. The audit reports whether PF-054's three-path shape is reachable as a data-race in current code; if yes, presents the smallest mitigation that fits 85.3's scope and pauses for human Ask-First; if no, the finding is bounced back to PF-054 with the audit's evidence documented inline.

**Approach.** Two-phase: audit, then fix.

1. **Audit** — invoke `/swift-concurrency-expert` (and optionally `/avdlee-swift-concurrency` as a second lens) on `BeatProvider`, `SoundFontBeatSequencer`, `ContinuousRhythmMatchingSession.gapPositionInCurrentBeat` / `currentBeatPosition` / `lastPublishedSubdivisionIndex` writers, `TimingOffsetDetectionSession.lastPublishedSubdivisionIndex` / `litDotCount` writers, `TrainingLifecycleCoordinator`'s session-activation serialization, `TrainingLifecycleCoordinator.awaitIdle`'s `withObservationTracking` shape, the `SoundFontPlayer.scheduleStopAll()` synchronous-commit serial chain (and the cancelled-trial cleanup catch in `NotePlayer+TimedPlay.swift` that 85.1 v2 removed from the chain), `SoundFontPlaybackHandle.stop`'s audio-queue routing, and the three-path MIDI dispatch surface on `SoundFontEngine` (PF-054). The audit produces: a Sendable / actor-isolation map of the current shape; a list of concrete data-race or memory-ordering risks beyond the known one; a recommendation per risk (document-as-contract / add-test / refactor); an explicit pick between the catalog's three trial-start-race options — (a) document the post-`start()` reset latency as a `BeatSequencer` contract with a coordinator-level test; (b) anchor TOD's `globalSubdivisionIndex` to a per-trial baseline `samplePosition` captured at start; (c) extend `BeatSequencer.timing` with a "trial-relative sample position" accessor; and an explicit pick between PF-047's three options — (a) re-check `session.isIdle` inside the `withObservationTracking` block before suspending; (b) restructure with the newer `Observation` `observe { ... }` API; (c) document the synchronous-flip-forbidden caller contract on `awaitIdle`.

2. **Fix** — apply the audit's recommendations. The maxReps=1 race is the must-close item; everything else is conditional on what the audit surfaces.

**Design principle.** Mechanism/policy separation per [[feedback_design_by_contract_and_separation]] — applied at the concurrency contract layer: each component's actor-isolation responsibility is named explicitly in the audit output; the coordinator's serialization invariant is a documented and tested contract rather than an emergent property of activation timing.

## Boundaries & Constraints

**Always:**
- PF-011, PF-013, and PF-047 are closed by this story or their scope is renegotiated with explicit human authorization.
- The maxReps=1 trial-start race is fixed with a regression test that demonstrates the failure mode against the audit's chosen mitigation — written first, then made to pass by the implementation.
- The cross-discipline serialization invariant gains a coordinator-level test pinning "the previous session has fully stopped before the next starts."
- BeatProvider, SoundFontBeatSequencer, and the two session polling paths land with an explicit Sendable / actor-isolation contract — at minimum documented in code comments; potentially enforced by Sendable conformance and actor isolation if the audit recommends it.
- For PF-013: if the audit identifies concrete behavioural divergences between `MockSequencerEngine` and `SoundFontEngine` under the invariants in scope (start/stop ordering, post-clear silence, sample-position reset semantics), those divergences are pinned by a focused conformance test suite that runs both implementations through the affected invariants. If the audit identifies no load-bearing divergence, the finding is documented and PF-013 closes with that documentation as its resolution.
- For PF-047: `TrainingLifecycleCoordinator.awaitIdle` is restructured or annotated per the audit's pick from the three options. If options (a) or (b) — code change — a unit test pins the synchronous-`isIdle = true` case (the failure mode the catalog entry describes) against the new implementation. If option (c) — documentation only — the caller-contract doc-comment names the invariant and the audit's rationale for not enforcing it structurally.
- Pre-commit gate: `bin/test.sh && bin/test.sh -p mac` AND `bin/test.sh --research && bin/test.sh --research -p mac` green.
- Catalog hygiene on merge: remove PF-011, PF-013, and PF-047 sections from `deferred-work.md` in the same change; cite all three IDs in the commit message.

**Ask First:**
- If the audit surfaces additional concrete data-race or memory-ordering risks beyond PF-011's known set — pause and present findings before scoping how many to address in this story versus filing new `PF-###` entries.
- If the audit recommends a contract change to the `BeatSequencer` protocol or `BeatProvider` shape (versus an additive contract via comments/tests), pause and confirm the protocol shape before implementing.
- If the audit endorses option (c) — adding a "trial-relative sample position" accessor — that's a new API surface and warrants a separate Ask-First before adding it.
- If the audit concludes the maxReps=1 race is already mitigated by something not visible in the catalog entry, pause and confirm before either writing a test for a non-bug or closing PF-011 as misclassified.

**Never:**
- No new actor or concurrency-primitive introductions unless the audit explicitly endorses them.
- No refactor of `TrainingLifecycleCoordinator`'s session-activation flow beyond adding the contract test and the PF-047 `awaitIdle` change (Story 85.1 owns the lifecycle policy consolidation; the boundary between these stories must be respected — `awaitIdle`'s internal mechanism is fair game, the activation-flow shape is not).
- No introduction of new `@AppStorage` or persistence work. Concurrency-only changes.

## I/O & Edge-Case Matrix

Filled to the closure level; the audit (Task 1) may extend this with newly-surfaced risks.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| New TOD trial with `maxRepetitions == 1` (PF-011 reachable race) | Trial starts; render thread takes >0 ms to reset `samplePosition` to 0 | Polling task does not observe stale `samplePosition`; `.repetitionCapReached` does not fire before any audio is heard | Asserted by regression test against the audit's chosen mitigation |
| Cross-discipline session transition (cross-discipline serialization invariant) | Active CRM session; user navigates to TOD | Coordinator stops CRM and waits for fully-idle before starting TOD; no overlapping `beatSequencer.start(...)` invocations | Asserted by coordinator-level contract test |
| `awaitIdle` synchronous `isIdle = true` (PF-047) | `awaitIdle(of:)` called; `session.isIdle` flips to `true` between the while-check and the observer install | `awaitIdle` returns instead of suspending indefinitely | Asserted by unit test against the audit's chosen mitigation (options a/b); doc-only under option c with a caller-contract test added to whichever caller can enforce the invariant |
| New CRM trial after the maxReps fix (regression sanity) | CRM trial starts with standard `maxRepetitions` | Behaviour unchanged from `baseline_commit`; existing CRM trial-progression tests still pass | N/A |
| Strict-concurrency build (post-audit Sendable contract) | Both Debug and Research schemes | Build remains clean; new `Sendable` / actor-isolation annotations (if any) compile without warnings | N/A |

</frozen-after-approval>

## Code Map

**Deliberately empty pre-verification.** Task 1's audit produces the verified code map and appends it here. Catalog-referenced surfaces:

- `BeatProvider` protocol (Sendable status)
- `Peach/Core/Audio/SoundFontBeatSequencer.swift` — `currentBeat` mutator, polling Task, timing snapshot
- `Peach/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift` — `evaluatePlaybackPosition` polling Task, `gapPositionInCurrentBeat` / `currentBeatPosition` / `lastPublishedSubdivisionIndex` writers
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift` — `evaluatePlaybackPosition` polling Task, `litDotCount` / `lastPublishedSubdivisionIndex` writers
- `Peach/App/TrainingLifecycleCoordinator.swift` — session-activation serialization path (handover between sessions); `awaitIdle`'s while-then-`withObservationTracking` shape (PF-047); post-85.1 routing (`stopCurrentSession`, scenePhase, `helpSheetPresented/Dismissed`, `navigate(to:)`, `handleSoundSourceChanged`)
- `Peach/Core/Audio/SoundFontPlayer.swift` — `scheduleStopAll() -> Task<Void, Never>` synchronous-commit serial chain (post-85.1); chain-tail capture on `play()`; the documented invariant *"synchronous-commit only enforces order on synchronous code paths"* — async-continuation callers must not register redundant chain entries
- `Peach/Core/Audio/SoundFontPlaybackHandle.swift` — `stop` routed through the audio queue (post-85.1)
- `Peach/Core/Audio/NotePlayer+TimedPlay.swift` — cancelled-trial cleanup catch (85.1 v2 removed `handle.stop()` from this path; audit confirms no further chain entries are reintroduced from async continuations)
- Possibly `Peach/Core/Audio/SoundFontEngine.swift` — render-thread `samplePosition` reset, generation-change fence; PF-054's three MIDI dispatch paths (direct MainActor, scheduled queue, render-thread flag) — audit-decides per Intent

**Added during verification (scope discovery):**

- `Peach/Core/Ports/BeatSequencer.swift` — protocol; not Sendable, no isolation annotation. Conformer `SoundFontBeatSequencer` lives in `Peach/Core/Audio/SoundFontBeatSequencer.swift` and is MainActor-isolated by project default. Polling-Task closure inherits MainActor.
- `Peach/Core/Audio/SequencerTypes.swift` — `BeatProvider` protocol declared without `Sendable`; nested types `Beat`/`Subdivision` are `Sendable`; `SequencerTiming` is `Sendable` (value type). Confirms PF-011's "BeatProvider not Sendable" framing; under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` the conformers (sessions) are MainActor-isolated so the strict-concurrency build stays clean — strict concurrency can't see what it can't see, per Intent.
- `Peach/Core/TrainingSession.swift` — `TrainingSession` protocol uses synchronous `isIdle: Bool { get }`. Critical for PF-047's race-shape analysis.
- `Peach/Core/Training/SessionLifecycle.swift` — `SessionLifecycle` is MainActor by project default; `cancelAllTasks()` is synchronous; no Sendable concerns surfaced.
- `Peach/Core/Ports/NotePlayer.swift` — protocol; `scheduleStopAll() -> Task<Void, Never>` invariant doc-comment already articulates the synchronous-commit contract relevant to PF-054/85.1 v2.
- `Peach/Training/PitchMatching/PitchMatchingSession.swift:377` and `:441-443` — `Task { try? await handle.stop() }` deferred from already-async contexts; these are async-cleanup paths that re-register chain entries on `SoundFontPlayer`'s serial queue, violating the invariant documented in [`project-context.md:84`](../project-context.md). New finding; see Audit Findings § E.
- `Peach/App/PeachApp.swift:177-215` (`handleSoundSourceChanged`) — exercises the cross-discipline serialization invariant from a different angle: stops every non-idle session synchronously, but does NOT await idle before `rebuildCoordinators()`. New finding; see Audit Findings § E.
- `PeachTests/Mocks/MockSequencerEngine.swift` — synchronous `currentSamplePosition = 0` reset inside `scheduleEvents`/`clearSchedule`; load-bearing divergence vs the real engine's deferred render-thread reset (PF-013).
- Project build setting `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (Swift 6.2) — load-bearing context for the entire audit. Every type/closure/Task created in project files inherits MainActor unless explicitly `nonisolated`. The Tasks inside `SoundFontBeatSequencer`, `ContinuousRhythmMatchingSession`, `TimingOffsetDetectionSession` are MainActor-isolated, eliminating data races on their `@Observable` state writes by isolation rather than by Sendable conformance.

## Code Map (verified)

| Surface | File | MainActor | Sendable | Notes |
|---|---|---|---|---|
| `BeatProvider` | `Peach/Core/Audio/SequencerTypes.swift:21` | conformers are MainActor | NOT Sendable | Crosses `start(tempo:beatProvider:)` boundary; safe under default-MainActor since `nextBeat()` is invoked synchronously from MainActor on the polling-Task scheduling path; the protocol cannot be `Sendable` while conformers are MainActor classes mutating non-Sendable trial state. Verified. |
| `BeatSequencer` | `Peach/Core/Ports/BeatSequencer.swift:1` | conformer is MainActor | not declared Sendable | `start/stop` are `async throws`; `playImmediateNote/samplePosition(forHostTime:)` are sync. Sole conformer: `SoundFontBeatSequencer`. |
| `SoundFontBeatSequencer.currentBeat` | `Peach/Core/Audio/SoundFontBeatSequencer.swift:55` | MainActor (impl. via default isolation) | n/a | Mutated by polling Task at line 119 (MainActor). Read by SwiftUI on MainActor. **No data race** under current isolation; risk is logical reentrancy at `Task.sleep` boundaries. |
| `SoundFontBeatSequencer.timing` | `Peach/Core/Audio/SoundFontBeatSequencer.swift:61-67` | MainActor | `SequencerTiming` is Sendable | Reads `engine.currentSamplePosition` (acquire-load on `Atomic<Int64>`) + MainActor-isolated `samplesPerBeat`. Safe. |
| `SoundFontBeatSequencer.runLoopTask` | `Peach/Core/Audio/SoundFontBeatSequencer.swift:71, 110, 151-153` | MainActor | n/a | The closure inherits MainActor; the `engine.currentSamplePosition` reads are cross-thread but atomic-acquire. Logical races (not data races) at the `await Task.sleep` boundary — see Risks §1/§2. |
| `ContinuousRhythmMatchingSession` writers | `Peach/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift` (`gapPositionInCurrentBeat:316`, `currentBeatPosition:310`, `lastPublishedSubdivisionIndex:311`, `gapPositions:270`) | MainActor | n/a | All writers run from MainActor (state-machine effects + polling Task closure). No data race. PF-011's catalog claim "gapPositions written from the sequencer's polling Task" is partially accurate: `gapPositions.append(...)` happens inside `nextBeat()`, called by the sequencer's `buildBatch(...)` on the MainActor stack of `start()` and of the subsequent re-fill on the polling Task; both still on MainActor. Safe by isolation, not by Sendable. |
| `TimingOffsetDetectionSession` writers | `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift` (`litDotCount:407`, `lastPublishedSubdivisionIndex:408`) | MainActor | n/a | All writers run from MainActor. `globalSubdivisionIndex` computation against `samplePosition` is at line 385 — direct stale-read risk per PF-011, see Risks §1. |
| `TrainingLifecycleCoordinator` | `Peach/App/TrainingLifecycleCoordinator.swift` | MainActor | n/a | Activation serialization in `navigate(to:)` (lines 191-203) relies on `await awaitIdle(of:)`; `awaitIdle` uses `withObservationTracking` (lines 205-215). See Risks §3/§5. |
| `SoundFontPlayer.pendingAudioStop` | `Peach/Core/Audio/SoundFontPlayer.swift:39` | MainActor | `Task<Void, Never>` is Sendable | Synchronous-commit serial chain. Invariant doc on the protocol (`Peach/Core/Ports/NotePlayer.swift:8-16`) and on `project-context.md:84`. Verified. |
| `SoundFontPlaybackHandle.hasStopped` | `Peach/Core/Audio/SoundFontPlaybackHandle.swift:13` | MainActor | n/a | First-call latch; second concurrent stop is a no-op. Safe. |
| `NotePlayer+TimedPlay.swift` cancellation catch | `Peach/Core/Audio/NotePlayer+TimedPlay.swift:12-14` | MainActor | n/a | Explicit `catch CancellationError` only re-throws; does NOT call `handle.stop()`. Verified clean per the 85.1 v2 removal; comment on line 13 documents the invariant. |
| `SoundFontEngine` | `Peach/Core/Audio/SoundFontEngine.swift:219` | explicit `@MainActor` | n/a | Render block is `@Sendable` and uses `DoubleBufferedScheduleState` (`@unchecked Sendable`) for SPSC + release/acquire fences. Per-channel volume mute uses `activeMuteCount` reference counter (MainActor only). |
| `DoubleBufferedScheduleState` | `Peach/Core/Audio/SoundFontEngine.swift:45` | `nonisolated` + `@unchecked Sendable` | unchecked | All cross-thread state is `Atomic<...>`. Reset flag `needsAllNotesOff` uses `.relaxed` ordering; visibility rides the generation counter's `.releasing` store + `.acquiring` load. Documented invariant on lines 36-44. |
| `SequencerEngine` protocol | `Peach/Core/Audio/SoundFontBeatSequencer.swift:6-18` | n/a | not declared Sendable | Conformers: `SoundFontEngine` (MainActor), `MockSequencerEngine` (MainActor). Behavioural divergence on sample-position reset semantics — see Findings § C. |

## Tasks & Acceptance

**Execution:**

- [x] **Task 1 — Audit (must complete and review before any code change).** Invoke `/swift-concurrency-expert` (and optionally `/avdlee-swift-concurrency` as a second lens) against the surfaces cited above. Produce: (a) a Sendable / actor-isolation map of the current shape; (b) a list of concrete data-race or memory-ordering risks, each with severity and whether reachable in production; (c) per risk, a recommendation — document-as-contract / add-test / refactor — naming the smallest change that closes it; (d) an explicit pick from the catalog's three trial-start-race options (a/b/c) with rationale. Append the output as a new `Code Map` and `Audit Findings` section above. **Halt for human review before Task 2.** Per `[[feedback_ask_dont_assume]]`.
- [x] **Task 2 — Approach lock-in (post-audit).** Based on the audit, finalise: (a) the exact mitigation for the maxReps=1 trial-start race; (b) the shape of the cross-discipline serialization contract test; (c) the Sendable / actor-isolation annotations (if any) the audit recommends; (d) any additional `PF-###` entries to file for risks beyond this story's scope. Update Boundaries & Constraints if Ask-First conditions triggered.
- [x] **Task 3 — Regression test for the trial-start race.** Tests-first: write a test that reproduces the maxReps=1 race against `baseline_commit` (proving the bug) and then passes after Task 4 lands the mitigation. The test exercises the polling-task path the audit identified, with an injected delay or controlled `samplePosition` to make the race deterministic.
- [x] **Task 4 — Apply the trial-start-race mitigation.** Implement the audit-chosen option (a, b, or c). The regression test from Task 3 passes; existing tests stay green.
- [x] **Task 5 — Coordinator serialization contract test + CRM stop-path symmetry fix (folds in audit finding (c)).** Add a `TrainingLifecycleCoordinatorTests` case pinning "the previous session has fully stopped before the next starts" — exercises the CRM → TOD handover and asserts no overlapping `beatSequencer.start(...)` invocations. The contract test exposes CRM's fire-and-forget `stopAll` (`ContinuousRhythmMatchingSession.swift:480-482`) — extract a CRM `enqueueSequencerStop` method mirroring TOD's pattern (`TimingOffsetDetectionSession.swift:528-547`), and have CRM's `stopAll` route through it. The contract test asserts CRM and TOD share the same stop-then-start serialization shape.
- [x] **Task 6 — Sendable / actor-isolation contract.** Apply the audit's recommendations on the protocol and session-state shapes. Document any contract that stays as a comment-only assertion (i.e., not enforced by Sendable) with the rationale.
- [x] **Task 7 — `SequencerEngine` conformance (conditional, PF-013).** If the audit (Task 1) identified concrete behavioural divergences between `MockSequencerEngine` and `SoundFontEngine` under the invariants in scope, add a focused conformance test suite that runs both implementations through the affected invariants. If no load-bearing divergence was identified, instead append a `SequencerEngine` conformance-contract section to the protocol's doc comment summarising the audit's finding (i.e., "the contracts agree at points X, Y, Z"). Either way, PF-013 is closed.
- [x] **Task 8 — `awaitIdle` race fix (PF-047).** Apply the audit-chosen option for PF-047 — (a) re-check inside the observation block, (b) restructure with the newer `Observation` `observe { ... }` API, or (c) document the synchronous-flip-forbidden caller contract. If (a) or (b), add a unit test that exercises the synchronous-`isIdle = true` case the catalog entry describes — the test must hang against `baseline_commit` (proving the bug) and pass after the implementation lands. If (c), name the invariant inline on `awaitIdle`'s doc-comment with the audit's rationale.
- [x] **Task 9 — Catalog hygiene.** Remove the PF-011, PF-013, and PF-047 sections from `docs/implementation-artifacts/deferred-work.md`. New PF entries from audit findings (a) and (b) — **PF-058** (PitchMatchingSession deferred `handle.stop()` chain-registration violation) and **PF-059** (`handleSoundSourceChanged` synchronous stop without awaiting idle) — were filed on 2026-06-06 during Task 2 lock-in; verify they remain in the catalog after merge. PF-054 stays open per audit verdict (bounce). Cite PF-011, PF-013, and PF-047 in the commit message, plus PF-054 (inline gating comment added) and PF-058/PF-059 (filed).
- [x] **Task 10 — Pre-commit gates.** Run `bin/test.sh && bin/test.sh -p mac` and `bin/test.sh --research && bin/test.sh --research -p mac`. All four green. Initial post-implementation results: iOS Debug 1966 / macOS Debug 1960 / iOS Research 2127 / macOS Research 2121. Post-review-patch re-run: iOS Debug 1965 / macOS Debug 1959 / iOS Research 2126 / macOS Research 2120 — count drop of 1 each scheme corresponds to Patch 4 retiring the real-engine `realEngineRapidReEntryExposesFinalScheduleCount` test (converted to documentation per consistent treatment with Group 1 / Group 2). Ran sequentially per [[feedback_test_sh_no_parallel]].

**Acceptance Criteria:**

- **PF-011 trial-start race.** Given a TOD trial with `maxRepetitions == 1`, when the trial starts, then `.repetitionCapReached` does not fire before any audible note is produced (asserted by regression test).
- **PF-011 cross-discipline serialization.** Given an active CRM session, when the user navigates to TOD, then `TrainingLifecycleCoordinator` stops CRM and waits for fully-idle before starting TOD (asserted by coordinator-level contract test); no overlapping `beatSequencer.start(...)` invocations occur.
- **PF-011 Sendable / actor-isolation contract.** Sequencer + session polling paths have an explicit concurrency contract — either documented inline with rationale or enforced by Sendable / actor annotations per the audit's recommendation.
- **PF-013 conformance contract.** Either: (a) a focused conformance test suite exercises `MockSequencerEngine` and `SoundFontEngine` through every audit-identified divergent invariant and passes on both, OR (b) the audit's finding that no load-bearing divergences exist is documented inline on the `SequencerEngine` protocol's doc comment with a summary of the invariants the audit checked. Either path closes PF-013.
- **PF-047 `awaitIdle` race.** Given `awaitIdle(of:)` is invoked and `session.isIdle` flips to `true` between the while-check and the observer install, when the audit's chosen mitigation is in place, then `awaitIdle` returns instead of suspending indefinitely (asserted by unit test under options a/b; documented inline with caller-contract rationale under option c).
- **Existing behavior parity.** All existing CRM and TOD tests pass without modification. Strict-concurrency build remains clean on both schemes.
- **Pre-commit gate.** All four schemes green: Debug × {iOS, macOS} and Research × {iOS, macOS}. No new compiler warnings.
- **Catalog hygiene.** PF-011, PF-013, and PF-047 sections removed from `deferred-work.md` in the closing commit; any audit-surfaced new findings filed as new `PF-###` entries.

## Audit Findings

Produced by Task 1 against baseline `c52fa597`. Source surfaces verified as listed in the Code Map (verified) section. Concurrency analysis grounded in current Swift 6.2 + `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` semantics; control-plane RT-audio reasoning grounded in [the 2026-06-06 RT-audio research record](../planning-artifacts/research/technical-rt-audio-control-plane-2026-06-06.md).

### A. Sendable / actor-isolation map

See Code Map (verified) above for the surface-by-surface table. Headline observations:

1. **Default-MainActor isolation is the load-bearing safety mechanism.** The project's `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` build setting makes every closure and unstructured `Task { ... }` in project sources MainActor-isolated unless explicitly `nonisolated`. The polling Tasks in `SoundFontBeatSequencer`, `ContinuousRhythmMatchingSession`, and `TimingOffsetDetectionSession` therefore run on MainActor — their writes to `@Observable` state (e.g., `currentBeat`, `gapPositionInCurrentBeat`, `litDotCount`) are NOT cross-actor and NOT data races. PF-011's framing "the sequencer mutates `currentBeat` from a background `Task`" is technically inaccurate under the current build configuration: the Task is MainActor-bound; the threading hazard is logical reentrancy at `await Task.sleep` boundaries, not a TSan-class data race.

2. **`BeatProvider` not being `Sendable` is structurally correct under current isolation.** Conformers (`ContinuousRhythmMatchingSession`, `TimingOffsetDetectionSession`) are MainActor classes with non-Sendable mutable state (`gapPositions: [BeatPosition]`, `currentTrial`, etc.). Marking `BeatProvider: Sendable` would require either (i) introducing actor isolation on the conformers (incompatible with their `@Observable` SwiftUI integration) or (ii) marking the conformers `@unchecked Sendable` (defeats the analysis). The right contract today is: `BeatProvider.nextBeat()` is only invoked synchronously from MainActor; documented inline, not enforced by Sendable.

3. **`SoundFontEngine`'s cross-thread surface is correctly engineered.** All render-thread-shared state lives inside `DoubleBufferedScheduleState` (`@unchecked Sendable`, MainActor unrelated), accessed via `Atomic<...>` with documented release/acquire ordering riding the generation counter. The render block is `@Sendable`. The `nonisolated` MIDI byte helper is real-time-safe (stack temporary allocation). The audit found NO data-race shape here under the in-scope invariants.

4. **`SoundFontPlayer.scheduleStopAll()` chain invariant is currently held in pitch playback, partially violated in `PitchMatchingSession`.** The invariant: "Synchronous-commit only enforces order on synchronous code paths" — async-cleanup continuations must NOT register additional chain entries. Verified clean in `NotePlayer+TimedPlay.swift:12-14` (cancellation catch does NOT call `handle.stop()`). VIOLATED in `PitchMatchingSession.swift:377` and `:441-443` where `Task { try? await handle.stop() }` is fire-and-forget from inside the session's MainActor-isolated state machine, registering a deferred-commit chain entry. See Risks § 6.

### B. Concrete data-race / memory-ordering risks

#### Risk 1 — PF-011 trial-start race against stale `samplePosition` — **reachable in production**

- **Mechanism.** `SoundFontBeatSequencer.start(tempo:beatProvider:)` returns on MainActor after `engine.scheduleEvents(batch.events)` (line 96) and `runLoopTask = Task { ... }` (line 110). The render thread observes the generation bump on its NEXT callback, at which point it stores `samplePosition = 0` (line 629 of `SoundFontEngine.swift`). Between the polling Task's first iteration (`engine.currentSamplePosition` read at line 115 of `SoundFontBeatSequencer.swift`) and the render thread's deferred reset, the polling Task reads the stale large value from the previous run.
- **In TOD** (`TimingOffsetDetectionSession.evaluatePlaybackPosition` line 385): `globalSubdivisionIndex = Int(timing.samplePosition / samplesPerSubdivision)` → huge; `completedCycles = globalSubdivisionIndex / subdivisionsPerBeat` → exceeds `maxRepetitions == 1` → fires `.repetitionCapReached` immediately, before any audible note.
- **In CRM** (`ContinuousRhythmMatchingSession.evaluatePlaybackPosition` line 296): `playingCycleIndex = Int(timing.samplePosition / timing.samplesPerBeat)` → huge; the `while lastEvaluatedCycleIndex < playingCycleIndex - 1` loop at line 320 fires 16 `cycleMissed` events in one tick, completing the trial silently. Same shape, different exit symptom.
- **Reachable today:** YES. Under Epic 84's TOD sharer + Story 80.2 reproduction conditions, an 8 ms polling tick can land before the render thread observes the gen bump. Probability is non-zero on all device classes.
- **Severity:** Medium-high.
- **Recommendation:** REFACTOR (small) + ADD-TEST + DOCUMENT-AS-CONTRACT (combined). See § C for option pick.

#### Risk 2 — Cross-discipline serialization gap on session handover — **reachable in production**

- **Mechanism.** `TrainingLifecycleCoordinator.navigate(to:)` (lines 191-203) calls `session.stop()` then awaits `awaitIdle(of: session)`. The session's reducer sets `state = .idle` synchronously inside `send(.stopRequested)`, so `isIdle` flips to `true` BEFORE `interpret(.stopAll) → stopAll() → Task { try? await beatSequencer.stop() }` has finished. `awaitIdle` therefore returns while the fire-and-forget `beatSequencer.stop()` Task is still in flight. If the new session's `beatSequencer.start(...)` lands during that window, the only thing preventing collision is the defensive `try await stop()` at the head of `SoundFontBeatSequencer.start()` (line 84).
- **Concrete failure shape:** A CRM → TOD handover where the outgoing CRM `stopAll`'s deferred `beatSequencer.stop()` is mid-`engine.stopNotes(...)` (which awaits fade-out) while TOD's `beatSequencer.start()` runs. Interleaving at `await` points lets TOD's `engine.scheduleEvents(...)` install a new schedule, then CRM's deferred stop's `engine.clearSchedule()` could land AFTER, wiping TOD's freshly-installed schedule. (The defensive `try await stop()` in `start()` mitigates by re-stopping before installing — but its `engine.clearSchedule()` THEN runs before the new `scheduleEvents`, so the dangerous interleaving requires CRM's deferred stop's `clearSchedule` to land DURING TOD's `start`'s post-`stop`-pre-`scheduleEvents` window. Narrow but reachable.)
- **Reachable today:** YES, narrow window.
- **Severity:** Medium.
- **Recommendation:** ADD-TEST (coordinator contract test pinning "previous session has fully stopped before next starts") + REFACTOR (small) — `TrainingSession.stop()` should expose an awaitable form OR `awaitIdle` should wait for both `isIdle` AND any in-flight `pendingSequencerStop`-equivalent. Smallest change: have CRM/TOD `stopAll()` chain its `beatSequencer.stop()` work onto a session-owned `stopTask` (TOD already does this via `enqueueSequencerStop`; CRM does NOT — see also Risk 2b).

#### Risk 2b — CRM's `stopAll` fire-and-forget — **reachable in production, sub-case of Risk 2**

- **Mechanism.** `ContinuousRhythmMatchingSession.stopAll()` (line 480-482): `Task { try? await beatSequencer.stop() }` — no chaining, no waiting. Compare TOD's `enqueueSequencerStop()` (line 528-547) which awaits the previous stop, cancels-and-awaits any in-flight `startTask`, then calls `beatSequencer.stop()`.
- **Reachable today:** YES. CRM rapid stop→start (e.g., reset button) can race the in-flight stop against the new start.
- **Severity:** Low-medium (CRM has fewer rapid-handover paths than TOD).
- **Recommendation:** REFACTOR — mirror TOD's `enqueueSequencerStop` pattern in CRM. Small consolidation. Closes the gap symmetrically.

#### Risk 3 — PF-047 `awaitIdle` race between while-check and observer install — **NOT reachable today**

- **Mechanism per catalog.** Catalog entry frames the race as: `isIdle` flips between `while !session.isIdle` and the `withObservationTracking` observer install. The audit verified that under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, both the while-check AND the observer install run in the same MainActor turn (no `await` between them). `TrainingSession.isIdle` is a synchronous computed property (`var isIdle: Bool { state == .idle }`); reading it does not yield MainActor. **Therefore no other code can mutate `state` between the check and the observer install.** The race shape requires an actor hop that the current code does not provide.
- **Catalog's reasoning was misframed.** The catalog says "Production does not currently exercise this race: `session.stop()` returns synchronously while the actual idle transition happens asynchronously through real audio teardown." Audit verification: TOD and CRM `isIdle` flips SYNCHRONOUSLY inside the reducer (`state = .idle` at TOD line 77, CRM line 65). The catalog's described shielding ("async audio teardown") is the opposite of what's happening. The actual shielding is "all on MainActor in the same actor turn, no `await` between read and observer install." The risk shape the catalog describes is structurally impossible while `isIdle` remains a synchronous MainActor-readable property.
- **Reachable today:** NO.
- **Severity:** Low (structural fragility only — if `isIdle` were ever to gain an `await`, the race window opens).
- **Recommendation:** REFACTOR (defensive 3-line change) per § C for option pick. See § C for option (a) rationale.

#### Risk 4 — PF-054 three-path MIDI dispatch surface — **NOT reachable today, structurally fragile**

- **Mechanism.** Three uncoordinated dispatch paths into the shared `AVAudioUnitSampler` MIDI input (see catalog PF-054 + research record). Path 1 (direct MainActor: `sampler.startNote/stopNote/sendController/sendPitchBend`) is currently isolated to pitch playback (`SoundFontPlayer`, `SoundFontPlaybackHandle`, `SoundFontEngine.stopNotes`). Paths 2 (sample-accurate scheduled queue) and 3 (render-thread CC#123 reset flag) are currently isolated to rhythm playback (`SoundFontBeatSequencer` via `engine.scheduleEvents/clearSchedule`).
- **The race the catalog warns about** — a pitch path-1 `startNote` racing the render thread's path-3 CC#123 reset — required pitch's `scheduleStopAll` to call `engine.clearSchedule()`. Story 85.1 v2 (commit `73ff62f3`) removed that call. Verified at `Peach/Core/Audio/SoundFontPlayer.swift:77`: "Don't call clearSchedule: pitch never schedules events, and the deferred render-thread CC#123 it triggers would race a subsequent play()'s noteOn." 85.1 v2 also removed `handle.stop()` from `NotePlayer+TimedPlay.swift`'s cancellation catch — verified at `Peach/Core/Audio/NotePlayer+TimedPlay.swift:12-14`.
- **Concurrency gating.** The `activeSession` invariant in `PeachApp.trackActiveSession` (line 163-173) stops any non-idle session before letting another become active, so rhythm path-3 and pitch path-1 are not concurrently active. A future feature introducing co-active dispatch (e.g., pitch reference during rhythm training) would re-open the race.
- **Reachable today:** NO (gated by activeSession invariant + 85.1 v2 removals).
- **Severity:** Low today; latent debt remains.
- **Recommendation:** BOUNCE TO PF-054 with this evidence. Inline a brief invariant comment near `SoundFontEngine.scheduleEvents` and `clearSchedule` naming PF-054 and the activeSession gating that holds the current safety. NO refactor within 85.3. The unified-FIFO refactor (research record F6) remains the right answer if a 4th caller is contemplated OR the underlying `auAudioUnit.reset()` crash root cause is investigated. Both are out of 85.3 scope.

#### Risk 5 — Post-85.1 async-continuation chain-registration invariant violation in `PitchMatchingSession` — **reachable, conditional**

- **Mechanism.** `Peach/Training/PitchMatching/PitchMatchingSession.swift:377` and `:441-443` spawn `Task { try? await handle.stop() }` from inside the session's MainActor-isolated effect interpreter or `stopAll`. Per the invariant on `project-context.md:84`: "From an async cleanup continuation … cleanup paths in async continuations must NOT register additional chain entries that are already redundant with the session-level stop."
- The `handle.stop()` call routes through `SoundFontPlaybackHandle.stop()` → `player.scheduleNoteStop(midiNote:)`, which registers a fresh entry on `SoundFontPlayer.pendingAudioStop`. The session-level `scheduleStopAll()` (line 425) already committed an earlier chain entry that silences the same note via global `stopNotes`. When the deferred `handle.stop()` Task body runs in a later MainActor turn, `hasStopped` is still `false` (no prior stop on this specific handle), so it registers — chain becomes `[scheduleStopAll, handleStop]`. The handleStop's `muteForFade` re-engages `activeMuteCount`, silencing any concurrent `play()` that lands during the mute window. Same shape as the 85.1 v2 NotePlayer+TimedPlay race.
- **Reachable today:** CONDITIONAL — fires only when the session is stopped while a tunable note is sounding AND the user re-enters a pitch session quickly (within the mute window). Probability non-trivial on rapid pause/resume.
- **Severity:** Medium (reproduces the symptom 85.1 v2 was designed to eliminate, in a different surface).
- **Recommendation:** REFACTOR — apply the same pattern that closed 85.1 v2: route session-level stops exclusively through `scheduleStopAll()` (which calls `stopNotes` globally), drop the deferred `handle.stop()` calls. The handle's specific note will be silenced by the global `stopNotes`. `currentHandle = nil` is sufficient bookkeeping. This is a NEW finding outside PF-011/013/047/054's scope — see § E.

#### Risk 6 — `handleSoundSourceChanged` synchronous stop without awaiting idle — **reachable in production**

- **Mechanism.** `Peach/App/PeachApp.swift:177-215`: `handleSoundSourceChanged` calls `session.stop()` synchronously on each non-idle session, then immediately constructs a new `SoundFontPlayer`, replaces session instances, and calls `rebuildCoordinators()`. The old sessions' fire-and-forget `Task { await beatSequencer.stop() }` (CRM) or `enqueueSequencerStop` (TOD) is still in flight; the new sessions begin observing the new (replaced) sequencer/notePlayer. Old in-flight stops may complete after the rebuild, possibly clearing or muting the new graph.
- **Reachable today:** YES, narrow window. Only fires if the user changes Sound Source while a session is active.
- **Severity:** Low (single-user-action surface; symptom is a one-shot audio glitch).
- **Recommendation:** REFACTOR (small) — `handleSoundSourceChanged` should `await` each session's idle state before rebuilding. Alternative: the deferred sequencer-stop Tasks should be awaitable from the orchestrator. NEW finding outside PF-011/013/047/054's scope — see § E. Optionally fold into Risk 2's coordinator serialization contract test.

### C. Explicit picks (with rationale)

#### PF-011 trial-start-race option — pick **(a)** "document the post-`start()` reset latency as a `BeatSequencer` contract with a coordinator-level test"

**Rationale.** Options (b) and (c) trigger Ask-First per spec Boundaries & Constraints (new accessor / API surface change). Option (a) is purely additive: it documents the contract that `BeatSequencer.start(...)` does NOT guarantee `timing.samplePosition` is reset on return — the render thread's deferred reset means callers MUST gate cap-check polling until they observe a transition consistent with the new trial. The minimal implementation in TOD/CRM: the polling task captures the post-start `samplePosition` as a "stale upper bound" and skips cap-check / cycle-miss accumulation while `samplePosition >= staleUpperBound`. On the next render-thread reset, `samplePosition` drops below the upper bound; the gate releases. This pattern is local to each polling task and does not require any protocol/API change.

**Test strategy.** A regression test against `baseline_commit` reproduces the race by:
- Driving a `MockSequencerEngine` whose `scheduleEvents` does NOT immediately reset `currentSamplePosition` to 0 (override the mock's current synchronous behaviour) — simulating the real engine's deferred reset.
- Calling `session.start(settings: …)` with `maxRepetitions == 1`.
- Pumping `evaluatePlaybackPosition()` once.
- Asserting `.repetitionCapReached` did NOT fire on the stale read.
- Then setting `currentSamplePosition = 0` and pumping again; trial proceeds normally.

The test fails against `baseline_commit` (proving the bug) and passes after the gate is added. The mock divergence this surfaces is exactly the divergence PF-013 closes with a conformance test pair (see below).

**Trade-offs accepted.** Option (a) lives or dies by the caller-side gate; it requires both polling tasks (TOD + CRM) to implement the gate. The Sendable / actor-isolation map and the gate are documented inline on the BeatSequencer protocol so a future polling caller can apply the same pattern.

#### PF-047 awaitIdle option — pick **(a)** "re-check `session.isIdle` inside the `withObservationTracking` block before suspending"

**Rationale.** The catalog's described race shape is NOT reachable today (Risk 3). Option (c) (document-the-contract) is therefore tempting on minimality grounds. But the rationale for option (c) — "couples the contract to an implicit timing assumption" — is exactly the documented anti-pattern in `[[feedback_design_by_contract_and_separation]]`. The defensive 3-line change in option (a) eliminates the race window for ALL current AND future `isIdle` shapes — including any future migration to an async-isolated `isIdle` accessor. Option (b) (`Observation`'s `observe { ... }` API) is more invasive and adds an iOS-26-only API surface where the simpler defensive pattern suffices.

**Test strategy.** A unit test instantiates a stub `TrainingSession` whose `isIdle` flips synchronously inside the `stop()` call (the catalog's described synthetic shape — already true of real TOD/CRM but the test makes it explicit and pin-able). The test calls `coordinator.navigate(to:)`, asserts `awaitIdle` returns within a bounded time (no infinite suspension), and asserts `resolvedNavigation` is set. Hangs against `baseline_commit` IF `isIdle` were ever to become async — passes after option (a) lands. Given the current `isIdle` is synchronous, the baseline test will pass too; the test pins the contract structurally so a future regression that introduces an async `isIdle` is caught.

#### PF-013 SequencerEngine conformance — load-bearing divergences EXIST

The audit found **three concrete behavioural divergences** between `MockSequencerEngine` and `SoundFontEngine` under the in-scope invariants:

1. **Sample-position reset on `scheduleEvents`/`clearSchedule`.**
   - Mock (`MockSequencerEngine.swift:36, 41`): synchronously sets `currentSamplePosition = 0`.
   - Real (`SoundFontEngine.scheduleEvents:502, clearSchedule:526`): sets `needsAllNotesOff = true` and bumps the double-buffer generation. The render thread observes the gen change on its next callback (lines 626-652) and THEN stores `samplePosition = 0`.
   - **Divergence is load-bearing.** It's exactly the divergence that hides PF-011's trial-start race in unit tests and exposes it in production. Pinned by the regression test in PF-011 § (a) above (which extends the mock with a "defer reset" option) and by a dedicated conformance test exercising both implementations through the post-`scheduleEvents` `currentSamplePosition` invariant.

2. **Post-clear MIDI silencing semantics.**
   - Mock: `clearSchedule` only drops the events array and counter; no concept of "all notes off".
   - Real: render thread reads `needsAllNotesOff` on next gen change and dispatches CC#123 + pitch-bend center on all 16 channels via `midiBlock(AUEventSampleTimeImmediate, 0, 3, ptr)`.
   - **Divergence is load-bearing for PF-054's framing** (the third dispatch path). Tests against the mock cannot exercise the CC#123 ordering relative to subsequent direct MainActor MIDI dispatch — that's where the 85.1 v2 race lived. A conformance test that schedules events, calls `clearSchedule`, then asserts a subsequent immediate `startNote` is NOT silenced by an in-flight CC#123 covers the contract (against real engine; against mock the test is vacuously true).

3. **Stop-then-start re-entry sequencing.**
   - Mock: state mutations are synchronous; `scheduleEvents` after `clearSchedule` is observed immediately.
   - Real: the sequence `clearSchedule → scheduleEvents` produces TWO generation bumps; render thread may process either the intermediate "empty" state or skip directly to the new schedule depending on render-callback cadence.
   - **Divergence is load-bearing for Risk 2's interleaving shape.** A conformance test that calls `scheduleEvents → clearSchedule → scheduleEvents` in rapid succession and asserts no events from the intermediate state leak to the render thread covers the contract.

**Resolution per Tasks & Acceptance.** Add a focused conformance test suite that runs both implementations through these three invariants. Per the story's Always-rule, PF-013 closes either way; the audit's finding ("load-bearing divergences exist") elects the test-suite path.

### D. PF-054 verdict

**Adequately documented by PF-054 + 85.1's removals.** Bounce to PF-054 with the audit's evidence:

- Story 85.1 v2 removed the only known-reachable interaction between path 1 (pitch direct MainActor dispatch) and path 3 (rhythm render-thread CC#123 flag). Verified at `Peach/Core/Audio/SoundFontPlayer.swift:77` and `Peach/Core/Audio/NotePlayer+TimedPlay.swift:12-14`.
- The `activeSession` invariant in `PeachApp.trackActiveSession` prevents pitch and rhythm sessions from being concurrently active.
- The audit found no NEW reachable interaction between the three paths under the current activeSession invariant.

**Recommended within 85.3 scope:** A short inline comment near `SoundFontEngine.scheduleEvents` and `SoundFontEngine.clearSchedule` naming PF-054 and the activeSession gating that holds today's safety. That's a one-line documentation amend — within the spec's "document any contract that stays as a comment-only assertion" rule for PF-011. NO refactor.

**Ask-First trigger:** NONE for PF-054 (no in-scope mitigation surfaces).

### E. Additional `PF-###`-worthy findings beyond PF-011/013/047/054

Per Boundaries & Constraints' Ask-First clause: "If the audit surfaces additional concrete data-race or memory-ordering risks beyond PF-011's known set — pause and present findings before scoping how many to address in this story versus filing new `PF-###` entries."

#### New finding (a) — `PitchMatchingSession` async-continuation chain-registration (Risk 5)

- **Surface.** `Peach/Training/PitchMatching/PitchMatchingSession.swift:377` and `:441-443`.
- **Severity.** Medium (reproduces the 85.1 v2 silencing race in a different surface).
- **Disposition recommendation.** Two options: (i) file a NEW `PF-###` entry and address in a follow-up cleanup, OR (ii) fix in 85.3 alongside PF-011 since the audit identified it during the same surface walk. **Recommendation: file new PF entry.** The fix is mechanically similar but touches `PitchMatchingSession` (out of 85.3's "sequencer concurrency" framing) — folding it in expands story scope. **Ask-First triggered.**

#### New finding (b) — `handleSoundSourceChanged` synchronous stop without awaiting idle (Risk 6)

- **Surface.** `Peach/App/PeachApp.swift:177-215`.
- **Severity.** Low.
- **Disposition recommendation.** File a NEW `PF-###` entry. Out of 85.3's scope ("No refactor of `TrainingLifecycleCoordinator`'s session-activation flow beyond …" — adjacent to but not strictly inside the coordinator). **Ask-First triggered.**

#### New finding (c) — CRM's `stopAll` fire-and-forget (Risk 2b)

- **Surface.** `Peach/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift:480-482`.
- **Severity.** Low-medium.
- **Disposition recommendation.** Either (i) file a NEW `PF-###` entry, OR (ii) fix in 85.3 as a symmetry sibling to PF-011's serialization contract — TOD already uses `enqueueSequencerStop`; CRM should mirror. **Recommendation: fix in 85.3 alongside the PF-011 coordinator-level serialization contract test (Task 5)** — the test will be cleaner if CRM's stop path is the same shape as TOD's, and the fix is a small extraction. **Ask-First triggered to confirm scoping.**

---

**Halt for human review per Tasks & Acceptance Task 1.** Three Ask-First conditions triggered (new findings a/b/c above). Proceeding to Task 2 requires confirmation on:

1. PF-011 pick — option (a) — confirmed for implementation.
2. PF-047 pick — option (a) — confirmed for implementation.
3. PF-054 — bounce to PF-054 (documentation-only comment within 85.3), confirmed.
4. Scoping for new findings (a) (b) (c) — file as new PF entries vs fold into 85.3.

## Suggested Review Order

**Trial-start race mitigation (PF-011)**

- Entry point: protocol contract callers must follow for polling-task safety
  [`BeatSequencer.swift:1`](../../Peach/Core/Ports/BeatSequencer.swift#L1)

- TOD's pre-await snapshot + polling gate — the canonical caller of the contract
  [`TimingOffsetDetectionSession.swift:391`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift#L391)

- CRM's matching gate — same shape per the audit's intentional symmetry
  [`ContinuousRhythmMatchingSession.swift:452`](../../Peach/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift#L452)

- TOD regression test pinning "cap does not fire on stale samplePosition"
  [`TimingOffsetDetectionSessionTests.swift:979`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionSessionTests.swift#L979)

- CRM regression test pinning "no cycle misses accumulate on stale samplePosition"
  [`ContinuousRhythmMatchingSessionTests.swift:346`](../../PeachTests/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingSessionTests.swift#L346)

**Cross-discipline serialization (PF-011 second prong + finding (c) folded)**

- TOD's existing `enqueueSequencerStop` pattern — load-bearing reference shape
  [`TimingOffsetDetectionSession.swift:583`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift#L583)

- CRM's new `enqueueSequencerStop` — symmetry fix with deliberate `onFailure` divergence
  [`ContinuousRhythmMatchingSession.swift:567`](../../Peach/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift#L567)

- Coordinator-level contract test pinning CRM → TOD handover serialization
  [`TrainingLifecycleCoordinatorTests.swift:480`](../../PeachTests/App/TrainingLifecycleCoordinatorTests.swift#L480)

**`awaitIdle` defensive re-check + Task cancellation (PF-047)**

- The defensive re-check + cancellation-handler wrap
  [`TrainingLifecycleCoordinator.swift:221`](../../Peach/App/TrainingLifecycleCoordinator.swift#L221)

- One-shot resume box guarding the three resume paths (sync, `onChange`, `onCancel`)
  [`TrainingLifecycleCoordinator.swift:284`](../../Peach/App/TrainingLifecycleCoordinator.swift#L284)

- Test pinning the synchronous-`isIdle` flip path
  [`TrainingLifecycleCoordinatorTests.swift:452`](../../PeachTests/App/TrainingLifecycleCoordinatorTests.swift#L452)

**Sendable / isolation contracts (Task 6)**

- `BeatProvider` intentionally not `Sendable` — rationale under default MainActor
  [`SequencerTypes.swift:38`](../../Peach/Core/Audio/SequencerTypes.swift#L38)

- `scheduleStopAll` chain-registration invariant carried over from 85.1 v2
  [`SoundFontPlayer.swift:80`](../../Peach/Core/Audio/SoundFontPlayer.swift#L80)

- PF-054 inline gating comment near `scheduleEvents` / `clearSchedule`
  [`SoundFontEngine.swift:502`](../../Peach/Core/Audio/SoundFontEngine.swift#L502)

**`SequencerEngine` conformance (PF-013)**

- Mock-side contract pins — three load-bearing divergence anchors
  [`SequencerEngineConformanceTests.swift:13`](../../PeachTests/Core/Audio/SequencerEngineConformanceTests.swift#L13)

**Catalog hygiene**

- PF-011 / PF-013 / PF-047 removed; PF-054 retained per audit bounce; PF-058 + PF-059 filed
  [`deferred-work.md:299`](./deferred-work.md#L299)

## Spec Change Log

**2026-06-06 — Pre-implementation refresh after 85.1 merge.** Baseline bumped from `6c6784f5` to `c52fa597` (current `main` HEAD). Code Map's catalog-referenced surfaces extended with 85.1-landed pieces: `SoundFontPlayer.scheduleStopAll()` chain, `SoundFontPlaybackHandle.stop` audio-queue routing, `NotePlayer+TimedPlay.swift` cancellation catch, post-85.1 `TrainingLifecycleCoordinator` routing (`stopCurrentSession`, scenePhase, `helpSheet`, `navigate`, `handleSoundSourceChanged`). PF-054 added to Intent as adjacent surface (audit-decides), not added to `closes:`. Approach's Audit step extended to enumerate the new surfaces.

**2026-06-06 — Task 1 audit complete; Task 2 lock-in.** Picks confirmed: PF-011 option (a) caller-side polling gate + `BeatSequencer` contract doc + extended-mock regression test; PF-047 option (a) defensive in-block re-check (audit reframed: race not reachable today under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` + synchronous `isIdle`, but defensive pattern eliminates the window for any future async-`isIdle` migration); PF-054 bounce with inline gating comment near `SoundFontEngine.scheduleEvents`/`clearSchedule`; PF-013 conformance test suite path (three load-bearing divergences identified — samplePosition reset, post-clear CC#123 semantics, stop-then-start gen-bump sequencing). Audit surfaced three new reachable risks beyond PF-011/013/047/054 scope: finding (a) `PitchMatchingSession` deferred `handle.stop()` chain-registration violation → filed as **PF-058**; finding (b) `handleSoundSourceChanged` synchronous stop without `awaitIdle` before `rebuildCoordinators()` → filed as **PF-059**; finding (c) CRM `stopAll` fire-and-forget → folded into Task 5 as `enqueueSequencerStop` symmetry fix with TOD. Boundaries & Constraints unchanged in shape — the audit lock-in fits within the existing "Always" / "Never" envelope; no Ask-First conditions remain open.

**2026-06-06 — Implementation deviations.**

- **`SingleShotResumer` helper added** for the `awaitIdle` defensive re-check. The locked pick's example shape (3-line restructure) cannot accommodate the synchronous-resume + later-onChange-may-fire pattern without a one-shot guard. The helper is `private`, ~15 lines, uses `OSAllocatedUnfairLock`-wrapped `CheckedContinuation<Void, Never>?` so no `@unchecked Sendable` is needed. (Renamed to `SingleShotResumerBox` during the review patch round to accommodate Task-cancellation handling — see review-patches log below.)
- **`SequencerEngineConformanceTests` Group 1 / Group 2 real-engine tests converted to documentation blocks.** Group 3's `realEngineRapidReEntryExposesFinalScheduleCount` was initially simplified to a main-thread `scheduledEventCount` assertion, then retired entirely during the review patch round for consistency. The render-thread-timing assertions originally drafted by Task 7 proved fragile under parallel simulator-clone execution (`mediaserverd` contention; audio I/O unit warm-up window unbounded). Per the audit's sanctioned fallback ("focus on the Mock's contract assertions and add documentation explaining what's tested vs. what's pinned by the real implementation's structure"), the real-engine assertions are exercised end-to-end by: (1) PF-011 regression tests in `TimingOffsetDetectionSessionTests` and `ContinuousRhythmMatchingSessionTests` — load-bearing for divergence (1); (2) existing `SoundFontEngineTests` `dispatchedEventCount` tests — load-bearing for divergence (2); (3) the CRM → TOD handover serialization test in `TrainingLifecycleCoordinatorTests` — load-bearing for divergence (3). The contracts are documented inline at `SoundFontEngine.scheduleEvents` / `clearSchedule` and on `BeatSequencer.start(tempo:beatProvider:)`. PF-013 still closes: the audit-identified divergences are documented, the mock-side contract is asserted, and the cross-implementation behavioural agreement is pinned indirectly via integration paths.

**2026-06-06 — Review-patch round (Step 4 adversarial review surfaced 11 patch-level findings).** Blind hunter + edge-case hunter agreed on 11 patch-classified findings; acceptance auditor verdict was READY FOR DONE. All 11 patches applied:

1. **`MockBeatSequencer.defersSamplePositionReset` was decorative** — flag declared but never read. Dropped; the mock's `start()` already preserved pre-set `currentSamplePosition` (matching real-engine deferred-reset semantics). PF-011 regression tests updated to drive `flushDeferredReset()` directly.
2. **`awaitIdleHandlesSynchronousIdleFlip` clarified** — test pins only the outer short-circuit path; the in-block re-check is structurally unreachable under sync MainActor `isIdle`. Documented inline. The defensive re-check stays as future-proofing.
3. **`awaitIdle` Task cancellation** — wrapped `withCheckedContinuation` in `withTaskCancellationHandler`; added `Task.isCancelled` checks. `SingleShotResumer` renamed to `SingleShotResumerBox` and given a state machine to handle install-after-resume race from the cancel path.
4. **`realEngineRapidReEntryExposesFinalScheduleCount` retired** — converted to documentation block matching Groups 1 / 2 treatment.
5. **CRM → TOD handover assertion strengthened** — replaced `firstIndex` ordering with a state-machine walk of the call log that pins exclusive sequencer ownership.
6. **`captureStaleSamplePositionUpperBound` → `setStaleSamplePositionUpperBound(_:)`** — both TOD and CRM now snapshot `samplePosition` BEFORE `await beatSequencer.start(...)` instead of after, closing the narrow race where the render thread's deferred reset is already observed by the time the post-await snapshot runs. Applied to `beginNextTrial`, `restartSequencerForCurrentTrial` (TOD), and CRM's start path.
7. **CRM's `enqueueSequencerStop` gained `onFailure: @escaping () -> Void = {}`** mirroring TOD's signature.
8. **`makeSharedSequencerFixture` platform-conditional** — selects `BackgroundPolicy` via `#if os(iOS)` / `#if os(macOS)` matching `PeachApp.makeBackgroundPolicy()`.
9. **Polling-task isolation-contract comments** added at both sessions' `startTrackingLoop` call sites, naming MainActor inheritance and the audit's §A finding.
10. **`SingleShotResumerBox` Sendable rationale** documented inline citing the `CheckedContinuation` resume contract and the lock-wrapped-optional invariant.
11. **`litDotCount == 2` magic number** — derivation comment added.

Post-patch four-platform gate: iOS Debug 1965 / iOS Research 2126 / macOS Debug 1959 / macOS Research 2120 all green. The −1 pass count vs. the initial gate corresponds to Patch 4 retiring one real-engine conformance test.

**2026-06-06 — `/simplify-code` final pass (CLAUDE.md mandatory gate).** Four parallel reviewers (reuse / quality / efficiency / clarity) surfaced 6 high-confidence findings, all applied:

1. **Stale `SingleShotResumer` references** in `TrainingLifecycleCoordinator.swift` comments at the `awaitIdle` doc-comment and inline comment — renamed to `SingleShotResumerBox` to match the class.
2. **`BeatSequencer.start` contract doc** said "capture immediately after `start` returns" but Review-Patch #6 changed both callers to snapshot BEFORE the await. Updated the protocol doc to say "capture IMMEDIATELY BEFORE `await`ing `start(...)`" with the rationale (post-await snapshot races the render-thread reset).
3. **`SingleShotResumerBox.install` `.consumed` arm** silently swallowed the incoming continuation, which would trap on the leaked `CheckedContinuation`. Changed to resume the incoming continuation immediately; `.armed` (genuine double-install with two live continuations) now `assertionFailure`s while still resuming the new one to avoid the trap.
4. **CRM's `enqueueSequencerStop` `onFailure` parameter** — added in Review-Patch #7 to mirror TOD's signature, but no CRM caller uses it (CRM has no answer-driven stop path; TOD's escalation is for `stopSequencerForAnswer`). Dropped the parameter; inline doc-comment explains the deliberate divergence and the condition under which it would be re-added.
5. **`SequencerEngineConformanceTests` suite rename** — `@Suite("SequencerEngine conformance")` overstated coverage since no real-engine assertion survives. Renamed to `@Suite("MockSequencerEngine contract pinning (PF-013 divergence anchors)")`. `@Test` descriptions reframed from "mock <verb> …" to "<verb> …" (the contract being pinned). Dropped the now-unused `makeRealEngine()` helper and `channel0` constant.
6. **Dead "companion test idea" comment block** in `TimingOffsetDetectionSessionTests.swift` removed. The rationale for snapshotting BEFORE the await is documented inline at `setStaleSamplePositionUpperBound` in production code and in this change log; a floating "test that wasn't" comment fades.

Findings skipped per project's "no abstractions beyond what the task requires" rule: extracting a shared `StaleSamplePositionGate` value type across TOD/CRM (Clarity reviewer's recommendation; Quality reviewer recommended the opposite — inlining the one-line helper). Both are debatable design choices; the current state with the named helper at each session is fine and matches the audit's intentional TOD/CRM symmetry.

Post-`/simplify-code` four-platform gate: iOS Debug 1965 / iOS Research 2126 / macOS Debug 1959 / macOS Research 2120 — unchanged from review-patch round, all green.
