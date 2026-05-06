---
title: 'Fix macOS training window title showing "Peach"'
type: 'bugfix'
created: '2026-05-06'
status: 'done'
baseline_commit: 'a3cb954f4ac3099690e5f218235569aebdcce67e'
context:
  - 'docs/project-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** On macOS the four training screens leave the window title at the app name `Peach` because none of them call `.navigationTitle(...)`. Profile, Settings, Info and Start all set one. The bug surfaced during 71.4 macOS screenshot capture.

**Approach:** Set `.navigationTitle(...)` on each training screen using the discipline's existing `displayName` localization key (`Compare Pitch`, `Compare Intervals`, `Match Pitch`, `Match Intervals`, `Compare Timing`, `Fill the Gap`). The `.principal` toolbar item (icon + noun) stays unchanged on iOS; on macOS the window title bar now shows the discipline name.

## Boundaries & Constraints

**Always:**
- Reuse the existing `String(localized: "...")` keys already used by the discipline `displayName` values — no new catalog entries.
- Branch on `isIntervalMode` for PitchDiscrimination/PitchMatching screens, mirroring the existing toolbar branching.

**Ask First:**
- If the `displayName` key turns out to need different wording for a window title than for the start-screen button, surface that before forking keys.

**Never:**
- Do not change the `TrainingScreenModifier` signature or behavior. Per-screen one-line addition only.
- Do not change principal toolbar items, icons, accessibility labels, or any non-title behavior.
- Do not modify story 71.4's spec or the untracked `marketing/screenshots/mac/` files.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior |
|----------|--------------|---------------------------|
| macOS, push any training screen | NavigationStack pushes the screen | Window title bar shows the discipline display name listed above; never `Peach` |
| iOS, push any training screen | NavigationStack pushes the screen | Nav bar still shows the existing `.principal` icon + noun, visually identical to before |
| macOS, training → Profile via chart icon | User taps Profile toolbar button | Profile back-button label is the discipline display name (current chevron only) |
| German locale, both platforms | System language is `de` | Window title / back-button uses the existing German translation; no untranslated keys |

</frozen-after-approval>

## Code Map

