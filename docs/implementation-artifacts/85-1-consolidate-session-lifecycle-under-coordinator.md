---
title: 'Story 85.1: Consolidate session lifecycle under TrainingLifecycleCoordinator'
type: 'cleanup'
created: '2026-06-05'
status: 'done'
baseline_commit: 'a7add6db'
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

### Verified surfaces — PF-001 (Redundant Session Stop via Background Notification on macOS)

- [`../../Peach/Core/Audio/AudioSessionInterruptionMonitor.swift`](../../Peach/Core/Audio/AudioSessionInterruptionMonitor.swift):36–47 — `backgroundNotificationName` / `foregroundNotificationName` registered as notification observers; on fire, invoke `onStopRequired()`. Each session owns one monitor via `SessionLifecycle`.
- [`../../Peach/Core/Training/SessionLifecycle.swift`](../../Peach/Core/Training/SessionLifecycle.swift):14–31 — `SessionLifecycle` constructs `AudioSessionInterruptionMonitor` and forwards `backgroundNotificationName`. Every session passes one.
- [`../../Peach/App/Platform/PlatformNotifications.swift`](../../Peach/App/Platform/PlatformNotifications.swift):15 — `backgroundNotificationName` on macOS = `NSApplication.didResignActiveNotification`.
- [`../../Peach/App/PeachApp.swift`](../../Peach/App/PeachApp.swift):429, 448, 466, 484 — all four sessions (PitchDiscrimination, PitchMatching, TimingOffsetDetection, ContinuousRhythmMatching) receive the same `backgroundNotificationName`; therefore four independent observers on macOS.
- [`../../Peach/App/Platform/ContentView+macOS.swift`](../../Peach/App/Platform/ContentView+macOS.swift):24–28 — macOS app-level observer on `NSApplication.didResignActiveNotification` → `lifecycle.handleAppDeactivated()` → `stopCurrentSession()`.
- [`../../Peach/App/TrainingLifecycleCoordinator.swift`](../../Peach/App/TrainingLifecycleCoordinator.swift):86–89 — `handleAppDeactivated()` logs "App deactivated — stopping current session" and calls `stopCurrentSession()`.
- [`../../Peach/App/TrainingLifecycleCoordinator.swift`](../../Peach/App/TrainingLifecycleCoordinator.swift):71–82 — `handleScenePhase(old:new:)` independently routes background → `stopCurrentSession()` via `backgroundPolicy.shouldStopTraining(newPhase:)`. This is a *third* stop path on top of (a) the coordinator's NSApplication observer and (b) each session's own monitor.

**Delta vs. catalog (PF-001):**

- **Catalog claim "4× redundant 'stop() called but already idle' log lines per app-switch" is not literal.** There is no such log line in the codebase (grep confirmed). The state machine's `(.idle, .stopRequested)` transition silently returns no commands ([`../../Peach/Training/PitchMatching/PitchMatchingSession.swift`](../../Peach/Training/PitchMatching/PitchMatchingSession.swift):64; matched in PitchDiscriminationSession). The visible symptom on macOS is therefore one `Lifecycle` log ("App deactivated — stopping current session") and potentially a second from the scenePhase path; the per-session redundant `stop()` invocations are silent.
- **Root cause framing still holds.** Architectural redundancy is real: three independent paths (scenePhase, app-level NSApplication observer, per-session monitor) converge on the same `session.stop()` for one active session, with three silently-no-op `stop()` calls hitting the three idle sessions.
- **Revised symptom to use in acceptance:** exactly one `Lifecycle` "App deactivated" log line per app-switch (asserting the coordinator owns the policy and no per-session monitor fires).

### Verified surfaces — PF-003 (Training Session Restart on In-Stack Navigation to Settings/Profile)

