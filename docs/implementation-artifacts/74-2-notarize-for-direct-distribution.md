# Story 74.2: Notarize for Direct Distribution

Status: ready-for-dev

## Story

As a **Mac user who prefers not to use the App Store**,
I want to download a notarized copy of Peach directly,
so that I can install it without macOS Gatekeeper warnings.

## Acceptance Criteria

1. **Given** the Mac app, **When** exported for "Developer ID" distribution, **Then** the app is signed with a Developer ID certificate.
2. **Given** the signed app, **When** submitted to Apple's notarization service, **Then** it is approved and stapled.
3. **Given** the notarized app, **When** a user downloads and opens it, **Then** macOS Gatekeeper allows it without security warnings.
4. **Given** the distribution artifact, **When** packaged, **Then** it is a .dmg or .zip suitable for GitHub Releases.

## Tasks / Subtasks

- [ ] Task 1: Obtain Developer ID Application certificate (AC: #1)
  - [ ] Navigate to Apple Developer > Certificates, Identifiers & Profiles
  - [ ] Create a "Developer ID Application" certificate if one does not exist
  - [ ] Install the certificate in the local Keychain
  - [ ] Verify Xcode recognizes the Developer ID certificate under Signing & Capabilities
- [ ] Task 2: Archive and export with Developer ID signing (AC: #1)
  - [ ] Select "Any Mac (Apple Silicon, Intel)" as the destination
  - [ ] Product > Archive
  - [ ] In Organizer, select the archive and click "Distribute App"
  - [ ] Choose "Direct Distribution" (Developer ID)
  - [ ] Let Xcode sign with the Developer ID Application certificate
  - [ ] Export the signed `.app` bundle to a known location
- [ ] Task 3: Submit for notarization (AC: #2)
  - [ ] Option A (Xcode): During the "Distribute App" flow, Xcode can submit for notarization automatically -- confirm this succeeds
  - [ ] Option B (CLI): Use `xcrun notarytool submit Peach.zip --apple-id <email> --team-id G3PDM6G8F8 --password <app-specific-password> --wait`
  - [ ] Verify notarization succeeds (check output or email confirmation)
  - [ ] If notarization fails, review the log: `xcrun notarytool log <submission-id>`
- [ ] Task 4: Staple the notarization ticket (AC: #2)
  - [ ] Run `xcrun stapler staple Peach.app`
  - [ ] Verify stapling succeeded: `xcrun stapler validate Peach.app`
- [ ] Task 5: Package the distribution artifact (AC: #4)
  - [ ] Create a .dmg: `hdiutil create -volname "Peach" -srcfolder Peach.app -ov -format UDZO Peach.dmg`
  - [ ] Alternatively, create a .zip: `ditto -c -k --sequesterRsrc --keepParent Peach.app Peach.zip`
  - [ ] Staple the .dmg if using that format: `xcrun stapler staple Peach.dmg`
- [ ] Task 6: Verify Gatekeeper acceptance (AC: #3)
  - [ ] Run `spctl --assess --verbose Peach.app` and confirm "accepted"
  - [ ] Copy the .dmg or .zip to a different Mac (or a different user account)
  - [ ] Open the app and verify no Gatekeeper warning dialog appears
  - [ ] Verify the app launches and functions correctly

## Dev Notes

### Prerequisites
- Apple Developer Program membership must be active
- A "Developer ID Application" certificate must be available (different from the App Store distribution certificate)
- An app-specific password is needed for `notarytool` CLI authentication (generate at appleid.apple.com > Sign-In and Security > App-Specific Passwords)
- Keychain must contain the Developer ID private key

### Step-by-step Guidance

1. **Developer ID vs. App Store signing**: These are different certificates. App Store builds use "Apple Distribution" certificates; direct distribution uses "Developer ID Application" certificates. Both can coexist.

2. **Notarization requirements**: Apple's notarization service checks that the app is signed with a Developer ID, uses Hardened Runtime, and does not contain known malware. Hardened Runtime should already be enabled from the Xcode project settings.

3. **App-specific password**: The `notarytool` CLI requires authentication. Use an app-specific password (not your Apple ID password). Store it in the Keychain for convenience: `xcrun notarytool store-credentials "peach-notarize" --apple-id <email> --team-id G3PDM6G8F8 --password <app-specific-password>`. Then use `--keychain-profile "peach-notarize"` instead of inline credentials.

4. **DMG vs ZIP**: A .dmg provides a nicer installation experience (drag to Applications), while a .zip is simpler. Both work for GitHub Releases. If using .dmg, staple it separately after creating it.

5. **Notarization time**: Notarization typically takes 5-15 minutes but can take longer. The `--wait` flag on `notarytool submit` blocks until completion.

### References
- [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [xcrun notarytool](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created
