---
title: 'Story 80.1: Gapless looped pattern playback in TimingOffsetDetectionSession'
type: 'feature'
created: '2026-06-02'
status: 'done'
baseline_commit: '9cc9f54f'
context:
  - '{project-root}/docs/implementation-artifacts/epic-80-context.md'
  - '{project-root}/docs/implementation-artifacts/spec-80-0-beat-subdivision-for-step-sequencer.md'
  - '{project-root}/docs/project-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `TimingOffsetDetectionSession` plays the 4-sixteenth pattern as a one-shot via `RhythmPlayer.play(pattern)` and then waits in `awaitingAnswer`. At 80–100 BPM the whole pattern is ~600–800 ms and the tested 3rd-sixteenth arrives ~1.5 intervals in — well before the auditory system's 2–3-interval pulse-stabilisation window. The discipline therefore measures working-memory encoding more than offset perception, violating the Performance Principle.

**Approach:** Replace one-shot pattern playback with gapless looping driven by the `BeatSequencer` introduced in 80.0. The session becomes a `BeatProvider` whose `nextBeat()` returns the current trial's 4-subdivision `Beat` (accent on subdivision 0, displaced `.note(offset:)` on subdivision 2). A new `playingPatternLoop` state combines today's `playingPattern` and `awaitingAnswer`: the loop runs continuously until the user submits a direction. The session stops the sequencer on submission, runs feedback, then restarts on the next quarter-note grid boundary for the next trial. The existing wall-clock grid alignment between trials is preserved unchanged.

## Boundaries & Constraints

**Always:**
- The 4-sixteenth pattern shape is unchanged: accent on subdivision 0 (`RhythmVelocity.accent`), normal velocity on 1/2/3, displaced 3rd-sixteenth carries the trial's offset as a `Subdivision.note(offset:)`.
- Within a trial, pattern playback loops gaplessly with no fade and no inter-repetition silence. The sequencer's continuous emission of beats produces this naturally — the existing `Beat.events` per-recursion clamp already guarantees no inter-subdivision overlap.
- `playingPatternLoop` exits only on `.answerReceived` or `.stopRequested`/`.audioError`. Pattern completion does not end the trial.
- Between trials, the existing wall-clock `nextGridPoint(...)` scheduling is preserved: feedback runs, then the session waits until the next quarter-note grid boundary, then restarts the sequencer.
- `litDotCount` is driven by polling `BeatSequencer.timing.samplePosition` at the same 120 Hz cadence and observation-gating discipline CRM uses (`evaluatePlaybackPosition` pattern in `ContinuousRhythmMatchingSession`). The value cycles 1→2→3→4→1→… continuously while in `playingPatternLoop`; it is 0 in every other state.
- `NextTimingOffsetDetectionStrategy`, observers, `TrainingProfile`, the `TrainingRecord` envelope, and the `TimingOffset` value type are unchanged. No data migration.
- Discipline remains research-only — all new code stays inside the `#if PEACH_RESEARCH` envelope already in use.
- Sequencer lifecycle within the session: `start(tempo:beatProvider:)` is called per trial in `.beginNextTrial`; `stop()` is called when leaving `playingPatternLoop` (answer received or stop). Per-trial start/stop matches the existing per-trial grid-alignment seam.

**Ask First:**
- Default: after the migration, `RhythmPlayer`, `RhythmPattern`, `RhythmPlaybackHandle`, `SoundFontRhythmPlaybackHandle`, the `SoundFontPlayer` conformance, `StubRhythmPlayer`, the `EnvironmentValues.rhythmPlayer` entry, and the `MockRhythmPlayer*` mocks become dead code (TOD is the last consumer; CRM migrated in 80.0). The default is to delete them in this story as the Boy Scout closeout. Confirm or defer to a follow-up.

