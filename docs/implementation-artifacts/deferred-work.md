# Deferred Work — Pre-Existing Findings Catalog

**Single source of truth for known pre-existing issues not caused by the current change.** Every entry has a unique `PF-###` ID and a disposition. The append target referenced by `bmad-quick-dev` (`step-04-review.md`, `step-oneshot.md`, etc.) is this file; the catalog discipline is colocated with the BMad mechanism that writes to it.

This file supersedes `docs/pre-existing-findings.md` (catalog protocol moved here on 2026-06-05). Historical story specs that reference PF-001..PF-004 by ID still resolve — those IDs were ported here unchanged.

## How to add an entry

When a review surfaces a finding classified as `defer`:

1. Allocate the next free `PF-###` (3-digit, sequential — highest ID below + 1).
2. Append a section using this format:

   ```markdown
   ### PF-###: Short title

   **Found:** YYYY-MM-DD (Story X.Y or context)
   **Severity:** Low | Medium | High
   **Disposition:** OPEN | WONT-FIX

   Symptom — what the bug or issue is, with code anchors.

   **Fix:** Proposed resolution sketch. If unknown, write "TBD" with what needs to be decided.
   ```

3. Group under `## OPEN` or `## WONT-FIX`.

When a finding is fixed: remove its section and reference its `PF-###` in the closing story's spec/commit. Git history (`git log -p -- docs/implementation-artifacts/deferred-work.md`) preserves all removed entries.

**Reviewers:** classifying a finding as "pre-existing" or "defer" requires citing an existing `PF-###`. If no entry exists, it's a new finding — add one here with a disposition before deferring. Untracked deferrals are not accepted.

---

## WONT-FIX — Documented Exceptions

### PF-006: `AsyncStream` single-consumer on `MIDIKitAdapter.events`

