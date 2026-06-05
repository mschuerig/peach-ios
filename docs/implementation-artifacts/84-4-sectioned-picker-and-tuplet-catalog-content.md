---
title: 'Story 84.4: Sectioned picker and tuplet catalog content'
type: 'feature'
created: '2026-06-05'
status: 'done'
baseline_commit: '64fd5a727eea27cff24a130b11bc25ed6daf0446'
context:
  - '{project-root}/docs/planning-artifacts/tod-tuplet-renderer-design.md'
  - '{project-root}/docs/implementation-artifacts/epic-84-context.md'
  - '{project-root}/docs/implementation-artifacts/84-3-proportional-timeline-renderer.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Epic 84's tuplet expansion stops one step short of the user: 84.3 shipped the proportional-timeline renderer, the recursive `audibleToGrid`, the nested-bracket and "in triplet" / "in duplet" / "dotted" label paths, and seven `@Test(.disabled("Enabled by Story 84.4 catalog registration of pattern_06..15"))` stubs — but no tuplet entries are registered, the picker remains a five-row flat list, and the disabled stubs still skip. The user sees no tuplet patterns; the renderer's nested-figure code paths are unverified end-to-end.

**Approach:** Register `pattern_06` … `pattern_15` as ten new `static let` instances on `TimingOffsetDetectionPattern` matching the locked *Catalog* table (subdivision shapes, `defaultOffsetNotePosition`, `dottedAudiblePositions`); extend `TimingOffsetDetectionPatternCatalog.all` to include them in the design-doc display order. Replace `TimingOffsetDetectionPatternPickerSettingsSection`'s drill-down `Picker` with a sectioned `Form { ForEach(sections) { Section(header:) { Picker(...) } } }` structure backed by a new `TimingOffsetDetectionPatternSection` enum keyed by bucket. Register the five new German section-header strings via `bin/add-localization.swift`. Flip the seven disabled stubs in `TimingDotViewTests` + three in `TimingOffsetDetectionPatternPickerSettingsSectionTests` to enabled with the locked expected outputs. Add catalog-content regression tests and a bucket-membership test.

## Boundaries & Constraints

**Always:**
- Register exactly the 10 entries from `tod-tuplet-renderer-design.md` § *Catalog* in display order: `pattern_06` (`* * *`), `pattern_07` (`* * -`), `pattern_08` (`* - *`), `pattern_09` (`* *. .`), `pattern_10` (`* *-*-*`), `pattern_11` (`*-*-* *`), `pattern_12` (`* * .-.`), `pattern_13` (`* .-. *`), `pattern_14` (`.-. * *`), `pattern_15` (`. . . . . .`). Each entry uses the *Beat builder shape* column verbatim: flat `[Subdivision]` for `06`/`07`/`08`/`09`/`15`; top-level subdivisions containing `.nested(Beat(subdivisions: [.note, ...]))` for `10`/`11`/`12`/`13`/`14`. `pattern_09`'s shape is the 6-cell sextuplet grid `n r n r r n` (multi-cell hold via flat-rest representation); its `dottedAudiblePositions = [2]`. Every entry's `defaultOffsetNotePosition` matches the *Catalog* table's *Default* column. All `.note` cells use `.zero` offset; audible 1 is `RhythmVelocity.accent`, all other audibles are `RhythmVelocity.normal`.
- `TimingOffsetDetectionPatternCatalog.all` lists all 15 entries in design-doc display order (`pattern_01` … `pattern_15`). The catalog header comment's *category roster* sentence updates to reference the five buckets locked in `tod-tuplet-renderer-design.md` § *Categorization*; the picker rendering note is rewritten to say the picker presents the entries sectioned by bucket (no longer "flat").
- A new `TimingOffsetDetectionPatternSection` enum lives in `TimingOffsetDetectionPatternCatalog.swift` (same file, no separate file) with cases `straight16ths`, `gapped16ths`, `triplets`, `nested`, `sextuplet` in picker-display order. Each case carries `localizedHeader: String` (returning `String(localized: "Straight 16ths")` etc.) and `patternIds: [String]` (the ordered ids that belong to this bucket). The catalog exposes `static let sections: [TimingOffsetDetectionPatternSection]` returning all five cases in order. Bucket assignment matches `tod-tuplet-renderer-design.md` § *Categorization* exactly: *Straight 16ths* = `[pattern_01]`; *Gapped 16ths* = `[pattern_02, pattern_03, pattern_04, pattern_05]`; *Triplets* = `[pattern_06, pattern_07, pattern_08, pattern_09]`; *Nested* = `[pattern_10, pattern_11, pattern_12, pattern_13, pattern_14]`; *Sextuplet* = `[pattern_15]`.
- `TimingOffsetDetectionPatternPickerDestination`'s `Form` body becomes `ForEach(TimingOffsetDetectionPatternCatalog.sections, id: \.self) { section in Section { Picker(selection: patternIdBinding) { ForEach(section.patternIds, id: \.self) { id in row(...).tag(id) } } ... } header: { Text(section.localizedHeader) } }`. Each section renders one inline `Picker` so selection across sections still cascades through the existing `patternIdBinding`. No `.lineLimit` or `.truncationMode` applied to section headers — SwiftUI default wrapping is the locked behaviour per design doc § *Categorization*.
- Section headers register in `Localizable.xcstrings` via `bin/add-localization.swift "<English>" "<German>"` (one call per pair, since `add-localization.swift` has no `--batch` flag in this repo): "Straight 16ths" / "Gerade Sechzehntel"; "Gapped 16ths" / "Lückenhafte Sechzehntel"; "Triplets" / "Triolen"; "Nested" / "Verschachtelt"; "Sextuplet" / "Sextolen". `bin/add-localization.swift --missing` reports `0` after the additions.
- The seven disabled stubs in `PeachTests/Training/TimingOffsetDetection/TimingDotViewTests.swift` (lines 265/272/277/282/287/292/297) and the three in `PeachTests/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSectionTests.swift` (lines 102/107/112) all flip to enabled with assertions filled in against the *I/O & Edge-Case Matrix* expected values. The `@Test(.disabled(...))` markers are removed, not preserved.
- New `TimingOffsetDetectionPatternCatalogTests` regressions: (i) `allListsAllFifteenCatalogEntriesInDisplayOrder` replaces today's five-entry check with the full ordered list; (ii) `catalogIdsMatchOpaqueConvention` extends to `pattern_01` … `pattern_15`; (iii) `catalogEntrySubdivisions` parameterized arguments extend to cover `pattern_06` … `pattern_15` cell-by-cell (matching the *Typed leaf sequence* column with explicit nested-child expansion); (iv) new `sectionsCoverEveryPatternExactlyOnce` asserts `Set(sections.flatMap(\.patternIds)) == Set(all.map(\.id))` and total counts match; (v) new `dottedAudiblePositionsLockedToPattern09` asserts `pattern_09.dottedAudiblePositions == [2]` and every other pattern's set is empty.
- Pre-commit gate: `bin/test.sh && bin/test.sh -p mac` green on `Debug`. `archlint Peach/` green. `bin/check-dependencies.sh` green. `bin/add-localization.swift --missing` reports `0`.
- Sprint status: this story's row in `docs/implementation-artifacts/sprint-status.yaml` advances `backlog → in-progress` at start, `in-progress → review` at hand-off, `review → done` at acceptance; `epic-84` row advances `in-progress → done` when this story closes (84.4 is the epic's last non-optional story).

