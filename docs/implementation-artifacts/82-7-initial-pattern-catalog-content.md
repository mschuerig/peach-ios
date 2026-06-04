---
title: 'Story 82.7: Ship the initial pattern catalog content'
type: 'feature'
created: '2026-06-04'
status: 'done'
baseline_commit: '78bbb69bf4d995491d3049bcbe452de958261612'
context:
  - '{project-root}/docs/planning-artifacts/tod-initial-pattern-catalog.md'
  - '{project-root}/docs/implementation-artifacts/epic-82-context.md'
  - '{project-root}/docs/implementation-artifacts/82-6-pattern-and-slot-picker-settings-ui.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `TimingOffsetDetectionPatternCatalog.all` still ships with `pattern_1111` as its only entry. The pattern-aware Settings UI from 82.6 renders a single-row picker; the catalog invariants (metric anchor excluded from `pickable`, default-is-pickable, unique ids) are exercised only against that one entry; and the rest-aware / single-pickable paths in `TimingDotView`, the pattern picker section, and the slot picker section are proven only by transient test fixtures (`TimingOffsetDetectionPatternFixtures`, ids `pattern_test_1011` / `pattern_test_1010`). Research users see no benefit from epic 82's catalog/wrapper work until the four remaining curated patterns ship.

**Approach:** Add the four catalog entries from `tod-initial-pattern-catalog.md` § *Catalog* (`pattern_1011`, `pattern_1101`, `pattern_1010`, `pattern_1001`) as static properties on `TimingOffsetDetectionPattern`, register them in `TimingOffsetDetectionPatternCatalog.all` in the design-doc's display order, and replace the test fixtures with the production patterns (same shape, real ids) at the three test call sites. Per-entry unit tests pin id, default, audible/grid shape, and beat-builder offset placement for each new pattern; the catalog-wide invariant tests from 82.5 automatically cover the new entries via their `for pattern in all` loops. No engine, Settings UI, view, or `@AppStorage` schema changes — the picker iterates `all`, so the entries appear in the UI by registration alone. No new user-facing strings (no per-pattern display names; the visual *is* the pattern's identity).

## Boundaries & Constraints

**Always:**
- Four new statics on `TimingOffsetDetectionPattern`: `pattern1011`, `pattern1101`, `pattern1010`, `pattern1001`. Each carries `id` matching the `pattern_NNNN` notation-mask convention (MSB = grid position 1), `subdivisions` per the catalog table (`.note(velocity: RhythmVelocity.accent, offset: .zero)` at grid 0, `.note(velocity: RhythmVelocity.normal, offset: .zero)` at other audible grid positions, `.rest` at silent grid positions), and `defaultOffsetNotePosition` per the table (`pattern_1011 → 2`, `pattern_1101 → 2`, `pattern_1010 → 2`, `pattern_1001 → 2`).
- `TimingOffsetDetectionPatternCatalog.all` lists exactly five entries in display order: `[.pattern1111, .pattern1011, .pattern1101, .pattern1010, .pattern1001]`. `defaultPatternId` stays `"pattern_1111"` (migration target).
- Per-entry rationale from `tod-initial-pattern-catalog.md` § *Per-entry default reasoning* is preserved as the doc comment on each new static, so future agents can read why each default was picked without chasing the design doc.
- Tests use the production statics. `TimingOffsetDetectionPatternFixtures` is deleted; the three test files that referenced `.pattern1011` / `.pattern1010` fixtures (`TimingDotViewTests`, `TimingOffsetDetectionPatternPickerSettingsSectionTests`, `TimingOffsetDetectionOffsetNotePositionSettingsSectionTests`) point to `TimingOffsetDetectionPattern.pattern1011` / `.pattern1010` instead. Assertions stay shape-based (audibleToGrid, pickable, cell classification, accessibility label); no test asserts the test-prefixed id.
- `TimingOffsetDetectionPatternCatalogTests` is updated: `allContainsOnlyPattern1111` is renamed and rewritten to assert the five-entry list and order; the two invariant tests (`everyPatternExcludesMetricAnchorFromPickable`, `everyPatternDefaultIsPickable`, `everyPatternIdIsUnique`) are unchanged in shape — they iterate `all` and gain coverage automatically.
- One parametrized per-entry test per new pattern verifies (a) `audibleToGrid` matches the catalog table, (b) `pickable` matches, (c) `defaultOffsetNotePosition` matches, (d) `beat(offsetNotePosition: default, offsetAmount: .milliseconds(N))` produces a `Beat` whose `.note` at `audibleToGrid[default - 1]` carries the offset and every other subdivision is `.zero` / `.rest` preserved.
- Doc comment on `TimingOffsetDetectionPatternCatalog.all` is updated: drop the "82.5 registers only" / "82.7 adds" wording and state that the five catalog entries from `tod-initial-pattern-catalog.md` are registered in display order.
- TOD remains `PEACH_RESEARCH`-gated. All new tests live under `#if PEACH_RESEARCH` (the surrounding files already are).
- Sprint-status key `82-7-initial-pattern-catalog-content` flips to `in-progress` on start and `done` after review per [[feedback_update_status_after_review]]. `epic-82` flips to `done` in the same status update.
- Pre-commit gate: `bin/test.sh --research && bin/test.sh --research -p mac && bin/test.sh && bin/test.sh -p mac` — all four green before any commit per [[feedback_test_sh_no_parallel]].

