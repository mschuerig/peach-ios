---
title: 'Story 84.1: Tuplet renderer and catalog design lock'
type: 'chore'
created: '2026-06-04'
status: 'done'
baseline_commit: '861f926bd83038145540f5bb08ec85d5e2e87829'
context:
  - '{project-root}/docs/planning-artifacts/tod-initial-pattern-catalog.md'
  - '{project-root}/docs/planning-artifacts/tod-discipline-future-direction.md'
  - '{project-root}/docs/implementation-artifacts/epic-84-context.md'
  - '{project-root}/docs/implementation-artifacts/82-3-initial-pattern-catalog-and-picker-ux.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Epic 84 splits TOD's tuplet expansion into three implementation stages (id swap → renderer → sectioned picker + catalog content), but all three are blocked on four unresolved design questions: the *proportional-timeline cell-width math* that replaces Epic 82's equal-cell renderer, the *per-cell `accessibilityLabel` form* for nested figures, the *sectioned picker categorization* (working scheme *Straight / Gapped / Triplet / Sextuplet / Nested*), and the *tuplet catalog set itself*. Without these landed before 84.2 starts, the id rename, the renderer, and the catalog content are either bias-built against one author's mental model or reworked once Adam's musical evidence lands.

**Approach:** A no-code design story modeled on 82.3 that produces one written design doc at `docs/planning-artifacts/tod-tuplet-renderer-design.md`, owned by this story and read by 84.2–84.4 as source of truth. The doc fixes (a) the cell-width math derived from each pattern's `Beat` representation with explicit forward-compat sketch for multi-beat, (b) the "spacing communicates grouping" rule as positioning math with non-textual grouping indicators for nested figures, (c) the per-cell accessibility-label form Adam green-lights, (d) the locked categorization scheme and bucket assignments, (e) at-scale sketch renderings of every surviving catalog entry verifying visual distinguishability without display names, and (f) Adam's per-entry idiomatic validation plus as-a-set judgment. The opaque pattern-id convention itself (whose value strings 84.2 swaps onto) is also locked here. `agent-music-domain-expert` (Adam) is consulted up front; his response is captured verbatim. No code, no SwiftUI, no `.xcstrings` changes.

## Boundaries & Constraints

