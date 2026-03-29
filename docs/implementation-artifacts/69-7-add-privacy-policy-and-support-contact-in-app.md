# Story 69.7: Add Privacy Policy and Support Contact In-App

Status: ready-for-dev

## Story

As a **user wanting to know how their data is handled**,
I want to see a privacy policy link and a support contact on the Info screen,
so that I can review the policy and reach the developer if needed.

## Acceptance Criteria

1. **Given** the Info screen **When** displayed **Then** it shows a tappable link to the hosted privacy policy URL.
2. **Given** the Info screen **When** displayed **Then** it shows a support contact method (email link or support URL).
3. **Given** the privacy policy link **When** tapped **Then** it opens the privacy policy in the system browser.
4. **Given** the support contact **When** tapped **Then** it opens the mail client or system browser as appropriate.
5. **Given** the Info screen **When** viewed in German locale **Then** the labels for the privacy policy and support links are localized.

## Tasks / Subtasks

- [ ] Add privacy policy URL constant to `InfoScreen.swift` (AC: #1, #3)
  - [ ] Use the URL from story 69-6 (e.g., `https://mschuerig.github.io/peach/privacy-policy`)
  - [ ] Follow the existing pattern: `static let` with `URL(string:)` and `preconditionFailure` guard (see `gitHubURL`)
- [ ] Add support contact constant (AC: #2, #4)
  - [ ] Email link using `mailto:` URL scheme, or a support page URL
  - [ ] Follow same `static let` pattern as `gitHubURL`
- [ ] Add links to the header section of `InfoScreen.swift` (AC: #1, #2)
  - [ ] Add `Link(String(localized: "Privacy Policy"), destination: Self.privacyPolicyURL)` after existing GitHub link
  - [ ] Add `Link(String(localized: "Support"), destination: Self.supportURL)` (for email: `mailto:` URL)
  - [ ] Style consistently with existing `Link` for GitHub (`.font(.caption)`)
- [ ] Add German translations (AC: #5)
  - [ ] Use `bin/add-localization.swift` to add translations for "Privacy Policy" and "Support" (or "Contact")
  - [ ] German: "Datenschutz" for privacy policy, "Kontakt" or "Support" for support
- [ ] Build both platforms: `bin/build.sh && bin/build.sh -p mac` (AC: #1-#4)
- [ ] Run tests: `bin/test.sh && bin/test.sh -p mac`

## Dev Notes

**Dependency**: This story depends on story 69-6 for the privacy policy URL. If 69-6 is not yet complete, use a placeholder URL and update when available.

The existing `InfoScreen.swift` header section (lines 74-95) already has a `Link` to GitHub. The new links should follow the same pattern and be placed logically — privacy policy and support below the GitHub link.

Current header layout:
1. App name (largeTitle)
2. Version (caption)
3. Copyright (caption)
4. License (caption)
5. GitHub link (caption)
6. **NEW: Privacy Policy link (caption)**
7. **NEW: Support contact link (caption)**

For the `mailto:` link, use `URL(string: "mailto:someone@example.com")` — SwiftUI `Link` handles this correctly on both iOS and macOS, opening the default mail client.

### Project Structure Notes

- `Peach/Info/InfoScreen.swift` — add static URL constants and Link views
- `Peach/Resources/Localizable.xcstrings` — add German translations via `bin/add-localization.swift`

### References

- `docs/reports/appstore-review-2026-03-28.md` — Critical: Guideline 5.1.1(i), Warning: Guideline 1.5
- `Peach/Info/InfoScreen.swift` — current implementation
- Story 69-6 — provides the privacy policy URL

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created
