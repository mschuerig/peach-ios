---
title: 'Story 80.3: Settings UI contribution + localization'
type: 'feature'
created: '2026-06-02'
status: 'done'
baseline_commit: 'bb82932d'
context:
  - '{project-root}/docs/implementation-artifacts/epic-80-context.md'
  - '{project-root}/docs/implementation-artifacts/spec-80-2-max-repetitions-setting.md'
  - '{project-root}/docs/project-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Story 80.2 plumbed `maxRepetitions` end-to-end through the TOD feature-local port and session, but the setting is invisible to users — the only way to change it today is to poke `UserDefaults` from the debugger. Users who want to opt into a finite-exposure constraint (e.g., `1` to restore the pre-80.1 one-shot semantics) have no way to do so from the app.

**Approach:** Add a TOD-specific Settings section, contributed by `TimingOffsetDetectionDiscipline` via `TrainingDisciplineUI.settingsSections` (the Epic 77 plugin model), that lets the user pick `maxRepetitions` from a curated set of discrete values. The high-end value (the existing `defaultMaxRepetitions = 20`) is labeled **∞** in the UI — meaning "the pattern keeps repeating until you submit a direction" — since 20 cycles at 80–100 BPM is functionally "loop until you decide" already. English and German strings (German informal `du`) are added to `Localizable.xcstrings`. A new `TimingOffsetDetectionHelp.maxRepetitionsSettingsHelp` section is appended to the discipline's `settingsHelp` so the Help sheet documents the setting alongside the existing shared-tempo help.

## Boundaries & Constraints

**Always:**
- Settings UI is contributed by the discipline via `TrainingDisciplineUI.settingsSections`. Do not add a switch arm or any TOD-specific code to `SettingsScreen.swift`. The aggregator (`DisciplineSettingsSection.aggregated(from:)`) already dedupes by section `id`.
- Section `id` is `"tod.maxRepetitions"` — TOD-namespaced, distinct from `SharedRhythmSectionID.tempo`. Declared as an inline string in `TimingOffsetDetectionDiscipline.settingsSections` (single constant; no feature-local enum yet, matching how `RhythmGapPositionsSettingsSection` is referenced).
- New section view file lives under `Peach/Training/TimingOffsetDetection/Settings/`, mirroring CRM's `Peach/Training/ContinuousRhythmMatching/Settings/`.
- The Picker is bound to the existing `@AppStorage(TimingOffsetDetectionSettingsKeys.maxRepetitions)` key with default `TimingOffsetDetectionSettingsKeys.defaultMaxRepetitions`. The same key the port reads from in `AppTimingOffsetDetectionUserSettings` — single source of truth, no parallel storage.
- Picker offerings are the explicit, fixed set `[1, 2, 3, 5, 10, 20]`. The value `20` (the existing `defaultMaxRepetitions`) is rendered as `"∞"`; all others render as their integer. The set is hard-coded in the view, not read from configuration.
- New strings added to `Localizable.xcstrings` via `bin/add-localization.swift`. Both English and German required before merging. German uses informal `du` / imperative form per project convention.
- Discipline stays research-only. The new view file compiles unconditionally (no `#if`), but it is only reachable through `TimingOffsetDetectionDiscipline`'s `settingsSections`, and the discipline itself is registered only inside `#if PEACH_RESEARCH` in `DisciplineBootstrap`. Same gating story as 80.2.
- Help section coverage. `TimingOffsetDetectionDiscipline.settingsHelp` is extended to concatenate `ContinuousRhythmMatchingHelp.tempoSettingsHelp + TimingOffsetDetectionHelp.maxRepetitionsSettingsHelp` so the Help sheet documents the new setting alongside the inherited tempo help.

**Ask First:**
- ∞ ⇔ `20` (Approach A) vs. ∞ ⇔ `Int.max` (Approach B). Spec assumes A: the existing `defaultMaxRepetitions = 20` is the value that renders as ∞, no sentinel needed, no model change. The 80.2 I/O matrix explicitly tested `maxRepetitions == .max` as "cap never fires", so B is feasible — but it would introduce a sentinel into the data model with no clear second use case. Confirm A or override to B before approval.
- Picker value set `[1, 2, 3, 5, 10, 20]`. Confirm or amend (e.g., add `4`, drop `10`). The set must include `1` (test-purity restore), the default (`20`), and a small ladder in between.
- Picker vs. Stepper. Spec assumes Picker because the offerings are discrete and non-equispaced (1→2→3→5→10→20); a Stepper would force either uniform `+1` steps (annoying past `5`) or non-uniform stepping with hidden values. Confirm Picker or override to Stepper.

