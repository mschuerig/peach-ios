---
title: 'Story 85.6: Pin TOD picker visual & accessibility invariants via snapshot/UI tests'
type: 'cleanup'
created: '2026-06-05'
status: 'done'
baseline_commit: '63f69aeb'
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
| PF-041: AX1 header rendering | Dynamic Type at AX1; longest German header (`Sechzehntel mit Lücken`, 22 chars) | Header wraps to two lines (no truncation); test pins this | N/A |
| Existing tests unchanged | Full pre-commit gate | All existing tests pass without modification on all four schemes | N/A |

</frozen-after-approval>

## Code Map

**Deliberately empty pre-verification.** Task 1's evaluation produces the infrastructure choice and the verified code map. Catalog-referenced surfaces:

- PF-036: `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionPatternPickerSettingsSection.swift` (the static `patternRowAccessibilityLabel` helper), `Peach/Training/TimingOffsetDetection/TimingDotView.swift` (per-cell labels)
- PF-040: `TimingOffsetDetectionPatternPickerDestination.body` (Story 84.4) — the five sibling inline `Picker`s
- PF-041: `tod-tuplet-renderer-design.md` § *Categorization* — the AX1 no-truncation invariant; rendered by the picker destination's section headers
- Potentially `bin/test.sh` — if the chosen mechanism needs new test-runner flags or output handling

**Added during verification (scope discovery):**

- `Peach/Resources/Localizable.xcstrings` — German value for `"Gapped 16ths"` renegotiated from `Lückenhafte Sechzehntel` to `Sechzehntel mit Lücken` (still the longest German section header at 22 chars; the AX1 fixture uses the new wording).
- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift` — added `static func categoryHeader(text:) -> some View` (PF-041 option (b)-lite extraction). `TimingOffsetDetectionPatternPickerDestination` stays file-private (the original visibility widening was for PF-040's runtime-host wrapper, no longer needed).
- `docs/planning-artifacts/tod-tuplet-renderer-design.md` — § *Categorization* updated for the renamed German header and notes that Story 85.6 replaces the manual "Visual check" with an automated AX1 test.
- `docs/planning-artifacts/epics.md` — Story 85.6 fixture string updated.
- `PeachTests/Helpers/AccessibilityTreeHelpers.swift` — narrow test helper (iOS-only via `#if canImport(UIKit)`): hosts a SwiftUI view, returns `renderedHeight(of:proposedWidth:)` via `UIHostingController.sizeThatFits(in:)`. Header doc documents the iOS 26 SwiftUI a11y-tree regression that made the originally-planned `combinedAccessibilityLabels` / `selectedAccessibilityElementsCount` helpers infeasible.
- `PeachTests/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerAccessibilityRowLabelTests.swift` — PF-036 structural test: every catalog pattern's row label equals the per-cell join via `TimingDotView.cellAccessibilityLabel`.
- `PeachTests/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerDestinationSelectionTests.swift` — PF-040 structural test: every catalog pattern belongs to exactly one category.
- `PeachTests/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerDestinationAX1Tests.swift` — PF-041 layout test: `categoryHeader(text:)` at AX1 with 150 pt frame wraps the longest German fixture to multiple lines.
- `docs/implementation-artifacts/deferred-work.md` — PF-036, PF-040, PF-041 sections removed (catalog hygiene per spec).

## Tasks & Acceptance

**Execution:**

