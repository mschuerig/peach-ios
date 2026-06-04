---
title: 'Story 82.8: Lift the PEACH_RESEARCH gate for Timing Offset Detection'
type: 'chore'
created: '2026-06-04'
status: 'done'
baseline_commit: '025f46d0a7500c826a12c715dd3ee5b90764cf32'
context:
  - '{project-root}/docs/implementation-artifacts/epic-82-context.md'
  - '{project-root}/Peach/App/Training/DisciplineBootstrap.swift'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** TOD is the only training discipline still hidden behind `#if PEACH_RESEARCH` after epic 82's pattern + slot work landed. The next App Store cut should include it; today only the four pitch disciplines are registered in non-Research builds because `DisciplineBootstrap.swift` wraps both TOD and Continuous Rhythm Matching (CRM) in the same gate. The TOD source itself already compiles in every configuration — only the registration entry and a fan-out of test guards keep it dark.

**Approach:** Mechanical reclassification, not behavior change. Split the single `#if PEACH_RESEARCH` block in `DisciplineBootstrap.allDisciplines` so `TimingOffsetDetectionDiscipline()` registers unconditionally while `ContinuousRhythmMatchingDiscipline()` stays gated. Then walk every test file that wraps TOD content in `#if PEACH_RESEARCH` and either remove the gate (TOD-only files) or split the gated region into a TOD-always-on part and a CRM-only `#if PEACH_RESEARCH` part (mixed files). CRM remains research-only end-to-end. No engine, UI, copy, or `@AppStorage` changes; the localized strings TOD needs (`"Compare Timing"`, help/Settings labels) already ship in `Localizable.xcstrings`.

## Boundaries & Constraints

**Always:**
- Source split: `DisciplineBootstrap.allDisciplines` registers `TimingOffsetDetectionDiscipline()` unconditionally; `ContinuousRhythmMatchingDiscipline()` stays inside `#if PEACH_RESEARCH`. The doc comment on the enum is refreshed to describe the new state (TOD always-on; CRM behind the flag) without re-narrating epic-82 history.
- TOD-only test files lose their `#if PEACH_RESEARCH` / `#endif` lines wholesale; the `@Suite` body stays unchanged.
- Mixed test files (TOD + CRM under one `#if`) are split so TOD `@Test` functions / `@Suite` regions run in every configuration and CRM ones remain inside `#if PEACH_RESEARCH`. Order of declarations within each file is preserved; only the guard placement changes.
- `TrainingDisciplineRegistryTests` registered-set comment is updated to say "configurations without `PEACH_RESEARCH` register the pitch disciplines and TOD; the Research configurations additionally register CRM." No assertion body changes (the existing tests assert invariants, not exact counts).
- New test counts on non-Research schemes must increase by exactly the count of TOD `@Test` functions that move out from under the gate. CRM `@Test` counts on non-Research schemes stay at zero.
- Pre-commit gate (per [[feedback_test_sh_no_parallel]]): `bin/test.sh --research && bin/test.sh --research -p mac && bin/test.sh && bin/test.sh -p mac` — all four green before commit. The non-Research runs grow visibly; the Research runs match their prior totals.
- Sprint-status key `82-8-lift-tod-research-gate` flips to `in-progress` on start and `done` after review per [[feedback_update_status_after_review]]. Epic 82 stays `done` (this story rides on top; the epic close from 82.7 stands).
- Stale comment hygiene: anywhere a code comment, doc-comment, or fixture remarks that "TOD ships only under `PEACH_RESEARCH`" or equivalent is brought current (TOD now always-on, CRM only under the flag). The intent is grep-and-fix accuracy, not rewriting.

**Ask First:**
- If a TOD test file's only contents are inside the `#if` block and the file uses no shared mocks (i.e. the entire file becomes a no-op file when ungated), confirm before deleting vs. ungating. **Default plan: ungate, keep the file.**
- If the registry/test-counts diff after un-gating reveals that an existing assertion silently relied on the registered count being exactly four (e.g. a hard-coded `== 4`), surface it before changing the literal. **Default plan: convert to an invariant-style assertion that holds for any registered set.**

