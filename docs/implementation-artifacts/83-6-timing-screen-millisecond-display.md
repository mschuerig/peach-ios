---
title: 'Story 83.6: Lead with milliseconds on the Compare Timing training screen'
type: 'bug'
created: '2026-08-08'
status: 'done'
baseline_commit: c21483ca5390844bf790059dcf4d9e93a245c0a3
context:
  - '{project-root}/docs/planning-artifacts/epics.md'
  - '{project-root}/docs/planning-artifacts/tod-discipline-future-direction.md'
  - '{project-root}/docs/implementation-artifacts/83-3-submit-next-app-store-cut.md'
  - '{project-root}/docs/implementation-artifacts/83-5-start-screen-unit-rendering.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Story 83.2 settled that Timing Offset Detection's unit is **raw milliseconds**, explicitly rejecting tempo-normalized percent-of-a-sixteenth on measurement-honesty grounds ("milliseconds are the measured quantity; percent is derived"). Story 83.5 then harmonized the shared progress surfaces — the Start card and the Profile card both render `79.5 ms`. The discipline's own training screen was never touched. It still reports:

| Surface | Renders today |
|---|---|
| `TimingStatsView` Latest line | `Latest: 20% (38 ms)` — percent leads, ms parenthetical |
| `TimingStatsView` Best line | `Best: 16% (31 ms)` — same |
| `TimingOffsetDetectionFeedbackView` pill | `20%` — **no milliseconds at all** |
| Feedback VoiceOver label | `Incorrect, 20 percent` — **percent only** |

So the one screen a user actually looks at while training reports a unit that appears nowhere else in the app and that the project decided against. It was found by looking at the running app during story 83.3's screenshot capture — the same way 83.5 was found, and again with a green test suite.

**Approach:** Display-only change on the two TOD views. Both lines of `TimingStatsView` and the feedback pill render **milliseconds only**; percent disappears from the user interface entirely, matching Start and Profile. `TimingOffsetDetectionFeedbackView` gains the `offsetMs` it currently is not given — `TimingOffsetDetectionSession.lastCompletedOffsetMs` already exists and is already passed to `TimingStatsView`, so the value needs plumbing, not computing. Number formatting goes through the locale-aware path 83.5 established rather than `String(format:)`, which is the defect 83.5 closed as PF-093 one file over.

**Why milliseconds only, not milliseconds-leading:** chosen by Michael 2026-08-08 over `38 ms (20%)`. Start and Profile show no percent; keeping it here alone would leave the training screen the only surface in the app speaking a unit the user meets nowhere else.

## Boundaries & Constraints

**Always:**
- **Display only.** No change to `TimingOffsetDetectionSession`'s tracking, to `CompletedTimingOffsetDetectionTrial`, to the record schema (`tempoBPM` + `offsetMs`), or to `AdaptiveTimingOffsetDetectionStrategy`, which uses percentage for its own adaptive logic and is not a display concern. Story 83.2's reversibility argument rests on the record schema; leave it untouched.
- **Session-best ranking stays keyed on percentage.** `evaluateAnswer` ranks with `if pct < best` and carries `sessionBestOffsetMs` as a passenger. Verified safe: `TimingOffsetDetectionTrial` takes `tempo: settings.tempo`, a snapshot fixed at `start()`, so tempo is **constant within a session** and ranking by percent is monotonically equivalent to ranking by milliseconds. Changing the ranking key is not required to make the display correct and would widen a pre-archive diff. See *Dev Notes* for the latent coupling this leaves behind.
- **Locale-aware number formatting**, per the PF-093 lesson from 83.5: a German user must see `38 ms`, not a value formatted through a `String(format:)` path that ignores locale. Reuse the existing `MetricValueFormatter` rather than introducing a second formatter.
- **Spoken form spelled out.** VoiceOver says "milliseconds", not "ms", consistent with the `unitLabel` / `unitSymbol` split 83.5 established — `unitLabel` is the spoken form, `unitSymbol` the compact rendered one.
- **Verify catalog keys directly, never by count.** `bin/add-localization.swift --missing` reports `0` vacuously for keys not yet extracted — the trap recorded in 83.5's sprint-status note. Confirm each new key is present in `Localizable.xcstrings` with a German value.
- Pre-commit gate on all four schemes, run **sequentially**, never in parallel per [[feedback_test_sh_no_parallel]].
- Story key `83-6-timing-screen-millisecond-display` flips to `in-progress` on start, `review` at hand-off, `done` after review per [[feedback_update_status_after_review]].

