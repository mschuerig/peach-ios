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
- **Tuplet catalog expansion (renderer math, accessibility semantics for nested figures, sectioned picker categorization, opaque pattern-id convention).** Owned by 84.1 → see [`tod-tuplet-renderer-design.md`](tod-tuplet-renderer-design.md). Locks the proportional-timeline renderer (replacing 82.6's equal-cell renderer for all entries), the *Straight 16ths / Gapped 16ths / Triplets / Nested / Sextuplet* sectioned scheme, and the initial tuplet catalog content (10 new entries). Longer-than-beat and multi-beat syncopated patterns remain deferred to a separate follow-up epic; the renderer math and id convention are forward-compatible by construction.

## Metric unit decision — milliseconds (2026-07-17, Story 83.2)

**Decision: the TOD perceptual profile keeps raw milliseconds as its timing-offset unit.** Settled by Adam consultation (music-domain expert) with Michael, closing story 83.2 before the first public TOD release. The alternative on the table was tempo-normalized percent-of-a-sixteenth, as implemented in peach-web (baseline 5%), flagged by the 2026-07-13 cross-platform code reading (`../code_reading_chat_2026-07-13.md`, finding 9).

**Grounds:**

1. **Temporal psychophysics.** Displacement-detection JNDs in isochronous sequences are piecewise (Michon 1964; Hibi 1983; Friberg & Sundberg 1995): approximately constant in *milliseconds* (~5–10 ms for attentive listeners) below an IOI knee of roughly 240–250 ms, approximately proportional (a few percent) above it. Peach's sixteenth IOIs span 75 ms (200 BPM) to 375 ms (40 BPM); everything from ~60 BPM up sits in the absolute-floor regime, where ms is the perceptually more uniform unit. Percent is uncalibrated exactly where the discipline is hardest: 5% of a sixteenth at 200 BPM is 3.75 ms — below any human's floor — and the web's 1% adaptive floor is 0.75 ms there. The tempo-normalization intuition belongs to expressive-timing research (performed deviations scaling with tempo at phrase level), a different framework from near-threshold displacement detection.
2. **Measurement honesty (Michael's argument).** Milliseconds are the measured quantity; percent is derived.
3. **Reversibility.** Every TOD record stores both `tempoBPM` and `offsetMs` (`TimingOffsetDetectionDiscipline.csvColumns`), and the perceptual profile is in-memory, rebuilt from records at startup. The release commits users' history to the *record schema*, not the statistic unit — a future unit change is a recomputation with a step-change in displayed headlines, not a data migration.
4. **Musician vocabulary.** Micro-timing practice speaks milliseconds ("laid back by 15 ms"); nobody rehearses in percent-of-a-sixteenth. Matches the sober-factual display stance. The iOS 15 ms baseline is defensible against trained-listener floors in the literature.

**On the code-reading's merging concern** ("iOS merges raw ms across tempo-range keys"): this is a merging question, not a unit question — neither unit merges cleanly across tempi under a piecewise sensitivity curve. The per-`TempoRange` stratification is the statistical ground truth; the cross-key overall aggregate is a convenience headline under either unit. If that headline ever needs rigor, the fix is per-key baselines or a knee-aware normalization (ms below the ~240 ms IOI knee, percent above), not a unit swap.

**Revisit trigger:** if slow, long-IOI patterns become a training focus (the tuplet catalog already spans ~50 ms sextuplet cells at 200 BPM to ~500 ms triplet-8th cells at 40 BPM), the proportional regime becomes genuinely relevant for those keys. Revisit then; it is a recompute, not a migration.

**Cross-platform consequence:** peach-web aligns to milliseconds (dropping its %-based baseline and fixed [1%, 20%] adaptive range) in its own repo, spec'd from this decision.

## References

- **Epic 82 — Find the Off Note — TOD Pattern & Slot Flexibility** (this doc's implementing epic; 7 stories, tuplets deferred).
- Epic 81 — Settings screen control taxonomy (stories 81.1–81.3 establish the control vocabulary this widget will draw from).
- Stories 48.1–48.3 — original TOD implementation.
- Story 75.11 — rhythm-to-timing naming alignment.
- Story 76.4 — build-gated timing disciplines (originally gated TOD + CRM under `PEACH_RESEARCH`; story 82.8 lifted TOD out of the gate, leaving only CRM behind it).
- `docs/planning-artifacts/rhythm-training-spec.md` — rhythm/timing training spec.
- `Peach/Core/Audio/SequencerTypes.swift` — `Beat` / `Subdivision` engine layer (already tuplet- and rest-capable).
