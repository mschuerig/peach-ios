---
title: 'Story 85.4: Restore per-key Voice Control addressing on NoteRangeSelector'
type: 'cleanup'
created: '2026-06-05'
status: 'ready-for-dev'
baseline_commit: '6c6784f5'
context:
  - '{project-root}/docs/implementation-artifacts/deferred-work.md'
closes:
  - 'PF-020'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem.** Story 81.3's Spec Always rule wanted per-key `MIDINote.name` labels addressable by Voice Control ("Tap C3" focuses the C3 key) **alongside** the two-marker adjustable representation used by VoiceOver and Switch Control. The implementation used `.accessibilityRepresentation` to expose the two-marker representation, which replaces the entire accessibility subtree — Voice Control sees only the two Sliders and the per-key Voice Control path is silently lost. The two goals were mutually exclusive in a single SwiftUI configuration as written.

This is a Medium-severity accessibility regression on the non-AX1 path. Voice Control users can no longer address individual keys; they can only nudge the two range markers.

**Approach.** Restructure `NoteRangeSelector`'s accessibility tree so per-key Voice Control addressing and the two-marker adjustable representation coexist. The catalog's sketch — `.accessibilityCustomActions` plus markers as adjustable elements without `.accessibilityRepresentation` — is a candidate; the audit (Task 1) validates it against (a) current SwiftUI semantics, which may have shifted since 2026-06-03, and (b) the AX1+ fallback path, which today swaps to a system Slider via `.accessibilityRepresentation` and must continue to work. The audit produces the locked design before any code change.

**Design principle.** The Story 81.3 trade-off ("AX1+ falls back to a system Slider entirely") established a multimodal access design with separate code paths for AX1 and below-AX1. This story doesn't reopen that decision — it fixes the below-AX1 path so that Voice Control's per-key addressing works there without sacrificing the VoiceOver / Switch Control two-marker behaviour the original design wanted.

## Boundaries & Constraints

**Always:**
- PF-020 is closed by this story or its scope is renegotiated with explicit human authorization.
- Below the AX1 Dynamic Type threshold: Voice Control "Tap C3" (and equivalent commands for every in-range key) focuses the corresponding key.
- Below the AX1 Dynamic Type threshold: VoiceOver and Switch Control continue to interact with the two-marker adjustable representation — moving the lower / upper marker by VoiceOver swipe and Switch Control adjust-action.
- At and above AX1: the existing `.accessibilityRepresentation` → two-Slider fallback path is preserved unchanged. PF-023 (WONT-FIX: AX1+ Slider partner-range shifts during edit) stays untouched.
- Drag, tap-on-dimmed, keyboard arrow, and the existing visual representation continue to behave as today on every Dynamic Type path.
- Pre-commit gate: `bin/test.sh && bin/test.sh -p mac` AND `bin/test.sh --research && bin/test.sh --research -p mac` green.
- Catalog hygiene on merge: remove the PF-020 section from `deferred-work.md` in the same change; cite the ID in the commit message.

**Ask First:**
- If the `/ios-accessibility` audit reveals that the catalog's sketch (`.accessibilityCustomActions` per-key plus markers as adjustable elements) no longer works as the catalog described — either because SwiftUI semantics have shifted since 2026-06-03 or because the AX1+ fallback path entangles with it — pause and present alternative designs before locking in.
- If the audit recommends extracting a custom accessibility container (`UIAccessibilityContainer`-style) rather than composing SwiftUI's existing accessibility modifiers, pause and confirm scope before implementing.
- If implementing per-key addressing requires changing PianoKeyboardLayout's public surface (it currently exposes `xPosition` and `midiNote(at:)` as the primary geometry interface), pause and confirm — PF-019 just landed doc-comments on those methods.

**Never:**
- No change to the AX1+ Slider fallback path. PF-023 stays as it is.
- No new accessibility-platform abstraction (e.g., a generic "multi-modal range selector" wrapper). Solution stays scoped to `NoteRangeSelector`.
- No refactor of `PianoKeyboardLayout` (PF-025 owns its main-actor reshape question; this story stays out of that).
- No drive-by closure of PF-024 (black-key y-aware hit-test). PF-024 is touched at the same component but is a separate concern (gesture hit-testing, not accessibility tree shape); folding it in would expand scope without architectural justification.

## I/O & Edge-Case Matrix

Filled to the closure level; the audit (Task 1) may extend this with newly-surfaced AT paths.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Voice Control below AX1 (PF-020 reachable regression) | User says "Tap C3" with the keyboard visible | C3 is focused / activated | Asserted by accessibility test |
| Voice Control name coverage | User says "Tap <name>" for every in-range MIDINote | Each in-range note is addressable by its name | Asserted by accessibility test over the range |
| VoiceOver below AX1 | User swipes through the keyboard | Two markers are presented as adjustable elements; swipes increment / decrement bound by semitone (current behaviour) | Asserted by accessibility test |
| Switch Control below AX1 | User scans and adjusts | Two markers are scannable as adjustable elements; adjust-action moves the focused bound (current behaviour) | Asserted by accessibility test |
| AX1+ Dynamic Type | User opens NoteRangeSelector at AX1 or higher | `.accessibilityRepresentation` → two-Slider fallback unchanged from `baseline_commit` | Asserted by existing AX1 test (or new test if none exists) |
| Drag / tap / keyboard arrow at any Dynamic Type | User interacts via touch or keyboard | Behaviour unchanged from `baseline_commit` | Asserted by existing tests; new tests if gaps |

