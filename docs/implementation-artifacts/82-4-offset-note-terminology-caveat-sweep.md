---
title: 'Story 82.4: Offset-note terminology caveat sweep and OffsetNotePosition value type'
type: 'refactor'
created: '2026-06-03'
status: 'done'
baseline_commit: '1b99c1c4ce27f0de2cfcea2eeb2b0b1a50746b56'
context:
  - '{project-root}/docs/planning-artifacts/tod-discipline-future-direction.md'
  - '{project-root}/docs/implementation-artifacts/epic-82-context.md'
  - '{project-root}/docs/implementation-artifacts/82-1-offset-slot-as-setting.md'
  - '{project-root}/docs/implementation-artifacts/82-2-offset-note-terminology-decision.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Story 82.2 ratified *Offset Note* / *Offset Note Position* as the final terminology — so 82.1's shipped code identifiers and German strings already match the settled term, but two doc-comment caveats in code still flag them as placeholders, and `docs/planning-artifacts/tod-discipline-future-direction.md` still carries placeholder-era *"Offset slot"* language behind explicit *"applied by 82.4"* pre-notes. Separately, the Quality reviewer's 82.1 finding (`docs/implementation-artifacts/deferred-work.md:59`) nominates 82.4's cleanup as the natural moment to introduce an `OffsetNotePosition` value type per project-context's *"Domain types everywhere"* rule — eliminating the two manual `- 1` index translations and absorbing the loose `validOffsetNotePositionRange` / `clamped(_:)` / `defaultOffsetNotePosition` constants currently scattered on `TimingOffsetDetectionSettingsKeys`.

**Approach:** Two coupled passes in one story. (1) Introduce `OffsetNotePosition` — a TOD-local `Sendable` value type wrapping a 1-based `Int`, with `rawValue`, `zeroBasedIndex`, `static let `default`` = 3, `static let validRange` = `1...4`, a `precondition`-guarded `init(_:)`, and a `init(clamping:)` factory that maps out-of-range values to `.default`. Migrate the protocol field, the settings struct, the `buildBeat` parameter, both `@AppStorage` consumer sites, the stub/mock, and the existing tests onto the new type. (2) Sweep the post-82.2 placeholder caveats: strip both *"placeholder, see 82.2"* doc comments; rewrite `tod-discipline-future-direction.md` so the *Future vision* and *Near-term step* sections read as a finished design record under the settled terminology; close the deferred-work entry. Rename the sprint-status key to match this file (`82-4-offset-note-terminology-caveat-sweep`).

## Boundaries & Constraints

**Always:**
- `OffsetNotePosition` is the canonical 1-based type. After the sweep, `Int` does not appear in the protocol field, the settings-struct field, the `buildBeat` parameter, the stub/mock, or the parameterized session test — only at the `@AppStorage` binding read site and inside the type itself.
- The `1...4` range and default `3` live on the value type. `TimingOffsetDetectionSettingsKeys` retains only the UserDefaults key string.
- Both `@AppStorage` consumer sites (settings section + training screen) read through `OffsetNotePosition(clamping:)`, preserving the audio/UI parity defence-in-depth from 82.1 review iteration 1.
- TOD remains `PEACH_RESEARCH`-gated; all new and updated tests stay under `#if PEACH_RESEARCH` where existing siblings are.
- Type lives at `Peach/Training/TimingOffsetDetection/OffsetNotePosition.swift` — TOD-local, not `Core/Music/`. 82.5's catalog work may revisit placement when patterns need variable slot counts.
- Sober factual copy in any new doc text per `[[feedback_sober_factual_copy]]`. No forward references to 82.5 inside the value type itself.
- Sprint-status key renames in lockstep with the spec filename: `82-4-apply-offset-note-terminology-rename` → `82-4-offset-note-terminology-caveat-sweep`.
- `deferred-work.md:59` (Bare-Int item) is marked closed with a reference to this story; the entry is not deleted (catalog discipline per `[[feedback_never_defer_preexisting]]`).