**Ask First:**
- **If the unused percentage properties turn out to be load-bearing somewhere this spec did not find.** The audit found `lastCompletedOffsetPercentage` and `sessionBestOffsetPercentage` read only by `TimingOffsetDetectionScreen` and the two views under change. **Default plan:** leave both properties in place; `sessionBestOffsetPercentage` stays live as the ranking key, and `lastCompletedOffsetPercentage` becomes unread by any view — raise it at code review rather than deleting it inside a pre-archive story.
- **If removing percent from the display breaks a test that encodes it as intended behavior** rather than as incidental formatting. **Default plan:** update the test to the new contract and say so explicitly in the record; do not weaken an assertion to make it pass.

**Never:**
- No change to the tempo-relative *adaptive* logic. `AdaptiveTimingOffsetDetectionStrategy` computing in percent is correct — it is choosing difficulty across tempi, which is exactly where normalization belongs. This story is about what the user reads, not how trials are chosen.
- No unit change anywhere outside the Compare Timing training screen. Start and Profile are already correct as of 83.5; do not re-touch them.
- No new discipline-config fields. 83.5 added `unitSymbol` for exactly this purpose; use it.
- No widening into PF-088/089/090, which are tracked and out of scope.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Latest line, after a trial | `lastCompletedOffsetMs = 38.0` | `Latest: 38 ms` plus trend arrow | percent must not appear |
| Best line, after a correct trial | `sessionBestOffsetMs = 31.0` | `Best: 31 ms` | percent must not appear |
| Feedback pill, correct | `isCorrect = true`, `offsetMs = 12.0` | green check + `12 ms` | — |
| Feedback pill, incorrect | `isCorrect = false`, `offsetMs = 38.0` | red x + `38 ms` | — |
| Feedback VoiceOver | same | `Incorrect, 38 milliseconds` | never "percent" |
| Latest VoiceOver | `38.0`, trend improving | `Latest result: 38 milliseconds, Improving` | — |
| Session start, no trial yet | `lastCompletedOffsetMs = nil` | both lines at `opacity 0`, `accessibilityHidden` — unchanged behavior | must not render `0 ms` visibly |
| German locale | `38.0` | `38 ms` with German catalog value for the spoken form | must not fall back to English |
| Rounding | `38.5` | one consistent, tested rounding rule, pinned in a test | half-even, matching 83.5's precedent |
| Negative / zero | `0.0` | `0 ms`, no crash, no sign artifact | — |
| Gate | four schemes | all green, `--missing` `0` with keys verified present | any red → halt |

</frozen-after-approval>

## Code Map

- `Peach/Training/TimingOffsetDetection/TimingStatsView.swift` — the main edit. `percentageText(_:ms:)` is replaced by millisecond rendering for both the Latest and Best lines; `msText` already exists and already localizes its unit via `String(localized: "ms")`, but formats the number with string interpolation of an `Int` — route the number through `MetricValueFormatter` instead. `latestAccessibilityLabel` / `bestAccessibilityLabel` switch to the spoken "milliseconds" form.
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionFeedbackView.swift` — gains `offsetMs`; `percentageText` gives way to millisecond rendering; `accessibilityLabel` drops the `percent` catalog key in favour of the spoken millisecond form. The hidden placeholder branch currently renders `Text("0%")` purely for layout — it must change too or it will size the slot against the wrong string.
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionScreen.swift` — `statsHeader` passes `offsetMs: session.lastCompletedOffsetMs` to the feedback view. One added argument; the value is already in hand two lines above.
- `Peach/Core/Profile/MetricValueFormatter.swift` — **read, not modified.** The locale-aware formatter 83.5 introduced; this story reuses it.
- `Peach/Resources/Localizable.xcstrings` — catalog keys. The spoken millisecond form should reuse the `milliseconds` / `Millisekunden` key 83.5 already added rather than introducing a parallel one; any genuinely new key needs a German value and a translator comment.
- `PeachTests/Training/TimingOffsetDetection/TimingStatsViewTests.swift` — rewritten against the millisecond contract.
- `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionFeedbackViewTests.swift` — the three existing tests all assert on `offsetPercentage`; they move to `offsetMs`.
- `docs/implementation-artifacts/sprint-status.yaml`, `docs/planning-artifacts/epics.md` — status bookkeeping.

