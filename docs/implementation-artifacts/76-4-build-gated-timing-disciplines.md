# Story 76.4: Build-gated timing disciplines via PEACH_RESEARCH flag

Status: ready-for-dev

## Story

As Michael preparing the v1.0 App Store release while keeping the timing disciplines available for targeted research feedback,
I want a `Research` Xcode build configuration whose `PEACH_RESEARCH` Swift compilation flag controls whether the two timing disciplines are registered in `DisciplineBootstrap`,
so that the `Release` build (and therefore the App Store binary) ships only the four pitch-and-intervals disciplines while a TestFlight build from the `Research` configuration ships all six for a small number of invited testers.

## Context

The timing disciplines (`TimingOffsetDetectionDiscipline`, `ContinuousRhythmMatchingDiscipline`) require sub-20 ms input latency to be musically useful. iOS touch input adds 50–80 ms latency on top of the audio stack, and BLE MIDI typically adds 30–50 ms with jitter — leaving only **wired USB MIDI** (USB-C direct or Lightning + Camera Connection Kit) as a reliable input path. With those constraints, the timing disciplines are not ready for an open App Store release: most users would have a broken experience.

Rather than removing the code (the implementation is mostly complete and wanted in v1.x), this story hides the timing disciplines from the `Release` build and exposes them in a separate `Research` build distributed via TestFlight to a small group of users from whom feedback is being solicited specifically about timing.

This is the user-visible behavior change. Stories 76.1, 76.2, and 76.3 prepared the seam; this story flips the switch and updates the documentation to reflect the new architecture.

## Scope Boundaries

- **In scope:** new `Research` Xcode build configuration (duplicate of `Release`), new shared `Peach (Research)` scheme, `PEACH_RESEARCH` Swift compilation flag scoped to the `Research` configuration only, `#if PEACH_RESEARCH` conditional registration of the two timing disciplines in `DisciplineBootstrap.swift`, replacement of the count-based test assertion with data-driven invariants, doc updates in `arc42.md`, `glossary.md`, `project-context.md`.
- **In scope:** verifying that the `Release` build (four disciplines) and `Research` build (six disciplines) both build and pass tests on iOS and macOS.
- **In scope:** updating the launch-time discipline-list verification (the count-based `registryContainsSixDisciplines` test from 76.2) with invariants that hold for any registered set.
- **Out of scope:** TestFlight beta-group setup or distribution of the Research build to testers. That's an operational task tracked separately under Epic 72 (or a follow-up).
- **Out of scope:** any UI work to inform users that timing disciplines exist but are unavailable. The feature is invisible in `Release`, period.
- **Out of scope:** marketing/App Store copy changes. Story 71.1 already ships "training disciplines" copy without committing to a count; verify this in Task 7.
- **Out of scope:** removing the `TrainingDisciplineID.timingOffsetDetection` and `.continuousRhythmMatching` static factories (in `App/Training/DisciplineIDs.swift` after 76.1) or the corresponding `NavigationDestination` cases (they remain in code, simply unreachable in `Release`).

## Acceptance Criteria

### AC 1: `Research` build configuration exists

**Given** the Xcode project
**When** Build Settings are inspected
**Then** a `Research` build configuration exists, duplicated from `Release`. It is selectable in the scheme editor as the **Run / Test / Profile / Analyze / Archive** configuration of a corresponding scheme (see AC 3). All other settings (optimization, symbol stripping, code signing) match `Release` exactly.

### AC 2: `PEACH_RESEARCH` Swift compilation flag is set in Research only

**Given** the project's Swift compiler flags
**When** inspected
**Then** the `Research` configuration sets `OTHER_SWIFT_FLAGS = $(inherited) -D PEACH_RESEARCH` (or equivalent — `SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) PEACH_RESEARCH` is also acceptable). Neither `Debug` nor `Release` defines `PEACH_RESEARCH`.

