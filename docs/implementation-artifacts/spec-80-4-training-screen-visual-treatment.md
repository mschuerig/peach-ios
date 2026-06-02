---
title: 'Story 80.4: Training-screen help text refresh for looped playback'
type: 'feature'
created: '2026-06-02'
status: 'done'
baseline_commit: '52accfd6'
context:
  - '{project-root}/docs/implementation-artifacts/epic-80-context.md'
  - '{project-root}/docs/implementation-artifacts/spec-80-3-settings-ui-contribution-and-localization.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** After 80.1 widened `canAcceptAnswer` to include `.playingPatternLoop` and made playback loop-until-decision, the training-screen Help text in `TimingOffsetDetectionHelp.trainingScreen` is now actively wrong: **Controls** says *"Once the pattern finishes, the **Early** and **Late** buttons become active"*, but the buttons are tappable from the first click. **Goal** also frames the pattern as a single one-shot ("You'll hear four clicks") rather than a repeating cycle.

**Approach:** Refresh the **Goal** and **Controls** bodies in `TimingOffsetDetectionHelp.swift` to describe the loop-until-decision model and the always-active answer buttons, and add German translations via `bin/add-localization.swift`. No view-layer changes: the existing `litDotCount` indicator already cycles 1→2→3→4 in sync with each loop iteration (driven by `evaluatePlaybackPosition` from 80.1), which is sufficient feedback that the pattern is repeating.

## Boundaries & Constraints

**Always:**
- Edit the two `String(localized:)` arguments in `TimingOffsetDetectionHelp.trainingScreen` in place; titles, ordering, and the **Feedback** / **Difficulty** sections are unchanged.
- New German strings added via `bin/add-localization.swift --batch`. Informal `du` / imperative, consistent with the existing entries in this file.
- The two orphaned English keys (the old **Goal** and **Controls** bodies) are removed from `Peach/Resources/Localizable.xcstrings` in the same commit, so the catalog has no stale TOD training-screen entries.
- The **Controls** rewrite tells the learner that the loop continues by default until they answer and points to the Maximum Repetitions setting as the cap — so the training-screen Help alone explains the new behaviour and where to constrain it.

**Never:**
- Do not touch `TimingDotView`, `TimingOffsetDetectionScreen`, the session state machine, or `litDotCount` publishing. No badge, ring-progress, "∞" overlay, or additional visual indicator.
- Do not modify `TimingOffsetDetectionHelp.maxRepetitionsSettingsHelp` (owned by 80.3) or any settings-side help/strings.
- Do not add a fifth `HelpSection` — reword in place rather than appending a "Looping" section.
- Do not add a string-equality test for the help body. It would mirror the source and add no signal.

## I/O & Edge-Case Matrix

| Scenario | State | Expected Behavior |
|---|---|---|
| Help tapped on TOD training screen, English | Help sheet opens | Four sections, in order: **Goal** (repeating four-click pattern, offset on the third click of each cycle), **Controls** (Early/Late tappable any time, default loops until answer, cap in Settings), **Feedback**, **Difficulty** |
| Help tapped on TOD training screen, German | Help sheet opens | All sections render in informal German (`du`); new **Goal** and **Controls** match the new English semantically |
| `Localizable.xcstrings` after this story lands | File on disk | New English keys present with German `state: "translated"`; the two old English keys are absent |
| Settings sheet help | Settings opened | Unchanged — still shows tempo help + max-repetitions help from 80.3 |

</frozen-after-approval>

## Code Map

- `Peach/Training/TimingOffsetDetection/Help/TimingOffsetDetectionHelp.swift` — **edit**. In `trainingScreen`, replace the `body:` arguments of **Goal** and **Controls** with new wording per Intent. Titles and the other two sections are unchanged.
- `Peach/Resources/Localizable.xcstrings` — **edit**. Add the two new English keys with German translations via `bin/add-localization.swift --batch`. Remove the two superseded keys via direct JSON edit.

## Tasks & Acceptance

**Execution:**
- [x] `Peach/Training/TimingOffsetDetection/Help/TimingOffsetDetectionHelp.swift` -- replace the **Goal** and **Controls** `body:` strings.
- [x] `Peach/Resources/Localizable.xcstrings` -- add the two new English keys with German translations via `bin/add-localization.swift --batch`; remove the two orphaned old keys. Both languages must land together.
- [x] Run `bin/build.sh && bin/build.sh -p mac`, then `bin/test.sh && bin/test.sh -p mac`. Manually open the iOS research build's Compare Timing → Help in English and German.

**Acceptance Criteria:**
- Given a research build with English locale, when the user taps **Help** on the TOD training screen, then the **Controls** section says Early/Late are tappable from the start of audio, that the pattern loops until the learner answers by default, and that Maximum Repetitions in Settings caps the loop.
- Given a research build with German locale, when the user taps **Help** on the TOD training screen, then **Goal** and **Controls** render in informal German (`du`/imperative), semantically matching the new English source.
- Given `Localizable.xcstrings` after this story, when grepping for `You'll hear four clicks` or `Once the pattern finishes`, then zero matches are returned.
- Given a research build, when starting a TOD trial, then no new visual indicator is present beyond the existing cycling `litDotCount` from 80.1.

## Spec Change Log

## Verification

**Commands:**
- `bin/build.sh && bin/build.sh -p mac` — expected: clean build.
- `bin/test.sh && bin/test.sh -p mac` — expected: full suite green; no test changes expected.
- `grep -F "You'll hear four clicks" Peach/Resources/Localizable.xcstrings; grep -F "Once the pattern finishes" Peach/Resources/Localizable.xcstrings` — expected: zero matches.
- `bin/add-localization.swift --missing` — expected: the two new English keys are not listed.

## Suggested Review Order

**Help-text refresh**

- Two `HelpSection` bodies rewritten to describe the loop-until-decision model and always-active answer buttons.
  [`TimingOffsetDetectionHelp.swift:8`](../../Peach/Training/TimingOffsetDetection/Help/TimingOffsetDetectionHelp.swift#L8)

**Localization**

- New English keys + German translations (informal `du`); old keys deleted in the same commit so the catalog has no stale TOD training-screen entries.
  [`Localizable.xcstrings:3035`](../../Peach/Resources/Localizable.xcstrings#L3035)

**Test linkage refresh**

- Literal updated so the `testedNoteIndex` ⇄ ordinal-in-help-text consistency check tracks the new key.
  [`TimingOffsetDetectionSessionTests.swift:276`](../../PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionSessionTests.swift#L276)
