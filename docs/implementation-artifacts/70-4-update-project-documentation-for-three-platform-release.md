# Story 70.4: Update Project Documentation for Three-Platform Release

Status: ready-for-dev

## Story

As a **developer maintaining the project**,
I want project documentation to accurately describe the release strategy and supported platforms,
so that future contributors understand the distribution model.

## Acceptance Criteria

1. **Given** `docs/project-context.md` **When** read **Then** it documents all three platforms (iOS, iPadOS, macOS) and their distribution channels.
2. **Given** the architecture documentation **When** read **Then** it reflects the current platform abstraction approach (ports/adapters per Epic 67).
3. **Given** the PRD **When** read **Then** platform scope is updated to include macOS as a first-class target.

## Tasks / Subtasks

- [ ] Task 1: Update `docs/project-context.md` (AC: #1)
  - [ ] 1.1 Ensure the Technology Stack section lists all three platforms: iOS, iPadOS, macOS (native)
  - [ ] 1.2 Document distribution model: single universal app on App Store for iPhone, iPad, and Mac
  - [ ] 1.3 Verify the "Universal app" line reflects reality (currently says "iPhone + iPad + Mac (native, not Catalyst)")
  - [ ] 1.4 Add any macOS-specific rules discovered during Epics 66–67 (e.g., platform-conditional patterns, port abstractions)
- [ ] Task 2: Update architecture documentation (AC: #2)
  - [ ] 2.1 Document the ports/adapters pattern in `Peach/Core/Ports/` for platform abstraction
  - [ ] 2.2 Document which ports have platform-specific implementations: `HapticFeedback`, `AudioSessionInterruptionMonitor`, lifecycle notifications
  - [ ] 2.3 Document the `#if os()` usage policy: prefer port abstractions, use `#if os()` only at the composition root or in platform-specific implementations
  - [ ] 2.4 Reference Epic 67 as the origin of the platform abstraction approach
- [ ] Task 3: Update the PRD (AC: #3)
  - [ ] 3.1 Locate the PRD and update platform scope to list macOS as a first-class target
  - [ ] 3.2 Add macOS-specific features: keyboard shortcuts, native Settings scene (Cmd+,), menu bar integration
  - [ ] 3.3 Document MIDI input as cross-platform (iOS and macOS)
- [ ] Task 4: Verify consistency across all docs (AC: #1, #2, #3)
  - [ ] 4.1 Ensure no document still describes Peach as iOS-only
  - [ ] 4.2 Ensure platform list is consistent: iOS, iPadOS, macOS everywhere

## Dev Notes

This is a **documentation-only story**. No code changes.

### Files to Update

- `docs/project-context.md` — primary AI agent context file; line 29 already mentions "Universal app — iPhone + iPad + Mac (native, not Catalyst)" but may need expansion
- Architecture documentation (likely `docs/arc42/` or similar) — needs ports/adapters documentation
- PRD — needs macOS scope update

### Key Facts to Document

**Platform abstraction (from Epic 67):**
- Port protocols in `Peach/Core/Ports/`: `HapticFeedback`, `MIDIInput`, `NotePlayer`, `RhythmPlayer`, `UserSettings`, etc.
- Platform-conditional implementations composed at the app entry point (`PeachApp.swift`)
- 18 files contain `#if os()` conditionals — this is the boundary, not scattered throughout

**macOS-specific features (from Epic 66):**
- Keyboard shortcuts for all training interactions (Story 66.5)
- Native `Settings` scene with Cmd+, (Story 66.6)
- Full menu bar: Training, Profile, Help, File menus (Story 66.7)
- Platform-conditional audio session (`AVAudioSession` iOS-only, Story 66.2)
- Platform-conditional lifecycle notifications (`NSApplication` vs `UIApplication`, Story 66.3)
- Haptic feedback no-op on macOS (Story 66.4)

**Distribution model:**
- Single universal binary on the App Store
- Supports iPhone, iPad, and Mac natively (not Catalyst, not "Designed for iPad")

### Project Structure Notes

- Docs directory: `docs/`
- Architecture docs: check for `docs/arc42/` or similar structure
- PRD location: check `docs/` root

### References

- Epic 66 stories: `docs/implementation-artifacts/66-*.md`
- Epic 67 story: `docs/implementation-artifacts/67-*.md` (platform ports)

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created
