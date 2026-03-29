# Story 73.2: Upload Metadata and Screenshots

Status: ready-for-dev

## Story

As a **developer completing the App Store listing**,
I want all metadata and screenshots uploaded to App Store Connect,
so that the listing is complete and ready for review.

## Acceptance Criteria

1. **Given** the App Store version page **When** metadata is entered **Then** description, subtitle, keywords, and promotional text from Story 71.1 are filled in.
2. **Given** the screenshots section **When** screenshots are uploaded **Then** iPhone 6.9" and iPad 13" screenshots from Story 71.3 are present.
3. **Given** the support URL field **When** filled in **Then** it points to a working URL.
4. **Given** the privacy policy URL field **When** filled in **Then** it points to the live GitHub Pages privacy policy from Story 69.6.
5. **Given** the App Review information section **When** filled in **Then** review notes from Story 71.2 are entered and contact information is provided.

## Tasks / Subtasks

- [ ] Enter App Store description, subtitle, and keywords (AC: #1)
  - [ ] Copy description text from Story 71.1 output into the Description field
  - [ ] Copy subtitle (under 30 characters) into the Subtitle field
  - [ ] Copy keywords (under 100 characters, comma-separated) into the Keywords field
  - [ ] Optionally fill in Promotional Text (can be changed without a new build)
  - [ ] If German localization was prepared in Story 71.1, add it via the language selector
- [ ] Upload screenshots (AC: #2)
  - [ ] Upload iPhone 6.9" display screenshots (required for the largest iPhone size; smaller sizes auto-scale)
  - [ ] Upload iPad 13" display screenshots (required for iPad listing)
  - [ ] Verify each screenshot meets Apple's resolution requirements
  - [ ] Arrange screenshots in the desired display order
- [ ] Set support URL (AC: #3)
  - [ ] Enter the support URL (e.g., GitHub repository issues page or a dedicated support page)
  - [ ] Verify the URL is publicly accessible
- [ ] Set privacy policy URL (AC: #4)
  - [ ] Enter the GitHub Pages privacy policy URL from Story 69.6
  - [ ] Verify the URL loads correctly and displays the privacy policy
- [ ] Fill in App Review information (AC: #5)
  - [ ] Enter review notes from Story 71.2 (explain what the app does, how to test it, note that no login is required)
  - [ ] Provide contact information: first name, last name, phone number, email
  - [ ] If the app requires a demo account, note that Peach does not — it is fully offline with no account system

## Dev Notes

This is a manual story performed entirely in App Store Connect. No code changes are involved. All content should already be prepared from Epic 71 stories.

### Prerequisites

- **Story 73.1** must be complete (app record configured).
- **Story 71.1** must be complete (description, subtitle, keywords prepared).
- **Story 71.2** must be complete (App Review notes prepared).
- **Story 71.3** must be complete (screenshots captured).
- **Story 69.6** must be complete (privacy policy hosted on GitHub Pages).

### Step-by-Step Guidance

1. In App Store Connect, navigate to the app version page (e.g., version 1.0).
2. Under "App Store Localization" for English (U.S.):
   - Paste the description, subtitle, and keywords from Story 71.1 artifacts.
   - Promotional text is optional and can be updated post-launch without a new build — useful for highlighting features or seasonal messaging.
3. Under "Screenshots":
   - Upload iPhone 6.9" screenshots. Apple requires at least one screenshot set for the largest device class; smaller sizes can reuse them.
   - Upload iPad 13" screenshots. Required separately since iPhone screenshots do not scale to iPad.
   - Apple accepts PNG or JPEG. Ensure no alpha channel and correct resolution.
4. Under "General App Information":
   - Set the Support URL. The GitHub repository URL or issues page works. Must be publicly accessible.
   - Set the Privacy Policy URL to the GitHub Pages URL from Story 69.6.
5. Under "App Review Information":
   - Paste the review notes from Story 71.2.
   - Fill in the contact details (name, phone, email). Apple may contact the developer if they have questions during review.
   - Sign-in information: Select "Sign-in is not required" — Peach has no user accounts.

### Common First-Time Pitfalls

- **Screenshot resolution mismatch:** Screenshots must exactly match the required pixel dimensions for each device class. Using the wrong simulator device for capture will produce incorrect sizes.
- **Description character limit:** 4,000 characters max. If the prepared description exceeds this, trim secondary details.
- **Subtitle character limit:** 30 characters max. App Store Connect will reject longer subtitles.
- **Keywords:** 100 characters max, comma-separated. Do not repeat words already in the app name or subtitle — Apple indexes those separately.
- **Privacy policy URL must be live:** If GitHub Pages deployment from Story 69.6 is not yet active, the URL will 404 and submission will be blocked.
- **Missing iPad screenshots:** Even if the app is primarily an iPhone app, iPad screenshots are required for Universal apps.

### Project Structure Notes

No code changes. All content is copied from previously prepared artifacts in Epic 71 and 69.

### References

- `docs/planning-artifacts/epics.md` — Epic 73 definition
- Story 71.1: `docs/implementation-artifacts/71-1-write-app-store-description-and-keywords.md`
- Story 69.6: defined in `docs/planning-artifacts/epics.md` (privacy policy)
- Apple docs: [App Store product page](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-your-app-s-product-page)

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created