**Read-only inputs (do not edit):** `TimingOffsetDetectionSession.swift`, `AdaptiveTimingOffsetDetectionStrategy.swift`, `CompletedTimingOffsetDetectionTrial.swift`, the discipline's `csvColumns`.

## Tasks & Acceptance

**Execution:**

- [x] **Task 1 — Red tests.** Written first and confirmed failing: `bin/build.sh -t` reported **15 compile errors**, all of them the absent `TimingOffsetFormatter` and the `offsetMs` argument label. New `TimingOffsetFormatterTests` (6 tests) plus rewritten `TimingStatsViewTests` and `TimingOffsetDetectionFeedbackViewTests`.
- [x] **Task 2 — `TimingStatsView` to milliseconds.** Both lines, both accessibility labels. `percentageText` and `msText` deleted; the view's percentage parameters (`latestValue`, `sessionBest`) removed entirely, leaving `latestMs` / `bestMs` / `trend`.
- [x] **Task 3 — `TimingOffsetDetectionFeedbackView` to milliseconds.** `offsetPercentage` → `offsetMs`, `percentageText` deleted, accessibility label rebuilt on the spoken form, hidden layout placeholder switched to the millisecond string so the slot sizes against what it will actually hold. All three `#Preview`s updated.
- [x] **Task 4 — Plumb `offsetMs` through the screen.** `statsHeader` now passes `latestMs` / `bestMs` to the stats view and `offsetMs` to the feedback view.
- [x] **Task 5 — Localization.** **No new keys were needed** — 83.5 already added `ms` (de `ms`) and `milliseconds` (de `Millisekunden`), and the four interpolated keys keep their existing `%@` shapes. `--missing` reports `0`, and all seven keys were verified **directly** in `Localizable.xcstrings` with their German values rather than trusted to the count.
- [x] **Task 6 — Gate.** Four schemes green sequentially: **2290 / 2277 / 2453 / 2440**. `archlint Peach/` exit 0, `bin/check-dependencies.sh` "All non-import dependency rules passed."
- [x] **Task 7 — Verify in the running app.** `Peach (Release)` on iPhone 17 Pro Max. Before: `Latest: 20% (38 ms)`, pill `20%`, VoiceOver "Incorrect, 20 percent". After: `Latest: 37.5 ms`, `Best: 37.5 ms`, pill `37.5 ms`, VoiceOver "Latest result: 37.5 milliseconds, Improving" and "Correct, 37.5 milliseconds". No percent on the screen. Start card still `79.5 ms` and pitch cards still `¢`, so nothing regressed.
- [x] **Task 8 — Hand off to 83.3.** `06-compare-timing` re-captured against the fixed build.

**Acceptance Criteria:**

1. **Given** a completed Compare Timing trial, **when** the training screen's Latest and Best lines are read, **then** both show a millisecond figure and neither contains a percent sign.
2. **Given** a completed trial, **when** the feedback pill is read, **then** it shows a millisecond figure; **and** its VoiceOver label announces the spoken millisecond form and never the word "percent".
3. **Given** a session with no completed trial, **when** the stats header renders, **then** both lines remain invisible and accessibility-hidden exactly as before — the change must not make a placeholder `0 ms` visible.
4. **Given** the app running in German, **when** a trial completes, **then** the rendered number is locale-formatted and the spoken unit uses the German catalog value.
5. **Given** the whole app after this change, **when** every surface that renders a timing figure is enumerated (Start card, Profile card, training stats, training feedback), **then** all four report milliseconds and none reports percent.
6. **Given** the four-scheme gate run sequentially, **then** all four are green; `bin/add-localization.swift --missing` reports `0` **and** each key involved is confirmed present in `Localizable.xcstrings` with a German value.
7. **Given** the diff, **when** reviewed, **then** it touches display code and its tests only — no session, strategy, trial, or record-schema change.

