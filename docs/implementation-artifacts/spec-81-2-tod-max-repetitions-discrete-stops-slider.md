---
title: 'Story 81.2: TOD Max Repetitions discrete-stops slider'
type: 'feature'
created: '2026-06-03'
status: 'done'
baseline_commit: 'd4c9b025'
context:
  - '{project-root}/docs/implementation-artifacts/epic-81-context.md'
  - '{project-root}/docs/implementation-artifacts/spec-81-1-continuous-value-slider-taxonomy-and-stepper-migration.md'
  - '{project-root}/docs/project-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `TimingOffsetDetectionMaxRepetitionsSettingsSection` renders the six choices `[1, 2, 3, 5, 10, ∞]` as a SwiftUI `Picker`, which on iOS pops a wheel sheet and on macOS a pop-up menu. Visually it sits next to Tempo (now a slider after 81.1) and Note Gap (slider), so the Settings screen reads as inconsistent for what is conceptually a "choose a position on a small ordered scale" decision. The current Picker also hides the qualitative non-linearity of the stops — `5 → 10 → ∞` is the same one-tap-away gesture as `1 → 2 → 3`, which is fine but is not the picture the values themselves paint.

**Approach:** Introduce a sibling to `ContinuousValueSlider`, `DiscreteStopsSlider`, that reuses the same visual chrome (label left, monospaced live value right, `−` / `Slider` / `+` row below) but maps the slider position to a non-linear stops list `[1, 2, 3, 5, 10, ∞]` with *equal visual spacing between stops* and tick marks at each stop. The slider snaps to a stop on drag-release; `−` / `+` step to the adjacent stop. The `∞` glyph renders at the rightmost stop in both the inline value and in the accessibility-value vocabulary ("unlimited" / "unbegrenzt"). Replace the `Picker` body of `TimingOffsetDetectionMaxRepetitionsSettingsSection` with the new view; the section's footer copy, `@AppStorage` key, default value, and storage encoding are unchanged.

## Boundaries & Constraints

**Always:**
- The `@AppStorage` key (`"timingOffsetDetectionMaxRepetitions"`), default value (`TimingOffsetDetectionSettingsKeys.defaultMaxRepetitions == 20`), and the `[1, 2, 3, 5, 10, defaultMaxRepetitions]` stops list are unchanged. `∞` is still stored as the integer `defaultMaxRepetitions` (20); neither `TimingOffsetDetectionUserSettings`, `AppTimingOffsetDetectionUserSettings`, `TimingOffsetDetectionSettings.from`, nor `TimingOffsetDetectionSession.maxRepetitions` change. No schema migration.
- The new `DiscreteStopsSlider` is a sibling of `ContinuousValueSlider`, not a refactor of it. Both views live in `Peach/Settings/`. They share the *visual* idiom (label-row on top, button–slider–button row below) and the project-context "static helpers" testability pattern, but their internal plumbing differs (`ContinuousValueSlider` binds a `BinaryFloatingPoint` value over a range with step-snapping; `DiscreteStopsSlider` binds an `Int` value to an integer index into a `stops: [Int]` array via an internal `Binding<Double>` adapter). Do not refactor the 81.1 chrome into a shared base view in this story — additive only, smallest blast radius.
- `DiscreteStopsSlider` uses SwiftUI `Slider(value: indexBinding, in: 0...Double(stops.count - 1), step: 1)` internally so the snap-to-stop behaviour comes from the system slider for free, and the underlying `Slider` accessibility (`adjustable` trait, VoiceOver swipe-up/down, Switch Control increment/decrement) works without a custom `.accessibilityRepresentation`. `.accessibilityValue(Text(accessibilityFormat(value)))` overrides the slider's default "0%–100%" announcement with the stop-formatted string.
- Tick marks render as thin `Rectangle` overlays at evenly spaced positions along the slider track via a `GeometryReader`-free `HStack { Rectangle; Spacer }` pattern padded to approximate the system slider's thumb-radius inset. Exact pixel alignment with the snap positions is approximate (the system slider's internal padding is private); the goal is "the user sees there are six discrete positions" rather than pixel-perfect tick-to-thumb registration. Tick height ~6 pt, width 1 pt, fill `.tertiary`.
- The label row hides its visual `Text` from VoiceOver via `.accessibilityHidden(true)` so the system slider's own label closure remains the single source of truth for the row's accessibility label, matching the 81.1 pattern.
- `−` / `+` precision buttons step between adjacent indices and clamp at index `0` / `stops.count - 1`. Each button is `.disabled` at its corresponding bound. Each button carries a parameterised accessibility label (`"Decrease %@"` / `"Increase %@"`, the four existing keys from 81.1) substituting the row label, and a hint phrased for the discrete-stops case ("Selects the next lower value" / "Selects the next higher value" with German equivalents) because the per-step magnitude varies and a fixed numeric hint would be wrong.
- The `−` / `+` `Image` carries an explicit `.frame(minWidth: 44, minHeight: 44)` to maintain the FR38 44×44 pt tap target, matching the 81.1 fix.
- Display format ("visual value, right side, monospaced digits"): `"1"`, `"2"`, `"3"`, `"5"`, `"10"`, `"∞"`. The `∞` glyph is a literal in source (not a separate xcstrings key) — it's a Unicode symbol, locale-independent.
- Accessibility format (VoiceOver value): the integer stops read as their digit (`"1"`, `"5"`, …); the `∞` stop reads as `"unlimited"` in English and `"unbegrenzt"` in German. Two new xcstrings keys are added for this single substitution.
- Static helper functions on `DiscreteStopsSlider` expose the pure logic for unit tests: `nearestStopIndex(to: Int, in: [Int]) -> Int`, `incrementIndex(_: Int, in: [Int]) -> Int`, `decrementIndex(_: Int, in: [Int]) -> Int`, `isIncrementEnabled(at: Int, in: [Int]) -> Bool`, `isDecrementEnabled(at: Int, in: [Int]) -> Bool`, plus the existing 81.1-style `displayMaxRepetitions(_:)` / `accessibilityMaxRepetitions(_:locale:)` on the call site or as static helpers on the view.
- Defence in depth for stored values not in `stops`: a stored value of e.g. `7` (a debugger write, a future-config artifact) maps via `nearestStopIndex` to the *nearest* stop's index for the slider position; the stored value is not rewritten on render. On the user's next interaction, the value snaps to a real stop. This is strictly better than the current Picker, which silently shows no selection.
- The existing footer copy (`"At ∞, the pattern keeps repeating until you submit a direction. Pick 1 to restore the single-pattern challenge."` / German equivalent already in `Localizable.xcstrings`) is retained verbatim. The existing `TimingOffsetDetectionHelp.maxRepetitionsSettingsHelp` body referencing **∞** and **1** is retained verbatim.
- All new and changed user-facing strings ship in English and German in this story. German uses informal `du` / imperative form per `[[feedback_german_informal]]`. New keys added via `bin/add-localization.swift --batch`. Use existing keys where they already cover the string ("Maximum Repetitions" exists; "Decrease %@", "Increase %@" exist).
- Unit tests cover the static helpers (nearest-stop lookup including out-of-set values, increment/decrement clamping at both ends, enabled-state predicates at both ends, display/accessibility format including the `∞` boundary). Tests follow the project-context "static layout-test helpers" pattern: no SwiftUI view instantiation. Existing `DisciplineSettingsSectionAggregationTests`, `AppTimingOffsetDetectionUserSettingsTests`, and `TimingOffsetDetectionSettingsTests` continue to pass unchanged.

