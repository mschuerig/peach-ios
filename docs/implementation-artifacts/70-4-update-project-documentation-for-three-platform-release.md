# Story 70.4: Update Project Documentation for Three-Platform Release

Status: done

## Story

As a **developer maintaining the project**,
I want project documentation to accurately describe the release strategy and supported platforms,
so that future contributors understand the distribution model.

## Acceptance Criteria

1. **Given** `docs/project-context.md` **When** read **Then** it documents all three platforms (iOS, iPadOS, macOS) and their distribution channels.
2. **Given** the architecture documentation **When** read **Then** it reflects the current platform abstraction approach (ports/adapters per Epic 67).
3. **Given** the PRD **When** read **Then** platform scope is updated to include macOS as a first-class target.

## Tasks / Subtasks

- [x] Task 1: Update `docs/project-context.md` (AC: #1)
  - [x] 1.1 Ensure the Technology Stack section lists all three platforms: iOS, iPadOS, macOS (native)
  - [x] 1.2 Document distribution model: single universal app on App Store for iPhone, iPad, and Mac
  - [x] 1.3 Verify the "Universal app" line reflects reality (currently says "iPhone + iPad + Mac (native, not Catalyst)")
  - [x] 1.4 Add any macOS-specific rules discovered during Epics 66–67 (e.g., platform-conditional patterns, port abstractions)
- [x] Task 2: Update architecture documentation (AC: #2)
  - [x] 2.1 Document the ports/adapters pattern in `Peach/Core/Ports/` for platform abstraction
  - [x] 2.2 Document which ports have platform-specific implementations: `HapticFeedback`, `AudioSessionInterruptionMonitor`, lifecycle notifications
  - [x] 2.3 Document the `#if os()` usage policy: prefer port abstractions, use `#if os()` only at the composition root or in platform-specific implementations
  - [x] 2.4 Reference Epic 67 as the origin of the platform abstraction approach
- [x] Task 3: Update the PRD (AC: #3)
  - [x] 3.1 Locate the PRD and update platform scope to list macOS as a first-class target
  - [x] 3.2 Add macOS-specific features: keyboard shortcuts, native Settings scene (Cmd+,), menu bar integration
  - [x] 3.3 Document MIDI input as cross-platform (iOS and macOS)
- [x] Task 4: Verify consistency across all docs (AC: #1, #2, #3)
  - [x] 4.1 Ensure no document still describes Peach as iOS-only
  - [x] 4.2 Ensure platform list is consistent: iOS, iPadOS, macOS everywhere

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
Claude Opus 4.6 + arc42 Documentation Architect agent (for Task 2)

### Debug Log References
None — documentation-only story, no code changes.

### Completion Notes List
- **Task 1**: Updated `project-context.md`: deployment target now lists all three platforms, distribution model expanded, added "Platform Abstraction" section documenting port protocols and `#if os()` policy, added guidance for new platform-conditional components.
- **Task 2**: Updated `arc42.md` (v2.0 → v3.0) via arc42 documentation architect agent: updated 10 sections including business/technical context diagrams, deployment view, dependency rules, new Section 8.8 (Platform Abstraction), new ADR-9, quality tree/scenarios, and glossary entries. Cross-section consistency verified.
- **Task 3**: Updated `prd.md`: platform scope updated throughout, "Mobile App Specific Requirements" renamed to "Platform-Specific Requirements", added macOS-specific FRs (FR105-FR108), MIDI documented as cross-platform.
- **Task 4**: Verified consistency across all living docs. Also updated `architecture.md` (5 fixes) and `ux-design-specification.md` (6 fixes). Historical documents (brainstorming, research reports, old stories) left as point-in-time snapshots.

### File List
- docs/project-context.md (modified)
- docs/arc42.md (modified)
- docs/planning-artifacts/prd.md (modified)
- docs/planning-artifacts/architecture.md (modified)
- docs/planning-artifacts/ux-design-specification.md (modified)
- docs/implementation-artifacts/sprint-status.yaml (modified)

## Change Log

- 2026-03-29: Story created
- 2026-04-25: All tasks completed — updated five documentation files to reflect three-platform (iOS, iPadOS, macOS) scope
