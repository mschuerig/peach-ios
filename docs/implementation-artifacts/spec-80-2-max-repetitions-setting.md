---
title: 'Story 80.2: Max-repetitions setting end-to-end'
type: 'feature'
created: '2026-06-02'
status: 'done'
baseline_commit: 'bf1e6212'
context:
  - '{project-root}/docs/implementation-artifacts/epic-80-context.md'
  - '{project-root}/docs/implementation-artifacts/spec-80-1-gapless-looped-pattern-playback.md'
  - '{project-root}/docs/project-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** After 80.1, the TOD pattern loops gaplessly until the user submits a direction — there is no upper cap on per-trial pattern repetitions. The epic requires a `maxRepetitions` setting (1 → practically ∞, default high) so users who want a finite-exposure constraint (e.g., `1` to restore pre-80.1 one-shot semantics) can opt in, while the default behaviour stays "loop until you decide".

**Approach:** Plumb a `maxRepetitions: Int` through the Epic 77 feature-local plugin model — a `TimingOffsetDetectionUserSettings` port owned by the discipline directory, an `App…` production type that reads `UserDefaults`, a feature-local `SettingsKeys` file with the default, and a session-settings field. When the per-trial completed-cycle count reaches `maxRepetitions`, the session stops the sequencer (audio silences) but stays in `playingPatternLoop` so the user can still submit a direction. Trial outcome is recorded only on the user's answer — schema and observer contracts are unchanged.

## Boundaries & Constraints

**Always:**
- Feature-local plumbing only. New files live under `Peach/Training/TimingOffsetDetection/Settings/`, mirroring CRM's `Peach/Training/ContinuousRhythmMatching/Settings/`. The central `Peach/Core/Ports/UserSettings.swift` and `Peach/Settings/AppUserSettings.swift` are not touched.
- `TimingOffsetDetectionSettings.from(_:todUserSettings:)` is the single seam that reads `maxRepetitions` from the feature-local port. The session does not see the port directly.
- `playingPatternLoop` exits only on `.answerReceived`, `.stopRequested`, or `.audioError` — the rep cap is a sequencer-stop mechanism within the state, not a state exit. (Preserves the 80.1 state-machine contract.)
- Cap-reached detection lives in the polling tracking task: `completedCycles = globalSubdivisionIndex / subdivisionsPerBeat`; when `completedCycles >= maxRepetitions`, `send(.repetitionCapReached)` once and let the cancelled tracking task suppress further firings.
- After the cap stops the sequencer, `currentTrial` and `settings` stay populated so `handleAnswer(direction:)` still completes the trial normally — feedback, grid alignment, and observer notification are unchanged.
- `maxRepetitions` is validated `>= 1` at the `TimingOffsetDetectionSettings` boundary via `precondition`. Reads through the port clamp/fall back to the default on out-of-range UserDefaults values (defence in depth at the UserDefaults read site).
- Discipline stays research-only. All new files compile and run inside the existing `#if PEACH_RESEARCH` envelope; non-research builds are unaffected.

**Ask First:**
- Default: `defaultMaxRepetitions = 20` (the brainstorming "soft cap ≈ 20" with auto-stop on decision). Confirm or override before the spec is locked in.
- Default: no separate "AppTODUserSettings UserDefaults round-trip" test file is added — the protocol-level `MockTimingOffsetDetectionUserSettings` covers session behaviour, mirroring CRM's existing test surface. Confirm or request explicit persistence tests.

