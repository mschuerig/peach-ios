# Story 74.5: Update Architecture Documentation for macOS Distribution

Status: ready-for-dev

## Story

As a **developer maintaining Peach**,
I want the architecture documentation to describe the macOS distribution channels and release process,
so that future releases can be executed consistently without tribal knowledge.

## Acceptance Criteria

1. **Given** the architecture documentation, **When** read, **Then** it describes the three macOS distribution channels: Mac App Store, GitHub Releases (notarized), and Homebrew.
2. **Given** the documentation, **When** read, **Then** it explains how to create a new release (tag, build, notarize, upload, update cask).

## Tasks / Subtasks

- [ ] Task 1: Document the three distribution channels (AC: #1)
  - [ ] Describe the Mac App Store channel: how the macOS build is submitted alongside the iOS app through App Store Connect
  - [ ] Describe the GitHub Releases channel: notarized .dmg/.zip attached to tagged releases
  - [ ] Describe the Homebrew channel: third-party tap at `mschuerig/homebrew-tap` with a cask formula pointing to GitHub Releases
  - [ ] Explain the relationship between channels (GitHub Release is the source artifact for Homebrew)
- [ ] Task 2: Document the release process (AC: #2)
  - [ ] Step 1: Create and push a version tag (`git tag v1.x && git push origin v1.x`)
  - [ ] Step 2: Archive in Xcode for Mac App Store and upload to App Store Connect
  - [ ] Step 3: Archive with Developer ID, notarize, staple, and package as .dmg
  - [ ] Step 4: Upload the notarized .dmg to the GitHub Release (created by the workflow)
  - [ ] Step 5: Publish the GitHub Release
  - [ ] Step 6: Update the Homebrew cask formula with the new version and SHA256 hash
  - [ ] Document which steps are automated and which are manual
- [ ] Task 3: Add the documentation to the appropriate location (AC: #1, #2)
  - [ ] Add a "macOS Distribution" section to the existing arc42 deployment view or a dedicated distribution guide
  - [ ] Cross-reference Stories 74.1 through 74.4 for detailed instructions
  - [ ] Keep the documentation focused on intent and process, not implementation details that live in code

## Dev Notes

### Documentation Scope

This story documents the "what and why" of macOS distribution at the architecture level. The detailed "how" (specific commands, UI steps, troubleshooting) lives in the individual story files (74.1-74.4) and can be referenced rather than duplicated.

The documentation should answer these questions for a future maintainer:
- What are the available distribution channels for macOS?
- What is the dependency chain between them?
- What does a complete release look like, end to end?
- Which steps are automated and which require manual intervention?

### Suggested Location

The deployment view in the arc42 documentation (`docs/arc42/`) is the natural home for distribution channel descriptions. If a separate release guide is more appropriate, `docs/release-guide.md` is an alternative.

### Project Structure Notes
- Architecture documentation: `docs/arc42/`
- Story references: `docs/implementation-artifacts/74-1-*` through `74-4-*`

### References
- arc42 Section 7: Deployment View

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created