## Dev Notes

### The latent coupling this story deliberately leaves in place

`evaluateAnswer` ranks the session best by percentage and assigns `sessionBestOffsetMs` inside that branch as a passenger:

```swift
if pct < best {
    sessionBestOffsetPercentage = pct
    sessionBestOffsetMs = ms
}
```

That is correct **only because tempo is constant within a session** — `AdaptiveTimingOffsetDetectionStrategy` builds every trial with `tempo: settings.tempo`, and `settings` is a value-type snapshot taken at `start()`. Under that invariant, percent and milliseconds are related by a constant factor, so the smallest percent is the smallest millisecond value and the displayed `Best: N ms` is genuinely the session's best.

If per-trial tempo variation is ever introduced — and the profile already stratifies by `TempoRange`, so the idea is not far-fetched — this breaks silently: the screen would display a millisecond figure selected by a percentage comparison, and the "best" shown would not be the smallest. The conservative choice here is to leave the ranking alone in a story that ships immediately before a release archive, and to raise re-keying it to milliseconds at code review. Flagging rather than fixing is deliberate; it is recorded here so the next person does not have to rediscover it.

### Why this was not caught by tests, twice

83.5 and 83.6 are the same root cause at two sites. Story 83.2's decision lives in a planning document. Nothing in the codebase enforces it, so the decision was applied to whichever surfaces someone happened to open — the Start card and Profile card in 83.5, and now the training screen only because 83.3 went to photograph it. The full suite was green through both defects, and both were found by a human looking at the running app.

83.5 added registry-level guards that fail if a rhythm discipline declares a cent unit. Those guards check the *discipline's declared unit*, not what a view renders, which is why they did not catch this. Worth considering at review, without widening this story: whether an assertion can bind a rendered timing figure to `unitSymbol` the way the registry guards bind the declared one. AC 5 encodes the enumeration manually; a test would encode it durably.

### Formatting precedent to follow

83.5's second review pass fixed `RhythmProfileCardView` for exactly the defect this story must avoid: it hardcoded `ms` and formatted with `String(format:)`, so a German user saw `79.5 ms` directly below pitch cards reading `6,4`. It now takes its unit from `config` and its number from `MetricValueFormatter`. `TimingStatsView.msText` has the same shape today (`"\(rounded) " + String(localized: "ms")`) — localized unit, unlocalized number. Do not copy it forward.

### References

- `docs/planning-artifacts/tod-discipline-future-direction.md` § *Metric unit decision* — 83.2's decision and its four grounds
- `docs/implementation-artifacts/83-5-start-screen-unit-rendering.md` — the sibling fix; its Spec Change Log records the `unitLabel` / `unitSymbol` split and the vacuous-guard lesson
- `docs/implementation-artifacts/83-3-submit-next-app-store-cut.md` — the blocked story; `06-compare-timing` waits on this one

## Verification

**Commands:**

- `grep -rn "percentageText" Peach/Training/TimingOffsetDetection/` — expected: no matches in view code after the change
- `grep -rn "%%" Peach/Training/TimingOffsetDetection/` — expected: no percent formatting left in the two views
- `bin/test.sh && bin/test.sh -p mac && bin/test.sh --research && bin/test.sh --research -p mac` — expected: four green, sequential
- `bin/add-localization.swift --missing` — expected: `0`, **plus** direct confirmation of each key in `Localizable.xcstrings`
- `archlint Peach/` and `bin/check-dependencies.sh` — expected: clean

**Manual checks:**