**Always:**
- Decide before recording. First step is a fresh `agent-music-domain-expert` consultation framed with: (a) the Performance-Principle requirement that TOD probe varied rhythmic contexts users can perform best in, (b) the engine constraints (`.nested(Beat)`, variable subdivision counts, mixed-duration shape as sextuplet grid with multi-cell holds — all already supported), (c) the single-beat-only scope and the "first audible note never pickable" rule inherited from Epic 82.3, (d) the candidate catalog from Epic 84's working list as starting input — entries may be added, removed, or revised. Adam's response captured verbatim in the doc's *Consultation* section.
- Each surviving catalog entry records the full quintuple: **opaque stable id** (per the convention locked in this doc — suitable for `@AppStorage` and a Swift identifier), **notation string** (Michael's makeshift convention: `*` audible, `-` rest, `.` next-smaller subdivision, hyphen-connected runs are tuplet groupings, trailing dot is dotted), **`Beat` builder shape** (described in prose: subdivision count, per-cell kind, nesting structure), **pickable-position list** (1-based audible-only, first audible excluded), and **`defaultOffsetNotePosition`** (per Adam's per-entry rationale).
- The opaque pattern-id convention is locked here, not in 84.2. The convention must (i) be self-contained without reference to bitmask shape, (ii) generate stable ids for every pattern Adam approves including all tuplet shapes, (iii) be forward-compatible with multi-beat patterns, (iv) survive a representative collision check across the full candidate set. The doc lists the new id for each surviving entry and the rename map for the five Epic-82 entries (`pattern_1111` → new, etc.).
- Cell-width math is recorded as a precise positioning rule expressed against each `Beat` representation: how many proportional units a subdivision occupies; how nested figures contribute units; how rests, dotted shapes, and multi-cell holds map. The math must be derivable from the `Beat` tree alone — no per-entry table of magic numbers. The doc includes a forward-compat sketch showing the same rule yielding multi-beat layouts without re-architecting.
- "Spacing communicates grouping" is turned into positioning math, not an ad-hoc visual rule. Grouping indicators for nested figures are **non-textual** (e.g. a thin proximity line or bracket above grouped cells; final visual settled by the doc, no localised glyphs). The doc states the rule precisely enough that 84.3 implements it without ambiguity.
- Per-cell `accessibilityLabel` semantics are recorded — Adam input on natural phrasing (working candidates from the epic: "Note 3 of 4, inside duplet of 16th-triplets" vs simpler "Position 3 of 4, nested duplet"). The doc locks one form and gives the worked label for every cell of every surviving entry. Existing rest-slot "unavailable" semantics from 82.3 are preserved unchanged.
- Categorization scheme is recorded with: the locked buckets (working scheme *Straight / Gapped / Triplet / Sextuplet / Nested*; Adam confirms or revises), the bucket assignment for every surviving entry, and the rule of thumb for placing future additions. The five Epic-82 patterns redistribute into *Straight* (`* * * *`, `* - * -`) and *Gapped* (`* - * *`, `* * - *`, `* - - *`).
- At-scale sketch renderings (ASCII / prose-level, not pixel-perfect) of every surviving entry's picker-row preview — across iPhone portrait minimum and Dynamic Type AX1 minimum — pasted into the doc to verify visual distinguishability without display names. If two entries collide visually at AX1, the doc states the resolution (revise spacing, change grouping indicator, or drop one entry).
- Settled terminology applies end-to-end: *Offset Note*, *Offset Note Position*, code identifier `offsetNotePosition`. "Slot" stays engineering-vocabulary only. "Displaced" must not appear in any new copy (load-bearing — see `feedback_tod_no_displaced_term`). "TOD" is shorthand only in this spec, never inside the design doc's prose or in any id/code-identifier proposal (see `feedback_tod_shorthand_only`).
- Cross-link the new doc into `tod-discipline-future-direction.md` and `epic-84-context.md` — the former gains a forward pointer under *Open questions to revisit before building the future expansion*; the latter's *Technical Decisions* and *UX & Interaction Patterns* sections gain the "locked in 84.1 → see doc" pointer in place of the working-scheme language.
- The doc states explicitly: 84.2 swaps ids using the rename map; 84.3 implements the cell-width math, grouping indicators, and a11y labels; 84.4 ships the sectioned picker chrome and registers the catalog content. Each downstream story's expected derivations are listed in a *Notes for 84.2–84.4* section.

**Ask First:**
- If Adam recommends a catalog substantially smaller or larger than the working list (say, fewer than 6 or more than 12 entries), or proposes a pattern shape outside single-beat scope — HALT and surface for triage before recording.
- If the cell-width math cannot be expressed as a single rule over the `Beat` tree without per-entry magic numbers — HALT. Per-entry tables are an architectural smell the forward-compat requirement is meant to prevent.
- If the at-scale rendering verification reveals two entries indistinguishable at AX1 and the resolution requires dropping or revising an entry Adam already green-lit — HALT for Michael's call before mutating the catalog.
- If the proposed opaque id convention cannot generate unique ids for the full candidate set, or cannot extend to multi-beat patterns without a second rule — HALT and surface; the convention is load-bearing across the rest of the epic.
- If grouping-indicator design cannot be expressed without text glyphs or localised symbols — HALT.

