---
title: 'Story 85.2: Move PeachApp heavyweight initialization out of init() to eliminate macOS double-init'
type: 'cleanup'
created: '2026-06-05'
status: 'done'
baseline_commit: '737f76cc'
context:
  - '{project-root}/docs/implementation-artifacts/deferred-work.md'
closes:
  - 'PF-002'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem.** On macOS, SwiftUI instantiates the `@main App` struct (`PeachApp`) twice before settling on a single instance. `PeachApp.init()` currently does heavyweight work — constructing `PerceptualProfile`, `SoundFontEngine`, the four training sessions, and other persistent infrastructure. Each instantiation pays that full cost; the second-instance objects are discarded but their construction side-effects already ran. Visible in logs as 2× "PerceptualProfile initialized (cold start)"; less visible but real: 2× `ModelContainer` setup, 2× `AudioEngine` init, doubled startup work on every cold launch on macOS. This is a known SwiftUI macOS behavior, not a Peach bug per se — but `PeachApp.init()` is the place where Peach has the power to make it free.

**Approach.** Make `PeachApp.init()` lightweight. Heavyweight resources move behind one of two well-known SwiftUI idioms — pick during verification (Task 1):

- **(a) `@State` with a factory.** Each heavyweight singleton becomes a `@State` property initialised via a closure that runs once when the property is first read by SwiftUI's storage. SwiftUI guarantees `@State` initialisation runs exactly once for the surviving App instance; the discarded second instance's `@State` storage never materialises.
- **(b) A lazily-created shared container.** A single `AppContainer` (or similar) holds the heavyweight references; constructed via a static-let factory or actor-isolated initialiser; `PeachApp` holds a reference, not the contents.

Both eliminate the second instance's cost by construction. The verification step decides which fits the existing code shape better.

**Design principle.** Same mechanism/policy separation as Story 85.1 [[feedback_design_by_contract_and_separation]], applied at the app-construction layer: `PeachApp` declares *what* exists (the scene graph, the bindings, the body); SwiftUI decides *when* to instantiate it; the heavyweight resources stop being collateral damage of that decision.

## Boundaries & Constraints

**Always:**
- After this story lands, `PeachApp.init()` does no work whose side effects are observable in logs or instruments (no `PerceptualProfile.init`, no `SoundFontEngine.init`, no session construction, no `ModelContainer` setup). The body is reduced to property declarations and a trivial body if any.
- Behavioural parity for the surviving instance: the heavyweight resources are constructed exactly once per app launch, with the same dependency wiring (e.g., the same `SoundFontEngine` is shared by every session that needs it).
- The fix works on both iOS and macOS; iOS does not regress (SwiftUI does not double-init on iOS, but the lazy-init pattern must still construct exactly once and at the right time).
- Pre-commit gate: `bin/test.sh && bin/test.sh -p mac` AND `bin/test.sh --research && bin/test.sh --research -p mac` green.
- Catalog hygiene on merge: remove the PF-002 section from `deferred-work.md` in the same change; cite the ID in the commit message.

**Ask First:**
- If verification (Task 1) reveals that the double-init logs have stopped reproducing on current `main` (some other change incidentally fixed it), pause and confirm before any code change. The story may close as "no-op" with a `deferred-work.md` removal and a one-line note in the commit citing the verification finding.
- If verification reveals that one of the heavyweight constructors has lifecycle-meaningful side effects on `init` (e.g., starting a background task, registering an observer, opening a file handle) that must run on the discarded instance for some non-obvious reason, pause and discuss the implications before relocating.
- If the chosen idiom forces a public-API change to any of the heavyweight types — making something `internal` vs `public`, changing initialiser visibility, or requiring a protocol extraction — pause and confirm scope before proceeding.

**Never:**
- No refactor of the heavyweight types themselves. `PerceptualProfile`, `SoundFontEngine`, sessions, and `ModelContainer` setup stay structurally as they are; only the timing and uniqueness of their construction change.
- No SwiftUI App lifecycle refactor beyond this fix. Scenes, scene-phase observers, the existing toolbar / menu / window-group setup all stay as they are.
- No DI-container library introduction. Plain Swift + SwiftUI's existing storage primitives (`@State`, static-let lazy, actor-isolated factories) are sufficient.
- No catalog drive-by closures of unrelated PF entries. PF-001/003/005 are Story 85.1's scope; this story stays scoped to PF-002.

