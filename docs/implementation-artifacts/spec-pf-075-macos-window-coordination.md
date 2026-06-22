---
title: 'PF-075: macOS auxiliary windows coexist coherently with training'
type: 'bugfix'
created: '2026-06-23'
status: 'done'
context: []
baseline_commit: '197d8f42'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** On macOS the training window can sit behind two non-modal auxiliary windows (separate Settings `Window`, singleton Help `NSWindow`), and the coordination is incoherent: (1) the training surface stays clickable while suspended, so a Timing Offset Detection answer-click resumes audio behind the open Settings window; (2) closing Settings resumes audio even when the Help window is still open and still owns a pause (the original PF-075); (3) the Help window keeps showing the discipline it was opened on after the user switches disciplines, contradicting the training window.

**Approach:** Model "foreground training is suspended" as a set of reasons (Settings window open, Help window open) on `TrainingLifecycleCoordinator`; resume/reconcile only when the *last* reason clears. Expose an observable `isForegroundSuspended` the macOS training surface reads to disable interaction (no overlay text). Make a Help window opened from the training screen *follow* the current discipline. iOS behavior must be provably unchanged.

## Boundaries & Constraints

**Always:** Resume/reconcile the foreground session only when no suspension reason remains. Each suspension reason pauses at most once (first reason pauses; later reasons are no-ops while paused). Surface-disable and Help-follow logic are macOS-only (`#if os(macOS)`). The Help window follows only when it was opened from the training screen Help button; help opened explicitly from the Help menu (a specific discipline) or "About Peach" stays pinned. Disabling the training surface uses `allowsHitTesting(false)` + a dim consistent with `TrainingIdleOverlay`; no message/banner.

**Ask First:** Any change that would alter iOS pause/resume/help-sheet behavior. Removing or repurposing the `pausedDestination` navigation machinery (it serves screen-disappear navigation, which is out of scope).

**Never:** Do not make the Settings or Help window modal. Do not auto-close the Help window on discipline switch (HIG: an inspector-class window updates, it does not close). Do not add analytics, telemetry, or new user-facing copy. Do not touch the iOS Settings push-screen or Help `.sheet` flows.

## I/O & Edge-Case Matrix

| Scenario (macOS, training active) | Input / State | Expected Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Settings opens | foreground session active | session pauses; `isForegroundSuspended == true`; surface non-interactive | N/A |
| TOD answer-click while Settings open | surface suspended | click is inert; no audio resumes | N/A |
| Settings closes, Help still open | `{settingsWindow, helpWindow}` → remove settings | stays paused; no audio | N/A |
| Last window (Help) closes | reasons empty, session non-idle | reconcile: resume if unchanged, restart if changed | N/A |
| Settings opens over an idle foreground discipline | session idle, `currentTrainingDestination != nil` | suspended (surface inert); nothing to pause; starts on close per policy | N/A |
| Settings opens from Start, then user enters a discipline | `currentTrainingDestination == nil` at open | suspension recorded at open; the entered discipline stays suspended (no auto-start) until the window closes | N/A |
| Menu-bar Help / About Peach opens over active training | session active, opened via Help menu | suspends + pauses like the toolbar button; menu help is *pinned* (does not follow discipline switches) | N/A |
| Switch discipline while training Help open | Help shows discipline A, user navigates to B | Help window re-titles/re-contents to B's training help | N/A |
| Switch discipline while menu/About help open | help pinned (not training help) | help window unchanged | N/A |
| iOS Help sheet present/dismiss | only `helpWindow` reason ever active | identical to pre-change (reason set empties immediately on dismiss) | N/A |

</frozen-after-approval>

## Code Map

