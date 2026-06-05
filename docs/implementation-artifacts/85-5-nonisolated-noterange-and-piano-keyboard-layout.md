---
title: 'Story 85.5: Make NoteRange and PianoKeyboardLayout nonisolated to match Core/Music convention'
type: 'cleanup'
created: '2026-06-05'
status: 'ready-for-dev'
baseline_commit: '6c6784f5'
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

- *(populated by Task 1)*

## Tasks & Acceptance

**Execution:**

- [ ] **Task 1 — Audit (must complete and review before any code change).** `grep -rn` for every `NoteRange` and `PianoKeyboardLayout` reference across `Peach/` and `PeachTests/`. For each consumer, classify: (a) compiles unchanged after isolation removal, (b) requires an explicit isolation hop, or (c) genuinely depends on main-actor isolation (the only case requiring human decision). Output: append the consumer map under the "Code Map" heading above; flag any (c) entries explicitly. **Halt for human review if any (c) entries surface.** If only (a) and (b) categories appear, the audit's finding is "safe to unwind" and Task 2 proceeds.
- [ ] **Task 2 — Approach lock-in (post-audit).** Confirm the isolation-removal pattern based on the audit. Typical pattern: drop the `@MainActor` annotation on `NoteRange.Hashable`'s `==` / `hash(into:)` (or on `NoteRange` itself, depending on how the isolation propagates today); drop `@MainActor` on `PianoKeyboardLayout`. Identify any (b) call sites that need isolation hops.
- [ ] **Task 3 — Remove `NoteRange`'s isolation.** Apply the change. Run `bin/build.sh` (both schemes) to surface any (b)-category call-site updates needed. Apply those updates.
- [ ] **Task 4 — Remove `PianoKeyboardLayout`'s isolation.** Apply the change. Build again; apply any further (b)-category updates.
- [ ] **Task 5 — Catalog hygiene.** Remove the PF-025 section from `docs/implementation-artifacts/deferred-work.md`. Cite PF-025 in the commit message.
- [ ] **Task 6 — Pre-commit gates.** Run `bin/test.sh && bin/test.sh -p mac` and `bin/test.sh --research && bin/test.sh --research -p mac`. All four green; strict-concurrency build clean.

**Acceptance Criteria:**

- **PF-025 isolation removed.** `NoteRange` and `PianoKeyboardLayout` are both `nonisolated`. A test that constructs `final class TestConsumer { let range: NoteRange }` outside the main actor compiles successfully (the failure mode the story is closing).
- **Existing behavior parity.** Every existing test passes on all four schemes without modification.
- **Strict-concurrency build clean.** No new Sendable / actor-isolation warnings on Debug or Research schemes.
- **Pre-commit gate.** All four schemes green: Debug × {iOS, macOS} and Research × {iOS, macOS}. No new compiler warnings.
- **Catalog hygiene.** PF-025 section removed from `deferred-work.md` in the closing commit.

## Audit Findings

*(empty — populated by Task 1; halt for human review if (c)-category consumers surface)*

## Spec Change Log

*(empty — populated by review iterations if any)*
