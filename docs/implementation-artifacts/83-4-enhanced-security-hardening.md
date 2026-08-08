---
title: 'Story 83.4: Enable Enhanced Security hardening before the release archive'
type: 'chore'
created: '2026-08-08'
status: 'done'
baseline_commit: cb5eb4f364a4c555c384b29ab610f59507a35eb5
context:
  - '{project-root}/docs/planning-artifacts/epics.md'
  - '{project-root}/docs/project-context.md'
  - '{project-root}/docs/implementation-artifacts/83-3-submit-next-app-store-cut.md'
  - '{project-root}/.claude/skills/audit-xcode-security-settings/references/enhanced-security.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Peach has **no `.entitlements` file at all**. `ENABLE_ENHANCED_SECURITY` is absent from all eight build configurations, so the shipping binary carries none of Apple's current runtime memory-safety protections — hardened heap, read-only dyld state, platform restrictions. This is not a regression: it has been true since the project was created, and 1.0.0 shipped that way. It surfaced only because story 83.3 ran `/audit-xcode-security-settings` for the first time in the project's history (verified: no `xcode-security-settings.md` decision document exists, and the 2026-03-28 App Store audit contains zero mentions of sandbox, entitlements, or hardening).

**Approach:** Adopt the Enhanced Security capability on the app target — project-level build setting plus the `com.apple.security.hardened-process` entitlement family — and create the entitlements file the project has never had. Verify with the full four-scheme gate, a validating `Peach (Release)` archive, and a real listening test, because the runtime protections change allocator and dyld behaviour underneath a real-time audio engine and CoreMIDI.

**Why now, not later:** there is no release schedule ([[feedback_no_release_schedule]]). The only argument for deferring was proximity to the 83.3 archive, which is not an argument. Doing it now means 83.3 ships a hardened binary instead of shipping unhardened and repeating the whole submission later.

**Why this is separate from 83.3:** 83.3's frozen block scopes that story to a version bump and nothing else, so the binary change gets its own diff and its own review rather than riding along with the submission paperwork. Michael chose this split explicitly on 2026-08-08.

## Boundaries & Constraints

**Always:**
- **`ENABLE_POINTER_AUTHENTICATION = NO`.** Enhanced Security enables it by default; this story explicitly turns it off. Apple's documentation confirms the two are separable — *"If you need to turn off pointer authentication for your target… set the `ENABLE_POINTER_AUTHENTICATION` build setting to `No`"* — and confirms iOS is a supported Enhanced Security platform. Whether arm64e binaries are accepted for third-party App Store distribution **could not be verified**: Apple's Enhanced Security and pointer-authentication pages say nothing about submission, and the one search result claiming *"arm64e is not supported for third-party user space code"* is an uncorroborated snippet. Shipping a release on an unverified premise is not acceptable, so arm64e is out of scope here and becomes its own decision.
- Entitlements to add, exactly (per `references/enhanced-security.md` Part B):
  - `com.apple.security.hardened-process` = `true`
  - `com.apple.security.hardened-process.enhanced-security-version-string` = `"2"`
  - `com.apple.security.hardened-process.hardened-heap`
  - `com.apple.security.hardened-process.dyld-ro`
  - `com.apple.security.hardened-process.platform-restrictions-string` = `"2"`
- `ENABLE_ENHANCED_SECURITY` is set at **project level** (the capability requires it there). The project has no `.xcconfig` files, so it goes in `project.pbxproj`.
- Audio and MIDI verification is **required before this story closes**, per [[feedback_verify_audio_features]]: Michael runs a listening test (Grand Piano + Sine Wave at `noteDuration = 1 s`) plus a MIDI-input check. Tests-green is necessary and not sufficient — hardened-heap and dyld-ro change allocator and dynamic-linker behaviour underneath `AVAudioEngine`'s render thread, which is exactly where a regression would be silent in unit tests.
- Pre-commit gate per [[feedback_test_sh_no_parallel]] (sequential, never parallel): `bin/test.sh && bin/test.sh -p mac && bin/test.sh --research && bin/test.sh --research -p mac` — all four green.
- A `Peach (Release)` archive must **validate** (Xcode Organizer → Validate App) before this story closes. Rationale: Mac App Store submissions have reportedly been rejected under Guideline 2.4.5(i) for *"entitlements with invalid values"* when Enhanced Security is misconfigured. That report is unverified, but validating locally is cheap and 83.3's archive depends on this story being correct.
- A decision document is written per the audit skill's `references/decision-document.md` convention — the project has never had one, and its absence is why this gap went unobserved for so long.
- Story key `83-4-enhanced-security-hardening` flips `in-progress` → `review` → `done` per [[feedback_update_status_after_review]].