**Never:**
- Do not add a `maxRepetitions` field, key, or default to the central `UserSettings` port, `AppUserSettings`, or `SettingsKeys.swift`. The plugin model forbids it.
- Do not add a Settings UI row — that is 80.3.
- Do not change the dot-view rendering, `litDotCount` semantics, or visual treatment of the cap-stopped state beyond reusing `resetTracking()` — that is 80.4.
- Do not change `TimingOffsetDetectionTrial`, `CompletedTimingOffsetDetectionTrial`, `TimingOffset`, the strategy protocol, observer protocols, the SwiftData record, or the CSV contract. No schema migration.
- Do not add a "no-answer" outcome or auto-submit on cap. The cap silences audio; the user still owes a direction.
- Do not introduce `import SwiftUI` into `Core/`. Settings-row composition is 80.3's problem.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Cap reached before answer | `playingPatternLoop`, `globalSubdivisionIndex == maxRepetitions * subdivisionsPerBeat` | `send(.repetitionCapReached)` once; sequencer stopped via `enqueueSequencerStop()`; `litDotCount` reset to 0; state stays `playingPatternLoop`; `currentTrial` retained | Sequencer-stop failure logged at `.error` (teardown-style no-op `onFailure`, matching `stopAll()`); no `.audioError` escalation |
| Answer arrives after cap stop | Cap-stopped state, `handleAnswer(direction:)` | State → `showingFeedback`; `evaluateAnswer` runs; observer notified once; feedback timer scheduled; grid alignment proceeds as in 80.1 | N/A |
| Answer arrives before cap | `playingPatternLoop`, sequencer running, `handleAnswer(direction:)` | Unchanged from 80.1 — tracking cancelled, sequencer stopped via answer path, evaluate + feedback fire | N/A |
| `maxRepetitions == 1` | Trial begins, first cycle plays | After subdivision 3 of cycle 1 plays, polling sees `completedCycles == 1`; cap fires; audio stops; user must still answer | N/A |
| Cap exceeds completed cycles forever | `maxRepetitions == .max` (or any high value the user never reaches) | Behaviour identical to 80.1 — loops until user answers; `.repetitionCapReached` never fires | N/A |
| Spurious cap event in non-loop state | `.repetitionCapReached` arrives in `showingFeedback`/`waitingForGrid`/`idle` | Reducer default case: no state change, no effects | N/A |
| UserDefaults missing or out of range | `defaults.object(forKey:) == nil` or stored value `< 1` | Port returns `defaultMaxRepetitions` | N/A |

</frozen-after-approval>

## Code Map

- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionSettingsKeys.swift` — new. `enum TimingOffsetDetectionSettingsKeys { static let maxRepetitions = "timingOffsetDetectionMaxRepetitions"; static let defaultMaxRepetitions = 20 }`. Mirrors `ContinuousRhythmMatchingSettingsKeys`.
- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionUserSettings.swift` — new. `protocol TimingOffsetDetectionUserSettings { var maxRepetitions: Int { get } }` + `final class AppTimingOffsetDetectionUserSettings: TimingOffsetDetectionUserSettings` reading `UserDefaults.standard` with the key + clamp-to-default fallback on missing/`< 1` values.
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSettings.swift` — add `var maxRepetitions: Int` field; `init` default `= TimingOffsetDetectionSettingsKeys.defaultMaxRepetitions`; `precondition(maxRepetitions >= 1, "maxRepetitions must be >= 1")`; replace `static func from(_:)` with `static func from(_ userSettings: UserSettings, todUserSettings: TimingOffsetDetectionUserSettings)`.
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionLifecycleContribution.swift` — add `todUserSettings: any TimingOffsetDetectionUserSettings` parameter; pass through to `.from(_:todUserSettings:)`. Mirrors `ContinuousRhythmMatchingLifecycleContribution`.
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift` — add `case repetitionCapReached` to `Event`; add `case stopSequencerAtCap` to `Effect`; reducer `(.playingPatternLoop, .repetitionCapReached) → return [.stopSequencerAtCap]` (no state change); interpret `.stopSequencerAtCap` as a new `stopSequencerAtCap()` helper that cancels `trackingTask`, calls `resetTracking()`, and calls `enqueueSequencerStop()` with the default no-op `onFailure`; in `evaluatePlaybackPosition`, after computing `globalSubdivisionIndex`, check `let completedCycles = globalSubdivisionIndex / Self.subdivisionsPerBeat; if let settings, completedCycles >= settings.maxRepetitions { send(.repetitionCapReached); return }` *before* the `litDotCount` publish (so the cap fires on the boundary tick, not after).
- `Peach/App/PeachApp.swift` — add `private let todUserSettings = AppTimingOffsetDetectionUserSettings()` near the existing `crmUserSettings` (line ~40); add `todUserSettings: any TimingOffsetDetectionUserSettings` parameter to `buildCoordinators`; thread `todUserSettings: todUserSettings` into both `buildCoordinators(...)` call sites (init ~85, `rebuildCoordinators` ~205); update the TOD `.contribute(...)` call inside `lifecycleRegistry` (~512) to pass it through. Wrap the new property and the new build-coordinator argument in `#if PEACH_RESEARCH` to match the discipline's research-only gating.
- `PeachTests/Mocks/MockTimingOffsetDetectionUserSettings.swift` — new. `final class MockTimingOffsetDetectionUserSettings: TimingOffsetDetectionUserSettings { var maxRepetitions: Int = TimingOffsetDetectionSettingsKeys.defaultMaxRepetitions }`. Mirrors `MockContinuousRhythmMatchingUserSettings`.
- `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionSessionTests.swift` — extend the factory to accept an optional `maxRepetitions:` override; cover every I/O matrix row (cap-fires-once, post-cap answer completes trial, pre-cap answer unchanged, `maxRepetitions == 1` plays exactly one cycle, high-cap never fires).
- `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionReduceTests.swift` — add table entries for `(.playingPatternLoop, .repetitionCapReached) → []` effect `[.stopSequencerAtCap]`, plus spurious-event rows for other states.
- `PeachTests/App/TrainingLifecycleCoordinatorTests.swift` — line ~510 TOD `.contribute(...)` call gets `todUserSettings: MockTimingOffsetDetectionUserSettings()`; constructor wiring (~532) likewise.