A grep for `PEACH_RESEARCH` in the project's `pbxproj` confirms it appears only under the `Research` configuration block.

### AC 3: A shared `Peach (Research)` scheme exists for both platforms

**Given** the Xcode schemes
**When** inspected
**Then** there is a shared scheme named `Peach (Research)` (or similar) that:

1. Uses the `Research` configuration for Run, Test, Profile, Analyze, and Archive actions.
2. Is checked in (`Shared` schemes folder, not under user-specific `xcuserdata`).
3. Builds the same iOS and macOS targets that the existing `Peach` scheme builds.

### AC 4: `bin/build.sh` and `bin/test.sh` support a `--research` flag

**Given** the project's build/test helper scripts
**When** invoked with the new `--research` flag (name TBD by dev — `--config Research` is also acceptable)
**Then** they build/test against the `Research` configuration. Without the flag they default to the existing behavior (`Debug` for `bin/test.sh`, the current default for `bin/build.sh`).

If retrofitting the scripts is more disruptive than expected, the dev MAY skip this AC and document `xcodebuild` invocation patterns for `Research` builds in the story's Completion Notes; CI configuration is then a follow-up.

### AC 5: `DisciplineBootstrap` gates timing discipline registration on `PEACH_RESEARCH`

**Given** `Peach/App/Training/DisciplineBootstrap.swift`
**When** inspected
**Then** the `allDisciplines` static is constructed such that `TimingOffsetDetectionDiscipline()` and `ContinuousRhythmMatchingDiscipline()` are included only when `PEACH_RESEARCH` is defined:

```swift
enum DisciplineBootstrap {
    static let allDisciplines: [any TrainingDiscipline] = {
        var disciplines: [any TrainingDiscipline] = [
            UnisonPitchDiscriminationDiscipline(),
            IntervalPitchDiscriminationDiscipline(),
            UnisonPitchMatchingDiscipline(),
            IntervalPitchMatchingDiscipline(),
        ]
        #if PEACH_RESEARCH
        disciplines.append(TimingOffsetDetectionDiscipline())
        disciplines.append(ContinuousRhythmMatchingDiscipline())
        #endif
        return disciplines
    }()
}
```

The exact form (closure as above, or two separate `let` arrays joined, or anything equivalent) is the dev's choice. The constraint: the `#if PEACH_RESEARCH` guard appears **in this file and nowhere else** in production code. No other file uses the flag.

### AC 6: Tests assert invariants, not counts

**Given** `PeachTests/Core/Training/TrainingDisciplineRegistryTests.swift`
**When** inspected
**Then**:

1. The `registryContainsSixDisciplines` test (currently `#expect(registry.all.count == 6)`) is **removed** or replaced with an invariant test such as:
   - `registry.all.count >= 4` (the four pitch disciplines are always present).
   - For each `category` in `registry.activeCategories`, `registry.disciplines(in: category)` is non-empty.
   - The set of registered IDs is a subset of `TrainingDisciplineID.canonicalIDs` (the App-side identifier catalog declared in 76.1).
   - No discipline ID appears twice in `registry.all`.
   - Every registered discipline's `category` is in `TrainingCategory.allCases`.
2. The `allDisciplineIDsRegistered` test (which asserts `registeredIDs == canonicalIDs`) is updated to assert the **subset** relation: `registeredIDs.isSubset(of: canonicalIDs)`. Equality is no longer guaranteed across configurations.
3. The `subscriptReturnsCorrectDiscipline` test iterates `registry.all.map(\.id)` instead of `TrainingDisciplineID.canonicalIDs`. (The current iteration would crash in `Release` for unregistered IDs.)
4. New parameterized tests use Swift Testing's `@Test(arguments:)` to drive assertions over `registry.all` (one per discipline) rather than enumerating cases by hand. See Dev Notes for examples.
5. The test file contains no `#if PEACH_RESEARCH` guards. Tests assert properties true in any registered set.

### AC 7: App Store copy is verified count-free

