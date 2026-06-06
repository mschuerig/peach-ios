---
title: 'Story 85.7: Resolve `.navigationDestination(isPresented:)` future-deprecation in TOD picker drill-down'
type: 'cleanup'
created: '2026-06-05'
status: 'done'
baseline_commit: 'af543f3e'
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

**Added during verification (scope discovery, post-Task 1):**

- `Peach/Training/TimingOffsetDetection/TimingDotView.swift` — confirmed `body` is fully flexible (`GeometryReader` → all positioning proportional via `cell.widthProportion * containerWidth`, `cell.startXProportion * containerWidth`). The dot row takes whatever width is given; iteration-2's chevron-mirroring trick worked only because both HStacks delivered identical residual widths to their flexible dot-row child. Direct fixed-width framing on both dot rows is the cleanest way to guarantee identical containers without coupling to anything trailing them. (This is what made option (f) viable.)

**Touched files (option (f), locked in 2026-06-06):**

- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift` — replace `Button` + `.navigationDestination(isPresented:)` with plain `NavigationLink(destination:)`. Drop `isShowingDestination` state. Drop `patternRowChevron(isVisible: true)` from the row HStack; constrain the dot row with `.frame(width: TimingDotView.settingsRowDotsWidth)`.
- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionOffsetNotePositionSettingsSection.swift` — drop `patternRowChevron(isVisible: false)` from the row HStack; constrain the slot-picker GeometryReader with `.frame(width: TimingDotView.settingsRowDotsWidth)`. Remove the outer HStack since there's no longer a chevron to lay out beside it (the slot picker becomes the sole row content).
- `Peach/Training/TimingOffsetDetection/TimingDotView.swift` — add `static let settingsRowDotsBaseWidth: CGFloat = 220`. Each section view wraps it in `@ScaledMetric(relativeTo: .caption2) private var dotRowWidth: CGFloat = TimingDotView.settingsRowDotsBaseWidth`. Delete `patternRowChevron(isVisible:)` static and `patternRowChevronSpacing` static (iteration-2 mechanism retires; nothing else references them).

## Tasks & Acceptance

**Execution:**

