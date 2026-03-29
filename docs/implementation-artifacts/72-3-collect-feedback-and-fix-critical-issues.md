# Story 72.3: Collect Feedback and Fix Critical Issues

Status: ready-for-dev

## Story

As a **developer**,
I want to collect beta tester feedback and fix any critical issues,
so that the app is stable and trustworthy before public App Store submission.

## Acceptance Criteria

1. **Given** beta tester feedback, **When** triaged, **Then** issues are classified as critical, important, or nice-to-have.
2. **Given** critical issues, **When** identified, **Then** they are fixed, a new build uploaded, and testers verify the fix.
3. **Given** the final beta build, **When** tested for at least 48 hours, **Then** no new critical issues are reported.

## Tasks / Subtasks

- [ ] Task 1: Collect and organize feedback (AC: #1)
  - [ ] Monitor TestFlight feedback (available in App Store Connect under TestFlight > Feedback)
  - [ ] Check for crash reports in App Store Connect (TestFlight > Crashes)
  - [ ] Gather any feedback received via email or other channels
  - [ ] Create a feedback log listing each reported issue
- [ ] Task 2: Triage feedback (AC: #1)
  - [ ] Classify each issue using the following categories:
    - **Critical**: Crashes, data loss, audio not working, app cannot launch, blocking bugs
    - **Important**: Incorrect behavior, confusing UX, accessibility regressions, performance issues
    - **Nice-to-have**: Polish, cosmetic issues, minor inconveniences, feature requests
  - [ ] Prioritize critical issues for immediate fix
  - [ ] Document triage decisions and rationale
- [ ] Task 3: Fix critical issues (AC: #2)
  - [ ] For each critical issue, create a fix on the main branch
  - [ ] Run full test suite (`bin/test.sh && bin/test.sh -p mac`) before committing
  - [ ] Increment build number
  - [ ] Archive and upload a new build to TestFlight (follow Story 72.1 process)
  - [ ] Notify testers that a new build is available
  - [ ] Verify with testers that the critical issue is resolved
- [ ] Task 4: Stabilization period (AC: #3)
  - [ ] After the last fix build is uploaded, start a 48-hour stabilization window
  - [ ] Monitor for new crash reports and tester feedback during the window
  - [ ] If new critical issues emerge, fix them and restart the 48-hour window
  - [ ] After 48 hours with no new critical issues, mark the build as the release candidate
- [ ] Task 5: Document results (AC: #1, #2, #3)
  - [ ] Record total number of beta builds produced
  - [ ] Record all issues found and their classifications
  - [ ] Record which issues were fixed and which were deferred
  - [ ] Note the final build number that passed stabilization

## Dev Notes

### Prerequisites
- Story 72.2 must be complete (testers have access and are actively testing)
- Testers have been given clear instructions on what to test and how to report issues

### Step-by-step Guidance

1. **Feedback sources**: TestFlight provides two built-in feedback channels: screenshots with annotations (testers can send these from the TestFlight app) and crash reports. Both appear in App Store Connect. Also check your feedback email.

2. **Triage discipline**: Be honest about severity. A crash that occurs during normal use is critical, even if it only affects one tester. An ugly layout on one screen size is important but not critical. A "would be nice if" suggestion is nice-to-have.

3. **Fix-and-ship cycle**: Each fix cycle requires a new build number (not a new version number). For example, version 1.0.0 might go through builds 1, 2, 3 during beta. Keep the version number stable; only increment the build number.

4. **48-hour stabilization**: This is a minimum. The goal is confidence that the build is stable under real-world use. If testers are not actively using the app during this window, the 48 hours provides less signal. Encourage testers to exercise all features.

5. **When to defer**: Important and nice-to-have issues discovered during beta can be deferred to a post-launch update. Do not let scope creep delay the release unless the issue genuinely blocks users.

6. **Multiple iterations**: This story is inherently iterative. Expect 1-3 fix cycles for a typical beta. If you exceed 5 cycles, step back and evaluate whether there is a systemic quality issue that needs a different approach.

### Project Structure Notes
### References

- [App Store Connect Help: View crash and feedback reports](https://developer.apple.com/help/app-store-connect/test-a-beta-version/view-crash-reports-for-a-beta-app)
- [TestFlight beta testing overview](https://developer.apple.com/testflight/)

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created
