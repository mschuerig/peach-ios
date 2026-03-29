# Story 73.4: Submit for App Store Review

Status: ready-for-dev

## Story

As a **developer launching Peach**,
I want to submit the app for Apple's review,
so that it can be approved and published on the App Store.

## Acceptance Criteria

1. **Given** App Store Connect **When** all sections show green checkmarks **Then** the "Submit for Review" button is enabled.
2. **Given** submission **When** confirmed **Then** the app status changes to "Waiting for Review."
3. **Given** App Store review **When** feedback is received **Then** if approved, the app goes live. If rejected, the rejection reason is documented and addressed.

## Tasks / Subtasks

- [ ] Pre-submission checklist (AC: #1)
  - [ ] Verify app record is complete (Story 73.1): name, category, age rating, pricing, copyright
  - [ ] Verify metadata and screenshots are uploaded (Story 73.2): description, subtitle, keywords, screenshots, support URL, privacy policy URL, review notes
  - [ ] Verify privacy nutrition labels are set (Story 73.3): "No Data Collected"
  - [ ] Verify a valid build is selected for the version (from Epic 72 TestFlight or a newer upload)
  - [ ] Confirm all sections in the version page show green checkmarks
  - [ ] Verify the "Submit for Review" button is enabled
- [ ] Configure release options (AC: #2)
  - [ ] Choose release method: "Automatically release this version" or "Manually release this version"
  - [ ] If manual release is preferred, select that option (allows controlling exactly when the app goes live after approval)
- [ ] Submit for review (AC: #2)
  - [ ] Click "Submit for Review"
  - [ ] Confirm any final declarations (e.g., content rights, advertising identifier usage — select "No" for IDFA)
  - [ ] Verify the app status changes to "Waiting for Review"
- [ ] Monitor review progress (AC: #3)
  - [ ] Check App Store Connect periodically for status changes
  - [ ] If status changes to "In Review", no action needed — wait for outcome
  - [ ] If approved: confirm the app is live on the App Store (or release manually if that option was chosen)
  - [ ] If rejected: document the rejection reason, address the cited issues, upload a new build if needed, and resubmit

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
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created
