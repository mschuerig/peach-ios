# Story 69.1: Create Privacy Manifest

Status: ready-for-dev

## Story

As a **developer submitting to the App Store**,
I want the app to include a privacy manifest declaring all required-reason API usage,
so that Apple does not reject the binary for missing privacy declarations.

## Acceptance Criteria

1. **Given** the Peach target **When** building for distribution **Then** `Peach/Resources/PrivacyInfo.xcprivacy` is included in the bundle.
2. **Given** the privacy manifest **When** inspected **Then** it declares `NSPrivacyAccessedAPICategoryUserDefaults` with reason code `CA92.1`.
3. **Given** the privacy manifest **When** inspected **Then** `NSPrivacyTracking` is `false`, `NSPrivacyTrackingDomains` is empty, and `NSPrivacyCollectedDataTypes` is empty.
4. **Given** MIDIKit as a dependency **When** reviewing its API usage **Then** verify whether MIDIKit uses any required-reason APIs and add entries to the manifest if needed.
5. **Given** the project **When** built for both iOS and macOS **Then** builds succeed with no warnings related to privacy manifests.

## Tasks / Subtasks

- [ ] Create `Peach/Resources/PrivacyInfo.xcprivacy` with required privacy declarations (AC: #1, #2, #3)
  - [ ] Set `NSPrivacyTracking` to `false`
  - [ ] Set `NSPrivacyTrackingDomains` to empty array
  - [ ] Set `NSPrivacyCollectedDataTypes` to empty array
  - [ ] Add `NSPrivacyAccessedAPITypes` entry for `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`
- [ ] Add `PrivacyInfo.xcprivacy` to the Xcode project so it is included in the app bundle (AC: #1)
- [ ] Audit MIDIKit 0.11.0 for required-reason API usage (AC: #4)
  - [ ] Check if MIDIKit uses UserDefaults, file timestamp, system boot time, or disk space APIs
  - [ ] CoreMIDI is not on Apple's required-reason API list, so likely no additions needed
  - [ ] If MIDIKit ships its own `PrivacyInfo.xcprivacy`, no action needed on our side
- [ ] Build both platforms: `bin/build.sh && bin/build.sh -p mac` (AC: #5)

## Dev Notes

The privacy manifest is an XML property list with a specific schema. The file must be named `PrivacyInfo.xcprivacy` and placed in the app bundle's resources.

UserDefaults usage locations in the app:
- `@AppStorage` in `PeachApp.swift` (soundSource key)
- `AppUserSettings` reads `UserDefaults.standard`
- All keys centralized in `SettingsKeys.swift`

Reason code `CA92.1`: "Access info from same app, app clips, or app extensions."

### Project Structure Notes

File goes in `Peach/Resources/` alongside `Assets.xcassets`, `Localizable.xcstrings`, and `Samples.sf2`.

### References

- `docs/reports/appstore-review-2026-03-28.md` — Critical finding: Guideline 5.1.1
- `docs/planning-artifacts/research/technical-ios-app-store-submission-readiness-research-2026-03-09.md`
- Apple docs: [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created
