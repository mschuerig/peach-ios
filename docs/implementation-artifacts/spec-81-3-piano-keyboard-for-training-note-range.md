---
title: 'Story 81.3: Piano-keyboard control for training note range'
type: 'feature'
created: '2026-06-03'
status: 'done'
baseline_commit: '0ee60ed8'
context:
  - '{project-root}/docs/implementation-artifacts/epic-81-context.md'
  - '{project-root}/docs/implementation-artifacts/spec-81-1-continuous-value-slider-taxonomy-and-stepper-migration.md'
  - '{project-root}/docs/implementation-artifacts/spec-81-2-tod-max-repetitions-discrete-stops-slider.md'
  - '{project-root}/docs/project-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Settings → Training Range exposes the training note range as two `Stepper` controls (`Lowest Note: %@`, `Highest Note: %@`), each scoped against the other (low's max = high − 12, high's min = low + 12). On a screen now dominated by sliders after 81.1/81.2, twin Steppers for what is conceptually "pick two endpoints on the same domain" reads as inconsistent — and the Stepper hides the domain entirely (the user does not see *what* the range is part of; they tap `+`/`−` against an opaque MIDI note label). Single-step Stepper traversal across A0–C8 (88 keys) is slow and gives no spatial sense of the selection's width within the piano's full range.

**Approach:** Replace the two Steppers with a single domain-shaped `NoteRangeSelector` that renders the full 88-key piano (MIDI 21 / A0 — MIDI 108 / C8) with in-range keys at full saturation, out-of-range keys at ~35 % opacity, every C labelled below in caption text, and two draggable bound markers (chevron + `MIDINote.name` pill) above the keyboard. Drag snaps to the nearest semitone; tap on a dimmed key jumps the nearer bound; the 12-semitone minimum span is enforced by stopping the active marker. The 88 keys fit by default on iPad and macOS; on iPhone portrait the keyboard scrolls horizontally and auto-scrolls on first appearance to centre the current selection. Storage (`@AppStorage` `noteRangeMin` / `noteRangeMax` as `Int`) is unchanged.

## Boundaries & Constraints

**Always:**
- `@AppStorage` keys `noteRangeMin` / `noteRangeMax` (Int, MIDI rawValue), their defaults (36 / 84 → C2 / C6), `SettingsKeys.absoluteMinNote` / `absoluteMaxNote` (21 / 108), `NoteRange.minimumSpan` (12), the `NoteRange` precondition, and `MIDINote.validRange` (0...127) are unchanged. No schema migration. No changes to `MIDINote`, `NoteRange`, or `SettingsKeys` beyond what `NoteRangeSelector` needs to *read* (it adds no new stored state).
- Recover `PianoKeyboardLayout` from `2e7cf102^:Peach/Profile/PianoKeyboardView.swift` into a new file `Peach/Core/Music/PianoKeyboardLayout.swift`. Port the API from `midiNote: Int` parameters to `MIDINote` / `NoteRange`; keep the pure-geometry shape (no SwiftUI imports — `Core/Music/` is framework-free per `archlint.yaml`). Extend it with the inverse hit-test `func midiNote(at x: CGFloat, totalWidth: CGFloat) -> MIDINote` that returns the MIDI note whose key centre is nearest to `x` (considering all 88 keys, white and black).
- `NoteRangeSelector` is a new `View` in `Peach/Settings/`, sibling of `ContinuousValueSlider` and `DiscreteStopsSlider`. Public surface: `init(lowerBound: Binding<Int>, upperBound: Binding<Int>, onCommit: ((MIDINote) -> Void)? = nil)`. The `Int` bindings match the `@AppStorage` types directly; the view wraps reads as `MIDINote(rawValue:)` internally. `onCommit` fires once on drag-release / tap-extend / keyboard-commit with the bound's *new* `MIDINote`. The Settings call site wires `onCommit` to `coordinator.playSoundPreview(note: $0, duration: .milliseconds(400))`.
- Extend `SettingsCoordinator` with `func playSoundPreview(note: MIDINote, duration: Duration) async` that resolves the frequency via the same path the existing `playSoundPreview(duration:)` uses (`userSettings.tuningSystem.frequency(for: note, referencePitch: userSettings.referencePitch)`) and calls the `notePlayer` with the same envelope as the existing preview. The existing zero-arg variant stays for the duration slider's "play A4" check.
- Marker accessibility: `NoteRangeSelector` is *two* adjustable elements — one per bound — exposed via `.accessibilityRepresentation { Slider(value: lowerBinding, in: Double(absoluteMinNote.rawValue)...Double((upperBound - minimumSpan).rawValue), step: 1) { Text("Lowest Note") } }` and the symmetric upper variant. The custom hit area is `.accessibilityHidden(true)`. Each marker pill renders `MIDINote.name` (English; note names are *not* localised — confirmed via investigation). VoiceOver swipe-up/down moves one semitone; the marker's `.accessibilityValue` reads the localised label "Lowest Note, C3" / "Tiefster Ton, C3" with the note name interpolated.
- Each individual key carries an `.accessibilityLabel` of its `MIDINote.name` (`"C3"`, `"F#4"`) so Voice Control "Tap C3" works. Keys themselves are *not* focusable as separate accessibility elements outside Voice Control; they collapse into the two-marker representation under VoiceOver / Switch Control.
- macOS keyboard navigation (no iPad/iOS keyboard nav required for the custom drag area beyond the slider rotor): `@FocusState` cycles between the two markers; `.onKeyPress` handles `.leftArrow` / `.rightArrow` (−1 / +1 semitone), Shift-modified arrows (−12 / +12), `.home` / `.end` (jump to legal min / max for the focused bound). Each commit re-uses the same clamping path as a drag (12-semitone span enforced) and fires `onCommit`.
- Tap behaviour on a dimmed (out-of-range) key: identify which bound is closer (semitone distance); move that bound to the tapped key. Ties (equidistant): deterministic — move the **lower** bound (documented). Tap on an in-range key is a no-op (no preview, no marker movement); this matches the epic's "tap inside the selection is a no-op".
- Drag-release audio preview is the *only* audio side-effect (not during drag, not on tap of an in-range key, not on VoiceOver value change). Keyboard arrow commits also play (preview is the "I committed to this note" cue regardless of input modality). On view disappear, any in-flight preview is implicitly let to finish — `playSoundPreview` is short-envelope; no explicit cancellation.
- Layout responsiveness: a private helper `static func fitsWithoutScrolling(availableWidth: CGFloat) -> Bool` returns `true` when the available width can render 88 keys at the readability threshold (`minWhiteKeyWidth = 8 pt × 52 white keys = 416 pt`). When `false`, wrap in a `ScrollView(.horizontal)` with a `ScrollViewReader`; on first `.onAppear`, scroll to the midpoint between `lowerBound` and `upperBound` with `.anchor(.center)`. When `true`, no scroll wrapper.
- Dynamic Type at AX1 or larger: marker pills would overlap on most displays. Use `@Environment(\.dynamicTypeSize)` and, when `dynamicTypeSize >= .accessibility1`, render a single-line summary `"Lowest %@ · Highest %@"` (interpolated with `MIDINote.name`) followed by *two* visible system `Slider`s (one per bound) over the legal range with semitone step. The keyboard graphic itself is hidden. This fallback satisfies the AX-size accessibility line of the epic ("the keyboard collapses to a single summary line … adjustment falls back to the slider rotor or a 'Pick from list' custom action").
- All new and changed user-facing strings ship in English and German in this story. German uses informal `du` / imperative form. Use `bin/add-localization.swift --batch` for German strings; never hand-edit `Localizable.xcstrings`. Existing keys `"Lowest Note: %@"` / `"Tiefster Ton: %@"` and `"Highest Note: %@"` / `"Höchster Ton: %@"` are re-used where applicable, but spec adds new keys for the AX1+ summary, the marker accessibility labels without the colon, and the marker hint copy.
- Unit tests cover `PianoKeyboardLayout` (white-key count for known ranges, x-position monotonicity, inverse hit-test at key centres / between keys / at viewport extremes / on out-of-range keys mapped to the nearest in-range key, octave-boundary list) and `NoteRangeSelector`'s static helpers (bound clamping at the 12-semitone minimum span, tap-to-extend resolution including the equidistant tie-break, keyboard-arrow nudge clamping at the legal bounds, summary-line formatting). Tests follow the project-context "static layout-test helpers" pattern: no SwiftUI view instantiation. Existing `DisciplineSettingsSectionAggregationTests`, `ContinuousValueSliderTests`, `DiscreteStopsSliderTests`, and the user-settings tests for `noteRangeMin` / `noteRangeMax` continue to pass unchanged.