**Ask First:**
- **View name.** Spec uses `DiscreteStopsSlider`. Alternatives considered: `SteppedSlider`, `SnappingSlider`, `EnumSlider`. `DiscreteStopsSlider` matches the epic body's vocabulary ("discrete-stops slider"). Confirm or pick the alternative.
- **Vocabulary for `∞` accessibility value.** Spec assumes `"unlimited"` / `"unbegrenzt"`. Alternative: `"infinity"` / `"unendlich"` (literal symbol-to-word translation). `"Unlimited"` reads more naturally in a sentence ("Maximum Repetitions: unlimited" vs. "Maximum Repetitions: infinity"); German `"unbegrenzt"` is the established term in the existing help text at `Localizable.xcstrings:62` ("…bis du dich entscheidest"). Confirm.
- **Hint phrasing for `−` / `+`.** Spec assumes generic `"Selects the next lower value"` / `"Selects the next higher value"`. Alternative: row-label-parameterised `"Decreases %@ to the next lower stop"` / similar. The generic form is shorter and works for any future `DiscreteStopsSlider` use; the parameterised form is consistent with 81.1's hint style but reads awkwardly at the discrete-stops case. Confirm.
- **Tick-mark visibility under Increase Contrast / High Contrast.** Spec uses `.tertiary` fill. If Increase Contrast is on, `.tertiary` may not provide enough delta against the slider track background. Confirm the default is acceptable for first cut, or call for a `Color(uiColor: .label).opacity(0.3)` fallback under high-contrast environments.

**Never:**
- Do not refactor `ContinuousValueSlider` to share a base view or chrome primitive with `DiscreteStopsSlider`. Two siblings, additive, in `Peach/Settings/`. Refactoring 81.1's view widens the story's blast radius for no compile-time benefit; future consolidation (if ever justified) is a separate retrospective candidate.
- Do not change `TimingOffsetDetectionSettingsKeys.defaultMaxRepetitions`, the stops list values, the `@AppStorage` key, or the storage encoding. The `∞` sentinel-as-int is the contract `TimingOffsetDetectionSession` and `TimingOffsetDetectionSettings` both depend on.
- Do not change `TimingOffsetDetectionUserSettings`, `AppTimingOffsetDetectionUserSettings`, `TimingOffsetDetectionSettings.from`, or the read-time clamp at `AppTimingOffsetDetectionUserSettings.maxRepetitions`. The migration is UI-only.
- Do not change `TimingOffsetDetectionHelp.maxRepetitionsSettingsHelp` content or the section footer text. The discoverability copy is unchanged.
- Do not introduce a separate `DiscreteStopsSlider<Value: Hashable>` generic surface. Spec keeps `value: Binding<Int>` + `stops: [Int]` typed because: (a) this is the only call site in the codebase, (b) the nearest-stop fallback requires `Comparable`, (c) the existing call site stores `Int`, and (d) a generic version with `Comparable` constraints adds noise without a second caller to justify it. If a second discrete-stops Settings row ever appears, that story is the right time to generalise.
- Do not introduce snapshot testing or a SwiftUI view-test framework — the new view is thin and its testable logic lives in static helpers, matching 81.1.
- Do not move `TimingOffsetDetectionMaxRepetitionsSettingsSection` out of `Peach/Training/TimingOffsetDetection/Settings/`. The feature directory home is correct; only the body changes.
- Do not bundle the piano-keyboard work (Story 81.3) into this story. Strict 81.1 → 81.2 → 81.3.
- Do not place the new view under a new `Shared/` or `UI/` directory — none exists per the project-context rule "Do not create `Utils/`, `Helpers/`, `Shared/`, `Common/` directories". `Peach/Settings/` is the home, next to `ContinuousValueSlider`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Fresh install — Maximum Repetitions | `@AppStorage` empty for `timingOffsetDetectionMaxRepetitions` | Slider thumb at rightmost stop (index 5, value 20); right-side display reads `"∞"`; `.accessibilityValue` reads `"unlimited"` (English) / `"unbegrenzt"` (German); `−` enabled, `+` disabled (at upper bound). | N/A |
| User drags slider one stop left from `∞` | Drag ends near index 4 | Slider snaps to index 4 (`stops[4] == 10`); `UserDefaults.standard.integer(forKey: "timingOffsetDetectionMaxRepetitions") == 10`; display reads `"10"`; accessibility reads `"10"`. | N/A — `Slider(step: 1)` handles snap |
| User taps `−` at the `∞` cap | Value `20`, `−` tap | Value becomes `10` (index 4); display `"10"`; `+` becomes enabled. | N/A |
| User taps `+` at `10` | Value `10`, `+` tap | Value becomes `20` (index 5, `∞`); display `"∞"`; `+` becomes disabled. | N/A |
| User taps `−` at `1` | Value `1` (index 0), `−` already disabled | Tap has no effect (button disabled and does not register). | N/A |
| User taps `+` at `∞` | Value `20` (index 5), `+` already disabled | Tap has no effect. | N/A |
| User drags from `1` to mid-slider position | Drag ends between two stops | Slider snaps to nearest integer index on release; stored value is `stops[snappedIndex]`. | N/A |
| `@AppStorage` contains a value not in `stops` (e.g., `7`) | Settings screen opens | `nearestStopIndex(to: 7, in: [1,2,3,5,10,20]) == 3` (stop value `5`); slider thumb at index 3; display reads `"5"`. The stored `7` is *not* rewritten by the view. | N/A — view displays the nearest stop; storage normalisation belongs to `AppTimingOffsetDetectionUserSettings.maxRepetitions` (already clamps `< 1` to default at read time) |
| User then drags the slider after the out-of-set load | From the visualised index 3, user drags to index 4 | Stored value becomes `10` (a real stop). First user interaction implicitly normalises any out-of-set value. | N/A |
| German locale active | `Locale.current` is `de_DE` | Row label reads `"Maximale Wiederholungen"` (existing key); display values unchanged (digits, `∞`); `.accessibilityValue` at the cap reads `"unbegrenzt"`; `−` / `+` accessibility labels read `"Verringere Maximale Wiederholungen"` / `"Erhöhe Maximale Wiederholungen"` (existing parameterised keys); hints read `"Wählt den nächst niedrigeren Wert"` / `"Wählt den nächst höheren Wert"`. | N/A |
| Dynamic Type at AX1+ | System size is AX1 or larger | Label and live-value text scale with Dynamic Type; slider track height unchanged; `−` / `+` retain ≥ 44 × 44 pt tap target; tick marks scale only in horizontal position (height pinned). | N/A |
| VoiceOver active | VoiceOver on | The row announces label + `.accessibilityValue` (e.g., "Maximum Repetitions, 5, adjustable"); swipe-up moves to the next stop (index +1) and announces the new value; swipe-down moves to the previous stop; `−` / `+` buttons are individually focusable, announce parameterised labels and hints. | N/A |
| Switch Control active | Switch Control scanning on | The slider element receives increment / decrement actions that move by one stop index; the `−` / `+` buttons are independent scannable elements. | N/A |
| App backgrounded mid-drag | User releases drag while app backgrounds | Slider snap and `@AppStorage` write are synchronous SwiftUI bindings; no async work to interrupt. | N/A |

