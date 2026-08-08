---
title: 'Story 83.5: Render each discipline''s own unit on the Start screen'
type: 'bug'
created: '2026-08-08'
status: 'in-progress'
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

**Approach:** Give `TrainingDisciplineConfig` a second unit field. `unitLabel` stays the spoken/axis form (`"cents"`, `"ms"`), used by VoiceOver and chart axes; a new `unitSymbol` carries the compact form (`"¢"`, `"ms"`) rendered next to a number in the Start cards. Every discipline declares both. Replace the `Cents(_:)` wrapping in the shared progress surfaces with a neutral `MetricValueFormatter`, and have `Cents.formatted()` delegate to it so cent formatting is bit-for-bit unchanged.

**Why a second field rather than reusing `unitLabel`:** substituting `unitLabel` into the card would render `11.5 cents` on the four pitch cards, replacing a deliberately compact glyph with a word in a tight layout. Michael chose the added field over that regression.

## Boundaries & Constraints

**Always:**
- The unit rendered anywhere comes from the discipline's config. No view hardcodes a unit.
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
| VoiceOver, timing card | `unitLabel: "ms"` | speaks the value followed by `ms` |
| Chart Y axis | `unitLabel` | unchanged — already correct before this story |
| New discipline added | any | registry test fails if a rhythm discipline declares a cent unit |
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

**Resolution pass 2026-08-08.** All 9 patches applied and 2 of 5 decisions resolved on Michael's "fix" instruction. Gate re-run: iOS 2287, macOS 2274, iOS Research 2450, macOS Research 2437 — all green sequentially; `--missing` 0; archlint and check-dependencies clean. Verified in a running `Peach (Release)` build on iPhone 17 Pro Max: the accessibility tree now exposes `Compare Timing` / value `79.5 ms, Improving` (it exposed no value at all before), and the visible cards still read `11.5 ¢ … 79.5 ms`. PF-091 and PF-092 were fixed by this pass rather than deferred, and their catalog entries were removed accordingly. Three decisions remain open for Michael — marked below.

- [x] [Review][Decision] **Start-card value and trend are never spoken by VoiceOver** — **FIXED.** Removed the overriding `.accessibilityLabel` from the `NavigationLink` and composed the card's own accessibility element inside `trainingCard`: `.accessibilityLabel(config.displayName)` plus `.accessibilityValue(...)`. `sparklineAccessibilityLabel` became `sparklineAccessibilityValue(ewma:trend:unitLabel:)`, returning `String?` so an absent measurement or trend produces no value instead of a fabricated one — which also closes PF-091. The sparkline itself is now `.accessibilityHidden(true)`, since the card speaks for it.
  *Original finding:* `StartScreen.swift:122` put `.accessibilityLabel(config.displayName)` on the `NavigationLink`, which merges its subtree and supersedes `ProgressSparklineView`'s own label, so the only unit-aware spoken path — modified and tested by this story — was unreachable. VoiceOver announced "Compare Timing, Button" and never the value, unit, or trend. Raised independently by blind+edge.
- [ ] [Review][Decision] **OPEN — Rhythm disciplines cannot separate spoken from compact unit** — `TimingOffsetDetectionDiscipline.swift:18-19` and `ContinuousRhythmMatchingDiscipline.swift:18-19` resolve both `unitLabel` and `unitSymbol` from the single catalog key `"ms"`. A translator cannot make VoiceOver say "Millisekunden" without also changing the card glyph, and VoiceOver may spell "ms" as letters. This falsifies the doc comment added at `TrainingDisciplineConfig.swift:42-43` ("spelled out for speech") and `:48` ("Distinct from `unitLabel`, which is spoken in full") for 2 of 7 disciplines. Raised by blind+edge.
- [ ] [Review][Decision] **OPEN — The frozen constraint "No view hardcodes a unit" is false as written** — five views still hardcode units: `PitchMatchingFeedbackIndicator.swift:33,58,60,62`, `RhythmTimingFeedbackIndicator.swift:27,49`, `TimingStatsView.swift:48`, `ChromaticTrialResultView.swift:63-64`, `TrainingStatsView.swift:15,30`. None is a live defect — each sits in a discipline-specific view where the unit is correct — but the constraint is written unconditionally and the spec neither enumerates nor dismisses them. Either narrow the frozen wording to shared multi-discipline surfaces, or widen the fix. Raised by auditor.
- [x] [Review][Decision] **AC 5's before/after evidence does not reconcile — RESOLVED by investigation.** Three explanations were tested and rejected: the EWMA loop (`TrainingDisciplineStatistics.swift:68-75`) weights by inter-record deltas only and has no `now` term, so wall-clock decay is impossible; the value is stable at `79.5` across four relaunches, so merge-order nondeterminism is falsified; and `feedRecords` applies no filtering while all 120 seed tempos fall inside `TempoRange.defaultRanges`, so no records are dropped. An independent recomputation from the seed CSV yields 81.7, matching neither observation — because the import was a **Merge**, so the device's dataset is the seed CSV plus whatever that container already held. No baseline for the numeric value is therefore available, and none is needed: nothing in this diff can alter it, since the `NumberFormatter` configuration is byte-identical to the one it replaced. The Completion Notes and I/O matrix were reworded so AC 5 claims what it actually evidences — the **unit** changed from `¢` to `ms` while the pitch cards were untouched — rather than implying a controlled numeric comparison. Raised by auditor.
- [ ] [Review][Decision] **OPEN — The `ChartData` "pitch trend" rewording is scope the frozen block does not authorize** — the frozen Approach authorizes the `unitSymbol` field and the `MetricValueFormatter` swap only. The rewording was justified in agent-written sections as "the same root cause", but the Intent names a hardcoded *unit glyph* in `ProgressSparklineView`, while this is a hardcoded *domain word* in a different file on a different surface. Story 83.3's frozen block says such defects become "a separate story against a separate commit". Ratify by amending 83.5's frozen block, or split into its own story. Raised by auditor.
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
- [x] [Review][Defer] Trend announced as "Stable" when none was computed [Peach/Start/ProgressSparklineView.swift:37] — deferred, pre-existing, PF-091
- [x] [Review][Defer] Unit pair is two undistinguished `String`s; transposition compiles [Peach/Core/Training/TrainingDisciplineConfig.swift:44,49] — deferred, PF-092