## I/O & Edge-Case Matrix

Filled to the closure level; the verified code map (Task 1) may extend this.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Cold launch on macOS | App starts | Logs show exactly one "PerceptualProfile initialized (cold start)"; exactly one `SoundFontEngine` construction; exactly one `ModelContainer` setup | N/A |
| Cold launch on iOS | App starts | Same as today — exactly one of each; no behavioural change | N/A |
| First scene-attach access | SwiftUI attaches the WindowGroup body | The heavyweight resources exist and are wired identically to today | N/A |
| Quick relaunch on macOS | User quits, relaunches | One construction per launch, no carryover from previous process | N/A |
| Window close + reopen on macOS (if app stays alive) | User closes the main window, opens a new one | Existing heavyweight resources continue to be shared; no second construction | N/A |
| Preview / `PreviewDefaults` callers | SwiftUI previews resolve `PeachApp`-adjacent views | Preview defaults continue to substitute stub heavyweights as they do today; no production-path init triggered by preview | N/A |

</frozen-after-approval>

## Code Map

**Catalog-referenced surfaces (pre-verification):**

- `Peach/App/PeachApp.swift` — `init()` body and stored properties
- `Peach/Audio/SoundFontEngine.swift` — construction side effects
- Wherever `PerceptualProfile` is constructed (init log site identifies it)
- Wherever `ModelContainer` is set up for the app (SwiftData `@main` integration)
- Session constructors that depend on the above

**Added during verification (Task 1, 2026-06-05):**

### What `PeachApp.init()` does today

Reading `Peach/App/PeachApp.swift:45-105`, the body of `init()` performs (in order):

1. `TrainingDisciplineRegistry.bootstrap(disciplines:)` — `Peach/App/PeachApp.swift:46`. Precondition-guarded (see below).
2. `CSVHistoryRegistry.bootstrap(histories:)` — `Peach/App/PeachApp.swift:47`. Precondition-guarded.
3. `configureSingleWindowApp()` — macOS only, sets `NSWindow.allowsAutomaticWindowTabbing = false`. Idempotent.
4. `Self.setupDataStore()` — `Peach/App/PeachApp.swift:234-251`. Constructs `ModelContainer(for: schema, migrationPlan:)`, wraps in `TrainingDataStore`. Touches disk; on schema mismatch wipes store files.
5. `Self.setupSoundFontInfrastructure()` — `Peach/App/PeachApp.swift:269-286`. Constructs `SoundFontLibrary` (parses SF2 PHDR + sorts presets) and `SoundFontEngine` (creates `AVAudioEngine`, attaches sampler, registers MIDI blocks, calls `audioSessionConfigurator.configure(...)`, calls `engine.start()`, attaches source node — `Peach/Core/Audio/SoundFontEngine.swift:280-309`). Audio session + engine start are observable side effects of `init`.
6. `Self.setupPlayers(engine:library:userSettings:)` — `Peach/App/PeachApp.swift:288-313`. Constructs `SoundFontPlayer` (channel 0) and `SoundFontBeatSequencer` (channel 1), creates channel 1 on the engine.
7. `Self.setupProfile(dataStore:)` — `Peach/App/PeachApp.swift:329-338`. Builds `PerceptualProfile` from all stored records (cost scales with data size); constructs `ProgressTimeline`.
8. `Self.createTransferService(dataStore:profile:)` — `Peach/App/PeachApp.swift:340-352`.
9. `Self.createAllSessions(notePlayer:beatSequencer:profile:dataStore:)` — `Peach/App/PeachApp.swift:366-411`. Constructs `MIDIKitAdapter` (initialises MIDI client), four session instances + their observer adapters.
10. `Self.buildCoordinators(...)` — `Peach/App/PeachApp.swift:500-541`. Constructs `TrainingLifecycleRegistry`, `TrainingLifecycleCoordinator`, `SettingsCoordinator`.
11. `try? Tips.configure()` — TipKit one-time setup.

All eleven steps run *every* time `init()` runs. The `@State` storage receives the *already-constructed* heavyweight references via `State(wrappedValue:)`. SwiftUI's `@State` semantics do not lazily defer the wrappedValue computation — the closure (or expression) that produces it runs on every struct init.

