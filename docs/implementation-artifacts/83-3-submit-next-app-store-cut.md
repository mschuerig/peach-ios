---
title: 'Story 83.3: Submit the next App Store cut'
type: 'chore'
created: '2026-08-08'
status: 'ready-for-dev'
baseline_commit: cb5eb4f364a4c555c384b29ab610f59507a35eb5
context:
  - '{project-root}/docs/planning-artifacts/epics.md'
  - '{project-root}/docs/planning-artifacts/appstore-metadata.md'
  - '{project-root}/docs/implementation-artifacts/83-1-tod-release-copy-update.md'
  - '{project-root}/docs/implementation-artifacts/72-1-archive-and-upload-first-build-to-testflight.md'
  - '{project-root}/docs/implementation-artifacts/73-2-upload-metadata-and-screenshots.md'
  - '{project-root}/docs/implementation-artifacts/73-4-submit-for-app-store-review.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Peach 1.0.0 (build 1) has been live on the iOS App Store since 2026-06-01. 148 commits have landed since the `v1.0.0` tag, including two changes users are waiting on: **Timing Offset Detection** shipped as a regular discipline (story 82.8 lifted its `PEACH_RESEARCH` gate) and **reference-relative Just Intonation** corrected in-tune interval targets that previously wandered ±41 ¢ on the hidden random reference note (Epic 87). Both live only in the repository. Every downstream artifact of a release — version number, binary, App Store Connect metadata, screenshots, release notes — still describes and ships 1.0.0.

**Approach:** One manual iOS App Store submission mirroring Epic 73's process, with three source-of-truth edits ahead of it. (1) Bump `MARKETING_VERSION` to `1.1.0` and `CURRENT_PROJECT_VERSION` to `2` across all eight build configurations. (2) Author "What's New" release-notes copy (EN + DE) into `appstore-metadata.md`, which is this project's versioned source of truth for every App Store field. (3) Re-capture the screenshots that no longer show the shipping app. Then: run the pre-submission audits, gate all four schemes green, archive the **`Peach (Release)`** scheme, upload via Xcode Organizer, refresh the App Store Connect listing from `appstore-metadata.md`, submit, and monitor to approval. Epic 83 flips to `done` when the cut is live.

**Why the version is 1.1.0, not 1.0.1:** a new user-facing training discipline is a feature addition, not a patch. The build number is bumped independently because App Store Connect rejects a re-used `CURRENT_PROJECT_VERSION` for the same marketing version.

## Boundaries & Constraints

**Always:**
- **iOS only.** macOS distribution is Epic 74 (paused, separate cut, separate App Store Connect platform record). Do not touch `marketing/screenshots/mac/`, and omit the App Review Notes' `Platforms` and `Mac menus` sections from the iOS submission — the 73.2 precedent, recorded as a pitfall in that story.
- **Archive the `Peach (Release)` scheme.** Not `Peach (Debug)` — Debug sets `DEBUG_INFORMATION_FORMAT = dwarf`, produces no dSYM, and Validate App fails with "Upload Symbols Failed" (72.1 burned an archive cycle on exactly this). Not `Peach (Release, Research)` — that configuration additionally registers Continuous Rhythm Matching and Chromatic Construction, so it would ship seven disciplines against App Store copy that promises five.
- **App Store Connect UI in English** per [[feedback_asc_english_ui]] — the German ASC localization has misleading translations.
- `docs/planning-artifacts/appstore-metadata.md` is the source of truth for every App Store text field. Nothing is typed into App Store Connect that does not exist in that file first; the "What's New" copy gets a new section there before it is pasted anywhere.
- Release-notes copy follows the same rules as the rest of the metadata: sober and factual, no marketing hyperbole or motivational framing per [[feedback_sober_factual_copy]]; "disciplines", never "modes", per [[feedback_disciplines_not_modes]]; German informal `du` per [[feedback_german_informal]]; "Compare Timing" / "Timing vergleichen" is the discipline's user-facing name, not an invented marketing label.
- Version bump touches **all eight** build configurations (Debug / Debug Research / Release / Release Research × app target + Tests target). 72.1 established that the project keeps `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` uniform across the matrix.
- Pre-archive gate per [[feedback_test_sh_no_parallel]] (never run iOS and macOS concurrently — shared DerivedData build-DB locks produce a phantom 0/0): `bin/test.sh && bin/test.sh -p mac && bin/test.sh --research && bin/test.sh --research -p mac` — all four green. `bin/add-localization.swift --missing` reports `0`.
- The archived commit gets an annotated git tag `v1.1.0`, matching the `v1.0.0` precedent from 72.1.
- Story key `83-3-submit-next-app-store-cut` flips to `in-progress` on start, `review` at hand-off, `done` after review per [[feedback_update_status_after_review]].

**Ask First:**
- **If any screenshot beyond the four identified as stale turns out to be stale**, ask before widening the capture set. **Default plan:** re-capture `01-start-screen`, `06-profile-screen`, `07-settings-screen`; insert a new Compare Timing shot; visually diff `02`–`05` against the running app and leave them if they still match.
- **If `/appstore-review` or `/audit-xcode-security-settings` surfaces a finding that requires a code change**, stop and report before editing. A submission story must not silently absorb remediation work. **Default plan:** report findings, let Michael decide fix-now vs. file-as-`PF-###`.
- **If Apple rejects the submission**, report the Resolution Center citation and stop. Do not begin remediation unprompted.
- **Release method** (Automatic vs. Manual release on approval). **Default plan:** Automatic, matching 73.4.