- `Peach/App/TrainingLifecycleCoordinator.swift` -- owns suspension; add reason set + `isForegroundSuspended`; rework `helpSheetPresented/Dismissed`, `pauseForegroundSession/reconcileForegroundSession`, and the auto-start guard in `trainingScreenAppeared`.
- `Peach/App/TrainingScreenModifier.swift` -- single chokepoint for all disciplines; apply macOS suspend-gate; on macOS `onAppear`, push current `helpSections` to a following Help window; mark training-screen help as following.
- `Peach/App/TrainingIdleOverlay.swift` -- reference for the dim/`allowsHitTesting` idiom; add a sibling `trainingSuspendedGate()` (macOS-only) or extend.
- `Peach/App/Platform/HelpPanel.swift` -- `HelpPanelController`: track whether the open window is training help; add `updateIfShowingTrainingHelp(title:sections:)`.
- `Peach/App/Platform/PlatformHelpPresentation.swift` -- thread a `followsTrainingDiscipline` flag from `platformHelp(sections:)` into `HelpPanelController.show`.
- `Peach/App/PeachApp.swift` -- Settings `Window` `.onAppear/.onDisappear` already call pause/reconcile; no change expected.
- `PeachTests/App/TrainingLifecycleCoordinatorTests.swift` -- Swift Testing; `MockTrainingSession` (pause/resume/stop counts, mutable `isIdle`); add multi-owner-suspension tests.
- `docs/implementation-artifacts/deferred-work.md` -- close PF-075; correct its wrong "Help sheet on the training window" premise.

## Tasks & Acceptance

**Execution:**
- [x] `TrainingLifecycleCoordinator.swift` -- add `private var foregroundSuspensions: Set<ForegroundSuspensionReason>` (`.settingsWindow`, `.helpWindow`) and observable `var isForegroundSuspended: Bool`. `helpSheetPresented`/`pauseForegroundSession` route through `suspendForeground`: insert the reason and pause only when the set was empty and the session is non-idle (recording `pausedDestination` so existing lingering-cleanup applies). `helpSheetDismissed`/`reconcileForegroundSession` route through `releaseForeground`: remove their reason and return early unless the set is now empty, then reconcile the *current foreground* session (order-independent), or honour `autoStartIfIdle` (help only). Auto-start guarded by `!isForegroundSuspended` in `trainingScreenAppeared`, `handleScenePhase`, `handleAppActivated`.
- [x] `TrainingIdleOverlay.swift` + `TrainingScreenModifier.swift` -- added macOS-only `trainingSuspendedGate()`: when `lifecycle.isForegroundSuspended`, dim content (0.35) and `allowsHitTesting(false)`; no Start button, no text. No-op on iOS.
- [x] `HelpPanel.swift` + `PlatformHelpPresentation.swift` -- `isTrainingHelp` flag on the controller; `updateIfShowingTrainingHelp` swaps content+title in place (no re-order) when a following window is open; `followsTrainingDiscipline` threaded from the training-screen Help button.
- [x] `TrainingScreenModifier.swift` -- macOS `onAppear` calls `HelpPanelController.shared.updateIfShowingTrainingHelp(title: "Training Help", sections: helpSections)`.
- [x] `TrainingLifecycleCoordinatorTests.swift` -- added the multi-owner suspension suite covering every I/O Matrix coordinator row, two-reason interleavings, order-independence, and unchanged iOS single-reason flow.
- [x] `deferred-work.md` -- PF-075 marked RESOLVED; premise corrected.

**Acceptance Criteria:**
- Given a macOS training session is active, when the user opens Settings then clicks a TOD answer button, then nothing audible happens and the surface is visibly inert until a window closes.
- Given both Settings and Help are open over training, when the user closes one, then audio stays silent; when the user closes the second, then the session reconciles once (resume if settings unchanged, restart if changed).
- Given the training-screen Help window is open for discipline A, when the user switches to discipline B via the menu, then the Help window shows B's training help.
- Given iOS, when Help is presented and dismissed, then pause/resume behavior is byte-for-byte the prior behavior (existing iOS tests still pass).

## Spec Change Log

- **2026-06-23 (post-workflow `/code-review high`, user-approved "fix both"):** The frozen I/O-matrix row "Settings opens while idle / no foreground → not suspended" was too permissive — opening Settings from Start and *then* entering a discipline (macOS) auto-started audio behind the open Settings window. Amended the matrix so suspension is recorded at window-open regardless of whether a discipline is foreground; a subsequently-entered discipline then stays suspended until the window closes. Implemented by dropping `suspendForeground`'s "no foreground → return" guard. Added a matrix row for menu-bar Help / About Peach now suspending+pausing like the toolbar Help button (pinned, not discipline-following). Known-bad avoided: audio looping behind a Settings/Help window opened before the user reaches a discipline, or opened from the Help menu. KEEP: resume keys off `currentTrainingDestination` (order-independent); menu help stays pinned (`followsTrainingDiscipline` default false).

