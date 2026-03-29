# Story 74.3: Set Up GitHub Releases

Status: ready-for-dev

## Story

As a **Mac user**,
I want to download Peach from a GitHub Release page,
so that I can get the notarized app directly from the project's repository.

## Acceptance Criteria

1. **Given** a git tag matching `v*` (e.g., `v1.0`), **When** pushed, **Then** a GitHub Actions workflow creates a GitHub Release with the tag.
2. **Given** the GitHub Release, **When** published, **Then** it includes the notarized macOS app artifact (.dmg or .zip) as a download.
3. **Given** the release, **When** viewed on GitHub, **Then** it includes release notes.

## Tasks / Subtasks

- [ ] Task 1: Create GitHub Actions release workflow (AC: #1)
  - [ ] Create `.github/workflows/release.yml`
  - [ ] Trigger on push of tags matching `v*`
  - [ ] Use `softprops/action-gh-release` or `gh release create` to create the release
  - [ ] Configure the release to be created as a draft initially (for manual artifact upload)
  - [ ] Include auto-generated release notes from GitHub (`generate_release_notes: true`)
- [ ] Task 2: Define the artifact upload strategy (AC: #2)
  - [ ] Option A (manual upload): Build and notarize locally per Story 74.2, then upload the .dmg/.zip to the draft release via GitHub web UI or `gh release upload`
  - [ ] Option B (CI build): Add macOS build steps to the workflow using `macos-latest` runner, archive, sign, notarize, and attach as a release asset
  - [ ] Document the chosen approach in this story's completion notes
- [ ] Task 3: Configure release notes (AC: #3)
  - [ ] Enable GitHub's auto-generated release notes (based on PR titles since last tag)
  - [ ] Optionally create `.github/release.yml` to categorize changes (features, fixes, etc.)
  - [ ] Verify release notes are meaningful and include relevant changes
- [ ] Task 4: Test the release workflow (AC: #1, #2, #3)
  - [ ] Create a test tag (e.g., `v0.0.1-rc1`) and push it
  - [ ] Verify the workflow runs and creates a draft release
  - [ ] Upload the notarized artifact to the release
  - [ ] Publish the release and verify the download link works
  - [ ] Verify the downloaded artifact passes Gatekeeper on a clean machine
  - [ ] Clean up the test release if needed

## Dev Notes

### Implementation Approach

The recommended approach is a hybrid: the GitHub Actions workflow creates the release and generates release notes automatically on tag push, while the notarized artifact is built locally and uploaded manually. This avoids the complexity of storing Developer ID certificates and notarization credentials in CI secrets.

If CI-based notarization is desired later, the following secrets would be needed:
- `DEVELOPER_ID_CERTIFICATE_P12` and `DEVELOPER_ID_CERTIFICATE_PASSWORD` for code signing
- `NOTARIZE_APPLE_ID`, `NOTARIZE_TEAM_ID`, and `NOTARIZE_PASSWORD` for notarytool
- A macOS runner with Xcode installed

### Workflow Skeleton

```yaml
name: Release
on:
  push:
    tags: ['v*']

permissions:
  contents: write

jobs:
  create-release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: softprops/action-gh-release@v2
        with:
          draft: true
          generate_release_notes: true
```

### Manual Artifact Upload

After the workflow creates the draft release:
1. Build and notarize the app locally (Story 74.2)
2. Upload: `gh release upload v1.0 Peach.dmg`
3. Publish: `gh release edit v1.0 --draft=false`

### Project Structure Notes
- Workflow file: `.github/workflows/release.yml`
- Optional release config: `.github/release.yml`

### References
- [GitHub Actions: Creating releases](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)
- [softprops/action-gh-release](https://github.com/softprops/action-gh-release)

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created
