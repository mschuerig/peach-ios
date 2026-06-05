# TOD Tuplet Patterns — Renderer and Catalog Design

**Status:** Locked, 2026-06-04. Owned by Story 84.1; read by Stories 84.2, 84.3, 84.4.

**Purpose:** Fix the four design questions blocking Epic 84's implementation stages — the *proportional-timeline cell-width math* that replaces Epic 82's equal-cell renderer, the *per-cell `accessibilityLabel` form* for nested figures, the *sectioned picker categorization*, and the *tuplet catalog set itself*. Also fixes the opaque pattern-id convention 84.2 swaps onto.

**Predecessor design doc:** [`tod-initial-pattern-catalog.md`](tod-initial-pattern-catalog.md) — the Epic 82.3 lock-the-inputs doc. The conventions established there (visual-is-identity, "Accent" / "Note N of K" a11y labels, rest-cell de-emphasis, `beatOneDotDiameter` accent marker, doubled-glyph offset marker, `previewScale`) carry forward. This doc extends them; it does not supersede them.

---

## Inputs and constraints

**The Performance Principle is the north star.** TOD probes timing perception under varied rhythmic contexts users can perform their best in. Catalog additions extend the contexts the user is exposed to; they do not constrain the user.

**Single-beat scope only.** Longer-than-beat and multi-beat syncopated patterns are explicitly deferred to a near-future follow-up epic. The renderer math and id convention here are forward-compatible by construction (see § *Multi-beat forward-compat sketch*), but no multi-beat content ships in Epic 84.

**The "first audible note never pickable" rule from Epic 82.3 § *Pickable-position rule* extends without modification to nested figures.** The metric anchor is the first audible note in the *flat audible walk* of the `Beat` tree — whether that audible lives at the top level or inside a nested child. Every catalog entry's `pickable` set excludes audible position 1.

**Engine boundaries.** The engine layer (`Core/Audio/SequencerTypes.swift`) is untouched in Epic 84. `Beat` / `Subdivision` / `.nested(Beat)` already support every catalog shape in scope (variable subdivision counts, multi-cell holds via flat-grid-with-rests, depth-1 nesting). `SoundFontStepSequencer.events(...)` already walks `.nested` recursively. The wrapper layer (`TimingOffsetDetectionPattern`) is the only catalog-side code 84.2/84.4 touch, and the visual renderer (`TimingDotView`) is the only UI-side code 84.3 touches. 84.4 also touches the picker chrome (`TimingOffsetDetectionPatternPickerSettingsSection`).

**One acknowledged data-layer change.** Today's `TimingOffsetDetectionPattern.audibleToGrid` walks only top-level `.note` subdivisions ("Excludes `.rest` (and, if it ever appears, `.nested`) entries" per the header comment). For the tuplet catalog, nested figures' audibles must participate. Epic 84's epic-block "no data-layer change" claim was over-optimistic. **The wrapper's audible-walk becomes recursive; the shape is locked here, not deferred:**

