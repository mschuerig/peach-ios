# Story 69.6: Write and Host Privacy Policy on GitHub Pages

Status: ready-for-dev

## Story

As a **first-time App Store submitter**,
I want a privacy policy hosted at a stable URL with automated deployment,
so that I can link it in App Store Connect and in-app, and it stays live without manual hosting.

## Acceptance Criteria

1. **Given** the privacy policy content **When** reviewed **Then** it states: Peach collects no personal data, all training data is stored locally on-device, no third-party analytics/advertising/tracking SDKs are used, no data is shared with third parties, and includes developer contact information.
2. **Given** the GitHub Pages site **When** accessed at the configured URL **Then** the privacy policy page renders correctly and is publicly accessible.
3. **Given** the repository **When** a change to the privacy policy is pushed to main **Then** a GitHub Actions pipeline deploys it automatically to GitHub Pages.
4. **Given** the privacy policy page **When** viewed on mobile or desktop **Then** it is readable with no broken layout.

## Tasks / Subtasks

- [ ] Write privacy policy content (AC: #1)
  - [ ] State that Peach collects no personal data
  - [ ] State that all training data (pitch discrimination, pitch matching, rhythm exercises) is stored locally on-device only
  - [ ] State that no third-party analytics, advertising, or tracking SDKs are used
  - [ ] State that MIDIKit is the sole third-party library and it does not transmit data
  - [ ] State that no data is shared with third parties
  - [ ] Include developer contact: Michael Schuerig, email address
  - [ ] Include effective date
- [ ] Create privacy policy page in repository (AC: #2, #4)
  - [ ] Create `docs/privacy-policy.md` (or `docs/privacy-policy/index.html`) for GitHub Pages
  - [ ] Keep it simple — Markdown rendered by GitHub Pages, or minimal HTML
  - [ ] Ensure responsive layout (GitHub Pages default themes handle this)
- [ ] Configure GitHub Pages deployment (AC: #2, #3)
  - [ ] Option A: Configure GitHub Pages to serve from `docs/` folder on `main` branch (simplest)
  - [ ] Option B: Create `.github/workflows/pages.yml` GitHub Actions workflow for custom deployment
  - [ ] The URL will be `https://mschuerig.github.io/peach/privacy-policy` (or similar)
- [ ] Verify the page is accessible and renders on mobile/desktop (AC: #4)

## Dev Notes

This is a manual-heavy story. The implementation agent can create the file content and GitHub Actions workflow, but GitHub Pages configuration in repository settings requires manual action by the developer.

**Recommended approach**: Use GitHub Pages serving from `docs/` on `main` branch. Create a `docs/privacy-policy.md` file. GitHub renders Markdown automatically with a responsive theme. This avoids needing a separate branch or complex workflow.

If a GitHub Actions workflow is needed (e.g., for custom domain or Jekyll processing), a minimal `.github/workflows/pages.yml` can deploy the `docs/` directory.

The final URL must be noted for use in story 69-7 (in-app link) and App Store Connect metadata.

### Project Structure Notes

New files:
- `docs/privacy-policy.md` (or `docs/privacy-policy/index.md`)
- Possibly `.github/workflows/pages.yml`

No changes to Swift code. This is a docs/infrastructure story.

### References

- `docs/reports/appstore-review-2026-03-28.md` — Critical: Guideline 5.1.1(i), no privacy policy URL
- Apple docs: [App Store Review Guidelines 5.1.1](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage)

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created
