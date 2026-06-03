# TOD Discipline — Future Direction & Near-Term Slot Selection

**Status:** Design direction (informational, not a story spec)
**Date:** 2026-06-03
**Context:** UX discussion (Sally) on extending Timing Offset Detection beyond its current fixed third-of-four-16th-notes layout. Captured to inform the upcoming "which slot carries the offset" setting and to keep future expansion cheap.
**Implemented by:** Epic 82 — *Find the Off Note — TOD Pattern & Slot Flexibility* (`docs/planning-artifacts/epics.md`). Tuplets remain deferred to a follow-up epic per the call below.

## Resolved: terminology

**Term:** *Offset Note* (noun). **Settings-label form:** *Offset Note Position* (1-based). **Code identifier:** `offsetNotePosition`. **German:** *Position der Offset-Note* with body copy *Wähle, welche der vier Sechzehntelnoten den Timing-Offset trägt.*

**Decided:** 2026-06-03 (story 82.2) after re-consulting `agent-music-domain-expert` (Adam).

**Rationale (against each constraint):**

- *Unintentional-error framing.* "Offset" names the *symptom* — a measurable temporal deviation from the implied grid — not a *gesture*. That keeps the discipline pointed at temporal fact rather than at deliberate musical choice. Directional pedagogical nouns ("rushed", "dragged", "lagging") pre-commit to a polarity and were rejected; judgmental nouns ("errant", "misplaced", "wayward") assert wrongness the discipline does not assert.
- *No collision with rhythmic displacement.* "Offset" is borrowed from engineering/measurement, not from music theory. It arrives at the user without the music-theory luggage that "displaced" carries (intentional, grid-aware metric shift). The "no displaced" guardrail stays in place — see `feedback_tod_no_displaced_term` in the auto-memory — to stop future contributors from translating "offset" back into "displaced".
- *Natural EN + informal DE.* "Offset Note Position" reads cleanly in an English Settings label. "Offset" is established Anglo-loan vocabulary in technical-musical German (cf. *Offset-Druck*, *Timing-Offset*); *Versatz / Versatznote* would be more native but sounds slightly archaic and risks confusion with grace-note adjacent vocabulary. The shipped German with informal *du* (*Wähle …*) holds.

**Vocabulary boundary:** "Slot" remains a code/engineering term only — engineering layers in 82.5–82.6 may speak of *pickable slots* and *rest slots* in the pattern data structure, but the user-facing noun for the chosen audible position is always *Note*. The user picks an *Offset Note Position*; the code addresses *slots* within the pattern.

**Implementation note:** The English and German strings shipped via story 82.1 already match the settled term; no string edits are required. Code identifiers were introduced under the same term in 82.1 and need no rename. The terminology rename in story 82.4 therefore focuses on removing the "placeholder, see 82.2" caveats from code comments, test names, and this doc's *Near-term step* / *Future vision* sections.

## Future vision (not now)

> **Note:** Placeholder-era language below (e.g. "**Offset slot**", "Slot selection depends on the pattern") predates the *Resolved: terminology* section above and is left in place verbatim — the cleanup to "Offset Note Position" is owned by story 82.4 and applied across this doc, code, and comments in one sweep.

TOD will expand from a fixed pattern to a settings model with two independent axes:

- **Pattern** — chosen from a curated catalog (no arbitrary user-defined patterns). Catalog will include:
  - Patterns longer than one beat / more than four notes.
  - Patterns with gaps (rests), e.g. `* - * *`, `* * - *`, `* - * -`, `* - - *`.
  - Syncopated patterns.
  - Tuplets (triplets and beyond).
- **Offset slot** — which slot within the chosen pattern carries the timing offset. Constrained to playable slots (rests cannot carry an offset).

Two separate widgets. Slot selection depends on the pattern; changing the pattern invalidates the slot.

## Near-term step — slot selection as a setting

> **Note:** Story 82.1 shipped this step. The placeholder-era language in the bullets below (e.g. "which slot carries the offset", "Use the placeholder term consistently") predates the terminology resolution above and is left in place verbatim — the cleanup is owned by story 82.4 and applied across code, comments, and this section in one sweep, not piecemeal.

The immediate next step is to make today's hard-coded third-of-four a user setting (one of four slots). Guidance to keep future expansion cheap:

- **Frame the widget generically.** Not "third of four" — "which slot carries the offset." Today's pattern is fixed (straight 16ths) so the widget shows four slots; the same widget should scale to N without redesign.
- **Visual reference: the Continuous Rhythm Matching widget.** Provisional reuse, fine for now.
- **Organize Settings as if pattern were a (currently fixed) setting in the same section.** Even non-interactive today — future expansion then fills existing space rather than rearranging.
- **Design the slot-rendering primitive with rests in mind.** Even though no rests exist today, the slot widget's visual vocabulary should already accommodate a "non-playable slot" appearance so adding rests later becomes data, not redesign.
- **Equal-cell layout is fine for now; flag it for tuplets.** When tuplets land, the row of equal cells may need to become a proportional timeline. Do not over-engineer today.
- **Use the placeholder term consistently.** Whatever generic label is chosen for the interim ("offset slot" recommended), use it across the setting label, the underlying setting key, and any German string — a single global rename when the proper term lands is far cheaper than scattered variants.

## Open questions to revisit before building the future expansion

- Pattern-catalog UI categorization (likely *Straight / Gapped / Syncopated / Tuplet*; not decided). Owned by 82.3.
- Pattern preview rendering (text glyphs like `* - * *` vs. proportional timeline strip). Owned by 82.3.
- How slot selection presents when the pattern has rests — disabled-tap state, visual contrast, accessibility labels. Owned by 82.6.

## References

- **Epic 82 — Find the Off Note — TOD Pattern & Slot Flexibility** (this doc's implementing epic; 7 stories, tuplets deferred).
- Epic 81 — Settings screen control taxonomy (stories 81.1–81.3 establish the control vocabulary this widget will draw from).
- Stories 48.1–48.3 — original TOD implementation.
- Story 75.11 — rhythm-to-timing naming alignment.
- Story 76.4 — build-gated timing disciplines (TOD ships only under `PEACH_RESEARCH`).
- `docs/planning-artifacts/rhythm-training-spec.md` — rhythm/timing training spec.
- `Peach/Core/Audio/SequencerTypes.swift` — `Beat` / `Subdivision` engine layer (already tuplet- and rest-capable).