- A `GridPath` is a non-empty `[Int]` — the sequence of subdivision indices traversed from the top-level `Beat` to reach a `.note` leaf. Top-level audibles have single-element paths (`[0]`, `[2]`); nested audibles have multi-element paths (`[1, 0]`, `[1, 1]`, `[1, 2]` for a nested triplet inside top-level index 1). Path depth ≤ 2 in Epic 84; the type permits deeper nesting for forward-compat.
- `audibleToGrid: [GridPath]` — produced by a depth-first walk of `subdivisions`: visit each `.note` (collect its path), descend into each `.nested(Beat)` (extending the path by the child's index, then recursing). `.rest` cells are skipped entirely.
- `audibleCount: Int { audibleToGrid.count }` — unchanged surface.
- `pickable: Set<Int>` (1-based audible positions) — unchanged surface and semantics (still excludes audible position 1).
- `beat(offsetNotePosition:offsetAmount:)` — walks the same recursive structure: when reconstructing the `Beat`, the leaf at `audibleToGrid[offsetNotePosition.zeroBasedIndex]` receives the offset; every other `.note` keeps `.zero`; every `.rest` and every `.nested(Beat)` traversal preserves structure. The path-walk happens inside the recursive reconstruction — no exposure of `GridPath` to callers.

Story 84.3 implements this shape (per § *Notes for 84.2–84.4*); 84.4 registers tuplet entries against it.

**Settled terminology (no new terms in this epic).** *Offset Note* / *Offset Note Position* / code identifier `offsetNotePosition`. "Slot" stays engineering-vocabulary only. "Displaced" must not appear in new descriptive copy (load-bearing — see `feedback_tod_no_displaced_term`). "TOD" is shorthand only — never in code identifiers, type names, or persistent docs (see `feedback_tod_shorthand_only`).

**No swing.** The mixed-duration triplet `* *. .` is a structurally-defined entry, not a swing-feel emulator. No "swing" toggle, "swing ratio" control, or swing-labeled UI element appears anywhere in this doc.

---

## Pattern-id convention

**Status note (Story 84.4 iteration 4 revision):** The opaque `pattern_NN` convention this section originally locked is **superseded by a category-prefixed convention** at Michael's request. Rationale: opaque IDs were chosen to decouple identification from categorization, but in practice the IDs are used in spoken/written discussion (PR descriptions, bug reports, code reviews) where `pattern_05` is unmemorable while `pattern_gapped16ths_04` is self-explanatory. The decoupling principle was outweighed by communicability. Categorization remains a load-bearing property of a pattern (encoded in `TimingOffsetDetectionPattern.category`), so encoding the category in the ID is consistent with the type's structure.

**Convention:** `pattern_<category>_<NN>` — `pattern_` prefix, then the category's `idToken` (the enum case name in camelCase, e.g. `straight16ths`, `gapped16ths`, `triplets`, `nested`, `sextuplet`), then a zero-padded two-digit sequence number **within that category**.

**Rule:**
- Sequence numbers are per-category, assigned at first registration. **An entry's id is fixed and never changes.**
- Numbers within a category are never reused. A removed entry's number stays retired; new entries take the next available number in that category.
- **Retired-id registry:** when a pattern is removed from the catalog, its id is recorded in a comment block at the top of `TimingOffsetDetectionPatternCatalog.swift`. (Epic 84 retires nothing.)
- Two-digit padding handles up to 99 entries per category. Past `_99` within a category, new entries widen to three digits; existing two-digit ids are preserved.
- A pattern moving to a different category would be a **rename** (its id changes). Pattern-id stability is per-category, not global. In practice, categories are determined by the pattern's structural shape; a pattern doesn't drift between categories.
- Multi-beat patterns from a future epic introduce new categories (e.g. `pattern_multibeat_01`); the existing categories' sequences continue independently.

**Why category-prefixed (not opaque, not semantic-shape, not bitmask):**
- *Opaque ids* (`pattern_NN`) decouple id from categorization but are unmemorable and force every discussion to reference the lookup table.
- *Semantic-shape ids* (`triplet-full`, `straight-16ths`) encode the pattern's structural shape in the id; a future restructure of the shape would force a rename.
- *Bitmask ids* (`pattern_1111`) were Epic-82-shape-bound (four 16th-cells); they don't generalize.
- *Category-prefixed ids* encode the structural family (which is itself stable and a load-bearing property of the pattern) without encoding the within-category specifics. The category prefix is communicable; the sequence number is opaque within the category.

**ID schema invariant (enforced at construction):** `TimingOffsetDetectionPattern.init` requires `id.hasPrefix("pattern_\(category.idToken)_")`. A misregistered pattern (e.g. `id: "pattern_triplets_01"` with `category: .gapped16ths`) traps at construction time, before any session or storage reads it.

**Collision check:** 15 entries spread across 5 categories → no collisions by construction. The per-category numbering means adding new patterns in one category does not disturb numbering in other categories.

**Catalog roster (locked):**

| Id | Notation | Category |
|---|---|---|
| `pattern_straight16ths_01` | `* * * *` | Straight 16ths |
| `pattern_gapped16ths_01` | `* - * *` | Gapped 16ths |
| `pattern_gapped16ths_02` | `* * - *` | Gapped 16ths |
| `pattern_gapped16ths_03` | `* - * -` | Gapped 16ths |
| `pattern_gapped16ths_04` | `* - - *` | Gapped 16ths |
| `pattern_triplets_01` | `* * *` | Triplets |
| `pattern_triplets_02` | `* * -` | Triplets |
| `pattern_triplets_03` | `* - *` | Triplets |
| `pattern_triplets_04` | `* *. .` | Triplets |
| `pattern_nested_01` | `* *-*-*` | Nested (PEACH_RESEARCH-gated) |
| `pattern_nested_02` | `*-*-* *` | Nested (PEACH_RESEARCH-gated) |
| `pattern_nested_03` | `* * .-.` | Nested (PEACH_RESEARCH-gated) |
| `pattern_nested_04` | `* .-. *` | Nested (PEACH_RESEARCH-gated) |
| `pattern_nested_05` | `.-. * *` | Nested (PEACH_RESEARCH-gated) |
| `pattern_sextuplet_01` | `. . . . . .` | Sextuplet |

**Default-target id:** `pattern_straight16ths_01`. The "unknown-id-on-lookup falls back to default" behaviour from Epic 82.5 is preserved.

**Historical rename map** (preserved for traceability — `tod-initial-pattern-catalog.md` cites the old `pattern_1NNN` ids; Story 84.2 mapped them to `pattern_NN`; Story 84.4 iteration 4 maps them again to the category-prefixed form):

| Epic-82 bitmask id | 84.2 opaque id | 84.4 iter-4 category-prefixed id |
|---|---|---|
| `pattern_1111` | `pattern_01` | `pattern_straight16ths_01` |
| `pattern_1011` | `pattern_02` | `pattern_gapped16ths_01` |
| `pattern_1101` | `pattern_03` | `pattern_gapped16ths_02` |
| `pattern_1010` | `pattern_04` | `pattern_gapped16ths_03` |
| `pattern_1001` | `pattern_05` | `pattern_gapped16ths_04` |

---

## Cell-width math

**Rule (one rule over the `Beat` tree — no per-entry magic numbers):**

```
1. Total available width for the picker-row preview = W (one proportional unit; pixels resolved by SwiftUI layout).
2. Walk the Beat tree depth-first, producing a flat sequence of typed nodes:
       node ∈ { .note(leaf_width), .rest(leaf_width), .nest_enter, .nest_exit }
3. leaf_width is the leaf's share of W, computed by descent:
       - The top-level Beat has allocated_width = W.
       - A Beat with K subdivisions splits its allocated_width into K equal cells:
                per_cell = allocated_width / K
       - A .note or .rest leaf at depth d gets leaf_width = per_cell at that level.
       - A .nested(Beat) at depth d recurses with allocated_width = per_cell at that level.
4. Build "visual cells" from the flat sequence. The rule is complete — every possible leaf-kind transition has a defined outcome:
       - A .note opens a visual cell at start_x with accumulator_width = leaf_width.
       - An immediately-following .rest extends accumulator_width by rest.leaf_width.
         (Immediately-following means: same depth; no .nest_enter / .nest_exit between.)
       - A .rest that does NOT extend an in-flight visual cell — i.e. an "orphan rest" — emits its own visual cell at the rest's start_x with width = leaf_width and rest treatment (de-emphasis per 82.3's locked rest treatment). Orphan rests occur in four cases, all defined identically:
           (a) leading .rest at depth-entry: the first child of a Beat is .rest, no prior .note at that depth — emits orphan-rest cell.
           (b) .rest immediately after .nest_exit at the parent depth: the child group ended, no in-flight .note at the parent — emits orphan-rest cell.
           (c) consecutive .rest leaves where the first is itself an orphan rest (a, b, or recursive d): each subsequent .rest extends the previous orphan-rest cell (same accumulator rule, but the cell is rest-treatment, not note-treatment).
           (d) .rest immediately after .nest_enter: cannot occur inside the child group's first child — covered by (a) at the child depth.
         **No Epic 84 catalog entry triggers (a) or (b); both are forward-compat completeness for the multi-beat epic.** The rule is documented so 84.3's `static` function passes its own boundary tests even on shapes the catalog hasn't reached yet.
       - A .nest_enter terminates any in-flight visual cell at the parent depth (emit it), then begins emitting the child Beat's visual cells.
       - A .nest_exit ends the child's emission. The next leaf at the parent depth is treated per its own rule: .note opens a new visual cell at the parent depth; .rest is an orphan rest per case (b); .nest_enter begins another child group adjacent to the prior one.
5. Each visual cell renders at proportional width relative to W.
```

**Worked examples (the math walking each pattern shape in scope):**

For `* * * *` (Epic-82 reference; K=4 flat, all notes): four equal visual cells at width W/4 each.

For `* - * *` (Epic-82 gapped): leaves `note(W/4), rest(W/4), note(W/4), note(W/4)` → visual cells `[note absorbing the rest: width W/2]`, `[note: W/4]`, `[note: W/4]`. The first visual cell is twice as wide as the others. **Behaviour change vs Epic 82's equal-cell renderer: yes, visually.** The previously-de-emphasized rest at grid index 2 is no longer a separate cell — its width is absorbed into the preceding accent dot's cell.

For `* - - *` (Epic-82 worst-case gap): leaves `note, rest, rest, note` → visual cells `[note absorbing 2 rests: width 3W/4]`, `[note: W/4]`. Two visual cells of widths 3:1.

For `* - * -` (Epic-82 single-pickable straight 8ths): leaves `note, rest, note, rest` → visual cells `[note + rest: W/2]`, `[note + rest: W/2]`. Two equal visual cells (the "8ths feel" comes through).

For `* * *` (8th-triplet, K=3 flat, all notes): three equal visual cells at W/3 each.

For `* * -` (8th-triplet with trailing rest): leaves `note, note, rest` → visual cells `[note: W/3]`, `[note absorbing the rest: 2W/3]`. Two visual cells of widths 1:2.

For `* - *` (8th-triplet with middle rest): leaves `note, rest, note` → visual cells `[note + rest: 2W/3]`, `[note: W/3]`. Two visual cells of widths 2:1.

For `* *. .` (mixed-duration triplet, K=6 flat with multi-cell holds): leaves `note, rest, note, rest, rest, note` → visual cells `[note + 1 rest: 2W/6 = W/3]`, `[note + 2 rests: 3W/6 = W/2]`, `[note: W/6]`. Three visual cells of widths 2:3:1. **This is how the medium-long-short feel becomes proportionally visible.**

For `* *-*-*` (8th + nested 16th-triplet): top-level Beat has K=2, per_cell = W/2. Subdivisions are `[note, .nested(triplet)]`. Top-level leaves: `note(W/2)`, then nest_enter. Inside the nested Beat (K=3, allocated W/2, per_cell = W/6): `note(W/6), note(W/6), note(W/6)`. Visual cells: `[note: W/2]`, [nest bracket spans next 3 cells], `[note: W/6]`, `[note: W/6]`, `[note: W/6]`. Four visual cells of widths 3:1:1:1 (the first being three times wider than each nested-child cell).

For `*-*-* *` (mirror): top-level `[.nested(triplet), note]`. Visual cells: [nest bracket spans first 3 cells], `[note: W/6]`, `[note: W/6]`, `[note: W/6]`, `[note: W/2]`. Widths 1:1:1:3.

For `* * .-.` (8th-triplet with duplet on position 3): top-level K=3, per_cell = W/3. `[note, note, .nested(duplet)]`. Inside the nested Beat (K=2, allocated W/3, per_cell = W/6): `note, note`. Visual cells: `[note: W/3]`, `[note: W/3]`, [nest bracket], `[note: W/6]`, `[note: W/6]`. Widths 2:2:1:1.

For `* .-. *` (8th-triplet with duplet on position 2): `[note, .nested(duplet), note]`. Visual cells: `[note: W/3]`, [nest bracket], `[note: W/6]`, `[note: W/6]`, `[note: W/3]`. Widths 2:1:1:2.

For `.-. * *` (8th-triplet with duplet on position 1): `[.nested(duplet), note, note]`. Visual cells: [nest bracket], `[note: W/6]`, `[note: W/6]`, `[note: W/3]`, `[note: W/3]`. Widths 1:1:2:2.

For `. . . . . .` (flat sextuplet): K=6 flat, all notes. Six equal visual cells at W/6 each.

---

### Multi-beat forward-compat sketch

For a hypothetical 2-beat pattern, the renderer wraps the top level once more: total available width W maps to a *sequence* of two beats, each at width W/2. Each top-level beat is itself a `Beat` with its own subdivisions; the recursive rule applies unchanged.

Implementation sketch (not in scope for Epic 84):

```
visual_cells(pattern, W):
    beats = pattern.beats   // [Beat] for multi-beat; [singleton beat] for Epic 84
    beat_width = W / count(beats)
    for each beat in beats:
        emit visual_cells_for_beat(beat, allocated_width = beat_width)
```

For Epic 84, `pattern.beats.count == 1` for every entry. The current `TimingOffsetDetectionPattern` exposes `subdivisions: [Subdivision]` (i.e. one implicit beat); a future multi-beat-capable shape would expose `beats: [Beat]` or equivalent. The renderer's math doesn't care about the wrapping shape — it cares about the `Beat` tree the wrapper hands it.

**Beat-boundary marker (forward-compat only):** between adjacent beats at the top level, the renderer would emit a thin separator (e.g. a 1pt gap or a faint vertical line) so the user can distinguish a one-beat pattern from a same-cell-count multi-beat pattern. Not implemented in Epic 84 because every entry has exactly one beat.

---

## Grouping indicators

**Visual spec for nested figures:** a thin continuous horizontal line ("bracket") rendered above the span of nested-child visual cells.

- **Geometry (Dynamic-Type-aware):** thickness, offset, and inset all use `@ScaledMetric(relativeTo: .caption2)` so the bracket scales in lockstep with the cell dots (which use the same `caption2` token per 82.3's preview-scale convention). Base values at default Dynamic Type:
    - Thickness: **1.5pt** (was "1pt" — bumped to 1.5pt so the bracket remains visible at AX1 against the larger scaled dots; at AX1 the bracket renders at roughly `1.5 × scaleFactor` pt).
    - Offset above cell tops: **4pt** at full scale on the training screen; multiplied by `previewScale` (0.625) in the picker preview.
    - End-inset: **1pt** at full scale; multiplied by `previewScale` in the picker preview.
    - Length: spans from the start of the first nested-child visual cell to the end of the last nested-child visual cell, then inset symmetrically by the end-inset.
- **Continuity:** the bracket is a single continuous line, not a sequence of dashes. (ASCII renderings in this doc use `─` dashes for typographic limitation; the production rendering is one stroked path.)
- **Color:** `.primary` at 50% opacity. Same primary-color vocabulary the cell dots use; the 50% opacity distinguishes the bracket as structural-not-content.
- **No text.** No digit, no localized word, no glyph. The bracket is the *visual* affordance for the nesting; per-cell `accessibilityLabel`s carry the screen-reader burden (see § *Per-cell accessibility labels*, which extends the locked label form so the leading-nested accent's bracket membership is named in the label too — VoiceOver users do not lose the affordance the bracket gives sighted users).
- **No nesting-depth indicator.** Epic 84's deepest nesting is depth 1 (a single `.nested(Beat)` inside the top-level beat). A future epic that introduces depth-2 nesting would render brackets at both levels, stacked at increasing y-offsets above the cells. Not implemented in Epic 84.

**Rationale for the bracket form (not braces, not boxes, not background tints):**
- *Braces* — `{ ... }` — are localized typography and read as text glyphs to VoiceOver. Disqualified.
- *Boxes* — rendering a stroked rectangle around the nested span — would visually compete with the cell-border vocabulary already used for the doubled-glyph offset marker and the selected-cell highlight in the slot picker (per 82.3 § *Slot-picker chrome*).
- *Background tints* — coloring the nested-cell background — would conflict with the rest-cell de-emphasis already in the visual vocabulary.
- *Bracket lines above* — visually inert when not present, clearly structural when present, no conflict with existing primitives, scales naturally with Dynamic Type via the same `@ScaledMetric` rule the cells use.

---

## Per-cell accessibility labels

**UI surfaces these labels apply to:** the per-cell labels below are applied to (i) the pattern-picker preview row inside the Settings *Pattern* picker (currently `accessibilityHidden(true)` per `TimingDotView`; 84.3 unhides and applies the labels), and (ii) the Settings *Offset Note Position* slot picker. The slot picker additionally appends `", not selectable"` to position-1's label when the cell is rendered as the non-tappable anchor (preserving 82.3's locked slot-picker hint). Every other position's label is identical across both surfaces.

**Locked form** (extends 82.3's vocabulary; position-1 in flat patterns preserves the "Accent" form verbatim; position-1 when first audible of a leading nested child is extended to name the group — the rule below is normative, not the verbatim 82.3 form):

| Position kind | Label form |
|---|---|
| Position 1, top-level (not inside any nested child group) | `"Accent"` |
| Position 1, first audible of a *leading* nested child group | `"Accent, in <child-division>"` |
| Non-anchor audible at position N, top-level, no nesting context at this position | `"Note N of K"` (K = total audibles for the pattern) |
| Non-anchor audible at position N, inside a nested child group | `"Note N of K, in <child-division>"` |
| Non-anchor audible at position N, dotted duration (mixed-duration triplet only) | `"Note N of K, dotted"` |
| Rest cell | non-focusable; no label (per 82.3 § *Rest-cell a11y*) |
| Position 1 in slot picker (anchor cell) | locked form above, appended with `", not selectable"` |

**Why the leading-nest exception:** A sighted user sees the bracket and infers the accent is the leading cell of the nested group. A VoiceOver user without the leading-nest extension would hear `"Accent, Note 2 of 4, in triplet, Note 3 of 4, in triplet, Note 4 of 4, in triplet"` for `pattern_11` and infer the triplet starts at position 2 — losing the affordance the bracket gives. With the extension, they hear `"Accent, in triplet, Note 2 of 4, in triplet, …"` — correctly perceiving the leading triplet. The cost is one extra phrase on two entries (`pattern_11` and `pattern_14`); the benefit is parity with sighted users.

**Why hosts are not named for non-anchor labels:** For trailing or middle nested groups, the listener heard the preceding audibles at the host division before reaching the nested child, so the host's tempo is established. Naming the host on every nested-cell label doubles the readout for no added discriminability. The leading-nest case is the exception because no preceding audibles establish the host — but for the leading-nest case the bracket itself shows what's nested, and the position-1 label names the child division.

**Absorbed-rest non-focusability:** When a `.rest` leaf is absorbed into the preceding `.note`'s visual cell per the cell-width math § rule 4 (the common case: `note, rest` → one wider cell), the absorbed rest does NOT emit a separate accessibility element. The composite visual cell is a single focusable element labeled per the absorbing audible's position. Orphan rests (cases (a)–(c) of rule 4) DO emit their own non-focusable element. This keeps VoiceOver rotor traversal aligned with audible-position count.

**Child-division vocabulary:**
- `"triplet"` — nested 3-cell child (16th-triplet inside an 8th-position host)
- `"duplet"` — nested 2-cell child (duplet inside a triplet-8th-position host)
- `"sextuplet"` — reserved for future use (no Epic 84 entry uses it)

**Worked labels — every cell of every surviving entry:**

| Pattern | Pos 1 | Pos 2 | Pos 3 | Pos 4 | Pos 5 | Pos 6 |
|---|---|---|---|---|---|---|
| `* * * *` | Accent | Note 2 of 4 | Note 3 of 4 | Note 4 of 4 | — | — |
| `* - * *` | Accent | Note 2 of 3 | Note 3 of 3 | — | — | — |
| `* * - *` | Accent | Note 2 of 3 | Note 3 of 3 | — | — | — |
| `* - * -` | Accent | Note 2 of 2 | — | — | — | — |
| `* - - *` | Accent | Note 2 of 2 | — | — | — | — |
| `* * *` | Accent | Note 2 of 3 | Note 3 of 3 | — | — | — |
| `* * -` | Accent | Note 2 of 2 | — | — | — | — |
| `* - *` | Accent | Note 2 of 2 | — | — | — | — |
| `* *. .` | Accent | Note 2 of 3, dotted | Note 3 of 3 | — | — | — |
| `* *-*-*` | Accent | Note 2 of 4, in triplet | Note 3 of 4, in triplet | Note 4 of 4, in triplet | — | — |
| `*-*-* *` | Accent, in triplet | Note 2 of 4, in triplet | Note 3 of 4, in triplet | Note 4 of 4 | — | — |
| `* * .-.` | Accent | Note 2 of 4 | Note 3 of 4, in duplet | Note 4 of 4, in duplet | — | — |
| `* .-. *` | Accent | Note 2 of 4, in duplet | Note 3 of 4, in duplet | Note 4 of 4 | — | — |
| `.-. * *` | Accent, in duplet | Note 2 of 4, in duplet | Note 3 of 4 | Note 4 of 4 | — | — |
| `. . . . . .` | Accent | Note 2 of 6 | Note 3 of 6 | Note 4 of 6 | Note 5 of 6 | Note 6 of 6 |

**German wording** (informal `du`/imperative register per `feedback_german_informal`; 84.4 registers these via `bin/add-localization.swift`):

| English token | German token |
|---|---|
| Accent | Akzent |
| Note N of K | Note N von K |
| in triplet | in Triole |
| in duplet | in Duole |
| dotted | punktiert |
| not selectable | nicht auswählbar |

**Composition examples** (the labels above compose token-by-token; these are the surfaces 84.4 verifies are natural German with Michael as native speaker):

| English composed label | German composed label |
|---|---|
| `Accent` | `Akzent` |
| `Accent, in triplet` | `Akzent, in Triole` |
| `Accent, in duplet` | `Akzent, in Duole` |
| `Note 2 of 4, in triplet` | `Note 2 von 4, in Triole` |
| `Note 2 of 3, dotted` | `Note 2 von 3, punktiert` |
| `Accent, not selectable` (slot picker) | `Akzent, nicht auswählbar` |

**84.4 verification (light task):** before registering via `bin/add-localization.swift --batch`, run `bin/add-localization.swift --list` to identify which tokens are already registered from Epic 82.3 (likely `Akzent`, `Note N von K`, and `nicht auswählbar` if 82.3 registered the slot-picker form). Net-new German tokens for Epic 84 are: `in Triole`, `in Duole`, `punktiert`, plus the five section headers (see § *Categorization*). Michael (native German speaker) confirms composition naturalness during 84.4 review.

**Edge case — leading nested group (covered by the locked rule above):** For `.-. * *`, audible 1 is the first cell of the nested duplet → label `"Accent, in duplet"`. For `*-*-* *`, audible 1 is the first cell of the nested triplet → label `"Accent, in triplet"`. The grouping bracket renders over the two/three nested cells respectively; the VoiceOver label and the visual bracket carry the same information.

---

## Categorization

**Locked buckets** (single-axis: perceived host division + nesting):

| # | Bucket | Membership rule | Entries |
|---|---|---|---|
| 1 | Straight 16ths | Host 4 cells, no nesting, no rests | `* * * *` |
| 2 | Gapped 16ths | Host 4 cells, no nesting, contains rests | `* - * *`, `* * - *`, `* - * -`, `* - - *` |
| 3 | Triplets | Perceived host division 3, no nesting | `* * *`, `* * -`, `* - *`, `* *. .` |
| 4 | Nested | Top-level beat contains at least one `.nested(Beat)` child | `* *-*-*`, `*-*-* *`, `* * .-.`, `* .-. *`, `.-. * *` |
| 5 | Sextuplet | Perceived host division 6, no nesting | `. . . . . .` |

**Membership is exclusive.** Every entry fits exactly one bucket.

**The mixed-duration `* *. .` is bucketed as a *Triplet*, not a *Sextuplet*,** even though its engine representation is a 6-cell flat `Beat`. Rationale: the user *hears* it as a triplet derivative — three audibles with mixed durations forming a triplet feel. Bucket-by-perception, not by engine grid.

**`pattern_04` (`* - * -`) is bucketed as *Gapped 16ths*, not as a notional "Straight 8ths" bucket,** even though it audibly resembles two straight 8th notes. Rationale: structurally it lives on a 16ths-grid with rests, the rule-of-thumb's "perceived host division" yields *8ths* but no *8ths* bucket exists in Epic 84's scheme (and one isn't worth adding for a single entry). This is the one place where the *grid representation* trumps the *perception* in bucket assignment; called out explicitly so future contributors don't try to re-bucket it.

**Rule of thumb for future additions:**

> Pick the bucket by the *perceived* host division — what the listener hears as the primary pulse. If the pattern's host has any nested child group, it goes to *Nested* regardless of the host division. The 16ths buckets stay as today's two; tuplet-family buckets split by host division (3 → *Triplets*, 6 → *Sextuplet*). Add a new bucket only when a future epic introduces patterns whose perceived host division is not 4, 3, or 6.

**Picker section order** (top to bottom):
1. Straight 16ths
2. Gapped 16ths
3. Triplets
4. Nested
5. Sextuplet

**Rationale for ordering:** simplest-to-most-complex by rhythmic-perception load. New users land on Straight 16ths; advancing users explore Nested and Sextuplet. Not a "difficulty curve" per the Performance Principle — it's a navigation-friendliness ordering. Users may select any pattern from any section at any time.

**Section headers (English / German):**
- Straight 16ths / Gerade Sechzehntel
- Gapped 16ths / Lückenhafte Sechzehntel
- Triplets / Triolen
- Nested / Verschachtelt
- Sextuplet / Sextolen

**Section header behavior at AX1:** SwiftUI `Section { ... } header: { Text(...) }` defaults to `lineLimit(nil)` for `Text` — headers wrap to multiple lines at AX1 rather than truncate. This is the locked behavior: 84.4 does NOT apply `lineLimit(1)` or `truncationMode` to the section headers. The longest German header is "Lückenhafte Sechzehntel" (23 chars); at AX1 on iPhone portrait it will wrap to two lines. The 84.4 a11y test captures a screenshot at AX1 to confirm no truncation. If wrapping looks visually broken at AX1, the fallback is to abbreviate "Lückenhafte Sechzehntel" to "Lückenh. Sechzehntel" — a known-bad-state mitigation, not a default.

---

## Catalog

One row per entry. Every field is required.

The *Typed leaf sequence* column uses the four leaf kinds the cell-width math walks: `n` (`.note`), `r` (`.rest`), `[` (`.nest_enter`), `]` (`.nest_exit`). Spaces in the sequence are visual separators with no semantic meaning. The sequence is what `Beat.events(...)` and the renderer's depth-first walk produce; downstream stories implement against this exact form.

| ID | Notation | Bucket | `Beat` builder shape | Typed leaf sequence | Audible count | Pickable | Default |
|---|---|---|---|---|---|---|---|
| `pattern_01` | `* * * *` | Straight 16ths | Flat, K=4 | `n n n n` | 4 | {2,3,4} | 3 |
| `pattern_02` | `* - * *` | Gapped 16ths | Flat, K=4 | `n r n n` | 3 | {2,3} | 2 |
| `pattern_03` | `* * - *` | Gapped 16ths | Flat, K=4 | `n n r n` | 3 | {2,3} | 2 |
| `pattern_04` | `* - * -` | Gapped 16ths | Flat, K=4 | `n r n r` | 2 | {2} | 2 |
| `pattern_05` | `* - - *` | Gapped 16ths | Flat, K=4 | `n r r n` | 2 | {2} | 2 |
| `pattern_06` | `* * *` | Triplets | Flat, K=3 | `n n n` | 3 | {2,3} | 2 |
| `pattern_07` | `* * -` | Triplets | Flat, K=3 | `n n r` | 2 | {2} | 2 |
| `pattern_08` | `* - *` | Triplets | Flat, K=3 | `n r n` | 2 | {2} | 2 |
| `pattern_09` | `* *. .` | Triplets | Flat, K=6 (mixed-duration via multi-cell holds) | `n r n r r n` | 3 | {2,3} | 2 |
| `pattern_10` | `* *-*-*` | Nested | Top K=2; child at index 1 is `.nested(Beat(K=3, all notes))` | `n [ n n n ]` | 4 | {2,3,4} | 3 |
| `pattern_11` | `*-*-* *` | Nested | Top K=2; child at index 0 is `.nested(Beat(K=3, all notes))` | `[ n n n ] n` | 4 | {2,3,4} | 3 |
| `pattern_12` | `* * .-.` | Nested | Top K=3; child at index 2 is `.nested(Beat(K=2, all notes))` | `n n [ n n ]` | 4 | {2,3,4} | 4 |
| `pattern_13` | `* .-. *` | Nested | Top K=3; child at index 1 is `.nested(Beat(K=2, all notes))` | `n [ n n ] n` | 4 | {2,3,4} | 3 |
| `pattern_14` | `.-. * *` | Nested | Top K=3; child at index 0 is `.nested(Beat(K=2, all notes))` | `[ n n ] n n` | 4 | {2,3,4} | 2 |
| `pattern_15` | `. . . . . .` | Sextuplet | Flat, K=6 | `n n n n n n` | 6 | {2,3,4,5,6} | 4 |

**`pickable` excludes audible position 1 for every entry** (the metric anchor). Catalog-wide invariant: `pattern.pickable.contains(1) == false`. The default position is always a member of `pickable` (catalog-wide invariant enforced by `TimingOffsetDetectionPattern.init`).

**Per-entry default rationale** (Adam-approved, see § *Consultation with Adam*):

- `pattern_01`: default 3 — preserves Epic 82.7's `pattern_1111` default. Audible 3 = grid 3 = on the half-beat; strongest non-anchor in a 4-flat figure.
- `pattern_02`: default 2 — preserves Epic 82.7's `pattern_1011` default. Audible 2 = grid 2 = on the half-beat.
- `pattern_03`: default 2 — preserves Epic 82.7's `pattern_1101` default. Tie between audibles 2 and 3 (both equidistant from the gap); audible 2 stays per 82.3's per-entry rationale.
- `pattern_04`: default 2 — forced (single-pickable). Preserves Epic 82.7.
- `pattern_05`: default 2 — forced (single-pickable). Preserves Epic 82.7.
- `pattern_06`: default 2 — middle of the triplet; clearest "between-anchors" probe.
- `pattern_07`: default 2 — forced (single-pickable).
- `pattern_08`: default 2 — forced (single-pickable).
- `pattern_09`: default 2 — the dotted (long) cell; perceptually most marked.
- `pattern_10`: default 3 — middle of the nested 16th-triplet; cross-rhythm probe at the densest point.
- `pattern_11`: default 3 — middle of the nested 16th-triplet (mirror reasoning).
- `pattern_12`: default 4 — second cell of the trailing duplet; cross-rhythm landing into the next beat.
- `pattern_13`: default 3 — second cell of the middle duplet.
- `pattern_14`: default 2 — second cell of the leading duplet; cross-rhythm settle before the host triplet resumes.
- `pattern_15`: default 4 — perceptual midpoint of the sextuplet (3/6 = half-beat).

All defaults are starting points; playtest evidence may revise — as Epic 82 already established for `pattern_03`'s tie.

---

## At-scale renderings

ASCII / prose-level sketches of each entry as it appears in the picker-row preview. Two scales per entry: iPhone portrait (the design baseline) and Dynamic Type AX1 (the smallest a11y size before Dynamic Type stops scaling further). All renderings use the established visual vocabulary: `●` = normal-size audible dot, `◉` = `beatOneDotDiameter` accent dot, `─` = grouping bracket (above), space = rest absorption. Widths in the renderings are proportional; horizontal pitch reflects the cell-width math.

**Important — ASCII is illustrative, the cell-width math is canonical.** The renderings below use character-cell granularity which cannot reproduce sub-character-width ratios precisely. When the cell-width math says "W/2 : W/4 : W/4", the ASCII sketch approximates the proportion; downstream visual tests in 84.3 verify against the math, not against the sketch glyph spacing.

**Notation key** (applies to every rendering):
- The character `◉` denotes the accent dot at audible position 1 (always present, fixed size `beatOneDotDiameter`).
- The character `●` denotes a normal audible dot (`dotDiameter`).
- The character `─` denotes the nesting bracket; in the production rendering this is a single continuous stroked path, NOT a sequence of dashes (see § *Grouping indicators*). The ASCII discretisation is a typographic limitation.
- Horizontal spacing between glyphs in the rendering is proportional to the visual cell widths.
- Each glyph sits inside its visual cell; visual-cell boundaries are not drawn (the renderer does not stroke cell borders for the audible-cell preview).

### Straight 16ths

**`pattern_01` (`* * * *`):**

```
iPhone portrait:    ◉   ●   ●   ●
AX1:                ◉    ●    ●    ●
```

### Gapped 16ths

**`pattern_02` (`* - * *`):**

```
iPhone portrait:    ◉       ●   ●
AX1:                ◉         ●    ●
```

The accent's cell is twice the width of the trailing cells (W/2 vs W/4 each).

**`pattern_03` (`* * - *`):**

```
iPhone portrait:    ◉   ●       ●
AX1:                ◉    ●         ●
```

Audible 2's cell absorbs the trailing rest (width W/2); audible 1 and audible 3 are W/4.

**`pattern_04` (`* - * -`):**

```
iPhone portrait:    ◉       ●
AX1:                ◉         ●
```

Two visual cells of equal width (W/2 each); the "8ths feel" comes through.

**`pattern_05` (`* - - *`):**

```
iPhone portrait:    ◉           ●
AX1:                ◉             ●
```

Two visual cells of widths 3:1 (3W/4 vs W/4).

### Triplets

**`pattern_06` (`* * *`):**

```
iPhone portrait:    ◉    ●    ●
AX1:                ◉      ●      ●
```

Three equal visual cells at W/3 each.

**`pattern_07` (`* * -`):**

```
iPhone portrait:    ◉    ●
AX1:                ◉      ●
```

Two visual cells of widths 1:2 (W/3 vs 2W/3).

**`pattern_08` (`* - *`):**

```
iPhone portrait:    ◉        ●
AX1:                ◉          ●
```

Two visual cells of widths 2:1 (2W/3 vs W/3).

**`pattern_09` (`* *. .`):**

```
iPhone portrait:    ◉    ●       ●
AX1:                ◉      ●         ●
```

Three visual cells of widths 2:3:1 (W/3, W/2, W/6). The medium-long-short feel is the proportional spacing.

### Nested

**`pattern_10` (`* *-*-*`):**

```
iPhone portrait:           ─ ─ ─
                    ◉    ● ● ●
AX1:                       ─  ─  ─
                    ◉      ●  ●  ●
```

Top-level audible 1 sits in a W/2 cell. The bracket (`─ ─ ─`) spans audibles 2–4 inside the nested triplet (each at W/6).

**`pattern_11` (`*-*-* *`):**

```
iPhone portrait:    ─ ─ ─
                    ◉ ● ●     ●
AX1:                 ─  ─  ─
                    ◉  ●  ●      ●
```

Bracket over audibles 1–3 (the nested triplet); audible 4 sits in a W/2 cell at the right.

**`pattern_12` (`* * .-.`):**

```
iPhone portrait:                ─ ─
                    ◉    ●    ● ●
AX1:                              ─  ─
                    ◉      ●      ●  ●
```

Two top-level triplet cells (W/3 each), then a bracket over audibles 3–4 inside the nested duplet (W/6 each).

**`pattern_13` (`* .-. *`):**

```
iPhone portrait:         ─ ─
                    ◉    ● ●    ●
AX1:                       ─  ─
                    ◉      ●  ●      ●
```

Top-level audible 1 (W/3), bracket over audibles 2–3 inside the duplet (W/6 each), top-level audible 4 (W/3).

**`pattern_14` (`.-. * *`):**

```
iPhone portrait:    ─ ─
                    ◉ ●    ●    ●
AX1:                 ─  ─
                    ◉  ●      ●      ●
```

Bracket over audibles 1–2 inside the leading duplet (W/6 each), then top-level audibles 3 and 4 (W/3 each).

### Sextuplet

**`pattern_15` (`. . . . . .`):**

```
iPhone portrait:    ◉  ●  ●  ●  ●  ●
AX1:                ◉   ●   ●   ●   ●   ●
```

Six equal visual cells (W/6 each). The accent dot is larger; the five trailing audibles are normal-size.

---

### Pairwise distinguishability check

**Method:** for each within-bucket pair, evaluate visual distinguishability at AX1. Cross-bucket pairs are distinguishable via the section header (sectioning ships in 84.4); within-bucket pairs are the only ones where the dot-diagram itself must carry the discrimination. The table below enumerates EVERY within-bucket pair (C(n,2) per bucket: Straight 16ths and Sextuplet have one entry each — no within-bucket pairs; Gapped 16ths has 6 pairs; Triplets has 6 pairs; Nested has 10 pairs — total 22 within-bucket pairs).

| Bucket | Pair | Distinguishable at AX1? | Discriminator |
|---|---|---|---|
| Gapped 16ths | `02` vs `03` | Yes | Audible 2's cell width: `02` has W/2 audible 1 + W/4 audible 2; `03` has W/4 audible 1 + W/2 audible 2. Asymmetry direction differs. |
| Gapped 16ths | `02` vs `04` | Yes | Audible count differs (3 vs 2). |
| Gapped 16ths | `02` vs `05` | Yes | `02` is 3 audibles widths W/2:W/4:W/4; `05` is 2 audibles widths 3W/4:W/4. |
| Gapped 16ths | `03` vs `04` | Yes | Audible count differs (3 vs 2). |
| Gapped 16ths | `03` vs `05` | Yes | `03` is 3 audibles widths W/4:W/2:W/4; `05` is 2 audibles widths 3W/4:W/4. |
| Gapped 16ths | `04` vs `05` | Yes | `04` is 2 equal cells (W/2:W/2); `05` is 2 cells widths 3W/4:W/4. |
| Triplets | `06` vs `07` | Yes | Audible count differs (3 vs 2). |
| Triplets | `06` vs `08` | Yes | Audible count differs (3 vs 2). |
| Triplets | `06` vs `09` | Yes | `06` is 3 equal cells (W/3 each); `09` is 3 cells widths W/3:W/2:W/6 — the small final cell is the discriminating feature. |
| Triplets | `07` vs `08` | Yes | `07` is W/3:2W/3 (small-then-big); `08` is 2W/3:W/3 (big-then-small) — mirror shapes, asymmetry direction differs. |
| Triplets | `07` vs `09` | Yes | Audible count differs (2 vs 3). Even on shared first two cells (W/3 + something), `09` has a third small cell. |
| Triplets | `08` vs `09` | Yes | Audible count differs (2 vs 3). `08` ends in W/3; `09` has W/2 middle + W/6 final, recognisable. |
| Nested | `10` vs `11` | Yes | Bracket position (right vs left) — mirror shapes. |
| Nested | `10` vs `12` | Yes | `10`: bracket on cells 2–4 (3-cell triplet); `12`: bracket on cells 3–4 (2-cell duplet). Bracket length and end position differ. |
| Nested | `10` vs `13` | Yes | `10`: bracket spans 3 cells at the right; `13`: bracket spans 2 cells in the middle. Bracket length, start, end all differ. |
| Nested | `10` vs `14` | Yes | `10`: bracket spans 3 cells at the right; `14`: bracket spans 2 cells at the left including accent. Bracket-vs-accent relationship differs. |
| Nested | `11` vs `12` | Yes | `11`: bracket on cells 1–3 (3-cell triplet, leading); `12`: bracket on cells 3–4 (2-cell duplet, trailing). Bracket position fully opposite. |
| Nested | `11` vs `13` | Yes | `11`: 3-cell leading bracket; `13`: 2-cell middle bracket. Length and start position differ. |
| Nested | `11` vs `14` | Yes | Both have a *leading* bracket. `11`'s spans 3 cells (the triplet); `14`'s spans 2 cells (the duplet). Bracket length and child-division name in the position-1 a11y label both differ. |
| Nested | `12` vs `13` | Yes | Bracket on cells 3–4 vs 2–3 — visible at AX1; locked a11y labels differ at positions 2/3. |
| Nested | `12` vs `14` | Yes | Bracket on cells 3–4 vs 1–2; the leading bracket includes the accent dot in `14` (accent label is `"Accent, in duplet"`). |
| Nested | `13` vs `14` | **Borderline at AX1** — see below. | Bracket on cells 2–3 vs 1–2 — at AX1's coarsest scaling, the difference is one cell-width of bracket position. **Visual mitigation:** the accent dot (`beatOneDotDiameter` ≈ 22pt at full scale, scaled via `@ScaledMetric(.caption2)`) is markedly larger than non-anchor dots (`dotDiameter` ≈ 16pt). In `pattern_14`, the accent dot sits *inside* the bracket; in `pattern_13`, the accent dot sits *outside* the bracket (the bracket starts after audible 1). Since bracket thickness is now also `@ScaledMetric(.caption2)`-locked at 1.5pt base (see § *Grouping indicators*), accent-to-bracket size ratio remains ≈ 14:1 across all Dynamic Type sizes. **VoiceOver mitigation:** locked label at position 1 differs — `pattern_13` says `"Accent"`, `pattern_14` says `"Accent, in duplet"`. **Verdict:** distinguishable for both sighted and VoiceOver users; halt condition in 84.3's a11y test is a screenshot inspection at AX1 with pattern_13 and pattern_14 side-by-side. |

**Fallback if `pattern_13` vs `pattern_14` visual mitigation fails 84.3's screenshot inspection:** drop `pattern_13` (the position-2 nesting case), which Adam identified as the least musically essential of the three duplet-in-triplet entries. The drop retires `pattern_13` per the id convention (number stays retired in the catalog source-comment registry). Recorded as a known-bad-state mitigation, not an active design decision.

**Cross-bucket pairs:** trivially distinguishable for sighted users via section header (sectioning ships in 84.4); VoiceOver users hear the section announcement on section transitions. Not enumerated.

---

## Consultation with Adam

Captured verbatim from the 2026-06-04 consultation. Adam was framed with: (a) the Performance Principle as the design north star, (b) the engine model (`Beat` / `[Subdivision]` with `.nested(Beat)`, variable subdivisions, multi-cell holds), (c) the single-beat scope and the first-audible-excluded rule inherited from Epic 82.3, (d) the working candidate catalog from Epic 84's epic block, (e) the four design questions (catalog, categorization, a11y phrasing, distinguishability).

---

🎵 Hallo Michael — Adam hier. Skipping the menu since your intent is clear: a fresh consultation for Story 84.1's design lock.

Let me work through your four design questions in the order they affect downstream stories. I'll be opinionated where the musical evidence is strong, and explicit about where it's a judgment call.

### Framework first

Three frameworks overlap on this catalog and they should not be allowed to bleed:

1. **Metric/divisive theory** — patterns subdivide a beat into equal cells; rests and audibles populate cells. The five Epic-82 entries live entirely here.
2. **Tuplet theory** — a "tuplet" is a deliberate subdivision against the prevailing meter. Triplets-against-duple, duplets-against-triple, sextuplets, 16th-triplets-inside-8ths. The new catalog lives here.
3. **Rhythmic-perception research** — what listeners can actually distinguish under varying load. The Performance Principle's design north star; informs the "first audible never pickable" rule and pickable-set sizing.

The categorization decision lives in framework 1+2. The accessibility-label phrasing draws on 2+3. The per-entry default position is mostly 3, with 2 as a sanity check.

### On the working catalog — per entry

I'll give a verdict and one reason. Verdicts: **KEEP**, **KEEP with note**, **REVISE**, **DROP**.

**8th-note triplets (host division = 3):**

- **`* * *` — KEEP.** The reference triplet. Foundational; everything else in the *Triplets* bucket is read against it.
- **`* * -` — KEEP.** Tests perception of the trailing gap landing — common in jazz comping and bossa nova clave fragments.
- **`* - *` — KEEP.** The "long-short-long" feel — common in waltz syncopation and Celtic-style triplet figures. Distinct probe from `* * -` because the gap is between two audibles rather than after the last.
- **`* *. .` — KEEP with note.** Mixed-duration medium-long-short. This is **not swing** (your epic block already calls that out and you're right — swing is rubato-flexible, not strict-triplet-ratio). It is structurally a sextuplet-grid with holds: audibles at sextuplet cells 1, 3, 6 → durations 2:3:1 of the beat. Idiomatic in clave-derived 2-3-1 groupings, some Bulgarian aksak fragments, and the classical "anapest" rhythm at fast tempi. The cognitive load differs from straight triplet: user judges against a *learned shape* rather than against equal-spacing. Inclusion is justified — but flag for picker-row visual distinguishability (it looks proportionally like `* * *` plus a short tail). The renderer needs to make the long-cell clearly longer than the medium-cell at AX1.

**16th-triplets inside 8ths (host = 2, child = 3 at position 2 or 1):**

- **`* *-*-*` — KEEP.** 8th + nested 16th-triplet. Common in jazz fills, prog rock, Indian classical tihai-adjacent figures.
- **`*-*-* *` — KEEP.** Mirror. Pair coverage: trailing density vs leading density. Both are real.

**Duplets nested in triplet positions (host = 3, child = 2 at position 1, 2, or 3):**

- **`* * .-.` — KEEP.** Duplet at the tail. Probes leading-into-next-beat cross-rhythm. Common in West African and Cuban contexts.
- **`* .-. *` — KEEP with note.** Duplet in the middle. Least common in real repertoire (middle-of-three nestings carry less rhythmic weight), but valuable as the symmetric center case for systematic timing-perception coverage.
- **`.-. * *` — KEEP.** Duplet at the head. Probes downbeat cross-rhythm. Very common — most Latin syncopation begins this way.

**Set-level concern:** Three duplet-in-triplet entries that share the same nesting at different host positions risk visual collision at picker-row scale (especially AX1). The renderer must clearly distinguish *which* triplet position carries the duplet. If the proportional-timeline math + grouping indicator can't do this distinctly at AX1, the position-2 entry (`* .-. *`) is the one I'd consider dropping first — least musically essential of the three.

**Sextuplet (host = 6, flat):**

- **`. . . . . .` — KEEP.** Equal six. Covers fast-passagework timing perception. Distinct from triplets (subdivision rate is double).

**Adam's additions to consider — DEFER:**

- A *gapped sextuplet* like `. . - . . -` would extend the *Sextuplet* bucket and probe equal-six-with-gaps. Defer to a future epic — your 11-entry candidate set is already a lot for an initial expansion.
- A *quintuplet* or *septuplet* (5- or 7-tuplet) is musically valid but cognitively much harder; out of scope for initial timing-perception probing.

**Verdict on the set as a whole:** Covers triplet feel, triplet-with-gaps, mixed-duration triplet, faster-nested (16th-triplet-in-8th), cross-rhythm (duplet-in-triplet), and equal-fast (sextuplet). The set is **balanced for single-beat timing-perception competencies**. Green light.

### On categorization — revise the working scheme

Your working scheme *Straight / Gapped / Triplet / Sextuplet / Nested* mixes two axes (presence-of-rests + subdivision-family) and that produces collisions. `* * -` is simultaneously *Triplet* AND *Gapped*. `. . . . . .` is *Sextuplet* but it's also entirely flat (no rests, no nesting) — does "Straight" pull it? You'll have arguments at the bucket boundaries.

**Revised scheme — single axis (host subdivision family + nesting), five buckets:**

| Bucket | Membership rule | Epic-84 entries |
|---|---|---|
| **Straight 16ths** | Host division 4, no nesting, no rests after position 1 | `* * * *`, `* - * -` |
| **Gapped 16ths** | Host division 4, no nesting, contains rests | `* - * *`, `* * - *`, `* - - *` |
| **Triplets** | Host division 3, no nesting | `* * *`, `* * -`, `* - *`, `* *. .` |
| **Nested** | Mixed nesting depth (host has at least one `.nested` child) | `* *-*-*`, `*-*-* *`, `* * .-.`, `* .-. *`, `.-. * *` |
| **Sextuplet** | Host division 6, no nesting | `. . . . . .` |

**Membership is exclusive — every entry fits exactly one bucket.** Mixed-duration `* *. .` is a perceptual triplet (the user hears triplet pulses) even though it lives on a 6-cell engine grid; it goes in *Triplets*, not *Sextuplet*. This is the one place where the *perception* trumps the *grid representation*, and it's worth calling out in the design doc.

**Rule of thumb for future additions (write this verbatim in the doc):**

> Pick the bucket by the *perceived* host division — what the listener hears as the primary pulse. If the pattern's host has any nested child group, it goes to *Nested* regardless of the host division. The 16ths buckets stay as today's two; tuplet-family buckets split by host division (3 → *Triplets*, 6 → *Sextuplet*); add a new bucket only when a future epic introduces patterns whose host division is not 4, 3, or 6 (e.g. quintuplets at 5).

The five Epic-82 patterns redistribute exactly as your epic block already states. No revision needed there.

> **Reconciliation note from the implementing agent (not Adam — flagged so the discrepancy is visible):** Adam's *Straight 16ths* table row enumerates `* * * *`, `* - * -`. Adam's *Gapped 16ths* row enumerates `* - * *`, `* * - *`, `* - - *` (three entries). Adam's *rule* for Straight 16ths is "Host division 4, no nesting, no rests after position 1." `* - * -` has rests at positions 2 and 4 — by Adam's own rule, it belongs in *Gapped 16ths*. The locked categorization table earlier in this doc applies Adam's rule, placing `* - * -` in *Gapped 16ths* (4 entries) — not in Adam's enumeration's *Straight 16ths*. This is the implementing agent's interpretation of Adam's rule when Adam's table enumeration disagrees with the rule he wrote — a reasonable resolution but a unilateral interpretive act. If Michael wants to push back, the conservative alternative is to re-consult Adam for the specific case.

### On per-cell accessibility labels

The longer working candidate ("Note 3 of 4, inside duplet of 16th-triplets") names too much. The simpler candidate ("Position 3 of 4, nested duplet") loses the host context. **Compromise on a form that builds on 82.3's locked convention and stays compact:**

**Locked form:**
- Position 1 (always the metric anchor): `"Accent"` — **inherited verbatim from 82.3, do not change.**
- Non-anchor audible at position N (where K = total audibles), no nesting at this position: `"Note N of K"` — **inherited verbatim from 82.3.**
- Non-anchor audible at position N, position is inside a nested child group: `"Note N of K, in <child-name>"`

`<child-name>` is the bare child-division noun. Hosts are not named — they're context the listener inferred from the preceding audibles. Naming both child and host doubles the label length without adding discriminability in practice (screen-reader users who've heard the first two audibles already know the host).

**Child-name vocabulary:**
- `"triplet"` for nested 3-cell child (16th-triplet inside an 8th)
- `"duplet"` for nested 2-cell child (duplet inside a triplet 8th)
- `"sextuplet"` reserved for future use if a hypothetical 16th-triplet-inside-a-triplet shows up (not in this catalog)

**Special case — mixed-duration `* *. .`:** position 2 carries longer cell duration. Use `"Note 2 of 3, dotted"`. Position 3 stays `"Note 3 of 3"` (the short tail). The dotted descriptor lives at the position-2 label only; it's how the user perceives the "long one."

### On per-entry `defaultOffsetNotePosition`

The 82.3 principle holds: pick the position that probes the *most cognitively interesting* timing perception — typically the perceptual midpoint, the cross-rhythm cell, or the metrically-strongest non-anchor.

| Pattern | Pickable | Default | Rationale |
|---|---|---|---|
| `* * *` | {2, 3} | **2** | The middle of a triplet — clearest "between-anchors" probe. |
| `* * -` | {2} | **2** | Forced (single-pickable). |
| `* - *` | {2} | **2** | Forced. |
| `* *. .` | {2, 3} | **2** | The dotted (long) cell. Perceptually most marked — user's internal sense of "where the long lands" is sharpest. |
| `* *-*-*` | {2, 3, 4} | **3** | Middle of the nested 16th-triplet — cross-rhythm probe at the densest point. |
| `*-*-* *` | {2, 3, 4} | **3** | Middle of the nested 16th-triplet (same reasoning, mirrored). |
| `* * .-.` | {2, 3, 4} | **4** | Second of the duplet — the cross-rhythm landing into the next beat. Position 3 (first of the duplet) is musically valuable too; user can switch. |
| `* .-. *` | {2, 3, 4} | **3** | Second of the duplet — middle cross-rhythm. |
| `.-. * *` | {2, 3, 4} | **2** | Second of the leading duplet — the "cross-rhythm settle" before the host triplet resumes. |
| `. . . . . .` | {2, 3, 4, 5, 6} | **4** | Perceptual midpoint (3/6 = half-beat). Strongest secondary pulse in a flat sextuplet. |

These are starting points; playtest evidence may revise — as 82.3 already established for `pattern_1101`'s default.

### Hidden-assumption flags

Three landmines I want you to write into the design doc explicitly so downstream stories don't trip on them:

1. **The current `audibleToGrid` in `TimingOffsetDetectionPattern.swift` does NOT walk into `.nested(Beat)` children.** Line 24: "Excludes `.rest` (and, if it ever appears, `.nested`) entries." Your Epic 84 epic-block claims "no data-layer change" but this comment says otherwise. Either:
   - (a) `audibleToGrid` must be made recursive (collect audibles via depth-first walk of nested children, producing a path-based or flattened index), OR
   - (b) the picker presents the flat audible list itself by walking the `Beat` tree.

   Whichever route — 84.3 or 84.4's data-layer task — the design doc must call this out. *This is the one place where the epic block was overoptimistic about engine-as-is.*

2. **"Dotted" duration is a sextuplet-grid artefact, not a structural property.** When 84.4 registers `* *. .`, the `Beat` is `[note, rest, note, rest, rest, note]` on a 6-cell grid — the "dot" is implicit in the trailing two rests after the second audible. Accessibility-label-wise the user perceives a dotted long note, but the engine sees rests. The label text "dotted" is correct perceptually; the implementation must not derive "dotted" from any per-subdivision flag (none exists). It's named in the per-entry static label table only.

3. **The "first audible never pickable" rule extends without modification to nested figures** — but the *nesting* of the first audible matters for the label. In `.-. * *`, audible 1 is the first cell of a nested duplet; the duplet group encloses two cells but only the first is anchor. The duplet group's grouping indicator (which 84.3 designs) must render even though the audible inside it is labeled "Accent" not "Note 1 of 4, in duplet". Conceptually: the grouping indicator is about the *child group's extent*, not about any specific audible's label.

That's the consultation. Capture it verbatim in `tod-tuplet-renderer-design.md` § *Consultation with Adam*. Any of the verdicts you want to push back on, ask — I'd rather we lock the catalog with disagreement aired than with rubber-stamped agreement.

🎵 — Adam

---

## Constraint check

**Performance Principle:** The 10 new entries extend the rhythmic contexts TOD probes — triplet feel, mixed-duration triplet derivative, faster-nested cross-rhythm (16th-triplets-in-8ths), cross-rhythm at varying host positions (duplet-in-triplet at positions 1, 2, 3), equal-fast (sextuplet). No artificial constraint is introduced; every catalog entry gives the user another context in which to demonstrate timing perception. The catalog ordering (Straight → Gapped → Triplets → Nested → Sextuplet) is for navigation ease, not difficulty gating — users may select any entry at any time.

**Single-beat scope:** Every entry is a single-beat `Beat`. Multi-beat patterns are out of scope; the renderer math and id convention are forward-compatible without pre-building content.

**First-audible-excluded rule:** Every entry's `pickable` set excludes audible position 1. Verified at construction time by `TimingOffsetDetectionPattern.init`'s precondition. Catalog-wide invariant test required in 84.4.

---

## Notes for 84.2–84.4

### Story 84.2: Opaque pattern-id convention swap

**Derives from this doc:**
- The new convention rule (§ *Opaque pattern-id convention*).
- The rename map for the five Epic-82 entries (§ *Opaque pattern-id convention* table).
- The fallback-target id update (`pattern_1111` → `pattern_01`) for Epic 82.5's unknown-id-on-lookup behaviour.

**Exhaustive enumeration of code surfaces 84.2 touches** (the spec for 84.2 should treat this list as the verification checklist):

- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPattern.swift` — the five `static let` instances (`pattern1111`, `pattern1011`, `pattern1101`, `pattern1010`, `pattern1001`) are renamed to `pattern01`–`pattern05`. The `id:` string literal inside each instance becomes `"pattern_01"`–`"pattern_05"`.
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPatternCatalog.swift` — the catalog enumeration, `defaultPattern` (returns the renamed `pattern01`), the static `all` array (renamed instances + same order), and the unknown-id fallback target (returns `pattern01`). Add the retired-id registry comment block at the top (empty initially).
- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionSettingsKeys.swift` — the `clamped(_:)` helper's logic stays semantically identical; the literal default-id string changes from `"pattern_1111"` to `"pattern_01"`; the `@AppStorage` default value for `selectedPatternId` changes correspondingly.
- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionUserSettings.swift` — `@AppStorage` reads/writes against `selectedPatternId` key; the literal default-value string changes to `"pattern_01"`.
- The TOD `BeatProvider` implementation (search for `nextBeat()` in the TOD directory) — pattern-id lookups update.
- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift` — every pattern-id literal updates; selection-state comparisons against id strings update.
- All test files under `PeachTests/Training/TimingOffsetDetection/` referencing the old ids — update id literals and any test data that constructs patterns by name.
- `docs/planning-artifacts/tod-initial-pattern-catalog.md` — predecessor design doc retains the old ids as historical context; 84.2 adds a single forward note pointing to the rename map in `tod-tuplet-renderer-design.md`.

**Out of scope for 84.2** (doc reminder): no new entries register. The five Epic-82 patterns continue to render with the equal-cell renderer (the proportional renderer lands in 84.3). The picker stays flat (sectioning lands in 84.4).

**Documentation that 84.2 produces:** the rename map appears in 84.2's story spec for traceability; the *Spec Change Log* in 82.7's spec is NOT amended (Epic 82 is done; 84.2 is a successor change). The `@AppStorage` reset semantics — Michael's developer device gets `selectedPatternId` reset to `pattern_01` and `offsetNotePosition` reset to 3 on first launch after the swap (acceptable because the TOD-shipping cut has not reached the App Store) — are documented in 84.2's spec.

### Behaviour change for Epic-82 catalog when Story 84.3 ships

Worth surfacing up front so 84.3's PR description frames it correctly. The proportional-timeline renderer changes the visual appearance of the *existing five* catalog entries — even though no catalog content changes in 84.3:

- `pattern_01` (`* * * *`) — **unchanged** (4 equal cells stay 4 equal cells).
- `pattern_02` (`* - * *`) — accent dot's cell visibly widens to W/2 (absorbing the trailing rest); the two trailing audibles narrow to W/4 each. Previously: 4 equal cells with the rest position visually de-emphasized.
- `pattern_03` (`* * - *`) — audible 2's cell visibly widens to W/2 (absorbing the trailing rest); accent and audible 3 are W/4 each.
- `pattern_04` (`* - * -`) — visually now 2 cells of W/2 each (the "8ths feel" comes through). Previously: 4 equal cells with two visually-de-emphasized rests.
- `pattern_05` (`* - - *`) — accent dot's cell visibly widens to 3W/4 (absorbing both rests); audible 2 is W/4.

This is a *visual-only* change — sample-accurate audio is unchanged, the `Beat` shapes are unchanged, `pickable` and `defaultOffsetNotePosition` are unchanged, the per-cell `accessibilityLabel`s now apply per the new locked form. Users with persistent `selectedPatternId` (only Michael's dev device, since the TOD cut hasn't shipped to the App Store) experience the visual change on first launch after 84.3 lands. No migration shim needed. 84.3's PR description should frame this as "proportional renderer ships, behaviour visible at the existing five entries."

### Story 84.3: Proportional-timeline renderer

**Derives from this doc:**
- The cell-width math rule (§ *Cell-width math*).
- The grouping-indicator visual spec (§ *Grouping indicators*).
- The per-cell `accessibilityLabel` form (§ *Per-cell accessibility labels*).

**Implementation hand-off:** the existing `TimingDotView` becomes the proportional-timeline renderer. Today's `HStack(spacing: dotSpacing * scale)` + `ForEach(pattern.subdivisions.indices)` is replaced by:
1. A static function `visualCells(for: TimingOffsetDetectionPattern) -> [VisualCell]` that walks the `Beat` tree depth-first and produces typed visual-cell descriptors `(start_x_proportion, width_proportion, kind)` where `kind ∈ {accent, normalAudible, nestingBracket}`.
2. A SwiftUI layout that places each visual cell at its proportional x position with its proportional width — a `GeometryReader` providing the available width W, then absolute positioning per cell.
3. The doubled-glyph offset marker overlays the visual cell whose audible-position matches the user's `OffsetNotePosition` (via the same audible-walk used to compute visual cells).
4. The accent dot at audible position 1 uses `beatOneDotDiameter`; all other audibles use `dotDiameter`. Unchanged from 82.3.

**Unit tests:** `visualCells(for:)` is the testable static function. For each Epic-82 entry, a test asserts the produced `[VisualCell]` matches the expected widths from § *Cell-width math* worked examples. For each tuplet entry (registered in 84.4, not 84.3), a placeholder test stub exists in 84.3 with `@Test(.disabled("Pending pattern_06..15 catalog registration in 84.4"))`.

**Accessibility tests:** for each Epic-82 entry, a test enumerates per-cell `accessibilityLabel` strings against the expected values from the *Per-cell accessibility labels* table above. Tuplet-entry a11y tests are stubbed identically.

**Data-layer adjustment (Hidden Assumption #1 from Adam):** `TimingOffsetDetectionPattern.audibleToGrid` becomes recursive — a depth-first walk producing `[GridPath]` (or equivalent flat index encoding) instead of `[Int]`. The exact shape (flat indices vs paths) is 84.3's call; the public surface (`audibleCount`, `pickable`) keeps its semantics. This unblocks 84.4's tuplet registration.

### Story 84.4: Sectioned picker + tuplet catalog content

**Derives from this doc:**
- The locked categorization buckets and section order (§ *Categorization*).
- The complete catalog content — id, `Beat` builder shape, pickable set, `defaultOffsetNotePosition` (§ *Catalog* table).
- The per-cell `accessibilityLabel` worked-label tables (§ *Per-cell accessibility labels*).
- The English+German section header wording (§ *Categorization* table).
- The new German descriptors for `"in triplet"`, `"in duplet"`, `"dotted"` (§ *Per-cell accessibility labels*).

**Implementation hand-off:**
1. Replace the flat list in `TimingOffsetDetectionPatternPickerSettingsSection.swift` with a sectioned `List`/`Section` structure. Section headers vend via SwiftUI `Section { ... } header: { Text(...) }` so VoiceOver announces section transitions.
2. Register the 10 new `TimingOffsetDetectionPattern` static instances (`pattern_06` … `pattern_15`) in `TimingOffsetDetectionPatternCatalog.swift` with the `Beat` builder shapes from the *Catalog* table.
3. Register the four new German strings via `bin/add-localization.swift --batch <file.json>`: section headers (×5 — but verify each via `--list` first since some may collide with existing 82.3 entries), descriptors (×4: "in triplet", "in duplet", "dotted", plus any header missing).
4. `bin/add-localization.swift --missing` reports `0` before commit.

**Tests:**
- Per-entry `Beat`-builder correctness: each new pattern produces a non-empty `events(...)` output that matches the expected audible count at each pickable position.
- Catalog-wide invariant: `for each pattern: pattern.pickable.contains(1) == false`.
- Pattern-change reclamp (from Epic 82.6): switching from `pattern_01` to `pattern_06` reclamps `offsetNotePosition` to 2 (the new default).
- Section-header VoiceOver: the picker exposes 5 sections; section-header strings match the locked wording.

**Pre-commit gate:** `bin/test.sh && bin/test.sh -p mac` green on all four configurations (`Debug`, `Release`, `Debug (Research)`, `Release (Research)`).

---

## Cross-links

- [`tod-discipline-future-direction.md`](tod-discipline-future-direction.md) — receives a forward pointer to this doc for the four design questions Story 84.1 owns (renderer / a11y / categorization / catalog-content).
- [`epic-84-context.md`](../implementation-artifacts/epic-84-context.md) — receives "locked in 84.1 → see doc" pointers in § *Technical Decisions* and § *UX & Interaction Patterns* in place of the working-scheme language.
- [`tod-initial-pattern-catalog.md`](tod-initial-pattern-catalog.md) — predecessor; the rendering / a11y / categorization conventions established there are the baseline this doc extends. Receives a "Partially superseded" pointer in its header so future readers landing on the 82.3 doc discover this one.

## Review-iteration log

### 2026-06-04 — Review iteration 1

Three parallel adversarial reviews (blind hunter / edge-case hunter / acceptance auditor) ran against the v1 draft of this doc. Deduplicated findings + resolutions:

**Patched in-place (substantive design locks):**
- **Cell-width math completed** — the rule now defines every leaf-kind transition including orphan rests after `.nest_exit`, leading rests at depth-entry, and consecutive `.rest` runs. Forward-compat claim now actually holds. (§ *Cell-width math* step 4.)
- **Data-layer shape locked** — `audibleToGrid: [GridPath]` with `GridPath = [Int]` path-from-root semantics is specified here, not deferred to 84.3. Public surface (`audibleCount`, `pickable`, `beat(...)`) preserved. (§ *Inputs and constraints* "data-layer change" paragraph.)
- **Bracket geometry @ScaledMetric-locked** — thickness 1.5pt base, offset 4pt, end-inset 1pt, all `@ScaledMetric(relativeTo: .caption2)` so bracket-to-dot ratio stays constant across Dynamic Type sizes. The earlier 1pt was bumped to 1.5pt for AX1 visibility. Continuity (single stroked path, not dashes) made explicit. (§ *Grouping indicators*.)
- **Leading-nest accent a11y label rule extended** — position 1 when first audible of a leading nested child group now reads `"Accent, in <child-division>"` (not bare `"Accent"`). Pattern_11 label becomes `"Accent, in triplet"`; pattern_14 becomes `"Accent, in duplet"`. Restores screen-reader parity with the visual bracket. (§ *Per-cell accessibility labels* + worked-label table updates for `*-*-* *` and `.-. * *`.)
- **Per-cell labels: UI-surface clarification** — labels apply to both the picker preview row (84.3 unhides) and the slot picker (existing). Slot picker's position-1 cell appends `", not selectable"` to preserve the 82.3 hint. (§ *Per-cell accessibility labels* "UI surfaces" preamble.)
- **Absorbed-rest non-focusability** — explicit statement that a `.rest` absorbed into a preceding `.note`'s visual cell does NOT emit a separate accessibility element; the composite cell is one focusable element. (§ *Per-cell accessibility labels*.)
- **Pairwise distinguishability table completed** — every within-bucket pair (22 total) enumerated with discriminator. Cross-bucket pairs justified via section header. The sloppy `(sorry, 2:3:1)` parenthetical removed.
- **Opaque id convention governance** — id is fixed at first registration (reordering doesn't renumber); retired ids tracked in a comment block at the top of `TimingOffsetDetectionPatternCatalog.swift`; past-99 widening preserves existing ids (`clamped(_:)` accepts both two- and three-digit forms). (§ *Opaque pattern-id convention*.)
- **Pattern_04 host-division exception called out** — `* - * -` audibly resembles 8ths but is bucketed *Gapped 16ths* by grid representation; explicit note prevents future contributors from re-bucketing. (§ *Categorization*.)
- **Adam-vs-locked-doc reconciliation reworded** — "transcription clarification" changed to "implementing agent's interpretation of Adam's rule when his enumeration disagrees with it." More honest about the unilateral interpretive act. (§ *Consultation with Adam*.)
- **ASCII-illustrative disclaimer** — added at top of § *At-scale renderings* stating the cell-width math is canonical; ASCII spacing is approximate.
- **Catalog table "typed leaf sequence" column normalized** — uses `n`/`r`/`[`/`]` notation matching the cell-width math's leaf kinds. (§ *Catalog*.)
- **84.2 code-surface enumeration expanded** — exhaustive list of files/symbols 84.2 touches, including `defaultPattern`, `@AppStorage` defaults, the `BeatProvider`, and the predecessor doc's forward note. (§ *Notes for 84.2–84.4*.)
- **Behaviour change for Epic-82 catalog elevated** — new top-level subsection inside § *Notes for 84.2–84.4* enumerating per-entry visual changes for the existing five when 84.3 ships.
- **German composition examples added** — composed labels (`Akzent, in Triole` etc.) and a `--list` verification step for 84.4.
- **Section-header AX1 wrap behavior locked** — `lineLimit(nil)` (SwiftUI default); 84.4 a11y test screenshots at AX1; fallback abbreviation documented as known-bad-state.
- **Forward pointer added to predecessor doc** — `tod-initial-pattern-catalog.md`'s header gains a "Partially superseded by `tod-tuplet-renderer-design.md`" note so future readers don't miss the successor.

**Kept as-is (reviewer findings considered but not actionable):**
- *Adam's "user can switch" sub-clause for `pattern_12`'s default rationale*: the verbatim consultation captures Adam's nuance ("Position 3 is musically valuable too; user can switch"). The distilled per-entry rationale stays concise; future playtest can re-derive from the captured consultation. (§ *Consultation with Adam* preserves the full text.)

**Files affected by this iteration:**
- `tod-tuplet-renderer-design.md` — extensive amendments per the patches above.
- `tod-initial-pattern-catalog.md` — forward pointer added to header.
- `epic-84-context.md` — no further edits in this iteration (the 84.1 spec already flipped the relevant bullets in iteration 0).
- `tod-discipline-future-direction.md` — no further edits in this iteration.
- `84-1-tuplet-renderer-and-catalog-design.md` (story spec) — Spec Change Log entry appended; Verification section updated to reference iteration 1.

**Net effect:** the doc moved from "implementation-ready in shape, with three under-specified hand-offs" (per blind hunter) to "implementation-ready with all hand-offs locked." 84.3 no longer needs to invent `GridPath` shape; 84.4 no longer needs to discover the section-header wrap behavior; downstream a11y testing has explicit halt conditions.
