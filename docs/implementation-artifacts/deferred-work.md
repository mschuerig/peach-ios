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

### PF-020: Voice Control "Tap C3" lost under marker `.accessibilityRepresentation`

**Found:** 2026-06-03 (Story 81.3)
**Severity:** Medium (Voice Control regression on the non-AX1 path)
**Disposition:** OPEN

Spec Always rule line 30 wanted per-key `MIDINote.name` labels addressable by Voice Control ("Tap C3" works) alongside the two-marker adjustable representation for VoiceOver / Switch Control. `.accessibilityRepresentation` replaces the entire accessibility subtree, so Voice Control sees only the two Sliders. The two goals are mutually exclusive in a single SwiftUI configuration without a different mechanism.

**Fix:** Restructure the accessibility tree so per-key Voice Control addressing works on the non-AX1 path as well (e.g., `.accessibilityCustomActions` plus markers as adjustable elements without `.accessibilityRepresentation`). Future story.

### PF-036: `patternRowAccessibilityLabel` and SwiftUI `.accessibilityElement(children: .combine)` are two independent label paths

**Found:** 2026-06-05 (Story 84.3)
**Severity:** Low (latent test/UI drift)
**Disposition:** OPEN

In `TimingOffsetDetectionPatternPickerSettingsSection`, the static helper is pinned by unit tests; the runtime label is what VoiceOver actually reads after `.combine` joins the `TimingDotView` per-cell labels. Today both produce the same comma-joined string. If the per-cell label format changes in the renderer without a parallel update to the static helper (or vice versa), tests pass against the helper while VoiceOver reads different text.

**Fix:** Resolution candidates: (a) add a UI test that exercises the rendered VoiceOver label and pins it to `patternRowAccessibilityLabel`; (b) collapse the two paths by computing the row label exclusively from `.combine` and removing the static helper; (c) document the relationship inline.

### PF-040: Sectioned `Picker` shared-binding rendering on cross-section selection transitions is unverified

**Found:** 2026-06-05 (Story 84.4 review)
**Severity:** Low (no current bug observed; surface for explicit visual check)
**Disposition:** OPEN

`TimingOffsetDetectionPatternPickerDestination.body` (Story 84.4) renders five sibling inline `Picker`s, each iterating its own `section.patternIds`, all sharing the same `patternIdBinding`. SwiftUI's inline-Picker selection-indicator behaviour with one binding shared across multiple `Picker` views (each containing a disjoint tag set) is not documented as a guaranteed contract — every section's `Picker` may render no selection indicator until its bucket's row matches the current id, which is the intended behaviour but may surface visual quirks at section transitions (e.g. a brief no-checkmark frame during a cross-section selection animation).

**Fix:** Resolution candidates: (a) add an integration / snapshot test asserting exactly one row in the visible drill-down carries the selection indicator at steady state; (b) collapse to one outer `Picker` wrapping all five sections (loses the per-section visual grouping the design doc requires); (c) leave to manual visual inspection per 84.4's "Visual check" task.

### PF-041: AX1 no-truncation invariant for picker section headers has no snapshot test

**Found:** 2026-06-05 (Story 84.4 review)
**Severity:** Low
**Disposition:** OPEN

`tod-tuplet-renderer-design.md` § *Categorization* "Section header behavior at AX1" locks SwiftUI default wrapping (no `.lineLimit(1)` / `.truncationMode`) and explicitly says "the 84.4 a11y test captures a screenshot at AX1 to confirm no truncation." 84.4 ships without a snapshot/UI test asserting that the longest German header (`Lückenhafte Sechzehntel`, 23 chars) wraps to two lines instead of truncating at AX1 — only manual visual inspection per the spec's "Visual check" task. A future contributor adding `.lineLimit(1)` to the picker section header could break the invariant silently.

**Fix:** Resolution candidates: (a) wire snapshot-testing infrastructure (e.g. swift-snapshot-testing) and add an AX1 screenshot test for the picker destination; (b) extract header rendering into a thin view function with a static `lineLimit` accessor that a unit test can pin to `nil`; (c) accept manual visual inspection as the verification surface and document the invariant in the section's doc comment.

### PF-046: `.navigationDestination(isPresented:)` inside `Form` triggers SwiftUI lazy-container warning

**Found:** 2026-06-05 (Story 84.4 iteration 3 visual verification on iOS Simulator)
**Severity:** Medium (Apple warns "It will be ignored in a future release")
**Disposition:** OPEN

`TimingOffsetDetectionPatternPickerSettingsSection.body` attaches `.navigationDestination(isPresented: $isShowingDestination)` to a `Button` inside a `Section`. The Section is part of a parent `Form` (assembled by `DisciplineSettingsSection.aggregated`), which SwiftUI implements as a lazy `List` underneath. iOS logs: "Do not put a navigation destination modifier inside a 'lazy' container, like `List` or `LazyVStack`. ... It will be ignored in a future release." The current iOS keeps the destination wired, but a future release will silently break the drill-down.

The architecture creating this conflict was iteration-2 of 84.3: the iteration-2 fix replaced `NavigationLink` (which renders the system chevron) with `Button` + `.navigationDestination(isPresented:)` so a custom chevron view (`TimingDotView.patternRowChevron`) could be rendered on both the *Pattern* row and the *Offset Note Position* row at identical widths, restoring dot alignment between them. Reverting to `NavigationLink` re-introduces the chevron-alignment problem (Michael called it "completely unusable" in iteration-2).

**Fix options (none chosen yet):**
- **(a)** Hoist the `.navigationDestination(isPresented:)` modifier to `SettingsScreen.body`'s `Form` (outside the lazy container). Requires extending `DisciplineSettingsSection` to declare navigation contributions a parent screen can collect and attach. Cross-cutting architectural change touching `App/Training/`.
- **(b)** Switch picker row back to `NavigationLink`. Reverts the iteration-2 fix; reintroduces chevron-alignment misery. Not acceptable per iteration-2 history.
- **(c)** Restructure the picker drill-down so the Pattern picker destination also hosts the *Offset Note Position* selector (one drill-down screen containing both controls instead of two adjacent inline rows). The settings screen then shows only the *Pattern* row (drill-in to edit both). UX change worth its own design discussion.

**Constraints:**
- Iteration-2 chevron-alignment fix (`TimingDotView.patternRowChevron` rendered identically on both rows) must be preserved or replaced by an equivalent guarantee.
- The picker's selection cascade through `patternIdBinding` (writing both `selectedPatternId` and `offsetNotePosition` atomically) must be preserved.

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