**Ask First:**
- **If the four-scheme gate or the listening test shows any regression**, stop and report rather than tuning sub-options to make it pass. **Default plan:** report which protection is implicated and let Michael decide between disabling that sub-option and abandoning the capability.
- **If `Validate App` rejects the archive over entitlements**, stop and report the exact message. **Default plan:** do not guess at key combinations; the message names the offending key.

**Never:**
- **No macOS App Sandbox keys in this story.** `com.apple.security.app-sandbox` and Hardened Runtime are Guideline 2.4.5(i) requirements for *Mac App Store* distribution only — iOS apps are sandboxed by the OS unconditionally, with no entitlement to enable. That work is already tracked in Epic 74 (`74-1-submit-to-mac-app-store.md:23-24`, both unchecked). This story creates the entitlements file those keys will later live in; it does not add them.
- **No hardware memory tagging.** `com.apple.security.hardened-process.checked-allocations` is default-OFF, needs A19/M5-class silicon, and the audit skill explicitly does not auto-enable it.
- No arm64e, and therefore no `WorkspaceSettings.xcsettings` changes. (When pointer authentication is eventually considered, it will need `iOSPackagesShouldBuildARM64e` / `macOSPackagesShouldBuildARM64e` there, because SPM packages are not built arm64e automatically and Peach depends on MIDIKit and swift-async-algorithms. Recorded here so the next story does not rediscover it.)
- No unrelated build-setting changes. The audit found no security-catalog setting explicitly set to `NO`, and `ENABLE_USER_SCRIPT_SANDBOXING`, `DEAD_CODE_STRIPPING`, the three `CLANG_ANALYZER_*` and six `GCC_WARN_*` settings are already correct. Leave them alone.
- No source-code changes. If a protection surfaces a genuine latent bug, that is a finding to report, not to patch inside this story.
- No version-number changes. 83.3 owns `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Entitlements file creation | no file exists today | `Peach/Resources/Peach.entitlements` exists, valid plist, contains exactly the five keys above | `plutil -lint` fails → fix before proceeding |
| Wiring | app target, 4 configs | `CODE_SIGN_ENTITLEMENTS = Peach/Resources/Peach.entitlements` in all four app-target configurations | present in fewer than 4 → build signs inconsistently per configuration |
| Test target | unit-test bundle | **no** entitlements and **no** *target-level* `ENABLE_ENHANCED_SECURITY` override — `com.apple.product-type.bundle.unit-test` is not a supported product type. The project-level setting inherits to every target by definition; that is unavoidable given the project-level mandate above, and inert here (no entitlements → runtime protections inert; pure Swift → compiler half inert) | entitlements, or a *target-level* override, applied to the test target → out of spec, revert |
| Project build setting | `project.pbxproj` | `ENABLE_ENHANCED_SECURITY = YES` in all **four** project-level configurations (Debug, Release, Debug (Research), Release (Research)) | set at target level instead → capability may not provision; set in fewer than 4 → inconsistent per scheme |
| Pointer authentication | after the cascade | resolves to `NO` on the app target | resolves to `YES` → arm64e build, out of scope, fix the override |
| Four-scheme gate | post-change | all four green, sequentially | any red → halt per *Ask First* |
| Listening test | Grand Piano + Sine Wave, `noteDuration = 1 s` | no dropouts, clicks, stuck notes, or changed latency vs. the pre-change build | any audible regression → halt, report which protection is implicated |
| MIDI check | connected controller or IAC bus | pitch-bend input still drives Match disciplines; CRM tap input still registers | input dead → halt, report |
| Archive validation | `Peach (Release)` archive | Validate App passes, no entitlement complaints | rejection → halt, report the exact message per *Ask First* |
| Decision document | after the story | `docs/reports/xcode-security-settings.md` records every setting, its status, and rationale — including the deliberate `ENABLE_POINTER_AUTHENTICATION = NO` and the deferred MTE and App Sandbox items | absent → the next audit rediscovers everything from scratch |

</frozen-after-approval>

## Code Map

- `Peach/Resources/Peach.entitlements` — **new.** The five `com.apple.security.hardened-process*` keys. Placed alongside `PrivacyInfo.xcprivacy`, which is the established home for target-level resource/metadata files.
- `Peach.xcodeproj/project.pbxproj` —
  - project level: `ENABLE_ENHANCED_SECURITY = YES`
  - app target, all 4 configurations: `CODE_SIGN_ENTITLEMENTS = Peach/Resources/Peach.entitlements`, `ENABLE_POINTER_AUTHENTICATION = NO`
  - test target: untouched
- `docs/reports/xcode-security-settings.md` — **new.** Decision document per the audit skill's convention. Sits with the other audit reports (`appstore-review-2026-03-28.md`, `claude-code-analysis-2026-03-02.md`).
- `docs/implementation-artifacts/sprint-status.yaml` — `83-4-enhanced-security-hardening` status transitions.

**Read-only inputs:** `.claude/skills/audit-xcode-security-settings/references/enhanced-security.md` (key list, Part A/B split, supported product types), `references/decision-document.md` (document format).

## Tasks & Acceptance

**Execution:**

- [x] **Task 1 — Create the entitlements file.** Write `Peach/Resources/Peach.entitlements` with exactly the five keys. Verify with `plutil -lint`.
- [x] **Task 2 — Wire and enable.** `ENABLE_ENHANCED_SECURITY = YES` at project level; `CODE_SIGN_ENTITLEMENTS` and `ENABLE_POINTER_AUTHENTICATION = NO` on all four app-target configurations. Leave the test target alone.
- [x] **Task 3 — Verify resolved settings.** Confirm via resolved build settings that `ENABLE_ENHANCED_SECURITY` is `YES` and `ENABLE_POINTER_AUTHENTICATION` is `NO` for the app target, and that neither is set on the test target.
- [x] **Task 4 — Build both platforms.** `bin/build.sh && bin/build.sh -p mac`. Record any new warnings — Enhanced Security implies `GCC_WARN_SHADOW`, `CLANG_WARN_EMPTY_BODY`, and `ENABLE_SECURITY_COMPILER_WARNINGS`, which can surface diagnostics that were previously off. New warnings are a **finding to report**, not something to silence.
- [x] **Task 5 — Four-scheme gate.** Sequentially, never in parallel. All four green. Record counts.
- [x] **Task 6 — Archive validation.** Archive `Peach (Release)` and run Validate App. Must pass with no entitlement complaints. — **passed 2026-08-08** (Michael). No entitlement complaint, so the `hardened-process` key set is accepted by Apple's validator; the 2.4.5(i) "entitlements with invalid values" risk the spec flagged did not materialise. Satisfies AC 5.
- [x] **Task 7 — Audio and MIDI verification (Michael).** Listening test: Grand Piano and Sine Wave at `noteDuration = 1 s`, across a pitch discipline and Compare Timing. Confirm no dropouts, clicks, stuck notes, or latency change. MIDI: confirm pitch-bend input still drives a Match discipline. — **passed 2026-08-08** (Michael), **on a physical iOS device**. Satisfies AC 6. The platform matters and was recorded during code review: the iOS Simulator does not enforce `com.apple.security.hardened-process`, and the four-scheme gate's iOS halves are Simulator-only, so a Simulator run would have exercised none of the runtime protections. Device hardware is what makes this check evidence. The **macOS** runtime path remains unverified — see the caveat in `docs/reports/xcode-security-settings.md`.
- [x] **Task 8 — Decision document.** Write `docs/reports/xcode-security-settings.md` per the skill's convention: every audited setting, its status, and rationale — including the deliberate pointer-authentication opt-out with its unresolved-arm64e reasoning, MTE deferred, and App Sandbox assigned to Epic 74.
- [x] **Task 9 — Close out.** `83-4` → `review` → `done`. Note in `sprint-status.yaml` that 83.3's archive precondition is now satisfied. — **done 2026-08-08** after code review of `a0afbe7d`. Recorded honestly: the `in-progress` leg of this sequence was never represented in git (see the File List correction above); the key first appeared at `review` in commit `1875ea30`, and this review moves it to `done`.

**Acceptance Criteria:**

1. **Given** the app target's resolved build settings, **when** inspected, **then** `ENABLE_ENHANCED_SECURITY = YES` and `ENABLE_POINTER_AUTHENTICATION = NO`; **and** the built binary is arm64 only, not arm64e.
2. **Given** `Peach/Resources/Peach.entitlements`, **when** linted and read, **then** it is a valid plist containing exactly the five `hardened-process` keys, with `enhanced-security-version-string` and `platform-restrictions-string` both `"2"`, and **no** `checked-allocations` and **no** `app-sandbox` key.
3. **Given** the test target, **when** its settings are inspected, **then** it has no entitlements file and no *target-level* `ENABLE_ENHANCED_SECURITY` override — its product type is unsupported for the capability. It inherits the project-level `YES` like every target, which the project-level mandate above makes unavoidable and which is inert without entitlements. *(Reworded 2026-08-08 during code review of `a0afbe7d`, with Michael's approval to amend the frozen block: the original wording — "no `ENABLE_ENHANCED_SECURITY`" — could not hold simultaneously with the Always-block requirement that the setting live at project level.)*
4. **Given** the four-scheme gate run sequentially, **when** the results are read, **then** all four are green.
5. **Given** a `Peach (Release)` archive, **when** Validate App runs, **then** it passes with no entitlement-related complaint.
6. **Given** the hardened build **on a physical iOS device** (the Simulator does not enforce the `hardened-process` entitlement, so it cannot satisfy this AC), **when** Michael runs the listening test on Grand Piano and Sine Wave at `noteDuration = 1 s`, **then** playback is indistinguishable from the pre-change build — no dropouts, clicks, stuck notes, or added latency — **and** MIDI pitch-bend input still drives a Match discipline.
7. **Given** `docs/reports/xcode-security-settings.md`, **when** read by a later audit, **then** it explains why pointer authentication is off, why MTE is off, and where App Sandbox lives — so none of those get rediscovered as fresh findings.
8. **Given** the full diff, **when** reviewed, **then** it contains no source-code change, no version-number change, and no App Sandbox key.

### Review Findings

*From `bmad-code-review` on commit `a0afbe7d` (2026-08-08). Three layers: Blind Hunter, Edge Case Hunter, Acceptance Auditor. Independently re-verified during triage: `plutil -lint` OK; setting counts 4/4/4; all twelve `XCBuildConfiguration` blocks classified (4 project / 4 app / 4 test) with the test target carrying none of the three keys at target level; `.entitlements` **not** leaked into any built bundle despite the synchronized root group; `lipo -archs` on the device build = `arm64`; all five `hardened-process` keys embedded in the signed binary. Eight findings dismissed — see the note at the end.*

- [x] [Review][Decision] **AC 3 cannot hold together with the project-level mandate — and the record's evidence is of a different kind than the AC asks for** — The *Always* block requires `ENABLE_ENHANCED_SECURITY` at **project** level, which by Xcode inheritance resolves to `YES` on *every* target, including `PeachTests` (the four test-target blocks carry no override). AC 3 (spec:102) and I/O-matrix row 3 (spec:61) demand the test target have "**no** `ENABLE_ENHANCED_SECURITY`" and call the alternative "out of spec, revert". Both cannot be true. Compounding it, Task 3 (spec:90) promises confirmation "**via resolved build settings**", but the Debug Log (spec:182) records that the test-target resolved check failed and "was discarded as meaningless"; the claim was then satisfied at spec:189 by a pbxproj text search, and `docs/reports/xcode-security-settings.md:113` repeats it as "Test target confirmed free of all three settings". Practical impact is nil — the test bundle has no entitlements, so the runtime protections are inert, and the compiler half is inert in pure Swift — but the AC is formally unmet and the frozen block is human-owned. **Needs:** either reword AC 3 + matrix row 3 to "no *target-level* override and no entitlements", or add explicit `ENABLE_ENHANCED_SECURITY = NO` on the four test-target configs to make AC 3 literally true. — **Resolved 2026-08-08:** Michael approved amending the frozen block and chose the rewording. AC 3, I/O-matrix row 3, the Task 2 completion note and `xcode-security-settings.md` all amended to distinguish target-level override from inherited value. No build-configuration change, so the four-scheme gate stands.
- [x] [Review][Decision] **AC 6's listening test has no recorded platform, and that is the variable that decides whether it proved anything** — `com.apple.security.hardened-process` is not enforced by the iOS Simulator; the four-scheme gate's iOS halves are Simulator-only (the sole iOS test bundle in DerivedData is `Debug-iphonesimulator/…`). Task 7 (spec:94), AC 6 (spec:105) and the decision document all record "passed 2026-08-08" with instrument, note duration and discipline, but never a device, platform or configuration. This is the one check the spec argues nothing else can replace (spec:37, spec:123) — archive validation tests entitlement *shape*, not runtime effect — and story 83.3 ships on it. **Needs:** Michael to state what the listening test actually ran on, recorded into Task 7 and AC 6; if it was the Simulator, the check has no evidential value and wants a device re-run. — **Resolved 2026-08-08:** it ran on a **physical iOS device**, so AC 6 holds and the runtime protections were genuinely exercised. Recorded into Task 7, AC 6 and the decision document. The **macOS** runtime path remains unverified and is now flagged in `xcode-security-settings.md` for Epic 74.
- [x] [Review][Patch] **Decision document says the audio/MIDI verification is still outstanding, contradicting the same commit** `[docs/reports/xcode-security-settings.md:121-123]` — reads "Outstanding: the audio/MIDI listening test (Michael)" while spec:94 marks Task 7 passed and the commit message says "listening test and MIDI input verified by Michael". Still live in `HEAD`; the two follow-up commits did not fix it. The document is declared the single source of truth for these decisions, so a later audit is told the verification never happened.
- [x] [Review][Patch] **Spec Change Log is stale in the opposite direction** `[83-4-enhanced-security-hardening.md:219]` — still reads "Tasks 6 (archive validation) and 7 (audio/MIDI listening test) await Michael" while spec:93-94 mark both `[x] passed 2026-08-08`. Three artifacts in one commit disagree about whether verification is complete.
- [x] [Review][Patch] **File List asserts a `sprint-status.yaml` change that is not in the commit and a status the repo never held** `[83-4-enhanced-security-hardening.md:214]` — claims "modified (`83-4` → `in-progress`)". `git show a0afbe7d:…/sprint-status.yaml` has **no** `83-4` entry at all; `git log -S` returns a single commit, `1875ea30` (story 83.3's, two commits later), introducing it directly at `review`. The mandated `in-progress → review → done` sequence never existed in git.
- [x] [Review][Patch] **Two acceptance-criterion mis-citations in the Dev Agent Record** — spec:191 "Satisfies AC 1 and the arm64 half of AC 8"; AC 8 (spec:107) has no arm64 clause, that is AC 1. spec:205 "AC 1–4 and 8 by build and gate evidence"; AC 8 is a diff-inspection criterion that build and gate evidence cannot establish. (The diff does satisfy AC 8 — verified — but the cited evidence does not support the claim.) This is a record whose entire function is claim-to-evidence mapping.
- [x] [Review][Patch] **Decision document generalizes an iOS-only verification to "distribution"** `[docs/reports/xcode-security-settings.md:118-119]` — one target ships both platforms (`SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx"`), and the entitlements apply identically to the macOS product, but every verification performed was iOS (`lipo`, `codesign`, the `Peach (Release)` archive). The Guideline 2.4.5(i) rejection report that motivated validating at all is *Mac App Store*-only — so the platform whose risk drove the check is the one never validated. Add the caveat so Epic 74 does not inherit an unstated assumption. Related and worth one line: whether the macOS runtime protections are in force at all with `ENABLE_HARDENED_RUNTIME = NO` is nowhere reconciled; the deferral at `:90` is argued purely on compliance grounds and silently assumed orthogonal to efficacy.
- [x] [Review][Patch] **"The cascade fired" and the cascaded-settings list claim more observation than was made** `[docs/reports/xcode-security-settings.md:39-42, 110-112]` — `ENABLE_SECURITY_COMPILER_WARNINGS = YES` is cited as confirming the cascade, with no pre-change baseline taken, so it is equally consistent with an Xcode 26 default. Of the six settings listed as "cascaded automatically", four do not appear in the resolved dump the story cites, and `CLANG_WARN_EMPTY_BODY` is a template default. The list was transcribed from the skill reference into a permanent record. Reword to "per Apple/skill documentation, not individually observed".
- [x] [Review][Patch] **PF-086's Low severity contradicts its own description** `[docs/implementation-artifacts/deferred-work.md]` — the entry states that "a genuine one-test regression is indistinguishable from this noise" in the pre-commit gate every story in the project relies on, and is filed Low. Raise to Medium.
- [x] [Review][Defer] **No regression guard on the eight lines the whole protection consists of** — `ENABLE_ENHANCED_SECURITY` ×4 and `CODE_SIGN_ENTITLEMENTS` ×4 in `project.pbxproj`. Any Xcode "Signing & Capabilities" edit can silently drop them, and a *fifth* build configuration would inherit Enhanced Security at project level while missing the target-level `ENABLE_POINTER_AUTHENTICATION = NO` — silently reversing this story's central decision. The project has grown its configuration set before (the Research pair). `bin/test.sh`, `bin/build.sh` and `bin/pre-commit` catch none of it; the spec's own `grep -c` commands (spec:156-158) would, but were run once by hand and hard-code the count `4`. This story forbids source changes, so it lands in the catalog — deferred as **PF-087**.

