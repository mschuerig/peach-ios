---
title: 'Story 82.1: Offset slot as a setting on the current pattern'
type: 'feature'
created: '2026-06-03'
status: 'done'
baseline_commit: 'e8d97a3e031dca709edf0c0d8d8225b5b5800591'
context:
  - '{project-root}/docs/planning-artifacts/tod-discipline-future-direction.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** TOD hard-codes the timing offset onto the third of four 16th notes per beat (`TimingOffsetDetectionSession.testedNoteIndex = 2`). The fixed position is artificial constraint disguised as discipline — there is no defensible reason to keep one note privileged, and it blocks the broader pattern-flexibility direction set in `docs/planning-artifacts/tod-discipline-future-direction.md`.

**Approach:** Make the offset-carrying note a `UserDefaults`-backed setting (`offsetNotePosition`, 1-based index in `1...4`). Default to `3` so existing research-build sessions behave identically. Surface it on the Settings screen via a new TOD section — a horizontal four-cell single-select grid that visually mirrors `RhythmGapPositionsSettingsSection`'s chrome — and thread it through to `TimingOffsetDetectionSession.buildBeat` so the chosen note carries the offset. Use placeholder terminology ("Offset Note Position") per Adam's consultation of 2026-06-03; story 82.2 settles the proper term and 82.4 applies the rename.

## Boundaries & Constraints

**Always:**
- Default value preserves current behavior — position `3` (the third 16th note).
- TOD remains `PEACH_RESEARCH`-gated. New tests are wrapped in `#if PEACH_RESEARCH`.
- Setting key, accessor, field name, and UI label all use the placeholder term `offsetNotePosition` / "Offset Note Position." Single rename target in 82.4.
- Storage type is `Int`, **1-based**, valid range `1...subdivisionsPerBeat`. Out-of-range values from `UserDefaults` clamp to the default — same defence-in-depth pattern as `AppTimingOffsetDetectionUserSettings.maxRepetitions`. The 1-based-to-0-based translation lives in exactly one place: `buildBeat`'s array index expression.
- Accessibility: each cell exposes selection state and label to VoiceOver — Button with `.accessibilityLabel("Note N of 4")` (N matches the stored position) and `.accessibilityAddTraits([.isSelected])` on the active cell. Matches and lightly extends the established `GridToggleRow` pattern (which uses plain Buttons with default accessibility).
- German translation via `bin/add-localization.swift` for every new user-visible string; informal `du`/imperative.

**Ask First:**
- If the cell appearance can't visually match `RhythmGapPositionsSettingsSection`'s cells (font, sizing, rounded corners, accent color) without copying the implementation, halt and ask whether to extract a shared single-select primitive or accept divergence.

**Never:**
- No widget abstraction across CRM gap-positions and TOD note-position — both are one-off until 82.6 evolves the picker. No premature `SingleSelectGridRow` extraction.
- No rest-aware visual states yet. All four positions are notes and pickable; rest-handling is 82.6.
- No `@AppStorage` migration shim — the placeholder key is brand-new in 82.1.
- No changes to `Beat` / `Subdivision` / `SoundFontStepSequencer`. Engine is correct as-is.
- No CSV schema changes. The note position is configuration, not per-trial record metadata.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Default note position | `UserDefaults` has no `timingOffsetDetectionOffsetNotePosition` key | Accessor returns `3`; `buildBeat` applies offset to subdivision index 2 (third note) | N/A |
| User picks position 1 | Setting = `1`; trial active | `buildBeat` returns beat with offset on subdivision 0, zero on 1/2/3 | N/A |
| User picks position 4 | Setting = `4`; trial active | `buildBeat` returns beat with offset on subdivision 3, zero on 0/1/2 | N/A |
| Corrupt UserDefaults value | Stored value `0`, `-1`, `5`, `99` | Accessor clamps to default `3` | Silent clamp, no crash |
| Persistence round-trip | Tap "Note N" in UI → re-read settings | `@AppStorage` write becomes `Int` in defaults; `AppTimingOffsetDetectionUserSettings.offsetNotePosition` returns N | N/A |

</frozen-after-approval>

## Code Map

- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionSettingsKeys.swift` — add `offsetNotePosition` key, `defaultOffsetNotePosition = 3`.
- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionUserSettings.swift` — add `var offsetNotePosition: Int { get }` to protocol; implement on `AppTimingOffsetDetectionUserSettings` with clamp-to-default semantics (valid range `1...4`).
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSettings.swift` — add `offsetNotePosition: Int` field, precondition `(1...TimingOffsetDetectionSession.subdivisionsPerBeat).contains(offsetNotePosition)`, default `TimingOffsetDetectionSettingsKeys.defaultOffsetNotePosition`. Update `from(_:todUserSettings:)`.
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift` — delete `static let testedNoteIndex = 2`. Change `buildBeat(for:)` to `buildBeat(for:offsetNotePosition:)`; the array-index expression becomes `(index == offsetNotePosition - 1)`. Update `nextBeat()` to pass `settings.offsetNotePosition`.
- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionOffsetNotePositionSettingsSection.swift` — **NEW**. Section with `@AppStorage` binding, inline `HStack` of four `Button` cells mirroring `GridToggleRow` chrome (cell size via `@ScaledMetric(relativeTo: .caption2)`, `Color.accentColor` background when selected, `.platformHoverEffect()`).
- `Peach/Training/TimingOffsetDetection/Discipline/TimingOffsetDetectionDiscipline.swift` — register the new section under id `"tod.offsetNotePosition"` in `settingsSections`; append a new `offsetNotePositionSettingsHelp` block to `settingsHelp`.
- `Peach/Training/TimingOffsetDetection/Help/TimingOffsetDetectionHelp.swift` — replace "the **third** click" wording in `trainingScreen.Goal`; add `offsetNotePositionSettingsHelp` block.
- `Peach/App/PreviewDefaults.swift` — extend `StubTimingOffsetDetectionUserSettings` with `let offsetNotePosition = TimingOffsetDetectionSettingsKeys.defaultOffsetNotePosition`.
- `PeachTests/Mocks/MockTimingOffsetDetectionUserSettings.swift` — extend with `var offsetNotePosition: Int = TimingOffsetDetectionSettingsKeys.defaultOffsetNotePosition`.
- `PeachTests/Training/TimingOffsetDetection/AppTimingOffsetDetectionUserSettingsTests.swift` — extend with `offsetNotePosition` tests.
- `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionSessionTests.swift` — replace single "offset on third" assertion with parameterized coverage across positions 1...4.
- `PeachTests/Core/Training/TimingOffsetDetectionSettingsTests.swift` — extend `from(...)` tests to cover `offsetNotePosition`.
- `Peach/Localization/Localizable.xcstrings` — German translations added via `bin/add-localization.swift`.

**Added during implementation (scope discovery):**
- `Peach/Training/TimingOffsetDetection/TimingDotView.swift` — the training-screen dot indicator referenced the deleted `testedNoteIndex` constant. Replaced with a `let testedNoteIndex: Int` parameter; `isTestedNote(index:testedNoteIndex:)` became a two-arg static. Previews pass `defaultOffsetNotePosition - 1`.
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionScreen.swift` — reads `@AppStorage(offsetNotePosition)` and passes `position - 1` into `TimingDotView`.
- `PeachTests/Training/TimingOffsetDetection/TimingDotViewTests.swift` — `isTestedNote` test parameterized over all four positions; the static-equality test against the deleted constant was removed.
- `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionSessionTests.swift` — `testedNoteIndexConsistentWithHelpText` deleted (the help text no longer encodes an ordinal).
- `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionDisciplineTests.swift` — section-aggregation and help-aggregation tests extended to include the new section.

## Tasks & Acceptance

**Execution:**
- [x] `TimingOffsetDetectionSettingsKeys.swift` -- add `offsetNotePosition` key + `defaultOffsetNotePosition = 3` -- single source of truth for default
- [x] `TimingOffsetDetectionUserSettings.swift` -- add `offsetNotePosition: Int` to protocol + clamping implementation -- mirrors `maxRepetitions` defence-in-depth pattern
- [x] `TimingOffsetDetectionSettings.swift` -- add `offsetNotePosition` field with `1...4` precondition; update `from(...)` -- value-type snapshot at session start
- [x] `TimingOffsetDetectionSession.swift` -- remove `testedNoteIndex`; `buildBeat(for:offsetNotePosition:)` does the `position - 1` translation; `nextBeat()` reads `settings.offsetNotePosition` -- per-trial offset placement driven by user choice
- [x] `TimingOffsetDetectionOffsetNotePositionSettingsSection.swift` -- new SwiftUI section with four single-select cells -- the UI surface
- [x] `TimingOffsetDetectionDiscipline.swift` -- register section + extend `settingsHelp` -- discipline-owned aggregation
- [x] `TimingOffsetDetectionHelp.swift` -- generic "Goal" wording + new `offsetNotePositionSettingsHelp` -- training-screen text no longer pins to the third note
- [x] `PreviewDefaults.swift` + `MockTimingOffsetDetectionUserSettings.swift` -- add `offsetNotePosition` -- compile parity for existing call sites
- [x] `AppTimingOffsetDetectionUserSettingsTests.swift` -- missing-key / out-of-range / valid-value tests -- mirrors maxRepetitions suite
- [x] `TimingOffsetDetectionSessionTests.swift` -- parameterized `buildBeat` per-position test (positions 1...4); existing "offset on third" test becomes the position-3 case -- covers I/O matrix
- [x] `TimingOffsetDetectionSettingsTests.swift` -- `from(...)` reads `offsetNotePosition` from port -- factory wiring
- [x] German strings via `bin/add-localization.swift` for: "Offset Note Position", footer copy, training-screen "Goal" replacement, "Note N of 4" accessibility format, help-section title and body -- localization parity
- [x] Run `bin/test.sh --research && bin/test.sh --research -p mac` and `bin/test.sh && bin/test.sh -p mac` -- both schemes must pass

