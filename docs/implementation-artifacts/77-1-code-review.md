# Story 77.1 — Code Review

Reviewed: 2026-04-27
Reviewers (parallel): Blind Hunter, Edge Case Hunter, Acceptance Auditor
Diff under review: commit `10a2e19` (`Implement story 77.1: Plugin-style discipline UI contributions and per-discipline compile-time activation`)
Follow-ups taken into account: stories 77.2, 77.3, 77.4 (same epic, status: ready-for-dev). Issues that those stories explicitly resolve are not flagged as 77.1 defects but are listed under "Defer" for traceability.

## Summary

`P1` HIGH `P2` HIGH `P3` MEDIUM `P4` MEDIUM `P5` MEDIUM `P6` LOW
`D1`–`D7` deferred (acknowledged follow-ups or pre-existing)
13 findings rejected as noise / verified-OK

The implementation cleanly meets ACs 1, 2, 4, 5 (file-coverage), and most of AC 7. Two material gaps remain: AC 4's spec intent ("compile-time gating leaves no dormant code path") is not actually achieved by the new tuple-list shape, and AC 7's first bullet (a behavioural test for `SettingsScreen` rendering the union of contributions) is missing. AC 3 is partially met by design — 77.2 is the deferral.

---

## Patch — fixable code issues

### P1 (HIGH) — Timing-discipline symbols leak into App Store binary

**Location:** `Peach/App/Training/DisciplineBootstrap.swift:24-32`

`candidates` unconditionally lists `{ TimingOffsetDetectionDiscipline() }` and `{ ContinuousRhythmMatchingDiscipline() }`, gated only by an `isResearchBuild: Bool` runtime flag. Even when the closure is never invoked, the closure literal's reference keeps `TimingOffsetDetectionDiscipline.self` and its transitive dependency graph (record types, CSV parsers, training screens) reachable in the App Store binary.

The pre-77.1 code wrapped the two `disciplines.append(...)` lines in `#if PEACH_RESEARCH`, physically excluding those symbols at compile time. The new shape regresses on the spec's own Dev Notes ("Why per-discipline activation is compile-time only" — points 2–3): "compile-time gating leaves no dormant code path that needs disclosure" and "users cannot stumble into half-finished features via debug menus or URL schemes."

**Fix:** Wrap the two timing rows in `#if PEACH_RESEARCH`/`#endif` directly inside the `candidates` literal, and drop the `isResearchBuild` Bool. The `(active:, factory:)` shape stays; only the `#if` guard moves.

### P2 (HIGH) — Missing `SettingsScreen` aggregation test

**Location:** `PeachTests/Settings/SettingsTests.swift` (or sibling)

AC 7 first bullet: "A test asserts `SettingsScreen` renders the union of common sections plus contributions from `registry.all` (or `registry.activeCategories`) — verified by reading the section list, not by snapshot."

The diff covers the **help** aggregation (`HelpContentViewTests.settingsHelpFollowsEmptyContribution`) and the registry's contribution invariants (`RegistryContributionsTests`), but no test reads the rendered Form sections of `SettingsScreen`. The audit test (`CategoryLiteralAuditTests`) pins source-text invariance, not behaviour.

**Fix:** Add a test that constructs a synthetic registry subset, then walks `SettingsScreen`'s `body` (or its rendered section identifiers via a testable hook) and asserts the union: common-on sections + the synthetic subset's contributions + Data section, in registration order.

### P3 (MEDIUM) — `CategoryLiteralAuditTests` has bypass paths

**Location:** `PeachTests/App/CategoryLiteralAuditTests.swift:13-21`

Forbidden substrings catch `.contains(.rhythm)`, `switch discipline.category`, and `case .rhythm:`/`.pitch:`/`.intervals:` patterns. They do not catch:
- `if discipline.category == .rhythm` (equality)
- `discipline.category.isRhythm` (computed property)
- `where discipline.category == .rhythm`
- Multi-case patterns: `case .rhythm, .intervals:` (no trailing colon after `.rhythm`)
- `switch foo.category` where the binding is named anything other than `discipline`

They also produce false-positive risk on string literals and comments (e.g. a doc comment containing `case .rhythm:`).

**Fix:** Add `.category == .rhythm`, `.category == .pitch`, `.category == .intervals` and `switch.*\.category` (regex) to the forbidden list, and consider a multiline-aware regex for the `case .X:` patterns to skip comments. Story 77.2's AC 5 already extends this list; align with 77.2's direction.

