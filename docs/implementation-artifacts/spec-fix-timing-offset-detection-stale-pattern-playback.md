---
title: 'Fix Timing Offset Detection stale pattern after changing settings mid-session'
type: 'bugfix'
created: '2026-06-22'
status: 'done'
context: []
baseline_commit: '57f82d83c752cb222ea18dad6bca7290d2d6c194'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** In Timing Offset Detection, navigating training screen → Settings → change pattern → back to training resumes the paused session and the display shows the new pattern, but playback keeps playing the *old* pattern. It does not reproduce via training → Start → Settings → Start → training, because that path discards the paused session and starts fresh. Root cause: the session captures an immutable `TimingOffsetDetectionSettings` snapshot at `start()`; `resume()` re-engages that stale snapshot, while the screen reads the pattern live from `@AppStorage`.

**Approach:** Make the coordinator's resume decision settings-aware. When the user returns to a paused training screen, rebuild the live settings snapshot and compare it to the one the session is running. If unchanged, `resume()` (preserve the in-trial state — the intentional Story 85.1 behavior for a quick Profile peek). If changed, restart the session fresh with the new settings (identical to the Start-screen path). The settings comparison naturally distinguishes "peeked at Profile, nothing changed → resume" from "changed the pattern in Settings → restart".

## Boundaries & Constraints

