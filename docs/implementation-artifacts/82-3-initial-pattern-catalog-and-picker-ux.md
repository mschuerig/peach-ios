---
title: 'Story 82.3: Initial pattern catalog and picker UX design'
type: 'chore'
created: '2026-06-03'
status: 'done'
baseline_commit: 'd1f3b77049c600bd49e3708b89a7ff030ae56759'
context:
  - '{project-root}/docs/planning-artifacts/tod-discipline-future-direction.md'
  - '{project-root}/docs/implementation-artifacts/82-1-offset-slot-as-setting.md'
  - '{project-root}/docs/implementation-artifacts/82-2-offset-note-terminology-decision.md'
  - '{project-root}/docs/implementation-artifacts/epic-82-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Epic 82 splits Settings UI evolution into 82.6 (controls) and 82.7 (catalog content), but both stories — and 82.5's `NamedPattern` data shape — are blocked on three unresolved design questions: *which* patterns ship in the initial catalog, *how* the catalog is categorized in the UI, and *how* a pattern previews inline (text glyphs vs. a small visual strip). Without an answer landed before 82.5 starts, the data model and the picker layout are either over-built for unknown content or under-built and reworked twice. The placeholder language already in `tod-discipline-future-direction.md` (e.g. "likely Straight / Gapped / Syncopated; not decided") names this gap explicitly and assigns it here.

**Approach:** A no-code story that produces one written design doc at `docs/planning-artifacts/tod-initial-pattern-catalog.md`, owned by this story and treated as the source of truth read by 82.5–82.7. The doc enumerates the initial catalog (each entry with stable id, EN+DE name, notation string, per-slot kind, and pickable-slot list), records the UI categorization decision with rationale, records the preview-rendering decision (text glyphs vs. visual strip) on the basis of localization cost / accessibility / Dynamic Type, and includes sketch-level mocks (ASCII or prose-level — not pixel-perfect) of the pattern picker and the rest-aware slot picker. `agent-music-domain-expert` (Adam) is consulted up front for the pattern selection and categorization recommendation; the doc records his response verbatim and the validation against the three Performance-Principle / Epic-82 constraints. No code, no SwiftUI, no `.xcstrings` changes — every implementation move belongs to 82.5–82.7.

## Boundaries & Constraints

