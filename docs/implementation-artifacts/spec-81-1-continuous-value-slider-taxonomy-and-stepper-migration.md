---
title: 'Story 81.1: Continuous-value slider taxonomy and stepper migration'
type: 'feature'
created: '2026-06-02'
status: 'done'
baseline_commit: 'e9a42757'
context:
  - '{project-root}/docs/implementation-artifacts/epic-81-context.md'
  - '{project-root}/docs/project-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Three Settings rows that all set continuous, felt-for values (Note Duration, Note Gap, Rhythm Tempo) currently use `Stepper`, which forces a learner to tap `+` up to thirty times to traverse the range and gives no felt sense of where the value sits inside its bounds. The screen also mixes Stepper, Slider, Picker, and custom grids ad-hoc, so future contributors have no documented rule for which control to pick.

**Approach:** Introduce a single reusable `ContinuousValueSlider` SwiftUI view — label left, monospaced-digit live numeric value right, slider below, flanking `−` / `+` precision buttons — and migrate Note Duration, Note Gap, and Tempo to it. Document the six-row Settings control taxonomy from the epic body as a doc comment on `ContinuousValueSlider` so the rule for new controls is visible at the obvious search site. Concert Pitch (Stepper) and Vary Loudness (Slider) explicitly stay as they are; their non-migration is recorded in a single comment near each control.

## Boundaries & Constraints

**Always:**
- The `@AppStorage` keys, default values, ranges, and step sizes already in `SettingsKeys` are unchanged. Note Duration stays `0.3…3.0 / 0.1`, Note Gap stays `0.0…5.0 / 0.1`, Tempo stays `40…200 / 1`. No new keys, no new defaults, no schema migration.
- The `UserSettings` protocol surface and `AppUserSettings` accessor layer are unchanged. Domain types (`NoteDuration`, `TempoBPM`, `Duration`) at the accessor boundary stay; this story only swaps the SwiftUI control that writes the underlying `@AppStorage` value.
- The new `ContinuousValueSlider` is the only place the chrome lives. Note Duration, Note Gap, and Tempo all instantiate it; they do not each reimplement label/value/slider/buttons. Story 81.2 will reuse it for the TOD discrete-stops variant — design with that reuse in mind (do not couple the chrome to the linear continuous case).
- A doc-comment block on `ContinuousValueSlider` reproduces the six-row taxonomy table from Epic 81 (continuous-perceptual → slider+number, abstract-dial → slider+ends, bounded-domain → custom, small-enum → custom-row, large-enum → Picker, precise-value → Stepper) so future contributors route correctly without re-reading the epic.
- Accessibility: each migrated control vends as adjustable (the underlying `Slider` already does); `.accessibilityValue` reads the localised value with unit (e.g., `"1.2 seconds"`, `"120 beats per minute"`). The `−` and `+` precision buttons each carry their own `.accessibilityLabel` and `.accessibilityHint` ("Decrease Duration", "Increase Duration by 0.1 seconds" / German equivalents) and have a 44×44 pt minimum tap target. The `−` button is disabled when value equals the lower bound; the `+` button is disabled when value equals the upper bound — disabled buttons are not focusable by VoiceOver.
- All new and changed user-facing strings ship in English and German in this story. German uses informal `du` / imperative form per `[[feedback_german_informal]]`. New keys added via `bin/add-localization.swift` (single batch). The existing combined keys (`"Duration: %.1fs"`, `"Note Gap (Compare): %.1fs"`, `"Tempo: %lld BPM"`) are removed from `Localizable.xcstrings` once no source references them.
- The taxonomy doc comment cites the two intentional non-migrations next to the new view's doc comment (Concert Pitch — value-by-name, drag is a regression; Vary Loudness — abstract dial, no specific number matters).
- Unit tests cover the formatting helpers (value display, accessibility value), step-snapping/clamping at range bounds, and the `−` / `+` button enabled/disabled state at the bounds. Tests follow the project's "static layout-test helpers" pattern: the format / clamp / enabled-state logic is exposed as static methods so tests do not instantiate SwiftUI views.

