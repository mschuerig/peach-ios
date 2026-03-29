# Story 72.2: Configure TestFlight and Distribute Beta

Status: ready-for-dev

## Story

As a **developer**,
I want to configure TestFlight and distribute the beta to testers,
so that real users can install and exercise Peach before public release.

## Acceptance Criteria

1. **Given** the processed build, **When** configuring TestFlight, **Then** beta test information is filled in (what to test, contact email).
2. **Given** TestFlight configuration, **When** adding internal testers, **Then** at least one tester is invited and receives the invitation.
3. **Given** a tester, **When** they open the TestFlight link, **Then** they can install and launch Peach.
4. **Given** external testers (optional), **When** a public TestFlight link is created, **Then** up to 10,000 users can join.

## Tasks / Subtasks

- [ ] Task 1: Fill in beta test information (AC: #1)
  - [ ] Navigate to App Store Connect > Apps > Peach > TestFlight
  - [ ] Enter "What to Test" description (e.g., core training flow, navigation, accessibility)
  - [ ] Enter feedback email address
  - [ ] Optionally add a privacy policy URL and marketing URL
  - [ ] Set beta app description if prompted
- [ ] Task 2: Configure internal testing group (AC: #2)
  - [ ] Create an internal testing group (e.g., "Peach Internal Testers")
  - [ ] Add the processed build to the group
  - [ ] Add at least one internal tester (must be an App Store Connect user with the Tester role or higher)
  - [ ] Verify the tester receives an email invitation
- [ ] Task 3: Verify tester can install and launch (AC: #3)
  - [ ] Tester opens the TestFlight invitation email or link
  - [ ] Tester installs the TestFlight app (if not already installed)
  - [ ] Tester accepts the beta invitation in TestFlight
  - [ ] Tester installs Peach from TestFlight
  - [ ] Tester launches Peach and confirms it opens to the start screen
- [ ] Task 4: Configure external testing (optional) (AC: #4)
  - [ ] Create an external testing group (e.g., "Peach Public Beta")
  - [ ] Add the build to the external group
  - [ ] Submit the build for Beta App Review
  - [ ] Wait for Beta App Review approval (typically < 24 hours)
  - [ ] Enable public link for the external group
  - [ ] Copy and save the public TestFlight link for distribution

## Dev Notes

### Prerequisites
- Story 72.1 must be complete (build uploaded and processed in App Store Connect)
- At least one Apple ID available for internal testing

### Step-by-step Guidance

1. **Internal vs. external testers**:
   - Internal testers: Must be App Store Connect users on your team (up to 100). No review required. Builds are available immediately.
   - External testers: Anyone with an Apple ID (up to 10,000). Requires Beta App Review for the first build of each new version.

2. **"What to Test" text**: Keep it specific and actionable. Example:
   - "Please test the ear training flow: start a session, complete at least 5 comparisons, and check your profile screen. Report any crashes, audio issues, or confusing UI."

3. **Internal tester setup**: Internal testers must have an App Store Connect role. If testing with your own account, you are automatically eligible. The invitation arrives as an email with a link that opens TestFlight.

4. **Beta App Review for external testers**: The first submission for external testing triggers a review. This is lighter than full App Store review but still checks for crashes, broken functionality, and guideline violations. Approval typically takes less than 24 hours.

5. **Public link considerations**: A public TestFlight link lets anyone join without an explicit invitation. Consider whether you want open access or a controlled group at this stage. You can disable the link at any time.

6. **Common issues**:
   - "Build not available for testing" -- check that the build has finished processing and that export compliance is resolved
   - Tester does not receive email -- check spam folder; alternatively, share the TestFlight link directly
   - "This beta is no longer accepting testers" -- the public link may be disabled or the tester limit reached

### Project Structure Notes
### References

- [TestFlight overview](https://developer.apple.com/testflight/)
- [App Store Connect Help: TestFlight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview)

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created
