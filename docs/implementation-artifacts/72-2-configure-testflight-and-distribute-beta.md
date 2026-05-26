# Story 72.2: Configure TestFlight and Distribute Beta

Status: review

## Story

As a **developer**,
I want to configure TestFlight and distribute the beta to testers,
so that real users can install and exercise Peach before public release.

## Acceptance Criteria

1. **Given** the processed build, **When** configuring TestFlight, **Then** beta test information is filled in (what to test, contact email).
2. **Given** TestFlight configuration, **When** adding internal testers, **Then** at least one tester is invited and receives the invitation.
3. **Given** a tester, **When** they open the TestFlight link, **Then** they can install and launch Peach.
4. **Given** external testers (optional), **When** a public TestFlight link is created, **Then** up to 10,000 users can join.

## Tasks / Subtasks

- [x] Task 1: Fill in beta test information (AC: #1)
  - [x] Navigate to App Store Connect > Apps > Peach Ear Trainer > TestFlight
  - [x] Enter "What to Test" description on the build (per-build field under "Test Details")
  - [x] Enter feedback email address (`michael@schuerig.de`) on the app-level "Test Information" page
  - [x] Optionally add a privacy policy URL and marketing URL (user's discretion at save time)
  - [x] Set beta app description if prompted (License Agreement left blank → Apple Standard EULA applies)
- [x] Task 2: Configure internal testing group (AC: #2)
  - [x] Create an internal testing group "Peach Internal"
  - [x] Add the processed build (1.0.0 build 1) to the group
  - [x] Add at least one internal tester (Michael, as account holder, has implicit Tester access)
  - [x] Verify the tester receives an email invitation (received at `michael@schuerig.de` from `noreply@email.apple.com`)
- [x] Task 3: Verify tester can install and launch (AC: #3)
  - [x] Tester opens the TestFlight invitation email or link
  - [x] Tester installs the TestFlight app (if not already installed)
  - [x] Tester accepts the beta invitation in TestFlight
  - [x] Tester installs Peach from TestFlight on iPhone
  - [x] Tester launches Peach and confirms it opens to the start screen (no crash; look and behavior as expected)
- [ ] Task 4: Configure external testing (optional) (AC: #4) — **Deferred** per user decision; this story scoped to internal testing only. AC #4 is labelled optional in the story spec and is not blocking. May be addressed in a follow-up story before App Store submission if a wider beta is desired.
  - [ ] Create an external testing group (e.g., "Peach Public Beta")
  - [ ] Add the build to the external group
  - [ ] Submit the build for Beta App Review
  - [ ] Wait for Beta App Review approval (typically < 24 hours)
  - [ ] Enable public link for the external group
  - [ ] Copy and save the public TestFlight link for distribution

## Dev Notes

### Prerequisites
- Story 72.1 must be complete (build uploaded and processed in App Store Connect)
- At least one Apple ID available for internal testing

### Step-by-step Guidance

1. **Internal vs. external testers**:
   - Internal testers: Must be App Store Connect users on your team (up to 100). No review required. Builds are available immediately.
   - External testers: Anyone with an Apple ID (up to 10,000). Requires Beta App Review for the first build of each new version.

2. **"What to Test" text**: Keep it specific and actionable. Example:
   - "Please test the ear training flow: start a session, complete at least 5 comparisons, and check your profile screen. Report any crashes, audio issues, or confusing UI."

3. **Internal tester setup**: Internal testers must have an App Store Connect role. If testing with your own account, you are automatically eligible. The invitation arrives as an email with a link that opens TestFlight.

4. **Beta App Review for external testers**: The first submission for external testing triggers a review. This is lighter than full App Store review but still checks for crashes, broken functionality, and guideline violations. Approval typically takes less than 24 hours.

5. **Public link considerations**: A public TestFlight link lets anyone join without an explicit invitation. Consider whether you want open access or a controlled group at this stage. You can disable the link at any time.

6. **Common issues**:
   - "Build not available for testing" -- check that the build has finished processing and that export compliance is resolved
   - Tester does not receive email -- check spam folder; alternatively, share the TestFlight link directly
   - "This beta is no longer accepting testers" -- the public link may be disabled or the tester limit reached

### Project Structure Notes
### References

- [TestFlight overview](https://developer.apple.com/testflight/)
- [App Store Connect Help: TestFlight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview)

## Dev Agent Record

### Agent Model Used

claude-opus-4-7

### Debug Log References

None — story is configuration-only (App Store Connect web UI + TestFlight on a device); no code or tests touched.

### Completion Notes List

- 2026-05-26: Story is non-engineering — all work is in App Store Connect's web UI and on a tester's device. Dev's role this session was to draft the "What to Test" copy, guide the user through each App Store Connect / TestFlight step, and record completion.
- 2026-05-26: **Test Information page** (app-level, applies to every build): feedback email set to `michael@schuerig.de`; License Agreement left blank, so Apple's Standard EULA applies (correct choice — a free pitch-training app with no accounts and no data leaving the device does not need a custom EULA; "MIT License" as a string would have been invalid, since that field expects the literal EULA text, and MIT is a source-code license not an end-user agreement). Privacy Policy URL / Marketing URL / Beta App Description handled at user's discretion at save time.
- 2026-05-26: **"What to Test"** text drafted in English and pasted on the build (per-build field under "Test Details", not app-level). Covers: four pitch disciplines, audio behavior, training flow, Settings live-update, Profile chart updates, interruptions (call/lock/app-switch), accessibility (VoiceOver / Dynamic Type / Voice Control), localization (en/de), CSV export-import. Notes limitations: iPhone+iPad only (no macOS in this TestFlight), two timing-based disciplines hidden per Epic 76 build gate. Direct contact line: `michael@schuerig.de`. Important: this field does not carry forward to future builds and must be re-entered for each upload.
- 2026-05-26: **Internal testing group "Peach Internal"** created. Recommended enabling "automatic distribution" so future builds auto-attach. Tester added: Michael (account holder). Build 1.0.0 (1) distributed.
- 2026-05-26: **Invitation email** received at `michael@schuerig.de` from `noreply@email.apple.com`. Peach installed via TestFlight on iPhone. App launches without crash; opens to the start screen with the four pitch disciplines visible; look and behavior as expected versus dev builds (icon, "Peach" home-screen name via CFBundleDisplayName per 72.1, no missing assets).
- 2026-05-26: AC #1, #2, #3 satisfied. AC #4 (external testing / public link) deferred per user decision — explicitly labelled optional in the story spec; revisit before App Store submission if a wider beta is desired.

### File List

No source files modified. Story is App Store Connect / TestFlight configuration only.

External / non-file artifacts:

- App Store Connect → TestFlight → **Test Information** (app-level) configured: feedback email `michael@schuerig.de`; License Agreement → Apple Standard EULA (field left blank).
- App Store Connect → TestFlight → **Build 1.0.0 (1)** "Test Details" → **What to Test** populated (English).
- App Store Connect → TestFlight → **Internal Testing → "Peach Internal"** group created; build 1.0.0 (1) distributed; tester Michael (account holder) added; invitation delivered; install + launch verified on iPhone.

## Change Log

- 2026-03-29: Story created
- 2026-05-26: Test Information configured in App Store Connect (feedback email, default Apple EULA); "What to Test" English copy added to build 1.0.0 (1); internal group "Peach Internal" created and tester added.
- 2026-05-26: Invitation email received; Peach installed via TestFlight on iPhone; launches to start screen as expected. AC #1, #2, #3 satisfied; AC #4 deferred per user decision (external testing out of scope for this story). Status → review.