- [`../../Peach/App/TrainingScreenModifier.swift`](../../Peach/App/TrainingScreenModifier.swift):36–42 — `onAppear` → `lifecycle.trainingScreenAppeared(destination:)`; `onDisappear` → `lifecycle.trainingScreenDisappeared()`.
- [`../../Peach/App/TrainingLifecycleCoordinator.swift`](../../Peach/App/TrainingLifecycleCoordinator.swift):101–111, 132–139 — `trainingScreenAppeared` → `startCurrentSession()` if `shouldAutoStartTraining`; `trainingScreenDisappeared` → `stopCurrentSession()` and nils `currentTrainingDestination`. `startCurrentSession()` calls `contribution.start()`; `stopCurrentSession()` calls `currentSession?.stop()`.
- [`../../Peach/Training/PitchMatching/PitchMatchingSession.swift`](../../Peach/Training/PitchMatching/PitchMatchingSession.swift):229–230, 276–277, 384–408 — `stop()` sends `.stopRequested`; the resulting `.stopAll` command clears `currentTrial`, `lastResult`, `sessionBestCentError`, `currentInterval`, `settings`, `keyboardPitchValue`, `midiPitchBendValue`, `referenceFrequency`, `currentHandle`, and cancels `midiListeningTask`.
- [`../../Peach/Training/PitchDiscrimination/PitchDiscriminationSession.swift`](../../Peach/Training/PitchDiscrimination/PitchDiscriminationSession.swift):378–395 — mirrors the pattern: clears `currentTrial`, `lastCompletedTrial`, `sessionBestCentDifference`, `currentInterval`, `settings`.
- [`../../Peach/App/TrainingLifecycleCoordinator.swift`](../../Peach/App/TrainingLifecycleCoordinator.swift):113–122 — **Prior art.** `helpSheetPresented()` snapshots `wasActiveBeforeHelpSheet = isTrainingActive` and calls `stopCurrentSession()`; `helpSheetDismissed()` re-issues `startCurrentSession()` if it was active. **This pattern is restart-from-scratch, not state preservation** — the resumed session starts a fresh trial. The flag is the right shape for nav-push routing; the missing piece is real in-trial preservation.

**Delta vs. catalog (PF-003):**

- **Confirmed in full.** Both NavigationStack push (to Settings/Profile) and pop (to Start) fire the same `onDisappear` on the training screen — the modifier cannot distinguish intent without a coordinator-side hint or a SwiftUI-version environment signal. Distinguishing temporary push from permanent pop requires either (a) coordinator state that knows "the user is about to push" vs. "pop", or (b) sessions that preserve state on pause and discard on stop, with the modifier choosing pause vs. stop based on navigation context. **Approach choice is a Task 2 decision.**

### Verified surfaces — PF-005 (Session Leak on Sound Source Change)

- [`../../Peach/App/PeachApp.swift`](../../Peach/App/PeachApp.swift):179–204 — `handleSoundSourceChanged(_:)` rebuilds `notePlayer`, then reassigns `pitchDiscriminationSession` and `pitchMatchingSession` via `Self.createPitchDiscriminationSession`/`createPitchMatchingSession` *without calling `stop()` on the outgoing instances*. Calls `rebuildCoordinators()` after.
- [`../../Peach/App/PeachApp.swift`](../../Peach/App/PeachApp.swift):206–222 — `rebuildCoordinators()` reassigns `trainingLifecycle` and `settingsCoordinator`. **Side-effect worth noting:** the new `trainingLifecycle` is a fresh instance — `currentTrainingDestination`, any pause state, `wasActiveBeforeHelpSheet`, and `autoStartSetting` are all lost (re-initialized from `initialAutoStartSetting`). Existing behavior, but it widens the "what changes through a sound-source swap" surface beyond just the two sessions.
- [`../../Peach/Training/PitchMatching/PitchMatchingSession.swift`](../../Peach/Training/PitchMatching/PitchMatchingSession.swift):129–162 — MIDI listening task spawned from `startMIDIListening()` consumes `midiInput.events` (`AsyncStream`); stored in `lifecycle.setTrainingTask(...)` (line 161 area). Outlives reassignment unless `lifecycle` is dropped — but the *old* `lifecycle` is dropped with the old session, which cancels its tracked tasks via deinit chain.
- [`../../Peach/Core/Training/SessionLifecycle.swift`](../../Peach/Core/Training/SessionLifecycle.swift):8, 36–55 — `SessionLifecycle` holds `trainingTask: Task<Void, Never>?` and `feedbackTask: Task<Void, Never>?`. These are owned by reference; if the session is reassigned, the old `SessionLifecycle` instance is deallocated only when no other references hold it. The `AudioSessionInterruptionMonitor` has an `isolated deinit` that removes notification observers when it's collected.
- **Sessions not affected by sound source.** `TimingOffsetDetectionSession` and `ContinuousRhythmMatchingSession` are not reassigned in `handleSoundSourceChanged` — they don't use the `NotePlayer` for sound output. Task 6 surface is narrower than the catalog implied.

