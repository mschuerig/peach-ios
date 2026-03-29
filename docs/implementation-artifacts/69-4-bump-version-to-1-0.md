# Story 69.4: Bump Version to 1.0

Status: ready-for-dev

## Story

As a **user downloading from the App Store**,
I want the app version to be 1.0,
so that it reflects a polished first public release rather than a pre-release.

## Acceptance Criteria

1. **Given** the Xcode project **When** inspected **Then** `MARKETING_VERSION` is `1.0` for all targets.
2. **Given** the Info screen **When** displayed **Then** it shows version `1.0`.

## Tasks / Subtasks

- [ ] Update `MARKETING_VERSION` from `0.1` to `1.0` in `project.pbxproj` (AC: #1)
  - [ ] There are 4 occurrences (Debug/Release x iOS/macOS build configurations) — update all
- [ ] Verify Info screen displays correctly (AC: #2)
  - [ ] `InfoScreen.swift` reads `CFBundleShortVersionString` from `Bundle.main.infoDictionary` — this is populated from `MARKETING_VERSION` automatically
- [ ] Build both platforms: `bin/build.sh && bin/build.sh -p mac` (AC: #1)
- [ ] Run tests: `bin/test.sh && bin/test.sh -p mac` (AC: #2)

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
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created
