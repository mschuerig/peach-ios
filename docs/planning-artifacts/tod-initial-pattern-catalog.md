# TOD — Initial Pattern Catalog & Picker UX

**Status:** Locked design direction (informational, not a story spec). **Partially superseded by [`tod-tuplet-renderer-design.md`](tod-tuplet-renderer-design.md)** (Epic 84 — tuplet expansion) for the proportional-timeline renderer, the opaque pattern-id convention (the five `pattern_NNNN` ids documented here are renamed to `pattern_01`–`pattern_05`), and the sectioned picker categorization. The pickable-position rule, the rest-cell a11y treatment, the `TimingDotView` visual vocabulary, and the per-pattern rationale recorded here all carry forward unchanged.
**Date:** 2026-06-03
**Owner story:** 82.3 (no-code)
**Consumed by:** 82.5 (data layer), 82.6 (UI), 82.7 (catalog content). **Successor reader:** Epic 84 (84.2–84.4) reads this doc as historical baseline; the live design direction for the proportional renderer, the new id convention, and the sectioned picker lives in `tod-tuplet-renderer-design.md`.
**Companion docs:**
- [`tod-discipline-future-direction.md`](tod-discipline-future-direction.md) — long-form direction, including the settled *Offset Note* terminology (§ *Resolved: terminology*).
- [`../implementation-artifacts/epic-82-context.md`](../implementation-artifacts/epic-82-context.md) — epic-wide context including the technical-decisions table and cross-story dependency chain.

This document locks the inputs to 82.5–82.7 that were left as open questions in `tod-discipline-future-direction.md` § *Open questions to revisit before building the future expansion*: the initial pattern catalog, the UI categorization, and the preview rendering. The slot-with-rests presentation question is also resolved here (it falls out of the picker-chrome decision).

## Purpose

Timing Offset Detection currently plays one fixed figure — four equally-spaced 16th notes per beat, with the offset locked to the third note. Epic 82 loosens both axes (which note carries the offset, and which figure the beat plays). 82.5 introduces the `NamedPattern` data layer, 82.6 the Settings UI, 82.7 the catalog content. All three need the same three answers up front: **which patterns**, **how categorized**, **how previewed**. Locking them here, before any code is written downstream, is the same pattern that 82.2 used for terminology — it prevents 82.5's data shape from being biased by whichever patterns its author imagines, and prevents 82.6's picker from being designed without the worst-case pattern in mind.

## Constraints (load-bearing)

These are the constraints the catalog is derived from. They are stated up front because removing any of them would invalidate the catalog.

1. **No metronome.** TOD plays the figure looped, with no external pulse reference. The listener constructs the perceptual grid from what they hear. This has two consequences:
   - **Patterns starting with a rest are not viable.** `- * * *`, `- * - *`, and similar are auditorily indistinguishable from the same pattern with leading rests removed — the first audible note becomes the perceptual "1". Any "missing first note" lesson requires an external pulse reference and is out of scope until TOD gets one (separate feature, not in epic 82).
   - **The first audible note in each pattern is the metric anchor and cannot itself be the Offset Note.** The accent on position 1 (`RhythmVelocity.accent`) makes it the perceptual reference; the listener anchors to it and judges everything else against it. If position 1 itself is offset, the direction-judgment task inverts (the listener perceives the *other* notes as deviating in the opposite direction), and the trial scores a perceptually-correct answer as wrong. The pickable-position rule is therefore: **the first audible note is excluded from the pickable set, always**.
2. **No tuplets in the initial catalog.** The `Beat` engine supports `.nested(Beat)` (the tuplet mechanism) and is correct as-is. The slot-picker UI ships an equal-cell renderer in 82.6; a proportional-timeline renderer for tuplets is a follow-up epic. Catalog entries here are all flat (no `.nested(Beat)` subdivisions).
3. **One beat per pattern.** All catalog entries are one-beat figures. Longer-than-beat patterns add a metric-cycle-length axis that mixes with the subdivision-feel axis; they're a follow-up consideration after the initial five-pattern catalog has playtested.
4. **No additional accents.** Playback keeps the current velocity model — `RhythmVelocity.accent` on position 1, `RhythmVelocity.normal` elsewhere. Patterns are not free to redistribute accents.
5. **Settled vocabulary.** Per [`tod-discipline-future-direction.md` § *Resolved: terminology*](tod-discipline-future-direction.md): the user-pickable note is the **Offset Note**, the setting is the **Offset Note Position**, code identifier `offsetNotePosition`. The music-theory term explicitly forbidden by 82.2 (see the design-direction doc and the associated auto-memory entry) stays forbidden; *slot* is engineering vocabulary only (data-structure term), never user-facing. Position vocabulary like *e / and / a* is **not** promoted to UI or code — positions are numeric (Note 1, Note 2, …).
6. **No pattern names.** The visual *is* the pattern's identity. No EN or DE display name is shipped per entry. The pattern picker rows are dot-diagram previews (see *Preview Rendering* below). Accessibility labels are derived programmatically from the audible/silent structure (see *Notes for 82.6*).

## Catalog

Five patterns. Position indexing in this table:
- **Grid position** = 1-based across all four subdivisions (`*` and `-` alike). Used for `Beat.subdivisions` array indexing in `buildBeat`.
- **Audible position** = 1-based across audible (`.note`) subdivisions only. **This is the indexing the user-facing Offset Note Position uses.** Rests are skipped; the indexing compresses the audible notes.