**Never:**
- Do not change `TimingOffsetDetectionSettingsKeys` (key name, default value, or storage type). 80.2 froze the contract; the view binds to the existing key.
- Do not introduce `Int.max` (or any sentinel) as a picker value unless the "Ask First" item flips to Approach B. Under Approach A the picker's max is the literal `20`.
- Do not touch `SettingsScreen.swift`, `SharedRhythmSectionID.swift`, `RhythmTempoSettingsSection.swift`, or any CRM file. This story is additive to TOD's discipline contribution only.
- Do not change `TimingOffsetDetectionUserSettings`, `AppTimingOffsetDetectionUserSettings`, `TimingOffsetDetectionSettings`, or the session/reducer state machine. Story 80.2 owns those.
- Do not add training-screen visual treatment, dot-view changes, or training-screen help text for the loop-until-decision mechanic — that is 80.4.
- Do not introduce snapshot testing or a SwiftUI view test framework. The view is thin; coverage stays at the discipline-contribution level.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Fresh install (no stored value) | Picker appears; `UserDefaults` has no entry for `timingOffsetDetectionMaxRepetitions` | Picker selection = `20`, rendered as `"∞"` (matches `defaultMaxRepetitions`) | N/A |
| User picks `1` | Picker tap on `"1"` row | `UserDefaults` updates to `1`; subsequent TOD trial starts with `maxRepetitions = 1` (cap fires after one full cycle, per 80.2 AC) | N/A |
| User picks `"∞"` | Picker tap on `"∞"` row | `UserDefaults` updates to `20`; subsequent TOD trial loops until user answers or 20 cycles elapse | N/A |
| `UserDefaults` contains an off-list value (e.g., stored `7` from debugger) | Settings screen opens | Picker shows no selection highlighted (SwiftUI default for unmatched tag); user can re-select; underlying value remains `7` until they pick. Port still returns `7` because `7 >= 1` — runtime behavior is unaffected. | N/A — out-of-set values are tolerated; SwiftUI does not crash on a Picker with no matching tag |
| `UserDefaults` contains `0` / negative / missing | Settings screen opens | Picker selection = `20` (the `@AppStorage` default applies on absent value; for stored `0` / negative, the Picker shows nothing selected but the port returns the default at session start, mirroring the defence-in-depth from 80.2) | N/A |
| Discipline not registered (non-research build) | App launched in `Debug` or `Release` without `PEACH_RESEARCH` | `TimingOffsetDetectionDiscipline` is absent from `TrainingDisciplineRegistry.shared.all`; the new section never appears in `SettingsScreen` because `allUI` does not yield it | N/A |
| Both rhythm disciplines registered | Research build, TOD + CRM both in registry | TOD's TOD-specific section renders exactly once. The shared `rhythm.tempo` section still renders exactly once (deduped by `id` by `DisciplineSettingsSection.aggregated`, unchanged from today) | N/A |

</frozen-after-approval>

## Code Map

- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionMaxRepetitionsSettingsSection.swift` — **new**. SwiftUI `View` returning a `Section` with a `Picker("Maximum repetitions", selection: $maxRepetitions)` bound to `@AppStorage(TimingOffsetDetectionSettingsKeys.maxRepetitions)` defaulted to `TimingOffsetDetectionSettingsKeys.defaultMaxRepetitions`. Picker iterates a private `static let choices: [Int] = [1, 2, 3, 5, 10, 20]`; the row for `20` shows `Text("∞")`, others show `Text("\(value)")`. A `footer` explains the ∞ semantics ("At ∞, the pattern keeps repeating until you submit a direction"). All user-facing strings via `String(localized:)`.
- `Peach/Training/TimingOffsetDetection/Discipline/TimingOffsetDetectionDiscipline.swift` — **edit**. Extend `settingsSections` to append `DisciplineSettingsSection(id: "tod.maxRepetitions") { TimingOffsetDetectionMaxRepetitionsSettingsSection() }` after the shared tempo section. Extend `settingsHelp` to `ContinuousRhythmMatchingHelp.tempoSettingsHelp + TimingOffsetDetectionHelp.maxRepetitionsSettingsHelp`.
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionHelp.swift` — **edit**. Add `static let maxRepetitionsSettingsHelp: [HelpSection]` describing what the setting does, what ∞ means, and the recommended values (`1` for test purity, `∞` for the default loop-until-decision experience). Mirror the style of `ContinuousRhythmMatchingHelp.tempoSettingsHelp`.
- `Peach/Resources/Localizable.xcstrings` — **edit** (via `bin/add-localization.swift`). New English keys: the picker label, the ∞ symbol's accessibility value, the section header/footer, and each help heading + body. German translations for all, informal `du` / imperative.
- `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionDisciplineTests.swift` — **new or extend** (check whether file exists; if not, create following the pattern of `ContinuousRhythmMatchingDisciplineTests.swift` if that exists, otherwise create a minimal file). Two `@Test`s: (1) `settingsSections` contains exactly two entries with the expected `id`s in order (`SharedRhythmSectionID.tempo`, `"tod.maxRepetitions"`); (2) `settingsHelp` is non-empty and contains both the tempo help and the new max-repetitions help (assert by first/last `HelpSection.heading` since contents are localized).