</frozen-after-approval>

## Code Map

**Deliberately empty pre-verification.** Task 1's accessibility audit produces the verified code map and appends it here. Catalog-referenced surfaces:

- `Peach/Settings/NoteRangeSelector.swift` — `keyboardBody`, marker accessibility setup, `.accessibilityRepresentation` block
- `Peach/Settings/BoundMarker.swift` (or wherever the marker view lives) — marker accessibility properties
- Any test files exercising NoteRangeSelector accessibility (search via `PeachTests/Settings/NoteRangeSelector*` or grep)

**Added during verification (scope discovery):**

- *(populated by Task 1)*

## Tasks & Acceptance

**Execution:**

- [ ] **Task 1 — Accessibility audit (must complete and review before any code change).** Invoke `/ios-accessibility` against `NoteRangeSelector`'s current accessibility tree. The audit produces: (a) a tree map of the current accessibility surface on the non-AX1 path and the AX1+ fallback path, naming what each AT (VoiceOver / Switch Control / Voice Control / Full Keyboard Access) sees; (b) confirmation or correction of the catalog's framing (the catalog says the two goals were mutually exclusive in the original SwiftUI configuration — verify whether that's still true at current SwiftUI semantics); (c) the locked design — concrete modifier composition (`.accessibilityCustomActions` per-key, markers as `.accessibilityAdjustable`, or whatever the audit endorses) — including how it interacts with the AX1+ fallback path; (d) any additional accessibility paths the audit surfaces (e.g., Full Keyboard Access) that warrant explicit handling. Append output as a new section above. **Halt for human review before Task 2.**
- [ ] **Task 2 — Approach lock-in (post-audit).** Based on the audit, finalise the modifier composition and update Boundaries & Constraints if Ask-First conditions triggered. Identify the AT-specific tests Task 3 will write.
- [ ] **Task 3 — Accessibility tests (tests-first).** Add tests that pin the contract on every relevant AT path: Voice Control per-key addressing for a representative set of in-range notes (at minimum the four boundary notes plus a black-key sample); VoiceOver two-marker adjustable; Switch Control two-marker adjustable; AX1+ Slider fallback. Use whatever test harness `/ios-accessibility` recommends (XCUITest accessibility audits, `accessibilityElements` direct inspection, or both).
- [ ] **Task 4 — Restructure the accessibility tree.** Implement the locked design from Task 2. Replace `.accessibilityRepresentation` with the composition the audit endorsed on the non-AX1 path. Preserve the AX1+ fallback path unchanged.
- [ ] **Task 5 — Catalog hygiene.** Remove the PF-020 section from `docs/implementation-artifacts/deferred-work.md`. Cite PF-020 in the commit message.
- [ ] **Task 6 — Pre-commit gates.** Run `bin/test.sh && bin/test.sh -p mac` and `bin/test.sh --research && bin/test.sh --research -p mac`. All four green.

**Acceptance Criteria:**

- **PF-020 Voice Control.** Given Dynamic Type below AX1 with the keyboard visible, when the user issues a Voice Control command of the form "Tap <name>" for any in-range `MIDINote`, then that key is focused or activated (asserted by accessibility test over a representative sample of in-range notes including white keys, black keys, and the range boundaries).
- **VoiceOver parity below AX1.** Given Dynamic Type below AX1, when VoiceOver navigates through the keyboard, then the two-marker adjustable representation is presented and behaves as today (asserted by accessibility test against `baseline_commit` behaviour).
- **Switch Control parity below AX1.** Given Dynamic Type below AX1, when Switch Control scans and adjusts, then the two-marker adjustable behaviour matches `baseline_commit` (asserted by accessibility test).
- **AX1+ fallback unchanged.** Given Dynamic Type at or above AX1, when any AT interacts with the keyboard, then the existing two-Slider fallback path behaves identically to `baseline_commit` (asserted by accessibility test, plus existing AX1 tests still pass without modification).
- **Functional parity.** Drag, tap-on-dimmed, keyboard arrow, and visual rendering behave identically to `baseline_commit` on every Dynamic Type path.
- **Pre-commit gate.** All four schemes green: Debug × {iOS, macOS} and Research × {iOS, macOS}. No new compiler warnings.
- **Catalog hygiene.** PF-020 section removed from `deferred-work.md` in the closing commit.

## Accessibility Audit Findings

*(empty — populated by Task 1; halt for human review before Task 2)*

## Spec Change Log

*(empty — populated by review iterations if any)*