**Never:**
- Do not introduce a max-repetitions cap — that is 80.2.
- Do not change the dot-view rendering or help text — that is 80.4.
- Do not change `BeatSequencer`, `BeatProvider`, `Beat`, or `Subdivision` — they are frozen by 80.0.
- Do not introduce a session-long sequencer that keeps running through feedback/grid-wait with silent beats. Per-trial start/stop is the chosen seam.
- Do not change `TimingOffsetDetectionTrial`, `TimingOffset`, `CompletedTimingOffsetDetectionTrial`, the strategy protocol, observer protocols, or the SwiftData record.
- Do not introduce `import SwiftUI` into Core/.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| User answers mid-loop | `playingPatternLoop`, sequencer running, `handleAnswer(.early)` | State → `showingFeedback`; sequencer stopped (audio silenced within current subdivision); `evaluateAnswer` + `scheduleFeedbackTimer` fire; observers notified once | N/A |
| User answers between repetitions | `playingPatternLoop`, `litDotCount` just rolled 4→1 | Same as above; no special handling needed at boundary | N/A |
| Feedback completes, grid aligns | `showingFeedback` → `.feedbackTimerFired` → `waitingForGrid` → wall-clock wait → `.gridAlignmentReached` | State → `playingPatternLoop`; new trial selected; sequencer started again; `litDotCount` resumes from 1 | N/A |
| Stop during loop | `playingPatternLoop`, `stop()` called (foreground/background/interruption) | Sequencer stopped, lifecycle tasks cancelled, all state cleared to `idle` | Audio errors during stop are logged at `.warning` and ignored |
| Sequencer start fails | `.beginNextTrial` effect, `beatSequencer.start(...)` throws | `.audioError` event sent; state → `idle`; `stopAll` runs | Logged at `.error`; no observer notification |
| Stop before first trial completes | `start()` then `stop()` before any beat emission | Sequencer stopped if started, no completed trial recorded | N/A |

</frozen-after-approval>

## Code Map

- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift` — state machine rewrite (drop `playingPattern`/`awaitingAnswer`, add `playingPatternLoop`; drop `.patternFinished` event); conform to `BeatProvider`; `nextBeat()` returns the current trial's `Beat`; replace `buildPattern(... ) -> RhythmPattern` with `buildBeat(for:settings:) -> Beat`; replace per-note `Task.sleep` loop with a 120 Hz polling task that derives `litDotCount` from `beatSequencer.timing.samplePosition`; constructor swaps `rhythmPlayer: RhythmPlayer` + `sampleRate: SampleRate` for `beatSequencer: any BeatSequencer`.
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionLifecycleContribution.swift` — verify still compiles; signature is unchanged from the contribution side.
- `Peach/App/PeachApp.swift` — the `makeTimingOffsetDetectionSession(...)` factory and the `audio.beatSequencer` already constructed by 80.0 wire the sequencer into TOD instead of `audio.rhythmPlayer`. Inside the `PEACH_RESEARCH` factory only.
- `Peach/App/PreviewDefaults.swift` — preview wiring switches the TOD session to a `StubBeatSequencer` instance.
- `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionSessionTests.swift` — rewrite to use `MockBeatSequencer` + `MockBeatProvider`-equivalent assertions; cover new state transitions; assert `nextBeat()` shape; remove `MockRhythmPlayer` usage.
- `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionReduceTests.swift` — update for the new state machine.
- `PeachTests/App/TrainingLifecycleCoordinatorTests.swift` — swap `MockRhythmPlayer()` for `MockBeatSequencer()` in the TOD constructor call.
- `PeachTests/Training/TimingOffsetDetection/TimingDotViewTests.swift` — no behavioural change to the dot view itself, but if `litDotCount` semantics are now "currently-playing subdivision index + 1 mod 4," tests that exercise the visual mapping may need updates.