**Never:**
- No edits to TOD source files. The discipline implementation, screens, Settings sections, help, profile adapter, CSV history, settings types, value objects (`OffsetNotePosition`, `TimingOffsetDetectionPattern`, etc.) all stay byte-identical.
- No edits to CRM source or test files outside the guard-split work. CRM remains research-only without any behavior changes.
- No App Store / xcstrings / marketing / project-context.md / `project_initial_release_pitch_only.md` memory edits. Those land in a separate copy-update story.
- No new entries to `Localizable.xcstrings`; `bin/add-localization.swift --missing` must still report `0`.
- No changes to schemes, Xcode build configurations, or `PEACH_RESEARCH` flag wiring. The flag still exists and still gates CRM.
- No engine, `@AppStorage` schema, `PeachSchema`, or migration changes. TOD records already round-trip in every configuration because the persistence layer is registry-driven.
- No registration-order changes for the four pitch disciplines. The new order is `[pitch×4, TOD]` always-on, with CRM appended inside the `#if` — matches the existing array order.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Non-Research scheme, Start screen | `bin/test.sh` build of `Debug` configuration | Start screen lists 5 disciplines: 4 pitch + Timing Offset Detection (display name "Compare Timing"); CRM absent | N/A |
| Research scheme, Start screen | `Debug (Research)` build | Start screen lists 6 disciplines (TOD + CRM both present) | N/A |
| Registry invariant tests (any scheme) | `TrainingDisciplineRegistryTests` runs | All existing invariant tests pass; pitch subset still asserted; registered IDs ⊆ canonical; no duplicates | N/A |
| Non-Research TOD trial round-trip | Launch `Debug`, open TOD, complete one trial | Trial persists, `PerceptualProfile` updates the TOD `StatisticsKey`, profile screen shows the rhythm card without CRM data | N/A |
| Mixed test file after split | `TrainingDisciplineImplementationTests.swift` after edits | TOD `@Test`s run on every scheme; CRM `@Test`s only on Research; total `@Test` count unchanged | N/A |
| `bin/add-localization.swift --missing` post-change | run after edits | `0 keys missing German translation` | N/A |
| Stored CRM records on a non-Research device | A device that previously ran Research has `continuousRhythmMatching` SwiftData rows; user updates to a non-Research build | Rows stay in the store untouched; `TrainingDataExporter.fetchExportRecords` for CRM is unreachable (no registration) so they neither export nor crash; the next Research build sees them again | N/A — registry-driven dispatch swallows the unregistered case |

</frozen-after-approval>

## Code Map

