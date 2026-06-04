# Epic 84 Context: TOD Tuplet Patterns

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Expand the Timing Offset Detection (TOD) pattern catalog with tuplet-structured rhythms — 8th-note triplets (full and gapped), 16th-note triplets nested inside 8ths, duplets nested inside 8th-triplet positions, sextuplets, and mixed-duration triplet derivatives. Epic 82 deferred all of these to keep its equal-cell picker renderer valid; this epic introduces a proportional-timeline renderer that makes them visually coherent, swaps the catalog onto a single opaque pattern-id convention shared by old and new entries, and adds sectioned picker chrome so the growing catalog stays scannable. Forward-compatible with the anticipated multi-beat / syncopation follow-up epic without pre-building for it.

## Stories

- Story 84.1: Lock the renderer math, accessibility semantics, picker categorization, and tuplet catalog set (no code)
- Story 84.2: Swap all pattern ids to the new opaque convention (data-only, no catalog additions)
- Story 84.3: Replace the equal-cell renderer with the proportional-timeline renderer (existing five patterns only)
- Story 84.4: Section the picker and register the tuplet catalog content

## Requirements & Constraints

- **Engine is untouched.** `Beat` / `Subdivision` / `SoundFontStepSequencer` already support `.nested(Beat)`, variable subdivision counts, rests, and the mixed-duration shape (representable as a sextuplet grid with multi-cell holds). This epic adds renderer + catalog content only.
- **Curated catalog only.** Arbitrary user-defined patterns remain out of scope.
- **No localized per-pattern names or captions.** Pattern identity is the visual preview; per-cell `accessibilityLabel`s carry the screen-reader burden. Section headers are localized; pattern entries are not.
- **No `@AppStorage` migration shim** for the id rename. The TOD-shipping cut has not reached the App Store, so a one-time reset of `selectedPatternId` and `offsetNotePosition` on Michael's device is acceptable and must be documented in the story spec.
- **Pre-commit gate.** `bin/test.sh && bin/test.sh -p mac` green on every story.
- **Localization.** German via `bin/add-localization.swift`, informal `du`/imperative. `--missing` reports `0`.
- **Forward compatibility.** Renderer math and id convention designed so the multi-beat / syncopation follow-up epic extends without re-architecting.

## Explicitly out of scope

- Longer-than-beat and multi-beat syncopated patterns (likely-near-term follow-up epic).
- Patterns starting with a rest (require external pulse / metronome).
- A metronome feature; a "swing" toggle or swing-labeled UI; lifting the `PEACH_RESEARCH` gate on Continuous Rhythm Matching.
- Changes to the Offset Note magnitude control or the early/late direction control.

## Technical Decisions

