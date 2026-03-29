# Story 70.1: Platform Polish Audit — iOS / iPadOS

Status: ready-for-dev

## Story

As a **musician using Peach on iPhone or iPad**,
I want the app to feel like a native iOS/iPadOS app with no rough edges,
so that training is seamless and professional on my device.

## Acceptance Criteria

1. **Given** iPhone in portrait and landscape **When** using all training modes **Then** layouts render correctly with no clipped text, overlapping controls, or broken scrolling.
2. **Given** iPad in all size classes (full screen, Split View, Slide Over) **When** using the app **Then** layouts adapt properly and remain usable.
3. **Given** iPad with pointer (trackpad/mouse) **When** hovering over interactive elements **Then** hover effects appear where appropriate.
4. **Given** any training screen **When** audio is playing and the user rotates the device **Then** audio continues uninterrupted and the UI adapts smoothly.
5. **Given** the app **When** tested with Dynamic Type at the largest accessibility size **Then** all screens remain usable.

## Tasks / Subtasks

- [ ] Task 1: Test all six training modes on iPhone in portrait and landscape (AC: #1)
  - [ ] 1.1 Pitch Comparison — verify button layout, feedback indicator, cents display
  - [ ] 1.2 Pitch Matching — verify pitch indicator, target display, mic permission prompt
  - [ ] 1.3 Interval Pitch Comparison — verify interval label rendering, button layout
  - [ ] 1.4 Interval Pitch Matching — verify interval display and matching UI
  - [ ] 1.5 Rhythm Offset Detection — verify timing display, playback controls
  - [ ] 1.6 Continuous Rhythm Matching — verify rhythm grid, real-time feedback
- [ ] Task 2: Test iPad multitasking scenarios (AC: #2)
  - [ ] 2.1 Full-screen on iPad — all screens
  - [ ] 2.2 Split View 50/50 — verify compact layout activates
  - [ ] 2.3 Split View 33/67 and 67/33
  - [ ] 2.4 Slide Over — verify narrow layout
- [ ] Task 3: Test iPad pointer support (AC: #3)
  - [ ] 3.1 Hover over training buttons (Higher/Lower, rhythm tap targets)
  - [ ] 3.2 Hover over Start Screen training cards
  - [ ] 3.3 Hover over Settings controls
  - [ ] 3.4 Hover over Profile screen interactive elements
- [ ] Task 4: Test rotation during active training (AC: #4)
  - [ ] 4.1 Rotate during pitch playback — audio must not glitch
  - [ ] 4.2 Rotate during rhythm playback — timing must stay synchronized
  - [ ] 4.3 Verify `TrainingLifecycleCoordinator` does not pause session on rotation
- [ ] Task 5: Test Dynamic Type accessibility sizes (AC: #5)
  - [ ] 5.1 Set system text size to AX5 (largest) — walk through every screen
  - [ ] 5.2 Verify no truncated labels, overlapping text, or unreachable buttons
  - [ ] 5.3 Verify ScrollView wrapping where content exceeds screen
- [ ] Task 6: Document all issues found (AC: #1–#5)
  - [ ] 6.1 Create issues list with severity (must-fix / nice-to-have)
  - [ ] 6.2 File each must-fix issue as a task in Story 70.3

## Dev Notes

This is a **manual testing story**. No code changes expected here — only issue discovery and documentation.

### Testing Checklist

**Devices to test:**
- iPhone 17 Pro (or latest available Simulator)
- iPhone SE-class compact device (smallest supported width)
- iPad Pro 13-inch
- iPad mini (smallest iPad form factor)

**Training modes to cover (6 total):**
- `PitchDiscriminationScreen` — pitch comparison and interval pitch comparison
- `PitchMatchingScreen` — pitch matching and interval pitch matching
- `RhythmOffsetDetectionScreen` — rhythm offset detection
- `ContinuousRhythmMatchingScreen` — continuous rhythm matching

**Key layout files from Story 7.3:**
- Size-class-aware layouts use `@Environment(\.verticalSizeClass)` and `@Environment(\.horizontalSizeClass)`
- Compact vertical size class (landscape iPhone) reflows buttons to horizontal arrangement

### Project Structure Notes

- Training screens: `Peach/PitchDiscrimination/`, `Peach/PitchMatching/`, `Peach/RhythmOffsetDetection/`, `Peach/ContinuousRhythmMatching/`
- Lifecycle handling: `Peach/App/TrainingLifecycleCoordinator.swift`
- Navigation: `Peach/App/ContentView.swift`, `Peach/App/NavigationDestination.swift`
- Start screen: `Peach/Start/StartScreen.swift`

### References

- Story 7.3 (iPhone/iPad/orientation support): `docs/implementation-artifacts/7-3-iphone-ipad-portrait-and-landscape-support.md`
- Story 7.2 (accessibility audit): `docs/implementation-artifacts/7-2-accessibility-audit-and-custom-component-labels.md`

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created