**Ask First:**
- If the sectioned `Form` shows two `Section`s adjacent without visible header separation on iOS or macOS (because each section is a separate `Picker`), HALT — the locked design assumes section headers are visually distinct. Possible mitigations are `Form` styling overrides or wrapping the `Picker`s differently; surface for design decision before committing a visual workaround.
- If the picker-row composite-label test for `pattern_11` (`*-*-* *`) reads `"Accent, in triplet, Note 2 of 4, in triplet, …"` instead of `"Accent, Note 2 of 4, in triplet, …"` — the leading-nest accent extension was already shipped in 84.3's renderer (`childDivision(forAudiblePosition: 1, ...)` returns the nested division), so the expected string in the test is the *with*-extension form. If the assertion fails the *other* direction (label has no "in triplet" on position 1), it means 84.3's accent branch is not firing for the leading-nest case — HALT and re-examine before rewriting the test expectation.
- If `pattern_13` (`* .-. *`) and `pattern_14` (`.-. * *`) appear visually indistinguishable in the picker preview at AX1 during the manual verification step, HALT per `tod-tuplet-renderer-design.md` § *Pairwise distinguishability check* "Borderline at AX1" row. The locked fallback (drop `pattern_13`, record retirement in the catalog header comment block) is a known-bad-state mitigation, not a default; reach for it only after Michael confirms visually.
- If any `.nested(Beat(...))` construction in a `static let` triggers a compiler error about `Beat` not being usable in a constant-expression context (e.g. `static let` not allowing nested constructors at top level), HALT — surface as a structural issue with how the engine types compose, not a workaround to inline.

**Never:**
- No new engine changes. `Core/Audio/SequencerTypes.swift` (`Beat`, `Subdivision`) is untouched. Every catalog entry is expressible via existing primitives — flat `[.note, .rest]` arrays for `06`/`07`/`08`/`09`/`15`, `.nested(Beat(subdivisions: [...]))` for `10`/`11`/`12`/`13`/`14`.
- No renderer changes. `TimingDotView`'s `visualCells(for:)`, `cellAccessibilityLabel(for:in:)`, `audiblePositionToHighlight(...)`, bracket geometry, leading-nest accent branch, and dotted descriptor branch all shipped in 84.3 and stay untouched in 84.4. If any tuplet entry's rendered output deviates from § *Cell-width math* or § *Per-cell accessibility labels*, that is a renderer bug — re-open 84.3, do not patch the catalog entry to mask it.
- No catalog reordering of `pattern_01` … `pattern_05`. Their ids and array positions in `all` are stable; the five entries' bucket assignment per § *Categorization* may surprise future readers (`pattern_04` is *Gapped 16ths*, not *Straight 16ths* — already documented in the design doc), but the locked rule is "host division 4 + contains rests → Gapped 16ths."
- No `@AppStorage` migration shim, no `UserDefaults` reset. `selectedPatternId` defaults to `pattern_01` and unknown-id fallback already lands there; users with previously-stored `pattern_01` … `pattern_05` see no change. Users with no stored id (first launch after this story lands) see the sectioned picker with `pattern_01` selected — same default-pattern behaviour as before the story.
- No new section beyond the five locked buckets. *Straight 16ths*, *Gapped 16ths*, *Triplets*, *Nested*, *Sextuplet* exhaustively partition the Epic-84 catalog by the design doc's locked rule. Future bucket additions belong in a successor epic per § *Categorization* "Rule of thumb for future additions."
- No localized per-pattern names or display strings beyond what the design doc locks. Pattern identity is the visual preview; per-cell `accessibilityLabel`s carry the screen-reader burden. Section headers are the only localized strings new to 84.4.
- No "TOD" in any new code identifier introduced. No new top-level types outside the TOD feature directory (`TimingOffsetDetectionPatternSection` lives inside `TimingOffsetDetectionPatternCatalog.swift`). No emojis. No marketing copy. No "displaced" or "swing" terminology anywhere new (load-bearing per `feedback_tod_no_displaced_term`).
- No partial commit. Catalog entries + section enum + picker chrome + localization + test flips land as one commit per the project's "one commit per story" rule.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| `TimingOffsetDetectionPatternCatalog.all` after this story | Read the static array | 15 entries in order `pattern_01` … `pattern_15`; `count == 15`; ids match `["pattern_01", ..., "pattern_15"]` | N/A |
| `TimingOffsetDetectionPatternCatalog.sections` | Read the static array | 5 entries: `.straight16ths`, `.gapped16ths`, `.triplets`, `.nested`, `.sextuplet` in that order; `patternIds` per the *Categorization* table | N/A |
| `visualCells` for `pattern_06` (`* * *`) | `TimingDotView.visualCells(for: .pattern06)` | 3 cells at start-x `[0, 1/3, 2/3]`, widths `[1/3, 1/3, 1/3]`, kinds `[.accent, .normalAudible(2), .normalAudible(3)]` | N/A |
| `visualCells` for `pattern_09` (`* *. .`) | `TimingDotView.visualCells(for: .pattern09)` | 3 content cells at start-x `[0, 2/6, 3/6]`, widths `[2/6, 3/6, 1/6]`, kinds `[.accent, .normalAudible(2), .normalAudible(3)]` (no orphan rest; rests absorbed) | N/A |
| `visualCells` for `pattern_10` (`* *-*-*`) | `TimingDotView.visualCells(for: .pattern10)` | 4 content cells + 1 bracket. Content: `[(0, 1/2, .accent), (1/2, 1/6, .normalAudible(2)), (1/2 + 1/6, 1/6, .normalAudible(3)), (1/2 + 2/6, 1/6, .normalAudible(4))]`; bracket: `(1/2, 1/2, .nestingBracket(.triplet))` (spans nested-child cells) | N/A |
| `cellAccessibilityLabel` for `pattern_09` audible 2 | dotted-descriptor branch | `"Note 2 of 3, dotted"` (German: `"Note 2 von 3, punktiert"`) | N/A |
| `cellAccessibilityLabel` for `pattern_11` audible 1 (leading-nest accent) | leading-nest branch | `"Accent, in triplet"` (German: `"Akzent, in Triole"`) | N/A |
| `cellAccessibilityLabel` for `pattern_14` audible 1 (leading-nest accent, duplet) | leading-nest branch | `"Accent, in duplet"` (German: `"Akzent, in Duole"`) | N/A |
| `cellAccessibilityLabel` for `pattern_13` audibles 2 & 3 (middle-duplet) | nested-context branch | audible 2 → `"Note 2 of 4, in duplet"`; audible 3 → `"Note 3 of 4, in duplet"` | N/A |
| Composite label for `pattern_10` row | `patternRowAccessibilityLabel(for: .pattern10)` | `"Accent, Note 2 of 4, in triplet, Note 3 of 4, in triplet, Note 4 of 4, in triplet"` | N/A |
| Composite label for `pattern_09` row | `patternRowAccessibilityLabel(for: .pattern09)` | `"Accent, Note 2 of 3, dotted, Note 3 of 3"` | N/A |
| Composite label for `pattern_14` row | `patternRowAccessibilityLabel(for: .pattern14)` | `"Accent, in duplet, Note 2 of 4, in duplet, Note 3 of 4, Note 4 of 4"` | N/A |
| Pattern-change reclamp (Epic 82.6 invariant) | `cascadeWrites(forNewId: "pattern_06")` | `(selectedPatternId: "pattern_06", offsetNotePosition: 2)` (the locked default) | N/A |
| `pattern_09.beat(offsetNotePosition: OffsetNotePosition(2), offsetAmount: .milliseconds(20))` | recursive rebuild | top-level `subdivisions[2]` (the `.note` at sextuplet cell 3) carries `offset = .milliseconds(20)`; all other notes carry `.zero`; rests preserved at cells 1, 3, 4 | N/A |
| `pattern_10.beat(offsetNotePosition: OffsetNotePosition(3), offsetAmount: .milliseconds(20))` | recursive rebuild into `.nested` child | top-level `subdivisions[1]` is `.nested(Beat(subdivisions: [.note(zero), .note(20ms), .note(zero)]))` (offset applied to nested child index 1, the second triplet note); top-level `subdivisions[0]` is `.note(zero)` | N/A |
| Bucket coverage invariant | `Set(sections.flatMap(\.patternIds))` | equals `Set(all.map(\.id))`; `sections.flatMap(\.patternIds).count == all.count` (no duplicates, no omissions) | N/A |
| Section headers localized | `bin/add-localization.swift --missing` after running registrations | `0 keys missing German translation` | N/A |

