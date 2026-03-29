# Story 69.2: Add Export Compliance Declaration

Status: ready-for-dev

## Story

As a **developer uploading builds**,
I want the export compliance key set in Info.plist,
so that TestFlight and App Store builds don't show "Missing Compliance" warnings requiring manual confirmation.

## Acceptance Criteria

1. **Given** the app's Info.plist configuration **When** built **Then** `ITSAppUsesNonExemptEncryption` is set to `NO`.
2. **Given** a build uploaded to App Store Connect **When** processed **Then** no "Missing Compliance" banner appears.

## Tasks / Subtasks

- [ ] Add `ITSAppUsesNonExemptEncryption = NO` to the build settings (AC: #1)
  - [ ] The project uses `GENERATE_INFOPLIST_FILE = YES`, so add via `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` in project.pbxproj build settings (all 4 build configurations: Debug/Release x iOS/macOS)
- [ ] Build both platforms: `bin/build.sh && bin/build.sh -p mac` (AC: #1)
- [ ] Verify the key appears in the built Info.plist by inspecting the product bundle (AC: #2)

## Dev Notes

The app uses no encryption beyond Apple's standard HTTPS (which is exempt). No custom crypto, no VPN, no encrypted storage beyond SwiftData's defaults. `NO` is the correct value.

Since the project uses generated Info.plist files (`GENERATE_INFOPLIST_FILE = YES`), the correct approach is adding the `INFOPLIST_KEY_` prefixed build setting rather than creating a separate Info.plist file.

### Project Structure Notes

Change is in `Peach.xcodeproj/project.pbxproj` build settings only. No new files.

### References

- `docs/reports/appstore-review-2026-03-28.md`
- Apple docs: [Export compliance overview](https://developer.apple.com/help/app-store-connect/reference/export-compliance-documentation-for-encryption)

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created
