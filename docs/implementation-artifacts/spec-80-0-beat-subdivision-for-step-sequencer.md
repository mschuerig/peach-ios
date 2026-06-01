---
title: 'Story 80.0: Beat/Subdivision abstraction for step sequencer'
type: 'refactor'
created: '2026-06-01'
status: 'done'
baseline_commit: '62ea94c9'
context:
  - '{project-root}/docs/implementation-artifacts/epic-80-context.md'
  - '{project-root}/docs/project-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `SoundFontStepSequencer` hardcodes "a cycle is four equal steps" — `CycleDefinition { gapPosition: StepPosition }` and `StepPosition.first…fourth` are baked into the port, scheduling, and observation surface. This blocks Timing Offset Detection (80.1, needs per-subdivision sample offsets) and prevents any future rhythm discipline using triplets, dotted figures, or nested tuplets. The music-domain reading: the outer unit is a **beat** (the pulse), the inner units are **subdivisions**, and subdivisions may themselves be nested beats (tuplets) recursively.

**Approach:** Replace the cycle/step abstraction with a `Beat`/`Subdivision` tree at the sequencer layer. `Beat` holds an ordered, equal-spaced list of subdivisions. Each `Subdivision` is `.rest`, `.note(velocity, offset)`, or `.nested(Beat)` — the third case is the tuplet. `BeatProvider.nextBeat() -> Beat` replaces `StepProvider.nextCycle()`. `SoundFontStepSequencer` walks the beat recursively to emit scheduled events; its port no longer mentions `StepPosition` or `CycleDefinition`. ContinuousRhythmMatching migrates its sequencer-facing plumbing to build a 4-subdivision flat `Beat`, but keeps `StepPosition` and `GapPositionEncoding` as discipline-internal helpers — its UI, settings, statistics, audio, and dot view are behaviourally unchanged. Timing Offset Detection is untouched (its migration is 80.1).

## Boundaries & Constraints

**Always:**
- ContinuousRhythmMatching is byte-for-byte identical at runtime: same MIDI events, same statistics, same UI, same persisted formats. (Renames change *names*, not behaviour.)
- The sequencer port and `BeatProvider` protocol expose no discipline-specific types — only `Beat`, `Subdivision`, sample positions, and tempo.
- `Beat`/`Subdivision` are `Sendable` value types; `Beat.events(...)` is a pure function.
- The recursive `.nested(Beat)` path is exercised by unit tests, even though no production discipline uses nesting yet.
- The sequencer's refill loop, `cyclesPerBatch`, polling cadence, host-time conversion, and stop semantics are unchanged.
- "Step" terminology is dropped throughout per the **Renames** section. The engine protocol shape and `SoundFontEngine`'s scheduling primitives are unchanged — only the protocol's *name* changes.

**Ask First:**
- Whether `samplesPerStep` is dropped from `SequencerTiming` (default — yes; consumers compute `samplesPerBeat / N` locally) or kept as a flat-beat convenience.
- Whether `StepVelocity` constants stay shared in `SequencerTypes.swift` (default) or move into the consuming discipline.

**Never:**
- Do not touch `RhythmPlayer`, `RhythmPattern`, `SoundFontPlayer` rhythm code, or `TimingOffsetDetection` types (those are 80.1).
- Do not change `SoundFontEngine` or the engine protocol's shape (methods/signatures); the protocol may be *renamed* per the Renames section, but its surface stays identical.
- Do not introduce nested tuplets in any production discipline yet — `.nested(Beat)` exists for future-proofing and is exercised only by tests.

</frozen-after-approval>

## Renames

"Step" is dropped throughout. Apply mechanically (rename refactor / find-replace), including filename changes for renamed types. Test filenames mirror class renames.

