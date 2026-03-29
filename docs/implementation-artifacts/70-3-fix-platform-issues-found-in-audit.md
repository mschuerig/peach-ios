# Story 70.3: Fix Platform Issues Found in Audit

Status: ready-for-dev

## Story

As a **developer**,
I want all issues discovered during platform testing fixed before release,
so that no platform ships with known UX defects.

## Acceptance Criteria

1. **Given** the issues list from Stories 70.1 and 70.2 **When** triaged **Then** all issues classified as "must fix before release" are resolved.
2. **Given** each fix **When** applied **Then** it is verified on the affected platform and does not regress other platforms.
3. **Given** the full test suite **When** run on both iOS and macOS **Then** all tests pass.

## Tasks / Subtasks

_Tasks will be populated after Stories 70.1 and 70.2 are complete. Each must-fix issue becomes a task here._

- [ ] Task 1: Triage issues from Story 70.1 (iOS/iPadOS audit) (AC: #1)
  - [ ] 1.1 Review all discovered issues
  - [ ] 1.2 Classify each as "must fix before release" or "nice-to-have / post-release"
- [ ] Task 2: Triage issues from Story 70.2 (macOS audit) (AC: #1)
  - [ ] 2.1 Review all discovered issues
  - [ ] 2.2 Classify each as "must fix before release" or "nice-to-have / post-release"
- [ ] Task 3: Fix all must-fix issues (AC: #1, #2)
  - [ ] _Subtasks added per issue after triage_
- [ ] Task 4: Cross-platform verification (AC: #2)
  - [ ] 4.1 Verify each fix on the affected platform
  - [ ] 4.2 Verify no regressions on other platforms
- [ ] Task 5: Run full test suite on both platforms (AC: #3)
  - [ ] 5.1 `bin/test.sh` — iOS tests pass
  - [ ] 5.2 `bin/test.sh -p mac` — macOS tests pass

## Dev Notes

This is a **catch-all fix story**. Scope depends entirely on what Stories 70.1 and 70.2 discover. If no issues are found, this story is marked done immediately.

### Workflow

1. Complete Stories 70.1 and 70.2 first — they produce the issues list.
2. Triage: classify every issue. "Must fix" = anything that blocks a professional release (broken layouts, non-functional features, crashes). "Nice-to-have" = cosmetic polish that can ship in a point release.
3. Fix each must-fix issue in isolation, verifying cross-platform after each change.
4. Run `bin/test.sh && bin/test.sh -p mac` before marking done.

### Common Fix Patterns

- **Layout issues**: Adjust `frame`, `padding`, `fixedSize`, or size-class conditionals in the affected screen view.
- **Keyboard shortcut conflicts**: Adjust key assignments in `PeachCommands.swift` or training screen `.keyboardShortcut()` modifiers.
- **Lifecycle issues**: Update `TrainingLifecycleCoordinator.swift` platform-conditional notification handling.
- **Dynamic Type overflow**: Wrap content in `ScrollView`, use `@ScaledMetric` for fixed dimensions, avoid hardcoded heights.

### Project Structure Notes

- Platform conditionals spread across 18 files — changes must be tested on both iOS and macOS builds.
- All port abstractions: `Peach/Core/Ports/` — fixes should go through these abstractions, not add new `#if os()` branches.

### References

- Story 70.1: `docs/implementation-artifacts/70-1-platform-polish-audit-ios-ipados.md`
- Story 70.2: `docs/implementation-artifacts/70-2-platform-polish-audit-macos.md`

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created