### P4 (MEDIUM) — `ProfileCardKind` not `CaseIterable`; tests hand-maintain the case list

**Location:** `Peach/Core/Training/Discipline/UIContributions.swift:21-24`, `PeachTests/Core/Training/RegistryContributionsTests.swift:87-103`

`SettingsSectionKind` and `ProfileHelpKind` derive `CaseIterable`. `ProfileCardKind` does not. Consequently the two exhaustiveness tests (`profileCardKindMappingIsExhaustive`, `everyRegisteredDisciplineHasKnownProfileCard`) hand-maintain `[.progressChart, .rhythmSpectrogram]`. A future case added to the enum would silently bypass these tests — the exact failure mode the tests exist to prevent.

**Fix:** Mark `enum ProfileCardKind: CaseIterable, Sendable, Hashable`. Replace the hardcoded literal with `ProfileCardKind.allCases` in both tests.

### P5 (MEDIUM) — AC 7 fourth bullet partially covered

**Location:** `PeachTests/Core/Training/RegistryContributionsTests.swift`

AC 7 fourth bullet: "construct a `TrainingDisciplineRegistry` from a synthesized subset of `DisciplineBootstrap.allDisciplines` and assert every aggregating helper (settings sections, help sections, profile card mapping) yields exactly the contributions for that subset and nothing more."

Coverage today:
- Settings help: covered (`settingsHelpFollowsEmptyContribution`).
- Profile help: covered (`profileHelpFollowsEmptyContribution`).
- **Settings sections:** only the all-empty case is covered (`settingsContributionsEmptyWhenNone`). No test constructs a `DisciplineBootstrap.allDisciplines` subset and asserts `registry.settingsSectionContributions` equals exactly that subset's kinds.
- **Profile-card mapping under a synthetic subset:** not covered. `everyRegisteredDisciplineHasKnownProfileCard` only checks the canonical bootstrap.

**Fix:** Add two tests — one constructs `[UnisonPitchDiscriminationDiscipline(), ContinuousRhythmMatchingDiscipline()]` and asserts `settingsSectionContributions == [.rhythmTempo, .rhythmGapPositions]`; one walks each registered discipline in a synthetic single-discipline registry and asserts `contributedProfileCard(for:)` returns the discipline's declared kind (drive via `_withSharedReplacedForTesting`).

### P6 (LOW) — No test pins the *display order* of contributed Settings sections

**Location:** `PeachTests/Settings/SettingsTests.swift` (or sibling)

`RegistryContributionsTests.settingsContributionsPreservesOrder` proves first-occurrence dedupe order is stable. It does not pin the desired display order in the UI — that Tempo appears above Gap Positions, which depends on `TimingOffsetDetectionDiscipline` being registered first in `DisciplineBootstrap`. A future re-ordering of the bootstrap list would silently swap the Settings UI.

**Fix:** Add a test that asserts `TrainingDisciplineRegistry.shared.settingsSectionContributions == [.rhythmTempo, .rhythmGapPositions]` under a Research build (or under `_withSharedReplacedForTesting` with both rhythm disciplines).

---

## Defer — acknowledged follow-ups or pre-existing issues

### D1 — AC 3 not literally satisfied (deferred to 77.2)

`HelpContent.swift` still owns the help bodies via `helpSection(for: SettingsSectionKind)` and `helpSection(for: ProfileHelpKind)` switches. AC 3 expects the help to "live with the contributor, not in a global `HelpContent.swift`." Story 77.2 explicitly deletes the per-feature help routing from `HelpContent` and moves help bodies into feature directories. Acceptable as filed for 77.1's pragmatic kinds-enum intermediate.

### D2 — `RhythmGapPositionsSettingsSection` lifecycle change (smoke-test before signing off; relocates in 77.2)

**Location:** `Peach/Settings/SettingsContributions.swift:50-58`

Pre-77.1, `@AppStorage` + `@State` + `.onAppear` decode lived at `SettingsScreen` level (one mount per screen lifetime). Post-77.1, they live inside a private struct rendered via `ForEach`. If SwiftUI re-mounts the section (lazy region scroll-out + scroll-in), `.onAppear` re-fires and re-decodes, potentially clobbering an in-flight user toggle that hasn't yet been encoded back. The completion notes mention a single manual smoke test (toggling `UnisonPitchDiscrimination` off) but not a smoke test of the gap-positions UI itself. Worth a quick smoke test on iOS before final sign-off; long-term, 77.2 relocates this section into the feature directory anyway.

