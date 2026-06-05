---
title: 'Story 85.6: Pin TOD picker visual & accessibility invariants via snapshot/UI tests'
type: 'cleanup'
created: '2026-06-05'
status: 'ready-for-dev'
baseline_commit: '6c6784f5'
context:
  - '{project-root}/docs/implementation-artifacts/deferred-work.md'
closes:
  - 'PF-036'
  - 'PF-040'
  - 'PF-041'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem.** Three TOD-picker catalog entries all want the same thing: a way to pin a visual or accessibility invariant that today's unit-test surface can't reach. Each individually is "Low; not currently broken; if X drifts from Y the test passes but the user-facing result is wrong."

- **PF-036 — `patternRowAccessibilityLabel` ↔ SwiftUI `.combine` drift.** Static helper is pinned by unit tests; the actual VoiceOver label is what `.combine` joins from `TimingDotView` per-cell labels. The two paths can drift apart silently.
- **PF-040 — Sectioned `Picker` shared-binding selection-indicator behaviour.** Story 84.4 renders five sibling inline `Picker`s sharing one `patternIdBinding`. SwiftUI doesn't document the steady-state contract that exactly one row shows the selection indicator; no test pins it.
- **PF-041 — AX1 picker section header no-truncation invariant.** `tod-tuplet-renderer-design.md` locks SwiftUI default wrapping (no `.lineLimit(1)` / `.truncationMode`) and explicitly calls for an AX1 screenshot test. 84.4 shipped with only a manual "Visual check" task.

The three share infrastructure needs: each wants to assert "what the user actually sees" rather than "what an isolated unit returns." Solving any one of them alone wastes the infrastructure investment.

**Approach.** Two-phase: evaluate, then build.

1. **Evaluate** (Task 1) — establish what mechanism to use for "pin the rendered output / the actual AT label." Candidates the audit considers:
   - `swift-snapshot-testing` (Point-Free) — well-known, image and accessibility snapshots, but new dependency.
   - SwiftUI's `ViewInspector` — view-tree inspection, no images.
   - XCUITest accessibility audit / `XCUIElement` queries — runs the app, queries real AT tree.
   - A bespoke approach using `accessibilityElements` direct inspection inside Swift Testing tests.
   - The audit produces: a candidate evaluation (what each gives us, costs, integration with existing test conventions), a recommendation, and a sketch of the infrastructure shape if the recommendation is "add a library." **Halt for human review** — Michael's note on this story: *"I don't know what is involved in snapshot testing. We'll discuss it when we come to the story."*

2. **Build** (Tasks 2+) — implement the chosen infrastructure (if any) and write the three tests, one per PF.

**Design principle.** Each of the three entries has a Low severity individually — but they share a common gap (UI-level invariants are untested) that compounds. Closing them together pays the infrastructure cost once. Beyond closing the three, the infrastructure leaves the door open for visual-regression coverage on PF-045 (nested-bracket overlay defect — currently `PEACH_RESEARCH`-gated, unpinned by automated checks).

## Boundaries & Constraints

**Always:**
- PF-036, PF-040, and PF-041 are closed by this story, or scope is renegotiated with explicit human authorization.
- The infrastructure choice is settled by the Task 1 evaluation, with Michael's explicit pick — not by my inference.
- Each PF's invariant is pinned by a test that would fail if the user-facing behaviour drifts from what the catalog entry describes, not just if an isolated unit changes signature.
- Pre-commit gate: `bin/test.sh && bin/test.sh -p mac` AND `bin/test.sh --research && bin/test.sh --research -p mac` green.
- Catalog hygiene on merge: remove the PF-036, PF-040, and PF-041 sections from `deferred-work.md` in the same change; cite all three IDs in the commit message.

**Ask First:**
- The infrastructure choice itself — Task 1 halts before any code change. Michael picks between the candidates the audit evaluates.
- If the evaluation finds that the right mechanism varies per PF (e.g., PF-036 best fits accessibility-tree inspection while PF-041 best fits image snapshots), pause and confirm whether to ship multiple mechanisms or settle on one.
- If adding the chosen library / framework requires changes to `bin/test.sh` (e.g., snapshot reference files, image-comparison output), pause and confirm the script changes.
- If the audit reveals that one of the three PFs has a cleaner non-test fix that the catalog missed (e.g., collapse two divergent paths into one — option (b) for PF-036, option (b) for PF-040, option (b) for PF-041) and that fix is endorsed, pause and confirm whether to take the non-test path for that entry instead.

**Never:**
- No drive-by closure of PF-045 (nested-bracket visual defect). The infrastructure may make a future fix for PF-045 easier, but actually pinning the correct rendering is its own story.
- No assumption about which library to use before Task 1 completes.
- No bespoke "snapshot testing lite" implementation unless the audit explicitly recommends one and Michael picks it.

## I/O & Edge-Case Matrix

