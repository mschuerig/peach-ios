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

### PF-051: Per-session pause/resume sub-state coverage in tests is partial

**Found:** 2026-06-05 (Story 85.1 step-04 review — Edge Case Hunter)
**Severity:** Low (no current bug; surface for future drift)
**Disposition:** OPEN (re-dispositioned 2026-07-17, Story 88.1)

Story 88.1 gave `TrainingLifecycleCoordinator` a pure `reduce()` state machine with an exhaustive state×event matrix (`TrainingLifecycleReduceTests`), closing the *coordinator*-side interleaving gap (PF-049/050/079). This PF is orthogonal: it concerns the *sessions'* own pause/resume from each mid-trial sub-state (`PauseResumeContractTests`), which the coordinator matrix does not exercise. Left OPEN — pick up as a session-level test-hardening pass when a session state machine next changes.

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

### PF-058: `PitchMatchingSession` deferred `handle.stop()` violates 85.1 v2 chain-registration invariant

**Found:** 2026-06-06 (Story 85.3 Task 1 audit — surfaced while mapping `SoundFontPlayer.scheduleStopAll()` chain invariant across session surfaces)
**Severity:** Medium (reproduces the 85.1 v2 silencing race on a different surface; conditional reachability — requires session stop with a sounding tunable note followed by rapid re-entry)
**Disposition:** OPEN

`Peach/Training/PitchMatching/PitchMatchingSession.swift:377` and `:441-443` spawn `Task { try? await handle.stop() }` from inside the session's MainActor-isolated effect interpreter / `stopAll`. Per the 85.1 v2 chain-registration invariant documented at `docs/project-context.md:84`: *"From an async cleanup continuation … cleanup paths in async continuations must NOT register additional chain entries that are already redundant with the session-level stop."*

The deferred `handle.stop()` Task body runs in a later MainActor turn and routes through `SoundFontPlaybackHandle.stop()` → `player.scheduleNoteStop(midiNote:)`, registering a fresh entry on `SoundFontPlayer.pendingAudioStop`. The session-level `scheduleStopAll()` (line 425) already committed an earlier chain entry that silences the same note via global `stopNotes`. Chain becomes `[scheduleStopAll, handleStop]`; the `handleStop`'s `muteForFade` re-engages `activeMuteCount`, silencing any concurrent `play()` that lands during the mute window. Same shape as the 85.1 v2 race that `NotePlayer+TimedPlay.swift`'s cancellation catch caused.

Reachable when: session stops while a tunable note is sounding AND the user re-enters a pitch session quickly (within the mute window). Probability non-trivial on rapid pause/resume.

**Fix:** Apply the 85.1 v2 pattern: route session-level stops exclusively through `scheduleStopAll()` (which calls `stopNotes` globally — silences the specific note as a side effect), drop the deferred `handle.stop()` calls. `currentHandle = nil` is sufficient bookkeeping for the session's own state machine. Out of 85.3's framing; tracked separately so the fix doesn't expand sequencer-concurrency scope. Reachable but bounded — defer to a focused PitchMatching cleanup story.

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

### PF-066: PF-055 `.appWasSuspended` filter is dead code on iOS 26 deployment

**Found:** 2026-06-07 (Story 85.8 implementation surfaced during build)
**Severity:** Low (code is correct and harmless; just unreachable on the supported deployment target)
**Disposition:** OPEN

`AVAudioSession.InterruptionReason.appWasSuspended` is deprecated on iOS 16+ with the documentation note "wasSuspended reason no longer present" — the system no longer fires `.began` interruption notifications with this reason. PF-055's defensive filter compares `reasonValue == 1` (the rawValue of `.appWasSuspended`) at `Peach/App/Platform/IOSAudioInterruptionObserver.swift:91-100`; on Peach's iOS 26 deployment target the comparison never matches because the system never emits the reason. The unit tests still pass because they synthesize the notification themselves, but the production code path is unreachable.

This finding surfaced because the audit (`/audio-programming`, Story 85.8 Task 1) confirmed PF-055's framing against the catalog text but didn't cross-check the deprecation status against Peach's `iOS 26` minimum target. The Apple-docs cross-check belongs in future audits invoked against catalog entries that name specific OS-version behaviors.

