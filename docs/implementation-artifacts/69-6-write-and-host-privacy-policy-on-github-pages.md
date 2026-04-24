# Story 69.6: Write and Host Privacy Policy on GitHub Pages

Status: done

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

- [x] Write privacy policy content (AC: #1)
  - [x] State that Peach collects no personal data
  - [x] State that all training data (pitch discrimination, pitch matching, rhythm exercises) is stored locally on-device only
  - [x] State that no third-party analytics, advertising, or tracking SDKs are used
  - [x] State that MIDIKit is the sole third-party library and it does not transmit data
  - [x] State that no data is shared with third parties
  - [x] Include developer contact: Michael Schuerig, email address
  - [x] Include effective date
- [x] Create privacy policy page in repository (AC: #2, #4)
  - [x] Create multilingual subdirectory structure: `docs/privacy-policy/en.md`, `docs/privacy-policy/de.md`, `docs/privacy-policy/index.html` (JS locale redirect)
  - [x] Keep it simple — Markdown rendered by GitHub Pages with minima theme
  - [x] Ensure responsive layout (minima theme is responsive by default)
  - [x] Cross-link between language versions
- [x] Configure GitHub Pages deployment (AC: #2, #3)
  - [x] Option B: Create `.github/workflows/pages.yml` GitHub Actions workflow for custom deployment
  - [x] Jekyll `_config.yml` scoped to only serve privacy policy (excludes all project docs)
  - [x] The URL will be `https://mschuerig.github.io/peach-ios/privacy-policy`
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
Claude Opus 4.6

### Debug Log References
None — docs-only story, no debugging needed.

### Completion Notes List
- Created multilingual privacy policy with subdirectory structure: `docs/privacy-policy/en.md` (English), `docs/privacy-policy/de.md` (German), `docs/privacy-policy/index.html` (JS locale redirect with noscript fallback to English)
- Privacy policy content covers all ACs: no data collection, local-only storage, no third-party analytics/tracking, MIDIKit disclosure, no data sharing, developer contact (michael@schuerig.de), effective date (2026-04-24)
- German version uses informal "du" form per project convention
- Each language version cross-links to the other
- Created `docs/_config.yml` with Jekyll configuration using minima theme, scoped to serve only the privacy policy (all project documentation directories and files excluded)
- Created `.github/workflows/pages.yml` with GitHub Actions workflow for automated deployment to GitHub Pages on push to main (triggers on changes to `docs/privacy-policy/**`, `docs/_config.yml`, or the workflow itself)
- URLs: `https://mschuerig.github.io/peach-ios/privacy-policy/` (auto-redirect), `.../privacy-policy/en` (English), `.../privacy-policy/de` (German)
- **Manual step required**: GitHub Pages must be enabled in repository settings (Settings → Pages → Source: GitHub Actions). The workflow will not deploy until this is configured.
- Verification (AC #4) requires the workflow to run and the page to be live — this can only be verified after pushing to main and enabling GitHub Pages.

### File List
- `docs/privacy-policy/en.md` — new: English privacy policy with Jekyll frontmatter
- `docs/privacy-policy/de.md` — new: German privacy policy with Jekyll frontmatter
- `docs/privacy-policy/index.html` — new: JS locale redirect (de → de, else → en) with noscript fallback
- `docs/_config.yml` — new: Jekyll config scoped to privacy policy only
- `.github/workflows/pages.yml` — new: GitHub Actions workflow for Pages deployment
- `docs/implementation-artifacts/sprint-status.yaml` — modified: story status updated
- `docs/implementation-artifacts/69-6-write-and-host-privacy-policy-on-github-pages.md` — modified: tasks checked, dev record updated

## Change Log

- 2026-03-29: Story created
- 2026-04-24: Implemented multilingual privacy policy (EN/DE), Jekyll config, and GitHub Actions deployment workflow
