---
title: 'Story 85.1: Consolidate session lifecycle under TrainingLifecycleCoordinator'
type: 'cleanup'
created: '2026-06-05'
status: 'ready-for-dev'
baseline_commit: '6c6784f5'
context:
  - '{project-root}/docs/implementation-artifacts/deferred-work.md'
  - '{project-root}/docs/implementation-artifacts/epic-85-context.md'
closes:
  - 'PF-001'
  - 'PF-003'
  - 'PF-005'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem.** Three deferred-work entries — PF-001, PF-003, PF-005 — are three faces of the same root cause: session lifecycle ownership is split between `PeachApp`, the sessions themselves, and `TrainingLifecycleCoordinator`. When the coordinator was introduced it added a new policy layer but did not retire the existing session-level mechanisms. The result is that sessions still encode policy ("I stop when the app backgrounds"; "I drop progress when my screen disappears") and `PeachApp` still owns wiring decisions that the coordinator could mediate.

The three symptoms:

- **PF-001** — On macOS, each session's `AudioSessionInterruptionMonitor` listens for `NSApplication.didResignActiveNotification` and calls `stop()`. The coordinator's `handleAppDeactivated()` also stops the current session. 4× redundant "stop() called but already idle" log lines per app-switch. *Cosmetic, but a direct symptom of policy living in two places.*
- **PF-003** — Navigating from the training screen to Settings or Profile fires `onDisappear`, which calls `lifecycle.trainingScreenDisappeared()` → `stopCurrentSession()` → `session.stop()`. `stop()` clears `sessionBestCentDifference`, `currentTrial`, and `lastResult`. On return, `onAppear` restarts training from scratch. *In-session progress lost on every nav round-trip.*
- **PF-005** — `PeachApp.onChange(of: soundSource)` replaces sessions without calling `stop()` on the outgoing instances. If a session was active, its internal Tasks capture `self` and run indefinitely until their `AsyncStream`s finish. *Latent leak, user-triggerable but rarely-exercised.*

**Approach.** Make `TrainingLifecycleCoordinator` the single authority for session lifecycle policy. Sessions retain mechanism — they own their audio resources and can stop themselves — but stop deciding *when*. Specifically:

1. Sessions on macOS no longer subscribe to `NSApplication.didResignActiveNotification`. The coordinator routes app-deactivation to the active session via the existing `handleAppDeactivated()` path. (closes PF-001)
2. Distinguish "temporary navigation push" (Settings, Profile drill-in) from "permanent navigation pop" (back to Start Screen). The coordinator gains pause/resume semantics; sessions gain `pause()`/`resume()` that preserve in-trial state, distinct from `stop()`/`start()` which reset it. The training screen's `onDisappear` routes to pause; only an explicit session-end routes to stop. (closes PF-003)
3. Session replacement on sound-source change routes through the coordinator, which stops the outgoing session(s) before assigning the replacements. (closes PF-005)

**Design principle.** Mechanism/policy separation per [[feedback_design_by_contract_and_separation]]: sessions check their own preconditions (no more, no less); the coordinator owns the business rule of when lifecycle transitions happen. Each component's revised responsibility is named explicitly in the verified code map (Task 1 output) and reflected in the protocol changes.

## Boundaries & Constraints

**Always:**
- All three `PF-###` entries are closed by this story or the spec is revised to defer one with explicit human authorization.
- Behavioural parity on the happy path: on iOS the training-screen entry-and-stop loop, the app-background-stop, and the sound-source-change flow all behave as today; only the *redundancy* and the *progress-loss* symptoms go away.
- The coordinator is the only caller that decides when a session pauses, resumes, stops, or starts. Sessions and `PeachApp` route lifecycle decisions through it.
- `pause()` and `resume()` preserve in-trial state explicitly: `currentTrial`, `sessionBestCentDifference`, `lastResult`, and any session-specific in-flight accumulators. Define the preservation contract per session protocol with tests.
- Pre-commit gate: `bin/test.sh && bin/test.sh -p mac` AND `bin/test.sh --research && bin/test.sh --research -p mac` green.
- Catalog hygiene on merge: remove the PF-001, PF-003, PF-005 sections from `deferred-work.md` in the same change; cite the IDs in the commit message.