**Never:**
- No code changes anywhere in the repo. No new SwiftUI files. No edits to `TimingOffsetDetectionPattern.swift`, `TimingOffsetDetectionPatternCatalog.swift`, `TimingOffsetDetectionPatternPickerSettingsSection.swift`, `TimingDotView.swift`, `TimingOffsetDetectionSettings.swift`, `TimingOffsetDetectionSettingsKeys.swift`, `TimingOffsetDetectionUserSettings.swift`, `Core/Audio/SequencerTypes.swift`, or `Localizable.xcstrings`.
- No new `.xcstrings` entries via `bin/add-localization.swift`. The doc records the German wording 84.4 will register for section headers; the actual registration is 84.4's job.
- No swing terminology. The mixed-duration triplet `* *. .` is a structurally-defined entry, not a swing-feel emulator. No "swing" toggle, "swing ratio" control, or swing-labeled UI proposed anywhere in the doc (per Michael, 2026-06-04).
- No localized per-pattern names or captions. The visual *is* the pattern's identity. Per-cell `accessibilityLabel` carries the screen-reader burden. Only section headers are localized.
- No tuplet patterns outside single-beat scope. Longer-than-beat / multi-beat syncopation is the follow-up epic; this doc's forward-compat sketches reference it but do not pre-build content.
- No metronome / external-pulse-reference feature proposed. No patterns starting with a rest.
- No re-litigation of *Offset Note* terminology (settled by 82.2). No re-litigation of "first audible note excluded from pickable set" (settled by 82.3 round 3).
- No image files for the at-scale renderings. ASCII / prose-level only — diff-friendly, LLM-readable, same standard as 82.3's slot-picker sketch.
- No arbitrary user-defined patterns. Catalog stays curated.
- No marketing copy in either language. No motivational framing, no "challenge yourself" register — describe what the pattern is and what it probes (per `feedback_sober_factual_copy`).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Adam approves the working catalog with minor revisions (~9–11 entries) | Consultation returns the list with per-entry musical commentary | Record verbatim; write the doc; cell-width math, ids, a11y labels, defaults derived per entry | N/A |
| Adam argues the mixed-duration `* *. .` is not idiomatically distinct from `* * *` at TOD's probe-scale | Consultation flags overlap | Record reasoning; drop or revise the entry; categorization unaffected | N/A |
| Adam recommends a new pattern shape inside single-beat scope (e.g. a sextuplet with rests) | Consultation adds an entry | Record; verify `Beat` builder representability against engine primitives; place in a bucket | N/A |
| Adam recommends a pattern that requires engine changes | Consultation proposes longer-than-beat / `Subdivision` extension | HALT per Ask First — out of scope | Halt-and-ask |
| At-scale rendering: two entries collide at AX1 | Visual distinguishability check fails | Try spacing/indicator revision; if still colliding, halt-and-ask before dropping an Adam-approved entry | Halt-and-ask if drop required |
| Opaque id convention: candidate scheme generates collisions | Convention check fails on full candidate set | Iterate the convention before recording; if no collision-free scheme emerges, halt-and-ask | Halt-and-ask |
| Cell-width math: a pattern needs a per-entry override | Math rule fails to cover a surviving entry | HALT per Ask First — the rule must be uniform | Halt-and-ask |
| Categorization: a surviving entry fits no bucket | E.g. a sextuplet-with-rests neither *Sextuplet* nor *Nested* | HALT per Ask First — either revise the scheme or drop the entry | Halt-and-ask |

</frozen-after-approval>

## Code Map

- `docs/planning-artifacts/tod-tuplet-renderer-design.md` — **NEW**. The design doc this story produces. Sections: *Purpose*, *Inputs and constraints*, *Opaque pattern-id convention* (rule + rename map for Epic-82 ids + new ids for tuplet entries), *Cell-width math* (rule expressed against `Beat`; worked examples per pattern shape; forward-compat sketch for multi-beat), *Grouping indicators* (non-textual visual spec for nested figures), *Per-cell accessibility labels* (locked phrasing + worked labels for every surviving entry), *Categorization* (locked buckets + per-entry assignment + rule of thumb for additions), *Catalog* (table — one row per entry with id / notation / `Beat` builder shape / per-cell kind / pickable positions / `defaultOffsetNotePosition`), *At-scale renderings* (ASCII sketches per entry at iPhone portrait + AX1), *Consultation with Adam* (verbatim), *Notes for 84.2–84.4* (what each downstream story derives).
- `docs/planning-artifacts/tod-discipline-future-direction.md` — add a forward pointer under § *Open questions to revisit before building the future expansion* to the new doc for the renderer / a11y / categorization / catalog-content questions this story owns. Other sections untouched.
- `docs/implementation-artifacts/epic-84-context.md` — under § *Technical Decisions* and § *UX & Interaction Patterns*, replace the working-scheme language with a "locked in 84.1 → see doc" pointer. Other bullets untouched.
- `docs/planning-artifacts/tod-initial-pattern-catalog.md` — **READ ONLY** as the predecessor design doc. The five Epic-82 entries and the rendering / a11y / categorization conventions established there are the baseline this story extends and partially supersedes. No edits.

## Tasks & Acceptance