*Dismissed as noise (8), with the evidence that killed each:* (1) `codesign -d --entitlements - --xml` reporting "invalid entitlements blob" — **falsified**: the identical warning appears on the pre-change Aug-7 build that had no entitlements file at all; it is an artifact of `--xml` against DER-only entitlements, and the DER form decodes all five keys. (2) "454 `.swift` files is wrong, it is 455" — 454 is the app+test target count; the 455th is `bin/add-localization.swift`, a build script, not app source. (3) "The test target needs its own `ENABLE_POINTER_AUTHENTICATION = NO` per the skill" — the skill requires that override only for targets "whose platform doesn't support arm64e", and `references/pointer-authentication.md:65-67` lists iOS and macOS as arm64e-**supporting**. (4) The consequent arm64e-test-bundle, SPM-link-failure and `WorkspaceSettings.xcsettings` findings — premise not realized: every built `PeachTests.xctest`, macOS and simulator, is `arm64`. (5) "The arm64e question was answerable by archiving with pointer auth on" — local Validate App tests entitlement well-formedness, not App Store *acceptance*; it cannot answer the question the story declared open. (6) "The opt-out understates its deviation from the skill's Part A" — the decision document records the opt-out, its full rationale and two revisit conditions at length. (7) Frozen Intent's "all eight build configurations" vs twelve blocks — defensible reading (eight target-level blocks), and the block is frozen. (8) `epics.md` carries no Status line for 83.4 — inconsistent practice (83.1 lacks one too), not a rule break.

