# Chromatic Construction Discipline — Direction

**Status:** Design direction (informational, not a story spec)
**Date:** 2026-06-12
**Context:** Brainstorm with the Music Domain Expert (Adam) on a new training discipline that addresses the difficulty of producing chromatic note sequences without instrumental support. Source: [`brainstorming-session-2026-06-12.md`](../brainstorming/brainstorming-session-2026-06-12.md).
**Working name:** *Chromatic Construction* (not pinned; revisit after live experience).
**Implemented by:** TBD — future epic, gated behind `PEACH_RESEARCH` for the initial cut.

## Discipline summary

The user produces a row of pitches that equally divide a given interval, walking forward note by note. Two pitched anchors are fixed at the start and end. The user places N intermediate slots in order, each at an equal cent-step from the previous. The skill trained is **production of equal cent intervals across a span** — locally consistent stepping and globally calibrated landing on the upper anchor.

The chromatic case (100-cent target steps) is the canonical instance. Parameterizing the outer interval and slot count generalizes the model to any equal cent division, even though the initial cut trains 100-cent steps only.

## Musical framing

### Why this is a real and under-trained skill

Western musicians spend most of their training priming two things: diatonic templates (whole/half scale patterns with a tonic) and consonance-landmarked intervals (P4, P5, thirds). Chromatic runs strip both away. There is no diatonic skeleton to anchor on, and the minor 2nd has no harmonic gravity to fall into. Performers navigate a chromatic line by internal cent template, not by ear-pull — and that template is rarely trained directly.

Chromaticism as a structural practice (Wagner, Liszt, jazz, atonal music) emerged alongside equal temperament precisely because the older tuning systems made chromatic passages awkward or context-bound.

### Theoretical frameworks that apply

- **Equal Temperament theory.** The 100-cent semitone is one specific equal-division convention; the underlying skill is equal-cent step production, of which chromatic is the canonical case.
- **Categorical pitch perception** (Burns & Ward line of research). Semitone category boundaries exist; training narrows them.
- **Linear melodic theory.** Chromatic lines as melodic gesture without harmonic anchoring.
- **Motor learning.** Sequential motor planning, error accumulation, anchor-relative anticipation. Maps directly onto the walk-and-commit structure.

### Tuning-system constraint (explicit)

**The discipline trains equal-tempered chromatic stepping.** In non-equal-temperament systems, "chromatic" does not mean equal cent steps; it means traversing the system's own uneven semitones (Pythagorean limma ≈ 90.2 cents vs. apotome ≈ 113.7 cents; quarter-comma meantone diatonic ≈ 117 cents vs. chromatic ≈ 76 cents; just intonation 25:24 ≈ 70.7 cents vs. 16:15 ≈ 111.7 cents). Training equal-cent steps inside a non-equal-temperament musical context would be musically incoherent.

The discipline is therefore gated to 12-TET (and any other equal divisions of the octave the project may support, e.g. 19-TET, 24-TET, 31-TET). System-specific chromatic stepping in unequal temperaments would be a separate discipline; out of scope for this work.

## Core concepts

### `Anchor`

A pitched note at one end of the row. Fixed for the trial. Always tappable for playback throughout the trial — it is the only ground truth the user has. Derived as `Frequency` from `MIDINote` via `TuningSystem.frequency(for:referencePitch:)`.

### `Path`

The sequence of *directed steps* defining the row's shape: `[Direction]` of length N where `Direction = up | down`. Each step is one target-cent step (100 cents in the chromatic case) in the indicated direction.

Net span of the path = (up-count − down-count) × `targetStepCents`. For a monotonic ascending path, all steps are `up` and the net span equals the outer cents between anchors.

### `Slot`

One position the user must place. Each slot is associated with one step in the path. State per slot: `pending | active | committed`. When committed, the slot carries a `placedCents` value (cents offset from the lower anchor). Only the active slot is editable; previously committed slots are tappable for playback but locked.

### `Ladder` (the trial structure)

- `lowerAnchor: PitchedNote` — start of the row
- `upperAnchor: PitchedNote` — end of the row
- `outerCents: Cents` — signed cents between anchors; in the initial cut, derived from a single user-controlled difficulty parameter
- `path: [Direction]` — full step sequence (length determines `slotCount`)
- `targetStepCents: Cents` — fixed at 100 in the initial cut

In the experimental cut, monotonic-only generation means every path is `[.up, .up, …]` (or `[.down, .down, …]` if descending is enabled). The schema, session logic, and visualization carry the full `[Direction]` model from day one so meandering becomes a path-generator change later, not a model rewrite.

### `Direction` (walk direction)

`ascending | descending`. Determines walk order and which anchor is starting vs. destination. Whether the initial cut supports both is a deferred decision.

## State machine

```
idle
  → start(ladder, settings)
  → walking(activeSlot: 1, committed: [])
  → walking(activeSlot: 2, committed: [s1])
  → ...
  → walking(activeSlot: N, committed: [s1...s(N-1)])
  → awaitingSubmit(committed: [s1...sN])
  → showingResult(visualization of placements vs. targets)
  → idle
```

