# Story 70.2: Platform Polish Audit — macOS

Status: ready-for-dev

## Story

As a **musician using Peach on Mac**,
I want the app to follow Mac conventions and feel like a native desktop app,
so that it integrates naturally with my Mac workflow.

## Acceptance Criteria

1. **Given** the Mac app **When** resizing the window **Then** all layouts adapt fluidly with no broken constraints or overlapping elements.
2. **Given** the Mac app **When** using keyboard shortcuts **Then** all training interactions respond correctly.
3. **Given** the Mac app **When** pressing Cmd+, **Then** the Settings window opens natively.
4. **Given** the Mac app **When** switching away and back (Cmd+Tab) **Then** the training session stops but the user remains on the training screen.
5. **Given** the Mac app **When** using menu bar items **Then** all menu commands work and are correctly enabled/disabled based on app state.
6. **Given** the Mac app **When** using MIDI input **Then** MIDI devices connect and events are received identically to iOS.

## Tasks / Subtasks

- [ ] Task 1: Test window resizing behavior (AC: #1)
  - [ ] 1.1 Resize to minimum window size — verify no clipping or overflow
  - [ ] 1.2 Resize to very large window — verify content scales or centers appropriately
  - [ ] 1.3 Test all six training modes at narrow, medium, and wide window widths
  - [ ] 1.4 Verify Start Screen card grid adapts to window width
  - [ ] 1.5 Verify Profile Screen charts render correctly at all sizes
- [ ] Task 2: Test keyboard shortcuts (AC: #2)
  - [ ] 2.1 Verify all training keyboard shortcuts from Story 66.5 work
  - [ ] 2.2 Pitch comparison: arrow keys or assigned keys for Higher/Lower
  - [ ] 2.3 Rhythm modes: spacebar or assigned key for tap input
  - [ ] 2.4 Verify shortcuts do not conflict with system or menu bar shortcuts
  - [ ] 2.5 Verify shortcuts are disabled when not on a training screen
- [ ] Task 3: Test native Settings scene (AC: #3)
  - [ ] 3.1 Cmd+, opens Settings window
  - [ ] 3.2 Settings changes apply immediately to active training
  - [ ] 3.3 Settings window can coexist with main window
  - [ ] 3.4 Closing Settings window does not affect main window state
- [ ] Task 4: Test app switching and lifecycle (AC: #4)
  - [ ] 4.1 Cmd+Tab away during active training — session pauses
  - [ ] 4.2 Cmd+Tab back — user remains on training screen, can resume
  - [ ] 4.3 Minimize window during training — same pause behavior
  - [ ] 4.4 Close and reopen window — verify state handling
- [ ] Task 5: Test menu bar commands (AC: #5)
  - [ ] 5.1 Training menu: each discipline navigates correctly
  - [ ] 5.2 Profile menu: "Show Profile" navigates to Profile Screen
  - [ ] 5.3 Help menu: all help items open correct content
  - [ ] 5.4 File menu: Export/Import commands work (Cmd+E, Cmd+I)
  - [ ] 5.5 Verify menu items enable/disable based on current screen context
- [ ] Task 6: Test MIDI input on macOS (AC: #6)
  - [ ] 6.1 Connect a MIDI device — verify it appears and connects
  - [ ] 6.2 Send MIDI note events during pitch matching — verify response
  - [ ] 6.3 Disconnect and reconnect MIDI device — verify graceful handling
  - [ ] 6.4 Verify MIDI input works identically to iOS behavior
- [ ] Task 7: Document all issues found (AC: #1–#6)
  - [ ] 7.1 Create issues list with severity (must-fix / nice-to-have)
  - [ ] 7.2 File each must-fix issue as a task in Story 70.3

## Dev Notes

This is a **manual testing story** on Mac hardware. No code changes expected here — only issue discovery and documentation.

### Testing Checklist

**Environment:**
- macOS on Apple Silicon Mac
- Test with both built-in display and external display if available
- Test with both trackpad and mouse

**Key macOS-specific files:**
- `Peach/App/PeachCommands.swift` — menu bar commands
- `Peach/App/PeachApp.swift` — `Settings` scene, `#if os(macOS)` branches
- `Peach/Settings/SettingsScreen.swift` — platform-conditional settings UI

**Keyboard shortcuts (from Story 66.5):**
- Defined in training screen views via `.keyboardShortcut()` modifiers
- Must not conflict with `PeachCommands` menu bar shortcuts

**MIDI integration:**
- Port abstraction: `Peach/Core/Ports/MIDIInput.swift`
- MIDIKit integration handles platform differences internally

### Project Structure Notes

- Platform-conditional code uses `#if os(macOS)` / `#if os(iOS)` — 18 files contain platform conditionals (per Epic 67 audit)
- Lifecycle notifications: `Peach/App/TrainingLifecycleCoordinator.swift` uses platform-conditional notification names
- Haptic feedback: `Peach/PitchDiscrimination/HapticFeedbackManager.swift` — no-op on macOS via protocol abstraction

### References

- Story 66.5 (keyboard shortcuts): `docs/implementation-artifacts/66-5-keyboard-shortcuts-for-training.md`
- Story 66.6 (native Settings scene): `docs/implementation-artifacts/66-6-native-macos-settings-scene.md`
- Story 66.7 (menu bar integration): `docs/implementation-artifacts/66-7-menu-bar-integration.md`
- Story 66.1 (macOS compilation): `docs/implementation-artifacts/66-1-add-macos-destination-and-fix-compilation.md`

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created
