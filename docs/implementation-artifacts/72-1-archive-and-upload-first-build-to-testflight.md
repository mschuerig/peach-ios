# Story 72.1: Archive and Upload First Build to TestFlight

Status: review

## Story

As a **developer**,
I want to archive the app and upload the first build to TestFlight,
so that the binary is processed by Apple and ready for beta distribution.

## Acceptance Criteria

1. **Given** the Xcode project with all Epic 69 fixes applied, **When** archived for "Any iOS Device (arm64)" via Product > Archive, **Then** the archive succeeds without errors.
2. **Given** the archive, **When** distributed via "TestFlight & App Store" > Upload, **Then** the upload succeeds and Apple sends a processing confirmation email.
3. **Given** the uploaded build, **When** viewed in App Store Connect, **Then** it shows as processed with no "Missing Compliance" warning.

## Tasks / Subtasks

- [x] Task 1: Prepare App Store Connect app record (AC: #1, #2)
  - [x] Log into App Store Connect (appstoreconnect.apple.com)
  - [x] Create new app record: bundle ID `de.schuerig.peach`, app name **"Peach Ear Trainer"** (the bare "Peach" was already taken), primary language English (U.S.)
  - [x] Choose an available SKU (e.g., `peach-ios-1`)
  - [x] Verify Team ID G3PDM6G8F8 is selected
- [x] Task 2: Verify Xcode project signing and build settings (AC: #1)
  - [x] Confirm bundle identifier is `de.schuerig.peach`
  - [x] Confirm "Automatically manage signing" is enabled with Team G3PDM6G8F8
  - [x] Confirm all Epic 69 compliance fixes are present in the binary (privacy manifest, export compliance, etc.)
  - [x] Set marketing version and build number (e.g., 1.0.0 build 1)
- [x] Task 3: Create the archive (AC: #1)
  - [x] Select "Any iOS Device (arm64)" as the destination
  - [x] Product > Archive
  - [x] Verify archive completes without errors or warnings
  - [x] Confirm archive appears in the Organizer window
- [x] Task 4: Upload to App Store Connect (AC: #2)
  - [x] In Organizer, select the archive and click "Distribute App" (Validate App was run first as a dry-run; passed)
  - [x] Choose "TestFlight & App Store" distribution method
  - [x] Let Xcode manage signing (automatic)
  - [x] Click Upload and wait for completion
  - [x] Verify Xcode shows "Upload Successful"
  - [x] Wait for Apple processing (build appeared in TestFlight with "Bereit zur Übermittlung"; Apple no longer sends a processing-complete email for most accounts)
- [x] Task 5: Verify processed build in App Store Connect (AC: #3)
  - [x] Navigate to App Store Connect > Apps > Peach Ear Trainer > TestFlight
  - [x] Confirm the build appears with status "Bereit zur Übermittlung" / "Ready to Submit"
  - [x] Verify no "Missing Compliance" warning (Epic 69's `ITSAppUsesNonExemptEncryption=NO` handled it)
  - [x] If "Missing Compliance" appears, set export compliance information manually (not needed)

## Dev Notes

### Prerequisites
- Apple Developer Program membership must be active
- All Epic 69 compliance fixes must be merged and present in the working tree
- Xcode must be signed in with the Apple ID associated with Team G3PDM6G8F8

### Step-by-step Guidance

1. **App Store Connect record**: The app record must exist before uploading. Minimal information is needed at this stage -- just bundle ID, name, and SKU. The full App Store listing (screenshots, description) is not required for TestFlight.

2. **Archive destination**: "Any iOS Device (arm64)" is required. You cannot archive while a simulator is selected. If this destination is missing, check that the deployment target and supported architectures are correct.

3. **Common upload failures**:
   - "No accounts with App Store Connect access" -- sign into Xcode with the correct Apple ID under Settings > Accounts
   - "No matching provisioning profile" -- enable automatic signing and ensure the bundle ID matches the App Store Connect record
   - "Invalid binary" -- usually means the Info.plist is missing required keys (privacy descriptions, export compliance)
   - "Build already exists" -- increment the build number

4. **Processing time**: After upload, Apple processes the build (typically 15-30 minutes). You will receive an email. If the build does not appear after 1 hour, check for processing errors in App Store Connect under Activity.

5. **Missing Compliance warning**: If Epic 69 correctly set `ITSAppUsesNonExemptEncryption = NO` in the Info.plist, this warning should not appear. If it does, you can resolve it manually in App Store Connect by answering the export compliance questions.

### Project Structure Notes
### References

- [Distributing your app for beta testing and releases](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)
- [App Store Connect Help: Add a new app](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app)

## Dev Agent Record

### Agent Model Used

claude-opus-4-7

### Debug Log References
### Completion Notes List

- 2026-05-26: Task 2 verified via static inspection of `Peach.xcodeproj/project.pbxproj`:
  - `PRODUCT_BUNDLE_IDENTIFIER = de.schuerig.peach` (app target)
  - `CODE_SIGN_STYLE = Automatic`, `DEVELOPMENT_TEAM = G3PDM6G8F8`
  - Epic 69 compliance present: `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`, `Peach/Resources/PrivacyInfo.xcprivacy` declares UserDefaults (CA92.1) + SystemBootTime (35F9.1) API reasons, no tracking
- 2026-05-26: Bumped `MARKETING_VERSION` from `1.0` to `1.0.0` across all 8 build configurations (Debug/Release × app target/Tests/macOS variants); `CURRENT_PROJECT_VERSION` (build number) remains `1`
- 2026-05-26: App Store Connect name "Peach" was already taken. Decided on App Store name **"Peach Ear Trainer"** (set via App Store Connect web UI when creating the app record). Added `INFOPLIST_KEY_CFBundleDisplayName = Peach` to all 4 app-target build configurations so the home-screen label under the icon stays "Peach"
- 2026-05-26: App Store Connect record created (iOS platform only; macOS deferred to a later epic). SKU `peach-ios-1`. Bundle ID dropdown surfaced `de.schuerig.peach` correctly (App ID was already registered via automatic signing)
- 2026-05-26: First archive attempt under `Peach (Debug)` scheme; Validate App rejected with "Upload Symbols Failed — archive did not include a dSYM for Peach.app". Root cause: the project uses one scheme per configuration (`Peach (Debug)`, `Peach (Debug, Research)`, `Peach (Release)`, `Peach (Release, Research)`) and Archive uses the configuration wired into the selected scheme. Debug config has `DEBUG_INFORMATION_FORMAT = dwarf` (no dSYM); Release has `dwarf-with-dsym`. Resolution: re-archive under `Peach (Release)`. No project edits required — the scheme choice was the only issue
- 2026-05-26: Second archive (under `Peach (Release)`): clean build folder, fresh archive, Validate App passed, Distribute App uploaded successfully. App Store Connect → TestFlight shows the build as "Bereit zur Übermittlung" with no Missing Compliance warning, expires 2026-08-24 (90 days from upload)
- 2026-05-26: Git artifact: annotated tag `v1.0.0` (commit d5e03e0) marks the source state archived as build 1

### File List

- `Peach.xcodeproj/project.pbxproj` — `MARKETING_VERSION` bumped to `1.0.0`; `INFOPLIST_KEY_CFBundleDisplayName = Peach` added to all 4 app-target configs

External / non-file artifacts:

- App Store Connect app record created: name "Peach Ear Trainer", bundle ID `de.schuerig.peach`, SKU `peach-ios-1`, iOS platform
- TestFlight build 1 of 1.0.0 uploaded, processed, status "Bereit zur Übermittlung" / "Ready to Submit"
- Git tag `v1.0.0` (annotated) at commit d5e03e0

## Change Log

- 2026-03-29: Story created
- 2026-05-26: Task 2 complete; MARKETING_VERSION bumped to 1.0.0
- 2026-05-26: App Store Connect name "Peach" taken; switched to "Peach Ear Trainer" for the App Store, kept "Peach" as home-screen display name via CFBundleDisplayName
- 2026-05-26: All ACs satisfied; build 1 of 1.0.0 live on TestFlight (internal); story → review