**Ask First:**
- If verification (Task 1) reveals that the catalog descriptions are stale — code has moved, additional `PF-###` entries belong in the cluster, or one of the three is already partially resolved — pause and present findings before re-scoping.
- If introducing `pause()`/`resume()` requires breaking the public `TrainingSession` protocol in a way that ripples beyond the four current sessions (`PitchMatching`, `PitchDiscrimination`, `TimingOffsetDetection`, `ContinuousRhythmMatching`), pause and confirm the protocol shape.
- If the coordinator's existing `handleAppDeactivated()` path turns out to predate the `AudioSessionInterruptionMonitor` migration on iOS (not just macOS), and removing the macOS-only `backgroundNotificationName` plumbing creates an iOS asymmetry, pause and discuss.

**Never:**
- No new abstraction beyond what these three entries require. No "session lifecycle state machine" library, no observable lifecycle event bus, no protocol-level activity tracker. The coordinator already exists; extend it.
- No changes to the `TrainingSession` protocol surface beyond what `pause()`/`resume()` and the routing-through-coordinator changes require.
- No iOS audio-session-interruption refactor as a drive-by. iOS interruptions (phone calls, AirPods disconnects) are a separate concern that genuinely belongs in `AudioSessionInterruptionMonitor`; only the macOS app-deactivation piggyback comes out.
- No new `@AppStorage` or persistence work. Pause/resume preserves in-memory state only; an app kill still loses the session, as today.

## I/O & Edge-Case Matrix

Filled to the cluster-closure level; per-PF acceptance lives in the Acceptance Criteria. The verified code map produced by Task 1 may extend this matrix.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| App backgrounding on macOS during active session (PF-001) | Active session, user switches apps | Coordinator stops the session exactly once; no redundant "stop() called but already idle" log lines | N/A |
| Settings drill-in from training screen (PF-003) | Active session with `currentTrial != nil`, user taps Settings toolbar item | Coordinator pauses session; on return, `currentTrial`, `sessionBestCentDifference`, `lastResult` are unchanged; training resumes from preserved state | N/A |
| Back-to-Start navigation from training screen (PF-003) | Active session, user pops to Start Screen | Coordinator stops session; in-trial state is cleared as today | N/A |
| Sound-source change during active session (PF-005) | Active session, user changes Sound Source in Settings | Coordinator stops the outgoing session(s) before replacement; no orphan Tasks observable after the change | N/A |
| Sound-source change with no active session (PF-005) | No active session, user changes Sound Source | Coordinator replaces sessions; no stop call needed; no log noise | N/A |
| App backgrounding on iOS during active session | Active session, user backgrounds | Behavior unchanged from today (iOS audio-session-interruption path remains in place) | N/A |

</frozen-after-approval>

## Code Map

**Deliberately empty pre-verification.** Task 1 (verification) produces the verified code map and appends it here before implementation begins. The catalog entries cite the following surfaces as their starting point; verification confirms they are current:

- PF-001 surface: `AudioSessionInterruptionMonitor`, `TrainingLifecycleCoordinator.handleAppDeactivated()`, session `backgroundNotificationName` plumbing in `PeachApp`
- PF-003 surface: `TrainingLifecycleCoordinator.trainingScreenDisappeared()`, `stopCurrentSession()`, session `stop()` implementations, training-screen `onDisappear`/`onAppear`
- PF-005 surface: `PeachApp.onChange(of: soundSource)`, session replacement assignments for `pitchMatchingSession`/`pitchDiscriminationSession` (and any other sessions that change with sound source)

**Added during verification (scope discovery):**

- *(populated by Task 1)*

