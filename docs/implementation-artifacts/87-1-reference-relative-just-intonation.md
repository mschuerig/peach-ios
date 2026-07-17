---
title: 'Story 87.1: Reference-relative Just Intonation for interval trials'
type: 'feature'
created: '2026-07-17'
status: 'in-progress'
baseline_commit: '822f636a978772bb56a94db57e2a7a235110c960'
context:
  - '{project-root}/docs/planning-artifacts/epics.md'
  - '{project-root}/docs/project-context.md'
  - '../code_reading_chat_2026-07-13.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem.** In Just Intonation mode, both pitch disciplines compute every note's absolute frequency against a fixed A-rooted 5-limit offset table: `TuningSystem.totalCentOffset(for:)` (`Peach/Core/Music/TuningSystem.swift:40-48`) decomposes the MIDI distance *from A4* into octaves + remainder interval and applies the JI interval size from A. The consequence, verified in the 2026-07-13 code reading (`../code_reading_chat_2026-07-13.md` § *The Just Intonation discussion* — file lives one level above the repo): in interval trials the "in tune" target depends on the trial's random reference note. Fifths are pure (702.0¢) from 9 of 12 roots but a 40/27 wolf (680.4¢) from B, G, D♯; major thirds are pure (386.3¢) from 8 roots but 32/25 (427.4¢, **+41¢**) from C♯, D♯, F♯, G♯; minor seconds span 70.7–133.2¢. The listener never hears the A root (no drone, tonic, or cadence), so they judge the bare interval against pure ratios or their 12-TET template while the app's correct answer wanders by tens of cents on a hidden random variable. The Settings help text already promises the better semantics ("Just Intonation uses pure frequency ratios").

The "JI needs a root" objection resolves cleanly: a *scale* root is only needed when three or more notes must be mutually consistent. A trial has exactly two notes, so the root is trivially the note the user just heard.

**Approach.** Compute interval-trial target frequencies *reference-relative*: target in-tune frequency = reference frequency × the directed interval's pure ratio, detune applied on top. The reference note's own absolute pitch becomes equal-tempered in all tuning systems (perceptually irrelevant — only the interval is judged; in unison trials both notes shift identically, so nothing changes there either).

The key structural fact (confirmed against source): `TuningSystem.centOffset(for: Interval)` **already is the pure-ratio interval table** — 16/15, 9/8, 6/5, 5/4, 4/3, 45/32, 3/2, 8/5, 5/3, 9/5, 15/8, 2/1 expressed in cents. The root lottery comes *solely* from `totalCentOffset`'s decomposition measuring absolute distance from A4. The fix therefore adds a small reference-relative frequency API on `TuningSystem` that reuses `centOffset(for:)`, routes both sessions' interval-trial playback through it, and removes the octave+remainder decomposition from the trial-playback path. Under equal temperament the reference-relative path is numerically identical to today's absolute path (ET is root-invariant), so one code path serves both tuning systems — no `if tuningSystem == .justIntonation` branch in the sessions.

**No data migration.** The stored metrics (`centOffset`, `initialCentOffset`, `userCentError`) are detune magnitudes relative to the in-tune point; records carry only the tuning-system name. Post-change JI statistics are cleaner, not incompatible. No SwiftData change, no CSV change.

**Release context.** This story is the release blocker Epic 83 references — it must ship in the next App Store cut (Michael, 2026-07-17: "I want the JI fix to get out").

## Boundaries & Constraints

**Always:**