- [x] **Task 1 — Design audit (must complete and review before any code change).** Invoke `/swiftui-pro` against the current navigation-destination shape; have it evaluate option (a) — hoisting `.navigationDestination` to the parent `Form` via a `DisciplineSettingsSection` navigation-contribution mechanism — against current SwiftUI semantics. Invoke `/bmad-agent-ux-designer` (Sally) for option (c) — collapsing *Pattern* + *Offset Note Position* into one drill-down — to evaluate the UX implications (user mental model, drill-down discoverability, ergonomics of editing both controls in one screen). Produce a comparative table: each option's blast radius (files touched, contracts changed); how each preserves the iteration-2 chevron-alignment and atomic-`patternIdBinding`-cascade constraints; any third option that surfaces during the consult. **Halt for human review.** Michael picks between (a) and (c) (or a third option the audit surfaces, with Ask-First).
- [x] **Task 2 — Approach lock-in (post-audit).** Finalise the chosen option, the touched-files list, the test surfaces. Update Boundaries & Constraints if Ask-First conditions triggered.
- [x] **Task 3 — Tests-first contract.** Write tests that fail on the current shape and pass after the chosen option lands: (a) clean iOS log capture (no lazy-container warning) at user interaction with the picker drill-down; (b) atomic-cascade test pinning that `selectedPatternId` and `offsetNotePosition` update together; (c) chevron-alignment regression test (per Story 85.6's infrastructure if it lands first, or per a bespoke mechanism if not).
- [x] **Task 4 — Implement.** Apply the chosen option. Preserve the iteration-2 chevron-alignment and atomic-cascade contracts.
- [x] **Task 5 — Visual verification on iOS Simulator.** Capture an iOS Simulator log during a *Pattern* drill-down → select → dismiss interaction. Confirm zero lazy-container warnings.
- [x] **Task 6 — Catalog hygiene.** Remove the PF-046 section from `docs/implementation-artifacts/deferred-work.md`. Cite PF-046 in the commit message.
- [x] **Task 7 — Pre-commit gates.** Run `bin/test.sh && bin/test.sh -p mac` and `bin/test.sh --research && bin/test.sh --research -p mac`. All four green.

**Acceptance Criteria:**

- **PF-046.** Given a user taps the *Pattern* row in the TOD settings, when the drill-down opens and the user completes a selection cycle, then iOS logs contain zero `"Do not put a navigation destination modifier inside a 'lazy' container"` warnings (asserted by log capture).
- **Chevron-alignment preservation.** The trailing chevrons (and dot rows where applicable) on the rows of the TOD settings section render at identical container widths — matching the iteration-2 visual guarantee (asserted by visual verification, plus a regression test if 85.6's infrastructure is available).
- **Atomic selection cascade.** Selecting a pattern in the destination writes `selectedPatternId` and `offsetNotePosition` as a single observable transition (asserted by test).
- **Existing behavior parity.** All other TOD picker interactions (back-out without selection, repeated drill-downs, AT path) behave identically to `baseline_commit`.
- **Pre-commit gate.** All four schemes green: Debug × {iOS, macOS} and Research × {iOS, macOS}. No new compiler warnings; strict-concurrency build remains clean.
- **Catalog hygiene.** PF-046 section removed from `deferred-work.md` in the closing commit.

## Design Audit Findings

_Task 1 audit run 2026-06-06 against current main (`af543f3e`). `/swiftui-pro` graded option (a); `/bmad-agent-ux-designer` (Sally) graded option (c). Each expert produced a focused single-option audit; Michael picks._

### Verified surface — what exists today

- Only one `.navigationDestination(isPresented:)` exists inside settings code (the PF-046 site at `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift:46`). `StartScreen` uses the value-driven `.navigationDestination(for:)` correctly.
- Six disciplines conform to `TrainingDisciplineUI`. Only TOD contributes a section that needs navigation; the other five would inherit an empty default if option (a)'s contribution mechanism lands.
- The parent `Form` lives in `Peach/Settings/SettingsScreen.swift:46` and is rendered inside a `NavigationStack` by every caller (production + previews). Attaching `.navigationDestination` to that `Form` is on the container view, not inside its lazy rows — Apple's documented supported attachment site.

### Option (a) — Hoist `.navigationDestination` via `DisciplineSettingsSection` navigation contribution

**SwiftUI semantics.** Apple's `View.navigationDestination(isPresented:destination:)` doc warns against placement inside lazy containers (`List`, `LazyVStack`, `Form`) and recommends attaching to the enclosing `NavigationStack` or a non-lazy ancestor. Attaching to the `Form` itself places the modifier on the container view — supported. Section-level attachment is NOT a fix: a `Section` inside `Form` is itself lazy material, same diagnostic.

**Concrete API sketch (additive):**

```swift
struct DisciplineSettingsNavigation: Identifiable {
    let id: String                    // stable, distinct from section id
    let isPresented: Binding<Bool>    // parent-owned @State, passed down
    let destination: () -> AnyView
}

protocol TrainingDisciplineUI: TrainingDiscipline {
    var settingsNavigations: [DisciplineSettingsNavigation] { get }
}

extension TrainingDisciplineUI {
    var settingsNavigations: [DisciplineSettingsNavigation] { [] } // additive default
}

extension DisciplineSettingsSection {
    static func aggregatedNavigations(
        from disciplines: [any TrainingDisciplineUI]
    ) -> [DisciplineSettingsNavigation] { /* dedup by id */ }
}
```

`SettingsScreen.body` owns the `@State` Bool, iterates aggregated navigations, attaches `.navigationDestination(isPresented:)` to its `Form`.

**Blast radius.**

- `Peach/App/Training/TrainingDisciplineUI.swift` — add `settingsNavigations` requirement + default
- `Peach/App/Training/DisciplineSettingsSection.swift` — add `DisciplineSettingsNavigation` + aggregator
- `Peach/Settings/SettingsScreen.swift:45` — own bindings, iterate navigations, attach modifier(s) on `Form`
- `Peach/Training/TimingOffsetDetection/Discipline/TimingOffsetDetectionDiscipline.swift` — vend the navigation contribution
- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift:30,46` — accept `@Binding`, drop `.navigationDestination`

Five files. Zero conformer changes for the five non-TOD disciplines (additive default).

**`isShowingDestination` ownership.** Parent-owned `@State`, `@Binding` passed down. The section owns no business state for this flag; aggregation runs every parent body call so per-render-collected bindings would churn identity; an `@Observable` coordinator is overkill for one Bool.

**Identity / state-loss risk.** Low. `@AppStorage` changes invalidate `Form` body but `@State` on `SettingsScreen` survives; the destination's `isPresented` binding keeps its value. `SettingsScreen` itself has stable identity in the `NavigationStack`.

**Constraint preservation.**

- Chevron alignment: **preserved by construction** — row body (`Button` + `HStack` with `patternRowChevron(isVisible: true)`) untouched; only the modifier hoists.
- Atomic `patternIdBinding` cascade: **preserved** — binding closure unchanged; setter order untouched.

**Ask-First triggers under (a).** None fired. The warning is still emitted on current SDKs; the additive-default design means non-TOD conformers need zero changes; no strictly-better architectural option surfaced.

**SwiftUI-architect verdict: viable.**

### Option (c) — Combine *Pattern* + *Offset Note Position* into one drill-down

**User mental model.** The two knobs are conceptually one act ("define the rhythmic figure I'll feel offsets against") — Pattern is the noun, Offset Note Position is its required attribute. Settings-list shrinks (good for density). Cost: the offset choice loses at-a-glance visibility. **Mitigation:** render the doubled-glyph on the settings row preview at the chosen position so the affordance "leaks" out of the closed row.

**Drill-down ergonomics (recommended c-1).** One screen with the categorized pattern list and the offset-position slot picker on the same `Form`. A pinned-top slot picker (always visible while scrolling the list) reads as "current selection + change either knob." Wizard (c-2) over-formalizes a coupled choice and punishes users tweaking only the position.

**Atomic commit semantics.** Auto-commit on each edit; back is "done". Mirrors today's inline-binding behavior; matches Apple Settings idioms (no Done button on detail drills). Pattern tap cascades (id + default position) as today; subsequent position taps commit position only. No in-progress state to design or test.

**Chevron alignment.**

- Settings screen: **moot** — only the Pattern row remains; chevron becomes a standard disclosure indicator; the custom-rendered chevron primitive can be dropped in favor of plain `NavigationLink`.
- Destination screen: same `visualCells` proportional math, same dot-row width parity contract — but inside one `Form`, no inter-`Section` coordination needed.

**Back-out semantics.** With auto-commit: back-out is "I'm done", everything saved, zero surprise, matches iOS Settings precedent.

**iOS pattern fit.** Strong. Settings.app → Sounds & Haptics → Ringtone (one-row drill into picker), Display & Brightness → Text Size (single drill hosts slider + toggle), Music.app → Settings → EQ (preset + related control on one screen). HIG progressive disclosure for tightly coupled controls.

**Blast radius.**

- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift` — settings row simplifies (`NavigationLink` instead of `Button` + `.navigationDestination`); custom `patternRowChevron(isVisible: true)` becomes the system disclosure; row preview gains the offset-glyph mitigation; private destination view absorbs the offset-position picker
- `Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionOffsetNotePositionSettingsSection.swift` — folded into the destination; file likely deleted or its `body` moves into the destination as a private section
- `Peach/Training/TimingOffsetDetection/Discipline/TimingOffsetDetectionDiscipline.swift` — drop the offset-position section from `settingsSections`
- `Peach/Training/TimingOffsetDetection/TimingDotView.swift` — `patternRowChevron` likely no longer needed at the settings layer (still needed inside the destination if dot-row width parity is reproduced there)
- Tests: AX1 no-truncation tests for the destination category headers stay; new tests for combined commit semantics; chevron-alignment tests at the settings layer retire

**Constraint preservation.**

- Iteration-2 chevron alignment: **moot at the settings layer; preserved inside the destination** via the same `visualCells` math.
- Atomic `patternIdBinding` cascade: **preserved** — `patternIdBinding` moves into the destination unchanged; position slot-picker writes `offsetNotePosition` directly. Both `@AppStorage` writes remain the source of truth; no in-progress buffer.

**Ask-First triggers under (c).** **Fired.** Two third-options surfaced:

1. **Sheet instead of push.** A `.sheet` (medium detent) keeps the settings list visible behind, reinforces "modal edit of a coupled pair," and lets a Done button feel native. Worth Michael's call against the push.
2. **Combined-picker primitive.** If other disciplines later grow paired knobs (pattern + accent; scale + root), extracting a `PatternWithSlotPicker` primitive now prevents one-off divergence. Premature otherwise.

**UX verdict: viable-with-caveats** — cohesion win provided the settings row preview surfaces the offset-glyph and Michael confirms push-vs-sheet before implementation.

### Comparative table

| Dimension                                           | Option (a) — hoist `.navigationDestination`                                                                                                | Option (c) — combined drill-down                                                                                                                            |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Files touched                                       | 5 (TrainingDisciplineUI, DisciplineSettingsSection, SettingsScreen, TOD discipline, TOD pattern-picker section)                            | 3–4 (TOD pattern-picker section, TOD offset-position section [folded/deleted], TOD discipline section list, possibly TimingDotView chevron retirement)      |
| Conformer impact (non-TOD disciplines)              | Zero (additive protocol default)                                                                                                           | Zero                                                                                                                                                        |
| New cross-cutting mechanism                         | `DisciplineSettingsNavigation` + protocol requirement on `TrainingDisciplineUI`                                                            | None — TOD-internal simplification                                                                                                                          |
| Chevron-alignment guarantee (settings)              | Preserved by construction                                                                                                                  | Moot (only one row remains)                                                                                                                                 |
| Chevron-alignment guarantee (destination)           | N/A — destination unchanged                                                                                                                | Same `visualCells` math; simpler (one `Form`, no inter-section coordination)                                                                                |
| Atomic `patternIdBinding` cascade                   | Preserved — binding closure untouched                                                                                                      | Preserved — binding moves into destination, semantics identical                                                                                             |
| User mental model                                   | Unchanged — two settings rows                                                                                                              | Two knobs collapse into one "rhythm + offset" decision; cohesion win, discoverability cost (mitigated by glyph-on-preview)                                  |
| Discoverability of offset-position                  | High (visible at top level)                                                                                                                | Reduced unless glyph-on-preview mitigation lands                                                                                                            |
| iOS pattern fit                                     | Standard SwiftUI navigation, Apple-docs-supported attachment                                                                               | Strong Settings.app idiom (Ringtone, Text Size, EQ); HIG progressive disclosure                                                                             |
| Ask-First triggers fired during audit               | None                                                                                                                                       | **Sheet-vs-push**; **combined-picker primitive**                                                                                                            |
| Test surface change                                 | Add: hoisted-modifier rendering; aggregation dedup. Keep: chevron-alignment tests, AX1 destination tests, atomic-cascade test.              | Drop: chevron-alignment tests at settings layer. Add: glyph-on-preview, combined-destination commit cascade, possibly auto-commit semantics test. Keep: AX1. |
| Risk profile                                        | Low — purely additive plumbing                                                                                                             | Low engineering; UX caveats (discoverability mitigation, push-vs-sheet)                                                                                     |
| Expert recommendation                               | Viable                                                                                                                                     | Viable-with-caveats                                                                                                                                         |

### Open decisions for Michael

1. **Pick (a) or (c).**
2. **If (c):** Sally surfaced two Ask-First triggers. Confirm pursue-as-drawn vs sheet-not-push vs combined-picker primitive. (Sally's instinct: push is fine if the settings row preview gains the offset-glyph; combined-picker primitive is premature until a second discipline needs it.)

_(Spec halts here per Task 1's "must complete and review before any code change". On Michael's pick, Task 2 locks in the chosen option, then Task 3 writes failing tests, etc.)_

## Spec Change Log

**2026-06-06 — Option (f) selected. Iteration-2 alignment mechanism retires entirely.**

The Task 1 design audit graded the two frozen-Intent options ((a) hoist `.navigationDestination` via `DisciplineSettingsSection` navigation contribution; (c) collapse Pattern + Offset Note Position into one drill-down). Michael rejected both:

- (a) introduces a special-case second channel on a cross-cutting protocol for a single discipline's need — unacceptable on architectural-hygiene grounds.
- (c) hides the Offset Note Position picker behind a drill-down — unacceptable because routinely switching to another screen to change the offset note is a usability nuisance for a setting users actually re-tune mid-session.

A second, deeper consult with `/swiftui-pro` and `/swiftui-ui-patterns` surfaced a third path (option (e) — transparent-NavigationLink overlay), but it relies on the undocumented "EmptyView-label suppresses NavigationLink's system chevron" behavior. Michael then asked the more fundamental question: the whole iteration-2 mechanism exists to make two dot rows occupy identical container widths via trailing-element matching; why not just give both dot rows an explicit fixed width and decouple the problem from anything trailing them?

Reading `TimingDotView.body` confirmed `TimingDotView` is fully flexible — it uses a `GeometryReader` and positions every cell proportionally. Today the two HStacks happen to deliver identical residual widths to their dot-row children only because they share an identical-intrinsic-width trailing chevron. Fixed-width framing on both dot rows dissolves the coupling.

**Option (f) — fixed-width dot rows (locked in).**

- Both dot rows constrained via `.frame(maxWidth: dotRowWidth, alignment: .leading)`, where `dotRowWidth` is each section's own `@ScaledMetric(relativeTo: .caption2)` wrapper around the shared base constant `TimingDotView.settingsRowDotsBaseWidth = 220`. Same base, identical Dynamic-Type scaling. `maxWidth` over `width` so the row clamps gracefully on extreme-narrow surfaces rather than overflowing.
- Pattern row uses plain `NavigationLink(destination:)`. System chevron is fine — it's no longer part of the alignment equation.
- Offset Note Position row drops its mirrored-transparent chevron; the slot picker is the row's sole content.
- `TimingDotView.patternRowChevron(isVisible:)` and `patternRowChevronSpacing` are deleted — the iteration-2 mechanism retires.
- No `.navigationDestination(...)` modifier remains in the lazy container → PF-046 vanishes.
- `DisciplineSettingsSection` is untouched. No protocol expansion. TOD-internal change.

**Constraints-preservation check against the frozen Intent's Always list:**

- "PF-046 is closed by this story" — yes; no `.navigationDestination(isPresented:)` modifier remains in the lazy container.
- "iOS logs no `Do not put a navigation destination modifier...` warning" — yes; nothing emits the diagnostic.
- "The iteration-2 chevron-alignment guarantee is preserved or replaced by an equivalent visual contract" — REPLACED. New contract: both dot rows share `TimingDotView.settingsRowDotsWidth`. Containers are equal by direct assignment, not by trailing-element matching. Audible positions still land at the same x because the proportional positioning math inside `TimingDotView` is unchanged.
- "The atomic selection cascade through `patternIdBinding` is preserved" — yes; `patternIdBinding` and its `cascadeWrites` static are untouched.

**Constraints-preservation check against the frozen Intent's Never list:**

- "No revert to `NavigationLink` (option (b))" — option (f) IS using `NavigationLink`, but the iteration-2 reason for excluding it (the system chevron breaking dot-x alignment) no longer applies because dot-x alignment is now achieved by direct fixed-width framing rather than by matching trailing-element widths. The Never's spirit (do not re-introduce the chevron-alignment misery) is honored.
- "No new navigation-style primitives" — none added; we use plain `NavigationLink`.
- "No drive-by closure of Story 85.6" — no overlap.
- "No `@AppStorage` or persistence changes" — none.

**Boundaries & Constraints renegotiation.** Per the frozen Intent's Ask-First clause ("If [the option (c) consult] surfaces a third design ... pause and confirm before pursuing it"), option (f) qualified as a third design and Michael's selection counts as the pause-confirm. No further Boundaries changes are needed beyond logging this in the Change Log.

**2026-06-06 — Step-04 review applied. One patch, two PFs filed, five rejects.**

Three review subagents (Blind Hunter, Edge Case Hunter, Acceptance Auditor) reviewed the diff. Deduplicated to 8 findings, classified:

- **Patch (F5)** — Spec text used `settingsRowDotsWidth` and `.frame(width:)` while code uses `settingsRowDotsBaseWidth` and `.frame(maxWidth:)`. Touched-files block and Spec Change Log option-(f) summary updated to match implementation naming.
- **Defer (F1) → PF-064.** Two parallel `@ScaledMetric` wrappers carry the dot-row width contract. Production-safe today (both sections share Form environment); structural risk if a future test or wrapper applies a per-section environment override. Fix is option-(a)-style hoist (rejected) or a shared `ViewModifier` — defer and revisit if divergence actually surfaces.
- **Defer (F4) → PF-065.** The new test pins the base constant value but not the alignment contract directly. Story 85.6's invariant infrastructure could host a regression test; out-of-scope for this story.
- **Reject (F2, F3)** — `.frame(maxWidth:)` ≠ literal fixed width; at AX5 on narrow rows both sections clamp to their respective available widths with ~22 pt asymmetry from the NavigationLink chevron. Acceptable trade-off; no regression vs the pre-85.7 mechanism which also degraded with text size. The `maxWidth` choice is deliberate over `width` for graceful overflow.
- **Reject (F6)** — Modifier order `.frame(maxWidth:)` before `.frame(height:)` does not collapse the GeometryReader; SwiftUI's `.frame` modifiers propagate proposed sizes through the chain in either order. Michael visually confirmed the layout renders correctly.
- **Reject (F7)** — `cells.filter { ... }` returning `[]` is not reachable under the current catalog (every pattern has at least one accent cell).
- **Reject (F8)** — `NavigationLink` VoiceOver announcement order differs from `Button` + `.accessibilityValue`. Switching to the standard iOS navigation idiom is generally a VoiceOver win, not a regression.

## Suggested Review Order

**The replacement contract (start here)**

- Shared base width — the single source of truth that ends the chevron-mirroring trick.
  [`TimingDotView.swift:224`](../../Peach/Training/TimingOffsetDetection/TimingDotView.swift#L224)

- Pattern row reads the base into its own `@ScaledMetric` wrapper.
  [`TimingOffsetDetectionPatternPickerSettingsSection.swift:30`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift#L30)

- Offset row reads the same base into its own `@ScaledMetric` wrapper — same base ⇒ identical resolved width.
  [`TimingOffsetDetectionOffsetNotePositionSettingsSection.swift:33`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionOffsetNotePositionSettingsSection.swift#L33)

**PF-046 closure — the warning-triggering modifier is gone**

- Pattern row switches from `Button` + `.navigationDestination(isPresented:)` back to plain `NavigationLink`; `isShowingDestination` state retired; system disclosure chevron is fine because alignment is no longer coupled to it.
  [`TimingOffsetDetectionPatternPickerSettingsSection.swift:35`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift#L35)

- Pattern row dot preview gets the width via `.frame(maxWidth: dotRowWidth, alignment: .leading)`.
  [`TimingOffsetDetectionPatternPickerSettingsSection.swift:42`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionPatternPickerSettingsSection.swift#L42)

- Offset row sheds its outer `HStack` and transparent chevron; slot picker is the sole row content, mirrored at the same width.
  [`TimingOffsetDetectionOffsetNotePositionSettingsSection.swift:67`](../../Peach/Training/TimingOffsetDetection/Settings/TimingOffsetDetectionOffsetNotePositionSettingsSection.swift#L67)

**Iteration-2 mechanism retired**

- `patternRowChevron(isVisible:)` and `patternRowChevronSpacing` deleted from `TimingDotView` — no other call site remains.
  [`TimingDotView.swift:212`](../../Peach/Training/TimingOffsetDetection/TimingDotView.swift#L212)

**Tests**

- Base constant pinned at 220pt (red-phase fail → green after implementation).
  [`TimingDotViewTests.swift:69`](../../PeachTests/Training/TimingOffsetDetection/TimingDotViewTests.swift#L69)

**Catalog hygiene & follow-ups**

- PF-046 entry removed; PF-064 (parallel `@ScaledMetric` divergence risk) and PF-065 (alignment regression test gap) filed for follow-up.
  [`deferred-work.md`](deferred-work.md)
