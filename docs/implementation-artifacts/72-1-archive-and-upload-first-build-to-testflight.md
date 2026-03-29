# Story 72.1: Archive and Upload First Build to TestFlight

Status: ready-for-dev

## Story

As a **developer**,
I want to archive the app and upload the first build to TestFlight,
so that the binary is processed by Apple and ready for beta distribution.

## Acceptance Criteria

1. **Given** the Xcode project with all Epic 69 fixes applied, **When** archived for "Any iOS Device (arm64)" via Product > Archive, **Then** the archive succeeds without errors.
2. **Given** the archive, **When** distributed via "TestFlight & App Store" > Upload, **Then** the upload succeeds and Apple sends a processing confirmation email.
3. **Given** the uploaded build, **When** viewed in App Store Connect, **Then** it shows as processed with no "Missing Compliance" warning.

## Tasks / Subtasks

- [ ] Task 1: Prepare App Store Connect app record (AC: #1, #2)
  - [ ] Log into App Store Connect (appstoreconnect.apple.com)
  - [ ] Create new app record: bundle ID `de.schuerig.peach`, app name "Peach", primary language English (U.S.)
  - [ ] Choose an available SKU (e.g., `peach-ios-1`)
  - [ ] Verify Team ID G3PDM6G8F8 is selected
- [ ] Task 2: Verify Xcode project signing and build settings (AC: #1)
  - [ ] Confirm bundle identifier is `de.schuerig.peach`
  - [ ] Confirm "Automatically manage signing" is enabled with Team G3PDM6G8F8
  - [ ] Confirm all Epic 69 compliance fixes are present in the binary (privacy manifest, export compliance, etc.)
  - [ ] Set marketing version and build number (e.g., 1.0.0 build 1)
- [ ] Task 3: Create the archive (AC: #1)
  - [ ] Select "Any iOS Device (arm64)" as the destination
  - [ ] Product > Archive
  - [ ] Verify archive completes without errors or warnings
  - [ ] Confirm archive appears in the Organizer window
- [ ] Task 4: Upload to App Store Connect (AC: #2)
  - [ ] In Organizer, select the archive and click "Distribute App"
  - [ ] Choose "TestFlight & App Store" distribution method
  - [ ] Let Xcode manage signing (automatic)
  - [ ] Click Upload and wait for completion
  - [ ] Verify Xcode shows "Upload Successful"
  - [ ] Wait for Apple processing confirmation email (typically 15-30 minutes)
- [ ] Task 5: Verify processed build in App Store Connect (AC: #3)
  - [ ] Navigate to App Store Connect > Apps > Peach > TestFlight
  - [ ] Confirm the build appears with status "Ready to Submit" or similar
  - [ ] Verify no "Missing Compliance" warning (Epic 69 should have handled ITSAppUsesNonExemptEncryption)
  - [ ] If "Missing Compliance" appears, set export compliance information manually

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
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created