## Tasks & Acceptance

**Execution:**
- [x] `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionSettingsKeys.swift` — create. Define `maxRepetitions` UserDefaults key and `defaultMaxRepetitions = 20` constant.
- [x] `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionUserSettings.swift` — create. Define the port protocol and `AppTimingOffsetDetectionUserSettings` production type with the missing-or-`< 1` → default fallback.
- [x] `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSettings.swift` — add `maxRepetitions` field with `precondition`; rewrite `from(_:)` factory to `from(_:todUserSettings:)`.
- [x] `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionLifecycleContribution.swift` — add `todUserSettings` parameter; thread through to `.from`.
- [x] `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift` — add `.repetitionCapReached` event + `.stopSequencerAtCap` effect; reducer case; `stopSequencerAtCap()` helper; cap check in `evaluatePlaybackPosition` ahead of the `litDotCount` publish.
- [x] `Peach/App/PeachApp.swift` — instantiate `AppTimingOffsetDetectionUserSettings` unconditionally (mirroring `crmUserSettings`), thread through `buildCoordinators` and `rebuildCoordinators`, update TOD `.contribute(...)` call. **Build-flag gating is `DisciplineBootstrap`'s responsibility, not PeachApp's.**
- [x] `PeachTests/Mocks/MockTimingOffsetDetectionUserSettings.swift` — create.
- [x] `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionSessionTests.swift` — factory takes `maxRepetitions:`; new tests cover every I/O matrix row.
- [x] `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionReduceTests.swift` — add `.repetitionCapReached` reducer rows.
- [x] `PeachTests/App/TrainingLifecycleCoordinatorTests.swift` — pass `MockTimingOffsetDetectionUserSettings()` in both wiring sites.