</frozen-after-approval>

## Code Map

- `Peach/Settings/DiscreteStopsSlider.swift` — **new**. Sibling of `ContinuousValueSlider`. Concretely typed `struct DiscreteStopsSlider: View` (no generics) with stored properties `label: LocalizedStringKey`, `value: Binding<Int>`, `stops: [Int]` (must be sorted ascending; this is a precondition, not enforced at runtime — the single call site complies), `displayFormat: (Int) -> String`, `accessibilityFormat: (Int) -> String`. Body mirrors `ContinuousValueSlider`'s `VStack(alignment: .leading, spacing: 4) { HStack { label; Spacer; value }; HStack { −; Slider; + } }`. The internal index binding adapts `$value` to `Binding<Double>` via `Self.indexBinding($value, in: stops)`. The slider is `Slider(value: indexBinding, in: 0...Double(stops.count - 1), step: 1) { Text(label) }` with the `.accessibilityValue(Text(accessibilityFormat(value)))` override. Tick marks render via `.overlay(alignment: .bottom) { ... HStack of 1×6 Rectangles with Spacer separators, padded horizontally to approximate the system slider's thumb-radius inset ... .offset(y: 4) }`. Doc comment cross-references `ContinuousValueSlider`'s taxonomy table: a single line `/// Discrete-stops sibling of ``ContinuousValueSlider``. See its doc comment for the full Settings control taxonomy.` Static helpers (all `static func` on `DiscreteStopsSlider`): `indexBinding(_ value: Binding<Int>, in stops: [Int]) -> Binding<Double>` (used by the view body), `nearestStopIndex(to value: Int, in stops: [Int]) -> Int` (smallest-absolute-distance lookup; ties resolved to the higher index for consistency with the current default-at-`∞` shape), `incrementIndex(_ value: Int, in stops: [Int]) -> Int` (returns `stops[min(currentIndex + 1, stops.count - 1)]` from the nearest stop), `decrementIndex(_ value: Int, in stops: [Int]) -> Int` (returns `stops[max(currentIndex - 1, 0)]`), `isIncrementEnabled(at value: Int, in stops: [Int]) -> Bool` (`nearestStopIndex(to:in:) < stops.count - 1`), `isDecrementEnabled(at value: Int, in stops: [Int]) -> Bool` (`nearestStopIndex(to:in:) > 0`). Static format helpers specific to the TOD max-repetitions use case live alongside: `displayMaxRepetitions(_ value: Int, capValue: Int) -> String` returns `value == capValue ? "∞" : "\(value)"`; `accessibilityMaxRepetitions(_ value: Int, capValue: Int, locale: Locale = .current) -> String` returns either the integer as a string or `String(localized: "unlimited", locale: locale, comment: "Accessibility value for the Maximum Repetitions slider when set to the unlimited cap. German: \"unbegrenzt\".")` at the cap.
- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionMaxRepetitionsSettingsSection.swift` — **edit**. Body becomes `Section { DiscreteStopsSlider(label: "Maximum Repetitions", value: $maxRepetitions, stops: Self.choices, displayFormat: { DiscreteStopsSlider.displayMaxRepetitions($0, capValue: TimingOffsetDetectionSettingsKeys.defaultMaxRepetitions) }, accessibilityFormat: { DiscreteStopsSlider.accessibilityMaxRepetitions($0, capValue: TimingOffsetDetectionSettingsKeys.defaultMaxRepetitions) }) } footer: { Text(...) }`. Delete the inner `Picker { ForEach { ... } }` and the private `label(for:)` helper (logic moves to the static `displayMaxRepetitions` on `DiscreteStopsSlider`). The `private static let choices` array stays in this file as the source of truth for which stops this Settings row exposes (single point of change if the stops list ever shifts). The doc comment at the top of the file is updated to reference `DiscreteStopsSlider` instead of `Picker`.
- `Peach/Resources/Localizable.xcstrings` — **edit** (via `bin/add-localization.swift --batch`). Add two keys for the `−` / `+` hints: `"Selects the next lower value"` → `"Wählt den nächst niedrigeren Wert"`, `"Selects the next higher value"` → `"Wählt den nächst höheren Wert"`. Add one key for the `∞` accessibility value: `"unlimited"` → `"unbegrenzt"`. Confirm existing keys are reused unchanged: `"Maximum Repetitions"` (line 1807 in baseline), `"Decrease %@"` / `"Increase %@"` (added by 81.1), the footer key (line 521), and the help-section key (line 57). No keys are removed.
- `PeachTests/Settings/DiscreteStopsSliderTests.swift` — **new**. Suite covers: (1) `nearestStopIndex(to: 1, in: [1,2,3,5,10,20]) == 0`; `(to: 5, ...) == 3`; `(to: 20, ...) == 5`; (2) out-of-set: `nearestStopIndex(to: 7, in: [1,2,3,5,10,20]) == 3` (closer to 5 than 10), `(to: 8, ...) == 4` (closer to 10 than 5), `(to: 0, ...) == 0`, `(to: 100, ...) == 5`; (3) tie-breaking on a constructed `[1, 10]` stops: `nearestStopIndex(to: 5, in: [1, 10])` resolves to the higher index `1` (documented behaviour); (4) `incrementIndex(5, in: [1,2,3,5,10,20]) == 10`; `incrementIndex(20, ...) == 20` (clamps at cap); (5) `decrementIndex(5, in: [1,2,3,5,10,20]) == 3`; `decrementIndex(1, ...) == 1` (clamps at floor); (6) increment from out-of-set: `incrementIndex(7, in: [1,2,3,5,10,20])` starts from `nearestStopIndex(7, ...) == 3` (value 5) and returns `10`; (7) `isIncrementEnabled(at: 10, in: [1,2,3,5,10,20]) == true`, `(at: 20, ...) == false`; `isDecrementEnabled(at: 1, ...) == false`, `(at: 2, ...) == true`; (8) `displayMaxRepetitions(1, capValue: 20) == "1"`; `(10, capValue: 20) == "10"`; `(20, capValue: 20) == "∞"`; (9) `accessibilityMaxRepetitions(5, capValue: 20)` starts with `"5"`; `accessibilityMaxRepetitions(20, capValue: 20, locale: en_US)` matches `"unlimited"` (token-presence assertion — bundle language not strictly assertable, see 81.1 Spec Change Log for the rationale). Tests use the static helpers directly — no SwiftUI view instantiation.
- `PeachTests/Settings/ContinuousValueSliderTests.swift` — **no change**. Unaffected by this story.
- `PeachTests/Settings/DisciplineSettingsSectionAggregationTests.swift` — **no change**. The aggregation contract (section IDs, order, dedupe) is unaffected by the body change inside the section.
- `PeachTests/Training/TimingOffsetDetection/AppTimingOffsetDetectionUserSettingsTests.swift` — **no change**. The read-time port behaviour and the clamp-at-`< 1` rule are unaffected.
- `PeachTests/Core/Training/TimingOffsetDetectionSettingsTests.swift` — **no change**. The settings value-type behaviour is unaffected.

## Tasks & Acceptance

**Execution:**
- [x] `Peach/Settings/DiscreteStopsSlider.swift` — create the new `View` with the chrome mirroring `ContinuousValueSlider`, the static index/clamp/enabled-state helpers, and the TOD-specific display/accessibility format helpers. Include the cross-reference doc comment pointing at the `ContinuousValueSlider` taxonomy table.
- [x] `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionMaxRepetitionsSettingsSection.swift` — replace the `Picker` body with `DiscreteStopsSlider`; remove the private `label(for:)` helper (its logic moves to `displayMaxRepetitions`); keep `Self.choices`, the section footer, and the `@AppStorage` declaration unchanged. Update the file's doc comment to mention the slider chrome instead of the picker.
- [x] `Peach/Resources/Localizable.xcstrings` — add the three new keys (`"Selects the next lower value"`, `"Selects the next higher value"`, `"unlimited"`) with their informal-`du` German translations via `bin/add-localization.swift --batch`.
- [x] `PeachTests/Settings/DiscreteStopsSliderTests.swift` — add the suite covering nearest-stop lookup (including out-of-set and tie-breaking), increment/decrement clamping at both ends (including from an out-of-set starting value), enabled-state predicates, display format including the `∞` boundary, and the accessibility-format token-presence assertion at the cap.
- [x] Run `bin/test.sh && bin/test.sh -p mac` — both platforms must pass. The `DiscreteStopsSliderTests` suite is gated on the same `PEACH_RESEARCH` flag as `AppTimingOffsetDetectionUserSettingsTests` if and only if the view itself is gated; spec assumes the view is *not* gated (it lives in `Peach/Settings/` next to `ContinuousValueSlider`, both in the always-compiled set) and only the call-site section `TimingOffsetDetectionMaxRepetitionsSettingsSection` is reachable when the discipline is registered (which is `PEACH_RESEARCH`-gated at the `DisciplineBootstrap.allDisciplines` level). Confirm the new view compiles in non-research configurations.
- [x] Run `bin/build.sh && bin/build.sh -p mac` — both platforms must build clean with no new warnings. Also verified `--research` builds clean on both platforms.
- [x] Run `bin/add-localization.swift --missing` — expect zero missing German translations after the batch add.

**Acceptance Criteria:**
- Given a `PEACH_RESEARCH` build with the Timing Offset Detection discipline registered, when the user opens Settings → Maximum Repetitions, then the row renders with the `DiscreteStopsSlider` chrome: label `"Maximum Repetitions"` on the left, the monospaced live value on the right, and a `−` button / slider / `+` button row below.
- Given the slider is at the rightmost stop, when the user looks at the right-side value, then it reads `"∞"`; the `+` button is disabled; the `−` button is enabled.
- Given the user taps `−` at the `∞` cap, when the tap registers, then the stored value becomes `10` (the previous stop in `[1, 2, 3, 5, 10, ∞]`), the display reads `"10"`, the `+` button becomes enabled, and the slider thumb moves one stop to the left.
- Given the user taps `+` until the value reaches `∞`, when the cap is reached, then the `+` button disables and further taps have no effect.
- Given the user drags the slider thumb from `∞` toward the left, when they release between two stops, then the slider snaps to the nearest stop and `UserDefaults.standard.integer(forKey: "timingOffsetDetectionMaxRepetitions")` equals the stop's storage value.
- Given the user looks at the slider track, when the screen is rendered, then six tick marks are visible at the six stop positions (equal visual spacing — the `1 → 2 → 3` and `5 → 10 → ∞` jumps look the same on screen, not proportionally spaced).
- Given the simulator language is German, when the row renders at the `∞` cap, then VoiceOver reads `"Maximale Wiederholungen, unbegrenzt"`; at `5` it reads `"Maximale Wiederholungen, 5"`; the `−` / `+` buttons read `"Verringere Maximale Wiederholungen"` / `"Erhöhe Maximale Wiederholungen"` with the discrete-stops hint phrasing.
- Given VoiceOver is active on iOS, when the user focuses the slider and swipes up, then the value advances to the next stop and VoiceOver announces the new value; swiping down at the floor (`1`) does not change the value.
- Given Switch Control is active, when the user reaches the slider element and triggers increment/decrement, then the value moves by one stop in the respective direction.
- Given the stored `@AppStorage` value is `7` (a non-stop integer), when the Settings screen renders, then the slider thumb is at the index of the nearest stop (`5`), the right-side display reads `"5"`, and the stored value `7` is not rewritten until the user interacts with the control.
- Given Dynamic Type is at AX1 or larger, when the Settings screen renders, then the row label and live value scale with the system font size, the `−` / `+` buttons retain a ≥ 44 × 44 pt tap target, and the layout does not clip.
- Given `bin/test.sh && bin/test.sh -p mac` runs, when both suites finish, then all tests pass on both iOS and macOS, including the new `DiscreteStopsSliderTests` and the unchanged `DisciplineSettingsSectionAggregationTests`, `AppTimingOffsetDetectionUserSettingsTests`, `ContinuousValueSliderTests`, and `TimingOffsetDetectionSettingsTests`.
- Given `bin/build.sh && bin/build.sh -p mac` runs, when both platforms build, then no new warnings are emitted in either configuration (`Debug` non-research and `Debug (Research)`).
- Given `bin/add-localization.swift --missing` runs, when it finishes, then it reports zero missing German translations for any of the new keys.

## Spec Change Log

- **2026-06-03** — Implementation deltas vs. Code Map:
  - **Tick-mark overlay uses absolute positioning, not `HStack { Rectangle; Spacer }`.** Code Map called for an `HStack` of `Rectangle`s separated by `Spacer`s, padded horizontally. Implementation uses a private `TickMarks` helper view with a `GeometryReader` + `ZStack(alignment: .leading)` and explicit `.offset(x:)` per tick (`thumbInset + stride * index`). The absolute-positioning shape is deterministic about where each tick lands; the `HStack`+`Spacer` shape spreads the marks but couples each mark's position to the `Rectangle` widths the `Spacer`s flex around, which makes the inset/padding interaction hard to reason about. Both produce equivalent visual output for fixed-width marks; absolute positioning is the cleaner expression of the intent.
  - **Tick overlay alignment is `.center`, not `.bottom`.** Code Map called for `.overlay(alignment: .bottom) { ... .offset(y: 4) }`. `Slider`'s frame on iOS extends to roughly the thumb height, so a `.bottom`-aligned overlay sits below the track, not on it. `.overlay(alignment: .center)` places the ticks at the track centre-line where they're visually associated with the slider position. The 1×6 pt marks read as small notches on the track; this matches the epic body's "tick marks at each stop" intent better than a separate row below.
  - **Tie-break test uses `[2, 8]`, not the spec example `[1, 10]` against value `5`.** Spec example was an arithmetic miscount: value `5` is closer to stop `1` (distance `4`) than to stop `10` (distance `5`), so it's not actually a tie. Replaced with `nearestStopIndex(to: 5, in: [2, 8])` where both distances are `3` — a real tie that exercises the documented "ties resolve to the higher index" behaviour.
  - **TOD section file's doc comment now references `DiscreteStopsSlider`.** The Code Map asked for this; recording the change explicitly so reviewers don't need to diff to confirm it happened.
  - **Increment/decrement helpers named `incrementValue`/`decrementValue`, not `incrementIndex`/`decrementIndex`.** Code Map listed `incrementIndex(_: Int, in: [Int]) -> Int`. The helpers return the *stop value at* the next/previous index, not the index itself, so the `Value` suffix is the accurate name. The Acceptance Auditor flagged the rename; keeping the more accurate name and recording it here rather than introducing a misleading `Index` suffix.
  - **Increase Contrast tick-mark fallback not implemented.** Spec listed this as an Ask-First: `.tertiary` may not provide enough delta against the slider track under Increase Contrast. Author shipped the default; no high-contrast branch. Acceptable for first cut per the Ask-First's "confirm default acceptable for first cut" option; revisit if a user reports the issue.
- **2026-06-03** — Step-4 review patches (Blind Hunter + Edge Case Hunter + Acceptance Auditor):
  - **Display readout and accessibility value now show the snapped stop, not the raw stored value.** Both reviewers flagged that the right-side `Text(displayFormat(value))` and `.accessibilityValue(Text(accessibilityFormat(value)))` were called on the raw `value` while the slider thumb is positioned via `nearestStopIndex`. For an out-of-set stored value (e.g. `7` against `[1,2,3,5,10,20]`), this produced a visible mismatch: thumb at stop `5` but display reading `"7"` — directly violating spec I/O matrix row "stored 7" ("display reads `\"5\"`") and AC #10. Fixed by computing `let snapped = stops.isEmpty ? value : stops[Self.nearestStopIndex(to: value, in: stops)]` at the top of `body` and passing `snapped` to both formatters. For in-set values this is a no-op; for out-of-set values it makes the readout, the thumb position, and the `+`/`−` behaviour mutually consistent (a `+` tap from displayed `5` now correctly goes to `10`, instead of from displayed `7` to `10` skipping `5` visually).
  - **`indexBinding.set` guards `stops.isEmpty`.** Sibling helpers (`nearestStopIndex`, `incrementValue`, `decrementValue`, `isIncrementEnabled`, `isDecrementEnabled`) all guard empty stops; `indexBinding.set` did not, leaving an asymmetric defensive posture (and an `Array.subscript` trap on `stops[0]` for the empty case). Added `guard !stops.isEmpty else { return }` for symmetry. Covered by new test `indexBindingSetNoOpForEmptyStops`.
  - **`indexBinding` round-trip coverage added.** Blind Hunter flagged that the most behaviour-critical adapter had no direct tests. Added seven tests covering: `get` on in-set value, `get` on out-of-set value, `set` with integer index, `set` rounding fractional indices both directions, `set` clamping over-cap and under-floor, and the empty-stops no-op. Uses a `Box` helper that materialises a `Binding<Int>` over local state so the static adapter is exercised end-to-end without instantiating a SwiftUI view.
  - **Rejected with reasoning (not patched, not deferred):**
    - Missing German for `"Decrease %@"` / `"Increase %@"` (Blind Hunter) — both keys already exist with German `"Verringere %@"` / `"Erhöhe %@"` from 81.1 (verified via `bin/add-localization.swift --list`). The interpolated row label `"Maximum Repetitions"` also has German (`"Maximale Wiederholungen"`). No gap.
    - `Text(label)` nested interpolation may not localise (Blind Hunter) — exact 81.1 pattern; works correctly in 81.1's production tests.
    - `displayMaxRepetitions` not locale-aware for digits (Blind Hunter) — matches 81.1 `displayTempo` (`"\(Int(value.rounded()))"`); `en` and `de` both use Arabic numerals; promoting to `value.formatted(.number.locale(...))` is a project-wide convention change, not in scope.
    - `"unlimited"` lowercase under `en_US` because no English entry (Blind Hunter + Edge Case Hunter) — matches the 81.1 vocabulary pattern (`"seconds"`, `"beats per minute"` — all lowercase noun phrases that read naturally mid-sentence as a VoiceOver value, not standalone). Adding capitalised `"Unlimited"` would diverge from the established convention.
    - Hard-coded `thumbInset: 12` doesn't scale with Dynamic Type / platform (Blind Hunter + Edge Case Hunter) — spec explicitly says "exact pixel alignment is intentionally not pursued"; tick marks read as visual cue, not registration marks. `@ScaledMetric` is a future-polish item.
    - Spec Change Log reference in code comment is a fragile pointer (Blind Hunter) — `docs/implementation-artifacts/spec-81-1-*.md` is a stable artifact in the repo; references to it are informative.
    - VoiceOver percentage announcement on slider (Edge Case Hunter) — setting `.accessibilityValue` on a `Slider` overrides the default percentage announcement entirely per Apple HIG; not a bug.
    - `count == 1` slider degeneracy + tick centre-vs-edge mismatch (Blind Hunter + Edge Case Hunter) — documented precondition "Must be sorted ascending. Precondition is not enforced at runtime — the single call site complies"; current and foreseeable callers all use ≥ 6 stops.
    - `TimingOffsetDetectionSettings.init` traps on `< 1` (Edge Case Hunter) — pre-existing trap; `AppTimingOffsetDetectionUserSettings` clamps `< 1` to default at read time, so no production caller can produce it. Out of scope for this story.
  - **Deferred (added to `deferred-work.md`):** `Int.max` (or any value > cap) flows through `AppTimingOffsetDetectionUserSettings.maxRepetitions` unchanged (the read-time clamp only handles `< 1`), and `nearestStopIndex` would trap on `abs(20 - Int.max)` underflow before snapping. Theoretical (would require a debugger write or corrupt UserDefaults), but a real crash path that the storage-layer defence doesn't cover from above. The clean fix is at the port (clamp above cap as well as below floor), not in the view.