**Found:** 2026-03-27 (MIDI pitch bend fix)
**Severity:** Low
**Disposition:** WONT-FIX (sessions are mutually exclusive by design and that won't change)

`MIDIKitAdapter.events` is a single `AsyncStream` shared between `PitchMatchingSession` and `ContinuousRhythmMatchingSession`. `AsyncStream` is documented as single-consumer. The constraint is not violated in practice because `TrainingLifecycleCoordinator.activeSession` is a single reference — only one session is active at any time — and parallel-discipline sessions are not on any roadmap.

**Fix:** No fix planned. If a future discipline ever needs to consume MIDI in parallel with another, switch to `AsyncBroadcastSequence` or per-session streams — but that would be a discipline-architecture change, not a fix to this entry.

### PF-016: `refillThreshold` uniform-tempo assumption

**Found:** 2026-06-02 (Story 80.0)
**Severity:** Low
**Disposition:** WONT-FIX (no roadmap for varying-tempo disciplines; assumption now documented inline)

`SoundFontBeatSequencer.refillThreshold` is computed once from `samplesPerBeat` at start, so a future discipline that varied tempo mid-session would mis-estimate refill timing. Every shipping discipline keeps tempo constant within a session, so the assumption stays correct for the life of the run-loop. The uniform-tempo assumption is documented inline at the `refillThreshold` computation site in `Peach/Core/Audio/SoundFontBeatSequencer.swift`.

**Fix:** No fix planned. If a future discipline ever needs to vary tempo mid-session, recompute `refillThreshold` on tempo change (or expose a tempo-change API that recomputes it as a side effect) — that story owns the refactor when planned.

### PF-019: O(N²) `PianoKeyboardLayout` x-position lookups

**Found:** 2026-06-03 (Story 81.3)
**Severity:** Low
**Disposition:** WONT-FIX (~465K ops/sec at 88 keys × 60 Hz drag — below perceptible-jank; trigger conditions documented inline)

`xPosition(forNote:)` is O(N) (filters `notes.prefix(while:)` for the white-key index), and `midiNote(at:)` calls it once per note (O(N²)). At the largest in-app range (88 keys) sustained at 60 Hz the cost is well below perceptible-jank on supported devices. Doc-comments on both methods in `Peach/Core/Music/PianoKeyboardLayout.swift` name the O(N²) and the trigger conditions for revisiting.

**Fix:** No fix planned. If a future caller renders a wider keyboard, animates per-key opacity at high frequency, or runs on a lower-performance device, precompute a `[MIDINote: CGFloat]` cache or an O(1) white-key-index table.

### PF-023: AX1+ Slider partner-imposed range shifts during edit

**Found:** 2026-06-03 (Story 81.3)
**Severity:** Low
**Disposition:** WONT-FIX (standard SwiftUI behavior for range-pair Sliders)

When the user moves one bound's Slider in `NoteRangeSelector`'s AX1+ accessibility path, the partner's legal range narrows synchronously. VoiceOver may announce the partner Slider's max changing under it. Standard behaviour for range-pair Sliders; acceptable for first cut but a UX polish item.

**Fix:** No fix planned. Revisit if a user reports the announcement is disruptive.

### PF-024: Black-key vs white-key y-aware hit-test

**Found:** 2026-06-03 (Story 81.3)
**Severity:** Low
**Disposition:** WONT-FIX (the piano keyboard is used for range-bound selection only, not per-note entry; finger-tap precision already exceeds single-semitone resolution for the actual use case)

`PianoKeyboardLayout.midiNote(at:)` is x-only. A tap on the bottom (white-only) half of a column over a black key resolves to the black key, even though visually the user pressed the white-key portion below it.

**Why this stays unfixed:** The keyboard is used only by `NoteRangeSelector` to set the lower / upper bound of the Training Note Range — not for melody entry or per-note interaction. Range bounds are coarse-grained ("around C4"); a single-semitone misresolution is easily corrected by the user via marker drag, keyboard arrows, or the AX1+ Sliders. Combined with adult-finger contact area exceeding single-semitone width on a screen-rendered keyboard, the catalog's proposed refinement would change behaviour the user can't reliably perceive or control on a use case that doesn't need it.

**Fix:** No fix planned. Revisit if/when a per-note entry use case lands on the keyboard (currently no such use case exists).

### PF-026: `BoundMarker` tap target ~30×30, below FR38's 44×44 minimum

**Found:** 2026-06-03 (Story 81.3)
**Severity:** Low
**Disposition:** WONT-FIX (documented trade-off)

Spec Change Log records the trade-off (44×44 markers would visually overlap at the 12-semitone minimum span on iPhone portrait). The multimodal access path (drag, tap-on-dimmed, kbd arrows, accessibility-representation Slider) means the drag target is one of several ways in, and AX1+ falls back to a system Slider entirely.

**Fix:** No fix planned. Revisit if a user reports drag imprecision; the cleanest fix is to expand the marker pill itself (visual + tap target both grow) rather than decoupling content shape from visual shape.

### PF-028: Boy Scout opportunity in `GridToggleRow`

**Found:** 2026-06-03 (Story 82.1)
**Severity:** Low
**Disposition:** WONT-FIX (deferred pending wider picker refactor)

`GridToggleRow` has zero explicit accessibility (no `accessibilityLabel`, no selection trait). The TOD picker introduced in Story 82.1 added both. Explicitly deferred by user direction during 82.1 review: "We will have to revise this anyway to handle more complicated rhythmic patterns" — i.e., the next picker-refactor story will replace `GridToggleRow` rather than retrofit it.

**Fix:** Reassess at the next discipline that needs a picker (Continuous Rhythm Matching gap-positions, currently the closest candidate).

### PF-030: `AppTimingOffsetDetectionUserSettings.selectedPattern` recomputes + logs on every access

**Found:** 2026-06-05 (Story 84.2)
**Severity:** Low
**Disposition:** WONT-FIX (self-healing on first user pick; the catalog noise was a dev-only window that closes on canonicalization)

`selectedPattern` reads `defaults` and resolves via `pattern(forStoredId:)`, which writes a `.warning` log when the id is unknown. No memoization, no log dedup — every read with a stale id emits a fresh warning line.

**Why this stays unfixed:** Production users start with the canonical default `selectedPatternId` (no warning). The window where the warning fires is dev-only: a device that survived the 84.2 id swap with a stale stored id, before its user makes a pattern selection (which canonicalizes the id and stops the warning). Bounded, self-healing, and tied to one specific migration that has already shipped. Memoization (option a, mutable state on a getter for no functional benefit) and a per-process warn-once `Set<String>` (option b, preventive plumbing) are both overengineering for a window that's already closed in practice.

**Fix:** No fix planned. The next id-rename event (when it comes) gets the warn-once mechanism as part of that story's scope, not as preventive plumbing here.

### PF-033: `TimingDotView` natural width can grow unbounded on deeply nested patterns

**Found:** 2026-06-05 (Story 84.3)
**Severity:** Low
**Disposition:** WONT-FIX (Epic 84 max nesting depth is 1; future deep-nesting epic owns the rendering adjustment; assumption documented inline)

With the proportional-timeline renderer driven by `GeometryReader`-supplied width, very deep nesting (e.g., sextuplet-inside-duplet-inside-triplet, smallest cell ≈ 1/36 of beat) would compress the smallest cell's pixel width below the dot diameter. Not triggered by any shipped pattern. The depth-1 assumption is documented inline on `TimingDotView.visualCells(for:)` in `Peach/Training/TimingOffsetDetection/TimingDotView.swift`.

**Fix:** No fix planned. A future multi-beat or depth-3 epic must either cap the renderer's effective scale on deep nests or render an alternate summary representation — that epic owns the renderer adjustment when planned.

### PF-034: `TimingDotView.cellAccessibilityLabel`'s `childDivision` walk only inspects the top-level `.nested`

**Found:** 2026-06-05 (Story 84.3)
**Severity:** Low
**Disposition:** WONT-FIX (Epic 84 max nesting depth is 1; correct for every shipped entry; assumption documented inline)

`childDivision(forAudiblePosition:)` only inspects the top-level `.nested(_)` child. For an audible at `path = [1, 2, 0]` (inside `pattern.subdivisions[1].nested(_).subdivisions[2].nested(_)`) the function returns the K of `subdivisions[1].nested(_)`'s direct child, not of the actually-containing deeper nest. Every shipped pattern's audible lives at depth ≤ 1, so the function is correct for the current catalog. The assumption is documented inline on `childDivision(forAudiblePosition:)` in `Peach/Training/TimingOffsetDetection/TimingDotView.swift`.

**Fix:** No fix planned. At the depth-2 epic, walk `path` through the `.nested(child)` levels to the actual containing `Beat` instead of stopping at the top.

### PF-035: Dotted-and-nested precedence not specified

**Found:** 2026-06-05 (Story 84.3)
**Severity:** Low
**Disposition:** WONT-FIX (Epic 84 has no overlap; first mixed-duration nested entry settles the precedence; question documented inline)

`TimingOffsetDetectionPattern.dottedAudiblePositions` and `childDivision(forAudiblePosition:)` are independent checks. If a future catalog entry has both true for the same audible position, the dotted branch wins (line ordering in `TimingDotView.cellAccessibilityLabel`'s `.normalAudible` case) and the nested-context descriptor is silently dropped. No Epic-84 entry exercises the overlap. The latent precedence question and the three resolution options are documented inline at the precedence site in `Peach/Training/TimingOffsetDetection/TimingDotView.swift`.

**Fix:** No fix planned. The first catalog entry with both flags true must pick one of (a) combine descriptors ("Note N of K, dotted, in triplet"); (b) define an explicit precedence in `tod-tuplet-renderer-design.md`; (c) make the flags mutually exclusive at the catalog boundary via `TimingOffsetDetectionPattern.init` — consult Adam (`agent-music-domain-expert`) for the user-facing label call.

---

## OPEN — Needs Architectural Decision

### PF-048: TimingOffsetDetection `gridOrigin` not refreshed on `resume()`

**Found:** 2026-06-05 (Story 85.1 step-04 review — Edge Case Hunter)
**Severity:** Low (bounded drift; audible only on long pauses)
**Disposition:** OPEN

`TimingOffsetDetectionSession.gridOrigin` is set once at first `beginNextTrial` from wall-clock `currentTime()`. `pause()` preserves it; `resume()` does not refresh it. After a long pause the next `scheduleFeedbackTimer` computes `nextGridPoint(quarterNoteDuration:)` against a stale origin while the audio clock has reset to 0 inside the sequencer. The grid alignment drift is bounded (≤ one quarter-note's wait), but the post-resume rhythmic feel is no longer audio-aligned.

**Fix:** Reset `gridOrigin = currentTime()` at the top of `resume()` before issuing `restartSequencerForCurrentTrial`. Add a test that pauses the session, advances `currentTime` by ≥1 second, resumes, and asserts the next feedback-timer grid wait is bounded to one quarter-note.

### PF-049: Help sheet open at audio-interruption silently does nothing on dismiss

**Found:** 2026-06-05 (Story 85.1 step-04 review — Edge Case Hunter)
**Severity:** Low (narrow interleaving; user can manually re-enter)
**Disposition:** OPEN

Sequence: user opens help sheet while training is active → coordinator pauses session. Audio interruption (phone call, AirPods disconnect) fires via `AudioInterruptionObserving.onStopRequired` → session's `stop()` runs → `isPaused = false`, state → `.idle`. User dismisses help sheet → coordinator's `helpSheetDismissed()` sees `pausedSession` still set (it points at the now-idle session) → calls `pausedSession.resume()` which is a no-op (`guard isPaused`) → clears `pausedSession`. Net effect: dismissing the help sheet after an audio interruption neither restarts training nor surfaces the interruption — the user is left on the training screen with no signal that they need to tap "Start" again.

**Fix:** When the coordinator's `pausedSession` becomes idle without going through `resume()`, the coordinator should detect this and fall through to the `shouldAutoStartTraining` branch on dismiss. One option: have the session signal "I went idle while paused" so the coordinator can drop the stale reference proactively. Simpler: in `helpSheetDismissed`, check `paused.isIdle` first — if the paused session became idle without coordination, treat as no-pause.

### PF-050: Scene-phase background while help sheet is open silently downgrades resume to cold restart

**Found:** 2026-06-05 (Story 85.1 step-04 review — Edge Case Hunter)
**Severity:** Low (narrow interleaving; downgrades preservation, doesn't lose data)
**Disposition:** OPEN

Sequence: help sheet open with `pausedSession` set → app backgrounds → `handleScenePhase(.background)` → `stopCurrentSession()` → `discardLingeringPausedSession()` stops the paused session and clears the reference → app returns active → on iOS `handleScenePhase(.active)` auto-restarts (cold) → user dismisses help sheet later → `helpSheetDismissed()` sees `pausedSession == nil` → falls through to `shouldAutoStartTraining` → starts again. Net effect: the in-trial state preserved by `helpSheetPresented`'s pause is lost; on dismiss the training restarts from scratch silently.

**Fix:** Either (a) document the downgrade explicitly in the spec (acceptable since user-initiated backgrounding has its own stop semantics), or (b) when help sheet is open, `handleScenePhase(.background)` should defer the stop until dismiss. (b) is more invasive and probably not worth the complexity.

### PF-051: Per-session pause/resume sub-state coverage in tests is partial

**Found:** 2026-06-05 (Story 85.1 step-04 review — Edge Case Hunter)
**Severity:** Low (no current bug; surface for future drift)
**Disposition:** OPEN

The new `PauseResumeContractTests.swift` covers pause from one representative sub-state per session (e.g. `.awaitingSliderTouch` / `.awaitingAnswer` / `.playingPatternLoop`) plus the MIDI-deflection clear in PM and the feedback-overlay clear in PD. Pause from `.playingReference` (PM), `.playingTargetNote` (PD), `.waitingForGrid` (TOD), and CRM's mid-trial sub-states is exercised only indirectly through the integration tests. A focused per-sub-state contract suite would catch future regressions earlier.

**Fix:** Add `pauseFromSubState_<state>` tests for each session, asserting (a) `isIdle == false` after pause, (b) `currentTrial` preserved, (c) feedback overlay flags consistent, (d) resume re-engages the trial without auto-completion or stuck states.

### PF-045: Nested-pattern bracket overlay renders incorrectly in `TimingDotView`

**Found:** 2026-06-05 (Story 84.4 visual verification on iOS Simulator)
**Severity:** Medium (visual defect; gated out of non-research builds)
**Disposition:** OPEN

Michael flagged during the 84.4 visual review that "the nested patterns don't work well for me and in their visualizations, the bar on top is incorrectly displayed." The bracket overlay above the nested-child cells in `pattern_10`..`pattern_14` doesn't render at the locked geometry from `tod-tuplet-renderer-design.md` § *Grouping indicators*. As a mitigation, the nested catalog entries (`pattern_10`..`pattern_14`) and the *Nested* picker section are gated behind `PEACH_RESEARCH` (84.4 iteration 3) — App Store users see only Straight 16ths, Gapped 16ths, Triplets, and Sextuplet. The static let definitions stay defined so the renderer code path keeps exercising under unit tests; the bug surfaces only in `Debug (Research)` / `Release (Research)` configurations.

**Fix:** Visual audit of the bracket rendering — likely candidates: bracket span computation (`spanStart`/`spanEnd` in `TimingDotView.walk`), bracket `y`-offset relative to the dot top, end-inset application (`bracketEndInset` × `previewScale` in the picker preview), or interaction with `bracketReserve` (which reserves vertical space only when `cells.contains { case .nestingBracket }` is true). Should be reopened when the bracket renderer is iterated; ungating the *Nested* bucket is gated on this resolving.

**Deferral (2026-06-05, Michael):** Known limitation. The PEACH_RESEARCH gate is acceptable mitigation; the fix is only needed when the decision is made to release nested patterns publicly. Re-triage when that decision is on the table — the *Nested* category remains research-only until then.

### PF-052: Sine wave SF2 preset clicks audibly on note tail

**Found:** 2026-06-06 (Story 85.1 v2 verification listening test)
**Severity:** Low (single preset; not a default; doesn't affect training correctness)
**Disposition:** OPEN

When the user selects Sine Wave (`sf2:8:80`) as Sound Source, every note tail produces an audible click at note-off. The Grand Piano (`sf2:0:0`) and Cello (`sf2:0:42`) presets do not click — their SF2 release envelopes handle the tail gracefully. The sine preset's release envelope is near-zero, so `sampler.stopNote()` cuts the sample mid-cycle.

Today the only mitigation is `SoundFontPlayer.fadeOutDuration = .milliseconds(25)` for this specific preset (set by `PeachApp.determineFadeOutDuration(for:)`), which engages `SoundFontEngine.muteForFade()` — a global `sampler.volume = 0` on every channel that previously had race-source implications (resolved separately in Story 85.1 v2 by removing the redundant cleanup paths that engaged it from cancellation continuations). The mute mechanism remains in place and silences the click for sine; the architectural untidiness of a "global volume = 0" primitive remains.

**Fix:** Resolution candidates: (a) convert `muteForFade` to a per-channel mute (parameterized `muteForFade(channel:)` / `restoreAfterFade(channel:)` with a per-channel counter) — keeps the same shape but removes the global-mute surface; (b) shape the SF2 sine preset's release envelope at asset-prep time (offline `polyphone` or `sf2parse` re-export with a longer release segment) — eliminates the click at source, removes the need for any runtime mute mechanism; (c) inline per-sample fade-out on the render thread (more invasive, larger code surface). Recommendation: (b) if the SF2 asset can be re-shaped without significant musical change; (a) as fallback.

### PF-053: `noteDuration` setting change doesn't take effect immediately

**Found:** 2026-06-06 (Story 85.1 v2 listening test side-finding)
**Severity:** Low (workaround: end the current trial / restart training)
**Disposition:** OPEN

When the user changes the `noteDuration` setting (Settings → Reference Note Duration) during an active session, the new value does not apply to the in-flight trial. The change takes effect only after the current trial completes or the session is stopped and restarted. Several other settings (e.g. velocity, sound source) update mid-session via observation/environment; `noteDuration` does not.

The likely cause is that `noteDuration` is read once at trial start (via `from(userSettings:intervals:)` factory or equivalent settings snapshot) and the snapshot is held for the duration of the trial. Other settings either re-read on each `play()` call or are pure environment lookups that always reflect current state.

**Fix:** Either (a) re-read `noteDuration` from `userSettings` at each `play(frequency:duration:)` call site instead of at trial-start, or (b) document explicitly that `noteDuration` is a per-trial snapshot (current behaviour, just needs to be intentional). Decision lives with whether immediate change is a UX expectation worth the cost — verify with user before coding.

### PF-054: Three uncoordinated MIDI dispatch paths into the shared `AVAudioUnitSampler`

**Found:** 2026-06-06 (Story 85.1 v2 diagnosis — root-cause framing)
**Severity:** Medium (latent — the load-bearing race is fixed; this is the underlying debt)
**Disposition:** OPEN

`SoundFontEngine` has **three** uncoordinated dispatch paths from main → the shared `AVAudioUnitSampler`'s MIDI input. They share no ordering and no acknowledgement primitive:

1. **Direct MainActor dispatch.** `sampler.startNote(...)`, `sampler.stopNote(...)`, `sampler.sendController(...)`, `sampler.sendPitchBend(...)` called synchronously from MainActor. Used by `SoundFontPlayer.play()`, `SoundFontEngine.stopNotes()`, `SoundFontEngine.stopNote()`. Ordering against itself within MainActor source order.
2. **Sample-accurate scheduled queue.** Events with sample positions enqueued via `scheduleState`; drained on the render thread by reading `eventBuffer(forSlot:)` against `samplePosition`. Used by `SoundFontBeatSequencer` for rhythm patterns. Sample-accurate ordering against itself.
3. **Render-thread flag-driven reset.** `needsAllNotesOff: Atomic<Bool>` set from MainActor (`clearSchedule()`); read by the render thread on the next generation change via `exchange(false)`, then CC#123 + pitch-bend-center dispatched on all 16 channels via `midiBlock(AUEventSampleTimeImmediate, 0, 3, ptr)`. Used by `clearSchedule()` (rhythm sequencer's stop path). Code comment says this replaced an `auAudioUnit.reset()` that was crashing.

Story 85.1 v2 surfaced the cost: removing redundant cleanup paths (NotePlayer+TimedPlay's cancellation `handle.stop`, pitch's invocation of `clearSchedule`) was sufficient to close the immediate race, but the underlying three-path structure remains. The next caller added to any of these paths must understand all three to avoid reintroducing a similar race. Future drift is the latent risk.

**Research backing:** `docs/planning-artifacts/research/technical-rt-audio-control-plane-2026-06-06.md` — community consensus (Bencina, Doumler, Tyson, Liljedahl) is "unify all MIDI dispatch through one ordered SPSC queue drained on the render thread via `AUScheduleMIDIEventBlock` with `AUEventSampleTimeImmediate + offsetFrames`". The current research did not investigate the original `auAudioUnit.reset()` crash that motivated the flag mechanism; that gap should be closed before any unification, since the flag may be a workaround for a sampler defect that would also bite a unified design.

**Fix:** Resolution candidates: (a) unify all dispatch through `enqueueImmediate` / scheduled queue (largest refactor; requires understanding the original `reset()` crash so the new path doesn't reintroduce it); (b) preserve all three paths but document the ordering contract between them inline (cheapest; still leaves the trap for future callers); (c) restrict path 3 to the rhythm sequencer's actual need and remove its accessibility from pitch (smaller surface; partially done in 85.1 v2 — pitch no longer summons `clearSchedule`, but the path itself remains shared on the engine). Recommendation: track until either a 4th dispatch caller is contemplated OR the `auAudioUnit.reset()` crash root cause is understood; then pick (a) or (c).

### PF-055: `appWasSuspended` interruption reason not filtered

**Found:** 2026-06-06 (`audio-programming` skill audit — lifecycle observation gap)
**Severity:** Low (false-positive engine stops on iOS 16+; user-visible as audio cutting out when the app is briefly suspended and resumed)
**Disposition:** OPEN

`IOSAudioInterruptionObserver.handleAudioInterruption` at `Peach/App/Platform/IOSAudioInterruptionObserver.swift:52-60` treats every `.began` interruption notification as a real interruption requiring engine stop. iOS 14.5+ added `AVAudioSessionInterruptionReasonKey` so apps can distinguish genuine interruptions (phone call, Siri, timer) from the framework-internal `.appWasSuspended` case, where iOS synthesizes an interruption notification for an app that was merely suspended in background. Treating `.appWasSuspended` as a real interruption stops a session that was about to resume cleanly; on iOS 16+ this is the dominant false-positive case for backgrounded media apps and is called out explicitly in the `audio-programming` skill's `references/avaudiosession.md`.

The reason key on `.ended` (e.g., `.shouldResume`) is also not consulted, but the current handler intentionally remains stopped on `.ended` ("ended - remains stopped" — comment at line 57). That choice is independent of this entry; this PF tracks only the `.began` filter.

**Fix:** Read `AVAudioSessionInterruptionReasonKey` from `notification.userInfo`; if reason is `.appWasSuspended`, return without calling `onStopRequired`. Other reasons (`.default`, `.builtInMicMuted`, `.routeDisconnected`) continue to stop as today. Regression test: synthetic `.began` notification with reason `.appWasSuspended` asserts `onStopRequired` is NOT called; `.began` with `.default` asserts it IS called.

### PF-056: `AVAudioEngineConfigurationChangeNotification` not observed

**Found:** 2026-06-06 (`audio-programming` skill audit — lifecycle observation gap)
**Severity:** Medium (engine stays silent after hardware sample-rate or route change until app relaunch; reproducible by Bluetooth codec switching or external interface plug-in)
**Disposition:** OPEN

When the audio I/O unit observes a hardware sample-rate or channel-count change — Bluetooth codec switch (A2DP ↔ HFP), external interface plug-in at a different rate, or `AVAudioSession` re-activation — `AVAudioEngine` stops itself and uninitializes, then posts `AVAudioEngineConfigurationChangeNotification`. Peach has no observer for this notification (`grep -rn "configurationChangeNotification" Peach/` returns zero hits). After the OS event the engine is stopped and no code restarts it; the next training session produces no audio until the app is killed and relaunched.

The notification can fire on a background thread; the handler must bounce to the right isolation domain before mutating the engine. `SoundFontEngine` is the canonical owner of the engine and its sample-rate-dependent state (`sourceFormat` derived from `engine.outputNode.outputFormat(forBus: 0).sampleRate` at `Peach/Core/Audio/SoundFontEngine.swift:299`); the observer should live near the engine instance, not in the iOS-specific interruption observer.

**Fix:** Add an observer for `AVAudioEngineConfigurationChangeNotification` on the engine instance. On notification: re-read `outputNode.outputFormat(forBus: 0)`; reconnect nodes that were attached with explicit formats derived from the previous hardware format (`sourceNode` is the explicit case in current code); call `engine.start()` again. Integration test via `engine.enableManualRenderingMode(.realtime, ...)` that flips the sample rate and asserts the engine re-runs. Manual verification of which iOS routes reliably trigger this notification (BT codec switch is reportedly reliable; external mic on iPad reportedly reliable) needed.

### PF-057: `AVAudioSession.mediaServicesWereResetNotification` not observed

**Found:** 2026-06-06 (`audio-programming` skill audit — lifecycle observation gap)
**Severity:** Medium (catastrophic when it occurs — silent audio death for the rest of the process lifetime — but rare; `mediaserverd` crashes are uncommon in production)
**Disposition:** OPEN

`AVAudioSession.mediaServicesWereResetNotification` posts when `mediaserverd` (the iOS audio server) crashes and respawns. When this happens, all audio-framework state held by the app is invalid: `AVAudioEngine` is dead, every `AVAudioUnit*` instance points at a recycled component, `AVAudioFile` handles are stale, `AudioComponentInstance` references are unusable. Without an observer, audio remains dead for the rest of the process lifetime; the user cannot recover without force-killing the app. Apple's docs treat the recovery handler as mandatory for any non-trivial audio app.

Peach has no observer (`grep -rn "mediaServicesWereReset" Peach/` returns zero hits). The frequency in production is low, but the failure mode is irrecoverable and silent, so the support-load cost per occurrence is high. The `audio-programming` skill's `references/avaudiosession.md` flags this as the canonical hardening item most apps skip.

**Fix:** Observe `AVAudioSession.mediaServicesWereResetNotification`. On fire: tear down `SoundFontEngine` and every `AVAudioUnitSampler` it owns; re-configure `AVAudioSession` (category/mode/options/active); construct a fresh `AVAudioEngine` + `AVAudioUnitSampler` graph; reload presets that were loaded before the reset; stop any active training session cleanly via the coordinator (resuming mid-trial after a `mediaserverd` reset is likely not desirable — surface the reset as a user-visible "audio reconnected, session stopped" notice and let the user start a new session). Decision needed during verification: silent recovery vs. user-visible notice. Hard to reproduce without inducing a `mediaserverd` crash; if no reliable trigger recipe is found, document the recovery path is unverified-in-production until a real crash occurs.

### PF-058: `PitchMatchingSession` deferred `handle.stop()` violates 85.1 v2 chain-registration invariant

**Found:** 2026-06-06 (Story 85.3 Task 1 audit — surfaced while mapping `SoundFontPlayer.scheduleStopAll()` chain invariant across session surfaces)
**Severity:** Medium (reproduces the 85.1 v2 silencing race on a different surface; conditional reachability — requires session stop with a sounding tunable note followed by rapid re-entry)
**Disposition:** OPEN

`Peach/Training/PitchMatching/PitchMatchingSession.swift:377` and `:441-443` spawn `Task { try? await handle.stop() }` from inside the session's MainActor-isolated effect interpreter / `stopAll`. Per the 85.1 v2 chain-registration invariant documented at `docs/project-context.md:84`: *"From an async cleanup continuation … cleanup paths in async continuations must NOT register additional chain entries that are already redundant with the session-level stop."*

The deferred `handle.stop()` Task body runs in a later MainActor turn and routes through `SoundFontPlaybackHandle.stop()` → `player.scheduleNoteStop(midiNote:)`, registering a fresh entry on `SoundFontPlayer.pendingAudioStop`. The session-level `scheduleStopAll()` (line 425) already committed an earlier chain entry that silences the same note via global `stopNotes`. Chain becomes `[scheduleStopAll, handleStop]`; the `handleStop`'s `muteForFade` re-engages `activeMuteCount`, silencing any concurrent `play()` that lands during the mute window. Same shape as the 85.1 v2 race that `NotePlayer+TimedPlay.swift`'s cancellation catch caused.

Reachable when: session stops while a tunable note is sounding AND the user re-enters a pitch session quickly (within the mute window). Probability non-trivial on rapid pause/resume.

**Fix:** Apply the 85.1 v2 pattern: route session-level stops exclusively through `scheduleStopAll()` (which calls `stopNotes` globally — silences the specific note as a side effect), drop the deferred `handle.stop()` calls. `currentHandle = nil` is sufficient bookkeeping for the session's own state machine. Out of 85.3's framing; tracked separately so the fix doesn't expand sequencer-concurrency scope. Reachable but bounded — defer to a focused PitchMatching cleanup story.

### PF-059: `handleSoundSourceChanged` synchronous stop without awaiting idle before `rebuildCoordinators()`

**Found:** 2026-06-06 (Story 85.3 Task 1 audit — surfaced while mapping cross-discipline serialization invariant)
**Severity:** Low (single-user-action surface — Sound Source change during an active session; symptom is a one-shot audio glitch on the rebuilt graph)
**Disposition:** OPEN

`Peach/App/PeachApp.swift:177-215` `handleSoundSourceChanged` calls `session.stop()` synchronously on each non-idle session, then immediately constructs a new `SoundFontPlayer`, replaces session instances, and calls `rebuildCoordinators()`. The old sessions' fire-and-forget `Task { await beatSequencer.stop() }` (CRM) or `enqueueSequencerStop` (TOD) is still in flight; the new sessions begin observing the new (replaced) sequencer/notePlayer. Old in-flight stops may complete after the rebuild, possibly clearing or muting the new graph.

Reachable when: user changes Sound Source while a session is active. Narrow window; symptom is a transient audio glitch, not a crash.

**Fix:** `handleSoundSourceChanged` should `await` each non-idle session's `awaitIdle` before constructing the replacement `SoundFontPlayer` and rebuilding coordinators. Alternative: route the rebuild through the coordinator's stop+await pattern (the same path `TrainingLifecycleCoordinator.navigate(to:)` uses), so all "stop everything and replace" surfaces share one mechanism. Out of 85.3's framing (composition-root orchestration, not sequencer/session concurrency); track separately.

### PF-061: `keyboardCommit` reverses adjust direction when `current` lies outside `legalRange`

**Found:** 2026-06-06 (Story 85.4 step-04 review — Edge Case Hunter)
**Severity:** Low (corrupt `@AppStorage` write only; debugger-injected reach)
**Disposition:** OPEN

`NoteRangeSelector.keyboardCommit(_:modifiers:current:legalRange:)` computes `candidateRaw = current ± 1` (or ±12 with Shift) then clamps into `legalRange`. When `current` is itself outside `legalRange` — possible if `@AppStorage` holds an invariant-violating pair where `lowerBound = upperBound` (zero span < `NoteRange.minimumSpan = 12`) — the clamped candidate is many semitones away from `current` and in the **opposite** direction from what was requested. A user pressing `.rightArrow` (or VoiceOver swipe-up `.increment`) with `current = 60, legalRange = 21...48` snaps the bound DOWN to 48, perceived as a backwards adjust. Affects both the hardware-arrow-key path (pre-existing) and the new `adjustMarker(_:direction:)` accessibility surface added by Story 85.4. The marker's `.accessibilityValue(Text(currentNote.name))` also announces a value outside the legal range.

**Fix:** At the top of `keyboardCommit`, if `current` is outside `legalRange`, snap to the nearest legal endpoint and return that (so the first adjust is a "land in legal range" jump; subsequent adjusts behave normally). Or: pre-clamp `current` into the legal range before computing the candidate. Add a corrupt-state test for both surfaces.

### PF-062: `NoteRangeSelector` marker `.accessibilityValue` reads English `note.name` regardless of locale

**Found:** 2026-06-06 (Story 85.4 step-04 review — Edge Case Hunter)
**Severity:** Low (Voice Control / VoiceOver fluency gap; addressing is locale-aware via `accessibilityInputLabels`, but value announcement isn't)
**Disposition:** OPEN

Both `BoundMarker` accessibility composition blocks (`Peach/Settings/NoteRangeSelector.swift` markers row) set `.accessibilityValue(Text(lowerNote.name))` / `Text(upperNote.name)`. `MIDINote.name` returns `"C#4"` etc. unconditionally in English with a literal `#` character. German VoiceOver may read this as "C Raute vier" or "C number sign four" depending on voice synthesis; the locale-aware spelled-out form `"Cis vier"` is available via the new `voiceControlInputLabels(for:locale:)` helper but is not used for the value announcement. Symmetrical gap on the AX1+ Slider path (`KeyboardSummary` uses the same `lower.name` for its `.accessibilityValue`).

**Fix:** Extend `MIDINote` with a `localizedSpokenName(locale: Locale) -> String` (or, scoped: a small helper on `NoteRangeSelector`) that returns "Cis 4" / "C-sharp 4" per locale. Wire into the marker value AND the AX1+ Slider value. Resolution candidates: (a) the new helper on `MIDINote`, used by both Settings surfaces and any future spoken-pitch UI; (b) a private helper on `NoteRangeSelector`, scoped to Settings only.

### PF-063: German Voice Control `"Tap B 4"` is ambiguous between A#4 (flat-of) and B4 (English-literal)

**Found:** 2026-06-06 (Story 85.4 step-04 review — Edge Case Hunter / Blind Hunter)
**Severity:** Low (Voice Control disambiguates via "Show numbers" overlay; reachable only when speaking the literal "B" in German Voice Control)
**Disposition:** OPEN

`NoteRangeSelector.voiceControlInputLabels(for:locale:)` adds the English spaced form `"<englishPitchClass> <octave>"` unconditionally in every locale; in German locale it also adds the flat-of-A# alternative `"B <octave>"`. Result for German locale: pitch class 10 (A#) emits `["A#4", "A sharp 4", "Ais 4", "Ais4", "Ais vier", "B 4", "B4", "B vier"]`, and pitch class 11 (B) emits `["B4", "B 4", "H 4", "H4", "H vier"]`. Both keys claim `"B 4"`; a user speaking `"Tap B 4"` in German Voice Control triggers a number-overlay disambiguation prompt instead of an immediate tap. The "Show numbers" UX is acceptable but suboptimal for a frequent training-range adjustment.

**Fix:** Resolution candidates: (a) in German locale, drop the unconditional English spaced form `"B 4"` for pitch class 11 — leave only the literal `"B4"` for visual-reading and `"H 4"`/`"H 4"`/`"H vier"` for spoken; (b) drop the German flat-of-A# form `"B 4"` for pitch class 10 — leave `"Ais 4"`/`"Ais vier"` only; users must say "Ais" for A-sharp. (a) preserves classical German convention (B = A-flat, H = B-natural); (b) prefers English literal mapping at the cost of German classical idiom. Consult `agent-music-domain-expert` for the call.

### PF-060: `NoteRangeSelector` keyboard requires horizontal scroll on ≤402-pt-wide portrait

**Found:** 2026-06-06 (Story 85.5 follow-up — user-reported usability degradation)
**Severity:** Medium (visible UX issue on the default iPhone 17 Pro portrait, every user touches Settings → Training Range)
**Disposition:** OPEN

`Peach/Settings/NoteRangeSelector.swift:70` sets `minKeyboardWidth = 416` (52 white keys × 8 pt). iPhone 17 Pro portrait has ~402 pt of screen width minus Form insets (~370 pt usable), so the `fitsWithoutScrolling` branch at line 128 is false and the keyboard falls into the `ScrollView(.horizontal)` branch (line 134). The full 88-key piano never fits at once in portrait on any modern iPhone — the user sees a partial keyboard and must scroll.

Symptom is "doesn't fit on the screen in full in portrait" — by design today, but the design predates iPhone-17-Pro-as-default and is unsatisfying on devices the user works on day-to-day. The horizontal-scroll fallback was added to allow the keyboard to remain "full pitch" on iPad / mac, but on phone portrait it pushes the user into a non-obvious gesture.

**Fix:** Resolution candidates: (a) compress to 6 pt per white key on portrait (reduces `minKeyboardWidth` to 312 pt — fits any modern iPhone, but the BoundMarker tap target shrinks too); (b) render only the absolute training range (`absoluteMinNote`...`absoluteMaxNote` = 36...108, 43 white keys) so the keyboard is `43 × 8 = 344 pt` wide and fits portrait; (c) fall back to the AX1+ `KeyboardSummary` (summary line + 2 system Sliders) on horizontally-constrained layouts, not just at large Dynamic Type. Touches the same layout policy 81.3 set; deserves a focused story rather than a Boy-Scout drive-by.

### PF-064: Two parallel `@ScaledMetric` wrappers carry the TOD settings dot-row width contract

**Found:** 2026-06-06 (Story 85.7 step-04 review — Blind Hunter / Edge Case Hunter)
**Severity:** Low (no current bug; structural symmetry risk for a load-bearing contract)
**Disposition:** OPEN

Story 85.7's option (f) replaced iteration-2's structurally-identical mirrored-chevron alignment mechanism with two parallel `@ScaledMetric(relativeTo: .caption2) private var dotRowWidth: CGFloat = TimingDotView.settingsRowDotsBaseWidth` declarations — one in `TimingOffsetDetectionPatternPickerSettingsSection.swift`, one in `TimingOffsetDetectionOffsetNotePositionSettingsSection.swift`. The two wrappers resolve from each view's environment at instantiation. In production both views are siblings in the same `Form` and share the same `\.dynamicTypeSize`, so the resolved widths are equal. But a future per-section environment override (e.g., a snapshot test that sets `.dynamicTypeSize(.accessibility5)` on one section only) could cause silent divergence, breaking the dot-x-alignment contract — the entire point of option (f).

The existing precedent `dotScale` (`previewScale`) uses the same parallel-wrapper pattern across these two views without issue, so this isn't unprecedented. The hoist to a single declaration in a shared parent would require extending `DisciplineSettingsSection` with a navigation/measurement contribution channel — exactly the special-case-second-channel mechanism Michael rejected in 85.7's Task 1 audit.

**Fix:** Resolution candidates: (a) accept current parallel pattern (consistent with `dotScale` precedent), document the contract that both sections must inherit identical Dynamic Type environment; (b) hoist `@ScaledMetric` resolution to a parent via the rejected option (a) channel — re-open if a second concrete use case appears; (c) extract a shared `ViewModifier` (`.settingsRowDotsWidth()`) that encapsulates the `@ScaledMetric` + `.frame(maxWidth:)` so the contract is DRY at the symbol level even though each instance still resolves independently. (c) is the lightest near-term hardening; revisit if a divergence actually surfaces.

### PF-065: Dot-x alignment regression test missing for TOD settings rows

**Found:** 2026-06-06 (Story 85.7 step-04 review — Blind Hunter)
**Severity:** Low (no current bug; gap in test coverage for a load-bearing visual contract)
**Disposition:** OPEN

Story 85.7's option (f) pins `TimingDotView.settingsRowDotsBaseWidth == 220` (`PeachTests/Training/TimingOffsetDetection/TimingDotViewTests.swift:163`) but doesn't directly assert the actual contract: both the *Pattern* row's dot preview and the *Offset Note Position* row's slot picker render their flexible dot containers at the same width and audible positions land at the same x. A future refactor that changes one site's `.frame(maxWidth: dotRowWidth, alignment: .leading)` to `.frame(width: dotRowWidth)` (or drops the wrapper, or swaps the alignment) would leave the constant-equals-220 test green while alignment regresses silently.

Story 85.6's TOD picker invariant infrastructure (structural / catalog-discipline tests after the iOS 26 SwiftUI hosting a11y-tree regression — cashapp/AccessibilitySnapshot #245, #259) provides a cheap home for this kind of assertion.

**Fix:** Add a structural test in `PeachTests/Training/TimingOffsetDetection/Settings/` that renders both sections with identical inputs and asserts (a) the two dot containers resolve to the same width, and (b) audible positions land at the same x. If the runtime hosting tree is still broken for layout introspection on iOS 26, fall back to a snapshot-image comparison via 85.6's snapshot infrastructure. At minimum, pin the structural invariant that both views declare `@ScaledMetric(relativeTo: .caption2) private var dotRowWidth: CGFloat = TimingDotView.settingsRowDotsBaseWidth` (source-level grep or doc-test) so a refactor that drops one is caught at review time.