## Tasks & Acceptance

**Execution:**
- [x] `Peach/Training/TimingOffsetDetection/Help/TimingOffsetDetectionHelp.swift` — add `maxRepetitionsSettingsHelp` static property with English source strings.
- [x] `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionMaxRepetitionsSettingsSection.swift` — create the section view per Code Map.
- [x] `Peach/Training/TimingOffsetDetection/Discipline/TimingOffsetDetectionDiscipline.swift` — append the new section to `settingsSections`; extend `settingsHelp` to include the new help.
- [x] `Peach/Resources/Localizable.xcstrings` — add English + German entries via `bin/add-localization.swift --batch`. German strings use informal `du` / imperative.
- [x] `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionDisciplineTests.swift` — add/extend with the two assertions above.
- [x] Run the I/O matrix coverage: build + full test suite on iOS and macOS; manual visual check of the Settings screen in a Research-configuration simulator run.

**Acceptance Criteria:**
- Given a Research build with a fresh install, when the user opens the Settings screen, then a "Maximum repetitions" picker is visible under the rhythm sections with selection `∞` (value `20`).
- Given the Settings screen is open, when the user taps `1` in the picker, then `UserDefaults.standard.integer(forKey: "timingOffsetDetectionMaxRepetitions") == 1` immediately and a subsequent TOD trial caps after exactly one full cycle per the 80.2 AC.
- Given the Settings screen is open, when the user taps `∞`, then `UserDefaults.standard.integer(forKey: "timingOffsetDetectionMaxRepetitions") == 20` and a subsequent TOD trial loops until the user answers (or 20 cycles, which is the soft cap).
- Given a non-research build (`Debug` or `Release` without `PEACH_RESEARCH`), when the Settings screen is rendered, then no "Maximum repetitions" picker appears (the discipline is not registered).
- Given the Help sheet is opened from the Settings screen, when the user scrolls to the rhythm help, then a section describing the maximum-repetitions setting (including the ∞ semantics) is visible.
- Given `bin/test.sh && bin/test.sh -p mac` runs, when both suites finish, then all tests pass on both iOS and macOS.
- Given `bin/build.sh && bin/build.sh -p mac` runs, when both build, then no new warnings are emitted on either platform.
- Given the German app locale is selected, when the Settings screen renders, then the new section's header, footer, and picker label are localized using informal `du` / imperative form (no formal `Sie`).

## Spec Change Log

- **2026-06-02** — Implementation deltas vs. Code Map:
  - **Help file path correction.** The Code Map listed `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionHelp.swift`; the actual file lives at `Peach/Training/TimingOffsetDetection/Help/TimingOffsetDetectionHelp.swift` (matching the CRM `Help/` subdirectory pattern). Edit landed at the correct path; task list updated.
  - **Boy Scout fix included in localization batch.** While running `bin/add-localization.swift --missing` to verify the new keys, found two pre-existing missing German translations not in `docs/pre-existing-findings.md`: `"Play Preview"` → `"Vorschau abspielen"` and `"Stop Preview"` → `"Vorschau stoppen"`. Added inline per the project's mandatory Boy Scout Rule rather than deferring (each entry is one informal-imperative noun phrase, no judgement calls). `bin/add-localization.swift --missing` now reports zero missing translations.
  - **Test verification used `--research` config.** `bin/test.sh` defaults to the non-research `Peach (Debug)` scheme where `#if PEACH_RESEARCH` test files (including the new `TimingOffsetDetectionDisciplineTests`) do not compile. Both new tests were confirmed running under `bin/test.sh --research` and `bin/test.sh --research -p mac`. The non-research default test runs still pass (1458 iOS, 1452 macOS) and the non-research builds compile clean — proving AC4 by code structure (discipline not registered in `DisciplineBootstrap`).