- **Adam consult first.** Invoke `/agent-music-domain-expert` (Adam) at the start of Task 2, per `[[reference_music_domain_expert]]`, to lock: (a) the per-interval 5-limit ratio table when used reference-relative — the existing `centOffset(for:)` values are the candidate table; the choices worth explicit confirmation are the tritone (45/32 = 590.2¢ vs. 64/45 = 609.8¢) and the minor seventh (9/5 = 1017.6¢ vs. 16/9 = 996.1¢); (b) that a descending directed interval is the inverted ratio (same cent magnitude, negative sign) — the obvious semantics, but it should be on the record; (c) that the reference note sounding at its equal-tempered pitch in JI mode is musically acceptable (the code-reading discussion concluded yes). Record the consult outcome in *Consultation Findings*.
- **Domain types everywhere** per `[[feedback_domain_types_in_specs]]` and `docs/project-context.md`: the new API takes/returns `DirectedInterval`, `Cents`, `Frequency` — no raw `Double` parameters. All bridge parameters explicit, no defaults, matching the existing `frequency(for:referencePitch:)` convention.
- **One playback path for both tuning systems.** The sessions must not branch on tuning system. The reference-relative API computes: ET → `Double(interval.semitones) × Cents.perSemitone` (signed by direction); JI → `centOffset(for: interval)` (signed by direction). Detune adds on top. A regression test pins that ET trial frequencies are bit-for-bit (or within `Double` ulp tolerance) identical to the pre-change absolute-path values.
- **Trials carry their interval.** `PitchDiscriminationTrial` and `PitchMatchingTrial` gain a `let interval: DirectedInterval` stored property (both sessions already hold the `DirectedInterval` at generation time — `PitchDiscriminationSession.beginNextTrial` and `PitchMatchingSession.generateTrial`). Frequency derivation must not re-derive the interval from MIDI-note distance.
- **Unison and octave provably unchanged.** Prime (1/1) and octave (2/1) are pure in both schemes; tests pin that unison and octave JI trials produce the same reference→target frequency relationship as before the change (absolute pitch may shift to ET — that is expected and covered by the invariance tests).
- **The A-rooted absolute path leaves trial playback.** After this story, `frequency(for: DetunedMIDINote, referencePitch:)` under `.justIntonation` is no longer reachable from `PitchDiscriminationTrial`, `PitchDiscriminationSession`, or `PitchMatchingSession`. The absolute API itself stays (it is the single-note logical→physical bridge; ChromaticConstruction and tests use the ET case), with a doc-comment stating that interval-trial playback must use the reference-relative API and why (the root-lottery this story fixes) — the shape stays available for a future drone/tonal-context discipline per the epic.
- **Help copy verified, not rewritten.** Task includes verifying the Settings/help text for Just Intonation against the new semantics; expectation is no change needed (it already says "pure frequency ratios"). If a discrepancy surfaces, fix is in scope only if it is a factual correction; tone stays sober per `[[feedback_sober_factual_copy]]`, German informal per `[[feedback_german_informal]]`.
- **Documentation sync.** Update the two-world-architecture bullet in `docs/project-context.md` (line ~85) and, if arc42 describes the frequency bridge, `docs/architecture.md` — intent-level only per `[[feedback_arc42_intent_not_implementation]]`.
- **Tests-first** per `docs/project-context.md` TDD workflow; Swift Testing only; suites mirror source structure. Pre-commit gate: `bin/test.sh && bin/test.sh -p mac` plus the two Research schemes — all four green, run sequentially per `[[feedback_test_sh_no_parallel]]`.
- **Listening test before done.** Audio-path change → Michael listening test per `[[feedback_verify_audio_features]]` (Grand Piano + Sine Wave, noteDuration 1 s): JI interval trials (pick a major third from C♯ — the formerly-worst root) and an ET trial to confirm no regression.
- Sprint-status key `87-1-reference-relative-just-intonation` flips to `in-progress` on start, `done` after review per `[[feedback_update_status_after_review]]`.

**Ask First:**

- If Adam's consult changes any ratio in the existing `centOffset(for:)` JI table (not just confirms it), pause and present the delta — changed ratios alter ET-vs-JI training targets beyond the root-lottery fix this story is scoped to.
- If verification (Task 1) finds an additional production call site of `frequency(for: DetunedMIDINote, referencePitch:)` in a trial-playback path beyond the three mapped in the Code Map, pause and present it before widening scope (`[[feedback_enumerate_instances_of_root_cause]]`).
- If renaming `PitchMatchingSession.referenceFrequency` (which actually stores the *in-tune target* frequency — a misnomer this story will trip over) expands the diff into the screen/tests noticeably, ask whether to fold the rename in or file it as a PF entry. **Default plan:** rename to `inTuneTargetFrequency` inline — it is small and this story touches every reader anyway.

