---
title: 'Story 86.1: Chromatic Construction domain types, session, and path strategies'
type: 'feature'
created: '2026-06-12'
status: 'ready-for-dev'
baseline_commit: 'e33c2c877a47222bc5faa0b89c495daf01607ebf'
context:
  - '{project-root}/docs/planning-artifacts/chromatic-construction-discipline-direction.md'
  - '{project-root}/docs/brainstorming/brainstorming-session-2026-06-12.md'
  - '{project-root}/docs/planning-artifacts/epics.md'
  - '{project-root}/docs/project-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem.** Peach's existing pitch disciplines (`PitchDiscrimination`, `PitchMatching`) train detection and tuning of a *single* cent relationship against a fixed reference. None of them train the production of *chained* equal-cent steps across a span — the cognitive skill underlying chromatic stepping (Wagner, Liszt, jazz, atonal music; equal-tempered semitones strung end to end with no diatonic skeleton or consonant landmarks to anchor on). The 2026-06-12 brainstorm with Adam converged on a *Construct* discipline: the user walks slot by slot from a lower anchor to an upper anchor, placing each slot at one target-cent step from the previous, with cumulative drift as the discipline-defining failure mode. The locked design direction is in `docs/planning-artifacts/chromatic-construction-discipline-direction.md`.

This story implements the **pure-Swift core** of the discipline: domain primitives (`Anchor`, `Path`, `Slot`, `Ladder`), the next-path strategy protocol with two monotonic conformances, and the session state machine. No SwiftUI. No registration. No screen. Story 86.2 picks up everything view-, lifecycle-, and registration-related.

**Approach.** Introduce five new files in `Peach/Training/ChromaticConstruction/` that together specify the discipline's behavioural contract:

1. `Anchor.swift` — value type wrapping `MIDINote` with `Frequency` derivation via `TuningSystem`.
2. `Slot.swift` — value type holding slot index, state (`pending | active | committed`), and (when committed) the user's `placedCents` offset from the lower anchor.
3. `Ladder.swift` — value type holding `lowerAnchor`, `upperAnchor`, `outerCents`, `path: [Direction]` (reuses the existing `Core/Music/Direction` enum), `targetStepCents`. Constructor validates that the tuning system is equal-tempered and that the anchor pair matches the outer interval / direction.
4. `NextPathStrategy.swift` (protocol) + `MonotonicAscendingPath.swift` + `MonotonicDescendingPath.swift` (conformances) — generate a `Path` for a given `outerCents` and target step. Both initial conformances produce a uniform-direction sequence of length `outerCents / targetStepCents`.
5. `ChromaticConstructionSession.swift` — the `TrainingSession`-conforming `@Observable` class implementing the state machine from the direction document. Implicit final-slot submit per the 2026-06-12 design lock-in. `ChromaticConstructionSettings.swift` co-located, value-type snapshot constructed at `start()` time.

The state machine has three live states — `.idle`, `.walking(activeSlotIndex:committed:ladder:directionPolicy:)`, `.showingResult(ladder:committed:)` — and a `.pause()`/`.resume()`/`.stop()` discipline mirroring `TimingOffsetDetectionSession`. The lossy step-back is implemented as a single event (`stepBack`) that drops the immediately previous slot back to `.active` and resets every later slot to `.pending`. The implicit submit is encoded as a guard inside the `place(cents:)` handler: when `activeSlotIndex == ladder.slotCount`, the slot commits and the state advances to `.showingResult` in one step. No `awaitingSubmit` intermediate.

The session takes a `NotePlayer` injected at construction; it never instantiates audio infrastructure. Audio-stop sequencing follows the project's `scheduleStopAll()` discipline (`[[project_context]]`: "Sessions and other synchronous callers MUST use `scheduleStopAll()`").

**Design principle.** The discipline trains *equal-cent stepping*, not "12-TET semitones" — the 100-cent target is one parameterization, not a hard-coded constant. Every cent computation is pure arithmetic on `Cents`; `TuningSystem` participates only to resolve the two anchor `MIDINote` values to `Frequency` for playback. Hard-coded `100` anywhere outside a single default-value declaration is a bug.

## Boundaries & Constraints