**Ask First:**
- If a per-entry test reveals that the beat builder's `precondition(pickable.contains(offsetNotePosition.rawValue))` traps for one of the single-pickable patterns when its only pickable position is passed in (theoretically impossible given the default == pickable invariant test, but worth flagging if it ever fires), halt before relaxing the precondition. **Default plan: the precondition stands; the trap means the catalog entry is misregistered, which should fail fast.**

**Never:**
- No engine edits. `Beat` / `Subdivision` / `SoundFontStepSequencer` / `SoundFontBeatSequencer` stay untouched.
- No edits to `TimingOffsetDetectionPattern` or `TimingOffsetDetectionPatternCatalog` *types* — only new statics and a doc-comment refresh. The wrapper / registry shape is locked from 82.5.
- No edits to `TimingOffsetDetectionOffsetNotePositionSettingsSection`, `TimingDotView`, or `TimingOffsetDetectionScreen`. These iterate `all` or consume a `TimingOffsetDetectionPattern` parameter; registration alone is the integration point.
- *(Renegotiated 2026-06-04 — see Spec Change Log entries 1 and 2.)* The pattern picker section may change its chrome from `.pickerStyle(.inline)` to a `NavigationLink` drill-down — the Settings row collapses to label + dot-row preview + chevron and tapping drills into a dedicated screen with the inline picker. Cascade logic, accessibility-label derivation, the static-helper signatures, and per-row dot-preview vocabulary stay locked.
- No per-pattern `LocalizedStringResource` display names. No localized strings added or modified (`bin/add-localization.swift --missing` must remain at `0`).
- No `@AppStorage` schema changes. `selectedPatternId` and `offsetNotePosition` keys are unchanged. No migration shim; existing `pattern_1111` users with stored `offsetNotePosition ∈ {2, 3, 4}` round-trip unchanged, stored `1` clamps to `3` (locked by 82.5).
- No `Section` chrome (Straight / Gapped headers) in the picker. Flat single-section presentation per [tod-initial-pattern-catalog.md § *Categorization*](../planning-artifacts/tod-initial-pattern-catalog.md#categorization). Design doc preserves the categorization rule for future agents; UI ships flat.
- No tuplet patterns. The catalog domain layer is tuplet-capable by construction (it wraps `Beat`), but the renderer is equal-cell and the four shipped entries are flat.
- No new patterns beyond the four named here. Adding a sixth requires a follow-up story; the catalog table in the design doc is the contract.
- No `OffsetNotePosition.validRange` change. The widest registered pattern (`pattern_1111`) has `audibleCount == 4`; `validRange = 1...4` covers every entry. Widening waits for a future K > 4 pattern.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Catalog registration | `TimingOffsetDetectionPatternCatalog.all` after 82.7 | `[pattern1111, pattern1011, pattern1101, pattern1010, pattern1001]` in that order | N/A |
| `pattern_1011` beat builder, default position | `pattern_1011.beat(offsetNotePosition: OffsetNotePosition(2), offsetAmount: .milliseconds(20))` | 4 subdivisions: accent note at 0 (zero offset), rest at 1, normal note at 2 (offset 20ms), normal note at 3 (zero offset) | N/A |
| `pattern_1101` beat builder, position 3 | `pattern_1101.beat(offsetNotePosition: OffsetNotePosition(3), offsetAmount: .milliseconds(15))` | accent note at 0 (zero), normal note at 1 (zero), rest at 2, normal note at 3 (offset 15ms) | N/A |
| `pattern_1010` beat builder, only pickable | `pattern_1010.beat(offsetNotePosition: OffsetNotePosition(2), offsetAmount: .milliseconds(10))` | accent at 0 (zero), rest at 1, normal at 2 (offset 10ms), rest at 3 | N/A |
| `pattern_1001` beat builder, only pickable | `pattern_1001.beat(offsetNotePosition: OffsetNotePosition(2), offsetAmount: .milliseconds(10))` | accent at 0 (zero), rest at 1, rest at 2, normal at 3 (offset 10ms) | N/A |
| Single-pickable pattern, illegal position | `pattern_1010.beat(offsetNotePosition: OffsetNotePosition(3), …)` | `precondition` trap — audible position 3 is out of `pickable = {2}` | trap (programmer error) |
| Stored unknown id resolves to default | `selectedPatternId = "pattern_xxxx"` (corrupt UserDefaults) | `pattern(forStoredId:)` returns `pattern_1111`; `offsetNotePosition` clamped to its default via existing read path | N/A — locked by 82.5 |
| `pattern_1011` selected via picker (cascade) | User taps `pattern_1011` row | `selectedPatternId = "pattern_1011"`, `offsetNotePosition = 2` (new pattern's default) | N/A — handled by existing `cascadeWrites(forNewId:)` |
| `audibleToGrid` shape across new entries | derived in `init` | `pattern_1011 → [0, 2, 3]`, `pattern_1101 → [0, 1, 3]`, `pattern_1010 → [0, 2]`, `pattern_1001 → [0, 3]` | N/A |
| Catalog invariants — every new entry | `for p in all` | `p.pickable.contains(1) == false`; `p.pickable.contains(p.defaultOffsetNotePosition.rawValue) == true`; `p.id` unique across `all` | N/A — existing tests cover automatically |

</frozen-after-approval>

## Code Map

- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPattern.swift` — Add four `static let` properties in the existing `extension TimingOffsetDetectionPattern { … }` block (currently holds only `pattern1111`). Each carries the `[Subdivision]` template per the catalog table plus the per-entry rationale as a leading doc comment. No other changes; the type, init, beat builder, and clamp logic are unchanged.
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPatternCatalog.swift` — Extend `all` from `[.pattern1111]` to `[.pattern1111, .pattern1011, .pattern1101, .pattern1010, .pattern1001]`. Refresh the doc comment on `all` to drop the 82.5/82.7 staging note and describe the five entries in terms of the design-doc table.
- `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionPatternCatalogTests.swift` — Rename `allContainsOnlyPattern1111` to `allListsFiveCatalogEntriesInDisplayOrder` and rewrite to assert the five-element list (count + per-position equality). The invariant tests (`everyPatternExcludesMetricAnchorFromPickable`, `everyPatternDefaultIsPickable`, `everyPatternIdIsUnique`) are unchanged. Keep the `defaultPatternId`, `defaultPattern`, `pattern(withId:)`, and `pattern(forStoredId:)` tests as-is.
- `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionPatternTests.swift` — Add one parametrized `@Test("each new catalog entry exposes the expected shape", arguments: [...])` test covering `pattern_1011`, `pattern_1101`, `pattern_1010`, `pattern_1001`: asserts `id`, `audibleToGrid`, `audibleCount`, `pickable`, `defaultOffsetNotePosition`, `subdivisions.count`. Add one parametrized beat-builder test verifying the offset lands at `pattern.audibleToGrid[default - 1]` for each new entry. Keep the existing `pattern1111Identity`, `pickable…`, `clampedOffsetNotePosition…`, and `beatPreservesRests` tests.
- `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionPatternFixtures.swift` — **DELETE.** Production patterns of identical shape now ship in the catalog; the test-prefixed fixtures are redundant.
- `PeachTests/Training/TimingOffsetDetection/TimingDotViewTests.swift` — Replace `TimingOffsetDetectionPatternFixtures.pattern1011` / `.pattern1010` references with `TimingOffsetDetectionPattern.pattern1011` / `.pattern1010`. Tests stay shape-based (the audible→grid translation assertions are unchanged).
- `PeachTests/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSectionTests.swift` — Replace fixture references with production statics. The accessibility-label tests (`labelForRestBearingPattern`, `labelForSinglePickablePattern`) assert the same structural output (`"Accent, Rest, Note, Note"` / `"Accent, Rest, Note, Rest"`) and are unchanged in behavior.
- `PeachTests/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionOffsetNotePositionSettingsSectionTests.swift` — Replace fixture references with production statics. `pattern1011AllCells` and `pattern1010AllCells` keep their shape assertions; rename the MARK comments to drop the `_test_` suffix. Add `pattern1101AllCells` and `pattern1001AllCells` to cover the remaining two new entries (edge-case-hunter finding 3).
- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift` — Replace the inline `Picker` with a `NavigationLink` whose label is `LabeledContent("Pattern") { row(for: activePattern) }`. NavigationLink's destination is a private `TimingOffsetDetectionPatternPickerDestination` view — a separate `Form` with `Section { Picker(...).pickerStyle(.inline).labelsHidden() }`, `.platformFormStyle()`, `.navigationTitle("Pattern")`, `.inlineNavigationBarTitle()`. The destination receives the same `patternIdBinding` so the cascade-write rule survives unchanged. `.accessibilityValue(...)` on the trigger row announces the current selection's structural label. Footer copy unchanged.
- `docs/implementation-artifacts/sprint-status.yaml` — Flip `82-7-initial-pattern-catalog-content` to `in-progress` on start and `done` after review. Flip `epic-82` from `in-progress` to `done` in the **same** post-review status update (acceptance-auditor finding 1).

## Tasks & Acceptance

**Execution:**
- [x] `TimingOffsetDetectionPattern.swift` — add `pattern1011`, `pattern1101`, `pattern1010`, `pattern1001` statics with per-entry doc comments
- [x] `TimingOffsetDetectionPatternCatalog.swift` — register the four new entries in `all`; refresh `all`'s doc comment
- [x] `TimingOffsetDetectionPatternCatalogTests.swift` — rewrite the count/order test for five entries
- [x] `TimingOffsetDetectionPatternTests.swift` — add parametrized shape + beat-builder tests for the four new entries (arguments stay pure-value; lookup via catalog inside the test body to avoid MainActor-isolation leak through `arguments:`)
- [x] `TimingOffsetDetectionPatternFixtures.swift` — deleted
- [x] `TimingDotViewTests.swift` — migrate fixture references to production statics
- [x] `TimingOffsetDetectionPatternPickerSettingsSectionTests.swift` — migrate fixture references to production statics
- [x] `TimingOffsetDetectionOffsetNotePositionSettingsSectionTests.swift` — migrate fixture references to production statics
- [x] `sprint-status.yaml` — flipped `82-7-…` to `in-progress`
- [x] Pre-commit gate (4 schemes green, iteration 1): iOS Research 1990 / macOS Research 1984 / iOS 1535 / macOS 1529; `bin/add-localization.swift --missing` reports 0
- [x] Manual smoke (iteration 1): launch `Peach (Debug, Research)`; Settings → TOD → **Pattern** section now shows five rows; tapping each row updates the selection chrome and resets the slot picker to the new pattern's default — confirmed on iPhone by Michael
- [x] **Iteration 2 patches** — applied (1) catalog-doc-grouping fix [blind hunter 1], (2) `pattern_1101` rationale wording aligned with design doc verbatim [blind hunter 2], (3) extra cell-classification tests for `_1101` / `_1001` [edge-case 3], (4) extra accessibility-label tests for `_1101` / `_1001` [edge-case 4], (5) non-default position coverage for `_1011` / `_1101` beat builder [edge-case 6 / acceptance 3], (6) tautological `audibleCount` assertion replaced with literal [edge-case 7]
- [x] **Iteration 2 chrome change** — `TimingOffsetDetectionPatternPickerSettingsSection`: replaced `.pickerStyle(.inline)` with a `NavigationLink` whose label is `LabeledContent("Pattern") { current-pattern dot-row }`. The destination is a new private `TimingOffsetDetectionPatternPickerDestination` view (Form + inline Picker + `.platformFormStyle()` + `.inlineNavigationBarTitle()`). Trigger row vends `.accessibilityValue(...)` so VoiceOver announces the active pattern's structural label. **(First attempt used `.pickerStyle(.menu)` per the initial renegotiation; SwiftUI's `.menu` style stripped the custom `View` row labels, leaving only the checkmark. Switched to NavigationLink — see Spec Change Log entry 2.)**
- [x] **Iteration 2 pre-commit gate** — iOS Research 1996 / macOS Research 1990 / iOS 1535 / macOS 1529; `bin/add-localization.swift --missing` reports 0 (re-run after the NavigationLink swap)
- [x] **Iteration 2 manual smoke** — Settings → TOD → Pattern row shows "Pattern" + dot-row preview of the current pattern + chevron; tapping drills into a screen titled "Pattern" with the five-entry inline picker; selecting an entry pops back and updates the Settings row's trailing dot-row + resets the slot picker — confirmed on iPhone by Michael

**Acceptance Criteria:**
- Given a Research build with default Settings, when the user opens the Pattern picker, then five rows are visible in the order `pattern_1111`, `pattern_1011`, `pattern_1101`, `pattern_1010`, `pattern_1001`, each with the correct dot-row preview (anchor + audible-position dots + empty cells for rests).
- Given the user taps the `pattern_1010` row, when the cascade fires, then `selectedPatternId = "pattern_1010"`, `offsetNotePosition = 2`, the slot picker renders `(anchor, rest, pickable[selected], rest)`, and the training-screen `TimingDotView` lights the doubled-glyph indicator at grid index 2.
- Given a corrupt stored `selectedPatternId = "pattern_xxxx"`, when the Settings screen renders, then the picker shows `pattern_1111` as selected (via the existing `pattern(forStoredId:)` fallback); no test assertion or production code path changes from 82.6.
- Given the catalog-wide invariant tests, when run against the five-entry catalog, then `pattern.pickable.contains(1) == false` for every entry, `pattern.defaultOffsetNotePosition.rawValue ∈ pattern.pickable` for every entry, and all five ids are unique.
- Given `bin/add-localization.swift --missing`, when run after this story, then `0 keys missing German translation` (no new strings were added).
- Both pre-commit gates pass on iOS and macOS for both Research and non-Research schemes.

## Spec Change Log

### 2026-06-04 — Review iteration 1 (patches + renegotiated chrome; no full loopback)

**Triggering findings (deduplicated across blind hunter / edge case hunter / acceptance auditor):**

- **Catalog `all` doc-comment categorization order mismatches array order.** The comment grouped entries semantically (`pattern_1010` as *Straight 8ths*, listed after the *Gapped* trio), but the array literal is in design-doc display order `[pattern_1111, pattern_1011, pattern_1101, pattern_1010, pattern_1001]`. A future reader skim-reading the comment for the display order is misled.
- **`pattern_1101` doc-comment rationale paraphrases the design doc instead of quoting it.** The implementation said "equidistant from the metric midpoint"; the design doc § *Per-entry default reasoning* says "equidistant from the rest at grid 3" (1-based). Same meaning, but the spec rule is "preserved … verbatim or in equivalent words" and the design-doc phrasing is more concrete.
- **Cell-classification tests cover only `_1011` and `_1010` of the four new entries.** `_1101` (audibleToGrid `[0, 1, 3]`, the early-audible-not-rest mapping) and `_1001` (single-pickable with two consecutive rests) have no per-cell classification test. A regression in `cellKind` for either shape would not trip.
- **Pattern-picker accessibility-label tests cover only `_1011` and `_1010`.** `_1101` and `_1001` accessibility strings are locked by the design doc § *Preview Rendering* table but unverified.
- **Parametrized beat-builder test only exercises each new entry at its `defaultOffsetNotePosition`.** Spec I/O matrix lists `pattern_1101.beat(offsetNotePosition: 3, …)` explicitly; the audible-3 → grid-3 translation that skips the rest at grid 2 is the most likely regression target and isn't pinned.
- **`#expect(pattern.audibleCount == expectation.audibleToGrid.count)` is tautological.** `audibleCount` is defined as `audibleToGrid.count` on the type; the assertion can never fail and offers no coverage. Replace with a literal expected count.
- **`sprint-status.yaml` change rule requires paired `epic-82 → done` flip.** The spec's *Always* rule said "`epic-82` flips to `done` in the same status update" as the story's `done` flip; the iteration-1 manual checklist didn't reaffirm that pairing. Cosmetic but worth carrying through.

**Triggering renegotiation (human, not reviewer-surfaced):**

- **Pattern-picker chrome consumes too much vertical space as the catalog grows.** With five rows shipping now and the catalog set to expand further (longer-than-beat patterns, future K=6/K=8 entries), the inline picker dominates Settings. Michael renegotiated the frozen-block *Never* item that prohibited edits to `TimingOffsetDetectionPatternPickerSettingsSection`; the lift permits a `.pickerStyle(.inline) → .pickerStyle(.menu)` swap so the section collapses to one row that opens a menu on tap.

**Amendments outside the frozen block:**

- *Code Map:* added a `TimingOffsetDetectionPatternPickerSettingsSection.swift` entry describing the `.menu`-style swap + the `header:` → `Picker` label promotion.
- *Code Map:* extended the slot-picker test entry to add `_1101` and `_1001` cell-classification tests.
- *Tasks:* added an *Iteration 2 patches* group covering the six reviewer-surfaced fixes plus an *Iteration 2 chrome change* group covering the picker style swap. Pre-commit gate and manual smoke re-listed for iteration 2.

**Amendment inside the frozen block (Michael-authorized renegotiation only):**

- *Never:* removed the picker section from the "no edits" list; added a parenthetical pointer to this change-log entry and a positive locking constraint that cascade logic, accessibility-label derivation, static-helper signatures, and per-row dot-preview vocabulary all stay locked.

**KEEP (re-derivation must preserve):**

- The five-entry catalog in display order `[pattern_1111, pattern_1011, pattern_1101, pattern_1010, pattern_1001]` per the design doc table.
- The four new statics' subdivisions / defaults exactly as the design doc table specifies.
- Each new static's per-entry doc-comment rationale, faithfully tracking § *Per-entry default reasoning* (verbatim or in equivalent words; the `_1101` patch tightens to "equidistant from the rest at grid 3").
- The deleted `TimingOffsetDetectionPatternFixtures` and the three migrated test consumers using production statics.
- The parametrized-test pattern with pure-value `arguments:` and catalog lookup inside the test body — avoids the MainActor-isolation leak Swift Testing's macro caused.
- Cascade-write logic (atomic id + position) and the static `cascadeWrites(forNewId:)` helper from 82.6 iteration 1.
- `patternRowAccessibilityLabel(for:)` derives structurally from `subdivisions`; no per-pattern display name field.
- The picker still reads `TimingOffsetDetectionPatternCatalog.all` (untouched by the chrome change); registration is the only integration point for new entries.

**Known-bad states avoided:**

- A future reader trusting the catalog `all` doc-comment for display order and getting `1111 / 1011 / 1101 / 1001 / 1010` instead of the real `1111 / 1011 / 1101 / 1010 / 1001`.
- A `pattern_1101` future revision shifting the default to audible 3 (the *other* equidistant candidate) without surfacing the tie rationale in the code comment.
- Silent regressions in `cellKind` and accessibility-label derivation for `_1101` / `_1001` after a future contributor refactors the static helpers.
- A future pattern-shape change that drops the audible count without the parametrized test catching it (the tautological assertion would still pass).
- Pattern picker dominating Settings vertical space as the catalog grows past five entries.
- A `done` flip for `82-7-…` without the matched `epic-82 → done` flip in the same yaml write.

### 2026-06-04 — Iteration 2 chrome pivot (`.menu` → `NavigationLink`)

**Triggering finding (manual smoke, iPhone):**

- **`.pickerStyle(.menu)` strips custom `View` row labels.** The first iteration of the renegotiated chrome used `.pickerStyle(.menu)` with the existing dot-row preview as each `Picker` option's label. SwiftUI's `.menu` style coerces option labels to text-only on iOS; the dot-row was invisible in the dropdown and only the checkmark remained on the selected row. Confirmed on iPhone — "The only thing that's visible is the checkmark. The pattern is not visible."

**Renegotiation:**

- Michael selected the `NavigationLink` drill-down approach: Settings row shows label + current-pattern dot-row + chevron; tap drills into a dedicated screen with the inline picker preserved. Idiomatic iOS-Settings pattern for `n`-option choosers; scales to any catalog size without label-rendering quirks.

**Amendments outside the frozen block:**

- *Code Map:* swapped the `.pickerStyle(.menu)` line for the NavigationLink + `TimingOffsetDetectionPatternPickerDestination` description; documented the destination's `Form` + inline `Picker` + `.platformFormStyle()` + `.inlineNavigationBarTitle()` shape.
- *Tasks:* annotated the chrome-change task with the `.menu` → NavigationLink pivot and updated the manual-smoke description to the drill-down walk.

**Amendment inside the frozen block (Michael-authorized renegotiation):**

- *Never:* updated the renegotiation pointer to reference Spec Change Log entries 1 *and* 2; replaced "`.pickerStyle(.menu)`" with "NavigationLink drill-down" in the locked description.

**KEEP (re-derivation must preserve):**

- The destination view exists as a private struct, not as additional surface on the section view.
- The destination receives `patternIdBinding` (the same atomic cascade binding the section already exposed) — there's no second cascade implementation.
- The trigger row's `.accessibilityValue(...)` carries `patternRowAccessibilityLabel(for: activePattern)` so VoiceOver announces the current selection structurally on the Settings screen without drill-in.
- The destination uses `.platformFormStyle()` and `.inlineNavigationBarTitle()` (existing cross-platform helpers from `App/Platform/PlatformModifiers.swift`) so macOS Settings inherits the same idiom.
- The destination's `Picker` keeps the `Section { … }` wrapper so list grouping renders consistently with the rest of the Settings form.

**Known-bad states avoided:**

- Picker rows on the destination collapsing to text labels (would re-introduce the `.menu` failure mode — the inline-style picker preserves custom `View` labels).
- A second cascade-write path appearing on the destination (would split the locked invariant from 82.6 iteration 1 across two surfaces).
- macOS Settings rendering with default form styling while iOS uses grouped — `.platformFormStyle()` keeps them aligned.

## Design Notes

**Why per-entry rationale lives in the doc comment, not the design doc only.** A future agent adding catalog entry six or removing an existing one will read the code, not (necessarily) `tod-initial-pattern-catalog.md`. Pinning the per-pattern default rationale (`pattern_1011 → 2: closest analogue to the Straight default — on the half-beat`) to the static itself keeps the why-this-default knowledge co-located with the data. Verbatim copy from the design doc § *Per-entry default reasoning*; design-doc remains the source of truth.

**Why delete the fixtures instead of keeping them as test scaffolding.** The fixtures' value was "exercise rest-aware / single-pickable paths before the production catalog has rest patterns." After 82.7 the production catalog *is* that fixture: `pattern_1011` and `pattern_1010` have identical shapes. Keeping the fixtures duplicates test data, splits the source of truth (a future shape change to either entry would require touching both places), and obscures that these tests now reflect production behavior. The migration is mechanical — the existing tests don't assert on the fixture id.

**Why parametrized tests over four near-identical test functions.** The four new entries differ only in their `subdivisions` array and `audibleToGrid` shape. A single `@Test(arguments: …)` over a `(pattern, expectedAudibleToGrid, expectedPickable, expectedDefault)` tuple captures all four without copy-paste. The catalog-wide invariant tests already iterate `all`; the parametrized per-entry tests cover the shape claims the invariants don't.

## Verification

**Commands:**
- `bin/test.sh --research` — expected: full suite green on iOS (Debug, Research); 5-entry catalog tests pass
- `bin/test.sh --research -p mac` — expected: full suite green on macOS (Debug, Research)
- `bin/test.sh` — expected: full suite green on iOS (Debug, non-Research); TOD code is `PEACH_RESEARCH`-gated so the new tests are excluded — the non-Research build must still compile cleanly with the catalog changes
- `bin/test.sh -p mac` — expected: full suite green on macOS (Debug, non-Research)
- `bin/build.sh --research` — expected: zero new warnings
- `bin/add-localization.swift --missing` — expected: `0 keys missing German translation`

**Manual checks:**
- Launch `Peach (Debug, Research)`. Settings → TOD → **Pattern** section: five rows visible in the expected order; the first row is selected by default; tapping any other row updates selection chrome and the slot picker below.
- Tap `pattern_1010` row: slot picker shows the second-cell-pickable / fourth-cell-rest layout; only audible position 2 is tappable (and pre-selected).
- Tap `pattern_1001` row: slot picker shows rest in cells 2 and 3; only cell 4 is tappable; the doubled-glyph indicator sits there.
- Tap `pattern_1011` row: slot picker shows rest in cell 2, pickable cells 3 and 4; default position is audible 2 (grid 2).
- Tap `pattern_1101` row: slot picker shows pickable cells 2 and 4, rest in cell 3; default position is audible 2 (grid 1).
- Start a TOD trial with `pattern_1011` selected and `offsetNotePosition = 3`: the training-screen indicator's doubled-glyph cell sits at grid index 3 (audible 3 → grid 3, via `audibleToGrid[2] = 3`).
- Force a known-bad UserDefaults state in Research: `defaults write de.schuerig.peach.research timingOffsetDetectionSelectedPatternId -string pattern_xxxx`; relaunch. Pattern picker selects `pattern_1111`; slot picker shows the four-cell `pattern_1111` layout.