**Given** `docs/planning-artifacts/marketing-copy/` (or wherever 71.1 / 71.2 stored their drafts), `HelpContent.swift`, and `Localizable.xcstrings`
**When** searched for "six disciplines", "6 disciplines", "six training disciplines", and similar count phrasings (English and German)
**Then**:

1. Any user-facing string that asserts a count is rewritten to either (a) compute the count at runtime from `registry.all.count`, or (b) avoid the count entirely (e.g., "training disciplines across pitch, intervals, and rhythm" — though see AC 8 for how to handle the rhythm reference).
2. Strings that name the categories ("pitch, intervals, and rhythm") are rewritten to avoid naming the rhythm category, OR are replaced with a list derived from `registry.activeCategories` localized titles. Hardcoding "pitch, intervals, and rhythm" in `Release` would lie about what's available.
3. App Store description and review notes (story 71.1 / 71.2 outputs) are checked; if they assert "six" or list rhythm, file follow-up edits as part of this story or note them in Completion Notes for the App Store metadata update before submission.

### AC 8: Active docs reflect the new architecture

**Given** `docs/arc42.md`, `docs/planning-artifacts/glossary.md`, `docs/project-context.md`
**When** inspected
**Then**:

1. **`arc42.md`** — the section describing the discipline registry pattern (search for "TrainingDisciplineRegistry") explains:
   - The registry is in `Core/Training/Discipline/` and defines mechanism only.
   - Concrete registration lives in `App/Training/DisciplineBootstrap.swift`.
   - The set of registered disciplines is build-configuration-dependent: `Release` registers four (pitch, intervals); `Research` additionally registers two timing disciplines gated behind `PEACH_RESEARCH`.
   - The reason for the gate (input-latency limitations on touch and BLE MIDI; timing disciplines require wired MIDI to be musically useful and are released only to research participants).
   - Add a brief note that `TrainingCategory` partitions disciplines for grouped display, and that empty categories vanish from UI surfaces automatically.
2. **`glossary.md`** — entries for `TrainingDiscipline`, `TrainingDisciplineID`, `TrainingDisciplineConfig`, and `TrainingDisciplineRegistry` are updated to reference: the slug-wrapping struct in Core with named factories in `App/Training/DisciplineIDs.swift` (per 76.1), the App-layer bootstrap, and the build-flag gate. The discipline count reference (currently "Six instances" per story 71.5 cleanup) is rewritten to "Four to six instances depending on build configuration" or similar.
3. **`project-context.md`** — line referring to "Six training disciplines" (per story 71.5) is rewritten to "Four to six training disciplines depending on build configuration" with a brief note on the `Release` vs `Research` distinction. The implementation rules section (if any) gains notes: "When adding a new discipline, declare its `TrainingDisciplineID` static in `App/Training/DisciplineIDs.swift` and register it in `App/Training/DisciplineBootstrap.swift`, not in `Core/`."

Bulk-edit scope is the listed files only. Historical artifacts (completed story files, code-review docs, retrospectives) are not modified.

### AC 9: Release build registers exactly four disciplines

**Given** a `Release` build of the app on iOS or macOS
**When** launched
**Then**:

1. `TrainingDisciplineRegistry.shared.all.count == 4`.
2. The four registered disciplines are: `unisonPitchDiscrimination`, `intervalPitchDiscrimination`, `unisonPitchMatching`, `intervalPitchMatching`.
3. `registry.activeCategories == [.pitch, .intervals]`.
4. StartScreen shows two sections (Pitch, Intervals), each with two cards. No Rhythm section.
5. PeachCommands Training menu shows Pitch and Intervals sections only. No Rhythm section.
6. PeachCommands Help menu shows about + four discipline-help buttons. No "Rhythm Compare Help" or "Fill the Gap Help".
7. Profile screen shows zero or more cards corresponding to registered disciplines that have data. No `RhythmProfileCardView` instances.
8. Info screen / About-Peach help shows discipline descriptions for the four registered disciplines only. No mention of "Compare Timing" or "Fill the Gap".
9. Settings screen does not display rhythm-specific controls (Tempo, Gap Positions) — or, if those controls are still rendered, they have no observable effect since no rhythm discipline is registered. Acceptable either way; document the chosen behavior in Completion Notes.