**Never:**
- No new features, no refactoring, no Boy-Scout cleanups in this story. The binary that ships is the code at `HEAD` plus a version-number bump and nothing else. If the audits or the gate expose a real defect, that is a separate story against a separate commit. *(This is exactly what happened: the security audit found Enhanced Security absent, and rather than absorb it, the work became story **83.4**, which must ship before this story archives. Amended 2026-08-08 with Michael's approval.)*
- No `PEACH_RESEARCH` disciplines in any user-facing surface — not in release notes, not in screenshots, not in the build. Continuous Rhythm Matching and Chromatic Construction stay invisible.
- No changes to the App Store description, keywords, or App Review Notes bodies — story 83.1 already brought all of those current for the five-discipline shipping set. This story *transfers* them to App Store Connect; it does not rewrite them. *(Amended 2026-08-08 on Michael's instruction: the `/appstore-review` audit found the EN/DE descriptions claiming macOS availability that does not exist. Both were corrected to "iPhone and iPad". No macOS release date has been decided. The privacy policy's third-party-library sentence was corrected in the same pass. Nothing else in the description bodies was touched.)*
- No fastlane. Epic 78 automation is explicitly not a prerequisite and is not introduced here; the submission is manual, as in Epic 73.
- No promotional-text copy. Left empty at 1.0.0 by choice (it is editable post-release without a new build) and stays empty.
- No closing of PF-082 / PF-083 / PF-084 / PF-085. They are tracked, non-blocking, and out of scope per [[feedback_never_defer_preexisting]] — they already have catalog entries.
- No privacy-nutrition-label changes. Peach still collects nothing; the existing "No Data Collected" declaration is *verified*, not re-authored.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Precondition check | `sprint-status.yaml` at story start | `87-1` = done, `83-1` = done, `83-2` = done (decision: keep milliseconds, no follow-up story), `83-4` = done (Enhanced Security hardening shipped; added 2026-08-08 by Michael's approval) | any not done → halt, report |
| Version bump | `project.pbxproj`, 8 configs | `MARKETING_VERSION = 1.1.0` and `CURRENT_PROJECT_VERSION = 2` in all 8; `grep -c` confirms 8 occurrences of each | fewer than 8 → fix before archiving |
| Release notes, EN | new `## What's New` section in `appstore-metadata.md` | ≤ 4,000 chars; names Compare Timing and the Just Intonation correction in plain factual language | over limit → trim secondary items |
| Release notes, DE | same section | parallels EN, informal `du`, ≤ 4,000 chars | same |
| Screenshot: start screen | current app, non-Research build | five disciplines under three category sections (Pitch, Intervals, Rhythm), Compare Timing last | shows four disciplines → screenshot is stale, re-capture |
| Screenshot: Compare Timing | new shot | a Compare Timing trial mid-session with the dot row visible | — |
| Screenshot: profile | current app | includes the Compare Timing progress chart with real data | empty state → populate via training runs first (71.3 AC #3) |
| Screenshot: settings | current app | Epic 81 controls: sliders (not steppers) for Duration/Gap/Tempo, piano keyboard for note range | shows steppers → stale, re-capture |
| Screenshot dimensions | captured PNGs | iPhone 6.9" = 1320×2868; iPad 13" = 2064×2752 | mismatch → wrong simulator device, re-capture |
| Pre-archive gate | four schemes | all green; `--missing` = 0 | any red → halt, do not archive |
| Archive scheme selection | Xcode Organizer | archive originates from `Peach (Release)` | `Peach (Debug)` → "Upload Symbols Failed", no dSYM; `… Research` → 7 disciplines in the binary |
| Validate App | archive | passes with no Missing Compliance warning (`ITSAppUsesNonExemptEncryption = NO` already set by 69.2) | warning appears → answer export-compliance questions in ASC |
| Build processing | uploaded build | appears in App Store Connect as processed / "Ready to Submit" | absent after 1 h → check ASC → Activity for processing errors |
| Version page, pre-submit | ASC 1.1.0 page | every section green: App Information, Pricing, App Privacy, Version Information, Build, App Review Information | any red → resolve before the Submit button enables |
| Submission declarations | ASC final prompts | Content Rights = Yes; IDFA = No | — |
| Post-submission | ASC status | "Waiting for Review" → "In Review" → Approved → live | rejected → record the guideline citation, halt per *Ask First* |
| Git tag | archived commit | annotated `v1.1.0` exists and points at the commit that was archived | tag placed on a different commit → the release is unreproducible |

</frozen-after-approval>

## Code Map

- `Peach.xcodeproj/project.pbxproj` — `MARKETING_VERSION` `1.0.0` → `1.1.0` and `CURRENT_PROJECT_VERSION` `1` → `2`, in all eight build configurations. These are the **only** source edits in this story.
- `docs/planning-artifacts/appstore-metadata.md` — add a `## What's New (Version 1.1.0)` section with EN and DE bodies plus `Length:` annotations, measured with the file's own documented method (Python `len()` on the stripped fence contents). Everything already in this file (description, keywords, App Review Notes) is current as of 83.1 and is **read**, not edited.
- `marketing/screenshots/iphone/`, `marketing/screenshots/ipad/` — re-capture `01-start-screen.png`, `06-profile-screen.png`, `07-settings-screen.png` and insert a Compare Timing shot. Target layout in both directories, preserving the start → disciplines → profile → settings ordering:

  | # | File | Action |
  |---|---|---|
  | 01 | `01-start-screen.png` | re-capture |
  | 02–05 | `02-compare-pitch` … `05-match-interval` | verify; re-capture only if the layout drifted |
  | 06 | `06-compare-timing.png` | **new** |
  | 07 | `07-profile-screen.png` | re-capture (was `06-`) |
  | 08 | `08-settings-screen.png` | re-capture (was `07-`) |

  `marketing/screenshots/mac/` is untouched (Epic 74).
- `docs/implementation-artifacts/sprint-status.yaml` — `83-3-submit-next-app-store-cut`: `backlog` → `in-progress` → `review` → `done`; `epic-83` → `done` once the cut is live; `last_updated` narrative.
- `docs/implementation-artifacts/83-3-submit-next-app-store-cut.md` — this file: task checkboxes, Dev Agent Record, Change Log.

**Read-only inputs (do not edit):**

- `docs/planning-artifacts/appstore-metadata.md` §§ Description, Keywords, App Review Notes — current as of 83.1; paste into App Store Connect verbatim, minus the `Platforms` and `Mac menus` sections.
- `Peach/Resources/PrivacyInfo.xcprivacy` — declares UserDefaults (CA92.1) and SystemBootTime (35F9.1); verify still accurate, do not modify.

**External artifacts (not files):** App Store Connect version 1.1.0 record, uploaded build 2, annotated git tag `v1.1.0`.

## Tasks & Acceptance

**Execution:**

- [x] **Task 1 — Verify preconditions.** Confirm in `sprint-status.yaml`: Epic 87 done, 83.1 done, 83.2 done with the "keep milliseconds" decision and no follow-up implementation story. **Re-verify `83-4` = done before Task 7 archives** (added 2026-08-08). Confirm `git status` is clean and `HEAD` is the intended release commit. Record the commit SHA in the Dev Agent Record. — **verified 2026-08-08**, release commit `cb5eb4f364a4c555c384b29ab610f59507a35eb5`
- [x] **Task 2 — Pre-submission audits.** Run `/appstore-review` (last run 2026-03-28, predating Epics 80–88) and `/audit-xcode-security-settings`. Report findings. Escalate per *Ask First* if any requires a code change; do not remediate unprompted. — **both complete.** Verdict: iOS cut READY, conditional only on the screenshot refresh already scoped here. Three findings dispositioned: Enhanced Security → **story 83.4** (must ship first); macOS availability claim → **corrected**; privacy-policy dependency count → **corrected**. Mac App Store App Sandbox gap → Epic 74, already tracked at `74-1:23-24`.
- [x] **Task 3 — Version bump.** `MARKETING_VERSION` → `1.1.0`, `CURRENT_PROJECT_VERSION` → `2`, all eight configurations. Verify with `grep -c`. — **8/8 each, zero residue of `1.0.0` / build `1`**
- [x] **Task 4 — Author release notes.** Draft EN + DE "What's New" copy covering Compare Timing and the Just Intonation correction. `/app-store-changelog` can seed a draft from `v1.0.0..HEAD`, but the shipped wording is settled deliberately against the copy constraints above, not accepted as generated. Add the section to `appstore-metadata.md` with measured `Length:` annotations. **Record the settled wording in the Spec Change Log before editing the file.** — EN 912 / DE 1,004 chars, annotations verified exact
- [x] **Task 5 — Re-capture screenshots.** — **COMPLETE: 16 shots, 8 per device, all dimensions verified.** The manual-import blocker is resolved (Michael's sandbox change makes `xcrun simctl` and simulator-container writes work; the iPhone already holds 604 seeded records). **Scope amended 2026-08-08 with Michael's approval: all eight shots per device are re-captured, not four** — shipping `02`–`05` came from a German-region simulator and render comma decimals under English UI. 7 of 8 iPhone shots are captured and verified; **`06-compare-timing` is blocked on story 83.6** and must be captured only after that fix ships. iPad capture not started. See the Spec Change Log and Dev Agent Record for detail.

  **Regenerate the seed CSV** — do not rely on any previously reported `$TMPDIR` path, which does not survive across sessions:

  ```
  python3 bin/generate-test-data.py --count 600 \
    --discrimination-unison --discrimination-interval \
    --matching-unison --matching-interval --timing-offset-detection \
    <output-path>
  ```

  The five flags are load-bearing: omitting them generates all six disciplines including Continuous Rhythm Matching, which is research-only and must not appear in a shipping screenshot. Verify with `grep -c continuousRhythmMatching <file>` → `0`.

  Then populate training data before capturing (71.3 AC #3 — no empty states). Capture on iPhone 16/17 Pro Max (1320×2868) and iPad Pro 13" (2064×2752) from a **non-Research** build. Re-shoot start / profile / settings, add Compare Timing, verify `02`–`05` still match the running app. Verify every file's pixel dimensions.
- [x] **Task 6 — Pre-archive gate.** Run sequentially **twice**. First at `498a293d` (2290 / 2277 / 2453 / 2440). Re-run after story 83.6's code review changed code again: **2297 / 2284 / 2463 / 2450**, all green — these are the binding figures. The only change to `Peach/` after that run is `933c9b62`, which adds auto-generated translator comments and `extractionState: stale` markers to `Localizable.xcstrings` and cannot affect behaviour. `bin/add-localization.swift --missing` → `0`, with the keys additionally verified present in `Localizable.xcstrings` rather than trusted to the count. `archlint Peach/` exit 0; `bin/check-dependencies.sh` "All non-import dependency rules passed."
- [x] **Task 7 — Archive and upload.** — **complete and verified on device.** Build `1.1.0 (2)` uploaded 2026-08-08 20:56, processed, **Ready to Submit**, **no Missing Compliance warning** (so `ITSAppUsesNonExemptEncryption = NO` survived into the archive).

  **A real ambiguity had to be resolved.** Two `Peach (Release)` archives existed for 2026-08-08, both stamped `1.1.0 (2)`: one at 14.05 and one at 20.49. Only the 20.49 archive contains story 83.6 — confirmed locally by `strings` (`current difficulty in milliseconds` present in 20.49, `as a percentage` present in 14.05). Xcode keeps **no local record of which archive was distributed**, and the archive-folder timestamps cannot distinguish upload from creation, so the file system could only make the case circumstantial (created 20:49, uploaded 20:56; the 14.05 archive predates every 83.6 commit and was untouched afterwards).

  **Resolved by installing the uploaded build from TestFlight** on a physical iPhone: the Start screen shows five disciplines under three sections, and Compare Timing renders milliseconds only. Percent being absent excludes the 14.05 archive, since it predates 83.6 entirely. Right scheme, right archive — AC 5 satisfied. `SchemeName: Peach (Release)` in the archive `Info.plist` corroborates independently.

  **Two verification attempts that did *not* work, recorded so they are not repeated.** (a) A simulator install cannot verify the upload — the archive is arm64, and a simulator build would only prove what the scheme does, not what was uploaded. (b) Searching the binary for `ContinuousRhythmMatchingDiscipline` / `ChromaticConstructionDiscipline` symbols proves nothing: `project-context.md` specifies that research discipline *types* compile into every configuration and only their *registration* is `#if PEACH_RESEARCH`-gated, so both symbols are present in a correct shipping build (180 and 127 occurrences). Only runtime behaviour distinguishes the configurations. ORIGINAL: **Precondition: confirm `83-4` is `done` in `sprint-status.yaml` before archiving** — it changes the binary. Destination "Any iOS Device (arm64)", scheme **`Peach (Release)`**, clean build folder, Product → Archive. Run Validate App as a dry run, then Distribute App → "TestFlight & App Store" → Upload. Confirm the build reaches "Ready to Submit" in App Store Connect with no Missing Compliance warning.
- [x] **Task 8 — Tag the release.** Annotated `v1.1.0` created on `9b2bf0de41039c9d4d203ecb4969288136018eeb`, the archived commit, matching the `v1.0.0` precedent from 72.1. **Not pushed** — the project does not push without an explicit request.
- [x] **Task 9 — Refresh App Store Connect metadata.** — done by Michael in App Store Connect. Recorded as *reported*, not agent-verified: App Store Connect state is not inspectable from here, and the Submit button only gates on sections being *present*, not current. One item was flagged as unconfirmed and was **resolved before submission**: the German locale did carry its own screenshot set inherited from 1.0.0 — the stale four-discipline images — and App Store Connect does not challenge that at submission, so it would have shipped silently under a description promising five. Michael removed them, so German now falls back to the primary-language set, which is correct: the captures are English by design (story 71.3). ORIGINAL: Create the 1.1.0 version. Paste EN + DE description and keywords from `appstore-metadata.md` (unchanged since 83.1 but not yet in ASC), the new "What's New" copy per locale, and the updated App Review Notes minus the Mac sections. Upload the new screenshots in order. Verify Support URL and Privacy Policy URL still resolve. Verify privacy nutrition labels still read "No Data Collected".
- [x] **Task 10 — Submit.** — submitted 2026-08-08; App Store Connect status **Waiting for Review**. ORIGINAL: Confirm every version-page section is green and the Submit button is enabled. Choose the release method per *Ask First* (default: Automatic). Submit; answer Content Rights = Yes, IDFA = No. Confirm status "Waiting for Review".
- [ ] **Task 11 — Monitor to outcome.** *(in progress — awaiting Apple)* ORIGINAL: Track status through review. On approval, confirm the app is live at version 1.1.0. On rejection, record the guideline citation and halt per *Ask First*.
- [ ] **Task 12 — Close out.** `83-3` → `done`; `epic-83` → `done` (the epic closes when the cut ships, not when its last story does). Update `sprint-status.yaml` `last_updated` narrative.

**Acceptance Criteria:**

1. **Given** `project.pbxproj` after the bump, **when** `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` are counted, **then** exactly eight occurrences of `1.1.0` and eight of `2` are present, and no configuration retains `1.0.0` or build `1`.
2. **Given** `appstore-metadata.md` after Task 4, **when** the "What's New" section is read, **then** it exists in EN and DE, each ≤ 4,000 characters with an accurate `Length:` annotation, each naming Compare Timing and the Just Intonation correction, neither mentioning Continuous Rhythm Matching, Chromatic Construction, "modes", or motivational language.
3. **Given** the re-captured screenshot set, **when** the start-screen shot is inspected, **then** it shows five disciplines under three category sections with Compare Timing last; **and** the set contains a Compare Timing training shot; **and** the profile shot includes a populated Compare Timing chart; **and** the settings shot shows Epic 81's sliders and piano keyboard; **and** every iPhone file is 1320×2868 and every iPad file 2064×2752.
4. **Given** the four-scheme gate run sequentially before archiving, **when** the results are read, **then** all four are green and `bin/add-localization.swift --missing` reports `0`.
5. **Given** the uploaded build, **when** viewed in App Store Connect, **then** it is version 1.1.0 build 2, processed, with no Missing Compliance warning, and it was produced from the `Peach (Release)` scheme (verifiable in-app: the shipped build registers exactly five disciplines).
6. **Given** the App Store Connect 1.1.0 version page before submission, **when** each section is checked, **then** all show green, the EN and DE description/keywords/release-notes match `appstore-metadata.md` verbatim, the App Review Notes contain no Mac-specific sections, the privacy labels still read "No Data Collected", and both URLs resolve.
7. **Given** the submission, **when** confirmed, **then** App Store Connect status is "Waiting for Review"; **and** on approval the app is live at 1.1.0.
8. **Given** the repository after archiving, **when** `git tag` is listed, **then** an annotated `v1.1.0` points at the exact commit that was archived.
9. **Given** the full story, **when** the diff is reviewed, **then** the only source-code change is the version bump — no feature, refactoring, or cleanup edits ride along.

## Dev Notes

### Why the archive scheme is the highest-risk decision in this story

The project uses one scheme per build configuration. Archive takes its configuration from the selected scheme, and two of the four wrong choices fail in ways that are easy to miss:

- `Peach (Debug)` — `DEBUG_INFORMATION_FORMAT = dwarf`, so the archive carries no dSYM and Validate App rejects it with "Upload Symbols Failed". Loud, and 72.1 already paid for this lesson.
- `Peach (Release, Research)` — builds cleanly, validates cleanly, uploads cleanly, and ships a binary registering **seven** disciplines while the App Store description promises five. Silent. This is the one to guard against. Story 83.1 added an `isDisjoint` assertion under `#if !PEACH_RESEARCH` in `TrainingDisciplineRegistryTests` precisely so a research discipline cannot leak into a shipping build unnoticed — but that guard only fires when the non-Research schemes are tested, which is why Task 6 runs all four and Task 7 names the scheme explicitly.

Cheapest post-hoc verification: install the archived build and count the Start-screen disciplines. Five under three sections = correct configuration.

### What actually changed for users since 1.0.0

The release-notes copy should be driven by these, not by the 148-commit log:

- **Compare Timing** (Epics 80–84) — the fifth discipline, previously research-gated. A short rhythmic pattern loops; the user judges whether a note came early or late. Carries its own settings (tempo, pattern, offset-note position, maximum repetitions) and its own progress chart.
- **Just Intonation correction** (Epic 87) — in-tune interval targets are now computed from each trial's reference note via pure ratios. Previously a fixed A-rooted 5-limit table made "correct" wander by up to ±41 ¢ depending on which reference note the trial happened to pick. This is a correctness fix to what the app teaches; it deserves a plain sentence, not a footnote.
- **Settings controls** (Epic 81) — continuous values moved from steppers to sliders; note range is now selected on a piano keyboard.
- **Reliability** (Epics 85, 88) — audio-session lifecycle hardening (Bluetooth codec switches, media-services resets) and profile-screen responsiveness.

Everything else in the 148 commits is internal architecture and does not belong in user-facing notes.

### Screenshot staleness, itemized

The 1.0.0 set was captured 2026-05 against a four-discipline app. Confirmed stale:

- `01-start-screen` — four disciplines in two sections; the app now renders five in three (Pitch, Intervals, Rhythm).
- `06-profile-screen` — predates the Compare Timing chart.
- `07-settings-screen` — predates Epic 81's slider taxonomy and piano-keyboard note range.
- **Missing entirely** — a Compare Timing training shot. Its absence, alongside a description bullet promising the discipline, is the kind of mismatch Guideline 2.3 (Accurate Metadata) exists for.

`02`–`05` (the four pitch training screens) are probably still accurate; verify rather than assume — Epic 75.3 introduced a shared training-screen modifier that may have shifted layout.

### Pre-submission audit rationale

`docs/reports/appstore-review-2026-03-28.md` is the last guidelines audit and predates Epics 80–88 entirely. `CLAUDE.md` mandates `/appstore-review` and `/audit-xcode-security-settings` before submission. Run both before archiving, not after — a finding that lands after the upload costs a whole build cycle.

### Compliance state carried forward from Epic 69 (verify, do not re-author)

- `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` — present in all four app-target configs; this is what suppresses the Missing Compliance warning.
- `Peach/Resources/PrivacyInfo.xcprivacy` — declares UserDefaults (CA92.1) and SystemBootTime (35F9.1) API reasons, no tracking. No new data-collecting API has been introduced since 1.0.0; the manifest and the "No Data Collected" nutrition labels both still hold.
- Privacy policy: `https://mschuerig.github.io/peach-ios/privacy-policy`. Support URL: `https://github.com/mschuerig/peach-ios`. Both were live at 1.0.0; re-verify, they are single points of submission failure.

### App Store Connect friction, recorded at 1.0.0

- The screenshot drop zone stays inert until you select a different display size in the picker and switch back. The picker state, not the file, gates the target.
- The "Notes" field under App Review Information carries hint copy suggesting it is China-specific. It is the general-purpose field every reviewer reads. Paste the full notes regardless.
- App Store Connect counts grapheme clusters; Python `len()` matches for ASCII and standard German diacritics.

### Project Structure Notes

This is a release story, not a development story. The single source edit is a version number in `project.pbxproj`; everything else is documentation, image assets, and external App Store Connect state. There is no new test to write — AC 5's "five disciplines in the shipping build" is already pinned by `TrainingDisciplineRegistryTests.shippingDisciplinesAlwaysRegistered` (lower bound) and its `isDisjoint` companion (upper bound), both landed by story 83.1.

macOS stays out. Epic 74 owns Mac App Store submission, notarization, GitHub Releases, and the Homebrew cask, and remains paused. Do not let a green `bin/test.sh -p mac` (which this story does run, as a gate) drift into Mac distribution work.

### References

- `docs/planning-artifacts/epics.md` § Epic 83 — epic definition, work order, and the "epic closes when the cut ships" rule
- `docs/planning-artifacts/appstore-metadata.md` — source of truth for all App Store text fields
- `docs/implementation-artifacts/83-1-tod-release-copy-update.md` — the copy this story transfers to App Store Connect; its review log explicitly assigns the "What's New" surface to this story
- `docs/implementation-artifacts/72-1-archive-and-upload-first-build-to-testflight.md` — archive/upload mechanics, scheme pitfall, version-matrix precedent, `v1.0.0` tag precedent
- `docs/implementation-artifacts/73-2-upload-metadata-and-screenshots.md` — ASC metadata upload, iOS-only trimming of the review notes, field-discovery friction
- `docs/implementation-artifacts/73-4-submit-for-app-store-review.md` — submission flow, final declarations, rejection playbook
- `docs/implementation-artifacts/71-3-capture-iphone-and-ipad-screenshots.md` — capture devices, exact dimensions, realistic-data requirement
- `docs/planning-artifacts/tod-discipline-future-direction.md` § Metric unit decision — story 83.2's outcome (keep milliseconds)
- Apple: [Submit for review](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-for-review) · [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

## Verification

**Commands:**

- `grep -c 'MARKETING_VERSION = 1.1.0' Peach.xcodeproj/project.pbxproj` — expected: `8`
- `grep -c 'CURRENT_PROJECT_VERSION = 2' Peach.xcodeproj/project.pbxproj` — expected: `8`
- `bin/test.sh && bin/test.sh -p mac && bin/test.sh --research && bin/test.sh --research -p mac` — expected: four green, run sequentially
- `bin/add-localization.swift --missing` — expected: `0 keys missing German translation`
- `sips -g pixelWidth -g pixelHeight marketing/screenshots/iphone/*.png` — expected: every file 1320×2868
- `sips -g pixelWidth -g pixelHeight marketing/screenshots/ipad/*.png` — expected: every file 2064×2752
- `git tag --sort=-creatordate | head -2` — expected: `v1.1.0` then `v1.0.0`
- `git log -1 --format=%H v1.1.0` — expected: the SHA recorded in Task 1

**Manual checks:**

- Install the archived `Peach (Release)` build; the Start screen shows exactly five disciplines under Pitch / Intervals / Rhythm. Seven disciplines means the Research scheme was archived — discard and re-archive.
- App Store Connect 1.1.0 page: every section green; EN and DE description, keywords, and "What's New" match `appstore-metadata.md` character-for-character; App Review Notes contain no `Platforms` or `Mac menus` section; privacy labels read "No Data Collected".
- Open the Support URL and the Privacy Policy URL in a browser; both load.
- After approval: open the live App Store listing and confirm it shows 1.1.0, the five-bullet discipline list, and the new screenshots.

## Spec Change Log

**2026-08-08 — Frozen-block amendments, all approved by Michael before the corresponding edits.**

1. **Precondition added:** `83-4` (Enhanced Security hardening) must be `done` before Task 7 archives, because it changes the binary this story ships. Applied to the I/O-matrix precondition row, Task 1, and Task 7. Origin: Task 2's `/audit-xcode-security-settings` run found Enhanced Security absent; Michael chose "separate story, ships before this cut" over folding it in or deferring it.
2. **"No changes to the description bodies" relaxed, twice.** The `/appstore-review` audit found the EN/DE descriptions claiming macOS availability that does not exist (Guideline 2.3.1(a)) and the privacy policy claiming one third-party library where `Package.resolved` pins four (5.1.1(i)). Michael instructed both be corrected. Descriptions now say "iPhone and iPad" — no macOS release date has been decided. Nothing else in the description bodies was touched; the App Review Notes' Mac sections were kept for the eventual Mac submission and flagged omit-for-iOS in *Notes for Upload*.

**Commits so far.** This is not a single-commit story — it spans the release:

| Commit | Contents |
|---|---|
| `a0afbe7d` | Story **83.4** — Enhanced Security hardening (separate story, separate diff) |
| `1875ea30` | Story 83.3 partial — version bump, EN+DE "What's New", both audit copy corrections, `epics.md`, both specs |

Both were split at hunk level out of a shared `project.pbxproj`: `a0afbe7d` carries only the 12 Enhanced Security insertions, `1875ea30` only the 8+8 version lines. For a code-review baseline over this story's work, spell out a range (`diff 1875ea30^..HEAD`) rather than a bare SHA, per [[reference_code_review_baseline_args]].

**2026-08-08 — Release-notes wording settled (Task 4).**

Content selected from the four user-visible change classes since `v1.0.0` (Compare Timing, the Just Intonation correction, Epic 81's Settings controls, Epics 85/88 reliability), not from the 148-commit log. German terminology taken from the shipping strings rather than invented: `Offset-Note` (`Position der Offset-Note`), `Tonumfang`, `Muster`, `Maximale Wiederholungen`, `reine Stimmung`.

| Surface | Settled wording |
|---|---|
| EN heading 1 | `Compare Timing — a new training discipline` |
| EN heading 2 | `Just Intonation correction` |
| EN heading 3 | `Other changes` |
| EN length | 912 chars (limit 4,000) |
| DE heading 1 | `Timing vergleichen — eine neue Übungsdisziplin` |
| DE heading 2 | `Korrektur der reinen Stimmung` |
| DE heading 3 | `Weitere Änderungen` |
| DE length | 1,004 chars (limit 4,000) |

The JI paragraph states the user-visible consequence (in-tune target off by up to 41 cents depending on the reference note) rather than the mechanism. "Judge" is used for the Compare Timing task, consistent with the App Store description bullet 83.1 settled and with PF-085's preferred verb.

**2026-08-08 — Task 5 amendments, both approved by Michael before the corresponding work.**

1. **Capture set widened from 4 shots to all 8 per device.** The spec scoped re-capture to `01`, `06`, `07`, `08` and told Task 5 to "verify `02`–`05` and leave them if the layout still matches". The layout *does* still match — live `02` was diffed against the shipping `02` and is identical, which exonerates Epic 75.3's shared training-screen modifier. But the shipping `02`–`05` render cent values with a decimal comma (`Latest: 10,2 ¢` in `02`; `Latest: 7,5 ¢` / `Best: 7,4 ¢` in `05`) while every piece of UI text is English. The new capture device is `en_US` and renders `11.5 ¢`; keeping them would ship an en-US listing whose eight screenshots disagree about the decimal separator. Michael chose to re-capture all eight rather than accept the mixed set. This is the *Ask First* "screenshot beyond the four identified as stale turns out to be stale" clause firing.

   **Provenance, corrected 2026-08-08.** This was **not** an unnoticed defect, as an earlier draft of this note implied. Story 71.3 recorded it at capture time and accepted it deliberately: *"simulator was set to English language with German region, so iPad status bar shows `100 %` (German number formatting). App text is fully English. Acceptable for initial release; can be tightened to en_US region later if desired."* This cut is that "later" — the remedy 71.3 named has now been applied, on both devices. The lesson is not that someone missed it but that a documented "tighten later" carries no trigger, so it surfaced only because an unrelated task happened to re-open the same files.
2. **A second unit defect found, and split out as story 83.6.** The Compare Timing **training screen** still leads with percent-of-a-sixteenth — `Latest: 20% (38 ms)` on the stats lines, a bare `20%` on the per-trial feedback pill, and "Incorrect, 20 percent" to VoiceOver — contradicting 83.2's settled milliseconds decision. Story 83.5 had harmonized only the *shared* progress surfaces (Start card, Profile card), so this is the same root cause at a second site. It is the screen the new `06-compare-timing` screenshot showcases. Michael chose a separate story shipping before the archive, mirroring 83.5 exactly, over absorbing it here or deferring it to a `PF-###`; and chose **milliseconds only** for the fix over milliseconds-leading-with-percent-secondary. `06-compare-timing` is therefore blocked until 83.6 lands. Recorded because it is the second time a release-blocking display defect has been found by *looking at the running app* rather than by any test, lint, or review pass.

## Dev Agent Record

### Agent Model Used

claude-opus-5[1m]

### Debug Log References

- `xcrun simctl` is unusable from the agent sandbox: `CoreSimulatorService connection became invalid` / `Connection refused` on the XPC connection, plus `Operation not permitted` opening `~/Library/Logs/CoreSimulator/`. XcodeBuildMCP works (it runs outside the sandbox) and is the supported path for build/launch/screenshot.
- Writing to `~/Library/Developer/CoreSimulator/Devices/<UDID>/data/` fails with `Operation not permitted`. This is what blocks Task 5's data seeding; not worked around per [[feedback_never_circumvent_sandbox]].
- XcodeBuildMCP session defaults were found pointing at scheme **`Peach (Debug, Research)`** and simulator `iPhone 17 Pro` — both wrong for this story (seven disciplines; not the 6.9" class). Confirms [[reference_xcodebuildmcp_config_overrides_session]]. Any capture run must re-verify defaults immediately before use.

### Completion Notes List

**Task 1 — preconditions (verified 2026-08-08).** Epic 87 `done`, 83.1 `done`, 83.2 `done` (keep milliseconds; no follow-up implementation story, so 83.3 is unblocked on that axis). Working tree carried only this story's own artifacts — no source changes pending. Release commit: `cb5eb4f364a4c555c384b29ab610f59507a35eb5` ("Apply story 83.1 code review findings").

**Task 2 — security audit (complete; one finding, escalated not applied).** Project is pure Swift (454 `.swift`, zero C/C++/ObjC), so the skill's Clang safety-warning step is not applicable — those settings are set anyway. Already correct: `ENABLE_USER_SCRIPT_SANDBOXING`, `DEAD_CODE_STRIPPING`, three `CLANG_ANALYZER_*`, six `GCC_WARN_*`. No security-catalog setting is explicitly `NO`. No decision document exists. **Gap: `ENABLE_ENHANCED_SECURITY` is absent**, no `.entitlements` file exists, and no `CODE_SIGN_ENTITLEMENTS` is wired. Both SPM dependencies (MIDIKit, swift-async-algorithms) build from source and there are no `.xcframework`/`.a`/`.dylib` binaries, so pointer authentication is dependency-safe — but adopting Enhanced Security changes the shipping binary materially and is therefore an *Ask First* escalation, not a drive-by, under this story's "no edits beyond the version bump" constraint. **`/appstore-review` has not returned; Task 2 stays open until it does.**

**Task 3 — version bump (complete).** `MARKETING_VERSION` `1.0.0` → `1.1.0` and `CURRENT_PROJECT_VERSION` `1` → `2`, eight occurrences each, zero residue. Satisfies AC 1.

**Task 4 — release notes (complete).** EN + DE "What's New" added to `appstore-metadata.md`. Measured lengths (912 / 1,004) match the `Length:` annotations exactly, re-verified by re-parsing the fences after the edit. No CRM, no Chromatic Construction, no "modes", no motivational framing; German uses informal `du` throughout. Satisfies AC 2.

**Task 5 — screenshots (IN PROGRESS; original blocker resolved, now gated on 83.6).** Seed CSV generated: 600 backdated records across exactly the five shipping disciplines (240 `pitchDiscrimination`, 240 `pitchMatching`, 120 `rhythmOffsetDetection`), verified to contain zero `continuousRhythmMatching` rows. Target devices: iPhone 17 Pro Max `6CA2827E-2CEC-4718-AF42-32593BBCA652`, iPad Pro 13-inch (M5) `17E13B03-B487-42CA-99AD-9132725A6206`.

**The manual-import blocker is gone.** Michael's sandbox change (`sandbox.network.allowMachLookup: ["com.apple.CoreSimulator.*"]` plus CoreSimulator paths in `filesystem.allowWrite`, working-tree-only in `.claude/settings.json`) makes both `xcrun simctl` and writes to the simulator data container work from the agent sandbox. The iPhone already carries **604 records** (600 seeded + 4 from live trials), confirmed by `sqlite3 … "select count(*) from ZTRAININGRECORD"` against the app's `default.store`. No manual import is needed on either device.

**Capture mechanics, confirmed working.** Full resolution comes from `xcrun simctl io <udid> screenshot --type=png` (1320×2868 verified). The XcodeBuildMCP `screenshot` tool returns a **downscaled 368×800 JPEG** and must not be used for App Store assets. XcodeBuildMCP session defaults were again found pointing at `Peach (Debug, Research)` / `iPhone 17 Pro`, per [[reference_xcodebuildmcp_config_overrides_session]]; corrected to `Peach (Release)` / `iPhone 17 Pro Max` and the built product verified at `Release-iphonesimulator/Peach.app`, version 1.1.0 (2), binary timestamped after the last source edit at HEAD.

**iPhone captures completed and visually verified (7 of 8):** `02-compare-pitch` (`Latest: 15.1 ¢`, `Best: 14.2 ¢`), `03-match-pitch` (`7.9 ¢`), `04-compare-interval` (`14.2 ¢`, `Perfect Fifth Up`, `Equal Temperament`), `05-match-interval` (`10.3 ¢`), `07-profile-screen` (scrolled to show the populated Compare Timing card: `79.5 ms ±7.1 ms` plus the tempo-range heatmap — satisfies the AC 3 requirement), `08-settings-screen` (Epic 81's piano keyboard with C2–C6 markers and Duration as a **slider** — satisfies AC 3), and `01-start-screen` (five disciplines, three sections, Compare Timing last, rendering `79.5 ms` — 83.5's fix confirmed live). **`06-compare-timing` is composed and captures cleanly but is withheld pending story 83.6**, because it displays `Latest: 20% (38 ms)`.

**Verified non-findings (checked, not assumed).** (a) `Best` appearing to lag `Latest` on the pitch screens is not a bug — `trackSessionBest` guards on `completed.isCorrect` and records the trial's cent *offset*, while `Latest` is the profile EWMA; they are different quantities and not comparable. (b) Session-best ranking on the timing screen keying off percentage is safe today because tempo is constant within a session; recorded in 83.6's Dev Notes as a latent coupling rather than a live defect.

**Task 5 complete — 16 shots, both devices.** Every iPhone file is 1320×2868 and every iPad file 2064×2752, verified with `sips`. `marketing/screenshots/mac/` untouched per Epic 74.

AC 3 satisfied on both devices: the start screen shows five disciplines under Pitch / Intervals / Rhythm with Compare Timing last and rendering `ms`; `06-compare-timing` is a mid-session trial with the dot row and its doubled offset-note dot visible, reading `Latest: 37.5 ms` / `Best: 37.5 ms` against the 83.6 build; `07-profile-screen` is scrolled to a populated Compare Timing card (`79.5 ms ±7.1 ms` on iPhone, `Current average 78.9 milliseconds ±0.0 ms` on iPad); `08-settings-screen` shows Epic 81's piano keyboard with C2–C6 markers and Duration as a slider.

**The iPad needed its own locale fix.** It booted in **German** — `Tonhöhe` / `Vergleichen` / `11,6 ¢` — which would have reproduced exactly the defect that widened this task's scope in the first place. Set to `en_US` via `xcrun simctl spawn <udid> defaults write -g AppleLocale/AppleLanguages` plus a shutdown/boot cycle, then re-verified before capture. **Record this for any future capture: verify the simulator's locale explicitly, per device; it is not inherited from the host or from another simulator.** iPad training data was seeded by copying `default.store{,-wal,-shm}` from the iPhone container (613 records) rather than by re-importing the CSV.

**A shell trap worth recording:** `cp` is aliased to `cp -i`, so the first store copy silently did nothing — it consumed EOF as "no" and still exited 0. This is the same failure mode as the aliased `rm -i` that made story 83.1 record a deletion that never happened. Use `/bin/cp -f` / `command cp` for scripted copies.

**Seed-data quality fixed (Michael's decision).** The Compare Timing heatmap first rendered almost entirely red ("Erratic") because `bin/generate-test-data.py` draws `offsetMs` uniformly from 5–150 ms, while `SpectrogramThresholds.default` tops out at ~55 ms for `loose` — so nearly every cell fell past the last band. That is data no real user could produce, and it depicted the user as consistently poor in the screenshot that introduces the release's headline discipline.

Rather than edit the shared generator (a committed tool, and out of this story's remit), the seeded records were reshaped in place. The store's `ZPAYLOADDATA` is plain JSON (`{"isCorrect":true,"offsetMs":-117.1,"tempoBPM":198}`), so a scratchpad script rewrote **only** `offsetMs` and `isCorrect` on `timingOffsetDetection` rows, leaving `tempoBPM`, timestamps, and both pitch disciplines untouched. Magnitudes are drawn lognormally around a centre falling from ~48 ms (oldest) to ~16 ms (newest) so the history reads as genuine improvement, with `isCorrect` following a sigmoid on magnitude because a larger displacement is easier to detect. Seeded (`random.seed(83)`), so it reproduces. Result: median 29.6 ms, 114 of 127 records inside the `loose` band or better, 13 beyond it — a heatmap that grades from red in the older months to orange/yellow/green in recent sessions, headline `27.0 ms ±2.3 ms` with an improving trend. `01-start-screen` was re-captured on both devices too, since the Compare Timing card's headline moved from `79.5 ms` to `27.0 ms`.

**Dispositioned as PF-097.** In the Compare Timing profile card the two widest tempo-range labels truncate to `160–2…` and `120–1…` in `07-profile-screen` on **both** devices. (An earlier note in this record claimed iPad rendered them in full; that was read off a `snapshot_ui` text node, which reports the underlying string rather than what is drawn, and the captured PNG disproves it.) The mechanism is a fixed `yAxisLabelWidth: CGFloat = 44` frame in `RhythmSpectrogramView`, so it is not a narrow-device problem — it reproduces on the widest devices. Michael reports the labels render correctly on a **physical iPhone 17 Pro**, which a fixed-width frame cannot explain; that discrepancy is recorded as unexplained in PF-097 rather than guessed at. Cosmetic, not a submission blocker; the captured screenshots ship as they are.

### File List

- `Peach.xcodeproj/project.pbxproj` — modified (`MARKETING_VERSION` → `1.1.0`, `CURRENT_PROJECT_VERSION` → `2`, all 8 configurations)
- `docs/planning-artifacts/appstore-metadata.md` — modified (new `## What's New (Version 1.1.0)` section, EN + DE; macOS availability claim corrected in both descriptions; `Length:` annotations recomputed; Mac-submission-only scope note added to *Notes for Upload*)
- `pages/privacy-policy/en.md` — modified (third-party library sentence corrected; effective date bumped). **Deployed and verified live 2026-08-08** at `https://mschuerig.github.io/peach-ios/privacy-policy/en`: serves "a small number of open-source libraries: MIDIKit … and swift-async-algorithms, together with the libraries those two depend on" and *Effective date: August 8, 2026*.
- `pages/privacy-policy/de.md` — modified (same, German). **Verified live** at `/privacy-policy/de`: "einige wenige Open-Source-Bibliotheken …" and *Gültig ab: 8. August 2026*.
- `docs/planning-artifacts/epics.md` — modified (stories 83.4, 83.5, 83.6 added; Epic 83 work order updated twice; Status line added to 83.3)
- `docs/implementation-artifacts/83-6-timing-screen-millisecond-display.md` — added (spec for the second unit-display story this one now depends on)
- `docs/implementation-artifacts/83-5-start-screen-unit-rendering.md` — modified (status `review` → `done`; its review closed at `c21483ca`)
- `marketing/screenshots/iphone/*.png` — re-captured (all eight; `06-compare-timing` pending story 83.6)
- `docs/implementation-artifacts/83-4-enhanced-security-hardening.md` — added (spec for the hardening story this one now depends on)
- `docs/implementation-artifacts/83-3-submit-next-app-store-cut.md` — added (spec), then modified (task checkboxes, Spec Change Log, this record)
- `docs/implementation-artifacts/sprint-status.yaml` — modified (`83-3` → `ready-for-dev` → `in-progress`, `last_updated`)

## Change Log

- 2026-08-08: Story created.
- 2026-08-08: Privacy policy pushed by Michael and verified live in both locales (corrected library sentence + bumped effective date serving at `mschuerig.github.io/peach-ios/privacy-policy/{en,de}`). The `/appstore-review` 5.1.1(i) finding is now closed end-to-end — corrected, committed, deployed, confirmed. This also re-satisfies the AC 6 precondition that the Privacy Policy URL resolves, which 73.2 recorded as a submission blocker if it 404s.
- 2026-08-08: Task 2 closed. `/appstore-review` verdict: iOS cut READY, conditional only on the screenshot refresh already scoped here; both 2026-03-28 criticals confirmed closed. Three findings dispositioned on Michael's instruction — Enhanced Security became story **83.4** (must ship before this story archives; frozen block amended in three places), the macOS availability claim in both descriptions was corrected to "iPhone and iPad" (no macOS release date decided), and the privacy policy's "one third-party library" sentence was corrected to name both direct dependencies and acknowledge their transitive ones (`Package.resolved` pins four; effective date bumped per the policy's own update clause). All five `Length:` annotations in `appstore-metadata.md` re-measured and exact. Verified no in-app localized string claims Mac availability; the sole remaining Mac claim is the App Review Notes `Platforms` section, which is Mac-submission-only and now flagged as such in *Notes for Upload*.
- 2026-08-08: Tasks 1, 3, 4 complete — preconditions verified, version bumped to 1.1.0 (build 2) across all 8 configurations, EN + DE release notes authored into `appstore-metadata.md`. Task 2 half complete: security audit found Enhanced Security absent (escalated, not applied); `/appstore-review` outstanding. Task 5 blocked on a manual seed-CSV import — the simulator data container is not writable from the agent sandbox.
- 2026-08-08: Task 5 unblocked and largely executed. Michael's sandbox change removed the manual-import blocker entirely — `xcrun simctl` and simulator-container writes now work, and the iPhone carries 604 seeded records. Capture flow proven end-to-end at full 1320×2868 resolution via `simctl io` (the XcodeBuildMCP screenshot tool returns a downscaled JPEG and is unusable for App Store assets). Seven of eight iPhone shots captured and visually verified, including the two the ACs are most specific about: `07-profile-screen` shows the populated Compare Timing card at `79.5 ms ±7.1 ms`, and `08-settings-screen` shows Epic 81's piano keyboard and the Duration **slider**. Two amendments approved by Michael and recorded in the Spec Change Log: the capture set widened to all eight shots per device (shipping `02`–`05` were captured on a German-region simulator and render comma decimals under English UI, which would have shipped an internally inconsistent en-US listing), and a second unit defect — the Compare Timing **training screen** still leading with percent-of-a-sixteenth against 83.2's settled decision — was split out as story **83.6** rather than absorbed or deferred, mirroring 83.5. `06-compare-timing` is withheld until 83.6 ships. Story 83.5 flipped `review` → `done`; its second-pass review closed at `c21483ca` with the gate green.
- 2026-08-08: **Submitted.** Tasks 7–10 complete. Build `1.1.0 (2)` archived from `Peach (Release)`, uploaded, and — after a genuine ambiguity between two same-versioned archives — **verified on a physical device via TestFlight**: five disciplines under three sections, Compare Timing rendering milliseconds only. Annotated tag `v1.1.0` on `9b2bf0de`. Metadata and App Review Notes entered in App Store Connect; status **Waiting for Review**. One item recorded as reported-not-verified: whether the German locale carries its own (stale) screenshot set, which App Store Connect does not enforce at submission.
- 2026-08-08: **Correction to the entry above — sequence.** The German locale screenshots were deleted **before** submission, not after, so the submitted version already carries the corrected state and no post-submission metadata edit occurred. They were the stale 1.0.0 four-discipline set, and App Store Connect does not flag a stale localized screenshot set — only a missing one — so they would have shipped silently beneath a description promising five disciplines. German now falls back to the primary-language captures, which are English by design (story 71.3). **Worth carrying forward: the Submit gate checks that metadata is present, never that it is current.** Every "verify, don't re-author" item in this story existed for that reason, and this is the one that had actually gone stale.