**Always:**
- Preserve the Story 85.1 pause/resume feature: a screen excursion that changes *nothing* relevant must still resume the same trial (no flash, no reset of session-best).
- Restart-on-change must be audio-safe: the fresh sequencer start must drain any in-flight stop spawned by the preceding `pause()`/`stop()` before starting (mirror `restartSequencerForCurrentTrial`'s `await priorStop?.value`). No back-to-back start-before-stop race.
- A restart goes through the existing `stop()` + `start(settings:)` so behavior is byte-for-byte the Start-screen path (fresh trial, reset session-best/grid).
- Lifecycle wiring stays in the coordinator/contribution; the session stays decoupled from `UserSettings` (fresh settings are supplied by the contribution closure, which already owns the `userSettings`/`todUserSettings` bindings).

**Ask First:**
- Generalizing the same fix to the other coordinator-driven disciplines (pitch discrimination/matching, CRM, chromatic) — they share the latent staleness but are out of the reported scope.
- Any change to macOS behavior, where Settings is a separate window and the training session is not paused while it is open (a related but distinct path).

**Never:**
- Do not remove or weaken pause-on-disappear (no "always restart on re-entry").
- Do not make the session read `@AppStorage`/`UserSettings` directly.
- Do not refresh only `pattern` — compare the whole snapshot (tempo, maxRepetitions, offsetNotePosition, pattern) so every TOD setting is covered.
- Do not add a default value for the new `register(resume:)` parameter (no silent omission).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Peek and return | Active TOD session paused; live settings == snapshot on reappear | `resume()`: same `currentTrial`, same pattern plays, session-best preserved | N/A |
| Change pattern | Paused TOD; pattern changed in Settings | Restart: new `TimingOffsetDetectionSettings`, `nextBeat()` emits the new pattern, fresh trial | N/A |
| Change tempo/maxReps/offsetNotePosition | Paused TOD; any other TOD setting changed | Restart with the new snapshot (full-snapshot comparison, not pattern-only) | N/A |
| Audio ordering | Restart fires while `pause()`'s sequencer stop is still in flight | Fresh sequencer start awaits the in-flight stop; audio plays, not silenced | Cancellation/audio error handled as in existing start path |
| Not paused | `resume(orRestartWith:)` called when `!isPaused` | No-op | N/A |

</frozen-after-approval>

## Code Map

- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSettings.swift` -- snapshot type; needs `Equatable` (all members already `Equatable`/`Hashable`).
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift` -- `start/pause/resume`; `nextBeat()` reads stale `settings.pattern`; `beginNextTrial` start path; new `resume(orRestartWith:)`.
- `Peach/App/Training/TrainingLifecycleRegistry.swift` -- `Contribution` + `Builder.register`; add `resume` closure.
- `Peach/App/TrainingLifecycleCoordinator.swift` -- `trainingScreenAppeared` and `helpSheetDismissed` call sites that currently invoke `session.resume()`.
- `Peach/Training/*/[A-Z]*LifecycleContribution.swift` (5 files, 7 `register` calls) -- pass the new `resume:` closure.

## Tasks & Acceptance

**Execution:**
- [x] `TimingOffsetDetectionSettings.swift` -- add `Equatable` conformance (synthesized) -- enables snapshot comparison.
- [x] `TimingOffsetDetectionSession.swift` -- (a) capture `let priorStop = stopTask` and `await priorStop?.value` (+ post-await `state`/cancel guard) at the top of `beginNextTrial`'s `startTask`, mirroring `restartSequencerForCurrentTrial`, so a back-to-back `stop()`+`start()` is audio-safe; (b) add `func resume(orRestartWith refreshed: TimingOffsetDetectionSettings)`: `guard isPaused`; if `settings == refreshed` → `resume()`, else `stop(); start(settings: refreshed)`.
- [x] `TrainingLifecycleRegistry.swift` -- add `let resume: () -> Void` to `Contribution`; add required `resume:` param to `Builder.register`.
- [x] `TrainingLifecycleCoordinator.swift` -- route the two resume call sites through `registry.contribution(for:)?.resume()` instead of `…?.session.resume()`.
- [x] `TimingOffsetDetectionLifecycleContribution.swift` -- `resume: { self.resume(orRestartWith: .from(userSettings, todUserSettings: todUserSettings)) }`.
- [x] `PitchDiscriminationLifecycleContribution.swift`, `PitchMatchingLifecycleContribution.swift`, `ContinuousRhythmMatchingLifecycleContribution.swift`, `ChromaticConstructionLifecycleContribution.swift` -- pass `resume: { self.resume() }` (preserve current behavior).
- [x] Tests -- cover the I/O matrix (see Verification).

**Acceptance Criteria:**
- Given an active TOD session, when I leave to Settings, change the pattern, and return, then playback plays the newly selected pattern and the display matches it.
- Given an active TOD session, when I leave to Profile and return without changing anything, then the same trial resumes (no flash, session-best preserved).
- Given the macOS path is unchanged, when the full suite runs on iOS and macOS, then both pass.

## Design Notes

The contribution closure is the only place that may read `UserSettings`; it supplies the refreshed snapshot, so the session stays decoupled. `TimingOffsetDetectionPattern` equality is by `id`, so a pattern change yields a non-equal snapshot. Restart deliberately reuses `stop()`+`start()` so a settings-change re-entry behaves exactly like returning via the Start screen (the path the user already confirmed works). The only new audio-path change is making `beginNextTrial` await the in-flight stop — harmless for the normal inter-trial loop (the prior stop is already complete by then) and for first start (`stopTask` is nil).

## Verification

**Commands:**
- `bin/test.sh` -- expected: full iOS suite green.
- `bin/test.sh -p mac` -- expected: full macOS suite green.

**New tests:**
- `TimingOffsetDetectionSettingsTests` -- equal vs pattern-changed snapshots compare (in)equal.
- `TimingOffsetDetectionSessionTests` -- `resume(orRestartWith:)`: equal → preserves `currentTrial`; changed pattern → new trial and `nextBeat()` emits the new pattern; back-to-back stop+start leaves the sequencer started (audio-safe), asserted via the mock `BeatSequencer` start/stop ordering.
- `TrainingLifecycleCoordinatorTests` -- `trainingScreenAppeared` on a paused destination invokes the contribution's `resume` closure; help-sheet dismissal routes through it too.

**Manual check (Michael, on device):** TOD → do a few trials → Settings → change pattern → back → confirm the new pattern is audible (the reported repro).

## Suggested Review Order

**The fix's decision point (start here)**

- Settings-aware resume: unchanged → preserve trial; changed → restart fresh.
  [`TimingOffsetDetectionSession.swift:265`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift#L265)

- The comparison key: snapshot made `Equatable` so the whole config (not just pattern) is compared.
  [`TimingOffsetDetectionSettings.swift:3`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSettings.swift#L3)

**Audio-safety**

- Shared `launchSequencer` drains the in-flight stop before launching, so back-to-back stop+start can't be silenced (start + resume paths now share it).
  [`TimingOffsetDetectionSession.swift:283`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift#L283)

**Lifecycle wiring (how live settings reach the paused session)**

- Resume routed through a per-discipline closure that owns the resume policy.
  [`TrainingLifecycleRegistry.swift:15`](../../Peach/App/Training/TrainingLifecycleRegistry.swift#L15)

- TOD's closure rebuilds the live snapshot; other disciplines forward to plain `resume()`.
  [`TimingOffsetDetectionLifecycleContribution.swift:16`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionLifecycleContribution.swift#L16)

- Coordinator's two resume call sites now call `contribution.resume()`.
  [`TrainingLifecycleCoordinator.swift:123`](../../Peach/App/TrainingLifecycleCoordinator.swift#L123)

**Tests**

- End-to-end: pattern changed while paused → new pattern plays on return (the reported bug).
  [`TrainingLifecycleCoordinatorTests.swift:591`](../../PeachTests/App/TrainingLifecycleCoordinatorTests.swift#L591)

- Session-level resume-vs-restart + audio-safe ordering.
  [`TimingOffsetDetectionSessionTests.swift:1107`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionSessionTests.swift#L1107)

- Equatable drives the decision: each field change breaks equality.
  [`TimingOffsetDetectionSettingsTests.swift:100`](../../PeachTests/Core/Training/TimingOffsetDetectionSettingsTests.swift#L100)
