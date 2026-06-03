---
title: 'Story 82.5: Pattern catalog domain layer wrapping `Beat`'
type: 'feature'
created: '2026-06-03'
status: 'done'
baseline_commit: 'bb67f89081a14744eb1180e7f9a5a2ddb18d82ee'
context:
  - '{project-root}/docs/planning-artifacts/tod-initial-pattern-catalog.md'
  - '{project-root}/docs/implementation-artifacts/epic-82-context.md'
  - '{project-root}/docs/implementation-artifacts/82-3-initial-pattern-catalog-and-picker-ux.md'
  - '{project-root}/docs/implementation-artifacts/82-4-offset-note-terminology-caveat-sweep.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** TOD's beat construction (`TimingOffsetDetectionSession.buildBeat`) hard-codes the four-equal-16ths figure and addresses positions as a single 1-based index into a fixed grid. Story 82.3 locked the data model needed to break this — a `TimingOffsetDetectionPattern` wrapper over `Beat` with audible-position indexing, a `TimingOffsetDetectionPatternCatalog` registry that returns patterns by stable id, and a pattern-aware clamp helper that gates every `@AppStorage` read — but nothing in code knows this design yet. The next two stories (82.6 Settings UI, 82.7 catalog content) are blocked until this scaffolding lands.

**Approach:** Introduce `TimingOffsetDetectionPattern` (TOD-local value type) and `TimingOffsetDetectionPatternCatalog` (TOD-local enum namespace) with **today's `pattern_1111` (`* * * *`) as the only registered entry**. Wire the existing pipeline through them: `TimingOffsetDetectionSession.buildBeat` is replaced by `TimingOffsetDetectionPattern.beat(offsetNotePosition:offsetAmount:)`; a new `selectedPatternId` `@AppStorage` key joins `offsetNotePosition` in `TimingOffsetDetectionSettingsKeys` / the port / the snapshot; the new `TimingOffsetDetectionPattern.clampedOffsetNotePosition(_:)` becomes the sole read path at every `@AppStorage` consumer site (port + settings section + training screen). Behavioral no-op for existing 82.1 users with stored `offsetNotePosition ∈ {2,3,4}` and unset `selectedPatternId` — they get the same `Beat` output. Existing 82.1 users with stored `offsetNotePosition == 1` reset to `OffsetNotePosition(3)` because position 1 (the metric anchor) is excluded from every pattern's pickable set by design (see [`tod-initial-pattern-catalog.md` § *Pickable-position rule*](../planning-artifacts/tod-initial-pattern-catalog.md#pickable-position-rule)). `OffsetNotePosition(clamping:)` (added in 82.4) is removed — pattern-aware clamping is the only path after this story.

## Boundaries & Constraints

**Always:**
- `TimingOffsetDetectionPattern.pickable` excludes audible position 1 for every entry. Derived at init as `Set(2...audibleCount)`. A catalog-wide invariant test asserts this on `TimingOffsetDetectionPatternCatalog.all`.
- `TimingOffsetDetectionPattern.beat(offsetNotePosition:offsetAmount:)` translates audible → grid via the pattern's precomputed `audibleToGrid` table; never via raw arithmetic on the audible index. Precondition: `pickable.contains(offsetNotePosition.rawValue)`. The resulting `Beat` preserves rests as `.rest`, applies `offsetAmount` to exactly the chosen grid `.note`, and leaves all other `.note` subdivisions with `.zero` offset.
- `TimingOffsetDetectionPattern.clampedOffsetNotePosition(_ rawValue: Int) -> OffsetNotePosition` is the only path from a stored `Int` to an `OffsetNotePosition` after this story. Every `@AppStorage` consumer site — the port (`AppTimingOffsetDetectionUserSettings`), the settings section, and the training screen — reads through it. Direct `OffsetNotePosition(clamping:)` calls disappear.
- `TimingOffsetDetectionPatternCatalog.pattern(withId:)` is the sole id → pattern lookup; `throws(TimingOffsetDetectionPatternCatalogError) -> TimingOffsetDetectionPattern` on miss (typed, no crash). `defaultPatternId == "pattern_1111"`; `defaultPattern` traps with `preconditionFailure` if the default id isn't registered (catalog invariant).
- `pattern_1111` registered with subdivisions `[.note(.accent,.zero), .note(.normal,.zero), .note(.normal,.zero), .note(.normal,.zero)]` and `defaultOffsetNotePosition: OffsetNotePosition(3)`. This preserves 82.4 audio output for users with stored `offsetNotePosition ∈ {2,3,4}` and absent `selectedPatternId`.
- `selectedPatternId` `@AppStorage` key has default `TimingOffsetDetectionPatternCatalog.defaultPatternId` (`"pattern_1111"`); the port resolves via the catalog and falls back to `defaultPattern` on unknown id, logging at `.warning` (TOD subsystem `os.Logger`) per the design doc § *Migration target*.
- TOD remains `PEACH_RESEARCH`-gated. New tests follow the surrounding `#if PEACH_RESEARCH` convention used by the existing TOD test files.
- New files live in `Peach/Training/TimingOffsetDetection/` (TOD-local). No move to `Core/Music/`.
- Sober factual copy in any new doc text per `[[feedback_sober_factual_copy]]`. No forward references to 82.6/82.7 inside the types themselves.
- Sprint-status key `82-5-pattern-catalog-domain-layer` flips to `in-progress` on start, `done` after review per `[[feedback_update_status_after_review]]`.

**Ask First:**
- If keeping `OffsetNotePosition.default = OffsetNotePosition(3)` becomes misleading once non-`pattern_1111` defaults exist (82.7), halt and ask whether to remove it now. **Default plan: keep `.default`.** Rationale: it remains pattern_1111's default (the migration target) and is convenient in test fixtures; renaming/removing would churn stubs/mocks for marginal gain.
- If `subdivisionsPerBeat` (a constant on `TimingOffsetDetectionSession`) has callers outside `buildBeat`, halt and surface before deleting. **Default plan: delete it along with `buildBeat`** since the pattern's `subdivisions.count` replaces it.
- If any TOD localized string would change for type-related reasons (it shouldn't — strings settled in 82.2; no UI text changes here), halt and surface before touching `Localizable.xcstrings`.

**Never:**
- No `@AppStorage` migration shim for `selectedPatternId`. The key is brand-new; absent storage defaults to `pattern_1111` via the `@AppStorage` default-value parameter.
- No edits to `Beat` / `Subdivision` / `SoundFontStepSequencer`. Engine layer is already correct.
- No changes to `Localizable.xcstrings`. No `LocalizedStringResource` display name on `TimingOffsetDetectionPattern` (design doc § *No pattern names*) — the type carries id + structural metadata only.
- No additional catalog entries — only `pattern_1111`. The other four entries (`pattern_1011`, `pattern_1101`, `pattern_1010`, `pattern_1001`) ship in 82.7.
- No Settings UI layout changes. `TimingOffsetDetectionOffsetNotePositionSettingsSection` keeps its 1...4 cell layout for this story (the rest-aware scalable picker is 82.6's job). Only the read-path clamp at the section + screen changes.
- No widening of `OffsetNotePosition.validRange` beyond `1...4`. All initial catalog entries have `audibleCount ≤ 4`. Wider ranges are a future story when K > 4 patterns land.
- No public constructor on `TimingOffsetDetectionPatternCatalog` that registers patterns at runtime. The catalog is a read-only static-data namespace; 82.7 adds entries by editing the `all` list.
- No DEBUG `@TaskLocal` override on `TimingOffsetDetectionPatternCatalog` in this story. The catalog has one entry; tests use it directly. (Revisit in 82.7 if per-pattern test helpers need isolation.)

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| `TimingOffsetDetectionPattern.beat` — pattern_1111, position 3 | `pattern1111.beat(offsetNotePosition: OffsetNotePosition(3), offsetAmount: .milliseconds(20))` | `Beat([note(accent,0), note(normal,0), note(normal,20ms), note(normal,0)])` | N/A |
| `TimingOffsetDetectionPattern.beat` — audible→grid via rests (test-fixture pattern, not registered) | fixture `[note(accent,0), .rest, note(normal,0), note(normal,0)]`, audible position 2 | offset applied to grid index 2 (audible 2 → grid 2 per `audibleToGrid = [0,2,3]`) | N/A |
| `TimingOffsetDetectionPattern.beat` — non-pickable position | `pattern1111.beat(offsetNotePosition: OffsetNotePosition(1), offsetAmount: .zero)` | `preconditionFailure` — caller must clamp first | crash (programmer error) |
| `TimingOffsetDetectionPattern.clampedOffsetNotePosition` — pickable | `pattern1111.clampedOffsetNotePosition(3)` | `OffsetNotePosition(3)` | N/A |
| `TimingOffsetDetectionPattern.clampedOffsetNotePosition` — metric-anchor | `pattern1111.clampedOffsetNotePosition(1)` | `OffsetNotePosition(3)` (pattern's default) | silent clamp |
| `TimingOffsetDetectionPattern.clampedOffsetNotePosition` — out-of-range | `pattern1111.clampedOffsetNotePosition(99)` | `OffsetNotePosition(3)` (pattern's default) | silent clamp |
| `TimingOffsetDetectionPatternCatalog.pattern(withId:)` — known id | `try .pattern(withId: "pattern_1111")` | returns `TimingOffsetDetectionPattern.pattern1111` | N/A |
| `TimingOffsetDetectionPatternCatalog.pattern(withId:)` — unknown id | `try .pattern(withId: "pattern_xxxx")` | throws `TimingOffsetDetectionPatternCatalogError.unknownPatternId("pattern_xxxx")` | typed throw |
| Port `selectedPattern` — no key | UserDefaults `selectedPatternId` absent | returns `TimingOffsetDetectionPatternCatalog.defaultPattern` (== `pattern_1111`) | silent default |
| Port `selectedPattern` — known stored id | UserDefaults stores `"pattern_1111"` | returns `pattern_1111` | N/A |
| Port `selectedPattern` — unknown stored id | UserDefaults stores `"pattern_xxxx"` | returns `TimingOffsetDetectionPatternCatalog.defaultPattern`; logs `.warning` with the unknown id | typed throw caught, logged |
| Port `offsetNotePosition` — no key | UserDefaults `offsetNotePosition` absent | returns `selectedPattern.defaultOffsetNotePosition` (3 for `pattern_1111`) | silent default |
| Port `offsetNotePosition` — pickable stored | UserDefaults stores `2`, pattern `pattern_1111` | returns `OffsetNotePosition(2)` | N/A |
| Port `offsetNotePosition` — metric-anchor stored | UserDefaults stores `1`, pattern `pattern_1111` | returns `OffsetNotePosition(3)` (clamped via pattern) | silent clamp via pattern |
| Port `offsetNotePosition` — corrupt stored | UserDefaults stores `99`, pattern `pattern_1111` | returns `OffsetNotePosition(3)` | silent clamp via pattern |
| Settings section read | `@AppStorage offsetNotePosition = 1`, `selectedPatternId = "pattern_1111"` | section displays cell 3 as the selected position (clamped via pattern) | silent clamp |
| Training screen read | same | dot indicator highlights audible position 3 (clamped via pattern); audio + indicator agree | silent clamp |

</frozen-after-approval>

## Code Map

- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPattern.swift` — **NEW**. `struct TimingOffsetDetectionPattern: Hashable, Sendable`. Stored: `id: String`, `subdivisions: [Subdivision]`, `defaultOffsetNotePosition: OffsetNotePosition`. Computed at init: `audibleToGrid: [Int]` (audible-1-based → grid-0-based; built by walking `subdivisions` and collecting `.note` indices), `audibleCount: Int { audibleToGrid.count }`, `pickable: Set<Int> { Set(2...audibleCount) }`. Methods: `func beat(offsetNotePosition: OffsetNotePosition, offsetAmount: Duration) -> Beat` (precondition `pickable.contains(...)`; rebuilds the subdivision array with offset applied to the resolved grid index); `func clampedOffsetNotePosition(_ rawValue: Int) -> OffsetNotePosition` (returns `OffsetNotePosition(rawValue)` if pickable, else `defaultOffsetNotePosition`). Carries `static let pattern1111: TimingOffsetDetectionPattern` defined inline (the only catalog entry until 82.7).
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPatternCatalog.swift` — **NEW**. `enum TimingOffsetDetectionPatternCatalog` (namespace). `static let all: [TimingOffsetDetectionPattern] = [.pattern1111]`. `static let defaultPatternId: String = "pattern_1111"`. `static var defaultPattern: TimingOffsetDetectionPattern { preconditionFailure on miss }`. `static func pattern(withId: String) throws(TimingOffsetDetectionPatternCatalogError) -> TimingOffsetDetectionPattern`. Co-locates `enum TimingOffsetDetectionPatternCatalogError: Error { case unknownPatternId(String) }`.
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift` — Delete the static `buildBeat(for:offsetNotePosition:)` and the `subdivisionsPerBeat` constant (only `buildBeat` uses it; verify with grep). `nextBeat()` becomes `settings.pattern.beat(offsetNotePosition: settings.offsetNotePosition, offsetAmount: trial.offset.duration)`.
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSettings.swift` — Add stored `var pattern: TimingOffsetDetectionPattern`. `from(_:todUserSettings:)` reads `todUserSettings.selectedPattern` and `todUserSettings.offsetNotePosition` (both already clamped against each other in the port).
- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionSettingsKeys.swift` — Add `static let selectedPatternId = "timingOffsetDetectionSelectedPatternId"`. Existing `offsetNotePosition` key string unchanged.
- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionUserSettings.swift` — Add `var selectedPattern: TimingOffsetDetectionPattern { get }` to the protocol. In `AppTimingOffsetDetectionUserSettings`: `selectedPattern` reads the id key (default `defaultPatternId`), calls `try? TimingOffsetDetectionPatternCatalog.pattern(withId:)`, falls back to `defaultPattern` and logs `.warning` on miss. `offsetNotePosition` now reads the active pattern first (via the same logic) and clamps the stored Int via `pattern.clampedOffsetNotePosition(_:)`; absent key → `pattern.defaultOffsetNotePosition`.
- `Peach/Training/TimingOffsetDetection/OffsetNotePosition.swift` — **Remove** `init(clamping rawValue: Int)`. Keep `init(_ rawValue: Int)` (strict, precondition), `static let validRange = 1...4`, `static let default = OffsetNotePosition(3)`, `var zeroBasedIndex: Int`.
- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionOffsetNotePositionSettingsSection.swift` — Add `@AppStorage(TimingOffsetDetectionSettingsKeys.selectedPatternId) private var selectedPatternId: String = TimingOffsetDetectionPatternCatalog.defaultPatternId`. Compute `private var activePattern: TimingOffsetDetectionPattern { (try? TimingOffsetDetectionPatternCatalog.pattern(withId: selectedPatternId)) ?? TimingOffsetDetectionPatternCatalog.defaultPattern }`. `effectivePosition` becomes `activePattern.clampedOffsetNotePosition(offsetNotePosition)`. Cell iteration still uses `OffsetNotePosition.validRange` for this story (layout unchanged). Tap action still writes the raw `Int` via the binding.
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionScreen.swift` — Same `selectedPatternId` `@AppStorage` + `activePattern` resolution. `testedNoteIndex: activePattern.clampedOffsetNotePosition(offsetNotePosition).zeroBasedIndex`. `TimingDotView` parameter stays `Int`.
- `Peach/App/PreviewDefaults.swift` — `StubTimingOffsetDetectionUserSettings`: add `let selectedPattern: TimingOffsetDetectionPattern = .pattern1111`.
- `PeachTests/Mocks/MockTimingOffsetDetectionUserSettings.swift` — Add `var selectedPattern: TimingOffsetDetectionPattern = .pattern1111`.
- `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionPatternTests.swift` — **NEW** (`#if PEACH_RESEARCH`). Covers every I/O matrix row whose subject is `TimingOffsetDetectionPattern.*`: init computes `audibleCount` and `audibleToGrid` correctly (use a non-`pattern_1111` test fixture with rests so the translation is non-trivial); `pickable == Set(2...audibleCount)`; `clampedOffsetNotePosition` rows; `beat(...)` produces the expected `Beat` for pattern_1111 (positions 2, 3, 4) and for the rest-containing fixture (validates audible→grid); `beat(...)` precondition trips on non-pickable position 1.
- `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionPatternCatalogTests.swift` — **NEW** (`#if PEACH_RESEARCH`). Covers catalog rows: `all.count == 1`; `all.first == TimingOffsetDetectionPattern.pattern1111`; `defaultPattern.id == "pattern_1111"`; `pattern(withId:)` known/unknown cases; **catalog-wide invariant**: `for p in TimingOffsetDetectionPatternCatalog.all { #expect(p.pickable.contains(1) == false) }`.
- `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionSessionTests.swift` — Migrate `buildBeatPerPosition` (was testing the static func) to assert on `TimingOffsetDetectionPattern.pattern1111.beat(offsetNotePosition:offsetAmount:)` directly for each of {2, 3, 4}; expectations on subdivisions/grid index unchanged. Existing `#if PEACH_RESEARCH` gate stays.
- `PeachTests/Training/TimingOffsetDetection/AppTimingOffsetDetectionUserSettingsTests.swift` — Add `selectedPattern` coverage rows from the I/O matrix (no key / known / unknown id). Migrate the existing `offsetNotePosition` rows to the pattern-aware clamp expectations (corrupt `1` and `99` both → `OffsetNotePosition(3)`; absent → `OffsetNotePosition(3)`; valid `2` → `OffsetNotePosition(2)`). Existing missing-key / corrupt-value coverage stays — just re-expressed under the new contract.
- `PeachTests/Core/Training/TimingOffsetDetectionSettingsTests.swift` — `from(...)` test asserts `settings.pattern == TimingOffsetDetectionPattern.pattern1111` (in addition to existing field expectations).
- `PeachTests/Training/TimingOffsetDetection/OffsetNotePositionTests.swift` — Drop the two `init(clamping:)` rows (valid / invalid). The clamping behavior moves to `TimingOffsetDetectionPatternTests`.
- `docs/implementation-artifacts/sprint-status.yaml` — `82-5-pattern-catalog-domain-layer: in-progress` (flipped to `done` after review).

## Tasks & Acceptance

**Execution:**
- [x] `TimingOffsetDetectionPattern.swift` — value type per Code Map; `static let pattern1111`
- [x] `TimingOffsetDetectionPatternCatalog.swift` — namespace + error enum
- [x] `OffsetNotePosition.swift` — remove `init(clamping:)`
- [x] `TimingOffsetDetectionSettingsKeys.swift` — add `selectedPatternId` key
- [x] `TimingOffsetDetectionUserSettings.swift` — add `selectedPattern` to protocol; rewrite `offsetNotePosition` getter; add `.warning` log
- [x] `TimingOffsetDetectionSettings.swift` — add `pattern` field; `from(...)` reads from port
- [x] `TimingOffsetDetectionSession.swift` — replace `buildBeat` with `settings.pattern.beat(...)`; delete static (kept `subdivisionsPerBeat` — has non-`buildBeat` callers in `silentBeat`, sample-position math, and lit-dot cycle indexing; surfaced in story report per *Ask First*)
- [x] `TimingOffsetDetectionOffsetNotePositionSettingsSection.swift` — add `selectedPatternId` `@AppStorage` + `activePattern`; clamp via pattern
- [x] `TimingOffsetDetectionScreen.swift` — same pattern-aware clamp path
- [x] `PreviewDefaults.swift` — add `selectedPattern` to stub
- [x] `MockTimingOffsetDetectionUserSettings.swift` — add `selectedPattern`
- [x] `TimingOffsetDetectionPatternTests.swift` — NEW; I/O matrix rows for `TimingOffsetDetectionPattern.*` (precondition-trip row omitted — no in-project precedent for asserting on `preconditionFailure`; surfaced in story report)
- [x] `TimingOffsetDetectionPatternCatalogTests.swift` — NEW; I/O matrix rows + catalog-wide invariant
- [x] `AppTimingOffsetDetectionUserSettingsTests.swift` — add `selectedPattern` tests; migrate `offsetNotePosition` tests to pattern-aware clamp
- [x] `TimingOffsetDetectionSessionTests.swift` — migrate `buildBeatPerPosition` to assert on `TimingOffsetDetectionPattern.pattern1111.beat(...)`
- [x] `TimingOffsetDetectionSettingsTests.swift` — `from(...)` expects `pattern == .pattern1111`
- [x] `OffsetNotePositionTests.swift` — drop `init(clamping:)` rows
- [x] `sprint-status.yaml` — flip to `in-progress`
- [x] Run `bin/test.sh --research && bin/test.sh --research -p mac` and `bin/test.sh && bin/test.sh -p mac` — all four pass; no new warnings
- [x] Run `bin/add-localization.swift --missing` — expected: 0 keys missing

**Acceptance Criteria:**
- Given a fresh-install or pre-82.5 user with absent `selectedPatternId` and stored `offsetNotePosition ∈ {2,3,4}`, when a TOD trial runs, then the emitted `Beat` is bit-identical to 82.4's output for the same trial parameters.
- Given a pre-82.5 user with stored `offsetNotePosition == 1`, when they open TOD, then the port, the settings-section selected cell, and the training-screen dot indicator all read `OffsetNotePosition(3)` (no UI/audio divergence; metric-anchor exclusion enforced).
- Given a pre-82.5 user with corrupt `selectedPatternId` (e.g. `"pattern_xxxx"`), when they open TOD, then the active pattern resolves to `pattern_1111`, the Console shows a `.warning` log naming the unknown id, and no crash occurs.
- Given `TimingOffsetDetectionPatternCatalog.pattern(withId: "pattern_xxxx")`, when called, then it throws `TimingOffsetDetectionPatternCatalogError.unknownPatternId("pattern_xxxx")`.
- Given a catalog-wide invariant test iterating `TimingOffsetDetectionPatternCatalog.all`, when run, then every entry's `pickable.contains(1) == false`.
- Given `TimingOffsetDetectionPattern.pattern1111.beat(offsetNotePosition: OffsetNotePosition(1), offsetAmount: .zero)`, when called, then `preconditionFailure` trips.
- Given `grep -rn "OffsetNotePosition(clamping" Peach PeachTests`, when run after this story, then zero matches.
- Given `grep -rn "static func buildBeat" Peach`, when run after this story, then zero matches in production.
- Both pre-commit gates pass on both schemes and both platforms (Research and non-Research, iOS and macOS).

## Spec Change Log

### 2026-06-04 — Review iteration 1 (patches only; no loopback)

**Triggering findings (deduplicated across blind hunter / edge case hunter / acceptance auditor):**

- **Catalog resolution duplicated across two views.** `TimingOffsetDetectionOffsetNotePositionSettingsSection` and `TimingOffsetDetectionScreen` both inlined `(try? pattern(withId:)) ?? defaultPattern` for the `@AppStorage` consumer pattern. All three reviewers flagged this as a code-reuse opportunity.
- **`pickable` was a computed property allocating `Set<Int>` per access.** Called once per `beat(...)` precondition; trivial to store as a `let` set in init.
- **Catalog did not enforce id uniqueness in `all`.** Single-entry catalog masks the risk; 82.7 expands `all` to five entries. A duplicate id would be silently shadowed by `first(where:)` (and equal under id-only `Equatable`).
- **`TimingOffsetDetectionSettings.init` defaulted to `.pattern1111`** rather than `TimingOffsetDetectionPatternCatalog.defaultPattern`. Same in `StubTimingOffsetDetectionUserSettings.selectedPattern`. Equivalent today; brittle if `defaultPatternId` ever changes.
- **No test pins the id-only `Equatable` choice.** Future refactor could quietly widen to structural equality without a test trip.
- **`TimingDotView.testedNoteIndex` semantics shift from grid to audible.** Correct for `pattern_1111` (audible == grid); breaks the moment 82.7 adds patterns with rests.
- **`.nested(Beat)` subdivisions pass through `beat(...)` verbatim.** Unreachable in the flat initial catalog; landmine for future tuplet patterns.

**Amendments outside the frozen block (per `simplify-code` / patch route — frozen block untouched):**

- `TimingOffsetDetectionPatternCatalog.swift` — added `static func pattern(forStoredId:) -> TimingOffsetDetectionPattern` that wraps `(try? pattern(withId:)) ?? defaultPattern` and documents the policy split (catalog stays pure; port logs unknown ids; views silently fall back).
- `TimingOffsetDetectionOffsetNotePositionSettingsSection.swift` and `TimingOffsetDetectionScreen.swift` — `activePattern` now delegates to the new helper.
- `TimingOffsetDetectionPattern.swift` — `pickable` promoted from computed `var` to stored `let`, computed once in `init`. The init-time precondition still uses the local `pickable` so initialization order stays clean.
- `TimingOffsetDetectionSettings.swift` and `PreviewDefaults.swift` — default values reference `TimingOffsetDetectionPatternCatalog.defaultPattern` instead of `.pattern1111` directly.
- `TimingOffsetDetectionPatternCatalogTests.swift` — added id-uniqueness invariant test and two `pattern(forStoredId:)` cases (known id round-trips, unknown id falls back to default).
- `TimingOffsetDetectionPatternTests.swift` — added `equalityIsIdentityBased` test pinning the id-only `Equatable` design choice.

**Defers (recorded in `docs/implementation-artifacts/deferred-work.md` under *From: Story 82.5*):**

- `TimingDotView` audible-vs-grid mismatch for non-`pattern_1111` patterns — resolution belongs to 82.6's `TimingDotView` reskin.
- `Subdivision.nested(Beat)` handling in `TimingOffsetDetectionPattern.beat(...)` — out of scope until tuplet patterns land.

**KEEP (re-derivation must preserve):**

- Audible-1-based addressing throughout the user-facing layer; grid-0-based internal to `beat(...)`.
- The pattern-aware clamp at every `@AppStorage` consumer site (port, settings section, training screen).
- The behavioral no-op for users with stored `offsetNotePosition ∈ {2,3,4}` and absent `selectedPatternId`.
- The metric-anchor exclusion (`pickable` never contains 1) as a catalog-wide invariant.
- The id-only `Hashable`/`Equatable` choice (now pinned by `equalityIsIdentityBased`).
- The K=4 math migration (`subdivisionsPerBeat` deleted; `evaluatePlaybackPosition` consults `settings.pattern.subdivisions.count`; `silentBeat` derives from the catalog default).

**Known-bad states avoided:**

- A third-place divergence in the `activePattern` resolution if a future contributor updates one view but not the other.
- A duplicate-id catalog entry in 82.7 silently shadowed by id-only equality + linear `first(where:)`.
- A future `defaultPatternId` change leaving stale `.pattern1111` defaults in synthesized settings.
- A future refactor of `==` to structural equality breaking the catalog's lookup model with no test to catch it.

## Design Notes

**Why `audibleToGrid` is precomputed at init, not derived per call:** the map is a property of the pattern's `[Subdivision]` shape and never changes. Computing it once keeps `beat(...)` O(K) (a single walk to apply the offset) and gives `clampedOffsetNotePosition` O(1) without per-call rescans. Three lines of init code prevent the silent no-op risk the design doc flags — an audible→grid off-by-one that lands the offset on a `.rest`, which `Beat.events(...)` then drops.

**Why `OffsetNotePosition.validRange` stays `1...4`:** the initial five-pattern catalog has `audibleCount ∈ {2,3,4}`, so the type's invariant covers every pickable position any registered pattern produces. The metric-anchor exclusion (position 1) is a *pickability* concern enforced by `TimingOffsetDetectionPattern.pickable`, not a *validity* concern of the value type. Future K>4 patterns will widen this; out of scope here.

**Why `OffsetNotePosition(clamping:)` is removed (deviation from 82.4):** 82.4 introduced it as defence-in-depth at the three `@AppStorage` consumer sites. After this story, every read site goes through `TimingOffsetDetectionPattern.clampedOffsetNotePosition(_:)`. The range-only clamp would incorrectly let position 1 through (1 is in `1...4`), but position 1 is never valid under the metric-anchor exclusion — a footgun. Leaving it in place would invite a future reader to call `OffsetNotePosition(clamping: 1)`, get `OffsetNotePosition(1)`, and then trip `beat(...)`'s precondition at runtime. Deleting forces every caller through the correct path.

**Why `OffsetNotePosition.default` stays:** it remains pattern_1111's default and is convenient in test fixtures, stubs, and mocks. Removing it would churn `MockTimingOffsetDetectionUserSettings` and `StubTimingOffsetDetectionUserSettings` for marginal gain. The naming asymmetry with `TimingOffsetDetectionPattern.defaultOffsetNotePosition` becomes worth revisiting if/when non-`pattern_1111` defaults arrive (82.7) — recorded under *Ask First*.

**Why the port owns the unknown-id `.warning` log, not the catalog:** the catalog throws a typed error; logging policy (level, subsystem, message format) belongs at the adapter boundary. The port is the only place that converts "what's in storage" to "what the rest of the code sees," so it's the natural site to surface "this stored value is unrecognized." The catalog stays pure (a registry); the port handles the storage → domain boundary.

**Why `TimingOffsetDetectionPatternCatalog` is an `enum` namespace, not a singleton:** the registry is read-only at runtime — no bootstrap step, no override flow, no mutation. `enum` with `static let all` is the simplest thing that works. `TrainingDisciplineRegistry`'s `Mutex` + `@TaskLocal` design exists because it IS bootstrapped from `PeachApp.init()` based on build configuration; this catalog isn't gated, never mutates, and doesn't need that machinery.

**Why `nextBeat()` consults `settings.pattern` and not the catalog directly:** the settings struct is the value-type snapshot the session captures at `start()` time. Resolving the pattern once (in `.from(...)`) and carrying it on `settings` matches the established pattern (other discipline-specific values are snapshotted there) and avoids the mid-session source-change anti-pattern.

**Behavioral compatibility — what stays exactly the same:** for any user with `offsetNotePosition ∈ {2,3,4}` and absent `selectedPatternId` (the universal pre-82.5 state), `settings.pattern.beat(...)` produces a `Beat` identical to the old `buildBeat`: four `.note` subdivisions, accent on grid 0, offset applied to grid index `offsetNotePosition - 1`. This is the no-op the epic refers to.

**Behavioral non-compatibility — what changes:** for users with stored `offsetNotePosition == 1`, the read path now clamps to 3. The audio at the next trial differs from what would have played pre-82.5 (offset on position 1 vs. 3). This is the design intent — position 1 is excluded by the perceptual analysis in [`tod-initial-pattern-catalog.md` § *Pickable-position rule*](../planning-artifacts/tod-initial-pattern-catalog.md#pickable-position-rule). TOD is `PEACH_RESEARCH`-gated; research-build users are developers; the reset is acceptable per the same precedent 82.4 set for the placeholder-key rename.

**No `@AppStorage` migration shim for `selectedPatternId`:** the key is brand-new — no prior version to migrate from. Absent storage defaults to `pattern_1111` via the `@AppStorage` default-value parameter. Once the (future) 82.6 picker writes the key, the user's choice persists; until then, the default carries.

## Verification

**Commands:**
- `bin/test.sh --research` — expected: full suite green on iOS (Debug, Research)
- `bin/test.sh --research -p mac` — expected: full suite green on macOS (Debug, Research)
- `bin/test.sh` — expected: full suite green on iOS (Debug, non-Research)
- `bin/test.sh -p mac` — expected: full suite green on macOS (Debug, non-Research)
- `bin/build.sh --research` — expected: zero new warnings
- `bin/add-localization.swift --missing` — expected: `0 keys missing German translation`
- `grep -rn "OffsetNotePosition(clamping" Peach PeachTests` — expected: zero matches
- `grep -rn "static func buildBeat" Peach` — expected: zero matches

**Manual checks:**
- Launch `Peach (Debug, Research)`. The Settings TOD section still shows four note-position cells with default selection on Note 3 (no UI layout regression). Tap a different position and relaunch; the new position persists.
- Force a metric-anchor stored value: `defaults write de.schuerig.peach.research timingOffsetDetectionOffsetNotePosition -int 1`. Relaunch. Both the dot indicator and the audible offset land on Note 3 — proving the pattern-aware clamp holds both consumer sites in agreement.
- Force an unknown selected pattern: `defaults write de.schuerig.peach.research timingOffsetDetectionSelectedPatternId -string "pattern_xxxx"`. Relaunch. Console emits a `.warning` log naming `pattern_xxxx`; the section behaves as if `pattern_1111` were selected; no crash.

## Suggested Review Order

**Pattern value type (entry point)**

- The single concept the whole story is built on — audible-position addressing, init-time invariant, pattern-aware clamp, and the `beat(...)` builder all live here.
  [`TimingOffsetDetectionPattern.swift:16`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPattern.swift#L16)

- `audibleToGrid` and `pickable` are computed once at init and stored. Init-time precondition catches a misregistered default before any session reads.
  [`TimingOffsetDetectionPattern.swift:48`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPattern.swift#L48)

- The translation that prevents an offset from landing on a `.rest` (which `Beat.events(...)` would drop). Precondition documents the contract for callers.
  [`TimingOffsetDetectionPattern.swift:73`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPattern.swift#L73)

- The sole `Int → OffsetNotePosition` path after this story; range *and* pickable both checked.
  [`TimingOffsetDetectionPattern.swift:100`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPattern.swift#L100)

- `pattern_1111` registration — the migration target, bit-identical to the pre-82.5 Beat for valid stored positions.
  [`TimingOffsetDetectionPattern.swift:132`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPattern.swift#L132)

**Catalog**

- Read-only namespace, throwing lookup, fail-fast `defaultPattern`, plus the `forStoredId:` helper shared by both `@AppStorage` views.
  [`TimingOffsetDetectionPatternCatalog.swift:7`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPatternCatalog.swift#L7)

**Settings & storage**

- New `selectedPatternId` `@AppStorage` key alongside the existing `offsetNotePosition` key.
  [`TimingOffsetDetectionSettingsKeys.swift:1`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionSettingsKeys.swift#L1)

- The port: resolves the active pattern, logs `.warning` on unknown ids, and clamps the stored Int through the pattern. Single source of truth for the storage→domain boundary.
  [`TimingOffsetDetectionUserSettings.swift:38`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionUserSettings.swift#L38)

- Settings snapshot carries the resolved pattern; consumed by the session at `start()` time.
  [`TimingOffsetDetectionSettings.swift:32`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSettings.swift#L32)

- `init(clamping:)` removed — the pattern-aware clamp is now the only path.
  [`OffsetNotePosition.swift:1`](../../Peach/Training/TimingOffsetDetection/OffsetNotePosition.swift#L1)

**Session — beat construction + K=4 migration**

- `nextBeat()` delegates to `settings.pattern.beat(...)`; the silent-teardown fallback derives its subdivision count from the catalog default.
  [`TimingOffsetDetectionSession.swift:228`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift#L228)

- `evaluatePlaybackPosition` consults `settings.pattern.subdivisions.count` per poll — the K=4 constant is gone.
  [`TimingOffsetDetectionSession.swift:325`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift#L325)

**`@AppStorage` consumer sites (both use the shared `forStoredId:` helper)**

- Settings section: `effectivePosition` clamps the raw `@AppStorage` Int through the active pattern.
  [`TimingOffsetDetectionOffsetNotePositionSettingsSection.swift:17`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionOffsetNotePositionSettingsSection.swift#L17)

- Training screen: the dot indicator's `testedNoteIndex` reads through the same path.
  [`TimingOffsetDetectionScreen.swift:22`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionScreen.swift#L22)

**Tests**

- Pattern: audible→grid, pickable, clamp, `beat(...)` per pickable position, plus the id-only equality pin.
  [`TimingOffsetDetectionPatternTests.swift:1`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionPatternTests.swift#L1)

- Catalog: registration, throwing lookup, `forStoredId:` known/unknown, and the catalog-wide invariants (no `1` in `pickable`, default is pickable, ids are unique).
  [`TimingOffsetDetectionPatternCatalogTests.swift:1`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionPatternCatalogTests.swift#L1)

- Port: `selectedPattern` + pattern-aware `offsetNotePosition` clamp; the metric-anchor reset for stored `1` is here.
  [`AppTimingOffsetDetectionUserSettingsTests.swift:1`](../../PeachTests/Training/TimingOffsetDetection/AppTimingOffsetDetectionUserSettingsTests.swift#L1)

- Session: `nextBeat()` end-to-end shape + `buildBeatPerPosition` migrated onto `pattern.beat(...)`.
  [`TimingOffsetDetectionSessionTests.swift:154`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionSessionTests.swift#L154)

- Settings snapshot's `from(...)` now expects `pattern == .pattern1111`.
  [`TimingOffsetDetectionSettingsTests.swift:1`](../../PeachTests/Core/Training/TimingOffsetDetectionSettingsTests.swift#L1)

**Stub & mock**

- Environment-default stub uses `TimingOffsetDetectionPatternCatalog.defaultPattern` (not the literal `.pattern1111` reference).
  [`PreviewDefaults.swift:44`](../../Peach/App/PreviewDefaults.swift#L44)

- Test mock follows the protocol's `selectedPattern` requirement.
  [`MockTimingOffsetDetectionUserSettings.swift:1`](../../PeachTests/Mocks/MockTimingOffsetDetectionUserSettings.swift#L1)

**Status & deferred work**

- Sprint key flipped in lockstep with the spec status.
  [`sprint-status.yaml:735`](./sprint-status.yaml#L735)

- Two follow-ups recorded under *From: Story 82.5* — the `TimingDotView` audible-vs-grid mismatch (resolves in 82.6) and `.nested(Beat)` handling (resolves with tuplets).
  [`deferred-work.md`](./deferred-work.md)

**Spec change log (review iteration 1 — patches only)**

- The seven findings, the amendments outside the frozen block, the defers, the KEEP list, and the known-bad states avoided.
  [`82-5-pattern-catalog-domain-layer.md`](./82-5-pattern-catalog-domain-layer.md)