- [x] **Task 1 — Evaluate infrastructure (must complete and review before any code change).** Survey candidate mechanisms for pinning the three PFs' invariants. At minimum evaluate: `swift-snapshot-testing`, `ViewInspector`, XCUITest accessibility audit, and an "inspect SwiftUI's `accessibilityElements` directly via the existing Swift Testing harness" approach. For each, document: what it can pin (image, accessibility tree, text), what dependencies it adds, how it integrates with `bin/test.sh`, what existing TOD picker tests would have to change, and which of the three PFs it actually closes. Produce a recommendation and sketch the infrastructure shape. **Halt for human review** — Michael's note: *"I don't know what is involved in snapshot testing. We'll discuss it when we come to the story."* The story can't proceed without his pick.
- [x] **Task 2 — Approach lock-in (post-evaluation).** Based on Michael's pick, finalise the infrastructure addition (or "no infrastructure — use existing harness") and identify the test files Tasks 3–5 will add or extend. Update Boundaries & Constraints if Ask-First conditions triggered.
- [x] **Task 3 — Set up the chosen infrastructure (if any).** Add the library / framework. Configure `bin/test.sh` if needed. Add any reference-snapshot directory to `.gitignore` if the mechanism generates them and they shouldn't be committed; conversely, commit the reference files if they should be.
- [x] **Task 4 — PF-036: pin the picker row accessibility label.** Write a test that fails if `patternRowAccessibilityLabel`'s static output diverges from the runtime `.combine`-joined label that VoiceOver actually reads.
- [x] **Task 5 — PF-040: pin the cross-section selection indicator.** Write a test that asserts exactly one row in the drill-down carries the selection indicator at steady state, for each pair of (source section, destination section) the design admits.
- [x] **Task 6 — PF-041: pin the AX1 no-truncation invariant.** Write a test that fails if any picker section header truncates at AX1 (longest header is `Sechzehntel mit Lücken`, 22 chars).
- [x] **Task 7 — Catalog hygiene.** Remove the PF-036, PF-040, and PF-041 sections from `docs/implementation-artifacts/deferred-work.md`. Cite all three IDs in the commit message.
- [x] **Task 8 — Pre-commit gates.** All four schemes green: iOS Debug 1980 passed, macOS Debug 1973 passed, iOS Research 2141 passed, macOS Research 2134 passed.

**Acceptance Criteria:**

