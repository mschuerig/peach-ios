# Epic 88 Context: Sharpen the Core — 2026-07 Code-Reading Cleanup

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Close the three iOS-side structural findings from the 2026-07-13 code reading (`../code_reading_chat_2026-07-13.md`, iOS findings 12–14) that were selected for story treatment: rewrite the lifecycle coordinator's suspension/resume/auto-start logic as a pure `reduce()` state machine (it is "a state chart written in prose" and the most bug-prone spot in the app, with four open PF entries), teach `SoundFontPlayer` to swap SF2 presets in place so the composition root stops rebuilding sessions/coordinators/monitor on a sound-source change, and memoize `ProgressTimeline`'s per-key statistics so SwiftUI body reads stop recomputing them. Not release blockers — the next cut does not wait on this epic.

## Stories

- Story 88.1: Give TrainingLifecycleCoordinator the reduce() treatment
- Story 88.2: SoundFontPlayer.setPreset() — swap presets in place
- Story 88.3: Memoize ProgressTimeline merged statistics

## Requirements & Constraints

- **Observable behaviour unchanged** in all three stories — these are internal restructurings. 88.3 explicitly: same values, fewer recomputations.
- **Deferred-work catalog hygiene** (`docs/implementation-artifacts/deferred-work.md`): fixed PF entries are removed from the catalog and referenced in the closing story's spec/commit; deferrals must cite an existing PF entry.
  - 88.1 closes **PF-049** (help-sheet dismiss after an audio interruption silently does nothing), **PF-050** (backgrounding while the help sheet is open downgrades resume to cold restart), **PF-079** (iOS: backgrounding with the Help sheet open restarts audio behind the sheet on return — fix is applying the `!isForegroundSuspended` scene-phase guard on iOS, currently `#if os(macOS)`). **PF-051** (partial per-sub-state pause/resume test coverage) should be covered by exhaustive state×event testing — re-disposition it at story close.
  - 88.2 closes **PF-059** (`handleSoundSourceChanged` stops sessions synchronously without awaiting idle before `rebuildCoordinators()`; in-flight old stops can mute the new graph) **by construction** — no rebuild, no rebuild race.
- **Verification-first Task 1** (Epic 85 pattern) for 88.1 and 88.2: map the current code, confirm or correct each PF's framing against it, and (88.1) halt for human review before writing code. The coordinator surface was reshaped by PF-075's multi-owner suspension-reason set (2026-06-23) — PF framings may predate it.
- Every PF-049/050/079 interleaving becomes an explicit test case in 88.1. 88.3 needs a test pinning that repeated reads without writes hit the memo (e.g., a computation-counter seam) and that a write invalidates it.
- All four pre-commit gates green per story; iOS and macOS must both pass.
- 88.2 touches the audio path — consult the `/audio-programming` skill for the preset-reload path, and verify audibly before done.

## Technical Decisions

- **88.1 shape:** pure `static reduce(state:event:) -> [Effect]` mirroring `PitchDiscriminationSession`'s event/effect split (Story 75.13); effects stay imperative at the edges (session calls, navigation). State to fold in: `foregroundSuspensions` (multi-owner reason set), `pausedDestination`, the auto-start policy, and the navigation task. The coordinator remains the single authority on *when* sessions transition; sessions keep mechanism.
- **88.2 shape:** `SoundFontPlayer`'s `preset` was fixed at init (a `let`) — that init-fixedness is exactly why the rebuild machinery existed; this story makes the preset swappable in place via an explicit `setPreset(_:fadeOutDuration:)` (the engine's `loadPreset` is already lazy and idempotent, invoked on every `play()`). `PeachApp.handleSoundSourceChanged` shrinks to: stop non-idle sessions via the coordinator, apply the preset. Sessions, coordinators, and `AppAudioInfrastructureMonitor` survive the change; `rebuildCoordinators()` is deleted outright. The fade-out-duration policy (`determineFadeOutDuration(for:)` — the sine-click PF-052 mitigation) must transfer to the new path. Map everything `rebuildCoordinators()` currently rebuilds first (85.8's C1 monitor-rewire patch documents some of it).
- **88.3 shape:** per-key generation counter + memo on `ProgressTimeline`, invalidated on record append/reset/import. Also cover the O(n)-per-trial `add_point` re-bucketing (code-reading finding 16) only if the memo shape makes the incremental fix free; otherwise leave it — judged harmless today.
- **Out of scope:** the generic training-screen host (finding 15 / PF-081 — waits for the sixth discipline), the TOD metric-unit question (Epic 83, story 83.2), and all web-side findings.

## Cross-Story Dependencies

- Preferred order: **88.2 before 88.1** — deleting `rebuildCoordinators()` first shrinks the coordinator surface 88.1 rewrites. Not a strict dependency.
- 88.3 is fully independent of the other two.
- Each story lands as its own commit.