**Always:**
- Domain types use existing `Core/Music/` value types — `MIDINote`, `Cents`, `Frequency`, `Direction`, `TuningSystem`, `Duration` — per `[[feedback_domain_types_in_specs]]`. Raw `Double`/`Int`/`String` appears only at the literal `UserDefaults` boundary (none in this story) or SwiftData `@Model` stored properties (none in this story).
- `Ladder.init` validates `tuningSystem == .equalTemperament` and rejects other systems with a typed error. Equal-cent stepping inside an unequal-temperament musical context is musically incoherent and is gated at the type boundary — see `[chromatic-construction-discipline-direction.md](../planning-artifacts/chromatic-construction-discipline-direction.md) § Tuning-system constraint`.
- `targetStepCents` defaults to `Cents(100.0)` but is a constructor parameter, never hard-coded inside path generation, the session, or the strategies. The path length and the cent-step math derive from `outerCents` and `targetStepCents` together.
- `Path` is `typealias Path = [Direction]`. The model carries meandering-capable shape from day one; only the two monotonic strategies are registered in this story.
- `NextPathStrategy` is a feature-local protocol in `Peach/Training/ChromaticConstruction/`, not in `Core/`. It mirrors the per-discipline strategy split already established by `NextPitchStrategy`, `NextRhythmOffsetDetectionStrategy` (`[[feedback_symmetric_protocol_design]]`).
- Step-back is single-slot and forward-lossy: dropping slot K back to `.active` resets slots K+1...N to `.pending`. The slot at K's `placedCents` value is preserved at re-activation as the slider's starting position so the user does not lose their prior intent unless they overwrite it.
- `ChromaticConstructionSession` conforms to `TrainingSession` with the state-preservation contract from `Peach/Core/TrainingSession.swift`: `pause()` cancels in-flight tasks and stops audio but preserves `currentLadder`, `committed`, `activeSlotIndex`; `resume()` re-plays the active-slot orienting cue; `stop()` returns to `.idle`. `isIdle` stays `false` while paused.
- Audio playback uses `scheduleStopAll()` for synchronous stop commits (`[[project_context]]`: "synchronous-commit only enforces order on synchronous code paths"). The session never writes `Task { try? await notePlayer.stopAll() }`.
- `ChromaticConstructionSettings` is the value-type start-time snapshot, constructed via a `.from(userSettings:, outerCents:, lowerAnchor:, directionPolicy:)` factory mirroring `TimingOffsetDetectionSettings.from(...)`. Defaults: `outerCents = Cents(700.0)` (P5), `lowerAnchor = MIDINote(60)` (C4), `directionPolicy = .mix`, `targetStepCents = Cents(100.0)`.
- `ChromaticConstructionDirectionPolicy` is a feature-local enum: `case ascending`, `case descending`, `case mix`. `mix` selects a random direction per trial via a Sendable RNG injected into the session (see *I/O matrix*).
- All new files import only `Foundation` (and `Observation` for the session). No `SwiftUI`, no `UIKit`, no `Charts`, no third-party packages. Per `[[project_context]]`: Core/Music conventions, feature-directory imports follow the same rule.
- Pre-commit gate: `bin/test.sh && bin/test.sh -p mac` AND `bin/test.sh --research && bin/test.sh --research -p mac` — all four schemes green. Types defined in this story must compile in every configuration (the `PEACH_RESEARCH` gate is at the *registration* site in 86.2; the types themselves are unconditional, per `[[project_context]]`'s gating-mechanism rules).
- Tests are Swift Testing (`@Test`, `@Suite`, `#expect()`), one test file per source file mirroring source structure under `PeachTests/Training/ChromaticConstruction/`, struct-based suites, every `@Test` `async`, behavioural descriptions per `[[project_context]]` testing rules.
- Sprint-status key `86-1-chromatic-construction-domain-and-session` flips to `in-progress` on start and `done` after review per `[[feedback_update_status_after_review]]`.
- Music-domain consultation: invoke `/agent-music-domain-expert` (Adam) at the start of Task 2 (protocol-shape lock-in) per `[[reference_music_domain_expert]]`. Adam framed the discipline in the brainstorm; the consultation here is targeted at *protocol-shape* questions — does `NextPathStrategy` have the right surface area for the deferred meandering case, does the slot-state lifecycle match motor-learning expectations, are there equal-division failure modes the unit tests should cover.

**Ask First:**
- If the protocol consultation surfaces a need for the slider-range mode (monotonic vs. full per slot — open design decision in the direction document) to be encoded at the session/contract layer rather than left to the view, pause and confirm. **Default plan:** the session exposes the *previous-committed cents* and the *destination-anchor cents* as observable derived values; the view layer (86.2) decides what range to clamp the slider to. The session does not enforce a clamp, so changing the slider range later is a view change, not a session-contract change.
- If Adam recommends a shape change for `NextPathStrategy` (e.g., the strategy returning `Ladder` rather than just `Path`, so anchor selection co-locates with path generation), pause and present the dependency map before proceeding. **Default plan:** the strategy returns `Path` only; ladder construction lives in a `LadderGenerator` helper that combines a chosen `Anchor`, `outerCents`, and a strategy-produced `Path`.
- If the equal-tempered gate on `Ladder.init` is wider than `tuningSystem == .equalTemperament` — e.g., a future N-TET system that is equal-cent by construction but not the current `.equalTemperament` case — pause and surface before locking. **Default plan:** for this cut, `equalTemperament` is the only allowed case; the typed error names the gating rule and references the direction document.

**Never:**
- No SwiftData `@Model` types. No `TrainingDataStore` calls. No observer protocol. No persistence path. The `ChromaticConstructionPayload` value type lives in 86.2 with the discipline registration; this story does not introduce it.
- No view, no SwiftUI imports, no `@Entry` environment key. Those land in 86.2.
- No `NavigationDestination` case, no `TrainingDisciplineID`, no `DisciplineBootstrap` change, no `PeachApp.swift` wiring. All registration is in 86.2.
- No `@AppStorage`, no `SettingsKeys`, no `UserSettings` protocol extension. The discipline ships with view-local controls only in this cut (per epic's *Scope* section). Settings persistence is explicitly deferred per the direction document.
- No statistics, no `StatisticsKey` extensions, no `PerceptualProfile` integration, no `ProgressTimeline` wiring. Deferred per the direction document.
- No `Pitch` struct anywhere — it was deleted per `[[project_context]]`'s *Never Do This* list. Use `MIDINote` for the anchor and `TuningSystem.frequency(for:referencePitch:)` for the bridge.
- No `print()` for diagnostics. Use `os.Logger` with subsystem `"com.peach.app"` and category `"ChromaticConstructionSession"` for lifecycle events.
- No third-party dependencies. Zero new Swift Package additions.
- No widening of `TuningSystem` to add an `nTET`/`19TET`/`24TET` case. Future-equal-division support is deferred per the direction document's *Future expansion*.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| `Ladder.init` — equal-tempered, ascending | `lower=MIDINote(60)`, `upper=MIDINote(67)`, `outerCents=700`, `path=[.up]*7`, `targetStep=100`, `tuningSystem=.equalTemperament` | `Ladder` with `slotCount == 7 - 1 == 6` (interior slots only — upper anchor is fixed) | N/A |
| `Ladder.init` — equal-tempered, descending | `lower=MIDINote(72)`, `upper=MIDINote(60)`, `outerCents=-1200`, `path=[.down]*12`, `targetStep=100`, `tuningSystem=.equalTemperament` | `Ladder` with `slotCount == 11` interior slots descending | N/A |
| `Ladder.init` — non-equal temperament | `tuningSystem=.justIntonation` (or any future non-equal case) | throws `ChromaticConstructionError.tuningSystemNotEqualTempered(.justIntonation)` | typed throw |
| `Ladder.init` — outer interval mismatch | `lower=MIDINote(60)`, `upper=MIDINote(67)` (P5 = 700¢), `outerCents=1200` | throws `ChromaticConstructionError.outerCentsMismatchesAnchors(declared: 1200, actual: 700)` | typed throw |
| `Ladder.init` — path length mismatch | `outerCents=700`, `targetStep=100`, `path.count=5` (should be 7) | throws `ChromaticConstructionError.pathLengthMismatch(expected: 7, actual: 5)` | typed throw |
| `Ladder.init` — non-monotonic path with monotonic ladder | `path=[.up, .down, .up, ...]` declared but `outerCents > 0` | accepted; `Ladder` does not enforce path monotonicity (meandering-ready by construction). Direction consistency is the strategy's responsibility, not the ladder's. | N/A |
| `Ladder.slotCount` | any valid ladder | returns `path.count - 1` (slots are *between* steps; final step lands on the upper anchor) | N/A |
| `Ladder.targetCents(forSlotIndex:)` | ascending P5, slot index 3 | returns `Cents(300.0)` (lower-anchor-relative; 3 × 100¢) | N/A |
| `Ladder.targetCents(forSlotIndex:)` | descending octave, slot index 5 | returns `Cents(-500.0)` (lower-anchor-relative; negative for descending) | N/A |
| `MonotonicAscendingPath.path(forOuterCents:targetStep:)` | `outerCents=700`, `targetStep=100` | returns `[.up, .up, .up, .up, .up, .up, .up]` (length 7) | N/A |
| `MonotonicAscendingPath.path(forOuterCents:targetStep:)` | `outerCents=-700` (descending requested via positive strategy) | precondition trips — strategy contract requires `outerCents.sign` matches the strategy's direction | crash (programmer error; strategy selection is the caller's responsibility) |
| `MonotonicAscendingPath.path(forOuterCents:targetStep:)` | `outerCents=750`, `targetStep=100` (non-integer division) | precondition trips — `outerCents.remainder(dividingBy: targetStep) ≠ 0` | crash (caller must align outerCents to targetStep multiples) |
| `MonotonicDescendingPath.path(forOuterCents:targetStep:)` | `outerCents=-700`, `targetStep=100` | returns `[.down, .down, .down, .down, .down, .down, .down]` (length 7) | N/A |
| `Slot` initial state | new slot at index K | `Slot(index: K, state: .pending, placedCents: nil)` | N/A |
| `Slot.commit(at:)` | pending or active slot, cent value provided | returns a new `Slot` with state `.committed` and `placedCents = ⌧given value⌧`; preserves index | N/A |
| `Slot.reactivate(preservingPlacedCents:)` | committed or pending slot | returns a new `Slot` with state `.active`; `placedCents` preserved (so view can use as slider starting position) | N/A |
| `Session.start(settings:)` from `.idle` | valid settings, ascending policy | transitions to `.walking(activeSlotIndex: 1, committed: [], ladder: …, directionPolicy: .ascending)`; plays the lower anchor's `Frequency` as the orienting cue for slot 1 | N/A |
| `Session.start(settings:)` — non-equal tuning | `settings.tuningSystem == .justIntonation` (via `userSettings`) | `Ladder.init` throws; session remains `.idle`; logs `.warning`; the screen is responsible for surfacing this to the user (out of scope for this story) | typed throw caught and logged |
| `Session.place(cents:)` while walking, K < slotCount | active slot K | active slot K commits with `placedCents = cents`; activeSlotIndex advances to K+1; plays the just-committed pitch's `Frequency` as the orienting cue for slot K+1 | N/A |
| `Session.place(cents:)` while walking, K == slotCount | final active slot | final slot commits; state advances to `.showingResult(ladder:, committed:)`; no orienting cue (the result UI takes over) | N/A |
| `Session.stepBack()` while walking, activeSlotIndex == 1 | no previous slot to step back to | no-op; state unchanged; `os.Logger` `.debug` entry | N/A |
| `Session.stepBack()` while walking, activeSlotIndex > 1 | activeSlotIndex K, committed [s1...s(K-1)] | transitions to `.walking(activeSlotIndex: K-1, committed: [s1...s(K-2)], …)`; the slot at K-1 re-enters `.active` with its previous `placedCents` preserved; the slot at K and any later slots in the view-side rendering reset to `.pending`; plays the lower anchor of K-1 (its predecessor's committed pitch, or the lower anchor for K-1 == 1) as the orienting cue | N/A |
| `Session.stepBack()` while in `.showingResult` | result shown after final commit | transitions back to `.walking(activeSlotIndex: slotCount, committed: [s1...s(slotCount-1)], …)`; the final slot re-enters `.active` with its previously placed value preserved. Result UI dismissed. | N/A |
| `Session.nextTrial()` while in `.showingResult` | request next trial | transitions to `.idle` (the screen calls `start(settings:)` again with a fresh ladder); audio stops | N/A |
| `Session.nextTrial()` while walking | invalid event for state | no-op; `os.Logger` `.debug` entry | N/A |
| `Session.pause()` while walking | active state K | cancels in-flight audio tasks; calls `notePlayer.scheduleStopAll()`; preserves `currentLadder`/`committed`/`activeSlotIndex`/`directionPolicy`; `isIdle` stays `false` | N/A |
| `Session.resume()` after pause | session preserved | re-engages the trial; re-plays the active-slot orienting cue (predecessor pitch or lower anchor); no state mutation beyond the audio re-engagement | N/A |
| `Session.stop()` from any non-idle state | running session | cancels in-flight tasks; calls `notePlayer.scheduleStopAll()`; transitions to `.idle`; clears `currentLadder`/`committed`/`activeSlotIndex` | N/A |
| `ChromaticConstructionSettings.from(userSettings:outerCents:lowerAnchor:directionPolicy:)` — ascending | `userSettings.tuningSystem=.equalTemperament`, `outerCents=700`, `lowerAnchor=MIDINote(60)`, `policy=.ascending` | `Settings` with `ladder.upperAnchor=MIDINote(67)` (60 + 7 semitones up), `directionPolicy=.ascending`, `targetStepCents=Cents(100)` | N/A |
| `ChromaticConstructionSettings.from(…)` — descending | same lower anchor, `policy=.descending`, `outerCents=700` | `Settings` with anchors *flipped* — `lowerAnchor=MIDINote(53)` (60 - 7), `upperAnchor=MIDINote(60)`, but the *starting* anchor for the walk is `MIDINote(60)`; the destination is `MIDINote(53)`. **Default plan, confirm in Task 2:** the *Anchor* terminology in the direction document is *start/destination*, not *lower/upper* — the spec uses lower/upper to match the direction-document field names but the strategy's direction determines which anchor the walk starts from. | N/A |
| `ChromaticConstructionSettings.from(…)` — mix policy | `policy=.mix` | settings encode `.mix`; the session resolves to `.ascending` or `.descending` per-trial via the injected RNG | N/A |
| `MonotonicAscendingPath` vs. `MonotonicDescendingPath` selection — given `.mix` policy | injected RNG returns `0` (ascending) or `1` (descending) | session uses `MonotonicAscendingPath` or `MonotonicDescendingPath` respectively for the next trial | N/A |
| RNG injection — default | unspecified at session construction | session uses `SystemRandomNumberGenerator()` per Swift's stdlib recommendation; deterministic-RNG injection point present for test seeding | N/A |

</frozen-after-approval>

## Code Map

**Production:**

- `Peach/Training/ChromaticConstruction/Anchor.swift` — **NEW**. `struct Anchor: Hashable, Sendable { let note: MIDINote; func frequency(in tuningSystem: TuningSystem, referencePitch: Frequency) -> Frequency }`. No exposure of raw `Int` — uses `MIDINote` throughout.
- `Peach/Training/ChromaticConstruction/Slot.swift` — **NEW**. `struct Slot: Hashable, Sendable { let index: Int; let state: SlotState; let placedCents: Cents? }`. `enum SlotState: Hashable, Sendable { case pending, active, committed }`. Methods: `func committing(at cents: Cents) -> Slot`, `func reactivated() -> Slot`, `func pendingAgain() -> Slot`. Plain value transitions; no behaviour beyond state mutation.
- `Peach/Training/ChromaticConstruction/Path.swift` — **NEW**. `typealias Path = [Direction]`. (Documented at the typealias site that the array semantically represents a directed step sequence; `Direction` is reused from `Core/Music/Direction.swift`.)
- `Peach/Training/ChromaticConstruction/Ladder.swift` — **NEW**. `struct Ladder: Hashable, Sendable { let lowerAnchor: Anchor; let upperAnchor: Anchor; let outerCents: Cents; let path: Path; let targetStepCents: Cents; let tuningSystem: TuningSystem }`. `init throws(ChromaticConstructionError)` validates tuning system, outer-cents/anchor agreement, and path length / step count consistency. Computed: `var slotCount: Int { path.count - 1 }`; `func targetCents(forSlotIndex k: Int) -> Cents` returns the lower-anchor-relative target cents for slot k (positive for ascending, negative for descending). Co-locates `enum ChromaticConstructionError: Error, Equatable { case tuningSystemNotEqualTempered(TuningSystem); case outerCentsMismatchesAnchors(declared: Cents, actual: Cents); case pathLengthMismatch(expected: Int, actual: Int) }`.
- `Peach/Training/ChromaticConstruction/NextPathStrategy.swift` — **NEW**. `protocol NextPathStrategy: Sendable { func path(forOuterCents: Cents, targetStep: Cents) -> Path }`. (Following `NextPitchStrategy` and `NextRhythmOffsetDetectionStrategy`'s shape; one-method functional protocol.)
- `Peach/Training/ChromaticConstruction/MonotonicAscendingPath.swift` — **NEW**. `struct MonotonicAscendingPath: NextPathStrategy, Sendable {}`. Implementation precondition-traps on negative `outerCents` and on `outerCents.remainder(dividingBy: targetStep) ≠ 0`; otherwise returns `Array(repeating: Direction.up, count: stepCount)` where `stepCount = Int(outerCents / targetStep)`.
- `Peach/Training/ChromaticConstruction/MonotonicDescendingPath.swift` — **NEW**. Mirror of `MonotonicAscendingPath` for negative `outerCents`; emits `.down`.
- `Peach/Training/ChromaticConstruction/ChromaticConstructionDirectionPolicy.swift` — **NEW**. `enum ChromaticConstructionDirectionPolicy: Hashable, Sendable, CaseIterable { case ascending, descending, mix }`. Display names are added in 86.2 (or co-located here as `LocalizedStringResource` properties; default plan: define here, exercise in 86.2's localization sweep).
- `Peach/Training/ChromaticConstruction/ChromaticConstructionSettings.swift` — **NEW**. `struct ChromaticConstructionSettings: Sendable { let ladder: Ladder; let directionPolicy: ChromaticConstructionDirectionPolicy; let referencePitch: Frequency }`. Factory: `static func from(userSettings: any UserSettings, outerCents: Cents, lowerAnchor: MIDINote, directionPolicy: ChromaticConstructionDirectionPolicy, strategySelector: (ChromaticConstructionDirectionPolicy, inout some RandomNumberGenerator) -> any NextPathStrategy = { defaultStrategy(for: $0, rng: &$1) }, rng: inout some RandomNumberGenerator = …) throws(ChromaticConstructionError) -> ChromaticConstructionSettings`. Resolves the strategy per the policy + RNG, derives `upperAnchor` from `lowerAnchor + outerCents` (via `MIDINote + Int` arithmetic — note: `outerCents / 100 == semitones` in 12-TET, and 12-TET is enforced by `Ladder.init`), reads `referencePitch` and `tuningSystem` from `userSettings`, and constructs the ladder. (`defaultStrategy(for:rng:)` is a free function in the same file: returns `MonotonicAscendingPath` / `MonotonicDescendingPath` / a randomized pick.)
- `Peach/Training/ChromaticConstruction/ChromaticConstructionSession.swift` — **NEW**. `@Observable final class ChromaticConstructionSession: TrainingSession { … }`. State enum mirrors the direction document; events `start`, `place(cents:)`, `stepBack`, `nextTrial`, `pause`, `resume`, `stop`; effects audio playback via injected `NotePlayer`. Constructor: `init(notePlayer: any NotePlayer, rng: any RandomNumberGenerator = SystemRandomNumberGenerator())`. Uses `os.Logger(subsystem: "com.peach.app", category: "ChromaticConstructionSession")`. `pause()`/`resume()`/`stop()` follow `TimingOffsetDetectionSession`'s patterns including audio-stop chain discipline (`scheduleStopAll()` synchronous commit).

**Tests:** mirror source structure under `PeachTests/Training/ChromaticConstruction/`.

- `PeachTests/Training/ChromaticConstruction/AnchorTests.swift` — `frequency(in:referencePitch:)` returns the same `Frequency` as `TuningSystem.frequency(for:referencePitch:)` for the same `MIDINote`; ascending vs. descending anchor pairs derive consistently.
- `PeachTests/Training/ChromaticConstruction/SlotTests.swift` — initial pending state; commit transitions; reactivate preserves `placedCents`; pendingAgain clears `placedCents`.
- `PeachTests/Training/ChromaticConstruction/LadderTests.swift` — every I/O matrix row whose subject is `Ladder.*`: valid construction (P5 ascending, octave descending); tuning-system rejection (justIntonation throws); outer-cents/anchor mismatch throws; path length mismatch throws; non-monotonic path accepted; `slotCount` derivation; `targetCents(forSlotIndex:)` for ascending and descending.
- `PeachTests/Training/ChromaticConstruction/MonotonicAscendingPathTests.swift` — outputs for representative outer intervals (200 → 2 steps, 700 → 7 steps, 1200 → 12 steps); precondition trip on negative outer cents; precondition trip on non-integer division (`outerCents=750, targetStep=100`).
- `PeachTests/Training/ChromaticConstruction/MonotonicDescendingPathTests.swift` — mirror.
- `PeachTests/Training/ChromaticConstruction/ChromaticConstructionSettingsTests.swift` — `from(…)` ascending / descending / mix; reference-pitch invariance (cent math agrees across two settings that differ only in `userSettings.referencePitch`).
- `PeachTests/Training/ChromaticConstruction/ChromaticConstructionSessionTests.swift` — state machine coverage for every event × state pair in the I/O matrix; `pause()`/`resume()`/`stop()` semantics including state preservation; `stepBack()` lossy reset (slots K+1..N return to `.pending`, `placedCents` cleared on those slots); implicit final-slot submit (`place(cents:)` at `K == slotCount` skips `.awaitingSubmit` and lands directly in `.showingResult`); session uses `MockNotePlayer` with `instantPlayback` mode and asserts on `playCallCount` / `lastFrequency` for the orienting-cue playback; deterministic RNG fixture for `.mix` policy verifies both directions are reachable.
- `PeachTests/Mocks/MockNotePlayer.swift` — **EXISTING.** No new test seam required for this story; if a new mock affordance is needed (e.g., `onScheduleStopAllCalled`), add it following the existing mock contract per `[[project_context]]`.

**No-op for this story:**

- `Peach/App/Training/DisciplineBootstrap.swift` — touched in 86.2.
- `Peach/App/Training/DisciplineIDs.swift` — touched in 86.2.
- `Peach/Core/NavigationDestination.swift` — touched in 86.2.
- `Peach/App/PeachApp.swift` — touched in 86.2.
- `Localizable.xcstrings` — touched in 86.2 (no user-facing strings introduced by this story; `Direction.displayName`'s existing "Up"/"Down" strings are reused via the existing localization; `ChromaticConstructionDirectionPolicy` display strings are added in 86.2 when the view-local control is built).

## Tasks & Acceptance

**Execution:**

- [ ] **Task 1 — Sprint-status start.** Flip `86-1-chromatic-construction-domain-and-session: backlog → in-progress` in `sprint-status.yaml`; flip `epic-86: backlog → in-progress`; update `last_updated` to today's date.
- [ ] **Task 2 — Music-domain consultation (must precede protocol drafting).** Invoke `/agent-music-domain-expert` (Adam) with the direction-document section *Core concepts* and the I/O matrix above. Ask three targeted questions: (a) does `NextPathStrategy`'s `path(forOuterCents:targetStep:)` signature give meandering strategies enough information to do their job (i.e. is `outerCents + targetStep` sufficient input, or do they need a `complexity` or `seed` parameter)? (b) is the slot-state lifecycle `pending → active → committed` (with lossy reactivate-back-to-active resetting forward) consistent with motor-learning failure modes, or should there be a separate `revisiting` state? (c) does the cent-step math assume any failure mode (rounding, accumulation) that unit tests should explicitly cover? Append Adam's findings to a *Consultation Findings* section below this Tasks list. **If Adam recommends a signature change to `NextPathStrategy`, halt and surface before drafting the protocol.**
- [ ] **Task 3 — Domain primitives (tests-first).** Write `AnchorTests`, `SlotTests`, `LadderTests`, `MonotonicAscendingPathTests`, `MonotonicDescendingPathTests` per the Code Map. Then implement `Anchor.swift`, `Slot.swift`, `Path.swift` (typealias), `Ladder.swift` (including `ChromaticConstructionError`), `NextPathStrategy.swift`, `MonotonicAscendingPath.swift`, `MonotonicDescendingPath.swift`, `ChromaticConstructionDirectionPolicy.swift`. Run the test suites until green.
- [ ] **Task 4 — Settings factory (tests-first).** Write `ChromaticConstructionSettingsTests` per the Code Map. Then implement `ChromaticConstructionSettings.swift`. The reference-pitch-invariance test exercises hidden-assumption #9 from the direction document: change `userSettings.referencePitch` between two settings constructions with the same `outerCents` / `lowerAnchor` and assert the cent math is identical (only the anchor frequencies differ).
- [ ] **Task 5 — Session state machine (tests-first).** Write `ChromaticConstructionSessionTests` per the Code Map. Then implement `ChromaticConstructionSession.swift`. State machine effects play through the injected `MockNotePlayer`. The `stepBack` test uses a deterministic RNG fixture and a slot-count-2 ladder (P3 = 300¢, slots 1 and 2) to cover the K==1 no-op and the K==2 → K==1 reset transitions without combinatorial blowup. `pause`/`resume`/`stop` tests follow the patterns in `PitchDiscriminationSessionTests` and `TimingOffsetDetectionSessionTests`.
- [ ] **Task 6 — Pre-commit gates.** Run `bin/test.sh && bin/test.sh -p mac` and `bin/test.sh --research && bin/test.sh --research -p mac`. All four green; no new warnings; strict-concurrency build clean.
- [ ] **Task 7 — `/simplify-code` pass.** Per `[[project_context]]`'s skills section: mandatory after any code change. Run `/simplify-code` on the diff; apply or reject findings per `[[feedback_fix_review_findings]]`.
- [ ] **Task 8 — Sprint-status finalize.** Flip `86-1-chromatic-construction-domain-and-session: in-progress → review` for review; after review, `review → done` per `[[feedback_update_status_after_review]]`.

**Acceptance Criteria:**

- **Ladder construction.** Given `Ladder.init(lowerAnchor:upperAnchor:outerCents:path:targetStepCents:tuningSystem:)`, all rows from the I/O matrix labeled `Ladder.init — *` produce the documented output (typed throw or accepted ladder).
- **Path generation.** `MonotonicAscendingPath().path(forOuterCents: Cents(700), targetStep: Cents(100))` returns `[.up]` of length 7. `MonotonicDescendingPath().path(forOuterCents: Cents(-700), targetStep: Cents(100))` returns `[.down]` of length 7. Precondition trips on direction mismatch and on non-integer division are asserted via XCTest crash assertions or via Swift Testing's `withKnownIssue { … }` — choose the in-repo precedent; if no precedent exists, document the omission in the Spec Change Log per `[[feedback_fix_review_findings]]`.
- **Session state machine.** Every (state, event) pair in the I/O matrix's `Session.*` rows produces the documented transition and side effects, verified through `MockNotePlayer` interaction. Step-back from slot K resets slots K+1..N to `.pending`. Implicit final-slot submit lands directly in `.showingResult` without an intermediate state. `pause` preserves `currentLadder`/`committed`/`activeSlotIndex`; `resume` re-plays the active-slot orienting cue. `stop` returns to `.idle`.
- **Reference-pitch invariance.** Two `ChromaticConstructionSettings` constructed from `userSettings` differing only in `referencePitch` produce identical `Ladder.targetCents(forSlotIndex:)` outputs for all slot indices (the anchor frequencies differ; the cent math does not). Asserted by `ChromaticConstructionSettingsTests`.
- **Tuning-system gating.** `Ladder.init(tuningSystem: .justIntonation, …)` throws `ChromaticConstructionError.tuningSystemNotEqualTempered(.justIntonation)`. Asserted by `LadderTests`.
- **Pure-Swift module.** `grep -rn "import SwiftUI\|import UIKit\|import Charts" Peach/Training/ChromaticConstruction/` returns zero matches. `grep -rn "import SwiftData" Peach/Training/ChromaticConstruction/` returns zero matches.
- **No registration leakage.** `grep -rn "ChromaticConstruction" Peach/App/ Peach/Core/NavigationDestination.swift` returns zero matches (registration is 86.2's job).
- **Pre-commit gates.** All four schemes green: Debug × {iOS, macOS} and Research × {iOS, macOS}. No new compiler warnings. Strict-concurrency build clean.
- **No third-party dependencies.** `Package.resolved` / project's package list unchanged.

## Dev Notes

### Domain-type reuse

- **`Direction`** (`Peach/Core/Music/Direction.swift`) — existing enum `case up, case down`. Reused for `Path` element type. The existing `displayName` ("Up"/"Down" — already localized) is suitable for any future view-side use.
- **`Cents`** (`Peach/Core/Music/Cents.swift`) — existing value type. All cent arithmetic uses this. Per `[[project_context]]`, raw `Double` is permitted only at the literal `UserDefaults` boundary (none in this story).
- **`MIDINote`** (`Peach/Core/Music/MIDINote.swift`) — existing value type, `nonisolated`. Used for anchor representation. Arithmetic `MIDINote + Int` exists and is used to derive the upper anchor from the lower anchor plus the outer-interval semitone count.
- **`Frequency`** (`Peach/Core/Music/Frequency.swift`) — existing value type. Returned by `Anchor.frequency(in:referencePitch:)`. Used for `NotePlayer.play(frequency:)`.
- **`TuningSystem`** (`Peach/Core/Music/TuningSystem.swift`) — existing enum. `.equalTemperament` is the only allowed value for this discipline. `.justIntonation` is rejected by `Ladder.init`.
- **`Duration`** (Swift stdlib) — used for any playback duration. Per `[[project_context]]`: never `TimeInterval` in public surfaces.

### Audio-stop chain discipline (from `[[project_context]]`)

> Sessions and other synchronous callers MUST use `scheduleStopAll()` rather than `Task { await notePlayer.stopAll() }` so the commitment order matches source code order on `MainActor` — otherwise a subsequent `play()` can race the deferred stop and be silenced by its fade-out.

This applies to:
- `Session.pause()` — synchronous stop commit.
- `Session.stop()` — synchronous stop commit.
- `Session.place(cents:)` — synchronous stop commit before the orienting-cue play for the next slot, if any previous note is still ringing.

### Two-world architecture (from `[[project_context]]`)

> Logical world (`MIDINote`, `DetunedMIDINote`, `Interval`, `Cents` in `Core/Music/`) and physical world (`Frequency` in `Core/Music/`), bridged by `TuningSystem.frequency(for:referencePitch:)`. Forward conversion (logical → physical) always goes through `TuningSystem`.

This story's bridge: `Anchor.frequency(in:referencePitch:)` delegates to `TuningSystem.frequency(for:referencePitch:)`. Slot pitches are computed as `Frequency` by combining the lower-anchor `Frequency` with the slot's `placedCents` offset: `lowerAnchorFrequency * pow(2.0, placedCents / Cents.perOctave)`. This is *pure cent math*, not a `TuningSystem` call — per hidden-assumption #2 in the direction document, routing slot pitches through `TuningSystem` would silently train tuning-system-specific semitones instead of equal-cent steps.

### Tests-first discipline

Per `[[project_context]]`'s TDD section:
1. Read story and acceptance criteria.
2. Write failing tests that encode the ACs.
3. Implement until tests pass.
4. Refactor if needed (tests must still pass).
5. Run full test suite.
6. Commit.

The Code Map's NEW test files precede their NEW production files in Tasks 3–5.

### Symmetric protocol design (`[[feedback_symmetric_protocol_design]]`)

This discipline introduces a new training domain and should mirror existing protocol splits:

| Existing discipline | This discipline |
|---|---|
| `NextPitchStrategy` (pitch) / `NextRhythmOffsetDetectionStrategy` (rhythm) | `NextPathStrategy` |
| `PitchDiscriminationSettings` / `TimingOffsetDetectionSettings` | `ChromaticConstructionSettings` |
| `PitchDiscriminationSession` / `TimingOffsetDetectionSession` | `ChromaticConstructionSession` |
| `TimingOffsetDetectionPayload` | `ChromaticConstructionPayload` (in 86.2) |
| `PitchDiscriminationObserver` / `TimingOffsetDetectionObserver` | *(deferred — no observer protocol in this cut; persistence + observation introduced together later)* |

Sessions adopt `TrainingSession` conformance with state-preservation contract. Settings use a `.from(...)` factory. Strategies are feature-local protocols with stateless conformances.

### Performance Principle (`[[project_context]]`)

> Disciplines optimize for users to perform their best — never artificial difficulty.

Application here:
- The slot's previous-committed pitch (or lower anchor for slot 1) plays automatically as an orienting cue on slot open. The user does not need to tap to "earn" the cue.
- All committed slots and both anchors remain tappable for unlimited free replay throughout the trial. No replay budget, no exposure window.
- Step-back is always available (until activeSlotIndex == 1) and lossy by design — the user chooses whether to redo deliberately.

### Direction-document hidden assumptions to preserve

From `[chromatic-construction-discipline-direction.md](../planning-artifacts/chromatic-construction-discipline-direction.md) § Hidden assumptions`:

1. **Sliders must be cent-linear, not Hz-linear.** Tested in 86.2; this story exposes the session's slider-value type as `Cents`, not `Frequency`.
2. **Target step is pure cent math, not derived from `TuningSystem`.** Enforced by Code Map: no `TuningSystem` call in `MonotonicAscendingPath` / `MonotonicDescendingPath`. Strategies operate purely on `Cents`.
3. **The discipline trains equal cent division, not "12-TET semitones."** Enforced by Code Map: `targetStepCents` is a constructor parameter, not a hard-coded constant.
4. **Anchors and targets can be non-MIDI-aligned.** Slot pitches are `Frequency` via continuous cent-math from the lower anchor — never quantized to nearest MIDI note. (Future-proofing for equal divisions beyond chromatic; not exercised in this cut because `targetStepCents == 100` and `outerCents % 100 == 0` keeps everything MIDI-aligned.)
5. **Equal cents ≠ equal Hz delta.** Frequency derivation uses `lowerAnchorFrequency * pow(2.0, cents / Cents.perOctave)`, not additive.
6. **Step-back is lossy by design.** Enforced by `ChromaticConstructionSession.stepBack` event handler.
9. **Reference-pitch invariance.** Tested in `ChromaticConstructionSettingsTests`.
10. **Slot pitches are arbitrary frequencies, not MIDI notes.** `NotePlayer.play(frequency:)` accepts continuous `Frequency`; no rounding.
11. **Tuning-system gating is musical, not cosmetic.** Enforced by `Ladder.init` throwing on non-equal-tempered systems.

### Project Structure Notes

- All NEW files land in `Peach/Training/ChromaticConstruction/`. Following the precedent of TimingOffsetDetection and ContinuousRhythmMatching, the `Discipline/`, `Help/`, and `Settings/` subdirectories will be added in 86.2 when the discipline conformance, help content, and settings UI land.
- `NextPathStrategy` is feature-local (in the same directory as its conformances) rather than under `Core/`. This matches `NextPitchDiscriminationStrategy`'s precedent (`Peach/Training/PitchDiscrimination/`).
- `ChromaticConstructionPayload` does NOT land in this story. Deferred to 86.2 alongside the `ChromaticConstructionDiscipline` struct.

### References

- [Direction document](../planning-artifacts/chromatic-construction-discipline-direction.md) — *Core concepts*, *State machine*, *Hidden assumptions to preserve*, *Tuning-system constraint*.
- [Brainstorm session](../brainstorming/brainstorming-session-2026-06-12.md) — *Construct refined as a sequential walk*, *Pruning Identify*, *Scoring discussion and Michael's pivot to defer*.
- [Epics file](../planning-artifacts/epics.md) — *Epic 86* (this story's parent).
- [Project context](../project-context.md) — `[[project_ios26_minimum]]`, TDD workflow, audio-stop chain discipline, two-world architecture, Performance Principle, `PEACH_RESEARCH` gating mechanism.
- [`TrainingSession` protocol](../../Peach/Core/TrainingSession.swift) — `pause()`/`resume()`/`stop()`/`isIdle` contract.
- [`TimingOffsetDetectionSession`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift) — reference for state machine shape, audio-stop chain discipline, `@Observable` class structure.
- [`PitchMatchingSession`](../../Peach/Training/PitchMatching/PitchMatchingSession.swift) — reference for slider-driven session shape (`PitchMatching` is the closest existing analog — it also has a per-trial active value and a commit step).
- [`TimingOffsetDetectionSettings`](../../Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSettings.swift) — reference for `.from(userSettings:...)` factory shape.

## Consultation Findings

*To be appended by Task 2 (Adam consultation). Empty until then.*

## Spec Change Log

*Empty until first review iteration.*

## Dev Agent Record

### Agent Model Used

*To be filled by dev agent.*

### Debug Log References

### Completion Notes List

### File List
