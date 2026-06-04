---
title: 'Story 84.2: Opaque pattern-id convention swap'
type: 'refactor'
created: '2026-06-05'
status: 'done'
baseline_commit: '9005aa12ce33427b8837bf6b26ddec35388745f3'
context:
  - '{project-root}/docs/planning-artifacts/tod-tuplet-renderer-design.md'
  - '{project-root}/docs/implementation-artifacts/epic-84-context.md'
  - '{project-root}/docs/implementation-artifacts/84-1-tuplet-renderer-and-catalog-design.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The five Epic-82 TOD patterns are keyed by bitmask-shaped ids (`pattern_1111`, `pattern_1011`, `pattern_1101`, `pattern_1010`, `pattern_1001`) that hard-code the four-16th-cell shape. The tuplet, nested-tuplet, sextuplet, and mixed-duration entries Story 84.4 ships cannot be expressed in that convention without overloading digit positions, so the entire catalog must move onto one uniform opaque id convention before any tuplet content lands. Story 84.1 locked the convention (`pattern_NN`, sequential, fixed at first registration, retired ids tracked in a top-of-file comment block) and the rename map; this story applies the rename across the catalog code surface, tests, doc comments, and the persisted `@AppStorage` default. No behaviour changes — neither audio, nor visual rendering, nor accessibility surface.

**Approach:** Apply the rename map from `tod-tuplet-renderer-design.md` § *Opaque pattern-id convention*: `pattern_1111` → `pattern_01`, `pattern_1011` → `pattern_02`, `pattern_1101` → `pattern_03`, `pattern_1010` → `pattern_04`, `pattern_1001` → `pattern_05`. Update both the `id:` string literals and the Swift `static let` identifiers (`pattern1111` → `pattern01`, etc.), the catalog's `defaultPatternId` string, all `@AppStorage`-flowing literals, every test reference, every doc comment, and every `#Preview` label. Add the (initially empty) retired-id registry comment block at the top of `TimingOffsetDetectionPatternCatalog.swift` per the convention's governance rule. No `@AppStorage` migration shim: the TOD-shipping cut has not reached the App Store, so the unknown-id-on-lookup fallback (Epic 82.5) handles Michael's stale `selectedPatternId` on first launch by resolving to the new default `pattern_01`; `offsetNotePosition` is reclamped to the new default's `defaultOffsetNotePosition` via the existing 82.6 reclamp path.

## Boundaries & Constraints