Log sites that would fire twice if `init()` ran twice:
- `Peach/Core/Profile/PerceptualProfile.swift:39` — `"PerceptualProfile initialized via builder"` (this is the post-refactor analogue of PF-002's original canary `"PerceptualProfile initialized (cold start)"`; see *Canary evolution* below).
- `Peach/Core/Audio/SoundFontEngine.swift:309` — `"SoundFontEngine initialized with Samples.sf2"`.
- `Peach/Core/Audio/SoundFontLibrary.swift:42` — `"SoundFontLibrary initialized with N melodic, M percussion presets"`.
- `Peach/Core/Audio/SoundFontPlayer.swift:40` — `"SoundFontPlayer initialized on channel … with preset …"`.
- `Peach/App/PeachApp.swift:335` — `"Profile loaded in <ms>ms"`.

### Canary evolution

PF-002 (2026-03-29) cites `"PerceptualProfile initialized (cold start)"` as the visible symptom. That log line is on `PerceptualProfile.init()` (no-args) at `Peach/Core/Profile/PerceptualProfile.swift:32`. The current `setupProfile` path (`Peach/App/PeachApp.swift:329-338`) uses `init(build:)` and logs `"…via builder"` at `Peach/Core/Profile/PerceptualProfile.swift:39`. The original `(cold start)` canary therefore does not fire from `setupProfile` today — but it *can* still fire from `EnvironmentValues` `@Entry` defaults at `Peach/App/EnvironmentKeys.swift:6` (`progressTimeline`) and `:8` (`perceptualProfile`), both of which call the no-args `PerceptualProfile()`. In production those defaults are overridden by `PeachApp.environment(\.perceptualProfile, profile)` / `\.progressTimeline, progressTimeline)` at the WindowGroup body, so the `(cold start)` line is suppressed; if PF-002's original symptom counted firings from those defaults rather than from `PeachApp.init()`, that was a different mechanism than the double-init claim.

The current verification rests on two signals that *are* coupled to `PeachApp.init()` running:
1. The bootstrap preconditions (see below) — a structural assertion that does not depend on log lines at all.
2. Michael's manual log-count of `"SoundFontEngine initialized"`, `"SoundFontLibrary initialized"`, `"SoundFontPlayer initialized"`, `"PerceptualProfile initialized via builder"`, and `"Profile loaded"` — each of those *is* on the `PeachApp.init()` → `Self.setupXxx(...)` path.

Both signals confirm `PeachApp.init()` runs once. The `(cold start)` canary's behaviour under `@Entry` defaults is a separate question that the closure does not need to answer to be sound on PF-002.

### Critical anomaly — the precondition test

`TrainingDisciplineRegistry.bootstrap` (`Peach/Core/Training/Discipline/TrainingDisciplineRegistry.swift:47-52`) and `CSVHistoryRegistry.bootstrap` (`Peach/Core/Training/Discipline/CSVHistoryRegistry.swift:54-59`) both contain:

```swift
precondition(registry == nil, "…bootstrap(…) called more than once")
```

These two `bootstrap` calls are the **first two lines** of `PeachApp.init()` (lines 46–47), executed before any heavyweight setup. If SwiftUI on macOS instantiated `PeachApp` twice in the same process, the second `init()` would trip the precondition and the app would crash on launch with a clear message.

The bootstrap mechanism with this precondition landed in story 76.2 (2026-04-25, commit `a5ebcac4`) — about a month *after* PF-002 was logged (Story 68.6, 2026-03-29). The 76.5 follow-up tightened the production preconditions. The app has shipped through Epic 77+ on macOS without this precondition firing.

### Implication

If `PeachApp.init()` were currently being called twice on macOS, the app would not launch. Since macOS launch is observed to succeed in current `main`, `init()` is running exactly **once** per process. The PF-002 symptom (double `ModelContainer`/`AudioEngine`/`PerceptualProfile`/`SoundFontEngine` construction inside `PeachApp.init()`) is no longer reproducing in the current code. (The original PF-002 description's `(cold start)` canary maps to a different log path under the post-76.2 refactor — see *Canary evolution* above.)

PF-002 was logged at a time when there was no precondition surfacing the double-init; the macOS double-init may have stopped between 2026-03-29 and 2026-04-25, plausibly due to one of: SwiftUI macOS framework change, the 75.6 composition-root decomposition, the 75.2 audio-engine extraction, or the addition of the `Window("Settings")` scene alongside the original `WindowGroup` (`Peach/App/PeachApp.swift:148-160`). None of those touched the init body directly but any could have shifted SwiftUI's macOS scene-resolution path.

### Verification — sandbox limit and the log-count substitute

This automated session could not directly launch the macOS Peach binary to capture a launch log (the harness sandbox blocks both `open` against the app bundle and direct `Contents/MacOS/Peach` execution — sandboxed launch fails on AVAudioUnitSampler component lookup before any log line we'd want to read). Beyond the structural precondition argument, the empirical signal came from Michael's manual log-count on the macOS Debug build (Xcode debugger console, subsystem `com.peach.app`): exactly **one** occurrence each of `SoundFontEngine initialized`, `SoundFontLibrary initialized`, `SoundFontPlayer initialized`, `PerceptualProfile initialized via builder`, and `Profile loaded`. Both signals point the same way; the closure rests on both.

### Idiom sketches (kept for the case the bug does still reproduce)

Both spec options interpreted with current SwiftUI semantics:

- **(a) `@State` of references resolved from a `static let` shared singleton.** `PeachApp` keeps the existing 14 `@State` properties; `init()` reads from a single `static let resources = AppResources()` (Swift `static let` provides lazy + thread-safe one-time init) and stuffs the resolved references into `State(wrappedValue: …)`. The `static let` init runs once even if `PeachApp.init()` runs twice; the second `init()` only re-wraps the same already-constructed references. (The original spec text says "SwiftUI guarantees `@State` initialisation runs exactly once for the surviving App instance" — that is not how `@State` actually behaves; `@State`'s wrappedValue is computed on every struct init. The one-time guarantee has to come from `static let` lazy initialisation, not `@State`.)
- **(b) Lazy `AppContainer` holding immutable heavyweight resources, `@State` retained only for runtime-mutable references.** Move `modelContainer`, `dataStore`, `soundFontLibrary`, `soundFontEngine`, `beatSequencer`, `profile`, `progressTimeline`, `transferService`, `timingOffsetDetectionSession`, `continuousRhythmMatchingSession`, and `midiAdapter` into a `@MainActor final class AppContainer` constructed once via `static let container = AppContainer()`. `@State` keeps only the references that are reassigned at runtime (`notePlayer`, `pitchDiscriminationSession`, `pitchMatchingSession`, `activeSession`, `trainingLifecycle`, `settingsCoordinator`) — those re-bind via `handleSoundSourceChanged` and `trackActiveSession`. `PeachApp.init()` reads from `Self.container` and seeds the mutable `@State` slots.

Approach (b) is the smaller-delta fit because the truly-mutable set is small (6 of 14 currently-`@State` properties) and segregating them clarifies the existing reassignment logic. Approach (a) keeps the existing shape but adds a singleton accessor for every property — more boilerplate, no real conceptual gain.

### "Must run twice" check

No constructor in the heavyweight set has a side effect that needs to run on a discarded instance. The Ask-First items in this regard are clean:

- `MIDIKitAdapter` opens a MIDI client; a second adapter on the same process would re-open it and leak the first — not desired.
- `SoundFontEngine` starts `AVAudioEngine`; a second engine in the same process competes for the audio session.
- `ModelContainer` opens the SwiftData store; a second container in the same process would race the first.
- `TipKit.configure()` is documented as one-shot.

In other words: even *if* the double-init were happening today, no part of the construction surface is "supposed to run twice." A fix is safe to apply on that axis.

## Verification Outcome (Task 1)

**Finding:** PF-002 is **no longer reproducing on current `main`**. The bootstrap preconditions (the very first statements in `PeachApp.init()`, lines 46–47) would crash a second `init()` call, and the app launches normally on macOS. Michael's manual log-count on the macOS Debug build (Xcode debugger console) confirmed exactly one occurrence each of `SoundFontEngine initialized`, `SoundFontLibrary initialized`, `SoundFontPlayer initialized`, `PerceptualProfile initialized via builder`, and `Profile loaded` — both signals agree.

**Closure path (confirmed by Michael 2026-06-05):** no-op per the spec's Ask-First clause —

> "The story may close as 'no-op' with a `deferred-work.md` removal and a one-line note in the commit citing the verification finding."

Concretely:
- PF-002 section removed from `docs/implementation-artifacts/deferred-work.md` (Task 6).
- Commit message cites PF-002 with the verification finding (bootstrap-precondition argument + log-count).
- No code change to `PeachApp.swift` or the heavyweight constructors (Tasks 3–5 skipped).
- Pre-commit gate still ran the full test suite to guarantee the no-op assertion does not destabilise either platform — all four schemes green (Task 7).

## Tasks & Acceptance

**Execution:**

- [x] **Task 1 — Verification (must complete and review before any code change).** Confirm against current code: (a) does the double-init on macOS still reproduce? Run the app on macOS, capture the launch log, count "PerceptualProfile initialized (cold start)" lines. (b) What exactly does `PeachApp.init()` do today? Catalog every observable side-effect. (c) Which idiom — `@State` factories or shared `AppContainer` — fits the existing wiring with the smallest delta? Sketch both. (d) Are there any constructor side effects that *must* run twice for some reason (event registration, etc.)? Output: append a verified code map below, log capture, and the chosen idiom with rationale. **Halt for human review before Task 2.** — done 2026-06-05; PF-002 does not reproduce on current `main`. See *Code Map → Added during verification (Task 1, 2026-06-05)* and *Verification Outcome (Task 1)*.
- [x] **Task 2 — Approach lock-in.** Based on verification, finalise the chosen idiom and the deletion/relocation list. Update Boundaries & Constraints if Ask-First conditions triggered. — Locked: no-op closure per the spec's Ask-First clause. No code change to `PeachApp.swift` or the heavyweight constructors. Boundaries & Constraints unchanged (frozen) — the no-op path is exactly the outcome that clause anticipated, so no renegotiation is required.
- [~] **Task 3 — Tests-first contract.** Write a test (or instrumentation hook) that asserts heavyweight resources construct exactly once across the surviving app lifetime. Use whatever mechanism is testable — counted construction via a test-injectable factory, or a `#if DEBUG` counter — without coupling the production code to the test. — **Skipped (no-op closure).** No new behaviour to assert. The existing `precondition(registry == nil, …)` in `TrainingDisciplineRegistry.bootstrap` / `CSVHistoryRegistry.bootstrap` is the de-facto live regression assertion: a future SwiftUI macOS regression that reintroduces double-init would crash the app on launch.
- [~] **Task 4 — Relocate construction.** Move heavyweight init out of `PeachApp.init()` per the locked idiom. — **Skipped (no-op closure).**
- [~] **Task 5 — Verify on both platforms.** Re-run cold launch on macOS (logs show exactly one of each) and on iOS (no regression). Capture logs for the commit message. — **Skipped (no-op closure).** Michael's manual log-count check on the Xcode debugger console for the macOS Debug build confirmed exactly one of each init log line; iOS was not separately re-verified because no production code is changing.
- [x] **Task 6 — Catalog hygiene.** Remove PF-002 from `docs/implementation-artifacts/deferred-work.md`. Cite PF-002 in the commit message. — Section removed; commit message will cite PF-002 + this verification finding.
- [x] **Task 7 — Pre-commit gates.** Run `bin/test.sh && bin/test.sh -p mac` and `bin/test.sh --research && bin/test.sh --research -p mac`. Both green. — All four green: iOS Debug 1943 passed, macOS Debug 1937 passed, iOS Research 2100 passed, macOS Research 2094 passed.

**Acceptance Criteria:**

- **PF-002.** Given a cold app launch on macOS, when the launch completes, then the launch log contains exactly one "PerceptualProfile initialized (cold start)" line, exactly one `SoundFontEngine` construction (asserted by counted instrumentation or log), and exactly one `ModelContainer` setup.
- **iOS parity.** Given a cold app launch on iOS, when the launch completes, then heavyweight resources construct exactly once and the surviving app behaves identically to `baseline_commit`.
- **PeachApp.init() is lightweight.** Static inspection of `PeachApp.init()` confirms it constructs no heavyweight type; instrumentation confirms no observable side effects during the discarded second instance.
- **Pre-commit gate.** Both schemes pass on both platforms: `bin/test.sh && bin/test.sh -p mac` (Debug) and `bin/test.sh --research && bin/test.sh --research -p mac` (Research). No new compiler warnings.
- **Catalog hygiene.** PF-002 section removed from `deferred-work.md` in the closing commit, which cites PF-002.

## Spec Change Log

- **2026-06-05 — Closed as no-op.** Task 1 verification surfaced the spec's Ask-First condition: PF-002 no longer reproduces on current `main`. The `precondition(registry == nil, …)` guard added to `TrainingDisciplineRegistry.bootstrap` and `CSVHistoryRegistry.bootstrap` in story 76.2 (`a5ebcac4`, 2026-04-25 — one month *after* PF-002 was logged) is the first statement of `PeachApp.init()`. A second `init()` call on macOS would crash the app on the precondition before any heavyweight setup ran. The app launches normally on macOS in current `main`, and Michael's manual log-count on the macOS Debug build (Xcode debugger console) confirmed exactly one occurrence of each of `SoundFontEngine initialized`, `SoundFontLibrary initialized`, `SoundFontPlayer initialized`, `PerceptualProfile initialized via builder`, and `Profile loaded`. Per the spec's Ask-First clause, the story closes with `deferred-work.md` PF-002 removal + a verification note in the commit, and no change to `PeachApp.swift` or any heavyweight constructor. Tasks 3–5 deliberately skipped; Tasks 1, 2, 6, 7 executed.

- **2026-06-05 — Review-iteration patches.** Step-04 adversarial review (Blind + Edge + Acceptance) raised the following findings; classified as `patch` and applied:
  - Tense fix: the *Verification Outcome (Task 1)* section was rewritten from a pre-confirmation "Confirm-before-proceed" framing (Blind #3) to past-tense reflecting Michael's actual log-count confirmation.
  - Canary reconciliation (Blind #7, Edge #1/#2): added a *Canary evolution* sub-section to Code Map explaining that the original PF-002 canary `"PerceptualProfile initialized (cold start)"` belongs to the no-args `PerceptualProfile.init()`, which `setupProfile` does not call (it uses `init(build:)` → `"…via builder"`). The `@Entry` defaults at `Peach/App/EnvironmentKeys.swift:6,8` *do* call the no-args path, but `PeachApp.environment(…)` overrides suppress those defaults in production. The verification's two coupled signals (precondition + `PeachApp.init()`-path log lines) remain sound; the closure does not depend on the `(cold start)` log.
  - Sprint-status header restored (Blind #2): `last_updated` comment in `sprint-status.yaml` had its prior Epic 85 work-order chain context overwritten; restored with a Story 85.2 closure note appended.
  - Acceptance Auditor's status-flip-to-`done` flag (Acc #6): handled at step-05 close, not at review time.
  - All other findings classified as `reject` (git-history-preserved deletion + Ask-First-authorised path; precondition is the live regression assertion; rendering-tool artefacts; out-of-scope Release-config / Preview hosting). Findings list and rationale recorded in the conversation transcript.

## Suggested Review Order

**Verification argument (load-bearing)**

- The precondition that would have caught any second `init()` — the structural backbone of the closure.
  [`85-2-defer-peachapp-heavyweight-init.md:110`](./85-2-defer-peachapp-heavyweight-init.md#L110)

- Why the original `(cold start)` canary doesn't appear in the post-76.2 codepath; what replaces it.
  [`85-2-defer-peachapp-heavyweight-init.md:100`](./85-2-defer-peachapp-heavyweight-init.md#L100)

- Final no-op closure decision and the two signals that support it.
  [`85-2-defer-peachapp-heavyweight-init.md:152`](./85-2-defer-peachapp-heavyweight-init.md#L152)

**Catalog hygiene**

- PF-002 section removed; PF-001 above and PF-003 below intact.
  [`deferred-work.md:164`](./deferred-work.md#L164)

**Workflow bookkeeping**

- Tasks 1, 2, 6, 7 done; Tasks 3, 4, 5 deliberately skipped with rationale.
  [`85-2-defer-peachapp-heavyweight-init.md:170`](./85-2-defer-peachapp-heavyweight-init.md#L170)

- Closure narrative + review-iteration patch trail.
  [`85-2-defer-peachapp-heavyweight-init.md:188`](./85-2-defer-peachapp-heavyweight-init.md#L188)

- Story marked `done`; Epic 85 work-order header preserved.
  [`sprint-status.yaml:799`](./sprint-status.yaml#L799)