### D3 — Audit test does not cover `ProfileContributions.swift` / `SettingsContributions.swift`

**Location:** `PeachTests/App/CategoryLiteralAuditTests.swift:23-37`

Both files are deleted by 77.2. Extending the audit now would be churn.

### D4 — `#filePath`-derived project root may break under remapped builds

**Location:** `PeachTests/App/CategoryLiteralAuditTests.swift:42-50`

`#filePath` returns the source path at compile time. `-debug-prefix-map`, archived builds, or alternative test layouts could break the path resolution. The doc-comment claims a precondition skip, but the implementation throws `try String(contentsOf:)`. Fix-when-it-fails; works in dev/CI today.

### D5 — Parallel-suite races on shared `TrainingDisciplineRegistry` (pre-existing)

12 test files mutate the shared registry via `_replaceSharedForTesting`. Swift Testing parallelizes by default. The new `_withSharedReplacedForTesting` introduced in 77.1 is *better* than the existing pattern because it restores the canonical registry on `defer`, but parallel tests in other suites can still observe the swapped state mid-test. This is a project-wide test-infrastructure concern, not a 77.1 regression.

### D6 — `helpSection(for:)` overload by parameter type relies on inference

**Location:** `Peach/App/HelpContent.swift:99, 164` and call sites at `:196, :207`

Two functions named `helpSection(for:)` differing only by parameter type. `.map(helpSection(for:))` works today via expected element type. Future overloads could create ambiguity. Low impact; rename only if a third overload arrives. 77.2 dissolves this anyway.

### D7 — First-launch silent default write to `UserDefaults` for `enabledGapPositions`

**Location:** `Peach/Settings/SettingsContributions.swift:50-57`

When the key has never been written, `decodeWithDefault` returns defaults; the assignment fires `.onChange`, which encodes the defaults back to `UserDefaults`. This pattern was already present in `SettingsScreen` pre-refactor — relocated, not introduced. 77.4 moves the storage entirely.

---

## Rejected (verified non-issues)

13 findings rejected as noise or verified-OK:

- **`.noData` guard removal regression** — Verified: `ProgressChartView.body` returns `EmptyView()` for `.noData`. Behaviour is preserved. The rhythm path never had the guard.
- **`EmptyView` in `VStack(spacing: 16)` adds spacing** — SwiftUI's stack layout treats `EmptyView` as no view; no spacing is allocated. Standard SwiftUI behaviour.
- **Settings Rhythm help losing Gap Positions paragraph** — The Tempo/Gap-Positions split is intentional and explicitly documented in Completion Notes (story spec line 205-206): for builds that register only `TimingOffsetDetection` (no continuous matching), Rhythm help renders without orphaned Gap Positions copy.
- **Default `profileCard = .progressChart` extension hides forgotten declarations** — Intentional per AC 2 ("with a default for pitch/intervals").
- **Tuple alignment whitespace creates noisy diffs** — Style nit.
- **Translator comments leak jargon (EWMA, stddev)** — Pre-existing in the relocated strings; not introduced.
- **Free-function namespace pollution** — Both files deleted by 77.2.
- **Non-exhaustive `helpSection(for:)` switch traps on new enum case** — Compiler warns on non-frozen enum switches.
- **`SyntheticDiscipline` reuses `PitchDiscriminationRecord.self`** — No test asserts on `recordTypes.count`; no current impact.
- **`titles.last == "Data"` doesn't pin position-invariance** — Theoretical; no current contradiction.
- Plus three minor sub-points already covered above.

---

## Summary line

**0** intent_gap, **0** bad_spec, **6** patch, **7** defer findings. **13** findings rejected as noise.

## Next steps

The 6 patch items can be addressed in a follow-up implementation pass before flipping the story to `done`. P1 and P2 are the load-bearing ones — P1 because the `#if PEACH_RESEARCH` regression contradicts the story's own stated rationale for compile-time gating, and P2 because AC 7 first bullet is literally unmet. P3-P6 are smaller polish items, all in tests.

Deferred items are noted for traceability against the 77.2-77.4 follow-ups; no action needed on them now.
