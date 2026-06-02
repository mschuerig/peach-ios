# Epic 81 Context: Tune the Controls — Settings Screen Consistency

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

The Settings screen has accumulated heterogeneous controls (Stepper, Slider, Picker, custom grid) chosen ad-hoc rather than by the kind of value being set. This epic codifies a Settings control taxonomy and migrates the three areas that diverge most visibly from it: continuous numeric values currently presented as Steppers (Note Duration, Note Gap, Tempo) move to a reusable continuous-value slider with an inline live numeric readout; the Timing Offset Detection max-repetitions Picker becomes a discrete-stops slider snapping to `[1, 2, 3, 5, 10, ∞]`; the Lowest/Highest Note Steppers become a single domain-shaped piano-keyboard control with two draggable bound markers. The win is visual coherence on a screen that reads as a hodge-podge today, plus a documented home for future settings so contributors no longer choose controls ad-hoc.

## Stories

- Story 81.1: Continuous-value slider taxonomy and stepper migration
- Story 81.2: TOD Max Repetitions discrete-stops slider
- Story 81.3: Piano-keyboard control for training note range

## Requirements & Constraints

- UI-only epic. Underlying `@AppStorage` keys, default values, range constraints, the `UserSettings` protocol surface, persistence formats, CSV contracts, training-session behaviour, and domain types (`MIDINote`, `NoteRange`, etc.) are all unchanged. No schema migration, no settings-port changes.
- The taxonomy itself is a deliverable: record it as a doc comment near the new view or on `SettingsScreen` so future contributors can route new controls correctly without a fresh UX consultation.
- Three controls explicitly stay as they are: Concert Pitch (Stepper — value has named landmarks like 415/432/440/442 Hz, drag is a regression), Vary Loudness (abstract-dial Slider), and the Sound Source / Tuning System Pickers (large enumerated sets). The Intervals selector and Gap Positions grid already conform to the "small enumerated set" idiom.
- Accessibility coverage is mandatory for every new or migrated control: VoiceOver-adjustable behaviour, Switch Control increment/decrement, Voice Control "Tap <element>" addressability, Dynamic Type at AX sizes, and 44×44 pt minimum tap targets (FR38). Custom controls vend an `.accessibilityRepresentation { Slider(...) }` where the underlying semantics are "adjustable scalar bound."
- All new and changed user-facing strings ship in English and German in the same story. German uses informal `du` / imperative form. Use `bin/add-localization.swift` for German strings; never hand-edit `Localizable.xcstrings`.
- macOS parity: keyboard navigation must work for any custom control (Tab between adjustable elements, arrow-key nudge by one semitone, modifier-arrow nudge by one octave, Home/End jump to the bound's legal min/max). The Settings scene is reachable via Cmd+, (FR106).
- Tests: unit-test the layout/snap math (forward and inverse keyboard hit-test, discrete-stop snapping, range-bound clamping, value-display formatting) and UI-test the user-visible behaviours that the unit tests can't cover (drag-snap, tap-to-extend, minimum-span enforcement, single-fire drag-release audio cue). Existing settings-aggregation tests must continue to pass unchanged.

## Technical Decisions

- **Settings Control Taxonomy (codified by this epic):**
  - *Continuous / perceptual* (felt-for, exact number incidental): slider with monospaced inline live numeric value and optional flanking `−` / `+` precision buttons. Today: Note Duration, Note Gap, Tempo.
  - *Abstract dimensionless dial* (off-to-max, no number matters): slider with min/max end labels, no numeric value. Today: Vary Loudness.
  - *Bounded range inside a fixed domain* (value lives in a domain with its own visual vocabulary): domain-shaped custom control. Today: piano keyboard for MIDI notes.
  - *Small enumerated set with semantic differences* (3–8 named choices, qualitatively distinct): custom row — grid tiles, multi-select grid, or discrete-stops slider — sharing the slider visual chrome. Today: TOD Max Repetitions, Intervals, Gap Positions.
  - *Large enumerated set* (too many to lay out): `Picker`. Today: Sound Source, Tuning System.
  - *Precise value where ±1 matters more than feel* (user knows the target number): `Stepper`. Today: Concert Pitch.
  - *Action / destructive operation*: `Button` with `.destructive` where appropriate; outside the taxonomy.
- **Reusable view: `ContinuousValueSlider<Value>`** — label left, monospaced-digit live value right (`.monospacedDigit()`), `Slider(value:, in:, step:)` below, optional flanking `−` / `+` buttons that increment/decrement by `step` and clamp at range bounds. Story 81.1 establishes this chrome; 81.2 reuses it for the discrete-stops variant.
- **Discrete-stops slider** (TOD Max Repetitions) shares the 81.1 chrome but maps slider position non-linearly to the qualitative stops `[1, 2, 3, 5, 10, ∞]` with equal *visual* spacing between stops and tick marks at each. The `∞` glyph renders at the rightmost stop. The underlying storage value at the cap is the existing `defaultMaxRepetitions` integer — no encoding change.
- **Domain control: `NoteRangeSelector`** renders all 88 keys A0–C8 (MIDI 21–108) with correct white/black key proportions, full-saturation in-range keys, ~35% opacity out-of-range keys, and every C labelled below in caption text. Two bound markers as chevron tabs above the keyboard with `MIDINote.name` pills snap to the nearest semitone on drag. The 12-semitone minimum span (`NoteRange.minimumSpan`) is enforced by stopping the active marker at the limit; the other marker does not move. Tap a dimmed key → the nearer bound jumps to it; tap inside the selection is a no-op.
- **Recover `PianoKeyboardLayout`** from commit `2e7cf102^` (last living revision before its Mar 23 2026 deletion) into `Peach/Core/Music/PianoKeyboardLayout.swift`, port to the current `MIDINote` / `NoteRange` API, and extend with the inverse hit-test `midiNote(at x: CGFloat, totalWidth: CGFloat) -> MIDINote`.
- **Audio preview** for `NoteRangeSelector` fires on drag-release only (not during drag), single short-envelope play via the currently-selected sound source, cancellable on view disappear.

## UX & Interaction Patterns

- **Layout adaptation:** iPhone portrait renders the keyboard as a horizontally scrolling view with auto-scroll on first appearance to centre the current selection; iPad and macOS fit the full 88 keys by default.
- **Accessibility — sliders (81.1 / 81.2):** `.accessibilityValue` reads the localised value with unit (e.g., "1.2 seconds", "120 BPM", "unbegrenzt" at the `∞` cap). Each `−` / `+` button has its own `.accessibilityLabel` and `.accessibilityHint`. The discrete-stops slider vends as a Slider-equivalent so VoiceOver swipe-up/down moves between stops, not by linear value.
- **Accessibility — keyboard control (81.3):** Vends as two adjustable elements via `.accessibilityRepresentation { Slider(value: bound, in: legalRange, step: 1) }` so VoiceOver rotor and Switch Control increment/decrement work without custom gesture handling. Each key carries an `.accessibilityLabel` of its note name (`"C3"`, `"F sharp 4"`) so Voice Control's "Tap C3" works. macOS: Tab between markers; ← / → nudge one semitone; ⇧← / ⇧→ nudge one octave; Home / End jump to legal min/max for that bound.
- **Dynamic Type at AX1+:** marker pills would overlap, so the keyboard collapses to a single summary line (`"Lowest C2 · Highest C6"`) and the keyboard becomes view-only; adjustment falls back to the slider rotor or a "Pick from list" custom action.
- **Visual consistency:** All migrated controls live inside the existing `Form`-based Settings screen and use SwiftUI semantic colors and Dynamic Type; nothing in this epic introduces a custom color palette or non-system font.

## Cross-Story Dependencies

- **Strict work order within the epic: 81.1 → 81.2 → 81.3.** 81.1 establishes the slider chrome that 81.2's discrete-stops variant builds on. 81.3 is independent of the slider chrome but ships last because it is by far the largest review surface; bundling it with 81.1/81.2 would obscure both.
- **No cross-epic dependencies on in-flight work.** Epic 81 is a UI refactor on top of the post-Epic-77 plugin model and the existing settings ports; it neither adds central seams that 77 removed nor changes any discipline's session behaviour.
