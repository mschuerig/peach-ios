---
title: 'Story 86.1: Chromatic Construction domain types, session, and path strategies'
type: 'feature'
created: '2026-06-12'
status: 'done'
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
- `Peach/Training/ChromaticConstruction/Path.swift` — **NEW**. `typealias Path = [Direction]`. (Documented at the typealias site: the array semantically represents a directed step sequence; `Direction` is reused from `Core/Music/Direction.swift`. **Invariant** every strategy must honor: `path.reduce(0) { $0 + ($1 == .up ? +1 : -1) } * targetStepCents == outerCents` — i.e., the path's net signed step count, multiplied by `targetStepCents`, equals the outer span. Monotonic strategies satisfy it trivially; meandering strategies must construct paths that close back to net span. Per Adam's Q1 consultation.)
- `Peach/Training/ChromaticConstruction/Ladder.swift` — **NEW**. `struct Ladder: Hashable, Sendable { let lowerAnchor: Anchor; let upperAnchor: Anchor; let outerCents: Cents; let path: Path; let targetStepCents: Cents; let tuningSystem: TuningSystem }`. `init throws(ChromaticConstructionError)` validates tuning system, outer-cents/anchor agreement, and path length / step count consistency. Computed: `var slotCount: Int { path.count - 1 }`; `func targetCents(forSlotIndex k: Int) -> Cents` returns the lower-anchor-relative target cents for slot k (positive for ascending, negative for descending). Co-locates `enum ChromaticConstructionError: Error, Equatable { case tuningSystemNotEqualTempered(TuningSystem); case outerCentsMismatchesAnchors(declared: Cents, actual: Cents); case pathLengthMismatch(expected: Int, actual: Int) }`.
- `Peach/Training/ChromaticConstruction/NextPathStrategy.swift` — **NEW**. `protocol NextPathStrategy: Sendable { func path(forOuterCents: Cents, targetStep: Cents, rng: inout some RandomNumberGenerator) -> Path }`. The `rng:` parameter is unused by monotonic conformances and consumed by future meandering conformances (per Adam's Q1 consultation: RNG-injection symmetry with `ChromaticConstructionSettings.from(...)`, no signature churn when meandering ships). One-method functional protocol; follows `NextPitchStrategy` and `NextRhythmOffsetDetectionStrategy` shape.
- `Peach/Training/ChromaticConstruction/MonotonicAscendingPath.swift` — **NEW**. `struct MonotonicAscendingPath: NextPathStrategy, Sendable {}`. Implementation precondition-traps on negative `outerCents` and on `outerCents.remainder(dividingBy: targetStep) ≠ 0`; otherwise returns `Array(repeating: Direction.up, count: stepCount)` where `stepCount = Int(outerCents / targetStep)`.
- `Peach/Training/ChromaticConstruction/MonotonicDescendingPath.swift` — **NEW**. Mirror of `MonotonicAscendingPath` for negative `outerCents`; emits `.down`.
- `Peach/Training/ChromaticConstruction/ChromaticConstructionDirectionPolicy.swift` — **NEW**. `enum ChromaticConstructionDirectionPolicy: Hashable, Sendable, CaseIterable { case ascending, descending, mix }`. Display names are added in 86.2 (or co-located here as `LocalizedStringResource` properties; default plan: define here, exercise in 86.2's localization sweep).
- `Peach/Training/ChromaticConstruction/ChromaticConstructionSettings.swift` — **NEW**. `struct ChromaticConstructionSettings: Sendable { let ladder: Ladder; let directionPolicy: ChromaticConstructionDirectionPolicy; let referencePitch: Frequency }`. Factory: `static func from(userSettings: any UserSettings, outerCents: Cents, lowerAnchor: MIDINote, directionPolicy: ChromaticConstructionDirectionPolicy, strategySelector: (ChromaticConstructionDirectionPolicy, inout some RandomNumberGenerator) -> any NextPathStrategy = { defaultStrategy(for: $0, rng: &$1) }, rng: inout some RandomNumberGenerator = …) throws(ChromaticConstructionError) -> ChromaticConstructionSettings`. Resolves the strategy per the policy + RNG, derives `upperAnchor` from `lowerAnchor + outerCents` (via `MIDINote + Int` arithmetic — note: `outerCents / 100 == semitones` in 12-TET, and 12-TET is enforced by `Ladder.init`), reads `referencePitch` and `tuningSystem` from `userSettings`, and constructs the ladder. (`defaultStrategy(for:rng:)` is a free function in the same file: returns `MonotonicAscendingPath` / `MonotonicDescendingPath` / a randomized pick.)
- `Peach/Training/ChromaticConstruction/ChromaticConstructionSession.swift` — **NEW**. `@Observable final class ChromaticConstructionSession: TrainingSession { … }`. State enum mirrors the direction document; events `start`, `place(cents:)`, `stepBack`, `nextTrial`, `pause`, `resume`, `stop`; effects audio playback via injected `NotePlayer`. Constructor: `init(notePlayer: any NotePlayer, rng: any RandomNumberGenerator = SystemRandomNumberGenerator())`. Uses `os.Logger(subsystem: "com.peach.app", category: "ChromaticConstructionSession")`. `pause()`/`resume()`/`stop()` follow `TimingOffsetDetectionSession`'s patterns including audio-stop chain discipline (`scheduleStopAll()` synchronous commit).

**Tests:** mirror source structure under `PeachTests/Training/ChromaticConstruction/`.

- `PeachTests/Training/ChromaticConstruction/AnchorTests.swift` — `frequency(in:referencePitch:)` returns the same `Frequency` as `TuningSystem.frequency(for:referencePitch:)` for the same `MIDINote`; ascending vs. descending anchor pairs derive consistently.
- `PeachTests/Training/ChromaticConstruction/SlotTests.swift` — initial pending state; commit transitions; reactivate preserves `placedCents`; *pendingAgain clears placedCents to prevent stale targets* (Q2-consultation: sharpen the test description so the lossy-by-design *why* travels with the test name).
- `PeachTests/Training/ChromaticConstruction/LadderTests.swift` — every I/O matrix row whose subject is `Ladder.*`: valid construction (P5 ascending, octave descending); tuning-system rejection (justIntonation throws); outer-cents/anchor mismatch throws; path length mismatch throws; non-monotonic path accepted; `slotCount` derivation; `targetCents(forSlotIndex:)` for ascending and descending. **Plus three Q3-consultation additions:** (a) fractional-step direct-multiplication test using a test-only ladder fixture that bypasses the integer-step strategy precondition (asserts `targetCents(forSlotIndex: 7)` for outerCents=750/slotCount=7 returns exactly `Cents(750.0)`, locking in the *direct multiplication, not recurrence* contract); (c) sign symmetry — for a descending octave ladder, all `targetCents(forSlotIndex: K)` for K in `1...slotCount` are negative and magnitudes match the ascending octave slot-for-slot.
- `PeachTests/Training/ChromaticConstruction/MonotonicAscendingPathTests.swift` — outputs for representative outer intervals (200 → 2 steps, 700 → 7 steps, 1200 → 12 steps); precondition trip on negative outer cents; precondition trip on non-integer division (`outerCents=750, targetStep=100`). **Plus Q3-consultation addition (b):** `outer=900, target=300 → 3 .up steps` (minor third × 3) — locks in "100 is one parameterization, not hard-coded."
- `PeachTests/Training/ChromaticConstruction/MonotonicDescendingPathTests.swift` — mirror (including the Q3 (b) addition: `outer=-900, target=300 → 3 .down steps`).
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

- [x] **Task 1 — Sprint-status start.** Flip `86-1-chromatic-construction-domain-and-session: backlog → in-progress` in `sprint-status.yaml`; flip `epic-86: backlog → in-progress`; update `last_updated` to today's date.
- [x] **Task 2 — Music-domain consultation (must precede protocol drafting).** Invoke `/agent-music-domain-expert` (Adam) with the direction-document section *Core concepts* and the I/O matrix above. Ask three targeted questions: (a) does `NextPathStrategy`'s `path(forOuterCents:targetStep:)` signature give meandering strategies enough information to do their job (i.e. is `outerCents + targetStep` sufficient input, or do they need a `complexity` or `seed` parameter)? (b) is the slot-state lifecycle `pending → active → committed` (with lossy reactivate-back-to-active resetting forward) consistent with motor-learning failure modes, or should there be a separate `revisiting` state? (c) does the cent-step math assume any failure mode (rounding, accumulation) that unit tests should explicitly cover? Append Adam's findings to a *Consultation Findings* section below this Tasks list. **If Adam recommends a signature change to `NextPathStrategy`, halt and surface before drafting the protocol.** *(Outcome: Adam recommended adding `rng: inout some RandomNumberGenerator` to `NextPathStrategy.path(...)` — an additive parameter, no shape change. Approved inline as a low-risk additive change matching the existing RNG-injection symmetry in `ChromaticConstructionSettings.from(...)`. Three Q3 test additions also applied to the spec. Full findings in Consultation Findings below.)*
- [x] **Task 3 — Domain primitives (tests-first).** Write `AnchorTests`, `SlotTests`, `LadderTests`, `MonotonicAscendingPathTests`, `MonotonicDescendingPathTests` per the Code Map. Then implement `Anchor.swift`, `Slot.swift`, `Path.swift` (typealias), `Ladder.swift` (including `ChromaticConstructionError`), `NextPathStrategy.swift`, `MonotonicAscendingPath.swift`, `MonotonicDescendingPath.swift`, `ChromaticConstructionDirectionPolicy.swift`. Run the test suites until green. *(34 new tests added — iOS Debug suite up from 1997 → 2033 green.)*
- [x] **Task 4 — Settings factory (tests-first).** Write `ChromaticConstructionSettingsTests` per the Code Map. Then implement `ChromaticConstructionSettings.swift`. The reference-pitch-invariance test exercises hidden-assumption #9 from the direction document: change `userSettings.referencePitch` between two settings constructions with the same `outerCents` / `lowerAnchor` and assert the cent math is identical (only the anchor frequencies differ). *(6 new tests including the reference-pitch invariance; iOS suite up from 2033 → 2039 green. Resolved a spec inconsistency between the two anchor-naming models — see Spec Change Log.)*
- [x] **Task 5 — Session state machine (tests-first).** Write `ChromaticConstructionSessionTests` per the Code Map. Then implement `ChromaticConstructionSession.swift`. State machine effects play through the injected `MockNotePlayer`. The `stepBack` test uses a deterministic RNG fixture and a slot-count-2 ladder (P3 = 300¢, slots 1 and 2) to cover the K==1 no-op and the K==2 → K==1 reset transitions without combinatorial blowup. `pause`/`resume`/`stop` tests follow the patterns in `PitchDiscriminationSessionTests` and `TimingOffsetDetectionSessionTests`. *(15 new session tests; iOS suite up from 2039 → 2054 green. Session does not hold its own RNG — the factory consumes the RNG and the session receives a concrete settings/ladder, per Spec Change Log entry.)*
- [x] **Task 6 — Pre-commit gates.** Run `bin/test.sh && bin/test.sh -p mac` and `bin/test.sh --research && bin/test.sh --research -p mac`. All four green; no new warnings; strict-concurrency build clean. *(Results: iOS Debug 2054 / macOS Debug 2041 / iOS Research 2214 / macOS Research 2201 — all green. `archlint Peach` clean. `bin/check-dependencies.sh` reports one violation (PF-070) — pre-existing false positive in `TimingDotView.swift` comment, cataloged.)*
- [x] **Task 7 — `/simplify-code` pass.** Per `[[project_context]]`'s skills section: mandatory after any code change. Run `/simplify-code` on the diff; apply or reject findings per `[[feedback_fix_review_findings]]`. *(Findings: Q1 — `ChromaticConstructionSession.playCue`'s `[notePlayer, logger]` capture list diverges from sibling sessions' implicit-self pattern (high confidence). Applied. C1 — 600ms hardcoded cue duration: reject; settings persistence deferred per direction document. C2 — `Anchor` is a near-empty wrapper: reject; semantic clarity per direction document. C3 — `Ladder.testFixture`'s `unsafelyBypassingInvariants: Void` discriminator: reject; functional and contained. iOS tests remain green after applying Q1.)*
- [x] **Task 8 — Sprint-status finalize.** Flip `86-1-chromatic-construction-domain-and-session: in-progress → review` for review; after review, `review → done` per `[[feedback_update_status_after_review]]`. *(Flipped to `review` 2026-06-12. Awaiting review; final flip to `done` happens after.)*

**Acceptance Criteria:**

- **Ladder construction.** Given `Ladder.init(lowerAnchor:upperAnchor:outerCents:path:targetStepCents:tuningSystem:)`, all rows from the I/O matrix labeled `Ladder.init — *` produce the documented output (typed throw or accepted ladder).
- **Path generation.** `MonotonicAscendingPath().path(forOuterCents: Cents(700), targetStep: Cents(100), rng: &rng)` returns `[.up]` of length 7. `MonotonicDescendingPath().path(forOuterCents: Cents(-700), targetStep: Cents(100), rng: &rng)` returns `[.down]` of length 7. Non-100 target step is exercised by `outer=900, target=300 → 3 steps` (Q3 (b)). Precondition trips on direction mismatch and on non-integer division are asserted via XCTest crash assertions or via Swift Testing's `withKnownIssue { … }` — choose the in-repo precedent; if no precedent exists, document the omission in the Spec Change Log per `[[feedback_fix_review_findings]]`.
- **Cent-step math (Q3 consultation).** `Ladder.targetCents(forSlotIndex:)` is direct multiplication, not recurrent summation — asserted via a fractional-step fixture (Q3 (a)). Descending ladders' `targetCents(forSlotIndex:)` outputs are sign-symmetric with the ascending counterpart (Q3 (c)).
- **Session state machine.** Every (state, event) pair in the I/O matrix's `Session.*` rows produces the documented transition and side effects, verified through `MockNotePlayer` interaction. Step-back from slot K resets slots K+1..N to `.pending`. Implicit final-slot submit lands directly in `.showingResult` without an intermediate state. `pause` preserves `currentLadder`/`committed`/`activeSlotIndex`; `resume` re-plays the active-slot orienting cue. `stop` returns to `.idle`.
- **Reference-pitch invariance.** Two `ChromaticConstructionSettings` constructed from `userSettings` differing only in `referencePitch` produce identical `Ladder.targetCents(forSlotIndex:)` outputs for all slot indices (the anchor frequencies differ; the cent math does not). Asserted by `ChromaticConstructionSettingsTests`.
- **Tuning-system gating.** `Ladder.init(tuningSystem: .justIntonation, …)` throws `ChromaticConstructionError.tuningSystemNotEqualTempered(.justIntonation)`. Asserted by `LadderTests`.
- **Pure-Swift module.** `grep -rn "import SwiftUI\|import UIKit\|import Charts" Peach/Training/ChromaticConstruction/` returns zero matches. `grep -rn "import SwiftData" Peach/Training/ChromaticConstruction/` returns zero matches.
- **No registration leakage.** `grep -rn "ChromaticConstruction" Peach/App/ Peach/Core/NavigationDestination.swift` returns zero matches (registration is 86.2's job).
- **Pre-commit gates.** All four schemes green: Debug × {iOS, macOS} and Research × {iOS, macOS}. No new compiler warnings. Strict-concurrency build clean.
- **No third-party dependencies.** `Package.resolved` / project's package list unchanged.

### Review Findings

**2026-06-12 — Three-layer adversarial review (Blind Hunter, Edge Case Hunter, Acceptance Auditor) of `e33c2c87..HEAD`.**

Patches (13):

- [ ] [Review][Patch] **`Ladder.targetCents` returns wrong values for non-monotonic ("meandering-ready") paths** — `Ladder.init` accepts non-monotonic paths (validated test `acceptNonMonotonicPath`) but `targetCents(forSlotIndex: k) = k * signedStep` only works for monotonic paths. For `[.up, .down, .up, ...]`, actual cumulative is 100, 0, 100, 0 — not 100, 200, 300, 400. No current callers pass non-monotonic paths, but the "meandering-ready" contract is silently lied to. Fix: walk `path.prefix(k)` and sum signed steps. [`Peach/Training/ChromaticConstruction/Ladder.swift` `targetCents(forSlotIndex:)`]
- [ ] [Review][Patch] **`Ladder.testFixture` parameter `slotCount` is actually path-length; test iterates past valid slot range** — `testFixture(slotCount: 7)` produces `path.count=7` so the real `slotCount = 6`, but `targetCentsIsDirectMultiplication` iterates `1...7`. The bypass initializer hides the inconsistency. Fix: rename to `stepCount` (or `pathLength`) and align the test bound to `ladder.slotCount`. [`Peach/Training/ChromaticConstruction/Ladder.swift` `testFixture`; `PeachTests/Training/ChromaticConstruction/LadderTests.swift:158`]
- [ ] [Review][Patch] **`pathLengthMismatch` error reports incomparable axes** — Guard compares `netSignedSteps == requiredNetSteps` but throws `.pathLengthMismatch(expected: |requiredNetSteps|, actual: path.count)`. The two payload fields are different quantities (net-signed vs total-length). Fix: report `expected: requiredNetSteps, actual: netSignedSteps`. [`Peach/Training/ChromaticConstruction/Ladder.swift` `init`]
- [ ] [Review][Patch] **`MonotonicDescendingPath` precondition diagnostic uses `.rawValue` but divides by `.magnitude`** — Message names `targetStep` by `.rawValue` (signed) but quotient division uses `.magnitude`. Cosmetic for today's positive `targetStep`, misleading if a negative `targetStep` ever lands. Fix: use `.magnitude` in the message. [`Peach/Training/ChromaticConstruction/MonotonicDescendingPath.swift:13`]
- [ ] [Review][Patch] **Factory silently rounds `outerCents/targetStepCents` to `Int`; fractional inputs reach `MonotonicAscendingPath` precondition and crash** — `let semitones = Int((outerCents / targetStepCents).rounded())` accepts non-integer ratios. `Cents(749.0)/Cents(100)=7.49` rounds to `7`, factory returns settings, then path strategy's `<1e-9` tolerance trips. Fix: add divisibility guard in factory (typed throw or precondition with explicit message); same gate as the path strategy. [`Peach/Training/ChromaticConstruction/ChromaticConstructionSettings.swift:322`]
- [ ] [Review][Patch] **`placeFinalSlotImplicitSubmit` + `pausePreservesState` tests rely on `Task.yield()` instead of `MockNotePlayer.waitForPlay/waitForStopAll`** — Single `Task.yield()` is not a drain barrier; the prior-slot orienting-cue Task may or may not have run when the snapshot is taken. Under CI load this will flake. Spec's Debug Log already records this race once. Fix: use the explicit wait helpers `MockNotePlayer` already provides. [`PeachTests/Training/ChromaticConstruction/ChromaticConstructionSessionTests.swift`]
- [ ] [Review][Patch] **`rngIgnored` test pins internal RNG state instead of output contract** — Asserts `rng.state == snapshotBefore`. The protocol contract is "monotonic strategies produce a deterministic path"; a future impl that consumes random bits to e.g. shuffle ties would be correct but break this test. Fix: assert output equality across different seeds, not state non-advancement. [`PeachTests/Training/ChromaticConstruction/MonotonicAscendingPathTests.swift` `rngIgnored`]
- [ ] [Review][Patch] **`SeededRNG.init(seed: UInt64.max)` overflows `&+ 1` to `state == 0`, breaking the documented non-zero invariant** — Comment promises non-zero state; the boundary case violates it. Fix: `state = (seed &+ 1) | 1` or explicit overflow check. [`PeachTests/Training/ChromaticConstruction/SeededRNG.swift:9`]
- [ ] [Review][Patch] **`Ladder.init` accepts degenerate paths (slotCount ≤ 0): outerCents=0, single-element path, or factory called with outerCents==targetStepCents** — Three facets of the same gap: no minimum-path-length guard. Session enters `.walking` but `place(cents:)` advances past `slotCount` and the trial never completes. Fix: `Ladder.init` requires `path.count ≥ 2`; add `ChromaticConstructionError.degeneratePath` case (or extend `pathLengthMismatch`). [`Peach/Training/ChromaticConstruction/Ladder.swift` `init`; `ChromaticConstructionSettings.swift:316–322`]
- [ ] [Review][Patch] **`start(settings:)` does not reset `isPaused`; `pause → start(settings:) → resume` leaves stale flag** — `pause` while walking sets `isPaused=true`. If the screen calls `start(settings:)` next (instead of `stop`), `isPaused` lingers, and the *next* `pause` is a no-op (`guard !isPaused`). Fix: set `isPaused = false` at the top of `start(settings:)`. [`Peach/Training/ChromaticConstruction/ChromaticConstructionSession.swift` `start`]
- [ ] [Review][Patch] **Test coverage gaps: stepBack twice from K=2, `slotCount=1` boundary, `.mix` across consecutive trials with one shared RNG** — Untested cases: (a) `start → place → place → stepBack → stepBack → stepBack` (third stepBack must no-op AND preserve `placedCents=95` on re-active slot 1); (b) minimum non-degenerate ladder `slotCount=1` (single `place(cents:)` is the implicit submit); (c) per-trial `from(...)` calls advancing a shared `SeededRNG` (production semantics) vs. seed-fresh per call (current test). Fix: add three test methods. [`PeachTests/Training/ChromaticConstruction/ChromaticConstructionSessionTests.swift`, `ChromaticConstructionSettingsTests.swift`]
- [ ] [Review][Patch] **Spec Change Log entry missing for omitted precondition-trip tests** — AC "Path generation" required either crash-assertions OR a Spec Change Log entry documenting the omission. Path strategies' preconditions on direction mismatch and non-integer division are never asserted in tests; no in-repo precedent exists; no Spec Change Log entry was added. Fix: add Spec Change Log entry naming the omission and citing the in-repo absence of precondition-test precedent. [this spec; Spec Change Log section]
- [ ] [Review][Patch] **`epics.md` Story 86.1 description claims `ChromaticConstructionPayload` is introduced in 86.1 — contradicts this story's "Never" boundary** — Per `[[feedback_epics_md_is_sot]]` epics.md is source of truth; here the spec correctly defers Payload to 86.2 and code follows the spec. Fix: amend epics.md Story 86.1 description to reflect the 86.1/86.2 split. [`docs/planning-artifacts/epics.md` Story 86.1 description]

Deferred (0):

All eight initial deferrals re-examined after the redesign and your challenge "what is the justification for deferring anything?" — none survive. PF-071/073/077/078 dissolved by the redesign (Ladder/Slot/policy enum/frozen matrix all deleted). PF-072 was wrong on its premise: the project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so the session is implicitly MainActor — the "latent data-race" was imagined. PF-074 (Frequency.init crash for cents in the −1e10 range) is "validation for scenarios that can't happen" by the project rule and was dismissed. PF-075 (silent no-op guard against an invariant break) was fixed in place — `Trial.stepBack`, `Trial.reopenFinalPosition`, and `Session.playOrientingCueForCurrentActivePosition` now crash loudly on impossible inputs instead of silently swallowing them. PF-076 (`stop()` not awaiting `scheduleStopAll()`) matches the established sibling pattern with production ordering guaranteed by the audio-chain — not a bug, nothing to defer.

Dismissed (11): factory MIDI overflow via `MIDINote.init` precondition — unreachable under 86.2's view-local selector (anchor ∈ {48, 60, 72}, outerCents ≤ 1200); no validation needed for scenarios that can't happen; tautological-but-still-useful `targetCentsIsDirectMultiplication` test (alternative pin can't reliably catch the regression for IEEE 754 small-step counts); two subsumed-by-other-findings items (outerCents=0 defensive precondition, signed-zero in `targetCents` — both fixed by the Ladder.init degenerate-path guard); `Slot.pendingAgain()` defined-but-unused (anticipated 86.2 view-layer use); Boy Scout `nonisolated` change (properly Spec Change-Logged); hidden-assumption #4 latent factory bug (subsumed by factory divisibility check).

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

### 2026-06-12 — Adam (music-domain expert), pre-protocol consultation

**Q1 — `NextPathStrategy` signature.** Keep the proposed shape; add one parameter.

- **Add** `inout some RandomNumberGenerator` to the call: `func path(forOuterCents: Cents, targetStep: Cents, rng: inout some RandomNumberGenerator) -> Path`. Monotonic conformances ignore it. Meandering conformances (future epic) consume it. This matches the RNG-injection symmetry already in `ChromaticConstructionSettings.from(...)`.
- **Keep** `(outerCents, targetStep)` as the only musical inputs. Anything else (complexity, contour template) is a property of the strategy *instance*, not the call. Mirrors `NextPitchStrategy`.
- **Document the invariant** at the `Path = [Direction]` typealias site: `path.reduce(0) { $0 + ($1 == .up ? +1 : -1) } * targetStepCents == outerCents`. This is the contract every strategy must honor.
- **Reject** changing the return type to `Ladder`. Strategy returns `Path`; ladder construction stays in the settings factory, so `Ladder.init` can cross-check anchor span against the strategy-produced path's net span.

**Q2 — Slot-state lifecycle.** Keep `pending / active / committed`. Do not add `revisiting`.

- Motor-learning literature does distinguish "first attempt" from "revisit" cognitively, but that belongs in (a) per-slot *visit count* captured for the future scoring pass and (b) the view layer's rendering decisions — not in the state-machine contract. Conflating "where we are in the trial" with "have we been here before" is the classic state-machine bug.
- The lossy reset of slots K..N to `.pending` (clearing `placedCents`) is the right granularity for the "predecessor changed, downstream targets are stale" failure mode.
- **Sharpen one test description** in `SlotTests`: `@Test("pendingAgain clears placedCents to prevent stale targets")` so the *why* travels with the test name.

**Q3 — Cent-step math failure modes.** Three explicit tests to add now.

- **(a) Direct multiplication invariant.** `Ladder.targetCents(forSlotIndex: K)` must compute `K * targetStepCents`, not a recurrence. A future fractional `targetStepCents` (e.g., 750/7 ≈ 107.142857) would accumulate floating-point error per step under a recurrent implementation. Add a test using a test-only `Ladder` fixture that bypasses the monotonic-step precondition and asserts the multiplied form round-trips exactly. **Acceptance Criteria addition:** `LadderTests` includes a fractional-step direct-multiplication assertion.
- **(b) Non-100 precisely-divisible step.** Add `outer=900, target=300 → 3 steps` to `MonotonicAscendingPathTests` (and mirror in `MonotonicDescendingPathTests`). 300 cents is a minor third — a musical interval — so the test name communicates intent. Locks in the "100 is one parameterization, not hard-coded" design principle.
- **(c) Sign symmetry.** Add a `LadderTests` row that constructs a descending ladder and asserts `targetCents(forSlotIndex: K) < Cents(0)` for all K in `1...slotCount`, *and* that magnitudes match the ascending counterpart slot-for-slot. Magnitudes-match assertion is what catches `Int(negative / positive)` truncation bugs in future non-integer-step variants.

**Net spec deltas applied below:**

1. `NextPathStrategy.path(...)` signature gains `rng: inout some RandomNumberGenerator`.
2. Path-net-span invariant documented at the `Path` typealias site.
3. Three new test rows added to the appropriate test files.
4. One `SlotTests` description sharpened.

No production-code architecture changes beyond the `rng:` parameter. No new types.

## Spec Change Log

### 2026-06-12 — Post-review redesign (replaces the prior implementation wholesale)

The three-layer code review surfaced architectural issues that Michael unpacked into a redesign: `Ladder` did too much (carried `tuningSystem` only to validate it; `outerCents` was derived from anchors; missing the only real precondition — path-fits-in-MIDI-range); `Cents` was used where the existing musical types (`DirectedInterval`, `MIDINote`) fit better; `Slot` carried state that belongs to the session, not the value; `targetStep` was a parameterization with no live use case (24-TET deferred indefinitely); `NextPathStrategy` exposed RNG that should be an implementation detail; the factory mixed concerns. The redesign collapses these into a smaller, established-pattern surface.

**Concrete deltas vs. the original Code Map:**

1. **`Ladder` deleted.** Its responsibilities split between `ChromaticPath` (anchor + outer interval + steps + path-fits-in-MIDI-range validation) and the session (tuning-system context, which is now *always* equal-tempered with no parameter — see #5).
2. **`Slot` deleted.** Per-slot state (pending/active/placed) is no longer a field on a value type; it is implicit in the session's `ChromaticConstructionTrial.placed: [DetunedMIDINote]` collection plus an `ActivePosition` descriptor. The placed value type IS `DetunedMIDINote` (the existing logical-pitch type in `Core/Music/`).
3. **`Anchor` deleted.** A twelve-line wrapper over `MIDINote` with one `.frequency(in:referencePitch:)` method that didn't earn its keep once `ChromaticPath` owned the anchor pair. Call sites use `TuningSystem.equalTemperament.frequency(for:referencePitch:)` directly.
4. **`Path` typealias deleted; `ChromaticPath` is a struct.** It owns the path-invariant validation (`degeneratePath`, `pathDoesNotReachInterval`, `pathExceedsMIDIRange`). `cumulativeSemitones(at:)` correctly honors meandering paths via prefix summation — the original `Ladder.targetCents(forSlotIndex:)` blind-multiplied `k × targetStep` and would have silently lied for non-monotonic paths.
5. **`targetStep` removed as a parameter.** The discipline is locked to one-semitone steps (12-TET). YAGNI applied: 24-TET / N-TET division was the only motivating case, and it isn't on any roadmap. Removing the parameter deletes Adam's Q3 (a) direct-multiplication test, Q3 (b) non-100 step test, the divisibility precondition, the `targetStepCents` field across the module, and the corresponding error case from `ChromaticConstructionError`. Hidden assumptions #2 and #3 (`pure cent math, not derived from TuningSystem`; `trains equal cent division, not 12-TET semitones`) are re-scoped: 86.1 ships 12-TET only; future N-TET disciplines would introduce a new path/strategy variant.
6. **`tuningSystem` removed from settings, errors, and the public surface.** The discipline is musically meaningful only in equal temperament; there's nothing to parameterize. The session calls `TuningSystem.equalTemperament.frequency(for:referencePitch:)` directly at the MIDI→Frequency bridge. The `userSettings.tuningSystem` global preference is intentionally ignored for this discipline (documented at discipline-registration time in 86.2). `ChromaticConstructionError.tuningSystemNotEqualTempered` deleted.
7. **`outerCents` removed.** Replaced by `outerInterval: DirectedInterval` (musical names: P5, octave, etc.). `MIDINote.transposed(by:)` does the arithmetic. Eliminates `Double ==` validation in `Ladder.init`, the path-length-mismatch / outer-cents-mismatch errors, and the divisibility-with-targetStep failure surface.
8. **`ChromaticConstructionDirectionPolicy` deleted.** Direction is intrinsic to `DirectedInterval` (via its `Direction` field). The "user enables ascending / descending / both" UX is modeled as `Set<DirectedInterval>` in settings (e.g., `{.up(P5)}`, `{.down(P5)}`, `{.up(P5), .down(P5)}`); the session picks one via `outerIntervals.randomElement()` per trial — mirroring `PitchDiscriminationSettings.intervals`. No separate enum, no `MixPathStrategy`, no shared-RNG ceremony.
9. **`NextPathStrategy` is RNG-free.** `func chromaticPath(lowerAnchor:outerInterval:) throws(...) -> ChromaticPath`. Adam's Q1 RNG-injection addition reversed: monotonic strategies don't need it, and future meandering strategies hold their own RNG as an implementation detail (matching `KazezNoteStrategy`'s use of `Bool.random()` / `MIDINote.random(in:)`). A future signature evolution may add a `profile: TrainingProfile` parameter additively.
10. **Single `MonotonicPath` strategy** replaces `MonotonicAscendingPath` + `MonotonicDescendingPath`. Direction is encoded in `outerInterval.direction`; the strategy fills `steps` with that direction.
11. **`ChromaticConstructionSession` adopts the `PitchDiscriminationSession` event/effect/reduce shape.** The state enum is `idle / walking / showingResult` (no associated values — state is data, not configuration). `currentTrial: ChromaticConstructionTrial?` and `lastCompletedTrial: CompletedChromaticConstructionTrial?` are observable fields alongside state, again matching PitchDiscrimination.
12. **`ChromaticConstructionTrial` + `CompletedChromaticConstructionTrial` introduced.** Mirrors `PitchDiscriminationTrial` / `CompletedPitchDiscriminationTrial`. The trial holds the path + the in-progress user state (`placed`, `active`). The completed trial wraps the trial + timestamp and provides per-position `absoluteErrorCents(at:)` / `relativeErrorCents(at:)` for downstream scoring. Cent-error metrics belong on the completed-trial value, not the session.
13. **No default parameters on any `init` in the module.** Per `[[feedback_no_default_params_inviting_errors]]`. Every value is explicit at the call site.
14. **`Settings.from(_ userSettings:)` shrunk to a pass-through.** Reads only `referencePitch` from user settings; everything else is supplied by the caller. No tuning-system gating (no longer applicable). No RNG.

**Net effect on the prior review's findings:**

- HIGH/MEDIUM patches against the prior `Ladder` / `Slot` / `outerCents` / `targetStep` / factory shape (P1, P3, P4, P5, P8, P9, P10): dissolved by deletion of the offending types.
- LOW patches against test discipline (P6 `Task.yield` → `waitForStopAll`, P11 coverage gaps) applied in the new test suite.
- P2 (tautological direct-multiplication test) and P7 (RNG-state pin) gone with the targetStep parameter and the RNG parameter.
- P12 (Spec Change Log entry for omitted precondition-trip tests) and P13 (epics.md Payload text) carried forward — see new entries below.
- Deferred PF-073 (Slot state contract), PF-077 (Logger privacy for state interpolation), PF-078 (frozen I/O matrix rows) all dissolve. PF-071 (Double ==) gone — exact integer-semitone math only. PF-072 (session not @MainActor), PF-074, PF-075, PF-076 stay open and apply to the new session unchanged.



- **2026-06-12 (Task 3 implementation):** Renamed top-level `typealias Path = [Direction]` → `typealias ChromaticPath = [Direction]`. Reason: `Path` shadowed `SwiftUI.Path` (the rendering shape type), breaking `ProgressSparklineView.swift`'s `func path(in:) -> Path` return-type resolution. `ChromaticPath` keeps the typealias's documentation home (path invariant) without the name collision. All references in `Ladder`, `NextPathStrategy`, `MonotonicAscendingPath`, `MonotonicDescendingPath`, and `LadderTests` updated.
- **2026-06-12 (Task 3 implementation, Boy Scout):** Added `nonisolated` to `Peach/Core/Music/TuningSystem.swift` and `Peach/Core/Music/DetunedMIDINote.swift`. Reason: `Anchor.frequency(in:referencePitch:)` and `ChromaticConstructionError.tuningSystemNotEqualTempered(TuningSystem)`'s synthesized `Equatable` require nonisolated TuningSystem. The two types are pure value/data types with no MainActor reason — `Cents`, `MIDINote`, `Frequency`, and other Music primitives are already `nonisolated`. Existing MainActor call sites continue to compile and run unchanged.
- **2026-06-12 (Task 3 implementation):** Refined `Ladder.init` path-length validation. Original phrasing checked `path.count == |outerCents / targetStepCents|` (length-based); the I/O matrix's "non-monotonic path accepted" row required checking *net signed step count* instead. Implementation now validates `path.reduce(0) { ±1 } * targetStepCents == outerCents` (net-span-based). The `pathLengthMismatch` error case keeps its existing fields (`expected: Int, actual: Int`); `expected` is the monotonic-path-length the caller most likely intended, `actual` is `path.count`.
- **2026-06-12 (Task 4 implementation):** Resolved a spec inconsistency between the two anchor-naming models used in the I/O matrix. The `Ladder.init` rows treat `lowerAnchor` as the *starting* anchor (Model A): for descending walks `lowerAnchor.rawValue > upperAnchor.rawValue` (e.g. `lower=72, upper=60`). The `ChromaticConstructionSettings.from(...)` descending row used Model B (lowerAnchor = lower-pitched anchor, anchors *flipped* for descending). The two are not reconcilable. Adopted Model A throughout (matching the direction document: `lowerAnchor` = "start of the row"). The factory's descending case now produces `lowerAnchor = user's chosen MIDI` and `upperAnchor = user's MIDI − semitones`, with `outerCents` negated. `LadderTests.targetCentsDescending` and the descending-octave I/O matrix row are unaffected (they already use Model A). `ChromaticConstructionSettingsTests.descendingDerivation` was updated to assert the Model A outputs.
- **2026-06-12 (Task 5 implementation):** Dropped the `rng:` parameter from `ChromaticConstructionSession.init`. The spec's Code Map listed `init(notePlayer: any NotePlayer, rng: any RandomNumberGenerator = SystemRandomNumberGenerator())`, but Swift cannot dispatch a mutating `next()` through an `any RandomNumberGenerator` existential, so the literal signature does not compile. The session also has no internal use for an RNG once the factory owns direction resolution and path generation — `start(settings:)` receives a concrete `Ladder`, and `nextTrial()` returns to `.idle` so the screen can call the factory again with fresh settings. Tests inject deterministic RNG into `ChromaticConstructionSettings.from(...)` and pass the resulting settings to the session. The session's `init` is now `init(notePlayer: any NotePlayer)`.
- **2026-06-12 (Task 5 implementation):** `ChromaticConstructionSessionState.walking` carries the full active `Slot` value (not just an index). The active slot's `placedCents` doubles as the slider's starting position when `stepBack()` reactivates a prior slot, eliminating the need for a separate `activeSlotPreviousPlacedCents` observable. State derivation: `start` produces `.walking(activeSlot: Slot(index: 1, .active, nil), …)`; `place(cents:)` for K < slotCount produces `.walking(activeSlot: Slot(index: K+1, .active, nil), committed + [committed K], …)`; `stepBack` produces `.walking(activeSlot: prior.reactivated(), committed.dropLast(), …)` — `reactivated()` preserves `placedCents`.

## Dev Agent Record

### Agent Model Used

Claude Opus 4.7 (claude-opus-4-7).

### Debug Log References

- Build failure: `error: main actor-isolated conformance of 'TuningSystem' to 'Equatable' cannot be used in nonisolated context` — resolved by marking `TuningSystem` and `DetunedMIDINote` as `nonisolated` (Spec Change Log entry 2).
- Build failure: `Peach/Start/ProgressSparklineView.swift:64: error: type 'SparklinePath' does not conform to protocol 'Shape'` plus `value of type 'Path' (aka 'Array<Direction>') has no member 'addLine'` — top-level `typealias Path = [Direction]` shadowed `SwiftUI.Path`; renamed to `ChromaticPath` (Spec Change Log entry 1).
- Test failure: `LadderTests/acceptNonMonotonicPath` — `Ladder.init` path-length validation was length-based but spec required net-signed-span-based to admit meandering paths (Spec Change Log entry 3).
- Test failure: `ChromaticConstructionSettingsTests/{descendingDerivation, mixPolicyPreservedInSettings, mixPolicyReachesBothDirections}` — anchor-naming inconsistency between I/O matrix rows (Model A in `Ladder.init`, Model B in factory). Adopted Model A throughout (Spec Change Log entry 4).
- Test failure: `ChromaticConstructionSessionTests/placeFinalSlotImplicitSubmit` — task-scheduling race between the slot-2 orienting cue Task and the final-slot transition. Test updated to snapshot `playCallCount` before/after instead of resetting between operations.

### Completion Notes List

- **Adam consultation (Task 2)** produced three actionable changes: (a) added `rng: inout some RandomNumberGenerator` to `NextPathStrategy.path(...)`, (b) sharpened `SlotTests.pendingAgainClearsPlacedCents`'s description, (c) added three Q3 cent-step math tests (direct-multiplication, non-100 step `outer=900/target=300`, sign symmetry).
- **Boy Scout fix:** `TuningSystem` and `DetunedMIDINote` marked `nonisolated`. Both are pure data + pure functions with no MainActor reason; convention matches `Cents`/`MIDINote`/`Frequency`/`Direction`. All existing callers (already on MainActor) compile and run unchanged.
- **Architectural simplification:** `ChromaticConstructionSession` does not own an RNG. The factory consumes the RNG to produce a concrete settings/ladder; the session accepts the settings via `start(settings:)` and consumes only `NotePlayer`. For `.mix` policy, the screen calls the factory again per trial. This removes the `any RandomNumberGenerator` existential-mutating-method problem from the session entirely.
- **State carries the active slot, not just an index:** `ChromaticConstructionSessionState.walking(activeSlot: Slot, committed: [Slot], ladder: Ladder)` — the active slot's `placedCents` doubles as the slider's starting position when `stepBack()` reactivates a prior slot, eliminating a separate `activeSlotPreviousPlacedCents` observable.
- **PF-070 filed:** `bin/check-dependencies.sh` matches feature names inside doc comments (false positive at `TimingDotView.swift:214`). Low-severity; cataloged for future cleanup.
- **No-registration verified:** `grep -rn "ChromaticConstruction" Peach/App/ Peach/Core/NavigationDestination.swift` returns zero matches — all registration deferred to 86.2 per the epic plan.
- **Pure-Swift module verified:** `grep -rn "import SwiftUI\|import UIKit\|import Charts\|import SwiftData" Peach/Training/ChromaticConstruction/` returns zero matches.

### File List

(After the 2026-06-12 post-review redesign — the originally-shipped files were replaced wholesale.)

**Production:**
- `Peach/Training/ChromaticConstruction/ChromaticConstructionError.swift`
- `Peach/Training/ChromaticConstruction/ChromaticPath.swift`
- `Peach/Training/ChromaticConstruction/NextPathStrategy.swift`
- `Peach/Training/ChromaticConstruction/MonotonicPath.swift` *(single strategy; direction encoded in `outerInterval.direction`)*
- `Peach/Training/ChromaticConstruction/ChromaticConstructionTrial.swift`
- `Peach/Training/ChromaticConstruction/CompletedChromaticConstructionTrial.swift`
- `Peach/Training/ChromaticConstruction/ChromaticConstructionSettings.swift`
- `Peach/Training/ChromaticConstruction/ChromaticConstructionSession.swift`

**Tests:**
- `PeachTests/Training/ChromaticConstruction/ChromaticPathTests.swift`
- `PeachTests/Training/ChromaticConstruction/MonotonicPathTests.swift`
- `PeachTests/Training/ChromaticConstruction/ChromaticConstructionTrialTests.swift`
- `PeachTests/Training/ChromaticConstruction/CompletedChromaticConstructionTrialTests.swift`
- `PeachTests/Training/ChromaticConstruction/ChromaticConstructionSettingsTests.swift`
- `PeachTests/Training/ChromaticConstruction/ChromaticConstructionSessionTests.swift`

**Modified (Boy Scout):**
- `Peach/Core/Music/TuningSystem.swift` — added `nonisolated` to enum declaration.
- `Peach/Core/Music/DetunedMIDINote.swift` — added `nonisolated` to struct declaration.

**Modified (documentation):**
- `docs/implementation-artifacts/86-1-chromatic-construction-domain-and-session.md` — this file.
- `docs/implementation-artifacts/sprint-status.yaml` — flipped 86.1 ready-for-dev → in-progress → review.
- `docs/implementation-artifacts/deferred-work.md` — added PF-070.

## Change Log

| Date | Change |
|---|---|
| 2026-06-12 | Story 86.1 created (ready-for-dev). |
| 2026-06-12 | Task 1: sprint-status flipped to in-progress. |
| 2026-06-12 | Task 2: Adam (music-domain expert) consultation completed. Outcome: `rng:` parameter added to `NextPathStrategy`, three Q3 cent-math tests added, one Slot test description sharpened. |
| 2026-06-12 | Task 3: domain primitives implemented tests-first. `Path` renamed to `ChromaticPath` (SwiftUI.Path collision). `TuningSystem` + `DetunedMIDINote` marked `nonisolated` (Boy Scout). `Ladder.init` path validation switched to net-signed-span. |
| 2026-06-12 | Task 4: settings factory implemented tests-first. Resolved anchor-naming inconsistency by adopting Model A throughout (lowerAnchor = walk start). |
| 2026-06-12 | Task 5: session state machine implemented tests-first. Session does not own an RNG (factory consumes it; session receives concrete ladder). `.walking` state carries the full active `Slot`. |
| 2026-06-12 | Task 6: pre-commit gate green on all four schemes (iOS Debug 2054 / macOS Debug 2041 / iOS Research 2214 / macOS Research 2201). PF-070 filed for `check-dependencies.sh` false positive. |
| 2026-06-12 | Task 7: `/simplify-code` applied 1 patch (Q1 — capture-list consistency with sibling sessions). Three findings rejected with rationale. |
| 2026-06-12 | Task 8: sprint-status flipped to review. Story status flipped to review. |
| 2026-06-12 | Post-review redesign: deleted `Ladder`, `Slot`, `Anchor`, `Path` typealias, `ChromaticConstructionDirectionPolicy`, `MonotonicAscendingPath`, `MonotonicDescendingPath`. Introduced `ChromaticPath` (struct with MIDI-range validation), `MonotonicPath` (single strategy; direction in `outerInterval`), `ChromaticConstructionTrial` / `CompletedChromaticConstructionTrial` (mirrors PitchDiscrimination Trial split). Dropped `targetStep` (YAGNI; 12-TET only). Dropped `tuningSystem` from settings/errors (discipline implicitly equal-tempered). Session adopts the PitchDiscrimination event/effect/reduce shape. All four schemes green: iOS Debug 2051 / macOS Debug 2038 / iOS Research 2211 / macOS Research 2198. |
| 2026-06-12 | `/simplify-code` applied two cleanups: dropped the do-catch in `Session.beginNextTrial` (`try!` is correct — strategy throw modes are all caller-validated invariants); dropped dead `isPaused = false` reset in `Session.start` (guard already establishes the invariant). |
| 2026-06-12 | Deferred-work challenge: all eight initial PF-### deferrals re-examined. PF-071/073/077/078 already dissolved by the redesign; PF-072 wrong premise (project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — session is implicitly MainActor); PF-074 dismissed as "validation for scenarios that can't happen"; PF-076 dismissed (matches sibling pattern, no real bug). PF-075 fixed in place across `Trial.stepBack`, `Trial.reopenFinalPosition`, and `Session.playOrientingCueForCurrentActivePosition` — silent-fail guards replaced with implicit force-unwraps documented by the invariants that hold them. Zero deferrals from this story. |