- Run a Compare Timing trial in a `Peach (Release)` build on iPhone 17 Pro Max: Latest, Best, and the feedback pill all read milliseconds; no percent anywhere on the screen.
- VoiceOver on the feedback pill announces the spoken millisecond form.
- Switch the simulator to German and repeat: number and unit both localized.

## Spec Change Log

**2026-08-08 — Story created.** Found during story 83.3's Task 5 screenshot capture. Two decisions taken with Michael before the spec was written: (1) handle it as its own story shipping before 83.3 archives, mirroring 83.5, rather than absorbing it into 83.3 or deferring it to a `PF-###`; (2) display **milliseconds only**, rather than milliseconds-leading with percent secondary, so the training screen matches Start and Profile instead of being the only surface showing a unit the user meets nowhere else.

**2026-08-08 — Two amendments discovered at implementation time. Flagged for review rather than silently absorbed.**

1. **A fourth file had to change: `ContinuousRhythmMatchingScreen`.** The Code Map missed it because the audit grepped only `Peach/Training/TimingOffsetDetection/`. Continuous Rhythm Matching renders `Mean offset: 20% (38 ms)` by calling `TimingStatsView.percentageText` **across a feature boundary** — a coupling `bin/check-dependencies.sh` does not catch, because it only checks cross-feature references to `*Screen` types, and `TimingStatsView` is not a screen. Deleting `percentageText` therefore broke the Research configurations.

   The frozen *Never* forbids "a unit change anywhere outside the Compare Timing training screen", so CRM's **displayed output is deliberately unchanged** — still `20% (38 ms)`, byte for byte. The formatting simply moved into `ContinuousRhythmMatchingScreen.meanOffsetText`, which the screen now owns instead of borrowing from another feature's view. Net effect: the frozen constraint is honoured exactly, one cross-feature coupling is removed, and no dead percent-formatting is left behind on a view whose whole purpose just changed. CRM is `PEACH_RESEARCH`-gated and does not ship, so its unit question is genuinely out of scope; if TOD's decision should ever propagate there, that is its own story.

2. **Rendering precision changed from integer to one decimal.** The old `msText` rounded to whole milliseconds (`38 ms`); the new formatter routes the number through `MetricValueFormatter`, which is fixed at one fraction digit — so the screen now reads `37.5 ms`. This was not spelled out in the frozen block, which used `38 ms` in its examples. It is the consequence of the *Always* rule requiring `MetricValueFormatter` for locale-awareness, and it is what makes the training screen agree with the Start card (`79.5 ms`) and the Profile card (`79.5 ms ±7.1 ms`) instead of using a third precision. The I/O matrix's `38 ms` examples should be read as `38.0 ms`. Raised here because it is a visible change nobody explicitly approved.

## Senior Developer Review (AI)

**Reviewed:** 2026-08-08, workflow-backed review at **high** effort against commit `498a293d` (4 finder angles, 26 candidates, 15 independent verifiers, 5 refuted, 10 reported).

**Outcome: Changes Requested — 7 applied, 3 deferred with catalog entries.**

The review found one genuine user-facing defect the story's own acceptance criteria claimed was impossible, and it was right to. **AC 5 was written as a manual enumeration of four surfaces** — Start card, Profile card, training stats, training feedback — and the Help sheet, reachable from a button in the Compare Timing screen's own navigation bar, was not among them. It described the readout as a percentage twice. The story's Dev Notes had predicted exactly this weakness ("AC 5 encodes the enumeration manually; a test would encode it durably") and then shipped the manual version anyway.

**Applied:**