**Acceptance Criteria:**
- Given a TOD trial started with `maxRepetitions = 3`, when 3 full cycles of the 4-sixteenth pattern have played, then the sequencer stops, `litDotCount == 0`, state remains `.playingPatternLoop`, and no observer is notified yet.
- Given the cap has stopped the sequencer mid-trial, when the user calls `handleAnswer(direction:)`, then state transitions to `.showingFeedback`, `evaluateAnswer` runs exactly once with the trial's outcome, and the observer is notified exactly once.
- Given `maxRepetitions = 1`, when a trial begins, then exactly one full cycle plays before the sequencer stops; the user must still submit a direction to advance to feedback.
- Given `bin/test.sh && bin/test.sh -p mac` runs, when both suites finish, then all tests pass with no flakes on either platform.
- Given a non-research build configuration (`Debug` or `Release` without `PEACH_RESEARCH`), when the project builds, then the build succeeds and no Timing Offset Detection discipline is registered (verified by `DisciplineBootstrap` not including TOD in `allDisciplines`); references to `AppTimingOffsetDetectionUserSettings` and `todUserSettings` in `PeachApp.swift` are unconditional but produce dead code that is unreachable at runtime.
- Given `UserDefaults` has no value for `timingOffsetDetectionMaxRepetitions` (or a stored value `< 1`), when `AppTimingOffsetDetectionUserSettings.maxRepetitions` is read, then it returns `TimingOffsetDetectionSettingsKeys.defaultMaxRepetitions`.

## Spec Change Log