**Never:**

- No change to stored record schemas, CSV columns, or the meaning of `centOffset` / `initialCentOffset` / `userCentError` (all remain relative-to-in-tune-point).
- No new Settings entry, no `@AppStorage` key, no UI change beyond (at most) factual help-copy correction.
- No tuning-system branch inside session code; the difference lives entirely in `TuningSystem`.
- No touching the web app; it aligns in its own repo, spec'd from this story's outcome.
- No `pattern`-style compatibility shim for old JI records — there is nothing to migrate.

## I/O & Edge-Case Matrix

| # | Given | When | Then |
|---|-------|------|------|
| 1 | JI, reference B4, ascending perfect fifth, detune 0 | target frequency computed | reference(ET) × 2^(701.955/1200) — pure 3/2; **not** the 40/27 wolf (680.4¢) the old path produced from B |
| 2 | JI, reference C♯4, ascending major third, detune 0 | target frequency computed | reference(ET) × 2^(386.314/1200) — pure 5/4; not 32/25 (+41¢) |
| 3 | JI, any two reference notes, same directed interval, same detune | in-tune targets computed | identical cent relationship reference→target for both (root-invariance test) |
| 4 | JI, descending perfect fifth from any reference | target computed | reference(ET) × 2^(−701.955/1200) (inverted ratio, sign from direction) |
| 5 | ET, any interval trial | target computed via new reference-relative path | numerically identical (ulp tolerance) to pre-change absolute-path frequency |
| 6 | JI, unison trial with detune +8¢ | both notes computed | same relationship as before the change: target = reference × 2^(8/1200) |
| 7 | JI, octave trial | targets computed | 2/1 exactly, both before and after (2^(1200/1200)) |
| 8 | Pitch Matching, JI, interval trial | slider at center (value 0) after slider touch | tunable starts at in-tune-target × 2^(initialCentOffset/1200); slider zero-error point is the pure ratio above/below the reference |
| 9 | Pitch Matching, JI | user commits exactly at the pure-ratio frequency | `userCentError == 0` (evaluation is against the reference-relative in-tune target) |
| 10 | Pitch Discrimination, JI, M3 trial | ET-vs-JI divergence checked in test | in-tune JI M3 target is 13.686¢ flat of the ET M3 target for the same reference (the learnable distinction the epic names) |
| 11 | Existing JI records from before the change | app launch, profile rebuild, CSV export | load/aggregate/export unchanged — metrics are in-tune-relative magnitudes, no migration |
| 12 | Session paused mid-trial, then resumed | `resume()` replays from preserved trial | frequencies recomputed from the preserved trial's stored `interval` — no re-derivation drift |

</frozen-after-approval>

## Code Map

All paths relative to repo root. Baseline: `9fee6fa2`.

**Task 1 verification (2026-07-17, against `822f636a`):** Code Map confirmed. Complete production-caller enumeration of `frequency(for: DetunedMIDINote/MIDINote, referencePitch:)`:

- `PitchDiscriminationTrial.referenceFrequency/targetFrequency` (trial playback — this story rewires).
- `PitchMatchingSession.playReferenceNoteForCurrentTrial` (341–345) and `startTunablePlayback` (372–374) (trial playback — this story rewires).
- `SettingsCoordinator.playSoundPreview(duration:)` (49) — ET hard-coded; unaffected.
- `SettingsCoordinator.playSoundPreview(note:duration:)` (74) — **not in original Code Map**; single-note Settings preview through `userSettings.tuningSystem`. Not a trial-playback path → stays on the absolute bridge (it is exactly the single-note conversion the retained API is for). No change.
- `ChromaticConstructionSession`/`Screen` — hard-code `.equalTemperament` by design; unaffected.

