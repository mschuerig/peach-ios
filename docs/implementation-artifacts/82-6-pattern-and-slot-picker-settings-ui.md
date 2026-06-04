---
title: 'Story 82.6: Pattern and slot picker Settings UI'
type: 'feature'
created: '2026-06-04'
status: 'done'
baseline_commit: '27a2d78122a93a7bfc6710406bcdb6c9be05da6a'
context:
  - '{project-root}/docs/planning-artifacts/tod-initial-pattern-catalog.md'
  - '{project-root}/docs/implementation-artifacts/epic-82-context.md'
  - '{project-root}/docs/implementation-artifacts/82-5-pattern-catalog-domain-layer.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Story 82.5 landed `TimingOffsetDetectionPattern` + `TimingOffsetDetectionPatternCatalog` with `pattern_1111` as the only registered entry, but the Settings UI still reflects the pre-pattern world: no pattern picker exists, the offset-note-position section is a four-cell numeric grid ignorant of audible/rest structure, the training-screen `TimingDotView` hard-codes `ForEach(0..<4)` and reads `testedNoteIndex` as audible-but-treats-it-as-grid (latent bug for any non-`pattern_1111` entry), and the offset-note help/footer copy still names "four 16th notes". Story 82.7 cannot register `pattern_1011` / `pattern_1101` / `pattern_1010` / `pattern_1001` until all three surfaces become pattern-aware and rest-aware.

**Approach:** Add a new `TimingOffsetDetectionPatternPickerSettingsSection` (section header **Pattern**) above the existing offset-note-position section in the TOD discipline contribution; reskin `TimingOffsetDetectionOffsetNotePositionSettingsSection` as an N-cell rest-aware picker driven by `activePattern.subdivisions`; refactor `TimingDotView` to render N cells based on the active pattern and translate audible → grid via `pattern.audibleToGrid` for the doubled-glyph cell. All three surfaces share one visual vocabulary: large accent dot at grid position 1, smaller normal dot at other audible positions, doubled-glyph indicator at the Offset Note, empty cell (preserved width) at rests. Pattern selection always writes both `selectedPatternId` *and* `offsetNotePosition = newPattern.defaultOffsetNotePosition.rawValue` (per `tod-initial-pattern-catalog.md` § *Migration target* reset-on-pattern-change rule). Rest-aware and single-pickable picker behavior is exercised via transient test-fixture `TimingOffsetDetectionPattern` values; the production catalog stays at one entry until 82.7.

## Boundaries & Constraints