**Always:**
- Apply the rename map exactly as locked in `tod-tuplet-renderer-design.md` § *Opaque pattern-id convention*. No off-map ids.
- Rename in lockstep at every surface: `id:` string literal AND the `static let` Swift identifier on `TimingOffsetDetectionPattern`. Both must move together — a pattern whose `id` is `"pattern_01"` but whose accessor stays `.pattern1111` is half-renamed and an invitation to confusion.
- `TimingOffsetDetectionPatternCatalog.defaultPatternId` becomes `"pattern_01"`. The catalog's `defaultPattern` computed property resolves to the renamed entry. The unknown-id-on-lookup fallback target updates implicitly to `pattern_01` via `defaultPattern` — no separate change needed.
- Add a retired-id registry comment block to the top of `TimingOffsetDetectionPatternCatalog.swift`. Format per the design doc: header line stating the registry's purpose, the convention rule (fixed at first registration, numbers never reused, two-digit padding with past-99 widening as `pattern_100`+), and an empty body — Epic 84 retires nothing. Future removals append `<retired-id> — <last-known-notation> — <commit/story> — <date>`.
- Preserve every `Beat` builder shape verbatim: the same `subdivisions` arrays, the same `defaultOffsetNotePosition` values, the same `RhythmVelocity` choices. The only change to `TimingOffsetDetectionPattern.swift` content beyond identifier renames is the `id:` literal per the rename map and any doc-comment text that names old ids (e.g. line 148's `pattern_1111` reference).
- Update every code-surface reference enumerated in `tod-tuplet-renderer-design.md` § *Story 84.2: Opaque pattern-id convention swap* — treat that list as the verification checklist. Cross-reference: `TimingOffsetDetectionPattern.swift`, `TimingOffsetDetectionPatternCatalog.swift`, `TimingOffsetDetectionPatternPickerSettingsSection.swift` doc comment, `TimingDotView.swift` previews + identifier refs, and all `PeachTests/` files containing `pattern1XXX` Swift identifiers or `"pattern_1XXX"` string literals.
- Update `docs/planning-artifacts/tod-initial-pattern-catalog.md` with a single forward note at the top pointing to the rename map in `tod-tuplet-renderer-design.md`. Old ids stay in the body as historical context; do not retroactively rewrite the 82.3 design doc's prose.
- Pre-commit gate: `bin/test.sh && bin/test.sh -p mac` green. Tests are updated in lockstep with code, never deferred.
- Document the `@AppStorage` reset semantics in this spec's *Design Notes*: Michael's dev device sees `selectedPatternId` resolved by Epic 82.5's unknown-id fallback to `pattern_01` on first launch after the swap; `offsetNotePosition` reclamps via the existing 82.6 path to the new default's `defaultOffsetNotePosition` (3 for `pattern_01`). No migration shim, no UserDefaults reset script.

**Ask First:**
- If `grep` surfaces any reference to the old `pattern_1XXX` ids outside the enumerated code surfaces — e.g. in `Localizable.xcstrings`, in `Core/`, in `App/`, in production docs under `docs/` — HALT and surface before deciding whether the reference is in-scope for the rename, refers to historical context that must be preserved, or belongs to a story (84.3 / 84.4) not yet written.
- If the existing `TimingOffsetDetectionPatternCatalogTests` "exactly five entries" assertion (or any equivalent catalog-count test) does not already exist, HALT — Story 84.1's *KEEP* list and the design doc's *Data-only* claim depend on this regression being tested. Add it as a small, named regression test inside this story before declaring done; do not silently rely on the next story to add it.
- If during implementation the `audibleToGrid` walk (today: top-level `.note` enumeration on line 38–44 of `TimingOffsetDetectionPattern.swift`) is found to be exercised by a test whose expected output would change under the recursive walk 84.3 introduces — HALT. 84.2 is data-only; the recursive walk is 84.3's job and any test change here would foreshadow that work incorrectly.

**Never:**
- No `@AppStorage` migration shim, no `UserDefaults` reset code, no first-launch lookup intercept. The unknown-id-on-lookup fallback from Epic 82.5 already handles stale stored ids by resolving to `defaultPattern`.
- No new catalog entries. The picker still shows exactly five entries — `pattern_01` through `pattern_05` — still flat, still rendered by Epic 82.6's equal-cell renderer (the proportional renderer is 84.3's; the sectioned picker + tuplet content is 84.4's).
- No changes to `Beat` builder shapes, `defaultOffsetNotePosition` values, `pickable` derivation, `audibleToGrid` semantics, or `clampedOffsetNotePosition(_:)` logic. The five patterns produce sample-identical audio and identical pickable sets before and after.
- No changes to per-cell accessibility labels or the `patternRowAccessibilityLabel(for:)` output. The visible string the screen reader speaks is unchanged for each pattern (the doc-comment example string updates to `pattern_01`, but the function's runtime output never named ids).
- No `Localizable.xcstrings` changes. No new German strings. `bin/add-localization.swift --missing` must still report `0`.
- No edits to `docs/planning-artifacts/tod-tuplet-renderer-design.md` (84.1's deliverable, frozen). No edits to `docs/implementation-artifacts/epic-84-context.md` (already updated by 84.1). No retroactive prose edits to `tod-initial-pattern-catalog.md` beyond the single forward-pointer note.
- No "TOD" in any code identifier introduced or modified by this story (per `feedback_tod_shorthand_only`). The retired-id registry comment uses "Timing Offset Detection" or a domain term in any prose.
- No reordering of `TimingOffsetDetectionPatternCatalog.all`. Entries stay in the same order; only their ids and Swift accessor names change.
- No partial commit. The rename lands as one commit: code + tests + doc-comment updates + retired-id registry header + forward-pointer note in `tod-initial-pattern-catalog.md`, all together.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Fresh install after swap | No `selectedPatternId` in `UserDefaults` | `@AppStorage` default `TimingOffsetDetectionPatternCatalog.defaultPatternId` = `"pattern_01"` resolves to `pattern_01`; `offsetNotePosition` defaults to `3` per `pattern_01.defaultOffsetNotePosition` | N/A |
| Michael's dev device after swap | `selectedPatternId` = `"pattern_1111"` stored from before swap | `pattern(forStoredId:)` falls through `pattern(withId:)` → throws `.unknownPatternId("pattern_1111")` → returns `defaultPattern` = `pattern_01`. The 82.6 reclamp path reads `pattern_01.clampedOffsetNotePosition(storedRaw)`: stored `3` stays `3` (pickable in `pattern_01`); any other stored value resolves to `pattern_01.defaultOffsetNotePosition` | N/A — Epic 82.5 fallback handles silently |
| Michael's dev device with non-default stored id | `selectedPatternId` = `"pattern_1010"` (or any other retired id) | Unknown-id fallback → `pattern_01`; `offsetNotePosition` reclamps to `pattern_01.defaultOffsetNotePosition` = `3` | N/A |
| Catalog count regression | `TimingOffsetDetectionPatternCatalog.all` | Contains exactly five entries `[pattern01, pattern02, pattern03, pattern04, pattern05]` in this order; each entry's `id` matches the new convention | Test fails (red); spec rejected |
| Beat-shape regression | For each renamed pattern, build a `Beat` via `pattern.beat(offsetNotePosition: <default>, offsetAmount: .zero)` | Resulting `subdivisions` array is bit-identical to the pre-rename construction (same kinds, same velocities, same `.zero` offsets) | Test fails (red); spec rejected |
| Pickable-set regression | For each renamed pattern, `pattern.pickable` | Matches the pre-rename set verbatim: `{2,3,4}` for `pattern_01`, `{2,3}` for `pattern_02`/`pattern_03`, `{2}` for `pattern_04`/`pattern_05` | Test fails (red); spec rejected |
| Picker row accessibility output | Each renamed pattern → `patternRowAccessibilityLabel(for:)` | Same string as before rename (e.g. `pattern_01` reads `"Accent, Note, Note, Note"`, same as `pattern_1111` did) | N/A |

</frozen-after-approval>

## Code Map

- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPattern.swift` — five `static let` entries: rename Swift identifiers (`pattern1111` → `pattern01`, etc.); update `id:` string literals per the rename map; update doc-comment prose at line 148 that names `pattern_1111`.
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPatternCatalog.swift` — add retired-id registry comment block at top of file (header + empty body, per design doc); update `defaultPatternId` literal to `"pattern_01"`; update `all` array's accessor names; update doc-comment prose (lines 9–18) that names the old ids and the categorization-by-old-id phrasing.
- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift` — doc comment line 93 names `pattern_1111` in a worked example; update to `pattern_01`. No runtime change.
- `Peach/Training/TimingOffsetDetection/TimingDotView.swift` — four `#Preview` labels naming `pattern_1111`; update to `pattern_01`. Four `pattern: .pattern1111` accessor refs; rename to `.pattern01`. One `TimingOffsetDetectionPattern.pattern1111.subdivisions.count` ref; rename to `.pattern01`.
- `PeachTests/Mocks/MockTimingOffsetDetectionUserSettings.swift` — `var selectedPattern: TimingOffsetDetectionPattern = .pattern1111` → `.pattern01`.
- `PeachTests/Core/Training/TimingOffsetDetectionSettingsTests.swift` — string literal `"pattern_1111"` in `@Test` description + identifier refs `.pattern1111`; update to new id and identifier.
- `PeachTests/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionOffsetNotePositionSettingsSectionTests.swift` — function names (`pattern1111Anchor`, `pattern1011AllCells`, …) + identifier refs + `@Test` description strings naming old ids + MARK comments. All update to new ids/identifiers.
- `PeachTests/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSectionTests.swift` — five `for: .pattern1XXX` refs + `@Test` description strings; update.
- `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionSessionTests.swift` — line 186 `@Test` description names `pattern_1111`; line 193 uses `.pattern1111`. Update.
- `PeachTests/Training/TimingOffsetDetection/TimingDotViewTests.swift` — three `for: .pattern1XXX` refs + `@Test` description strings + MARK-level comments naming old ids. Update.
- `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionPatternCatalogTests.swift` — `all` array literal + `@Test` description strings + `pattern(withId:)` / `pattern(forStoredId:)` test argument literals. Update.
- `PeachTests/Training/TimingOffsetDetection/AppTimingOffsetDetectionUserSettingsTests.swift` — string literals `"pattern_1111"` in setUp + assertion. Update.
- `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionPatternTests.swift` — `@Test` description strings + MARK headers naming old ids. Update.
- `docs/planning-artifacts/tod-initial-pattern-catalog.md` — add a single forward-pointer note (2–3 lines) at the top of the doc pointing to the rename map in `tod-tuplet-renderer-design.md`. Body prose retains old ids as historical context.

## Tasks & Acceptance

**Execution:**
- [x] `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPattern.swift` -- rename five `static let` identifiers and update `id:` string literals per the rename map; update doc-comment line 148. Verify each entry's `subdivisions`, `defaultOffsetNotePosition`, and velocity values are byte-identical to current.
- [x] `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPatternCatalog.swift` -- add retired-id registry comment block at top; update `defaultPatternId` to `"pattern_01"`; update `all` array entries to the new accessor names; rewrite the doc comment block (lines 9–18) to use the new ids and convention name.
- [x] `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift` -- update line 93's worked-example doc comment from `pattern_1111` to `pattern_01`.
- [x] `Peach/Training/TimingOffsetDetection/TimingDotView.swift` -- update four `#Preview` labels + accessor refs + identifier-qualified ref on line 153.
- [x] All `PeachTests/` files enumerated in Code Map -- update string-literal ids, Swift accessor refs, `@Test` description strings, function names, and MARK comments per the rename map. Grep-clean: zero `pattern_1[01]+` literals and zero `pattern1[01]+` Swift identifiers remain anywhere under `Peach/` or `PeachTests/` after this task.
- [x] `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionPatternCatalogTests.swift` -- regression test asserting `TimingOffsetDetectionPatternCatalog.all.count == 5` AND ids in order are `["pattern_01"…"pattern_05"]` added (`catalogIdsMatchOpaqueConvention`); Beat-shape regression added (`catalogEntrySubdivisions`, parameterized over all five entries).
- [x] `docs/planning-artifacts/tod-initial-pattern-catalog.md` -- forward-pointer note at top of doc already in place from 84.1's review iteration 1 (line 3 names the rename map and the `pattern_NNNN` → `pattern_01`–`pattern_05` rename). No additional edit needed.
- [x] Run `bin/test.sh && bin/test.sh -p mac`; both green. Confirm `bin/add-localization.swift --missing` reports `0` (no new strings expected).
- [x] Run `grep -rn "pattern_1[01]\{3,\}\|pattern1[01]\{3,\}" Peach PeachTests` -- expect zero matches. Captured in *Verification*.

**Acceptance Criteria:**
- Given the catalog after this story, when an agent reads `TimingOffsetDetectionPatternCatalog.all`, then it returns exactly five entries with ids `["pattern_01", "pattern_02", "pattern_03", "pattern_04", "pattern_05"]` in this order, each with `Beat`-builder output and `pickable` set verbatim from the pre-rename construction.
- Given a fresh install after this story, when the TOD screen loads, then `selectedPatternId` defaults to `"pattern_01"` and the renderer shows the same four-cell preview the user saw for the old `pattern_1111` (still under Epic 82.6's equal-cell renderer; visual change is 84.3's).
- Given Michael's dev device with a pre-swap stored `selectedPatternId` (any of the old `pattern_1XXX` ids), when the app launches, then `pattern(forStoredId:)` resolves via the Epic 82.5 unknown-id fallback to `pattern_01`, the existing 82.6 reclamp path resets `offsetNotePosition` to `pattern_01.defaultOffsetNotePosition` (`3`), and no crash, no migration prompt, and no log error occur.
- Given the catalog file after this story, when an agent opens `TimingOffsetDetectionPatternCatalog.swift`, then they find a retired-id registry comment block at the top stating the convention rule (fixed at first registration, two-digit padding, past-99 widening), with an empty registry body.
- Given the codebase after this story, when an agent runs `grep -rn "pattern_1[01]\{3,\}\|pattern1[01]\{3,\}" Peach PeachTests`, then it returns zero matches.
- Given `bin/test.sh && bin/test.sh -p mac` after this story, then both runs are green; `bin/add-localization.swift --missing` reports `0`.
- Given `docs/planning-artifacts/tod-initial-pattern-catalog.md` after this story, when read top-to-bottom, then it carries a forward-pointer note (within the first 10 lines after frontmatter) directing readers to the rename map in `tod-tuplet-renderer-design.md`; the body's pre-existing ids are unchanged.

## Spec Change Log

### 2026-06-05 — Review iteration 1 (patches only, no spec loopback)

Three parallel adversarial reviewers (blind hunter / edge-case hunter / acceptance auditor) produced ~45 raw findings. After deduplication: 0 `intent_gap`, 0 `bad_spec` (the `<frozen-after-approval>` block did not need amendment), 4 `patch` findings applied to the deliverable, 3 findings appended to `deferred-work.md`, and the remainder rejected (no-context misreadings of the diff format, conscious design trade-offs the reviewers couldn't see, speculative future concerns, pre-existing patterns in unrelated files, and one acceptance-auditor misread of the `sprint-status.yaml` header date).

**Triggering findings (severity-ordered, deduplicated):**

- MEDIUM — Edge hunter #1 + #2 — `TimingOffsetDetectionPatternPickerSettingsSection.patternIdBinding`'s `get` returned the *raw* stored id. On Michael's dev device with a stale `selectedPatternId` (`pattern_1111`), the outer row preview resolved via `pattern(forStoredId:)` and showed `pattern_01`'s visual, but the drill-down `Picker`'s row tags didn't match the raw stored value — drill-down entered with no row selected. **Regression caused by this rename.**
- LOW — Blind hunter #11 — `TimingOffsetDetectionOffsetNotePositionSettingsSectionTests` MARK section order was `pattern_01, _02, _04, _03, _05`. Organic bitmask grouping under the old ids; under the opaque convention numeric order is what readers expect.
- LOW — Edge hunter #7 — `TimingOffsetDetectionPatternTests` MARK header `// MARK: - New catalog entries (82.7)` and `newCatalogEntryShape` / `newCatalogEntryBeatBuilderPlacesOffsetAtResolvedGridIndex` referenced the long-retired "vs. the original `pattern_1111`" distinction.
- LOW — Edge hunter #13 — `AppTimingOffsetDetectionUserSettingsTests.selectedPatternUnknownIdFallsBackToDefault` used `"pattern_xxxx"` as the unknown id; nothing exercised the migration claim for the five legacy `pattern_<bitmask>` ids specifically.

**Amendments outside the frozen block:**

- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift` (`patternIdBinding`): `get` now returns `TimingOffsetDetectionPatternCatalog.pattern(forStoredId: selectedPatternId).id` — the resolved canonical id — so the drill-down picker's selection matches the outer row's preview when storage carries a retired id. No `UserDefaults` write; the existing `set` path still canonicalizes on user action. Doc comment expanded with the rationale.
- `PeachTests/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionOffsetNotePositionSettingsSectionTests.swift`: MARK sections reordered to numeric catalog order (`pattern_01, _02, _03, _04, _05`).
- `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionPatternTests.swift`: MARK header renamed `New catalog entries (82.7) → Rest-bearing catalog entries`; the two `@Test` descriptions and function names renamed `newCatalogEntryShape → restBearingCatalogEntryShape` and `newCatalogEntryBeatBuilderPlacesOffsetAtResolvedGridIndex → restBearingCatalogEntryBeatBuilderPlacesOffsetAtResolvedGridIndex`; doc comments rephrased ("every rest-bearing entry except `pattern_01`, the all-audible reference").
- `PeachTests/Training/TimingOffsetDetection/AppTimingOffsetDetectionUserSettingsTests.swift`: new `@Test`, parameterized over `["pattern_1111", "pattern_1011", "pattern_1101", "pattern_1010", "pattern_1001"]`, asserts `port.selectedPattern == .pattern01` for each. Locks the migration claim against future regression.

**Known-bad states avoided:**

- Michael's dev device opens TOD Settings → outer row preview shows `pattern_01` visual → drill-down picker shows "no row selected" → user picks the same visual that was already shown → silent storage rewrite to `pattern_01`. Cosmetically confusing without behavioural malfunction.
- A future contributor reordering `TimingOffsetDetectionPatternCatalog.all` and the existing id-only equality test passing while downstream test files' MARK ordering drifts further out of sync.
- 84.4 implementer reads `New catalog entries (82.7)` header, infers the parametrization is exclusive to the 82.7 set, and writes a parallel `New catalog entries (84.4)` block instead of extending the existing parametrization.
- A future regression in the legacy-id fallback path that breaks specifically on `pattern_<bitmask>` shapes (e.g. an over-eager prefix matcher) and gets caught only by Michael noticing.

**Deferred (appended to `deferred-work.md`):**

- Edge hunter #3 — `AppTimingOffsetDetectionUserSettings.selectedPattern` recomputes + logs warning on every access (no memoization, no log dedup).
- Edge hunter #5 — `catalogEntrySubdivisions` regression test has no `.nested` shape — 84.3/84.4 must extend `Cell` and the matcher (or replace with a `Beat`-tree equality check) when nested entries register.
- Edge hunter #9 — `pattern_02`'s doc comment cross-references `pattern_01` by id; no governance rule for catalog cross-references after hypothetical retirement.

**Rejected (sampled — not exhaustive):**

- Blind hunter "diff truncated" claim — `git diff` produced the full 532-line diff; no truncation. Acceptance auditor confirmed it could read all 14 files.
- Blind hunter "ID convention violated by the renumbering" — the convention was locked in 84.1 explicitly to start *with* this rename; "numbers never change" applies from this point forward.
- Blind hunter "silent data-loss regression masquerading as a rename" — addressed in this spec's *Design Notes*; Epic 82 hasn't shipped, dev-device cost is acknowledged and accepted.
- Blind hunter "opaque ids lose self-checkability" — the conscious trade-off Story 84.1 made; not in scope here.
- Acceptance auditor "`last_updated` rolled back to 2026-06-04" — misread; the date stayed at 2026-06-05, only the descriptive comment text changed (84.1 done → 84.2 in-progress).

**KEEP (re-derivation must preserve):**

- The five-entry rename map exactly as locked in 84.1's design doc — no off-map ids.
- The retired-id registry header at the top of `TimingOffsetDetectionPatternCatalog.swift` with empty body.
- The two regression tests `catalogIdsMatchOpaqueConvention` and `catalogEntrySubdivisions` and their hand-written expected arrays.
- The new legacy-bitmask-id fallback test in `AppTimingOffsetDetectionUserSettingsTests`.
- The picker `get`-resolves-canonical fix in `patternIdBinding`.
- The numeric MARK ordering in `OffsetNotePositionSettingsSectionTests`.
- No `UserDefaults` migration shim, no first-launch rewrite, no `Localizable.xcstrings` change.

## Design Notes

**Why both the `id:` string and the Swift accessor rename together:** Half-rename — `id` `"pattern_01"` but `static let pattern1111` — would persist the bitmask-shape mental model exactly where future readers grep when they wonder "what does this id mean?" The Swift identifier IS where the visual shape lived; if the id is opaque, the accessor name must be too. Renaming together is the cheapest moment to lock the convention into both surfaces.

**Why no migration shim:** Epic 82.5 already implemented the unknown-id-on-lookup fallback (`pattern(forStoredId:)` falls back to `defaultPattern`). For a stored `"pattern_1111"`, it resolves to `defaultPattern` (now `pattern_01`) — the exact same behavioural intent. Michael's dev device sees one launch where `offsetNotePosition` reclamps to `3` from whatever was stored, then settles. The TOD-shipping cut has not reached the App Store; no other devices carry stale state. A migration shim (read old key → write new key) would be code we delete in three weeks once Michael's dev device has reseated. The Epic 82.5 fallback was designed for exactly this case.

**Retired-id registry header (sketch):**

```
// Catalog of TimingOffsetDetectionPattern entries.
//
// ID convention (locked in tod-tuplet-renderer-design.md, story 84.1):
//   `pattern_NN` — sequential, zero-padded two-digit. Numbers are assigned at
//   first registration and never change; reordering this file does not
//   renumber entries. Removed entries' numbers are retired in the registry
//   below and never reused. New entries take the next available number.
//   Past `pattern_99`, new entries widen to three digits (`pattern_100`+);
//   existing two-digit ids are preserved.
//
// Retired ids:
//   (none yet — Epic 84 retires nothing)
```

**Why the data-layer recursive walk stays out:** `TimingOffsetDetectionPattern.audibleToGrid` walks only top-level `.note` subdivisions today; Adam's *Hidden Assumption #1* in the design doc surfaces this. That walk becomes recursive in 84.3 as part of the renderer work — that's where the test surface changes meaningfully (audible-to-grid for a `.nested(Beat)` child). Folding it into 84.2 would conflate "data-only id swap" with "data-shape change" and lose the clean review surface for both.

## Verification

**Commands (ran 2026-06-05; re-ran after review iteration 1 patches):**
- `bin/build.sh` -- `BUILD SUCCEEDED (1 warnings)` (unrelated AppIntents warning).
- `bin/test.sh` (iOS) -- `ALL TESTS PASSED (1866 passed)` (+5 from the new legacy-bitmask-id parameterized fallback test added in iteration 1).
- `bin/test.sh -p mac` (macOS) -- `ALL TESTS PASSED (1860 passed)` (+5 from the same test).
- `grep -rnE "pattern_1[01]{3,}|pattern1[01]{3,}|Pattern1[01]{3,}" Peach PeachTests` -- zero matches (exit 1).
- `grep -n "tod-tuplet-renderer-design" docs/planning-artifacts/tod-initial-pattern-catalog.md` -- 2 matches (lines 3 and 6), forward pointer in place from 84.1.
- `bin/add-localization.swift --missing` -- `0 keys missing German translation`.

**Manual checks:**
- `TimingOffsetDetectionPatternCatalog.swift`: retired-id registry header is in place at the top of the file, before the `enum` declaration; body line states `(none yet — Epic 84 retires nothing)`.
- On Michael's dev device after this swap lands, launch the app once: the TOD Settings screen should come up cleanly (no crash, no log error); the pattern preview shows the same equal-cell four-dot shape; if the previously-stored `selectedPatternId` was `pattern_1111`, Epic 82.5's `pattern(forStoredId:)` fallback resolves it to `pattern_01`, the picker drill-down (review iteration 1 patch) also shows `pattern_01` as the selected row (no "nothing selected" state), and Epic 82.6's reclamp pulls `offsetNotePosition` back to `3`. To verify, watch one launch then drill into Settings → TOD section → Pattern row.

## Suggested Review Order

**Entry point — the design constraint**

- The convention rule + rename map this story applies; reviewers should anchor here first.
  [`tod-tuplet-renderer-design.md:37`](../planning-artifacts/tod-tuplet-renderer-design.md#L37)

**Catalog rename + retired-id registry**

- Retired-id registry header (empty body); convention rule restated in-file.
  [`TimingOffsetDetectionPatternCatalog.swift:3`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPatternCatalog.swift#L3)

- `defaultPatternId` flips to `pattern_01`; `all` accessor refs renamed.
  [`TimingOffsetDetectionPatternCatalog.swift:36`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPatternCatalog.swift#L36)

- Five `static let`s renamed and `id:` literals updated in lockstep.
  [`TimingOffsetDetectionPattern.swift:133`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPattern.swift#L133)

**Picker UX continuity (review iteration 1 patch)**

- `patternIdBinding.get` resolves canonical id so drill-down `Picker` matches the outer row when storage carries a retired id.
  [`TimingOffsetDetectionPatternPickerSettingsSection.swift:54`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift#L54)

**Regression coverage**

- Catalog ids pinned to the locked rename-map strings — not id-only equality.
  [`TimingOffsetDetectionPatternCatalogTests.swift:91`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionPatternCatalogTests.swift#L91)

- Beat-shape regression: hand-written expected subdivisions per entry — proves data-only.
  [`TimingOffsetDetectionPatternCatalogTests.swift:100`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionPatternCatalogTests.swift#L100)

- Legacy bitmask ids fall back to `pattern_01` — locks the migration claim for Michael's dev device.
  [`AppTimingOffsetDetectionUserSettingsTests.swift:84`](../../PeachTests/Training/TimingOffsetDetection/AppTimingOffsetDetectionUserSettingsTests.swift#L84)

**Test housekeeping (review iteration 1 patches)**

- MARK sections reordered to numeric catalog order.
  [`TimingOffsetDetectionOffsetNotePositionSettingsSectionTests.swift:39`](../../PeachTests/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionOffsetNotePositionSettingsSectionTests.swift#L39)

- "New catalog entries (82.7)" renamed to "Rest-bearing catalog entries"; parameterized test names updated.
  [`TimingOffsetDetectionPatternTests.swift:245`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionPatternTests.swift#L245)

**Peripheral updates**

- Preview labels + identifier refs swept.
  [`TimingDotView.swift:122`](../../Peach/Training/TimingOffsetDetection/TimingDotView.swift#L122)

- Worked-example doc comment updated.
  [`TimingOffsetDetectionPatternPickerSettingsSection.swift:93`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift#L93)

- Sprint status: 84-2 advances to review; epic-84 remains in-progress.
  [`sprint-status.yaml:770`](sprint-status.yaml#L770)