**Ask First:**
- If `@AppStorage` cannot cleanly bind to `OffsetNotePosition` (it stores `Int` and the type isn't `RawRepresentable` over an `@AppStorage`-supported scalar), halt and ask whether to (a) keep the `@AppStorage` Int binding and wrap at read time, or (b) add a `RawRepresentable` conformance over `Int` that `@AppStorage` accepts.
- If any TOD localized string would need editing for type-related reasons (it shouldn't — strings were settled in 82.2), halt and surface before touching `Localizable.xcstrings`.

**Never:**
- No `@AppStorage` migration shim. The UserDefaults key string is unchanged from 82.1; existing research-build values continue to round-trip. Document explicitly in Design Notes.
- No widening the type for variable pattern lengths — that is 82.5's job when `NamedPattern` lands.
- No moving the type to `Core/Music/` in this story.
- No changes to user-visible English or German strings — they were ratified in 82.2.
- No changes to `Beat` / `Subdivision` / `SoundFontStepSequencer`, `TimingDotView`'s parameter type (it stays an internal `Int` 0-based index — the boundary is at the screen call site), or the CSV/JSON record schema.
- No retirement of the design-direction doc's *Open questions* section in this story (already struck through; leaving as historical record is intentional).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Valid init | `OffsetNotePosition(1)` … `OffsetNotePosition(4)` | `rawValue == n`; `zeroBasedIndex == n - 1` | N/A |
| Invalid init (strict) | `OffsetNotePosition(0)`, `(-1)`, `(5)`, `(99)` | `precondition` trips | crash (programmer error) |
| Clamping init (valid) | `OffsetNotePosition(clamping: 2)` | equals `OffsetNotePosition(2)` | N/A |
| Clamping init (invalid) | `OffsetNotePosition(clamping: 0)`, `(99)` | equals `OffsetNotePosition.default` (i.e. `3`) | silent clamp |
| Default exposure | `OffsetNotePosition.default` | `rawValue == 3` | N/A |
| Storage round-trip | UserDefaults stores `2` → port reads via clamping init | `port.offsetNotePosition == OffsetNotePosition(2)` | N/A |
| Corrupt UserDefaults | UserDefaults stores `99` → port and both `@AppStorage` sites read via clamping init | All three return `OffsetNotePosition.default`; audio and dot indicator stay in sync | silent clamp |

</frozen-after-approval>

## Code Map

- `Peach/Training/TimingOffsetDetection/OffsetNotePosition.swift` -- **NEW**. Value type per Intent. `nonisolated struct`, `Hashable`, `Sendable`. Mirrors `MIDIVelocity`'s shape (validRange / precondition-guarded init / static named default). Adds `init(clamping: Int)` factory and computed `zeroBasedIndex: Int`. `RawRepresentable` over `Int` if `@AppStorage` binding requires it (see Ask First).
- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionSettingsKeys.swift` -- strip the placeholder doc comment; remove `defaultOffsetNotePosition`, `validOffsetNotePositionRange`, and `clamped(_:)` (absorbed into the value type). Keep the `offsetNotePosition` UserDefaults key string.
- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionUserSettings.swift` -- protocol field type changes to `OffsetNotePosition`. App impl uses `OffsetNotePosition(clamping: defaults.integer(forKey:))` when the key is present, otherwise `OffsetNotePosition.default`.
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSettings.swift` -- field, init parameter, and `from(...)` all become `OffsetNotePosition`. Drop the now-redundant precondition (the type enforces it).
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift` -- `buildBeat(for:offsetNotePosition: OffsetNotePosition)`; drop the redundant precondition; offsetIndex becomes `offsetNotePosition.zeroBasedIndex`.
- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionOffsetNotePositionSettingsSection.swift` -- strip the placeholder doc comment; `effectivePosition` becomes `OffsetNotePosition(clamping: offsetNotePosition)`; cell iteration uses `OffsetNotePosition.validRange`. Tap action still writes the raw `Int` via the `@AppStorage` binding.
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionScreen.swift` -- `testedNoteIndex: OffsetNotePosition(clamping: offsetNotePosition).zeroBasedIndex`. `TimingDotView`'s parameter stays `Int` — boundary at the call site.
- `Peach/App/PreviewDefaults.swift` -- `StubTimingOffsetDetectionUserSettings.offsetNotePosition` becomes `let offsetNotePosition: OffsetNotePosition = .default`.
- `PeachTests/Mocks/MockTimingOffsetDetectionUserSettings.swift` -- field type changes to `OffsetNotePosition` with default `.default`.
- `PeachTests/Training/TimingOffsetDetection/OffsetNotePositionTests.swift` -- **NEW**. Covers every row of the I/O matrix plus the `validRange` exposure.
- `PeachTests/Training/TimingOffsetDetection/AppTimingOffsetDetectionUserSettingsTests.swift` -- update expectations to `OffsetNotePosition.default` / `OffsetNotePosition(2)` instead of raw Ints; retain missing-key / corrupt-value coverage.
- `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionSessionTests.swift` -- parameterized test passes `OffsetNotePosition` values; index expectation uses `.zeroBasedIndex`.
- `PeachTests/Core/Training/TimingOffsetDetectionSettingsTests.swift` -- `from(...)` test expects `OffsetNotePosition`; loops over the four positions via the type.
- `docs/planning-artifacts/tod-discipline-future-direction.md` -- drop the *Implementation note* paragraph (now obsolete); strip the two *"applied by 82.4"* pre-notes; rewrite the *Future vision* bullets and *Near-term step* bullets to use *Offset Note* / *Offset Note Position* vocabulary; the *Vocabulary boundary* paragraph at the top makes the engineering-vs-user distinction explicit so the doc reads coherent end-to-end.
- `docs/implementation-artifacts/deferred-work.md` -- mark the Bare-Int item closed with a reference to this story; do not delete the entry.
- `docs/implementation-artifacts/sprint-status.yaml` -- rename the key from `82-4-apply-offset-note-terminology-rename` to `82-4-offset-note-terminology-caveat-sweep`; set status `in-progress` (flipped to `done` on commit per `[[feedback_update_status_after_review]]`).

## Tasks & Acceptance

**Execution:**
- [x] `OffsetNotePosition.swift` -- new value type matching `MIDIVelocity`/`TempoBPM` shape; `init(_:)` precondition, `init(clamping:)` factory, `zeroBasedIndex`, `static let default`, `static let validRange`
- [x] `TimingOffsetDetectionSettingsKeys.swift` -- strip placeholder comment; remove range/default/clamped; keep key string only
- [x] `TimingOffsetDetectionUserSettings.swift` -- protocol + app impl use `OffsetNotePosition`
- [x] `TimingOffsetDetectionSettings.swift` -- field + init + `from(...)` use `OffsetNotePosition`; drop redundant precondition
- [x] `TimingOffsetDetectionSession.swift` -- `buildBeat` parameter is `OffsetNotePosition`; uses `.zeroBasedIndex`
- [x] `TimingOffsetDetectionOffsetNotePositionSettingsSection.swift` -- strip placeholder comment; positions from `OffsetNotePosition.validRange`; clamping via value type
- [x] `TimingOffsetDetectionScreen.swift` -- passes `OffsetNotePosition(clamping:).zeroBasedIndex` to `TimingDotView`
- [x] `PreviewDefaults.swift` + `MockTimingOffsetDetectionUserSettings.swift` -- field type + default
- [x] `OffsetNotePositionTests.swift` -- new file, covers I/O matrix
- [x] `AppTimingOffsetDetectionUserSettingsTests.swift`, `TimingOffsetDetectionSessionTests.swift`, `TimingOffsetDetectionSettingsTests.swift` -- migrate to the value type
- [x] `TimingDotView.swift` (preview default) -- migrate `previewTestedNoteIndex` off the removed `defaultOffsetNotePosition` constant to `OffsetNotePosition.default.zeroBasedIndex` (scope discovery)
- [x] `tod-discipline-future-direction.md` -- caveat sweep + bullet rewrites per Code Map
- [x] `deferred-work.md:59` -- mark CLOSED, reference this story
- [x] `sprint-status.yaml` -- rename key, set `in-progress`
- [x] Run `bin/test.sh --research && bin/test.sh --research -p mac` and `bin/test.sh && bin/test.sh -p mac` -- all four pass; no new warnings
- [x] Run `bin/add-localization.swift --missing` -- expected: zero new gaps (no string edits in this story)

**Acceptance Criteria:**
- Given an `OffsetNotePosition` constructed via any path (strict init, clamping init, `default`), when its `zeroBasedIndex` is read, then it equals `rawValue - 1`.
- Given a corrupt UserDefaults value for the offset-note position, when the training screen renders and a TOD trial runs, then the dot indicator's tested-note position and the audio engine's offset placement agree on `OffsetNotePosition.default` (no UI/audio divergence — same behavior as 82.1).
- Given `grep -rn "placeholder" Peach/Training/TimingOffsetDetection PeachTests/Training/TimingOffsetDetection`, when run after this story, then it returns no doc-comment lines referencing the 82.2/82.4 caveats.
- Given `grep -n "applied by 82.4\|placeholder" docs/planning-artifacts/tod-discipline-future-direction.md`, when run after this story, then it returns no matches.
- Given `deferred-work.md`, when read after this story, then the Bare-Int item has a CLOSED disposition referencing this story (entry retained).
- Both pre-commit gates pass on both schemes and both platforms.

## Design Notes

**Type placement (TOD-local, not `Core/Music/`):** `OffsetNotePosition` encodes a discipline-specific concept — *the 1-based position of the offset-carrying note in the current TOD pattern* — and currently bakes in the four-note assumption. `Core/Music/` types (`MIDINote`, `Cents`, `TempoBPM`) carry no discipline coupling. Keeping the type next to its consumers also defers a placement debate to 82.5, when `NamedPattern` may legitimately need a generalized position type with per-pattern slot counts.

**Why both a precondition-guarded `init(_:)` and a clamping factory:** Two distinct callers. Test fixtures and code that has already validated the value want the strict `init(_:)` (programmer error if violated, matching `MIDIVelocity` / `TempoBPM`). The two `@AppStorage` read sites and the port accessor want clamping (defence-in-depth against corrupt storage, established in 82.1 review iteration 1). Mirrors the *clamped helper for @AppStorage consumers* note in the 82.1 spec.

**Why the `TimingDotView` parameter stays `Int`:** The view receives a 0-based index for direct array iteration. The translation `OffsetNotePosition → zeroBasedIndex` happens at the screen call site — the same boundary the 82.1 spec called out (translation at well-defined consumer edges). Pushing the value type into the dot view would couple a generic visual primitive to a TOD-specific domain type without payoff.

**Why no `@AppStorage` migration shim:** The UserDefaults key string (`"timingOffsetDetectionOffsetNotePosition"`) is unchanged. The stored value remains a 1-based `Int`. The value type wraps but does not transform stored representation. Any 82.1-shipped research-build value round-trips unchanged.

**`@AppStorage` binding shape:** The `@AppStorage` binding stays `Int` because that is the storage representation. Consumers wrap on read via `OffsetNotePosition(clamping:)`. Writes from the settings section continue to write the raw `Int` produced by tapping a cell. The value type is the *semantic* boundary, not the *storage* boundary. (If at implementation time `RawRepresentable` over `Int` lets `@AppStorage` bind directly and reads cleaner, that is acceptable — but it is not the contract.)

**Caveat-sweep rewrite tone:** The replacement prose in `tod-discipline-future-direction.md` should read as if 82.2 had been settled from the start — no "now that the term is decided", no historical narration. The *Vocabulary boundary* paragraph (`Slot` is engineering, `Note` is user-facing) is the only meta-commentary that stays. The struck-through *Open questions* section is left in place as deliberate historical record.

## Verification

**Commands:**
- `bin/test.sh --research` -- expected: full suite green on iOS (Debug, Research)
- `bin/test.sh --research -p mac` -- expected: full suite green on macOS (Debug, Research)
- `bin/test.sh` -- expected: full suite green on iOS (Debug, non-research) — confirms no regressions in the pitch-only build
- `bin/test.sh -p mac` -- expected: full suite green on macOS (Debug, non-research)
- `bin/build.sh --research` -- expected: zero new warnings
- `bin/add-localization.swift --missing` -- expected: `0 keys missing German translation`
- `grep -rn "placeholder" Peach/Training/TimingOffsetDetection PeachTests/Training/TimingOffsetDetection` -- expected: zero matches referencing the 82.2/82.4 caveats
- `grep -n "applied by 82.4" docs/planning-artifacts/tod-discipline-future-direction.md` -- expected: zero matches

**Manual checks:**
- Launch `Peach (Debug, Research)`. The Settings TOD section still shows four note-position cells with default selection on Note 3; tapping a different position and restarting the app shows the new position persisted (round-trip through the renamed type works).
- Force a corrupt value via `defaults write` (e.g. `defaults write de.schuerig.peach.research timingOffsetDetectionOffsetNotePosition -int 99`), relaunch, observe both the dot indicator and the audible offset land on Note 3 — proving the clamping factory holds both consumer sites in agreement.

## Suggested Review Order

**Value type (entry point)**

- Single source of truth: valid range, default, strict and clamping inits, `zeroBasedIndex` accessor.
  [`OffsetNotePosition.swift:16`](../../Peach/Training/TimingOffsetDetection/OffsetNotePosition.swift#L16)

**Settings model — storage, port, snapshot**

- Keys file shrinks back to just the UserDefaults key string; range/default/clamping live on the value type now.
  [`TimingOffsetDetectionSettingsKeys.swift:10`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionSettingsKeys.swift#L10)

- Port returns the typed value, clamping corrupt storage via the value type's factory (preserves 82.1 review-iteration-1 defence-in-depth).
  [`TimingOffsetDetectionUserSettings.swift:26`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionUserSettings.swift#L26)

- Session-time snapshot field is `OffsetNotePosition`; the value type enforces its own invariant so the struct's precondition for this field is gone.
  [`TimingOffsetDetectionSettings.swift:9`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSettings.swift#L9)

**Audio engine threading**

- `buildBeat` now takes `OffsetNotePosition` and uses `.zeroBasedIndex` — no more manual `- 1`, no more reach into the keys file for the range.
  [`TimingOffsetDetectionSession.swift:231`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift#L231)

**UI surface**

- Settings section: positions derive from `OffsetNotePosition.validRange`; `effectivePosition` clamps the raw `@AppStorage` Int via the value type; cell still writes back the raw Int (storage shape unchanged).
  [`TimingOffsetDetectionOffsetNotePositionSettingsSection.swift:11`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionOffsetNotePositionSettingsSection.swift#L11)

- Training screen passes the value type's `zeroBasedIndex` to `TimingDotView` — translation now lives behind the type, not at the call site.
  [`TimingOffsetDetectionScreen.swift:24`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionScreen.swift#L24)

- Dot view preview default migrated off the removed `defaultOffsetNotePosition` constant.
  [`TimingDotView.swift:56`](../../Peach/Training/TimingOffsetDetection/TimingDotView.swift#L56)

**Stub & mock**

- Environment-default stub uses `OffsetNotePosition.default`.
  [`PreviewDefaults.swift:46`](../../Peach/App/PreviewDefaults.swift#L46)

- Test mock field type follows the protocol.
  [`MockTimingOffsetDetectionUserSettings.swift:6`](../../PeachTests/Mocks/MockTimingOffsetDetectionUserSettings.swift#L6)

**Tests**

- New value-type suite — strict init, clamping init, `zeroBasedIndex`, default, `validRange`, equality.
  [`OffsetNotePositionTests.swift:6`](../../PeachTests/Training/TimingOffsetDetection/OffsetNotePositionTests.swift#L6)

- Port tests now expect `OffsetNotePosition.default` and `OffsetNotePosition(stored)` instead of raw Ints; missing-key / corrupt-value / valid-value coverage retained.
  [`AppTimingOffsetDetectionUserSettingsTests.swift:46`](../../../PeachTests/Training/TimingOffsetDetection/AppTimingOffsetDetectionUserSettingsTests.swift#L46)

- `buildBeat` per-position parameterized test threads the value type through and asserts on `.zeroBasedIndex`.
  [`TimingOffsetDetectionSessionTests.swift:186`](../../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionSessionTests.swift#L186)

- Settings-snapshot tests use `.default` / `OffsetNotePosition(positionValue)` for parameterized cases.
  [`TimingOffsetDetectionSettingsTests.swift:55`](../../../PeachTests/Core/Training/TimingOffsetDetectionSettingsTests.swift#L55)

**Doc & status cleanup (Boy Scout sweep)**

- Design-direction doc now reads as a finished record: Implementation note removed, "applied by 82.4" pre-notes stripped, *Offset slot* / "slot carries the offset" rewritten to *Offset Note Position* / "which note carries the offset"; *Vocabulary boundary* kept as the engineering-vs-user distinction.
  [`tod-discipline-future-direction.md:8`](../planning-artifacts/tod-discipline-future-direction.md#L8)

- Deferred-work Bare-Int item marked CLOSED with reference to this story; entry retained for catalog discipline.
  [`deferred-work.md:59`](./deferred-work.md#L59)

- Sprint-status key renamed in lockstep with the spec filename and flipped to `done`.
  [`sprint-status.yaml:734`](./sprint-status.yaml#L734)