## Design Notes

**Why a sibling `DiscreteStopsSlider` rather than a refactor of `ContinuousValueSlider`.** The two views share a *visual* idiom (label-row on top, button–slider–button below) but their internal mechanics diverge sharply: continuous binds a `BinaryFloatingPoint` value over a range; discrete binds an `Int` to an index into a non-uniform stops list via an internal `Binding<Double>` adapter. A shared base view would require introducing a third "chrome primitive" type that one is a thin wrapper over and the other adapts via an index adapter — two extra layers for a two-caller codebase. The two-sibling shape is the simpler design and matches the 81.1 spec's own guidance ("design with that reuse in mind … do not couple the chrome to the linear continuous case") by way of *not coupling* rather than via shared code. If a third discrete-stops Settings row ever appears, that story's retrospective is the right time to consider a shared chrome primitive.

**Why concretely typed on `Int` rather than `<Value: Hashable>`.** Genericity on `Hashable` would let any value type live in `stops`, but the nearest-stop fallback requires `Comparable`, and the only caller stores `Int`. Two additional type parameters and a `Comparable` bound buy nothing today. The 81.1 generic on `BinaryFloatingPoint` was justified by two callers immediately (Duration/Note-Gap as `Double`, Tempo as `Int → Double` adapter); here there is one. Promote on the second use.

