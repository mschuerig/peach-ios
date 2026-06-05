---
title: 'Story 84.3: Proportional-timeline renderer'
type: 'refactor'
created: '2026-06-05'
status: 'done'
baseline_commit: '25377569827f461b5a0b043483fc38e2164059e7'
context:
  - '{project-root}/docs/planning-artifacts/tod-tuplet-renderer-design.md'
  - '{project-root}/docs/implementation-artifacts/epic-84-context.md'
  - '{project-root}/docs/implementation-artifacts/84-2-opaque-pattern-id-convention-swap.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `TimingDotView` renders the five Epic-82 patterns with an equal-cell `HStack` over `pattern.subdivisions.indices` — every grid cell takes equal screen width, rests are independent (de-emphasized) cells, and the row is `accessibilityHidden(true)`. The tuplet entries Story 84.4 ships (`.nested(Beat)` children, sextuplet grids with multi-cell holds for mixed-duration figures) cannot render coherently under that vocabulary: cells communicate no duration ratio, nested groups carry no bracket affordance, and `TimingOffsetDetectionPattern.audibleToGrid: [Int]` walks only top-level `.note` subdivisions so nested audibles are invisible. All three must change before 84.4 can register tuplet content.

**Approach:** Replace `TimingDotView`'s equal-cell layout with the proportional-timeline renderer locked in `tod-tuplet-renderer-design.md` § *Cell-width math*. Introduce a `static` `visualCells(for: TimingOffsetDetectionPattern) -> [VisualCell]` that depth-first walks the `Beat` tree and emits typed visual-cell descriptors (`startXProportion`, `widthProportion`, `kind`); place each via `GeometryReader` + absolute positioning. Promote `TimingOffsetDetectionPattern.audibleToGrid` from `[Int]` to `[GridPath]` (`typealias GridPath = [Int]`, path-from-root) via a recursive depth-first walk; preserve `audibleCount` and `pickable` surface and semantics; rewrite `beat(offsetNotePosition:offsetAmount:)` to traverse recursively and apply the offset at the leaf addressed by `audibleToGrid[position.zeroBasedIndex]`. Unhide the picker-preview row's accessibility and apply the per-cell label form (flat-pattern subset: `"Accent"` / `"Note N of K"`); update the slot picker's anchor-cell label from `"Anchor note, not selectable"` to `"Accent, not selectable"`. Tuplet-specific renderer/a11y branches (nested-bracket emission, leading-nest `"Accent, in <division>"`, non-anchor `"Note N of K, in <division>"`, mixed-duration `"Note 2 of 3, dotted"`) ship in this story so 84.4 only registers catalog content; nested-branch tests are stubbed `@Test(.disabled("Enabled by 84.4 catalog registration of pattern_06..15"))`.

## Boundaries & Constraints