Boy Scout deletions (contingent on Ask First default):
- `Peach/Core/Ports/RhythmPlayer.swift`, `Peach/Core/Ports/RhythmPlaybackHandle.swift`, `Peach/Core/Audio/SoundFontRhythmPlaybackHandle.swift`.
- `SoundFontPlayer` loses its `RhythmPlayer` conformance and the `play(_:)`/`stopAll()`-rhythm path (lines ~60–108).
- `Peach/App/EnvironmentKeys.swift` drops the `rhythmPlayer` entry.
- `Peach/App/PeachApp.swift` drops the rhythmPlayer construction, the `@State` field, the environment injection, and the factory tuple member.
- `Peach/App/PreviewDefaults.swift` drops `StubRhythmPlayer`/`StubRhythmPlaybackHandle`.
- `PeachTests/Mocks/MockRhythmPlayer.swift`, `…/MockRhythmPlaybackHandle.swift`, `…/MockRhythmPlayerTests.swift` deleted.
- `PeachTests/Core/Audio/SoundFontPlayerTests.swift` — the "RhythmPlayer Conformance" section is removed.

## Tasks & Acceptance

**Execution:**
- [x] `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift` — rewrite state machine, `BeatProvider` conformance, `buildBeat`, polling task driving `litDotCount`, constructor signature. Match the CRM polling and observation-gating pattern.
- [x] `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionLifecycleContribution.swift` — adjust if needed.
- [x] `Peach/App/PeachApp.swift` — wire `audio.beatSequencer` into the TOD session factory; drop `rhythmPlayer` argument from the TOD path.
- [x] `Peach/App/PreviewDefaults.swift` — TOD preview uses `StubBeatSequencer`.
- [x] `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionSessionTests.swift` — migrate to `MockBeatSequencer`; cover the new state transitions, `nextBeat()` shape (accent + offset placement), per-trial sequencer start/stop, `litDotCount` cycling. Cover every row of the I/O matrix.
- [x] `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionReduceTests.swift` — update for the rewritten reduce.
- [x] `PeachTests/App/TrainingLifecycleCoordinatorTests.swift` — TOD session constructor swap to `MockBeatSequencer`.
- [x] `PeachTests/Training/TimingOffsetDetection/TimingDotViewTests.swift` — adjust if `litDotCount` semantics changed. (No changes required: the view's static layout helpers don't depend on `litDotCount` semantics, and `testedNoteIndex` is unchanged.)
- [x] **Boy Scout (default per Ask First)** — delete `RhythmPlayer`, `RhythmPattern`, `RhythmPlaybackHandle`, `SoundFontRhythmPlaybackHandle`, the `SoundFontPlayer` conformance, `StubRhythmPlayer`, the `EnvironmentValues.rhythmPlayer` entry, the `MockRhythmPlayer*` mocks, and the SoundFontPlayer-tests RhythmPlayer section. Update `PeachApp.swift` and `PreviewDefaults.swift` accordingly.

**Acceptance Criteria:**
- Given the user starts a Timing Offset Detection session, when the first trial begins, then the 4-sixteenth pattern plays and continues looping gaplessly with no audible gap at the loop boundary until the user submits a direction.
- Given the user is in `playingPatternLoop` and submits a direction, when `handleAnswer` is invoked at any point during any loop iteration, then the session transitions to `showingFeedback`, the sequencer is stopped, and `evaluateAnswer` runs exactly once with the same outcome it would have produced under the pre-80.1 one-shot behaviour for that trial.
- Given feedback completes and the wall-clock grid alignment fires, when the next trial begins, then the sequencer restarts with the next trial's `Beat` and `litDotCount` resumes cycling from 1.
- Given `bin/test.sh && bin/test.sh -p mac` runs, when both suites finish, then all tests pass with no flakes on either platform.
- Given the TOD test suite, when `nextBeat()` is exercised, then it returns a `Beat` whose subdivision 0 is `.note(velocity: .accent, offset: .zero)`, subdivisions 1 and 3 are `.note(velocity: .normal, offset: .zero)`, and subdivision 2 is `.note(velocity: .normal, offset: trial.offset.duration)`.
- Given the Boy Scout deletions land, when the project builds, then no file references `RhythmPlayer`, `RhythmPattern`, or `RhythmPlaybackHandle` and the build succeeds on both platforms.

## Spec Change Log

