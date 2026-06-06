---
title: 'Story 85.5: Make NoteRange and PianoKeyboardLayout nonisolated to match Core/Music convention'
type: 'cleanup'
created: '2026-06-05'
status: 'done'
baseline_commit: '3d6dec25'
context:
  - '{project-root}/docs/implementation-artifacts/deferred-work.md'
closes:
  - 'PF-025'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem.** `Peach/Core/Music/` types follow a `nonisolated` convention — `MIDINote` and the other primary domain primitives are nonisolated by design so they can compose freely with concurrency-isolated callers. `NoteRange` and `PianoKeyboardLayout` deviate: `NoteRange.Hashable` is main-actor-isolated, which transitively isolates `PianoKeyboardLayout` and blocks storing `NoteRange` in any `nonisolated` value. Story 81.3's Spec Change Log named this as a trap.

The inconsistency is Medium-severity not because of a concrete current bug — strict-concurrency builds are clean — but because it's a load-bearing blocker for any future work that wants to store or pass `NoteRange` across actor boundaries. Stories 85.1 (lifecycle consolidation) and 85.3 (sequencer concurrency audit) are about to touch concurrency-adjacent surfaces, raising the probability that this constraint bites.

**Approach.** Make `NoteRange` `nonisolated` (matching the rest of Core/Music). Make `PianoKeyboardLayout` `nonisolated` too. Audit first to confirm no caller depends on the current main-actor isolation; then apply.

**Design principle.** Core/Music holds domain primitives that should be freely composable across isolation boundaries — they describe musical reality, not UI policy. The current main-actor isolation on `NoteRange.Hashable` is a residual leak from when `NoteRange` was tangled with UI state; the cleanup decouples the domain type from that history.

## Boundaries & Constraints