**Always:**
- Decide before recording. First step is a fresh `agent-music-domain-expert` consultation framed with: (a) the Performance-Principle requirement that TOD probe varied rhythmic contexts users can perform their best in, (b) the engine constraints (variable-length, gaps, syncopation all fine; **no tuplets** in the initial catalog), and (c) the offset-slot must land on an audible (non-rest) note. Adam's response is captured verbatim in the design doc's *Consultation* section.
- Each catalog entry in the doc records the full quadruple: **stable id** (snake_case, kebab-free, suitable for an `@AppStorage` value and a Swift identifier), **notation string** (the stylized inline preview, e.g. `* - * *`), **per-slot kind** (`.note` or `.rest`, in order), and **pickable-position list** (1-based, audible-only — see *Spec Change Log* entry 2026-06-03 for the EN/DE name field removal and the pickable-rule narrowing). The visual *is* the pattern's identity per the rendering decision; no per-entry display name ships in either language.
- Categorization decision is recorded with: the chosen scheme (the design-direction doc's working hypothesis is *Straight / Gapped / Syncopated*; confirm or replace), why, and what an agent in 82.6 should do if a new pattern doesn't cleanly fit (rule of thumb, not an algorithm).
- Preview-rendering decision is recorded as **one** choice — text glyphs, a small visual strip, or any third option that better fits the established visual vocabulary — with the explicit trade-off across: localization cost (glyphs need translation? — answer in doc), VoiceOver readability (a glyph string read as "asterisk hyphen asterisk asterisk" is unacceptable; the decision must address the accessibility label either way), and Dynamic Type scaling. Whichever wins, the doc states what the corresponding `.accessibilityLabel` text is. (Amended from a strict binary — see *Spec Change Log* 2026-06-03.)
- Sketch mocks: ASCII / prose-level depictions of (i) the pattern-picker row as it appears in `SettingsScreen` and (ii) the rest-aware scalable slot picker for the *worst case* pattern in the catalog (the one with the most rests / most slots), showing the visual de-emphasis treatment for rest slots. No pixel-perfect SwiftUI rendering; no Figma; no image files.
- Today's pattern (straight 16ths, four equal note slots, offset on the third by default) is included in the catalog with a stable id; the doc states explicitly that 82.7 must use this id as the migration target so existing settings preserve behavior.
- Settled terminology applies end-to-end: *Offset Note*, *Offset Note Position*, code identifier `offsetNotePosition`, German *Position der Offset-Note*. The word *displaced* must not appear in any new copy. *Slot* may appear only when describing the data structure, never as user-facing vocabulary (per `tod-discipline-future-direction.md` § *Vocabulary boundary*).
- Cross-link the new doc back into `tod-discipline-future-direction.md` § *Open questions to revisit before building the future expansion* — the three bullets owned by this story (catalog UI categorization, preview rendering, slot-with-rests presentation) are flipped from *open* to *resolved* with a link to the new doc.
- Cross-link the new doc back into `epic-82-context.md` § *UX & Interaction Patterns* — the preview-rendering "Decision deferred to 82.3" bullet is flipped to the recorded decision.

**Ask First:**
- If Adam's catalog recommendation includes more than ~6 patterns or proposes a longer-than-beat pattern whose beat-builder shape is non-obvious to express as a single `Beat` (with `.nested(Beat)` for the secondary beat) — HALT and surface for human triage. The initial catalog should stay small enough that 82.7's per-entry tests do not become an aggregation chore; if Adam argues for a larger set, that's a human decision.
- If the preview-rendering trade-off doesn't yield a single clear winner — e.g. both options are equally good under the stated criteria — HALT and surface so Michael picks rather than agent picks.
- If a candidate categorization scheme cannot place an Adam-recommended pattern (e.g. a pattern is neither cleanly Straight nor Gapped nor Syncopated) — HALT and surface before forcing a fit.

**Never:**
- No code changes anywhere in the repo. No new SwiftUI files. No edits to `TimingOffsetDetectionSession.swift`, `TimingOffsetDetectionSettings.swift`, `TimingOffsetDetectionSettingsKeys.swift`, `TimingOffsetDetectionUserSettings.swift`, `TimingOffsetDetectionOffsetNotePositionSettingsSection.swift`, or `Localizable.xcstrings`.
- No new `.xcstrings` entries via `bin/add-localization.swift`. The doc records the German wording 82.7 will register; the actual registration is 82.7's job.
- No `NamedPattern` Swift type sketched in code — its data shape is described in prose / a table in the doc, so 82.5 derives the type from the design.
- No tuplet patterns in the initial catalog. The catalog domain layer in 82.5 stays tuplet-capable by construction (because `Beat` is), but the doc must state explicitly that the renderer 82.6 ships remains equal-cell, and tuplets become a follow-up epic.
- No re-litigation of the *Offset Note* terminology — settled by 82.2. No re-litigation of *whether* the slot widget should be rest-aware — already a project decision per `tod-discipline-future-direction.md`.
- No arbitrary user-defined patterns. The catalog is curated.
- No marketing copy in either language. No motivational framing, no superlatives, no "challenge yourself" register — describe what the pattern is and what it probes.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Adam recommends a small catalog (~4–6 patterns) covering straight + gapped + syncopated | Fresh consultation returns a list within the size guidance | Record verbatim, validate, write the doc; ids/notation/per-slot kinds derived per entry | N/A |
| Adam recommends only straight + gapped (no syncopation) | Consultation argues syncopation isn't musically motivated for the initial catalog | Record Adam's reasoning; categorization scheme drops the unused bucket (e.g. *Straight / Gapped* only); doc states the smaller scheme is intentional | N/A |
| Adam recommends >6 patterns or a longer-than-beat pattern with non-obvious beat-builder shape | Consultation returns a large or structurally novel set | Halt per Ask First; on agreement, record the larger set with explicit notes for 82.7's test scope | Halt-and-ask, not silent inclusion |
| Preview rendering: text glyphs win | Trade-off concludes glyphs are equal or better on all three criteria | Record decision + the VoiceOver-friendly `.accessibilityLabel` template (e.g. "Note, rest, note, note") that 82.6 implements | N/A |
| Preview rendering: visual strip wins | Trade-off concludes a small strip beats glyphs on accessibility or Dynamic Type | Record decision + the strip's visual spec at a sketch level (cell size relative to Dynamic Type, color treatment for note vs. rest) | N/A |
| Preview rendering: tie | Both options are equally good | Halt per Ask First | Halt-and-ask |
| Categorization mismatch | A recommended pattern doesn't fit Straight / Gapped / Syncopated | Halt per Ask First; on agreement, either revise the scheme or drop the pattern | Halt-and-ask |

</frozen-after-approval>

## Code Map

- `docs/planning-artifacts/tod-initial-pattern-catalog.md` — **NEW**. The design doc this story produces. Sections: *Purpose*, *Constraints*, *Catalog* (table — one row per entry with id / EN / DE / notation / per-slot kind / pickable positions), *Categorization*, *Preview Rendering*, *Picker Sketches* (ASCII), *Consultation with Adam* (verbatim), *Constraint Check*, *Notes for 82.5–82.7* (what each downstream story should derive from the doc).
- `docs/planning-artifacts/tod-discipline-future-direction.md` — under § *Open questions to revisit before building the future expansion*, flip the three bullets owned by this story (catalog UI categorization, preview rendering, slot-with-rests presentation) from *open* to *resolved → see `tod-initial-pattern-catalog.md`*. Other sections untouched (82.4 owns the placeholder cleanup elsewhere).
- `docs/implementation-artifacts/epic-82-context.md` — under § *UX & Interaction Patterns*, flip the "Preview rendering for patterns. Decision deferred to 82.3" bullet to the recorded decision with a link. Other bullets untouched.

## Tasks & Acceptance

**Execution:**
- [x] Consult `agent-music-domain-expert` (Adam) framing the three inputs from *Always* clause 1; record the response verbatim in the doc's *Consultation* section.
- [x] Validate Adam's recommendation against the three constraints (Performance Principle / no tuplets / offset on audible note) in one short paragraph each.
- [x] Draft the *Catalog* table — one row per entry, all six columns filled. Confirm every pickable-slot list matches the `.note` positions in the per-slot kind column.
- [x] Decide and record the *Categorization* scheme with rationale and the rule of thumb for placing future additions.
- [x] Decide and record the *Preview Rendering* with the three-criterion trade-off and the corresponding accessibility label spec.
- [x] Sketch the *Pattern Picker* row and the *Rest-Aware Slot Picker* for the worst-case pattern (ASCII / prose level).
- [x] Write the *Notes for 82.5–82.7* section enumerating: what 82.5 derives (data shape / id format / pickable-slot semantics), what 82.6 derives (picker chrome / preview rendering / accessibility), what 82.7 derives (per-entry content / migration id).
- [x] Cross-link from `docs/planning-artifacts/tod-discipline-future-direction.md` and `docs/implementation-artifacts/epic-82-context.md` per Code Map.
- [x] Verification: run `grep -n "tod-initial-pattern-catalog" docs/planning-artifacts/ docs/implementation-artifacts/` and confirm at least three matches (the new doc itself, plus both back-links). Capture output in *Verification*.

**Acceptance Criteria:**
- Given an agent picking up 82.5, when they look for the `NamedPattern` data shape, then they find one canonical source — `tod-initial-pattern-catalog.md` — with the per-slot kind, id format, and pickable-slot semantics fully specified.
- Given an agent picking up 82.6, when they look for the preview rendering and the rest-aware slot treatment, then they find a single recorded decision with the accessibility label spec and a sketch.
- Given an agent picking up 82.7, when they look for the catalog content, then they find a complete table with every entry's id, notation, per-slot kind, and pickable positions — no placeholders, no TBDs. (No EN/DE name field — see *Spec Change Log* 2026-06-03.)
- Given the design-direction doc and the epic-context doc after this story, when an agent searches for "deferred to 82.3" or "decision deferred", then no matches remain for the three questions this story owns.
- Given the new doc end-to-end, when read, then it contains zero occurrences of the word "displaced" in any new copy and zero user-facing uses of "slot" outside the explicit *Vocabulary boundary* note.

## Spec Change Log

### 2026-06-03 — Review iteration 1

**Triggering findings (deduplicated across blind hunter / edge-case hunter / acceptance auditor):**

- **A. EN/DE pattern names dropped despite frozen Always #2.** Adam's round-1 recommendation included English names; Michael's round-2 directive ("we don't need names for the patterns and we don't need names for the positions either") removed them. The doc reflects Michael's directive. Acceptance auditor: CONDITIONAL PASS pending frozen-block amendment.
- **B. Round-3 pickable rule (position 1 never pickable) is a data-model expansion the spec did not anticipate.** The rule emerged from Michael's round-3 question ("Does it ever make sense to offset the first note?") and Adam's answer. Audit trail captured verbatim in the design doc.
- **C. Preview-rendering chose a third option (reuse `TimingDotView` at smaller scale) outside the spec's binary (text glyphs vs visual strip).** Spec's framing was too narrow; the third option is materially better (inherits accent encoding, keeps Settings/training-screen vocabulary in lockstep).
- **D. Migration-shim language was self-contradictory** — design doc said "no `@AppStorage` migration shim" while describing a pattern-aware `clamped(_:)` helper that functionally migrates on read.
- **E. Multiple under-specified handoffs** to 82.5/82.6/82.7: `pattern_NNNN` MSB ambiguity, cross-pattern `offsetNotePosition` semantics (global vs per-pattern), single-pickable-pattern picker UX, anchor-cell VoiceOver behavior, rest-cell focusability, Dynamic Type behavior, sketch-ASCII inconsistency (variable-spacing row sketch vs uniform-cell slot picker), accessibility-label phrasing left open, `pattern_1010` engine encoding vs perceptual description mismatch, Beat-builder rest-target precondition, vocabulary scope.
- **F. Categorization rule loses subdivision-density distinction** (`pattern_1010` and `pattern_1111` both classed *Straight* despite different perceptual densities).

**Amendments inside `<frozen-after-approval>` (authorized by Michael, 2026-06-03):**

- **Always #2 amended from sextuple to quadruple.** EN/DE name fields removed per Michael's round-2 directive; remaining required fields are stable id / notation / per-slot kind / pickable-position list.
- **Always #4 amended.** Preview-rendering decision is no longer constrained to a binary choice between text glyphs and visual strip; the design may choose any option that better fits the established visual vocabulary (third-option case).
- **AC3 updated** to remove EN/DE name expectations.

**Amendments outside the frozen block (per bad_spec resolution path):**

- Design doc's *Catalog* table replaced "Audible positions (grid)" header with explicit grid→audible mapping per row; added `pattern_NNNN` worked example to the Stable-ID convention.
- Design doc's *Migration target* section rewritten — locks `@AppStorage` shape (one global `selectedPatternId`, one global `offsetNotePosition`); locks reset-on-pattern-change semantics (never preserve old value across patterns); locks pattern-aware clamp as sole read path (every consumer must go through it); reconciles "no migration shim" with "clamp does defence-in-depth on read."
- Design doc's *Categorization* section gained the subdivision-density clarification and the equal-cell-renderer-at-non-K=4 note.
- Design doc's *Preview Rendering* section gained: uniform-width cell-container rule (HStack+EmptyView collapse trap); Dynamic Type via `@ScaledMetric(relativeTo: .caption2)` with explicit "spec the wrap behavior in 82.6, don't auto-wrap silently"; static-vs-`litCount`-opacity resolution; locked accessibility-label phrasing with per-entry table marking the anchor as `"Accent"`.
- Design doc's *Pickable-position rule* section gained: anchor-cell a11y behavior (focusable, announces "Anchor note, not selectable", rejects activation); rest-cell a11y behavior (not focusable); slot-picker label convention with K = audible count, not grid count.
- Design doc gained a new *Single-pickable patterns* subsection (pre-selected, locked, no-op tap; pattern picker is the only meaningful control).
- Design doc's *Picker Sketches* — pattern-picker row sketch redrawn with uniform cell columns for consistency with the slot-picker sketch.
- Design doc's *Notes for 82.5–82.7* — Beat-builder gained a `precondition(...)` requirement that translated grid index addresses a `.note` subdivision; per-entry test scope gained a catalog-wide invariant test (`pattern.pickable.contains(1) == false`); unknown-pattern-id fallback specified (fall back to `pattern_1111`, reset position, log at `.warning`).
- Design doc's *Consultation* — round-1 section prefixed with an editorial gloss marking it as superseded; round-2 *Vocabulary scope* note added to clarify "on the half-beat" is K=4-specific.
- Design doc's per-entry default rationale for `pattern_1101` honestly acknowledges the tie between audible-2 and audible-3 (both equidistant from the rest at grid 3) instead of arguing one is closer to the perceptual middle than the other.
- Design doc's encoding note for `pattern_1010` clarifies the 4-subdivision engine representation vs the "8ths feel" audible perception.

**Known-bad states avoided:**

- 82.5 inventing display names that nobody validated and 82.7 needing German translations for them.
- 82.5/82.6/82.7 implementing different views of `offsetNotePosition` semantics (per-pattern vs global; preserve-vs-reset on pattern change) — would split the test suite and reintroduce the kind of UI/audio divergence 82.1 iteration 1 fixed.
- A 82.5 author reading the `pattern_NNNN` convention with LSB-first endianness and registering patterns with mirrored notation.
- Direct `@AppStorage` reads bypassing the clamp helper (82.1 iteration 1's bug, again).
- An off-by-one in 82.5's audible→grid translation silently no-op-ing the offset (offset on `.rest` is dropped by `Beat.events(...)`).
- A naive `HStack(spacing:)` + `EmptyView` for rest cells collapsing the column alignment and mis-rendering pattern shapes.
- VoiceOver users unable to distinguish anchor from regular notes, or unable to perceive pattern shape (rests invisible to the rotor without the parent-level label).
- A future contributor re-including audible position 1 in a new pattern's pickable set with no test catching it.

**KEEP (re-derivation must preserve):**

- The five-pattern catalog and its IDs (`pattern_1111`, `pattern_1011`, `pattern_1101`, `pattern_1010`, `pattern_1001`).
- The pickable-position rule (first audible note never pickable) and its grounding in Adam's round-3 perceptual analysis.
- Reuse of `TimingDotView` visual vocabulary in the Settings preview, scaled smaller.
- Categorization scheme: *Straight / Gapped / (Syncopated — reserved)*; UI ships flat for the five-entry catalog.
- No tuplets in the initial catalog; equal-cell renderer in 82.6.
- Per-pattern defaults from the table (3 / 2 / 2 / 2 / 2 in audible-position terms); not from a single rule; subject to playtest revision.
- All cross-links into `tod-discipline-future-direction.md` and `epic-82-context.md`.

## Design Notes

**Why this is a separate no-code story rather than folded into 82.5 or 82.7:** 82.5 introduces the `NamedPattern` *type*, not its content; 82.7 ships the content. The pattern-set and the picker UX are upstream of both — if they're decided inside 82.5, the type shape is biased by whichever pattern 82.5's author imagines; if they're decided inside 82.7, 82.6's picker is built without the worst-case pattern in mind and gets reworked. Landing the decisions here, before either, is the cheaper sequence — same reasoning as 82.2 sitting upstream of 82.4.

**Why the design doc lives in `docs/planning-artifacts/` rather than `docs/implementation-artifacts/`:** Planning artifacts are the inputs to implementation; this doc is read by three implementation stories and lives across them. The spec file (this file) belongs in `docs/implementation-artifacts/` because it's the story spec; the *output* belongs alongside `tod-discipline-future-direction.md` because it's a long-form design direction in the same vein.

**Categorization scheme working hypothesis:** *Straight / Gapped / Syncopated* — matches `tod-discipline-future-direction.md` § *Open questions* and is what `epic-82-context.md` § *UX & Interaction Patterns* anticipates. The story keeps it as a hypothesis until Adam confirms; if Adam argues for *Straight / Gapped* only (no syncopation in the initial catalog), the scheme shrinks accordingly. The categorization shows up in 82.6's pattern picker as section grouping; one entry per row, sections collapsed by default if Adam recommends syncopated patterns that need visual separation.

**Preview rendering — anticipated trade-off shape:** Text glyphs (`* - * *`) win on localization cost (zero — the same glyph string ships in both languages) but lose on VoiceOver readability unless paired with an explicit label override (which they need anyway). A visual strip wins on at-a-glance readability and scales naturally with Dynamic Type via `@ScaledMetric`, but needs the same accessibility label override. Both options need the override; the deciding axis is therefore likely **visual scan-ability at small sizes** and **consistency with `RhythmGapPositionsSettingsSection`** (which uses textual cell labels). The recorded decision must name the deciding axis, not just the winner.

**Worst-case pattern for the slot-picker sketch:** Whichever Adam-recommended pattern has the most rests AND the most slots. If Adam recommends a longer-than-beat pattern with mixed notes and rests, that one. If not, the densest gapped pattern (e.g. `* - - *` has 2 rests, 4 slots, 2 pickable positions) is sufficient to specify the de-emphasis treatment.

**Why no `NamedPattern` Swift type in this story:** The data shape is fully specified in prose / a table. 82.5's author derives the Swift type from that — that's their job (Code Map / Tasks / Acceptance in 82.5's spec). Sketching the type here means 82.5 is reduced to transcription, which mis-allocates the design and the implementation across stories.

**Why not produce mocks as image files:** Image files add a binary review surface and need updating in lockstep with text, which doesn't happen. ASCII / prose sketches are diff-friendly, readable by the LLM agents implementing 82.6, and accurate enough to seed a sketch-fidelity implementation — exactly what `epic-82-context.md` calls for ("not pixel-perfect").

**Cross-link discipline:** Both back-links (in `tod-discipline-future-direction.md` and `epic-82-context.md`) are mandatory because both docs are loaded by future agents. The design-direction doc names this story by number ("Owned by 82.3"); the epic-context doc names the deferral. Flipping both is what makes the new doc discoverable.

## Verification

**Commands:**

- `grep -n "tod-initial-pattern-catalog" docs/planning-artifacts/*.md docs/implementation-artifacts/*.md` — ran 2026-06-03 (post-review-iteration-1; spec self-references grew from the Spec Change Log entry). 13 matches: `epics.md` (1), `tod-discipline-future-direction.md` (3 — back-links + strikethroughs), `epic-82-context.md` (1 — back-link), this spec (8 — self-references including change-log entry). Both required back-links present.

- `grep -nE "(deferred to 82\.3|Owned by 82\.3)" docs/planning-artifacts/*.md docs/implementation-artifacts/*.md` — ran 2026-06-03. Matches in `tod-discipline-future-direction.md` lines 54-55 are inside `~~...~~` strikethrough wrappers showing the resolved state (visible audit trail). Matches in this spec are inside the spec's own description of what it resolves. `epic-82-context.md` has **zero matches**. No active deferrals remain.

- `grep -niE "displaced" docs/planning-artifacts/tod-initial-pattern-catalog.md` — ran 2026-06-03; **zero matches**.

- `grep -niE "downbeat" docs/planning-artifacts/tod-initial-pattern-catalog.md` — ran 2026-06-03; seven matches, all in (a) use-mention contexts describing the prohibition (the *Consultation* preamble, the *Discarded alternatives* entry), or (b) verbatim quotes from rounds 1-3 of the consultation preserved as audit trail. **Zero matches in new descriptive copy.** The vocabulary correction caught at line 101 of an earlier draft (own-copy use of "downbeat") was fixed before this verification run.

**Manual checks:**
- Re-read the new doc end-to-end: the *Catalog* table has no empty cells, no TBDs, every pickable position is in the audible range and excludes the metric anchor (position 1).
- Re-read the *Consultation with Adam* section: rounds 1 and 2 captured verbatim; Michael's six pushback points quoted verbatim; round-3 Adam answer on position-1-pickability captured verbatim; the data-model consequences (pickable-set rule, 82.1 reset-from-position-1 migration) traced to the round-3 answer.
- Re-read `tod-discipline-future-direction.md` § *Open questions*: all three bullets owned by this story now strike through the original open-question wording and point at the new doc.
- Re-read `epic-82-context.md` § *UX & Interaction Patterns*: the preview-rendering bullet records the `TimingDotView`-reuse decision with a link.

## Suggested Review Order

**Entry point — the design doc**

- Start here: this is the artifact the story produces, the source of truth for 82.5–82.7.
  [`tod-initial-pattern-catalog.md`](../planning-artifacts/tod-initial-pattern-catalog.md)

**Catalog model**

- The five-pattern table with grid→audible mapping, pickable sets, and per-entry defaults.
  [`tod-initial-pattern-catalog.md:36`](../planning-artifacts/tod-initial-pattern-catalog.md#L36)

- `pattern_NNNN` ID convention plus the worked example for unambiguous endianness.
  [`tod-initial-pattern-catalog.md:44`](../planning-artifacts/tod-initial-pattern-catalog.md#L44)

- Per-entry default-position reasoning (not a single rule; shape-dependent).
  [`tod-initial-pattern-catalog.md:50`](../planning-artifacts/tod-initial-pattern-catalog.md#L50)

**Migration semantics (the biggest patch)**

- `@AppStorage` shape locked: global `selectedPatternId`, global `offsetNotePosition`, reset-on-pattern-change.
  [`tod-initial-pattern-catalog.md:58`](../planning-artifacts/tod-initial-pattern-catalog.md#L58)

- Pattern-aware clamp is the sole read path — defence against the 82.1-iteration-1 bug shape.
  [`tod-initial-pattern-catalog.md:64`](../planning-artifacts/tod-initial-pattern-catalog.md#L64)

**Pickable-position rule (the round-3 finding)**

- The metric anchor (first audible note) is never pickable; the perceptual rationale.
  [`tod-initial-pattern-catalog.md:122`](../planning-artifacts/tod-initial-pattern-catalog.md#L122)

- Slot-picker chrome for non-pickable anchor vs rest vs pickable; per-cell a11y semantics.
  [`tod-initial-pattern-catalog.md:133`](../planning-artifacts/tod-initial-pattern-catalog.md#L133)

- Single-pickable patterns (`pattern_1010`, `pattern_1001`) — pre-selected, locked, no-op tap.
  [`tod-initial-pattern-catalog.md:144`](../planning-artifacts/tod-initial-pattern-catalog.md#L144)

**Preview rendering — reuse `TimingDotView`**

- The decision and its three-axis trade-off (against text glyphs, against a custom strip).
  [`tod-initial-pattern-catalog.md:90`](../planning-artifacts/tod-initial-pattern-catalog.md#L90)

- Locked accessibility-label phrasing with worked examples for all five entries.
  [`tod-initial-pattern-catalog.md:105`](../planning-artifacts/tod-initial-pattern-catalog.md#L105)

- ASCII sketches — pattern picker rows and worst-case slot picker; uniform-cell layout.
  [`tod-initial-pattern-catalog.md:160`](../planning-artifacts/tod-initial-pattern-catalog.md#L160)

**Categorization**

- Two-bucket *Straight / Gapped* with *Syncopated* reserved; rule of thumb for additions.
  [`tod-initial-pattern-catalog.md:80`](../planning-artifacts/tod-initial-pattern-catalog.md#L80)

**Consultation with Adam (audit trail)**

- Round 1 with the explicit "superseded" editorial gloss at the top.
  [`tod-initial-pattern-catalog.md:218`](../planning-artifacts/tod-initial-pattern-catalog.md#L218)

- Your six pushback points (verbatim) and Adam's round-2 corrections.
  [`tod-initial-pattern-catalog.md:236`](../planning-artifacts/tod-initial-pattern-catalog.md#L236)

- Round 3 — the position-1-pickability question and answer that reshaped the data model.
  [`tod-initial-pattern-catalog.md:266`](../planning-artifacts/tod-initial-pattern-catalog.md#L266)

**Notes for downstream stories**

- 82.5: data shape, indexing, pickable metadata, ID convention, Beat-builder precondition, clamp helper.
  [`tod-initial-pattern-catalog.md:300`](../planning-artifacts/tod-initial-pattern-catalog.md#L300)

- 82.6: picker chrome, preview rendering, a11y rules, Dynamic Type, single-pickable case.
  [`tod-initial-pattern-catalog.md:310`](../planning-artifacts/tod-initial-pattern-catalog.md#L310)

- 82.7: catalog content registration, per-entry test scope, catalog-wide invariant test.
  [`tod-initial-pattern-catalog.md:319`](../planning-artifacts/tod-initial-pattern-catalog.md#L319)

**Cross-links (flipped from open → resolved)**

- `tod-discipline-future-direction.md` § *Open questions* — three bullets struck through and re-routed.
  [`tod-discipline-future-direction.md:54`](../planning-artifacts/tod-discipline-future-direction.md#L54)

- `epic-82-context.md` § *UX & Interaction Patterns* — preview-rendering bullet flipped.
  [`epic-82-context.md:48`](epic-82-context.md#L48)

**Spec change log — the review-iteration-1 trail**

- Triggering findings, amendments inside and outside the frozen block, known-bad states avoided, KEEP instructions.
  [`82-3-initial-pattern-catalog-and-picker-ux.md:99`](82-3-initial-pattern-catalog-and-picker-ux.md#L99)