### AC 10: Research build registers all six disciplines

**Given** a `Research` build of the app on iOS or macOS
**When** launched
**Then** behavior is identical to the pre-76.4 app: six disciplines, three categories, all UI surfaces show all disciplines, all settings work.

### AC 11: Both platforms green in both configurations

**Given** the full test suite
**When** run for both build configurations on both platforms
**Then** all tests pass with zero regressions:

- `bin/test.sh` (Debug, iOS) — green
- `bin/test.sh -p mac` (Debug, macOS) — green
- `bin/test.sh --research` (Research, iOS) — green
- `bin/test.sh --research -p mac` (Research, macOS) — green
- `bin/build.sh` and `bin/build.sh -p mac` — zero new warnings in both `Debug` and `Release` builds (pre-existing AppIntents metadata warning on macOS is acceptable, as in story 71.5).
- `bin/build.sh --research` and `bin/build.sh --research -p mac` — zero new warnings.

If the script changes from AC 4 are deferred, document the equivalent `xcodebuild -configuration Research ...` invocation used to verify.

## Tasks / Subtasks

- [ ] Task 1: Add `Research` build configuration (AC: 1)
  - [ ] 1.1 In Xcode project settings, duplicate `Release` to a new `Research` configuration
  - [ ] 1.2 Verify all build settings (codesigning, optimization, etc.) match `Release`
- [ ] Task 2: Add `PEACH_RESEARCH` Swift flag (AC: 2)
  - [ ] 2.1 Set `OTHER_SWIFT_FLAGS = $(inherited) -D PEACH_RESEARCH` (or `SWIFT_ACTIVE_COMPILATION_CONDITIONS`) on `Research` only
  - [ ] 2.2 Confirm `Debug` and `Release` do not define the flag
- [ ] Task 3: Add shared `Peach (Research)` scheme (AC: 3)
  - [ ] 3.1 Duplicate the existing `Peach` scheme
  - [ ] 3.2 Set Run/Test/Profile/Analyze/Archive to use `Research` configuration
  - [ ] 3.3 Mark scheme as Shared
  - [ ] 3.4 Commit the scheme files in `Peach.xcodeproj/xcshareddata/xcschemes/`
- [ ] Task 4: Add `--research` flag to build/test scripts (AC: 4)
  - [ ] 4.1 Read existing `bin/build.sh` and `bin/test.sh` flags
  - [ ] 4.2 Add `--research` (or `--config <name>`) flag that switches the `-configuration` xcodebuild argument
  - [ ] 4.3 Update each script's help text
  - [ ] 4.4 If retrofitting is non-trivial, defer per AC 4 fallback and document raw `xcodebuild` invocation
- [ ] Task 5: Gate registration in `DisciplineBootstrap` (AC: 5)
  - [ ] 5.1 Wrap timing-discipline registrations in `#if PEACH_RESEARCH`
  - [ ] 5.2 Confirm no other source file uses `PEACH_RESEARCH`
  - [ ] 5.3 Audit `TrainingDisciplineRegistry.subscript(_ id:)` in `Peach/Core/Training/Discipline/TrainingDisciplineRegistry.swift:50` (`byID[id]!`). Once registration is build-conditional, looking up an unregistered ID's `.config` or `.statisticsKeys` traps. Decide between (a) keeping the force-unwrap as an intentional invariant guard with a `precondition` carrying the unregistered slug for diagnostics, or (b) returning the entry as optional and migrating the two callers (`TrainingDisciplineID.config`, `TrainingDisciplineID.statisticsKeys`). Document the decision in Completion Notes.