**Dismissed (3):** `ewma ?? 0` fabricating a measurement — proven unreachable, `mergedStatistics` guards `!allMetrics.isEmpty` (blind claimed it; edge checked and correctly declined). NaN/infinity rendering as `"NaN ¢"` — unreachable, import parsers guard `.isFinite` and every `MetricPoint` value is `abs(...)`. Superseded `"pitch trend"` catalog entries left in place — Xcode marks them stale on its next extraction; hand-deleting risks catalog corruption.

**Acceptance Criteria:**

1. **Given** the Start screen with timing data, **when** the Compare Timing card is read, **then** it renders the value followed by `ms`, and contains no `¢`.
2. **Given** the Start screen with pitch data, **when** the four pitch cards are read, **then** they render exactly as before this story (`11.5 ¢`).
3. **Given** any registered rhythm discipline, **when** the registry tests run, **then** they fail if it declares `¢` as its symbol or `cents` as its label.
4. **Given** the four schemes run sequentially, **when** the results are read, **then** all are green and `bin/add-localization.swift --missing` reports `0` with the new keys actually present in the catalog.
5. **Given** a running `Peach (Release)` build, **when** the Start screen is inspected, **then** AC 1 and AC 2 hold in the rendered app, not only in tests.

## Dev Notes

### Why the accessibility path was already correct

`ProgressSparklineView` has taken a `unitLabel` parameter since it was written, and `sparklineAccessibilityLabel` interpolates it. Only `formatCompactEWMA` — the visible path — hardcoded the glyph. The bug was therefore invisible to any test that asserted on the accessibility label, and the one test that covered the visible path (`formatCompactEWMA includes cent sign`) *asserted the bug as correct behaviour*. That test was rewritten, not deleted.

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

**All five tasks complete.** Gate figures: iOS 2279, macOS 2266, iOS Research 2442, macOS Research 2429 — all green, run sequentially. `archlint` and `bin/check-dependencies.sh` clean. `--missing` = 0 with all three new keys verified present with German values.

Visual confirmation on iPhone 17 Pro Max (`Peach (Release)`, 1.1.0 build 2): Compare Timing renders `79.5 ms`; Compare Pitch `11.5 ¢`, Match Pitch `6.4 ¢`, Compare Intervals `13.1 ¢`, Match Intervals `6.4 ¢` — pitch cards unchanged, satisfying AC 1, AC 2, and AC 5.

**What AC 5's evidence does and does not establish.** It establishes the **unit**: the Compare Timing card changed from `¢` to `ms` while all four pitch cards kept `¢`. It does **not** establish anything about the numeric value, and must not be read as a controlled numeric comparison — the pre-fix reading was `80.5` and the post-fix reading `79.5`. Code review challenged this and the investigation is recorded under *Review Findings*: no code path in this diff can change the value (the `NumberFormatter` configuration is byte-identical), and no valid numeric baseline exists because the seed data was imported with **Merge** into a container that already held records.

### File List

- `Peach/Core/Training/TrainingDisciplineConfig.swift` — modified (new `unitSymbol` field)
- `Peach/Core/Profile/MetricValueFormatter.swift` — added (renamed from `MetricValueFormatting.swift` during the review pass so the filename matches its type; now pins `Locale.autoupdatingCurrent`)
- `PeachTests/Core/Profile/MetricValueFormatterTests.swift` — added (review pass)
- `Peach/Core/Profile/ChartData.swift` — modified (neutral formatter; "pitch trend" → "trend" in two accessibility strings)
- `Peach/App/CentsFormatting.swift` — modified (delegates to `MetricValueFormatter`)
- `Peach/Start/ProgressSparklineView.swift` — modified (`unitSymbol` property and parameter; `Cents(_:)` removed from both paths)
- `Peach/Start/StartScreen.swift` — modified (passes `config.unitSymbol`)
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
- `docs/implementation-artifacts/sprint-status.yaml` — modified

## Change Log

- 2026-08-08: Story created and implemented. Start screen rendered `80.5 ¢` for a millisecond metric; fixed by giving each discipline a compact `unitSymbol` alongside its spoken `unitLabel`, and by replacing the `Cents(_:)` wrapping in the shared progress surfaces with a neutral `MetricValueFormatter`. The adjacent `ChartData` "pitch trend" accessibility strings were corrected in the same pass as the same root cause. Verified in a running `Peach (Release)` build. Status → `review`.
- 2026-08-08: Code review of `9fae78c5` (three adversarial layers). 9 patches applied, 2 of 5 decisions resolved, 3 open. Fixed a pre-existing accessibility defect the review exposed — the `NavigationLink` label override meant the Start card never spoke its measurement — by composing the card's accessibility element and converting the sparkline helper to return an optional value, which also closed PF-091. `ProgressSparklineView` now takes the whole config instead of two undistinguished `String`s, closing PF-092. Registry guards rewritten to compare localized values against localized values after review found them vacuous in German. Added `MetricValueFormatterTests`, translator comments on the three new catalog keys, and `Locale.autoupdatingCurrent` on the shared formatter; renamed the formatter file to match its type. PF-088/089/090 filed as deferred. Gate: 2287 / 2274 / 2450 / 2437 green.