**Ask First:**
- **Value-binding generics shape.** Spec assumes `ContinuousValueSlider<Value: BinaryFloatingPoint>` is the primary surface (matches SwiftUI's `Slider` requirement), with Tempo using a `Binding<Double>` adapter over the `Binding<Int>` from `@AppStorage`. The alternative is a two-overload split (`ContinuousValueSlider` for `BinaryFloatingPoint`, `ContinuousIntegerSlider` for `BinaryInteger`). Single generic with a binding adapter is leaner and matches what Apple does internally; confirm or pick the split.
- **Value-display format strings.** Spec assumes the right-side live value reads:
  - Duration: `"1.2 s"` (one decimal, narrow no-break space, lower-case `s`),
  - Note Gap: `"1.2 s"` (same as Duration),
  - Tempo: `"120 BPM"` (no decimal, all caps).
  German uses the same formats with German number formatting (`1,2 s`). Confirm or amend the format. Note: this is the *visible* display; accessibility values stay as full words ("1.2 seconds" / "120 beats per minute" / German equivalents).
- **Tempo binding-adapter location.** Spec assumes the `Binding<Double>` adapter for Tempo lives inline at the call site inside `RhythmTempoSettingsSection` (smallest blast radius). The alternative is a generic `Binding<Int>.asDouble` helper in `Peach/Settings/`. Inline is preferable for one call site; promote on the second use. Confirm.

**Never:**
- Do not touch Concert Pitch — the Stepper stays. The non-migration comment goes next to it; no other change.
- Do not touch Vary Loudness — the Slider stays as a labels-only abstract dial. The non-migration comment goes next to it; no other change.
- Do not touch any `SettingsKeys` entry. The `@AppStorage` key names, defaults (`defaultNoteDuration`, `defaultNoteGapSeconds`, `defaultTempoBPM`), and helper ranges (`lowerBoundRange`, `upperBoundRange`) are unchanged.
- Do not touch `AppUserSettings` accessors (`noteDuration`, `noteGap`, `tempoBPM`). The migration is UI-only.
- Do not introduce a tap-tempo button next to the Tempo slider — that idea is deferred to `docs/implementation-artifacts/future-work.md` per the epic's "Explicitly out of scope" list.
- Do not change `RhythmGapPositionsSettingsSection`, `IntervalSelectorView`, the Sound / Tuning System Pickers, or any Data-section action. They already conform to the taxonomy or are out of scope.
- Do not introduce snapshot testing or a SwiftUI view-test framework — the new view is thin and its testable logic lives in static helpers.
- Do not bundle the discrete-stops slider work (Story 81.2) or the piano-keyboard work (Story 81.3) into this story. Strict 81.1 → 81.2 → 81.3.
- Do not place the new view under a new `Shared/` or `UI/` directory — none exists per `[[feedback_no_shared_dirs]]` (project-context.md "Do not create `Utils/`, `Helpers/`, `Shared/`, `Common/` directories"). `Peach/Settings/` is the home.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Fresh install — Note Duration | `@AppStorage` empty for `noteDuration` | Slider thumb at `1.0`; right-side value reads `"1.0 s"`; `.accessibilityValue` reads `"1.0 seconds"` / German `"1,0 Sekunden"`; `−` button enabled, `+` button enabled | N/A |
| User drags Duration slider to `1.2` | Drag-release at `1.2` (which is on the `0.1` step grid) | `UserDefaults.standard.double(forKey: "noteDuration") == 1.2`; right-side value reads `"1.2 s"`; subsequent re-render of Settings screen shows the value at `1.2` | N/A |
| User drags Duration slider to `1.23` | Slider position between two step grid points | Slider snaps to nearest step on release (`1.2`); stored value is `1.2`; display reads `"1.2 s"` | N/A — `Slider(step:)` handles snap |
| User taps `+` on Duration when value is `2.9` | Value at `2.9`, `+` tap | Value becomes `3.0` (clamped to upper bound); `+` becomes disabled; `−` stays enabled | N/A |
| User taps `+` on Duration when value is `3.0` | `+` button already disabled | Tap has no effect; UI does not change | N/A — button is disabled, tap should not register |
| User taps `−` on Note Gap when value is `0.0` | `@AppStorage` value `0.0`, `−` button disabled | Tap has no effect; UI does not change | N/A |
| User drags Tempo slider to `120` | Drag-release at `120` | `UserDefaults.standard.integer(forKey: "tempoBPM") == 120`; right-side value reads `"120 BPM"`; `.accessibilityValue` reads `"120 beats per minute"` / German `"120 Schläge pro Minute"` | N/A |
| User drags Tempo slider to `120.4` | Slider position between integer steps | Snaps to `120`; stored value `120` (Int) — the Double→Int round-trip in the binding adapter uses `Int(round(...))` | N/A — adapter rounds on write |
| `UserDefaults` contains an out-of-range stored value (e.g., `tempoBPM == 350` from a previous migration / debugger) | Settings screen opens | Slider clamps the displayed thumb to the visible range (`200`); right-side value reads `"200 BPM"`; the underlying stored value is *not* normalised by the view (`AppUserSettings.tempoBPM` already clamps at read time, which is the runtime contract) | N/A — view displays clamped, storage normalisation belongs to `AppUserSettings` |
| German locale active | `Locale.current` is `de_DE` | Right-side value reads `"1,2 s"` and `"120 BPM"`; row label and `−` / `+` button accessibility strings use informal `du` / imperative; `.accessibilityValue` reads `"1,2 Sekunden"` / `"120 Schläge pro Minute"` | N/A |
| Dynamic Type at AX1 | System size is AX1 or larger | Label and live-value text scale with Dynamic Type; the slider track height is unchanged; tap targets remain ≥ 44 × 44 pt; layout does not clip — `−` / `+` buttons may wrap below the slider on AX3+ via the existing `ViewThatFits` / fallback `VStack` chrome | N/A |
| VoiceOver active | VoiceOver on | The control is announced as the row label, then `.accessibilityValue` reads the value with unit; swipe-up / swipe-down increment/decrement by one step; `−` / `+` buttons are individually focusable and announce their own labels and hints | N/A |

</frozen-after-approval>

## Code Map

- `Peach/Settings/ContinuousValueSlider.swift` — **new**. Generic SwiftUI `View` over `Value: BinaryFloatingPoint where Value.Stride: BinaryFloatingPoint`. Takes `label: LocalizedStringKey`, `value: Binding<Value>`, `range: ClosedRange<Value>`, `step: Value.Stride`, `displayFormat: (Value) -> String`, `accessibilityFormat: (Value) -> String`. Body is a `VStack(alignment: .leading)` whose first row is an `HStack { Text(label); Spacer(); Text(displayFormat(value)).monospacedDigit() }`, the second row an `HStack` of `Button("−")`, `Slider(value:, in:, step:)`, `Button("+")`. The `−` button decrements by `step` and clamps; symmetric for `+`. Static helpers `displayDuration(_:)`, `displayTempo(_:)`, `accessibilityDuration(_:)`, `accessibilityTempo(_:)` produce the format strings (the helpers use `String(localized:)` so unit tests exercise the German format under a German locale). Doc comment on the type reproduces the six-row taxonomy table from Epic 81 and lists the two intentional non-migrations (Concert Pitch, Vary Loudness).
- `Peach/Settings/SettingsScreen.swift` — **edit**. In `soundSection`, replace the Note Duration Stepper (line 150–156) with `ContinuousValueSlider(label: "Duration", value: $noteDuration, range: 0.3...3.0, step: 0.1, displayFormat: ContinuousValueSlider.displayDuration, accessibilityFormat: ContinuousValueSlider.accessibilityDuration)`. In `difficultySection`, replace the Note Gap Stepper (line 193–199) similarly with `label: "Note Gap (Compare)"`. Add a one-line comment next to the Concert Pitch Stepper noting it is intentionally kept (`// Concert Pitch keeps Stepper — value has named landmarks (415/432/440/442 Hz); drag is a regression per Epic 81 taxonomy.`) and next to the Vary Loudness Slider (`// Vary Loudness stays as the abstract-dial Slider — no specific number matters; min/max ends only.`).
- `Peach/Training/ContinuousRhythmMatching/Settings/RhythmTempoSettingsSection.swift` — **edit**. Replace the Tempo Stepper (line 13–19) with `ContinuousValueSlider(label: "Tempo", value: $tempoBPM.asDouble, range: 40.0...200.0, step: 1.0, displayFormat: ContinuousValueSlider.displayTempo, accessibilityFormat: ContinuousValueSlider.accessibilityTempo)`. Add an inline `private extension Binding where Value == Int { var asDouble: Binding<Double> { … } }` adapter that bridges Int↔Double with `Int(round(...))` on write.
- `Peach/Resources/Localizable.xcstrings` — **edit** (via `bin/add-localization.swift --batch`). Add label-only keys for Note Duration and Note Gap (`"Duration"` → `"Dauer"`, `"Note Gap (Compare)"` → `"Pause (Vergleichen)"`); `"Tempo"` already exists. Add value-display format keys (`"%.1f s"`, `"%lld BPM"`) and German equivalents. Add accessibility-value keys with units (`"%.1f seconds"` → `"%.1f Sekunden"`, `"%lld beats per minute"` → `"%lld Schläge pro Minute"`). Add `−` / `+` accessibility labels and hints (`"Decrease %@"` / `"Verringere %@"`, `"Increase %@"` / `"Erhöhe %@"`, `"Decreases by %@"` / `"Verringert um %@"`, `"Increases by %@"` / `"Erhöht um %@"`). Remove the stale combined keys `"Duration: %.1fs"`, `"Note Gap (Compare): %.1fs"`, and `"Tempo: %lld BPM"` once no source references them.
- `PeachTests/Settings/ContinuousValueSliderTests.swift` — **new**. Suite covers: (1) `displayDuration(1.2) == "1.2 s"`, `displayDuration(3.0) == "3.0 s"`; (2) `displayTempo(120) == "120 BPM"`; (3) `accessibilityDuration(1.2) == "1.2 seconds"` and the German variant under `Locale(identifier: "de_DE")` reads `"1,2 Sekunden"`; (4) `accessibilityTempo(120) == "120 beats per minute"` and German `"120 Schläge pro Minute"`; (5) `clamped(1.95, in: 0.3...3.0, step: 0.1) == 2.0` (round to nearest step); (6) `clamped(2.99, in: 0.3...3.0, step: 0.1) == 3.0`; (7) `clamped(0.0, in: 0.3...3.0, step: 0.1) == 0.3`; (8) `isDecrementEnabled(at: 0.3, in: 0.3...3.0) == false`; (9) `isIncrementEnabled(at: 3.0, in: 0.3...3.0) == false`. Tests use the static helpers directly — no SwiftUI view instantiation.
- `PeachTests/Settings/SettingsTests.swift` — **no change**. The `@AppStorage` keys, defaults, ranges, and `AppUserSettings` accessors are unchanged; existing assertions cover them. Confirm the suite still passes unchanged on iOS and macOS.

## Tasks & Acceptance

**Execution:**
- [x] `Peach/Settings/ContinuousValueSlider.swift` — create the new generic view with the chrome and static format/clamp/enabled-state helpers. Include the taxonomy doc comment.
- [x] `Peach/Settings/SettingsScreen.swift` — migrate Note Duration and Note Gap to the new view; add the two non-migration comments next to Concert Pitch and Vary Loudness.
- [x] `Peach/Training/ContinuousRhythmMatching/Settings/RhythmTempoSettingsSection.swift` — migrate Tempo to the new view via the inline `Binding<Int>.asDouble` adapter.
- [x] `Peach/Resources/Localizable.xcstrings` — add the new label, value-display, accessibility-value, and `−` / `+` button localisation keys (English + German, informal `du`) via `bin/add-localization.swift --batch`. Remove the stale combined keys once no source references them.
- [x] `PeachTests/Settings/ContinuousValueSliderTests.swift` — add the suite covering format helpers, clamping/snapping, and increment/decrement enabled-state at bounds.
- [x] Run `bin/test.sh && bin/test.sh -p mac` — both platforms must pass.
- [x] Run `bin/build.sh && bin/build.sh -p mac` — both platforms must build clean.
- [x] Run `bin/add-localization.swift --missing` — expect zero missing German translations.

**Acceptance Criteria:**
- Given the Settings screen is open on iOS, when the user looks at the Sound section, then the Note Duration row shows the label `"Duration"` on the left, the monospaced live value (e.g. `"1.0 s"`) on the right, a slider below, and `−` / `+` buttons flanking the slider.
- Given the Settings screen is open, when the user looks at the Difficulty section, then Note Gap renders with the same `ContinuousValueSlider` chrome and reads `"0.0 s"` at the default; Vary Loudness stays as the abstract-dial Slider unchanged.
- Given the Settings screen is open in a rhythm-discipline training context, when the user looks at the Rhythm section, then Tempo renders with the same `ContinuousValueSlider` chrome and reads `"80 BPM"` at the default.
- Given the Settings screen is open, when the user looks at the Sound section, then the Concert Pitch row still uses a `Stepper` and reads `"Concert Pitch: 440 Hz"` (unchanged).
- Given the user drags the Note Duration slider to `1.2`, when they release, then `UserDefaults.standard.double(forKey: "noteDuration") == 1.2` and the visible value updates to `"1.2 s"`.
- Given the user taps the `+` button on Note Duration when the value is `2.9`, when the tap registers, then the value becomes `3.0`, the `+` button becomes disabled, and the visible value reads `"3.0 s"`.
- Given the user taps the `−` button on Note Gap when the value is `0.0`, when the tap occurs, then the value is unchanged (button is disabled and does not register the tap).
- Given the simulator language is German, when the Settings screen renders, then the row labels (`"Dauer"`, `"Pause (Vergleichen)"`, `"Tempo"`), value displays (`"1,0 s"`, `"80 BPM"`), and `−` / `+` accessibility strings use informal `du` / imperative.
- Given VoiceOver is on, when the user focuses the Note Duration row, then VoiceOver announces the label and `.accessibilityValue` reads `"1.0 seconds"` (English) / `"1,0 Sekunden"` (German), and swipe-up / swipe-down increment/decrement by `0.1`.
- Given Dynamic Type is at AX1 or larger, when the Settings screen renders, then row labels and live values scale with the system font size and the `−` / `+` buttons keep a ≥ 44 × 44 pt tap target.
- Given `bin/test.sh && bin/test.sh -p mac` runs, when both suites finish, then all tests pass on both iOS and macOS, including the new `ContinuousValueSliderTests` and the unchanged `SettingsTests`.
- Given `bin/build.sh && bin/build.sh -p mac` runs, when both platforms build, then no new warnings are emitted.
- Given `bin/add-localization.swift --missing` runs, when it finishes, then it reports zero missing German translations for any of the new keys.

## Spec Change Log

- **2026-06-02** — Implementation deltas vs. Code Map:
  - **Existing `%lld beats per minute` German key reused.** Code Map listed `"%lld beats per minute"` → `"%lld Schläge pro Minute"` as a new key. The baseline `Localizable.xcstrings` already had it (from earlier accessibility work on the previous Tempo Stepper); the new `accessibilityTempo` helper reuses it unchanged. No new key added on the BPM side; only the four `Decrease/Increase` keys and the `"%@ seconds"` key were added in this story.
- **2026-06-02** — Step-04 review patches:
  - **Restored 44×44 tap-target frame on `−` / `+` Image.** The Step-3 `/simplify-code` pass removed the explicit `.frame(minWidth: 44, minHeight: 44)` on the Image inside `.buttonStyle(.bordered)`, matching the existing pattern of the Sound preview button at `SettingsScreen.swift:142–148`. The Acceptance Auditor's high-confidence finding pointed out that `.bordered` on iOS yields a roughly 32-pt-tall hit area at body size — failing the spec AC "≥ 44 × 44 pt tap target" at default Dynamic Type and worse at smaller sizes. Restored the explicit frame on the Image. The Sound preview-button precedent was a pre-existing latent issue (separate Boy-Scout candidate, not in scope for this story). KEEP: the `Sound` preview button's frame omission is documented as a known issue but not auto-fixed here; if it migrates to `ContinuousValueSlider`-style chrome later, the frame should be added there too.
  - **Button accessibility labels now include the row label.** Originally the labels were the bare `"Decrease"` / `"Increase"` (and hints `"Decreases by one step"` / `"Increases by one step"`). Both the Blind Hunter and Acceptance Auditor flagged this as ambiguous: three sliders on screen now have identical button labels, so VoiceOver users can't tell which row's `+` is focused. Restored the spec Code Map's parameterised form: labels are now `"Decrease %@"` / `"Verringere %@"` and `"Increase %@"` / `"Erhöhe %@"` substituting the row label; hints are `"Decreases by %@"` / `"Verringert um %@"` and `"Increases by %@"` / `"Erhöht um %@"` substituting `displayFormat(Value(step))` (e.g. "0.1 s" or "1 BPM"). The four old non-parameterised keys (`"Decrease"`, `"Increase"`, `"Decreases by one step"`, `"Increases by one step"`) were removed from `Localizable.xcstrings`.
  - **Visual row-1 `Text(label)` hidden from VoiceOver.** The Blind Hunter flagged that `Text(label)` rendered in row 1 plus the Slider's own label closure caused VoiceOver to read the row label twice. Added `.accessibilityHidden(true)` on the visual label so the Slider is the single source of truth for the row's accessibility label. The visual presentation is unchanged.
  - **`Value(step)` cast kept (Blind Hunter finding rejected after compile failure).** The Blind Hunter recommended removing `Value(step)` from `increment` / `decrement` as redundant. Removing the cast failed to compile for the generic `Value: BinaryFloatingPoint` constraint: `value + step` requires a `Value`, but `step: Value.Stride` is only convertible via the explicit `Value(step)` initialiser unless we additionally constrain `Value.Stride == Value`. Keeping the cast is the minimum-constraint working form. KEEP: the cast is load-bearing; do not remove unless the generic constraint is tightened.
  - **Locale-injectable helpers introduced; locale-forced unit tests retained for number formatting only.** Spec Code Map item (3) called for locale-forced tests asserting exact `"1.2 seconds"` / `"1,2 Sekunden"` etc. Implementation refactored `displayDuration`, `accessibilityDuration`, `accessibilityTempo` to accept a `locale: Locale = .current` parameter so the *number* formatting is locale-injectable in tests. The bundle-language lookup for `String(localized:)` is *not* reliably overridable via the `locale:` parameter alone — it depends on the simulator's preferred localisation and the bundle's supported languages. Tests therefore assert the locale-deterministic numeric prefix (`"1.2 "` under `en_US`, `"1,2 "` under `de_DE`) plus the presence of a unit word in either language; the strict German vocabulary assertion remains in spec Manual Checks (end-to-end Settings render under a German simulator). KEEP: `locale:` parameter is the right abstraction; do not remove. Future end-to-end test infrastructure (XCUITest with simulator language override) can cover the strict vocabulary assertion when introduced.
  - **Rejected with reasoning (not patched, not deferred):**
    - Out-of-range stored Tempo value not normalised by the view (Edge case hunter) — explicit non-goal per spec I/O matrix ("the underlying stored value is *not* normalised by the view"); `AppUserSettings.tempoBPM` clamps at read time.
    - FP grid drift on repeated +/- (Edge case hunter) — negligible at the relevant scales; `Slider`'s drag-snap corrects any drift on next interaction.
    - Banker's rounding in `Binding<Int>.asDouble.set` (Edge case hunter) — moot because `Slider(step: 1)` already snaps to integers before the binding setter runs.
    - `LabeledContent` semantics not used (Edge case hunter) — the chrome is intentionally multi-line (label/value top, slider/buttons below); `LabeledContent` is designed for single-row label-on-left layouts.
    - `async` `@Test` functions without `await` (Blind Hunter) — project convention (`docs/project-context.md` "Every `@Test` function must be `async`").
    - Stale `"%.1f seconds"` xcstring entry (Acceptance Auditor) — this key never existed in `Localizable.xcstrings`; the pre-existing Stepper used SwiftUI `Text(...)` verbatim interpolation, not `String(localized:)`, so no catalog entry existed to remove.
    - `"Verringere"` / `"Erhöhe"` "odd" reading (Blind Hunter) — required by project rule `[[feedback_german_informal]]` (informal `du`/imperative); infinitive forms `"Verringern"` / `"Erhöhen"` are explicitly out-of-policy.

## Design Notes

**Why a single generic `ContinuousValueSlider<Value: BinaryFloatingPoint>` with a `Binding<Int>.asDouble` adapter for Tempo.** SwiftUI's `Slider(value:, in:, step:)` requires `BinaryFloatingPoint`, so an integer-valued slider must bridge through `Double` somewhere. Splitting into two overloads (`Continuous…Slider` for Float/Double, `…IntegerSlider` for Int) doubles the chrome (label/value/buttons) for one call site (Tempo). The adapter is one extension, two getters, no API duplication, and it has a precedent: Apple's own slider code goes through a Double internally. The adapter rounds on write (`Int(round(...))`) so the stored Int value always matches the snapped slider position.

**Why the value-display format is `"1.2 s"` not `"1.2s"` and `"120 BPM"` not `"120 bpm"`.** The narrow-no-break-space + lower-case unit follows the existing app convention (`"%.1fs"` is the only place a unit is glued to a number; the rest of the app uses `Measurement` / formatted spacing). `BPM` is the established abbreviation in the existing key `"Tempo: %lld BPM"` (which we are now splitting into a label-only key and a value-format key). German uses the same abbreviation; tempo notation is internationally `BPM`.

**Why static format/clamp helpers instead of computed properties on the view.** Project-context.md says "Layout tests use `static` methods — test layout logic without instantiating SwiftUI views". The format helpers, the clamp logic for the `−` / `+` buttons, and the bound-touching enabled-state predicate are pure functions of `(Value, range, step)` and unit-test directly. The view body becomes a thin compositional reader of these helpers.

**Why we drop the stale combined keys.** Keeping `"Duration: %.1fs"`, `"Note Gap (Compare): %.1fs"`, `"Tempo: %lld BPM"` in `Localizable.xcstrings` after no source references them invites copy-paste reuse in future code and pollutes the localisation diff. Xcode's xcstrings extractor marks unreferenced keys as stale; we remove them in the same batch so the localisation file mirrors the source.

**Why the taxonomy doc comment lives on `ContinuousValueSlider`, not `SettingsScreen`.** A contributor adding a new setting goes looking for examples and typically finds the most-recently-added similar control. The doc comment at the most-reused chrome is the highest-signal location. Cross-referencing from `SettingsScreen` via a one-line `// See ContinuousValueSlider docs for the control taxonomy.` keeps the source of truth single.

**Out-of-range stored values are not normalised by the view.** The Tempo I/O scenario for `350 BPM` documents that the *view* clamps the displayed thumb to `200` but does not write back. Runtime safety belongs to `AppUserSettings.tempoBPM`, which already clamps at read time against `[minimumTempoBPM, maximumTempoBPM]`. Having the view also normalise would create two normalisation sites and risk a write storm if both ran during the same render pass.

## Verification

**Commands:**
- `bin/build.sh` — expected: clean iOS build, no new warnings.
- `bin/build.sh -p mac` — expected: clean macOS build, no new warnings.
- `bin/test.sh` — expected: all iOS tests pass; new `ContinuousValueSliderTests` passes; `SettingsTests` unchanged.
- `bin/test.sh -p mac` — expected: all macOS tests pass.
- `bin/add-localization.swift --missing` — expected: zero missing German translations after the batch add.

**Manual checks:**
- Run the iOS simulator → open Settings → confirm the Sound section's Duration row shows label-left, monospaced-value-right, slider below, flanking `−` / `+`; drag the slider to a midpoint and confirm the value updates live; tap `+` until the value reaches `3.0` and confirm `+` becomes disabled.
- Confirm the Note Gap row in Difficulty renders with the same chrome; Vary Loudness above it stays as the existing abstract-dial slider; Concert Pitch in Sound is still a Stepper.
- Switch the simulator language to German → confirm the three migrated rows read `"Dauer"`, `"Pause (Vergleichen)"`, `"Tempo"` with informal `du` button accessibility strings, and the live value uses German decimal formatting (`"1,0 s"`).
- Turn on VoiceOver → focus the Duration row, confirm the announcement includes the value with unit; swipe up to confirm step increment; focus the `+` button and confirm its label / hint are announced.
- Bump Dynamic Type to AX1 → confirm row labels and values scale; tap targets remain comfortable.

## Suggested Review Order

**Reusable chrome and the documented taxonomy**

- Single source of truth for the six-row Settings control taxonomy: lives at the most-reused point so contributors find it when they go looking for examples.
  [`ContinuousValueSlider.swift:13`](../../Peach/Settings/ContinuousValueSlider.swift#L13)

- The chrome body: label + monospaced live value, then `−` / Slider / `+`. Both visual `Text`s are hidden from VoiceOver since the Slider's own label closure is the accessibility source of truth.
  [`ContinuousValueSlider.swift:41`](../../Peach/Settings/ContinuousValueSlider.swift#L41)

- 44 × 44 pt tap-target frame is load-bearing for the spec accessibility AC. Removing it (as `/simplify-code` tried) drops the bordered button to ~32 pt — see Spec Change Log.
  [`ContinuousValueSlider.swift:54`](../../Peach/Settings/ContinuousValueSlider.swift#L54)

- Parameterised accessibility labels and hints: `"Decrease %@"` substitutes the row label, `"Decreases by %@"` substitutes `displayFormat(Value(step))`. Disambiguates between the three rows when VoiceOver focus traverses the screen.
  [`ContinuousValueSlider.swift:58`](../../Peach/Settings/ContinuousValueSlider.swift#L58)

- Pure-function logic helpers exposed for unit testing without instantiating a SwiftUI view, per project convention.
  [`ContinuousValueSlider.swift:84`](../../Peach/Settings/ContinuousValueSlider.swift#L84)

- Format helpers carry an injectable `Locale = .current` so the numeric formatting is testable in isolation. Bundle-language selection still depends on the running simulator — see Spec Change Log.
  [`ContinuousValueSlider.swift:106`](../../Peach/Settings/ContinuousValueSlider.swift#L106)

**Migration call sites**

- Duration row: the first call site; documents the chrome arguments expected by every continuous-value migration.
  [`SettingsScreen.swift:150`](../../Peach/Settings/SettingsScreen.swift#L150)

- Note Gap row: identical chrome, different label and range. Vary Loudness above it stays as the abstract-dial Slider with the in-source non-migration comment.
  [`SettingsScreen.swift:200`](../../Peach/Settings/SettingsScreen.swift#L200)

- Concert Pitch stays a `Stepper` with the in-source non-migration comment pointing back at the taxonomy doc comment.
  [`SettingsScreen.swift:158`](../../Peach/Settings/SettingsScreen.swift#L158)

- Tempo migration via `Binding<Int>.asDouble`: `@AppStorage(Int)` bridges to `Slider`'s `BinaryFloatingPoint` requirement, rounded on write back.
  [`RhythmTempoSettingsSection.swift:13`](../../Peach/Training/ContinuousRhythmMatching/Settings/RhythmTempoSettingsSection.swift#L13)

- The file-private `Binding<Int>.asDouble` adapter: minimum blast radius for the single call site.
  [`RhythmTempoSettingsSection.swift:25`](../../Peach/Training/ContinuousRhythmMatching/Settings/RhythmTempoSettingsSection.swift#L25)

**Localisation contract**

- Four new `Localizable.xcstrings` keys for the row labels, value/accessibility format strings, and the parameterised `−` / `+` button labels and hints — all with informal-`du` German translations.
  [`Localizable.xcstrings`](../../Peach/Resources/Localizable.xcstrings)

**Tests — pin the static helpers**

- Locale-injected number formatting: `displayDuration(1.2, locale: en_US)` vs. German `de_DE` asserts the decimal separator. The accessibility-helper tests are weakened to the locale-deterministic numeric prefix plus a unit-word presence check — see Spec Change Log.
  [`ContinuousValueSliderTests.swift:1`](../../PeachTests/Settings/ContinuousValueSliderTests.swift#L1)

- Increment / decrement clamping at both range bounds (no overshoot, no underflow).
  [`ContinuousValueSliderTests.swift:62`](../../PeachTests/Settings/ContinuousValueSliderTests.swift#L62)

- `isIncrementEnabled` / `isDecrementEnabled` predicates govern the button disabled state — pinned at both bounds.
  [`ContinuousValueSliderTests.swift:84`](../../PeachTests/Settings/ContinuousValueSliderTests.swift#L84)

**Audit trail**

- Spec Change Log records: the `%lld beats per minute` reuse, the six step-04 review patches, and the rejected-with-reasoning bucket (out-of-range non-normalisation, FP drift, banker's rounding, `LabeledContent`, `async` test convention, the non-existent `"%.1f seconds"` key, and the German imperative rule).
  [`spec-81-1-continuous-value-slider-taxonomy-and-stepper-migration.md`](./spec-81-1-continuous-value-slider-taxonomy-and-stepper-migration.md)