- **2026-06-02** — `buildBeat` shipped as `buildBeat(for trial: TimingOffsetDetectionTrial) -> Beat` rather than the Code Map's `buildBeat(for:settings:)`. The trial fully determines the beat shape (accent on subdivision 0, displaced `.note(offset:)` on subdivision 2 from `trial.offset.duration`); the `settings` parameter was dead at the call site. Acceptance criterion on `nextBeat()` shape verifies the unchanged semantics.
- **2026-06-02** — Step-04 review patches (Blind hunter + Edge case hunter + Acceptance auditor):
  - **F1/F2 (sequencer stop race + swallowed errors)**: introduced a chained `stopTask` and `enqueueSequencerStop(onFailure:)` helper. Each stop awaits the previous stop's value (serializing back-to-back stops) and cancels-then-awaits any in-flight `startTask` before calling `beatSequencer.stop()`. Non-cancellation errors are logged at `.error`; answer-driven stops invoke `send(.audioError)` on failure (matching the spec's audio-error contract), teardown-driven stops log only.
  - **F3 (phantom-trial leak)**: `nextBeat()` now returns an all-`.rest` 4-subdivision beat when `currentTrial` is `nil`. A sequencer refill that outlives the session's stop schedules silence instead of an 80 BPM click pattern. Spec acceptance for `nextBeat()` shape is unchanged because that path requires an active trial.
  - **F9 (DRY for `lastPublishedSubdivisionIndex` reset)**: introduced `private func resetTracking()` and called it from `beginNextTrial`, `silenceSequencerForAnswer`, and `stopAll`. Single source of truth for the litDot reset invariant.
  - **F10 (skew risk between `patternNoteCount` and `subdivisionsPerBeat`)**: dropped the `patternNoteCount` constant and made it a computed `Int(subdivisionsPerBeat)`. Now impossible to skew.
  - **F13 (redundant `stopAll` on spurious `.idle + .audioError`)**: added an explicit `(.idle, .audioError) → []` case ahead of the catch-all. Prevents extra sequencer.stop() Tasks when a cancelled startTask's error path arrives after teardown. New reduce test pins the contract.
  - **F21 (Boy Scout on pre-existing `gridOrigin!`)**: replaced the force-unwrap in `beginNextTrial` with `let origin = currentTime(); gridOrigin = origin; logger.info("... \(origin) ...")`. Project rule "No force unwrapping (`!`)" — pre-existing condition fixed inline per the Boy Scout Rule.
  - **F23 (separation of mechanism and policy)**: split `Effect.evaluateAnswer` into two ordered effects emitted from reduce: `.silenceSequencer` (mechanism — interpreted by `silenceSequencerForAnswer()`, which cancels tracking, resets state, and enqueues the sequencer stop) followed by `.evaluateAnswer(direction:)` (policy — pure result computation, observer notification, statistics). The reduce test asserts the new effect order to keep the contract pinned.
  - **F15/F17/F18 (test depth)**: added `pollingTaskUpdatesLitDotCount` exercising the real trackingTask loop (not the visible-for-testing `evaluatePlaybackPosition`), strengthened `handleAnswerAtLoopBoundary` to assert the observed outcome equals a mid-loop answer for the same trial, and added `nextBeatStableAcrossRepetitions` to lock the looping invariant (`nextBeat()` returns equal beats across repeated calls within a trial).
  - **F16 (test fixture comment lied)**: comment on `sequencer.samplesPerBeat = 22050` now correctly notes the round value is ≈120 BPM @ 44.1 kHz and that the mock decouples it from `TempoBPM(80)`.
  - Deferred (appended to `docs/implementation-artifacts/deferred-work.md`): one-tick litDotCount blip at sequencer batch-refill boundary; cross-discipline sequencer serialization contract test (consolidate with 80.0 D1 concurrency audit).
  - Rejected with reasoning (not deferred): `startTask`/`trackingTask` not routed through `lifecycle.setTrainingTask` (intentional — CRM uses the same idiom; `SessionLifecycle` has only one trainingTask slot); `litDotCount` writes off MainActor (false positive under default MainActor isolation); polling cadence 125 Hz vs spec's "120 Hz" prose (8 ms is correct, matches CRM, spec prose can be clarified later); `StubBeatSequencer.samplesPerBeat == 0` produces dark dots in previews (same as CRM, no behavioural regression); duplicate `percussionPreset` defensive defaults in `PeachApp` (still used by the live sequencer, not dead); MIDI click note regression test (`Beat` carries no MIDI note number — it's compiled in by `SoundFontBeatSequencer.clickNote`, covered elsewhere).