## Dev Notes

### The compiler half is mostly inert here; the runtime half is the point

Enhanced Security cascades `CLANG_ENABLE_C_TYPED_ALLOCATOR_SUPPORT`, `CLANG_ENABLE_CPLUSPLUS_TYPED_ALLOCATOR_SUPPORT`, `CLANG_CXX_STANDARD_LIBRARY_HARDENING`, `GCC_WARN_SHADOW`, and `ENABLE_SECURITY_COMPILER_WARNINGS`. Peach is **pure Swift** — 454 `.swift` files, zero C/C++/ObjC — so essentially all of that is inert. The value is entirely in the entitlement-driven runtime protections:

- `hardened-heap` — extra type-isolation buckets in the allocator, applied at runtime regardless of compiler settings.
- `dyld-ro` — dyld state marked read-only.
- `platform-restrictions-string = "2"` — dyld and Mach messaging restrictions.

This matters for expectations: do not expect new compiler diagnostics to justify the change, and do not be surprised if Task 4 produces none.

### Why the audio verification is not optional

`hardened-heap` changes allocator behaviour and `platform-restrictions` constrains Mach messaging. Peach runs a real-time `AVAudioEngine` render callback plus a `SoundFontStepSequencer` scheduling MIDI events, and CoreMIDI communication is Mach-based. A regression here would most likely appear as a dropout, added latency, or a stuck note under load — none of which any unit test in this project detects, because the tests use `instantPlayback` mocks and `waitForState` rather than real audio ([[feedback_verify_audio_features]]).