- **Locked in 84.1** → see [`../planning-artifacts/tod-tuplet-renderer-design.md`](../planning-artifacts/tod-tuplet-renderer-design.md) for the full design: proportional-timeline cell-width math, opaque pattern-id convention with rename map, grouping-indicator visual spec, per-cell accessibility-label form (Adam-approved), sectioned categorization, and the complete tuplet catalog with per-entry `defaultOffsetNotePosition` rationale.
- **Proportional-timeline renderer** replaces Epic 82's equal-cell renderer at the existing TOD preview site (`TimingDotView` is the renderer; the picker site is `TimingOffsetDetectionPatternPickerSettingsSection`). Cell positions derive from each pattern's `Beat` representation via a uniform rule over the tree — no per-entry magic numbers; cell-position math is a `static` function for unit-testability. Non-textual grouping indicators (1pt brackets above nested-child spans) render for nested figures. The position-1 accent marker (`beatOneDotDiameter`) and the Offset Note doubled-glyph marker carry over unchanged from Epic 82.
- **Opaque pattern-id convention:** `pattern_NN` (zero-padded sequence). The five Epic-82 ids rename to `pattern_01` … `pattern_05`; tuplet entries are `pattern_06` … `pattern_15`. The convention is forward-compatible with multi-beat patterns (just keep numbering). 84.2 applies the rename across `TimingOffsetDetectionPatternCatalog`, `TimingOffsetDetectionSettingsKeys.clamped(_:)`, the TOD `BeatProvider`, the picker, and tests. The unknown-id-on-lookup fall-back from Epic 82.5 is preserved (fall-back target id updates from `pattern_1111` to `pattern_01`).
- **Sectioned picker** via SwiftUI `Section { header: Text(...) }` so VoiceOver announces section transitions. **Locked scheme:** *Straight 16ths / Gapped 16ths / Triplets / Nested / Sextuplet* (single-axis: perceived host division + nesting; membership exclusive). The five Epic-82 patterns redistribute as: *Straight 16ths* (`pattern_01`), *Gapped 16ths* (`pattern_02`, `pattern_03`, `pattern_04`, `pattern_05`).
- **Catalog construction.** Each tuplet entry constructs its `Beat` using existing primitives — `.nested(Beat)` for nested figures; sextuplet subdivision with multi-cell holds for the mixed-duration `* *. .` figure.
- **Data-layer caveat** flagged by Adam in 84.1: today's `TimingOffsetDetectionPattern.audibleToGrid` walks only top-level `.note` subdivisions; it must become recursive to address audibles inside `.nested(Beat)` children. 84.3 owns this adjustment as part of the renderer work, unblocking 84.4's tuplet registration.
- **"First audible note excluded" rule** from Epic 82.3 extends unchanged — all patterns here are single-beat. Per-entry `pickable` derives from the rule; `defaultOffsetNotePosition` per the Adam-approved rationale in 84.1's *Catalog* section. Pattern-change reclamp of `offsetNotePosition` (from Epic 82.6) must remain correct across category boundaries.
- **Settled terminology (inherited, no new terms).** Offset Note / Offset Note Position; code identifier `offsetNotePosition`. "Slot" stays engineering-vocabulary only. The "no displaced" guardrail is load-bearing (see `feedback_tod_no_displaced_term`). "TOD" is shorthand only — never in code identifiers (`feedback_tod_shorthand_only`).

## UX & Interaction Patterns

- **Locked in 84.1** → see [`../planning-artifacts/tod-tuplet-renderer-design.md`](../planning-artifacts/tod-tuplet-renderer-design.md) for the at-scale ASCII renderings of every entry at iPhone portrait + Dynamic Type AX1 and the pairwise distinguishability check.
- **Visual-is-identity.** Picker rows are dot-diagram previews with no display name. Per-cell `accessibilityLabel`s carry the screen-reader burden.
- **Proportional spacing communicates grouping** as positioning math derived from the `Beat` tree, not an ad-hoc visual rule. Nested figures get a 1pt grouping bracket above the nested-child span (`.primary` at 50% opacity, 1pt-inset endpoints). No text glyphs, no localised symbols.
- **Per-cell `accessibilityLabel` form** (locked, Adam-approved): position 1 → `"Accent"`; non-nested non-anchor → `"Note N of K"`; nested non-anchor → `"Note N of K, in <child-division>"` (`<child-division>` ∈ {`triplet`, `duplet`}); mixed-duration `* *. .` position 2 → `"Note 2 of 3, dotted"`. Hosts are not named in the label. Existing rest-cell "unavailable / non-focusable" semantics from 82.3 preserved.

## Cross-Story Dependencies

- **Stage 1 (84.1) blocks Stages 2–4.** Stages 2 (84.2 id swap) and 3 (84.3 renderer) are independent and may merge in either order. Stage 4 (84.4 sections + content) follows both. Each stage is its own commit and PR.
- **Predecessor — Epic 82.** This epic is modeled on Story 82.3's lock-the-inputs design pattern (84.1 → 82.3), reuses the catalog/wrapper layer from 82.5, and replaces the renderer + picker chrome 82.6 shipped. Story 82.7's catalog content is the input set Stage 2 renames.
- **Predecessor — Epic 81.** Settings control taxonomy established in 81.1–81.3 is the visual vocabulary the picker draws from.
- **Adam (music domain expert) consult** is mandatory for 84.1 per `reference_music_domain_expert` — candidate catalog is the starting input, not the final set; entries may be added, removed, or revised on Adam's evidence.
- **Successor — multi-beat / syncopation epic** (not yet drafted). Renderer math and id convention here are designed to extend without re-architecting; content for that axis stays out.
