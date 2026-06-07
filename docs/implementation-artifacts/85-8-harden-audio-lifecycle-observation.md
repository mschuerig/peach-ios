---
title: 'Story 85.8: Harden audio-session lifecycle observation against OS-level events'
type: 'cleanup'
created: '2026-06-06'
status: 'done'
baseline_commit: '26aaebdd'
context:
  - '{project-root}/docs/implementation-artifacts/deferred-work.md'
  - '{project-root}/.claude/skills/audio-programming/references/avaudiosession.md'
  - '{project-root}/.claude/skills/audio-programming/references/avaudio-engine.md'
closes:
  - 'PF-055'
  - 'PF-056'
  - 'PF-057'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem.** Three OS-posted audio-lifecycle notifications named by the `audio-programming` skill's lifecycle scope are either observed incorrectly or not observed at all in Peach today:

- **PF-055** — `IOSAudioInterruptionObserver.handleAudioInterruption` treats every `.began` interruption as real; iOS 14.5+ synthesizes a `.began` with reason `.appWasSuspended` when an app is merely suspended in background. Peach calls `onStopRequired` and silences a session that was about to resume cleanly. Dominant false-positive on iOS 16+.
- **PF-056** — `AVAudioEngineConfigurationChangeNotification` is not observed (`grep` returns zero hits). When iOS reports a hardware sample-rate or channel-count change (Bluetooth codec switch, external interface plug-in), `AVAudioEngine` self-stops and uninitializes; no code restarts it. The next training session is silent until app relaunch.
- **PF-057** — `AVAudioSession.mediaServicesWereResetNotification` is not observed. When `mediaserverd` crashes and respawns, every `AVAudioEngine`/`AVAudioUnitSampler`/`AudioComponentInstance` reference is invalid; audio is dead silent for the rest of the process lifetime.

**Approach.** Two-phase: verify-and-design, then implement.

1. **Verify-and-design** (Task 1) — invoke `/audio-programming` against the three audit targets (`Peach/App/Platform/IOSAudioInterruptionObserver.swift`, `Peach/Core/Audio/SoundFontEngine.swift`, and the `AudioSessionConfiguring` configurator path) to confirm or correct each PF's framing against current code. Output: per-PF handler ownership decision, response-shape sketch (including isolation hops — the configuration-change notification can fire on a background thread, so the handler must bounce to `@MainActor` before mutating the engine), and a recovery-UX decision for PF-057 (silent rebuild vs user-visible "audio reconnected, session stopped" notice). Halt before any code change.

2. **Implement** (Tasks 2+) — tests-first per PF, apply the audit's chosen ownership and response shapes, catalog hygiene, gates.

**Design principle.** PF-055 narrows existing logic (one new key read, one early return); PF-056 and PF-057 add observers near the resources they recover. New port abstractions are added only if the audit demonstrates the existing surfaces cannot host the handlers cleanly. The cluster's shared shape is "observe a named `Notification` → classify on a `userInfo` key → mutate engine/session on the right actor."

## Boundaries & Constraints

**Always:**
- PF-055, PF-056, PF-057 are closed by this story or scope is renegotiated with explicit human authorization.
- The configuration-change handler bounces to `@MainActor` before mutating `SoundFontEngine` state. No engine API is touched off the main actor.
- Sessions stop through the existing coordinator path (`TrainingLifecycleCoordinator`); the recovery handlers never bypass it to mutate session state directly.
- Existing reachable behavior is preserved: `.began` with reasons other than `.appWasSuspended` continues to stop; route-change `oldDeviceUnavailable` continues to stop; `.ended` continues to remain stopped.
- Pre-commit gate: `bin/test.sh && bin/test.sh -p mac` AND `bin/test.sh --research && bin/test.sh --research -p mac` green.
- Catalog hygiene on merge: remove PF-055, PF-056, PF-057 sections from `deferred-work.md` in the same change; cite each ID in the commit message.

**Ask First:**
- Task 1 halts for human review of the audit before any code change. Michael confirms per-PF handler ownership, isolation discipline, and the PF-057 recovery UX decision.
- If the audit finds a PF was already incidentally fixed elsewhere (e.g., code drift since 2026-06-06 filing), pause and confirm whether it can be marked closed without further code.
- If hosting PF-056 / PF-057 cleanly requires a new port protocol (one or more) added to `Core/Ports/`, pause and confirm the new surface area before introducing it.
- If the audit recommends folding PF-057's `mediaServicesWereLostNotification` companion into scope (skill ref names both reset + lost), pause and confirm before expanding scope.

