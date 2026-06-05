---
title: 'Story 85.3: Audit and harden the sequencer @Observable + Task concurrency contract'
type: 'cleanup'
created: '2026-06-05'
status: 'ready-for-dev'
baseline_commit: '6c6784f5'
context:
  - '{project-root}/docs/implementation-artifacts/deferred-work.md'
closes:
  - 'PF-011'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem.** PF-011 consolidates one concrete production-reachable race and one set of unverified concurrency invariants under a shared root cause: the sequencer's `@Observable`-plus-background-`Task` shape has accumulated cross-discipline sharers (CRM, TOD) and cross-task mutators without an explicit Sendable / actor-isolation contract. The strict-concurrency build is clean only because `BeatProvider` is not `Sendable` — strict concurrency isn't catching what it can't see.

The concrete reachable risk:

- **Stale `samplePosition` at new-trial start (Story 80.2 surface).** Between `beatSequencer.start(...)` returning on the main actor and the render thread resetting `engine.currentSamplePosition` to 0, the polling task may sample a stale large value. With `maxRepetitions == 1` and an unlucky 8 ms tick at the boundary, `completedCycles` already meets the cap before any audio is heard, immediately firing `.repetitionCapReached`. Reachable in production today; Epic 84 (which added TOD as a second sharer of the sequencer instance) raised the probability.

The unverified static shape:

- `BeatProvider` is not `Sendable`. The sequencer mutates `currentBeat` from a background `Task`. `ContinuousRhythmMatchingSession.gapPositions` is written from the sequencer's polling Task. Two independent adversarial reviewers (Blind hunter + Edge case hunter) flagged this as a latent data-race surface. Currently invisible to strict concurrency.
- **Cross-discipline serialization invariant.** TOD and CRM both call `beatSequencer.start(tempo:beatProvider:)` on the shared singleton. `TrainingLifecycleCoordinator` already serializes activations, but no test pins this contract — a future coordinator refactor could break it silently.

**Approach.** Two-phase: audit, then fix.

1. **Audit** — invoke `/swift-concurrency-expert` (and optionally `/avdlee-swift-concurrency` as a second lens) on `BeatProvider`, `SoundFontBeatSequencer`, `ContinuousRhythmMatchingSession.gapPositionInCurrentBeat` / `currentBeatPosition` / `lastPublishedSubdivisionIndex` writers, `TimingOffsetDetectionSession.lastPublishedSubdivisionIndex` / `litDotCount` writers, and `TrainingLifecycleCoordinator`'s session-activation serialization. The audit produces: a Sendable / actor-isolation map of the current shape; a list of concrete data-race or memory-ordering risks beyond the known one; a recommendation per risk (document-as-contract / add-test / refactor); and an explicit pick between the catalog's three trial-start-race options — (a) document the post-`start()` reset latency as a `BeatSequencer` contract with a coordinator-level test; (b) anchor TOD's `globalSubdivisionIndex` to a per-trial baseline `samplePosition` captured at start; (c) extend `BeatSequencer.timing` with a "trial-relative sample position" accessor.

2. **Fix** — apply the audit's recommendations. The maxReps=1 race is the must-close item; everything else is conditional on what the audit surfaces.

**Design principle.** Mechanism/policy separation per [[feedback_design_by_contract_and_separation]] — applied at the concurrency contract layer: each component's actor-isolation responsibility is named explicitly in the audit output; the coordinator's serialization invariant is a documented and tested contract rather than an emergent property of activation timing.

## Boundaries & Constraints

**Always:**
- PF-011 is closed by this story or its scope is renegotiated with explicit human authorization.
- The maxReps=1 trial-start race is fixed with a regression test that demonstrates the failure mode against the audit's chosen mitigation — written first, then made to pass by the implementation.
- The cross-discipline serialization invariant gains a coordinator-level test pinning "the previous session has fully stopped before the next starts."
- BeatProvider, SoundFontBeatSequencer, and the two session polling paths land with an explicit Sendable / actor-isolation contract — at minimum documented in code comments; potentially enforced by Sendable conformance and actor isolation if the audit recommends it.
- Pre-commit gate: `bin/test.sh && bin/test.sh -p mac` AND `bin/test.sh --research && bin/test.sh --research -p mac` green.
- Catalog hygiene on merge: remove the PF-011 section from `deferred-work.md` in the same change; cite the ID in the commit message.

**Ask First:**
- If the audit surfaces additional concrete data-race or memory-ordering risks beyond PF-011's known set — pause and present findings before scoping how many to address in this story versus filing new `PF-###` entries.
- If the audit recommends a contract change to the `BeatSequencer` protocol or `BeatProvider` shape (versus an additive contract via comments/tests), pause and confirm the protocol shape before implementing.
- If the audit endorses option (c) — adding a "trial-relative sample position" accessor — that's a new API surface and warrants a separate Ask-First before adding it.
- If the audit concludes the maxReps=1 race is already mitigated by something not visible in the catalog entry, pause and confirm before either writing a test for a non-bug or closing PF-011 as misclassified.

**Never:**
- No new actor or concurrency-primitive introductions unless the audit explicitly endorses them.
- No refactor of `TrainingLifecycleCoordinator`'s session-activation flow beyond adding the contract test (Story 85.1 owns the lifecycle policy consolidation; the boundary between these stories must be respected).
- No drive-by closures of PF-016 (`refillThreshold` uniform-tempo) or PF-047 (`awaitIdle` race) — both are coordinator/sequencer-adjacent but architecturally distinct.
- No introduction of new `@AppStorage` or persistence work. Concurrency-only changes.

## I/O & Edge-Case Matrix