Filled to the closure level; Task 1's evaluation may extend this.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| PF-036: per-cell label drifts in `TimingDotView` | Renderer changes per-cell `accessibilityLabel` format | Test fails before the change reaches release (the change is the bug, not the test) | N/A |
| PF-036: static helper drifts | `patternRowAccessibilityLabel` static helper format changes | Test fails before the change reaches release | N/A |
| PF-040: cross-section selection transition | User selects a pattern in section A, then section B | Exactly one row shows the selection indicator at steady state; test verifies this for every section pair | N/A |
| PF-041: AX1 header rendering | Dynamic Type at AX1; longest German header (`Lückenhafte Sechzehntel`, 23 chars) | Header wraps to two lines (no truncation); test pins this | N/A |
| Existing tests unchanged | Full pre-commit gate | All existing tests pass without modification on all four schemes | N/A |

</frozen-after-approval>

## Code Map

**Deliberately empty pre-verification.** Task 1's evaluation produces the infrastructure choice and the verified code map. Catalog-referenced surfaces:

- PF-036: `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPatternPickerSettingsSection.swift` (the static `patternRowAccessibilityLabel` helper), `Peach/Training/TimingOffsetDetection/TimingDotView.swift` (per-cell labels)
- PF-040: `TimingOffsetDetectionPatternPickerDestination.body` (Story 84.4) — the five sibling inline `Picker`s
- PF-041: `tod-tuplet-renderer-design.md` § *Categorization* — the AX1 no-truncation invariant; rendered by the picker destination's section headers
- Potentially `bin/test.sh` — if the chosen mechanism needs new test-runner flags or output handling

**Added during verification (scope discovery):**

- *(populated by Task 1)*

## Tasks & Acceptance

**Execution:**

- [ ] **Task 1 — Evaluate infrastructure (must complete and review before any code change).** Survey candidate mechanisms for pinning the three PFs' invariants. At minimum evaluate: `swift-snapshot-testing`, `ViewInspector`, XCUITest accessibility audit, and an "inspect SwiftUI's `accessibilityElements` directly via the existing Swift Testing harness" approach. For each, document: what it can pin (image, accessibility tree, text), what dependencies it adds, how it integrates with `bin/test.sh`, what existing TOD picker tests would have to change, and which of the three PFs it actually closes. Produce a recommendation and sketch the infrastructure shape. **Halt for human review** — Michael's note: *"I don't know what is involved in snapshot testing. We'll discuss it when we come to the story."* The story can't proceed without his pick.
- [ ] **Task 2 — Approach lock-in (post-evaluation).** Based on Michael's pick, finalise the infrastructure addition (or "no infrastructure — use existing harness") and identify the test files Tasks 3–5 will add or extend. Update Boundaries & Constraints if Ask-First conditions triggered.
- [ ] **Task 3 — Set up the chosen infrastructure (if any).** Add the library / framework. Configure `bin/test.sh` if needed. Add any reference-snapshot directory to `.gitignore` if the mechanism generates them and they shouldn't be committed; conversely, commit the reference files if they should be.
- [ ] **Task 4 — PF-036: pin the picker row accessibility label.** Write a test that fails if `patternRowAccessibilityLabel`'s static output diverges from the runtime `.combine`-joined label that VoiceOver actually reads.
- [ ] **Task 5 — PF-040: pin the cross-section selection indicator.** Write a test that asserts exactly one row in the drill-down carries the selection indicator at steady state, for each pair of (source section, destination section) the design admits.
- [ ] **Task 6 — PF-041: pin the AX1 no-truncation invariant.** Write a test that fails if any picker section header truncates at AX1 (longest header is `Lückenhafte Sechzehntel`, 23 chars).
- [ ] **Task 7 — Catalog hygiene.** Remove the PF-036, PF-040, and PF-041 sections from `docs/implementation-artifacts/deferred-work.md`. Cite all three IDs in the commit message.
- [ ] **Task 8 — Pre-commit gates.** Run `bin/test.sh && bin/test.sh -p mac` and `bin/test.sh --research && bin/test.sh --research -p mac`. All four green.

**Acceptance Criteria:**

- **PF-036.** A test exists that fails when the rendered VoiceOver label (after `.combine`) diverges from the static `patternRowAccessibilityLabel` helper — either path drifting independently is caught.
- **PF-040.** A test exists that asserts exactly one row in the visible picker drill-down carries the selection indicator at steady state, exercised across the section transitions the design admits.
- **PF-041.** A test exists that asserts no picker section header truncates at AX1 Dynamic Type, with the longest German header (`Lückenhafte Sechzehntel`) as a fixture.
- **Pre-commit gate.** All four schemes green: Debug × {iOS, macOS} and Research × {iOS, macOS}. No new compiler warnings.
- **Catalog hygiene.** PF-036, PF-040, and PF-041 sections removed from `deferred-work.md` in the closing commit.

## Infrastructure Evaluation

*(empty — populated by Task 1; halt for human review before Task 2)*

## Spec Change Log

*(empty — populated by review iterations if any)*
