# Story 73.1: Complete App Store Connect App Record

Status: ready-for-dev

## Story

As a **developer submitting for the first time**,
I want the App Store Connect app record fully configured,
so that all required metadata is in place for submission.

## Acceptance Criteria

1. **Given** App Store Connect **When** the app record is opened **Then** the following are set: app name ("Peach"), primary language (English), primary category (Music or Education), secondary category.
2. **Given** the age rating questionnaire **When** completed **Then** the result is 4+ (all answers "None"/"No").
3. **Given** the pricing section **When** configured **Then** the app is set to Free with availability in all territories.
4. **Given** the app information section **When** reviewed **Then** copyright is set to "2026 Michael Schürig".
5. **Given** the app record pricing and availability section **When** "Universal Purchase" (or "Distribute as a universal purchase") is reviewed **Then** it is enabled, so the app appears as a single listing across iPhone, iPad, and Mac.

## Tasks / Subtasks

- [ ] Verify app record exists in App Store Connect (AC: #1)
  - [ ] Confirm bundle ID `de.schuerig.peach` is registered and linked
  - [ ] Confirm app name is set to "Peach"
  - [ ] Confirm primary language is English (U.S.)
  - [ ] Set primary category (Music or Education — choose based on best fit)
  - [ ] Set secondary category if applicable
- [ ] Complete age rating questionnaire (AC: #2)
  - [ ] Answer all content description questions with "None" or "No"
  - [ ] Verify resulting age rating shows 4+
- [ ] Configure pricing and availability (AC: #3)
  - [ ] Set price to Free (Tier 0)
  - [ ] Verify availability is set to all territories (or adjust as desired)
  - [ ] Confirm no in-app purchases are listed
- [ ] Set copyright information (AC: #4)
  - [ ] Enter "2026 Michael Schürig" in the copyright field
- [ ] Enable Universal Purchase (AC: #5)
  - [ ] In "Pricing and Availability" (or "App Information" depending on UI version), locate the "Universal Purchase" option
  - [ ] Enable it so the app is distributed as a single purchase across iPhone, iPad, and Mac
  - [ ] Verify all three platforms show under a single app listing

## Dev Notes

This is a manual story performed entirely in App Store Connect. No code changes are involved.

### Prerequisites

- **Epic 72 (TestFlight):** A minimal app record was likely created during TestFlight setup. Review what is already configured before starting — some fields may already be filled in.
- **Apple Developer account** must be active with an enrolled membership.

### Step-by-Step Guidance

1. Log in to [App Store Connect](https://appstoreconnect.apple.com/).
2. Navigate to "My Apps" and open the Peach app record.
3. Under "App Information":
   - Verify app name is "Peach" and primary language is English (U.S.).
   - Select primary category. Music fits if App Store reviewers see it as a music utility; Education fits if positioned as a learning tool. Music is likely the better primary choice.
   - Optionally set a secondary category (Education if Music is primary, or vice versa).
   - Set copyright to "2026 Michael Schürig".
4. Under "Pricing and Availability":
   - Set price schedule to Free.
   - Under availability, confirm all territories are selected.
   - Enable "Universal Purchase" (may also appear as "Distribute as a universal purchase"). This ensures the app is a single listing across iPhone, iPad, and Mac — users see one entry in search, not separate per-platform listings. This requires the same bundle ID across all platforms, which Peach already uses (`de.schuerig.peach`).
5. Under "Age Rating" (or within the app version page):
   - Complete the questionnaire. All answers should be "None" or "No" — Peach has no violent content, no mature themes, no gambling, no user-generated content, no unrestricted web access.
   - Confirm the resulting rating is 4+.

### Common First-Time Pitfalls

- **App name conflicts:** If "Peach" is taken or flagged, App Store Connect will reject it during submission. Have a backup name in mind (e.g., "Peach — Ear Training").
- **Category selection:** Changing the category after launch is possible but can affect search ranking. Choose carefully.
- **Age rating questionnaire:** Even answering one question incorrectly (e.g., saying the app accesses the unrestricted web) can raise the rating. Peach has no web views or web access, so all answers should be "None"/"No".

### Project Structure Notes

No code changes. This story is fully manual in App Store Connect.

### References

- `docs/planning-artifacts/epics.md` — Epic 73 definition
- `docs/planning-artifacts/research/technical-ios-app-store-submission-readiness-research-2026-03-09.md`
- Apple docs: [Create an app record](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app)

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created
- 2026-03-29: Added AC #5 — Enable Universal Purchase for single cross-platform listing