1. **Help sheet copy corrected** (the AC 5 miss). Both the *Feedback* and *Difficulty* sections now describe milliseconds. German added, the two superseded entries removed from the catalog.
2. **`TimingOffsetFormatter` now takes the unit from the caller**, and both views supply it from `TrainingDisciplineID.timingOffsetDetection.config`. The original hardcoded `String(localized: "ms")` — which violated this spec's own *Never* ("No new discipline-config fields. 83.5 added `unitSymbol` for exactly this purpose; use it"), the contract in `MetricValueFormatter`'s doc comment, and the pattern `RhythmProfileCardView` already followed. Changing the discipline's declaration now changes this screen.
3. **`lastCompletedOffsetPercentage` deleted** rather than left. The *Ask First* default was to keep it and raise it at review; review confirmed it was dead by the project's own definition and dangerous — a plausible-looking `Double?` beside `lastCompletedOffsetMs` that a future surface could bind to and reintroduce percent.
4. **Its three tests were retargeted, not deleted**, onto `lastCompletedOffsetMs` — which the audit revealed had **zero** coverage despite being the value the whole screen now renders.
5. **Self-referential tests replaced.** The new suites compared the formatter against the same call it makes internally, so dropping the unit entirely would have kept them green. They now use sentinel units (`"UNIT"` / `"SPELLED"`) and pin exact output.
6. **`ContinuousRhythmMatchingScreen.meanOffsetText` given tests.** Its only coverage died with the deleted `TimingStatsViewTests` cases, leaving the commit's load-bearing "byte-identical output" claim unguarded on a helper whose own comment says "extracted for testability".
7. **Orphaned `percent` and `0%` catalog keys removed** — translated entries no source referenced, which the gate cannot detect (`--missing` reports used-but-absent, never present-but-unused).

**Deferred, with entries filed:** PF-094 (CRM non-locale number formatting — transplanted, not written, and fixing it would break this story's frozen constraint), PF-095 (feedback-pill width at large Dynamic Type — **could not be measured**, no narrow-device simulator installed; the review's `125.0 ms` bound is corrected to ~`75.0 ms`), PF-096 (`TimingStatsView` duplicates `TrainingStatsView` — real, and the same mechanism that caused this bug, but collapsing them touches all four pitch screens and is not a pre-archive change).

**Gate after fixes:** 2297 / 2284 / 2463 / 2450 green sequentially; archlint exit 0; check-dependencies clean; new catalog keys verified present with German values **directly**, not via the `--missing` count, which again reported `0` vacuously before the keys existed.

## Dev Agent Record

### Agent Model Used

claude-opus-5[1m]

### Debug Log References

- Evidence captured from a running `Peach (Release)` build (1.1.0/2) on iPhone 17 Pro Max `6CA2827E-2CEC-4718-AF42-32593BBCA652`, en_US, with 604 seeded records. Runtime UI snapshot after one incorrect trial: `Latest: 20% (38 ms)`, feedback text node `20%`, feedback accessibility label `Incorrect, 20 percent`.

### Completion Notes List

**All eight tasks complete.** The training screen now reports milliseconds on every surface: the Latest and Best lines, the per-trial feedback pill, and all three VoiceOver labels. Percent is gone from the Compare Timing UI entirely, so all four surfaces that render a timing figure — Start card, Profile card, training stats, training feedback — agree on the unit story 83.2 settled (AC 5).

**Shape of the fix.** A new `TimingOffsetFormatter` in the discipline's own directory owns both forms: `compact` (`37.5 ms`) for rendering and `spoken` (`37.5 milliseconds`) for VoiceOver, mirroring the `unitSymbol` / `unitLabel` split 83.5 established. Both route the number through `MetricValueFormatter`, so German renders `37,5 ms` — the PF-093 defect 83.5 fixed one file over, and which `TimingStatsView.msText` still had (`"\(Int(ms.rounded())) "`, a localized unit with an unlocalized number). Both views lost their percentage parameters entirely rather than keeping them unused.

**Session untouched, as scoped.** `TimingOffsetDetectionSession`, `AdaptiveTimingOffsetDetectionStrategy`, `CompletedTimingOffsetDetectionTrial`, and the record schema are unchanged. The adaptive strategy still reasons in percent, which is correct — normalizing across tempi is exactly what difficulty selection should do.

**Two review items deliberately left open, both recorded in the Spec Change Log rather than decided unilaterally:** the CRM cross-feature fallout, and the integer → one-decimal precision change. See that section.

**`lastCompletedOffsetPercentage` is now unread by any view.** `sessionBestOffsetPercentage` remains live as the session-best ranking key. Per the spec's *Ask First*, neither was deleted inside a pre-archive story; raising the unread one is a review decision.