| # | Stable ID | Notation | Grid | Audible positions (grid → audible) | Pickable Offset Note Positions (audible) | Default Offset Note Position (audible) |
|---|---|---|---|---|---|---|
| 1 | `pattern_1111` | `* * * *` | 4 subdivisions | 1→1, 2→2, 3→3, 4→4 | **{2, 3, 4}** | **3** |
| 2 | `pattern_1011` | `* - * *` | 4 subdivisions | 1→1, 3→2, 4→3 | **{2, 3}** | **2** |
| 3 | `pattern_1101` | `* * - *` | 4 subdivisions | 1→1, 2→2, 4→3 | **{2, 3}** | **2** |
| 4 | `pattern_1010` | `* - * -` | 4 subdivisions | 1→1, 3→2 | **{2}** | **2** |
| 5 | `pattern_1001` | `* - - *` | 4 subdivisions | 1→1, 4→2 | **{2}** | **2** |

**Stable ID convention:** `pattern_` prefix + 4-bit notation mask in grid order (1 = note, 0 = rest), **MSB = grid position 1**. Self-documenting once the convention is known; stable under reordering; no naming bikeshedding required of 82.7. The IDs are code-only and never user-facing (they're the `@AppStorage` value for the selected pattern and the catalog lookup key in `TODPatternCatalog`).

**Worked example.** `pattern_1011` reads bit-by-bit left-to-right as grid positions 1, 2, 3, 4 → `1, 0, 1, 1` → notation `* - * *` → grid positions 1, 3, 4 audible, grid position 2 a rest. Audible positions are 1→1, 3→2, 4→3 (compress out the rest). This matches the table row for entry 2.

### Per-entry default reasoning

The defaults are not derived from a single rule — each pattern's most perceptually interesting position is shape-dependent. 82.7 records the per-entry rationale alongside each catalog entry so a future agent doesn't try to algorithmically derive defaults from pattern shape.

- **`pattern_1111` → default 3.** Migration target. 82.1 shipped `defaultOffsetNotePosition = 3` (1-based audible position; the `testedNoteIndex = 2` constant was deleted in 82.1). For `pattern_1111`, audible-1-based and grid-1-based coincide (every position is audible), so the existing default carries over unchanged.
- **`pattern_1011` → default 2.** Audible position 2 = grid position 3 = on the half-beat. Closest analogue to the Straight default (which also sits on the half-beat).
- **`pattern_1101` → default 2.** The on-the-half-beat audible note is a rest in this pattern. Audible 2 (grid 2, the early subdivision) and audible 3 (grid 4, the tail) are both equidistant from the rest at grid 3 — a tie. Audible 2 is picked here as a starting default; 82.7 may revise after playtest evidence.
- **`pattern_1010` → default 2.** Forced — single pickable position. **Encoding note:** `pattern_1010` is encoded as a 4-subdivision `Beat` (grid `* - * -`), not as a 2-subdivision `Beat`, so the equal-cell renderer can show it alongside the other catalog entries with consistent cell counts. The "8ths feel" Adam refers to in round 1 is the *audible perception* of the pattern, not its engine representation. The two audible notes (grid 1 and grid 3) fire at the same sample positions a 2-subdivision Beat would produce; the visible difference is the picker shows four cells (two with dots, two empty) instead of two.
- **`pattern_1001` → default 2.** Forced — single pickable position.

### Migration target

Entry 1 (`pattern_1111`) is the migration target for existing 82.1 user settings.

**`@AppStorage` shape (locked here, implemented in 82.5):**
- `selectedPatternId: String` — one global key. Defaults to `pattern_1111` on absence (fresh install AND 82.1-upgrade users land here). On unknown stored id (e.g., a pattern removed in a later build), the data layer falls back to `pattern_1111` *and* resets `offsetNotePosition` to its default; logs the unknown id at `.warning` level.
- `offsetNotePosition: Int` — one global key, audible-1-based. Read through the pattern-aware clamp (below) at every site. Defaults to the active pattern's `defaultOffsetNotePosition` on absence.

**Cross-pattern semantics:** `offsetNotePosition` is **one global key shared across patterns**, not a per-pattern key. On every pattern change, it is **always reset** to the new pattern's `defaultOffsetNotePosition` — even when the old value would still be in the new pattern's pickable set. Rule chosen for predictability: the user picks a pattern, the picker shows its sensible default, the user adjusts if they want. The alternative (preserve-when-still-pickable) creates surprising state where the same number means different audible positions across patterns. Reset-on-change is the simpler invariant.

**The pattern-aware clamp is the sole read path.** `TimingOffsetDetectionSettingsKeys.clamped(_:)` (or its 82.5 successor — `TODPatternCatalog`-aware variant) takes the stored value AND the active pattern; returns the stored value if it's in the active pattern's pickable set, otherwise the active pattern's default. **Every `@AppStorage` consumer in the TOD code path — the Settings picker, the training screen indicator, the audio engine — must read through this helper.** Direct `@AppStorage` reads bypass the clamp and re-create the 82.1 iteration-1 bug (UI/audio divergence on corrupt or stale storage). This is a hard rule for 82.5/82.6/82.7.

**No `@AppStorage` migration shim is added.** 82.1's introduction of the `offsetNotePosition` key was brand-new (no prior versioning to migrate from); 82.5/82.7's expansion adds the pattern-aware clamp on the read path, which is defence-in-depth, not a version migration. Existing 82.1 users with a stored `offsetNotePosition = 1` get clamped to `3` (the `pattern_1111` default) on first read; users with `2/3/4` stored values round-trip unchanged for `pattern_1111`. TOD is `PEACH_RESEARCH`-gated; research-build users are developers and the reset is documented in 82.7's story spec — same precedent as 82.4's documented reset for the placeholder-key rename.

## Categorization

**Scheme:** *Straight / Gapped / (Syncopated — reserved)*.

- **Straight** — every audible note lands on the metric grid implied by the subdivision count, evenly spaced. Entries 1 (`pattern_1111`) and 4 (`pattern_1010`).
- **Gapped** — preserves the metric grid structure (rests fill missing slots, no off-grid placement). Entries 2 (`pattern_1011`), 3 (`pattern_1101`), 5 (`pattern_1001`).
- **Syncopated** — audible notes deliberately sit *off* the implied grid. **Reserved, no entries.** Genuinely syncopated patterns require multi-beat figures (because off-grid placement against a single-beat grid is just a different one-beat grid). Out of scope here; available when a longer-than-beat follow-up adds them.

**Rule of thumb for future catalog additions:** A pattern is *Straight* if every audible note lands on the metric grid implied by its subdivision count, evenly spaced; otherwise *Gapped* if it preserves the grid's audible/silent positions (rests fill missing slots); otherwise *Syncopated*. The rule classifies on *grid evenness*, not on *subdivision density* — `pattern_1111` (16ths feel) and `pattern_1010` (8ths feel) are both *Straight* under this rule, because both have evenly-spaced audible notes on the implied subdivision grid. The density distinction (16ths vs 8ths perception) is not a categorization axis; it's a property of the individual pattern.

**Equal-cell renderer at non-4 subdivision counts:** the renderer's "equal cell" rule scales to any subdivision count K (cell count = pattern's grid subdivision count, all cells equal width). The current catalog is K=4 across the board; future entries at K=6 or K=8 are renderer-compatible as long as they remain non-tuplet. Tuplets (`.nested(Beat)` in the engine, requiring proportional-timeline rendering) are the only thing the equal-cell renderer cannot handle — and they're explicitly deferred.

