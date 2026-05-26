# Story 73.2: Upload Metadata and Screenshots

Status: review

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

- [x] Enter App Store description, subtitle, and keywords (AC: #1)
  - [x] Copy description text from Story 71.1 output into the Description field
  - [x] Copy subtitle (under 30 characters) into the Subtitle field
  - [x] Copy keywords (under 100 characters, comma-separated) into the Keywords field
  - [x] Optionally fill in Promotional Text (can be changed without a new build)
  - [x] If German localization was prepared in Story 71.1, add it via the language selector
- [x] Upload screenshots (AC: #2)
  - [x] Upload iPhone 6.9" display screenshots (required for the largest iPhone size; smaller sizes auto-scale)
  - [x] Upload iPad 13" display screenshots (required for iPad listing)
  - [x] Verify each screenshot meets Apple's resolution requirements
  - [x] Arrange screenshots in the desired display order
- [x] Set support URL (AC: #3)
  - [x] Enter the support URL (e.g., GitHub repository issues page or a dedicated support page)
  - [x] Verify the URL is publicly accessible
- [x] Set privacy policy URL (AC: #4)
  - [x] Enter the GitHub Pages privacy policy URL from Story 69.6
  - [x] Verify the URL loads correctly and displays the privacy policy
- [x] Fill in App Review information (AC: #5)
  - [x] Enter review notes from Story 71.2 (explain what the app does, how to test it, note that no login is required)
  - [x] Provide contact information: first name, last name, phone number, email
  - [x] If the app requires a demo account, note that Peach does not — it is fully offline with no account system

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
- **Screenshot upload UI quirk:** In App Store Connect, the upload zone for iPhone screenshots may appear inactive until you first select another display size in the device picker and then switch back. The picker state, not the file itself, gates the drop target.
- **App Review Notes field is mislabelled:** The "Notes" field under App Review Information shows hints suggesting it is for China-specific legal questions. It is actually the general-purpose notes field that the entire review team reads. Paste the full review notes here regardless of the hint copy.
- **iOS-only submission trimming:** Story 71.2's review notes include Mac-specific sections ("Platforms" cross-platform paragraph, "Mac menus" enumeration). For an iOS-App-Store submission, omit those sections; they belong in the Mac App Store submission (Story 74.1).

### Project Structure Notes

No code changes. All content is copied from previously prepared artifacts in Epic 71 and 69.

### References

- `docs/planning-artifacts/epics.md` — Epic 73 definition
- Story 71.1: `docs/implementation-artifacts/71-1-write-app-store-description-and-keywords.md`
- Story 69.6: defined in `docs/planning-artifacts/epics.md` (privacy policy)
- Apple docs: [App Store product page](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-your-app-s-product-page)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.7 (claude-opus-4-7)

### Debug Log References

None — manual App Store Connect work, no code or test execution.

### Completion Notes List

- **AC #1 — Metadata (EN + DE)**: English description (1,369 chars), subtitle (`Ear Training for Musicians`, 26 chars), and keywords (`pitch,intonation,interval,tuning,midi,perception,singer,choir,violin,cello`, 74 chars) copied from `docs/planning-artifacts/appstore-metadata.md` into the App Store Connect version page. German locale added via the language selector with the corresponding German strings (description 1,537 chars; subtitle `Gehörbildung für Musiker:innen`, 30 chars at the limit; keywords 75 chars). Promotional Text left empty (can be edited later without a new build).
- **AC #2 — Screenshots**: All 7 iPhone 6.9" screenshots (1320×2868) and 7 iPad 13" screenshots (2064×2752) from `marketing/screenshots/` uploaded. Order matches the filenames: start → four training disciplines (Compare Pitch, Match Pitch, Compare Intervals, Match Intervals) → profile → settings.
- **AC #3 — Support URL**: Set to `https://github.com/mschuerig/peach` (project repo; the issues page is reachable from there).
- **AC #4 — Privacy Policy URL**: Set to `https://mschuerig.github.io/peach-ios/privacy-policy` — the GitHub Pages site deployed in Story 69.6, verified live before submission.
- **AC #5 — App Review Information**: Notes from `appstore-metadata.md` pasted, with the iOS-irrelevant sections (`Platforms` cross-platform paragraph, `Mac menus`) intentionally omitted — those sections belong in the Mac App Store submission (Story 74.1). Contact info filled in (Michael Schürig + email + phone). Sign-in not required.

### Field-discovery friction (recorded as pitfalls in this story)

- App Store Connect's screenshot upload control gates the drop zone on the display-size picker state; the iPhone slot only activated after temporarily selecting another size and switching back.
- The App Review Information "Notes" field carries UI hints that suggest it is China-specific. It is actually the general-purpose review notes field — every reviewer reads it.

### File List

- `docs/implementation-artifacts/73-2-upload-metadata-and-screenshots.md` (status, tasks, Dev Agent Record, Change Log, three new pitfalls)
- `docs/implementation-artifacts/sprint-status.yaml` (status: ready-for-dev → in-progress → review; last_updated)

## Change Log

- 2026-03-29: Story created
- 2026-05-26: All metadata, screenshots, URLs, and App Review Information entered in App Store Connect. iOS-specific subset of review notes uploaded (Mac sections deferred to Story 74.1). Status → review.