- **2026-06-02** — Post-review (`/simplify-code`) refinements applied before commit:
  - `Effect.silenceSequencer` renamed to `Effect.stopSequencer` (and `silenceSequencerForAnswer` → `stopSequencerForAnswer`) for naming symmetry with `stopAll`, `beginNextTrial`, `evaluateAnswer`, `scheduleFeedbackTimer` — every effect now names the mechanism, not the perceptual consequence. The "mechanism before policy" rationale moved from the helper docstring to a comment on the `.stopSequencer` case in `reduce` where it actually applies.
  - `subdivisionsPerBeat: Int64 = 4` → `static let subdivisionsPerBeat: Int = 4` (non-private so tests can compute subdivision-aligned positions from a single source of truth). `patternNoteCount` dropped (was a computed `Int(subdivisionsPerBeat)` wart). The one division site casts to `Int64` locally. Test fixture's `samplesPerSubdivision` now derives from `TimingOffsetDetectionSession.subdivisionsPerBeat`, removing the magic `/4`.
  - `nextBeat()` fallback now returns a `static let silentBeat = Beat(subdivisions: Array(repeating: .rest, count: subdivisionsPerBeat))` instead of allocating a new array on every call (sequencer batches request 500 beats per refill). The "WHY a refill outliving stop matters" rationale moved onto the static constant's docstring rather than the call site.
  - `enqueueSequencerStop(onFailure: (() -> Void)?)` → `enqueueSequencerStop(onFailure: @escaping () -> Void = {})` so the default no-op covers teardown stops naturally and `stopAll`'s call site drops the explicit `nil`. Docstring rewritten to lead with the WHY (serializing answer-driven and teardown-driven stops so they can't race on the sequencer's internal `runLoopTask`) and follow with the three numbered steps.
  - `stopAll`'s `enqueueSequencerStop` call-site comment rewritten to name the actual risk (an `.audioError` here would re-enter `stopAll` via the reducer, looping) rather than restating the parameter value.
  - `buildBeat`'s code-restating docstring dropped; the implementation is self-explanatory.
  - `trackingPollingInterval` docstring corrected: 8 ms is ≈125 Hz (not "matching the beat sequencer" — the sequencer is sample-clock-driven, not polled); the relevant fact is sub-perceptual cadence for the lit-dot indicator.
  - Test `pollingTaskUpdatesLitDotCount` renamed to `trackingTaskUpdatesLitDotCount` (with the meta description "real loop lifecycle" replaced by a behavioural one); the 5-line body comment restating the test's purpose dropped.
  - Test fixture comment on `samplesPerBeat = 22050` reduced from a 60-word paragraph to a single line stating the load-bearing fact (the mock doesn't derive the value from `TempoBPM`).
  - Rejected during this pass: keeping the sequencer running across trials with silent beats (forbidden by the spec's `Never` clause — per-trial start/stop is the chosen seam); hoisting `trackingPollingInterval`/`subdivisionsPerBeat` to shared infrastructure (would touch CRM unnecessarily and the constants are discipline-local — CRM's 4-step cycle and TOD's 4-sixteenth pattern are conceptually independent); caching `currentBeat` per trial (~2000 4-element allocations per session is trivial; not worth the field-coupling); extending `SessionLifecycle` with start/tracking/stop task slots (large symmetric refactor across both sessions, not in 80.1's scope); renaming `stopAll` to `tearDown` (touches CRM idiom, not in scope); applying PF-004's documented fix inline (catalog entry with concrete fix recipe already satisfies the "fix or track" rule).

## Design Notes

`litDotCount` derivation: in `playingPatternLoop`, the polling task computes `globalSubdivisionIndex = Int(timing.samplePosition / (timing.samplesPerBeat / 4))` (the same `/4` shape CRM uses locally), then publishes `litDotCount = (globalSubdivisionIndex % 4) + 1` when the index changes. This preserves today's "cumulative fill from 0/1 up to 4" visual but cycles continuously across loop iterations instead of resetting on `.patternFinished`. Story 80.4 is the place where the dot-view *rendering* may be reinterpreted (e.g. single-highlight vs. cumulative fill); 80.1 just supplies a sensibly-cycling integer.

Per-trial sequencer start/stop is chosen over "session-long sequencer with silent beats" because (a) it preserves the existing wall-clock `nextGridPoint(...)` mechanism unchanged, (b) it keeps `samplePosition` semantics simple (resets to 0 per trial), and (c) stopping the sequencer is the cleanest way to silence audio mid-pattern when the user answers.

## Verification

**Commands:**
- `bin/test.sh` — expected: all iOS tests pass.
- `bin/test.sh -p mac` — expected: all macOS tests pass.
- `bin/build.sh` and `bin/build.sh -p mac` — expected: no warnings introduced by the migration.

**Manual checks:**
- Start TimingOffsetDetection in a Research build. Audio loops gaplessly until a direction is submitted; submitting any time during the loop ends playback cleanly and shows feedback; the next trial begins on a quarter-note grid boundary. Verify on both iOS and macOS.

## Suggested Review Order

**State machine + BeatProvider — read this first**

- The new four-state reduce: `playingPattern` + `awaitingAnswer` collapse into `playingPatternLoop`; mechanism (`.stopSequencer`) is emitted ahead of policy (`.evaluateAnswer`).
  [`TimingOffsetDetectionSession.swift:42`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift#L42)

- `BeatProvider.nextBeat()` — the single seam that turns the session into a sequencer-callable beat source. Silent-beat fallback locks down the post-stop refill race.
  [`TimingOffsetDetectionSession.swift:217`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift#L217)

- Pure beat shape: accent on subdivision 0, displaced 3rd-sixteenth carries the trial's `Duration` offset on subdivision 2.
  [`TimingOffsetDetectionSession.swift:222`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift#L222)

- Static silent beat — allocated once, returned on every nil-trial `nextBeat()` so post-stop refills cannot leak audible clicks.
  [`TimingOffsetDetectionSession.swift:91`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift#L91)

**Audio lifecycle — the chained stop that keeps start/stop from racing**

- `enqueueSequencerStop` — the headline post-review subtlety. Serializes back-to-back stops and waits out any in-flight `startTask` so the sequencer's `runLoopTask` cannot race.
  [`TimingOffsetDetectionSession.swift:436`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift#L436)

- Answer-driven stop: cancels tracking, resets state, enqueues a sequencer stop that on failure escalates to `.audioError`.
  [`TimingOffsetDetectionSession.swift:336`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift#L336)

- Teardown: uses the default no-op `onFailure` because an audio error here would re-enter `stopAll` via the reducer, looping.
  [`TimingOffsetDetectionSession.swift:406`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift#L406)

**Tracking loop — driving `litDotCount` from sample position**

- Per-trial start: opens the sequencer with `self` as the BeatProvider, then arms the polling loop.
  [`TimingOffsetDetectionSession.swift:272`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift#L272)

- 125 Hz polling task — same shape as CRM, gated by `lastPublishedSubdivisionIndex` to avoid 120 Hz Observation churn.
  [`TimingOffsetDetectionSession.swift:306`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift#L306)

- Subdivision math: `samplePosition / (samplesPerBeat / subdivisionsPerBeat)` cycles `litDotCount` 1→2→3→4→1 across loop iterations.
  [`TimingOffsetDetectionSession.swift:318`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift#L318)

**Between trials — wall-clock grid alignment preserved**

- Feedback timer + grid wait — unchanged structurally; the sequencer is restarted on the next quarter-note boundary.
  [`TimingOffsetDetectionSession.swift:373`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift#L373)

- `nextGridPoint` — wall-clock alignment kept exactly as it was pre-80.1.
  [`TimingOffsetDetectionSession.swift:462`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift#L462)

**App wiring + Boy Scout deletions**

- TOD factory now consumes `audio.beatSequencer` (replacing the now-dead `audio.rhythmPlayer`).
  [`PeachApp.swift:430`](../../Peach/App/PeachApp.swift#L430)

- Composition root tuple lost the rhythmPlayer member; injection point unchanged otherwise.
  [`PeachApp.swift:289`](../../Peach/App/PeachApp.swift#L289)

- Environment surface lost `rhythmPlayer` — TOD reads `beatSequencer` like CRM does.
  [`EnvironmentKeys.swift:9`](../../Peach/App/EnvironmentKeys.swift#L9)

- `SoundFontPlayer` no longer conforms to `RhythmPlayer` (port deleted); `NotePlayer` is the only conformance left.
  [`SoundFontPlayer.swift:5`](../../Peach/Core/Audio/SoundFontPlayer.swift#L5)

- Preview wiring swaps `StubRhythmPlayer` for `StubBeatSequencer`.
  [`PreviewDefaults.swift:106`](../../Peach/App/PreviewDefaults.swift#L106)

**Tests — I/O matrix coverage + new looping invariants**

- Reduce table: `.answerReceived` now produces three ordered effects — `[.stopSequencer, .evaluateAnswer, .scheduleFeedbackTimer]`.
  [`TimingOffsetDetectionReduceTests.swift:34`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionReduceTests.swift#L34)

- `.idle + .audioError` no-op — pins the new explicit case that prevents redundant `stopAll`.
  [`TimingOffsetDetectionReduceTests.swift:108`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionReduceTests.swift#L108)

- `nextBeat()` shape with offset placement on subdivision 2 (positive and negative offsets).
  [`TimingOffsetDetectionSessionTests.swift:134`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionSessionTests.swift#L134)

- Silent-beat fallback after stop — proves the post-teardown refill cannot leak clicks.
  [`TimingOffsetDetectionSessionTests.swift:207`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionSessionTests.swift#L207)

- Beat-by-beat stability — every `nextBeat()` inside one trial returns the same beat (the gapless-loop invariant).
  [`TimingOffsetDetectionSessionTests.swift:229`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionSessionTests.swift#L229)

- Real polling task lifecycle — `litDotCount` updates as sample position advances and stops on session stop (no manual `evaluatePlaybackPosition` cheats).
  [`TimingOffsetDetectionSessionTests.swift:304`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionSessionTests.swift#L304)

- I/O matrix: mid-loop answer → `showingFeedback`, sequencer stopped, observer notified once.
  [`TimingOffsetDetectionSessionTests.swift:399`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionSessionTests.swift#L399)

- I/O matrix: loop-boundary answer produces byte-identical outcome to mid-loop answer (no special handling at boundary).
  [`TimingOffsetDetectionSessionTests.swift:444`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionSessionTests.swift#L444)

- I/O matrix: feedback completes → grid aligns → next trial starts on the boundary; sequencer is started a second time.
  [`TimingOffsetDetectionSessionTests.swift:496`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionSessionTests.swift#L496)

- I/O matrix: `sequencerStartFailureSendsAudioError` covers the audio-error path → `.idle`, no observer notification.
  [`TimingOffsetDetectionSessionTests.swift:585`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionSessionTests.swift#L585)

- Lifecycle coordinator's TOD construction swapped to `MockBeatSequencer` — one-line wiring change.
  [`TrainingLifecycleCoordinatorTests.swift:497`](../../PeachTests/App/TrainingLifecycleCoordinatorTests.swift#L497)

**Audit trail**

- Spec Change Log — three entries cover the signature deviation, step-04 review patches, and the `/simplify-code` refinements.
  [`spec-80-1-gapless-looped-pattern-playback.md:106`](./spec-80-1-gapless-looped-pattern-playback.md#L106)

- Two new deferred items appended for focused attention later (litDotCount refill blip + cross-discipline sequencer serialization).
  [`deferred-work.md:25`](./deferred-work.md#L25)

- Pre-existing macOS flake added to the findings catalog with a documented one-line fix.
  [`pre-existing-findings.md:38`](../pre-existing-findings.md#L38)