**Acceptance Criteria:**
- Given default `UserDefaults`, when a TOD session starts, then `buildBeat` applies the offset to subdivision index 2 (the third note) — behavioural parity with current `main`.
- Given the user taps "Note N" (N in 1...4) in the Settings UI, when a new trial begins, then `nextBeat()` returns a beat whose subdivision at index `N - 1` carries `trial.offset.duration` and whose other subdivisions carry `.zero`.
- Given `UserDefaults` contains an out-of-range value (`0`, `-1`, `5`, `99`), when the accessor is read, then it returns `defaultOffsetNotePosition` — no crash, no `precondition` trip.
- Given the Settings UI is visible, when a note position is selected, then the active cell renders with accent-color background and the previously selected cell loses it; VoiceOver announces "Note N of 4" for each cell.
- Given the help sheet on the TOD training screen is opened, then the Goal section text does not contain the word "third."
- Both pre-commit gates pass: `bin/test.sh && bin/test.sh -p mac` (Debug) and `bin/test.sh --research && bin/test.sh --research -p mac` (Research). No new compiler warnings.

## Spec Change Log

### 2026-06-03 — Review iteration 1

**Triggering findings (deduped from three reviewers — blind / edge-case / acceptance):**

- **A. `@AppStorage` reads bypass the port's clamp** (blind H#5, edge-case H#1, H#2). On corrupt storage (`0`, `-1`, `99`), the screen's dot indicator and the picker disagreed with the audio engine: audio used the default 3, picker showed no highlighted cell, indicator showed no doubled glyph.
- **C. Multiple translation sites** (blind M#4, acceptance ❌). Design Notes promised "single translation point in `buildBeat`," but `TimingOffsetDetectionScreen` and `TimingDotView` previews each translated 1→0 independently.
- **D. Settings layer depended on `TimingOffsetDetectionSession.subdivisionsPerBeat`** (blind H#3). Inverted dependency.
- **E. Orphan xcstrings entries** (acceptance ⚠️). The old "four-click" English and German strings remained in `Localizable.xcstrings` after the source was reworded.
- **F. `buildBeat` lacked its own precondition** (edge-case M#3). The struct preconditioned; the static helper trusted callers. Asymmetric design-by-contract.
- **B. Accessibility spec wording mismatch** (acceptance ❌). The frozen Always clause said "each cell vends as an adjustable element"; the implementation uses Button + `.isSelected` (mirroring `GridToggleRow`'s pattern and lightly extending it with explicit labels). Resolved by human (Michael, 2026-06-03): keep code, revise wording — the wholesale-rework in 82.6 makes a bigger refactor wasteful.

**Amendments (bad_spec-style: outside frozen, except B which Michael authorised):**

- Added `TimingOffsetDetectionSettingsKeys.validOffsetNotePositionRange` (`1...4`) and `clamped(_:)`. The keys file now owns its own validation range; the session's `subdivisionsPerBeat` stays an audio-engine concern.
- `AppTimingOffsetDetectionUserSettings.offsetNotePosition` and `TimingOffsetDetectionSettings.init` precondition both route through the new range / helper. No more reach into `TimingOffsetDetectionSession`.
- `TimingOffsetDetectionOffsetNotePositionSettingsSection` and `TimingOffsetDetectionScreen` both apply `clamped(_:)` to the `@AppStorage` value before use, eliminating UI/audio divergence on corrupt storage.
- `TimingOffsetDetectionSession.buildBeat(for:offsetNotePosition:)` now preconditions its parameter against `validOffsetNotePositionRange`.
- Removed the two orphan English keys (and their German translations) from `Localizable.xcstrings`.
- Frozen Always wording for accessibility softened from "adjustable element" to "exposes selection state and label to VoiceOver — Button + `.accessibilityLabel` + `.accessibilityAddTraits([.isSelected])`." This matches the implementation and the established `GridToggleRow` pattern.
- Design Notes "1-based throughout" claim re-expressed honestly: translation happens at two well-defined consumer boundaries (audio engine via `buildBeat`, visual indicator via the screen→TimingDotView edge), centralised via `TimingOffsetDetectionSettingsKeys.clamped(_:)`.

**Known-bad states avoided:** UI showing one tested-note position while audio plays a different one; the picker showing no selection at all on corrupt storage; settings layer depending on session internals; stale "third click" German string still appearing in any not-yet-recompiled localisation context.

**KEEP (re-derivation must preserve):**

- 1-based stored values; default 3.
- `validOffsetNotePositionRange` and `clamped(_:)` live on `TimingOffsetDetectionSettingsKeys`.
- Section visual chrome matches `GridToggleRow` (cellSize via `@ScaledMetric(relativeTo: .caption2)`, `Color.accentColor` for active, `.platformHoverEffect()`, `RoundedRectangle(cornerRadius: 6)`).
- Section accessibility: Button + `.accessibilityLabel("Note N of 4")` + `.accessibilityAddTraits([.isSelected])` when active.
- `buildBeat` stays static and pure for direct parameterized testing.
- No widget abstraction extracted across CRM and TOD pickers; 82.6 will rework the picker for rest-aware N-position patterns.

## Design Notes

**Terminology (placeholder, see 82.2):** Adam was consulted 2026-06-03. "Slot," "pulse," and "step" all fail when patterns later combine 8ths, 16ths, triplets, and rests — they each smuggle in a uniform-spacing assumption. The honest term for the user-facing pickable element is just **note**. So this story uses "Offset Note Position" everywhere user-visible and `offsetNotePosition` everywhere code-visible. 82.2 still has the final say.

**1-based throughout:** The stored `Int` is 1-based (range `1...4`, default `3`). Translation to a 0-based array index happens at two well-defined consumer boundaries — `buildBeat` for the audio engine, and `TimingOffsetDetectionScreen` for the `TimingDotView` parameter. Each consumer's own contract dictates the translation; centralising into a helper would be indirection without saving lines. UI, JSON, tests, accessibility labels, and footer text are all 1-based. Naming convention enforces the distinction: `Position` ⇒ 1-based; `Index` would be 0-based.

**Clamping helper for `@AppStorage` consumers:** Views that read the setting via `@AppStorage` get the raw stored `Int` — not the clamped value `AppTimingOffsetDetectionUserSettings` returns. To prevent the audio engine and the visual indicator from diverging when storage is corrupt (e.g., a stray `0` or `99`), `TimingOffsetDetectionSettingsKeys.clamped(_:)` is the canonical clamp, applied at both `@AppStorage` view sites and used by the port. `validOffsetNotePositionRange` lives on the keys file (`1...4`) rather than being derived from `TimingOffsetDetectionSession.subdivisionsPerBeat` — the settings layer should not reach into session internals.

**Why inline the four-cell UI instead of reusing `GridToggleRow`:** `GridToggleRow<Element: CaseIterable>` is multi-select with last-remaining-disable semantics. TOD needs single-select. Adapting `GridToggleRow` to do both would introduce an abstraction for two callers, and 82.6 reworks the picker anyway (rest-aware, N-position, pattern-reset). YAGNI applies — keep the UI inline now; let 82.6 extract if needed.

**Threading `offsetNotePosition` into `buildBeat`:** Pass as an explicit parameter rather than reading `self.settings` inside the static method. Preserves `buildBeat`'s purity so the parameterized per-position test can call it directly without instantiating a session.

**Default constant location:** `TimingOffsetDetectionSettingsKeys.defaultOffsetNotePosition = 3` (not `TimingOffsetDetectionSession.testedNoteIndex`). The latter conflated "the position today's hard-coded behavior uses" with "the type-level constant for subdivision indexing"; removing it eliminates that confusion and centralises defaults beside their key.

**Help text:** Current Goal text — "The **third** click in each cycle may arrive slightly **early** or **late**" — becomes "One of the four notes in each cycle may arrive slightly **early** or **late** — choose which one in Settings." Stays informational; no position name in the body.

**Section header / footer copy (English, placeholder):**
- Header: `"Offset Note Position"`
- Footer: `"Pick which of the four 16th notes carries the timing offset."`
- Settings help title: `"Offset Note Position"`
- Settings help body: `"**Offset Note Position** chooses which of the four 16th notes in the pattern arrives slightly early or late on each trial. The other three notes stay exactly on the beat."`

## Verification

**Commands:**
- `bin/test.sh --research` -- expected: full suite green on iOS (Debug, Research)
- `bin/test.sh --research -p mac` -- expected: full suite green on macOS (Debug, Research)
- `bin/test.sh` -- expected: full suite green on iOS (Debug, non-research) — confirms no regressions in pitch-only build
- `bin/test.sh -p mac` -- expected: full suite green on macOS (Debug, non-research)
- `bin/build.sh --research` -- expected: zero warnings introduced
- `bin/add-localization.swift --missing` -- expected: no new missing entries after localization task completes

**Manual checks:**
- Launch `Peach (Debug, Research)` scheme. In Settings, the new "Offset Note Position" section appears between the Rhythm tempo section and the Maximum Repetitions section. Default selection is "Note 3" (the third 16th). Selecting another position, restarting the app, and re-opening Settings shows the same selection persisted. Starting a TOD trial after picking "Note 1" makes the first 16th note of each beat audibly early or late (depending on the trial).
- VoiceOver: each note-position cell announces "Note N of 4." Tapping changes the selection without losing focus.

## Suggested Review Order

**Settings model (storage, validation, clamping)**

- Start here — the new setting's identity, default, valid range, and the canonical clamp used by every `@AppStorage` consumer.
  [`TimingOffsetDetectionSettingsKeys.swift:10`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionSettingsKeys.swift#L10)

- Port accessor clamps stored values; pattern mirrors `maxRepetitions` and now routes through the shared helper.
  [`TimingOffsetDetectionUserSettings.swift:26`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionUserSettings.swift#L26)

- Value-type snapshot carries the position through to the session; precondition enforces the invariant.
  [`TimingOffsetDetectionSettings.swift:9`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSettings.swift#L9)

**Audio engine threading**

- The hard-coded `testedNoteIndex = 2` constant is gone; `buildBeat` now takes the position as a parameter with its own precondition.
  [`TimingOffsetDetectionSession.swift:231`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift#L231)

- `nextBeat()` reads `settings.offsetNotePosition` and threads it into the pure builder.
  [`TimingOffsetDetectionSession.swift:226`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift#L226)

**UI surface**

- New Settings section — four-cell single-select grid mirroring `GridToggleRow`'s visual chrome; clamped read for the active-cell highlight.
  [`TimingOffsetDetectionOffsetNotePositionSettingsSection.swift:7`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionOffsetNotePositionSettingsSection.swift#L7)

- Training screen reads the position from `@AppStorage` (clamped) and passes it into `TimingDotView`.
  [`TimingOffsetDetectionScreen.swift:9`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionScreen.swift#L9)

- `TimingDotView` now takes the tested index as a parameter instead of reading a session constant.
  [`TimingDotView.swift:3`](../../Peach/Training/TimingOffsetDetection/TimingDotView.swift#L3)

**Discipline wiring & help**

- New section registered in the discipline's `settingsSections`; help concatenation extended.
  [`TimingOffsetDetectionDiscipline.swift:50`](../../Peach/Training/TimingOffsetDetection/Discipline/TimingOffsetDetectionDiscipline.swift#L50)

- Training-screen Goal text reframed (no more "third click"); new help block for the picker.
  [`TimingOffsetDetectionHelp.swift:7`](../../Peach/Training/TimingOffsetDetection/Help/TimingOffsetDetectionHelp.swift#L7)

**Tests**

- Parameterized per-position `buildBeat` test; default-flow test renamed to track the configured default.
  [`TimingOffsetDetectionSessionTests.swift:156`](../../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionSessionTests.swift#L156)

- Port accessor tests cover the missing-key / out-of-range / valid-value matrix.
  [`AppTimingOffsetDetectionUserSettingsTests.swift:46`](../../../PeachTests/Training/TimingOffsetDetection/AppTimingOffsetDetectionUserSettingsTests.swift#L46)

- Discipline section-ordering and help-aggregation expectations updated for the new section.
  [`TimingOffsetDetectionDisciplineTests.swift:9`](../../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionDisciplineTests.swift#L9)

- Factory wiring test gains `offsetNotePosition` parameterized coverage.
  [`TimingOffsetDetectionSettingsTests.swift:55`](../../../PeachTests/Core/Training/TimingOffsetDetectionSettingsTests.swift#L55)

**Localization & status**

- Six new German strings; two orphan "four-click" entries removed.
  [`Localizable.xcstrings`](../../Peach/Resources/Localizable.xcstrings)

- Sprint status flipped to in-progress on epic 82 + story 82.1 (will move to done on commit).
  [`sprint-status.yaml:730`](sprint-status.yaml#L730)
