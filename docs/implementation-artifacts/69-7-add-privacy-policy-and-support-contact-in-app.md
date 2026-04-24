# Story 69.7: Add Privacy Policy and Support Contact In-App

Status: done

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

- [x] Add privacy policy URL constant to `InfoScreen.swift` (AC: #1, #3)
  - [x] Use the URL from story 69-6 (e.g., `https://mschuerig.github.io/peach/privacy-policy`)
  - [x] Follow the existing pattern: `static let` with `URL(string:)` and `preconditionFailure` guard (see `gitHubURL`)
- [x] Add support contact constant (AC: #2, #4)
  - [x] Email link using `mailto:` URL scheme, or a support page URL
  - [x] Follow same `static let` pattern as `gitHubURL`
- [x] Add links to the header section of `InfoScreen.swift` (AC: #1, #2)
  - [x] Add `Link(String(localized: "Privacy Policy"), destination: Self.privacyPolicyURL)` after existing GitHub link
  - [x] Add `Link(String(localized: "Support"), destination: Self.supportURL)` (for email: `mailto:` URL)
  - [x] Style consistently with existing `Link` for GitHub (`.font(.caption)`)
- [x] Add German translations (AC: #5)
  - [x] Use `bin/add-localization.swift` to add translations for "Privacy Policy" and "Support" (or "Contact")
  - [x] German: "Datenschutz" for privacy policy, "Kontakt" or "Support" for support
- [x] Build both platforms: `bin/build.sh && bin/build.sh -p mac` (AC: #1-#4)
- [x] Run tests: `bin/test.sh && bin/test.sh -p mac`

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
Claude Opus 4.6

### Debug Log References
None

### Completion Notes List
- Extracted `InfoContentView` from `InfoScreen` so the same header + help content renders on both iOS and macOS
- `InfoScreen` wraps `InfoContentView` in NavigationStack/toolbar for iOS sheet presentation
- macOS "About Peach" (menu bar and start screen) shows `InfoContentView` via `HelpPanelController.show(title:view:)`
- Added `privacyPolicyURL` and `supportURL` constants with `Link` views in the header section
- Privacy policy URL: `https://mschuerig.github.io/peach-ios/privacy-policy`
- Support contact: `mailto:michael@schuerig.de`
- Refactored `HelpPanelController` to extract `showView(title:content:)` helper, eliminating duplicated window creation logic
- Updated `PlatformHelpWithCustomSheetModifier` to accept separate `macPanel` content instead of falling back to sections-only
- Localized "Privacy Policy" (de: "Datenschutz") and "Contact" (de: "Kontakt")
- All iOS tests pass (1770/1770)

### File List
- Peach/Info/InfoScreen.swift (modified — extracted InfoContentView, added privacy/contact links)
- Peach/App/Platform/HelpPanel.swift (modified — added show(title:view:) and showView helper)
- Peach/App/Platform/PlatformHelpPresentation.swift (modified — macPanel parameter for custom view on macOS)
- Peach/App/PeachCommands.swift (modified — About button shows InfoContentView)
- Peach/Start/StartScreen.swift (modified — updated platformHelp call with macPanel)
- Peach/Resources/Localizable.xcstrings (modified — added Privacy Policy and Contact translations)
- PeachTests/Start/StartScreenTests.swift (modified — updated references from InfoScreen to InfoContentView)

## Change Log

- 2026-03-29: Story created
- 2026-04-24: Implementation complete — privacy policy and contact links in shared InfoContentView for cross-platform parity