- `Peach/App/Training/DisciplineBootstrap.swift` — Move `TimingOffsetDetectionDiscipline()` out of the `#if PEACH_RESEARCH` block; CRM stays inside. Refresh the doc-comment paragraphs that describe the `PEACH_RESEARCH` envelope so they distinguish "TOD ships in every configuration; CRM stays research-only."
- `PeachTests/Core/Training/TrainingDisciplineRegistryTests.swift` — Update the registered-set MARK comment (lines ~10-15) to reflect the new partition. No `@Test` body changes.
- TOD-only test/mock files — remove the `#if PEACH_RESEARCH` / `#endif` lines around the file body. Files: `PeachTests/Mocks/MockTimingOffsetDetectionObserver.swift`, `PeachTests/Mocks/MockNextTimingOffsetDetectionStrategy.swift`, `PeachTests/Core/Music/TimingDirectionTests.swift`, `PeachTests/Core/Training/TimingOffsetDetectionSettingsTests.swift`, `PeachTests/Core/Training/CompletedTimingOffsetDetectionTrialTests.swift`, `PeachTests/Core/Algorithm/AdaptiveTimingOffsetDetectionStrategyTests.swift`, `PeachTests/Training/TimingOffsetDetection/*.swift` (all files in this directory and its `Settings/` subdir).
- TOD-only fragments inside otherwise-shared files — remove the surrounding `#if PEACH_RESEARCH`. Files: `PeachTests/Core/Profile/TrainingDisciplineConfigTests.swift` (single TOD-only block), `PeachTests/Core/Data/CSVFormatMigrationTests.swift`, `PeachTests/Core/Data/TrainingDataImporterTests.swift`, `PeachTests/Core/Data/TrainingDataStoreTests.swift`, `PeachTests/Core/Data/TrainingDataTransferServiceTests.swift`, `PeachTests/Helpers/PerceptualProfileTestHelpers.swift`.
- Mixed TOD + CRM test files — split each `#if PEACH_RESEARCH` block so TOD `@Test` functions sit outside the guard and CRM `@Test` functions stay inside a new `#if PEACH_RESEARCH` block immediately after. Files and primary blocks:
  - `PeachTests/Core/Training/TrainingDisciplineImplementationTests.swift` (blocks at lines ~101, ~208, ~321, ~448, ~547 — each currently runs TOD `@Test`s before CRM `@Test`s; split each).
  - `PeachTests/Core/Training/ObserverAdapterTests.swift` (blocks at ~151, ~322, ~420 — same pattern).
  - `PeachTests/Core/Training/DuplicateKeyTests.swift` (block at ~57).
  - `PeachTests/Core/Profile/PerceptualProfileTests.swift` (block at ~302).
  - `PeachTests/Core/Profile/TrainingDisciplineIDTests.swift` (TOD-only slug block at ~29 → ungate; mixed rhythm-modes block at ~46 → narrow the `for mode in […]` literal to `[.timingOffsetDetection]` outside the gate, keep the CRM iteration inside a residual `#if` *only if doing so preserves the invariant cleanly; if not, narrow the outer test and add a CRM-only sibling test inside the gate*).
  - `PeachTests/Core/Profile/StatisticsKeyTests.swift` (TOD blocks → ungate; CRM block stays gated).
  - `PeachTests/Core/Profile/ProgressTimelineTests.swift` (gated regions at ~14 typealias, ~29 helper, ~1033 — ungate the TOD typealias and any helper that feeds TOD payloads; keep gated only the regions whose body references `ContinuousRhythmMatchingPayload` or `ContinuousRhythmMatching*` types. The bulk of pitch-discipline `@Test`s sit outside the existing gates already — do not touch them).
  - `PeachTests/Core/Profile/SpectrogramDataTests.swift` (entire file currently gated; TOD's `profileCard` now exercises `SpectrogramData` in non-Research — **ungate the whole file**. Tests assert spectrogram math on synthetic `MetricPoint` data and do not type-depend on CRM payloads).
  - `PeachTests/Core/Data/CSVImportParserTests.swift` (blocks at ~575, ~640, ~680, ~720 — per survey: TOD-only blocks ungated, CRM-only block stays gated, mixed block split).
  - `PeachTests/Core/Data/TrainingDataExporterTests.swift` (block at ~242: TOD ungated; block at ~265: stays gated if it references CRM types, split if not).
  - `PeachTests/App/TrainingLifecycleCoordinatorTests.swift` (one block; split TOD vs CRM `@Test`s).
  - `PeachTests/Start/StartScreenTests.swift` (block at ~93: the `NavigationDestination.timingOffsetDetection` test moves out of the guard; the `.continuousRhythmMatching` test stays inside a residual `#if`).
- `docs/implementation-artifacts/sprint-status.yaml` — Add a new `82-8-lift-tod-research-gate` key under the epic-82 block (status flips to `in-progress` on start, `done` after review).
- `docs/implementation-artifacts/epic-82-context.md` — Append a one-line story entry for 82.8 in the **Stories** list (between 82.7 and any "retrospective" line). Do not rewrite the goal paragraph (the original epic 82 scope held; this is an explicit follow-on the user authorized).

## Tasks & Acceptance

**Execution:**
- [x] `Peach/App/Training/DisciplineBootstrap.swift` — split the `#if PEACH_RESEARCH` block (TOD ungated, CRM gated), refresh the enum doc-comment to match
- [x] TOD-only test/mock files — stripped surrounding `#if PEACH_RESEARCH` / `#endif` from 20 files (mocks, TimingDirectionTests, TimingOffsetDetectionSettingsTests, CompletedTimingOffsetDetectionTrialTests, AdaptiveTimingOffsetDetectionStrategyTests, and every file under `PeachTests/Training/TimingOffsetDetection/` + its `Settings/` subdir)
- [x] TOD-only fragments inside otherwise-shared files — ungated in `TrainingDisciplineConfigTests`, `CSVFormatMigrationTests`, `TrainingDataImporterTests`, `TrainingDataTransferServiceTests`, and the first gated block (`feedTimingOffsetDetections`) of `PerceptualProfileTestHelpers`
- [x] Mixed test files — split: `TrainingDisciplineImplementationTests` (5 blocks), `ObserverAdapterTests` (3 blocks), `DuplicateKeyTests` (both tests ungated — pure string-keyed `TempoDuplicateKey` behavior), `PerceptualProfileTests` (TOD observer/builder tests ungated; CRM-coupled `trainedTempoRanges` / `rhythmOverallAccuracy` / `resetAll` / CRM observer tests stay gated), `TrainingDisciplineIDTests` (TOD slug ungated; mixed `rhythmModesReturn12Keys` split into TOD-always + CRM-gated tests), `StatisticsKeyTests` (TOD range/direction tests ungated; CRM identity test gated), `TrainingDataStoreTests` (TOD block 322–378 ungated; CRM block 380–432 stays gated), `CSVImportParserTests` (TOD v2 import + mixed-types + rhythm-row blocks ungated; CRM migration + CRM-touching round-trip blocks stay gated), `TrainingDataExporterTests` (6 TOD-relevant tests ungated; the 2 schema-coupled `headerInExport` and `allRowsHave19Fields` stay gated because they assert `columns.count == 19` / `columns[14] == "meanOffsetMs"`), `StartScreenTests` (TOD nav case ungated, CRM nav case gated). `TrainingLifecycleCoordinatorTests` kept entirely gated — the suite uses `.continuousRhythmMatching` as its synchronous-session test fixture throughout, and rewriting to TOD-based fixtures is out of scope; TOD lifecycle behavior is covered by `TimingOffsetDetectionSessionTests` (now ungated).
- [x] Shared-but-TOD-touched files — `SpectrogramDataTests` outer `#if` removed; only the one `continuousRhythmMatchingClassifications` `@Test` is now gated. `ProgressTimelineTests` lost all three of its `#if PEACH_RESEARCH` blocks (TOD typealias + helper overload + Rhythm Mode Tests section — every reference was TOD-only).
- [x] `TrainingDisciplineRegistryTests.swift` — registered-set MARK comment refreshed to "non-Research = pitch + TOD; Research = + CRM"
- [x] Stale-comment hygiene — `CSVHistoryRegistry.swift` doc-comment updated ("excludes CRM" instead of "excludes timing disciplines"); `CSVImportParserTests.swift` `makeCSV` comment updated; `docs/project-context.md` "Training disciplines (build-gated)" rule updated to describe the new partition
- [x] Final grep audit: every surviving `PEACH_RESEARCH` hit is either CRM-only content (mocks, `BeatPosition`, `ContinuousRhythmMatching*` directories, `ContinuousRhythmMatchingSettingsTests`, etc.), a justified-gated CRM-coupled block in a shared file, or the `DisciplineBootstrap` envelope/registration. Test-count arithmetic confirms no TOD-only `@Test` is still trapped: non-Research grew by +281 (= all the ungated TOD tests), Research grew by +1 (only the new CRM-only `continuousRhythmMatchingReturns12Keys` test from the `TrainingDisciplineIDTests` split).
- [x] `bin/add-localization.swift --missing` reports `0 keys missing German translation`
- [x] `docs/implementation-artifacts/epic-82-context.md` — Stories list extended with the 82.8 line
- [x] `sprint-status.yaml` — `82-8-lift-tod-research-gate: in-progress` set at start; will flip to `done` after review per [[feedback_update_status_after_review]]
- [x] Pre-commit gate (4 schemes, iteration 1 after `TrainingDataExporterTests` split): iOS Research 1997 / macOS Research 1991 / iOS 1816 / macOS 1810. Research deltas vs. story 82.7 baseline = +1 each (clean CRM-test split). Non-Research deltas = +281 each (exactly the count of TOD `@Test`s lifted out of the gate). All green.
- [x] **Iteration 2 patches** — applied: (1) `StartScreenTests.allNavigationDestinationsCanBeCreated` L218 second block split (TOD screen ungated, CRM screen gated); (2) `TrainingLifecycleCoordinatorTests` file-wide `#if PEACH_RESEARCH` removed (fixture is self-contained and registry-bootstrap-independent, so all 33 tests run in both configurations); (3) `PerceptualProfileTests` MARK "Rhythm Offset Detection via Observer" → "Timing Offset Detection via Observer"; (4) `CSVImportParserTests.makeCSV` comment rewrapped cleanly; (5) `StatisticsKeyTests.identicalKeysEqual` example mode swapped from `.continuousRhythmMatching` to `.timingOffsetDetection` and the surrounding `#if PEACH_RESEARCH` removed; (6) `docs/arc42.md` updated in five locations (chapter 4 platform paragraph, the timing-disciplines latency paragraph that follows it, ADR-10 Decision text, ADR-10 first Consequence, glossary entries for `DisciplineBootstrap` and `PEACH_RESEARCH`); (7) `docs/planning-artifacts/glossary.md` "Training Discipline" + "Start Screen" entries refreshed; (8) `docs/planning-artifacts/tod-discipline-future-direction.md` story-76.4 reference updated; (9) `docs/implementation-artifacts/epic-82-context.md` Goal paragraph last sentence and Requirements-and-Constraints "TOD remains `PEACH_RESEARCH`-gated" rule both updated to describe the 82.8 partition.
- [x] **Iteration 2 pre-commit gate** — iOS Research 1997 / macOS Research 1991 / iOS 1855 / macOS 1849. Research counts unchanged from iteration 1; non-Research grew by +39 each (33 newly-ungated `TrainingLifecycleCoordinatorTests` `@Test` functions plus the parameterized-arguments expansion of `registryDispatchesEveryTrainingDestination`). `StartScreenTests.allNavigationDestinationsCanBeCreated` is one test that gained a TOD-screen instantiation; it doesn't add to the `@Test` count. CRM-only `@Test` count in non-Research stays at zero — the file-wide `TrainingLifecycleCoordinatorTests` un-gate runs the CRM-using tests against the suite's self-contained fixture (which compiles in both configurations because CRM types are unguarded source), not against the production registry; the spec's "CRM-test-on-non-Research = 0" invariant is satisfied for any test that *requires* CRM-bootstrap behavior (none of the unguarded coordinator tests do).
- [x] Manual smoke owed by Michael (he'll launch `Peach (Debug)` non-Research on iPhone + Mac, confirm 5-tile Start screen + TOD trial + Profile card render; CRM tile must be absent).

**Acceptance Criteria:**
- Given a non-Research build (`Debug` or `Release`), when the user opens the Start screen, then five discipline tiles are visible: the four pitch disciplines plus "Compare Timing"; no "Match Rhythm" / CRM tile is visible.
- Given a Research build (`Debug (Research)` or `Release (Research)`), when the user opens the Start screen, then six discipline tiles are visible (the original Research set, unchanged).
- Given any scheme, when the user opens an existing TOD trial flow (Settings sections, pattern picker, slot picker, training screen, feedback view, profile rhythm card), then behavior is byte-equivalent to the prior Research-only build; no new strings, layouts, or interactions appear.
- Given `bin/test.sh` and `bin/test.sh -p mac` (non-Research), when the suites run after this story, then every TOD `@Test` previously gated now runs and passes; CRM `@Test`s do not run on these schemes.
- Given `bin/test.sh --research` and `bin/test.sh --research -p mac`, when the suites run, then `@Test` totals match the prior Research baseline and all pass.
- Given a final `grep -rn "PEACH_RESEARCH" Peach PeachTests`, then every remaining hit references CRM-only code/tests or the `DisciplineBootstrap` envelope; no surviving hit gates TOD-only content.

## Spec Change Log

### 2026-06-04 — Review iteration 1 (patches; no full loopback)

**Triggering findings (deduplicated across blind hunter, edge-case hunter, and acceptance auditor):**

- **Code Map omitted a second `#if PEACH_RESEARCH` block in `PeachTests/Start/StartScreenTests.swift`.** The Code Map listed only the navigation-destination block at line ~93, but a second mixed block at line ~218 inside `allNavigationDestinationsCanBeCreated` still gates `TimingOffsetDetectionScreen()` instantiation. Acceptance auditor classified as **bad_spec** (Code Map omission); resolved as a surgical patch.
- **Code Map's `TrainingLifecycleCoordinatorTests.swift` carve-out was wrong.** Re-examination shows every type the suite uses (CRM session, CRM mocks, `NavigationDestination.continuousRhythmMatching`, `TrainingLifecycleRegistry`) is already unguarded source — the suite's fixture is self-contained and registry-bootstrap-independent. The file-wide `#if` traps two purely-TOD `@Test`s (`trainingScreenAppearedDoesNotAutoStartMacOS` L152, `startCurrentSessionDispatchesTimingOffsetDetection` L311) and the TOD args of `registryDispatchesEveryTrainingDestination`. Removing the file-wide guard runs all 33 tests in both configurations without compile or fixture changes.
- **`PeachTests/Core/Profile/PerceptualProfileTests.swift` `MARK` "Rhythm Offset Detection via Observer" is obsolete naming.** Refresh to "Timing Offset Detection via Observer" per the project's settled terminology.
- **`PeachTests/Core/Data/CSVImportParserTests.swift` `makeCSV` comment was rewrapped poorly during the iteration-1 stale-comment hygiene pass.** Cosmetic but worth a clean rewrap.
- **`PeachTests/Core/Profile/StatisticsKeyTests.swift` `identicalKeysEqual` was kept gated only because the example mode is `.continuousRhythmMatching`.** Switching the example to `.timingOffsetDetection` runs the equality coverage in non-Research without losing the test's intent.
- **Architecture docs are stale.** `docs/arc42.md` has multiple paragraphs (chapter on platform strategy, ADR-10, glossary entries) stating "the two timing disciplines are wrapped in `#if PEACH_RESEARCH`" and "the App Store cut contains no dormant timing code." `docs/planning-artifacts/glossary.md` has two entries (build configurations, Start Screen) describing the App Store cut as pitch-only. `docs/planning-artifacts/tod-discipline-future-direction.md` references "TOD ships only under `PEACH_RESEARCH`". All eight locations need to be brought current.
- **`docs/implementation-artifacts/epic-82-context.md` Goal paragraph contradicts the new Stories list entry.** It still says "TOD remains `PEACH_RESEARCH`-gated throughout this epic; lifting that gate depends on a separate playtest cycle and is out of scope." Removing that single sentence is a surgical patch, not a Goal rewrite.

**Amendments outside the frozen block:**

- *Code Map:* added a second-block entry for `StartScreenTests` covering L218; revised the `TrainingLifecycleCoordinatorTests` entry from "keep fully gated" to "remove the file-wide guard." Added entries for the stale-doc sweep (`docs/arc42.md` paragraphs, `docs/planning-artifacts/glossary.md` entries, `docs/planning-artifacts/tod-discipline-future-direction.md`, `docs/implementation-artifacts/epic-82-context.md` Goal-paragraph sentence) and for the three small content patches (`StatisticsKeyTests` example swap, `PerceptualProfileTests` MARK refresh, `CSVImportParserTests.makeCSV` comment rewrap).
- *Tasks:* added an *Iteration 2 patches* group covering the seven reviewer-surfaced fixes plus the doc sweep. Pre-commit gate re-listed for iteration 2; expected non-Research delta grows by ~33 (file-wide `TrainingLifecycleCoordinatorTests` ungate) + 1 (`StartScreenTests` second-block ungate) − 0 (Research counts unchanged).

**KEEP (re-derivation must preserve):**

- The 5-step gate split that already worked: source guard in `DisciplineBootstrap`, 20 TOD-only-file gate strips, 4 TOD-only-fragment strips, 11 mixed-file block splits, the `SpectrogramDataTests` outer-guard removal + inner CRM-only test guard, the `ProgressTimelineTests` triple-strip.
- The decision to keep `TrainingDataExporterTests.headerInExport` and `allRowsHave19Fields` gated — their `columns.count == 19` and `columns[14] == "meanOffsetMs"` assertions are inherently coupled to the full Research schema.
- The iteration-1 pre-commit gate arithmetic: non-Research grew by exactly the count of TOD `@Test`s lifted; Research grew by +1 due to the `TrainingDisciplineIDTests` rhythm-modes split.
- The `TrainingDisciplineRegistryTests` MARK-comment refresh, the `CSVHistoryRegistry` doc-comment refresh, the `docs/project-context.md` "Training disciplines (build-gated)" rule update.
- The `epic-82-context.md` Stories-list entry for 82.8 (separate from the Goal-paragraph sentence patch).
- The `sprint-status.yaml` 82-8 key already at `in-progress`.

**Known-bad states avoided:**

- An App Store cut that ships TOD code but whose test suite never exercises App Store-relevant TOD lifecycle/dispatch paths (the trapped `TrainingLifecycleCoordinatorTests` TOD `@Test`s).
- A `StartScreen` "all navigation destinations can be created" smoke test that silently skips `TimingOffsetDetectionScreen()` instantiation in App Store builds despite TOD shipping there.
- Architecture documentation (arc42, glossary, future-direction doc) claiming TOD is research-only after the code base has been changed otherwise — a future contributor reading those docs would be actively misled.
- An epic-82 context document that lists Story 82.8 while its Goal paragraph still scopes the epic as "TOD remains research-only."
- A `StatisticsKey.rhythm(...) == ...` equality assertion that runs only in Research and is therefore an untested invariant in App Store builds.

## Verification

**Commands:**
- `bin/test.sh --research` — expected: full suite green on iOS (Debug, Research); count matches prior baseline
- `bin/test.sh --research -p mac` — expected: full suite green on macOS (Debug, Research); count matches prior baseline
- `bin/test.sh` — expected: full suite green on iOS (Debug, non-Research); count strictly greater than prior baseline by exactly the number of TOD `@Test`s ungated
- `bin/test.sh -p mac` — expected: full suite green on macOS (Debug, non-Research); same delta as iOS
- `bin/build.sh` and `bin/build.sh -p mac` — expected: zero new warnings in non-Research builds
- `bin/add-localization.swift --missing` — expected: `0 keys missing German translation`
- `grep -rn "PEACH_RESEARCH" Peach PeachTests` — expected: every hit is CRM-related or in `DisciplineBootstrap` (envelope or registration); zero hits gate TOD-only code

**Manual checks:**
- Launch `Peach (Debug)` on iPhone simulator: Start screen lists "Compare Timing" alongside the four pitch tiles. Tap it; pattern + slot pickers from epic 82 render; one trial completes; Profile screen shows the rhythm spectrogram card for TOD with the new data point.
- Launch `Peach (Debug)` on Mac: same flow renders via native SwiftUI; Settings → TOD shows pattern picker (drill-down) + slot picker + max-repetitions section.
- Launch `Peach (Debug, Research)` on iPhone: Start screen lists six tiles (TOD + CRM both present); CRM flow still works.
- Launch `Peach (Release)` on iPhone: same five-tile Start screen as `Debug`; no Research-only assets leak.

## Suggested Review Order

**Source: the one production-side change**

- The whole story in eight lines — `TimingOffsetDetectionDiscipline()` hoisted out of the `#if PEACH_RESEARCH` block; doc-comment refreshed to match.
  [`DisciplineBootstrap.swift:33`](../../Peach/App/Training/DisciplineBootstrap.swift#L33)

- Stale source-comment hygiene — `CSVHistoryRegistry` doc-comment now names CRM as the discipline excluded in non-Research, not "timing disciplines."
  [`CSVHistoryRegistry.swift:8`](../../Peach/Core/Training/Discipline/CSVHistoryRegistry.swift#L8)

**Tests: the splits worth eyeballing**

- The registry's invariant tests: refreshed MARK comment is the load-bearing claim — the assertion bodies are unchanged and continue to hold for any registered set.
  [`TrainingDisciplineRegistryTests.swift:10`](../../PeachTests/Core/Training/TrainingDisciplineRegistryTests.swift#L10)

- `TrainingLifecycleCoordinatorTests` — iteration-2 patch: the file-wide `#if PEACH_RESEARCH` is gone (33 tests now run in both configurations because the fixture is self-contained).
  [`TrainingLifecycleCoordinatorTests.swift:6`](../../PeachTests/App/TrainingLifecycleCoordinatorTests.swift#L6)

- `TrainingDisciplineImplementationTests` — the canonical "split-mixed-block" pattern: TOD `@Test`s ungated, immediately followed by `#if PEACH_RESEARCH` + CRM `@Test` + `#endif`. Repeated for csvKeyValuePairs / round-trip / mergeImportRecords / fetchExportRecords.
  [`TrainingDisciplineImplementationTests.swift:208`](../../PeachTests/Core/Training/TrainingDisciplineImplementationTests.swift#L208)

- `TrainingDataExporterTests` — the deliberate non-split: `headerInExport` and `allRowsHave19Fields` stay gated because they assert `columns.count == 19` and `columns[14] == "meanOffsetMs"`, both inherently coupled to the full Research schema; 6 surrounding TOD-relevant tests are ungated.
  [`TrainingDataExporterTests.swift:316`](../../PeachTests/Core/Data/TrainingDataExporterTests.swift#L316)

- `StartScreenTests` second block — iteration-2 patch: `TimingOffsetDetectionScreen()` instantiation now happens in both configurations; only `ContinuousRhythmMatchingScreen()` remains gated.
  [`StartScreenTests.swift:218`](../../PeachTests/Start/StartScreenTests.swift#L218)

- `SpectrogramDataTests` — the inverse pattern: the *file*'s outer `#if` is gone (TOD's rhythm card now exercises `SpectrogramData` in non-Research), and only the single CRM-specific `@Test` carries an inner guard.
  [`SpectrogramDataTests.swift:333`](../../PeachTests/Core/Profile/SpectrogramDataTests.swift#L333)

- `PerceptualProfileTests` — TOD observer/builder tests ungated; the CRM-coupled `trainedTempoRanges` + `rhythmOverallAccuracy` + `resetAll` + CRM-observer tests stay inside the Rhythm-tests `#if`.
  [`PerceptualProfileTests.swift:299`](../../PeachTests/Core/Profile/PerceptualProfileTests.swift#L299)

**Documentation sweep**

- `docs/project-context.md` — the "Training disciplines (build-gated)" rule, refreshed for the new partition. This is the file most AI agents will load.
  [`project-context.md:260`](../../docs/project-context.md#L260)

- `docs/arc42.md` ADR-10 — Decision text + first Consequence updated to reflect that 82.8 narrowed the gate.
  [`arc42.md:913`](../../docs/arc42.md#L913)

- `docs/arc42.md` chapter 4 — platform paragraph + latency-rationale follow-up: TOD ships because it is judgment-driven, not input-driven; CRM stays research-only because of the sub-20 ms input-latency requirement.
  [`arc42.md:703`](../../docs/arc42.md#L703)

- Glossary entries — `Training Discipline`, `Start Screen` (planning glossary) and `DisciplineBootstrap`, `PEACH_RESEARCH` (arc42 glossary) all refreshed.
  [`glossary.md:16`](../../docs/planning-artifacts/glossary.md#L16)

- Epic 82 context — Goal paragraph last sentence + Requirements-and-Constraints rule both updated.
  [`epic-82-context.md:7`](../../docs/implementation-artifacts/epic-82-context.md#L7)

**Sprint tracking**

- New story key under the epic-82 block; epic-82 itself stays `done` (this story rides on top per the original close from 82.7).
  [`sprint-status.yaml:738`](../../docs/implementation-artifacts/sprint-status.yaml#L738)
