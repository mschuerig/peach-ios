# Story 73.3: Set Privacy Nutrition Labels

Status: ready-for-dev

## Story

As a **developer declaring data practices**,
I want privacy nutrition labels configured in App Store Connect,
so that users see accurate data collection disclosures.

## Acceptance Criteria

1. **Given** the App Privacy section in App Store Connect **When** completing the questionnaire **Then** "Data Not Collected" is selected.
2. **Given** the declaration **When** saved **Then** App Store Connect shows the privacy section as complete.

## Tasks / Subtasks

- [ ] Navigate to the App Privacy section in App Store Connect (AC: #1)
  - [ ] Open the app record and find "App Privacy" under the General section
- [ ] Complete the privacy questionnaire (AC: #1)
  - [ ] When asked "Do you or your third-party partners collect data from this app?", select "No, we do not collect data from this app"
- [ ] Save and verify completion (AC: #2)
  - [ ] Save the privacy declaration
  - [ ] Confirm the App Privacy section shows a green checkmark / complete status
  - [ ] Verify the public-facing label will display "No Data Collected"

## Dev Notes

This is a manual story performed entirely in App Store Connect. No code changes are involved. This is one of the simplest stories in the epic — a single questionnaire screen.

### Prerequisites

- **Story 73.1** must be complete (app record exists).
- The app must genuinely collect no data. Peach stores all training data locally on-device using SwiftData, uses no analytics SDKs, no crash reporting services, no advertising frameworks, and makes no network requests. The privacy manifest (Story 69.1) already declares `NSPrivacyCollectedDataTypes` as an empty array.

### Step-by-Step Guidance

1. In App Store Connect, navigate to "My Apps" and select Peach.
2. In the left sidebar under "General", click "App Privacy".
3. Click "Get Started" or "Edit" on the privacy questionnaire.
4. Apple will ask: "Do you or your third-party partners collect data from this app?" Select **No**.
5. Apple may ask about third-party SDKs. Peach uses no third-party SDKs that collect data (AudioKit is audio-only, local processing).
6. Save the declaration.
7. The App Privacy section should now show as complete with a "No Data Collected" summary.

### Consistency Check

The "Data Not Collected" declaration must be consistent with:
- The privacy manifest (`PrivacyInfo.xcprivacy`) from Story 69.1, which declares an empty `NSPrivacyCollectedDataTypes` array.
- The privacy policy from Story 69.6, which states no data is collected.
- The actual app behavior — no network calls, no analytics, no tracking.

Any inconsistency between these could trigger a rejection during App Store review.

### Common First-Time Pitfalls

- **Third-party SDK data collection:** If any dependency collects data (even crash logs or device info), the developer must disclose it. Peach has no such dependencies, so "No Data Collected" is correct.
- **Forgetting to save:** The questionnaire can be partially completed. Make sure to click through to the end and save.

### Project Structure Notes

No code changes. Single screen in App Store Connect.

### References

- `docs/planning-artifacts/epics.md` — Epic 73 definition
- Story 69.1: `docs/implementation-artifacts/69-1-create-privacy-manifest.md`
- Apple docs: [App privacy details](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created