**Execution:**
- [x] Consult `agent-music-domain-expert` (Adam) framing the four inputs from *Always* clause 1 (Performance Principle, engine constraints, single-beat scope + first-audible-excluded rule, working candidate catalog). Record the response verbatim in the doc's *Consultation* section.
- [x] Validate Adam's recommendation against the three baseline constraints (Performance Principle / single-beat scope / first-audible-excluded) in one short paragraph each.
- [x] Design and record the opaque pattern-id convention. Generate ids for every surviving entry and the rename map for the five Epic-82 entries. Verify no collisions across the full set; verify the convention extends to a multi-beat sketch.
- [x] Derive and record the cell-width math as a uniform rule over the `Beat` tree. Include a worked example per pattern shape in scope (8th-triplet, gapped 8th-triplet, 16th-triplet-in-8th, duplet-in-triplet, sextuplet, mixed-duration). Include the forward-compat sketch for multi-beat.
- [x] Design and record the grouping-indicator visual spec for nested figures — non-textual, no localised glyphs. State the indicator's position, scaling, and color treatment at a sketch level.
- [x] Lock the per-cell `accessibilityLabel` form with Adam's input. Write the worked label for every cell of every surviving entry.
- [x] Lock the categorization scheme and bucket assignments. State the rule of thumb for placing future additions.
- [x] Draft the *Catalog* table — one row per surviving entry, all columns filled (id / notation / `Beat` builder shape / per-cell kind / pickable positions / `defaultOffsetNotePosition`). Confirm every pickable-position list excludes audible position 1 and matches the audible cells in the `Beat` shape.
- [x] Produce at-scale ASCII renderings of every surviving entry at iPhone portrait and Dynamic Type AX1. Verify visual distinguishability pairwise; record the verification outcome.
- [x] Write *Notes for 84.2–84.4* enumerating: what 84.2 derives (rename map + new convention), what 84.3 derives (cell-width math + grouping indicators + a11y labels), what 84.4 derives (categorization + per-entry content + section-header localization wording).
- [x] Cross-link from `tod-discipline-future-direction.md` and `epic-84-context.md` per Code Map.
- [x] Verification: run `grep -n "tod-tuplet-renderer-design" docs/planning-artifacts/*.md docs/implementation-artifacts/*.md` and confirm at least three matches (the new doc itself plus both back-links). Capture output in *Verification*.
- [x] Run `grep -niE "displaced|swing" docs/planning-artifacts/tod-tuplet-renderer-design.md`; expect zero matches in new descriptive copy (use-mention contexts in *Discarded alternatives* or verbatim consultation rounds are allowed and called out).

**Acceptance Criteria:**
- Given an agent picking up 84.2, when they look for the rename map and the new opaque id convention, then they find one canonical source — `tod-tuplet-renderer-design.md` — with the per-entry rename map and the convention rule fully specified.
- Given an agent picking up 84.3, when they look for the cell-width math, grouping-indicator visual spec, and per-cell `accessibilityLabel` form, then they find a single recorded rule plus worked examples — no per-entry magic numbers, no placeholder a11y strings.
- Given an agent picking up 84.4, when they look for the categorization scheme and catalog content, then they find the locked bucket assignments, the complete per-entry table with `Beat` builder shape and `defaultOffsetNotePosition`, and the German section-header wording 84.4 will register.
- Given `tod-discipline-future-direction.md` and `epic-84-context.md` after this story, when an agent searches for the four working-scheme questions this story owns, then each is flipped to a "locked in 84.1 → see doc" pointer.
- Given the new doc end-to-end, when read, then it contains zero occurrences of "displaced" or "swing" in any new descriptive copy and zero user-facing uses of "slot" outside an explicit *Vocabulary boundary* note.
- Given the at-scale rendering section, when read, then every surviving catalog entry has a sketch at iPhone portrait AND at Dynamic Type AX1, and the pairwise distinguishability outcome is recorded.

## Spec Change Log

### 2026-06-04 — Review iteration 1 (patches only, no spec loopback)

