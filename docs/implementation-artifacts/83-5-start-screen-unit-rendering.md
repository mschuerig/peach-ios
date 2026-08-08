---
title: 'Story 83.5: Render each discipline''s own unit on the Start screen'
type: 'bug'
created: '2026-08-08'
status: 'done'
baseline_commit: 5f197110ce6663cdcf69db345fe98055e0584b95
context:
  - '{project-root}/docs/planning-artifacts/epics.md'
  - '{project-root}/docs/implementation-artifacts/83-3-submit-next-app-store-cut.md'
  - '{project-root}/docs/planning-artifacts/tod-discipline-future-direction.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The Start screen rendered `80.5 ¢` on the Compare Timing card. Timing Offset Detection measures **milliseconds** — story 83.2 settled that deliberately, after a domain consultation, and `TimingOffsetDetectionDiscipline` declares `unitLabel: "ms"` accordingly. `ProgressSparklineView.formatCompactEWMA` hardcoded the cent glyph and ignored the `unitLabel` the view was already being handed, so VoiceOver announced the correct unit while sighted users read the wrong one. The same function formatted millisecond values through `Cents(_:)` — the domain-type misuse `project-context.md` forbids outright.

Found while preparing story 83.3's screenshots. Without this fix the App Store screenshot for 1.1.0 would have advertised the release's headline feature with the wrong unit, and the shipping binary would have carried the defect regardless of screenshots.