**UI manifestation — 82.6:** With only five entries and two populated buckets, ship a **flat single-section picker** (no SwiftUI `Section` chrome, no header text). The categorization rule lives in the design doc for future-agent guidance, but doesn't appear as picker chrome until a third bucket exists or the entry count grows enough that section grouping aids scanability.

If a 82.6 author judges that explicit *Straight / Gapped* section headers would aid scanability at five entries — that's a reasonable alternative; the trade-off is the additional vertical space cost in Settings vs. the gain in semantic grouping. Either choice respects the catalog. Default to flat unless playtest evidence emerges.

## Preview Rendering

**Decision:** Reuse `TimingDotView`'s visual vocabulary at a smaller scale. No text glyphs (`* - * *`), no separate "visual strip" component.

`TimingDotView.swift` already encodes the metric structure correctly:
- Position 1 (the metric anchor / accented note): `beatOneDotDiameter` (22pt today).
- Other audible positions: `dotDiameter` (16pt).
- Offset Note: two overlapping circles via `ZStack` with `±overlapOffset/2` (the doubled-glyph marker).
- All dots `.fill(.primary)` with opacity controlled by `litCount` (irrelevant in the static picker preview — all dots full opacity).

For the catalog preview, the same vocabulary applies with these rules:

- **Rests** render as an *absent* circle in a cell of the same width as audible-note cells. Use uniform-width cell containers (`.frame(width: cellWidth)` containing either the dot or `Color.clear`/`EmptyView`) — a naive `HStack(spacing:)` with `EmptyView` collapses and breaks the column alignment. The cell column must persist; only the glyph is missing. This preserves horizontal spacing so the audible/silent pattern is scannable at a glance.
- **Scale and Dynamic Type:** smaller than the training-screen version. Suggested target: `beatOneDotDiameter ≈ 14`, `dotDiameter ≈ 10`, proportional `dotSpacing` and `overlapOffset`. The exact pixel values are 82.6's call; what's locked here is "same visual vocabulary, scaled down to fit a Settings row." Sizing uses `@ScaledMetric(relativeTo: .caption2)` (same convention as `TimingDotView` and `GridToggleRow`). At AX5 the dot row will widen; if it exceeds the row's available width, 82.6 chooses the wrap behavior — wrap onto a second line, or constrain the dot vocabulary to a smaller cap. **Spec this in 82.6, don't auto-wrap silently.**
- **Static state vs. `TimingDotView`'s `litCount` opacity path:** `TimingDotView` modulates opacity by `litCount` for playback animation. In the picker the pattern is identity, not playback — the catalog preview must render all audible dots at full opacity. Implementation: either reuse `TimingDotView` with `litCount` ≥ subdivision count (so the `index < litCount` test always passes) **or** extract a separate static renderer that shares the size/overlap-glyph constants. The constants must be shared (so a future `TimingDotView` change updates both surfaces in lockstep); the animation modulation must not bleed into the static preview.
- **Selected vs. unselected pattern row:** the row itself uses the standard Settings selection chrome (checkmark / accent background, whatever fits the platform). The dot preview within the row stays the same regardless of selection — selection is row-level, not glyph-level.

