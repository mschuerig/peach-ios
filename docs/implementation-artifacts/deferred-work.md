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

### PF-023: AX1+ Slider partner-imposed range shifts during edit

**Found:** 2026-06-03 (Story 81.3)
**Severity:** Low
**Disposition:** WONT-FIX (standard SwiftUI behavior for range-pair Sliders)

When the user moves one bound's Slider in `NoteRangeSelector`'s AX1+ accessibility path, the partner's legal range narrows synchronously. VoiceOver may announce the partner Slider's max changing under it. Standard behaviour for range-pair Sliders; acceptable for first cut but a UX polish item.

**Fix:** No fix planned. Revisit if a user reports the announcement is disruptive.

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

---

## OPEN — Needs Architectural Decision

### PF-001: Redundant Session Stop via Background Notification on macOS

**Found:** 2026-03-29 (Story 68.6)
**Severity:** Low (cosmetic log noise, no correctness impact)
**Disposition:** OPEN

On macOS, each session's `AudioSessionInterruptionMonitor` independently listens for `NSApplication.didResignActiveNotification` and calls `stop()`. The `TrainingLifecycleCoordinator` also stops the current session via `handleAppDeactivated()`. This results in 4× redundant "stop() called but already idle" log messages on every app switch.

**Fix:** Stop passing `backgroundNotificationName` to sessions on macOS, since the coordinator now owns the training lifecycle. The notification-based stop in sessions was the original mechanism before the coordinator existed.

### PF-002: PeachApp Initialized Twice on macOS

**Found:** 2026-03-29 (Story 68.6)
**Severity:** Medium (wasteful startup — double ModelContainer, AudioEngine, etc.)
**Disposition:** OPEN

On macOS, SwiftUI initializes the `@main App` struct twice before one instance is used. This creates duplicate `PerceptualProfile`, `SoundFontEngine`, sessions, and other heavyweight objects. Visible in logs as 2× "PerceptualProfile initialized (cold start)".

**Fix:** Move heavyweight initialization out of `PeachApp.init()` into a lazily-created shared container, or use `@State` with a factory that guards against double init. This is a known SwiftUI macOS behavior.

### PF-003: Training Session Restart on In-Stack Navigation to Settings/Profile

**Found:** 2026-04-07 (Story 75.3)
**Severity:** Medium (session progress lost on navigation round-trip)
**Disposition:** OPEN

When the user taps Settings or Profile in the training screen toolbar, SwiftUI's NavigationStack fires `onDisappear` on the training screen, which calls `lifecycle.trainingScreenDisappeared()` → `stopCurrentSession()` → `session.stop()`. The `stop()` method fully clears session state (`sessionBestCentDifference`, `currentTrial`, `lastResult` — all nilled). When the user navigates back, `onAppear` fires and `startCurrentSession()` restarts training from scratch, losing all in-session progress.

**Fix:** Introduce pause/resume semantics distinct from stop/start. Either add `pause()`/`resume()` to the `TrainingSession` protocol, or have the lifecycle coordinator distinguish between temporary pushes (Settings/Profile) and permanent pops (back to Start Screen). Requires multi-file change across the session protocol, all session implementations, and the lifecycle coordinator.

### PF-004: Flaky `navigateUsesEventDrivenIdle` test on macOS

**Found:** 2026-06-02 (Story 80.1)
**Severity:** Low (intermittent CI noise, no production impact)
**Disposition:** OPEN

`TrainingLifecycleCoordinatorTests.navigateUsesEventDrivenIdle()` fails intermittently on macOS Research builds. The test relies on a single `await Task.yield()` between `coordinator.navigate(to:)` and `mockSession.isIdle = true`. The navigationTask must reach `awaitIdle` and install its `withObservationTracking` observer before the test mutates `isIdle`; if the Task hasn't yet reached that point, the observation doesn't fire and `resolvedNavigation` stays `nil`. Single-yield is racy under macOS scheduling; the test passes on retry.

**Fix:** Replace the single `await Task.yield()` after `navigate(...)` with a bounded poll until `mockSession.stopCallCount > 0`, then another bounded poll after setting `isIdle = true` until `resolvedNavigation != nil`. Same pattern as the existing `waitUntilNotIdle` helper in this file.

### PF-005: Session leak on sound source change