**Fix:** Two viable options. (a) **Close as no-op**: delete the `reasonValue == 1` branch and its three regression tests; mark PF-055 closed in the catalog with a note that the bug is unreachable on iOS 26. (b) **Keep as defensive**: leave the code in place against the slim chance Apple revives the reason, with the existing rawValue-comparison comment documenting why the deprecated enum case isn't named directly. Option (a) is cleaner — dead code is a maintenance hazard; option (b) is paranoid. Recommend (a) and a one-line spec note that 85.8's PF-055 closure was downgraded to "no-op on iOS 26+, code removed."

### PF-067: No transient-banner pattern for audio-error UI surfacing

**Found:** 2026-06-07 (Story 85.8 step-04 review — Acceptance Auditor)
**Severity:** Low (Story 85.8 catalog-tracked errors all log at `.error` already; no user-visible regression. Gap is between the spec's frozen I/O-matrix promise and the existing UI surface.)
**Disposition:** OPEN

Story 85.8's frozen I/O matrix promises that PF-056's `engine.start()` failure path and PF-057's rebuild-throw path will "surface via existing audio-error path." The existing `AudioError` surface is structured for *fatal* error display via `fatalError` at startup (per the Task 1 audit's own analysis), not transient banners. The Story 85.8 implementation logs at `.error` from `SoundFontEngine.handleConfigurationChange` and `TrainingLifecycleCoordinator.handleMediaServicesReset`, which is the most reasonable behavior absent a transient-banner pattern, but the frozen I/O matrix expectation is partially unmet at the UX layer.

The catalog framing for Decision D=silent already accepted that PF-057 recovery is silent on the success path. The asymmetry is the *failure* path — when rebuild itself throws, the user sees only "session returned to idle" with no signal that audio is now permanently dead until app relaunch. PF-066 follow-up may take care of this if it folds into a broader "audio error UX" decision.