## Tasks & Acceptance

**Execution:**

- [ ] **Task 1 — Verification (must complete and review before any code change).** Read the code surfaces cited above against the catalog entries for PF-001, PF-003, PF-005. For each entry, confirm or correct: (a) the cited symbols still exist with the cited behavior, (b) the root-cause framing in the catalog still holds, (c) no in-flight work has partially resolved the issue, (d) no adjacent code reveals a fourth symptom that belongs in this cluster. Output: append the verified code map under the "Code Map" heading above with file paths + line numbers; list any deltas as bullet points; flag any entry whose description needs revision. **Halt for human review before Task 2.** Per `[[feedback_ask_dont_assume]]`, do not silently re-scope.
- [ ] **Task 2 — Approach lock-in (post-verification).** Based on the verification output, finalize: (a) the exact shape of `pause()`/`resume()` on the `TrainingSession` protocol, (b) the coordinator's routing of app-deactivation, nav-push, nav-pop, and sound-source-change events, (c) the deletion list for the legacy session-level mechanism. Update Boundaries & Constraints if Ask-First conditions triggered.
- [ ] **Task 3 — Protocol & coordinator changes.** Implement the locked-in protocol and coordinator additions. Tests-first per project convention: protocol contract tests pin the pause/resume preservation contract before the implementation lands.
- [ ] **Task 4 — Per-session implementations.** Implement `pause()`/`resume()` on each `TrainingSession` conformer. Preserve in-trial state per the contract; verify in unit tests.
- [ ] **Task 5 — Wire the training screen.** Route `onDisappear` to pause and the explicit session-end path to stop. Verify the round-trip Settings → training-screen preserves state.
- [ ] **Task 6 — Wire `PeachApp` sound-source change.** Route through the coordinator. Verify no orphan Tasks via a leak-style test (or observable assertion).
- [ ] **Task 7 — Remove the macOS notification path.** Delete the `backgroundNotificationName` plumbing on macOS; iOS path unchanged.
- [ ] **Task 8 — Catalog hygiene.** Remove the PF-001, PF-003, PF-005 sections from `docs/implementation-artifacts/deferred-work.md`. Cite the closed IDs in the commit message.
- [ ] **Task 9 — Pre-commit gates.** Run `bin/test.sh && bin/test.sh -p mac` and `bin/test.sh --research && bin/test.sh --research -p mac`. Both green.

**Acceptance Criteria:**

- **PF-001.** Given an active training session on macOS, when the user switches to another app, then exactly one `stop()` call occurs and no "stop() called but already idle" log lines appear.
- **PF-003.** Given an active training session with `currentTrial != nil` on either platform, when the user taps Settings or Profile in the training screen toolbar and then returns, then `currentTrial`, `sessionBestCentDifference`, and `lastResult` are the same values they were before the navigation push; training continues from the preserved state, not from scratch.
- **PF-003 (negative case).** Given an active training session, when the user pops back to the Start Screen, then the session stops and in-trial state is cleared — same behavior as today.
- **PF-005.** Given an active training session, when the user changes the Sound Source in Settings, then the outgoing session(s) are stopped before the replacement instances are constructed; no Tasks from the outgoing instances continue after the swap (asserted by test).
- **PF-005 (no-op case).** Given no active session, when the user changes the Sound Source, then sessions are replaced without `stop()` calls and without log noise.
- **iOS parity.** App-backgrounding behavior on iOS is unchanged from `baseline_commit`; existing iOS interruption tests still pass without modification.
- **Pre-commit gate.** Both schemes pass on both platforms: `bin/test.sh && bin/test.sh -p mac` (Debug) and `bin/test.sh --research && bin/test.sh --research -p mac` (Research). No new compiler warnings.
- **Catalog hygiene.** PF-001, PF-003, PF-005 sections are removed from `deferred-work.md` in the closing commit, which cites the three IDs.

## Spec Change Log

*(empty — populated by review iterations if any)*