**Found:** 2026-03-27 (MIDI pitch bend fix)
**Severity:** Medium (latent leak; user-triggerable but rarely-exercised path)
**Disposition:** OPEN

`onChange(of: soundSource)` in `PeachApp` replaces `pitchMatchingSession` and `pitchDiscriminationSession` without calling `stop()` on the old instances. If a session was active, its internal Tasks (MIDI listening, training loop) capture `self`, preventing deallocation. The old session's tasks run indefinitely until the AsyncStream finishes.

**Fix:** Call `stop()` before reassignment, or restructure sessions to replace their `NotePlayer` rather than being fully recreated.

### PF-007: CC#123 doesn't reset pitch bend/controllers

**Found:** 2026-04-25 (AVAudioUnitSampler thread crash fix)
**Severity:** Low (mitigated by explicit `sendPitchBend` before each `startNote`)
**Disposition:** OPEN

The old `auAudioUnit.reset()` reset all controller state including pitch bend. The replacement CC#123 (All Notes Off) only silences note-ons. If pitch bend was applied during playback and a new schedule starts, the bend could carry over. In practice mitigated because `sendPitchBend` is called explicitly before each `startNote`, but scheduled-only playback paths don't reset bend state.

**Fix:** Send an explicit pitch-bend-center CC before scheduled playback starts, or expose a controller-reset hook that scheduled paths can call.

### PF-008: `clearSchedule()` doesn't silence hanging notes

**Found:** 2026-04-25 (AVAudioUnitSampler thread crash fix)
**Severity:** Low (pre-existing behaviour; matches the old `.reset()` placement)
**Disposition:** OPEN

When `clearSchedule()` is called, no All-Notes-Off is sent. Notes whose note-on was dispatched but note-off hasn't been reached will ring indefinitely. The old `.reset()` was also only in `scheduleEvents()`, not `clearSchedule()`.

**Fix:** Send CC#123 (All Notes Off) inside `clearSchedule()` in addition to `scheduleEvents()`.

### PF-009: Rhythm spectrogram export temp file cleanup

**Found:** 2026-03-30 (Spectrogram sharing fix)
**Severity:** Low (cosmetic — temp dir grows until app restart)
**Disposition:** OPEN

`RhythmProfileCardView.renderShareImage()` writes PNGs to the temp directory on each re-render but doesn't track/delete previous renders, unlike `ChartImageRenderer.render()` which uses `lastRenderedURLs` for cleanup.

**Fix:** Unify both export paths through `ChartImageRenderer`, or replicate the `lastRenderedURLs` tracking in `RhythmProfileCardView`.

### PF-010: Rename `currentGapPosition` → `gapPositionInCurrentBeat`

**Found:** 2026-06-02 (Story 80.0)
**Severity:** Low (clarity-of-naming, low-risk pure rename)
**Disposition:** OPEN

On `ContinuousRhythmMatchingSession`, with the new `currentBeatPosition` also being `BeatPosition?`, both observable properties are typed identically and only their names disambiguate "where the playback head is" vs. "where the gap is in the current beat".

**Fix:** Rename the property and call sites in `ContinuousRhythmMatchingScreen`/`DotView` plus tests. Deferred only because the 80.0 spec scope was already wide.

### PF-011: Concurrency audit of the sequencer @Observable + Task pattern

**Found:** 2026-06-02 (Story 80.0; reinforced by 80.1, 80.2)
**Severity:** Medium (latent data-race surface; clean strict-concurrency build but unverified contract)
**Disposition:** OPEN

`BeatProvider` is not `Sendable`, `SoundFontBeatSequencer.currentBeat` is mutated from a background `Task`, and `ContinuousRhythmMatchingSession.gapPositions` is written from the sequencer's polling Task. The shape predates 80.0 and the Swift 6.2 strict-concurrency build is clean, but the Blind hunter + Edge case hunter flagged it as a latent data-race surface. Consolidates two cross-referenced concerns:

- *Sequencer cross-discipline serialization (Story 80.1):* with TOD and CRM both calling `beatSequencer.start(tempo:beatProvider:)` on the shared singleton, the lifecycle coordinator must ensure the previous session has fully stopped before the next starts. Today the coordinator already serializes activations, but no test pins this contract at the coordinator level.
- *Stale `samplePosition` at new-trial start (Story 80.2):* between `beatSequencer.start(...)` returning and the render thread resetting `engine.currentSamplePosition` to 0, the polling task may sample a stale large value. With `maxRepetitions == 1` and an unlucky 8 ms tick at the boundary, `completedCycles` could already meet the cap before any audio is heard, immediately triggering `.repetitionCapReached`.

**Fix:** Focused audit (probably via `/swift-concurrency-expert`) before any second discipline starts sharing a sequencer instance. Resolution candidates for the trial-start race: (a) document the post-`start()` reset latency as a `BeatSequencer` contract with a test; (b) anchor TOD's `globalSubdivisionIndex` to a per-trial baseline `samplePosition` captured at start; (c) extend `BeatSequencer.timing` with a "trial-relative sample position" accessor.

### PF-012: CRM refill state-reset on `samplePosition` wrap

**Found:** 2026-06-02 (Story 80.0)
**Severity:** Low (unreachable in current play; refill happens at ~25 trials in, trials never span a refill boundary)
**Disposition:** OPEN

`ContinuousRhythmMatchingSession.lastEvaluatedCycleIndex` (and the new `lastPublishedCycleIndex`/`lastPublishedSubdivisionIndex`) are not reset when the sequencer refills its batch and resets `samplePosition` to 0. The latent state-mismatch means `cycleMissed` would stop firing if it ever did.

