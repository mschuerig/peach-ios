# Story 69.1: Create Privacy Manifest

Status: done

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

- [x] Create `Peach/Resources/PrivacyInfo.xcprivacy` with required privacy declarations (AC: #1, #2, #3)
  - [x] Set `NSPrivacyTracking` to `false`
  - [x] Set `NSPrivacyTrackingDomains` to empty array
  - [x] Set `NSPrivacyCollectedDataTypes` to empty array
  - [x] Add `NSPrivacyAccessedAPITypes` entry for `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`
- [x] Add `PrivacyInfo.xcprivacy` to the Xcode project so it is included in the app bundle (AC: #1)
- [x] Audit MIDIKit 0.11.0 for required-reason API usage (AC: #4)
  - [x] Check if MIDIKit uses UserDefaults, file timestamp, system boot time, or disk space APIs
  - [x] CoreMIDI is not on Apple's required-reason API list, so likely no additions needed
  - [x] If MIDIKit ships its own `PrivacyInfo.xcprivacy`, no action needed on our side
- [x] Build both platforms: `bin/build.sh && bin/build.sh -p mac` (AC: #5)

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
Claude Opus 4.6

### Debug Log References
None

### Completion Notes List
- Created `PrivacyInfo.xcprivacy` with all required Apple privacy declarations: `NSPrivacyTracking=false`, empty tracking domains and collected data types, `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`
- Project uses `PBXFileSystemSynchronizedRootGroup` — file is automatically included in the app bundle without manual Xcode project edits
- Audited MIDIKit 0.11.0: uses UserDefaults for MIDI identifier persistence but does not ship its own privacy manifest. Our app's `CA92.1` reason code covers MIDIKit's usage since it's compiled into the same app
- Code review found MIDIKitInternals calls `mach_absolute_time()` — added `NSPrivacyAccessedAPICategorySystemBootTime` with reason `35F9.1` to cover this
- Both iOS and macOS builds succeed with no privacy-manifest-related warnings

### File List
- `Peach/Resources/PrivacyInfo.xcprivacy` (new)

## Change Log

- 2026-03-29: Story created
- 2026-04-24: Implementation complete — privacy manifest created, MIDIKit audited, both platforms build clean
- 2026-04-24: Code review fix — added NSPrivacyAccessedAPICategorySystemBootTime for MIDIKit's mach_absolute_time() usage
