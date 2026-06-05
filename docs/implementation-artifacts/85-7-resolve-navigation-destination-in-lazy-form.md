---
title: 'Story 85.7: Resolve `.navigationDestination(isPresented:)` future-deprecation in TOD picker drill-down'
type: 'cleanup'
created: '2026-06-05'
status: 'ready-for-dev'
baseline_commit: '6c6784f5'
context:
  - '{project-root}/docs/implementation-artifacts/deferred-work.md'
closes:
  - 'PF-046'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem.** `TimingOffsetDetectionPatternPickerSettingsSection.body` attaches `.navigationDestination(isPresented: $isShowingDestination)` to a `Button` inside a `Section`. The Section is part of the parent `Form` (assembled by `DisciplineSettingsSection.aggregated`), which SwiftUI implements as a lazy `List` underneath. iOS logs the warning:

> "Do not put a navigation destination modifier inside a 'lazy' container, like `List` or `LazyVStack`. ... It will be ignored in a future release."

Current iOS keeps the destination wired. A future iOS release will silently break the drill-down — the user will tap the *Pattern* row and nothing will happen.

The architecture creating the conflict landed in iteration-2 of Story 84.3: `NavigationLink` was replaced with `Button` + `.navigationDestination(isPresented:)` so the custom chevron view (`TimingDotView.patternRowChevron`) could be rendered on both the *Pattern* row and the *Offset Note Position* row at identical widths, restoring dot alignment between them. Reverting to `NavigationLink` re-introduces the chevron-alignment problem — Michael called it "completely unusable" in iteration-2 history. That trade-off must be preserved or replaced by an equivalent guarantee.

**Approach.** Two-phase: settle the design call, then implement.

1. **Settle** (Task 1) — pick between the two viable catalog options. **Option (b) is excluded** (revert to `NavigationLink` reintroduces the iteration-2 alignment misery). The viable options:
   - **(a) Hoist `.navigationDestination(isPresented:)` to `SettingsScreen.body`'s `Form`** (outside the lazy container). Requires extending `DisciplineSettingsSection` to declare navigation contributions that a parent screen can collect and attach. Cross-cutting architectural change touching `App/Training/`.
   - **(c) Restructure the picker drill-down so the *Pattern* destination also hosts the *Offset Note Position* selector** — one drill-down screen containing both controls instead of two adjacent inline rows. The settings screen shows only the *Pattern* row (drill-in to edit both). UX change worth a Sally consult.

   Task 1 invokes `/swiftui-pro` (and `/swiftui-ui-patterns` if it helps) to evaluate (a) against current SwiftUI navigation semantics, and `/bmad-agent-ux-designer` (Sally) for the UX call on (c). Output: a comparative pros-and-cons against the preserve-chevron-alignment + preserve-atomic-`patternIdBinding`-cascade constraints, plus a recommendation. Michael picks.

2. **Implement** (Tasks 2+) — apply the chosen option. Either path closes PF-046 by eliminating the lazy-container warning.

**Design principle.** This story doesn't reopen the iteration-2 trade-off — it preserves what iteration-2 achieved (chevron alignment, atomic selection cascade) while moving the navigation-destination attachment to a location SwiftUI documents as future-stable.

## Boundaries & Constraints

**Always:**
- PF-046 is closed by this story or scope is renegotiated with explicit human authorization.
- iOS logs no `"Do not put a navigation destination modifier inside a 'lazy' container"` warning at any user interaction with the TOD picker drill-down (verified by clean-log capture on iOS Simulator).
- The iteration-2 chevron-alignment guarantee is preserved or replaced by an equivalent visual contract. Specifically: the dot rows on the *Pattern* row and (if it still exists post-implementation) the *Offset Note Position* row must occupy identical container widths; the trailing chevron must render at identical widths on both rows.
- The atomic selection cascade through `patternIdBinding` is preserved — writing `selectedPatternId` and `offsetNotePosition` must remain a single observable transition from the user's perspective. If option (c) is picked and the two rows collapse into one destination, this constraint reduces to "the destination's commit writes both atomically before dismissing."
- Pre-commit gate: `bin/test.sh && bin/test.sh -p mac` AND `bin/test.sh --research && bin/test.sh --research -p mac` green.
- Catalog hygiene on merge: remove the PF-046 section from `deferred-work.md` in the same change; cite the ID in the commit message.