Three parallel reviewers (blind hunter / edge-case hunter / acceptance auditor) produced 22 deduplicated findings. None classified as `intent_gap` or `bad_spec` — the spec's `<frozen-after-approval>` block did not need amendment. 21 findings classified as `patch` and applied to the deliverable (`docs/planning-artifacts/tod-tuplet-renderer-design.md`) plus the predecessor doc (`docs/planning-artifacts/tod-initial-pattern-catalog.md` header forward-pointer). 1 finding rejected (Adam's "user can switch" sub-clause for `pattern_12` is preserved in the verbatim *Consultation with Adam* section; not also needed in the distilled per-entry rationale).

**Triggering findings (severity-ordered, deduplicated):**

- HIGH — VoiceOver cannot perceive a leading nested group containing the accent (edge-case hunter #1).
- HIGH — `audibleToGrid` recursion type deferred to 84.3 rather than locked here (blind hunter #3 + edge-case hunter #2).
- HIGH — Cell-width math undefined for transitions outside Epic 84's catalog scope (blind hunter #4 + edge-case hunter #3).
- HIGH — Pairwise distinguishability table covers ~10 of ~22 within-bucket pairs (blind hunter #1 + edge-case hunter #4).
- HIGH — Adam-vs-locked-doc bucket placement reconciliation wording (blind hunter #2).
- MEDIUM — Bracket geometry `@ScaledMetric` not locked (edge-case hunter #6).
- MEDIUM — `pattern_13` vs `pattern_14` AX1 borderline mitigation depends on unspecified bracket scaling (blind hunter #7 + acceptance auditor CONDITIONAL + edge-case hunter #7).
- MEDIUM — ASCII renderings don't precisely match math ratios — no disclaimer (blind hunter #6).
- MEDIUM — `pattern_04` host-division-2 perception vs *Gapped 16ths* bucket (blind hunter #8).
- MEDIUM — "Hosts not named" justification fails for leading-nested entries (blind hunter #9).
- MEDIUM — Opaque id convention governance gaps (blind hunter #10 + edge-case hunter #8).
- MEDIUM — German section header AX1 wrap behavior not locked (edge-case hunter #5).
- LOW — Sloppy "(sorry, 2:3:1)" parenthetical (blind hunter #11).
- LOW — German `--list` verification deferred to 84.4 (blind hunter #12).
- LOW — Predecessor doc lacks forward pointer (blind hunter #13).
- LOW — Epic-82 visual change buried in worked-example aside (blind hunter #15).
- LOW — Anchor cell label change from "Anchor note, not selectable" to "Accent" — surface ambiguity (edge-case hunter #10).
- LOW — Absorbed rests not separate focusable elements — implicit (edge-case hunter #11).
- LOW — German label composition naturalness not specified (edge-case hunter #12).
- LOW — 84.2 hand-off code surfaces incompletely enumerated (edge-case hunter #14).
- LOW — Catalog "Per-leaf kind" column uses informal notation (edge-case hunter #15).

**Amendments outside the frozen block (per patch resolution path):**

All amendments are to the deliverable (`tod-tuplet-renderer-design.md`) plus a one-line forward pointer in the predecessor doc (`tod-initial-pattern-catalog.md`). The story spec's frozen block is not amended. See the deliverable's *Review-iteration log* section for the full per-amendment audit trail.

**Known-bad states avoided:**

- 84.3's author inventing the `[GridPath]` shape on their own, with downstream divergence between the renderer's depth-first walk and the wrapper's audible addressing.
- 84.3's author shipping a 1pt-thick bracket that vanishes at AX1, leaving sighted users unable to perceive nesting at the largest a11y size.
- VoiceOver users on `pattern_11` and `pattern_14` mistaking the leading nested group's extent (inferring the bracket starts at position 2 because position 1 says only "Accent").
- 84.4 silently registering a German section header that collides with an 82.3-era German string already in `Localizable.xcstrings`.
- The catalog table being read as imprecise prose (`"note (top); [note, note] (nested)"`) and an implementer producing a different leaf sequence than the cell-width math expects.
- A future contributor re-bucketing `* - * -` (the single-pickable "8ths-feel" entry) into a notional "Straight 8ths" bucket on the basis of Adam's rule-of-thumb.
- 84.2's author missing a code surface (e.g. `defaultPattern`, the `BeatProvider` lookup, or the `@AppStorage` default) and shipping a half-renamed catalog.

**KEEP (re-derivation must preserve):**

- The 15-entry catalog set and Adam's per-entry musical evidence (verbatim consultation section in the deliverable).
- The opaque sequential id convention and the rename map for `pattern_01`–`pattern_05`.
- The cell-width math's "uniform rule over the Beat tree" property — no per-entry magic numbers.
- The categorization scheme (Straight 16ths / Gapped 16ths / Triplets / Nested / Sextuplet), the section order, and the rule of thumb for additions.
- The cross-links into `tod-discipline-future-direction.md` and `epic-84-context.md`.
- The first-audible-excluded rule and the catalog-wide invariant (`pattern.pickable.contains(1) == false`).
- The locked terminology (Offset Note / Offset Note Position; no "displaced"; no "swing"; "TOD" shorthand only in this spec, not in any code identifier).

## Design Notes

**Why a separate no-code story rather than folded into 84.3 or 84.4:** 84.3 implements the renderer; 84.4 ships the catalog content. Both are blocked on the cell-width math, the a11y form, the categorization, and the surviving catalog set. Deciding inside 84.3 biases the math to whichever patterns 84.3's author imagines; deciding inside 84.4 builds 84.3's renderer without the worst-case pattern in mind and gets reworked. Landing the lock here, before either, is the cheaper sequence — same reasoning as 82.3 sitting upstream of 82.5–82.7.

**Why the opaque id convention is locked in this story, not 84.2:** 84.2 *applies* the rename. The convention itself is a design decision that affects every entry's id including the tuplet additions 84.4 ships. Locking it here means 84.2 is mechanical transcription, 84.4 doesn't reopen the question, and the convention is reviewable against the full candidate catalog in one place. (If locked in 84.2 instead, 84.2's author would design the convention against only the five existing entries, then 84.4 might find it doesn't extend cleanly.)

**Why cell-width math must be uniform over the `Beat` tree:** Per-entry magic numbers create the same maintenance liability as per-entry display names. The forward-compat requirement (multi-beat / syncopation epic) makes this load-bearing — any future pattern shape Adam approves should render correctly with no renderer code change. If the math cannot be uniform, that's a signal the renderer abstraction is wrong and Michael needs to make the call before 84.3 ships.

**Why ASCII sketches, not image files:** Same reasoning as 82.3 — image files add a binary review surface, don't diff, and rot. The implementation agents for 84.3/84.4 are LLMs; ASCII / prose sketches are what they actually read. "Sketch-fidelity" is the bar — exactly what `epic-84-context.md` calls for.

**Worst-case entry for visual distinguishability:** Whichever surviving entry has the deepest nesting AND the densest cell count. From the working list, the duplet-in-triplet entries (`* * .-.`, `* .-. *`, `.-. * *`) and the sextuplet (`. . . . . .`) compete for this — both render with significant cell density at picker-row scale. The doc's pairwise check pays special attention to the three duplet-in-triplet entries against each other (they share the same shape with different audible-position arrangements — high collision risk).

**Adam consultation framing — what to give him up front:** A single message naming (a) the Performance Principle as the design's north star, (b) the single-beat scope and "first audible excluded" inherited rule, (c) the engine's `.nested(Beat)` capability with a concrete example, (d) the working catalog with Michael's notation convention explained, (e) the four design questions (catalog, categorization, a11y phrasing, distinguishability). Adam may push back on the working scheme's buckets — record that pushback as part of the categorization decision.

## Verification

**Commands:**
- `grep -n "tod-tuplet-renderer-design" docs/planning-artifacts/*.md docs/implementation-artifacts/*.md` — ran 2026-06-04 (post-iteration-1; self-references grew from the *Review-iteration log* and the *Spec Change Log*). The new doc itself, this spec, `epic-84-context.md` (2 back-links — *Technical Decisions* + *UX & Interaction Patterns*), `tod-discipline-future-direction.md` (1 back-link in *Open questions*), `tod-initial-pattern-catalog.md` (1 back-link in header — added in iteration 1), `epics.md` (3 references in the Epic 84 / Story 84.1 / Story 84.3 narrative — pre-existing). All required back-links present, including the new predecessor forward-pointer.
- `grep -niE "displaced|swing" docs/planning-artifacts/tod-tuplet-renderer-design.md` — re-run after iteration 1; remains all use-mention occurrences (the *Settled terminology* paragraph stating the "displaced" prohibition; the *No swing* paragraph stating the swing prohibition; Adam's verbatim consultation explaining why `* *. .` is not swing). Zero matches in new descriptive copy.
- `grep -niE "(working scheme|decision deferred)" docs/planning-artifacts/tod-discipline-future-direction.md docs/implementation-artifacts/epic-84-context.md` — ran 2026-06-04. **Zero matches.** All four working-scheme questions this story owns are flipped to "locked in 84.1 → see doc" pointers.

**Manual checks:**
- Re-read the new doc end-to-end: the *Catalog* table has no empty cells, no TBDs; every pickable-position list excludes audible position 1; every entry's `Beat` builder shape is derivable from engine primitives; every entry has a `defaultOffsetNotePosition` with Adam-approved rationale.
- Re-read the *Cell-width math* section: the rule is expressed once and yields each worked example without per-entry constants; the multi-beat forward-compat sketch uses the same rule.
- Re-read the *Per-cell accessibility labels* section: the form is locked once; the worked labels for every cell of every surviving entry are present; no placeholder strings.
- Re-read the *At-scale renderings*: every surviving entry has a sketch at iPhone portrait AND Dynamic Type AX1; pairwise distinguishability outcome is recorded with the worst-case pairs (the three duplet-in-triplet entries) explicitly addressed; `pattern_13` vs `pattern_14` borderline-at-AX1 case mitigated via the accent-inside-bracket cue.
- Re-read the *Consultation with Adam* section: Adam's response is captured verbatim; one transcription clarification (Adam's working-scheme table placed `* - * -` in *Straight 16ths*, but Adam's own rule places it in *Gapped 16ths* — locked table is correct, noted inline in the consultation section so the discrepancy is visible).
- Re-read `tod-discipline-future-direction.md` and `epic-84-context.md`: the four questions this story owns are flipped to "locked in 84.1 → see doc" pointers in *Open questions to revisit*, *Technical Decisions*, and *UX & Interaction Patterns*.
- One acknowledged forward dependency surfaced in the doc: `TimingOffsetDetectionPattern.audibleToGrid` is documented as walking only top-level `.note` subdivisions today (the comment on line 24 of `TimingOffsetDetectionPattern.swift` explicitly excludes `.nested`). The design doc surfaces this as Adam's *Hidden Assumption #1* and assigns the recursive-walk fix to Story 84.3 as part of the renderer work. After iteration 1, the data-layer shape is now LOCKED in this doc (`GridPath = [Int]`); 84.3 implements against the locked shape rather than inventing it. The contradiction with the Epic 84 epic block's "no data-layer change" claim is reconciled in the doc.

## Suggested Review Order

**Entry point — the deliverable**

- The locked design doc the four downstream stages (84.2 / 84.3 / 84.4) consume.
  [`tod-tuplet-renderer-design.md`](../planning-artifacts/tod-tuplet-renderer-design.md)

**Catalog set + opaque id convention**

- Sequential `pattern_NN` convention with retirement-registry, governance, past-99 widening.
  [`tod-tuplet-renderer-design.md:37`](../planning-artifacts/tod-tuplet-renderer-design.md#L37)

- 15-entry catalog: id, notation, bucket, `Beat` builder shape, typed leaf sequence, pickable set, default.
  [`tod-tuplet-renderer-design.md:291`](../planning-artifacts/tod-tuplet-renderer-design.md#L291)

- Rename map for the five Epic-82 entries (`pattern_1111` → `pattern_01` etc.).
  [`tod-tuplet-renderer-design.md:48`](../planning-artifacts/tod-tuplet-renderer-design.md#L48)

**Cell-width math + data-layer shape**

- The uniform rule over the `Beat` tree, with all leaf-kind transitions defined (now forward-compat-complete after iteration 1).
  [`tod-tuplet-renderer-design.md:71`](../planning-artifacts/tod-tuplet-renderer-design.md#L71)

- `audibleToGrid: [GridPath]` recursive shape — locked here, not deferred to 84.3.
  [`tod-tuplet-renderer-design.md:21`](../planning-artifacts/tod-tuplet-renderer-design.md#L21)

- Worked examples per pattern shape (Epic-82, triplets, mixed-duration, nested, sextuplet).
  [`tod-tuplet-renderer-design.md:90`](../planning-artifacts/tod-tuplet-renderer-design.md#L90)

**Grouping indicators + accessibility**

- Bracket geometry: `@ScaledMetric(.caption2)`-locked thickness/offset/inset, continuous stroked path.
  [`tod-tuplet-renderer-design.md:152`](../planning-artifacts/tod-tuplet-renderer-design.md#L152)

- Per-cell `accessibilityLabel` form (locked rule) — extended for leading-nest accent to preserve VoiceOver parity.
  [`tod-tuplet-renderer-design.md:174`](../planning-artifacts/tod-tuplet-renderer-design.md#L174)

- Worked label table for every cell of every entry, English + German composition examples.
  [`tod-tuplet-renderer-design.md:200`](../planning-artifacts/tod-tuplet-renderer-design.md#L200)

**Categorization**

- Five locked buckets, single-axis (perceived host division + nesting), exclusive membership.
  [`tod-tuplet-renderer-design.md:249`](../planning-artifacts/tod-tuplet-renderer-design.md#L249)

- `* - * -` exception called out: bucketed *Gapped 16ths* by grid representation despite the 8ths perception.
  [`tod-tuplet-renderer-design.md:271`](../planning-artifacts/tod-tuplet-renderer-design.md#L271)

**Visual distinguishability**

- At-scale renderings — every entry at iPhone portrait + Dynamic Type AX1 with ASCII-is-illustrative disclaimer.
  [`tod-tuplet-renderer-design.md:339`](../planning-artifacts/tod-tuplet-renderer-design.md#L339)

- Pairwise check covering every within-bucket pair (22 pairs total); `pattern_13` vs `pattern_14` AX1 mitigation.
  [`tod-tuplet-renderer-design.md:506`](../planning-artifacts/tod-tuplet-renderer-design.md#L506)

**Adam's consultation (audit trail)**

- Verbatim consultation with Adam's per-entry verdicts, categorization revision, label form, default positions, and three Hidden Assumption flags.
  [`tod-tuplet-renderer-design.md:542`](../planning-artifacts/tod-tuplet-renderer-design.md#L542)

**Downstream notes**

- 84.2 hand-off: exhaustive code-surface enumeration for the id rename.
  [`tod-tuplet-renderer-design.md:692`](../planning-artifacts/tod-tuplet-renderer-design.md#L692)

- Behaviour change for Epic-82 catalog when 84.3 ships — per-entry visual diffs.
  [`tod-tuplet-renderer-design.md:719`](../planning-artifacts/tod-tuplet-renderer-design.md#L719)

- 84.3 hand-off: data-layer adjustment, accessibility tests, cell-width-math `static` function.
  [`tod-tuplet-renderer-design.md:733`](../planning-artifacts/tod-tuplet-renderer-design.md#L733)

- 84.4 hand-off: sectioned picker, catalog registration, German `--list` verification step.
  [`tod-tuplet-renderer-design.md:751`](../planning-artifacts/tod-tuplet-renderer-design.md#L751)

**Cross-links (flipped in 84.1)**

- `tod-discipline-future-direction.md` *Open questions* — new bullet pointing to the design doc.
  [`tod-discipline-future-direction.md:50`](../planning-artifacts/tod-discipline-future-direction.md#L50)

- `epic-84-context.md` *Technical Decisions* — working-scheme language replaced by "locked in 84.1" pointer.
  [`epic-84-context.md:35`](epic-84-context.md#L35)

- `tod-initial-pattern-catalog.md` header — forward pointer to the successor doc (added in iteration 1).
  [`tod-initial-pattern-catalog.md:3`](../planning-artifacts/tod-initial-pattern-catalog.md#L3)

**Review-iteration log + change log**

- Per-amendment audit trail for iteration 1's 20 patches (all `patch`-classified, no spec loopback).
  [`tod-tuplet-renderer-design.md:778`](../planning-artifacts/tod-tuplet-renderer-design.md#L778)

- Story spec's Spec Change Log — triggering findings, amendments outside frozen block, known-bad states avoided, KEEP instructions.
  [`84-1-tuplet-renderer-and-catalog-design.md:105`](84-1-tuplet-renderer-and-catalog-design.md#L105)