**Approach:** Give `TrainingDisciplineConfig` a second unit field. `unitLabel` stays the spoken/axis form (`"cents"`, `"milliseconds"` — see Spec Change Log #3), used by VoiceOver and chart axes; a new `unitSymbol` carries the compact form (`"¢"`, `"ms"`) rendered next to a number in the Start cards. Every discipline declares both. Replace the `Cents(_:)` wrapping in the shared progress surfaces with a neutral `MetricValueFormatter`, and have `Cents.formatted()` delegate to it so cent formatting is bit-for-bit unchanged.

Two further items were folded in under the same root cause — pitch-specific assumptions baked into surfaces every discipline shares — and are **ratified as in scope** *(2026-08-08, Michael's instruction; see Spec Change Log)*: `ChartData`'s chart-annotation accessibility strings, which called the trend a "pitch trend" for whichever discipline reached them (in practice only the pitch disciplines, since both rhythm disciplines override `profileCard` — so this was a latent wording defect, not a live one); and the rhythm disciplines' spoken unit, which shared the compact `"ms"` key and so could not be spelled out for VoiceOver.

**Why a second field rather than reusing `unitLabel`:** substituting `unitLabel` into the card would render `11.5 cents` on the four pitch cards, replacing a deliberately compact glyph with a word in a tight layout. Michael chose the added field over that regression.

## Boundaries & Constraints

**Always:**
- On surfaces shared by more than one discipline — the Start cards and the profile charts — the unit rendered comes from the discipline's config. No *shared* view hardcodes a unit. Views scoped to a single training *category* may hold their unit literally, since every discipline rendering them measures the same quantity: `PitchMatchingFeedbackIndicator` and `TrainingStatsView` (pitch only, though each serves more than one discipline — `TrainingStatsView` serves all four), `RhythmTimingFeedbackIndicator` and `TimingStatsView` (rhythm only), `ChromaticTrialResultView` (Chromatic Construction only). All are correct today and this story does not change them. *(An earlier wording said "only one discipline ever renders them", which was false for `TrainingStatsView` and `PitchMatchingFeedbackIndicator`.)* *(Narrowed 2026-08-08 on Michael's instruction — the original unconditional wording was false as written; see Spec Change Log.)*
- `unitLabel` is always spelled out and always differs from `unitSymbol`, so VoiceOver reads a word rather than letters.
- `unitLabel` and `unitSymbol` are both localized, consistent with the existing `unitLabel` idiom.
- All four schemes green before commit, run sequentially per [[feedback_test_sh_no_parallel]]; `bin/add-localization.swift --missing` reports `0`.
- Separate commit from story 83.3, per that story's frozen block: *"If the audits or the gate expose a real defect, that is a separate story against a separate commit."*
- Visual confirmation in a running non-Research build before the story closes, per [[feedback_verify_visual_features]].

**Never:**
- No change to what the pitch cards render. `11.5 ¢` before, `11.5 ¢` after.
- No change to the numeric formatting of any value — `MetricValueFormatter` reproduces the previous `NumberFormatter` configuration exactly (decimal, 1 fraction digit).
- No change to stored records, CSV columns, or the profile's statistical model. This is a rendering fix.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior |
|---|---|---|
| Pitch discipline card | `unitSymbol: "¢"`, ewma 11.5 | `11.5 ¢` — unchanged from before the fix |
| Timing discipline card | `unitSymbol: "ms"`, ewma 79.5 | `79.5 ms`; never contains `¢` |
| VoiceOver, timing card | `unitLabel: "milliseconds"` | card speaks its discipline name as label and the value + spelled-out unit + trend as value |
| Chart Y axis | `unitLabel` | pitch axes read "cents" — unchanged. Rhythm disciplines render a tempo/quality heatmap (`RhythmProfileCardView`), not `ProgressChartView`, so they have no `unitLabel` axis and are unaffected. |
| New discipline added | any | registry tests fail if it declares a unit inconsistent with its category, a blank unit, or the same string for both unit forms |
| Non-English locale | German | decimal separator is locale-driven; the unit is not |

</frozen-after-approval>

## Code Map

- `Peach/Core/Training/TrainingDisciplineConfig.swift` — new `unitSymbol` field, documented against `unitLabel`.
- Seven discipline definitions — each declares `unitSymbol`: `¢` for the four pitch disciplines and Chromatic Construction, `ms` for Timing Offset Detection and Continuous Rhythm Matching.
- `Peach/Core/Profile/MetricValueFormatter.swift` — **added.** Discipline-agnostic numeric formatter; the unit is never assumed here. Tracks `Locale.autoupdatingCurrent` so a Region change while the app is resident is picked up.
- `Peach/Start/ProgressSparklineView.swift` — `formatCompactEWMA(_:unitSymbol:)`; both paths drop `Cents(_:)`. Takes the whole `TrainingDisciplineConfig` rather than two undistinguished `String`s, so the unit pair cannot be transposed at the call site. Accessibility moved to `sparklineAccessibilityValue(ewma:trend:unitLabel:) -> String?`; the view itself is `.accessibilityHidden(true)`.
- `Peach/Start/StartScreen.swift` — passes `config`; composes the card's accessibility element (label = discipline name, value = measurement + trend) and no longer overrides the label on the `NavigationLink`.
- `Peach/App/CentsFormatting.swift` — `Cents.formatted()` delegates to `MetricValueFormatter`.
- `Peach/Core/Profile/ChartData.swift` — `formatEWMA` / `formatStdDev` use the neutral formatter; the two chart-annotation accessibility strings say "trend", not "pitch trend".
- `Peach/Resources/Localizable.xcstrings` — three keys added with German values and translator comments (the `¢` comment states explicitly that it is the musical cent, not a currency).
- `PeachTests/Core/Profile/MetricValueFormatterTests.swift` — **added.** Covers fraction-digit contract, zero, rounding, unit-agnosticism, and `Cents.formatted()` delegation.

## Tasks & Acceptance

- [x] **Task 1 — Red.** Update `ProgressSparklineViewTests` to the unit-carrying signature; add a timing case asserting `ms` and the absence of `¢`; add registry-level guards. Confirm failure before implementing. — **confirmed**, build failed on the missing `unitSymbol`
- [x] **Task 2 — Green.** Add `unitSymbol`, thread it through, introduce `MetricValueFormatter`, correct the `ChartData` strings. — **done**
- [x] **Task 3 — Localization.** Add German for the three new keys; verify they exist in the catalog rather than trusting a vacuous `--missing 0`. — **done**, all three verified present with German values
- [x] **Task 4 — Gate.** Four schemes sequentially, plus `archlint` and `bin/check-dependencies.sh`. — **done**, all green
- [x] **Task 5 — Visual confirmation.** Non-Research build on iPhone 17 Pro Max. — **done**, `79.5 ms` on the Compare Timing card, pitch cards unchanged

### Review Findings

*Code review 2026-08-08 of `9fae78c5` — three adversarial layers (Blind Hunter, Edge Case Hunter, Acceptance Auditor), all completed.*

**Resolution pass 2026-08-08.** All 9 patches applied and 2 of 5 decisions resolved on Michael's "fix" instruction. Gate re-run: iOS 2287, macOS 2274, iOS Research 2450, macOS Research 2437 — all green sequentially; `--missing` 0; archlint and check-dependencies clean. Verified in a running `Peach (Release)` build on iPhone 17 Pro Max: the accessibility tree now exposes `Compare Timing` / value `79.5 ms, Improving` (it exposed no value at all before), and the visible cards still read `11.5 ¢ … 79.5 ms`. Two findings initially drafted as deferrals — the fabricated "Stable" trend, and the transposable unit pair — were **fixed in this pass instead**, so they were never filed. They were briefly given the identifiers PF-091 and PF-092 in an uncommitted working tree and removed before the commit; those identifiers therefore correspond to no catalog entry in any commit and must not be cited as if they do. Three decisions were left open at this point and were resolved separately (see Spec Change Log).

- [x] [Review][Decision] **Start-card value and trend are never spoken by VoiceOver** — **FIXED.** Removed the overriding `.accessibilityLabel` from the `NavigationLink` and composed the card's own accessibility element inside `trainingCard`: `.accessibilityLabel(config.displayName)` plus `.accessibilityValue(...)`. `sparklineAccessibilityLabel` became `sparklineAccessibilityValue(ewma:trend:unitLabel:)`, returning `String?` so an absent measurement or trend produces no value instead of a fabricated one — which also removes the fabricated "Stable" trend. The sparkline itself is now `.accessibilityHidden(true)`, since the card speaks for it.
  *Original finding:* `StartScreen.swift:122` put `.accessibilityLabel(config.displayName)` on the `NavigationLink`, which merges its subtree and supersedes `ProgressSparklineView`'s own label, so the only unit-aware spoken path — modified and tested by this story — was unreachable. VoiceOver announced "Compare Timing, Button" and never the value, unit, or trend. Raised independently by blind+edge.
- [x] [Review][Decision] **Rhythm disciplines cannot separate spoken from compact unit — RESOLVED: spoken key added** (Michael, 2026-08-08). Both rhythm disciplines now declare `unitLabel: String(localized: "milliseconds")` (German "Millisekunden") while keeping `unitSymbol: String(localized: "ms")`. Consistent with the pitch disciplines, whose axes and speech already used the spelled-out "cents" against a compact "¢". Checked in the running app rather than assumed: this changes **only** VoiceOver, which now says "79.5 milliseconds, Improving". There is no visible regression, because rhythm disciplines render a heatmap card and never use `ProgressChartView`'s `unitLabel` axis — an earlier draft of this resolution wrongly predicted a "milliseconds" axis label. A registry guard now fails if any discipline uses one string for both forms. ORIGINAL: — `TimingOffsetDetectionDiscipline.swift:18-19` and `ContinuousRhythmMatchingDiscipline.swift:18-19` resolve both `unitLabel` and `unitSymbol` from the single catalog key `"ms"`. A translator cannot make VoiceOver say "Millisekunden" without also changing the card glyph, and VoiceOver may spell "ms" as letters. This falsifies the doc comment added at `TrainingDisciplineConfig.swift:42-43` ("spelled out for speech") and `:48` ("Distinct from `unitLabel`, which is spoken in full") for 2 of 7 disciplines. Raised by blind+edge.
- [x] [Review][Decision] **The frozen constraint "No view hardcodes a unit" is false as written — RESOLVED: wording narrowed** (Michael, 2026-08-08). The constraint now binds only shared multi-discipline surfaces and names the five discipline-specific views that legitimately hold their unit literally. No code change. ORIGINAL: — five views still hardcode units: `PitchMatchingFeedbackIndicator.swift:33,58,60,62`, `RhythmTimingFeedbackIndicator.swift:27,49`, `TimingStatsView.swift:48`, `ChromaticTrialResultView.swift:63-64`, `TrainingStatsView.swift:15,30`. None is a live defect — each sits in a discipline-specific view where the unit is correct — but the constraint is written unconditionally and the spec neither enumerates nor dismisses them. Either narrow the frozen wording to shared multi-discipline surfaces, or widen the fix. Raised by auditor.
- [x] [Review][Decision] **AC 5's before/after evidence does not reconcile — RESOLVED by investigation.** Three explanations were tested and rejected: the EWMA loop (`TrainingDisciplineStatistics.swift:68-75`) weights by inter-record deltas only and has no `now` term, so wall-clock decay is impossible; the value is stable at `79.5` across four relaunches, so merge-order nondeterminism is falsified; and `feedRecords` applies no filtering while all 120 seed tempos fall inside `TempoRange.defaultRanges`, so no records are dropped. An independent recomputation from the seed CSV yields 81.7, matching neither observation — because the import was a **Merge**, so the device's dataset is the seed CSV plus whatever that container already held. No baseline for the numeric value is therefore available, and none is needed: nothing in this diff can alter it, since the `NumberFormatter` configuration is byte-identical to the one it replaced. The Completion Notes and I/O matrix were reworded so AC 5 claims what it actually evidences — the **unit** changed from `¢` to `ms` while the pitch cards were untouched — rather than implying a controlled numeric comparison. Raised by auditor.
- [x] [Review][Decision] **The `ChartData` "pitch trend" rewording is scope the frozen block does not authorize — RESOLVED: ratified** (Michael, 2026-08-08). The frozen Approach now names it, and the spoken-unit change, as in-scope under the same root cause rather than splitting them into a further story. ORIGINAL: — the frozen Approach authorizes the `unitSymbol` field and the `MetricValueFormatter` swap only. The rewording was justified in agent-written sections as "the same root cause", but the Intent names a hardcoded *unit glyph* in `ProgressSparklineView`, while this is a hardcoded *domain word* in a different file on a different surface. Story 83.3's frozen block says such defects become "a separate story against a separate commit". Ratify by amending 83.5's frozen block, or split into its own story. Raised by auditor.
- [x] [Review][Patch] Registry guard is vacuous outside English — `unitLabel != "cents"` compares a localized value (German `"Cent"`) against an English literal [PeachTests/Core/Training/TrainingDisciplineRegistryTests.swift:112-116]
- [x] [Review][Patch] Registry guard checks only the `.rhythm` branch; pitch/intervals disciplines could declare `"ms"` undetected [PeachTests/Core/Training/TrainingDisciplineRegistryTests.swift:112]
- [x] [Review][Patch] Empty-symbol guard passes for whitespace-only, which still renders a dangling space [PeachTests/Core/Training/TrainingDisciplineRegistryTests.swift:105]
- [x] [Review][Patch] No test asserts the Start card receives `config.unitSymbol`; transposing the two arguments passes the whole suite [Peach/Start/StartScreen.swift:143-144]
- [x] [Review][Patch] `MetricValueFormatter` ships with no tests, against the project's "all new code requires tests" rule [Peach/Core/Profile/MetricValueFormatting.swift]
- [x] [Review][Patch] New catalog entries lost the per-argument translator comments their superseded keys carried; `"¢"` is presented to translators as a bare currency glyph with no context [Peach/Resources/Localizable.xcstrings]
- [x] [Review][Patch] Static `NumberFormatter` snapshots the locale at first use; a Region change while the app is resident leaves stale decimal separators [Peach/Core/Profile/MetricValueFormatting.swift:11-17]
- [x] [Review][Patch] Filename `MetricValueFormatting.swift` does not match its type `MetricValueFormatter` [Peach/Core/Profile/MetricValueFormatting.swift]
- [x] [Review][Patch] `sprint-status.yaml` records a `.claude/settings.json` change as landed, but that edit is uncommitted and absent from `9fae78c5` [docs/implementation-artifacts/sprint-status.yaml]
- [x] [Review][Defer] Profile chart headline values render with no unit [Peach/Profile/ProgressChartView.swift:72-77] — deferred, pre-existing, PF-088
- [x] [Review][Defer] `%lld data points` accessibility strings have no plural rule [Peach/Core/Profile/ChartData.swift:287] — deferred, pre-existing, PF-089
- [x] [Review][Defer] Imported metric values have no magnitude bound [import parsers] — deferred, pre-existing, PF-090
- [x] [Review][Fixed] Trend announced as "Stable" when none was computed [Peach/Start/ProgressSparklineView.swift] — **fixed in this story, not deferred**; no PF entry exists or should be cited
- [x] [Review][Fixed] Unit pair is two undistinguished `String`s; transposition compiles [Peach/Start/ProgressSparklineView.swift] — **partly fixed, not deferred**; the view now takes the whole config so the call site cannot transpose, and the registry guard asserts both forms per category. The two `String` properties on `TrainingDisciplineConfig` remain. No PF entry exists or should be cited

**Dismissed (3):** `ewma ?? 0` fabricating a measurement — proven unreachable, `mergedStatistics` guards `!allMetrics.isEmpty` (blind claimed it; edge checked and correctly declined). NaN/infinity rendering as `"NaN ¢"` — unreachable, import parsers guard `.isFinite` and every `MetricPoint` value is `abs(...)`. Superseded `"pitch trend"` catalog entries left in place — Xcode marks them stale on its next extraction; hand-deleting risks catalog corruption.

### Review Findings — second pass

*Code review 2026-08-08 of `ded972f1^..HEAD` (the review-fix commits), three adversarial layers, all completed. Blind Hunter built and ran the app and dumped the live accessibility tree rather than reasoning about SwiftUI semantics — it confirmed the accessibility restructure is correct at runtime: the button trait survives, the tap target is unchanged, the value propagates to the merged button element, and `milliseconds` is spoken in full.*

- [x] [Review][Patch] **`RhythmProfileCardView` hardcoded `ms` and formatted with `String(format:)`** — the exact bug class this story exists to remove, on a card rendered by **both** rhythm disciplines. Screenshot-confirmed in German: `79.5 ms  ±7.1 ms` directly below pitch cards reading `6,4`. Now takes the unit from `config` and the number from `MetricValueFormatter`; the spoken label uses the spelled-out `unitLabel`. Closes PF-093 and the rhythm half of PF-088.
- [x] [Review][Patch] Registry guard was asymmetric — the non-rhythm branch never inspected `unitLabel`, so a pitch discipline declaring `"milliseconds"` passed. Both branches now assert equality on both forms [TrainingDisciplineRegistryTests]
- [x] [Review][Patch] `everyDisciplineDeclaresUnits` lacked the `checked > 0` inert-loop guard its sibling received in the same commit [TrainingDisciplineRegistryTests]
- [x] [Review][Patch] The `String?` contract was discarded by `?? ""` at the only call site; now applied via `accessibilityValue(ifPresent:)` so a card with no measurement exposes no value [StartScreen.swift]
- [x] [Review][Patch] The spoken value was assembled by raw interpolation, unlike every sibling — word order and separator were frozen to English. Now `String(localized:)` with translator comments [ProgressSparklineView.swift]
- [x] [Review][Patch] `.accessibilityHidden(true)` was redundant (the parent already declares `children: .ignore`) and baked a non-reusable policy into a general-purpose view — removed [ProgressSparklineView.swift]
- [x] [Review][Patch] Three tautological assertions removed or made meaningful: `unitAgnostic` compared a pure function to itself; the config test compared the production expression to itself; `centsDelegates` kept as an explicit drift guard with the rationale stated [MetricValueFormatterTests, TrainingDisciplineConfigTests]
- [x] [Review][Patch] The rounding test was misnamed — `NumberFormatter` defaults to `.halfEven`, not half-away — and never exercised a real half. Renamed, and `.halfEven` pinned on 8.25 [MetricValueFormatterTests]
- [x] [Review][Patch] Negative values were untested on a formatter backing a signed domain type [MetricValueFormatterTests]
- [x] [Review][Patch] Record corrections: PF-091/092 cited as catalog entries that never existed in any commit; frozen Approach still said `unitLabel` was `"ms"`; the narrowed constraint's stated reason was false for two named views; File List missing two files and describing two others by their pre-review shape; a Dev Notes section referenced deleted symbols; Completion Notes carried pre-review gate figures; sprint-status said the decisions were both resolved and open.
- [x] [Review][Dismiss] Non-Latin numbering systems (ar_EG, fa_IR) break `contains("80")` — unreachable; the app ships `en` + `de` only.
- [x] [Review][Dismiss] `trend` non-nil with `ewma` nil discards the trend — unreachable: `trend` requires `recordCount >= 2`, which implies metrics exist, which implies a non-nil `ewma`.
- [x] [Review][Dismiss] Latent axis-truncation risk if a rhythm discipline ever adopted the default profile card — noted, but both override `profileCard` today and the override is what makes the spelled-out label safe.

**Acceptance Criteria:**

1. **Given** the Start screen with timing data, **when** the Compare Timing card is read, **then** it renders the value followed by `ms`, and contains no `¢`.
2. **Given** the Start screen with pitch data, **when** the four pitch cards are read, **then** they render exactly as before this story (`11.5 ¢`).
3. **Given** any registered rhythm discipline, **when** the registry tests run, **then** they fail if it declares `¢` as its symbol or `cents` as its label.
4. **Given** the four schemes run sequentially, **when** the results are read, **then** all are green and `bin/add-localization.swift --missing` reports `0` with the new keys actually present in the catalog.
5. **Given** a running `Peach (Release)` build, **when** the Start screen is inspected, **then** AC 1 and AC 2 hold in the rendered app, not only in tests.

## Dev Notes

### Why the accessibility path looked correct but was not

`ProgressSparklineView` had taken a `unitLabel` parameter since it was written, and its accessibility helper interpolated it, so the spoken path *appeared* correct while only `formatCompactEWMA` — the visible path — hardcoded the glyph. The bug was invisible to any test asserting on the accessibility label, and the one test covering the visible path (`formatCompactEWMA includes cent sign`) *asserted the bug as correct behaviour*; that test was rewritten, not deleted.\n\nCode review then showed the premise was wrong twice over: the spoken path was **unreachable**, because `StartScreen` overrode the label on the enclosing `NavigationLink`, so no unit was ever announced at all. The helper is now `sparklineAccessibilityValue`, applied by the card itself. Neither `unitLabel` as a parameter nor `sparklineAccessibilityLabel` survives.

### On the `Cents(_:)` wrapping

`Cents.formatted()` turned out to be a plain 1-decimal `NumberFormatter` with nothing cent-specific about it, so the numbers rendered for millisecond values were never wrong — only the unit was. The wrapping was still a domain-type violation and is removed, but this is why the defect showed up as a wrong label rather than a wrong number.

### Locale note

`MetricValueFormatter` is locale-aware, so the decimal separator follows the device region — `80.5` in en_US, `80,5` in de_DE. Two tests initially asserted on `"80.5"` and failed on the German-region test simulator. The assertions were narrowed to the locale-stable digits; the implementation was not changed.

## Verification

**Commands:**

- `bin/test.sh && bin/test.sh -p mac && bin/test.sh --research && bin/test.sh --research -p mac` — four green, sequential
- `bin/add-localization.swift --missing` — `0`
- `archlint Peach/` and `bin/check-dependencies.sh` — clean

**Manual checks:**

- Start screen on a running non-Research build: Compare Timing shows `ms`; the four pitch cards show `¢`.

## Dev Agent Record

### Agent Model Used

claude-opus-5

### Debug Log References

- `bin/add-localization.swift --missing` reported `0` *before* the German values were added, because the string catalog had not yet extracted the new keys — the tool only checks keys already present. Verified key presence directly in `Localizable.xcstrings` instead of trusting the count. Worth remembering: `--missing 0` is not by itself evidence that new strings are translated.
- The superseded `"… pitch trend …"` catalog entries remain in `Localizable.xcstrings`. Xcode marks such entries stale on its next extraction pass; they were left rather than hand-deleted.
- Two new tests failed on first green run purely because of the test simulator's German region formatting the decimal separator as `,`. Implementation was correct; the assertions were locale-fragile.

### Completion Notes List

**All five tasks complete.** Gate figures at the final commit: iOS 2288, macOS 2275, iOS Research 2451, macOS Research 2438 — all green, run sequentially. (The story's first commit gated at 2279 / 2266 / 2442 / 2429; the two review passes added tests, which accounts for the difference.) `archlint` and `bin/check-dependencies.sh` clean. `--missing` = 0 with all three new keys verified present with German values.

Visual confirmation on iPhone 17 Pro Max (`Peach (Release)`, 1.1.0 build 2): Compare Timing renders `79.5 ms`; Compare Pitch `11.5 ¢`, Match Pitch `6.4 ¢`, Compare Intervals `13.1 ¢`, Match Intervals `6.4 ¢` — pitch cards unchanged, satisfying AC 1, AC 2, and AC 5.

**What AC 5's evidence does and does not establish.** It establishes the **unit**: the Compare Timing card changed from `¢` to `ms` while all four pitch cards kept `¢`. It does **not** establish anything about the numeric value, and must not be read as a controlled numeric comparison — the pre-fix reading was `80.5` and the post-fix reading `79.5`. Code review challenged this and the investigation is recorded under *Review Findings*: no code path in this diff can change the value (the `NumberFormatter` configuration is byte-identical), and no valid numeric baseline exists because the seed data was imported with **Merge** into a container that already held records.

### File List

- `Peach/Core/Training/TrainingDisciplineConfig.swift` — modified (new `unitSymbol` field)
- `Peach/Core/Profile/MetricValueFormatter.swift` — added (renamed from `MetricValueFormatting.swift` during the review pass so the filename matches its type; now pins `Locale.autoupdatingCurrent`)
- `PeachTests/Core/Profile/MetricValueFormatterTests.swift` — added (review pass)
- `Peach/Core/Profile/ChartData.swift` — modified (neutral formatter; "pitch trend" → "trend" in two accessibility strings)
- `Peach/App/CentsFormatting.swift` — modified (delegates to `MetricValueFormatter`)
- `Peach/Start/ProgressSparklineView.swift` — modified (takes `config: TrainingDisciplineConfig`; `Cents(_:)` removed from both paths; accessibility helper returns `String?` and builds a localized string)
- `Peach/Start/StartScreen.swift` — modified (passes `config`; composes the card accessibility element; `accessibilityValue(ifPresent:)` helper)
- `Peach/Training/PitchDiscrimination/Discipline/UnisonPitchDiscriminationDiscipline.swift` — modified
- `Peach/Training/PitchDiscrimination/Discipline/IntervalPitchDiscriminationDiscipline.swift` — modified
- `Peach/Training/PitchMatching/Discipline/UnisonPitchMatchingDiscipline.swift` — modified
- `Peach/Training/PitchMatching/Discipline/IntervalPitchMatchingDiscipline.swift` — modified
- `Peach/Training/TimingOffsetDetection/Discipline/TimingOffsetDetectionDiscipline.swift` — modified
- `Peach/Training/ContinuousRhythmMatching/Discipline/ContinuousRhythmMatchingDiscipline.swift` — modified
- `Peach/Training/ChromaticConstruction/Discipline/ChromaticConstructionDiscipline.swift` — modified
- `Peach/Resources/Localizable.xcstrings` — modified (three keys added with German values)
- `PeachTests/Start/ProgressSparklineViewTests.swift` — modified
- `PeachTests/Core/Training/TrainingDisciplineRegistryTests.swift` — modified (two registry guards added)
- `PeachTests/Helpers/SyntheticDiscipline.swift` — modified
- `PeachTests/Core/Training/RegistryContributionsTests.swift` — modified
- `docs/planning-artifacts/epics.md` — modified (story 83.5 added; Epic 83 work order updated)
- `docs/implementation-artifacts/83-5-start-screen-unit-rendering.md` — added (this file)
- `Peach/Training/ContinuousRhythmMatching/Profile/RhythmProfileCardView.swift` — modified (review pass 2: unit from `config`, number through `MetricValueFormatter` instead of `String(format:)`)
- `PeachTests/Core/Profile/TrainingDisciplineConfigTests.swift` — modified (review pass: assertion de-tautologised)
- `docs/implementation-artifacts/deferred-work.md` — modified (PF-088/089/090 filed; PF-088 corrected twice; PF-093 filed then removed once fixed)
- `docs/implementation-artifacts/sprint-status.yaml` — modified

## Spec Change Log

**2026-08-08 — Frozen-block amendments, all three instructed by Michael in response to the code review's decision findings.**

1. **`Always` constraint narrowed.** "No view hardcodes a unit" was unconditional and false: five discipline-specific views hold their unit literally, each correctly, because only one discipline renders them. The constraint now binds shared multi-discipline surfaces only and enumerates the five exceptions. No code change — the spec was wrong, not the code.
2. **Scope ratified rather than split.** The `ChartData` "pitch trend" accessibility rewording was folded into this story during implementation and flagged at the time; the Acceptance Auditor correctly noted the frozen Approach did not authorize it and that story 83.3's rule points at a separate story. Michael ratified it in place. The Approach now names it explicitly.
3. **Spoken unit separated from compact unit.** Both rhythm disciplines resolved `unitLabel` and `unitSymbol` from the single catalog key `"ms"`, so the spoken form could not be spelled out and the type's own doc comment ("spoken in full") was false for 2 of 7 disciplines. `unitLabel` is now `"milliseconds"` / `"Millisekunden"`, and a registry guard fails if any discipline uses one string for both forms. Verified in the running app: the change is audible only — the Start card still renders `79.5 ms` and speaks `79.5 milliseconds`, and no chart axis changed, because rhythm disciplines use a heatmap card rather than `ProgressChartView`.

## Change Log

- 2026-08-08: Story created and implemented. Start screen rendered `80.5 ¢` for a millisecond metric; fixed by giving each discipline a compact `unitSymbol` alongside its spoken `unitLabel`, and by replacing the `Cents(_:)` wrapping in the shared progress surfaces with a neutral `MetricValueFormatter`. The adjacent `ChartData` "pitch trend" accessibility strings were corrected in the same pass as the same root cause. Verified in a running `Peach (Release)` build. Status → `review`.
- 2026-08-08: Code review of `9fae78c5` (three adversarial layers). 9 patches applied, 2 of 5 decisions resolved, 3 open. Fixed a pre-existing accessibility defect the review exposed — the `NavigationLink` label override meant the Start card never spoke its measurement — by composing the card's accessibility element and converting the sparkline helper to return an optional value, which also removed the fabricated "Stable" trend. `ProgressSparklineView` now takes the whole config instead of two undistinguished `String`s. Registry guards rewritten to compare localized values against localized values after review found them vacuous in German. Added `MetricValueFormatterTests`, translator comments on the three new catalog keys, and `Locale.autoupdatingCurrent` on the shared formatter; renamed the formatter file to match its type. PF-088/089/090 filed as deferred. Gate: 2287 / 2274 / 2450 / 2437 green.
- 2026-08-08: Three review decisions resolved on Michael's instruction — spoken unit key added (`milliseconds` / `Millisekunden`), the `Always` constraint narrowed to shared multi-discipline surfaces, and the `ChartData` rewording ratified in place. A pre-existing test pinning `unitLabel == "ms"` was updated to the localized spelled-out form. While verifying, the Profile screen showed that PF-088 had been filed with an inverted description — the timing headline carries a unit and the pitch headlines do not, not the reverse — so PF-088 was corrected and PF-093 filed for `RhythmProfileCardView` formatting numbers with `String(format:)` rather than the locale-aware `MetricValueFormatter`. Gate re-run after the unit change: 2287 / 2274 / 2450 / 2437 green; `--missing` 0; archlint and check-dependencies clean. Status → `review`.
- 2026-08-08: Second code review, of the review-fix commits (`ded972f1^..HEAD`), three adversarial layers. One real user-visible defect found and fixed: `RhythmProfileCardView` — rendered by BOTH rhythm disciplines and therefore a shared surface — hardcoded `ms` and formatted with `String(format:)`, so a German user saw `79.5 ms` directly below pitch cards reading `6,4`. It now takes its unit from `config` and its number from `MetricValueFormatter`. Registry guard made symmetric (the non-rhythm branch never checked `unitLabel`, so a pitch discipline declaring `milliseconds` passed); inert-loop guard added to its sibling; the `String?` accessibility contract now honoured via `accessibilityValue(ifPresent:)`; the spoken value localized; redundant `.accessibilityHidden` removed; three tautological assertions removed or justified; the rounding test renamed and `.halfEven` pinned; negative values covered. Record corrections: PF-091/092 were cited as catalog entries that never existed in any commit — they were drafted and removed in an uncommitted tree; the frozen Approach still described `unitLabel` as `ms`; the narrowed constraint's stated reason was false for two named views; File List and Completion Notes were stale. PF-093 fixed and removed; PF-088 corrected and narrowed to the pitch headlines. Gate: 2288 / 2275 / 2451 / 2438 green.
