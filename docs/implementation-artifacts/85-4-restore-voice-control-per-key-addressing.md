---
title: 'Story 85.4: Restore per-key Voice Control addressing on NoteRangeSelector'
type: 'cleanup'
created: '2026-06-05'
status: 'done'
baseline_commit: '67cd974a'
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

- `Peach/Core/Music/MIDINote.swift` — `name` property uses literal `#` for black keys (`"C#3"`); Voice Control synonym labels need to translate `#` → "sharp" for spoken matching.
- *No XCUITest target* in project today. Test surface stays in Swift Testing unit suites against pure helpers.

## Tasks & Acceptance

**Execution:**

- [x] **Task 1 — Accessibility audit (must complete and review before any code change).** Invoke `/ios-accessibility` against `NoteRangeSelector`'s current accessibility tree. The audit produces: (a) a tree map of the current accessibility surface on the non-AX1 path and the AX1+ fallback path, naming what each AT (VoiceOver / Switch Control / Voice Control / Full Keyboard Access) sees; (b) confirmation or correction of the catalog's framing (the catalog says the two goals were mutually exclusive in the original SwiftUI configuration — verify whether that's still true at current SwiftUI semantics); (c) the locked design — concrete modifier composition (`.accessibilityCustomActions` per-key, markers as `.accessibilityAdjustable`, or whatever the audit endorses) — including how it interacts with the AX1+ fallback path; (d) any additional accessibility paths the audit surfaces (e.g., Full Keyboard Access) that warrant explicit handling. Append output as a new section above. **Halt for human review before Task 2.**
- [x] **Task 2 — Approach lock-in (post-audit).** Based on the audit, finalise the modifier composition and update Boundaries & Constraints if Ask-First conditions triggered. Identify the AT-specific tests Task 3 will write.
- [x] **Task 3 — Accessibility tests (tests-first).** Add tests that pin the contract on every relevant AT path: Voice Control per-key addressing for a representative set of in-range notes (at minimum the four boundary notes plus a black-key sample); VoiceOver two-marker adjustable; Switch Control two-marker adjustable; AX1+ Slider fallback. Use whatever test harness `/ios-accessibility` recommends (XCUITest accessibility audits, `accessibilityElements` direct inspection, or both).
- [x] **Task 4 — Restructure the accessibility tree.** Implement the locked design from Task 2. Replace `.accessibilityRepresentation` with the composition the audit endorsed on the non-AX1 path. Preserve the AX1+ fallback path unchanged.
- [x] **Task 5 — Catalog hygiene.** Remove the PF-020 section from `docs/implementation-artifacts/deferred-work.md`. Cite PF-020 in the commit message.
- [x] **Task 6 — Pre-commit gates.** Run `bin/test.sh && bin/test.sh -p mac` and `bin/test.sh --research && bin/test.sh --research -p mac`. All four green. *(2026-06-06 post-review re-run: iOS Debug 1977, macOS Debug 1971, iOS Research 2138, macOS Research 2132.)*

**Acceptance Criteria:**

- **PF-020 Voice Control.** Given Dynamic Type below AX1 with the keyboard visible, when the user issues a Voice Control command of the form "Tap <name>" for any in-range `MIDINote`, then that key is focused or activated (asserted by accessibility test over a representative sample of in-range notes including white keys, black keys, and the range boundaries).
- **VoiceOver parity below AX1.** Given Dynamic Type below AX1, when VoiceOver navigates through the keyboard, then the two-marker adjustable representation is presented and behaves as today (asserted by accessibility test against `baseline_commit` behaviour).
- **Switch Control parity below AX1.** Given Dynamic Type below AX1, when Switch Control scans and adjusts, then the two-marker adjustable behaviour matches `baseline_commit` (asserted by accessibility test).
- **AX1+ fallback unchanged.** Given Dynamic Type at or above AX1, when any AT interacts with the keyboard, then the existing two-Slider fallback path behaves identically to `baseline_commit` (asserted by accessibility test, plus existing AX1 tests still pass without modification).
- **Functional parity.** Drag, tap-on-dimmed, keyboard arrow, and visual rendering behave identically to `baseline_commit` on every Dynamic Type path.
- **Pre-commit gate.** All four schemes green: Debug × {iOS, macOS} and Research × {iOS, macOS}. No new compiler warnings.
- **Catalog hygiene.** PF-020 section removed from `deferred-work.md` in the closing commit.

## Accessibility Audit Findings

*Performed 2026-06-06 against `Peach/Settings/NoteRangeSelector.swift` at baseline `67cd974a`. Uses iOS 26 SDK semantics for `.accessibilityRepresentation`, `.accessibilityAdjustableAction`, `.accessibilityAction`, and `.accessibilityInputLabels`.*

### (a) Current accessibility tree

#### Below-AX1 path (`keyboardBody`, lines 127–173)

Modifier composition (read outside-in):

```
keyboardBody (GeometryReader)
├── .frame(height: totalKeyboardHeight)
├── .accessibilityElement(children: .contain)
└── .accessibilityRepresentation { VStack { Slider×2 } }
```

The `.accessibilityRepresentation` block (lines 161–172) replaces the entire accessibility subtree of `keyboardBody` with two `Slider`s labeled `"Lowest Note"` / `"Highest Note"`, valued at `lowerNote.name` / `upperNote.name`, stepping by 1 over `lowerLegalRange` / `upperLegalRange` (converted to `Double`). Per Apple docs, `.accessibilityRepresentation` is a tree replacement, not an addition — none of the original subtree (including the per-key `.accessibilityLabel(Text(note.name))` set inside `PianoKey` at line 477) is reachable through the accessibility tree on this path.

Subtree elements that exist visually but are NOT exposed through `.accessibilityRepresentation`:

| Element | Source | Visual modifier | Reachable today? |
|---------|--------|-----------------|------------------|
| `PianoKey` (white & black) per-key | `keysRow`, line 219 / 225 | `.accessibilityLabel(Text(note.name))` (line 477 inside `PianoKey`) | **No** — hidden by parent's `.accessibilityRepresentation` |
| `BoundMarker` lower | `markerRow`, line 190 | `.accessibilityHidden(true)` (line 503 inside `BoundMarker`) + `.accessibilityHint(...)` at call site (line 198) | No — already explicitly hidden inside |
| `BoundMarker` upper | `markerRow`, line 199 | same as lower (line 207 hint) | No |
| Octave labels row | `labelsRow`, line 245 | `.accessibilityHidden(true)` (line 249) | No — decorative |
| `liveBoundHUD` lower/upper | `labelsRow`, lines 255–256 | `.accessibilityHidden(true)` (line 269) | No — decorative |

What each AT actually sees on the below-AX1 path:

| AT | What's visible | UX |
|----|----------------|-----|
| **VoiceOver** | Two Sliders (Lowest Note, Highest Note); each adjustable by swipe-up/down; values read as note names | Works |
| **Switch Control** | Two Sliders, scannable, adjust-action increments/decrements | Works |
| **Voice Control** | Only `"Tap Lowest Note"` / `"Tap Highest Note"` addressable; **`"Tap C3"` / any per-key command resolves to nothing** | **PF-020 — broken** |
| **Full Keyboard Access** | Two paths overlap: (1) SwiftUI focus tree (`.focusable()` + `.onKeyPress` on each marker, lines 193–197 / 202–206) — Tab cycles lower marker ↔ upper marker, arrow keys adjust ±1 semitone (Shift ±12), Home/End jump to legal-range bounds. (2) Accessibility tree — Tab also visits the two Sliders from the representation. The two surfaces both work but FKA users see redundant focus stops | Works (slightly noisy) |

#### AX1+ path (`KeyboardSummary`, lines 507–538)

`body` branches on `dynamicTypeSize >= .accessibility1` (line 113). At AX1+ the keyboard view is not rendered; `KeyboardSummary` is rendered instead with two real `Slider` controls.

What each AT sees on the AX1+ path:

| AT | What's visible | Notes |
|----|----------------|-------|
| VoiceOver / Switch Control / Voice Control | Two real `Slider`s with labels "Lowest Note" / "Highest Note" and value = note name | Works |
| Full Keyboard Access | Two Sliders; system focus + arrow-key adjust | Works |

PF-023 (partner-imposed range shifts mid-edit) lives on this path and stays WONT-FIX.

### (b) Catalog framing — confirm + one correction

The catalog's framing of `.accessibilityRepresentation` as **tree replacement, not addition** is confirmed at iOS 26 SDK semantics. There is no SwiftUI modifier today that composes a system-Slider adjustable behaviour over a custom subtree without hiding the subtree. Per-key labels and `.accessibilityRepresentation` are mutually exclusive on the same view — exactly as PF-020 describes.

**Correction to the catalog's proposed sketch.** The catalog said:

> *Restructure the accessibility tree so per-key Voice Control addressing works on the non-AX1 path as well (e.g., `.accessibilityCustomActions` plus markers as adjustable elements without `.accessibilityRepresentation`).*

`.accessibilityCustomActions` is the **wrong mechanism for per-key addressing**. Custom actions are surfaced under a parent element via Voice Control's `"Show actions"` command and VoiceOver's Actions Rotor — they are not addressable by name as standalone elements. To make `"Tap C3"` work, each key must be its own **accessibility element with the `.isButton` trait and a tap action**, not a custom action on a parent.

The right framing: per-key accessibility elements (`.isButton` + `.accessibilityAction`) + markers as separate adjustable accessibility elements (`.accessibilityAdjustableAction`), all without `.accessibilityRepresentation`.

### (c) Locked design

**Below-AX1 keyboard tree (replaces current `.accessibilityRepresentation` block):**

1. `keyboardBody` root keeps `.accessibilityElement(children: .contain)`. Remove `.accessibilityRepresentation { ... }`. Add a container label (e.g., `Text("Training Note Range Keyboard", comment: …)`) so VoiceOver's "where am I" announcement is useful.

2. Each `PianoKey` in `keysRow` becomes a tappable accessibility element:

    ```swift
    PianoKey(note: note, isWhite: true, isInRange: isInRange(note))
        .frame(width: keyWidth, height: Self.whiteKeyHeight)
        .id(note.rawValue)
        .accessibilityAddTraits(.isButton)
        .accessibilityInputLabels(Self.voiceControlInputLabels(for: note))
        .accessibilityAction { tapNote(note) }
        .accessibilitySortPriority(0)
    ```

   `PianoKey`'s existing `.accessibilityLabel(Text(note.name))` inside the struct stays. `tapNote(_:)` is a new `NoteRangeSelector` method that routes through the existing `tapResolution` → `clampLower`/`clampUpper` semantics — same logic as `handleTap` but taking a `MIDINote` directly (CGPoint → MIDINote lookup is unnecessary since we already know the key). In-range taps remain no-ops, matching visual tap semantics.

3. Each `BoundMarker` site in `markerRow` becomes an adjustable accessibility element:

    ```swift
    BoundMarker(note: lowerNote)
        .position(x: ..., y: ...)
        .gesture(dragGesture(for: .lower, totalWidth: totalWidth))
        .focusable()
        .focused($focusedMarker, equals: .lower)
        .onKeyPress(phases: [.down, .repeat]) { press in handleKey(press, marker: .lower) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Lowest Note", comment: …))
        .accessibilityValue(Text(lowerNote.name))
        .accessibilityHint(Text("Adjust to set the lowest training note", comment: …))
        .accessibilityAdjustableAction { direction in adjustMarker(.lower, direction: direction) }
        .accessibilitySortPriority(1)
    ```

   And the same shape for the upper marker (label "Highest Note", value = `upperNote.name`, sort priority 1). `adjustMarker(_:direction:)` is a new method that increments/decrements by one semitone within the marker's legal range — equivalent to `keyboardCommit(.rightArrow / .leftArrow, ...)` plumbed through the binding.

   Remove `.accessibilityHidden(true)` from `BoundMarker`'s internal `body` (line 503) — its now-overridden by the call-site `.accessibilityElement(children: .ignore)`, but removing the hidden modifier is cleaner.

4. Octave labels row and `liveBoundHUD` stay `.accessibilityHidden(true)` — they are decorative.

5. **Sort priority partitions the swipe order.** Markers get `.accessibilitySortPriority(1)`, keys get `0` (default). VoiceOver swipe order on the keyboard becomes `[lower marker, upper marker, key, key, …]` — markers are reachable in two swipes, then per-key elements follow. Voice Control addresses everything by name regardless of sort priority. Switch Control scans the same order.

**Voice Control speech matching (one new concern surfaced by the audit).**

`MIDINote.name` returns `"C3"` / `"C#3"` — black keys use the literal `#` character. Voice Control does NOT translate `#` → "sharp" automatically; `"Tap C sharp 3"` will not resolve to a label literal of `"C#3"`. The AC requires every in-range note — including black keys — addressable by Voice Control, so the locked design **requires** `.accessibilityInputLabels` synonyms per key:

| Key | `accessibilityLabel` | `accessibilityInputLabels` |
|-----|----------------------|-----------------------------|
| White (e.g. `C3`) | `"C3"` | `["C3", "C 3", "C three"]` |
| Black (e.g. `C#3`) | `"C#3"` | `["C sharp 3", "C-sharp 3", "C sharp three", "C#3"]` |

Implementation: a `static func voiceControlInputLabels(for: MIDINote) -> [String]` on `NoteRangeSelector` (private), derived from `note.name`. Pure function — unit-testable.

Open question: should the labels also vary by locale? German VoiceOver and Voice Control might prefer `"Cis 3"` (German note name for C-sharp). Per [feedback_german_informal] and the broader localization effort, German strings need to use informal forms. **Recommended**: ship the English synonyms in this story and surface German spoken names as a follow-up (separate PF) — the AC asserts Voice Control addressing works, not that German Voice Control reads German note names. Confirm during human review.

**AX1+ path interaction.** No change. The `body`'s `if dynamicTypeSize >= .accessibility1` branch (line 113) keeps the two surfaces fully separate. `KeyboardSummary` is unchanged; PF-023 stays WONT-FIX.

**Full Keyboard Access path.** Unchanged — `.focusable()` + `.onKeyPress` on the two markers remains the FKA Tab cycle (2 stops). The new per-key accessibility elements are accessibility-only (`.accessibilityAddTraits(.isButton)` + `.accessibilityAction` without wrapping in a real `Button`) so they do NOT enter the SwiftUI focus tree — FKA users still get a 2-stop Tab cycle, not 88+2. Voice Control addresses keys via the accessibility tree, which is independent of focus.

### (d) Additional surfaces

- **VoiceOver Buttons Rotor** will list all in-range piano keys as buttons (one entry per in-range note). Acceptable consequence of per-key addressing — also gives VoiceOver users a "jump to C3" route via Rotor.
- **Switch Control** automatic scanning will scan markers first (sort priority 1), then keys (sort priority 0). Scan-adjust on a focused marker invokes the same `.accessibilityAdjustableAction`. ✓
- **Voice Control "Show numbers"** will overlay one number per accessibility element — 2 markers + N in-range keys. Acceptable.
- **Voice Control "Show grid"** (precision tapping) — unaffected; works regardless of accessibility tree.

### Tests

Project has **no XCUITest UI test target** today (verified by `find PeachUITests`). All tests are Swift Testing unit tests on static helpers and pure logic.

**Recommended test surface** (covers the AC's "asserted by accessibility test"):

1. **Pin the action helpers** (Swift Testing, mirrors existing `NoteRangeSelectorTests` style):
   - `tapNote` resolves an in-range note → no-op
   - `tapNote` resolves a below-range note → moves lower bound, respects `clampLower`
   - `tapNote` resolves an above-range note → moves upper bound, respects `clampUpper`
   - `tapNote` at boundary notes → no-op
   - `adjustMarker(.lower, direction: .increment)` → +1 semitone within `lowerLegalRange`
   - `adjustMarker(.upper, direction: .decrement)` → −1 semitone within `upperLegalRange`
   - `adjustMarker` at the partner-imposed limit → no change
   - `voiceControlInputLabels(for:)` for representative MIDI notes (white, black, range boundaries): asserts each label string list contains the literal name AND the spoken-form variants.

2. **Manual verification documented in spec** (executed during Task 6 visual check, matching [feedback_verify_visual_features]):
   - VoiceOver below AX1: swipe through keyboard, verify two markers come first; adjust each by swipe up/down; verify per-key labels are read on subsequent swipes.
   - Switch Control below AX1: scan to lower marker, adjust by scan-adjust; scan to upper marker, adjust.
   - Voice Control below AX1: enable, say "Show names", verify per-key labels overlay; say "Tap C3", "Tap C sharp 3", "Tap A0" (lowest white), "Tap C8" (highest white), "Tap C sharp 8" (highest black) — verify each focuses/activates the corresponding key.
   - AX1+: enable AX1, verify keyboard hidden, summary line + two system Sliders shown, both Sliders work.
   - Full Keyboard Access: Tab cycles markers only (2 stops), arrow keys still adjust.

Both pre-commit gates (Debug & Research, iOS & macOS) must pass.

### Locked answers (post human review, 2026-06-06)

- **(Q1) Locale coverage — English + German.** `voiceControlInputLabels(for:locale:)` returns locale-specific synonyms. English locale: `["C3", "C 3", "C three"]` for white keys, `["C#3", "C sharp 3", "C-sharp 3", "C sharp three"]` for black keys. German locale: `["C3", "C 3", "C drei"]` for white keys, `["C#3", "Cis 3", "Cis drei", "Cis3"]` for black keys (German sharp suffix `-is`). B/H trap handled: English pitch class 11 (`"B3"`) German alternative is `"H3"` / `"H 3"` / `"H drei"`; English `"A#3"` (pitch class 10) German alternatives are `"Ais 3"` and the flat form `"B 3"`. Locale resolution at view-init via `Locale.current`. Tests pass explicit locale to the static helper.
- **(Q2) Test surface — static helpers + documented manual verification.** Swift Testing unit tests pin the new `tapNote`, `adjustMarker`, and `voiceControlInputLabels` helpers. Manual verification matrix documented in the spec; executed during Task 6 visual check (per [feedback_verify_visual_features]).
- **(Q3) In-range `tapNote` — no-op.** Matches visual `tapResolution(at:lower:upper:)` semantics. Voice Control still focuses/highlights the key on `"Tap [name]"` even when the action is a no-op, satisfying the AC's "focused **or** activated" phrasing.

## Spec Change Log

- **2026-06-06 — Task 1 audit complete; locked answers recorded.** Catalog's `.accessibilityCustomActions` sketch corrected to per-key `.isButton` + `.accessibilityAction` (custom actions are not addressable by `"Tap [name]"`). Voice Control speech matching for black-key `#` literal flagged; locked design adds `.accessibilityInputLabels` synonyms via a new static helper `voiceControlInputLabels(for:locale:)`. Locale coverage expanded to English + German per human review (Q1) — scope-additive to the frozen "every in-range key" rule, not a renegotiation. Test surface stays static helpers + manual verification (Q2). In-range tap stays no-op (Q3).
- **2026-06-06 — Step-04 review patches + defers.** Three review subagents (blind hunter, edge case hunter, acceptance auditor) returned 35 raw findings; 5 patches and 4 defers after dedup. **Patches applied:** (A) test cleanup — replaced duplicate `#expect(labels.contains("A -1"))` with negative assertions matching the comment's stated intent; (D) added the no-space German variant (`Cis4`, `Dis4`, ...) per locked answer Q1 literal text plus a test assertion; (E) tightened `voiceControlInputLabels` doc-comment to clarify short-form-vs-spelled-out distinction. **Patches deliberately not applied:** the locked design illustrated an `.accessibilityHint(Text("Adjust to set..."))` and a container `.accessibilityLabel(Text("Training note range keyboard"))` on the keyboard root. Both omitted. Reason: per the `/ios-accessibility` skill's "Do not add hints unless needed", the marker's `.accessibilityLabel + .accessibilityValue + .accessibilityAdjustableAction` composition causes VoiceOver to announce "Adjustable. Swipe up or down with one finger…" built-in, making the hint redundant. Container label deferred pending a Settings-screen-wide a11y polish story. **Defers filed:** PF-061 (`keyboardCommit` direction inversion when `current` outside `legalRange` — pre-existing in arrow-key path, inherited by accessibility adjust); PF-062 (marker `.accessibilityValue` reads English `note.name` regardless of locale — symmetrical gap with AX1+ Slider); PF-063 (German Voice Control `"B 4"` collision between A#4 and B4 — Voice Control number-overlay disambiguates; classical-vs-modern German convention call deferred to `agent-music-domain-expert`).
- **2026-06-06 — `/simplify-code` pass.** Collapsed `handleTap(location:totalWidth:)` to a one-liner delegating to `tapNote(_:)` after walking every reachable `tapResolution` case and confirming the `if clamped != current` guard never triggered (visual tap and accessibility tap share one implementation now). Trimmed `tapNote` doc-comment to match project style ("default to writing no comments") — name is self-explanatory. Kept short `adjustMarker` doc-comment since the `keyboardCommit` reuse rationale is non-obvious. All four schemes green after consolidation.

## Suggested Review Order

**Accessibility tree restructure (the design intent)**

- The old `.accessibilityRepresentation` Slider block is gone; container keeps `.accessibilityElement(children: .contain)` so per-key + marker elements are both exposed.
  [`NoteRangeSelector.swift:160`](../../Peach/Settings/NoteRangeSelector.swift#L160)

**Marker = adjustable accessibility element (VoiceOver / Switch Control surface)**

- Lower marker: label "Lowest Note", value = current note, `.accessibilityAdjustableAction` increments / decrements by one semitone within legal range; sort priority 1 keeps it ahead of keys.
  [`NoteRangeSelector.swift:186`](../../Peach/Settings/NoteRangeSelector.swift#L186)

- Upper marker mirrors the lower marker's composition.
  [`NoteRangeSelector.swift:201`](../../Peach/Settings/NoteRangeSelector.swift#L201)

**Per-key Voice Control addressing (closes PF-020)**

- Each white key carries `.isButton` + `.accessibilityInputLabels(...)` synonyms + `.accessibilityAction { tapNote(note) }`.
  [`NoteRangeSelector.swift:223`](../../Peach/Settings/NoteRangeSelector.swift#L223)

- Black keys mirror the same composition over the overlaid `ZStack`.
  [`NoteRangeSelector.swift:234`](../../Peach/Settings/NoteRangeSelector.swift#L234)

**Dispatch helpers (shared between visual and accessibility surfaces)**

- `tapNote(_:)` is the single canonical tap implementation; visual `handleTap` now delegates after the CGPoint→MIDINote lookup.
  [`NoteRangeSelector.swift:347`](../../Peach/Settings/NoteRangeSelector.swift#L347)

- `adjustMarker(_:direction:)` reuses `keyboardCommit` so the VO/SC adjustable path and the hardware arrow-key path share one legal-range clamp.
  [`NoteRangeSelector.swift:365`](../../Peach/Settings/NoteRangeSelector.swift#L365)

**Voice Control synonyms (locale-aware label generator)**

- `voiceControlInputLabels(for:locale:)` is the new pure helper — English + German spelled-out forms, classical sharp/flat names, dedup.
  [`NoteRangeSelector.swift:512`](../../Peach/Settings/NoteRangeSelector.swift#L512)

**Tests (pinning the helper, not the SwiftUI plumbing)**

- 12 new `voiceControlInputLabels` tests cover white, black, range boundaries, German classical names (Cis, Dis, Es, As, Ais, H), B/H trap, and out-of-table octave fallback.
  [`NoteRangeSelectorTests.swift:234`](../../PeachTests/Settings/NoteRangeSelectorTests.swift#L234)

**Catalog hygiene**

- PF-020 removed; PF-061 / PF-062 / PF-063 filed in its place during step-04 review.
  [`deferred-work.md:359`](deferred-work.md#L359)