Trial constructor call sites: `PitchDiscriminationTrial` — production: `KazezNoteStrategy:76`, `PreviewDefaults.StubPitchDiscriminationStrategy:65`; tests: `SettingsTests`, `PitchDiscriminationTrialTests`, `KazezNoteStrategyTests`, `ProgressTimelineTests`, `PitchDiscriminationSession{,UserDefaults,Reset,Integration,Loudness,Difficulty}Tests`, `MockNextPitchDiscriminationStrategy`, `PitchDiscriminationTestHelpers`, `ProfileScreenTests`. `PitchMatchingTrial` — production: `PitchMatchingSession.generateTrial:475` only; tests construct `CompletedPitchMatchingTrial` (no `interval` field — unchanged) rather than the trial struct.

Observers/records/profile consume MIDI notes + cent offsets only — no absolute frequencies anywhere downstream. `PitchMatchingSession.referenceFrequency` has no readers outside the session and its test file (761/774/777/1027). JI help copy sites: `SettingsScreen.swift:204` (footer) and the Settings help sheet string (`Localizable.xcstrings:2578`) — both already promise pure-ratio semantics. Existing `TuningSystemTests` assert in cents (log-domain) with ≤0.001¢/0.1¢ tolerances — new suites follow that style.

**Modify:**

- `Peach/Core/Music/TuningSystem.swift` — add the reference-relative API (working shape, final signature at implementation time):
  - `func intervalCents(for interval: DirectedInterval) -> Cents` — signed: ET → `semitones × Cents.perSemitone`; JI → `centOffset(for:)`; negative for `.down`.
  - `func frequency(for interval: DirectedInterval, detunedBy offset: Cents, above reference: Frequency) -> Frequency` — `reference × 2^((intervalCents + offset)/1200)`.
  - Doc-comment on `frequency(for: DetunedMIDINote, referencePitch:)`: absolute A-rooted path; must not be used for interval-trial playback (root lottery); retained for single-note conversion and a future drone/tonal-context discipline.