- [ ] Task 6: Update tests (AC: 6)
  - [ ] 6.1 Remove or replace `registryContainsSixDisciplines` with subset / invariant assertions
  - [ ] 6.2 Replace `TrainingDisciplineID.canonicalIDs == registeredIDs` with `registeredIDs.isSubset(of: canonicalIDs)`
  - [ ] 6.3 Update `subscriptReturnsCorrectDiscipline` to iterate `registry.all`
  - [ ] 6.4 Add parameterized tests using `@Test(arguments:)` for any new invariants
  - [ ] 6.5 Run `bin/test.sh` in both configurations
- [ ] Task 7: Verify and update App Store copy and in-app strings for count-references (AC: 7)
  - [ ] 7.1 `grep -rn "six disciplines\|six training\|6 disciplines\|6 training" docs/ Peach/Resources/Localizable.xcstrings`
  - [ ] 7.2 For each hit, decide: rewrite count-free, compute at runtime, or list follow-up
  - [ ] 7.3 Apply rewrites; for App Store metadata draft files (Stories 71.1 / 71.2), apply changes there; if those stories already shipped to App Store Connect, document the necessary update in Completion Notes
- [ ] Task 8: Update active docs (AC: 8)
  - [ ] 8.1 `arc42.md` registry-pattern section
  - [ ] 8.2 `glossary.md` registry/config/discipline entries
  - [ ] 8.3 `project-context.md` discipline-count reference
- [ ] Task 9: Verify Release build behavior (AC: 9)
  - [ ] 9.1 Build and launch `Release` (iOS Simulator and macOS)
  - [ ] 9.2 Walk through StartScreen, training menus, profile, settings, help — verify timing disciplines are nowhere
  - [ ] 9.3 Run all four registered disciplines end-to-end
- [ ] Task 10: Verify Research build behavior (AC: 10)
  - [ ] 10.1 Build and launch `Research` (iOS Simulator and macOS)
  - [ ] 10.2 Verify all six disciplines visible and functional
- [ ] Task 11: Build & test all four (config × platform) combinations (AC: 11)
  - [ ] 11.1 `bin/build.sh && bin/build.sh -p mac` — zero new warnings
  - [ ] 11.2 `bin/build.sh --research && bin/build.sh --research -p mac` — zero new warnings
  - [ ] 11.3 `bin/test.sh && bin/test.sh -p mac` — green
  - [ ] 11.4 `bin/test.sh --research && bin/test.sh --research -p mac` — green

## Dev Notes

### Why a separate build configuration, not a runtime flag

A `UserDefaults`-backed runtime flag (toggleable via custom URL scheme or hidden Settings entry) was considered and rejected:

- **App Review risk** — Apple's Guideline 2.3.1 prohibits hidden, dormant, undocumented functionality. A runtime-toggleable feature in the App Store binary would require disclosure in App Review notes, and the disclosed mechanism is itself reviewable.
- **Support burden** — accidental discovery (always happens) creates user confusion about a feature that's intentionally not ready for them.
- **Recruitment shape** — testers are explicitly invited; TestFlight is Apple's intended channel for "this build for these people" and has no review-notes implication.
- **Compile-time gating** is also more honest: the `Release` binary genuinely does not contain the timing-discipline code path's `*Discipline()` instantiation; users can't stumble into broken behavior.

The `Research` build is distributed via TestFlight to a small invited group (operational follow-up; tracked separately).

### Why the implementation code (TimingOffsetDetectionDiscipline, etc.) stays compiled in

The user explicitly stated: "I don't want to remove the code and help texts, just make it inaccessible/invisible." The `*Discipline` types and their associated screens, sessions, and help content remain in the codebase and compile in `Release`. They are simply not constructed and not registered in `DisciplineBootstrap`'s `Release` build, so their UI surface is never reached. Help text per story 76.2 is generated from `registry.all`, so absent disciplines naturally produce no help paragraphs.