**Always:**
- PF-025 is closed by this story or its scope is renegotiated with explicit human authorization.
- `NoteRange` becomes `nonisolated` (matching `MIDINote`'s shape in the same Core/Music folder).
- `PianoKeyboardLayout` becomes `nonisolated` (matching the Core/Music convention; the transitive isolation from `NoteRange` is what currently forces it main-actor).
- Strict-concurrency build remains clean on all four schemes after the isolation change.
- Behavioural parity: every existing test passes without modification; every existing call site continues to compile (most as-is, some with explicit isolation hops if they were implicitly relying on the main-actor isolation).
- Pre-commit gate: `bin/test.sh && bin/test.sh -p mac` AND `bin/test.sh --research && bin/test.sh --research -p mac` green.
- Catalog hygiene on merge: remove the PF-025 section from `deferred-work.md` in the same change; cite the ID in the commit message.

**Ask First:**
- If the audit (Task 1) reveals any caller that actually depends on the current main-actor isolation — e.g., a SwiftUI view that holds `NoteRange` in `@State` and reads it via implicit main-actor isolation — pause and confirm the call-site change before unwinding the isolation.
- If removing the isolation surfaces new concurrency requirements at downstream callers (Sendable violations, actor-isolation warnings) that ripple beyond `NoteRange` / `PianoKeyboardLayout` and their direct callers, pause and present the dependency map before proceeding.
- If the audit recommends a broader Core/Music isolation review (e.g., the conventions need to be documented in the module-level doc-comment), pause and confirm scope.

**Never:**
- No other Core/Music type's isolation changes. Just `NoteRange` and `PianoKeyboardLayout`.
- No protocol changes (no new protocols, no protocol extensions touched beyond what the isolation removal requires for compile correctness).
- No drive-by closures of adjacent catalog entries (PF-019 is closed; PF-024 is WONT-FIX; PF-020 has its own story).
- No API surface change beyond the isolation removal. The two types' public methods, properties, and signatures stay as they are; only the isolation annotations change.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Existing call site compiles after isolation removal | Any current `NoteRange` or `PianoKeyboardLayout` reference in the codebase | Compiles without modification, or compiles with an explicit isolation hop if the caller was relying on transitive main-actor isolation | N/A |
| Existing tests pass after isolation removal | Full test suite on all four schemes | All tests pass without modification | N/A |
| Strict-concurrency build remains clean | Both Debug and Research schemes | Build clean; no new Sendable / actor-isolation warnings introduced | N/A |
| Future `nonisolated` consumer can compose with NoteRange | Hypothetical: `nonisolated final class X { let range: NoteRange }` | Compiles successfully (currently fails — that failure is the load-bearing motivation for this story) | N/A |

</frozen-after-approval>

## Code Map

**Deliberately empty pre-verification.** Task 1's audit produces the verified code map and appends it here. Catalog-referenced surfaces:

- `Peach/Core/Music/NoteRange.swift` — the type whose `Hashable` conformance is main-actor-isolated
- `Peach/Core/Music/PianoKeyboardLayout.swift` — transitively main-actor-isolated because it stores `NoteRange`
- Every `NoteRange` consumer (via `grep -rn NoteRange Peach/ PeachTests/`)
- Every `PianoKeyboardLayout` consumer (similar grep)

**Added during verification (scope discovery):**

Direct `NoteRange` consumers (source):
- `Peach/Core/Music/NoteRange.swift` — the type
- `Peach/Core/Music/PianoKeyboardLayout.swift:11` — stored property `let noteRange: NoteRange`
- `Peach/Core/Music/TempoRange.swift:6` — doc-comment reference only ("Follows the same pattern as `NoteRange`"); no code dependency
- `Peach/Core/Ports/UserSettings.swift:4` — `var noteRange: NoteRange { get }` protocol requirement
- `Peach/Settings/SettingsKeys.swift:38-51` — `static let defaultNoteRange = NoteRange(...)`, `NoteRange.minimumSpan` arithmetic
- `Peach/Settings/AppUserSettings.swift:6-12` — `UserSettings` conformer returning `NoteRange`
- `Peach/Settings/NoteRangeSelector.swift:8,58,93,99,103,106,385,395` — constructor call, `minimumSpan` constant, doc comment
- `Peach/Settings/SettingsScreen.swift` — uses `NoteRangeSelector`, never the type directly
- `Peach/App/PreviewDefaults.swift:29` — `let noteRange = NoteRange(...)`
- `Peach/Training/PitchDiscrimination/PitchDiscriminationSettings.swift:4,18` — settings struct property + default
- `Peach/Training/PitchMatching/PitchMatchingSettings.swift:4,16` — settings struct property + default

Direct `NoteRange` consumers (tests): `PeachTests/Mocks/MockUserSettings.swift`; `PeachTests/Settings/{SettingsTests, AppUserSettingsTests, NoteRangeSelectorTests}.swift`; `PeachTests/Core/Music/{NoteRangeTests, PianoKeyboardLayoutTests}.swift`; `PeachTests/Core/Training/{PitchDiscriminationSettingsTests, PitchMatchingSettingsTests}.swift`; `PeachTests/Core/Algorithm/KazezNoteStrategyTests.swift`; `PeachTests/Training/PitchDiscrimination/PitchDiscriminationSessionUserDefaultsTests.swift`, `PitchDiscriminationSessionSettingsTests.swift`; `PeachTests/Training/PitchMatching/PitchMatchingSessionTests.swift`.

Direct `PianoKeyboardLayout` consumers (source):
- `Peach/Core/Music/PianoKeyboardLayout.swift` — the type
- `Peach/Settings/NoteRangeSelector.swift:57,75,76` — `static let layout`, `PianoKeyboardLayout.isWhiteKey` (already `nonisolated`)

Direct `PianoKeyboardLayout` consumers (tests): `PeachTests/Core/Music/PianoKeyboardLayoutTests.swift`.

## Tasks & Acceptance

**Execution:**

- [x] **Task 1 — Audit (must complete and review before any code change).** `grep -rn` for every `NoteRange` and `PianoKeyboardLayout` reference across `Peach/` and `PeachTests/`. For each consumer, classify: (a) compiles unchanged after isolation removal, (b) requires an explicit isolation hop, or (c) genuinely depends on main-actor isolation (the only case requiring human decision). Output: append the consumer map under the "Code Map" heading above; flag any (c) entries explicitly. **Halt for human review if any (c) entries surface.** If only (a) and (b) categories appear, the audit's finding is "safe to unwind" and Task 2 proceeds.
- [x] **Task 2 — Approach lock-in (post-audit).** Confirm the isolation-removal pattern based on the audit. Typical pattern: drop the `@MainActor` annotation on `NoteRange.Hashable`'s `==` / `hash(into:)` (or on `NoteRange` itself, depending on how the isolation propagates today); drop `@MainActor` on `PianoKeyboardLayout`. Identify any (b) call sites that need isolation hops.
- [x] **Task 3 — Remove `NoteRange`'s isolation.** Apply the change. Run `bin/build.sh` (both schemes) to surface any (b)-category call-site updates needed. Apply those updates.
- [x] **Task 4 — Remove `PianoKeyboardLayout`'s isolation.** Apply the change. Build again; apply any further (b)-category updates.
- [x] **Task 5 — Catalog hygiene.** Remove the PF-025 section from `docs/implementation-artifacts/deferred-work.md`. Cite PF-025 in the commit message.
- [x] **Task 6 — Pre-commit gates.** Run `bin/test.sh && bin/test.sh -p mac` and `bin/test.sh --research && bin/test.sh --research -p mac`. All four green; strict-concurrency build clean.

**Acceptance Criteria:**

- **PF-025 isolation removed.** `NoteRange` and `PianoKeyboardLayout` are both `nonisolated`. A test that constructs `final class TestConsumer { let range: NoteRange }` outside the main actor compiles successfully (the failure mode the story is closing).
- **Existing behavior parity.** Every existing test passes on all four schemes without modification.
- **Strict-concurrency build clean.** No new Sendable / actor-isolation warnings on Debug or Research schemes.
- **Pre-commit gate.** All four schemes green: Debug × {iOS, macOS} and Research × {iOS, macOS}. No new compiler warnings.
- **Catalog hygiene.** PF-025 section removed from `deferred-work.md` in the closing commit.

## Audit Findings

**Finding: safe to unwind.** All consumers fall into category **(a) compiles unchanged**. Zero **(b)** isolation-hop sites; zero **(c)** main-actor-dependent sites.

**Reasoning.** With `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, every consumer surveyed is implicitly main-actor isolated (SwiftUI Views, Settings structs, test suites, the `UserSettings` protocol). Main-actor code can freely read and call `nonisolated` types — `nonisolated` strictly removes a constraint without imposing new ones. Concretely:

- **`PianoKeyboardLayout.swift`** stores `let noteRange: NoteRange`. Currently this transitively pins `PianoKeyboardLayout` to main-actor. After both types become `nonisolated`, the storage relationship stays valid (nonisolated type storing nonisolated value).
- **`SettingsKeys.swift`** holds `static let defaultNoteRange = NoteRange(...)`. The `NoteRange.init` precondition path (`upperBound - lowerBound >= minimumSpan`) executes via the `MIDINote.-` operator already marked `nonisolated`. The static stays main-actor-accessible (its enclosing type is main-actor) and the initializer remains valid.
- **`NoteRangeSelector.swift`** holds `static let layout = PianoKeyboardLayout(noteRange: NoteRange(...))`. View struct stays main-actor; constructing nonisolated values from a main-actor context is legal.
- **`UserSettings`** protocol declares `var noteRange: NoteRange { get }`. The getter requirement is main-actor (protocol is implicitly main-actor); returning a nonisolated value type is fine. `AppUserSettings` and `MockUserSettings` conformances stay main-actor.
- **Settings structs (`PitchDiscriminationSettings`, `PitchMatchingSettings`)** hold `var noteRange: NoteRange` with a default constructor expression. Both structs are value types passed across `start(settings:)` calls; the default expressions run at the call site (main-actor) and remain valid.
- **Tests** are struct-based with `async` test methods (main-actor by default). `Set<NoteRange>` literal usage exercises `Hashable` which becomes nonisolated — main-actor callers retain access.

No SwiftUI `@State` of `NoteRange`, no `Task.detached`, no actor-isolated background storage of `NoteRange` was discovered.

Task 2 proceeds.

## Spec Change Log

*(empty — populated by review iterations if any)*

## Suggested Review Order

**Domain-type isolation change (the core of the story)**

- Single-token addition; mirrors `MIDINote.swift:8` — the canonical Core/Music pattern.
  [`NoteRange.swift:8`](../../Peach/Core/Music/NoteRange.swift#L8)

- Type-level `nonisolated` subsumes the three previously-redundant inner markers; whole struct now follows the MIDINote shape.
  [`PianoKeyboardLayout.swift:10`](../../Peach/Core/Music/PianoKeyboardLayout.swift#L10)

**Pattern reference**

- Compare against the canonical Core/Music shape this story is now matching.
  [`MIDINote.swift:8`](../../Peach/Core/Music/MIDINote.swift#L8)

**Catalog hygiene**

- PF-025 section deleted; entry no longer occupies a slot between PF-022 (line ~191) and PF-036 (now line ~204).
  [`deferred-work.md:204`](deferred-work.md#L204)

**Sprint-status**

- Story key flipped `ready-for-dev` → `in-progress` → (will be) `review` on commit.
  [`sprint-status.yaml:806`](sprint-status.yaml#L806)