**Why the slider is `Slider(value: Binding<Double>, in: 0...n-1, step: 1)` over the index.** It earns: (a) free snap-to-stop on drag-release via SwiftUI's built-in step behaviour, (b) the `adjustable` accessibility trait so VoiceOver swipe-up/down and Switch Control increment/decrement work without `.accessibilityRepresentation`, (c) the same drag-and-release UX as `ContinuousValueSlider`. A custom-drawn track would let us pixel-perfect-align the tick marks with the thumb stops, but at the cost of losing all three of those wins. Tick alignment is a visual polish item; accessibility is non-negotiable.

**Why a static `nearestStopIndex` rather than a runtime precondition on the stored value.** A precondition on render would crash the app for a debugger-write or a future-config artifact. A clamped-on-read normaliser inside `AppTimingOffsetDetectionUserSettings.maxRepetitions` would force the storage value to always be a stop value, but that file's contract is "clamp `< 1` to default" — it does not currently coerce to one of the stops, and broadening it would change a behaviour outside this story's scope. The view's nearest-stop fallback is a UI-side defence in depth: graceful display, no auto-rewrite, and the first user interaction normalises the value organically. This pattern matches the 81.1 design note "Out-of-range stored values are not normalised by the view."

**Why the `∞` glyph is a Unicode literal, not a localisation key.** `∞` is a mathematical symbol with the same form across locales; treating it as a localisable string would add a redundant German entry that translates to the identical character. The accessibility *vocabulary* at the cap (`"unlimited"` / `"unbegrenzt"`) does need translation — that is the one new xcstrings entry for the glyph case.