| Old | New |
|-----|-----|
| `StepSequencer` (port) | `BeatSequencer` |
| `SoundFontStepSequencer` | `SoundFontBeatSequencer` |
| `StepSequencerEngine` | `SequencerEngine` |
| `StubStepSequencer` | `StubBeatSequencer` |
| `MockStepSequencer` | `MockBeatSequencer` |
| `MockStepSequencerEngine` | `MockSequencerEngine` |
| `StepProvider` | `BeatProvider` (`nextCycle` → `nextBeat`) |
| `StepVelocity` | `RhythmVelocity` |
| `StepPosition` (CRM enum) | `BeatPosition` |
| `samplesPerStep` (`SequencerTiming`) | dropped — consumers use `samplesPerBeat / 4` |
| `currentStep` (port) | dropped |
| `currentStep` (CRM session) | `currentBeatPosition: BeatPosition?` |
| `for step in …` locals | `for position in …` per context |

`StepPosition` → `BeatPosition` ("position within a beat") avoids namespace clash with the `Subdivision` enum. `currentGapPosition` (CRM session) is unchanged in this spec — meaning is still "which BeatPosition is the gap."

## Code Map

Files that need behavioural / structural changes beyond the mechanical Renames cascade:

- `Peach/Core/Audio/SequencerTypes.swift` -- add `Beat`, `Subdivision`, `BeatProvider`; `Beat.events(...)` (here or sibling file); remove `CycleDefinition` and the old `StepProvider`; rename per Renames.
- `Peach/Core/Audio/SoundFontBeatSequencer.swift` -- `currentBeat: Beat?`, `Batch.definitions: [Beat]`, `buildBatch` delegates to `beat.events(...)`; `SequencerTiming` drops `samplesPerStep` and renames `samplesPerCycle` → `samplesPerBeat`.
- `Peach/Core/Ports/BeatSequencer.swift` -- `currentBeat: Beat?`; `start(tempo:beatProvider:)`; drop `currentStep`.
- `Peach/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift` -- conform to `BeatProvider`; `nextBeat()` builds flat 4-subdivision `Beat`; `handleTap`/`evaluatePlaybackPosition` use `samplesPerBeat / 4` locally.
- `PeachTests/Core/Audio/BeatTests.swift` (new) -- direct unit tests for `Beat.events(...)`, including `.nested`.

Files that need only the mechanical Renames cascade (no behavioural change): `PeachApp.swift`, `EnvironmentKeys.swift`, `PreviewDefaults.swift`, ContinuousRhythmMatching settings/view/screen/completed-trial, `MockBeatSequencer.swift`, `MockSequencerEngine.swift`, `SoundFontBeatSequencerTests.swift`, `BeatSequencerTests.swift`, `TrainingLifecycleCoordinatorTests.swift`, `ContinuousRhythmMatchingSessionTests.swift`.

## Tasks & Acceptance

> **Renames apply throughout.** All task descriptions below use the new names from the Renames table. Apply the cascade (types, properties, files, locals) with a rename refactor or find/replace before / as part of each task.