**Never:**
- No silencing or relaxing PF-055's existing `.began`-with-reason-`.default` stop behavior. The filter is strictly additive.
- No mutation of `SoundFontEngine` state from a background thread. The configuration-change observer is the canonical place where this would be tempting; it must hop.
- No introduction of an auto-resume on `.ended` (skill ref documents this as the `.shouldResume` check; PF-055's frame explicitly excludes the `.ended` branch — current "remains stopped" stays).
- No expansion to PF-054 (flag-vs-FIFO MIDI dispatch); the deferred-work catalog reaffirms it but PF-054 stays independently tracked with its existing disposition.
- No `mediaServicesWereLostNotification` handling unless Ask-First confirms (skill ref names it; this story scopes to "were reset" per the catalog entry).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| PF-055 — `.appWasSuspended` interruption | `.began` notification with `AVAudioSessionInterruptionReasonKey = .appWasSuspended` | `onStopRequired` NOT called; existing route logging preserved | N/A — handler returns early |
| PF-055 — genuine `.began` | `.began` notification with reason `.default` (or absent reason key on older iOS) | `onStopRequired` called as today | N/A |
| PF-055 — `.began` with other reason (`.builtInMicMuted`, `.routeDisconnected`) | Same notification shape, non-`appWasSuspended` reason | `onStopRequired` called as today | N/A |
| PF-055 — `.ended` | `.ended` notification, any reason | No-op; session remains stopped | N/A |
| PF-056 — sample-rate change | `AVAudioEngineConfigurationChangeNotification` posts (sim: route flip under `enableManualRenderingMode(.realtime)`) | Handler hops to MainActor → re-reads `outputNode.outputFormat`, reconnects `sourceNode` with the new format, calls `engine.start()` | If `engine.start()` throws, log and surface via existing audio-error path |
| PF-056 — notification on background thread | Same as above, posted off-main | Handler does NOT touch engine APIs before the hop | Verified by the integration test's actor-isolation assertion |
| PF-057 — media services reset | `AVAudioSession.mediaServicesWereResetNotification` posts (sim: synthetic notification post) | `SoundFontEngine` torn down + rebuilt (new `AVAudioEngine` + `AVAudioUnitSampler`s); `AudioSessionConfiguring.configure` re-invoked; previously-loaded presets reloaded; coordinator stops the active session per Task 1's UX decision | If rebuild throws, log at `.error`, surface via existing audio-error path; do not retry in-loop |

</frozen-after-approval>

## Code Map

**Verified by Task 1 audit (2026-06-07, against `baseline_commit`).** Catalog framings confirmed for all three PFs: PF-055 site at [`IOSAudioInterruptionObserver.swift:52-55`](../../Peach/App/Platform/IOSAudioInterruptionObserver.swift#L52) (no reason inspection); PF-056 has zero observers anywhere under `Peach/`, `sourceNode` connected with explicit-format derivation at [`SoundFontEngine.swift:299-307`](../../Peach/Core/Audio/SoundFontEngine.swift#L299); PF-057 has zero observers, `loadedPresets` at [`SoundFontEngine.swift:233`](../../Peach/Core/Audio/SoundFontEngine.swift#L233) is the reload inventory, [`TrainingLifecycleCoordinator.stopCurrentSession`](../../Peach/App/TrainingLifecycleCoordinator.swift) is the canonical session-stop entry point.

**Touched files (locked-in under decisions A=(c′), B=B1, C=fold-in, D=silent — see Spec Change Log 2026-06-07):**

- [`Peach/Core/Ports/AudioInterruptionObserving.swift`](../../Peach/Core/Ports/AudioInterruptionObserving.swift) — `setupObservers` signature extended with `onMediaServicesLost` and `onMediaServicesReset` closures (B1)
- [`Peach/App/Platform/IOSAudioInterruptionObserver.swift`](../../Peach/App/Platform/IOSAudioInterruptionObserver.swift) — PF-055 `.appWasSuspended` reason-key filter on `.began`; PF-057 observers for `mediaServicesWereLost` + `mediaServicesWereReset`; remains the single iOS port impl
- [`Peach/App/Platform/NoOpAudioInterruptionObserver.swift`](../../Peach/App/Platform/NoOpAudioInterruptionObserver.swift) — macOS no-op extended with no-op `onMediaServicesLost` / `onMediaServicesReset` parameters
- [`Peach/Core/Audio/SoundFontEngine.swift`](../../Peach/Core/Audio/SoundFontEngine.swift) — PF-056 `AVAudioEngineConfigurationChangeNotification` observer registered in `init`, removed in `deinit`; self-recovery (SR re-read, `sourceNode` reconnect, `engine.start()`); `rebuildAfterMediaReset()` method added for coordinator-invoked PF-057 recovery (silent — Decision D)
- [`Peach/App/TrainingLifecycleCoordinator.swift`](../../Peach/App/TrainingLifecycleCoordinator.swift) — gains `handleAudioInterruptionStop()`, `handleMediaServicesLost()`, `handleMediaServicesReset()` methods; receives an injected `SoundFontEngine` reference for the reset path; `mediaServicesLost` sets a "rebuild pending" flag consumed when Reset fires (Decision C)
- [`Peach/App/PeachApp.swift`](../../Peach/App/PeachApp.swift) — constructs ONE app-scoped `AudioInterruptionObserving` instance, wires its three closures to coordinator methods; `makeAudioInterruptionObserver()` retires per-session call sites; coordinator gains the `SoundFontEngine` injection
- [`Peach/Core/Audio/AudioSessionInterruptionMonitor.swift`](../../Peach/Core/Audio/AudioSessionInterruptionMonitor.swift) — **retired**. Its job (own observer tokens, call `setupObservers`, `removeObserver` in deinit) moves to a single instance owned by `PeachApp` or coordinator; deleted in this story
- [`Peach/Core/Training/SessionLifecycle.swift`](../../Peach/Core/Training/SessionLifecycle.swift) — drop `audioInterruptionObserver` parameter and `AudioSessionInterruptionMonitor` construction; the `onStopRequired` chain is replaced by coordinator-driven `stopCurrentSession`
- The four session constructors — drop `audioInterruptionObserver: AudioInterruptionObserving` parameter from `PitchDiscriminationSession.init`, `PitchMatchingSession.init`, `TimingOffsetDetectionSession.init`, `ContinuousRhythmMatchingSession.init`; remove their `SessionLifecycle` construction wiring for the observer
- `PeachTests/App/Platform/IOSAudioInterruptionObserverTests.swift` — extended for PF-055 reason filtering + PF-057 Reset trigger + Lost trigger
- `PeachTests/Core/Audio/SoundFontEngineConfigurationChangeTests.swift` — new file for PF-056 integration test under `enableManualRenderingMode(.realtime)`
- `PeachTests/App/TrainingLifecycleCoordinatorTests.swift` — extended for the three new coordinator methods (existing fixture pattern)
- Any session test fixtures that constructed the observer parameter — adapted to the new constructor signatures (estimated 4–6 test files)

## Design Audit Findings

_Task 1 audit run 2026-06-07 against `baseline_commit`. References loaded: `.claude/skills/audio-programming/references/avaudiosession.md`, `avaudio-engine.md`._

### Per-PF verification table

| PF | Catalog framing | Handler ownership | Registration site | Response shape (terse) | Isolation hop | Test mechanism |
|---|---|---|---|---|---|---|
| **PF-055** | Holds — no reason inspection at `IOSAudioInterruptionObserver.swift:52-55` | `IOSAudioInterruptionObserver` (existing type) | Existing `setupObservers` — no new wiring | Parse `AVAudioSessionInterruptionReasonKey` alongside type; if `.appWasSuspended`, log + return; else current `.began` path | Unchanged — outer closure on `.main` queue extracts UInts (Sendable) synchronously, hops via `Task { @MainActor in … }` | Synthetic `NotificationCenter` post; spy callback; iOS-only (`#if os(iOS)`) |
| **PF-056** | Holds — zero observers anywhere; `sourceNode` is the SR-dependent reconnection target | `SoundFontEngine` (NOT iOS-only — macOS device change also fires this notification; lives in `Core/Audio/` without `#if`) | `SoundFontEngine.init` after `engine.start()` succeeds; token stored in `private var configChangeObserver: NSObjectProtocol?`; removed in `deinit` | Identity-check `notification.object` sync → `Task { @MainActor in … }` → re-read `outputNode.outputFormat`; if SR unchanged, just `engine.start()` if not running; if changed, disconnect + recreate `sourceNode` with new format bound to the same `DoubleBufferedScheduleState`, reconnect, `engine.start()`. No sampler/preset reload (samplers are SR-agnostic at the AVAudioUnit boundary; mainMixer SRCs at boundary). | Notification fires on background thread → no engine mutation pre-hop; all mutation on MainActor | `engine.enableManualRenderingMode(.realtime, …)` to drive without hardware; synthetic notification post with `object: engine`; assert `engine.isRunning` and new sample rate after `await Task.yield()` |
| **PF-057** | Holds — zero observers; `loadedPresets` is the reload inventory; `TrainingLifecycleCoordinator.stopCurrentSession` is the canonical stop | **Split**: registration in `IOSAudioInterruptionObserver` (iOS-only, AVAudioSession-scoped — keeps all session.* observation together); recovery action delegated via new closure on the port. Recovery composed at `PeachApp` and runs against `SoundFontEngine` + `TrainingLifecycleCoordinator`. | Extension to `AudioInterruptionObserving.setupObservers` signature: add `onAudioInfrastructureReset: @escaping () -> Void` (subject to Decision B); composed at `PeachApp` callers | Background → `Task { @MainActor in … }` → `onAudioInfrastructureReset()` → coordinator stops current session → `SoundFontEngine.rebuildAfterMediaReset()` (tear channels, re-`configure` session, fresh `AVAudioEngine`, recreate samplers, `loadSoundBankInstrument` for each saved `loadedPresets` entry, rewire sourceNode, `engine.start()`) → surface user-visible notice | Background → MainActor hop pre any AVAudio mutation. `SoundFontEngine` is already `@MainActor`-isolated. `DoubleBufferedScheduleState` re-binds to the new sourceNode's render closure | Synthetic `NotificationCenter` post; assert spy `onAudioInfrastructureReset` invoked. Full rebuild path documented as integration-verified-on-real-reset (no reliable production trigger) |

### PF-057 recovery UX recommendation

**User-visible "audio reconnected, session stopped" notice** — not silent. Rationale: (1) `mediaserverd` crashes are rare enough that a one-line transient notice is not noise; when it does happen the user needs to know audio was just rebuilt to correctly attribute the silence-then-resume to OS recovery rather than app bug. (2) The coordinator-routed session stop is **already user-visible** — trial counter resets, UI returns to idle — so silent rebuild creates a mismatch between the visible state change and the unexplained cause. (3) The existing `AudioError` surface is structured for fatal `fatalError` display at startup, not transient banners; a one-off notice on the active screen via a `@State`-driven alert is cheaper than reusing the fatal-error machinery and gives Michael a single place to choose the copy (sober factual, informal "du"; subject to confirmation in Decision D).

### Cross-cutting concern — per-session observer multiplication

Each of the four sessions (PitchDiscrimination, PitchMatching, TimingOffsetDetection, ContinuousRhythmMatching) constructs its own `AudioInterruptionObserving` instance via `PeachApp.makeAudioInterruptionObserver()` and registers its own pair of `AVAudioSession.interruptionNotification` + `routeChangeNotification` observers. Adding a per-session PF-057 reset handler under this shape would produce four parallel rebuild paths racing — only one wins, the others either no-op or double-rebuild. Three viable splits:

- **(a) Per-session observers stay; engine-scoped + reset-scoped observers added separately.** PF-056 lives in `SoundFontEngine`; PF-057 reset observer registers ONCE in a fresh app-scoped observer (separate from per-session instances) wired at `PeachApp.setupSoundFontInfrastructure`. PF-055 stays inside the existing per-session observers. **Smallest delta; respects each notification's natural scope.** Recommended.
- **(b) Unify into one app-scoped `IOSAudioInterruptionObserver`** owning all three notifications; sessions read via multicast or coordinator mediation. Larger refactor; out of story scope.
- **(c) Move all session-stop wiring to `TrainingLifecycleCoordinator`** — the observer fans out to "stop the current session" which is exactly the coordinator's job; per-session callback chain collapses to one. Cleanest but a session-architecture change beyond this story.

### Out-of-scope confirmation

- `mediaServicesWereLostNotification` companion — skill ref names it; story Boundaries say it stays out; audit confirms deferral as the safe call (subject to Decision C).
- PF-054 (`trackActiveSession` invariant) — PF-057's rebuild does NOT re-open PF-054 because coordinator-routed stop runs before engine rebuild.
- `.ended` auto-resume — current "remains stopped" stays; independent of PF-055 per catalog.

### Audit Decisions for Michael (Ask-First gate)

**A. Cross-cutting observer architecture.** Pick (a), (b), or (c) from §Cross-cutting concern. Audit recommends **(a)**: PF-055 stays per-session; PF-056 in `SoundFontEngine`; PF-057 in a new app-scoped iOS-only observer.

**B. PF-057 port surface — closure-on-existing-port vs separate port.** Two shapes:
- **B1 — extend `AudioInterruptionObserving`**: add `onAudioInfrastructureReset` as a second closure on `setupObservers`. Smaller surface, ties reset to the same port the iOS implementation already owns.
- **B2 — new port `AudioInfrastructureResetObserving`**: separate protocol, separate iOS implementation, macOS no-op. Cleaner separation (reset has different scope than session interruption), more files.

Audit slightly favors **B1** under architecture (a), since reset is the same AVAudioSession-scoped notification family as interruption and the macOS no-op grows by one method, not one file.

**C. `mediaServicesWereLostNotification` fold-in.** Skill ref names it as the companion to Reset; the catalog and story Boundaries scope to Reset only. Audit recommends confirming the deferral. If we fold it in, both observers register at the same site with the same recovery closure (Lost handler logs + waits for Reset; no immediate rebuild, since rebuilding before mediaserverd respawns would fail).

**D. PF-057 recovery UX.** Audit recommends **user-visible notice** (transient banner on active screen). Alternative: silent rebuild. Decision shapes whether `PeachApp` composes a UI-surfacing closure or just the engine-rebuild + coordinator-stop pair.

**(Spec halts here per Task 1's "must complete and review before any code change". On Michael's decisions, Task 2 locks in the chosen ownership table + touched-files list, updates Boundaries if Ask-First triggered, then Task 3 writes the first failing test.)**

## Tasks & Acceptance

**Execution:**

- [x] **Task 1 — Verify-and-design audit (must complete and review before any code change).** Invoke `/audio-programming` against the three audit targets named in Code Map. For each PF, output: (i) is the catalog framing still accurate against current code, (ii) handler ownership recommendation, (iii) response-shape sketch including the isolation hop for PF-056, (iv) for PF-057, a silent-vs-user-visible recovery UX recommendation with rationale. Produce a per-PF table of: file owner, observer registration site, response steps, isolation discipline, test surface. **Halt for human review.** Michael confirms ownership, hops, and the PF-057 recovery UX. — _2026-06-07: audit complete; decisions A=(c′), B=B1, C=fold-in, D=silent locked in (see Spec Change Log)._
- [x] **Task 2 — Approach lock-in (post-audit).** Code Map and per-PF ownership table appended above. Spec Change Log entry 2026-06-07 records all four decisions and the cascade. Boundaries text unchanged (frozen) — Ask-First triggers honored via the Change Log per the frozen clause structure.
- [x] **Task 3 — Port signature change + macOS no-op extension.** `AudioInterruptionObserving.setupObservers` extended with `onMediaServicesLost` + `onMediaServicesReset`; `NoOpAudioInterruptionObserver` accepts (and ignores) them; `IOSAudioInterruptionObserver` stores them.
- [x] **Task 4 — Tests-first contract for PF-055.** Three new tests in `IOSAudioInterruptionObserverTests.swift`: `.appWasSuspended` reason → no stop; `.default` → stop; `.builtInMicMuted` → stop.
- [x] **Task 5 — Implement PF-055.** Reason-key parse + early-return in `IOSAudioInterruptionObserver.handleAudioInterruption`. Compared by `rawValue == 1` since `.appWasSuspended` is deprecated on iOS 16+ (build surfaced the deprecation; filed PF-066 for the follow-up).
- [x] **Task 6 — Tests-first contract for PF-056.** New `SoundFontEngineConfigurationChangeTests.swift`: observer fires; idempotent; restarts-engine-when-stopped path.
- [x] **Task 7 — Implement PF-056.** Observer registered in `SoundFontEngine.init` after `engine.start()`; token removed in `deinit`. `handleConfigurationChange()` re-reads `outputNode.outputFormat`; if SR unchanged, ensures engine running; if SR changed, disconnects + recreates `sourceNode` at the new format bound to the same `DoubleBufferedScheduleState`, reconnects, restarts. `engine` and `sourceNode` made `var` to support replacement; `sourceSampleRate` cached for comparison.
- [x] **Task 8 — Tests-first contract for PF-057 (+ Lost).** Extended `IOSAudioInterruptionObserverTests` for Lost / Reset / lost-then-reset; new `SoundFontEngineMediaResetTests.swift` for `rebuildAfterMediaReset` (preset reload, channel topology, idempotent, multi-channel); new coordinator-level tests in `TrainingLifecycleCoordinatorTests.swift` for the three new methods.
- [x] **Task 9 — Implement PF-057 (+ Lost) and the (c′) cascade.** Reset + Lost observers added to `IOSAudioInterruptionObserver` (returns 4 tokens now). `SoundFontEngine.rebuildAfterMediaReset()` added (engine is now `var`; tears channels + presets, re-configures session, constructs fresh engine + samplers, rewires `sourceNode`, re-registers config-change observer, reloads `loadedPresets` snapshot). Coordinator gains `handleAudioInterruptionStop` / `handleMediaServicesLost` / `handleMediaServicesReset` + `mediaInfrastructureRebuild` closure parameter (separates policy from mechanism; cleaner for tests). New `AppAudioInfrastructureMonitor` retires the prior `AudioSessionInterruptionMonitor`; wired ONCE in `PeachApp`. `audioInterruptionObserver` parameter dropped from the four session constructors; `SessionLifecycle` simplified (task management only). 11 test files updated; `PitchDiscriminationSessionAudioInterruptionTests.swift` and `AudioSessionInterruptionMonitorTests.swift` deleted (per-session integration moved to coordinator-level + IOSAudioInterruptionObserver-level).
- [ ] **Task 10 — Manual verification on iOS device (where reachable).** Deferred to Michael. PF-056: BT codec / external-mic route change. PF-055: backgrounding flow on iOS 26 (filter is unreachable per PF-066 — see follow-up). PF-057: no reliable production trigger; rely on synthetic-post contract tests.
- [x] **Task 11 — Catalog hygiene.** PF-055, PF-056, PF-057 sections removed from `docs/implementation-artifacts/deferred-work.md`. PF-066 filed for the iOS-26 `.appWasSuspended`-deprecation follow-up.
- [x] **Task 12 — Pre-commit gates.** Final results: iOS Debug 1991 / iOS Research 2151 / macOS Debug 1978 / macOS Research 2138 — all four schemes green. Strict-concurrency build clean.

**Acceptance Criteria:**

- **PF-055.** Given an iOS 14.5+ system, when iOS posts `interruptionNotification` with type `.began` and reason `.appWasSuspended`, then `onStopRequired` is not called (asserted by test); when reason is `.default` or other non-`.appWasSuspended`, `onStopRequired` is called (asserted by test).
- **PF-056.** Given `SoundFontEngine` is running, when `AVAudioEngineConfigurationChangeNotification` fires, then the handler hops to `@MainActor`, re-reads `outputNode.outputFormat(forBus: 0)`, reconnects `sourceNode` with the new format, and the engine resumes (`engine.isRunning == true`). Asserted by integration test under `enableManualRenderingMode(.realtime)`; manually verified on device for at least one reliable trigger route.
- **PF-057.** Given a synthetic `mediaServicesWereResetNotification` is posted, when the handler completes, then `SoundFontEngine` has been torn down and a fresh instance constructed, `AudioSessionConfiguring.configure` has been re-invoked, all entries in the prior `loadedPresets` are reloaded on the new instance, and the coordinator's stop path is invoked. The PF-057 recovery UX matches Task 1's decision (silent vs surfaced).
- **No regressions.** All four pre-commit schemes green. Existing `IOSAudioInterruptionObserverTests` continue to pass. Strict-concurrency build clean.
- **Catalog hygiene.** PF-055, PF-056, PF-057 sections removed from `deferred-work.md` in the closing commit; any audit-surfaced new findings filed as new `PF-###` entries with dispositions.

## Spec Change Log

**2026-06-07 — Audit decisions locked in (A=(c′), B=B1, C=fold-in, D=silent).**

Task 1 audit produced four open Ask-First decisions. Michael's calls:

- **A. Cross-cutting observer architecture → (c′) Hybrid.** Coordinator owns session-scoped notifications (PF-055 interruption + PF-057 media-services Reset + media-services Lost companion); `SoundFontEngine` self-observes the engine-scoped `AVAudioEngineConfigurationChangeNotification` (PF-056). Michael's question — "Can (c) handle everything?" — clarified to (c′) after the audit noted pure (c) would teach the coordinator about engine-config notifications it currently has no awareness of (`TrainingLifecycleCoordinator.swift` has zero `SoundFontEngine` / `SoundFontPlayer` references today). Cascade: the four per-session `AudioInterruptionObserving` instances retire; `AudioSessionInterruptionMonitor` retires; `SessionLifecycle` no longer constructs the monitor; four session constructors drop the `audioInterruptionObserver` parameter; coordinator gains a `SoundFontEngine` injection for the reset path. Net structural simplification; net new injection point. The blast radius is larger than a pure catalog-driven fix because the catalog framings each tackled their PF in isolation; (c′) accepts a one-time architectural realignment to host all three handlers cleanly.

- **B. Port shape → B1 — extend `AudioInterruptionObserving`.** Two new closures on `setupObservers`: `onMediaServicesLost` and `onMediaServicesReset`. macOS no-op (`NoOpAudioInterruptionObserver`) grows by two no-op parameters. No new port protocol introduced.

- **C. `mediaServicesWereLostNotification` fold-in.** Both observers register at the same site. Lost handler logs at `.warning` and sets a `rebuildPending: Bool` flag on the coordinator; the flag is consumed when Reset fires (rebuilding before `mediaserverd` respawns would fail). If Reset fires without prior Lost, the rebuild still runs (the flag is permissive, not gating).

- **D. PF-057 recovery UX → silent rebuild.** No transient banner. The user perceives the coordinator-routed session stop (trial counter resets, UI returns to idle) and audio simply resumes on the next user-initiated trial. Logged via `os.Logger` at `.notice` for diagnostic capture.

**Boundaries & Constraints renegotiation.** Per the frozen Intent's Ask-First clauses: (a) "hosting PF-056 / PF-057 cleanly requires a new port protocol" — port extended in-place via B1, not a new protocol; the spirit of the clause (pause-confirm) is honored by Michael's B1 selection. (b) "fold `mediaServicesWereLost` companion into scope" — explicitly folded in per Decision C. (c) The frozen "Never" list item "no `mediaServicesWereLostNotification` handling unless Ask-First confirms" is satisfied by Decision C's explicit confirmation. (d) The frozen "Always" list item "Sessions stop through the existing coordinator path; recovery handlers never bypass it" is preserved — Decision A routes all session-stop calls through `TrainingLifecycleCoordinator.stopCurrentSession`. No further Boundaries text changes needed beyond logging this in the Change Log.

**2026-06-07 — Step-04 review applied. 13 patches, 3 PFs filed, 7 rejects.**

Three review subagents (Blind Hunter, Edge Case Hunter, Acceptance Auditor) reviewed the 2294-line diff. No `intent_gap` or `bad_spec` findings — the spec's frozen Intent held up. 27 raw findings deduplicated to 23 distinct issues; classified:

**Critical patches applied (would cause real bugs):**

- **C1 (EH1)** — `AppAudioInfrastructureMonitor` outlived the lifecycle coordinator on sound-source change. After `rebuildCoordinators()`, the monitor's `[weak coordinator]` closures resolved to nil because the new coordinator is a fresh instance; audio observers silently dead for the rest of the session. **Fix:** `rebuildCoordinators()` now re-constructs the monitor with the new coordinator. The old monitor's `isolated deinit` removes its tokens when `@State` drops it.
- **C2 (BH1)** — `rebuildAfterMediaReset` started the new engine BEFORE attaching the `sourceNode`. The source node's render block drives `scheduleState` consumers; attaching after `start()` left the engine running for a moment without its render-clock callback wired into the graph. **Fix:** Reordered so `attach(sourceNode)` + `connect(sourceNode, …)` happen before `engine.start()`.
- **C3a (EH3)** — `handleMediaServicesReset` could be re-entered while a prior rebuild was in flight, producing concurrent Tasks that mutate `channels` / `loadedPresets` / `engine` against mismatched instances. **Fix:** `rebuildInFlight` guard in `SoundFontEngine.rebuildAfterMediaReset` early-returns the second call. (The Task at the coordinator level was retained for the typical case where Reset arrives once; the engine-side guard catches the rare re-entrance.)
- **C3b (EH2)** — Config-change notification Task queued from the old engine's observer could resolve after `rebuildAfterMediaReset` swapped the engine pointer, mutating the freshly-built graph. **Fix:** `handleConfigurationChange` early-returns when `rebuildInFlight == true`. The new observer registered on `newEngine` owns post-rebuild notifications.
- **C4a (BH3, EH5)** — Preset-reload errors during `rebuildAfterMediaReset` were swallowed; the log lied about success count (`presetsSnapshot.count` reloaded). After a partial failure, `loadedPresets` permanently shrank — a future rebuild would never retry the failed preset. **Fix:** New `pendingPresetReload` field tracks failed presets; the next rebuild merges them back into the recovery inventory. Log reports `N of M reloaded, K pending retry`.
- **C4b (EH6)** — `audioSessionConfigurator.configure` throwing mid-rebuild left the engine state torn down (`channels.removeAll()` had already run) with no recovery, and `mediaRebuildPending` was cleared as if it succeeded. **Fix:** Reordered so `configure()` runs FIRST, before any teardown. If it throws, old engine state is intact; pending flag stays true; next Reset retries.
- **C5 (EH7)** — Coordinator only stopped the session on Reset, not Lost. Between Lost and Reset, sessions kept running against dead `AVAudioUnitSampler` references — note dispatches went into the void. **Fix:** `handleMediaServicesLost` now calls `stopCurrentSession()` before setting the pending flag.

**Quick patches applied:**

- **P1 (AA1)** — Removed `= { }` default from `TrainingLifecycleCoordinator.mediaInfrastructureRebuild` (violates memory rule about silent-omission defaults). Production callers and test fixtures pass an explicit closure.
- **P2 (AA4)** — Removed redundant `@MainActor` annotation on coordinator's `Task` (coordinator already `@MainActor` by default isolation).
- **P7 (EH11, AA6)** — `Task { [weak self] in ... }` instead of `[self]` in `handleMediaServicesReset` for consistency with observer-level patterns; `guard let self else { return }` early-return.

**Test improvements added:**

- **P4 (AA2, BH11)** — `srChangedBranchRewiresSourceNode` test added: forces stale `sourceSampleRate` via test seam, posts synthetic config-change, asserts `sourceNodeIdentityForTesting` changed. Exercises the previously-untested SR-changed rewire branch in `handleConfigurationChange`.
- **P6 (AA7)** — `rebuildReRegistersConfigChangeObserver` test added: after `rebuildAfterMediaReset`, exercises the new observer with another synthetic config-change post and asserts the sourceNode identity changes (i.e., the observer is wired against the new engine).
- **C5 verification** — `handleMediaServicesLostStopsSession` test added: starts a session, calls `handleMediaServicesLost`, asserts `!coordinator.isTrainingActive`.
- **C4a verification** — `rebuildLeavesZeroPendingPresets` and engine-identity / source-node-identity replacement tests added.

**Deferred (filed as new PFs):**

- **PF-067 (AA3)** — Audio-error UI surface gap. Frozen I/O matrix promised `engine.start()` failure paths would "surface via existing audio-error path"; the existing `AudioError` surface is fatal-error-only. Logged at `.error` for now; a transient-banner pattern is the future fix.
- **PF-068 (AA8)** — `ForTesting`-suffixed seams sit on production type surface without `@_spi(Testing)` or `#if DEBUG` gating. Standard cleanup pattern; deferred until a broader test-seam pass.
- **PF-069 (BH9, BH10, EH10)** — Lifecycle-test timing waits use blanket `Task.sleep(50ms)` instead of progress-based signals. No flakiness observed locally; cleanup deferred to a focused test-quality story.

**Rejects (verified non-issues):**

- BH4 / AA10 (coordinator already `@MainActor` by default isolation — annotation redundancy already covered by P2).
- BH5 (closure-as-leak for `mediaInfrastructureRebuild` capture of `soundFontEngine` — bounded by app-lifetime ownership; not actionable).
- BH6 (`[weak coordinator]` defensive theatre — addressed by C1 fix re-wiring the monitor).
- BH7 (engineRef capture in addObserver closure — bounded by observer-rotation in `rebuildAfterMediaReset`; no leak in production paths).
- BH12 (SessionLifecycle isolated-deinit fragility — `SoundFontEngine` is still `@MainActor` with `isolated deinit`; no regression vs baseline).
- BH13 (CRM test deletion silently reduces coverage — verified `stopDiscardsIncompleteTrial` at line 165 of `ContinuousRhythmMatchingSessionTests.swift` retains the `completedCallCount == 0` invariant).
- BH14 (PM tests renamed wholesale — coverage intentionally shifted to coordinator + observer levels per Decision (c′); the wiring chain is covered by `IOSAudioInterruptionObserverTests` + `TrainingLifecycleCoordinatorTests`).
- BH8 / AA9 (PF-066 already filed with both close-as-no-op and keep-as-defensive options; user owns the close decision).

## Design Notes

**Isolation discipline (compiler-enforced).** Default `MainActor` isolation means the `Task { @MainActor in ... }` shape already used in `IOSAudioInterruptionObserver` is the canonical hop for these handlers. PF-056's observer cannot read engine state on a background thread; the format re-read and the `engine.start()` retry must run inside the MainActor hop.

**PF-057 reload inventory.** `SoundFontEngine.loadedPresets: [MIDIChannel: SF2Preset]` is the authoritative pre-reset preset map. The rebuilt engine should iterate this map and call `loadPreset(_:channel:)` for each entry. Channel topology (channel 0 = melodic, channel 1 = percussion per `PeachApp.setupPlayers`) is reconstructed by `setupSoundFontInfrastructure` + `setupPlayers`; PF-057's rebuild should reuse those primitives rather than open-coding the graph.

**Notification observer lifetime.** Existing pattern in `AudioSessionInterruptionMonitor`: token array retained, removed in `isolated deinit`. PF-056 / PF-057 observers must follow the same shape — token retention on whatever owner the audit chooses, removed on deinit.

## Verification

**Commands:**
- `bin/test.sh` -- expected: full iOS suite green; new `IOSAudioInterruptionObserver`, `SoundFontEngine`, and media-services-reset tests pass
- `bin/test.sh -p mac` -- expected: full macOS suite green (PF-055 / PF-057 tests `#if os(iOS)`-gated; PF-056 test runs on both)
- `bin/test.sh --research && bin/test.sh --research -p mac` -- expected: Research-config schemes green on both platforms

**Manual checks:**
- PF-056 on device: connect Bluetooth headphones mid-session (A2DP codec change), confirm audio resumes within a couple seconds without app relaunch. External mic plug-in on iPad is a second reliable trigger.
- PF-055 on device: start a session, background the app briefly, foreground — confirm the next user-initiated trial plays audio (no false-positive stop).
- PF-057: no reliable production trigger; manual check limited to the synthetic-post contract test. Document the gap.

## Suggested Review Order

**The architectural pivot — start here**

- One app-scoped observer replaces four per-session monitors; routes session-scoped notifications to coordinator methods.
  [`AppAudioInfrastructureMonitor.swift:14`](../../Peach/App/AppAudioInfrastructureMonitor.swift#L14)

- Composition root wires the monitor once and recreates it when sound-source changes swap the coordinator (C1 patch).
  [`PeachApp.swift:104`](../../Peach/App/PeachApp.swift#L104)
  [`PeachApp.swift:249`](../../Peach/App/PeachApp.swift#L249)

- Port signature extended with `onMediaServicesLost` + `onMediaServicesReset` closures (Decision B1; Decision C).
  [`AudioInterruptionObserving.swift:13`](../../Peach/Core/Ports/AudioInterruptionObserving.swift#L13)

**Coordinator-side handler trio + rebuild closure (PF-057 + Lost)**

- `mediaInfrastructureRebuild` is non-defaulted — production wires the closure, tests pass `{ }` explicitly.
  [`TrainingLifecycleCoordinator.swift:60`](../../Peach/App/TrainingLifecycleCoordinator.swift#L60)

- The three new methods route audio-lifecycle events through `stopCurrentSession`; Reset spawns the rebuild Task.
  [`TrainingLifecycleCoordinator.swift:198`](../../Peach/App/TrainingLifecycleCoordinator.swift#L198)
  [`TrainingLifecycleCoordinator.swift:210`](../../Peach/App/TrainingLifecycleCoordinator.swift#L210)
  [`TrainingLifecycleCoordinator.swift:222`](../../Peach/App/TrainingLifecycleCoordinator.swift#L222)

**PF-055 — reason-key filter (dead code on iOS 26 per PF-066)**

- Hoisted constant + one-line filter; collapsed from the 13-line `/simplify-code` patch.
  [`IOSAudioInterruptionObserver.swift:14`](../../Peach/App/Platform/IOSAudioInterruptionObserver.swift#L14)
  [`IOSAudioInterruptionObserver.swift:97`](../../Peach/App/Platform/IOSAudioInterruptionObserver.swift#L97)

**PF-056 — engine-scoped config-change observer (SoundFontEngine self-observes)**

- Helper `makeSourceNode` extracts the triplicated attach-and-connect sequence shared by `init`, rebuild, and config-change handler.
  [`SoundFontEngine.swift:331`](../../Peach/Core/Audio/SoundFontEngine.swift#L331)

- Helper `installConfigurationChangeObserver` registers the observer (no engineRef identity guard — NotificationCenter filters by `object`).
  [`SoundFontEngine.swift:351`](../../Peach/Core/Audio/SoundFontEngine.swift#L351)

- Handler with SR-changed rewire branch; guarded against in-flight rebuild (C3b).
  [`SoundFontEngine.swift:573`](../../Peach/Core/Audio/SoundFontEngine.swift#L573)

**PF-057 — media-services rebuild (the centerpiece change)**

- `rebuildAfterMediaReset`: re-entrance guard, configure-FIRST ordering (C4b), build-new-then-swap, observer re-registration, preset reload with partial-failure retry.
  [`SoundFontEngine.swift:479`](../../Peach/Core/Audio/SoundFontEngine.swift#L479)

- Partial-failure inventory: presets that throw during reload land in `pendingPresetReload` for the next rebuild's recovery snapshot (C4a).
  [`SoundFontEngine.swift:244`](../../Peach/Core/Audio/SoundFontEngine.swift#L244)

**(c′) cascade evidence — session simplification**

- `SessionLifecycle` reduces to task management only; the audio-observer wiring moved up the stack.
  [`SessionLifecycle.swift:4`](../../Peach/Core/Training/SessionLifecycle.swift#L4)

- Representative session constructor sheds the `audioInterruptionObserver` parameter (four sessions; one shown).
  [`PitchDiscriminationSession.swift:115`](../../Peach/Training/PitchDiscrimination/PitchDiscriminationSession.swift#L115)

**Tests**

- New PF-056 contract tests (idempotent + SR-changed branch).
  [`SoundFontEngineConfigurationChangeTests.swift:14`](../../PeachTests/Core/Audio/SoundFontEngineConfigurationChangeTests.swift#L14)

- New PF-057 contract tests (rebuild replaces engine + sourceNode, re-registers observer, channel + preset survival).
  [`SoundFontEngineMediaResetTests.swift:14`](../../PeachTests/Core/Audio/SoundFontEngineMediaResetTests.swift#L14)

- Coordinator-level tests for the three new methods + Lost-stops-session (C5).
  [`TrainingLifecycleCoordinatorTests.swift:721`](../../PeachTests/App/TrainingLifecycleCoordinatorTests.swift#L721)

- Observer-level tests for Reset / Lost / lost-then-reset paths.
  [`IOSAudioInterruptionObserverTests.swift:65`](../../PeachTests/App/Platform/IOSAudioInterruptionObserverTests.swift#L65)

**Catalog hygiene + follow-ups**

- PF-055/056/057 entries removed; PF-066/067/068/069 filed for the audit-surfaced follow-ups.
  [`deferred-work.md`](../deferred-work.md)