**Why the hint reads "Selects the next lower value" rather than 81.1's "Decreases by 0.1 s" pattern.** 81.1's hints communicate the magnitude of the change because the change *is* a fixed magnitude (the step). Here the step varies (1 → 2 is one repetition; 10 → ∞ is the cap leap). A magnitude hint would be wrong or misleading. The discrete-stops phrasing communicates the same affordance ("there is a next position; this button selects it") in a step-agnostic way.

**Why tick marks are an approximate `HStack { Rectangle; Spacer }` overlay rather than a `GeometryReader`-positioned set.** The system slider's thumb has an internal padding that is not part of the public SwiftUI API. A `GeometryReader` measuring the slider's frame and computing exact stop positions would still need to compensate for this private padding; the result would be marginally better alignment at the cost of a more fragile and platform-specific implementation. The `HStack { Rectangle; Spacer }` pattern padded to roughly the thumb-radius inset (≈ 12 pt) is close enough that the visual reading is "six stops", which is the requirement.

**Why we keep `private static let choices` in the section file rather than promoting it to `TimingOffsetDetectionSettingsKeys`.** The stops list `[1, 2, 3, 5, 10, defaultMaxRepetitions]` is a UI choice (which subset of the legal `≥ 1` domain we expose), not a storage-layer concern. The storage layer's contract is just "any `Int ≥ 1`". If a future story needs the same stops in a different view (unlikely), promotion is a small refactor; today it lives at its single point of use.

