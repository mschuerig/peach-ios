---
title: 'Story 85.2: Move PeachApp heavyweight initialization out of init() to eliminate macOS double-init'
type: 'cleanup'
created: '2026-06-05'
status: 'ready-for-dev'
baseline_commit: '6c6784f5'
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

**Deliberately empty pre-verification.** Task 1 produces the verified code map and appends it here. Catalog-referenced surfaces:

- `Peach/App/PeachApp.swift` — `init()` body and stored properties
- `Peach/Audio/SoundFontEngine.swift` — construction side effects
- Wherever `PerceptualProfile` is constructed (init log site identifies it)
- Wherever `ModelContainer` is set up for the app (SwiftData `@main` integration)
- Session constructors that depend on the above

**Added during verification (scope discovery):**

- *(populated by Task 1)*

## Tasks & Acceptance

**Execution:**

- [ ] **Task 1 — Verification (must complete and review before any code change).** Confirm against current code: (a) does the double-init on macOS still reproduce? Run the app on macOS, capture the launch log, count "PerceptualProfile initialized (cold start)" lines. (b) What exactly does `PeachApp.init()` do today? Catalog every observable side-effect. (c) Which idiom — `@State` factories or shared `AppContainer` — fits the existing wiring with the smallest delta? Sketch both. (d) Are there any constructor side effects that *must* run twice for some reason (event registration, etc.)? Output: append a verified code map below, log capture, and the chosen idiom with rationale. **Halt for human review before Task 2.**
- [ ] **Task 2 — Approach lock-in.** Based on verification, finalise the chosen idiom and the deletion/relocation list. Update Boundaries & Constraints if Ask-First conditions triggered.
- [ ] **Task 3 — Tests-first contract.** Write a test (or instrumentation hook) that asserts heavyweight resources construct exactly once across the surviving app lifetime. Use whatever mechanism is testable — counted construction via a test-injectable factory, or a `#if DEBUG` counter — without coupling the production code to the test.
- [ ] **Task 4 — Relocate construction.** Move heavyweight init out of `PeachApp.init()` per the locked idiom.
- [ ] **Task 5 — Verify on both platforms.** Re-run cold launch on macOS (logs show exactly one of each) and on iOS (no regression). Capture logs for the commit message.
- [ ] **Task 6 — Catalog hygiene.** Remove PF-002 from `docs/implementation-artifacts/deferred-work.md`. Cite PF-002 in the commit message.
- [ ] **Task 7 — Pre-commit gates.** Run `bin/test.sh && bin/test.sh -p mac` and `bin/test.sh --research && bin/test.sh --research -p mac`. Both green.

**Acceptance Criteria:**

- **PF-002.** Given a cold app launch on macOS, when the launch completes, then the launch log contains exactly one "PerceptualProfile initialized (cold start)" line, exactly one `SoundFontEngine` construction (asserted by counted instrumentation or log), and exactly one `ModelContainer` setup.
- **iOS parity.** Given a cold app launch on iOS, when the launch completes, then heavyweight resources construct exactly once and the surviving app behaves identically to `baseline_commit`.
- **PeachApp.init() is lightweight.** Static inspection of `PeachApp.init()` confirms it constructs no heavyweight type; instrumentation confirms no observable side effects during the discarded second instance.
- **Pre-commit gate.** Both schemes pass on both platforms: `bin/test.sh && bin/test.sh -p mac` (Debug) and `bin/test.sh --research && bin/test.sh --research -p mac` (Research). No new compiler warnings.
- **Catalog hygiene.** PF-002 section removed from `deferred-work.md` in the closing commit, which cites PF-002.

## Spec Change Log

*(empty — populated by review iterations if any)*