**Accessibility label for a pattern row** (read by VoiceOver). **Locked phrasing:** `"Accent, <kind>, <kind>, <kind>"` — where the first audible note (the metric anchor) is announced as `"Accent"` and other positions are announced as `"Note"` or `"Rest"`. Worked examples for the five entries:

| Pattern | Accessibility label |
|---|---|
| `pattern_1111` | `"Accent, note, note, note"` |
| `pattern_1011` | `"Accent, rest, note, note"` |
| `pattern_1101` | `"Accent, note, rest, note"` |
| `pattern_1010` | `"Accent, rest, note, rest"` |
| `pattern_1001` | `"Accent, rest, rest, note"` |

This format is positional (parallel to the visual), conveys the anchor distinction the visual encodes via `beatOneDotDiameter`, and does not ask the user to count. **Not** "Straight 16ths," "Gap on the 'e'," or any pattern-name phrase — the constraint that no pattern names ship applies to accessibility too.

### Why not text glyphs

A glyph string like `* * * *` does mislead, in two ways:
1. **Accent marking absent.** Position 1 (the metric anchor, the accented note) looks identical to all other notes; the listener hears it accented but reads it as equal. The dot diagram encodes the accent visually via `beatOneDotDiameter`.
2. **Position weight ambiguity.** The reader has to count to know that position 3 in a row of four corresponds to the on-the-half-beat reference. The dot diagram encodes position-1 distinctness directly.

The localization argument for glyphs ("no translation needed") is real but small — the dot diagram is similarly language-free.

### Why not a custom visual strip

Considered (taller cell for position 1, half-beat marker, color-coded note vs. rest). Rejected because it duplicates `TimingDotView`'s job and gives Settings a different rhythmic vocabulary from the training screen. Reusing `TimingDotView` keeps both surfaces in lockstep: any future change to the dot vocabulary updates both at once.

## Pickable-position rule