Transitions:

- `place(cents)` while walking: commits the active slot's `placedCents`, advances to the next slot or to `awaitingSubmit`.
- `stepBack()` while walking or awaiting submit: resets only the *immediately previous* slot to `pending`; the previously active slot is re-activated. Per the design discussion, back-step is **always one slot at a time** — no arbitrary jumps.
- `pause/resume/stop` per the `TrainingSession` protocol.

On entering `walking(activeSlot: K, ...)`: the slider's initial cent position equals the previous-committed pitch (or the lower anchor if K = 1). The previous-committed pitch sounds on slot open as an orienting cue. Previous slots' pitches and both anchors remain tappable for playback. Slot N+1 onward are `pending` (not visible as active sliders, but visible as placeholders in the contour).

### Step-back is lossy by design

Going back one slot resets *all* forward committed slots to `pending`. This is correct behavior, not a UX accident: forward slot targets were committed against the prior slot's now-invalid pitch and are therefore stale. UX should communicate the loss so the user can choose deliberately (visual cue: forward placeholders fade; back button shows what will clear).

## Visualization

A 2D contour, not a horizontal row of sliders.

- Horizontal axis: step index (1 to N+1)
- Vertical axis: pitch (cents)
- Anchors as fixed endpoints
- Committed slots as marker points connected by a visible line (the shape the user has produced)
- Active slot shows the current slider position; updates as the user moves it
- Pending slots shown as placeholders in the upcoming direction (so the user can see where the path is heading)

For monotonic ascending paths, the contour is a diagonal ramp from lower-left to upper-right. For descending, lower-right to upper-left. For meandering (future), a zig-zag. The visualization is identical in structure across all three; only the generator differs.

### Visualization as feedback

In the experimental cut (no numeric scoring), the contour itself is the trial-end feedback. Show the user's contour with the target line overlaid (or with anchors visually emphasized). The user sees directly where they sagged, where they overshot, where the line landed. No metric required — the shape is the diagnosis.

## Experimental cut — initial scope

### What ships

- Session, state machine, walk logic
- 2D contour visualization (meandering-capable internally, monotonic-only generated)
- Sliders, tap-to-play, anchor playback, single-step back
- View-local control for outer interval on the training screen (pure view state, no persistence)
- `NextPathStrategy` protocol with `MonotonicAscending` (and optionally `MonotonicDescending`) as initial conformances
- `TrainingSession` protocol conformance for lifecycle (pause/resume/stop)
- `TrainingLifecycleCoordinator` routing
- Registered in `DisciplineBootstrap.allDisciplines` inside `#if PEACH_RESEARCH`

### What gets deferred

- SwiftData `@Model` for trial records
- Observer wiring (`TrainingDataStore`, `ProgressTimeline`)
- `PerceptualProfile` integration
- Numeric scoring
- Trial history and progress aggregation
- Persistent user settings (no Settings-screen entry)
- Meandering path generation (architecture present, generator stays monotonic-only)
- Possible `MetricPoint` → `MeasuredValue` refactor (only triggered when scoring lands; see [`feedback_metricpoint_measured_value`](TBD))

### Difficulty control

The initial cut exposes **one knob: outer interval**. Range 200–1200 cents in 100-cent steps. With the target step fixed at 100 cents, outer interval implicitly determines slot count:

- 200 cents → 1 slot (one step)
- 700 cents (P5) → 6 slots
- 1200 cents (octave) → 11 slots

UI suggestion: discrete control (stepper or segmented), not a continuous slider.

### Build gating

The discipline ships behind `PEACH_RESEARCH`. Per the established gating pattern: types defined in all builds (so unit tests stay valid), registration in `DisciplineBootstrap.allDisciplines` gated with `#if PEACH_RESEARCH`. When persistence and scoring land and the discipline is ready to ship, remove the gate.

## Future expansion (post-experimental)

To revisit after living with the discipline:

- **Scoring model.** Capture-everything-first approach: collect candidate signals (first-attempt placement per slot, final placement per slot, back-step visits per slot, time-to-commit per slot, total back-steps, total duration, anchor/previous-slot replay counts, full path, ladder parameters) and decide the primary metric after the discipline's failure modes become clear in use.
- **Persistence.** Introduce a SwiftData `@Model` (e.g. `ChromaticConstructionRecord`) carrying the captured signal set. Note the model becomes vector-heavy (`[Cents]` and `[Int]` fields of length `slotCount`), in contrast to scalar-per-trial records for the pitch disciplines.
- **`PerceptualProfile` integration.** Open question with no obvious answer. PP is `MIDINote`-indexed scalar data; this discipline produces per-trial vector data spanning a cent range. Either skip PP for this discipline (clean) or define a lossy per-MIDI-note-pair extraction (compromised). Likely answer: separate progress aggregation, not PP.
- **Meandering paths.** Generator change only: add `MeanderingPath` conformances to `NextPathStrategy`. Anchor semantics shifts (anchors as landmarks the path touches, not strict span endpoints). Difficulty axes grow to include meander complexity.
- **Descending walks** (if not enabled in initial cut).
- **Multiple equal-divisions** beyond chromatic (e.g. equal trisection of a tritone — 150-cent steps). Architecture supports it; only the difficulty surface needs design.
- **Persistent user settings** (promote view-local outer-interval control to a real Settings entry).
- **Discipline name.** Defer until the discipline starts to feel right. Current working candidates: *Chromatic Construction*, *Chromatic Lines*, *Equal Steps*, *Even Steps*, *Step Construction*. Rename is cheap before App Store ship.