This matches the user's intent and minimizes the diff. When the timing disciplines are ready to ship publicly, the change is one line in `DisciplineBootstrap.swift`.

### Why the implementation code (`TimingOffsetDetectionDiscipline`, etc.) reference paths via 76.2

After story 76.2 the only `*Discipline` constructors live in `App/Training/DisciplineBootstrap.swift`, so this story's `#if PEACH_RESEARCH` guard sits in exactly one file. The `TrainingDisciplineID.timingOffsetDetection` and `.continuousRhythmMatching` static factories declared in `App/Training/DisciplineIDs.swift` (per 76.1) remain unguarded — they exist as identifier values regardless of build, and `NavigationDestination` cases referencing them remain valid Swift. They simply have no registered discipline behind them in `Release`.

### Why the count-based test must go

`#expect(registry.all.count == 6)` would fail in `Release`. We could `#if PEACH_RESEARCH` it, but then the test set diverges per build configuration — exactly the "two test plans" anti-pattern the user explicitly rejected. The right substitute is an invariant: every category that's active is non-empty, every registered ID is in `TrainingDisciplineID.canonicalIDs`, no duplicates. These hold in any registered set without enumeration.

### Example data-driven invariant test

```swift
@Test("every registered discipline's ID is in the canonical catalog",
      arguments: TrainingDisciplineRegistry.shared.all)
func registeredIDInCatalog(_ discipline: any TrainingDiscipline) {
    #expect(TrainingDisciplineID.canonicalIDs.contains(discipline.id))
}

@Test("active categories are non-empty",
      arguments: TrainingDisciplineRegistry.shared.activeCategories)
func activeCategoryNonEmpty(_ category: TrainingCategory) {
    #expect(!TrainingDisciplineRegistry.shared.disciplines(in: category).isEmpty)
}
```

The argument set is derived from the registry, so the test cardinality scales with the registered set automatically.

### TestFlight follow-up

Distributing the `Research` build to invited testers is operational and out of scope for this story. After this story, the dev/user can:

1. Archive `Peach (Research)` scheme.
2. Upload to App Store Connect (separate build from the `Release` archive — Apple holds them in the same app record; TestFlight groups choose which build they receive).
3. Create a TestFlight Internal or External group named e.g. "Timing Research" and invite testers.

This may be tracked as a new story under Epic 72 (TestFlight Beta) or as a one-off operational task — coordinate with the user before adding planning scope.

### What about the "Compare Timing" / "Fill the Gap" rhythm-related strings in Settings?

`SettingsScreen` has Tempo and Gap Positions controls that exist primarily for rhythm disciplines. In `Release`:

- Option A: leave the controls visible and inert (they still write to `UserSettings`, but no session reads from them).
- Option B: hide the controls when no rhythm discipline is registered (requires another `registry`-driven check in the view).

Option A is simpler and acceptable for this story. Document the choice in Completion Notes. If A causes user confusion, file a follow-up; this is a hobby-project release with limited test users so the cost is low.

### References

- `MEMORY.md → feedback_design_by_contract_and_separation.md` — build flag belongs to App, not Core
- `MEMORY.md → feedback_disciplines_not_modes.md` — terminology in any new strings
- Party-mode discussion (this story's parent conversation) — full design rationale
- Story 76.1 — relocated `TrainingDisciplineID`'s named instances and `canonicalIDs` to `App/Training/DisciplineIDs.swift`
- Story 76.2 — relocated bootstrap that this story conditionalizes
- Story 76.3 — data-driven UI iteration that this story relies on for empty-category invisibility
- Apple App Review Guideline 2.3.1 — hidden functionality (motivating the build-flag-not-runtime-toggle decision)

## Change Log

- 2026-04-25: Story drafted as Story 76.4 of Epic 76. Renumbered from original 76.3 when a new 76.1 (relocate `TrainingDisciplineID` to App) was inserted. Status → ready-for-dev. Depends on Stories 76.1, 76.2, and 76.3.
