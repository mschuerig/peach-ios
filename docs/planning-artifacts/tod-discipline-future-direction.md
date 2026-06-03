# TOD Discipline — Future Direction & Offset Note Position

**Status:** Design direction (informational, not a story spec)
**Date:** 2026-06-03
**Context:** UX discussion (Sally) on extending Timing Offset Detection beyond its current fixed third-of-four-16th-notes layout. Captured to inform the *Offset Note Position* setting and to keep future expansion cheap.
**Implemented by:** Epic 82 — *Find the Off Note — TOD Pattern & Slot Flexibility* (`docs/planning-artifacts/epics.md`). Tuplets remain deferred to a follow-up epic per the call below.

## Terminology

**Term:** *Offset Note* (noun). **Settings-label form:** *Offset Note Position* (1-based). **Code identifier:** `offsetNotePosition`. **German:** *Position der Offset-Note* with body copy *Wähle, welche der vier Sechzehntelnoten den Timing-Offset trägt.*

**Decided:** 2026-06-03 (story 82.2) after re-consulting `agent-music-domain-expert` (Adam).

**Rationale (against each constraint):**

- *Unintentional-error framing.* "Offset" names the *symptom* — a measurable temporal deviation from the implied grid — not a *gesture*. That keeps the discipline pointed at temporal fact rather than at deliberate musical choice. Directional pedagogical nouns ("rushed", "dragged", "lagging") pre-commit to a polarity and were rejected; judgmental nouns ("errant", "misplaced", "wayward") assert wrongness the discipline does not assert.
- *No collision with rhythmic displacement.* "Offset" is borrowed from engineering/measurement, not from music theory. It arrives at the user without the music-theory luggage that "displaced" carries (intentional, grid-aware metric shift). The "no displaced" guardrail stays in place — see `feedback_tod_no_displaced_term` in the auto-memory — to stop future contributors from translating "offset" back into "displaced".
- *Natural EN + informal DE.* "Offset Note Position" reads cleanly in an English Settings label. "Offset" is established Anglo-loan vocabulary in technical-musical German (cf. *Offset-Druck*, *Timing-Offset*); *Versatz / Versatznote* would be more native but sounds slightly archaic and risks confusion with grace-note adjacent vocabulary. The shipped German with informal *du* (*Wähle …*) holds.

**Vocabulary boundary:** "Slot" remains a code/engineering term only — engineering layers in 82.5–82.6 may speak of *pickable slots* and *rest slots* in the pattern data structure, but the user-facing noun for the chosen audible position is always *Note*. The user picks an *Offset Note Position*; the code addresses *slots* within the pattern.

## Future vision (not now)

TOD will expand from a fixed pattern to a settings model with two independent axes:

- **Pattern** — chosen from a curated catalog (no arbitrary user-defined patterns). Catalog will include:
  - Patterns longer than one beat / more than four notes.
  - Patterns with gaps (rests), e.g. `* - * *`, `* * - *`, `* - * -`, `* - - *`.
  - Syncopated patterns.
  - Tuplets (triplets and beyond).
- **Offset Note Position** — which audible note in the chosen pattern carries the timing offset. Constrained to playable positions (rest slots cannot carry an offset).

Two separate widgets. The pickable positions depend on the pattern; changing the pattern invalidates the current selection.

## Near-term step — Offset Note Position as a setting

Story 82.1 shipped this step. Guidance recorded here so future expansion stays cheap:

- **Frame the widget generically.** Not "third of four" — "which note carries the offset." Today's pattern is fixed (straight 16ths) so the widget shows four positions; the same widget should scale to N without redesign.
- **Visual reference: the Continuous Rhythm Matching widget.** Provisional reuse, fine for now.
- **Organize Settings as if pattern were a (currently fixed) setting in the same section.** Even non-interactive today — future expansion then fills existing space rather than rearranging.
- **Design the position-rendering primitive with rests in mind.** Even though no rests exist today, the visual vocabulary should already accommodate a "non-playable slot" appearance so adding rests later becomes data, not redesign.
- **Equal-cell layout is fine for now; flag it for tuplets.** When tuplets land, the row of equal cells may need to become a proportional timeline. Do not over-engineer today.

## Open questions to revisit before building the future expansion

- ~~Pattern-catalog UI categorization (likely *Straight / Gapped / Syncopated / Tuplet*; not decided). Owned by 82.3.~~ **Resolved by 82.3** → see [`tod-initial-pattern-catalog.md` § *Categorization*](tod-initial-pattern-catalog.md#categorization). Scheme is *Straight / Gapped / (Syncopated — reserved)*; UI ships flat in 82.6.
- ~~Pattern preview rendering (text glyphs like `* - * *` vs. proportional timeline strip). Owned by 82.3.~~ **Resolved by 82.3** → see [`tod-initial-pattern-catalog.md` § *Preview Rendering*](tod-initial-pattern-catalog.md#preview-rendering). Reuse `TimingDotView`'s visual vocabulary at a smaller scale.
- ~~How slot selection presents when the pattern has rests — disabled-tap state, visual contrast, accessibility labels. Owned by 82.6.~~ **Specified by 82.3** → see [`tod-initial-pattern-catalog.md` § *Pickable-position rule*](tod-initial-pattern-catalog.md#pickable-position-rule) and § *Picker Sketches*. 82.6 implements the picker against the specified treatment.

## References

- **Epic 82 — Find the Off Note — TOD Pattern & Slot Flexibility** (this doc's implementing epic; 7 stories, tuplets deferred).
- Epic 81 — Settings screen control taxonomy (stories 81.1–81.3 establish the control vocabulary this widget will draw from).
- Stories 48.1–48.3 — original TOD implementation.
- Story 75.11 — rhythm-to-timing naming alignment.
- Story 76.4 — build-gated timing disciplines (TOD ships only under `PEACH_RESEARCH`).
- `docs/planning-artifacts/rhythm-training-spec.md` — rhythm/timing training spec.
- `Peach/Core/Audio/SequencerTypes.swift` — `Beat` / `Subdivision` engine layer (already tuplet- and rest-capable).
