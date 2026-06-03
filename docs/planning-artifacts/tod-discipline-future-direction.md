# TOD Discipline — Future Direction & Near-Term Slot Selection

**Status:** Design direction (informational, not a story spec)
**Date:** 2026-06-03
**Context:** UX discussion (Sally) on extending Timing Offset Detection beyond its current fixed third-of-four-16th-notes layout. Captured to inform the upcoming "which slot carries the offset" setting and to keep future expansion cheap.
**Implemented by:** Epic 82 — *Find the Off Note — TOD Pattern & Slot Flexibility* (`docs/planning-artifacts/epics.md`). Tuplets remain deferred to a follow-up epic per the call below.

## Open: terminology

We need a proper term for the note in the pattern that carries the timing offset. The term must:

- Frame the discipline as **detecting unintentional playing errors**, not as cataloging deliberate rhythmic gestures.
- Avoid collision with **rhythmic displacement** (music-theory term for intentional, grid-aware shifts) — the opposite of what TOD trains. "Displaced" is therefore rejected.
- Read naturally in setting labels and German localization. Consult `agent-music-domain-expert` (Adam) before fixing.

**Deferred.** Use generic placeholders ("offset slot," "offset position") in interim code, UI strings, settings keys, and analytics until a proper term is chosen.

## Future vision (not now)

TOD will expand from a fixed pattern to a settings model with two independent axes:

- **Pattern** — chosen from a curated catalog (no arbitrary user-defined patterns). Catalog will include:
  - Patterns longer than one beat / more than four notes.
  - Patterns with gaps (rests), e.g. `* - * *`, `* * - *`, `* - * -`, `* - - *`.
  - Syncopated patterns.
  - Tuplets (triplets and beyond).
- **Offset slot** — which slot within the chosen pattern carries the timing offset. Constrained to playable slots (rests cannot carry an offset).

Two separate widgets. Slot selection depends on the pattern; changing the pattern invalidates the slot.

## Near-term step — slot selection as a setting

The immediate next step is to make today's hard-coded third-of-four a user setting (one of four slots). Guidance to keep future expansion cheap:

- **Frame the widget generically.** Not "third of four" — "which slot carries the offset." Today's pattern is fixed (straight 16ths) so the widget shows four slots; the same widget should scale to N without redesign.
- **Visual reference: the Continuous Rhythm Matching widget.** Provisional reuse, fine for now.
- **Organize Settings as if pattern were a (currently fixed) setting in the same section.** Even non-interactive today — future expansion then fills existing space rather than rearranging.
- **Design the slot-rendering primitive with rests in mind.** Even though no rests exist today, the slot widget's visual vocabulary should already accommodate a "non-playable slot" appearance so adding rests later becomes data, not redesign.
- **Equal-cell layout is fine for now; flag it for tuplets.** When tuplets land, the row of equal cells may need to become a proportional timeline. Do not over-engineer today.
- **Use the placeholder term consistently.** Whatever generic label is chosen for the interim ("offset slot" recommended), use it across the setting label, the underlying setting key, and any German string — a single global rename when the proper term lands is far cheaper than scattered variants.

## Open questions to revisit before building the future expansion

- Proper term for the offset-carrying note (above).
- Pattern-catalog UI categorization (likely *Straight / Gapped / Syncopated / Tuplet*; not decided).
- Pattern preview rendering (text glyphs like `* - * *` vs. proportional timeline strip).
- How slot selection presents when the pattern has rests — disabled-tap state, visual contrast, accessibility labels.

## References

- **Epic 82 — Find the Off Note — TOD Pattern & Slot Flexibility** (this doc's implementing epic; 7 stories, tuplets deferred).
- Epic 81 — Settings screen control taxonomy (stories 81.1–81.3 establish the control vocabulary this widget will draw from).
- Stories 48.1–48.3 — original TOD implementation.
- Story 75.11 — rhythm-to-timing naming alignment.
- Story 76.4 — build-gated timing disciplines (TOD ships only under `PEACH_RESEARCH`).
- `docs/planning-artifacts/rhythm-training-spec.md` — rhythm/timing training spec.
- `Peach/Core/Audio/SequencerTypes.swift` — `Beat` / `Subdivision` engine layer (already tuplet- and rest-capable).