**The first audible note in each pattern is not pickable as the Offset Note.** This is a property of the perceptual task, not of any specific pattern (see *Constraints* above and Adam's consultation below for the full rationale).

In the slot picker (82.6's evolved 82.1 control):
- **Audible, non-pickable (always: the metric anchor):** renders as the larger accent dot at full opacity, with the doubled-glyph indicator never available on it. **Non-tappable.** No "selected" state ever applies. **Accessibility:** focusable to VoiceOver; announced as `"Anchor note, not selectable"` (or platform-appropriate equivalent); activation gesture is a no-op. Visually distinct from a rest (the dot is drawn), distinct from a normal pickable note (no tap target).
- **Audible, pickable:** renders as the normal dot, tappable, shows the doubled-glyph indicator when selected. **Accessibility:** uses the 82.1 cell label convention `"Note N of K"` where **N is audible-position-1-based** and **K is the audible-position count for the active pattern** (not the grid subdivision count — avoids the mismatch where audible position 3 of a 3-audible-note pattern reads as "Note 3 of 4"). Worked example: pattern_1011 has K=3 audible notes; its three cells read `"Note 1 of 3"` (the anchor, non-tappable), `"Note 2 of 3"` (tappable), `"Note 3 of 3"` (tappable). Selected cell appends `", selected"`.
- **Rest:** no dot drawn, cell width preserved, **non-tappable**. **Accessibility:** not focusable. The rest's structural information (where in the pattern it sits) is conveyed by the pattern-row label at the parent level (`"Accent, rest, note, note"`); per-rest-cell focus would be noise.

Whether the non-pickable anchor and a rest should be visually distinguished beyond "dot present vs. absent" is a 82.6 UX question. My read: don't add additional visual chrome — the user's mental model is "this slot isn't a valid Offset Note here," which is true for both. The dot-present-vs-absent distinction is enough.

### Single-pickable patterns

`pattern_1010` and `pattern_1001` have a single pickable position (`{2}`). In the slot picker:
- The single tappable cell is **pre-selected** (the pattern's default IS the only option).
- The cell remains tappable for affordance consistency, but tapping it is a no-op (cannot deselect, cannot move).
- No alternative "no selection" state. The pattern *implies* the Offset Note Position; the picker shows it but cannot change it.
- The pattern picker (one level up) is the only meaningful control for these patterns. This is intentional — choosing one of these patterns IS choosing both the rhythmic context and the offset position in one gesture.
- **Accessibility:** the pre-selected tappable cell reads `"Note N of K, selected"` (per the convention above). Activation announces nothing new (no-op). The user can switch away by selecting a different pattern at the pattern-picker level.

## Picker Sketches

ASCII at sketch fidelity. 82.6 produces the actual SwiftUI; these establish the spatial vocabulary.

### Pattern picker row (one row per catalog entry, in `SettingsScreen`)

Each row uses **uniform cell columns**, same width per cell, regardless of whether the cell holds an audible-note dot or is silent. This matches the slot-picker sketch below and the *Preview Rendering* rule about preserving cell width for rests.

```
┌─────────────────────────────────────────────────────────────┐
│  ┌──┐ ┌──┐ ┌──┐ ┌──┐                                        │
│  │● │ │· │ │· │ │· │                              ✓        │  ← pattern_1111 (selected)
│  └──┘ └──┘ └──┘ └──┘                                        │
├─────────────────────────────────────────────────────────────┤
│  ┌──┐ ┌──┐ ┌──┐ ┌──┐                                        │
│  │● │ │  │ │· │ │· │                                        │  ← pattern_1011
│  └──┘ └──┘ └──┘ └──┘                                        │
├─────────────────────────────────────────────────────────────┤
│  ┌──┐ ┌──┐ ┌──┐ ┌──┐                                        │
│  │● │ │· │ │  │ │· │                                        │  ← pattern_1101
│  └──┘ └──┘ └──┘ └──┘                                        │
├─────────────────────────────────────────────────────────────┤
│  ┌──┐ ┌──┐ ┌──┐ ┌──┐                                        │
│  │● │ │  │ │· │ │  │                                        │  ← pattern_1010
│  └──┘ └──┘ └──┘ └──┘                                        │
├─────────────────────────────────────────────────────────────┤
│  ┌──┐ ┌──┐ ┌──┐ ┌──┐                                        │
│  │● │ │  │ │  │ │· │                                        │  ← pattern_1001
│  └──┘ └──┘ └──┘ └──┘                                        │
└─────────────────────────────────────────────────────────────┘
```

Notation: `●` = position 1 accent dot (large); `·` = normal dot (smaller); empty cell = rest (column persists, no glyph drawn). The checkmark (or platform-appropriate selection chrome) sits at the row's trailing edge for the selected pattern. The cell columns in this sketch are *illustrative* of equal-width column placement — actual rendering scales via `@ScaledMetric`.

### Rest-aware slot picker (worst-case pattern: `pattern_1001` — two slots, one unpickable + one pickable, plus two rests)

```
   ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐
   │      │ │      │ │      │ │      │
   │  ●   │ │      │ │      │ │  ⦿⦿  │
   │      │ │      │ │      │ │      │
   └──────┘ └──────┘ └──────┘ └──────┘
   anchor    rest    rest    selected
   (large    (cell   (cell   (overlapping
   dot,      empty,  empty,  glyphs,
   not       not     not     tappable)
   tappable) tapp.)  tapp.)
```

Cell width is uniform across all four grid positions (equal-cell renderer per 82.6 constraint). Tappability is per-cell: only audible, pickable positions accept taps. The selected Offset Note shows the overlapping-glyph indicator (`⦿⦿`) per `TimingDotView`'s `ZStack` treatment.

For a multi-pickable pattern (`pattern_1111`, slots {2, 3, 4} pickable):

```
   ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐
   │      │ │      │ │      │ │      │
   │  ●   │ │  ·   │ │  ⦿⦿  │ │  ·   │
   │      │ │      │ │      │ │      │
   └──────┘ └──────┘ └──────┘ └──────┘
   anchor    tap     selected tap
   (not      audible (current  audible
   tappable) pos 2)  pos 3)    pos 4)
```

Tapping a tappable cell moves the doubled-glyph indicator to that cell and writes the new audible position to the `@AppStorage` key.

## Consultation with `agent-music-domain-expert` (Adam), 2026-06-03

Recorded verbatim across two rounds. The first round produced a preliminary catalog; Michael's pushback in the second round caught two material errors (metronome assumption and "downbeat" terminology) and prompted a perceptual-design question (offset on position 1) whose answer reshapes the data model. The final catalog above reflects round-2.

### Round 1 — preliminary catalog (superseded)

> **Editorial note (review iteration 1):** Round-1 reasoning is preserved verbatim as audit trail but does **not** reflect the final design. The catalog, terminology, names, and preview-rendering choices were materially revised in rounds 2 and 3 below. Skip to round 2 if reading for design guidance; refer to round 1 only when investigating *why* a particular decision came out the way it did.

Adam initially recommended five patterns including `- * * *` ("Backbeat 16ths"), used "downbeat" loosely for position 1, and recommended shipping per-pattern names like "Straight 16ths" / "16ths, gap on 'e'" using percussion vocabulary (1-e-and-a). Categorization: *Straight / Gapped*, Syncopated bucket reserved. Preview rendering: pushed toward a custom visual strip with metric-weight encoding (taller cell for the downbeat, half-beat marker).

Excerpt on perceptual territory:

> "Position 1 is the metric downbeat (strongest reference); positions 2 and 4 are the unaccented 'e' and 'a' 16ths (weakest, hardest offset-detection targets); position 3 is the back-half 'and' (medium — sits on the half-beat, which carries metric weight)."

Excerpt on `- * * *` (later dropped):

> "Offset starts on the 'e', no downbeat. Three audible: positions 1, 2, 3 in audible-only indexing. Genuinely uncomfortable timing — no metric anchor at the start of the beat — and probes a competency the straight grid cannot: timing perception when the perceptual ground (the downbeat) is absent and the listener must construct the grid from the audible material."

### Round 2 — corrections from Michael, captured verbatim

Michael's six points:

> "Maybe I misunderstood, but I don't think we need names for the patterns and we don't need names for the positions ('1-e-and-a') either."

> "We don't have a metronome and as such, we don't need patterns that are essentially identical without a metronome. Given this, I'm not sure if patterns where the '1' is missing make any sense."

> "Use of the 'downbeat' terminology is wrong. Used correctly, it applies to beats in a bar, but that's not what we're dealing with here. Our current patterns are exactly one beat long and comprise four 16th notes."

> "As such, emphasis on notes other than the first isn't needed."

> "`* - - *` is certainly not redundant."

> "In the settings widget we should use exactly the same display as on the training screen, including the overlapping bullet glyphs for the offset note. Maybe scaled a bit smaller."

### Round 2 — Adam's revised catalog

Excerpt on the metronome correction (the most consequential revision):

> "Without a metronome, the first audible note *becomes* the perceptual '1' — the leading rest is invisible to the listener, and `- * * *` is auditorily identical to `* * *` (just shifted in time). It probes no competency the straight pattern doesn't already probe. Drop entry 5 (Backbeat 16ths). Drop any future candidate that starts with a rest, for the same reason."

Excerpt on the terminology correction:

> "Right — *downbeat* applies to the first beat of a bar, not the first 16th of a beat. Our patterns are one-beat figures. Correct vocabulary going forward in the design doc: Position 1 = **on the beat** / **the beat** (the metric anchor of the figure). Position 3 = **on the half-beat** (the midpoint of a four-subdivision figure). Positions 2 and 4 = subdivisions of the beat; no special term needed for the pair."

**Vocabulary scope (editorial note added during review):** "On the half-beat" specifically names grid position 3 of a 4-subdivision figure. For future catalog entries at other K (e.g., K=6 or K=8), the midpoint nomenclature would need re-derivation (grid 4 of K=6 isn't the half-beat; it's the two-thirds mark). The "on the beat" / "metric anchor" vocabulary scales naturally (it always means grid position 1); "on the half-beat" is K=4-specific and should not be exported to non-4 patterns without re-grounding.

Excerpt on `* - - *`:

> "With entry 5 gone, `* - - *` is the *only* two-audible-note 16th-grid pattern in the catalog (entry 4 is 8ths, which is a different metric scale entirely). It probes 'anchor + tail' perception specifically — judging the timing of a note that's separated from its preceding reference by two rests. Common in march, dotted-eighth+16th figures, folk strumming patterns. Distinct competency. Add it."

Excerpt on the preview-rendering decision:

> "Decisive. … The existing `TimingDotView` already does this (`beatOneDotDiameter: 22` vs. `dotDiameter: 16`). This kills the text-glyph option entirely. The preview is the dot diagram. The picker row shows the row of dots (small) for each pattern; the slot picker (the existing four-cell grid from 82.1) gets reskinned in 82.6 to use the same dot vocabulary scaled to whatever cell size works in that context."

### Round 3 — should position 1 be pickable as the Offset Note?

Michael's question:

> "Does it ever make sense to offset the first note? I'm undecided. Of course, it can happen in practice, but does it make a useful training exercise?"

Adam's answer, verbatim:

> "No — and it's a good question to land on, because the answer reshapes the data model. Short answer: Position 1 (the accented note, the metric anchor) should not be pickable as the Offset Note. The training task fundamentally requires it as the reference, not the candidate.
>
> Without a metronome, the listener's perceptual grid is constructed from what they hear — and the most stable anchor is the accented note. The accent's job in the figure (`RhythmVelocity.accent`, position 1 only) is precisely to *be* the perceptual reference. The listener's brain locks onto it as 'the start of each iteration' and judges everything else relative to it.
>
> Now ask what happens if position 1 itself is offset by, say, +10ms (late) on every loop iteration: Position 1 fires every full-beat duration (regular interval from itself). Positions 2/3/4 also fire every full-beat duration (regular intervals from themselves). The listener anchors to position 1 because it's accented and consistent. From that anchor, positions 2/3/4 appear *early* — they sit at +90/+190/+290ms instead of +100/+200/+300ms after the accent.
>
> The trial expects the user to answer 'the Offset Note is *late*' (position 1, +10ms). What they actually perceive is 'positions 2/3/4 are *early* relative to the accent.' The direction inverts. The user, doing the perceptual task correctly, gives the answer the trial scores wrong.
>
> This isn't a hard-to-detect-position problem (which would be a difficulty issue and acceptable). It's a question-mismatch problem — the perceptual task and the score check are testing different things at position 1."

The pickable-position rule and its data-model consequences (Pickable column in the catalog table, 82.1 reset-from-position-1 migration) are derived from this answer.

## Constraint Check

**1 — Performance Principle (TOD lets users perform their best).** Pass. The catalog spans straight 16ths, three asymmetric gapped figures, and the two-note "8ths" and "anchor + tail" shapes — covering the perceptually distinct rhythmic contexts users encounter in real playing. None of the patterns is included to make TOD "harder"; each is included because it probes a competency the others don't.

**2 — No tuplets in the initial catalog.** Pass. All five entries have a flat 4-subdivision shape (no `.nested(Beat)`). The catalog domain layer (82.5) stays tuplet-capable at the type level — `Beat.subdivisions` already supports `.nested(Beat)` — but no shipped entry uses it.

**3 — Offset lands on an audible note.** Pass. The pickable-set rule excludes both rests (per `Subdivision.rest` having no audible event) and the first audible note (per the metric-anchor rationale above). All default Offset Note Positions in the table are audible, non-anchor positions.

## Notes for 82.5–82.7

These translate the catalog and rules above into concrete handoffs for the implementing stories.

### 82.5 — `NamedPattern` + `TODPatternCatalog`

- **Indexing.** The user-facing Offset Note Position is **audible-position 1-based** (compresses rests). The data layer should expose audible positions to consumers (UI, accessibility, defaults) and translate to grid positions only when constructing the `Beat`. The grid index is internal to `NamedPattern.beat(offsetNotePosition:offsetAmount:)`.
- **Pickable-position metadata.** Each `NamedPattern` exposes a `pickable: Set<Int>` (or equivalent) in audible-position terms. Per the catalog rule, this **never** includes position 1. 82.5's type can either compute this at construction time from a `[Subdivision]` template or accept it as a parameter; either is fine. What's locked is that `pickable.contains(1) == false` for every catalog entry, every time.
- **Stable IDs.** Use the `pattern_NNNN` convention (4-bit notation mask, 1 = note, 0 = rest, MSB = grid position 1). 82.7 ships the strings as catalog registration; 82.5 enforces uniqueness in `TODPatternCatalog` and raises a typed error on lookup of an unknown id.
- **Beat builder signature.** Per the epic-context working name: `func beat(offsetNotePosition: Int, offsetAmount: Duration) -> Beat`. The parameter is audible-1-based; the implementation translates to a grid index via the pattern's audible→grid map (precomputed at construction time) and applies `offsetAmount` to the corresponding `.note` subdivision (others get `.zero`, rests stay `.rest`). **Precondition (enforced by the builder):** the translated grid index must address a `.note` subdivision, never `.rest`. Derive the grid index from the audible→grid map; do not compute by raw arithmetic on the audible index. Document the precondition as a `precondition(...)` in the builder so an off-by-one in 82.5 fails fast rather than silently no-op-ing the offset (an offset applied to a `.rest` is dropped by `Beat.events(...)`).
- **Catalog at 82.5's merge point.** Register only `pattern_1111` (today's pattern). The other four entries are registered by 82.7. The behavioral no-op proves the wiring without conflating with content rollout.
- **Position-1 clamp logic.** The `TimingOffsetDetectionSettingsKeys.clamped(_:)` helper (or its 82.5 successor) needs to be pattern-aware — clamping must consult the active pattern's pickable set rather than just the `1...4` range. An out-of-range or non-pickable stored value falls back to the active pattern's default. This is the gate that catches existing 82.1 users with `offsetNotePosition = 1` and reroutes them to the new default (`3` for `pattern_1111`).

### 82.6 — Pattern picker + rest-aware scalable slot picker

- **Pattern picker UX.** Flat single section (no `Section` chrome) for the five-entry catalog. Each row contains a dot-diagram preview (per *Preview Rendering* above) and standard Settings selection chrome at the trailing edge. Tapping a row writes the selected pattern's id to the `@AppStorage` key and resets the Offset Note Position to the new pattern's default.
- **Slot picker reskin.** The existing 82.1 four-cell control evolves into the rest-aware scalable picker described in *Picker Sketches*. Cell count = grid subdivision count (always 4 for the initial catalog; the renderer is equal-cell). Per-cell tappability driven by the pattern's audible/pickable status:
  - **Audible + pickable:** tappable; renders normal dot; doubled-glyph indicator when selected.
  - **Audible + non-pickable (the metric anchor):** non-tappable; renders normal dot (the accented `beatOneDotDiameter` size); no doubled-glyph indicator ever.
  - **Rest:** non-tappable; no dot rendered; cell width preserved.
- **Preview rendering.** Reuse `TimingDotView`'s visual vocabulary at a smaller scale (target: `beatOneDotDiameter ≈ 14`, `dotDiameter ≈ 10`). Exact sizing is 82.6's call; what's locked is the visual vocabulary (large accent dot + smaller normal dots + doubled-glyph offset indicator + empty cell for rest).
- **Accessibility.** Per *Preview Rendering* above: pattern-row VoiceOver label is positional and structural, not nominal. Recommended phrasing: `"Note, rest, note, note"` (parallel to the visual). Slot-picker cells continue using the 82.1 pattern `"Note N of K"` where K = grid subdivision count; for non-pickable or rest cells append `", unavailable"`. Settled vocabulary applies — *Offset Note*, *Offset Note Position*; no theory vocabulary.
- **Localization.** German strings for any new copy via `bin/add-localization.swift`, informal `du` per `[[feedback_german_informal]]`. Sober factual register per `[[feedback_sober_factual_copy]]`. No pattern names = no per-entry localization burden; only structural accessibility strings need German equivalents.

### 82.7 — Catalog content

- **Register the four new entries** (`pattern_1011`, `pattern_1101`, `pattern_1010`, `pattern_1001`) in `TODPatternCatalog` with the per-pattern data from the catalog table above: the `[Subdivision]` template (in grid order, `.note(velocity:offset:)` with `.zero` offset for the baseline, `.rest` for gaps), the `pickable` set, and the default Offset Note Position.
- **Velocity model unchanged.** `RhythmVelocity.accent` on grid position 1, `RhythmVelocity.normal` on every other `.note` position. No per-entry velocity customization. Constraint 4 above.
- **No pattern names ship.** No `LocalizedStringResource` display name field on the registered entries. The pattern picker reads from each pattern's structural data (audible/silent positions) to render the preview.
- **Per-entry test scope.** For each catalog entry, verify: (a) the beat-builder produces a `Beat` whose `.note` subdivisions are at the expected grid positions with the offset applied to the indexed pickable position; (b) the pickable set excludes audible position 1; (c) `events(...)` walks the tree correctly with the chosen offset. Cross-platform — iOS and macOS both.
- **Catalog-wide invariant test.** Add a single test that iterates `TODPatternCatalog.all` and asserts `pattern.pickable.contains(1) == false` for every entry. Defence against a future contributor re-including audible position 1 in a new pattern's pickable set; the per-entry tests above check existing entries explicitly, this invariant test catches the addition case.
- **`pattern_1111` migration verification.** With the new clamp logic in place, verify: existing `offsetNotePosition = 1` stored values for `pattern_1111` clamp to the default (3); existing `offsetNotePosition` values of 2, 3, 4 round-trip unchanged.

## Discarded alternatives

Recorded so a future agent doesn't re-litigate settled ground.

- **`- * * *` (round 1's "Backbeat 16ths") and any other pattern starting with a rest.** Auditorily indistinguishable from the same pattern with leading rests removed (no metronome). Requires an external pulse reference, which TOD does not have. Off-table until that feature exists.
- **`* - - *` as redundant with `- * * *`** — round-1 reasoning, reversed in round 2. `* - - *` is now the only two-audible-note 16th-grid pattern and probes anchor+tail timing perception specifically.
- **Position 1 as a pickable Offset Note Position.** The perceptual task inverts at the metric anchor (round-3 analysis above). The training exercise scores correct percepts as wrong. Not pickable in any catalog entry, now or future, unless TOD acquires an external pulse reference.
- **Per-pattern names (EN + DE).** The visual *is* the pattern's identity (Michael, round 2). No display-name field on `NamedPattern`; no localization shipped; accessibility labels are derived from structure, not from a name.
- **Position vocabulary "e / and / a" (1-e-and-a counting).** Theoretical precision but unnecessary — UI uses numeric labels; the design doc uses "on the beat" / "on the half-beat" / "subdivisions of the beat" where directional vocabulary is needed.
- **The word "downbeat".** Wrong scale (applies to beats in a bar, not subdivisions in a beat). Use "the beat" / "on the beat" / "metric anchor" instead. Forbidden in new copy and design discussion.
- **Text-glyph preview (e.g. `* - * *`).** Doesn't encode the accent on position 1; doesn't encode position weight; gives Settings a different rhythmic vocabulary from the training screen. Dropped per round-2 directive.
- **Custom visual strip with metric-weight encoding (taller cell for position 1, half-beat marker, color-coded note vs. rest).** Round-1 push; superseded by the `TimingDotView` reuse decision. Avoids duplicating dot vocabulary across surfaces.
- **Six-entry initial catalog with an explicit syncopated pattern.** Would force the *Syncopated* UI bucket to ship populated before the perceptual benefit is established; one entry per bucket is the wrong shape. Defer to a longer-than-beat follow-up.
- **`- * - *` (off-beat 8ths, dropped first note).** Same metronome-absence reason as `- * * *`.
- **`* - * -` listed separately as "every other 16th".** Same data as entry 4 (8ths) under a different name. Don't ship twice.
- **Explicit *Straight / Gapped* section headers in the picker chrome.** Considered; deferred. Two-bucket grouping at five entries is borderline overkill for vertical space cost. Categorization rule lives in this doc; UI ships flat.

## References

- [`tod-discipline-future-direction.md`](tod-discipline-future-direction.md) — long-form direction; § *Resolved: terminology* (Offset Note, Offset Note Position) is the source-of-truth for vocabulary; § *Open questions to revisit* is the gap this doc closes.
- [`../implementation-artifacts/epic-82-context.md`](../implementation-artifacts/epic-82-context.md) — epic-wide constraints, cross-story dependencies, technical decisions table.
- [`../implementation-artifacts/82-1-offset-slot-as-setting.md`](../implementation-artifacts/82-1-offset-slot-as-setting.md) — the existing four-cell single-select Settings section, the `validOffsetNotePositionRange` / `clamped(_:)` helpers, and the per-`@AppStorage`-consumer clamp pattern that 82.5 evolves.
- [`../implementation-artifacts/82-2-offset-note-terminology-decision.md`](../implementation-artifacts/82-2-offset-note-terminology-decision.md) — the parallel no-code story that settled the *Offset Note* terminology this doc builds on.
- [`../implementation-artifacts/82-3-initial-pattern-catalog-and-picker-ux.md`](../implementation-artifacts/82-3-initial-pattern-catalog-and-picker-ux.md) — this story's own spec, with the boundaries that scoped this doc.
- `Peach/Core/Audio/SequencerTypes.swift` — `Beat` / `Subdivision` engine layer (already correct as-is for the initial catalog).
- `Peach/Training/TimingOffsetDetection/TimingDotView.swift` — the visual vocabulary the settings preview reuses.
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift` (`buildBeat`) — what `NamedPattern.beat(...)` replaces in 82.5.