**Verified, not assumed:** the session-best ranking keying off percentage is safe because `TimingOffsetDetectionTrial` is built with `tempo: settings.tempo`, a `start()`-time snapshot, so tempo is constant within a session and percent-ranking and ms-ranking coincide. Recorded in *Dev Notes* as a latent coupling for the day per-trial tempo variation arrives.

### File List

- `Peach/Training/TimingOffsetDetection/TimingOffsetFormatter.swift` — added (`compact` / `spoken`, both via `MetricValueFormatter`)
- `Peach/Training/TimingOffsetDetection/TimingStatsView.swift` — modified (percentage parameters and `percentageText` / `msText` removed; both lines and both accessibility labels on milliseconds)
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionFeedbackView.swift` — modified (`offsetPercentage` → `offsetMs`; `percentageText` removed; accessibility label and hidden placeholder updated; previews updated)
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionScreen.swift` — modified (`statsHeader` passes `latestMs` / `bestMs` / `offsetMs`)
- `Peach/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingScreen.swift` — modified (owns `meanOffsetText` locally instead of calling across the feature boundary into `TimingStatsView`; **rendered output unchanged**)
- `PeachTests/Training/TimingOffsetDetection/TimingOffsetFormatterTests.swift` — added (6 tests, including the never-renders-percent guard)
- `PeachTests/Training/TimingOffsetDetection/TimingStatsViewTests.swift` — rewritten against the millisecond contract
- `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionFeedbackViewTests.swift` — rewritten against the millisecond contract
- `docs/planning-artifacts/epics.md` — modified (story 83.6 added; Epic 83 work order updated)
- `docs/implementation-artifacts/83-6-timing-screen-millisecond-display.md` — added (this file)
- `docs/implementation-artifacts/sprint-status.yaml` — modified

**Deliberately not modified:** `TimingOffsetDetectionSession.swift`, `AdaptiveTimingOffsetDetectionStrategy.swift`, `Localizable.xcstrings` (no new keys required).

## Change Log

- 2026-08-08: Story created — found during 83.3's screenshot capture, the same way 83.5 was, and with a green test suite in both cases.
- 2026-08-08: Story implemented, TDD. Red phase confirmed by 15 compile errors before any production code was written. Compare Timing's training screen moved from percent-of-a-sixteenth to milliseconds across the stats lines, the feedback pill, and all three VoiceOver labels; a new `TimingOffsetFormatter` owns the compact and spoken forms and routes both through the locale-aware `MetricValueFormatter`. Implementation surfaced a fourth affected file — `ContinuousRhythmMatchingScreen` was reaching across a feature boundary into `TimingStatsView.percentageText`, a coupling `check-dependencies.sh` misses because it only guards `*Screen` types; CRM now owns that formatting locally with its rendered output unchanged, honouring the frozen "no unit change outside the Compare Timing screen" constraint exactly. Gate green on all four schemes sequentially (2290 / 2277 / 2453 / 2440), archlint and check-dependencies clean, `--missing` 0 with all keys verified present directly in the catalog. Confirmed in a running `Peach (Release)` build. Status → `review`. Two items flagged for review rather than decided: the CRM fallout and the integer → one-decimal precision change.
- 2026-08-08: Code review (workflow-backed, high effort, 21 agents) of `498a293d`. 10 findings reported; 7 applied, 3 deferred as PF-094/095/096. The material one: **AC 5's claim that no percentage-only surface remained was false** — the Help sheet on this very screen described the readout as a percentage twice, missed because AC 5 enumerated surfaces by hand rather than by test, a weakness the story's own Dev Notes had named in advance. Also applied: the formatter now takes its unit from the discipline config instead of hardcoding `ms` (which had violated this spec's own *Never* clause); `lastCompletedOffsetPercentage` deleted and its three tests retargeted onto the untested `lastCompletedOffsetMs`; self-referential assertions replaced with sentinel-unit tests that fail if the unit is dropped; `meanOffsetText` given the coverage that died with the tests it inherited; two orphaned catalog keys removed. Gate 2297 / 2284 / 2463 / 2450 green.
