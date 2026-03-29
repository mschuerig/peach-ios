# Story 74.1: Submit to Mac App Store

Status: ready-for-dev

## Story

As a **Mac user**,
I want Peach to be available on the Mac App Store,
so that I can discover and install it through Apple's trusted distribution channel.

## Acceptance Criteria

1. **Given** the Xcode project, **When** archived for "Any Mac (Apple Silicon, Intel)", **Then** the archive succeeds.
2. **Given** the Mac archive, **When** uploaded to App Store Connect, **Then** it is processed successfully alongside the iOS app (same app record, separate platform).
3. **Given** the Mac App Store listing, **When** reviewed, **Then** macOS screenshots from Story 71.4 are uploaded and macOS-specific metadata is correct.
4. **Given** the Mac build, **When** submitted for review, **Then** it passes review (or rejection reasons are addressed).

## Tasks / Subtasks

- [ ] Task 1: Verify Xcode project settings for Mac App Store distribution (AC: #1)
  - [ ] Confirm bundle identifier is `de.schuerig.peach` for the macOS target
  - [ ] Confirm "Automatically manage signing" is enabled with Team G3PDM6G8F8
  - [ ] Confirm App Sandbox entitlement is enabled (required for Mac App Store)
  - [ ] Confirm Hardened Runtime is enabled
  - [ ] Set marketing version and build number to match the iOS release
- [ ] Task 2: Create the Mac archive (AC: #1)
  - [ ] Select "Any Mac (Apple Silicon, Intel)" as the destination
  - [ ] Product > Archive
  - [ ] Verify archive completes without errors or warnings
  - [ ] Confirm archive appears in the Organizer window
- [ ] Task 3: Upload to App Store Connect (AC: #2)
  - [ ] In Organizer, select the Mac archive and click "Distribute App"
  - [ ] Choose "App Store Connect" distribution method
  - [ ] Let Xcode manage signing (automatic)
  - [ ] Click Upload and wait for completion
  - [ ] Verify Xcode shows "Upload Successful"
  - [ ] Wait for Apple processing confirmation email
  - [ ] Confirm the build appears under the macOS platform in the existing Peach app record
- [ ] Task 4: Upload macOS screenshots and verify metadata (AC: #3)
  - [ ] Navigate to App Store Connect > Apps > Peach > macOS App Store page
  - [ ] Upload macOS screenshots prepared in Story 71.4
  - [ ] Verify macOS-specific metadata: category, description, age rating are correct
  - [ ] Verify the "What's New" text is appropriate for the Mac version
- [ ] Task 5: Submit for review (AC: #4)
  - [ ] Add the Mac build to the release
  - [ ] Submit for App Review
  - [ ] Monitor review status and respond to any reviewer questions
  - [ ] If rejected, address the stated reasons and resubmit

## Dev Notes

### Prerequisites
- Apple Developer Program membership must be active
- iOS version should already be submitted or approved (same app record)
- macOS screenshots from Story 71.4 must be ready
- All Epic 69 compliance fixes must be present in the build

### Step-by-step Guidance

1. **Same app record**: Since Peach is a SwiftUI multiplatform app, the Mac version uses the same App Store Connect app record as iOS. When uploading, App Store Connect automatically recognizes it as a macOS build based on the archive platform.

2. **App Sandbox**: Mac App Store apps require the App Sandbox entitlement. Verify this is enabled in the target's Signing & Capabilities tab. If Peach accesses any resources (audio, network), the corresponding sandbox exceptions must be declared.

3. **Universal binary**: Archiving for "Any Mac (Apple Silicon, Intel)" produces a universal binary supporting both architectures. This is the required configuration for Mac App Store submission.

4. **Review considerations**: Mac App Store review may flag different issues than iOS review. Common Mac-specific concerns include window management, menu bar integration, and keyboard shortcut support. Peach's macOS support was implemented in Epic 66, so these should already be addressed.

### References
- [Distributing your app for beta testing and releases](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created
