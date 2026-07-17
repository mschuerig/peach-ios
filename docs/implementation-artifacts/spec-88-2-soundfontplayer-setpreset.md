---
title: 'Story 88.2: SoundFontPlayer.setPreset() — swap presets in place'
type: 'refactor'
created: '2026-07-17'
status: 'in-review'
baseline_commit: 'dc41a1a7'
review_loop_iteration: 0
context: ['docs/implementation-artifacts/epic-88-context.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Changing the sound source rebuilds the world: `PeachApp.handleSoundSourceChanged` constructs a new `SoundFontPlayer` (its `preset` and `fadeOutDuration` are `let`), recreates the pitch sessions, and calls `rebuildCoordinators()` — replacing the lifecycle coordinator, settings coordinator, and audio monitor, discarding live coordinator state (`foregroundSuspensions`, `currentTrainingDestination`), and carrying subtle invariants (85.8 C1 monitor rewire, stop-before-rebuild ordering). PF-059's stop-race lives inside this machinery.

**Approach:** Give `SoundFontPlayer` an explicit `setPreset(_:fadeOutDuration:)` that mutates preset state in place — the engine's `loadPreset` is already idempotent per channel and called on every `play()`, so the next note picks the new preset up. Shrink `handleSoundSourceChanged` to "stop non-idle sessions via the coordinator, apply the preset"; delete `rebuildCoordinators()` outright. PF-059 dissolves by construction: with no rebuild there is no rebuild race.

## Boundaries & Constraints

**Always:**
- Sessions, both coordinators, and `AppAudioInfrastructureMonitor` survive a sound-source change — same instances, no environment re-publication.
- `setPreset` is a synchronous state mutation; the engine load stays lazy on the next `play()` (which awaits the `pendingAudioStop` chain, preserving stop/play ordering).
- The fade-out policy transfers: `determineFadeOutDuration(for:)` is applied on every preset change (sine `sf2:8:80` → 25 ms, all others → `.zero`) — the PF-052 click mitigation must keep working.
- The coordinator preserves `foregroundSuspensions` and `currentTrainingDestination` across the change; `pausedDestination` is cleared because the paused session is stopped.
- Catalog hygiene: remove PF-059 from `docs/implementation-artifacts/deferred-work.md`; cite it in the commit message.
- Observable behaviour otherwise unchanged; the one intended improvement is suspension-state survival (see I/O matrix row 3).

**Ask First:**
- Anything that would touch the percussion/sequencer channel (`MIDIChannel(1)`, `SoundFontBeatSequencer`) — expected fully untouched.
- Any need to eagerly pre-load the preset in `setPreset` (e.g. first-note latency concerns) — the lazy design is deliberate; renegotiate before adding async work there.

**Never:**
- No `setPreset` on the `NotePlayer` protocol — `SF2Preset` is SoundFont-specific; the composition root holds the concrete `SoundFontPlayer`.
- No changes to `SoundFontEngine.loadPreset` semantics, the media-reset rebuild, or the MIDI dispatch paths (PF-054 stays untouched).
- No changes to session state machines or `SettingsCoordinator` behaviour.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Change while everything idle | New tag in Settings | Next played note (preview or trial) sounds with the new preset; no object replaced | N/A |
| Change during active training | One session non-idle | Session stops via coordinator; coordinator bookkeeping stays consistent | N/A |
| Change while paused behind macOS Settings window | Paused session, `.settingsWindow` suspension held | Paused session stopped, `pausedDestination` cleared, suspension retained; closing Settings auto-starts per policy (today's rebuild loses `currentTrainingDestination` and silently breaks this — intended improvement) | N/A |
| Change to/from Sine Wave | Preset bank 8, program 80 | `player.fadeOutDuration` becomes 25 ms (to sine) / `.zero` (away from sine) | N/A |
| `.onChange` fires at launch | Stored tag ≠ code default | Cheap no-rebuild mutation; sessions all idle, nothing stops | N/A |

</frozen-after-approval>

## Code Map

- `Peach/Core/Audio/SoundFontPlayer.swift` -- `preset`/`fadeOutDuration` are `let` (lines 22–30); `play()` calls `soundFontEngine.loadPreset(preset, channel:)` every time (line 56)
- `Peach/Core/Audio/SoundFontEngine.swift` -- `loadPreset` (line 616) is idempotent via `loadedPresets[channel]` guard (line 632); no engine changes needed
- `Peach/App/PeachApp.swift` -- `handleSoundSourceChanged` (220–265), `rebuildCoordinators` (267–300, incl. C1 monitor block), `setupPlayers` (382–407, returns `any NotePlayer`), `determineFadeOutDuration` (414–419), `@State notePlayer` (line 33)
- `Peach/App/TrainingLifecycleCoordinator.swift` -- gets the new stop-all entry point; `discardLingeringPausedSession` (342) already handles the paused case
- `Peach/App/Training/TrainingLifecycleRegistry.swift` -- only exposes `contribution(for:)`; needs an all-contributions accessor
- `PeachTests/Core/Audio/SoundFontPlayerTests.swift` -- real engine + `TestSoundFont`; `makePlayer(preset:)` factory; engine exposes `loadedPresetCountForTesting` (a which-preset accessor may need adding)
- `PeachTests/Core/Audio/SoundFontPresetStressTests.swift` -- line 155 "Rapid preset switching creates new player per preset without crash" encodes the current new-player-per-preset model
- `PeachTests/App/TrainingLifecycleCoordinatorTests.swift` -- `makeCoordinator` factory + `MockTrainingSession`
- `docs/project-context.md` -- lines 78 and 91 describe the old flow (line 78 is already stale: claims per-play `userSettings.soundSource` read)
- `docs/planning-artifacts/architecture.md` -- line 3435 documents the rebuild flow
- `docs/implementation-artifacts/deferred-work.md` -- PF-059 entry (line 262)

## Tasks & Acceptance

**Execution:**
- [x] `Peach/Core/Audio/SoundFontPlayer.swift` -- make `preset` and `fadeOutDuration` `private(set) var`; add `func setPreset(_ preset: SF2Preset, fadeOutDuration: Duration)` (synchronous mutation only) -- the single capability the whole rebuild machinery substitutes for
- [x] `Peach/App/Training/TrainingLifecycleRegistry.swift` -- expose `var all: [Contribution]` -- coordinator stop-all needs to iterate every registered session
- [x] `Peach/App/TrainingLifecycleCoordinator.swift` -- add `func handleSoundSourceChanged()`: `discardLingeringPausedSession()` then `stop()` every remaining non-idle registered session; must not touch `foregroundSuspensions` or `currentTrainingDestination` -- joins the existing `handle*` family as the canonical multi-session stop
- [x] `Peach/App/PeachApp.swift` -- type `notePlayer` as `SoundFontPlayer` (adjust `setupPlayers` return type); shrink `handleSoundSourceChanged` to `trainingLifecycle.handleSoundSourceChanged()` + resolve tag + `notePlayer.setPreset(preset, fadeOutDuration: Self.determineFadeOutDuration(for: preset))`; delete `rebuildCoordinators()` and the session-recreation block -- `createPitchDiscriminationSession`/`createPitchMatchingSession`/`createChromaticConstructionSession` remain (still used by `init`)
- [x] `PeachTests/Core/Audio/SoundFontPlayerTests.swift` -- test `setPreset`: mutates `preset` + `fadeOutDuration`; `play()` after `setPreset` uses the new preset (via an engine loaded-preset seam; add an internal accessor if none exists)
- [x] `PeachTests/Core/Audio/SoundFontPresetStressTests.swift` -- migrate the rapid-preset-switching test (line 155) from new-player-per-preset to repeated `setPreset` on one player -- the stress test should exercise the new model
- [x] `PeachTests/App/TrainingLifecycleCoordinatorTests.swift` -- test `handleSoundSourceChanged()`: stops active session; stops paused session and clears `pausedDestination`; preserves `foregroundSuspensions` and `currentTrainingDestination`; macOS flow: change-while-suspended then `reconcileForegroundSession()` auto-starts per policy; no-op when all idle -- model on the existing Menu Navigation / Media Reset suites (`MockTrainingSession`, `waitUntilStopped`)
- [x] `docs/project-context.md` -- update line 78 (player holds preset, `setPreset` swaps in place) and line 91 (coordinator routing: `handleSoundSourceChanged` → stop all non-idle sessions; no rebuild)
- [x] `docs/planning-artifacts/architecture.md` -- update the line-3435 table row to the new flow
- [x] `docs/implementation-artifacts/deferred-work.md` -- remove PF-059 (dissolved by construction)

**Acceptance Criteria:**
- Given any app state, when the sound source changes, then no `SoundFontPlayer`, session, coordinator, or monitor instance is replaced (identity-stable), and `rebuildCoordinators()` no longer exists in the codebase
- Given an active or paused session, when the sound source changes, then every non-idle session stops through the coordinator and coordinator suspension/destination bookkeeping remains consistent
- Given a sound-source change to Sine Wave, when the next note stops, then the 25 ms fade-out engages (no click); away from Sine Wave, fade-out returns to `.zero`
- Given a sound-source change, when the next note plays (preview or trial), then it sounds with the new preset

## Spec Change Log

## Design Notes

Implementation notes (2026-07-17): two small additions beyond the task list. (1) `scheduleStopAll()` now snapshots `fadeOutDuration` at commit time (matching `scheduleNoteStop`'s existing capture) — with the property mutable, a lazy read at task-execution time would let a `setPreset` away from Sine Wave strip the 25 ms fade off an already-committed sine-note stop (PF-052 click). Stops keep the fade they were committed with; the frozen constraint "the fade-out policy transfers" is what this preserves. (2) Boy Scout: `bin/check-dependencies.sh` failed at baseline on a comment-only `SettingsScreen` reference in `Training/TimingOffsetDetection/TimingDotView.swift:214`; reworded to "the Settings screen" — gate now clean.

Review patch round (2026-07-17): adversarial review found a fade late-binding cluster — with `fadeOutDuration` now late-bound mutable state, notes already sounding at `setPreset` time could observe post-swap fade values in three windows (under the old rebuild model, in-flight audio held the doomed player's immutable fade). Fixes: (1) `scheduleNoteStop` takes `fadeOutDuration` as a parameter and `SoundFontPlaybackHandle.stop()` passes its play-time capture, so a timed note whose stop commits after the note duration keeps the fade it was played with; (2) `play()` snapshots `preset` + `fadeOutDuration` once after awaiting the chain, so a `setPreset` landing at the `loadPreset` suspension cannot produce a mixed note — a play awaiting the chain when `setPreset` lands deliberately binds to the post-swap preset; (3) `PeachApp.handleSoundSourceChanged` commits a synchronous `scheduleStopAll()` BEFORE `setPreset`, silencing straggler preview audio (the Settings preview's async stop path commits on a later MainActor turn) with the old fade. Both snapshots are pinned by tests via a new `muteForFadeCallCountForTesting` engine seam. Honest note on acceptance criterion 1: identity stability / `rebuildCoordinators()` deletion is verified by review + grep, not by an automated test.

Verified framing (Task-1 evidence, 2026-07-17): the epic sketch says the player "already reads `userSettings.soundSource` on each `play()`" — that is outdated; `preset` is a `let` set at init, which is exactly why the rebuild exists. The engine side needs nothing: `loadPreset` is lazy, idempotent (`loadedPresets[channel]` guard), and invoked on every `play()`. `AppAudioInfrastructureMonitor` references only the coordinator; `notePlayer` is constructor-injected everywhere (never in the SwiftUI environment); `KazezNoteStrategy` is stateless, so dropping its recreation changes nothing. Lazy `setPreset` avoids any ordering interaction with in-flight `scheduleStopAll` chain entries — `play()` already awaits the chain tail before loading. The historical "MIDI pitch bend lost on sound source change" bug class (session recreation dropping constructor args) is eliminated wholesale. PF-059's proposed fix was "await idle before rebuilding" — dissolved instead: with nothing rebuilt, no await is needed; in-flight session stops land on surviving objects and `play()`'s chain-tail await provides the ordering.

## Verification

**Commands:**
- `bin/test.sh && bin/test.sh -p mac` -- expected: full suite green on both platforms (never in parallel)
- `bin/build.sh && bin/build.sh -p mac` -- expected: no errors/warnings
- `archlint Peach/` and `bin/check-dependencies.sh` -- expected: clean

**Manual checks (if no CLI):**
- Michael listening test before `done` (audio-path change): switch Grand Piano ↔ Sine Wave ↔ Cello mid-idle and mid-training at noteDuration 1 s — next notes sound with the new instrument, sine notes end without click, training stops cleanly on change
- Sharpened PF-052 scenario: with Sine Wave selected and noteDuration 1 s, start a Settings preview note and switch away from Sine Wave while the note is still sounding — the preview must end without a click (its stop keeps the sine 25 ms fade despite the swap)

## Suggested Review Order

**The new capability — in-place preset swap**

- Entry point: the whole story is this synchronous mutation replacing the rebuild machinery
  [`SoundFontPlayer.swift:59`](../../Peach/Core/Audio/SoundFontPlayer.swift#L59)

- `play()` snapshots preset + fade once after the chain await — one consistent note, deliberate post-swap binding
  [`SoundFontPlayer.swift:75`](../../Peach/Core/Audio/SoundFontPlayer.swift#L75)

**Fade-out late-binding protection (review-round patches, PF-052)**

- Commit-time fade snapshot: a setPreset between commit and execution cannot strip a sine stop's fade
  [`SoundFontPlayer.swift:101`](../../Peach/Core/Audio/SoundFontPlayer.swift#L101)

- `scheduleNoteStop` now takes the caller's play-time fade instead of reading mutable state late
  [`SoundFontPlayer.swift:130`](../../Peach/Core/Audio/SoundFontPlayer.swift#L130)

- The handle passes its play-time capture — previously only used in the dead-player fallback
  [`SoundFontPlaybackHandle.swift:36`](../../Peach/Core/Audio/SoundFontPlaybackHandle.swift#L36)

**Composition root shrinks; rebuild machinery deleted**

- 85 lines → 3: coordinator stop-all, then stragglers stopped with old fade (load-bearing order), then setPreset
  [`PeachApp.swift:220`](../../Peach/App/PeachApp.swift#L220)

**Coordinator becomes the canonical multi-session stop**

- New `handle*`-family entry point; suspensions and current destination deliberately survive
  [`TrainingLifecycleCoordinator.swift:350`](../../Peach/App/TrainingLifecycleCoordinator.swift#L350)

- Registry exposes all contributions for whole-app operations
  [`TrainingLifecycleRegistry.swift:53`](../../Peach/App/Training/TrainingLifecycleRegistry.swift#L53)

**Docs and catalog hygiene**

- Player description rewritten (line 78) and coordinator routing entry (line 91)
  [`project-context.md:78`](../project-context.md#L78)

- Routing table row: no rebuild, instances survive
  [`architecture.md:3435`](../planning-artifacts/architecture.md#L3435)

- PF-059 entry removed — dissolved by construction (see git diff)
  [`deferred-work.md:1`](deferred-work.md#L1)

**Tests (peripherals)**

- setPreset mutation + next-play pickup via new engine seam
  [`SoundFontPlayerTests.swift:289`](../../PeachTests/Core/Audio/SoundFontPlayerTests.swift#L289)

- Both fade snapshots pinned against future "simplification" back to direct property reads
  [`SoundFontPlayerTests.swift:322`](../../PeachTests/Core/Audio/SoundFontPlayerTests.swift#L322)

- Stress tests migrated to one-player model; mid-note swap concurrency added
  [`SoundFontPresetStressTests.swift:155`](../../PeachTests/Core/Audio/SoundFontPresetStressTests.swift#L155)

- Seven coordinator tests: stop-all semantics, bookkeeping survival, macOS reconcile both auto-start branches, double-stop tolerance
  [`TrainingLifecycleCoordinatorTests.swift:1210`](../../PeachTests/App/TrainingLifecycleCoordinatorTests.swift#L1210)

- Engine test seams: which-preset accessor and muteForFade counter
  [`SoundFontEngine.swift:448`](../../Peach/Core/Audio/SoundFontEngine.swift#L448)