Filled to the closure level; the audit (Task 1) may extend this with newly-surfaced risks.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| New TOD trial with `maxRepetitions == 1` (PF-011 reachable race) | Trial starts; render thread takes >0 ms to reset `samplePosition` to 0 | Polling task does not observe stale `samplePosition`; `.repetitionCapReached` does not fire before any audio is heard | Asserted by regression test against the audit's chosen mitigation |
| Cross-discipline session transition (cross-discipline serialization invariant) | Active CRM session; user navigates to TOD | Coordinator stops CRM and waits for fully-idle before starting TOD; no overlapping `beatSequencer.start(...)` invocations | Asserted by coordinator-level contract test |
| New CRM trial after the maxReps fix (regression sanity) | CRM trial starts with standard `maxRepetitions` | Behaviour unchanged from `baseline_commit`; existing CRM trial-progression tests still pass | N/A |
| Strict-concurrency build (post-audit Sendable contract) | Both Debug and Research schemes | Build remains clean; new `Sendable` / actor-isolation annotations (if any) compile without warnings | N/A |

</frozen-after-approval>

## Code Map

**Deliberately empty pre-verification.** Task 1's audit produces the verified code map and appends it here. Catalog-referenced surfaces:

- `BeatProvider` protocol (Sendable status)
- `Peach/Core/Audio/SoundFontBeatSequencer.swift` — `currentBeat` mutator, polling Task, timing snapshot
- `Peach/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift` — `evaluatePlaybackPosition` polling Task, `gapPositionInCurrentBeat` / `currentBeatPosition` / `lastPublishedSubdivisionIndex` writers
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift` — `evaluatePlaybackPosition` polling Task, `litDotCount` / `lastPublishedSubdivisionIndex` writers
- `Peach/App/TrainingLifecycleCoordinator.swift` — session-activation serialization path (handover between sessions)
- Possibly `Peach/Core/Audio/SoundFontEngine.swift` — render-thread `samplePosition` reset, generation-change fence

**Added during verification (scope discovery):**

- *(populated by Task 1)*

## Tasks & Acceptance

**Execution:**

- [ ] **Task 1 — Audit (must complete and review before any code change).** Invoke `/swift-concurrency-expert` (and optionally `/avdlee-swift-concurrency` as a second lens) against the surfaces cited above. Produce: (a) a Sendable / actor-isolation map of the current shape; (b) a list of concrete data-race or memory-ordering risks, each with severity and whether reachable in production; (c) per risk, a recommendation — document-as-contract / add-test / refactor — naming the smallest change that closes it; (d) an explicit pick from the catalog's three trial-start-race options (a/b/c) with rationale. Append the output as a new `Code Map` and `Audit Findings` section above. **Halt for human review before Task 2.** Per `[[feedback_ask_dont_assume]]`.
- [ ] **Task 2 — Approach lock-in (post-audit).** Based on the audit, finalise: (a) the exact mitigation for the maxReps=1 trial-start race; (b) the shape of the cross-discipline serialization contract test; (c) the Sendable / actor-isolation annotations (if any) the audit recommends; (d) any additional `PF-###` entries to file for risks beyond this story's scope. Update Boundaries & Constraints if Ask-First conditions triggered.
- [ ] **Task 3 — Regression test for the trial-start race.** Tests-first: write a test that reproduces the maxReps=1 race against `baseline_commit` (proving the bug) and then passes after Task 4 lands the mitigation. The test exercises the polling-task path the audit identified, with an injected delay or controlled `samplePosition` to make the race deterministic.
- [ ] **Task 4 — Apply the trial-start-race mitigation.** Implement the audit-chosen option (a, b, or c). The regression test from Task 3 passes; existing tests stay green.
- [ ] **Task 5 — Coordinator serialization contract test.** Add a `TrainingLifecycleCoordinatorTests` case pinning "the previous session has fully stopped before the next starts" — exercises the CRM → TOD handover and asserts no overlapping `beatSequencer.start(...)` invocations.
- [ ] **Task 6 — Sendable / actor-isolation contract.** Apply the audit's recommendations on the protocol and session-state shapes. Document any contract that stays as a comment-only assertion (i.e., not enforced by Sendable) with the rationale.
- [ ] **Task 7 — Catalog hygiene.** Remove the PF-011 section from `docs/implementation-artifacts/deferred-work.md`. File any new `PF-###` entries surfaced by the audit per Task 2(d). Cite PF-011 in the commit message.
- [ ] **Task 8 — Pre-commit gates.** Run `bin/test.sh && bin/test.sh -p mac` and `bin/test.sh --research && bin/test.sh --research -p mac`. All four green.

**Acceptance Criteria:**

- **PF-011 trial-start race.** Given a TOD trial with `maxRepetitions == 1`, when the trial starts, then `.repetitionCapReached` does not fire before any audible note is produced (asserted by regression test).
- **PF-011 cross-discipline serialization.** Given an active CRM session, when the user navigates to TOD, then `TrainingLifecycleCoordinator` stops CRM and waits for fully-idle before starting TOD (asserted by coordinator-level contract test); no overlapping `beatSequencer.start(...)` invocations occur.
- **PF-011 Sendable / actor-isolation contract.** Sequencer + session polling paths have an explicit concurrency contract — either documented inline with rationale or enforced by Sendable / actor annotations per the audit's recommendation.
- **Existing behavior parity.** All existing CRM and TOD tests pass without modification. Strict-concurrency build remains clean on both schemes.
- **Pre-commit gate.** All four schemes green: Debug × {iOS, macOS} and Research × {iOS, macOS}. No new compiler warnings.
- **Catalog hygiene.** PF-011 section removed from `deferred-work.md` in the closing commit; any audit-surfaced new findings filed as new `PF-###` entries.

## Audit Findings

*(empty — populated by Task 1; halt for human review before Task 2)*

## Spec Change Log

*(empty — populated by review iterations if any)*