</frozen-after-approval>

## Code Map

- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPattern.swift` — append ten new `static let pattern06` … `pattern15` instances in the existing `extension TimingOffsetDetectionPattern { ... // MARK: - Static catalog entries }`. Each instance's `subdivisions` matches the *Catalog* table's *Beat builder shape* column; `defaultOffsetNotePosition` matches the *Default* column; `pattern09` sets `dottedAudiblePositions: [2]`; the rest use the default `[]`. Doc comment per entry: one short paragraph describing the rhythmic figure and Adam's per-entry default rationale (≤4 lines).
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPatternCatalog.swift` — `all` extends to 15 entries in `pattern_01` … `pattern_15` order. Header comment's *category roster* sentence updates to reference the five Epic-84 buckets; "picker presents them flat" rewrites to "picker presents them sectioned by bucket per `TimingOffsetDetectionPatternCatalog.sections`". A new `enum TimingOffsetDetectionPatternSection` is appended at file scope (after the catalog `enum`, before `TimingOffsetDetectionPatternCatalogError`) with cases `straight16ths`/`gapped16ths`/`triplets`/`nested`/`sextuplet`, computed `localizedHeader`, and `patternIds`. `TimingOffsetDetectionPatternCatalog.sections` returns `[.straight16ths, .gapped16ths, .triplets, .nested, .sextuplet]`.
- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift` — `TimingOffsetDetectionPatternPickerDestination.body` replaces today's single `Section { Picker { ForEach(catalog.all) } }` with `ForEach(catalog.sections, id: \.self) { section in Section { Picker { ForEach(section.patternIds) { row.tag } } header: { Text(section.localizedHeader) } } }`. Outer row + composite label unchanged. The pattern lookup inside the inner `ForEach` resolves via `try? catalog.pattern(withId: id)` with the `Set`-default skipped; `forStoredId` is fine as the safe variant.
- `Peach/Resources/Localizable.xcstrings` — adds five header strings: `"Straight 16ths"` → `"Gerade Sechzehntel"`, `"Gapped 16ths"` → `"Lückenhafte Sechzehntel"`, `"Triplets"` → `"Triolen"`, `"Nested"` → `"Verschachtelt"`, `"Sextuplet"` → `"Sextolen"`. Use `bin/add-localization.swift "<English>" "<German>"` once per pair. No other strings change.
- `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionPatternTests.swift` — extend existing `audibleToGrid` parameterized expectations to cover `pattern_06` … `pattern_15` (the locked `audibleToGrid` shape derives from the *Typed leaf sequence* column: e.g. `pattern_10` is `[[0], [1, 0], [1, 1], [1, 2]]`). Extend `beat(...)` regression to cover `pattern_09` (sextuplet-grid rebuild, offset lands on a top-level `.note`) and `pattern_10` (nested-child rebuild, offset lands inside `.nested(Beat)`). Add `dottedAudiblePositions` assertion for `pattern_09`.
- `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionPatternCatalogTests.swift` — replace `allListsFiveCatalogEntriesInDisplayOrder` with `allListsAllFifteenCatalogEntriesInDisplayOrder` (full 15-entry equality check); extend `catalogIdsMatchOpaqueConvention` to `["pattern_01", …, "pattern_15"]`; extend `catalogEntrySubdivisions` `arguments` to include `pattern_06` … `pattern_15`, with new `Cell` cases as needed (the existing `Cell` enum is `accent`/`normal`/`rest` — for nested entries, add `case nested([Cell])` and a recursive matcher in the switch). Add `sectionsCoverEveryPatternExactlyOnce` and `dottedAudiblePositionsLockedToPattern09`. Add `sectionsListThreeBucketsInOrder` (assert the five `TimingOffsetDetectionPatternSection` cases come back in `[straight16ths, gapped16ths, triplets, nested, sextuplet]` order — name kept "Three" for grep-collision avoidance per the design doc's five-bucket lock).
- `PeachTests/Training/TimingOffsetDetection/TimingDotViewTests.swift` — flip the seven `@Test(.disabled("Enabled by Story 84.4 catalog registration of pattern_06..15"))` stubs (lines 265/272/277/282/287/292/297) to active tests; fill assertions per the *I/O & Edge-Case Matrix* expected values. Remove `.disabled(...)` markers. Add `visualCellsPattern11LeadingNestedTriplet`, `visualCellsPattern15Sextuplet`, and one bracket-cell start/width assertion per nested entry (`pattern_10` through `pattern_14`).
- `PeachTests/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSectionTests.swift` — flip the three disabled stubs (lines 102/107/112) to active tests with assertions per the *I/O & Edge-Case Matrix* composite-label rows. Add `cascadeWritesForPattern06ResetsOffsetNotePositionToTwo` and one analogous test per new default-position value (one per distinct default in the catalog: position 2 covers `06`/`07`/`08`/`09`/`14`; position 3 covers `10`/`11`/`13`; position 4 covers `12`/`15` — three tests parameterized over distinct (id, default) pairs is sufficient).
- `docs/implementation-artifacts/sprint-status.yaml` — `84-4-sectioned-picker-and-tuplet-catalog-content` row advances `backlog → in-progress → review → done`; `epic-84` row advances `in-progress → done` on acceptance.

## Tasks & Acceptance

**Execution:**
- [x] `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPattern.swift` — appended ten `static let` instances `pattern06` … `pattern15` per the *Catalog* table. Nested entries use `.nested(Beat(subdivisions: [...]))` inline; `pattern09` sets `dottedAudiblePositions: [2]`. Per-entry doc comments cite the notation, audibleToGrid shape, pickable set, and Adam-approved default rationale.
- [x] `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPatternCatalog.swift` — extended `all` to 15 entries; rewrote header comment's *category roster* + picker rendering sentences; added `enum TimingOffsetDetectionPatternSection: CaseIterable, Hashable` with `localizedHeader: String` + `patternIds: [String]`; added `static let sections: [TimingOffsetDetectionPatternSection]`.
- [x] `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift` — rewrote `TimingOffsetDetectionPatternPickerDestination.body` to iterate `catalog.sections`, emitting one `Section` per bucket with an inline `Picker(selection: patternIdBinding)` over `section.patternIds`. Outer row and `patternRowAccessibilityLabel(for:)` unchanged.
- [x] Localization: ran five `bin/add-localization.swift` calls — "Straight 16ths" / "Gerade Sechzehntel", "Gapped 16ths" / "Lückenhafte Sechzehntel", "Triplets" / "Triolen", "Nested" / "Verschachtelt", "Sextuplet" / "Sextolen". `bin/add-localization.swift --missing` reports `0`.
- [x] `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionPatternTests.swift` — added `tupletCatalogEntryShape` (10-entry parameterized check over audibleToGrid/audibleCount/pickable/default/subdivisionCount), `dottedAudiblePositionsLockedToPattern09`, `beatForPattern09PlacesOffsetOnAudibleSextupletCell`, `beatForPattern10PlacesOffsetOnNestedMiddleLeaf`.
- [x] `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionPatternCatalogTests.swift` — replaced 5-entry checks with 15-entry checks; extended `catalogEntrySubdivisions` to cover all 15 entries with `Cell.nested([Cell])` and a depth-recursive `expectSubdivisions` matcher; added `sectionsListBucketsInOrder`, `sectionsCoverEveryPatternExactlyOnce`, `sectionIdsResolveToCatalogPatterns`, `sectionMembership`.
- [x] `PeachTests/Training/TimingOffsetDetection/TimingDotViewTests.swift` — flipped seven `.disabled(...)` stubs to active; added `visualCellsPattern07TripletTrailingRest`, `visualCellsPattern08TripletMiddleRest`, `visualCellsPattern11LeadingNestedTriplet`, `visualCellsPattern12TrailingDuplet`, `visualCellsPattern13MiddleDuplet`, `visualCellsPattern14LeadingDuplet`, `visualCellsPattern15Sextuplet`. Bracket cells covered for every nested entry.
- [x] `PeachTests/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSectionTests.swift` — flipped three `.disabled(...)` stubs to active; added `labelForPattern11LeadingTriplet`, `labelForPattern15Sextuplet`, `cascadeWritesForTupletPatterns` parameterized over all 10 new entries × locked defaults.
- [x] Ran `bin/test.sh` (iOS) — `ALL TESTS PASSED (1954 passed)`; `bin/test.sh -p mac` — `ALL TESTS PASSED (1948 passed)`. Ran `archlint Peach/` — exit 0. Ran `bin/check-dependencies.sh` — green. Ran `bin/add-localization.swift --missing` — `0`.
- [ ] Visual check on the iOS Simulator per Verification §: drill into Settings → TOD → Pattern picker; confirm five sections appear with locked headers, each containing its locked entries in order; switch to a tuplet pattern and confirm the dot-row preview renders with bracket overlays for nested entries.
- [x] `docs/implementation-artifacts/sprint-status.yaml` — `84-4-sectioned-picker-and-tuplet-catalog-content` advanced `backlog → in-progress` at start; will advance to `review` at hand-off below.

**Acceptance Criteria:**
- Given `TimingOffsetDetectionPatternCatalog.all` after this story, when read, then it returns exactly 15 entries in `pattern_01` … `pattern_15` order, each with `id` matching the opaque convention.
- Given `TimingOffsetDetectionPatternCatalog.sections`, when read, then it returns `[.straight16ths, .gapped16ths, .triplets, .nested, .sextuplet]` and the union of `section.patternIds` equals `Set(all.map(\.id))` with no duplicates.
- Given each new pattern `pattern_06` … `pattern_15`, when `TimingDotView.visualCells(for:)` is called, then the returned cells match the locked widths and start-x proportions from `tod-tuplet-renderer-design.md` § *Cell-width math* within `1e-6`, and the `kind` ordering matches the design doc's worked example for that entry.
- Given each new pattern's audible position 2 (or its locked default), when `pattern.beat(offsetNotePosition:offsetAmount:)` is called, then the offset is applied to the `.note` leaf addressed by `audibleToGrid[1]` (nested-child for `pattern_10` … `pattern_14`; top-level otherwise); every other `.note` carries `.zero`; `.rest` and `.nested(Beat)` structures are preserved.
- Given the Pattern-picker drill-down on iPhone or iPad in either locale, when read by VoiceOver, then five section transitions are announced with the locked English/German strings, and per-row composite labels read per the locked form (e.g. `pattern_10` reads `"Accent, Note 2 of 4, in triplet, Note 3 of 4, in triplet, Note 4 of 4, in triplet"`).
- Given `bin/test.sh && bin/test.sh -p mac`, then both runs are green. Given `bin/add-localization.swift --missing`, then it reports `0`. Given `archlint Peach/` and `bin/check-dependencies.sh`, then both exit `0`.
- Given the seven `@Test(.disabled("Enabled by Story 84.4 catalog registration of pattern_06..15"))` markers in `TimingDotViewTests.swift` and the three in `TimingOffsetDetectionPatternPickerSettingsSectionTests.swift`, when an agent greps `PeachTests/Training/TimingOffsetDetection` for `Enabled by Story 84.4`, then zero matches remain — every stub is active.

## Spec Change Log

### 2026-06-05 — Review iteration 1 (patches only, no spec loopback)

Three parallel adversarial reviewers (blind hunter / edge-case hunter / acceptance auditor) produced 23 raw findings. After deduplication: 0 `intent_gap`, 0 `bad_spec`, 3 `patch` findings applied to the deliverable, 5 findings appended to `deferred-work.md`, and the remainder rejected (design-doc locks, already-covered invariants, forward-compat speculation, and one finding describing the existing binding-`get` resolution path that's already correct).

**Triggering findings (severity-ordered, deduplicated):**

- HIGH — Edge-case hunter — `OffsetNotePosition.validRange = 1...4` but `pattern_15` (sextuplet) has 6 audibles and `pickable = {2, 3, 4, 5, 6}`. User selects audible 5 or 6 → `clampedOffsetNotePosition(rawValue)`'s `validRange.contains(rawValue)` guard fails → silently reverted to default 4. The picker shows audible 5/6 as selectable but the engine never plays them. The type's existing doc comment literally calls out: "future K > 4 patterns will widen it." 84.4 is that future and missed the widening.
- MEDIUM — Blind hunter + Acceptance auditor — `TimingOffsetDetectionPatternPickerDestination.body` passed `section.localizedHeader` both as the `Picker` `label:` AND the `Section` `header:`. Even with `.labelsHidden()`, the duplicate adds noise to the source and risks future VoiceOver double-announce regressions if `.labelsHidden()` semantics ever change.
- LOW — Blind hunter — `cascadeWritesForTupletPatterns` test description claimed coverage of "every catalog pattern" but the `arguments:` tuple list only covered `pattern_06` … `pattern_15`. The 5 Epic-82 entries' defaults are tested elsewhere (`cascadeWritesForKnownId` covers `defaultPatternId`); the description was overly broad.

**Amendments outside the frozen block:**

- `Peach/Training/TimingOffsetDetection/OffsetNotePosition.swift`:
  - `validRange` widened from `1...4` to `1...6`; doc comment updated to reference the Epic 84 catalog audibleCount range (most ≤ 4, sextuplet `pattern_15` = 6).
- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift`:
  - The sectioned `Picker`'s `label:` argument changed from `Text(section.localizedHeader)` to `EmptyView()`; doc comment expanded with rationale (section header already carries the bucket name for both sighted and VoiceOver users).
- `PeachTests/Training/TimingOffsetDetection/OffsetNotePositionTests.swift`:
  - `validValuesRoundTrip` description tightened to `1...6`; `zeroBasedIndexMatchesRawValue` arguments extended to `[1, 2, 3, 4, 5, 6]`.
  - `validRangeIsOneThroughFour` renamed to `validRangeIsOneThroughSix` and asserts the new range.
  - Added `validRangeCoversEveryCatalogPickablePosition` (catalog-wide invariant — every pickable position in every registered pattern falls inside `validRange`).
  - Added `clampedPositionAcceptsPattern15Audibles` parameterized over audibles 2–6 (regression for the silent-revert bug).
- `PeachTests/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSectionTests.swift`:
  - `cascadeWritesForTupletPatterns` description tightened to "each Story 84.4 tuplet pattern."

**Known-bad states avoided:**

- A user selecting audible 5 or 6 on `pattern_15` and the picker silently reverting their choice to audible 4 — a visible-vs-stored mismatch with no error surface.
- A programmatic caller (now or in a future test) constructing `OffsetNotePosition(5)` or `(6)` and trapping at the `precondition` because `validRange` rejects the value.
- Future drift where a 7-audible entry registers without widening `validRange` — pinned by `validRangeCoversEveryCatalogPickablePosition`, which iterates every registered pattern.
- Duplicate VoiceOver announcement of the section header if `.labelsHidden()`'s VoiceOver semantics ever stop suppressing the label.

**Deferred (appended to `deferred-work.md`):**

- PF-040 — Sectioned `Picker` shared-binding rendering on cross-section selection transitions is unverified.
- PF-041 — AX1 no-truncation invariant for picker section headers has no snapshot test (manual visual inspection still owns this; design doc references it).
- PF-042 — `TimingOffsetDetectionPattern.init` does not validate `dottedAudiblePositions` is in-range or non-anchor.
- PF-043 — `Cell.nested([Cell])` test matcher has no max-depth or structural-divergence guard.
- PF-044 — `1e-6` cell-width tolerance hard-codes float evaluation order; forward-compat concern for K > 6 or depth > 2.

**Rejected (sampled — not exhaustive):**

- Blind hunter — `"Sextuplet"` / `"Sextolen"` numerus mismatch (English singular header vs German plural). Locked verbatim by `tod-tuplet-renderer-design.md` § *Categorization* table; outside the frozen block but a settled translation decision. Pushback belongs to a German-copy retro, not this story.
- Blind hunter — `Section.patternIds` raw string literals are not compile-time linked to `static let pattern06` … `pattern15`. Covered by `sectionsCoverEveryPatternExactlyOnce` regression: `Set(sections.flatMap(\.patternIds)) == Set(all.map(\.id))` catches any drift before merge.
- Blind hunter — `pattern(forStoredId:)` inside the `ForEach` is a "crash vector if `patternIds` and `.all` drift." The function is non-failable with a `defaultPattern` fallback; the `sectionIdsResolveToCatalogPatterns` test iterates every section id through `pattern(withId:)` (throws on unknown).
- Blind hunter — `pattern_09` doc comment "spans positions 3–5" — accurate in 1-based grid positions (grid index 2 + rests at 3 and 4 → 1-based 3, 4, 5). The off-by-one perception came from mixing 0-based and 1-based reading.
- Blind hunter — `pattern_10` / `pattern_11` accent placement "asymmetry." Required by the audible-1 = accent invariant: `pattern_11`'s first audible is inside the nested triplet (the triplet is leading), so the accent must live on the first nested note. `pattern_10`'s first audible is top-level. Both patterns are "mirrors" in audible structure, not in subdivision-position; the locked code is correct.
- Blind hunter — One-entry buckets (`pattern_01` in Straight 16ths, `pattern_15` in Sextuplet) "clutter the picker." Locked by `tod-tuplet-renderer-design.md` § *Categorization*; the bucket scheme is single-axis and a notional "8ths" bucket for `pattern_04` was explicitly considered and rejected in the design doc.
- Acceptance auditor — No regression test for "first audible never pickable" on tuplet entries. Already covered by `TimingOffsetDetectionPatternCatalogTests.everyPatternExcludesMetricAnchorFromPickable`, which iterates every entry in `TimingOffsetDetectionPatternCatalog.all`.
- Edge-case hunter — Sectioned picker "leaves stale binding value unrendered if it falls outside every section's `patternIds`." The `patternIdBinding`'s `get` resolves through `pattern(forStoredId:).id`, so the binding value handed to each `Picker` is always a canonical id present in exactly one section. Retired-id storage falls back to `defaultPatternId` automatically.
- Edge-case hunter — Float drift, `Cell.nested` depth, `dottedAudiblePositions` init validation — all deferred as forward-compat hardening (PF-042/043/044).

**KEEP (re-derivation must preserve):**

- `OffsetNotePosition.validRange = 1...6` — catalog-wide invariant, asserted by `validRangeCoversEveryCatalogPickablePosition`.
- Sectioned `Picker` with `EmptyView()` label — section `header:` is the single VoiceOver announcement surface.
- `validRangeCoversEveryCatalogPickablePosition` and `clampedPositionAcceptsPattern15Audibles` regressions.

### 2026-06-05 — Review iteration 2 (visual verification, patches only, no spec loopback)

Michael started a TOD trial on the iOS Simulator with `pattern_15` (sextuplet) selected and hit a `Fatal error: Schedule overflow: 6000 events exceeds buffer capacity 4096` at `Peach/Core/Audio/SoundFontEngine.swift:503`. The crash fires inside `SoundFontEngine.scheduleEvents`'s `assertionFailure` when the sequencer hands it an event batch larger than the engine's circular buffer. `feedback_verify_visual_features` is why this surfaced before close.

**Triggering finding:**

- HIGH — `SoundFontBeatSequencer.beatsPerBatch = 500` was sized for the pre-84.4 catalog (at most TOD = 8 events/beat for `pattern_01`'s 4 audibles × note-on/off). `pattern_15` (sextuplet) emits 6 audibles × 2 events = **12 events/beat**; 500 × 12 = 6000 events overshoots the 4096-event `SoundFontEngine.scheduleCapacity` by 47 %. The sequencer's doc comment literally instructed: "Disciplines emitting denser beats must lower this constant." 84.4 introduced the denser entry and missed the constant update — neither automated tests nor the unit reviewers caught the cross-file invariant (sequencer constant ↔ engine capacity ↔ catalog density), only manual sim verification did.

**Amendments outside the frozen block:**

- `Peach/Core/Audio/SoundFontBeatSequencer.swift`:
  - `beatsPerBatch` lowered from `500` to `300`. New ceiling: 300 × 12 = 3600 events, leaves 496 headroom against `scheduleCapacity`. Doc comment updated to reflect TOD's new max (12 events/beat with `pattern_15` sextuplet); the contract "lower this constant when adding a denser discipline" preserved.
  - `beatsPerBatch` access lifted from `private` to `internal` so the cross-file invariant has a regression test surface.
- `Peach/Core/Audio/SoundFontEngine.swift`:
  - `scheduleCapacity` access lifted from `private` to `internal` for the same regression surface.
- `PeachTests/Core/Audio/SoundFontBeatSequencerTests.swift`:
  - Added `buildBatchStaysWithinScheduleCapacity` — iterates every entry in `TimingOffsetDetectionPatternCatalog.all`, builds a full `beatsPerBatch`-sized batch using the pattern's `beat(offsetNotePosition: defaultOffsetNotePosition, offsetAmount: .zero)` (matches a real trial's first beat), and asserts `batch.events.count <= SoundFontEngine.scheduleCapacity`. Pins the cross-file invariant so future catalog additions or constant tunings trip a CI failure before reaching the sim.

**Known-bad states avoided:**

- The TOD trial on `pattern_15` crashing on first beat-batch build (Debug) or silently truncating events past 4096 (Release) — both surfaces are now reachable only if a future denser entry is registered without revising `beatsPerBatch`, which the regression test catches.
- A future contributor adding a pattern denser than `pattern_15` (e.g. an 8-audible figure) and not noticing the new shape pushes the batch over the limit; the regression test would fail immediately.
- The misleading prior doc comment ("TOD = 8 events/beat") rotting as the catalog grew.

**KEEP (re-derivation must preserve):**

- `SoundFontBeatSequencer.beatsPerBatch = 300` — sized for the sextuplet density; bound to the engine's `scheduleCapacity = 4096` via the regression test.
- `buildBatchStaysWithinScheduleCapacity` — catalog-wide invariant test, must iterate `TimingOffsetDetectionPatternCatalog.all`.
- `nonisolated static let` access on both `beatsPerBatch` and `scheduleCapacity` lifted to internal — the test layer needs to read both constants to assert the invariant.

**Verification commands (re-ran 2026-06-05 after iteration-2 patches):**

- `bin/build.sh` — `BUILD SUCCEEDED`.
- `bin/test.sh` (iOS) — `ALL TESTS PASSED (1963 passed)` — +1 vs iteration-1 (the new regression).
- `bin/test.sh -p mac` (macOS) — `ALL TESTS PASSED (1957 passed)` — +1 from the same.
- `archlint Peach/` — exit 0.
- `bin/check-dependencies.sh` — green.

**Re-verification ask:** Michael repeats the original repro — start a TOD trial with `pattern_15` selected — and confirms it plays without crashing.

### 2026-06-05 — Review iteration 3 (scope change: gate nested entries behind PEACH_RESEARCH)

During the iteration-2 visual re-verification (post-`pattern_15` crash fix), Michael identified that the nested-pattern bracket overlay (`pattern_10`..`pattern_14`) doesn't render correctly. Rather than block the story on a renderer iteration, he requested gating the nested entries behind `PEACH_RESEARCH` — keeping the code paths for further iteration but hiding the buggy visualization from App Store users.

**Triggering finding:**

- MEDIUM — Visual #1 — Michael ran TOD trials on `pattern_10`..`pattern_14` and observed: "the bar on top is incorrectly displayed" for the nested-pattern bracket overlay. The bracket geometry doesn't match the locked `tod-tuplet-renderer-design.md` § *Grouping indicators* spec. No automated regression caught it — `bracketGeometryBaseValues` pins the constants but not the rendered position (see PF-039); only visual inspection surfaces the defect.

**Amendments outside the frozen block:**

- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPatternCatalog.swift`:
  - `all` rewritten as a closure: builds the always-on entries (`pattern_01`..`pattern_09`, `pattern_15`), appends `pattern_10`..`pattern_14` only when `PEACH_RESEARCH` is defined.
  - `sections` rewritten similarly: builds `[straight16ths, gapped16ths, triplets]`, appends `.nested` only under `PEACH_RESEARCH`, then appends `.sextuplet`.
  - `TimingOffsetDetectionPatternSection.nested.patternIds` returns the locked five ids under `PEACH_RESEARCH` and `[]` otherwise, so set-math invariants (`Set(sections.flatMap(\.patternIds)) == Set(all.map(\.id))`) stay consistent across builds.
  - Doc comments on `all` and `.nested.patternIds` updated to call out the gating mechanism and reference PF-045.
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPattern.swift`:
  - **No change** — the `static let pattern10`..`pattern14` definitions stay unconditional. This preserves the renderer-unit-test surface (`TimingDotViewTests.visualCellsPattern10..14*` etc.) so the nested-figure code paths keep exercising in every build, even though the patterns aren't catalog-registered in non-research builds.
- `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionPatternCatalogTests.swift`:
  - `allListsAllFifteenCatalogEntriesInDisplayOrder` renamed to `allListsCatalogEntriesInDisplayOrder`; builds the expected array with `#if PEACH_RESEARCH` matching the catalog gating.
  - `catalogIdsMatchOpaqueConvention` similarly conditional on build flag.
  - `catalogEntrySubdivisions` parameterized arguments narrowed to always-on entries (`pattern_01`..`pattern_09`, `pattern_15`); new `researchOnlyNestedCatalogEntrySubdivisions` covers the nested entries under `#if PEACH_RESEARCH`.
  - `sectionsListBucketsInOrder` builds expected sections with the same conditional.
  - `sectionMembership` argument list narrowed to always-on sections; new `nestedSectionMembership` separately tests `.nested.patternIds` for both build flavors (full list under research, empty otherwise).
- `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionPatternTests.swift`:
  - `tupletCatalogEntryShape` arguments narrowed to always-on entries; new `researchOnlyNestedCatalogEntryShape` covers `pattern_10`..`pattern_14` under `#if PEACH_RESEARCH`.
- `PeachTests/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSectionTests.swift`:
  - `cascadeWritesForTupletPatterns` arguments narrowed to always-on entries; new `cascadeWritesForNestedPatterns` covers the nested entries under `#if PEACH_RESEARCH`.
- `docs/project-context.md`:
  - New rule under *Domain Rules Agents Will Get Wrong* documenting the `PEACH_RESEARCH` gating convention generally — type/value definitions stay defined, only registration is gated; set-math invariants kept consistent via `.nested.patternIds → []` in non-research; static lets for gated entries (e.g. `pattern_10`) stay unconditional so renderer tests keep exercising. Cites `DisciplineBootstrap` and `TimingOffsetDetectionPatternCatalog` as canonical examples.
- `docs/implementation-artifacts/deferred-work.md`:
  - **PF-045** appended — "Nested-pattern bracket overlay renders incorrectly in `TimingDotView`." Documents the visual defect, the gating mitigation, and the resolution-blocker (ungating the *Nested* bucket is gated on this resolving).

**Known-bad states avoided:**

- App Store users encountering the broken bracket overlay on nested-pattern previews.
- The nested-pattern renderer code rotting (unexercised by tests) while gated out — preserved by leaving the `static let` definitions and the renderer unit tests intact.
- Set-math invariants (`sectionsCoverEveryPatternExactlyOnce`, `validRangeCoversEveryCatalogPickablePosition`, `everyPatternExcludesMetricAnchorFromPickable`) silently breaking across build configurations — preserved by `.nested.patternIds → []` returning consistently with the gated `Catalog.all`.

**Spec frontmatter scope amendment (Michael-driven, not review-driven):**

The frozen block's I/O matrix and Acceptance Criteria say `TimingOffsetDetectionPatternCatalog.all` contains 15 entries in `pattern_01`…`pattern_15` order with `count == 15`, and the picker shows five sections. These claims now hold only in `PEACH_RESEARCH` builds; non-research builds see 10 entries and 4 sections. The bucket assignment table (*Straight 16ths*, *Gapped 16ths*, *Triplets*, *Nested*, *Sextuplet*) and the section-ordering decision remain unchanged — only the runtime visibility of the *Nested* bucket is build-flag conditional. Michael's request authorized this scope amendment.

**KEEP (re-derivation must preserve):**

- Static lets `TimingOffsetDetectionPattern.pattern10`..`pattern14` stay unconditional — renderer code paths must keep being exercised by unit tests.
- `.nested.patternIds` returns `[]` in non-research builds — set-math invariants depend on this.
- The `#if PEACH_RESEARCH` block in `Catalog.all` appends nested entries between `pattern_09` and `pattern_15` (not after `pattern_15`) — preserves the design-doc display order.
- The `#if PEACH_RESEARCH` block in `Catalog.sections` places `.nested` between `.triplets` and `.sextuplet` — preserves the locked picker section order.
- The new project-context.md rule documenting the gating convention generally — future `PEACH_RESEARCH` gates should follow it without re-deriving the pattern.

**Verification commands (re-ran 2026-06-05 after iteration-3 patches):**

- `bin/test.sh` (iOS Debug, non-research) — `ALL TESTS PASSED (1948 passed)` — −15 vs iteration-2 (research-only tests don't compile in this config).
- `bin/test.sh -p mac` (macOS Debug, non-research) — `ALL TESTS PASSED (1957 passed)`.
- `bin/test.sh --research` (iOS Debug, Research) — `ALL TESTS PASSED (2105 passed)` — covers the gated entries plus continuous rhythm matching.
- `bin/test.sh --research -p mac` (macOS Debug, Research) — `ALL TESTS PASSED (2099 passed)`.
- `archlint Peach/` — exit 0.
- `bin/check-dependencies.sh` — green.

**Re-verification ask:** Michael repeats the original repro in **`Debug`** (non-research, the default) — start a TOD trial with `pattern_15` selected and confirm pattern_15 still plays; drill into the picker and confirm only four sections appear (no *Nested* / *Verschachtelt*). In `Debug (Research)`, confirm the *Nested* section is back.

### 2026-06-05 — Review iteration 4 (Michael-driven scope amendment: Category refactor + ID rename + gating restructure)

After iteration 3, Michael flagged five interlocking concerns that warranted a coherent restructure rather than incremental patches:

1. The iteration-3 `PEACH_RESEARCH` gating was scattered across `Catalog.all`, `Catalog.sections`, and `Category.patternIds` — too many places to keep in sync when moving a category in or out of the gate.
2. "Bucket" / "Section" / "Category" were used interchangeably in the codebase; pick one.
3. Opaque pattern IDs (`pattern_NN`) were chosen by the design doc for decoupling, but in practice are unmemorable in discussion. A category-prefixed ID schema (`pattern_<category>_NN`) makes IDs communicable.
4. A pattern's category was imposed externally via `Category.patternIds`; should be a stored property of the pattern itself.
5. Filtering the catalog by category should be a one-liner; including/excluding a category from the gate should be a one-place edit.

Item 6 — the navigation-destination-inside-lazy-container warning — is deferred to PF-046 with three documented fix options, none small enough to bundle without a UX/architecture decision.

**Amendments outside the frozen block:**

- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPattern.swift`:
  - `TimingOffsetDetectionPattern` gains a `let category: TimingOffsetDetectionPatternCategory` stored property.
  - `init` requires `category:` and validates `id.hasPrefix("pattern_\(category.idToken)_")` via a precondition.
  - The 15 `static let pattern01`..`pattern15` definitions are renamed to `pattern_<category>_NN` (`pattern_straight16ths_01`, `pattern_gapped16ths_01..04`, `pattern_triplets_01..04`, `pattern_nested_01..05`, `pattern_sextuplet_01`). Each declares its `category:` explicitly. Definitions stay unconditional in all builds so renderer tests for `pattern_nested_*` keep exercising even in non-research builds.
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPatternCatalog.swift`:
  - `TimingOffsetDetectionPatternSection` renamed to `TimingOffsetDetectionPatternCategory`. The enum becomes pure data — `idToken` (the pattern-id infix), `localizedHeader` (the section header string). The iteration-3 `patternIds` accessor is removed; bucket membership now lives on the pattern via `pattern.category`.
  - `Catalog.all` rewritten as a closure builder: appends always-on patterns, then `#if PEACH_RESEARCH` appends the five nested patterns, then appends `pattern_sextuplet_01`. The `#if` lives in **one place only** (this closure). Swift does not allow `#if` inside array-literal expressions, so the closure form is required; compile-time exclusion semantics are identical to inline `#if`.
  - `Catalog.sections` (iteration-3 vintage) removed. Replaced by:
    - `Catalog.patterns(in:)` — filter by category.
    - `Catalog.categories` — categories present in the current build's catalog, derived from `Catalog.all`. A category appears iff at least one of its patterns is registered.
  - `defaultPatternId` updated to `"pattern_straight16ths_01"`.
- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift`:
  - `TimingOffsetDetectionPatternPickerDestination.body` rewritten to iterate `Catalog.categories` and call `Catalog.patterns(in: category)` per section. The iteration-3 `Catalog.sections.flatMap(\.patternIds)` style is gone.
- `PeachTests/Training/TimingOffsetDetection/*Tests.swift`:
  - All references to `.pattern01`..`pattern15` static lets renamed to the category-prefixed form via mechanical sweep.
  - All `pattern_NN` ID strings in test arguments renamed to `pattern_<category>_NN`.
  - Test fixtures that constructed `TimingOffsetDetectionPattern` directly with synthetic IDs (`"fixture_1011"`, `"fixture_nested_triplet"`, etc.) now use schema-conforming IDs with sequence `_99`/`_98` (e.g. `"pattern_gapped16ths_99"`) plus the matching `category:` argument so the init's precondition passes.
  - Iteration-3 tests over `Catalog.sections` and `Section.patternIds` are rewritten against `Catalog.categories` and `Catalog.patterns(in:)`. The iteration-3 `nestedSectionMembership` test becomes `nestedCategoryMembership` (asserts `Catalog.patterns(in: .nested)` is `[]` in non-research, full list in research).
  - New regression: `patternIdMatchesCategoryPrefix` iterates `Catalog.all` and asserts every pattern's id matches the schema for its declared category. `categoryIdTokenRoundTrips` ensures every catalog pattern's id's category-infix matches a known `Category.idToken`.
- `docs/planning-artifacts/tod-tuplet-renderer-design.md`:
  - § *Opaque pattern-id convention* renamed to § *Pattern-id convention*; opening "Status note" amendment explains the iteration-4 revision and rationale. New convention rule + locked catalog roster + historical rename map preserved for traceability.
- `docs/project-context.md`:
  - The `PEACH_RESEARCH` gating note (added in iteration 3) is rewritten to describe the iteration-4 mechanism: gating in ONE place (the registry's `#if PEACH_RESEARCH` block inside its closure builder), categories as pure data with no build-flag awareness, "categories are derived from registered patterns via `Catalog.categories`." Notes the Swift constraint that forces the closure-builder form.
- `docs/implementation-artifacts/deferred-work.md`:
  - **PF-046** appended — navigation-destination warning, three fix options enumerated.

**Known-bad states avoided:**

- The iteration-3 dispersal of `#if PEACH_RESEARCH` across three places — easy to forget one when moving a category in or out of the gate.
- "Bucket" / "Section" / "Category" vocabulary drift — single name now.
- Discussions of patterns by opaque IDs that nobody remembers.
- A pattern's categorization being something an external function dictates (iteration-3 `Section.patternIds` was the source of truth) rather than a property the pattern itself declares.

**Spec frontmatter scope amendment (Michael-driven):**

The frozen block's I/O matrix, Boundaries, and Acceptance Criteria reference the iteration-1..3 vintage: `TimingOffsetDetectionPatternSection`, `sections`, `Section.patternIds`, `pattern_01`..`pattern_15` ID schema. Iteration 4 supersedes all of these — the new contracts are described by the convention revision in `tod-tuplet-renderer-design.md` § *Pattern-id convention* and by the design notes here. Michael's request authorized the scope amendment; the frozen block's claims about specific numbers (15 entries, 5 sections) remain semantically correct in `PEACH_RESEARCH` builds (10 entries + 4 categories in non-research, per the iteration-3 gating that persists).

**KEEP (re-derivation must preserve):**

- `TimingOffsetDetectionPattern.category` stored property; init validates `id.hasPrefix("pattern_\(category.idToken)_")`.
- `TimingOffsetDetectionPatternCategory` is pure data (`idToken`, `localizedHeader`); no `isActiveInBuild`, no `patternIds`.
- `Catalog.all` uses a closure builder with `#if PEACH_RESEARCH` in **one** place; this is the single point of gating.
- `Catalog.patterns(in:)` and `Catalog.categories` derive everything else from `Catalog.all`.
- Static-let definitions for `pattern_nested_*` stay unconditional (renderer tests must keep exercising them).
- ID schema invariant `pattern_<category>_NN` (camelCase category token matching enum case).
- `patternIdMatchesCategoryPrefix` and `categoryIdTokenRoundTrips` regressions.

**Stale test-method names (cosmetic, intentional):**

Test method identifiers like `visualCellsPattern09MixedDuration`, `labelForPattern10NestedTriplet`, `dottedAudiblePositionsLockedToPattern09`, `beatForPattern09PlacesOffsetOnAudibleSextupletCell`, etc. were not renamed in iteration 4. The test descriptions, assertions, and expected values reference the new IDs (`pattern_triplets_04`, `pattern_nested_01`, etc.); only the method names remain stale. Method names are identifiers, not user-facing content; renaming them would be cosmetic churn without behavioural impact. A future cleanup pass may rename them.

**Verification commands (re-ran 2026-06-05 after iteration-4 patches):**

- `bin/build.sh` (iOS Debug, non-research) — `BUILD SUCCEEDED`.
- `bin/test.sh` (iOS Debug, non-research) — `ALL TESTS PASSED (1942 passed)`.
- `bin/test.sh -p mac` (macOS Debug, non-research) — `ALL TESTS PASSED (1936 passed)`.
- `bin/test.sh --research` (iOS Debug, Research) — `ALL TESTS PASSED (2098 passed)`.
- `bin/test.sh --research -p mac` (macOS Debug, Research) — `ALL TESTS PASSED (2093 passed)`.
- `archlint Peach/` — exit 0.
- `bin/check-dependencies.sh` — green.
- `bin/add-localization.swift --missing` — `0`.

**Re-verification ask:** Michael runs the iOS Simulator on `Debug` (non-research), drills into Settings → TOD → Pattern picker. Confirms four categories appear (*Straight 16ths*, *Gapped 16ths*, *Triplets*, *Sextuplet*) with the renamed entries. Switches to `pattern_sextuplet_01` and verifies the trial plays. Optionally cross-checks `Debug (Research)` shows five categories including *Nested* with `pattern_nested_01`..`pattern_nested_05`.

## Design Notes

**Why a `TimingOffsetDetectionPatternSection` enum (not `[(header, ids)]` tuples or a per-pattern `bucket: Section` property):** A tuple array re-encodes the bucket-to-pattern mapping inline at the catalog declaration site without a name to grep on; a per-pattern stored property duplicates the categorization across all 15 entries and invites drift. The enum centralizes the locked taxonomy in one place, gives the picker chrome a typed iteration target (`CaseIterable`), and makes "which bucket does `pattern_07` live in?" a one-line answer at the enum site instead of a scan across 15 instances. `localizedHeader` and `patternIds` are computed properties (no stored state) so the enum stays a pure dispatch table.

**Why `Section.patternIds: [String]` (not `[TimingOffsetDetectionPattern]`):** Storing concrete patterns inside the enum couples the section to the catalog ordering and creates two sources of truth ("is `pattern_06` in `all` or in `Section.triplets.patterns`?"). Returning ids keeps the catalog (`all`) the single source of patterns; the section is a taxonomy layer keyed by id. Resolution to the concrete pattern is one call: `catalog.pattern(forStoredId: id)`.

**Why a per-section inline `Picker` (not one outer `Picker` wrapping sectioned rows):** SwiftUI's inline `Picker` style with `Form` `Section`s renders each section's selection as an independent group while still tracking selection through one shared `Binding` (the existing `patternIdBinding`). Wrapping the entire `ForEach(sections)` in a single outer `Picker` causes SwiftUI to render the section headers as visual noise without the per-section visual grouping the design doc requires. The per-section inline form matches Apple's HIG for grouped lists with category headers and produces the locked behaviour (one `Picker` per group, shared selection state) without an extra binding layer.

**Why the catalog test introduces `Cell.nested([Cell])` (not a flat sentinel like `.nestedTriplet`):** The recursive expansion makes the test assertion read the same as the actual `Beat` shape — the test fails informatively when a nested-child cell drifts (wrong velocity, wrong offset, wrong subdivision count) instead of failing with a single opaque "nested cell mismatch." The added recursion in the matcher is local to the test and unlocks per-cell precision on `pattern_10` … `pattern_14` without forking the test pattern across nested-and-flat variants.

## Verification

**Commands:**
- `bin/test.sh` (iOS) — expected: `ALL TESTS PASSED` with count = previous + new tests (the ten flipped stubs + ~12 new regressions = +22 vs. 84.3's 1890).
- `bin/test.sh -p mac` (macOS) — expected: matching count on macOS (+22 vs. 84.3's 1884).
- `bin/build.sh` — expected: `BUILD SUCCEEDED (0 warnings)` after the catalog changes.
- `bin/add-localization.swift --missing` — expected: `0 keys missing German translation`.
- `archlint Peach/` — expected: exit 0, no output.
- `bin/check-dependencies.sh` — expected: `All non-import dependency rules passed.`
- `rtk proxy grep -n "Enabled by Story 84.4" PeachTests/Training/TimingOffsetDetection/` — expected: zero matches (all stubs flipped).

**Manual checks (to perform on the iOS Simulator after this change lands):**
- Open Settings → TOD → Pattern row. Tap to drill into the picker destination. Confirm five visible section headers in order: *Straight 16ths*, *Gapped 16ths*, *Triplets*, *Nested*, *Sextuplet*. Confirm each section contains its locked entries in the order from § *Categorization*.
- Switch to one entry per bucket (e.g. `pattern_06`, `pattern_09`, `pattern_10`, `pattern_15`) and confirm the picker preview row at the bottom of the Pattern section, the slot picker on the *Offset Note Position* row, and the dot-row on the TOD training screen all render with proportional spacing matching § *Cell-width math*. For nested entries, the bracket overlay is visible above the nested-child cells.
- Enable VoiceOver. Swipe through the picker destination — section transitions should announce the locked headers (English locale). Switch device to German locale (`Settings → General → Language & Region`) and confirm the German headers announce.
- For `pattern_09`, confirm the VoiceOver readout for audible 2 contains "dotted" / "punktiert".
- For `pattern_11` and `pattern_14`, confirm the VoiceOver readout for audible 1 contains "in triplet" / "in duplet" (and German equivalents).
- For `pattern_13` and `pattern_14` side-by-side at AX1 Dynamic Type, confirm visual distinguishability per § *Pairwise distinguishability check* — if indistinguishable, trigger the *Ask First* halt.

## Suggested Review Order

**Catalog content — entry definitions**

- The catalog locks: ten new `static let` instances for `pattern_06` … `pattern_15` per the design-doc *Catalog* table.
  [`TimingOffsetDetectionPattern.swift:276`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPattern.swift#L276)

- The mixed-duration entry with `dottedAudiblePositions: [2]` — the only pattern that carries the dotted descriptor.
  [`TimingOffsetDetectionPattern.swift:319`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPattern.swift#L319)

- Two nested-triplet "mirrors" — `pattern_10` (trailing) vs `pattern_11` (leading); accent placement reflects audible-1 = accent invariant.
  [`TimingOffsetDetectionPattern.swift:340`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPattern.swift#L340)

- The flat sextuplet — six audibles, default position 4 (perceptual midpoint).
  [`TimingOffsetDetectionPattern.swift:436`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPattern.swift#L436)

**Sectioned-picker taxonomy**

- The five-bucket section enum keyed by single-axis classification (perceived host division + nesting).
  [`TimingOffsetDetectionPatternCatalog.swift:110`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPatternCatalog.swift#L110)

- Bucket → pattern-id mapping — exclusive partition over the 15-entry catalog.
  [`TimingOffsetDetectionPatternCatalog.swift:132`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPatternCatalog.swift#L132)

- `sections` static — the catalog's single source of truth for picker iteration order.
  [`TimingOffsetDetectionPatternCatalog.swift:53`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPatternCatalog.swift#L53)

**Picker chrome — sectioned `Form` drill-down**

- `ForEach(sections)` wrapping one inline `Picker` per bucket, all sharing the same `patternIdBinding`.
  [`TimingOffsetDetectionPatternPickerSettingsSection.swift:139`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift#L139)

- `EmptyView()` label — section `header:` is the single VoiceOver announcement surface (iteration-1 patch).
  [`TimingOffsetDetectionPatternPickerSettingsSection.swift:153`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift#L153)

**Range-invariant fix — iteration-1 HIGH patch**

- `OffsetNotePosition.validRange` widened from `1...4` to `1...6` to cover `pattern_15`'s 6 audibles.
  [`OffsetNotePosition.swift:14`](../../Peach/Training/TimingOffsetDetection/OffsetNotePosition.swift#L14)

- Catalog-wide regression: every pickable position in every registered pattern must fit `validRange`.
  [`OffsetNotePositionTests.swift:33`](../../PeachTests/Training/TimingOffsetDetection/OffsetNotePositionTests.swift#L33)

- Pattern-15 pickable-position regression — silent-revert defense (iteration-1 patch).
  [`OffsetNotePositionTests.swift:45`](../../PeachTests/Training/TimingOffsetDetection/OffsetNotePositionTests.swift#L45)

**Regression coverage — catalog shape and section invariants**

- Tuplet entries' `audibleToGrid` / `audibleCount` / `pickable` / default — parameterized over all 10 new entries.
  [`TimingOffsetDetectionPatternTests.swift:403`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionPatternTests.swift#L403)

- Section coverage invariant — `Set(sections.flatMap(\.patternIds)) == Set(all.map(\.id))`, no duplicates.
  [`TimingOffsetDetectionPatternCatalogTests.swift:206`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionPatternCatalogTests.swift#L206)

- Composite-label coverage for the leading-nest accent + dotted-descriptor + trailing-nested cases.
  [`TimingOffsetDetectionPatternPickerSettingsSectionTests.swift:103`](../../PeachTests/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSectionTests.swift#L103)

- Renderer coverage for the new entries — visualCells for `pattern_09` (dotted-feel) and `pattern_10` (nested-triplet bracket).
  [`TimingDotViewTests.swift:288`](../../PeachTests/Training/TimingOffsetDetection/TimingDotViewTests.swift#L288)

**Peripherals**

- Five German section headers via `bin/add-localization.swift`.
  [`Localizable.xcstrings`](../../Peach/Resources/Localizable.xcstrings)

- Sprint status: 84-3 advances to `done` (housekeeping); 84-4 to `review` after this iteration.
  [`sprint-status.yaml:771`](sprint-status.yaml#L771)