**Ask First:**
- The design pick itself — Task 1 halts before any code change. Michael picks between (a) and (c) based on the audit's pros/cons.
- If the audit reveals that current SwiftUI semantics have shifted such that the warning no longer applies (Apple changed `Form`'s underlying implementation; or `.navigationDestination` semantics relaxed), pause and confirm whether PF-046 has been incidentally resolved before adding implementation work for a non-bug.
- If option (a) turns out to require touching every `DisciplineSettingsSection` conformer (not just the TOD one) to declare navigation contributions, pause and confirm the migration scope.
- If option (c) UX consult with Sally surfaces a third design (e.g., a sheet instead of a push, or a combined picker primitive across disciplines), pause and confirm before pursuing it.

**Never:**
- No revert to `NavigationLink` (option (b)). The iteration-2 history rules it out.
- No new navigation-style primitives beyond what the chosen option requires. If (a) is picked, the `DisciplineSettingsSection` navigation-contribution mechanism is what gets added — not a generic "settings navigation framework."
- No drive-by closure of Story 85.6 (PF-036/040/041 — picker invariants). The infrastructure 85.6 adds may help test PF-046's outcome, but 85.7 doesn't depend on 85.6 shipping first.
- No `@AppStorage` or persistence changes. Navigation-attachment-only.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| User taps *Pattern* row to drill in | Settings screen visible; *Pattern* row tapped | Picker destination pushes onto the navigation stack; no lazy-container warning in logs | Asserted by visual verification + log capture |
| User selects a pattern in the destination | Drill-down visible; user taps a pattern row | `selectedPatternId` and `offsetNotePosition` both update atomically; destination dismisses (or behaves per the chosen option's UX) | Asserted by selection cascade test |
| User backs out of the destination without selecting | Drill-down visible; user dismisses | `selectedPatternId` and `offsetNotePosition` unchanged from the values they held on entry | Asserted by test |
| Chevron visual alignment | Settings screen visible; *Pattern* row and (if applicable) *Offset Note Position* row rendered | The trailing chevrons (and dot rows) on both rows occupy identical container widths | Asserted by visual verification; pinned by Story 85.6's infrastructure if it lands before |
| Strict-concurrency build clean | Both Debug and Research schemes | Build clean; no new Sendable / actor-isolation warnings introduced | N/A |

</frozen-after-approval>

## Code Map

**Deliberately empty pre-verification.** Task 1's design audit produces the verified code map and appends it here. Catalog-referenced surfaces:

- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift` — current `.navigationDestination(isPresented:)` attachment site
- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerDestination.swift` (or wherever the destination view lives) — the destination's selection cascade
- `Peach/App/SettingsScreen.swift` — parent `Form` that would receive the hoisted `.navigationDestination` under option (a)
- `Peach/App/DisciplineSettingsSection.swift` — discipline-plugin contribution mechanism that would need extending under option (a)
- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionOffsetNotePositionSettingsSection.swift` — the row that would fold into the destination under option (c)
- `Peach/Training/TimingOffsetDetection/TimingDotView.swift` — `patternRowChevron` (iteration-2 alignment guarantee)

**Added during verification (scope discovery):**

- *(populated by Task 1)*

## Tasks & Acceptance

**Execution:**

- [ ] **Task 1 — Design audit (must complete and review before any code change).** Invoke `/swiftui-pro` against the current navigation-destination shape; have it evaluate option (a) — hoisting `.navigationDestination` to the parent `Form` via a `DisciplineSettingsSection` navigation-contribution mechanism — against current SwiftUI semantics. Invoke `/bmad-agent-ux-designer` (Sally) for option (c) — collapsing *Pattern* + *Offset Note Position* into one drill-down — to evaluate the UX implications (user mental model, drill-down discoverability, ergonomics of editing both controls in one screen). Produce a comparative table: each option's blast radius (files touched, contracts changed); how each preserves the iteration-2 chevron-alignment and atomic-`patternIdBinding`-cascade constraints; any third option that surfaces during the consult. **Halt for human review.** Michael picks between (a) and (c) (or a third option the audit surfaces, with Ask-First).
- [ ] **Task 2 — Approach lock-in (post-audit).** Finalise the chosen option, the touched-files list, the test surfaces. Update Boundaries & Constraints if Ask-First conditions triggered.
- [ ] **Task 3 — Tests-first contract.** Write tests that fail on the current shape and pass after the chosen option lands: (a) clean iOS log capture (no lazy-container warning) at user interaction with the picker drill-down; (b) atomic-cascade test pinning that `selectedPatternId` and `offsetNotePosition` update together; (c) chevron-alignment regression test (per Story 85.6's infrastructure if it lands first, or per a bespoke mechanism if not).
- [ ] **Task 4 — Implement.** Apply the chosen option. Preserve the iteration-2 chevron-alignment and atomic-cascade contracts.
- [ ] **Task 5 — Visual verification on iOS Simulator.** Capture an iOS Simulator log during a *Pattern* drill-down → select → dismiss interaction. Confirm zero lazy-container warnings.
- [ ] **Task 6 — Catalog hygiene.** Remove the PF-046 section from `docs/implementation-artifacts/deferred-work.md`. Cite PF-046 in the commit message.
- [ ] **Task 7 — Pre-commit gates.** Run `bin/test.sh && bin/test.sh -p mac` and `bin/test.sh --research && bin/test.sh --research -p mac`. All four green.

**Acceptance Criteria:**

- **PF-046.** Given a user taps the *Pattern* row in the TOD settings, when the drill-down opens and the user completes a selection cycle, then iOS logs contain zero `"Do not put a navigation destination modifier inside a 'lazy' container"` warnings (asserted by log capture).
- **Chevron-alignment preservation.** The trailing chevrons (and dot rows where applicable) on the rows of the TOD settings section render at identical container widths — matching the iteration-2 visual guarantee (asserted by visual verification, plus a regression test if 85.6's infrastructure is available).
- **Atomic selection cascade.** Selecting a pattern in the destination writes `selectedPatternId` and `offsetNotePosition` as a single observable transition (asserted by test).
- **Existing behavior parity.** All other TOD picker interactions (back-out without selection, repeated drill-downs, AT path) behave identically to `baseline_commit`.
- **Pre-commit gate.** All four schemes green: Debug × {iOS, macOS} and Research × {iOS, macOS}. No new compiler warnings; strict-concurrency build remains clean.
- **Catalog hygiene.** PF-046 section removed from `deferred-work.md` in the closing commit.

## Design Audit Findings

*(empty — populated by Task 1; halt for human review before Task 2)*

## Spec Change Log

*(empty — populated by review iterations if any)*