**Fix:** Reset the published-index trackers on observed negative jump in `samplePosition`. Surfaced incidentally by Edge case hunter (finding #15).

### PF-013: Protocol-level contract tests for `SequencerEngine`

**Found:** 2026-06-02 (Story 80.0)
**Severity:** Low (predates 80.0; same gap existed for `StepSequencerEngine`)
**Disposition:** OPEN

No tests verify that `SoundFontEngine`'s `SequencerEngine` conformance matches the contract exercised by `MockSequencerEngine`. The two could silently diverge (e.g., what `clearSchedule()` does mid-render).

**Fix:** Add a conformance test suite that runs both implementations through the same set of invariants (start/stop ordering, post-clear silence, sample-position reset semantics).

### PF-014: Signed-offset bounds validation in `Beat.events`

**Found:** 2026-06-02 (Story 80.0)
**Severity:** Low (no production user supplies negative offsets today)
**Disposition:** OPEN

A `.note(offset: .milliseconds(-N))` on a beat's first subdivision can produce a negative `sampleOffset`, which the audio scheduler doesn't handle. Story 80.1 (TimingOffsetDetection on `BeatProvider`) will introduce signed offsets.

**Fix:** Add a bounds-check or precondition in `Beat.events`, or document that the caller is responsible for keeping offsets in-range. Decide as part of the next story to introduce signed-offset patterns.

### PF-015: Deep-nesting safety in `Beat.events`

**Found:** 2026-06-02 (Story 80.0)
**Severity:** Low (not reachable from any production discipline)
**Disposition:** OPEN

`subdivisionDuration = beatDuration / Int64(subdivisions.count)` can truncate to 0 when subdivisions are many and beatDuration is small (or after several layers of recursion). The current code would then stack all notes at `baseOffset`.

**Fix:** Add a precondition or saturating-floor guard. Flag for the first nested-tuplet discipline.

### PF-016: `refillThreshold` uniform-tempo assumption

**Found:** 2026-06-02 (Story 80.0)
**Severity:** Low (no current discipline varies tempo mid-session)
**Disposition:** OPEN

`SoundFontBeatSequencer.refillThreshold` is computed from a single `samplesPerBeat` set once at start. Any future discipline that wants to vary tempo mid-session would mis-estimate refill timing.

**Fix:** Recompute `refillThreshold` on tempo change, or expose a tempo-change API that recomputes it as a side effect.

### PF-017: One-tick `litDotCount` blip at batch refill

**Found:** 2026-06-02 (Story 80.1)
**Severity:** Low (sub-perceptual, ~8 ms, self-correcting)
**Disposition:** OPEN

In `TimingOffsetDetectionSession.evaluatePlaybackPosition`: when `SoundFontBeatSequencer` refills (~every 500 beats), `engine.samplePosition` resets to 0. The session's `lastPublishedSubdivisionIndex` is high; modulo math may light a stale dot for one polling tick (8 ms) before resyncing.

**Fix:** On observed negative jump in `globalSubdivisionIndex`, reset `lastPublishedSubdivisionIndex = -1` before the equality gate.

### PF-018: `AppTimingOffsetDetectionUserSettings.maxRepetitions` should clamp `> cap` as well as `< 1`

**Found:** 2026-06-03 (Story 81.2)
**Severity:** Medium (theoretical crash path; requires corrupt UserDefaults or manual seeding)
**Disposition:** OPEN

The port currently clamps stored values `< 1` to `defaultMaxRepetitions` but lets arbitrarily large values (`Int.max`, a stale config from a future build, debugger writes) pass through unchanged. The new `DiscreteStopsSlider`'s `nearestStopIndex` computes `abs(stops[i] - value)` for each stop; with `value == Int.max` the arithmetic underflows and traps before any snap can happen.

**Fix:** Clamp above the cap to `defaultMaxRepetitions` at the storage-layer port, mirroring the existing below-floor clamp. Removes the trap surface from every future caller.

### PF-019: O(N²) `PianoKeyboardLayout` x-position lookups

**Found:** 2026-06-03 (Story 81.3)
**Severity:** Low (~465K ops/sec at 88 keys × 60 Hz drag — below perceptible-jank threshold)
**Disposition:** OPEN

`xPosition(forNote:)` is O(N) (filters `notes.prefix(while:)` for the white-key index), and `midiNote(at:)` calls it once per note (O(N²)).

**Fix:** Precomputed `[MIDINote: CGFloat]` cache or an O(1) white-key-index table. Required if a future caller renders a wider keyboard, animates per-key opacity at high frequency, or runs on a lower-performance device.

### PF-020: Voice Control "Tap C3" lost under marker `.accessibilityRepresentation`

**Found:** 2026-06-03 (Story 81.3)
**Severity:** Medium (Voice Control regression on the non-AX1 path)
**Disposition:** OPEN

Spec Always rule line 30 wanted per-key `MIDINote.name` labels addressable by Voice Control ("Tap C3" works) alongside the two-marker adjustable representation for VoiceOver / Switch Control. `.accessibilityRepresentation` replaces the entire accessibility subtree, so Voice Control sees only the two Sliders. The two goals are mutually exclusive in a single SwiftUI configuration without a different mechanism.

**Fix:** Restructure the accessibility tree so per-key Voice Control addressing works on the non-AX1 path as well (e.g., `.accessibilityCustomActions` plus markers as adjustable elements without `.accessibilityRepresentation`). Future story.

### PF-021: Auto-recenter scroll on bound change in `NoteRangeSelector`

**Found:** 2026-06-03 (Story 81.3)
**Severity:** Low
**Disposition:** OPEN

Scrolls to the midpoint between bounds only on first `.onAppear`. If the user drags a marker so far that it leaves the iPhone-portrait viewport, the marker stays off-screen.

**Fix:** Add `.onChange(of: focusedMarker)` and `.onChange(of: lowerBound + upperBound)` to call `scroll.scrollTo(activeBound, anchor: .center)`.

### PF-022: Audio preview debouncing for keyboard `.repeat` phases

**Found:** 2026-06-03 (Story 81.3)
**Severity:** Low (audibly muddy, not a correctness bug)
**Disposition:** OPEN

Holding ←/→ on macOS fires `onCommit` at the system key-repeat rate (~10 Hz). Each `playSoundPreview(note:duration: .milliseconds(400))` overlaps the previous. The sampler handles overlap gracefully but it's audibly muddy.

**Fix:** Serialize previews in `SettingsCoordinator` (cancel previous Task) or debounce at the call site.

### PF-024: Black-key vs white-key y-aware hit-test

**Found:** 2026-06-03 (Story 81.3)
**Severity:** Low
**Disposition:** OPEN

`PianoKeyboardLayout.midiNote(at:)` is x-only. A tap on the bottom (white-only) half of a column over a black key resolves to the black key, even though visually the user pressed the white-key portion below it.

**Fix:** Standard piano-UI behaviour requires y-coordinate awareness (top half: respect overlay; bottom half: white only).

### PF-025: `PianoKeyboardLayout` is main-actor-isolated; Core/Music style is `nonisolated`

**Found:** 2026-06-03 (Story 81.3)
**Severity:** Medium (architectural inconsistency; blocks `nonisolated` storage of `NoteRange`)
**Disposition:** OPEN

Spec Change Log records the trap — `NoteRange.Hashable` is main-actor-isolated, so storing `NoteRange` in a `nonisolated` value fails to compile.

**Fix:** Make `NoteRange` `nonisolated` (consistent with `MIDINote`) and then make `PianoKeyboardLayout` `nonisolated` too. Touches a widely-used domain type; deserves its own focused story rather than a Boy-Scout drive-by.

### PF-027: `SettingsCoordinator.playSoundPreview` swallows audio errors with `try?`

**Found:** 2026-06-03 (Story 81.3)
**Severity:** Low (pre-existing pattern in the coordinator)
**Disposition:** OPEN

Silent-failure mode means a broken preview is indistinguishable from a working one with the wrong sound font. The existing zero-arg variant has the same shape.

**Fix:** Add `os.Logger` warning on error consistently across both `playSoundPreview` overloads.

### PF-029: `TimingOffsetDetectionSettings` pair-invariant not enforced at the value-type boundary

**Found:** 2026-06-04 (Story 82.7)
**Severity:** Low (only mock/test paths construct directly today)
**Disposition:** OPEN

The settings struct's plain initializer accepts any `(OffsetNotePosition, TimingOffsetDetectionPattern)` pair; the `.from(userSettings:intervals:)` factory clamps, but a direct construction with `OffsetNotePosition(3)` and `.pattern1010` (pickable `{2}`) builds fine, then `nextBeat()` traps at runtime on the pattern's `beat(...)` precondition.

**Fix:** Resolution candidates: (a) add `precondition(pattern.pickable.contains(offsetNotePosition.rawValue))` at the settings init; (b) replace the init with a private one + factory that clamps; (c) make the settings struct carry only the pattern + a `clampedOffsetNotePosition` accessor (eliminate redundant Int storage).

### PF-030: `AppTimingOffsetDetectionUserSettings.selectedPattern` recomputes + logs on every access

**Found:** 2026-06-05 (Story 84.2)
**Severity:** Low (bounded log noise; clears on first user pick or canonicalization)
**Disposition:** OPEN

The computed property reads `defaults`, resolves via `pattern(forStoredId:)`, and `pattern(forStoredId:)` writes a warning when the id is unknown. There is no memoization and no one-shot log dedup. On dev devices after the 84.2 swap, every call site that reads `selectedPattern` while `selectedPatternId` still carries a retired id (`pattern_1111` etc.) emits a fresh "unknown pattern id" log line.

**Fix:** Resolution candidates: (a) memoize the resolution per-port instance with a stored `lastResolvedId` guard; (b) move the warning log into `pattern(forStoredId:)` with a per-process `Set<String>` of already-warned ids; (c) accept the noise.

### PF-031: `TimingOffsetDetectionPatternCatalogTests.catalogEntrySubdivisions` has no `.nested` case

**Found:** 2026-06-05 (Story 84.2)
**Severity:** Low (blocks coverage for the next nested-tuplet story)
**Disposition:** OPEN

The new beat-shape regression test added in 84.2 only handles `(.accent, .note)`, `(.normal, .note)`, `(.rest, .rest)` pairs. The expected side has no `Cell.nested` symbol, so the test cannot pin nested-shape expectations at all. The next story that registers `.nested(Beat)` entries must extend `Cell` and the matcher, or replace the matcher with a `Beat`-tree equality check, before its entries can use this regression coverage.

**Fix:** Extend `Cell` with a `.nested` variant matching `Subdivision.nested(Beat)`, or replace the matcher with structural `Beat`-tree equality.

### PF-032: `TimingOffsetDetectionPattern.pattern02`'s doc comment cross-references `pattern_01` by id

**Found:** 2026-06-05 (Story 84.2)
**Severity:** Low (no current breakage; load-bearing only under hypothetical retire of `pattern_01`)
**Disposition:** OPEN

The retired-id registry's job is to prevent number reuse, not to police doc-comment cross-references. If a future story rephrases without preserving the by-id reference, the connection between the two entries is silently lost.

**Fix:** Resolution candidates: (a) inline the rationale ("default 2 sits on the half-beat — same metric position as the all-audible reference entry"); (b) leave as-is and accept that the catalog file is small enough to grep when retirements come; (c) add a convention rule that catalog doc comments must not cross-reference other entries by id.

### PF-033: `TimingDotView` natural width can grow unbounded on deeply nested patterns

**Found:** 2026-06-05 (Story 84.3)
**Severity:** Low (Epic 84 max nesting depth is 1; not triggered by any shipped pattern)
**Disposition:** OPEN

With the proportional-timeline renderer driven by `GeometryReader`-supplied width, very deep nesting (e.g., sextuplet-inside-duplet-inside-triplet, smallest cell ≈ 1/36 of beat) compresses the smallest cell's pixel width below the dot diameter.

**Fix:** A future multi-beat or depth-3 epic must either cap the renderer's effective scale on deep nests or render an alternate summary representation.

### PF-034: `TimingDotView.cellAccessibilityLabel`'s `childDivision` walk only inspects the top-level `.nested`

**Found:** 2026-06-05 (Story 84.3)
**Severity:** Low (Epic 84 max nesting depth is 1; correct for every shipped entry)
**Disposition:** OPEN

For an audible at path `[1, 2, 0]` (inside `pattern.subdivisions[1].nested(_).subdivisions[2].nested(_)`), `childDivision(forAudiblePosition:)` returns the K of `subdivisions[1].nested(_)`'s child, ignoring the deeper nest the audible actually sits in.

**Fix:** At the depth-2 epic: walk the path through `.nested(child)` levels to the actual containing Beat.

### PF-035: Dotted-and-nested precedence not specified

**Found:** 2026-06-05 (Story 84.3)
**Severity:** Low (Epic 84 has no overlap; latent for the first mixed-duration nested entry)
**Disposition:** OPEN

`TimingOffsetDetectionPattern.dottedAudiblePositions` and `childDivision(forAudiblePosition:)` are independent checks. If a future catalog entry has both flags true for the same audible position (a nested mixed-duration figure), the dotted branch wins and the nested-context descriptor is silently dropped.

**Fix:** Resolution candidates: (a) combine descriptors ("Note N of K, dotted, in triplet"); (b) define an explicit precedence in the design doc; (c) catalog-side invariant that the flags are mutually exclusive.

### PF-036: `patternRowAccessibilityLabel` and SwiftUI `.accessibilityElement(children: .combine)` are two independent label paths

**Found:** 2026-06-05 (Story 84.3)
**Severity:** Low (latent test/UI drift)
**Disposition:** OPEN

In `TimingOffsetDetectionPatternPickerSettingsSection`, the static helper is pinned by unit tests; the runtime label is what VoiceOver actually reads after `.combine` joins the `TimingDotView` per-cell labels. Today both produce the same comma-joined string. If the per-cell label format changes in the renderer without a parallel update to the static helper (or vice versa), tests pass against the helper while VoiceOver reads different text.

**Fix:** Resolution candidates: (a) add a UI test that exercises the rendered VoiceOver label and pins it to `patternRowAccessibilityLabel`; (b) collapse the two paths by computing the row label exclusively from `.combine` and removing the static helper; (c) document the relationship inline.

### PF-037: `Localizable.xcstrings` retains the retired `"Anchor note, not selectable"` key after 84.3

**Found:** 2026-06-05 (Story 84.3)
**Severity:** Low (no production caller; cruft accumulates with each rename)
**Disposition:** OPEN

84.3 flipped the slot-picker anchor label to `"Accent, not selectable"`. The localization tool (`bin/add-localization.swift`) has no removal path.

**Fix:** Resolution candidates: (a) add a `--remove` flag to the tool and run a one-time cleanup; (b) extend the tool to detect un-referenced keys; (c) accept the cruft and revisit during a catalog audit.

### PF-038: Rest-after-`.nested(...)` orphan-rest emission is unit-test-uncovered

**Found:** 2026-06-05 (Story 84.3)
**Severity:** Low (no current catalog entry exercises the shape)
**Disposition:** OPEN

`TimingDotView.visualCells(for:)`'s cell-width math rule 4 case (b) ("`.rest` immediately after `.nest_exit` at the parent depth → orphan rest") is implemented in the `walk(...)` helper but no Epic-82 catalog entry exercises the shape — no flat pattern has a `.nested` followed by a `.rest`. A future contributor refactoring `walk(...)` could break case (b) without any catalog test surfacing the regression.

**Fix:** Add a fixture-based test (not catalog-dependent) that exercises `[.nested(Beat([.note])), .rest]` → expected `[content cell, orphan rest cell, bracket]`.

### PF-039: `bracketGeometryBaseValues` × previewScale multiplication is unit-test-uncovered

**Found:** 2026-06-05 (Story 84.3)
**Severity:** Low
**Disposition:** OPEN

`bracketGeometryBaseValues` pins the constants 1.5/4/1 but no test verifies the `× previewScale` multiplication actually applies in the rendered output. The design doc § *Grouping indicators* says "Offset above cell tops: **4pt** at full scale on the training screen; multiplied by `previewScale` (0.625) in the picker preview." The code multiplies the `@ScaledMetric` value by `scale` in `cellView`, but no test asserts that a `.nestingBracket` cell at `scale: previewScale` ends up at half-ish the offset of one at `scale: 1.0`.

**Fix:** Resolution candidates: (a) add a UI snapshot test at two scales; (b) extract the offset-computation as a pure function and unit-test it; (c) leave to manual visual inspection.

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

### PF-042: `TimingOffsetDetectionPattern.init` does not validate `dottedAudiblePositions` is in-range or non-anchor

**Found:** 2026-06-05 (Story 84.4 review)
**Severity:** Low
**Disposition:** OPEN

`TimingOffsetDetectionPattern.init` enforces the catalog-default-is-pickable invariant via `precondition` but accepts any `Set<Int>` for `dottedAudiblePositions` without validating that each member is in `2...audibleCount` and a non-anchor. A future entry passing `dottedAudiblePositions: [99]` would silently never render the "dotted" descriptor; passing `[1]` would also be a no-op (the `.accent` branch in `TimingDotView.cellAccessibilityLabel` never consults `dottedAudiblePositions`).

**Fix:** Add `precondition(dottedAudiblePositions.allSatisfy { (2...audibleToGrid.count).contains($0) }, "TimingOffsetDetectionPattern '\(id)' dottedAudiblePosition out of range")` to `init`. Optional: lift the test catalog-wide so misregistration surfaces in CI.

### PF-043: `Cell.nested([Cell])` test matcher has no max-depth or structural-divergence guard

**Found:** 2026-06-05 (Story 84.4 review)
**Severity:** Low
**Disposition:** OPEN

`TimingOffsetDetectionPatternCatalogTests`'s recursive `expectSubdivisions` matcher (introduced in 84.4) descends whenever both sides are `.nested` with no maximum depth and no check that the matcher's recursion mirrors the renderer's depth-first walk. Epic 84 entries are depth-1 only; a future depth-3 entry could pass `catalogEntrySubdivisions` while diverging structurally between the expected `Cell.nested(.nested(...))` tree and the actual `.nested(Beat.nested(Beat))` shape.

**Fix:** Add a max-depth assert or guard inside `expectSubdivisions`, or assert the recursive walk's depth matches the actual `Beat` tree depth via a parallel walk. Forward-compat concern only — no current entry exercises depth > 2.

### PF-044: `1e-6` cell-width tolerance hard-codes float evaluation order

**Found:** 2026-06-05 (Story 84.4 review)
**Severity:** Low
**Disposition:** OPEN

`TimingDotViewTests.expectVisualCells` uses absolute tolerance `1e-6` to compare `startXProportion` and `widthProportion` against expected literals. For Epic 84 entries this is comfortable (the largest divisor is 6, and `1.0 / 3.0`, `1.0 / 6.0`, etc. drift by ULP-scale only — well under 1e-6). A future entry with divisor > 6 (e.g. K=7 septuplet) or deeper nesting (e.g. K=3 inside K=3 inside K=2 → /18 cells) could accumulate enough float drift to break the absolute tolerance.

**Fix:** Switch to a relative tolerance (`max(abs(expected), 1.0) * 1e-6`) or use `Double.ulpOfOne * N` to scale with magnitude. Forward-compat concern — no current entry triggers it.

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