**Fix:** Either (a) leave as-is (current `.error` logging is informational and matches the project's "sober factual UI" stance); (b) add a transient-banner pattern on the active training screen that surfaces `AudioError` with informal-du copy; (c) extend the existing `AudioError` enum with a "recoverable-failure" case and wire a SwiftUI `.alert` to a coordinator-published `currentRecoverableError` value. Decision deferred — no current production trigger has been observed, and the cost of a banner pattern outweighs the value for a low-frequency failure mode. Revisit if user reports of "audio went dead and didn't come back" surface in TestFlight.

### PF-068: `ForTesting`-suffixed methods sit on production type surface

**Found:** 2026-06-07 (Story 85.8 step-04 review — Acceptance Auditor)
**Severity:** Low (no current bug; production calls never reach these methods, but the surface area is technically callable from any internal site.)
**Disposition:** OPEN

`SoundFontEngine` exposes five test-only seams: `postSyntheticConfigurationChangeForTesting`, `stopEngineForTesting`, `loadedPresetCountForTesting`, `pendingPresetReloadCountForTesting`, `sourceNodeIdentityForTesting`, `engineIdentityForTesting`, `forceStaleSourceSampleRateForTesting`. They are internal (default access) with no `#if DEBUG` gating or `@_spi(Testing)` attribute. A future contributor could call them from production code by mistake, and they show up in autocomplete next to the real API.

**Fix:** Two options. (a) Wrap each with `#if DEBUG` — release builds drop them entirely. (b) Add `@_spi(Testing)` attribute — opt-in import for tests, still excluded from the auto-suggested API surface elsewhere. (a) is the heavier hammer; (b) is the canonical Swift solution and what other Apple-platform projects use for test seams. Recommend (b) — `@_spi(Testing) internal` on each — but holding off until the broader Story 85.8 work is settled.

### PF-069: Lifecycle-test timing waits use blanket `Task.sleep(50ms)`

**Found:** 2026-06-07 (Story 85.8 step-04 review — Blind Hunter + Edge Case Hunter)
**Severity:** Low (tests pass reliably on dev machines; CI flakiness is hypothetical.)
**Disposition:** OPEN

Multiple new tests added in Story 85.8 use `try? await Task.sleep(for: .milliseconds(50))` followed by an assertion as their progress signal — `IOSAudioInterruptionObserverTests` (PF-055, Lost/Reset closure tests), `SoundFontEngineConfigurationChangeTests`, `SoundFontEngineMediaResetTests` (rebuild + re-registration), and `TrainingLifecycleCoordinatorTests` (handleMediaServicesReset, lost-then-reset). The 50ms is empirically fine on a quiet machine, but the lack of a progress-based signal (e.g., `CheckedContinuation` resumed inside the spy closure, or `waitForState`-style retry loop) means CI under load could see flakiness — particularly under `-O` Research builds or on contention-heavy Xcode-cloud agents.

The project's existing `waitForState` helper in `PitchDiscriminationTestHelpers.swift` is the canonical pattern: yield-in-a-loop with a max retry budget and an early-exit on observable state change. The Story 85.8 audio-observer tests don't have a directly-equivalent state-change API to poll, but a `CheckedContinuation`-based pattern would replace the blanket sleep.

**Fix:** For each Story 85.8 timing-based test, replace `Task.sleep(50ms)` with either: (a) a `CheckedContinuation` resumed by the spy closure (cleanest for closure-based assertions like the Lost/Reset/Reset-after-Lost tests); (b) a `waitForState`-style polling helper that checks the assertion target up to a max-budget timeout; (c) for engine tests, expose a counter the test polls until incremented. Acceptable to keep as-is for the foreseeable future — flakiness has not been observed locally — but a follow-up cleanup pass when extending Story 85.8 coverage should adopt the better pattern.


### PF-070: `check-dependencies.sh` matches feature names inside comments

**Found:** 2026-06-12 (Story 86.1 pre-commit gate)
**Severity:** Low (false-positive noise; does not affect compiled correctness)
**Disposition:** OPEN

`bin/check-dependencies.sh` reports `TimingOffsetDetection/ references SettingsScreen (cross-feature dependency)` from a documentation comment in `Peach/Training/TimingOffsetDetection/TimingDotView.swift:214` ("slot picker in `SettingsScreen`"). The reference is text inside a `///` doc comment — there is no actual code dependency between `TimingDotView` and `SettingsScreen`. The script's regex matches any occurrence of a feature-directory name in another feature's source files without skipping comments or string literals.

This is the first cross-feature warning since Story 85.7 introduced the comment. The check has been silently allowing pre-existing-on-main runs to "pass" anyway because the violation count was zero — re-reading the script confirms its exit is non-zero only when violations are *introduced*. Story 86.1's full-gate run surfaced it.

**Fix:** Either (a) strip Swift comments (`// …` / `/// …` / `/* … */`) before running the cross-feature regex; (b) restrict the regex to import statements and identifier references (e.g. require a leading `.` or word boundary against a typed name); or (c) re-word the `TimingDotView` comment to avoid naming `SettingsScreen` (workaround, not a fix to the script). Recommendation: (a) — the script is the right place to handle the syntax-vs-comment distinction. Until then, this is a low-noise false positive.



### PF-071: No integration test for `setupDataStore`'s wipe-then-retry path

**Found:** 2026-06-16 (spec-fix-overbroad-data-store-wipe step-04 review — Blind Hunter)
**Severity:** Low
**Disposition:** OPEN

`PeachAppDataStoreClassifierTests` exercises the `shouldWipeStore(after:)` classifier in isolation; the full `setupDataStore` code path (initial `ModelContainer.init` failure → classifier check → `wipeDefaultStoreFiles` → second `ModelContainer.init` → final outcome) has no test. The classifier covers the decision logic correctly, so most of the risk is captured, but the integration story — including the second-init-also-fails branch and the new "wipe failed, rethrow original error" branch added during this same review — is verified only by code reading.

The wipe path is a startup-only code path that's triggered at most once per major schema bump (story 77.4 was the only such bump on record). The wipe-then-retry orchestration was the same shape both before and after this fix; this story narrowed only the classification. Test coverage is nice-to-have, not load-bearing.

**Fix:** Refactor `setupDataStore` to accept a `ModelContainerFactory` seam — a protocol with one `make(schema:migrationPlan:) throws -> ModelContainer` method — that production satisfies with the real `ModelContainer.init` and tests satisfy with a stub that injects per-call outcomes (first-call throws X, second-call throws Y, second-call succeeds, etc.). Then add tests for the four branches: success-first-try; wipe-then-success; wipe-fails-rethrows-original; second-init-fails-rethrows-second. Defer until SwiftData adds a new schema migration that exercises the path — at that point the testing investment pays off.


### PF-072: Pre-existing `privacy: .public` convention on `error.localizedDescription`

**Found:** 2026-06-16 (spec-fix-overbroad-data-store-wipe step-04 review — Edge Case Hunter + Blind Hunter)
**Severity:** Low (sysdiagnose / unified-log exposure, not network or persistent storage)
**Disposition:** OPEN

`PeachApp.setupDataStore` and other startup error paths emit `error.localizedDescription` with `privacy: .public`. For `CocoaError` / `SwiftDataError` instances surfaced from the file system, `localizedDescription` can include the on-disk store path, which on iOS includes the app container UUID and on macOS includes the user's home directory and account short name. Both end up in unified log and sysdiagnose bundles unredacted. This story propagated the pattern (the original line was already `.public`) rather than introducing it.

**Fix:** Audit all startup-error logger sites for `error.localizedDescription, privacy: .public` and decide a project-wide convention — likely `privacy: .private(mask: .hash)` for `localizedDescription` and `.public` for the error type's domain + code (which is the actionable triage info anyway). Single-file changes are not enough; the convention belongs in a CLAUDE.md / project-context.md note so future logger sites follow it.


### PF-073: No telemetry / no backup on the destructive `wipeDefaultStoreFiles` path

**Found:** 2026-06-16 (spec-fix-overbroad-data-store-wipe step-04 review — Blind Hunter)
**Severity:** Low (the failure mode requires a real schema-incompatible store on disk — rare per major version bump — and the path is already narrower than it was)
**Disposition:** OPEN

When `setupDataStore` decides to wipe the on-disk store, it does so silently — one `logger.error` line and then `FileManager.removeItem` for `default.store{,-shm,-wal}`. No `os_signpost` for crash triage, no analytic event, no "we destroyed N rows" telemetry, no first-run flag the user can inspect on next launch, no backup of the about-to-be-deleted files to `~/tmp` for forensic recovery in TestFlight. For an explicitly destructive action this is thin.

Peach has no analytics infrastructure today and adding one is out of scope for an isolated bugfix. The story narrowed the wipe surface so the destructive path fires only on actual schema mismatches; the previous "wipe on anything" surface had the same telemetry gap with a much wider blast radius, so this is strictly an improvement.

**Fix:** When telemetry / signpost infrastructure lands — or whenever the project decides on a structured-event pipeline — add a single event at the wipe site recording: pre-wipe file sizes, the classifying error's domain + code, and the post-wipe init outcome. Optionally: copy the three files to `temporaryDirectory/peach-wipe-{ISO8601}/` before removal so a developer can recover them from a sysdiagnose bundle. Both are nice-to-have. Acceptable to leave indefinitely — the failure mode is rare and self-recovering.


### PF-075: macOS Help + Settings windows coexist — closing Settings resumes audio while Help is still open

**Found:** 2026-06-22 (spec-macos-stop-playback-on-settings-open step-04 review — Edge Case Hunter)
**Severity:** Low (transient audio behind a non-modal Help window; self-corrects when it is dismissed)
**Disposition:** RESOLVED — fixed in spec-pf-075-macos-window-coordination (2026-06-23)

Correction to the original premise: on macOS, Help is **not** a sheet on the training window. It is a standalone, **non-modal** `NSWindow` managed by the `HelpPanelController` singleton (`HelpPanel.swift`); only iOS presents Help as a `.sheet`. So the user can have the training window, a separate Settings `Window`, and a separate Help window all open at once.

Root cause: "training is suspended" had two independent, divergent mechanisms — `pausedDestination` for Help, and `currentTrainingDestination`-keying for Settings — so closing one window reconciled/resumed the session even while the other still wanted it quiet. Two adjacent defects shared the cause: (a) the training surface stayed clickable while suspended, so a Timing Offset Detection answer-click resumed audio behind the open Settings window; (b) closing Settings resumed audio while the Help window was still open.

**Fix (shipped):** `TrainingLifecycleCoordinator` now models foreground suspension as a multi-owner reason set (`.settingsWindow`, `.helpWindow`); the session pauses on the first reason and only reconciles once the last reason clears, independent of open/close order. An observable `isForegroundSuspended` drives a macOS-only `trainingSuspendedGate()` that makes the training surface non-interactive while suspended. Help opened from the training screen now follows the current discipline (`HelpPanelController.updateIfShowingTrainingHelp`). iOS behavior is unchanged (it never adds the `.settingsWindow` reason and its Help sheet already covers the surface).


### PF-080: Chromatic Construction production paradigm fights pitch-memory interference

**Found:** 2026-07-13 (code reading & design chat, `../code_reading_chat_2026-07-13.md` — file lives one level above the repo)
**Severity:** Medium (paradigm-level; discipline is research-gated, so no user impact)
**Disposition:** OPEN

Michael's diagnosis from living with the Epic 86 cut: the paradigm doesn't work — the continuously-sounding adjusted tone overwrites the memory of the previous one. This matches Deutsch's pitch-memory interference findings: memory for a tone is disrupted by subsequent tones, maximally when they're within about a semitone — and the adjusted tone lives inside that band while the remembered tone's trace decays. Not fixable by UI polish; the fix space is the audio scaffold and the response mode. The discipline's ET-only stance and the anti-motor-cheat countermeasures (per-slot random `audibleOffsets`) were confirmed sound.

**Fix:** Two directions adopted in the chat, to be promoted to an epic when picked up: (1) **perception before production** as the starting approach — a TOD-shaped variant: play a chromatic run from the anchor with uniform seeded per-step drift ±x cents, two buttons sharp/flat, Kazez on x (kept per-step so difficulty doesn't scale with step count), profile warm start, statistics keyed by (span bucket, Direction) mirroring TOD's (TempoRange, Direction) — shippable day one, and it dissolves the direction doc's open vector-shaped-profile question by yielding a scalar per trial; a later variant: single-wrong-step with "tap the offending dot" reusing `ChromaticContourView`. (2) **Alternation scaffold** as a per-discipline configuration option for the production variant (and generalizable to pitch matching): predecessor (~400 ms) → gap → candidate (~400 ms) → gap loop, re-pitching the candidate each cycle; slider changes apply on the next repetition; a reference-scaffold difficulty axis (alternating → single hearing + sustained candidate), unstratified knob per the note-gap precedent. Production stays a research-gated playground meanwhile; drone-under-the-walk was considered and rejected (changes the trained skill, reintroduces consonance landmarks).

### PF-081: Five training screens duplicate ~150 lines of scaffolding each

**Found:** 2026-07-13 (code reading, `../code_reading_chat_2026-07-13.md`)
**Severity:** Low (duplication; no behavioural defect)
**Disposition:** OPEN

Each training screen re-implements the same scaffolding — stats header, size-class branching, key handlers, `.trainingScreen` wiring — roughly 150 lines per screen across five screens. `TrainingDisciplineUI` could host a generic training screen that disciplines parameterize.

**Fix:** Extract a generic training-screen host into the `TrainingDisciplineUI` plugin surface. The natural moment is the next discipline addition ("the sixth discipline"), when the generic host pays for itself immediately — e.g., the perception-variant discipline sketched in PF-080. Not worth a standalone refactor story before then.

---

## Deferred from: code review of story 83.1 (2026-08-07)

### PF-082: Architecture and glossary docs still describe a four-discipline app

**Found:** 2026-08-07 (Story 83.1 code review — Blind Hunter)
**Severity:** Low
**Disposition:** OPEN

`docs/planning-artifacts/architecture.md:1570` and `:1585` describe `ProgressTimeline` as tracking "all four disciplines"; the shipping set has been five since story 82.8 lifted the Timing Offset Detection gate. `docs/planning-artifacts/glossary.md:16` additionally advertises user-facing discipline names — "Hear & Compare", "Tune & Match" — that no longer exist anywhere in the UI. Story 83.1 swept *user-facing* copy only; these are internal docs outside that scope, but they are now actively misleading to any agent that loads them as context.

**Fix:** Update the two `architecture.md` counts to reflect the registry-driven set (prefer wording that does not hard-code a count, since the set is build-configuration dependent), and replace the obsolete names in `glossary.md` with the current `displayName` values from each discipline's config.

### PF-083: `PEACH_RESEARCH` prose omits Chromatic Construction across four files

**Found:** 2026-08-07 (Story 83.1 code review — Blind Hunter + Edge Case Hunter)
**Severity:** Low
**Disposition:** OPEN

Multiple doc comments and docs state that the Research configurations "additionally register Continuous Rhythm Matching", naming one discipline. `DisciplineBootstrap.allDisciplines` has appended `ChromaticConstructionDiscipline()` inside the same `#if PEACH_RESEARCH` block since epic 86, so the gated set has two members. Known instances: `Peach/App/Training/DisciplineBootstrap.swift:14-25`, `docs/project-context.md:265`, `docs/arc42.md:703` and `:1009`, `docs/planning-artifacts/glossary.md:16`. The instance inside `PeachTests/Core/Training/TrainingDisciplineRegistryTests.swift:11-15` is fixed by story 83.1 itself, since that file was touched.

**Fix:** Sweep the listed instances to name both gated disciplines, or reword to avoid enumerating them (e.g. "the research-only disciplines") so the prose stops needing maintenance each time one is added.

### PF-084: Historical epic ACs assert a four-discipline release

**Found:** 2026-08-07 (Story 83.1 code review — Blind Hunter)
**Severity:** Low
**Disposition:** OPEN

`docs/planning-artifacts/epics.md:7693` (story 76.4, AC 9) asserts that in a `Release` build "four disciplines are registered, only Pitch and Intervals categories appear in StartScreen/PeachCommands/Profile/Help, and no rhythm-discipline UI is reachable". AC 5 and AC 10 of the same story are stale on the same axis. These were true when written and story 82.8 superseded them. Because `epics.md` is the declared source of truth for epic and story content, an agent reading it today gets a contradiction with the shipping build.

**Fix:** Do not rewrite historical acceptance criteria — they are the record of what was accepted at the time. Add a `**Status:**`/`**Superseded:**` line to story 76.4 pointing at story 82.8, matching the Status-line convention already used on epics 80/81/84/85.

### PF-085: In-app help copy says the user "decides" the fact rather than judging it

**Found:** 2026-08-07 (Story 83.1 code review — Michael's copy note during triage)
**Severity:** Low
**Disposition:** OPEN

Peach's disciplines ask the user to report a *perception*; the app already knows the ground truth. "Decide" frames the user as determining the fact ("you decide which is higher"), when what they actually do is judge, or more precisely utter an impression. Story 83.1 corrected this in the App Store description and App Review Notes; the in-app help strings still carry it.

Instances (all in `Peach/Resources/Localizable.xcstrings`, each with a German `entscheiden` mirror):
- `Hear a short rhythmic pattern and decide whether the tested note was early or late.` (TOD `helpDescription`)
- `Listen to two notes and decide which one is higher.` (Compare Pitch `helpDescription`)
- `You still decide which note is higher — but now you're training your sense of musical distance.` (interval help)
- `Your job is to decide: was the second note higher or lower than the first?` (Compare Pitch help)
- `Your job is to decide which it was.` (TOD help)

Explicitly **not** in scope: uses meaning "once you have made up your mind", which are correct as written — e.g. `Tap Early or Late as soon as you decide`, `Bei ∞ wiederholt sich das Pattern, bis du dich entscheidest`.

Not folded into story 83.1: those strings live in files the story never touched, and its frozen *Never* clause forbids new copy beyond TOD. Deliberately deferred rather than expanding a release-copy sweep into an app-wide verb sweep.

**Fix:** Replace fact-determining "decide" with "judge" (DE: `beurteilen`) across the five strings above plus their German values, leaving the made-up-your-mind uses alone. Note that changing an English value rewrites the xcstrings *key*, so each edit is a key+value rewrite; run `bin/add-localization.swift --missing` afterwards.

---

## Deferred from: story 83.4 (2026-08-08)

### PF-086: `bin/test.sh`'s pass count is a line-count heuristic, but stories cite it as an exact regression signal

**Found:** 2026-08-08 (Story 83.4 — gate run after enabling Enhanced Security)
**Severity:** Medium *(raised from Low during code review of `a0afbe7d`: the entry's own text states that a genuine one-test regression is indistinguishable from this noise, in the pre-commit gate every story in the project relies on — that is not a Low-severity property.)*
**Disposition:** OPEN

`bin/test.sh:187` derives its reported figure with `grep -cE "(Test .* passed|✔ Test|passed on)"` over the raw xcodebuild output. That regex counts **lines**, not distinct tests, and matches at least three different shapes: per-test `✔ Test "…" passed` lines, `✔ Suite "…" passed` lines, and Swift Testing's own run-summary line `✔ Test run with N tests passed …` (which matches `Test .* passed`). The `passed on` alternative adds another.

Observed: two consecutive `bin/test.sh --research -p mac` runs on an unchanged working tree reported **2424** and then **2425**, both "ALL TESTS PASSED". No test failed in either run; the delta is one matching line, not one missing test.

Why this matters: sprint-status entries and story records treat these numbers as exact and reason from small deltas — story 83.1's record states "iOS Research 2438 / macOS Research 2425 / iOS Debug 2275 / macOS Debug 2262 (**+1 in the non-Research schemes only**, matching the new guard's build gating)". That inference happened to be right, but the metric cannot support ±1 reasoning, and a genuine one-test regression is indistinguishable from this noise. It also cost a real investigation during story 83.4 before the cause was identified.

**Fix:** Count distinct tests rather than matching lines. Either (a) restrict the regex to the per-test shape only (`✔ Test "` for Swift Testing plus the XCTest `Test Case '…' passed` form) and drop the `passed on` and suite-level alternatives; or (b) preferably, parse Swift Testing's run-summary line and report the `N` it states, which is authoritative — `bin/parse-xcresult.py` already exists and may be the better home. Until then, do not draw conclusions from ±1 differences in recorded counts.

---

## Deferred from: code review of 83-4-enhanced-security-hardening (2026-08-08)

### PF-087: The Enhanced Security configuration has no regression guard, and a fifth build configuration would silently reverse it

**Found:** 2026-08-08 (code review of story 83.4, commit `a0afbe7d`)
**Severity:** Medium
**Disposition:** OPEN

The entire hardening this project now relies on is eight lines in `Peach.xcodeproj/project.pbxproj`: `ENABLE_ENHANCED_SECURITY = YES` ×4 (project level) and `CODE_SIGN_ENTITLEMENTS = Peach/Resources/Peach.entitlements` ×4 (app target), plus `ENABLE_POINTER_AUTHENTICATION = NO` ×4 as the deliberate arm64e opt-out.

Two failure modes, neither observable by any existing check:

1. **Silent removal.** Any edit through Xcode's *Signing & Capabilities* pane can drop the capability or rewrite the entitlements wiring. `bin/test.sh`, `bin/build.sh` and `bin/pre-commit` would all stay green — the app builds and every test passes without any of these settings, which is precisely how the gap survived from project creation through the 1.0.0 release.

2. **Asymmetric inheritance on growth.** `ENABLE_ENHANCED_SECURITY` is set once per configuration at *project* level and therefore inherits into any newly added configuration automatically, while its counter-setting `ENABLE_POINTER_AUTHENTICATION = NO` is duplicated four times at *target* level and would not. A fifth configuration would silently build arm64e — reversing story 83.4's central decision, taken specifically because App Store acceptance of arm64e could not be established. The project has grown its configuration set before (`Debug (Research)` / `Release (Research)`), so this is a realized pattern, not a hypothetical. There are no `.xcconfig` files to centralize the pairing.

Story 83.4's *Never* block forbids source changes, so the guard could not land in that story.

**Fix:** Wire the three `grep -c` checks the story already wrote (`83-4-enhanced-security-hardening.md:156-158`) into `bin/pre-commit` or `bin/check-dependencies.sh`. Assert *consistency* rather than the literal count `4` — the count must equal the number of project configurations, and every app-target configuration carrying `ENABLE_ENHANCED_SECURITY` inheritance must also carry an explicit `ENABLE_POINTER_AUTHENTICATION` value — so that adding a configuration fails the check instead of passing it silently.

### PF-088: Pitch profile headlines render without a unit while the rhythm headline hardcodes one

**Found:** 2026-08-08 (code review of story 83.5; description corrected the same day after checking the running app)
**Severity:** Medium
**Disposition:** OPEN

Two different treatments of the same headline figure:

- `Peach/Profile/ProgressChartView.swift:72-77` renders `Text(ChartData.formatEWMA(ewma))` and `Text(ChartData.formatStdDev(stddev))` with **no unit**; `Peach/Profile/ExportChartView.swift:52-54` likewise. The unit appears only on the Y-axis label. The four pitch disciplines use this card, so their headlines read `11.5` and `±0.0`.
- `Peach/Training/ContinuousRhythmMatching/Profile/RhythmProfileCardView.swift:133-139` renders `79.5 ms` and `±7.1 ms` via its own `formatRhythmEWMA`/`formatRhythmStdDev`, which **hardcode the unit** rather than reading `config.unitSymbol`.

Verified in a running build: the Profile screen shows `Compare Pitch  11.5  ±0.0` above `Compare Timing  79.5 ms  ±7.1 ms`. An earlier draft of this entry claimed the timing headline lacked a unit — that was wrong; the pitch headlines are the ones missing it.

Story 83.5 left both alone: `ProgressChartView` was outside its Start-screen scope, and `RhythmProfileCardView` is a discipline-specific view, which the story's narrowed "no *shared* view hardcodes a unit" constraint permits.

**Fix:** Give the pitch headline its unit from `config.unitSymbol`, matching the rhythm card's treatment, and have the rhythm card read `config.unitSymbol` instead of a literal so the two cannot drift.

### PF-089: Chart-annotation accessibility strings have no plural rule

**Found:** 2026-08-08 (code review of story 83.5)
**Severity:** Low
**Disposition:** OPEN

`Peach/Core/Profile/ChartData.swift:287` produces `"… , %lld data points"` with no plural variation in `Localizable.xcstrings`, so a single-point zone is announced as "1 data points" (German: "1 Datenpunkte"). Pre-existing — the superseded `"… pitch trend …"` keys had no `variations` block either, so story 83.5's rewording neither introduced nor worsened this.

**Fix:** Add a `variations.plural` block (`one` / `other`) for the `%lld` argument on both the single-bucket and range variants, in both locales.

### PF-090: Imported metric values have no magnitude bound

**Found:** 2026-08-08 (code review of story 83.5)
**Severity:** Low
**Disposition:** OPEN

CSV import parsers guard `.isFinite`, so NaN and infinity cannot reach the profile, but no upper magnitude bound is enforced. A crafted or corrupt row carrying e.g. `1e308` formats through `MetricValueFormatter` into a ~310-character grouped string, which would break Start-screen card and chart layout.

Not reachable from normal use — every `MetricPoint` value is produced by the app's own trial code. This is an import-validation gap, not a formatting one.

**Fix:** Bound metric magnitudes at import time to a domain-plausible ceiling (cents and milliseconds both sit far below 10 000), rejecting or clamping out-of-range rows with a logged warning.

### PF-093: The rhythm profile card formats numbers without locale awareness

**Found:** 2026-08-08 (code review of story 83.5)
**Severity:** Medium
**Disposition:** OPEN

`Peach/Training/ContinuousRhythmMatching/Profile/RhythmProfileCardView.swift:133-139` formats via `String(format: "%.1f", value)`, which always emits a period as the decimal separator regardless of locale:

```swift
static func formatRhythmEWMA(_ value: Double) -> String { "\(String(format: "%.1f", value)) ms" }
static func formatRhythmStdDev(_ value: Double) -> String { "±\(String(format: "%.1f", value)) ms" }
```

Every other metric surface goes through `MetricValueFormatter`, which is locale-aware. Consequence for a German user: the Start card reads `79,5 ms` and the Profile card directly below reads `79.5 ms` — two separators for the same quantity on adjacent screens.

Note `String(format:)` is the *fallback* inside `MetricValueFormatter`, reached only if `NumberFormatter` returns nil; here it is the primary path.

**Fix:** Route both helpers through `MetricValueFormatter.format(_:)` and take the unit from `config.unitSymbol` (see PF-088).