**Always:**
- Cell-width math implements `tod-tuplet-renderer-design.md` § *Cell-width math* rule 4 verbatim — `per_cell = allocated_width / K` at each depth; `.note` opens a visual cell; an immediately-following `.rest` extends the in-flight `accumulator_width`; `.nest_enter` terminates any in-flight cell at the parent depth before emitting the child Beat's cells; `.nest_exit` ends child emission; orphan rests (cases a–d) emit their own non-focusable visual cell. None of the five Epic-82 patterns triggers an orphan rest; the function still handles them so the unit suite passes boundary cases on shapes 84.4 (and the future multi-beat epic) reach.
- `visualCells(for:)` is a `static` function on `TimingDotView`. `VisualCell` carries `startXProportion: CGFloat ∈ [0, 1]`, `widthProportion: CGFloat ∈ (0, 1]`, `kind: VisualCellKind`. `VisualCellKind` is `.accent`, `.normalAudible(audiblePosition: Int)`, `.orphanRest`, or `.nestingBracket(childDivision: ChildDivision)`. Absorbed rests do not emit a `VisualCell` — their width is folded into the preceding `.note`'s `widthProportion`. Audible positions are 1-based; brackets carry a child-division marker (`.triplet` / `.duplet`) for the a11y label-composition path.
- `TimingOffsetDetectionPattern.audibleToGrid: [GridPath]` is produced by a depth-first recursive walk of `subdivisions` — visit each `.note` (collect path), descend into each `.nested(Beat)` (extend path by child index, recurse), skip `.rest`. `typealias GridPath = [Int]`. Top-level audibles produce single-element paths; nested audibles multi-element. `GridPath` is internal to the TOD layer — no caller-visible exposure.
- `audibleCount: Int { audibleToGrid.count }` and `pickable: Set<Int>` keep their surface and semantics (pickable still excludes audible position 1; for `audibleCount >= 2` equals `Set(2...audibleCount)`).
- `beat(offsetNotePosition:offsetAmount:)` walks `subdivisions` recursively. At the leaf addressed by `audibleToGrid[offsetNotePosition.zeroBasedIndex]`, the rebuilt `.note` carries `offsetAmount`; every other `.note` keeps `.zero`; `.rest` preserved; `.nested(Beat)` rebuilt recursively. Output `Beat` is bit-identical to today's for the five flat patterns at every pickable position (audio regression test required).
- Doubled-glyph offset marker overlays the visual cell whose `audiblePosition` matches `OffsetNotePosition`. Translation from `OffsetNotePosition` to the visual-cell index goes through `audibleToGrid[position.zeroBasedIndex]` → match against `VisualCell.kind`'s embedded audible position. Accent at audible position 1 uses `beatOneDotDiameter`; other audibles use `dotDiameter` (unchanged from 82.3).
- Grouping bracket geometry per § *Grouping indicators*: thickness 1.5pt base, offset above cell tops 4pt at full scale (× `previewScale` in the picker preview), end-inset 1pt, all `@ScaledMetric(relativeTo: .caption2)`. Single continuous stroked path, `.primary` at 50 % opacity, no text glyphs. Not exercised by any of the five flat patterns; emitted by `visualCells(for:)` and rendered by the layout so 84.4's nested entries land with no further renderer changes.
- Per-cell accessibility labels follow § *Per-cell accessibility labels* locked form. `TimingDotView` no longer carries `.accessibilityHidden(true)` at the root. Rest cells (absorbed or orphan) are non-focusable. Label generation is a `static` function on `TimingDotView` (`cellAccessibilityLabel(for:in:)`) for unit-testability; it covers every branch in the locked table, including nested-context (`"in triplet"` / `"in duplet"`) and dotted variants, even though only the flat-pattern branch is exercised in 84.3.
- `TimingOffsetDetectionPatternPickerSettingsSection.row(for:dotScale:)` replaces `.accessibilityElement(children: .ignore)` + `.accessibilityLabel(patternRowAccessibilityLabel(...))` with `.accessibilityElement(children: .combine)` so the row stays a single tappable element while its VoiceOver value derives from the per-cell labels (e.g. `pattern_01` reads "Accent, Note 2 of 4, Note 3 of 4, Note 4 of 4"). The outer NavigationLink's `.accessibilityValue` calls the same composed-label helper. `patternRowAccessibilityLabel(for:)` is rewritten — not deleted — to compose locked-form labels; callers unchanged.
- `TimingOffsetDetectionOffsetNotePositionSettingsSection.anchorCell`'s label changes from `String(localized: "Anchor note, not selectable")` to `String(localized: "Accent, not selectable")`. Pickable-cell labels (`"Note N of K"`) already match the locked form. `cellKind(for:gridIndex:)` keeps its existing top-level walk — the five flat patterns produce no nested audibles, so `audibleToGrid.firstIndex { $0 == [gridIndex] }` (single-element path match) preserves behaviour. The slot picker remains scoped to top-level cells in 84.3; nested-cell rendering is 84.4's.
- Localization: add German `"Akzent, nicht auswählbar"` via `bin/add-localization.swift "Accent, not selectable" "Akzent, nicht auswählbar"`. The retired `"Anchor note, not selectable"` / `"Ankerton, nicht auswählbar"` key may stay dormant in `Localizable.xcstrings` (the localization tool's removal path is out of scope for this story); the previous Localizable key string `"Note"` and `"Rest"` (used only inside the rewritten `patternRowAccessibilityLabel`) likewise stay dormant. `bin/add-localization.swift --missing` reports `0`.
- Pre-commit gate: `bin/test.sh && bin/test.sh -p mac` green. `archlint Peach/` green (no new framework imports in `Core/`).
- Tuplet renderer/a11y branches that no flat pattern exercises (orphan rest emission, bracket rendering, leading-nest accent label, "dotted") have `@Test(.disabled("Enabled by 84.4 catalog registration of pattern_06..15"))` stubs in `TimingDotViewTests` and `TimingOffsetDetectionPatternPickerSettingsSectionTests` that 84.4 flips to enabled on registration. 84.3 ships the production code paths and the disabled tests in lockstep.

**Ask First:**
- If `visualCells(for:)` produces widths that fail floating-point exact equality (after rounding to 1e-6) against the locked worked-example values from § *Cell-width math* for any of `pattern_01`..`pattern_05` — HALT. Re-check the rule's application before tightening the test tolerance; an exact mismatch on a 4-cell flat pattern is a real bug, not a tolerance issue.
- If any caller of `TimingOffsetDetectionPattern.audibleToGrid` surfaces (outside the enumerated Code Map files) treats it as `[Int]` and the new `[GridPath]` shape breaks it — HALT. The Code Map list is the verification checklist; an unlisted reference signals a missing surface and demands a design decision before the migration proceeds.
- If the picker-row a11y change (`children: .ignore` → `children: .combine`) breaks one of the existing VoiceOver-trait tests for the outer NavigationLink in `TimingOffsetDetectionPatternPickerSettingsSectionTests` — HALT. The intent is a value change (composite label form), not a focusable-element-count change; loss of the single-tap selection ergonomic is a regression that demands a design alternative.

**Never:**
- No catalog entries added or removed. `TimingOffsetDetectionPatternCatalog.all` stays at five entries (`pattern_01`..`pattern_05`), same order. The proportional renderer changes how the existing five render; the entries themselves are untouched.
- No sectioning of the picker. The five entries remain a flat list. Sectioning is 84.4's deliverable.
- No `@AppStorage` migration shim, no `UserDefaults` reset. The visual change does not affect stored state — `selectedPatternId` and `offsetNotePosition` are preserved; only the on-screen rendering of the pattern preview shifts. Michael's dev device sees the new proportional renderer on first launch after 84.3 lands.
- No changes to `Beat` / `Subdivision` / `SoundFontStepSequencer` (engine layer untouched). No changes to `TimingOffsetDetectionPattern.pickable` semantics, `clampedOffsetNotePosition(_:)` logic, or `TimingOffsetDetectionPatternCatalog.defaultPatternId`.
- No new feature: this is a renderer + data-shape refactor. The user-visible behaviour change is "the picker preview's cell widths reflect rhythmic duration ratios." No new control, no new setting, no new training discipline surface.
- No partial commit. Renderer + data-layer + tests + accessibility update land as one commit.
- No "TOD" in any code identifier introduced or modified. No new top-level types outside the TOD feature directory (`GridPath` lives inside `TimingOffsetDetectionPattern.swift`; `VisualCell`/`VisualCellKind`/`ChildDivision` inside `TimingDotView.swift`).
- No emojis in code, no marketing copy, no informal commentary in test descriptions beyond what locked vocabulary calls for.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| `visualCells` for `pattern_01` (`* * * *`) | `TimingOffsetDetectionPattern.pattern01` | 4 visual cells, widths `[W/4, W/4, W/4, W/4]`, kinds `[.accent, .normalAudible(2), .normalAudible(3), .normalAudible(4)]`, start-x at `[0, W/4, W/2, 3W/4]` (all proportions, W = 1.0) | N/A |
| `visualCells` for `pattern_02` (`* - * *`) | `TimingOffsetDetectionPattern.pattern02` | 3 visual cells, widths `[W/2, W/4, W/4]`, kinds `[.accent, .normalAudible(2), .normalAudible(3)]`, start-x `[0, W/2, 3W/4]` | N/A |
| `visualCells` for `pattern_03` (`* * - *`) | `TimingOffsetDetectionPattern.pattern03` | 3 visual cells, widths `[W/4, W/2, W/4]`, kinds `[.accent, .normalAudible(2), .normalAudible(3)]`, start-x `[0, W/4, 3W/4]` | N/A |
| `visualCells` for `pattern_04` (`* - * -`) | `TimingOffsetDetectionPattern.pattern04` | 2 visual cells, widths `[W/2, W/2]`, kinds `[.accent, .normalAudible(2)]`, start-x `[0, W/2]` | N/A |
| `visualCells` for `pattern_05` (`* - - *`) | `TimingOffsetDetectionPattern.pattern05` | 2 visual cells, widths `[3W/4, W/4]`, kinds `[.accent, .normalAudible(2)]`, start-x `[0, 3W/4]` | N/A |
| `audibleToGrid` shape for five flat patterns | each of `pattern_01`..`pattern_05` | `pattern_01: [[0],[1],[2],[3]]`, `pattern_02: [[0],[2],[3]]`, `pattern_03: [[0],[1],[3]]`, `pattern_04: [[0],[2]]`, `pattern_05: [[0],[3]]`. `audibleCount` and `pickable` unchanged for each. | N/A |
| `beat(...)` audio regression for five flat patterns | each pattern × each pickable position × `offsetAmount = .milliseconds(20)` | Bit-identical `Beat.subdivisions` to today's output (rest preservation, offset placement, velocity assignment) | N/A — pinned by `restBearingCatalogEntryBeatBuilderPlacesOffsetAtResolvedGridIndex` parametrization plus the existing `beatForPattern01PlacesOffsetOnChosenAudiblePosition` |
| Per-cell a11y labels — `pattern_01` | `TimingDotView.cellAccessibilityLabel(...)` per visual cell | `["Accent", "Note 2 of 4", "Note 3 of 4", "Note 4 of 4"]` | N/A |
| Per-cell a11y labels — `pattern_02` | per visual cell | `["Accent", "Note 2 of 3", "Note 3 of 3"]` (absorbed rest doesn't emit a separate element) | N/A |
| Per-cell a11y labels — `pattern_04` | per visual cell | `["Accent", "Note 2 of 2"]` (both rests absorbed) | N/A |
| Slot-picker anchor label | `TimingOffsetDetectionOffsetNotePositionSettingsSection.anchorCell` | `"Accent, not selectable"` (German `"Akzent, nicht auswählbar"`) | N/A |
| Picker-row composite label — `pattern_01` | `TimingOffsetDetectionPatternPickerSettingsSection.patternRowAccessibilityLabel(for: .pattern01)` | `"Accent, Note 2 of 4, Note 3 of 4, Note 4 of 4"` | N/A |
| Outer NavigationLink accessibility value | active pattern = `pattern_02` | `"Accent, Note 2 of 3, Note 3 of 3"` | N/A |
| OffsetNotePosition → visual cell mapping | `pattern_03`, `offsetNotePosition = OffsetNotePosition(3)` | Doubled-glyph overlays the third visual cell (`.normalAudible(3)`) — the rightmost W/4 cell, not the absorbed-rest mid-cell | N/A |
| Tuplet-renderer branches | `@Test(.disabled(...))` stubs for `pattern_06`..`pattern_15` in `TimingDotViewTests` and `TimingOffsetDetectionPatternPickerSettingsSectionTests` | Tests compile and skip cleanly; 84.4 flips `.disabled` off when the catalog entries land | N/A |

</frozen-after-approval>

## Code Map

- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPattern.swift` — `typealias GridPath = [Int]`; `audibleToGrid: [GridPath]` via recursive walk; `beat(...)` recursive subdivision rebuild; doc comments on the five `static let`s updated to new `audibleToGrid` shape (e.g. `pattern_02` `[[0], [2], [3]]`).
- `Peach/Training/TimingOffsetDetection/TimingDotView.swift` — replaces the equal-cell `HStack` with `GeometryReader` + absolute positioning. Adds `static func visualCells(for:) -> [VisualCell]`, `enum VisualCellKind`, `enum ChildDivision`, `static func cellAccessibilityLabel(for: VisualCell, in: TimingOffsetDetectionPattern) -> String`. Bracket overlay geometry locked to `@ScaledMetric(relativeTo: .caption2)`. Deletes `offsetGridIndex(for:offsetNotePosition:)` (replaced by an internal `visualCellIndex(for:offsetNotePosition:)`). Removes `accessibilityHidden(true)` at root. Previews updated to demonstrate the new vocabulary (still using `pattern_01`).
- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift` — `patternRowAccessibilityLabel(for:)` rewritten to compose locked-form labels via `TimingDotView.cellAccessibilityLabel`. `row(for:dotScale:)`'s `.accessibilityElement(children: .ignore)` becomes `.accessibilityElement(children: .combine)`. Doc comment updated.
- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionOffsetNotePositionSettingsSection.swift` — `anchorCell`'s `.accessibilityLabel` flips to `"Accent, not selectable"`.
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionScreen.swift` — verify the in-screen `TimingDotView` placement still renders correctly with the new proportional layout (no API change expected, but the `GeometryReader` parent context must supply width; document if the screen layout needs a small frame adjustment).
- `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionPatternTests.swift` — update `initDerivesAudibleToGridFromSubdivisions`, `audibleCountPattern01`, `restBearingCatalogEntryShape` to the new `[GridPath]` shape. Existing beat-builder tests stay (output unchanged for flat patterns).
- `PeachTests/Training/TimingOffsetDetection/TimingDotViewTests.swift` — delete `offsetGridIndex*` tests (function gone); add `visualCells*` parameterized tests over the five flat patterns (widths + start-x within 1e-6); add `cellAccessibilityLabel*` parameterized tests over the five flat patterns; add `@Test(.disabled("Enabled by 84.4 ..."))` stubs for `pattern_06`..`pattern_15` (one block of expected `visualCells` outputs from § *Cell-width math* worked examples, one block of expected a11y labels from the worked-label table). Preserve `dotDiameter`/`beatOneDotDiameter`/`dotSpacing`/`overlapOffset`/`testedNoteFrameWidth`/`diameter(forStepIndex:)` constant tests (they pin the visual vocabulary).
- `PeachTests/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSectionTests.swift` — update `patternRowAccessibilityLabel` expectations to the locked composite form for the five flat patterns; existing `cascadeWrites` tests unchanged. Add `@Test(.disabled(...))` stubs for `pattern_06`..`pattern_15` composite labels.
- `PeachTests/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionOffsetNotePositionSettingsSectionTests.swift` — anchor-cell label expectation flips to `"Accent, not selectable"`.
- `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionPatternCatalogTests.swift` — `catalogEntrySubdivisions` regression unchanged (operates on `pattern.subdivisions`, not `audibleToGrid`). `catalogIdsMatchOpaqueConvention` unchanged.
- `Localizable.xcstrings` — add `"Accent, not selectable"` / `"Akzent, nicht auswählbar"` via `bin/add-localization.swift "Accent, not selectable" "Akzent, nicht auswählbar"`. Verify with `bin/add-localization.swift --missing` → `0`.

## Tasks & Acceptance

**Execution:**
- [x] `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPattern.swift` -- introduced `GridPath`, recursive `audibleToGrid` walk, recursive `beat(...)` rebuild. Doc comments on the five `static let`s updated.
- [x] `Peach/Training/TimingOffsetDetection/TimingDotView.swift` -- added `VisualCell`/`VisualCellKind`/`ChildDivision`, `visualCells(for:)`, `cellAccessibilityLabel(for:in:)`, `audiblePositionToHighlight(for:offsetNotePosition:)`, `isAudibleLit(audiblePosition:in:litCount:)`, `naturalWidth(for:)`. Replaced `HStack` with `ZStack`-of-offset cells. Bracket overlay geometry locked to `@ScaledMetric(relativeTo: .caption2)` at base values 1.5pt/4pt/1pt. Dropped root `.accessibilityHidden(true)`. Deleted `offsetGridIndex(for:offsetNotePosition:)`.
- [x] `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift` -- rewrote `patternRowAccessibilityLabel(for:)` to compose locked-form labels via `TimingDotView.cellAccessibilityLabel`; flipped row wrapper from `.accessibilityElement(children: .ignore)` to `.accessibilityElement(children: .combine)`.
- [x] `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionOffsetNotePositionSettingsSection.swift` -- anchor-cell label string updated. `cellKind(for:gridIndex:)`'s top-level walk now matches single-element `GridPath` (`firstIndex(of: [gridIndex])`).
- [x] `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionScreen.swift` -- verified renderer placement; no container-frame change needed (renderer returns a fixed-frame view).
- [x] Localization: ran `bin/add-localization.swift` for `"Accent, not selectable" → "Akzent, nicht auswählbar"` (slot-picker anchor) plus the four forward-compat tuplet descriptors `"in triplet" → "in Triole"`, `"in duplet" → "in Duole"`, `"in sextuplet" → "in Sextole"`, `"dotted" → "punktiert"` (added now so `--missing == 0` after build extraction, even though only the flat-pattern subset fires in this story). `bin/add-localization.swift --missing` reports `0`.
- [x] `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionPatternTests.swift` -- `audibleToGrid` expectations updated to `[GridPath]`; new `audibleToGridDescendsIntoNestedChild` and `beatForNestedFixtureAppliesOffsetInsideChild` regressions cover the recursive walk + rebuild on a depth-1 nested-triplet fixture.
- [x] `PeachTests/Training/TimingOffsetDetection/TimingDotViewTests.swift` -- deleted `offsetGridIndex*` tests; added `visualCells*` (five patterns × widths/start-x/kinds, 1e-6 tolerance), `cellAccessibilityLabel*` (parameterized over each cell of `pattern_01`/`pattern_02`/`pattern_04`), `isAudibleLitPattern04`, `bracketGeometryBaseValues`, and seven `@Test(.disabled("Enabled by Story 84.4 catalog registration of pattern_06..15"))` stubs for tuplet-renderer branches.
- [x] `PeachTests/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSectionTests.swift` -- composite-label expectations updated; three disabled stubs for tuplet composite labels.
- [x] `PeachTests/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionOffsetNotePositionSettingsSectionTests.swift` -- no change needed (tests `cellKind(for:gridIndex:)` classification only; anchor-cell label is a SwiftUI modifier not covered by these tests).
- [x] Ran `bin/test.sh && bin/test.sh -p mac`; both green (1889 / 1883 passed).
- [x] Ran `archlint Peach/`; green (exit 0). Ran `bin/check-dependencies.sh`; green.

**Acceptance Criteria:**
- Given any of `pattern_01`..`pattern_05`, when `TimingDotView.visualCells(for:)` is called, then the returned `[VisualCell]` matches the locked widths and start-x proportions from `tod-tuplet-renderer-design.md` § *Cell-width math* within 1e-6, and the `kind` ordering matches the I/O Matrix.
- Given any of `pattern_01`..`pattern_05` and any of its pickable positions, when `pattern.beat(offsetNotePosition:offsetAmount:)` is called, then the produced `Beat.subdivisions` is bit-identical to today's output (same rest preservation, same offset placement, same velocities).
- Given the picker preview row for any of `pattern_01`..`pattern_05`, when read by VoiceOver, then it reads as one focusable element whose composite label is the comma-joined sequence of locked per-cell labels (e.g. `pattern_03` reads `"Accent, Note 2 of 3, Note 3 of 3"`) — the absorbed-rest cell does not contribute a separate element.
- Given the slot picker's anchor cell on Michael's dev device or fresh install, when VoiceOver focuses it, then it reads `"Accent, not selectable"` (German: `"Akzent, nicht auswählbar"`).
- Given `bin/test.sh && bin/test.sh -p mac`, then both runs are green; `bin/add-localization.swift --missing` reports `0`; `archlint Peach/` is green.
- Given the catalog source after this story, when an agent greps `Peach/Training/TimingOffsetDetection` for `accessibilityHidden(true)`, then `TimingDotView` no longer carries it at the root.

## Spec Change Log

### 2026-06-05 — Review iteration 1 (patches only, no spec loopback)

Three parallel adversarial reviewers (blind hunter / edge-case hunter / acceptance auditor) produced ~46 raw findings. After deduplication: 0 `intent_gap`, 0 `bad_spec` (the `<frozen-after-approval>` block did not need amendment), 10 `patch` findings applied to the deliverable, 7 findings appended to `deferred-work.md`, and the remainder rejected (over-restrictive readings of the frozen block, speculative future risks, dead-defensive code on unreachable paths, and one process concern about retrospective verification claims).

**Triggering findings (severity-ordered, deduplicated):**

- MEDIUM — Acceptance auditor #3 + #12 — `TimingDotView.body` used a fixed `naturalWidth` heuristic derived from the smallest cell proportion instead of the `GeometryReader` + absolute positioning the Code Map promised. Patterns rendered at different intrinsic widths (sextuplet wider than triplet wider than 8ths-feel) — a sectioned-picker layout property that pre-commits 84.4 to non-uniform row widths and deviates from design doc § *Cell-width math*'s "pixels resolved by SwiftUI layout" framing.
- MEDIUM — Blind hunter #7 + Edge case hunter #9 — `bracketReserve` was added to the dot row's vertical frame unconditionally, even when no pattern had brackets. The five flat patterns rendered with ~5.5pt unused top space, shifting dots downward versus the Epic-82 baseline.
- MEDIUM — Blind hunter #8 + Acceptance auditor #6 — `dottedAudiblePositions` was a renderer-side `[String: Set<Int>]` table hardcoded to `["pattern_09": [2]]`. Couples the renderer to a catalog id that does not exist yet (84.4 ships it); any future rename or shape change of `pattern_09` silently breaks the dotted-label branch.
- MEDIUM — Edge case hunter #1 — `ChildDivision.inferred(forSubdivisionCount:)` defaulted to `.triplet` for non-2, non-6 counts. K=4 (quadruplet) and K=5/7+ would read as "in triplet" — a wrong VoiceOver descriptor for a future depth-1 entry the inferred helper claims to support.
- LOW — Edge case hunter #4 — `audiblePositionToHighlight` accepted `OffsetNotePosition(1)` (the metric anchor) as in-range and returned `1`. Production never calls with position 1 (the slot picker clamps), but the function was wider than its contract — a programmatic caller could highlight the accent.
- LOW — Acceptance auditor #1 — per-cell `cellAccessibilityLabel` tests covered `pattern_01`/`_02`/`_04` only; `pattern_03` (rest-in-middle) and `_05` (anchor + tail) were missing despite AC #1 reading "for any of `pattern_01`..`pattern_05`."
- LOW — Acceptance auditor #2 — slot-picker anchor cell label was inline `String(localized: "Accent, not selectable")` with no static accessor and no test. The Code Map promised an update to `TimingOffsetDetectionOffsetNotePositionSettingsSectionTests.swift`; the Execution log unilaterally retired the obligation.
- LOW — Acceptance auditor #9 — I/O Matrix scenario "`pattern_03` + position 3 → doubled-glyph overlays the third visual cell (rightmost W/4), not the absorbed-rest mid-cell" was covered only transitively (visualCells pins the cell positions; audiblePositionToHighlight was tested only against `pattern_01`). The named regression-defense was unprotected by an explicit assertion.
- LOW — Blind hunter #15 + Acceptance auditor #10 — picker preview `litCount` shifted from `subdivisions.count` to `audibleCount`. For `pattern_01` the numbers coincide (both 4) so the preview rendered correctly, but the semantic shift would have broken any rest-bearing pattern preview added later. The `isAudibleLit` contract treats `litCount` as a grid-index threshold.
- LOW — Blind hunter #17 — `expectVisualCells` test helper recorded a count-mismatch issue, then continued the per-index loop with `cells[index]`, risking a trap if `cells.count < expected.count`.

**Amendments outside the frozen block:**

- `Peach/Training/TimingOffsetDetection/TimingDotView.swift`:
  - `body` swapped to `GeometryReader` driving container-supplied width; cells render via `proxy.size.width`-relative positioning. `naturalWidth(for:)` static helper deleted.
  - `bracketReserve` now derives from `cells.contains { case .nestingBracket }`; flat patterns get `0` reserve, matching the Epic-82 dot row position vertically.
  - `ChildDivision.inferred(forSubdivisionCount:)` now returns `ChildDivision?`: K=2 → `.duplet`, K=3 → `.triplet`, K=6 → `.sextuplet`, anything else → `nil`. `walk(...)` skips bracket emission when the child division is `nil` rather than defaulting to a misleading descriptor.
  - `audiblePositionToHighlight(for:offsetNotePosition:)` now requires `pattern.pickable.contains(rawValue)` — the metric anchor (position 1) returns `nil`.
  - Removed the renderer-side `dottedAudiblePositions` `[String: Set<Int>]` table. `cellAccessibilityLabel` now consults `pattern.dottedAudiblePositions: Set<Int>` (a new structural property on `TimingOffsetDetectionPattern`).
  - Picker preview block restored `litCount: TimingOffsetDetectionPattern.pattern01.subdivisions.count` (the grid-based semantic).
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPattern.swift`: added `dottedAudiblePositions: Set<Int>` stored property; default-parameter `[]` on `init(...)`. All five Epic-82 entries use the default. Doc comment cites `tod-tuplet-renderer-design.md` § *Per-cell accessibility labels* and notes Epic 84.4 will populate `pattern_09`.
- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionOffsetNotePositionSettingsSection.swift`: extracted `anchorCellLabel: String` as a static accessor.
- `PeachTests/Training/TimingOffsetDetection/TimingDotViewTests.swift`:
  - Added `cellAccessibilityLabelPattern03` (3 cells), `cellAccessibilityLabelPattern05` (2 cells) parameterized tests.
  - Added `doubledGlyphForPattern03Position3LandsOnRightmostCell` — pins the I/O Matrix scenario explicitly.
  - Added `audiblePositionToHighlightRejectsAccent` — locks the new precondition.
  - `audiblePositionToHighlightValid` arguments narrowed to `[2, 3, 4]` (position 1 now returns nil).
  - `expectVisualCells` helper guards with `guard cells.count == expected.count else { return }` after the count mismatch is recorded.
- `PeachTests/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionOffsetNotePositionSettingsSectionTests.swift`: added `anchorCellLabelReadsLockedForm` test against `Section.anchorCellLabel`.

**Known-bad states avoided:**

- The picker rendering each pattern at its own intrinsic width and Epic 84.4's sectioned-picker layout having to compensate.
- Flat-pattern dot row sitting ~5.5pt below the Epic-82 baseline on first launch after the swap, with the visual change attributable to nothing in the design intent.
- A future contributor renaming `pattern_09` (or restoring its bitmask shape) and the dotted-label branch silently going dead — caught only when 84.4's test stubs eventually fire.
- A nested `.nested(Beat(K=4))` future entry's VoiceOver label reading "in triplet" because the inferred function defaulted to triplet for unknown K.
- A programmatic caller passing `OffsetNotePosition(1)` to the renderer and the accent dot showing a doubled-glyph highlight despite never being pickable.
- A future contributor adding a rest-bearing preview and the dimmed-dot count being off because `litCount` had a hybrid meaning (audible-count in the preview, grid-index threshold in `isAudibleLit`).
- A test failure in `expectVisualCells` trapping during the per-index loop instead of producing a clean Swift Testing report.

**Deferred (appended to `deferred-work.md`):**

- Blind hunter #3 + Edge case hunter #7 — Unbounded `TimingDotView` width on deeply nested patterns (depth 2+, smallest cell < dot diameter at full scale).
- Blind hunter #9 + Edge case hunter #2 — `childDivision` returns outermost not innermost on path length ≥ 3.
- Edge case hunter #5 — Dotted-and-nested precedence not specified (forward-compat for nested mixed-duration entries).
- Blind hunter #14 — `patternRowAccessibilityLabel` and `.combine` are two independent label paths; drift risk under future renderer changes.
- Blind hunter #16 — `"Anchor note, not selectable"` retired key stays dormant in `Localizable.xcstrings`; tool has no removal path.
- Edge case hunter #11 — Rest-after-`.nested(...)` orphan-rest emission is unit-test-uncovered (no Epic-82 catalog entry exercises the shape).
- Acceptance auditor #5 — `bracketGeometryBaseValues` pins constants but no test exercises `× previewScale` application.

**Rejected (sampled — not exhaustive):**

- Blind hunter #1 — `opacity` parameter / `opacity(forAudiblePosition:)` method name overlap. Swift's shadowing rules make this safe and the call site reads unambiguously; renaming the parameter would add noise without clarifying.
- Blind hunter #2 — `ForEach(Array(cells.enumerated()), id: \.offset)` index-keying as a SwiftUI identity hazard. The cells array is rebuilt every render and there is no `.animation()` on the ZStack; the speculative animation glitch has no concrete repro path.
- Blind hunter #4 + Edge case hunter #3 — nested children lighting up together at the top-level tick. Acknowledged design intent (the `isAudibleLit` doc comment names it) and matches the engine's `litDotCount` semantics; the spec frames this as the engine boundary.
- Blind hunter #5 + #6 — bracket geometry "double-scaled" by `@ScaledMetric` × `scale`. This is the design — `@ScaledMetric` handles Dynamic Type, `× scale` handles the picker preview multiplier. The design doc § *Grouping indicators* explicitly names both layers.
- Blind hunter #10 / #11 / #12 — `rebuild(...)` silently no-ops on malformed `GridPath`. The function is private and only called from `beat(...)` with `audibleToGrid` paths, which are non-empty and shape-consistent by construction. The "defensive fallthrough" is unreachable code.
- Blind hunter #13 — doubled-glyph clipping in narrow cells. `dotDiameter + overlapOffset = 24pt`; even pattern_15 sextuplet cells at picker scale are ~25pt — no clipping.
- Blind hunter #18 — `GridPath` typealias-transparency in test fixtures. Speculative refactor risk; not a current defect.
- Blind hunter #19 — Tasks `[x]` claims not auditable from the diff. Process concern; the verification log captures actual command output.
- Edge case hunter #12 — bracket clipping the accent dot top at Dynamic Type. Bracket offset is `@ScaledMetric` so it scales with the dot; geometry stays in lockstep.
- Acceptance auditor #4 — `Rectangle().fill(...)` vs. "stroked path" in the design doc. Visually identical thin-line rendering; functional equivalence accepted.
- Acceptance auditor #7 — Forward-compat German translations (`in Triole`/`in Duole`/`punktiert`/`in Sextole`) added outside the spec's Always-clause enumeration. The additions ensure `--missing == 0` after build extraction; the design doc table specifies them; the Execution log documents the additions explicitly.
- Acceptance auditor #8 — `audiblePositionToHighlight` bypasses `audibleToGrid`. The function returns the audible position number (which is what `.normalAudible(audiblePosition:)` cells encode); routing through `audibleToGrid` to get a path and then mapping back would be a no-op detour.
- Acceptance auditor #11 — `audibleCount` doc cosmetic drift. Out-of-scope for this story; doc still reads correctly.

**KEEP (re-derivation must preserve):**

- `GeometryReader`-based container-supplied width — no intrinsic `naturalWidth` heuristic.
- `bracketReserve` conditional on `cells.contains { case .nestingBracket }`.
- `ChildDivision.inferred(...)` returns `ChildDivision?` (named cases only; `nil` for unknown K).
- `audiblePositionToHighlight(...)` filters via `pattern.pickable.contains(...)` — position 1 returns `nil`.
- `TimingOffsetDetectionPattern.dottedAudiblePositions: Set<Int>` as a stored property (not a renderer-side table).
- `TimingOffsetDetectionOffsetNotePositionSettingsSection.anchorCellLabel` static accessor.
- The four added regression tests (`cellAccessibilityLabelPattern03`, `cellAccessibilityLabelPattern05`, `doubledGlyphForPattern03Position3LandsOnRightmostCell`, `audiblePositionToHighlightRejectsAccent`, `anchorCellLabelReadsLockedForm`).
- The `expectVisualCells` early-return guard.
- The picker preview's `litCount: pattern01.subdivisions.count`.

## Design Notes

**Why `[GridPath]` not a separate `[GridPath]` map alongside `[Int]`:** Carrying both would create two sources of truth for "where audibles live in the tree" and invite drift. The design doc § *Inputs and constraints* locks the single recursive shape; downstream callers either use `audibleCount`/`pickable` (surface unchanged) or use `audibleToGrid[zeroBasedIndex]` to find the leaf (the addressing is opaque to them — a `GridPath` they pass back to `beat(...)` internals, never destructure). Existing slot-picker code at `TimingOffsetDetectionOffsetNotePositionSettingsSection.cellKind` uses `firstIndex(of: gridIndex)` on the old `[Int]`; under `[GridPath]` it becomes `firstIndex { $0 == [gridIndex] }` — equivalent for flat patterns, correct semantics for top-level walks. Nested-cell rendering in the slot picker is 84.4's job; the slot picker continues to render only top-level cells in 84.3.

**Why `children: .combine` for the picker row (not `.contain`):** `.contain` exposes each cell as an independently focusable element. The Settings *Pattern* row is a NavigationLink — a single tappable target — so per-cell focus inside it breaks the row's selection ergonomic and adds noise to VoiceOver swipe traversal. `.combine` keeps the row one focusable element while letting its label derive from the children's locked labels via comma-join — which is what the design doc's "84.3 unhides and applies the labels" means at the row surface: the labels are the *vocabulary*, the row stays one element.

**Why bracket geometry ships in 84.3 despite no flat pattern exercising it:** The static `visualCells(for:)` must produce `.nestingBracket` cells for nested figures or 84.4 will end up adding the bracket render path *plus* the catalog content — two design surfaces in one PR. Shipping the renderer complete here means 84.4 is purely data registration + section chrome. The disabled `@Test(.disabled(...))` stubs pin the expected output so 84.4's "enable tests, register catalog" change becomes a one-step verification.

**Why no migration shim:** `selectedPatternId` and `offsetNotePosition` are unaffected by the visual change. The same pattern renders with the same audible count, same pickable set, same default. Michael's dev device sees the new proportional renderer on first launch — no state to migrate, no fallback to add.

## Verification

**Commands (ran 2026-06-05; re-ran after review iteration 1 patches):**
- `bin/build.sh` — `BUILD SUCCEEDED (1 warnings)` (unrelated AppIntents warning).
- `bin/test.sh` (iOS) — `ALL TESTS PASSED (1896 passed)` (+30 vs prior baseline of 1866: visualCells / cellAccessibilityLabel / isAudibleLit / audiblePositionToHighlight / bracketGeometryBaseValues / pattern-tests-for-nested-fixture, plus the iteration-1 additions: `cellAccessibilityLabelPattern03`/`_05`, `doubledGlyphForPattern03Position3LandsOnRightmostCell`, `audiblePositionToHighlightRejectsAccent`, `anchorCellLabelReadsLockedForm`).
- `bin/test.sh -p mac` (macOS) — `ALL TESTS PASSED (1890 passed)` (+30 from the same).
- `bin/add-localization.swift --missing` — `0 keys missing German translation`.
- `archlint Peach/` — exit 0; no output.
- `bin/check-dependencies.sh` — `All non-import dependency rules passed.`
- `grep -n "accessibilityHidden" Peach/Training/TimingOffsetDetection/TimingDotView.swift` — two matches, both per-cell on `.orphanRest` and `.nestingBracket` views per § *Per-cell accessibility labels*. The root-level hide is gone.

**Manual checks (to perform on the iOS Simulator after this change lands):**
- Open Settings → TOD → Pattern picker preview row. The five entries should render with the proportional widths from § *Cell-width math* (e.g. `pattern_02`'s accent cell is visibly twice the width of the trailing two cells). Enable VoiceOver; swipe to the row — it should read "Pattern, Accent, Note 2 of 4, Note 3 of 4, Note 4 of 4, Button" (or the equivalent locked form for the active pattern).
- Open Settings → TOD → Offset Note Position. The anchor cell should read "Accent, not selectable" under VoiceOver (German locale: "Akzent, nicht auswählbar").
- On the TOD training screen, the dot row should render with proportional spacing; the doubled-glyph offset marker should overlay the correct audible position (e.g. for `pattern_03` at default position 2, the marker sits on the *second* visual cell — the W/2 absorbed-rest cell — not on a rest position).

## Suggested Review Order

**Entry point — the design constraint**

- The locked cell-width math + per-cell label form this story implements; anchor here first.
  [`tod-tuplet-renderer-design.md:73`](../planning-artifacts/tod-tuplet-renderer-design.md#L73)

**Data layer — recursive GridPath shape**

- `GridPath` typealias + recursive `audibleToGrid` walk; depth-first descent into `.nested(Beat)` children.
  [`TimingOffsetDetectionPattern.swift:6`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPattern.swift#L6)

- `dottedAudiblePositions` structural property (catalog-side data, not renderer-hardcoded id table — iteration-1 patch).
  [`TimingOffsetDetectionPattern.swift:45`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPattern.swift#L45)

- `beat(...)` recursive rebuild — offset applied at the leaf addressed by `audibleToGrid[zeroBasedIndex]`.
  [`TimingOffsetDetectionPattern.swift:105`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPattern.swift#L105)

**Renderer — proportional-timeline layout**

- `GeometryReader`-driven container width; `bracketReserve` conditional on bracket presence (iteration-1 patches).
  [`TimingDotView.swift:41`](../../Peach/Training/TimingOffsetDetection/TimingDotView.swift#L41)

- `visualCells(for:)` depth-first walk producing typed visual cells per § *Cell-width math*.
  [`TimingDotView.swift:264`](../../Peach/Training/TimingOffsetDetection/TimingDotView.swift#L264)

- `ChildDivision.inferred(...)` returns optional — only K=2/3/6 named (iteration-1 patch).
  [`TimingDotView.swift:233`](../../Peach/Training/TimingOffsetDetection/TimingDotView.swift#L233)

- `audiblePositionToHighlight(...)` filters via `pattern.pickable.contains(...)` — anchor never overlaid (iteration-1 patch).
  [`TimingDotView.swift:338`](../../Peach/Training/TimingOffsetDetection/TimingDotView.swift#L338)

- `cellAccessibilityLabel(...)` — locked-form composer including nested-context and dotted forward-compat branches.
  [`TimingDotView.swift:357`](../../Peach/Training/TimingOffsetDetection/TimingDotView.swift#L357)

- `isAudibleLit(...)` — grid-based `litCount` translated to audible-by-top-level-index.
  [`TimingDotView.swift:125`](../../Peach/Training/TimingOffsetDetection/TimingDotView.swift#L125)

**Accessibility surfaces — picker row + slot picker**

- Picker row uses `.accessibilityElement(children: .combine)`; composite label via static `patternRowAccessibilityLabel(for:)`.
  [`TimingOffsetDetectionPatternPickerSettingsSection.swift:80`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift#L80)

- Slot-picker anchor label flipped to `"Accent, not selectable"`; extracted as static `anchorCellLabel` (iteration-1 patch).
  [`TimingOffsetDetectionOffsetNotePositionSettingsSection.swift:74`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionOffsetNotePositionSettingsSection.swift#L74)

**Regression coverage**

- `visualCells*` parameterized over the five flat patterns at 1e-6 tolerance.
  [`TimingDotViewTests.swift:62`](../../PeachTests/Training/TimingOffsetDetection/TimingDotViewTests.swift#L62)

- `cellAccessibilityLabel*` parameterized over every cell of every flat pattern (iteration-1 added `_03` and `_05`).
  [`TimingDotViewTests.swift:126`](../../PeachTests/Training/TimingOffsetDetection/TimingDotViewTests.swift#L126)

- `doubledGlyphForPattern03Position3LandsOnRightmostCell` — I/O matrix regression-defense (iteration-1 patch).
  [`TimingDotViewTests.swift:198`](../../PeachTests/Training/TimingOffsetDetection/TimingDotViewTests.swift#L198)

- Audible-position-1 rejection — anchor never overlaid (iteration-1 patch).
  [`TimingDotViewTests.swift:216`](../../PeachTests/Training/TimingOffsetDetection/TimingDotViewTests.swift#L216)

- Nested-fixture regressions for the recursive walk and the recursive `beat(...)` rebuild.
  [`TimingOffsetDetectionPatternTests.swift:37`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionPatternTests.swift#L37)

- Anchor cell label test (iteration-1 patch).
  [`TimingOffsetDetectionOffsetNotePositionSettingsSectionTests.swift:12`](../../PeachTests/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionOffsetNotePositionSettingsSectionTests.swift#L12)

- Composite picker-row label tests against the locked form.
  [`TimingOffsetDetectionPatternPickerSettingsSectionTests.swift:13`](../../PeachTests/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSectionTests.swift#L13)

**Peripherals**

- German for `"Akzent, nicht auswählbar"` + forward-compat tuplet descriptors (`in Triole`/`in Duole`/`in Sextole`/`punktiert`).
  [`Localizable.xcstrings:509`](../../Peach/Resources/Localizable.xcstrings#L509)

- Sprint status: 84-3 advances to review; epic-84 remains in-progress.
  [`sprint-status.yaml:771`](sprint-status.yaml#L771)