- **2026-06-02** — Step-04 review patches:
  - **Doubled `"Maximum Repetitions"` label removed.** Edge-case-hunter review flagged that the Section's explicit `header: { Text("Maximum Repetitions") }` and the inline `Picker("Maximum Repetitions", ...)` row label rendered the same text twice in the Form on iOS (once as the uppercase section header, once inline above the chosen value). CRM's two settings sections avoid this by either omitting the inline picker label (gap-positions uses a header + grid widget with no inner label) or using distinct strings (tempo's section header is the *category* `"Rhythm"`, the inline label is `"Tempo: \(value) BPM"`). Fix: drop the explicit `header:` block from `TimingOffsetDetectionMaxRepetitionsSettingsSection`. The picker remains self-labeling via its `"Maximum Repetitions"` title; the `footer:` is unchanged. No localization keys removed (the header text reused the same `"Maximum Repetitions"` key used by the picker label and the help title). All four test runs re-verified post-patch (1458 / 1830 iOS, 1452 / 1824 macOS).
  - **Rejected with reasoning (not deferred or patched):** ∞ ⇔ `defaultMaxRepetitions` coupling and potential `choices` collision if the default ever changes (Blind#1/2, Edge#3/4) — explicitly chosen in the spec's "Ask First" Approach A; the constant is hard-coded as the spec required. Stale-`UserDefaults` value tolerance (Edge#1) — explicitly documented in the spec's I/O matrix and Design Notes as intentional non-normalization. "Pick 1 to restore the single-pattern challenge" copy (Blind#3) — historically accurate (pre-80.1 TOD was a single pattern). Test gated on `PEACH_RESEARCH` (Blind#4) — correct mirroring of the discipline's research-only gating. Literal `"tod.maxRepetitions"` string in the test (Blind#5) — spec required the id to be an inline string, so the test pinning the same literal is intentional contract enforcement. `settingsHelp` test compares titles not bodies (Blind#6) — structural check is what the spec required. Localization `comment` / `extractionState` fields missing (Blind#7/9) — Xcode's auto-extractor handles these on next build for `String(localized:)` source strings. Footer/help near-duplicates (Blind#8) — intentional UX split between at-a-glance footer and longer Help-sheet body. Sprint-status `in-progress` vs `done` (Blind#10) — workflow state, advances at step-05. `"∞"` glyph not localized + VoiceOver reading (Edge#5/6) — universal mathematical symbol; "Maximum Repetitions, infinity" is a meaningful VoiceOver reading. Stale-value test gap (Edge#7) — port behavior already covered by `AppTimingOffsetDetectionUserSettingsTests.validValueIsReturned`; "no selection" rendering is a SwiftUI default; spec excludes view-snapshot tests. CRM cross-feature help coupling (Edge#8) — pre-existing intentional design, documented in the discipline's doc comment.

## Design Notes

**Why Approach A (∞ ⇔ `20`).** The 80.2 epic context says "Factory default for `maxRepetitions` is high (effectively 'loop until decision')". 20 cycles at the 4-sixteenth pattern at 80–100 BPM is ≈ 12–15 seconds — well past the realistic decision window for direction-judgement (typically 1–3 seconds). The user is virtually never going to hit the cap at 20 in normal use, so labeling 20 as ∞ in the UI is honest. Introducing an `Int.max` sentinel would force a parallel-state representation (Int storage with sentinel meaning) without buying any user-visible behavior beyond what 20 already provides. Approach B remains technically possible (80.2's I/O matrix proved it) and is the "Ask First" escape if Michael wants a literal "never auto-stops" option.

**Off-list `UserDefaults` values are tolerated, not normalized.** If a user (or a future migration glitch) writes `7` to the key, the port still returns `7` (defence-in-depth from 80.2 only clamps `< 1`), the cap fires after 7 cycles, and the Settings picker shows nothing selected. We do not snap to the nearest list value because that would (a) hide the discrepancy from the user and (b) overwrite a value the user might have set intentionally via the debugger. SwiftUI Pickers tolerate an unmatched selection tag by rendering no row as selected — no crash.

**No view-snapshot tests.** The view is thin (binds an `@AppStorage` Int to a Picker over a hard-coded array). The interesting state — picker → UserDefaults → port → session — is already covered by the existing `AppTimingOffsetDetectionUserSettingsTests` and `TimingOffsetDetectionSessionTests`. The new discipline test only verifies that the section is *contributed* (id + count), not how it renders.

**Help text scope split with 80.4.** This story adds the *settings* help section (what the setting means, what values mean). Story 80.4 owns the *training-screen* help update (the loop-until-decision mechanic). Splitting along the same Settings-vs-Training boundary as the visible UI keeps each story self-contained.

## Verification

**Commands:**
- `bin/build.sh` — expected: clean iOS build, no new warnings.
- `bin/build.sh -p mac` — expected: clean macOS build, no new warnings.
- `bin/test.sh` — expected: all iOS tests pass; new discipline test passes.
- `bin/test.sh -p mac` — expected: all macOS tests pass.
- `bin/add-localization.swift --missing` — expected: no missing German translations for any of the new keys after the batch add.

**Manual checks:**
- Run a Research build on the iOS simulator → open Settings → confirm the "Maximum repetitions" section appears below the shared Rhythm tempo section, with the picker defaulting to `∞`. Tap `1`, start a TOD trial, confirm the cap behavior. Tap `∞`, start a TOD trial, confirm it loops past 1 cycle.
- Switch the simulator language to German → confirm the section header, picker label, and footer use informal `du` / imperative.
- Run a non-research build (`Debug`) → confirm no TOD settings section appears.

## Suggested Review Order

**Plugin contribution — the only edit that wires the new section into the Settings screen**

- New `"tod.maxRepetitions"` section appended to TOD's `settingsSections`; section id is TOD-namespaced so dedup never collides with the shared `rhythm.tempo` section.
  [`TimingOffsetDetectionDiscipline.swift:50`](../../Peach/Training/TimingOffsetDetection/Discipline/TimingOffsetDetectionDiscipline.swift#L50)

- `settingsHelp` concatenates inherited tempo help + new max-repetitions help so each contributed section has documentation.
  [`TimingOffsetDetectionDiscipline.swift:61`](../../Peach/Training/TimingOffsetDetection/Discipline/TimingOffsetDetectionDiscipline.swift#L61)

**Picker view — the actual UI surface**

- `@AppStorage` bound to the same key `AppTimingOffsetDetectionUserSettings` reads from — single source of truth, no parallel storage. Default = `TimingOffsetDetectionSettingsKeys.defaultMaxRepetitions` (= 20) for fresh installs.
  [`TimingOffsetDetectionMaxRepetitionsSettingsSection.swift:13`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionMaxRepetitionsSettingsSection.swift#L13)

- Hard-coded `choices` array with the high value referenced via the constant, keeping the "∞ ⇔ default" invariant in one place.
  [`TimingOffsetDetectionMaxRepetitionsSettingsSection.swift:16`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionMaxRepetitionsSettingsSection.swift#L16)

- `label(for:)` swaps the integer for `"∞"` at the high end. Step-04 patch dropped the explicit section `header:` to remove the doubled `"Maximum Repetitions"` label seen on iOS Form rows.
  [`TimingOffsetDetectionMaxRepetitionsSettingsSection.swift:30`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionMaxRepetitionsSettingsSection.swift#L30)

**Help text — Settings help-sheet entry**

- New `maxRepetitionsSettingsHelp` describing what the cap means and what the ∞ / 1 endpoints buy the user.
  [`TimingOffsetDetectionHelp.swift:28`](../../Peach/Training/TimingOffsetDetection/Help/TimingOffsetDetectionHelp.swift#L28)

**Tests — contract pinning at the discipline-contribution level**

- Pins the section-id contract: tempo first, TOD-namespaced section second. Asserts the literal `"tod.maxRepetitions"` to match the production inline string.
  [`TimingOffsetDetectionDisciplineTests.swift:9`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionDisciplineTests.swift#L9)

- Pins `settingsHelp` concatenation order + count without comparing localized bodies.
  [`TimingOffsetDetectionDisciplineTests.swift:18`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionDisciplineTests.swift#L18)

**Audit trail**

- Spec Change Log — implementation deltas + step-04 review patch (doubled-label fix) + rejected-with-reasoning bucket.
  [`spec-80-3-settings-ui-contribution-and-localization.md`](./spec-80-3-settings-ui-contribution-and-localization.md)