### Two findings that look like one

The audit reported "no entitlements file" once, but it covers two unrelated gaps:

| | App Sandbox + Hardened Runtime | Enhanced Security |
|---|---|---|
| Required by | Guideline 2.4.5(i) | nothing |
| Platform | **macOS only** — iOS is sandboxed by the OS, no entitlement exists | iOS, iPadOS, macOS, visionOS |
| Blocks | Epic 74 (Mac App Store) | nothing; pure hardening |
| Owner | Epic 74, tracked at `74-1:23-24` | **this story** |

Conflating them is the trap. This story creates the file both will share, and adds only the Enhanced Security half.

### Product-type scoping

`references/enhanced-security.md` lists the supported product types. `com.apple.product-type.application` (the app) qualifies; `com.apple.product-type.bundle.unit-test` (the test bundle) does not. The project has exactly these two targets, so the capability lands on one and must not land on the other.

### References

- `.claude/skills/audit-xcode-security-settings/references/enhanced-security.md` — Part A/B split, required + default-ON keys, supported product types, deprecated-key migration
- `.claude/skills/audit-xcode-security-settings/references/pointer-authentication.md` — arm64e behaviour and the SPM `WorkspaceSettings.xcsettings` requirement
- `.claude/skills/audit-xcode-security-settings/references/decision-document.md` — decision-document format
- Apple: [Enabling enhanced security for your app](https://developer.apple.com/documentation/xcode/enabling-enhanced-security-for-your-app) — platform support; pointer authentication separability
- `docs/implementation-artifacts/74-1-submit-to-mac-app-store.md:23-24` — where App Sandbox is tracked
- `docs/implementation-artifacts/83-3-submit-next-app-store-cut.md` — the story this one unblocks

## Verification

**Commands:**

- `plutil -lint Peach/Resources/Peach.entitlements` — expected: `OK`
- `grep -c 'ENABLE_ENHANCED_SECURITY = YES' Peach.xcodeproj/project.pbxproj` — expected: `4`. *(Corrected 2026-08-08: the spec originally said `1`, assuming a single project-level configuration. The project has **four** — Debug, Release, Debug (Research), Release (Research) — so a project-level setting appears four times. Same shape as the version-bump matrix in 83.3.)*
- `grep -c 'CODE_SIGN_ENTITLEMENTS = Peach/Resources/Peach.entitlements' Peach.xcodeproj/project.pbxproj` — expected: `4` (app target configs)
- `grep -c 'ENABLE_POINTER_AUTHENTICATION = NO' Peach.xcodeproj/project.pbxproj` — expected: `4`
- `bin/build.sh && bin/build.sh -p mac` — expected: clean; report any new warnings
- `bin/test.sh && bin/test.sh -p mac && bin/test.sh --research && bin/test.sh --research -p mac` — expected: four green, sequential
- `lipo -archs <built app binary>` — expected: `arm64` (NOT `arm64e`)

**Manual checks:**

- Xcode → Signing & Capabilities on the app target shows Enhanced Security present with "Authenticate Pointers" **unchecked**.
- Archive `Peach (Release)` → Validate App passes with no entitlement complaint.
- Listening test (Michael): Grand Piano and Sine Wave at `noteDuration = 1 s`, one pitch discipline plus Compare Timing. No dropouts, clicks, stuck notes, or latency change.
- MIDI (Michael): pitch-bend input still drives a Match discipline.

## Spec Change Log

**2026-08-08 — Story created.** Surfaced by the first-ever `/audit-xcode-security-settings` run, during story 83.3's Task 2. Michael chose "separate story, ships before this cut" over folding the work into 83.3 or deferring it. Scope decision recorded at creation: pointer authentication explicitly **off**, because App Store acceptance of arm64e for third-party apps could not be verified against Apple's documentation and the contrary claim available was an uncorroborated search snippet.

## Dev Agent Record

### Agent Model Used

claude-opus-5[1m]

### Debug Log References

- `xcodebuild -showBuildSettings` returns **no settings at all** from inside the agent sandbox — it dies on `CoreSimulatorService connection became invalid` / `Connection refused` before emitting them. Resolved settings were obtained through XcodeBuildMCP's `show_build_settings`, which runs outside the sandbox. Note the first attempt at this check was written as `grep … || echo "(none — correct)"`, which reports "correct" identically whether the setting is absent *or* the whole command failed — the test-target result from that run was discarded as meaningless rather than recorded as a pass.
- XcodeBuildMCP session defaults point at scheme `Peach (Debug, Research)` per [[reference_xcodebuildmcp_config_overrides_session]], so the resolved-settings dump is from that configuration. This is sound for these three keys because `ENABLE_ENHANCED_SECURITY` is set in all four *project* configurations and `CODE_SIGN_ENTITLEMENTS` / `ENABLE_POINTER_AUTHENTICATION` in all four *app-target* configurations — verified by count in `project.pbxproj` (4/4/4), not assumed.

### Completion Notes List

**Task 1 — entitlements file.** `Peach/Resources/Peach.entitlements` created with exactly the five `hardened-process` keys. `plutil -lint`: OK. Placed beside `PrivacyInfo.xcprivacy`, the established home for target metadata. No `checked-allocations`, no `app-sandbox`. Satisfies AC 2.

**Task 2 — wiring.** Applied by script rather than by hand, inserting each key alphabetically into the correct `XCBuildConfiguration` blocks after classifying all twelve by content. Result: `ENABLE_ENHANCED_SECURITY = YES` ×4 (project level), `CODE_SIGN_ENTITLEMENTS` ×4 and `ENABLE_POINTER_AUTHENTICATION = NO` ×4 (app target). All four **test-target** configuration blocks verified free of all three keys **at target level** — this is a `project.pbxproj` inspection, not a resolved-settings check, and the distinction matters: `PeachTests` *resolves* to `ENABLE_ENHANCED_SECURITY = YES` by project-level inheritance, as every target does. `plutil -lint` on `project.pbxproj`: OK. Satisfies AC 3 as reworded during code review. *(Corrected 2026-08-08: this note previously read "verified free of all three", which asserted more than the evidence showed.)*

**Task 3 — resolved settings.** Confirmed via XcodeBuildMCP: `ENABLE_ENHANCED_SECURITY = YES`, `ENABLE_POINTER_AUTHENTICATION = NO`, `CODE_SIGN_ENTITLEMENTS = Peach/Resources/Peach.entitlements`, `ARCHS = arm64`, and `ENABLE_SECURITY_COMPILER_WARNINGS = YES` — the last confirming the capability's cascade actually fired. `ENABLE_APP_SANDBOX` and `ENABLE_HARDENED_RUNTIME` both still `NO`, as intended (Epic 74). Direct binary evidence: `lipo -archs` on the built product reports `arm64`, **not** `arm64e`, and `codesign -d --entitlements` on the iOS build shows `com.apple.security.hardened-process => true` embedded. Satisfies AC 1, including its arm64 clause. *(Corrected 2026-08-08: this previously read "and the arm64 half of AC 8"; AC 8 has no arm64 clause — it covers the absence of source, version and App Sandbox changes.)*

**Task 4 — builds.** iOS and macOS both succeed. **Zero new warnings** on either platform — as the Dev Notes predicted, Enhanced Security's compiler-driven half is inert in a pure-Swift codebase. The single iOS warning is the pre-existing AppIntents-metadata notice, unrelated to entitlements.

**Task 5 — four-scheme gate.** All green, run sequentially: iOS Debug **2275**, macOS Debug **2262**, iOS Research **2438**, macOS Research **2424**. Satisfies AC 4.

macOS Research initially appeared to be one short of story 83.1's recorded 2425, which was investigated rather than waved off. A repeat run on the identical tree reported 2425, so the figure is not stable. Cause identified: `bin/test.sh:187` derives its number with `grep -cE "(Test .* passed|✔ Test|passed on)"`, which counts *lines* — including suite lines and Swift Testing's own run-summary line — not distinct tests. The ±1 is a counting artifact, not a missing or failing test; both runs reported all tests passing. Filed as **PF-086**, because sprint-status records these counts as exact and story 83.1 reasoned from a ±1 delta.

**Task 8 — decision document.** `docs/reports/xcode-security-settings.md` created. Records every setting enabled, the pointer-authentication opt-out with its full unresolved-arm64e reasoning and revisit conditions, MTE deferred with its hardware requirement, App Sandbox assigned to Epic 74 with the specific entitlement Peach will need, and the C/C++ bounds-safety models marked not-applicable. `docs` is a synchronized root group, so no `project.pbxproj` edit was needed to include it ([[feedback_pbxproj_synchronized_groups]]).

**Task 6 — archive validation (Michael, 2026-08-08).** `Peach (Release)` archived and Validate App passed with no entitlement complaint. This is the meaningful confirmation that the five-key `hardened-process` set is well-formed as far as Apple's validator is concerned — the spec flagged reported Mac App Store rejections under Guideline 2.4.5(i) for "entitlements with invalid values", and that risk did not materialise. Satisfies AC 5 and unblocks story 83.3's archive.

**Task 7 — audio and MIDI verification (Michael, 2026-08-08).** Listening test passed on Grand Piano and Sine Wave at `noteDuration = 1 s`; MIDI pitch-bend input still drives a Match discipline. No dropouts, clicks, stuck notes, or latency change. This is the verification that actually exercises `hardened-heap` and `platform-restrictions` under a live render callback and CoreMIDI — the runtime question archive validation cannot answer and no unit test in this project can reach. Satisfies AC 6.

**All acceptance criteria satisfied.** AC 1–2 by build and resolved-settings evidence, AC 3 by `project.pbxproj` inspection (as reworded during code review), AC 4 by the four-scheme gate, AC 5 by archive validation, AC 6 by the on-device listening test, AC 7 by `docs/reports/xcode-security-settings.md`, and **AC 8 by inspection of the diff** — not by build or gate evidence, which cannot establish the absence of a change. Story handed to review; story 83.3's archive precondition is now met. *(Evidence mapping corrected 2026-08-08 during code review of `a0afbe7d`.)*

### File List

- `Peach/Resources/Peach.entitlements` — added (5 `hardened-process` keys)
- `Peach.xcodeproj/project.pbxproj` — modified (`ENABLE_ENHANCED_SECURITY` ×4 project-level; `CODE_SIGN_ENTITLEMENTS` and `ENABLE_POINTER_AUTHENTICATION` ×4 app-target)
- `docs/reports/xcode-security-settings.md` — added (decision document)
- `docs/implementation-artifacts/deferred-work.md` — modified (**PF-086** filed)
- `docs/implementation-artifacts/83-4-enhanced-security-hardening.md` — modified (task checkboxes, corrected AC/verification expectation, this record)
- `docs/implementation-artifacts/sprint-status.yaml` — **not modified by commit `a0afbe7d`.** *(Corrected 2026-08-08 during code review: this entry previously claimed "modified (`83-4` → `in-progress`)". The commit contains five files and this is not among them; the `83-4` key first appears two commits later, in `1875ea30`, directly at `review`. The story never held `in-progress` in git, so the `in-progress → review → done` sequence the Always block mandates was not represented.)*

## Change Log

- 2026-08-08: Story created.
- 2026-08-08: Tasks 1–5 and 8 complete. Enhanced Security adopted with pointer authentication explicitly off; entitlements file created and wired to the app target only; both platforms build with zero new warnings; four-scheme gate green; decision document written. PF-086 filed for `bin/test.sh`'s line-count pass metric. Corrected an error in this story's own spec: AC/verification expected `ENABLE_ENHANCED_SECURITY` once, but the project has four project-level configurations, so the correct count is 4.
- 2026-08-08: Tasks 6 and 7 complete. `Peach (Release)` archive validated with no entitlement complaint; listening test and MIDI check passed on a physical iOS device. All eight acceptance criteria met; story handed to review.
- 2026-08-08: Code review of `a0afbe7d` (`bmad-code-review`, three layers). Two decisions and nine patches; one item deferred as **PF-087** (no regression guard on the eight `project.pbxproj` lines the hardening consists of). AC 3 and I/O-matrix row 3 reworded with Michael's approval — the original wording could not hold alongside the Always-block requirement that `ENABLE_ENHANCED_SECURITY` live at project level, since project-level settings inherit to every target. The listening test's platform (physical iOS device) recorded, because the Simulator does not enforce the entitlement. Record corrections applied to the Change Log, File List, AC evidence mapping and two AC mis-citations; `docs/reports/xcode-security-settings.md` updated for the stale "outstanding" note, the iOS-only scope of its verification, and its overstated cascade claims. No build-configuration or source changes, so the four-scheme gate remains valid.