- `Peach/Training/PitchDiscrimination/PitchDiscriminationScreen.swift` — needs `.navigationTitle(...)` keyed on `isIntervalMode`
- `Peach/Training/PitchMatching/PitchMatchingScreen.swift` — needs `.navigationTitle(...)` keyed on `isIntervalMode`
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionScreen.swift` — needs `.navigationTitle("Compare Timing")`
- `Peach/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingScreen.swift` — needs `.navigationTitle("Fill the Gap")`
- `Peach/Training/*/Discipline/*Discipline.swift` — read-only reference for the existing localized keys
- `Peach/App/Platform/PlatformModifiers.swift` — adds `platformPrincipalToolbarItem<Content:>(@ViewBuilder _:)` helper that places the principal toolbar item on iOS and is a no-op on macOS
- `Peach/App/TrainingScreenModifier.swift` — replaces inline `ToolbarItem(.principal) { title }` with `.platformPrincipalToolbarItem { title }` outside the toolbar block; trailing toolbar items remain unchanged

## Tasks & Acceptance

**Execution:**
- [x] `Peach/Training/PitchDiscrimination/PitchDiscriminationScreen.swift` -- add `.navigationTitle(isIntervalMode ? String(localized: "Compare Intervals") : String(localized: "Compare Pitch"))` before `.trainingScreen(...)`
- [x] `Peach/Training/PitchMatching/PitchMatchingScreen.swift` -- add `.navigationTitle(isIntervalMode ? String(localized: "Match Intervals") : String(localized: "Match Pitch"))` before `.trainingScreen(...)`
- [x] `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionScreen.swift` -- add `.navigationTitle(String(localized: "Compare Timing"))` before `.trainingScreen(...)`
- [x] `Peach/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingScreen.swift` -- add `.navigationTitle(String(localized: "Fill the Gap"))` before `.trainingScreen(...)`
- [x] Hide the `.principal` training-toolbar item on macOS via a new `platformPrincipalToolbarItem` helper in `Peach/App/Platform/PlatformModifiers.swift`; `TrainingScreenModifier` now calls `.platformPrincipalToolbarItem { title }` instead of placing a `ToolbarItem(.principal)` inline. This avoids the doubled / truncated macOS title bar (`Tonhöhe vergleich…` next to `Tonhöhe`) discovered after the first build.
- [x] Built `bin/build.sh` (iOS) and `bin/build.sh -p mac` cleanly (1 pre-existing AppIntents warning each, no new warnings). Tests: `bin/test.sh` 1479 passed, `bin/test.sh -p mac` 1473 passed. Visual verification (Mac window title + iOS nav bar) is a manual step for the human reviewer.

**Acceptance Criteria:**
- Given the macOS app on the Start Screen, when the user enters any of the six training disciplines, then the window title bar shows the discipline's display name and never `Peach`.
- Given the iOS app, when the user enters any training screen, then the nav bar `.principal` icon + noun looks visually identical to before this change.
- Given the macOS app, when the user enters any training screen, then the toolbar shows ONLY the trailing buttons (Help, Settings, Profile) — no principal item — and the window title bar shows the discipline's full display name without truncation/competition.
- Given a German locale on macOS, when the user enters pitch comparison, then the window title shows the existing German translation of the relevant key (no new untranslated strings appear).

## Spec Change Log

- **2026-05-06 — User-driven loopback (renegotiated frozen constraint).**
  Triggering finding: with `.principal` toolbar items left in place on macOS, the navigation toolbar showed both the icon-rich principal item and the navigationTitle, and the navigationTitle truncated to fit (`Tonhöhe vergleich…`). The frozen `Never:` clause forbidding changes to `TrainingScreenModifier` was wrong — the principal item must be hidden on macOS, where the window title bar already covers that role.
  Amendment: relaxed to permit hiding the principal toolbar item on macOS. The `#if os()` branch lives in `Peach/App/Platform/PlatformModifiers.swift` per `docs/project-context.md`'s `#if os()` policy (composition root or `App/Platform/` only). A new `platformPrincipalToolbarItem<Content: View>(@ViewBuilder _ content: () -> Content)` helper was added there; `TrainingScreenModifier` now calls `.platformPrincipalToolbarItem { title }` and its `toolbarContent` carries only the trailing items.
  Avoids the known-bad state where `TrainingScreenModifier` itself contains `#if os(iOS)` (which I had introduced as a first try and which the user rejected on the second review).
  KEEP: the per-screen `.navigationTitle(...)` strings are correct and must survive re-derivation; only the principal-item hiding strategy was added.

## Design Notes

`.principal` toolbar items replace the iOS nav-bar title slot but on macOS they coexist with the window title bar — visually competing and forcing truncation. The fix has two parts: (1) per-screen `.navigationTitle(...)` so macOS has a real window title (not the inherited `Peach`), and (2) hide the `.principal` item on macOS so the window title bar is the single title surface.

The platform conditional lives behind `platformPrincipalToolbarItem` in `App/Platform/PlatformModifiers.swift` so feature-level files stay platform-agnostic. The `title: Title` parameter on `TrainingScreenModifier` is unchanged — it is still passed by callers and consumed by the iOS branch of the helper; on macOS the helper returns `self`.

Side benefit on iOS: navigationTitle drives back-button labels, so the Profile screen pushed from a training screen will now show the discipline name on its back button instead of a bare chevron.

## Verification

**Commands:**
- `bin/build.sh` and `bin/build.sh -p mac` -- expected: succeed without new warnings
- `bin/test.sh && bin/test.sh -p mac` -- expected: all tests pass (no new tests added; this is a UI-chrome change with no testable Swift surface)

**Manual checks:**
- macOS: enter each of the six training-discipline buttons; confirm the title bar shows the right discipline name and never `Peach`.
- macOS: training → Profile via chart icon → back; confirm navigation flows correctly and the title restores.
- iOS: enter all six training-discipline buttons; confirm the nav bar layout is visually unchanged.
- German locale: repeat the macOS check; confirm titles use existing translations.