**`Section { ... } footer: { ... }` shape stays.** Both the section wrapper and the existing footer text are part of the `Form` aggregation contract, not part of the control idiom. The control swap is the slider chrome inside the section; nothing else changes.

## Verification

**Commands:**
- `bin/build.sh` — expected: clean iOS build, no new warnings.
- `bin/build.sh -p mac` — expected: clean macOS build, no new warnings.
- `bin/test.sh` — expected: all iOS tests pass; new `DiscreteStopsSliderTests` passes; `DisciplineSettingsSectionAggregationTests`, `AppTimingOffsetDetectionUserSettingsTests`, `ContinuousValueSliderTests`, `TimingOffsetDetectionSettingsTests` unchanged.
- `bin/test.sh -p mac` — expected: all macOS tests pass.
- `bin/add-localization.swift --missing` — expected: zero missing German translations after the batch add.

**Manual checks:**
- Build a `PEACH_RESEARCH` configuration (`Debug (Research)`), run the iOS simulator → open Settings → scroll to the TOD section → confirm Maximum Repetitions renders as a label/value/slider/buttons row (no Picker chevron), with `"∞"` shown at the right at first launch and the slider thumb at the rightmost position.
- Drag the slider thumb leftward → confirm it snaps to one of the six stops on release and the right-side value updates in monospaced digits.
- Tap `+` until the value reaches `∞` → confirm `+` becomes disabled (visibly greyed and not interactive); tap `−` from `∞` → confirm value goes to `10` and `+` re-enables.
- Confirm the section footer text is unchanged ("At ∞, the pattern keeps repeating until you submit a direction. Pick 1 to restore the single-pattern challenge.").
- Confirm six tick marks are visible at evenly spaced positions along the slider track.
- Switch the simulator language to German → confirm the row label reads `"Maximale Wiederholungen"`, the right-side value at the cap reads `"∞"`, and VoiceOver at the cap announces `"unbegrenzt"`.
- Turn on VoiceOver → focus the slider, confirm the announcement includes the row label and the formatted value with the `adjustable` trait; swipe-up to confirm one-stop advance; focus the `−` / `+` buttons and confirm parameterised labels and the discrete-stops hint phrasing.
- Bump Dynamic Type to AX1 → confirm the row label and live value scale, tap targets remain comfortable, and tick marks remain visible.
- (Optional) Manually set the `@AppStorage` value to `7` via the debugger or a launch argument, reopen Settings → confirm the slider thumb is at the index of stop `5`, display reads `"5"`, stored value remains `7` until the next user interaction.

## Suggested Review Order

**Entry point — the slider body**

