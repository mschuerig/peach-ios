# Epic 82 Context: Find the Off Note — TOD Pattern & Slot Flexibility

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Loosen the two axes that Timing Offset Detection (TOD) currently hard-codes: which note in a beat carries the timing offset, and which rhythmic figure that beat is. Today TOD plays four equally-spaced 16th notes per beat with the offset locked to the third note. This epic introduces (1) a per-trial setting for which note carries the offset (under today's fixed figure), then (2) a curated catalog of named patterns — gapped, syncopated, longer-than-beat — with a settings model that lets the user pick both the pattern and the offset-carrying note within it. Story 82.8 (added after the original epic close) lifts the `PEACH_RESEARCH` gate for TOD so the discipline ships in the next release; Continuous Rhythm Matching stays research-only.

## Stories

- Story 82.1: Offset slot as a setting on the current pattern (done)
- Story 82.2: Terminology decision for the offset-carrying note (this story — no code)
- Story 82.3: Initial pattern catalog and picker UX design (no code)
- Story 82.4: Apply terminology rename across the slot-setting surface introduced in 82.1
- Story 82.5: Pattern catalog domain layer wrapping `Beat`
- Story 82.6: Settings UI for pattern picker and rest-aware scalable slot picker
- Story 82.7: Ship the initial pattern catalog content
- Story 82.8: Lift the `PEACH_RESEARCH` gate for Timing Offset Detection so it ships in the next release; Continuous Rhythm Matching stays research-only

## Requirements & Constraints

- **Performance Principle:** TOD must let users perform their best. The fixed third-of-four arrangement is artificial constraint with no defensible musical or perceptual rationale; loosening it is the explicit goal.
- **Engine is already capable.** `Beat`/`Subdivision`/nested-`Beat` and `SoundFontStepSequencer` already support variable-length patterns, rests, and tuplets. This epic adds a catalog/wrapper layer plus Settings UI; it does not modify the engine.
- **Curated catalog only.** Users pick from a curated set; arbitrary user-defined patterns are out of scope.
- **TOD was `PEACH_RESEARCH`-gated for stories 82.1–82.7.** New tests in those stories were wrapped in `#if PEACH_RESEARCH`. Story 82.8 (added after the original epic close) lifted the gate; from 82.8 forward, TOD ships in every configuration and CRM stays research-only.
- **No `@AppStorage` migration shims.** Research-build users are developers; document any reset explicitly when keys are renamed.
- **Terminology constraints (this story specifically):**
  - Must frame TOD as detecting *unintentional playing errors*, not cataloging deliberate rhythmic gestures.
  - Must not collide with "rhythmic displacement" (a music-theory term for intentional, grid-aware shifts). "Displaced" is explicitly rejected.
  - Must read naturally in English settings labels and in informal German (`du`/imperative per project convention).
- **Slot-picker primitive must be rest-aware by 82.6.** Rests are not pickable; they render de-emphasized and refuse taps. Equal-cell layout is acceptable for the initial catalog (no tuplets).
- **No tuplet patterns in the initial catalog.** Catalog domain layer is tuplet-capable by construction, but the picker renderer stays equal-cell. Tuplets become a follow-up epic.

## Technical Decisions

- **Engine layer is fixed.** `Beat` / `Subdivision` / `SoundFontStepSequencer` are not modified by this epic. `.nested(Beat)` is the tuplet mechanism, `.rest` is the rest mechanism.
- **New domain wrapper (`NamedPattern`) lands in 82.5.** Wraps a `Beat`-builder with display metadata and per-slot picker info. Slot indices address *audible* positions, not raw subdivision indices, so future tuplet patterns can present a flat pickable list. Carries a stable id, a `LocalizedStringResource` display name, flat per-slot metadata (note vs. rest), and `func beat(offsetSlot: Int, offsetAmount: Duration) -> Beat`.
- **`TODPatternCatalog` (working name) is the registry.** `@MainActor` singleton; today's fixed pattern is the only entry until 82.7. Unknown id lookups raise a typed error, not a crash.
- **Settings shape after the epic:** two `@AppStorage` keys — selected pattern id and offset-carrying note position (1-based) — and a corresponding pair of fields on `TimingOffsetDetectionSettings`.
- **`BeatProvider` consults the catalog.** After 82.5, the TOD `BeatProvider` resolves the active pattern from the catalog and applies the offset to the chosen note position; until then, the placeholder code path from 82.1 stands.
- **Today's pattern stays as the default.** Migration paths preserve current behavior on existing settings.
- **Naming convention for indices:** `Position` ⇒ 1-based (user-facing, settings, accessibility); `Index` ⇒ 0-based (internal arrays). 82.1 established this; stay consistent through 82.4–82.7.

## UX & Interaction Patterns

- **Settings UI evolves in stages, not at once.** 82.1 introduced a four-cell single-select grid in a new TOD Settings section, visually mirroring `RhythmGapPositionsSettingsSection` chrome. 82.6 evolves that grid into a rest-aware, N-cell scalable picker driven by the chosen pattern's metadata. The pattern picker is a new Settings row landing in 82.6.
- **Slot widget is generic from the start.** Frame the slot widget as "which note carries the offset," not "third of four" — same widget should scale to N without redesign.
- **Pattern row organization.** Settings is organized as if the pattern were a (currently fixed) setting in the same section — future expansion fills the existing layout rather than rearranging it.
- **Preview rendering for patterns.** Resolved by 82.3: reuse `TimingDotView`'s visual vocabulary (large accent dot for position 1, smaller dots for other audible notes, doubled-glyph indicator for the Offset Note, empty cell for rests) at a smaller scale in the Settings preview. See [`../planning-artifacts/tod-initial-pattern-catalog.md` § *Preview Rendering*](../planning-artifacts/tod-initial-pattern-catalog.md#preview-rendering).
- **Accessibility:** slot picker cells vend selection state and a per-cell label ("Note N of 4"); rest slots read "unavailable" and refuse taps. Pattern picker vends as a `Picker` or `.accessibilityRepresentation { Picker(...) }`. Pattern changes announce the new pattern.
- **Localization:** every new user-facing string gets a German translation via `bin/add-localization.swift`, informal `du`/imperative. Sober, factual copy — no marketing hyperbole.

## Cross-Story Dependencies

- **82.1 → done.** Introduced the placeholder `offsetNotePosition` key, the four-cell single-select Settings section, and parameterized `buildBeat`.
- **82.2 (this story) and 82.3 run in parallel after 82.1.** Both are no-code; neither blocks the other.
- **82.4 follows 82.2.** Applies the rename decided here across the surface 82.1 introduced. No migration shim — research build users are developers, document the reset.
- **82.5 follows 82.3.** Introduces `NamedPattern` + `TODPatternCatalog` with today's pattern as the only entry; behavioral no-op proving the wiring.
- **82.6 follows 82.4 + 82.5.** Settings UI for pattern picker + rest-aware scalable slot picker.
- **82.7 follows 82.6.** Ships the curated catalog content.
- **External dependency — Epic 81.** The Settings-screen control taxonomy established in 81.1–81.3 is the visual vocabulary 82.6 draws from.
- **Auto-memory `feedback_tod_no_displaced_term.md`** records the "no displaced" constraint and the open-terminology status as of 2026-06-03. 82.2 updates or retires it once the term is settled.