**Execution:**
- [x] **Rename cascade** — apply every entry in the Renames table mechanically: type renames, file renames, property renames, local variable renames. Verify the build compiles (will fail on the type changes from the rest of the spec; that's expected).
- [x] `Peach/Core/Audio/SequencerTypes.swift` -- define `struct Beat: Sendable { let subdivisions: [Subdivision] }`; define `enum Subdivision: Sendable { case rest; case note(velocity: MIDIVelocity, offset: Duration); case nested(Beat) }`; define `protocol BeatProvider { func nextBeat() -> Beat }`; remove `CycleDefinition` and `StepProvider`.
- [x] Implement `Beat.events(beatOffset: Int64, beatDuration: Int64, channel: MIDIChannel, clickNote: MIDINote, noteOffDelaySamples: Int64) -> [ScheduledMIDIEvent]`: equal-spacing over `subdivisions.count`; emit noteOn/noteOff for `.note` at `beatOffset + index * subdivisionDuration + offsetSamples` (signed); skip `.rest`; recurse for `.nested(child)` with `beatOffset += index * subdivisionDuration` and `beatDuration = subdivisionDuration`. (Signature adds `sampleRate: SampleRate` — see Spec Change Log.)
- [x] `Peach/Core/Ports/BeatSequencer.swift` -- `currentBeat: Beat?`; `start(tempo: TempoBPM, beatProvider: any BeatProvider) async throws`.
- [x] `Peach/Core/Audio/SoundFontBeatSequencer.swift` -- internal state and `Batch` shift to `Beat`; `buildBatch` calls `beat.events(beatOffset: Int64(cycleIndex) * samplesPerBeat, beatDuration: samplesPerBeat, ...)`; `SequencerTiming` removes `samplesPerStep`, renames `samplesPerCycle` → `samplesPerBeat`; `SequencerEngine` (renamed) declared here.
- [x] `Peach/App/PreviewDefaults.swift` -- `StubBeatSequencer.currentBeat`; new `start` signature.
- [x] `Peach/App/PeachApp.swift`, `Peach/App/EnvironmentKeys.swift` -- update all type references (`SoundFontBeatSequencer`, `(any BeatSequencer)?`).
- [x] `Peach/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift` -- conform to `BeatProvider`; `nextBeat()` picks a gap `BeatPosition` as today and returns `Beat(subdivisions: (0..<4).map { i in i == gap.rawValue ? .rest : .note(velocity: i == 0 ? MIDIVelocity(127) : MIDIVelocity(100), offset: .zero) })`; in `handleTap`/`evaluatePlaybackPosition`, replace `timing.samplesPerStep` with `timing.samplesPerBeat / 4`.
- [x] ContinuousRhythmMatching consumers (`CompletedContinuousRhythmMatchingTrial`, `…DotView`, `…Screen`, settings files, `GapPositionEncoding`) -- apply `BeatPosition` rename; behaviour and encoding semantics unchanged. `BeatPosition` lives at `Peach/Training/ContinuousRhythmMatching/BeatPosition.swift` (discipline-local).
- [x] `PeachTests/Mocks/MockBeatSequencer.swift`, `…/MockSequencerEngine.swift`, `…/MockBeatProvider.swift` -- mirror renamed port, engine, and provider.
- [x] `PeachTests/Core/Audio/BeatTests.swift` (new) -- assert event offsets/counts for: flat beat; beat with one `.rest`; beat with one `.note(_, offset:)` (positive and negative shifts); nested beat.
- [x] `PeachTests/Core/Audio/SoundFontBeatSequencerTests.swift`, `…/BeatSequencerTests.swift` -- replace `CycleDefinition` setup with equivalent `Beat`s; assert via `currentBeat`; recompute `samplesPerStep` references from `samplesPerBeat / 4`. `BeatPositionTests.swift` (new) sits next to the CRM enum.
- [x] `PeachTests/App/TrainingLifecycleCoordinatorTests.swift`, `…/ContinuousRhythmMatchingSessionTests.swift` -- adjust references to renamed types, `samplesPerStep`, or `currentCycle`. `ContinuousRhythmMatchingSettingsTests`, `GapPositionEncodingTests`, `ContinuousRhythmMatchingDotViewTests`, and `TimingOffsetDetectionSessionTests` updated for the renames too.

**Acceptance Criteria:**
- Given `bin/test.sh && bin/test.sh -p mac` runs, when both suites finish, then all tests pass with no flakes.
- Given ContinuousRhythmMatching is started, when it runs, then scheduled MIDI events, tap evaluation, statistics, and dot view are identical to pre-refactor for the same inputs.
- Given any `Beat` (flat, with rests, with offsets, or nested), when `Beat.events(...)` is called, then it returns events at the mathematically correct sample offsets — verifiable in unit tests without the sequencer.
- Given the `BeatSequencer` port and `BeatProvider`, when read in isolation, then they contain no references to `BeatPosition`, `CycleDefinition`, or any discipline-specific type.
- Given a future discipline (e.g., 80.1 TimingOffsetDetection) implements `BeatProvider.nextBeat()`, then no port, mock, or sequencer change is required to use it.

## Spec Change Log

- **2026-06-01** — `Beat.events(...)` takes an additional `sampleRate: SampleRate` parameter so it can convert a `Subdivision.note(offset: Duration)` into a sample offset. The reference signature in Tasks does not list it; without it, the function cannot honour the `offset: Duration` field on `.note`. Tests in `BeatTests.swift` pass a fixed sample rate, so the "verifiable without the sequencer" acceptance still holds.
- **2026-06-01** — `BeatPosition` (renamed from CRM-local `StepPosition`) lives at `Peach/Training/ContinuousRhythmMatching/BeatPosition.swift` and has a sibling `PeachTests/Training/ContinuousRhythmMatching/BeatPositionTests.swift` (the original `StepSequencerTests` was actually a domain-types test; its `StepPosition`/`CycleDefinition` content moves with the rename, and the renamed `BeatSequencerTests.swift` now covers the remaining shared types `RhythmVelocity` and `SequencerTiming`).
- **2026-06-01** — `ContinuousRhythmMatchingDotView` parameter `activeStep` is renamed to `activeBeatPosition` and the helper parameter `stepIndex` to `index`, consistent with the spec's "Step terminology is dropped throughout."
- **2026-06-02** — Post-review (`/simplify-code`) refinements applied before commit:
  - `noteOffDelaySamples` clamp moved out of `SoundFontBeatSequencer` and into `Beat.events(...)`, where `subdivisionDuration` is known per-recursion. The sequencer's `samplesPerStep / 4` clamp was leaking the CRM "4 subdivisions" assumption back into the port; the new clamp uses each beat's own subdivision count, so future tuplets (3, 5, 6, …) get the correct headroom automatically. CRM byte-for-byte behaviour preserved.
  - New `extension SampleRate { func samples(for duration: Duration) -> Int64 }` in `Peach/Core/Music/SampleRate.swift` replaces four open-coded `Int64(rate × duration.timeInterval)` sites (`Beat.events`, `SoundFontBeatSequencer.playImmediateNote`, `SoundFontBeatSequencer.buildBatch`, `TimingOffsetDetectionSession.swift`). Truncating semantics match every pre-existing call site exactly.
  - `MockBeatProvider.crmBeats(gapPositions:)` and the `init(gapPositions: [BeatPosition])` convenience init dropped — they leaked CRM-local `BeatPosition` into shared mock infrastructure used by Core/Audio tests. `SoundFontBeatSequencerTests` now builds generic 4-subdivision beats via a local `beat(restAt: Int)` helper; CRM tests build via the canonical `ContinuousRhythmMatchingSession.beat(withGapAt:)`.
  - `ContinuousRhythmMatchingSession.selectNextGapPosition` inlined into `nextBeat()`; the `enabled.count == 1` special case dropped (`randomElement()` handles it); the duplicate `precondition(!enabled.isEmpty)` dropped (`ContinuousRhythmMatchingSettings.init` already enforces it). The append-only-when-running invariant matches the pre-80.0 behaviour (the old `nextCycle()` also short-circuited before appending); the split-helper version in the initial implementation had regressed this and the refinement restores it.
  - Observation churn at the 120 Hz tracking rate gated on actual change: `SoundFontBeatSequencer.currentBeat` and `ContinuousRhythmMatchingSession.currentBeatPosition` / `currentGapPosition` now only re-publish when their derived index changes.
  - `Beat.events` pre-reserves `subdivisions.count * 2` capacity to match the pre-80.0 allocation profile.
  - Restating-the-code comments deleted across the touched files.
  - Finding I (rename `currentGapPosition` → `gapPositionInCurrentBeat`) was deferred to `docs/implementation-artifacts/deferred-work.md` — pure rename, out of scope for this story.
- **2026-06-02** — Step-04 review patches (Blind hunter + Edge case hunter + Acceptance auditor):
  - Acceptance #1 / Boy Scout: `TimingOffsetDetectionSession.buildPattern` now uses `SampleRate.samples(for:)` for the `samplesPerSixteenth` computation (the sibling site was already migrated).
  - Acceptance #2: stale "step sequencer refill" comment in `SoundFontEngineTests.swift:339` updated to "beat sequencer refill".
  - Acceptance #3: `ContinuousRhythmMatchingSession.nextBeat()` replaces `randomElement()!` with a fused `guard let` against the captured settings — falls back to `.fourth` if the (precondition-guaranteed-non-empty) set is somehow empty, removing the force-unwrap per project rule.
  - Acceptance #4: spec change log wording about `gapPositions.append` corrected — the move restores pre-80.0 behaviour rather than tightening it.
  - Blind #5: `Beat` and `Subdivision` gain `Equatable` (auto-synthesizable) — useful for future testability without imposing identity semantics.
  - Blind #11: `Beat.init(subdivisions:)` was the auto-synthesized memberwise init; removed as boilerplate.
  - Blind #2: `Beat.events` doc clarified — the per-recursion clamp prevents within-beat subdivision overlap; inter-beat overlap is the scheduler's concern.
  - Blind #8: `beatsPerBatch` doc now states the implicit "≤8 events per beat" budget so future denser disciplines know to lower the constant.
  - Deferred (D1–D6) appended to `docs/implementation-artifacts/deferred-work.md`: concurrency audit, CRM refill state-reset, `SequencerEngine` contract tests, signed-offset bounds, deep-nesting safety, uniform-tempo `refillThreshold` assumption.
  - Rejected with reasoning (not deferred): integer-division drift (bounded < 1 sample per subdivision; realigns at every beat boundary), NaN/inf defenses (no production path produces NaN Duration), persisted-data migration (raw values 0–3 identical), CRM-vs-sequencer subdivision math drift (both use same `/4` formula), `BeatProvider` "leaked into TOD" claim (TOD uses `RhythmPattern`, not `BeatPosition`), and several premature defenses against future-only scenarios.

## Design Notes

`Subdivision.nested(Beat)` is the tuplet. Examples: 4-sixteenth quarter = `Beat([.note × 4])`; quarter triplet = `Beat([.note × 3])` — count 3 *is* the tuplet; swing eighths = `Beat([.nested(Beat([.note, .rest, .note]))])` (textbook triplet-with-rest; swing is a triplet feel, not 2:1). Per-subdivision duration isn't a field — equal spacing is enforced by construction; unequal rhythms (dotted, swing) come from nesting + rests, which stays musically coherent.

`samplesPerStep` drops because "step" presumes a flat grid; CRM (and 80.1) compute `samplesPerBeat / 4` locally. The nested-tuplet test locks the recursive path down before any discipline depends on it.

**Resolved Ask Firsts (2026-06-01):** `samplesPerStep` dropped; `StepVelocity` → `RhythmVelocity` shared in `SequencerTypes.swift`. The user expanded scope to drop "Step" comprehensively (see Renames) and renegotiated the frozen `Never` clause that had excluded `SoundFontStepSequencer`'s rename.

## Verification

- `bin/test.sh && bin/test.sh -p mac` — full iOS and macOS suites pass before commit.
- Manual: start a ContinuousRhythmMatching session in Debug — audio, dots, gap behaviour, statistics indistinguishable from before. Confirm TimingOffsetDetection (Research) is unaffected.

## Suggested Review Order

**The new abstraction**

- Single source of truth for `Beat`/`Subdivision`/`BeatProvider` + the pure event compiler. Read first.
  [`SequencerTypes.swift:5`](../../Peach/Core/Audio/SequencerTypes.swift#L5)

- The port — small enough to be the contract reviewers should hold up against everything else.
  [`BeatSequencer.swift:1`](../../Peach/Core/Ports/BeatSequencer.swift#L1)

**The sequencer**

- Walks beats, schedules batches, derives `currentBeat`. The Observation-gating in the run loop is the post-review subtlety.
  [`SoundFontBeatSequencer.swift:84`](../../Peach/Core/Audio/SoundFontBeatSequencer.swift#L84)

- `Beat → events` delegation. Verify the per-recursion `effectiveNoteOff` clamp is the only thing the sequencer relies on for inter-subdivision safety.
  [`SoundFontBeatSequencer.swift:171`](../../Peach/Core/Audio/SoundFontBeatSequencer.swift#L171)

- New `Duration → samples` helper that replaces four open-coded conversions.
  [`SampleRate.swift:40`](../../Peach/Core/Music/SampleRate.swift#L40)

**The CRM migration (byte-for-byte equivalence is the headline claim)**

- `BeatProvider` conformance and the discipline-local `BeatPosition`-shaped beat builder. This is where "flat 4-subdivision with rest at gap, accent on first" now lives canonically.
  [`ContinuousRhythmMatchingSession.swift:220`](../../Peach/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift#L220)

- The CRM-local `BeatPosition` enum — the spec says this is discipline-local; verify the boundary holds.
  [`BeatPosition.swift:1`](../../Peach/Training/ContinuousRhythmMatching/BeatPosition.swift#L1)

- `handleTap` and `evaluatePlaybackPosition` now compute the 16th-note subdivision locally as `samplesPerBeat / 4`. Verify the math matches the sequencer's emission grid.
  [`ContinuousRhythmMatchingSession.swift:178`](../../Peach/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift#L178)

- Observation gating on the 120 Hz tracking tick.
  [`ContinuousRhythmMatchingSession.swift:247`](../../Peach/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift#L247)

**App wiring**

- Type/name updates only; verify no behavioural change.
  [`PeachApp.swift:34`](../../Peach/App/PeachApp.swift#L34)

- Environment key, stub, and preview wiring.
  [`EnvironmentKeys.swift:10`](../../Peach/App/EnvironmentKeys.swift#L10)

- `PreviewDefaults.StubBeatSequencer` mirrors the port surface.
  [`PreviewDefaults.swift:72`](../../Peach/App/PreviewDefaults.swift#L72)

**Tests (verify what's covered and what's deferred)**

- `Beat.events` direct unit tests — flat, rest, signed offsets, nested, note-off clamp. The recursive `.nested(Beat)` path is exercised even though no production discipline uses it yet (spec requirement).
  [`BeatTests.swift:1`](../../PeachTests/Core/Audio/BeatTests.swift#L1)

- Sequencer tests — generic `beat(restAt:)` helper avoids leaking CRM's `BeatPosition` into Core/Audio tests.
  [`SoundFontBeatSequencerTests.swift:22`](../../PeachTests/Core/Audio/SoundFontBeatSequencerTests.swift#L22)

- CRM session tests, including the `nextBeat after stop` regression-pin.
  [`ContinuousRhythmMatchingSessionTests.swift:212`](../../PeachTests/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingSessionTests.swift#L212)

- Mocks — `MockBeatProvider` no longer takes `BeatPosition` (review-driven; was leaking CRM-local types into shared mock infra).
  [`MockBeatProvider.swift:1`](../../PeachTests/Mocks/MockBeatProvider.swift#L1)

**Spec change log + deferred work**

- Full audit trail of every deviation from the original spec listing, including the post-review patches.
  [`spec-80-0-beat-subdivision-for-step-sequencer.md:104`](./spec-80-0-beat-subdivision-for-step-sequencer.md#L104)

- Six review-surfaced items appended for later focused attention (concurrency audit, refill state-reset, contract tests, signed-offset bounds, deep-nesting safety, tempo-change assumption).
  [`deferred-work.md:19`](./deferred-work.md#L19)
