---
title: 'macOS: stop training playback while the Settings window is open'
type: 'bugfix'
created: '2026-06-22'
status: 'done'
context: []
baseline_commit: 'c3046bfb'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** On macOS the Settings window is a separate window, so the training window keeps its session running. Opening Settings during an active discipline (reported for Timing Offset Detection, but the loop affects every reconcile-enabled discipline) leaves the rhythm/pattern audibly looping behind Settings even though the training screen is no longer the focus. Today only the *close* side is wired (`reconcileForegroundSession()` on `.onDisappear`); nothing pauses playback on open.

**Approach:** Mirror the existing open/close symmetry of the help-sheet flow. Add a coordinator method that pauses the foreground training session, wire it to the Settings window's `.onAppear`. The existing `reconcileForegroundSession()` on `.onDisappear` already restarts the session fresh when settings changed, or resumes the preserved trial when unchanged — so closing Settings automatically restarts playback with the new settings applied.

## Boundaries & Constraints

**Always:** Pause (not stop) the foreground session so the preserved trial survives for resume-on-close. Cover all reconcile-enabled disciplines uniformly via `currentTrainingDestination` — no per-discipline edits. Keep the change macOS-only (the wiring lives in the existing `#if os(macOS)` Settings-window block). The pause must be a no-op when no training is foreground or the session is already idle.

**Ask First:** None.

**Never:** Do not use the `pausedDestination` machinery (`helpSheetPresented`-style) for this path — the close hook keys off `currentTrainingDestination`, so setting `pausedDestination` would leave a lingering paused destination after reconcile resumes. Do not touch iOS lifecycle (iOS pauses via `trainingScreenDisappeared` when the pushed Settings screen covers the training screen). Do not modify the `Localizable.xcstrings` stale-annotation working-tree noise.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Open Settings, training active | `currentTrainingDestination` set, session non-idle | Foreground session `pause()`d once; playback stops | N/A |
| Open Settings, no training foreground | `currentTrainingDestination == nil` | No-op | N/A |
| Open Settings, session idle | destination set, session idle | No-op (no `pause()`) | N/A |
| Close Settings, settings unchanged | session paused | `reconcile()` resumes preserved trial; playback resumes | N/A |
| Close Settings, settings changed | session paused | `reconcile()` restarts fresh with new settings | N/A |

</frozen-after-approval>

## Code Map

- `Peach/App/TrainingLifecycleCoordinator.swift` -- add `pauseForegroundSession()` next to `reconcileForegroundSession()`; same guard shape, calls `session.pause()`.
- `Peach/App/PeachApp.swift` -- macOS Settings `Window` block (~line 180-194): add `.onAppear { trainingLifecycle.pauseForegroundSession() }` alongside the existing `.onDisappear`.
- `PeachTests/App/TrainingLifecycleCoordinatorTests.swift` -- add coverage for the new method and the full open→close cycle (real TOD fixture + mock fixtures already exist).

## Tasks & Acceptance

**Execution:**
- [x] `Peach/App/TrainingLifecycleCoordinator.swift` -- add `pauseForegroundSession()`: guard `currentTrainingDestination` resolves to a contribution whose session is `!isIdle`, then `session.pause()`. Doc-comment the macOS-Settings-open rationale and the symmetry with `reconcileForegroundSession()`.
- [x] `Peach/App/PeachApp.swift` -- wire `.onAppear { trainingLifecycle.pauseForegroundSession() }` on the Settings window's `NavigationStack`, paired with the existing `.onDisappear` reconcile. Match the existing comment style.
- [x] `PeachTests/App/TrainingLifecycleCoordinatorTests.swift` -- add tests covering the I/O matrix rows (pause on open when active; no-op when idle; no-op when no foreground; only the foreground discipline pauses) plus a full-cycle test on the real TOD fixture: open (pause) → reconcile unchanged resumes / changed restarts.

**Acceptance Criteria:**
- Given an active foreground session on macOS, when the Settings window opens, then the session is paused exactly once and no audio continues.
- Given a paused foreground session, when the Settings window closes with no settings changed, then the preserved trial resumes.
- Given a paused foreground session, when the Settings window closes after a settings change, then the session restarts fresh with the new settings.
- Given no foreground training (Settings opened from Start) or an idle session, when the Settings window opens, then nothing is paused.

## Design Notes

The close path already handles a *paused* session correctly: `reconcileForegroundSession()` guards `!session.isIdle` (paused is non-idle, so it proceeds), and `reconcile(with:)` does `if isPaused { resume() }` on an unchanged snapshot or `stop()/start()` on a changed one. So adding only the open-side pause completes the cycle — no change to `reconcileForegroundSession` or any session is needed.

```swift
func pauseForegroundSession() {
    guard let destination = currentTrainingDestination,
          let session = registry.contribution(for: destination)?.session,
          !session.isIdle else { return }
    session.pause()
}
```

Note: the first staleness commit (4ae50e8f) referenced "PF-074" for the unaddressed macOS case; no such entry exists in `deferred-work.md`. This spec closes the remaining half of that case (stop-on-open); the staleness half was already fixed in f002d0f6 / c3046bfb.

## Verification

**Commands:**
- `bin/test.sh && bin/test.sh -p mac` -- expected: full iOS and macOS suites green (the new `TrainingLifecycleCoordinatorTests` cases included).

**Manual checks:**
- On macOS: start Timing Offset Detection (pattern looping), open Settings → loop stops immediately. Close Settings without changes → playback resumes. Change the pattern, close Settings → playback restarts with the new pattern.

## Suggested Review Order

**The fix (open/close symmetry)**

- Entry point — the new open-side hook; pause (not stop) preserves the trial for resume-on-close.
  [`TrainingLifecycleCoordinator.swift:189`](../../Peach/App/TrainingLifecycleCoordinator.swift#L189)
- The close-side counterpart (unchanged behavior, updated doc) — resumes if unchanged, restarts if changed.
  [`TrainingLifecycleCoordinator.swift:208`](../../Peach/App/TrainingLifecycleCoordinator.swift#L208)

**macOS Settings-window wiring**

- `.onAppear`/`.onDisappear` pairing on the separate Settings window's NavigationStack root.
  [`PeachApp.swift:195`](../../Peach/App/PeachApp.swift#L195)

**Tests**

- Real-session full cycle: open pauses, close restarts TOD with the new pattern (the reported bug).
  [`TrainingLifecycleCoordinatorTests.swift:790`](../../PeachTests/App/TrainingLifecycleCoordinatorTests.swift#L790)
- Coordinator-level routing + no-op guards for the new `pauseForegroundSession()`.
  [`TrainingLifecycleCoordinatorTests.swift:719`](../../PeachTests/App/TrainingLifecycleCoordinatorTests.swift#L719)
