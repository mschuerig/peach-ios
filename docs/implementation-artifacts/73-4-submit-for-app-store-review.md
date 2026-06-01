# Story 73.4: Submit for App Store Review

Status: done

## Story

As a **developer launching Peach**,
I want to submit the app for Apple's review,
so that it can be approved and published on the App Store.

## Acceptance Criteria

1. **Given** App Store Connect **When** all sections show green checkmarks **Then** the "Submit for Review" button is enabled.
2. **Given** submission **When** confirmed **Then** the app status changes to "Waiting for Review."
3. **Given** App Store review **When** feedback is received **Then** if approved, the app goes live. If rejected, the rejection reason is documented and addressed.

## Tasks / Subtasks

- [x] Pre-submission checklist (AC: #1)
  - [x] Verify app record is complete (Story 73.1): name, category, age rating, pricing, copyright
  - [x] Verify metadata and screenshots are uploaded (Story 73.2): description, subtitle, keywords, screenshots, support URL, privacy policy URL, review notes
  - [x] Verify privacy nutrition labels are set (Story 73.3): "No Data Collected"
  - [x] Verify a valid build is selected for the version (from Epic 72 TestFlight or a newer upload)
  - [x] Confirm all sections in the version page show green checkmarks
  - [x] Verify the "Submit for Review" button is enabled
- [x] Configure release options (AC: #2)
  - [x] Choose release method: "Automatically release this version" or "Manually release this version"
  - [x] If manual release is preferred, select that option (allows controlling exactly when the app goes live after approval)
- [x] Submit for review (AC: #2)
  - [x] Click "Submit for Review"
  - [x] Confirm any final declarations (e.g., content rights, advertising identifier usage — select "No" for IDFA)
  - [x] Verify the app status changes to "Waiting for Review"
- [x] Monitor review progress (AC: #3)
  - [x] Check App Store Connect periodically for status changes
  - [x] If status changes to "In Review", no action needed — wait for outcome
  - [x] If approved: confirm the app is live on the App Store (or release manually if that option was chosen)
  - [x] ~~If rejected~~ — not exercised; Apple approved on first submission

## Dev Notes

This is a manual story. The actual submission is a single button click, but the preparation and follow-up are important.

### Prerequisites

- **Story 73.1** must be complete (app record fully configured).
- **Story 73.2** must be complete (metadata and screenshots uploaded).
- **Story 73.3** must be complete (privacy nutrition labels set).
- **Epic 72** must be complete (a valid build has been uploaded and processed by App Store Connect).
- All prior epics (69, 70, 71) must be complete — they provide the technical compliance, build pipeline, and content that this story depends on.

### Step-by-Step Guidance

1. In App Store Connect, navigate to the app version page.
2. Review each section. Every section should show a green checkmark:
   - App Information (name, category, age rating, copyright)
   - Pricing and Availability
   - App Privacy
   - Version Information (description, screenshots, keywords, etc.)
   - Build (a processed build must be selected)
   - App Review Information (contact info, review notes)
3. Under "Version Release", choose the release method:
   - **Automatic:** The app goes live as soon as Apple approves it. Simplest option.
   - **Manual:** The developer must click "Release" after approval. Useful if timing the launch to coincide with marketing or other events.
4. Click "Submit for Review".
5. Apple will ask a few final questions:
   - Content rights: Confirm you have the rights to all content.
   - Advertising identifier (IDFA): Select "No" — Peach does not use the advertising identifier.
6. Confirm the submission. Status should change to "Waiting for Review."

### What to Expect

- **Review timeline:** Apple typically reviews within 24-48 hours, though first-time submissions or apps from new developer accounts may take longer.
- **Status progression:** Waiting for Review -> In Review -> (Approved or Rejected).
- **Communication:** Apple sends email notifications for status changes. Check the developer email registered with the Apple Developer account.

### If Rejected

Common rejection reasons for first-time apps and how to address them:

- **Guideline 2.1 — App Completeness:** The app must feel finished. Ensure all screens are functional, no placeholder content remains, and no debug UI is visible.
- **Guideline 2.3 — Accurate Metadata:** Screenshots must reflect actual app functionality. Description must match what the app does.
- **Guideline 5.1.1 — Data Collection and Storage:** Privacy declarations must match actual behavior. Peach collects no data, which is straightforward.
- **Guideline 4.0 — Design:** The app must meet basic quality standards. With SwiftUI and Liquid Glass on iOS 26, this should not be an issue.
- **Bug or crash during review:** If the reviewer encounters a crash, the app will be rejected. Ensure the build selected has been tested thoroughly via TestFlight (Epic 72).

If rejected, the rejection notice in the Resolution Center will cite the specific guideline. Fix the issue, upload a new build via the archive pipeline (Epic 70), select it in the version page, and resubmit.

### Project Structure Notes

No code changes unless a rejection requires a fix. In that case, the fix would go through the normal development process: code change, tests, build, archive, upload, resubmit.

### References

- `docs/planning-artifacts/epics.md` — Epic 73 definition
- `docs/planning-artifacts/research/technical-ios-app-store-submission-readiness-research-2026-03-09.md`
- `docs/reports/appstore-review-2026-03-28.md`
- Apple docs: [Submit for review](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-for-review)
- Apple docs: [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

## Dev Agent Record

### Agent Model Used

claude-opus-4-7

### Debug Log References

### Completion Notes List

- **Submission complete.** Peach 1.0.0 (build 1) submitted to Apple for App Store review on 2026-05-26. App Store Connect status: "Waiting for Review" ("Warten auf Prüfung" in localized UI).
- **Release method:** Automatic — app will go live on the App Store immediately upon Apple's approval.
- **Pre-submission verification:** All sections on the version page showed green checkmarks (App Information, Pricing and Availability, App Privacy nutrition labels from 73.3, Version Information with description/keywords/screenshots from 73.2, processed build from Epic 72, App Review Information with reviewer notes from 71.2). "Submit for Review" button was enabled (AC #1).
- **Final declarations confirmed at submission:** Content Rights — Yes (rights to all content); Advertising Identifier (IDFA) — No. Export Compliance pre-declared via `ITSAppUsesNonExemptEncryption = NO` (Story 69.2), no additional prompt.
- **No code changes.** Manual story executed entirely in App Store Connect web UI.
- **AC #3 — approved on first submission.** Apple approved Peach 1.0.0 without rejection. The app is live on the App Store: https://apps.apple.com/de/app/peach-geh%C3%B6rtrainer/id6773384465 (App ID 6773384465, localized title "Peach Gehörtrainer" on the German storefront). Conditional "If rejected" subtask was not exercised.
- **Epic 73 leftover housekeeping** completed in commit `518e17c0` (closed epic 69: 69-3 wont-do, 69-4 done, epic-69 done).

### File List

- `docs/implementation-artifacts/73-4-submit-for-app-store-review.md` (status, task checkboxes, completion notes, change log)
- `docs/implementation-artifacts/sprint-status.yaml` (story status: ready-for-dev → in-progress → review; last_updated)

## Change Log

- 2026-03-29: Story created
- 2026-05-26: Submitted Peach 1.0.0 (build 1) to Apple App Store review with automatic release method. App Store Connect status: "Waiting for Review".
- 2026-06-01: Apple approved on first submission. Peach 1.0.0 is live on the App Store at https://apps.apple.com/de/app/peach-geh%C3%B6rtrainer/id6773384465 (App ID 6773384465). All ACs satisfied. Story closed as done.