**Always:**
- The pattern picker section sits **above** the offset-note-position section in `TimingOffsetDetectionDiscipline.settingsSections`; section ids `tod.patternPicker` and `tod.offsetNotePosition` are TOD-specific (no collision with shared ids).
- Pattern selection writes both `selectedPatternId` *and* `offsetNotePosition` (= new pattern's `defaultOffsetNotePosition.rawValue`). No "preserve when still pickable" path — locked rule from `tod-initial-pattern-catalog.md` § *Migration target*. Re-selecting the active pattern still performs both writes (no `oldId == newId` special case).
- The slot picker iterates `0..<activePattern.subdivisions.count` (grid count). Per-cell type from the pattern: `.note` at grid index 0 → **anchor**; `.note` with audible position in `pickable` → **pickable**; `.rest` → **rest**. `.nested` is unreachable in the initial catalog (constraint 2 of the design doc) but is rendered as an empty cell defensively, never as a tap target.
- Per-cell behavior: **anchor** — large accent dot (`beatOneDotDiameter`), non-tappable, VoiceOver-focusable, label `"Anchor note, not selectable"`. **Pickable** — normal dot (`dotDiameter`), tappable; selected cell also draws the doubled-glyph indicator; VoiceOver label `"Note N of K"` where N = 1-based audible position, K = `pattern.audibleCount`; selected cell appends `", selected"`. **Rest** — no dot drawn, cell width preserved via `Color.clear.frame(width: cellWidth)`, not focusable.
- Pattern picker rows render the static dot-row preview (no `litCount` opacity modulation; all dots full opacity). VoiceOver presents the picker as a `Picker` (native inline `Picker` preferred; `.accessibilityRepresentation { Picker(...) }` if needed). Per-row accessibility label is positional/structural per `tod-initial-pattern-catalog.md` § *Preview Rendering*: `"Accent, note, note, note"` for `pattern_1111`, derived programmatically from `subdivisions` (`.note` at grid 0 → "Accent"; other `.note` → "Note"; `.rest` → "Rest"). No per-pattern display names.
- `TimingDotView` becomes pattern-aware: inputs are `pattern: TimingOffsetDetectionPattern`, `offsetNotePosition: OffsetNotePosition`, `litCount: Int`. The doubled-glyph cell index is `pattern.audibleToGrid[offsetNotePosition.zeroBasedIndex]`, not `offsetNotePosition.zeroBasedIndex`. Closes the deferred-work entry "`TimingDotView.testedNoteIndex` audible-vs-grid mismatch" from 82.5.
- Dot sizing across all three surfaces is centralized on `TimingDotView`'s existing `static let` constants (`beatOneDotDiameter`, `dotDiameter`, `dotSpacing`, `overlapOffset`, `testedNoteFrameWidth`). Both the training-screen size (full scale) and the picker preview size (smaller scale via `@ScaledMetric(relativeTo: .caption2)`, target `beatOneDotDiameter ≈ 14`, `dotDiameter ≈ 10`) derive from those constants; no second set of magic numbers.
- Test fixtures use transient `TimingOffsetDetectionPattern` values constructed in the test body (not registered into `TimingOffsetDetectionPatternCatalog.all`) to exercise rest-aware and single-pickable behavior — e.g. `pattern_test_1011` (audible {2,3}, default 2) and `pattern_test_1010` (audible {2}, default 2). Production catalog stays at one entry until 82.7.
- TOD remains `PEACH_RESEARCH`-gated; new tests follow the surrounding `#if PEACH_RESEARCH` convention.
- Localized strings shipped via `bin/add-localization.swift`, informal `du` per [[feedback_german_informal]]. Sober factual copy per [[feedback_sober_factual_copy]]; no marketing register.
- Help body text drops the hard-coded "four 16th notes" from `offsetNotePositionSettingsHelp` and the training-screen Goal — pattern-agnostic phrasing. Closes the deferred-work entry "Help body strings hard-code 'four 16th notes'".
- Sprint-status key `82-6-pattern-and-slot-picker-settings-ui` flips to `in-progress` on start and `done` after review per [[feedback_update_status_after_review]].

**Ask First:**
- If at AX5 the picker preview row exceeds the row's available width, halt before deciding whether to wrap, shrink the dots, or cap the scale. Per design doc § *Preview Rendering*: "spec the wrap behavior in 82.6, don't auto-wrap silently." **Default plan: cap the picker-preview `@ScaledMetric` so the row stays single-line at AX5; do not wrap.**
- If a `Picker` with custom dot-row labels under `.pickerStyle(.inline)` renders with selection-chrome alignment surprises or label truncation on iOS, halt before switching to a `ForEach`-of-`Button` row layout with `.accessibilityRepresentation { Picker(...) }`. **Default plan: native inline `Picker` with custom labels.**

**Never:**
- No new catalog entries in production. The four remaining catalog patterns ship in 82.7.
- No edits to `TimingOffsetDetectionPattern` or `TimingOffsetDetectionPatternCatalog`. The domain layer is set; UI consumes it.
- No edits to `Beat` / `Subdivision` / `SoundFontStepSequencer`.
- No per-pattern display names. No `LocalizedStringResource` field on pattern entries.
- No "preserve when still pickable" behavior on pattern change.
- No `Section` chrome for categorization (`Straight` / `Gapped`) in the picker. Design doc § *Categorization* mandates flat single-section presentation.
- No tuplet-aware rendering. Equal-cell renderer only.
- No new `@AppStorage` keys — `selectedPatternId` already exists from 82.5.
- No public mutation API on `TimingOffsetDetectionPatternCatalog`. Test fixtures construct values directly.
- No refactor of `GridToggleRow` or `RhythmGapPositionsSettingsSection` from this story; they remain CRM-owned and their a11y improvements stay deferred.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Pattern picker — select a different pattern | Active `pattern_1111`, `offsetNotePosition = 4`. User taps row for fixture `pattern_test_1011` (default 2) | `selectedPatternId = "pattern_test_1011"`, `offsetNotePosition = 2` (reset to new default) | N/A |
| Pattern picker — re-select the active pattern | Active `pattern_1111`, `offsetNotePosition = 4`. User taps `pattern_1111` row | Both writes occur (no special case); `offsetNotePosition` resets to 3 | N/A |
| Slot picker — tap pickable cell | Active `pattern_1111`, `offsetNotePosition = 3`. User taps cell at audible position 4 | `offsetNotePosition = 4` | N/A |
| Slot picker — tap rest cell | Active fixture `pattern_test_1011` (grid 1 = rest) | No-op; rest cell is not focusable, not tappable | N/A |
| Slot picker — tap anchor cell | Active `pattern_1111`. User taps cell at audible position 1 | No-op; cell is focusable for VoiceOver, activation rejected | N/A |
| Slot picker — single-pickable pattern | Active fixture `pattern_test_1010` (pickable {2}), `offsetNotePosition = 2` | Cell at audible position 2 renders selected; tap is a no-op | N/A |
| Slot picker — cell count vs subdivision count | Active fixture `pattern_test_1011` (4 grid subdivisions, 3 audible) | 4 cells (anchor / rest / pickable / pickable) | N/A |
| TimingDotView — pattern with rests | Active fixture `pattern_test_1011`, `offsetNotePosition = 2` (audible 2 → grid 2) | 4 cells; grid 0 large dot; grid 1 empty; grid 2 doubled-glyph; grid 3 normal dot | N/A |
| Pattern row a11y label — `pattern_1111` | `subdivisions = [.note, .note, .note, .note]` | `"Accent, note, note, note"` | N/A |
| Pattern row a11y label — fixture with rests | `subdivisions = [.note, .rest, .note, .note]` | `"Accent, rest, note, note"` | N/A |

</frozen-after-approval>

## Code Map

- `Peach/Training/TimingOffsetDetection/TimingDotView.swift` — Refactor. New signature `init(pattern:, offsetNotePosition:, litCount:)`. `ForEach(pattern.subdivisions.indices, …)` replaces `ForEach(0..<4)`. Per-grid-index dispatch on `Subdivision`: `.rest` → `Color.clear.frame(width: dotDiameter + overlapOffset, height: beatOneDotDiameter)` (preserves column width); `.note` → existing circle (large at grid 0, small otherwise), with doubled-glyph `ZStack` when the index equals `pattern.audibleToGrid[offsetNotePosition.zeroBasedIndex]`; `.nested` → same empty-cell treatment as `.rest`. `litCount` opacity rule unchanged (`opacity = index < litCount ? 1.0 : 0.2`). Size constants stay exposed as `static let`.
- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift` — **NEW**. `Section { Picker(selection: $selectedPatternId) { ForEach(TimingOffsetDetectionPatternCatalog.all, id: \.id) { row(for: $0).tag($0.id) } }.pickerStyle(.inline) } header: { Text("Pattern") } footer: { Text("Pick the rhythmic pattern used for each trial.") }`. `row(for:)` renders a static dot-row preview at `@ScaledMetric` cell size, plus an accessibility label derived programmatically from `subdivisions` ("Accent, note, …, rest"). `.onChange(of: selectedPatternId)` writes `offsetNotePosition = TimingOffsetDetectionPatternCatalog.pattern(forStoredId: selectedPatternId).defaultOffsetNotePosition.rawValue`. Static-helper namespace `Self.patternRowAccessibilityLabel(for: TimingOffsetDetectionPattern) -> String` carries the label derivation for unit tests.
- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionOffsetNotePositionSettingsSection.swift` — Rewrite. Cell iteration over `0..<activePattern.subdivisions.count`. Static classifier `Self.cellKind(for: Subdivision, gridIndex: Int, pickable: Set<Int>, audibleToGrid: [Int]) -> CellKind` (`.anchor | .pickable(audiblePosition: Int) | .rest`) drives per-cell rendering. Pickable cell is a `Button` writing `offsetNotePosition`; anchor cell is plain View with `.accessibilityLabel("Anchor note, not selectable")` and `.accessibilityAddTraits(.isStaticText)`; rest cell is `Color.clear.frame(width: cellSize, height: cellSize).accessibilityHidden(true)`. Doubled-glyph indicator overlays the pickable cell whose audible position equals `effectivePosition.rawValue`.
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionScreen.swift` — Replace the `testedNoteIndex:` argument with `pattern:` and `offsetNotePosition:` on the new `TimingDotView`. Drop the manual `clampedOffsetNotePosition(_:).zeroBasedIndex` line.
- `Peach/Training/TimingOffsetDetection/Discipline/TimingOffsetDetectionDiscipline.swift` — Insert `DisciplineSettingsSection(id: "tod.patternPicker") { TimingOffsetDetectionPatternPickerSettingsSection() }` between the rhythm-tempo entry and `tod.offsetNotePosition`. Insert `TimingOffsetDetectionHelp.patternPickerSettingsHelp` into `settingsHelp` at the matching slot.
- `Peach/Training/TimingOffsetDetection/Help/TimingOffsetDetectionHelp.swift` — Rewrite `offsetNotePositionSettingsHelp` body to pattern-agnostic phrasing ("**Offset Note Position** chooses which note in the pattern carries the timing offset on each trial. The other notes stay on the beat."). Rewrite training-screen Goal body similarly. Add `patternPickerSettingsHelp: [HelpSection]` (one section, "Pattern" title, body explaining catalog/preview vocabulary).
- `Peach/Localizable.xcstrings` — Add German strings via `bin/add-localization.swift`: section header "Pattern", footer "Pick the rhythmic pattern used for each trial.", revised offset-note footer "Pick which note carries the timing offset.", VoiceOver tokens "Accent" / "Note" / "Rest", anchor label "Anchor note, not selectable", revised Goal body, revised offset-note help body, new pattern-picker help title + body. Verify with `bin/add-localization.swift --missing`.
- `PeachTests/Training/TimingOffsetDetection/TimingDotViewTests.swift` — Update or add layout-helper tests for pattern-aware rendering: anchor at grid 0 uses `beatOneDotDiameter`; rest cells produce no dot; doubled-glyph index equals `pattern.audibleToGrid[clamped.zeroBasedIndex]` for a multi-rest fixture pattern (asserts the audible/grid translation directly).
- `PeachTests/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSectionTests.swift` — **NEW** (`#if PEACH_RESEARCH`). Tests the static helpers: `patternRowAccessibilityLabel(for:)` for `pattern_1111` returns `"Accent, note, note, note"`; for a fixture with rests returns the matching positional string; on-change cascade computes the right reset value (`pattern.defaultOffsetNotePosition.rawValue`).
- `PeachTests/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionOffsetNotePositionSettingsSectionTests.swift` — **NEW** (`#if PEACH_RESEARCH`). Static `cellKind(for:gridIndex:pickable:audibleToGrid:)` tests for `pattern_1111`, a multi-rest fixture, and a single-pickable fixture: anchor at grid 0; rest at rest indices; pickable at audible positions ≥ 2. Audible-position derivation matches `audibleToGrid` inverse. Single-pickable case still returns `.pickable` for its one position (selected, no-op tap is enforced by the read-only `effectivePosition`).
- `docs/implementation-artifacts/sprint-status.yaml` — `82-6-pattern-and-slot-picker-settings-ui: in-progress` (flip to `done` after review).
- `docs/implementation-artifacts/deferred-work.md` — Close the two 82.5 entries this story resolves: "`TimingDotView.testedNoteIndex` audible-vs-grid mismatch" and "Help body strings hard-code 'four 16th notes'".

## Tasks & Acceptance

**Execution:**
- [x] `TimingDotView.swift` — pattern-aware rendering; size constants preserved; added `scale: CGFloat`, `previewScale`, and `doubledGlyph(...)` shared primitive
- [x] `TimingOffsetDetectionPatternPickerSettingsSection.swift` — NEW; inline Picker over catalog; on-change cascade; static a11y-label helper
- [x] `TimingOffsetDetectionOffsetNotePositionSettingsSection.swift` — rewrite as N-cell rest-aware picker; static `cellKind` classifier (signature collapsed to `(pattern:, gridIndex:)`); `CellKind.pickable` carries `OffsetNotePosition`
- [x] `TimingOffsetDetectionScreen.swift` — pass `pattern` into `TimingDotView`; drop manual `zeroBasedIndex`
- [x] `TimingOffsetDetectionDiscipline.swift` — register `tod.patternPicker` section and help between tempo and offset-note entries
- [x] `TimingOffsetDetectionHelp.swift` — generic phrasing in `offsetNotePositionSettingsHelp` + training Goal; new `patternPickerSettingsHelp`
- [x] `Localizable.xcstrings` — German translations via `bin/add-localization.swift --batch`; verify `--missing` reports 0; three orphaned "four 16th notes" / "four-note pattern" entries removed
- [x] `TimingDotViewTests.swift` — pattern-aware layout helper tests (incl. audible-vs-grid translation for a multi-rest fixture); dead `isTestedNote` helper + its self-referential test removed
- [x] `TimingOffsetDetectionPatternPickerSettingsSectionTests.swift` — NEW
- [x] `TimingOffsetDetectionOffsetNotePositionSettingsSectionTests.swift` — NEW
- [x] `TimingOffsetDetectionPatternFixtures.swift` — NEW (test helper; factors out `pattern_test_1011` / `pattern_test_1010` for the three test files that consume them)
- [x] `TimingOffsetDetectionDisciplineTests.swift` — updated for the 4-entry `settingsSections` order and the `patternPickerSettingsHelp` insertion
- [x] `sprint-status.yaml` — flipped `82-6-…` to `in-progress`
- [x] `deferred-work.md` — closed the two 82.5 entries this story resolves
- [x] Pre-commit: `bin/test.sh --research && bin/test.sh --research -p mac && bin/test.sh && bin/test.sh -p mac` — all four green (1980 / 1974 / 1535 / 1529)
- [ ] Manual smoke: Launch `Peach (Debug, Research)`; verify Settings shows **Pattern** above **Offset Note Position**; slot picker shows the anchor cell as non-tappable

**Acceptance Criteria:**
- Given the Settings screen in a Research build with `pattern_1111` selected, when opened, then the **Pattern** section shows one row with the four-dot preview (large accent + three normal dots) and the selected-state checkmark; the **Offset Note Position** section shows four cells with the anchor non-tappable and audible position 3 selected by default.
- Given a test fixture `pattern_test_1011` (subdivisions `.note, .rest, .note, .note`, pickable `{2,3}`, default 2), when made the active pattern in a unit test of the slot picker, then the picker classifies cells as `anchor, rest, pickable(2), pickable(3)` and only the two pickable cells respond to taps.
- Given a single-pickable fixture `pattern_test_1010` (subdivisions `.note, .rest, .note, .rest`, pickable `{2}`, default 2), when made active in a unit test, then `effectivePosition.rawValue == 2` and the pickable cell's selected state is true regardless of the stored `@AppStorage` value (clamped via `pattern.clampedOffsetNotePosition`).
- Given the user taps a different pattern row in the picker, when the on-change handler fires, then both `selectedPatternId` and `offsetNotePosition` are written; `offsetNotePosition` equals the new pattern's `defaultOffsetNotePosition.rawValue`.
- Given the training screen with `pattern_1111` selected and `offsetNotePosition = 3`, when rendered, then `TimingDotView`'s doubled-glyph cell sits at grid index 2 (audible→grid identity for `pattern_1111`).
- Given a multi-rest fixture pattern (`pattern_test_1011`) with audible position 2 stored, when `TimingDotView` is rendered, then the doubled-glyph cell sits at grid index `pattern.audibleToGrid[1] == 2`, not at audible index 1.
- Given `TimingOffsetDetectionPatternPickerSettingsSection.patternRowAccessibilityLabel(for:)`, when called with `pattern_1111`, then it returns `"Accent, note, note, note"`; when called with `pattern_test_1011`, then it returns `"Accent, rest, note, note"`.
- Given `bin/add-localization.swift --missing`, when run after this story, then `0 keys missing German translation`.
- Both pre-commit gates pass on iOS and macOS for both Research and non-Research schemes.

## Spec Change Log

### 2026-06-04 — Review iteration 1 (patches only; no loopback)

**Triggering findings (deduplicated across blind hunter / edge case hunter / acceptance auditor):**

- **Unknown stored id desynchronizes the two `@AppStorage` keys.** `patternIdBinding.set` wrote `selectedPatternId = newId` verbatim while `offsetNotePosition` was derived from the *resolved* pattern (the catalog default for unknown ids). Storage ended up with an unknown id and the default pattern's offset — readers re-clamped, but persistence stayed self-inconsistent.
- **`patternIdBinding` cascade has no unit test.** The "write both keys on every selection" rule was asserted only in prose and review; a regression to no-reset or wrong-order would be undetectable.
- **Anchor cell has no `.isStaticText` trait.** The cell carries `"Anchor note, not selectable"` as its accessibility label, but VoiceOver / Switch Control received no trait signal that the element is informational — auto-scan and rotor heuristics could still treat it as actionable.

**Amendments outside the frozen block (patches only — frozen block untouched):**

- `TimingOffsetDetectionPatternPickerSettingsSection.swift` — extracted `static func cascadeWrites(forNewId:) -> (selectedPatternId: String, offsetNotePosition: Int)`. The binding setter calls it and writes the *resolved* pattern id, not the user-supplied id.
- `TimingOffsetDetectionPatternPickerSettingsSectionTests.swift` — added `cascadeWritesForKnownId` and `cascadeWritesForUnknownId` tests pinning the resolver behavior and the "unknown id collapses to default" rule.
- `TimingOffsetDetectionOffsetNotePositionSettingsSection.swift` — added `.accessibilityAddTraits(.isStaticText)` on the anchor cell so assistive tech reads it as informational.

**Defers:** None — every other reviewer finding is rejected as either intentionally locked by the spec (always-reset, "Note N of K" with K = audibleCount, anchor's distinct label, no per-rest VoiceOver focus), addressed by the static helper extraction, or out of scope per the spec's "Never" rules (`OffsetNotePosition.validRange` widening, catalog edits).

**KEEP (re-derivation must preserve):**

- The atomic-cascade pattern: both `@AppStorage` keys written in one binding-set call, with the resolved pattern's id (never the user-supplied id verbatim).
- The static `cascadeWrites(forNewId:)` helper as the test boundary for the reset rule.
- The anchor cell's explicit `.isStaticText` trait alongside the `"Anchor note, not selectable"` label.

**Known-bad states avoided:**

- A future debug write of an invalid pattern id staying in storage and surfacing on every relaunch as a `.warning` log entry from the port.
- A future contributor flipping the binding's write order or dropping the reset, with no test trip.
- Switch Control users landing on the anchor cell expecting it to be actionable.

## Design Notes

**Why `TimingDotView` takes the pattern directly (not a `[Subdivision]` + offset grid index):** the doubled-glyph cell index is `pattern.audibleToGrid[offsetNotePosition.zeroBasedIndex]`. Pushing that translation into the view means callers pass the same `OffsetNotePosition` they already hold and never re-derive the map. A separate mask would split the source of truth away from `TimingOffsetDetectionPattern.audibleToGrid`, recreating the audible-vs-grid bug shape the design doc flags.

**Why native inline `Picker` with custom labels (not a `ForEach` of Buttons + `.accessibilityRepresentation`):** a SwiftUI `Picker` vends as a single accessibility element with rotor-navigable options and platform-native selection chrome (checkmark on iOS, radio on macOS) for free. A custom layout needs `.accessibilityRepresentation { Picker(...) }` to recover the same semantics, plus manual selection-chrome rendering. The rows still use custom labels (the dot-row preview); SwiftUI's `Picker` accepts arbitrary `View` labels per option.

**Why reset on every pattern change, including re-selecting the active pattern:** `tod-initial-pattern-catalog.md` § *Migration target* / *Cross-pattern semantics* locks "always reset" as the simpler invariant. Treating re-selection as a no-op would require special-casing `oldId == newId`; the storage layer absorbs the rewrite harmlessly. Less code path → fewer places for future inconsistency.

**Why test fixtures over expanding the production catalog:** the production catalog is 82.7's deliberate content rollout. Registering rest patterns in 82.6 would split content ownership across stories. Test fixtures (transient `TimingOffsetDetectionPattern` values constructed in test bodies, not registered) exercise the picker's rest-aware and single-pickable paths without polluting the production registry.

**Why the slot picker's static `cellKind` classifier is the test boundary:** SwiftUI views are not unit-testable in this project (we never instantiate them in tests); the layout logic lives in pure static helpers per the project's "extract layout to static methods" convention. `cellKind(for: pattern, gridIndex:)`, `patternRowAccessibilityLabel(for:)`, and the review-iteration `cascadeWrites(forNewId:)` are those helpers — full per-cell-type coverage and per-cascade-rule coverage is achievable without rendering a view.

## Verification

**Commands:**
- `bin/test.sh --research` — expected: full suite green on iOS (Debug, Research)
- `bin/test.sh --research -p mac` — expected: full suite green on macOS (Debug, Research)
- `bin/test.sh` — expected: full suite green on iOS (Debug, non-Research)
- `bin/test.sh -p mac` — expected: full suite green on macOS (Debug, non-Research)
- `bin/build.sh --research` — expected: zero new warnings
- `bin/add-localization.swift --missing` — expected: `0 keys missing German translation`

**Manual checks:**
- Launch `Peach (Debug, Research)`. Settings → TOD section shows a **Pattern** section above **Offset Note Position**. The Pattern section has one row (the only catalog entry) with the four-dot preview at smaller scale than the training screen, plus the selected-state chrome.
- Slot picker on the Offset Note Position section: the leftmost cell is the large accent dot (non-tappable; VoiceOver reads "Anchor note, not selectable"); the next three cells are tappable normal dots; the cell at audible position 3 shows the doubled-glyph indicator by default. Tapping cells 2 or 4 moves the indicator.
- Training screen: `TimingDotView` continues to light dots in playback order; the doubled-glyph cell sits at the audible position the slot picker shows.
- Force a known-bad UserDefaults state in Research: `defaults write de.schuerig.peach.research timingOffsetDetectionOffsetNotePosition -int 1`; relaunch. Both the slot picker selection and the training-screen indicator land on audible position 3 (the active pattern's default) — port + view agree via the shared clamp.

## Suggested Review Order

**Pattern picker — Settings row UX**

- Entry point: the new Settings section. Native inline `Picker` over the catalog with custom dot-row labels and atomic cascade-write to both `@AppStorage` keys.
  [`TimingOffsetDetectionPatternPickerSettingsSection.swift:23`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift#L23)

- Atomic cascade — static helper resolves the user-supplied id, then writes both `selectedPatternId` (resolved) and `offsetNotePosition` (= new pattern's default). Test boundary for the reset-on-pattern-change rule. Added during review-iteration 1 to fix the unknown-id desync surfaced by the blind hunter.
  [`TimingOffsetDetectionPatternPickerSettingsSection.swift:58`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift#L58)

- Programmatic accessibility label — derived structurally from `subdivisions`, not from per-pattern display names (which the design doc forbids).
  [`TimingOffsetDetectionPatternPickerSettingsSection.swift:73`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift#L73)

**Slot picker — rest-aware N-cell classification**

- The `CellKind` enum + static classifier; the test boundary for the slot picker. `CellKind.pickable` carries `OffsetNotePosition` (not `Int`) per the project's "domain types everywhere" rule.
  [`TimingOffsetDetectionOffsetNotePositionSettingsSection.swift:121`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionOffsetNotePositionSettingsSection.swift#L121)

- Per-cell rendering dispatch: anchor (large dot, `.isStaticText` trait), pickable (Button with shared `doubledGlyph` when selected), rest (empty cell, hidden from VoiceOver). Anchor `.isStaticText` added during review iteration so assistive tech treats the cell as informational.
  [`TimingOffsetDetectionOffsetNotePositionSettingsSection.swift:54`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionOffsetNotePositionSettingsSection.swift#L54)

**Training-screen indicator — pattern-aware doubled-glyph**

- `TimingDotView` is now pattern-driven: `ForEach(pattern.subdivisions.indices, …)` + audible→grid translation via `pattern.audibleToGrid`. Closes the 82.5 deferred-work entry "audible-vs-grid mismatch."
  [`TimingDotView.swift:32`](../../Peach/Training/TimingOffsetDetection/TimingDotView.swift#L32)

- Shared `doubledGlyph(diameter:overlapOffset:)` — one primitive serves training screen, pattern preview, and slot picker so the visual vocabulary stays in lockstep.
  [`TimingDotView.swift:89`](../../Peach/Training/TimingOffsetDetection/TimingDotView.swift#L89)

- `offsetGridIndex(for:offsetNotePosition:)` — the audible→grid helper extracted as a static method for the test boundary.
  [`TimingDotView.swift:107`](../../Peach/Training/TimingOffsetDetection/TimingDotView.swift#L107)

- The screen call site — minimal change; just passes `pattern` + the clamped position into the new initializer.
  [`TimingOffsetDetectionScreen.swift:26`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionScreen.swift#L26)

**Discipline registration & help**

- `tod.patternPicker` inserted between the rhythm-tempo and the offset-note-position sections; `patternPickerSettingsHelp` joins `settingsHelp` in matching position.
  [`TimingOffsetDetectionDiscipline.swift:50`](../../Peach/Training/TimingOffsetDetection/Discipline/TimingOffsetDetectionDiscipline.swift#L50)

- Help bodies — pattern-agnostic phrasing replaces "four 16th notes" / "four-note pattern"; new `patternPickerSettingsHelp`. Closes the 82.5 deferred-work entry "Help body strings hard-code 'four 16th notes'."
  [`TimingOffsetDetectionHelp.swift:24`](../../Peach/Training/TimingOffsetDetection/Help/TimingOffsetDetectionHelp.swift#L24)

**Tests**

- Test fixtures — `pattern_test_1011` (rest-bearing) and `pattern_test_1010` (single-pickable) factored out of three inline duplications so the rest-aware and single-pickable picker paths share one source of truth.
  [`TimingOffsetDetectionPatternFixtures.swift:9`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionPatternFixtures.swift#L9)

- Pattern picker tests — accessibility label derivation + the cascade-writes resolver including the unknown-id path (review-iteration 1 patch).
  [`TimingOffsetDetectionPatternPickerSettingsSectionTests.swift:36`](../../PeachTests/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSectionTests.swift#L36)

- Slot picker tests — `cellKind` shape for the three patterns (catalog + two fixtures); `pickableCellLabel` uses audible count, not grid count.
  [`TimingOffsetDetectionOffsetNotePositionSettingsSectionTests.swift:18`](../../PeachTests/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionOffsetNotePositionSettingsSectionTests.swift#L18)

- `TimingDotView` tests — audible→grid translation pinned for both the identity case (pattern_1111) and the rest-bearing case (`pattern_test_1011`); dead `isTestedNote` tautology removed.
  [`TimingDotViewTests.swift:55`](../../PeachTests/Training/TimingOffsetDetection/TimingDotViewTests.swift#L55)

- Discipline contribution test updated for the 4-entry section order + concatenated help.
  [`TimingOffsetDetectionDisciplineTests.swift:9`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionDisciplineTests.swift#L9)

**Status & deferred work**

- Two 82.5 deferred-work entries closed by this story.
  [`deferred-work.md`](./deferred-work.md)

- Sprint key flipped in lockstep with the spec status.
  [`sprint-status.yaml`](./sprint-status.yaml)