## Design Notes

HIG backing: a background `NSWindow` stays interactive by AppKit design, so the pause must be enforced in code (disable the surface) — Settings' mere presence cannot block input. A help window "about the current discipline" is inspector-class: "information displayed in an inspector panel should always match the current state… update accordingly" → follow, never freeze or auto-close. The pause-on-Settings model itself diverges from the HIG's live-apply convention but is an established product decision (`feedback_settings_apply_on_exit`).

Why per-reason resume semantics are preserved rather than unified: help-dismiss starts an idle session under autostart (iOS) while settings-close only reconciles a non-idle one. Keeping each release path's existing action — gated behind the shared empty-set check — fixes the cross-window resume bug without changing iOS single-window behavior.

## Verification

**Commands:**
- `bin/test.sh -s TrainingLifecycleCoordinatorTests` -- expected: all green, including new multi-owner tests.
- `bin/test.sh && bin/test.sh -p mac` -- expected: both platforms green.
- `bin/build.sh && bin/build.sh -p mac` -- expected: no new warnings.

**Manual checks (macOS, requested of Michael before done):**
- Active TOD session → open Settings → click an answer: no audio, surface inert. Close Settings: reconciles.
- Open Help + Settings over training → close Settings: silent → close Help: reconciles once.
- Open training Help for one discipline → switch discipline via menu: Help content follows.

## Suggested Review Order

**Multi-owner suspension (entry point)**

- Start here — the core observable and the multi-owner reason set the whole change pivots on.
  [`TrainingLifecycleCoordinator.swift:70`](../../Peach/App/TrainingLifecycleCoordinator.swift#L70)

- Record a reason + pause only on the first one; records even with no foreground so a later discipline-entry stays suspended.
  [`TrainingLifecycleCoordinator.swift:233`](../../Peach/App/TrainingLifecycleCoordinator.swift#L233)

- Release a reason; reconcile only when the last clears — order-independent, keyed off the current foreground.
  [`TrainingLifecycleCoordinator.swift:251`](../../Peach/App/TrainingLifecycleCoordinator.swift#L251)

- Settings-close path mirrors Help (`autoStartIfIdle: true`) so a switched-to idle discipline starts on close.
  [`TrainingLifecycleCoordinator.swift:218`](../../Peach/App/TrainingLifecycleCoordinator.swift#L218)

- Auto-start guarded by `\!isForegroundSuspended` (the scene-phase guard is macOS-scoped to keep iOS unchanged).
  [`TrainingLifecycleCoordinator.swift:156`](../../Peach/App/TrainingLifecycleCoordinator.swift#L156)

**Surface gating (macOS)**

- The gate that makes the training surface inert while suspended — reuses the idle-overlay idiom, no text.
  [`TrainingIdleOverlay.swift:41`](../../Peach/App/TrainingIdleOverlay.swift#L41)

- Applied at the single per-discipline chokepoint.
  [`TrainingScreenModifier.swift:54`](../../Peach/App/TrainingScreenModifier.swift#L54)

**Help follows the current discipline**

- In-place content swap when a following window is open; provenance flag + preserved dismiss owner guard the leak.
  [`HelpPanel.swift:39`](../../Peach/App/Platform/HelpPanel.swift#L39)

- Training-screen help marked as following; re-synced on discipline change in `onAppear`.
  [`TrainingScreenModifier.swift:44`](../../Peach/App/TrainingScreenModifier.swift#L44)

- The `followsTrainingDiscipline` flag threaded through the help modifier.
  [`PlatformHelpPresentation.swift:13`](../../Peach/App/Platform/PlatformHelpPresentation.swift#L13)

- Menu-bar help / About now suspend+pause like the toolbar button, but pinned (do not follow switches).
  [`PeachCommands.swift:148`](../../Peach/App/Platform/PeachCommands.swift#L148)

**Tests**

- Multi-owner suspension suite: interleavings, order-independence, entry-order, unchanged iOS single-reason flow.
  [`TrainingLifecycleCoordinatorTests.swift:871`](../../PeachTests/App/TrainingLifecycleCoordinatorTests.swift#L871)
