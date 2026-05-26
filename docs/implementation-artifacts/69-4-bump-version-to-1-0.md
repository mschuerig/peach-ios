# Story 69.4: Bump Version to 1.0

Status: done

## Story

As a **user downloading from the App Store**,
I want the app version to be 1.0,
so that it reflects a polished first public release rather than a pre-release.

## Acceptance Criteria

1. **Given** the Xcode project **When** inspected **Then** `MARKETING_VERSION` is `1.0` for all targets.
2. **Given** the Info screen **When** displayed **Then** it shows version `1.0`.

## Tasks / Subtasks

- [x] Update `MARKETING_VERSION` from `0.1` to `1.0` in `project.pbxproj` (AC: #1)
  - [x] There are 4 occurrences (Debug/Release x iOS/macOS build configurations) — update all
- [x] Verify Info screen displays correctly (AC: #2)
  - [x] `InfoScreen.swift` reads `CFBundleShortVersionString` from `Bundle.main.infoDictionary` — this is populated from `MARKETING_VERSION` automatically
- [x] Build both platforms: `bin/build.sh && bin/build.sh -p mac` (AC: #1)
- [x] Run tests: `bin/test.sh && bin/test.sh -p mac` (AC: #2)

## Dev Notes

The version is read dynamically in `Peach/Info/InfoScreen.swift` line 5:
```swift
private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
```

No hardcoded version strings elsewhere. Changing `MARKETING_VERSION` in the project file is sufficient.

`CURRENT_PROJECT_VERSION` (build number) should remain at its current value or be set to `1` if not already — App Store Connect requires build numbers to increment, but the initial submission can be `1`.

### Project Structure Notes

Change is in `Peach.xcodeproj/project.pbxproj` only. No Swift file changes needed.

### References

- `docs/reports/appstore-review-2026-03-28.md` — Marketing Version: 0.1
- `Peach/Info/InfoScreen.swift` — version display

## Dev Agent Record

### Agent Model Used

claude-opus-4-7

### Debug Log References

### Completion Notes List

- Story note said "4 occurrences" but the project actually contains **8** `MARKETING_VERSION = 0.1;` entries: 4 build configurations (Debug, Release, Debug (Research), Release (Research)) × 2 targets (app `de.schuerig.peach`, test `de.schuerig.peachTests`). All 8 were updated to `1.0` to satisfy AC #1 ("for all targets").
- `CURRENT_PROJECT_VERSION` already `1` across all configurations — left unchanged per Dev Notes.
- `InfoScreen.swift` reads version dynamically from `CFBundleShortVersionString`; no Swift changes required.
- Verification: iOS build OK, macOS build OK, iOS tests 1479/1479, macOS tests 1473/1473.

### File List

- `Peach.xcodeproj/project.pbxproj` (modified)

## Change Log

- 2026-03-29: Story created
- 2026-05-09: MARKETING_VERSION bumped from 0.1 to 1.0 in all 8 build configuration entries (app + test targets across Debug/Release/Debug (Research)/Release (Research)). Both platforms build clean and full test suites pass.