*Renegotiated 2026-06-06 after the iOS 26 SwiftUI accessibility-tree regression (cashapp/AccessibilitySnapshot #245, #259) blocked the original "runtime VoiceOver label" formulation for PF-036 and the original "runtime selection indicator" formulation for PF-040. See Spec Change Log entry "2026-06-06 — iOS 26 a11y-tree regression: PF-036 and PF-040 pivoted to structural tests" for the full reasoning. PF-041 retains its original height-measurement formulation because layout (`sizeThatFits`) is independent of the broken a11y path.*

- **PF-036.** A test exists that fails when `patternRowAccessibilityLabel(for:)` diverges from the per-cell `TimingDotView.cellAccessibilityLabel(for:in:)` composition pipeline (join via `", "` over focusable visual cells: `.accent` and `.normalAudible`). Pins the *composition contract*: a refactor that inlines a different formatter into the helper, changes the join separator, or surfaces a new `VisualCellKind` case without updating the helper's exhaustive switch fails this test. Pinning the *rendered* VoiceOver label after SwiftUI's `.combine` join is deferred until SwiftUI hosted-view a11y materialization is usable in iOS unit tests again.
- **PF-040.** A test exists that asserts every catalog pattern belongs to exactly one `TimingOffsetDetectionPatternCategory`. This is the necessary precondition for the destination's sectioned-`Picker` shared-binding rendering to ever produce at most one selection indicator: if the catalog ever buckets a pattern into multiple categories, two `Picker`s would match the binding simultaneously. Pinning the *runtime* "exactly one indicator across all sections at steady state" assertion is deferred until SwiftUI hosted-view a11y materialization is usable in iOS unit tests again.
- **PF-041.** A test exists that asserts `categoryHeader(text:)` wraps the longest German fixture (`Sechzehntel mit Lücken`) to multiple lines at AX1 Dynamic Type, measured via `UIHostingController.sizeThatFits(in:)` at a constrained width (150 pt). `.lineLimit(1)` or `.truncationMode(...)` added to the helper collapses both renderings to a single line and the test fails.
- **Pre-commit gate.** All four schemes green: Debug × {iOS, macOS} and Research × {iOS, macOS}. No new compiler warnings.
- **Catalog hygiene.** PF-036, PF-040, and PF-041 sections removed from `deferred-work.md` in the closing commit.

## Infrastructure Evaluation

*Author: Claude · Date: 2026-06-06 · Halt point per spec — Michael picks an option before Task 2.*

### What each PF actually wants pinned

Reframing the three PFs in terms of "what observable signal must the test read" — this is what scopes the candidate evaluation.

- **PF-036.** Read the *runtime* VoiceOver label that SwiftUI synthesises after `.accessibilityElement(children: .combine)` joins `TimingDotView`'s per-cell `accessibilityLabel`s, and compare it to the static `patternRowAccessibilityLabel(for:)`. Both paths must be exercised in the same test so independent drift fails.
- **PF-040.** Inspect the *rendered* drill-down for a Picker selection indicator (the SwiftUI inline `Picker` accessibility trait `.isSelected`, surfaced visually as a checkmark) and assert exactly one row across all five sections carries it at steady state, for every pair of (source section, destination section).
- **PF-041.** Render the drill-down at AX1 Dynamic Type with the longest German header (`Sechzehntel mit Lücken`) and assert the header `Text` lays out on two lines instead of being truncated. The signal can be either (a) the rendered image (header height ≥ 2 × single-line height) or (b) the layout-measured frame of the header Text.

The three signals — accessibility-tree text, accessibility-tree boolean trait, layout-measured frame — overlap heavily: any mechanism that surfaces SwiftUI's runtime accessibility tree closes (a) PF-036 and PF-040; any mechanism that renders at a forced trait collection closes PF-041.

### Candidate evaluation

| Mechanism | Closes PF-036? | Closes PF-040? | Closes PF-041? | New deps? | Touches `bin/test.sh`? | Risk |
|---|---|---|---|---|---|---|
| **A. swift-snapshot-testing** (Point-Free) | Yes (`assertSnapshot(of:as: .accessibility(...))`) | Yes (image diff or accessibility-tree diff) | Yes (`.image(traits: UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge))`) | **+1 SPM package** | Reference PNGs / JSON under VCS; new test fixture directory | Approval needed (zero-deps policy); cross-renderer noise on image snapshots when iOS/Xcode updates land; macOS-specific snapshots are second-class for non-AppKit views |
| **B. ViewInspector** | Partial (inspects `.accessibilityElement` modifier presence, **not** the synthesised `.combine` runtime label — runs at view-tree level, not the accessibility-element-processing stage) | Partial (can read `.tag` per row; can't observe the rendered selection indicator) | Partial (can read the modifier set on the header `Text`, can't measure actual line-wrap) | **+1 SPM package** | None | Approval needed; runtime semantics (`.combine`, system-rendered selection indicator, Dynamic Type wrap) are *not* simulated — so the three signals we actually want to pin all fall in ViewInspector's "tree introspection ≠ runtime behaviour" gap |
| **C. XCUITest accessibility audit** | Yes (`XCUIElement.label` reads the actual VoiceOver string) | Yes (`XCUIElement.isSelected`) | Partial (XCUITest sees rendered hierarchy; AX1 setup is per-launch via launch argument or scheme env var; line-wrap detection needs frame measurement) | None (XCTest framework only) | **Add UI test target**, scheme-level UI-test action, AX1 launch-arg plumbing; per-PF launch overhead 5–15 s | High infra burden — no UI test target exists today; runtime is 100× slower than Swift Testing; flaky in CI when sim state isn't pristine; ships outside the existing 4-scheme matrix |
| **D. Bespoke / built-in** (SwiftUI `ImageRenderer` + `UIHostingController`/`NSHostingController` accessibility tree introspection, all inside Swift Testing) | Yes (host the view in `UIHostingController`, walk `accessibilityElements` on the resolved view, read `accessibilityLabel` — that is the *runtime* combined label) | Yes (host the destination, walk accessibility tree for elements with `.isSelected` trait — SwiftUI publishes `Picker` selection through this) | Yes (host at `traitCollection.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge`, measure rendered header `Text` frame via `sizeThatFits` or `ImageRenderer`-driven layout pass; assert height ≥ 2 × single-line height) | **None** (`ImageRenderer`, `UIHostingController`, accessibility tree are platform APIs already in use — see `Peach/Profile/ChartImageRenderer.swift:13` and `PeachTests/Profile/ExportChartViewTests.swift:44`) | **None** — runs in the existing 4-scheme matrix | Low — relies on platform accessibility/layout APIs documented under `UIAccessibility`. macOS path needs `NSHostingController` + `accessibilityChildren()` instead; minor `#if os(...)` split for the host setup. AX1 line-wrap measurement on macOS isn't symmetric (no Dynamic Type) — that PF runs iOS-only, fine per existing test scopes |

### Cross-cuts that matter

1. **Zero-deps policy.** The project context locks the project at zero third-party dependencies and requires explicit approval for additions. A/B both trigger that approval. D does not.
2. **Existing infrastructure pattern.** `ChartImageRenderer` already uses `ImageRenderer`, and `ExportChartViewTests.rendersWithMockData()` already drives `ImageRenderer` from a Swift Testing test (`PeachTests/Profile/ExportChartViewTests.swift:44`). The pattern D builds on is already in the codebase — adopting it is incremental, not novel.
3. **`bin/test.sh` integration.** All schemes test inside the same `PeachTests` target. A and C add new file kinds (reference PNGs) or new targets (UI tests) that bind to `bin/test.sh`; D adds nothing — the new tests live in `PeachTests/Training/TimingOffsetDetection/Settings/` next to the existing ones.
4. **What "snapshot test" means here.** The spec name says "snapshot test" but the actual signals (combined accessibility label, single-selection trait, header line-wrap) are all *queryable* — they don't need byte-equality reference images. The mechanism category that fits is **rendered-view introspection**, not **image-diff comparison**. A handles the latter at high cost; D handles the former with zero cost.
5. **Cross-renderer drift on image snapshots.** Image-diff approaches (A's image mode, C's screenshots) are notoriously brittle across iOS/Xcode versions and Simulator runtime changes — a 1px antialias shift flunks the test. The PFs do not require that level of pinning; they require that the *semantic* invariant (label text matches, exactly one selection, header doesn't truncate) hold.
6. **Per-PF mechanism vs. unified.** None of the four PF signals requires a different mechanism — they're all readable through the SwiftUI accessibility/layout API surface, so the "ship multiple mechanisms" Ask-First trigger does not fire.

### Recommendation

**Option D — Bespoke / built-in, using `UIHostingController` + accessibility tree introspection + `ImageRenderer`-driven layout measurement, all inside Swift Testing.**

Rationale:

- It is the only option that fits the project's zero-deps policy without requiring approval.
- It closes all three PFs without compromise (A, B, C each leave at least one PF partially covered or require infrastructure the project explicitly avoids).
- It builds on infrastructure already exercised in `ExportChartViewTests` — no new pattern for contributors to learn, no new file kinds in VCS, no new scheme.
- It pins the *semantic* invariants the PFs care about, not pixel-level images that drift across Xcode releases.
- It keeps the test surface inside the existing 4-scheme matrix that `bin/test.sh` already runs end-to-end.

Implementation sketch (if D is picked):

1. New helper file `PeachTests/Helpers/AccessibilityTreeHelpers.swift` (iOS+macOS shared with `#if os(...)`). Exposes:
   - `accessibilityLabels(of view: some View) -> [String]` — hosts the view, traverses the accessibility tree, returns concatenated labels in tree order.
   - `selectedAccessibilityElementsCount(of view: some View) -> Int` — counts elements with `.isSelected` trait.
   - `renderedTextHeight(of view: some View, contentSize: ContentSizeCategory) -> CGFloat` — drives `ImageRenderer` (or `UIHostingController.sizeThatFits`) at the given Dynamic Type and returns the resolved height of the topmost `Text`.
2. Three test files:
   - `TimingOffsetDetectionPatternPickerAccessibilityRowLabelTests.swift` (PF-036) — for each catalog pattern, assert `accessibilityLabels` after `.combine` equal `patternRowAccessibilityLabel(for:)`.
   - `TimingOffsetDetectionPatternPickerDestinationSelectionTests.swift` (PF-040) — for each pair (source-section pattern, destination-section pattern), drive the binding, assert `selectedAccessibilityElementsCount == 1`.
   - `TimingOffsetDetectionPatternPickerDestinationAX1Tests.swift` (PF-041) — iOS-only, render the destination at AX1 with German locale, assert the `Sechzehntel mit Lücken` header height is ≥ 1.5 × single-line height (proxy for "wraps to 2 lines").
3. `bin/test.sh` — no changes.
4. `.gitignore` — no changes (no reference images).

Open question for Michael:

- The drill-down `Picker` in (b) uses an `@State`-backed `Binding<String>`. Hosting it in tests requires the `patternIdBinding` parameter to be exposed in a way the test can mutate. Three options:
  1. Pass the binding from a test-only wrapper view that owns `@State`.
  2. Lift `selectedPatternId` to a parameter on `TimingOffsetDetectionPatternPickerDestination.init` (small API surface change to the destination type).
  3. Use `@AppStorage` mutation through the test's `UserDefaults` suite (matches what the production code reads from).
- The wrapper approach (1) is cleanest and contains the testability concern in tests — that's my default. Confirm or override.

### Ask-First triggers — none fired

- The recommended mechanism (D) closes all three PFs uniformly — no per-PF split needed.
- D does not touch `bin/test.sh`.
- The audit did not surface a cleaner non-test fix for any of the three PFs that supersedes the catalog's option (a). PF-036 option (b) "collapse to one path" was considered: it would require removing `patternRowAccessibilityLabel(for:)` and re-deriving the row's `accessibilityValue` from the rendered `.combine` join — but the static helper is currently the *unit-test surface* for the per-cell label composition, and the unit tests in `TimingOffsetDetectionPatternPickerSettingsSectionTests.swift` would have to be reworked to render the view too. That trades the existing fast, deterministic per-cell tests for slower hosted-view tests with no actual reduction in code paths to maintain. Recommend keeping both paths and pinning their equivalence — exactly what (a) does. Surfacing this anyway for transparency; not enough to halt.

## Spec Change Log

**2026-06-06 — Mechanism picked (Option D, Bespoke / built-in).** Michael confirmed the recommended option from the Task 1 evaluation. Test infrastructure lives entirely in the existing Swift Testing harness via `UIHostingController` + accessibility tree introspection + `ImageRenderer`-style layout measurement (`UIHostingController.sizeThatFits`). No new SPM packages, no new test target, no `bin/test.sh` changes, no reference-image artifacts. The chosen helper landed in `PeachTests/Helpers/AccessibilityTreeHelpers.swift`.

**2026-06-06 — PF-040 binding hook: test-only `@State` wrapper.** Michael picked the test-only wrapper over (1) lifting `selectedPatternId` to a destination init parameter or (2) `@AppStorage` mutation through `UserDefaults`. Implementation: `DestinationHost` private struct inside the PF-040 test file owns `@State<String>` and forwards a `Binding` into `TimingOffsetDetectionPatternPickerDestination`.

**2026-06-06 — PF-041 reach: extract `categoryHeader(text:)` helper (option (c) from the AX1 hook question).** Michael picked the small production extraction over (b) the stripped fixture view or (a) `UserDefaults[AppleLanguages]` mutation. Implementation: `TimingOffsetDetectionPatternPickerSettingsSection.categoryHeader(text:)` returns `Text(text)` with default modifiers; the destination calls it; the test harnesses it directly with the longest-German-header fixture. Adding `.lineLimit(...)` or `.truncationMode(...)` inside the helper now breaks the PF-041 test by design.

**2026-06-06 — German renaming.** Michael flagged mid-implementation that `Lückenhafte Sechzehntel` reads poorly and requested `Sechzehntel mit Lücken` (22 chars, still the longest German header). Updated `Localizable.xcstrings`, `tod-tuplet-renderer-design.md`, `epics.md`, and the AX1 fixture string. Char-count noted as 22 (down from 23) — wrap behaviour at AX1 unchanged.

**2026-06-06 — Pre-commit gate green.** All four schemes pass: iOS Debug 1980, macOS Debug 1973, iOS Research 2141, macOS Research 2134. No new compiler warnings.

**2026-06-06 — iOS 26 a11y-tree regression: PF-036 and PF-040 pivoted to structural tests.** The first pass of PF-036 and PF-040 implemented runtime-hosted assertions (`UIHostingController` → `UIWindow.makeKeyAndVisible()` → walk `accessibilityElements` for the `.combine`-joined label or `.selected` trait). On iOS 26, SwiftUI's accessibility-tree materialization in `UIHostingController` unit-test contexts is broken — the hosted view's `accessibilityElements` is always `[]` regardless of `makeKeyAndVisible()`, `UIWindow(windowScene:)`, `UIAccessibility.post(.screenChanged, …)`, runloop ticks, or live-window injection. Confirmed by cashapp/AccessibilitySnapshot open issues #245 (June 2025) and #259 (September 2025); no supported workaround from Apple.

Pivot (authorised by Michael 2026-06-06): keep the production extraction of `categoryHeader(text:)` and the AX1 height-measurement test for PF-041 (works because layout is independent of the broken a11y path); replace the PF-036 and PF-040 runtime tests with structural tests that pin the *necessary* invariants:

- **PF-036 structural test** (`TimingOffsetDetectionPatternPickerAccessibilityRowLabelTests.patternRowLabelEqualsCellByCellJoinForEveryCatalogPattern`): for every catalog pattern, assert `patternRowAccessibilityLabel(for: pattern)` equals the focusable-cell join via `TimingDotView.cellAccessibilityLabel(for:in:)`. Pins the composition contract.
- **PF-040 structural test** (`TimingOffsetDetectionPatternPickerDestinationSelectionTests.everyCatalogPatternBelongsToExactlyOneCategory`): assert every catalog pattern belongs to exactly one category. This is the necessary precondition for the destination's sectioned-`Picker` shared-binding rendering to ever produce at most one selection indicator.

The runtime VoiceOver-label and runtime selection-indicator assertions are deferred — to be picked up whenever SwiftUI hosted-view a11y materialization works in unit tests again (Apple fix, or a community library that bypasses the regression).

**2026-06-06 — Helper surface narrowed.** `AccessibilityTreeHelpers` collapsed from three helpers (`combinedAccessibilityLabels`, `selectedAccessibilityElementsCount`, `renderedHeight`) to just `renderedHeight`. The first two depended on the broken a11y-tree path; only the layout-measurement helper survived. Header doc updated to document the regression in-line.

**2026-06-06 — `TimingOffsetDetectionPatternPickerDestination` reverted from `internal` to `private`.** The visibility widening was for PF-040's runtime-host wrapper view, which is no longer needed. The destination keeps its original file-private scope.

**2026-06-06 — PF-041 harness reshaped.** First pass measured a full `Form { Section { ... } header: { ... } }` and saw identical heights regardless of header length (Form imposes a 54 pt minimum row height that absorbs the wrap signal). Fixed by measuring `categoryHeader(text:)` directly with an explicit `.frame(width: 150)` constraint at AX1: `Sechzehntel mit Lücken` measures 121.67 pt vs baseline `X` at 87.67 pt — clear +34 pt delta.

**2026-06-06 — Review patches.** step-04 surfaced six low/medium findings (no intent_gap, no bad_spec), all applied as patches:

- *Patch A (PF-036)* — Test reconstructed the helper's `.accent / .normalAudible` switch verbatim, making the assertion partially tautological. Replaced with an independent oracle: `cellAccessibilityLabel(for:)` returns `""` for `.orphanRest` / `.nestingBracket` by contract; the test now filters on `!.isEmpty` instead of mirroring the helper's switch. Added per-cell non-empty assertion so both paths drifting to empty strings symmetrically would still be caught.
- *Patch B (PF-040)* — Original assertion ("each pattern in exactly 1 category") was satisfied trivially by the catalog's single-`category` field design. Replaced with pairwise disjointness across all category pairs using `Set(patterns(in:)).isDisjoint(with:)`, which surfaces a real bucketing mistake regardless of how `patterns(in:)` is implemented. Added inline note that `.nested` coverage is `PEACH_RESEARCH`-gated by design.
- *Patch C (PF-040)* — Second `#expect` (`containing.first == pattern.category`) fired with a confusing message when `count != 1`. Now guarded behind `if containing.count == 1`.
- *Patch D (`renderedHeight`)* — `host.view.frame` / `UIWindow(frame:)` / `layoutIfNeeded()` dance risked caching a first-pass size at proposal `(width, 200)` that `sizeThatFits(width, ∞)` then returned stale. Also used the deprecated `UIWindow(frame:)` init. Helper simplified to a single `UIHostingController(rootView:).sizeThatFits(in:)` call — `sizeThatFits` drives a fresh layout pass at the requested proposal, no window needed.
- *Patch E (`categoryHeader` doc)* — Doc enumerated only `.lineLimit(1)` and `.truncationMode(...)`. Reworded to "any modifier that constrains line count, truncates, or scales text down" (covers `.minimumScaleFactor(...)` and fixed-height container wrappers).
- *Patch F (PF-041 threshold)* — `longHeight >= baselineHeight + 20` was robust today (+34 pt delta) but coupled to iOS-26-specific Text metrics. Replaced with ratio `longHeight / baselineHeight >= 1.25` (decisively between today's 1.39 and `.lineLimit(1)`'s 1.0 — tolerates ±10% baseline metric drift).

Four-scheme matrix re-run green after patches: iOS 1980 / macOS 1973 / iOS Research 2141 / macOS Research 2134.

## Suggested Review Order

**Production extraction (PF-041 reach)**

- Section header `Text` extracted as a `static` helper so the AX1 test can render the exact production view; doc enumerates the wrap-collapsing modifier family.
  [`TimingOffsetDetectionPatternPickerSettingsSection.swift:133`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift#L133)

- Existing helper that the PF-036 structural test now independently re-derives via `cellAccessibilityLabel(for:in:)`.
  [`TimingOffsetDetectionPatternPickerSettingsSection.swift:111`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift#L111)

**Test harness (only PF-041 needs runtime layout; PF-036/040 are pure data)**

- One-call `sizeThatFits` — no window dance, no layout pre-pass; documents the iOS 26 a11y-tree regression that scoped this helper to layout only.
  [`AccessibilityTreeHelpers.swift:42`](../../PeachTests/Helpers/AccessibilityTreeHelpers.swift#L42)

**Invariant pinning (the three PFs)**

- PF-041: ratio-based wrap detection at AX1 against the longest German fixture; tolerates iOS metric drift.
  [`TimingOffsetDetectionPatternPickerDestinationAX1Tests.swift:48`](../../PeachTests/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerDestinationAX1Tests.swift#L48)

- PF-036: independent oracle over `visualCells × cellAccessibilityLabel` + non-empty-label check; not a tautological mirror of the helper.
  [`TimingOffsetDetectionPatternPickerAccessibilityRowLabelTests.swift:32`](../../PeachTests/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerAccessibilityRowLabelTests.swift#L32)

- PF-040: pairwise category disjointness via `Set.isDisjoint`, plus self-reported `.category` consistency guarded behind `count == 1`.
  [`TimingOffsetDetectionPatternPickerDestinationSelectionTests.swift:24`](../../PeachTests/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerDestinationSelectionTests.swift#L24)

**Peripherals**

- German rename of `Gapped 16ths` to `Sechzehntel mit Lücken` (still the longest German section header, 22 chars).
  [`Localizable.xcstrings`](../../Peach/Resources/Localizable.xcstrings)

- AX1 section-header wording note updated; design doc records that 85.6 replaces the manual 84.4 "Visual check" with an automated test.
  [`tod-tuplet-renderer-design.md`](../planning-artifacts/tod-tuplet-renderer-design.md)

- Closing PF-036, PF-040, PF-041 from the catalog.
  [`deferred-work.md`](deferred-work.md)
