# Story 74.4: Create Homebrew Cask

Status: ready-for-dev

## Story

As a **Mac user who manages software with Homebrew**,
I want to install Peach via `brew install --cask peach`,
so that I can install and update it using my preferred package manager.

## Acceptance Criteria

1. **Given** a Homebrew tap repository (e.g., `mschuerig/homebrew-tap`), **When** created, **Then** it contains a cask formula for Peach.
2. **Given** the cask formula, **When** reviewed, **Then** it points to the GitHub Release artifact URL, includes correct SHA256 hash, and specifies the app name.
3. **Given** a user, **When** they run `brew tap mschuerig/tap && brew install --cask peach`, **Then** Peach is installed into `/Applications`.
4. **Given** a new Peach version, **When** released on GitHub, **Then** the cask formula is updated with the new version and hash.

## Tasks / Subtasks

- [ ] Task 1: Create the Homebrew tap repository (AC: #1)
  - [ ] Create a new GitHub repository named `mschuerig/homebrew-tap`
  - [ ] Add a README explaining the tap's purpose
  - [ ] Create the `Casks` directory structure
- [ ] Task 2: Write the cask formula (AC: #1, #2)
  - [ ] Create `Casks/peach.rb` with the cask definition
  - [ ] Set `version` to match the current GitHub Release tag (e.g., "1.0")
  - [ ] Set `url` to the GitHub Release artifact download URL
  - [ ] Compute and set the `sha256` hash of the artifact
  - [ ] Set `name` to "Peach"
  - [ ] Set `homepage` to the GitHub repository URL or project site
  - [ ] Set `app` to "Peach.app"
  - [ ] Add a `desc` field describing the app
- [ ] Task 3: Test the cask installation (AC: #3)
  - [ ] Run `brew tap mschuerig/tap`
  - [ ] Run `brew install --cask peach`
  - [ ] Verify Peach.app appears in `/Applications`
  - [ ] Launch Peach and verify it works correctly
  - [ ] Run `brew uninstall --cask peach` and verify clean removal
- [ ] Task 4: Plan cask update process (AC: #4)
  - [ ] Document manual update steps: edit version and sha256 in `peach.rb`, commit, push
  - [ ] Optionally create a script or GitHub Actions workflow to automate formula updates when a new release is published

## Dev Notes

### Cask Formula Template

```ruby
cask "peach" do
  version "1.0"
  sha256 "REPLACE_WITH_ACTUAL_SHA256"

  url "https://github.com/mschuerig/peach/releases/download/v#{version}/Peach.dmg"
  name "Peach"
  desc "Music ear-training app with adaptive difficulty"
  homepage "https://github.com/mschuerig/peach"

  app "Peach.app"

  zap trash: [
    "~/Library/Containers/de.schuerig.peach",
  ]
end
```

### Computing the SHA256 Hash

```bash
shasum -a 256 Peach.dmg
```

### Automating Formula Updates

A GitHub Actions workflow in the tap repository can listen for `release` events on the main Peach repository (via `repository_dispatch` or a workflow in the Peach repo that triggers the tap update). The workflow would:
1. Download the new release artifact
2. Compute the SHA256 hash
3. Update `peach.rb` with the new version and hash
4. Commit and push

This can be added later once the manual process is established.

### Project Structure Notes
- Tap repository: `github.com/mschuerig/homebrew-tap`
- Cask formula: `Casks/peach.rb` in the tap repository

### References
- [Homebrew Cask: How to create a cask](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
- [Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created