- Start here: the snapped-value computation that keeps the right-side readout, the slider thumb, and the `+` / `−` button behaviour in lockstep even when the stored value isn't on a stop. Fixed in step-04 review.
  [`DiscreteStopsSlider.swift:30`](../../Peach/Settings/DiscreteStopsSlider.swift#L30)

**Discrete-stops mechanism**

- The internal `Binding<Double>` index adapter — the seam that lets a SwiftUI `Slider(step: 1)` give us snap-to-stop and the `adjustable` accessibility trait for free, while the outer API stores the actual stop value as `Int`.
  [`DiscreteStopsSlider.swift:83`](../../Peach/Settings/DiscreteStopsSlider.swift#L83)

- Nearest-stop fallback: graceful UI for out-of-set stored values without rewriting storage on render. Tie-break resolves to the higher index — pinned by the `[2, 8]` against value `5` test.
  [`DiscreteStopsSlider.swift:97`](../../Peach/Settings/DiscreteStopsSlider.swift#L97)

- `incrementValue` / `decrementValue` anchor at the nearest stop's index and step from there, so `+` and `−` work coherently from in-set and out-of-set values alike.
  [`DiscreteStopsSlider.swift:111`](../../Peach/Settings/DiscreteStopsSlider.swift#L111)

- Slider call: index range `0...(stops.count - 1)`, step `1`. The `.accessibilityValue` override replaces the system's default "X percent" announcement with the formatted stop value.
  [`DiscreteStopsSlider.swift:53`](../../Peach/Settings/DiscreteStopsSlider.swift#L53)

**Visual chrome (sibling of 81.1, intentionally not refactored into a shared base)**

- Label-row hides the visual `Text` from VoiceOver so the system slider's own label closure is the single source of truth — matches the 81.1 pattern.
  [`DiscreteStopsSlider.swift:33`](../../Peach/Settings/DiscreteStopsSlider.swift#L33)

- Tick-mark overlay: 1×6 pt `Rectangle`s positioned via `GeometryReader` + explicit `.offset(x:)` with a `thumbInset` of 12 pt to approximate the system slider's thumb-radius inset. Pixel alignment is intentionally approximate.
  [`DiscreteStopsSlider.swift:160`](../../Peach/Settings/DiscreteStopsSlider.swift#L160)

- 44 × 44 pt tap-target frame on the `−` / `+` Image — required by FR38, matching the 81.1 step-04 fix.
  [`DiscreteStopsSlider.swift:46`](../../Peach/Settings/DiscreteStopsSlider.swift#L46)

- Parameterised accessibility labels reuse the 81.1 `"Decrease %@"` / `"Increase %@"` keys; hints are step-agnostic (`"Selects the next lower / higher value"`) because per-step magnitudes vary across the non-uniform stops list.
  [`DiscreteStopsSlider.swift:50`](../../Peach/Settings/DiscreteStopsSlider.swift#L50)

**Format helpers**

- `displayMaxRepetitions`: digits below the cap, the `∞` Unicode literal at the cap. No xcstrings entry for the glyph — locale-independent.
  [`DiscreteStopsSlider.swift:137`](../../Peach/Settings/DiscreteStopsSlider.swift#L137)

- `accessibilityMaxRepetitions`: digit string for integer stops; the localised `"unlimited"` / `"unbegrenzt"` vocabulary at the cap. Matches the 81.1 lowercase-noun-phrase convention (`"seconds"`, `"beats per minute"`).
  [`DiscreteStopsSlider.swift:146`](../../Peach/Settings/DiscreteStopsSlider.swift#L146)

**Migration call site**

- The `Section { ... } footer: { ... }` shell, the `@AppStorage` declaration, the `Self.choices` array, and the footer copy all stay; only the body inside `Section` swaps from `Picker` to `DiscreteStopsSlider`.
  [`TimingOffsetDetectionMaxRepetitionsSettingsSection.swift:20`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionMaxRepetitionsSettingsSection.swift#L20)

**Localisation contract**

- Three new `Localizable.xcstrings` keys with informal-`du` German translations: `"Selects the next lower value"` / `"Wählt den nächst niedrigeren Wert"`, `"Selects the next higher value"` / `"Wählt den nächst höheren Wert"`, `"unlimited"` / `"unbegrenzt"`. Existing keys reused: row label, `−` / `+` parameterised labels, footer, help-section body.
  [`Localizable.xcstrings`](../../Peach/Resources/Localizable.xcstrings)

**Tests — pin the static helpers**

- Nearest-stop lookup at every meaningful position: exact-match, closer-to-lower, closer-to-upper, real-tie tie-break (resolves to higher index), below-floor, above-cap.
  [`DiscreteStopsSliderTests.swift:13`](../../PeachTests/Settings/DiscreteStopsSliderTests.swift#L13)

- Increment / decrement: from an in-set value (steps to the adjacent stop), from an out-of-set value (anchors at the nearest stop's index, then steps), clamping at both ends.
  [`DiscreteStopsSliderTests.swift:37`](../../PeachTests/Settings/DiscreteStopsSliderTests.swift#L37)

- Display / accessibility format: digits below the cap, `∞` glyph in display, `"unlimited"`/`"unbegrenzt"` token in accessibility — including the cap boundary.
  [`DiscreteStopsSliderTests.swift:87`](../../PeachTests/Settings/DiscreteStopsSliderTests.swift#L87)

- `indexBinding` round-trip — the most behaviour-critical adapter, added in step-04 review. Materialises a `Binding<Int>` over a local `Box` so the static adapter is exercised end-to-end without instantiating a SwiftUI view. Pins: get for in-set / out-of-set values; set with integer / fractional / over-cap / under-floor / empty-stops inputs.
  [`DiscreteStopsSliderTests.swift:113`](../../PeachTests/Settings/DiscreteStopsSliderTests.swift#L113)

**Audit trail**

- Spec Change Log captures: four Code-Map deltas (tick-overlay shape and alignment, the corrected tie-break test, the `Value`-suffixed helper names, and the deferred Increase Contrast Ask-First), three step-04 patches (display/accessibility uses the snapped value, `indexBinding.set` guards empty stops, `indexBinding` round-trip coverage), nine rejected-with-reasoning findings, and the one deferred port-clamp gap.
  [`spec-81-2-tod-max-repetitions-discrete-stops-slider.md`](./spec-81-2-tod-max-repetitions-discrete-stops-slider.md)