- **2026-06-02** — Implementation deltas vs. Code Map:
  - **`#if PEACH_RESEARCH` cannot wrap a parameter inside an argument or parameter list.** Swift rejects inline `#if` inside parameter lists (`error: expected parameter name followed by ':'`). The Code Map's "wrap the new build-coordinator argument in `#if PEACH_RESEARCH`" was therefore translated to: `buildCoordinators` takes `todUserSettings` unconditionally; both call sites resolve the value via a small `#if PEACH_RESEARCH ... #else AppTimingOffsetDetectionUserSettings() #endif` `let` declaration immediately before each call. The App-level `todUserSettings` *property* is still wrapped in `#if PEACH_RESEARCH` as specified. The non-research path constructs a throwaway `AppTimingOffsetDetectionUserSettings()` so the discipline-gated property isn't referenced when the type would still link.
  - **TOD `.contribute(...)` call inside `lifecycleRegistry` is now wrapped in `#if PEACH_RESEARCH`.** Pre-existing behaviour was: TOD always contributed even in non-research builds (the discipline just wasn't registered, so the contribution was unreachable). Wrapping the contribution in research-only gating matches the discipline's research-only gating and avoids the placeholder-`AppTimingOffsetDetectionUserSettings()` route through the production code path. CRM remains unchanged (pre-existing inconsistency — out of scope for this spec).
  - **PreviewDefaults updated.** Added `StubTimingOffsetDetectionUserSettings` (mirroring `StubContinuousRhythmMatchingUserSettings`) and threaded it through the `TrainingLifecycleCoordinator.stub` registry so previews remain in sync with the new `contribute(...)` signature. Not in the Code Map; required because the new signature broke compilation otherwise.
  - **`TimingOffsetDetectionSettingsTests.swift` updated.** The existing `Core/Training/TimingOffsetDetectionSettingsTests.swift` (not listed in the Code Map) called the old `from(_:)` factory; updated to `from(_:todUserSettings:)` and added a coverage row for the new `maxRepetitions` path through the port.
  - **`cancelTrackingAndReset` helper extracted in `TimingOffsetDetectionSession`.** Both `stopSequencerForAnswer` and `stopSequencerAtCap` share the "cancel trackingTask, clear it, call `resetTracking()`" preamble; consolidating it keeps the two paths' divergence (the `onFailure` escalation) visible at the single line that differs. `stopAll` is intentionally left as-is because its cleanup sequence interleaves `lifecycle?.cancelAllTasks()` between the cancel and the reset, and consolidating would obscure that.
- **2026-06-02** — Step-04 review patches:
  - **`#if PEACH_RESEARCH` scattering removed from `PeachApp.swift` (centralisation per user direction).** The first 2026-06-02 entry above documented three `#if PEACH_RESEARCH` blocks in `PeachApp.swift` (property, init's `todUserSettingsForBuild` let-fallback, `rebuildCoordinators`'s let-fallback) plus a (false) claim that the TOD `.contribute(...)` call was also gated. Acceptance-auditor review found the contribute-wrapping claim was inaccurate, and Blind/Edge-case reviewers flagged the per-rebuild allocation of `AppTimingOffsetDetectionUserSettings()` in the non-research branch. Direction from user: "flags deciding what goes into the build should only be handled in a central place, such as `DisciplineBootstrap`." All three `#if PEACH_RESEARCH` blocks in `PeachApp.swift` were removed; `todUserSettings` is now an unconditional `private let` mirroring `crmUserSettings`. The discipline-not-bootstrapped fact in `DisciplineBootstrap` is the sole gating mechanism — `TimingOffsetDetectionSession.contribute(to:userSettings:todUserSettings:)` registers a lifecycle entry that is unreachable in non-research builds because no `NavigationDestination.timingOffsetDetection` is reachable from the start screen. AC5 amended above to reflect this design (functional gating via `DisciplineBootstrap`, not literal source-code reference absence in `PeachApp.swift`).
  - **Cap idempotence latched in code, not just by trackingTask cancellation.** Blind/Acceptance/Edge-case reviewers flagged that `evaluatePlaybackPosition`'s cap check would re-fire `.repetitionCapReached` on every poll once `completedCycles >= maxRepetitions`, relying entirely on `trackingTask.cancel()` to stop further polls. The production path was safe; tests calling `evaluatePlaybackPosition` directly could re-fire. Introduced `private var didFireRepetitionCap: Bool = false`, guard at the cap check, reset at the start of every `beginNextTrial` and in `stopAll`. Not reset in `cancelTrackingAndReset` because that helper is invoked from `stopSequencerAtCap` immediately after the latch is set; resetting there would defeat the latch within the same poll.
  - **AC6 covered by a new test file.** `PeachTests/Training/TimingOffsetDetection/AppTimingOffsetDetectionUserSettingsTests.swift` exercises the UserDefaults round-trip with a temporary suite: missing key → default, stored `0` → default, stored `-3` → default, stored `7` → 7. The "Ask First" item that originally permitted skipping this test is now obsolete; the small test is cheap and the AC was otherwise unverified. Test file is `#if PEACH_RESEARCH`-gated to match the existing `TimingOffsetDetectionSettingsTests` envelope.
  - **One item deferred to `deferred-work.md` under "Story 80.2 Max-repetitions setting review (2026-06-02)":** stale `samplePosition` at new-trial start could fire the cap before any audio plays with `maxRepetitions == 1`. Property of the shared `BeatSequencer`'s post-`start()` reset latency, not introduced by 80.2; surfaces a new failure mode here. Coordinate with 80.0 D1 concurrency audit and 80.1 litDot-blip entry.
  - **Rejected with reasoning (not deferred):** off-by-one cap firing at cycle boundary (intentional — `maxRepetitions == N` means `N` full cycles play, cap fires at the buffer-fill boundary of cycle `N+1` which the chained `enqueueSequencerStop` silences within a polling tick); "cycle" vs. "beat" naming conflation (the 4-sixteenth pattern *is* one beat; one cycle = one beat is a load-bearing property of this discipline); `cap-stop discards failure callback` (intentional, spec I/O matrix row 1 explicitly specifies teardown-style no-op `onFailure`); `from(_:todUserSettings:)` only maps tempo + maxRepetitions (the other fields aren't user-configurable — feedbackDuration etc. keep their init defaults); `AppTimingOffsetDetectionUserSettings.defaults` is a mutable `var` (mirrors CRM's pre-existing shape; consistency over local cleanup); `MockTimingOffsetDetectionUserSettings.maxRepetitions` as `var` not matching the protocol's `{ get }` (mocks need to be writable for tests — universal pattern); `samplesPerBeat` not divisible by `subdivisionsPerBeat` accuracy drift (~70μs at production rates — sub-perceptual); Int overflow on 32-bit platforms (iOS is 64-bit only); double-stop on answer after cap (the chained `stopTask` was designed in 80.1 for exactly this back-to-back-stop pattern); `gridOrigin` not refreshed after early cap stop (existing 80.1 grid alignment behaviour, not changed by 80.2).

## Design Notes

**Cap fires from polling, not `nextBeat()`.** The sequencer batches `nextBeat()` calls in refills (cf. 80.1's silent-beat fallback), so beat-count overruns the actually-played cycles. The polling task's `samplePosition`-derived `globalSubdivisionIndex` is the only authority for *played* subdivisions.

**`playingPatternLoop` stays put.** A dedicated "cap reached, waiting for answer" state would duplicate every `playingPatternLoop` transition for `handleAnswer`/`stop`/`audioError`. Reusing the state and stopping the audio inside it keeps the reducer narrow; the visual delta (frozen vs. cycling dots) is 80.4.

**Defence in depth on `< 1`.** The `TimingOffsetDetectionSettings.precondition` is a programmer-error contract for direct constructors/test fixtures. The UserDefaults read is an external-input boundary — a corrupted value (`0`, negatives, future-migration glitch) clamps to the default rather than crashing.

## Verification

**Commands:**
- `bin/test.sh` — expected: all iOS tests pass.
- `bin/test.sh -p mac` — expected: all macOS tests pass.
- `bin/build.sh` and `bin/build.sh -p mac` — expected: no warnings introduced; the non-`PEACH_RESEARCH` configuration also builds clean (PeachApp's gating must hold).

**Manual checks:**
- In a Research build, set `UserDefaults.standard.set(2, forKey: "timingOffsetDetectionMaxRepetitions")` via the debugger before starting TOD; observe audio stop after two cycles and the trial complete only when a direction is submitted. Verify on both iOS and macOS.

## Suggested Review Order

**Cap-fire mechanism — read this first**

- New event + effect that turn the rep cap into a state-machine concern; reducer keeps state in `playingPatternLoop` so the user still owes a direction.
  [`TimingOffsetDetectionSession.swift:23`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift#L23)

- Reducer arm for `.repetitionCapReached` — no state change, single `.stopSequencerAtCap` effect.
  [`TimingOffsetDetectionSession.swift:62`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift#L62)

- Polling-tick cap detection — `completedCycles >= settings.maxRepetitions` guarded by `didFireRepetitionCap` so the latch is structural, not just a side effect of trackingTask cancellation.
  [`TimingOffsetDetectionSession.swift:351`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift#L351)

- The latch field, sibling to `lastPublishedSubdivisionIndex` (same polling-loop ownership).
  [`TimingOffsetDetectionSession.swift:139`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift#L139)

- Cap-stop helper — reuses the answer-stop's `cancelTrackingAndReset` preamble, diverges on the no-op `onFailure` (matches `stopAll` teardown semantics).
  [`TimingOffsetDetectionSession.swift:376`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift#L376)

- Latch reset on every trial begin — the only safe place; `cancelTrackingAndReset` cannot reset it (would defeat the latch within the same poll).
  [`TimingOffsetDetectionSession.swift:289`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift#L289)

- Latch reset on teardown for cleanliness.
  [`TimingOffsetDetectionSession.swift:465`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift#L465)

**Feature-local UserDefaults port — Epic 77 plugin model adoption**

- Port protocol — `{ get }` only; the production type owns the UserDefaults read.
  [`TimingOffsetDetectionUserSettings.swift:3`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionUserSettings.swift#L3)

- Production type with the missing/`< 1` → default clamp. Defence in depth for `precondition(maxRepetitions >= 1)` at the settings boundary.
  [`TimingOffsetDetectionUserSettings.swift:14`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionUserSettings.swift#L14)

- Feature-local key + default (20). Mirrors `ContinuousRhythmMatchingSettingsKeys`.
  [`TimingOffsetDetectionSettingsKeys.swift:3`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionSettingsKeys.swift#L3)

- `from(_:todUserSettings:)` factory — the single seam where the port's value enters the settings struct.
  [`TimingOffsetDetectionSettings.swift:26`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSettings.swift#L26)

- `precondition(maxRepetitions >= 1)` — programmer-error contract for direct constructors.
  [`TimingOffsetDetectionSettings.swift:18`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSettings.swift#L18)

- Lifecycle contribution gains the second port parameter — mirrors CRM exactly.
  [`TimingOffsetDetectionLifecycleContribution.swift:5`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionLifecycleContribution.swift#L5)

**App-level wiring — `DisciplineBootstrap` is the only gating point**

- `todUserSettings` is an unconditional `private let`, mirroring `crmUserSettings`. No `#if PEACH_RESEARCH` here — the build flag belongs in `DisciplineBootstrap` per Michael's direction.
  [`PeachApp.swift:41`](../../Peach/App/PeachApp.swift#L41)

- `buildCoordinators` takes the port unconditionally; both call sites pass `todUserSettings` directly.
  [`PeachApp.swift:511`](../../Peach/App/PeachApp.swift#L511)

- Preview wiring gets a `StubTimingOffsetDetectionUserSettings`; the stub returns the default so previews behave like a fresh user.
  [`PreviewDefaults.swift:44`](../../Peach/App/PreviewDefaults.swift#L44)

**Tests — I/O matrix coverage + reducer pinning + AC6**

- Reducer table: `playingPatternLoop + .repetitionCapReached → playingPatternLoop, .stopSequencerAtCap`.
  [`TimingOffsetDetectionReduceTests.swift:120`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionReduceTests.swift#L120)

- Reducer table: spurious `.repetitionCapReached` outside the loop is a no-op (pins the default case).
  [`TimingOffsetDetectionReduceTests.swift:133`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionReduceTests.swift#L133)

- I/O matrix row 1 — cap fires once, state stays, observer not notified.
  [`TimingOffsetDetectionSessionTests.swift:838`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionSessionTests.swift#L838)

- I/O matrix row 2 — answer after cap completes the trial through the normal path.
  [`TimingOffsetDetectionSessionTests.swift:881`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionSessionTests.swift#L881)

- I/O matrix row 4 — `maxRepetitions == 1` stops the sequencer after exactly one full cycle (restored pre-80.1 semantics).
  [`TimingOffsetDetectionSessionTests.swift:936`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionSessionTests.swift#L936)

- I/O matrix row 5 — very high cap never fires; behaviour matches the uncapped loop.
  [`TimingOffsetDetectionSessionTests.swift:969`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionSessionTests.swift#L969)

- AC6 round-trip — missing key, `0`, negative, and a valid stored value through a per-test `UserDefaults` suite.
  [`AppTimingOffsetDetectionUserSettingsTests.swift:16`](../../PeachTests/Training/TimingOffsetDetection/AppTimingOffsetDetectionUserSettingsTests.swift#L16)

- Settings factory reads the port; default constructor reads `defaultMaxRepetitions`.
  [`TimingOffsetDetectionSettingsTests.swift:43`](../../PeachTests/Core/Training/TimingOffsetDetectionSettingsTests.swift#L43)

- Lifecycle coordinator wiring — `MockTimingOffsetDetectionUserSettings()` threaded through both registry call sites.
  [`TrainingLifecycleCoordinatorTests.swift:510`](../../PeachTests/App/TrainingLifecycleCoordinatorTests.swift#L510)

**Audit trail**

- Spec Change Log — initial implementation deltas, plus the step-04 review patches (this iteration) covering AC5 amendment, `#if` centralisation, cap idempotence latch, AC6 test addition.
  [`spec-80-2-max-repetitions-setting.md:101`](./spec-80-2-max-repetitions-setting.md#L101)

- Deferred-work entry — stale `samplePosition` at new-trial start can fire the cap before audio plays with `maxRepetitions == 1`. Coordinate with 80.0 D1 and 80.1 litDot-blip.
  [`deferred-work.md`](./deferred-work.md)