**Ask First:**
- **`SettingsCoordinator` extension shape.** Spec adds `playSoundPreview(note: MIDINote, duration: Duration) async` and keeps the existing `playSoundPreview(duration:)` (fixed A4). Alternative: refactor the existing method to be a thin wrapper `playSoundPreview(duration:) = playSoundPreview(note: .a4, duration:)` and have all callers use the new shape. The spec keeps both because the duration-slider call site is unrelated to the keyboard and changing it widens the blast radius; the duplicate is one delegation away from being unified later. Confirm the additive shape is acceptable.
- **Tap-on-dimmed-key equidistant tie-break.** Spec resolves ties by moving the **lower** bound (symmetric with `DiscreteStopsSlider`'s "ties to higher index" precedent: pick the bound that's *farther* from the tapped key, since "farther" is the side the user is more likely trying to extend toward — and "extending the bottom of your range" is the more common gesture per UX assumption). Alternative: move the upper bound, or pick based on which bound is at its legal limit (avoid moving a bound that's pinned). Confirm the lower-bound choice.
- **macOS keyboard nudge modifier.** Epic body says `⇧← / ⇧→` for octave nudge. Spec follows that. Alternative: `⌥← / ⌥→` (Option), which is the macOS-native convention for "word/section jump" — but `⇧` is what the epic specifies and is consistent with the muscle memory of "Shift = larger increment" used in many drag-handle controls. Confirm `⇧` over `⌥`.
- **AX1+ summary line vs. two adjacent system sliders.** Spec ships *both* (the summary line for read-out, two sliders for adjustment). Alternative: only the two sliders, with each slider's accessibility label being the full "Lowest Note, C3" string and no separate summary `Text`. The two-slider-only shape is one fewer element but loses the at-a-glance "where am I in the piano" read for sighted AX1+ users. Confirm the summary + two sliders shape.

**Never:**
- Do not refactor `ContinuousValueSlider` or `DiscreteStopsSlider` to share chrome with `NoteRangeSelector`. Three siblings, additive, in `Peach/Settings/`. The keyboard's idiom (domain-shaped control) is fundamentally different from the slider chrome; sharing buys nothing.
- Do not change the `@AppStorage` storage type from `Int` to `MIDINote` rawValue-encoded, do not introduce a `Codable` `NoteRange` storage, do not migrate the keys. The `Int`-as-MIDI-rawValue contract is depended on by the existing user-settings types and the discipline plumbing.
- Do not generalise `PianoKeyboardLayout` to render arbitrary instruments (no `KeyboardLayout` protocol, no `LayoutProvider`). Piano only.
- Do not render any keys outside the 88-key range A0–C8 even if the absolute MIDI range is 0–127. The 88-key window is the piano metaphor.
- Do not introduce snapshot testing or a SwiftUI view-test framework — testable logic lives in `PianoKeyboardLayout` and `NoteRangeSelector`'s static helpers.
- Do not create a new directory under `Peach/Settings/` or `Peach/Core/` for these files. `Peach/Core/Music/PianoKeyboardLayout.swift` and `Peach/Settings/NoteRangeSelector.swift` are the placements.
- Do not add audio playback during drag or during keyboard scrubbing. Audio fires once per commit (drag-release, tap-extend, keyboard arrow press). Drag-scrub audio would be a per-frame storm; keyboard-repeat audio would be a per-keystroke storm under `.repeat` phases.
- Do not import `SwiftData`, `UIKit`, or `AVAudioEngine` in `Peach/Core/Music/PianoKeyboardLayout.swift`. Pure math, `Sendable`, `Hashable` value type.
- Do not import `AVAudioEngine` or `NotePlayer` directly in `Peach/Settings/NoteRangeSelector.swift`. The view calls `onCommit` only; the call site at `SettingsScreen` resolves the closure to `coordinator.playSoundPreview(note:duration:)`.
- Do not change the `Section("Training Range")` header text, the section's position in `SettingsScreen.body`, or the surrounding sections.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Fresh install — Training Range | `@AppStorage` empty for `noteRangeMin` / `noteRangeMax` | Keyboard renders 88 keys A0–C8; keys MIDI 36 (C2) through 84 (C6) at full saturation, all others at ~35 % opacity; lower marker centred on C2 key with pill `"C2"`, upper marker centred on C6 with pill `"C6"`; every C key labelled below in caption text (`"C1"`, `"C2"`, …, `"C8"`). | N/A |
| User drags lower marker right by 5 semitones | Drag end position over F2 (MIDI 41) | Lower marker snaps to F2; `UserDefaults.standard.integer(forKey: "noteRangeMin") == 41`; out-of-range opacity zone shrinks accordingly; `onCommit` fires with `MIDINote(41)`; `coordinator.playSoundPreview(note: MIDINote(41), duration: .milliseconds(400))` plays one short F2. | N/A |
| User drags lower marker toward upper marker past the 12-semitone span | Drag would place lower at MIDI 73 while upper is at 84 (span would shrink to 11) | Lower marker stops at MIDI 72 (upper − minimumSpan); upper marker does not move; `onCommit` fires with `MIDINote(72)`; preview plays at the clamped value. | N/A — clamp in static helper |
| User drags upper marker symmetrically past the span | Drag would place upper at MIDI 47 while lower is at 36 | Upper marker stops at MIDI 48 (lower + minimumSpan); lower marker does not move; `onCommit` fires with `MIDINote(48)`. | N/A |
| User taps a dimmed key above the current range | Range C2–C6 (36–84); tap on G6 (MIDI 79) — wait, 79 is in-range. Tap on G7 (MIDI 91) which is out-of-range | Upper bound (closer of the two; `|91-84|=7` vs `|91-36|=55`) jumps to MIDI 91; `onCommit` fires with `MIDINote(91)`; preview plays G7. | N/A |
| User taps a dimmed key below the current range | Tap on A1 (MIDI 33) with range 36–84 | Lower bound (closer; `|33-36|=3` vs `|33-84|=51`) jumps to MIDI 33; preview plays A1. | N/A |
| User taps an in-range key | Tap on G4 (MIDI 67) with range 36–84 | No marker moves; no preview; no `onCommit`. | N/A — explicit no-op |
| User taps an out-of-range key equidistant from both bounds | Range 36–84; tap on MIDI 15 — but 15 < 21 so unreachable. Construct case: range 40–60, tap on MIDI 50 (in-range, no-op). For a real tie: range 48–60, tap on MIDI 30 (out-of-range below); `|30-48|=18`, `|30-60|=30`; not a tie. Real tie: range 48–84, tap on MIDI 33; `|33-48|=15`, `|33-84|=51`; not a tie. For an *equidistant out-of-range tie*, both bounds must straddle the tap symmetrically, but tapping out-of-range means the tap is *outside* both bounds, which precludes equidistance unless the range is empty (impossible per minimumSpan). The genuine tie case is *equidistant in-range* tap, which is a no-op. **Result: documented as "ties cannot occur for out-of-range taps; lower-bound preference is the implementation default if math ever produces one (e.g. degenerate stored state)."** | N/A — defensive default |
| User taps a dimmed key at the absolute edge | Tap on A0 (MIDI 21) with range 36–84 | Lower bound jumps to MIDI 21; preview plays A0; lower marker is at the leftmost-possible position. | N/A |
| Stored `noteRangeMin` is below absolute min (e.g. 10 from a debugger write) | View renders | Read clamped to `absoluteMinNote` (21) for display; the stored value is not rewritten on render (matches 81.2's "view doesn't rewrite stored state"). First user interaction normalises. | N/A — view displays the clamped value |
| iPhone portrait (width < 416 pt) | View appears | Keyboard wrapped in `ScrollView(.horizontal)`; `.onAppear` triggers `ScrollViewReader.scrollTo(centreOfSelection, anchor: .center)`. User can scroll horizontally to inspect either end of the piano. | N/A |
| iPad portrait, macOS, iPhone landscape (width ≥ 416 pt) | View appears | Keyboard renders without scroll wrapper; all 88 keys visible. | N/A |
| VoiceOver active (any size class) | VoiceOver on | The view exposes two adjustable elements via `.accessibilityRepresentation`: "Lowest Note, C2, adjustable" and "Highest Note, C6, adjustable"; swipe-up/down moves one semitone (the rep is a `Slider` with `step: 1`); clamping at the 12-semitone span and the absolute bounds is the underlying `Slider`'s range constraint. Audio preview fires on each VoiceOver-driven value change (the commit cue is universal across modalities). | N/A |
| Switch Control active | Switch Control scanning on | The two slider representations are individually scannable; increment / decrement actions move by one semitone. | N/A |
| macOS, keyboard nav — Tab to lower marker, press `→` | Lower marker focused, range 36–84 | Lower bound increments to 37; `onCommit` fires with `MIDINote(37)`; preview plays C#2. | N/A |
| macOS, keyboard nav — `⇧→` on focused upper marker | Upper marker focused, range 36–84 | Upper bound increments to 96 (84 + 12); preview plays C7. | N/A — Shift = octave |
| macOS, keyboard nav — `End` on focused upper marker | Upper marker focused at any in-range position | Upper bound jumps to `absoluteMaxNote` (108, C8); preview plays C8. | N/A |
| macOS, keyboard nav — `Home` on focused lower marker | Lower marker focused at any in-range position | Lower bound jumps to `absoluteMinNote` (21, A0); preview plays A0. | N/A |
| macOS, keyboard nav — `→` on lower marker at the 12-semitone-from-upper limit | Lower at 72, upper at 84 | Lower stays at 72 (cannot encroach); no `onCommit`; no preview (no change to commit). | N/A — silent clamp on no-op |
| Dynamic Type at AX1+ | `dynamicTypeSize >= .accessibility1` | Keyboard graphic hidden; replaced by `Text("Lowest C2 · Highest C6")` (or "Tiefster C2 · Höchster C6" in German) and two stacked system `Slider`s with semitone step, one per bound, each labelled with its localised accessibility name. Adjustment via slider only. | N/A |
| German locale active | `Locale.current` is `de_DE` | Section header `"Trainingsumfang"` (existing — or current key; spec preserves); marker rep accessibility labels read `"Tiefster Ton"` / `"Höchster Ton"`; AX1+ summary reads `"Tiefster %@ · Höchster %@"`; note names themselves stay in English (`"C3"`, not `"C3"` localised — confirmed there is no German variant in the codebase). | N/A |
| App backgrounded mid-drag | User backgrounds the app while dragging | `DragGesture.onEnded` is not called by SwiftUI when the gesture is cancelled by app lifecycle; no commit fires; the stored value reflects the last completed gesture. On foreground, the marker renders at the stored position. | N/A — SwiftUI handles cancellation |

</frozen-after-approval>

## Code Map

- `Peach/Core/Music/PianoKeyboardLayout.swift` — **new** (recovered from `2e7cf102^:Peach/Profile/PianoKeyboardView.swift` and ported). Pure-value `struct PianoKeyboardLayout: Sendable, Hashable` with `let noteRange: NoteRange` (the full 88-key window, `NoteRange(lowerBound: SettingsKeys.absoluteMinNote, upperBound: SettingsKeys.absoluteMaxNote)` at the call site). Static API (pitch-class predicates, pure): `static func isWhiteKey(_ note: MIDINote) -> Bool`, `static func isOctaveBoundary(_ note: MIDINote) -> Bool`. Instance API (geometry, pure): `var whiteKeyCount: Int`, `func whiteKeyWidth(totalWidth: CGFloat) -> CGFloat`, `func xPosition(forNote note: MIDINote, totalWidth: CGFloat) -> CGFloat` (recovered behaviour: white keys evenly distributed, black keys at the midpoint between adjacent white keys), `func midiNote(at x: CGFloat, totalWidth: CGFloat) -> MIDINote` (**new** — scans all keys in `noteRange.lowerBound...upperBound`, returns the one whose `xPosition` is nearest to `x`; ties resolve to the lower MIDI note for determinism), `var octaveBoundaries: [MIDINote]` (returns the `MIDINote` values where `isOctaveBoundary` is true — call site composes the label). No SwiftUI import. Ported parameter types: every `midiNote: Int` becomes a `MIDINote`; `Int`-based internal ranges become `MIDINote`-iterated sequences via `stride(from: lowerBound.rawValue, through: upperBound.rawValue, by: 1).map(MIDINote.init)` where needed.

- `Peach/Settings/NoteRangeSelector.swift` — **new**. `struct NoteRangeSelector: View` with stored `lowerBound: Binding<Int>`, `upperBound: Binding<Int>`, `onCommit: ((MIDINote) -> Void)?` (default `nil`). Uses `@Environment(\.dynamicTypeSize) private var dynamicTypeSize`. Body branches on `dynamicTypeSize`: at AX1+, renders the summary-line fallback (one `Text` plus two system `Slider`s with semitone step over the legal range for each bound); otherwise renders the keyboard. Below the AX1+ threshold, body composes (top to bottom): the two `BoundMarker` sub-views overlaid above the keyboard at their `xPosition`s, the keyboard itself (a `ZStack` of `PianoKey` views — white keys in a flat `HStack` for layout, black keys overlaid via `.overlay` with explicit `.offset(x:)` from layout's `xPosition`), and a row of C-key labels in caption text below. The keyboard is wrapped in a `ScrollView(.horizontal)` + `ScrollViewReader` when `!Self.fitsWithoutScrolling(availableWidth: geo.size.width)` (measured via a `GeometryReader` at the top of the body). On the first `.onAppear` of the scroll wrapper, `proxy.scrollTo("centre", anchor: .center)` runs (the keyboard contains a hidden `.id("centre")` marker at the midpoint of the current selection). `DragGesture(minimumDistance: 0)` attached to each marker translates the `value.location.x` (in the keyboard's coordinate space) through `layout.midiNote(at:totalWidth:)` into a candidate `MIDINote`, clamps it through static helpers (below), and writes to the corresponding binding on `.onChanged` (live drag) — but only fires `onCommit` and the audio preview on `.onEnded`. Tap on a key (not a marker) is handled by a key-area `.onTapGesture` that routes through the static `tapResolution(at:lower:upper:)` helper. macOS keyboard support: `@FocusState private var focusedMarker: Marker?` cycles between `.lower` / `.upper`; `.onKeyPress(.leftArrow, .rightArrow, .home, .end, phases: [.down, .repeat])` dispatches through a static `keyboardCommit(_:on:current:legalRange:partner:minimumSpan:)` helper. Static helpers (all `static func` on `NoteRangeSelector` — testable without SwiftUI): `clampLower(_ candidate: MIDINote, against upper: MIDINote, minimumSpan: Int = NoteRange.minimumSpan) -> MIDINote`, `clampUpper(_ candidate: MIDINote, against lower: MIDINote, minimumSpan: Int = NoteRange.minimumSpan) -> MIDINote`, `tapResolution(at tapped: MIDINote, lower: MIDINote, upper: MIDINote) -> TapOutcome` where `TapOutcome` is an internal enum `case noOp / case moveLower(MIDINote) / case moveUpper(MIDINote)`, `keyboardCommit(_ key: KeyEquivalent, modifiers: EventModifiers, current: MIDINote, legalRange: ClosedRange<MIDINote>) -> MIDINote?` (returns `nil` when the key isn't handled or the resulting value is unchanged), `fitsWithoutScrolling(availableWidth: CGFloat, whiteKeyCount: Int = 52, minWhiteKeyWidth: CGFloat = 8) -> Bool`, `summaryLine(lower: MIDINote, upper: MIDINote, locale: Locale = .current) -> String` (returns `String(localized: "Lowest %@ · Highest %@")` interpolated with `lower.name` and `upper.name`). Private sub-views (each < 40 lines per the project-context "extract subviews at ~40 lines" rule): `private struct PianoKey: View` (one key — white or black, in-range or dimmed, labelled-C-below or unlabelled), `private struct BoundMarker: View` (chevron pointing down + pill with `MIDINote.name`), `private struct KeyboardSummary: View` (the AX1+ fallback).

- `Peach/Settings/SettingsScreen.swift` — **edit**. Replace the body of the private `trainingRangeSection` property: delete both `Stepper`s and replace with a single `NoteRangeSelector(lowerBound: $noteRangeMin, upperBound: $noteRangeMax, onCommit: { note in Task { await coordinator.playSoundPreview(note: note, duration: .milliseconds(400)) } })`. The `Section("Training Range") { ... }` shell stays; only the inner control swaps. The `@AppStorage` declarations for `noteRangeMin` / `noteRangeMax` are unchanged.

- `Peach/App/SettingsCoordinator.swift` — **edit**. Add `func playSoundPreview(note: MIDINote, duration: Duration) async` that resolves frequency via `userSettings.tuningSystem.frequency(for: note, referencePitch: userSettings.referencePitch)` and calls `notePlayer.play(...)` with the same envelope shape as the existing `playSoundPreview(duration:)` (zero amplitude variation, immediate play). The existing zero-arg `playSoundPreview(duration:)` stays for the Note Duration slider preview and other callers; it does **not** delegate to the new method (additive, lowest-risk shape — confirmed in Ask-First).

- `Peach/Resources/Localizable.xcstrings` — **edit** (via `bin/add-localization.swift --batch`). Add five new keys: `"Lowest Note"` → `"Tiefster Ton"` (the marker accessibility label without colon), `"Highest Note"` → `"Höchster Ton"` (symmetric), `"Lowest %@ · Highest %@"` → `"Tiefster %@ · Höchster %@"` (AX1+ summary), `"Drag to set the lowest training note"` → `"Ziehe, um den tiefsten Trainings-Ton einzustellen"` (marker hint), `"Drag to set the highest training note"` → `"Ziehe, um den höchsten Trainings-Ton einzustellen"` (symmetric). Existing keys kept unchanged: `"Lowest Note: %@"` / `"Tiefster Ton: %@"` and `"Highest Note: %@"` / `"Höchster Ton: %@"` — retained for any test or debug surface that still uses them; if they have zero remaining call sites after the migration, they may be removed in a future cleanup story (this story doesn't audit). Section header (currently `"Training Range"` / `"Trainingsumfang"` per existing localisation) unchanged.

- `PeachTests/Core/Music/PianoKeyboardLayoutTests.swift` — **new**. Suite covers: (1) `whiteKeyCount` for the 88-key window equals 52; for one-octave window equals 7; (2) `xPosition` monotonicity — for any two notes `n1 < n2`, `xPosition(n1) < xPosition(n2)`; (3) `xPosition(forNote: lowerBound, totalWidth: w)` is approximately `whiteKeyWidth / 2` (within 0.5 pt); `xPosition(forNote: upperBound, ...)` is within `whiteKeyWidth / 2` of `w`; (4) black-key `xPosition` lies between its two adjacent white keys' `xPosition`s; (5) inverse hit-test at key centres — `layout.midiNote(at: layout.xPosition(forNote: n, totalWidth: 1000), totalWidth: 1000) == n` for a sample of notes covering white and black, low and high; (6) inverse hit-test between two adjacent keys — returns the *nearer* note; (7) inverse hit-test at `x = 0` returns `lowerBound`; at `x = totalWidth` returns `upperBound`; (8) inverse hit-test for `x` outside `[0, totalWidth]` clamps to the nearest in-range note (no precondition trap); (9) `octaveBoundaries` for the 88-key window contains exactly `[C1, C2, C3, C4, C5, C6, C7, C8]` (eight Cs); for a sub-octave window contains zero or one. Tests use `MIDINote(rawValue:)` constructors; no SwiftUI view instantiation.

- `PeachTests/Settings/NoteRangeSelectorTests.swift` — **new**. Suite covers: (1) `clampLower(MIDINote(80), against: MIDINote(84)) == MIDINote(72)` (clamped to upper − 12); `clampLower(MIDINote(50), against: MIDINote(84)) == MIDINote(50)` (no clamp); `clampLower(MIDINote(20), against: MIDINote(84))` traps if `MIDINote.init` precondition checks (or returns `MIDINote(21)` if the helper clamps to `absoluteMinNote` — spec assumes the *call site* clamps to absolute bounds before calling, so the helper only enforces the relative span — pin this in the test); (2) symmetric `clampUpper`; (3) `tapResolution(at: MIDINote(91), lower: MIDINote(36), upper: MIDINote(84))` returns `.moveUpper(MIDINote(91))`; `tapResolution(at: MIDINote(33), lower: MIDINote(36), upper: MIDINote(84))` returns `.moveLower(MIDINote(33))`; `tapResolution(at: MIDINote(60), lower: MIDINote(36), upper: MIDINote(84))` returns `.noOp` (in-range); (4) `tapResolution` lower-bound-preference on tie (constructed: `tapResolution(at: MIDINote(15), lower: MIDINote(20), upper: MIDINote(40))` — but 15 < absoluteMin; use a degenerate-state assertion with notes that admit a real arithmetic tie); (5) `keyboardCommit(.rightArrow, modifiers: [], current: MIDINote(60), legalRange: MIDINote(21)...MIDINote(108)) == MIDINote(61)`; `keyboardCommit(.rightArrow, modifiers: .shift, ...) == MIDINote(72)` (octave); `keyboardCommit(.home, ...) == MIDINote(21)`; `keyboardCommit(.end, ...) == MIDINote(108)`; `keyboardCommit(.rightArrow, modifiers: [], current: MIDINote(108), legalRange: MIDINote(21)...MIDINote(108)) == nil` (clamps, returns no commit); (6) `fitsWithoutScrolling(availableWidth: 415) == false`; `(availableWidth: 416) == true`; `(availableWidth: 1024) == true`; (7) `summaryLine(lower: MIDINote(36), upper: MIDINote(84))` contains `"C2"` and `"C6"` (token-presence; bundle language is not strictly assertable — matches the 81.2 pattern). Tests use the static helpers directly — no SwiftUI view instantiation.

- `PeachTests/Settings/ContinuousValueSliderTests.swift` — **no change**.
- `PeachTests/Settings/DiscreteStopsSliderTests.swift` — **no change**.
- `PeachTests/Settings/DisciplineSettingsSectionAggregationTests.swift` — **no change**. Aggregation contract is unaffected by the Training Range section body swap.
- `PeachTests/Settings/SettingsScreenTests.swift` (if it exists) — **no change** beyond what the compiler forces (no test reads the Stepper body directly).

## Tasks & Acceptance

**Execution:**
- [x] `Peach/Core/Music/PianoKeyboardLayout.swift` — create by recovering `git show 2e7cf102^:Peach/Profile/PianoKeyboardView.swift`, extract the `PianoKeyboardLayout` struct, port `midiNote: Int` parameters to `MIDINote`, add the inverse hit-test `midiNote(at:totalWidth:)`, add `Sendable` and `Hashable` conformance. Verify no SwiftUI / UIKit / AVAudio imports.
- [x] `PeachTests/Core/Music/PianoKeyboardLayoutTests.swift` — add the suite from the Code Map (white-key count, x-position monotonicity, edges, black-key interpolation, inverse hit-test at centres / between / at viewport extremes / outside, octave boundaries).
- [x] `Peach/App/SettingsCoordinator.swift` — add `playSoundPreview(note: MIDINote, duration: Duration) async`. The zero-arg variant stays.
- [x] `Peach/Settings/NoteRangeSelector.swift` — create the view with the static helpers (`clampLower`, `clampUpper`, `tapResolution`, `keyboardCommit`, `fitsWithoutScrolling`, `summaryLine`), the three private sub-views (`PianoKey`, `BoundMarker`, `KeyboardSummary`), the body branching on Dynamic Type, the scroll wrapper + `ScrollViewReader` auto-scroll, the drag gestures per marker, the tap-to-extend handler on the key area, the `@FocusState`-driven macOS keyboard nav, and the `.accessibilityRepresentation` per marker.
- [x] `PeachTests/Settings/NoteRangeSelectorTests.swift` — add the suite from the Code Map (clamping, tap resolution, keyboard commit, scroll threshold, summary-line format).
- [x] `Peach/Settings/SettingsScreen.swift` — replace the body of `trainingRangeSection` (delete both `Stepper`s, insert single `NoteRangeSelector`). Keep the `Section("Training Range")` shell and the `@AppStorage` declarations unchanged. Wire `onCommit` to `coordinator.playSoundPreview(note:duration:)`.
- [x] `Peach/Resources/Localizable.xcstrings` — add the five new keys via `bin/add-localization.swift --batch`. Verify no key churn on the existing four (`"Lowest Note: %@"`, `"Highest Note: %@"`, and their German equivalents) — they remain in the catalog even if call sites disappear.
- [ ] Run `bin/test.sh && bin/test.sh -p mac` — both platforms must pass. The new layout and selector tests run on both platforms.
- [ ] Run `bin/build.sh && bin/build.sh -p mac` — both platforms must build clean with no new warnings. Verify `--research` build also clean.
- [ ] Run `bin/add-localization.swift --missing` — expect zero missing German translations.

**Acceptance Criteria:**
- Given the app launches on a fresh install, when the user opens Settings → Training Range, then the section renders an 88-key piano (A0–C8) with keys C2 through C6 at full saturation, all other keys at ~35 % opacity, every C labelled below in caption text, and two chevron-with-pill markers above the keyboard centred over C2 and C6 with pill text `"C2"` / `"C6"`.
- Given the keyboard is rendered, when the user drags the lower marker rightward across several keys and releases, then the marker snaps to the nearest semitone, the `noteRangeMin` `@AppStorage` value updates to the new MIDI rawValue, the out-of-range opacity zone updates accordingly, and a single short-envelope preview of the newly-set note plays through the configured sound source.
- Given the lower marker is at MIDI 72 and the upper at MIDI 84, when the user attempts to drag the lower marker further right (toward the upper), then the lower marker stops at MIDI 72; the upper marker does not move; no AppStorage write occurs beyond the clamped value.
- Given the keyboard is rendered with range C2–C6, when the user taps an out-of-range key above the range (e.g. G7), then the upper marker jumps to the tapped key, AppStorage updates, and the preview plays the tapped note. The lower marker does not move.
- Given the keyboard is rendered, when the user taps an in-range key, then nothing happens: no marker moves, no preview plays, no AppStorage write.
- Given iPhone portrait (width below the 416 pt readability threshold), when the Settings screen appears with the Training Range section visible, then the keyboard is wrapped in a horizontal scroll view that auto-scrolls on first appearance to centre the current selection between the two markers.
- Given iPad portrait, macOS, or iPhone landscape (width ≥ 416 pt), when the section appears, then the keyboard renders without a scroll wrapper and all 88 keys are visible side by side.
- Given VoiceOver is active, when the user focuses the Training Range section, then VoiceOver finds exactly two adjustable elements ("Lowest Note, C2, adjustable" and "Highest Note, C6, adjustable" in English; informal-`du` German equivalents in German); swipe-up advances the focused bound by one semitone (clamped by the 12-semitone minimum span and the absolute A0–C8 window); each change plays the preview.
- Given Switch Control is active, when the user activates the Training Range section, then the two slider representations are individually scannable and respond to increment / decrement actions with one-semitone moves and a preview per commit.
- Given the macOS app is running with keyboard focus on the Training Range section, when the user presses `Tab`, then focus cycles between the lower and upper marker; `←` / `→` nudge the focused bound by one semitone; `⇧←` / `⇧→` nudge by one octave (12 semitones), clamped at the legal bounds; `Home` / `End` jump the focused bound to its absolute legal min / max (A0 / C8); each commit plays the preview.
- Given Dynamic Type is at AX1 or larger, when the section renders, then the keyboard graphic is hidden; a single-line summary "Lowest C2 · Highest C6" appears (informal-`du` German "Tiefster C2 · Höchster C6"); two stacked system `Slider`s (one per bound, semitone step, over the legal range) provide adjustment.
- Given the German locale is active, when the section renders, then the section header reads `"Trainingsumfang"` (unchanged); marker accessibility labels read `"Tiefster Ton"` / `"Höchster Ton"`; AX1+ summary reads `"Tiefster C2 · Höchster C6"`; note names themselves stay in English (e.g. `"C3"`, `"F#4"`).
- Given the stored `noteRangeMin` is below `absoluteMinNote` (e.g. set to 10 via debugger), when the section renders, then the lower marker displays at the `absoluteMinNote` position (clamped read), and the stored value is not rewritten until the user interacts with the control.
- Given `bin/test.sh && bin/test.sh -p mac` runs, when both suites finish, then all tests pass on iOS and macOS, including new `PianoKeyboardLayoutTests` and `NoteRangeSelectorTests`, and the previously-passing `ContinuousValueSliderTests`, `DiscreteStopsSliderTests`, `DisciplineSettingsSectionAggregationTests`, and the relevant user-settings tests pass unchanged.
- Given `bin/build.sh && bin/build.sh -p mac` runs, when both platforms build, then no new warnings appear in either configuration (Debug non-research and Debug (Research)).
- Given `bin/add-localization.swift --missing` runs, when it finishes, then it reports zero missing German translations for any of the five new keys.

## Spec Change Log

- **2026-06-03** — Implementation deltas vs. Code Map:
  - **`PianoKeyboardLayout` uses default MainActor isolation, not `nonisolated`.** Code Map called for a `nonisolated struct PianoKeyboardLayout: Hashable, Sendable` (mirroring `nonisolated struct MIDINote`). `NoteRange`'s `Hashable` conformance is main-actor-isolated (declared without `nonisolated`), so storing a `NoteRange` in a `nonisolated` value type fails to compile (`main actor-isolated conformance of 'NoteRange' to 'Hashable' cannot be used in nonisolated context`). Following project-context rule "`nonisolated` only when the compiler requires it", the struct now uses default MainActor isolation. The view consumes the layout on the main actor anyway, so this matches the call-site reality. If a future story needs to use `PianoKeyboardLayout` off-main, the cleaner fix is to make `NoteRange` `nonisolated` consistently with `MIDINote`.
  - **`octaveBoundaries` returns `[MIDINote]`.** Spec already prescribed this shape; recording explicitly that the recovered tuple shape `[(midiNote: Int, name: String)]` was dropped during the `Int → MIDINote` port. Callers compose `note.name` themselves.
  - **Drag gesture uses `.coordinateSpace(.named("noteRangeKeyboard"))` on the marker row + `DragGesture(coordinateSpace: .named(...))`.** Initial implementation used `DragGesture(minimumDistance: 0)` with default `.local` coordinate space. With `.position()` placing the marker as a small view, `.local` reports `location.x` relative to the marker's tiny frame — feeding wrong values into `layout.midiNote(at: location.x, totalWidth:)`. Switching to a named coordinate space on the marker row makes `location.x` consistent with the keyboard's left-edge origin. The keys-row tap gesture stays on `.local` correctly because the tap target IS the keys row (full keyboard width).
  - **`BoundMarker` does not expand to a 44×44 tap target.** 81.1/81.2 `−`/`+` buttons each carry `.frame(minWidth: 44, minHeight: 44)` for FR38. Markers render as a compact pill+chevron (~30×30). Forcing 44×44 would make markers visually overlap at minimum-span apart on iPhone portrait (~56 pt between markers; two 44-pt tap areas extending ±22 each would collide). Kept compact; the multimodal access path (accessibility-representation Sliders, macOS keyboard arrows, tap-on-dimmed-key, drag) means the drag target is one of several ways in. Revisit if drag imprecision is reported.
  - **Audio preview wired with `.milliseconds(400)`** per spec, not the existing `SettingsScreen.previewDuration` (2 s). The 2 s preview is for the explicit Play Preview sound-source button; for the keyboard's commit cue, a short pluck is the right shape.
  - **C-key octave labels render as a separate row below the keys, not inside the white-key cells.** Per Code Map's three-row VStack (`markerRow + keysRow + labelsRow`); matches the spec's "every C labelled below in caption text" wording. Recording explicitly because in-key labels would have been the other natural interpretation.
- **2026-06-03** — `/simplify-code` deltas:
  - **`whiteKeys` / `blackKeys` promoted to `static let` on `NoteRangeSelector`.** Were instance computed properties (`(absoluteMinNote...absoluteMaxNote).map.filter` per access) but the values are invariant across instances. Static-let avoids the per-render allocation. Required making `PianoKeyboardLayout.isWhiteKey`, `isOctaveBoundary`, and `whitePitchClasses` `nonisolated` so they're callable from a static initializer (which has no actor context). These predicates were already pure pitch-class arithmetic, so `nonisolated` is the natural and correct annotation.
  - **Single `clampedToAbsoluteRange(_:)` static helper** replaces the inline `MIDINote(min(max(...), absoluteMinNote.rawValue), absoluteMaxNote.rawValue)` pattern that appeared in `lowerNote`, `upperNote`, `lowerSliderBinding.set`, and `upperSliderBinding.set`. Four call sites collapse to one helper.
- **2026-06-03** — Step-4 review patches (Blind hunter + Edge case hunter + Acceptance auditor):
  - **Defensive `lowerLegalRange` / `upperLegalRange`.** Acceptance auditor #5 and Edge case hunter #1–#2 flagged that the original `MIDINote(upperBound - NoteRange.minimumSpan)` traps when stored `upperBound < 12` or `> 139`, and the resulting `ClosedRange` traps inverted when `upperBound < 33` — directly violating the spec AC "the lower marker displays at the `absoluteMinNote` position (clamped read)" for corrupt stored state. Introduced `effectiveUpperBound` / `effectiveLowerBound` computed properties that clamp the raw `Int` bindings into `[absoluteMinNote + minimumSpan, absoluteMaxNote]` before legal-range arithmetic. The view now renders gracefully for any stored bound value, no rewriting of storage on render (per the spec's "stored value not rewritten").
  - **Defensive `clampLower` / `clampUpper` helpers.** Edge case hunter #3 flagged that `MIDINote(min(candidate.rawValue, upper.rawValue - minimumSpan))` traps when `upper.rawValue < 12` (ceiling < 0). The helpers now clamp the computed ceiling/floor into `MIDINote.validRange` before constructing the `MIDINote`. Two new tests pin this: `clampLowerAgainstLowUpperStaysValid` and `clampUpperAgainstHighLowerStaysValid`.
  - **Self-clamp on commit in `applyDrag` and `handleTap`.** Edge case hunter #4 flagged that committing a value clamped only against a corrupt partner could persist a value outside `[absoluteMinNote, absoluteMaxNote]`. The commit path now wraps the relative-clamp result in `Self.clampedToAbsoluteRange(...)` before writing the binding.
  - **Added `.accessibilityValue(Text(note.name))` to the non-AX1 representation Sliders.** Acceptance auditor #1 / #3 caught the omission: spec Always rule line 29 required VoiceOver to read "Lowest Note, C2" but the representation Sliders had only the label, so VoiceOver was speaking the raw Double. Now matches the AX1+ `KeyboardSummary` path which already had `.accessibilityValue`.
  - **Consolidated named coordinate space onto `keyboardStack`.** Blind hunter #10 and Edge case hunter #7 / #8 flagged that drag used a named space attached to `markerRow` while tap used `.local` on `keysRow` — coincidentally aligned because both rows share the same x-origin today, but fragile to future leading-inset changes. Moved `.coordinateSpace(.named("noteRangeKeyboard"))` to the enclosing `keyboardStack` and updated both drag and tap to reference it.
  - **`PianoKey` stroke colour switched from `Color.primary.opacity(0.4)` to `Color.gray.opacity(0.5)`.** Blind hunter #16 partial — `Color.primary` is white in Dark Mode, so the stroke disappeared against the near-white white-key fill. `Color.gray` is roughly mid-luminance in both schemes; the white/black key fills stay piano-traditional (white near-white, black near-black).
  - **Rejected with reasoning (not patched, not deferred):**
    - Black-key fallback edge cases in `PianoKeyboardLayout` (Blind hunter #2 / #3) — `PianoKeyboardLayout` is only ever instantiated with A0–C8 in this codebase (both endpoints are white keys); the fallback branches are unreachable. Spec explicitly says "Piano only" and pins A0/C8 endpoints.
    - "Drag eats tap under marker" (Blind hunter #18) — markers live in `markerRow` above the keys row, not over the keys themselves. Their `.position(...)` places them in a 30 pt-tall row above the 64 pt keyboard. Cannot geometrically overlap.
    - 88-element VoiceOver swarm (Blind hunter #14) — the `.accessibilityRepresentation` on `keyboardBody` replaces the entire accessibility subtree; the per-`PianoKey` `.accessibilityLabel` never reaches VoiceOver under this configuration.
    - Black-key vs white-key y-aware hit-test (Blind hunter #5) — spec says the inverse hit-test returns "the note whose key centre is nearest to `x`" (x-only). A future polish item, captured in deferred-work.
    - `locale` parameter on `summaryLine` is "dead" (Blind hunter #13) — matches the testability pattern of 81.1's `accessibilityDuration` / `accessibilityTempo` helpers; default `.current` works in production, the parameter exists for locale-pinning in future tests.
    - Static layout staleness if `absoluteMin/Max` ever change (Blind hunter #19) — both are `let` compile-time constants; runtime change is impossible.
    - Marker pill `.foregroundStyle(.white)` contrast vs. light `.accentColor` (Blind hunter #15) — `Color.accentColor` defaults to system blue which has sufficient contrast against white text; pluggable user accent colours are out of scope.
    - `try?` swallowing audio errors in `SettingsCoordinator.playSoundPreview` (Blind hunter #20) — pre-existing pattern in the same file; captured in deferred-work for consistent logging across both overloads.
    - Test theory nits (Blind hunter #21 / #22 / #23) — minor.
    - Positional `%@` ordering (Blind hunter #24) — German preserves the same order; relevant only if a future language reverses, at which point Apple's String catalog UI surfaces the issue.
    - `Self.allKeys` / `whiteKeys` / `blackKeys` duplicate the layout's own iteration (Blind hunter #26) — three small arrays at type-init; the duplication is intentional for the per-row `ForEach` (which needs an array, not a lazy iterator), and the layout's `notes` is private.
    - No default focus (Blind hunter #27) — standard SwiftUI behaviour; first Tab/Shift-Tab into the section finds whichever marker comes first in tab order.
    - Hint phrasing for AX1+ (Blind hunter #25) — `BoundMarker` is only rendered in the non-AX1 path; the AX1+ `KeyboardSummary` Sliders carry no "Drag" hints. Scope is already correct.
  - **Deferred (added to `deferred-work.md`):** O(N²) layout cost, Voice Control "Tap C3" lost under `.accessibilityRepresentation` (mutually exclusive with the marker-Slider representation under the current SwiftUI API), auto-recenter on bound change, audio-preview debouncing for `.repeat` keyboard phases, AX1+ partner-imposed range shifts mid-edit, black-key vs white-key y-aware hit-test, `NoteRange` `nonisolated` Boy-Scout refactor (touches a widely-used Core type), `BoundMarker` 44×44 tap-target sizing (visual-overlap trade-off), `SettingsCoordinator.playSoundPreview` error logging across both overloads.

## Design Notes

**Why recover `PianoKeyboardLayout` rather than rewrite.** The layout math (white-key distribution, black-key midpoint interpolation, white-key counting per range) is a small, well-tested shape with no SwiftUI dependency. Rewriting would add no value and risks off-by-one errors that the recovered version has already shaken out. The deletion note ("zero references in production code or tests") is now factually obsolete — this story is the production reference.

**Why a pure-geometry `PianoKeyboardLayout` in `Core/Music/` and a separate SwiftUI `NoteRangeSelector` in `Settings/`.** The split mirrors the project's framework-boundary rule (`Core/Music/` is framework-free). It also makes the geometry independently unit-testable without instantiating SwiftUI views — the bulk of the testable surface for this story lives in the layout's pure functions.

**Why `Int` bindings rather than a single `Binding<NoteRange>`.** The `@AppStorage` types are `Int`. Bridging two `Int`s into a single `NoteRange` binding inside `SettingsScreen` would require a custom `Binding` with a `get` returning `NoteRange(lowerBound: MIDINote(noteRangeMin), upperBound: MIDINote(noteRangeMax))` and a `set` decomposing back — that's a lot of bridging code for an API that the view doesn't actually need (the view operates on the bounds independently for drag-clamp and tap-extend). Two `Binding<Int>` is the smallest interface that matches storage and the view's internal operations.

**Why one `onCommit` closure rather than per-bound closures.** Audio preview is symmetric across bounds — the only relevant detail is "what note did the user just commit to?" Passing one closure that fires with the bound's new `MIDINote` keeps the API minimal. If a future story needs to distinguish lower-vs-upper commits (e.g. analytics), changing the closure's signature is a localised refactor.

**Why drag-release audio rather than drag-scrub.** A drag gesture fires `.onChanged` at ~60 Hz; playing audio on each change would either queue a backlog of overlapping notes or require per-frame cancellation logic. Drag-release matches the user's "I'm done choosing; what does this sound like?" mental model and matches the existing Settings preview shape (Note Duration plays on slider release, not during).

**Why the AX1+ fallback is a single line + two sliders, not a "Pick from list" custom action.** The two sliders preserve continuous adjustment (the rotor / Switch Control actions of the underlying `Slider` work), and the summary line preserves the at-a-glance read for sighted AX-size users. A "Pick from list" custom action would force a modal picker for every adjustment, which is heavier than the slider rotor and out of step with the rest of Settings' AX behaviour.

**Why iPhone portrait scrolls rather than compressing the keyboard.** Compressing 88 keys into 390 pt yields a 4–5 pt white key, below comfortable tap-and-recognise size. The 8 pt minimum threshold is conservative; a future story could tune it after Dynamic Type interaction is observed. The auto-scroll-to-centre on first appearance is the affordance that says "this scrolls".

**Why `tapResolution` returns an enum rather than mutating bindings directly.** Pure functions over the bound state are testable without binding-mock infrastructure. The view body inspects the enum and writes to bindings — a thin adapter layer that does not need its own tests.

## Verification

**Commands:**
- `bin/build.sh` — expected: clean iOS build, no new warnings.
- `bin/build.sh -p mac` — expected: clean macOS build, no new warnings.
- `bin/test.sh` — expected: all iOS tests pass; new `PianoKeyboardLayoutTests` and `NoteRangeSelectorTests` pass; existing slider, aggregation, and user-settings tests unchanged.
- `bin/test.sh -p mac` — expected: all macOS tests pass.
- `bin/add-localization.swift --missing` — expected: zero missing German translations.

**Manual checks:**
- Run the iOS simulator (iPhone) → open Settings → scroll to Training Range → confirm the section shows an 88-key piano (not two Steppers), with markers at C2 / C6 on a fresh install; horizontally scroll the keyboard to inspect A0 and C8 ends; confirm auto-scroll centred the selection on first open.
- Run on iPad (or rotate iPhone to landscape) → confirm the 88 keys fit without scrolling.
- Drag the lower marker right by several keys → confirm the snap-on-release, the AppStorage write (visible by reopening and re-rendering), and a single short preview audio cue plays at the new note.
- Drag the lower marker hard right toward the upper → confirm the marker stops at upper − 12; the upper marker does not move.
- Tap a dimmed key above the current range → confirm the upper marker jumps to that key, preview plays.
- Tap a dimmed key below the current range → confirm the lower marker jumps, preview plays.
- Tap an in-range key → confirm nothing happens (no marker move, no preview).
- Switch the simulator language to German → confirm the section header is `"Trainingsumfang"`, VoiceOver labels read `"Tiefster Ton"` / `"Höchster Ton"`, AX1+ summary reads `"Tiefster %@ · Höchster %@"`. Confirm note names themselves remain English.
- Turn on VoiceOver → focus the section, confirm exactly two adjustable elements, swipe-up advances by one semitone with preview.
- Bump Dynamic Type to AX1 → confirm the keyboard graphic disappears, replaced by a summary line and two stacked system sliders; adjustment via slider plays preview.
- On macOS, Tab into the Training Range section → confirm focus cycles between markers; `←` / `→` nudge by one semitone with preview; `⇧←` / `⇧→` nudge by one octave; `Home` / `End` jump to A0 / C8 of the focused bound.
- (Optional) Set `noteRangeMin = 10` via debugger / launch argument → reopen Settings → confirm the lower marker renders at A0 (clamped read) without rewriting the stored 10 until the first interaction.

## Suggested Review Order

**Entry point — what changed and why**

- The Settings row swap: two Steppers replaced by one `NoteRangeSelector`, wired with an audio-preview commit closure routed through the coordinator.
  [`SettingsScreen.swift:105`](../../Peach/Settings/SettingsScreen.swift#L105)

- The view's branching: Dynamic Type ≥ AX1 falls back to a summary line + two adjacent system Sliders; the default path renders the 88-key piano.
  [`NoteRangeSelector.swift:100`](../../Peach/Settings/NoteRangeSelector.swift#L100)

**Defensive bounds handling (most-reviewed surface)**

- `effectiveUpperBound` / `effectiveLowerBound`: defensive clamp of the raw `@AppStorage` Int bindings so legal-range arithmetic stays well-formed for corrupt stored state. Pinned by step-4 review.
  [`NoteRangeSelector.swift:79`](../../Peach/Settings/NoteRangeSelector.swift#L79)

- `clampLower` / `clampUpper`: pure mechanism for the 12-semitone span, with absolute-MIDI floor/ceiling defence-in-depth. Step-4 patch ensures the helpers never trap on extreme partner values.
  [`NoteRangeSelector.swift:349`](../../Peach/Settings/NoteRangeSelector.swift#L349)

- `applyDrag` / `handleTap` self-clamp into the absolute MIDI range *after* the partner-clamp, so a corrupt partner can't push the committed value out of `21...108`.
  [`NoteRangeSelector.swift:248`](../../Peach/Settings/NoteRangeSelector.swift#L248)

**Geometry — `Core/Music` (framework-free)**

- The inverse hit-test that drives drag and tap: nearest-centre over all 88 keys, x-clamped so taps outside the viewport map to the boundary note.
  [`PianoKeyboardLayout.swift:58`](../../Peach/Core/Music/PianoKeyboardLayout.swift#L58)

- The forward layout: white keys evenly distributed, black keys at the midpoint between adjacent whites. Recovered from a deleted commit and ported to `MIDINote` / `NoteRange`.
  [`PianoKeyboardLayout.swift:32`](../../Peach/Core/Music/PianoKeyboardLayout.swift#L32)

- `nonisolated` pitch-class predicates so the static keys arrays in `NoteRangeSelector` can use them from a static initializer (no actor context).
  [`PianoKeyboardLayout.swift:15`](../../Peach/Core/Music/PianoKeyboardLayout.swift#L15)

**Input mechanics — drag, tap, keyboard**

- `dragGesture` uses the named `keyboardCoordinateSpace` so `value.location.x` is in the keyboard's frame, not the marker's tiny local frame.
  [`NoteRangeSelector.swift:238`](../../Peach/Settings/NoteRangeSelector.swift#L238)

- `tapResolution` static logic — in-range = no-op, out-of-range = nearer bound moves, equidistant resolves to lower (deterministic).
  [`NoteRangeSelector.swift:369`](../../Peach/Settings/NoteRangeSelector.swift#L369)

- `keyboardCommit` static logic — arrow / Shift-arrow / Home / End mapped to clamped MIDI moves, returning `nil` for clamp-on-edge no-ops so `onCommit` doesn't fire spuriously.
  [`NoteRangeSelector.swift:379`](../../Peach/Settings/NoteRangeSelector.swift#L379)

- `handleKey` wires the static commit logic into `@FocusState` per-marker key handling for macOS.
  [`NoteRangeSelector.swift:282`](../../Peach/Settings/NoteRangeSelector.swift#L282)

**Visual layout — three stacked rows in `keyboardStack`**

- The composition: marker row above, keys row in the middle, octave-label row below — sharing the named coordinate space so drag and tap agree on the origin.
  [`NoteRangeSelector.swift:152`](../../Peach/Settings/NoteRangeSelector.swift#L152)

- `keysRow` renders white keys as a flat `HStack` and black keys as an overlay positioned via the layout's `xPosition`. Tap uses the shared named coordinate space.
  [`NoteRangeSelector.swift:191`](../../Peach/Settings/NoteRangeSelector.swift#L191)

- `markerRow` positions each `BoundMarker` at the layout's `xPosition` for its bound note; per-marker drag gestures attach here.
  [`NoteRangeSelector.swift:164`](../../Peach/Settings/NoteRangeSelector.swift#L164)

**Accessibility**

- The `.accessibilityRepresentation` on `keyboardBody`: two adjustable Sliders, each with `.accessibilityValue(Text(note.name))` so VoiceOver speaks `"Lowest Note, C2"` rather than the raw Double. Step-4 patch.
  [`NoteRangeSelector.swift:138`](../../Peach/Settings/NoteRangeSelector.swift#L138)

- `KeyboardSummary` — the AX1+ fallback rendering a localised summary line plus two stacked system Sliders.
  [`NoteRangeSelector.swift:465`](../../Peach/Settings/NoteRangeSelector.swift#L465)

**Audio preview wiring**

- New `playSoundPreview(note:duration:)` overload — resolves frequency via the user's `tuningSystem` (not hard-coded equal temperament like the A4-only variant).
  [`SettingsCoordinator.swift:51`](../../Peach/App/SettingsCoordinator.swift#L51)

- `trainingRangeSection` wires `NoteRangeSelector.onCommit` to a fire-and-forget `playSoundPreview(note:duration:)` Task at the call site.
  [`SettingsScreen.swift:108`](../../Peach/Settings/SettingsScreen.swift#L108)

**Tests — static helpers, no SwiftUI view instantiation**

- `PianoKeyboardLayoutTests` pins the layout math: white-key count, x-position monotonicity and edges, black-key interpolation, inverse hit-test round-trip and outside-viewport clamp, octave boundaries.
  [`PianoKeyboardLayoutTests.swift:5`](../../PeachTests/Core/Music/PianoKeyboardLayoutTests.swift#L5)

- `NoteRangeSelectorTests` pins clamp/tap/keyboard logic, plus the two step-4 defence tests (`clampLowerAgainstLowUpperStaysValid`, `clampUpperAgainstHighLowerStaysValid`).
  [`NoteRangeSelectorTests.swift:5`](../../PeachTests/Settings/NoteRangeSelectorTests.swift#L5)

**Audit trail**

- Spec Change Log captures: six Code-Map deltas (MainActor isolation, `octaveBoundaries` shape, drag-coordinate fix, marker tap-target trade-off, preview duration, label-row placement), two `/simplify-code` deltas, six step-4 patches, twelve rejected-with-reasoning findings, nine deferred items.
  [`spec-81-3-piano-keyboard-for-training-note-range.md`](./spec-81-3-piano-keyboard-for-training-note-range.md)