**Delta vs. catalog (PF-005):**

- **Confirmed but narrowed.** Only `pitchDiscriminationSession` and `pitchMatchingSession` are reassigned. TOD/CRM are not in the leak surface.
- **Note for Task 6:** `rebuildCoordinators()` constructs a fresh `TrainingLifecycleCoordinator`. If pause/resume state lives in the coordinator (per the spec's approach), a sound-source change blows it away. **Acceptable consequence?** Most likely yes — a sound-source change is a user-initiated config event, not transient navigation. But the Task 2 approach decision should name whether the coordinator's pause state survives a sound-source swap. (Spec acceptance says: "outgoing session(s) are stopped before replacement instances are constructed" — that wording is compatible with either choice.)

### Fourth symptom — adjacent cluster member

[`../../Peach/App/TrainingLifecycleCoordinator.swift`](../../Peach/App/TrainingLifecycleCoordinator.swift):113–122 — **`helpSheetPresented()` is PF-003 in miniature.** A modal help sheet opens, the coordinator calls `stopCurrentSession()` which clears in-trial state, and on dismiss `startCurrentSession()` begins a fresh trial. The auto-restart smooths the UX *for the bookkeeping* (the user returns to a running training screen if they were active), but the in-trial state (`currentTrial`, `sessionBestCentError`/`sessionBestCentDifference`, `lastResult`) is gone exactly as in PF-003.

This was not in the catalog. It is the same root cause and the same fix shape — routing `helpSheetPresented` through pause and `helpSheetDismissed` through resume instead of stop/start. **Question for human:** include in this story's scope (one extra line at each call site once pause/resume exists), or open a PF-### follow-up and leave help-sheet alone?

## Tasks & Acceptance

**Execution:**

- [x] **Task 1 — Verification (must complete and review before any code change).** Read the code surfaces cited above against the catalog entries for PF-001, PF-003, PF-005. For each entry, confirm or correct: (a) the cited symbols still exist with the cited behavior, (b) the root-cause framing in the catalog still holds, (c) no in-flight work has partially resolved the issue, (d) no adjacent code reveals a fourth symptom that belongs in this cluster. Output: append the verified code map under the "Code Map" heading above with file paths + line numbers; list any deltas as bullet points; flag any entry whose description needs revision. **Halt for human review before Task 2.** Per `[[feedback_ask_dont_assume]]`, do not silently re-scope.
- [x] **Task 2 — Approach lock-in (post-verification).** Based on the verification output, finalize: (a) the exact shape of `pause()`/`resume()` on the `TrainingSession` protocol, (b) the coordinator's routing of app-deactivation, nav-push, nav-pop, and sound-source-change events, (c) the deletion list for the legacy session-level mechanism. Update Boundaries & Constraints if Ask-First conditions triggered.
- [x] **Task 3 — Protocol & coordinator changes.** Implement the locked-in protocol and coordinator additions. Tests-first per project convention: protocol contract tests pin the pause/resume preservation contract before the implementation lands.
- [x] **Task 4 — Per-session implementations.** Implement `pause()`/`resume()` on each `TrainingSession` conformer. Preserve in-trial state per the contract; verify in unit tests.
- [x] **Task 5 — Wire the training screen.** Route `onDisappear` to pause and the explicit session-end path to stop. Verify the round-trip Settings → training-screen preserves state.
- [x] **Task 5b — Route help sheet through pause/resume.** Update `helpSheetPresented()` / `helpSheetDismissed()` in `TrainingLifecycleCoordinator` to call pause/resume instead of stop/start. Replace the `wasActiveBeforeHelpSheet` snapshot with the coordinator's pause state (or drop it if pause/resume make it redundant). Verify in-trial state survives a help-sheet round-trip. (Added during Task 1 verification — scope expansion approved 2026-06-05.)
- [x] **Task 6 — Wire `PeachApp` sound-source change.** Route through the coordinator. Verify no orphan Tasks via a leak-style test (or observable assertion).
- [x] **Task 7 — Remove the macOS notification path.** Delete the `backgroundNotificationName` plumbing on macOS; iOS path unchanged.
- [x] **Task 8 — Catalog hygiene.** Remove the PF-001, PF-003, PF-005 sections from `docs/implementation-artifacts/deferred-work.md`. Cite the closed IDs in the commit message.
- [x] **Task 9 — Pre-commit gates.** Run `bin/test.sh && bin/test.sh -p mac` and `bin/test.sh --research && bin/test.sh --research -p mac`. Both green.

**Acceptance Criteria:**

- **PF-001.** Given an active training session on macOS, when the user switches to another app, then exactly one `Lifecycle` "App deactivated" log line appears (from the coordinator's `handleAppDeactivated()` path), and no per-session `AudioSessionInterruptionMonitor` fires its `backgroundNotificationName` handler. (Reframed during Task 1 verification: the catalog's "4× 'stop() called but already idle' log lines" claim was not literal — no such log exists; the redundancy is silent. The reframed acceptance pins the architectural fix to an observable signal.)
- **PF-003.** Given an active training session with `currentTrial != nil` on either platform, when the user taps Settings or Profile in the training screen toolbar and then returns, then `currentTrial`, `sessionBestCentDifference`, and `lastResult` are the same values they were before the navigation push; training continues from the preserved state, not from scratch.
- **PF-003 (negative case).** Given an active training session, when the user pops back to the Start Screen, then the session stops and in-trial state is cleared — same behavior as today.
- **Help sheet (added 2026-06-05).** Given an active training session with `currentTrial != nil`, when the user opens the help sheet from the training screen and then dismisses it, then `currentTrial`, `sessionBestCentDifference`/`sessionBestCentError`, and `lastResult` are the same values they were before the sheet was presented; training resumes from the preserved state, not from scratch.
- **PF-005.** Given an active training session, when the user changes the Sound Source in Settings, then the outgoing session(s) are stopped before the replacement instances are constructed; no Tasks from the outgoing instances continue after the swap (asserted by test).
- **PF-005 (no-op case).** Given no active session, when the user changes the Sound Source, then sessions are replaced without `stop()` calls and without log noise.
- **iOS parity.** App-backgrounding behavior on iOS is unchanged from `baseline_commit`; existing iOS interruption tests still pass without modification.
- **Pre-commit gate.** Both schemes pass on both platforms: `bin/test.sh && bin/test.sh -p mac` (Debug) and `bin/test.sh --research && bin/test.sh --research -p mac` (Research). No new compiler warnings.
- **Catalog hygiene.** PF-001, PF-003, PF-005 sections are removed from `deferred-work.md` in the closing commit, which cites the three IDs.

## Spec Change Log

### 2026-06-05 — Step-04 review patches (Blind / Edge Case / Acceptance reviewers)

Three reviewers produced 53 raw findings. Classification per `step-04-review.md`:

**Patches applied (high-severity bugs in the as-implemented preservation contract):**

- **PitchMatchingSession.pause()** now resets `hasBeenDeflected`, `midiPitchBendValue`, `currentPitchValue`, `keyboardPitchValue`, and (when paused from `.showingFeedback`) `lastResult`. Without this, the first neutral pitch-bend after resume would auto-commit the trial silently (Edge Case Hunter #7).
- **PitchDiscriminationSession.pause()** now clears `showFeedback` and `isLastAnswerCorrect`. Otherwise the prior correctness overlay rendered over the resumed reference playback (Edge Case Hunter #6).
- **TimingOffsetDetectionSession.pause()** clears `showFeedback` and `isLastAnswerCorrect`. `resume()` now chains `restartSequencerForCurrentTrial`'s `startTask` behind the pause-spawned `stopTask` — prevents the race that `enqueueSequencerStop` was originally introduced to prevent (Edge Case Hunter #3, #4).
- **ContinuousRhythmMatchingSession.pause()** clears `showFeedback` and `lastHitOffsetMs`. `startSequencer` effect now awaits the pause-spawned `pendingSequencerStop` before issuing `beatSequencer.start(...)` — closes a sequencer start-before-stop race on fast pause→resume cycles (Edge Case Hunter #4).
- **PitchMatching/PitchDiscrimination resume** now chains `notePlayer.play(...)` behind a `pendingAudioStop` Task captured at pause time. Prevents NotePlayer race on fast cycles (Edge Case Hunter #8).
- **PeachApp.handleSoundSourceChanged** now stops **all four** sessions (guarded on `!isIdle`), not just the two pitch sessions. Without this, a paused TOD or CRM session would survive `rebuildCoordinators()` (which constructs a fresh `TrainingLifecycleCoordinator` with no `pausedSession` reference), leaving the session in a state from which neither the modifier nor the new coordinator could recover until manually toggled (Edge Case Hunter #1).
- **TrainingLifecycleCoordinator.startScreenAppeared()** added and called from `StartScreen.onAppear`. Discards any lingering paused session — closes the PF-003 negative-case acceptance ("pop-to-Start stops the session"). Approved 2026-06-05 (Q4); chosen over a spec-text relaxation because pop-to-Start is the dominant route by which a paused session would otherwise linger indefinitely. (Acceptance Auditor #1.)
- **PF-005 no-op case (Acceptance Auditor #2):** `handleSoundSourceChanged` now guards `stop()` on `!isIdle` per the literal acceptance text. Idle sessions are no longer touched.
- **`PlatformNotifications.swift` deleted** (Acceptance Auditor #17 — caught a failed deletion; the file was orphaned but still on disk).
- **`TrainingSession` protocol** gained doc comments on `pause()` and `resume()` describing idempotency and the stop-before-start serialization requirement (Blind Hunter #8).

**Deferred (cataloged in `deferred-work.md`):**

- **PF-048** — TOD `gridOrigin` not refreshed on resume (Edge Case Hunter #5). Bounded drift.
- **PF-049** — Help-sheet open at audio-interruption silently does nothing on dismiss (Edge Case Hunter #9). Narrow interleaving.
- **PF-050** — Scene-phase background while help sheet open downgrades resume to cold restart (Edge Case Hunter #10). Narrow interleaving.
- **PF-051** — Per-sub-state pause/resume test coverage is partial (Edge Case Hunter #14). No current bug; surface for future drift.

**Rejected (noise):**

- Blind Hunter #1 (stale `pausedSession` identity) — assignment ordering is correct; `appearingSession` is computed *after* `currentTrainingDestination = destination`.
- Blind Hunter #5 (`isPaused` + state two sources of truth) — `isPaused` is private and only consulted by pause/resume internally; protocol surface is clean.
- Blind Hunter #7 (backgrounding regression risk) — Acceptance Auditor verified that iOS `AVAudioSession` interruption path is preserved and that scenePhase still routes background to `stopCurrentSession()`; no regression.
- Blind Hunter #9 (tests don't assert order), #10 (orphan const) — low.
- Edge Case Hunter #11, #12, #13 — low / self-corrected.

**Tests added:**

- `PitchMatchingSessionPauseResumeTests.pauseClearsMidiDeflectionState` — reproduces the auto-commit bug and verifies the fix.
- `PitchDiscriminationSessionPauseResumeTests.pauseClearsShowingFeedbackOverlay` — pins the feedback-overlay clear contract.
- `TrainingLifecycleCoordinatorTests.startScreenAppearedDiscardsPaused` — pins PF-003 negative-case acceptance.

**Pre-commit gates re-run after patches:** iOS Debug 1958, macOS Debug 1952, iOS Research 2118, macOS Research 2112 — all green.

### 2026-06-05 — Task 2 approach lock-in

**Protocol shape.** Add `pause()` and `resume()` to `TrainingSession`:

```swift
protocol TrainingSession: AnyObject {
    var isIdle: Bool { get }
    func stop()
    func pause()
    func resume()
}
```

**Preservation contract.**

- `pause()` cancels in-flight Tasks and stops audio (`notePlayer.stopAll()` for pitch sessions; sequencer stop for TOD/CRM). **Preserves** `currentTrial` / `lastCompletedTrial`, `lastResult`, `sessionBestCent*`, `currentInterval`, `settings`, and in-flight user input (`keyboardPitchValue`, `midiPitchBendValue`). State machine moves to an internal `.paused` state. `isIdle` remains `false`. No-op when idle.
- `resume()` re-engages the current trial from its start: pitch sessions re-play the reference note and re-await input; sequencer-driven sessions re-arm the sequencer. If `currentTrial == nil` (paused between trials), behaves like `start()`. No-op when not paused.
- `stop()` unchanged: cancels Tasks, stops audio, clears all data, transitions to `.idle`. Also valid from `.paused`.

**Coordinator routing.** Pause state lives on the coordinator (per-destination flag, since only one destination is current). Sessions are unaware of nav context.

| Event | Action |
|-------|--------|
| `handleScenePhase(_:.background)` (iOS) / `(.background\|.inactive)` (macOS) | `stopCurrentSession()` |
| `handleScenePhase(_:.active)` | `startCurrentSession()` if `shouldAutoStartTraining` |
| `handleAppDeactivated()` (macOS NSApp.didResignActive) | `stopCurrentSession()` |
| `handleAppActivated()` (macOS NSApp.didBecomeActive) | `startCurrentSession()` if `shouldAutoStartTraining` |
| `trainingScreenAppeared(destination:)` | Paused for same destination → `resumeCurrentSession()`. Else → `startCurrentSession()` if `shouldAutoStartTraining` |
| `trainingScreenDisappeared()` | `pauseCurrentSession()` (NOT stop). `currentTrainingDestination` stays set |
| `helpSheetPresented()` | `pauseCurrentSession()`. Drop the `wasActiveBeforeHelpSheet` flag |
| `helpSheetDismissed()` | `resumeCurrentSession()` |
| `toggleTraining()` | `isPaused` → resume. `!isIdle` → stop. Else → start |
| `navigate(to:)` (menu nav) | `stop()` + `awaitIdle()` + emit nav request. Clears pause state |
| `handleSoundSourceChanged()` (PeachApp) | Stop outgoing pitch sessions BEFORE reassignment. `rebuildCoordinators()` discards pause state (acceptable) |

**Deletion list (Task 7).**

- `Peach/App/PeachApp.swift:9` — drop `backgroundNotificationName` static constant (becomes unused).
- `Peach/App/PeachApp.swift:429, 448, 466, 484` — drop `backgroundNotificationName:` argument from all four `create*Session` callsites.
- `Peach/Training/PitchMatching/PitchMatchingSession.swift` — drop `backgroundNotificationName` and `foregroundNotificationName` init parameters; remove pass-through to `SessionLifecycle`.
- `Peach/Training/PitchDiscrimination/PitchDiscriminationSession.swift` — same.
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift` — same.
- `Peach/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift` — same.
- `Peach/Core/Training/SessionLifecycle.swift` — drop `backgroundNotificationName` and `foregroundNotificationName` init parameters; stop passing them to `AudioSessionInterruptionMonitor`.
- `Peach/Core/Audio/AudioSessionInterruptionMonitor.swift:18–24, 36–47` — drop the two `Notification.Name?` init parameters and the platform-notification observer loop. The `audioInterruptionObserver.setupObservers(...)` call for AVAudioSession interruptions (iOS phone-call/AirPods) stays.
- `Peach/App/Platform/PlatformNotifications.swift` — if no other caller references `.background` / `.foreground`, file becomes dead. `ContentView+macOS.swift` uses `NSApplication.didResignActiveNotification` directly (not via the enum), so the enum likely becomes unused. Verify and remove if so. Doc references in `docs/walkthrough/5-composition-root.md:134` and `docs/project-context.md:101` need updating too.
- `PeachTests/Core/Audio/AudioSessionInterruptionMonitorTests.swift:76, 117` — remove the two tests asserting the dropped observer behavior.
- `PeachTests/Training/PitchMatching/PitchMatchingSessionTests.swift:41–54, 1123, 1139, 1155, 1188` — remove the test-helper parameters and the four backgrounding tests; replace with coordinator-level tests for the new architecture.
- `docs/planning-artifacts/architecture.md:1917–1918` and `docs/walkthrough/3-training-sessions.md:160–161` — update sample-code references.

**Catalog framing correction.** PF-001's "macOS only" wording is inaccurate. `PeachApp.swift:9` defines `backgroundNotificationName` without `#if os()` gating; iOS sessions also subscribe to `UIApplication.didEnterBackgroundNotification`, which `handleScenePhase` also catches. Same architectural redundancy on both platforms (iOS: 2 paths; macOS: 3 paths). The cleanup applies symmetrically. iOS behavior unchanged: scenePhase already routes through the coordinator. Approved 2026-06-05 (Q3).

### 2026-06-05 — Task 1 verification deltas

## Suggested Review Order

**Lifecycle policy consolidation (the design intent)**

- Coordinator gains pause/resume routing, a `pausedSession` field, and a Start-screen hook for PF-003 negative case.
  [`TrainingLifecycleCoordinator.swift:34`](../../Peach/App/TrainingLifecycleCoordinator.swift#L34)
- The screen modifier already routed disappear/appear; the coordinator's new pause semantics take effect through it without any view-layer change.
  [`TrainingScreenModifier.swift:36`](../../Peach/App/TrainingScreenModifier.swift#L36)
- New `startScreenAppeared()` hook called from `StartScreen.onAppear` — discards any lingering paused session so pop-to-Start stops cleanly.
  [`StartScreen.swift:78`](../../Peach/Start/StartScreen.swift#L78)

**Protocol surface (the contract)**

- `TrainingSession` gains `pause()` / `resume()` with doc comments capturing the preservation, idempotency, and stop-before-start serialization contract.
  [`TrainingSession.swift:1`](../../Peach/Core/TrainingSession.swift#L1)

**Per-session preservation contract (where the bugs lived)**

- PitchMatching: `pause()` resets in-flight MIDI deflection state so resume cannot auto-commit on a stale neutral bend. Resume chains `notePlayer.play` behind the pause-spawned stop.
  [`PitchMatchingSession.swift:229`](../../Peach/Training/PitchMatching/PitchMatchingSession.swift#L229)
- PitchDiscrimination: same shape — clears feedback overlay flags on pause, chains stop-before-play on resume.
  [`PitchDiscriminationSession.swift:215`](../../Peach/Training/PitchDiscrimination/PitchDiscriminationSession.swift#L215)
- TOD: pause uses the existing `enqueueSequencerStop` chain; resume's `restartSequencerForCurrentTrial` awaits the prior `stopTask` before re-entering the sequencer's serial run loop.
  [`TimingOffsetDetectionSession.swift:228`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift#L228)
- CRM: in-trial cycle is musically unresumable mid-tap, so resume restarts the trial cycle while preserving `lastTrialResult`. Sequencer start chains behind `pendingSequencerStop`.
  [`ContinuousRhythmMatchingSession.swift:170`](../../Peach/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift#L170)

**Per-session backgrounding plumbing removed (PF-001)**

- Per-session notification subscriptions are gone; `AudioSessionInterruptionMonitor` keeps only the AVAudioSession interruption path (iOS phone-call / AirPods).
  [`AudioSessionInterruptionMonitor.swift:18`](../../Peach/Core/Audio/AudioSessionInterruptionMonitor.swift#L18)
- `SessionLifecycle.init` drops the two `Notification.Name?` parameters.
  [`SessionLifecycle.swift:14`](../../Peach/Core/Training/SessionLifecycle.swift#L14)
- `PlatformNotifications.swift` deleted — orphaned with no other consumers.

**Composition-root wiring (PF-005)**

- Sound-source change stops all four sessions before reassignment + `rebuildCoordinators()` — guards against pause state surviving the coordinator swap.
  [`PeachApp.swift:179`](../../Peach/App/PeachApp.swift#L179)

**Test coverage**

- Coordinator pause/resume routing under mocks: nine new tests pin the directional contracts for pause-on-disappear, resume-on-reappear, discard-on-different-destination, start-screen-discards-paused, etc.
  [`TrainingLifecycleCoordinatorTests.swift:431`](../../PeachTests/App/TrainingLifecycleCoordinatorTests.swift#L431)
- Per-session contract tests: PitchMatching MIDI-deflection clear (the silent auto-fail bug), PitchDiscrimination feedback overlay clear, CRM resume restarts cycle.
  [`PauseResumeContractTests.swift:1`](../../PeachTests/Training/PauseResumeContractTests.swift#L1)

**Catalog + docs**

- PF-001, PF-003, PF-005 removed from `deferred-work.md`. PF-048/049/050/051 added for step-04 deferrals.
  [`deferred-work.md:32`](deferred-work.md#L32)
- Walkthrough and architecture docs trim the removed `backgroundNotificationName` parameter from sample code; project-context drops the dead `PlatformNotifications` reference.
  [`architecture.md:1907`](../planning-artifacts/architecture.md#L1907)



- **PF-001 reframed.** Catalog's "4× redundant 'stop() called but already idle' log lines per app-switch" claim is not literal — there is no such log line in the codebase (state machine silently no-ops `(.idle, .stopRequested)`). Acceptance criterion updated to a single-log assertion plus a per-session-monitor-non-fire assertion. Architectural redundancy framing unchanged.
- **Third stop path documented.** `TrainingLifecycleCoordinator.handleScenePhase(old:new:)` is a third independent path on macOS (in addition to the `NSApplication.didResignActiveNotification` observer and the per-session monitors). It routes through `BackgroundPolicy.shouldStopTraining(newPhase:)`. Task 7 deletes only the per-session `backgroundNotificationName` plumbing; `handleScenePhase` and `handleAppDeactivated` both stay as the consolidated coordinator-owned paths.
- **PF-005 scope narrowed.** Only `pitchDiscriminationSession` and `pitchMatchingSession` are reassigned by `handleSoundSourceChanged`. TOD and CRM are not in the leak surface. Note: `rebuildCoordinators()` constructs a fresh `TrainingLifecycleCoordinator` — any pause/resume state lives in the coordinator and is therefore lost across a sound-source swap. Acceptable: sound-source change is an intentional user-initiated config event, not transient navigation.
- **Fourth symptom added — help sheet.** `helpSheetPresented()`/`helpSheetDismissed()` in `TrainingLifecycleCoordinator` follow the same restart-from-scratch pattern as PF-003. Scope expansion approved (Q2 on 2026-06-05); Task 5b added and a help-sheet acceptance criterion added. Catalog does not gain a new PF-### — the cluster fix absorbs it.