- `Peach/Training/PitchDiscrimination/PitchDiscriminationTrial.swift` — add `let interval: DirectedInterval`; `referenceFrequency(...)` becomes ET-absolute conversion of `referenceNote`; `targetFrequency(...)` becomes reference-relative via the new API with `targetNote.offset` as detune. `targetNote: DetunedMIDINote` stays (records/observers read it).
- `Peach/Training/PitchDiscrimination/PitchDiscriminationSession.swift` — trial construction passes `interval` (strategy call site `beginNextTrial`, line ~294); playback path unchanged otherwise (it already delegates to the trial's frequency methods).
- Strategy conformances producing `PitchDiscriminationTrial` (`NextPitchDiscriminationStrategy` implementations, e.g. `KazezNoteStrategy`) — construct the trial with its interval. **Verify in Task 1** which conformances and mocks construct trials.
- `Peach/Training/PitchMatching/PitchMatchingTrial.swift` — add `let interval: DirectedInterval`.
- `Peach/Training/PitchMatching/PitchMatchingSession.swift` —
  - `generateTrial(settings:interval:)` (line ~462): store the interval in the trial.
  - `playReferenceNoteForCurrentTrial` (lines ~338-346): `refFreq` = ET-absolute of `trial.referenceNote`; in-tune target = new reference-relative API (detune 0); rename `referenceFrequency` property → `inTuneTargetFrequency` (misnomer; see Ask First).
  - `startTunablePlayback` (lines ~368-374): replace the `DetunedMIDINote(note:offset:)` absolute reconstruction with in-tune target × `initialCentOffset` detune (equals `sliderFrequency(for: 0)`).
  - `evaluateResult` / `sliderFrequency`: unchanged semantics — they are already relative to the in-tune target.
- `docs/project-context.md` — two-world-architecture bullet (~line 85): note the reference-relative interval bridge alongside the absolute single-note bridge.
- `docs/architecture.md` — only if it describes the frequency bridge; intent-level touch-up.

**Tests (modify/add):**

- `PeachTests/Core/Music/TuningSystemTests.swift` — add reference-relative suites: matrix rows 1-5, 7, 10 (wolf roots B/G/D♯ fifths; C♯/D♯/F♯/G♯ major thirds; root-invariance; descending inversion; ET equivalence; octave; ET-vs-JI divergence constants).
- `PeachTests/Training/PitchDiscrimination/` — trial-frequency tests for the new shape; update trial-construction call sites for the added `interval` field.
- `PeachTests/Training/PitchMatching/PitchMatchingSessionTests.swift` — lines ~134/226/509/533 build expected values via the ET absolute path; ET equivalence means values stay valid, but constructor call sites gain `interval`. Add a JI matching test (matrix rows 8-9).
- Any mock strategies/fixtures constructing trials.

**Not touched:** SwiftData models, CSV schema/parsers, `SoundFontPlayer.decompose` (inverse Hz→MIDI, tuning-agnostic), `ChromaticConstruction` (own ET-only cent math), `TuningSystem` Settings picker and indicator UI, web app.

## Tasks & Acceptance

- [x] **Task 1 — Verification & call-site audit.** Confirm the Code Map against baseline: enumerate every production caller of `frequency(for: DetunedMIDINote/MIDINote, referencePitch:)` and every constructor call site of both trial types (including tests and mocks). Confirm the JI help copy location and current wording. Confirm neither `KazezNoteStrategy` nor observers/records consume absolute JI frequencies anywhere else. Any surprise → Ask First. (AC: Code Map confirmed or corrected in this file before implementation.)
- [x] **Task 2 — Adam consult.** Lock the ratio table, descending semantics, and ET-reference acceptability per Boundaries. Record in *Consultation Findings*. (AC: locked table recorded; any table change → Ask First.)
- [x] **Task 3 — Tests first: TuningSystem reference-relative API.** Write failing tests for matrix rows 1-5, 7, 10. Implement `intervalCents(for:)` + `frequency(for:detunedBy:above:)`. (AC: rows 1-5, 7, 10 green; existing `TuningSystemTests` untouched and green.) *Final signature uses `from:` instead of `above:` — direction-neutral (descending targets sit below the reference).*
- [x] **Task 4 — Pitch Discrimination path.** Trial gains `interval`; frequency methods go reference-relative; strategy + session + test call sites updated. (AC: rows 3, 6, 10 green through the trial API; ET regression row 5 pinned at trial level; full suite green.) *Both trial inits gained a `precondition(referenceNote.transposed(by: interval) == targetNote)` coherence check — the trial owns the invariant its frequency derivation now relies on.*
- [x] **Task 5 — Pitch Matching path.** Trial gains `interval`; session reference/target/tunable computation per Code Map; `inTuneTargetFrequency` rename. (AC: rows 8-9 green; existing matching tests green with updated constructors.) *Rename folded in per default plan; tunable start now reuses `sliderFrequency(for: 0)`.*
- [x] **Task 6 — Help copy + docs.** Verify JI help text (expectation: no change); update `project-context.md` two-world bullet; arc42 touch-up if applicable. (AC: copy verified or factually corrected; docs reflect the reference-relative bridge.) *Both copy sites (`SettingsScreen.swift:204` footer, help-sheet string) already state "pure frequency ratios" — now factually true; no change. arc42 §two-world bridge + worked example updated; `project-context.md` two-world bullet updated.*
- [ ] **Task 7 — Gates + listening test.** All four schemes green (sequential). Michael listening test per Boundaries (JI M3 from C♯, ET control). (AC: gates green; Michael confirms; then status → review, and after review → done per `[[feedback_update_status_after_review]]`.) *Gates green 2026-07-17: iOS 2169 / macOS 2156 / iOS Research 2333 / macOS Research 2320; `archlint` clean; `check-dependencies.sh` sole finding is the pre-existing PF-070 comment-text false positive (fails identically on baseline). Michael listening test pending.*

## Dev Notes

### The one-table insight (load-bearing)

`centOffset(for: Interval)` under `.justIntonation` is already the pure 5-limit interval table. Do **not** introduce a second ratio table. The entire JI fix is: use that table *relative to the reference* instead of relative to A4. `totalCentOffset`'s octave+remainder decomposition is what encodes the A-root; it leaves the trial-playback path but the function itself stays for the absolute bridge.

### Why ET goes through the same new path

ET interval cents are root-invariant (`semitones × 100`), so reference-relative ET ≡ absolute ET. Routing both systems through the reference-relative API deletes the possibility of session-level divergence and gives the ET-equivalence regression test its meaning: if row 5 holds, the refactor cannot have broken ET training.

### Compound intervals

`Interval` caps at `.octave` and `DirectedInterval` composes it with direction; trial generation constrains ranges so reference+interval stays in MIDI range (`generateTrial`, both sessions). No compound-interval handling is needed — but storing `interval` in the trials (instead of re-deriving from MIDI distance) keeps it that way by construction.

### The `referenceFrequency` misnomer in PitchMatchingSession

Line 345: `self.referenceFrequency = targetFreq` — the property named "reference" holds the in-tune *target*. `sliderFrequency` and `evaluateResult` are correct only because of this. The rename to `inTuneTargetFrequency` is part of this story's default plan; every reader of the property is already in the diff.

### Two-world architecture (from `docs/project-context.md`)

Forward conversion logical→physical goes through `TuningSystem`; this story *adds* a second forward bridge (directed interval + reference frequency → frequency) rather than bypassing the type. `Frequency`-typed arithmetic stays inside `TuningSystem` / the trial types; sessions keep passing `Frequency` to `NotePlayer` (which knows only Hz).

### Testing precision

The app requires 0.1-cent precision (`docs/project-context.md`). Frequency assertions should compare in cents (log-domain) with tolerance ≤ 0.01¢, not in Hz with absolute epsilons — matching the existing `TuningSystemTests` style (verify in Task 1).

### Project Structure Notes

- New API lives on the existing `TuningSystem` enum (`Core/Music/`) — no new files expected in production code; the change is concentrated in 2 core + 4 training files.
- Trial types stay in their feature directories; adding `interval: DirectedInterval` imports nothing new (`DirectedInterval` is `Core/Music/`).
- No cross-feature coupling introduced; `archlint Peach/` and `bin/check-dependencies.sh` must stay clean.

### References

- [Source: ../code_reading_chat_2026-07-13.md § The Just Intonation discussion] — problem analysis, resolution of the root question, proposed change, no-migration argument.
- [Source: docs/planning-artifacts/epics.md § Epic 87] — theme, scope, out-of-scope (web app, drone discipline, copy).
- [Source: Peach/Core/Music/TuningSystem.swift:12-57] — current table + absolute bridge (read during story creation).
- [Source: Peach/Training/PitchDiscrimination/PitchDiscriminationTrial.swift] — current trial frequency methods.
- [Source: Peach/Training/PitchMatching/PitchMatchingSession.swift:338-346,368-374,399-417,456-476] — matching playback/evaluation paths.
- [Source: docs/planning-artifacts/epics.md § Epic 83] — release-blocker linkage (83.3 waits on this story).

## Consultation Findings

**Adam (music-domain-expert), 2026-07-17 — all three questions resolved; table locked unchanged.**

Framework: interval identity in JI is a frequency ratio between two tones; the scale-degree framework (10/9 vs 9/8, wolf fifths) only activates when ≥3 tones must be mutually consistent. A trial is a dyad → ratio-identity governs; reference-relative is theoretically confirmed as the right architecture.

- **(a) Table locked = existing `centOffset(for:)` values, no changes.** Senario consonances (2/1, 3/2, 4/3, 5/4, 6/5, 5/3, 8/5) unambiguous. M2 9/8 correct for a bare dyad (10/9 is a scale-position artifact). m2 16/15 / M7 15/8 correct (diatonic semitone + complement). **Tritone 45/32 kept as convention** — no perceptual ground truth exists for a bare 5-limit tritone; 45/32 and 64/45 are symmetric about ET (±9.8¢); septimal 7/5 would leave the 5-limit frame; continuity wins. **m7 9/5 kept** — P5+m3 consonance stack, more anchorable than 3-limit 16/9. On the record: the table is inversionally inconsistent at m7/M2 (9/8 inverts to 16/9, not 9/5) — harmless reference-relative since trials never stack intervals.
- **(b) Descending = inverted ratio, confirmed.** Target below reference by the same ratio: reciprocal frequency ratio, same cent magnitude, negative sign. Only semantics consistent with ratio-identity.
- **(c) ET-pitched reference confirmed acceptable.** Absolute placement of the reference is imperceptible without AP (and unobjectionable with it — identical to ET mode's reference); tuning a pure interval from an ET reference is standard musical practice. The A-rooted alternative is exactly the root lottery being removed.
- Proactive flag (no code impact): users with a strong 12-TET template will initially err ~14¢ sharp on JI major thirds — the intended learnable distinction; may appear as a temporary difficulty bump in JI statistics.

Since the table is confirmed unchanged, the Ask-First trigger (table delta) does not fire.

## Dev Agent Record

### Agent Model Used

Claude Fable 5 (claude-fable-5) via bmad-quick-dev; test-constructor churn delegated to a general-purpose subagent (64 sites, 16 files).

### Debug Log References

None — no test failures during implementation; all four schemes green on first full run after the churn.

### Completion Notes List

- New API is two methods on `TuningSystem`: `intervalCents(for: DirectedInterval) -> Cents` (signed) and `frequency(for:detunedBy:from:)`. One playback path for both tuning systems — no session-level branch anywhere.
- `PitchDiscriminationTrial.referenceFrequency` dropped its now-meaningless `tuningSystem:` parameter (reference is ET in every system); `targetFrequency(tuningSystem:referencePitch:)` kept its shape.
- Both trial inits enforce `referenceNote.transposed(by: interval) == targetNote` by precondition, so a trial whose stored interval disagrees with its note pair cannot exist — protects the frequency derivation that no longer looks at MIDI distance.
- `SettingsCoordinator.playSoundPreview(note:duration:)` (found in Task 1) intentionally stays on the absolute bridge — single-note preview, exactly the retained API's purpose.
- Adam consult locked the existing ratio table unchanged (tritone 45/32, m7 9/5); no Ask-First trigger fired.
- `check-dependencies.sh` finding = PF-070 (pre-existing comment-text false positive; verified identical on baseline via stash).

### File List

**Production:** `Peach/Core/Music/TuningSystem.swift`, `Peach/Training/PitchDiscrimination/PitchDiscriminationTrial.swift`, `Peach/Training/PitchDiscrimination/PitchDiscriminationSession.swift`, `Peach/Core/Algorithm/KazezNoteStrategy.swift`, `Peach/App/PreviewDefaults.swift`, `Peach/Training/PitchMatching/PitchMatchingTrial.swift`, `Peach/Training/PitchMatching/PitchMatchingSession.swift`

**Tests:** `PeachTests/Core/Music/TuningSystemTests.swift`, `PeachTests/Core/Training/PitchDiscriminationTrialTests.swift`, `PeachTests/Training/PitchMatching/PitchMatchingSessionTests.swift`, plus 16 files of mechanical `interval:` constructor updates (see subagent list in git diff)

**Docs:** `docs/arc42.md`, `docs/project-context.md`, this spec

## Change Log

- 2026-07-17 — Story created from Epic 87 (code-reading triage 2026-07-13; ultimate context engine analysis completed — comprehensive developer guide created).
- 2026-07-17 — Tasks 1–6 complete + gates green (all four schemes, sequential). Task 1 confirmed the Code Map and added one finding (SettingsCoordinator note preview — stays absolute). Task 2 locked the ratio table unchanged. Awaiting Michael listening test (Task 7) and step-04 review.