## Hidden assumptions to preserve

Surfaced during brainstorm; record here so implementers and reviewers don't reintroduce them silently.

1. **Sliders must be cent-linear, not Hz-linear.** Pitch perception is logarithmic. Hz-linear sliders feel non-uniform across the range. Non-negotiable.
2. **Target step is pure cent math, not derived from `TuningSystem`.** `TuningSystem` resolves anchor `MIDINote` → `Frequency`. Equal-division targets are `outerCents / (slotCount + 1)` regardless of tuning system. Routing targets through `TuningSystem` would silently train tuning-system-specific semitones instead of equal-cent steps.
3. **The discipline trains equal cent division, not "12-TET semitones."** 100-cent steps are one common case. Do not hard-code `100` anywhere; always derive from outer interval and path length.
4. **Anchors and targets can be non-MIDI-aligned.** Outer = 750 cents with 7 slots yields target step = 93.75 cents; slots land between MIDI notes. `NotePlayer.play(frequency:)` already handles continuous frequencies — no MIDI quantization.
5. **Equal *cents* ≠ equal *Hz delta*.** Equal cent spacing means equal log-frequency ratios — multiplicative in Hz, not additive.
6. **Step-back is lossy by design.** Forward slot values reset because their targets were committed against the prior slot's now-invalid pitch. Correct behavior.
7. **Slider range per slot.** Two clean options, not yet pinned:
   - *Monotonic:* range = (previous-committed, upper-anchor). Enforces forward motion; the line cannot reverse.
   - *Full:* range = (lower-anchor, upper-anchor). Permits overshoot/reversal as legitimate error.
   Default for the initial cut: monotonic (matches the monotonic-only generation). Re-decide before meandering ships.
8. **Direction asymmetry exists.** Ascending and descending chromatic lines show different performance in some studies. Either separate them as distinct practice modes or balance trial mix when both are enabled; do not assume parity.
9. **Reference-pitch invariance.** Anchor frequencies depend on `UserSettings.referencePitch`; cent relationships do not. When persistence lands, trial records should store both the cent math (invariant) and the reference pitch separately, so post-hoc analysis across sessions with different `referencePitch` settings is not confounded.
10. **Slot pitches are arbitrary frequencies, not MIDI notes.** `SoundFontPlayer` receives continuous `Frequency` for each placed slot. Do not round to nearest MIDI note for sampler-friendliness reasons — it would defeat the entire discipline.
11. **Tuning-system gating is musical, not cosmetic.** See *Musical framing* § *Tuning-system constraint*. Non-equal-temperament systems have multiple, unequal semitones; equal-cent stepping inside them is not "chromatic stepping."

## Open design decisions

Carried forward; not blockers for the experimental cut unless flagged.

- Slider range per slot (monotonic vs. full) — default monotonic for initial cut, re-decide later
- Slot-open behavior: previous note plays automatically vs. on first touch
- Direction policy: ascending-only first cut, or both ascending and descending available
- Anchor pitch selection policy: fixed (e.g. always around A4), randomized within a MIDI range, or eventually user-configurable
- Final-slot commit: explicit submit action vs. last `place` is implicit submit
- Step-back UX: visual cue/warning before forward-loss, vs. silent reset
- Difficulty progression: which outer-interval values become the "easy/medium/hard" sequence — informed by experience, not pre-decided
- Discipline name (see *Future expansion*)

## References

- Brainstorm session: [`docs/brainstorming/brainstorming-session-2026-06-12.md`](../brainstorming/brainstorming-session-2026-06-12.md)
- [`docs/project-context.md`](../project-context.md) — domain types, training-discipline patterns, `PEACH_RESEARCH` gating convention
- [`docs/planning-artifacts/architecture.md`](architecture.md) — `TrainingSession` protocol, `TrainingLifecycleCoordinator` routing, two-world architecture
- [`docs/planning-artifacts/epics.md`](epics.md) — implementing epic to be added
- `agent-music-domain-expert` (Adam) — consultation pattern; consult before drafting protocols, not as review
- Sibling disciplines for pattern reference: `PitchDiscrimination`, `PitchMatching` (state machines, observer pattern, settings factories)
- Related design direction: [`tod-discipline-future-direction.md`](tod-discipline-future-direction.md) — precedent for discipline-direction documents
