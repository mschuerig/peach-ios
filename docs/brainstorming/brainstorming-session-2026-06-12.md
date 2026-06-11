---
stepsCompleted: [1]
inputDocuments: []
session_topic: 'New training discipline — chromatic step construction'
session_goals: 'Brainstorm a new training discipline addressing the difficulty of singing or playing chromatic note sequences without instrumental support. Music Domain Expert (Adam) facilitates.'
selected_approach: 'informal-conversation-with-adam'
techniques_used: []
ideas_generated: []
context_file: ''
---

# Brainstorming Session Results

**Facilitator:** Michael
**Date:** 2026-06-12

## Session Overview

**Topic:** New training discipline for the difficulty of producing chromatic note sequences without instrumental support.

**Goals:** Explore design directions for a new Peach discipline that trains the ability to sing or play a row of chromatic notes without external pitch reference. Originated from Michael's observation that singing or playing several chromatic notes in a row is genuinely hard without an instrument's help. Two starting candidate ideas:

1. *Identify* — find the off-note(s) in a chromatic row.
2. *Construct* — within a given interval, arrange the notes so they form proper half-steps.

The session aimed to validate or prune the two ideas, surface hidden musical assumptions, and converge on a buildable scope.

### Context Guidance

_No context file provided. Music Domain Expert (Adam) facilitates the conversation per user request, with the project context (`docs/project-context.md`) loaded as foundational background._

### Session Setup

Informal conversation with Adam. No structured ideation framework adopted; running record format with periodic synthesis. Michael directed the pace and the scope choices; Adam contributed musical framing, research-area pointers, hidden-assumption flagging, and structural critique.

---

## Conversation Log

### Opening framing (Adam)

Chromatic stepping without instrumental support is a real and under-trained skill, for a specific musical reason: Western musicians prime two things heavily — diatonic templates (whole/half scale patterns with a tonic) and consonance-landmarked intervals (P4, P5, thirds). Chromatic runs strip away both. There is no diatonic skeleton to anchor on, and the minor 2nd has no harmonic gravity to fall into. Performers navigate chromatic lines by internal cent template, not by ear-pull.

Pedagogical tradition addressing this gap is sparse but real (e.g. Edlund's *Modus Novus* for atonal sight-singing; serial-era choral practice). Adjacent research areas worth knowing: categorical pitch perception (Burns & Ward and successors), vocal pitch imitation accuracy (Pfordresher line of work), equal-interval discrimination. Cited as areas and authors, not as specific papers — verify before quoting.

### First pass on the two ideas

**Idea 1 — Identify (find the off-note in a chromatic row).** Clean perceptual task. Load-bearing decisions hiding inside: memory contamination as row length grows; reference policy (cold vs. with correct version shown); anchor asymmetry (off-note position changes detection difficulty); direction symmetry; tuning assumption.

**Idea 2 — Construct (arrange notes for proper half-steps within an interval).** More unusual, more underspecified. Outer-interval choice has musical consequences (P5 leans on diatonic 3rd as anchor; tritone has no consonant landmark; octave invokes octave equivalence). Input modality choice is even more load-bearing: selection from pool (discrimination flavor), slider per slot (matching flavor), or microphone production (much bigger build).

A third variant was floated by Adam: *equal-division-of-any-interval* — generalize idea 2 to arbitrary outer intervals divided into N equal cent steps. Architecturally clean superset of chromatic; less recognizable surface for users.

### Decisions on the four load-bearing questions (Michael)

1. Identify reference policy: **cold** (no correct row shown).
2. Identify run length: **parameterized**, with explicit non-memory constraint — notes are visible and play on tap so the user can investigate freely.
3. Construct outer interval: **parameter**, not a fixed musical interval.
4. Construct input modality: **multiple sliders**.

### Construct refined as a sequential walk (Michael)

Michael further refined Construct to a sequential structure rather than parallel-edit:

- Sliders are adjustable one at a time, **in order**.
- Difficulty grows with **outer interval size**.
- Slot's initial slider position plays the previous committed note (orienting cue).
- Step-back allowed, but **lossy** — going back resets all forward placements.

Adam observed that this reshape turns Construct into a chain of mini-matching trials with two musically rich properties: error accumulates (real performance failure mode for chromatic lines — sags or rushes by the end), and the upper anchor remains globally available as a future reference, enabling both local ("next step from here") and global ("how much room left?") strategies.

Adam also raised: bringing the sequential pattern back to Identify (walk-and-judge, edge-tap variant, anchor-emphasized inspection).

### Pruning Identify (Michael's instinct, Adam's reasoning)

Michael questioned whether Identify carries its weight given Construct's strength. Adam concurred and sharpened the reason: in the cold + tap-to-play + visual-row form, Identify is functionally **interval-JND-with-extra-UI**. The user's mental operation is tap-pair-compare across adjacencies — which is exactly what `PitchDiscrimination` already trains, applied to 100-cent intervals. The row context dresses it up without adding a distinct perceptual demand once free replay is allowed.

Construct, by contrast, trains things nothing else in Peach touches: internal cent-template for "one step up from here," forward planning relative to the upper anchor, drift awareness, and the motor-cognitive action of stepping forward through cent-space.

The Discrimination/Matching symmetry of the pitch family was raised as a counter-argument. Adam noted the symmetry holds only because the two pitch disciplines genuinely carve off distinct skills; cutting Identify here would not break a real symmetry, only a cosmetic one.

Adam flagged a perceptual skill that *neither* `PitchDiscrimination` nor Construct covers, and that a *different* Identify-shaped paradigm could train: **row-wise drift perception** (listen to a complete chromatic line as a phrase, judge whether it lands, sags, or overshoots). Parked as a possible future sibling discipline; not built on speculation.

**Decision:** Identify dropped. Construct retained as the single new discipline.

### Tuning-system implications (Adam-raised, Michael acknowledged)

Adam surfaced a hidden assumption with real teeth: the discipline as scoped implicitly assumes equal temperament. In non-equal-temperament systems, "chromatic" does not mean equal cent steps:

- Pythagorean: limma ≈ 90.2 cents (e.g. E→F), apotome ≈ 113.7 cents (e.g. F→F♯) — uneven by design.
- Quarter-comma meantone: diatonic semitone ≈ 117 cents, chromatic semitone ≈ 76 cents — inverted relative size vs. Pythagorean; C♯ ≠ D♭.
- Just intonation: multiple chromatic intervals (25:24, 16:15, 135:128) depending on context.
- Well temperaments: semitone size varies by key.

Chromaticism as we know it (Wagner, Liszt, jazz, atonal music) emerged alongside equal temperament. Training equal-cent steps inside a non-equal-temperament musical context would be musically incoherent.

**Decision:** discipline gated to 12-TET (and any other equal divisions of the octave). System-specific chromatic stepping in unequal temperaments would be a separate discipline, out of scope.

### Scoring discussion and Michael's pivot to defer

Adam initially proposed two orthogonal scoring axes: local step consistency (mean per-step deviation from target) and global drift (signed offset of final committed slot from upper anchor). Michael responded with a sharper observation: with unlimited free back-stepping, users will correct toward the upper anchor, so final drift trends to zero. The behavioral signal moves backward — what did the line look like *before* corrections?

Michael proposed **back-step count** as the natural primary measure, also constraining back-step to **always one slot at a time** (no arbitrary jumps).

Adam concurred and suggested capturing additional signals — first-attempt vs. final placement per slot, time-to-commit, replay counts — so that interpretation can be deferred without losing data.

Michael then made a broader scope decision: **defer data storage and profile integration entirely** for the experimental cut. The first version provides controls on the training screen (initially just outer interval) to let him experience the discipline before deciding what is worth measuring or how progress should be detected.

### Meandering paths and the visualization implication

Michael wanted to keep the option of longer meandering sequences (non-monotonic chromatic lines) even though the first cut would ship monotonic-only. This made it explicit that a horizontal row of sliders is insufficient: meandering requires a 2D contour visualization (slot index × pitch). Adam noted that building the contour visualization and `Path = [Direction]` data model from day one, while generating monotonic-only paths initially, costs little and saves a UI rewrite later. Michael agreed.

### Final scope decisions for the experimental cut

- **Pure view state**, no persistence for the difficulty controls.
- **`PEACH_RESEARCH` gating** confirmed — established pattern per project memory.

---

## Decisions Captured

- **Two starting candidate disciplines reduced to one.** Identify dropped as redundant with `PitchDiscrimination`. Construct retained.
- **Construct is a sequential walk**, not a parallel-edit form. Sliders are adjusted one at a time, in order.
- **Step-back is single-slot only**, and forward-lossy by design.
- **Slot-open behavior:** initial slider position plays the previous committed pitch (or lower anchor for the first slot).
- **2D contour visualization** from day one (meandering-capable internally, monotonic-only generated in the experimental cut).
- **Path data model uses `[Direction]`** from day one (`Direction = up | down`); monotonic-only generation is a path-generator constraint, not a model constraint.
- **Outer interval is the only difficulty control** in the experimental cut, exposed via view-local state on the training screen.
- **Target step fixed at 100 cents** in the experimental cut; outer interval implicitly determines slot count.
- **No persistence, no scoring, no observer wiring** in the experimental cut. Visualization itself serves as trial-end feedback.
- **`PEACH_RESEARCH` gating** for the discipline registration.
- **12-TET only.** Discipline explicitly does not cover unequal-temperament chromatic stepping; that would be a separate discipline.
- **Naming deferred.** Working name *Chromatic Construction*; cheap to rename.

## Deferred

To revisit after living with the discipline:

- Data persistence (SwiftData `@Model` records)
- Observer wiring (`TrainingDataStore`, `ProgressTimeline`)
- `PerceptualProfile` integration (open question; vector-per-trial data may not fit PP's `MIDINote`-indexed scalar model — likely answer: separate aggregation)
- Numeric scoring model; defer until live experience informs which signals matter
- Meandering path generation (architecture present, generator stays monotonic-only)
- Descending walks (optional; ascending-only feasible for first cut)
- Equal divisions beyond chromatic (e.g. 150-cent steps as equal trisection of a tritone)
- Persistent user settings (promote view-local outer-interval control later)
- Discipline name
- Possible `MetricPoint` → `MeasuredValue` refactor (only triggered when scoring lands and mixed-kind measurements appear)
- Drift-perception paradigm as a possible perceptual sibling discipline (parked; not built on speculation)

## Next Steps

- Michael revisits the captured artifacts: this brainstorm session and [`chromatic-construction-discipline-direction.md`](../planning-artifacts/chromatic-construction-discipline-direction.md).
- Briefing of the planning workflow (PRD via `bmad-create-prd`, or directly `bmad-create-epics-and-stories` if scope is small enough) with the direction document as input.
- Future revisit after experimental cut ships and live experience accumulates: scoring model, persistence, profile integration, meandering.

## References

- [`chromatic-construction-discipline-direction.md`](../planning-artifacts/chromatic-construction-discipline-direction.md) — design direction document derived from this session
- [`docs/project-context.md`](../project-context.md) — domain types, training-discipline patterns, `PEACH_RESEARCH` gating convention
- `agent-music-domain-expert` (Adam) skill — consult-early pattern
- Sibling disciplines for pattern reference: `PitchDiscrimination`, `PitchMatching` — protocol shape, observer pattern, lifecycle routing
- Precedent for discipline-direction document format: [`tod-discipline-future-direction.md`](../planning-artifacts/tod-discipline-future-direction.md)
