# Story 71.3: Capture iPhone and iPad Screenshots

Status: ready-for-dev

## Story

As a **potential user browsing the App Store on iPhone or iPad**,
I want to see screenshots showing real training sessions and results,
so that I can understand the app's interface and functionality before downloading.

## Acceptance Criteria

1. **Given** iPhone screenshots, **When** captured on iPhone 16 Pro Max Simulator (6.9"), **Then** at least 3 screenshots at 1320x2868 px covering: Start Screen, a training session in progress, and the Profile Screen.
2. **Given** iPad screenshots, **When** captured on iPad Pro 13" Simulator, **Then** at least 3 screenshots at 2064x2752 px covering the same screens.
3. **Given** all screenshots, **When** reviewed, **Then** they show realistic training data (not empty states) — the profile visualization has data, training sessions show active interactions.
4. **Given** the screenshots, **When** compared across device sizes, **Then** the app looks good at both iPhone and iPad sizes with appropriate layout adaptations.

## Tasks / Subtasks

- [ ] Task 1: Prepare realistic training data (AC: #3)
  - [ ] Run several training sessions across multiple modes to populate the profile with data
  - [ ] Ensure the perceptual profile visualization has enough data points to look meaningful
  - [ ] Verify data appears on both iPhone and iPad simulators (or use shared SwiftData store)
- [ ] Task 2: Capture iPhone 16 Pro Max screenshots (AC: #1)
  - [ ] Launch app on iPhone 16 Pro Max Simulator (6.9" display)
  - [ ] Capture Start Screen showing all training modes
  - [ ] Capture a training session in progress (e.g., pitch comparison with a trial visible)
  - [ ] Capture Profile Screen with populated perceptual profile visualization
  - [ ] Verify each screenshot is 1320x2868 px (Cmd+S in Simulator saves at correct resolution)
  - [ ] Consider capturing 1-2 additional screens: Settings, interval training, or rhythm training
- [ ] Task 3: Capture iPad Pro 13" screenshots (AC: #2)
  - [ ] Launch app on iPad Pro 13" Simulator
  - [ ] Capture Start Screen
  - [ ] Capture a training session in progress
  - [ ] Capture Profile Screen with populated data
  - [ ] Verify each screenshot is 2064x2752 px
- [ ] Task 4: Review and compare (AC: #4)
  - [ ] Compare iPhone and iPad screenshots side by side
  - [ ] Verify layouts adapt appropriately (no stretched or cramped UI)
  - [ ] Verify text is readable at both sizes
  - [ ] Check that screenshots collectively tell a clear story of the app's functionality
- [ ] Task 5: Organize files (AC: #1, #2)
  - [ ] Store screenshots in `marketing/screenshots/iphone/`
  - [ ] Store screenshots in `marketing/screenshots/ipad/`
  - [ ] Use descriptive filenames: `01-start-screen.png`, `02-training-session.png`, `03-profile.png`

## Dev Notes

### Exact Dimensions (required by App Store Connect)
- **iPhone 6.9" (iPhone 16 Pro Max):** 1320x2868 px — required for the largest iPhone display size class
- **iPad 13" (iPad Pro):** 2064x2752 px — required for the largest iPad display size class
- These are the mandatory sizes. Smaller device sizes are optional (App Store Connect can auto-scale).

### Device List
- iPhone 16 Pro Max Simulator — Xcode Simulator, 6.9" display
- iPad Pro 13" Simulator — Xcode Simulator, 13" display

### Screens to Capture (minimum 3 per device)
1. **Start Screen** — shows all seven training modes, establishes the app's visual identity
2. **Training session** — an active pitch comparison or pitch matching session showing the core interaction
3. **Profile Screen** — perceptual profile visualization with data, demonstrating the value of continued training

### Optional Additional Screenshots (up to 10 per device)
4. Interval training session
5. Rhythm training session
6. Settings screen (showing tuning system selection, MIDI options)
7. CSV export flow

### Tips for Realistic Data
- Complete at least 10-15 training sessions across different modes before capturing
- Vary performance so the profile shows interesting patterns, not flat lines
- The profile visualization is the most visually compelling screen — make sure it has rich data

### Capture Process
1. Open Simulator, select correct device
2. Navigate to desired screen in the app
3. Press Cmd+S to save screenshot (saves to Desktop by default)
4. Move to `marketing/screenshots/` with appropriate subfolder

### Project Structure Notes

- Screenshots stored in `marketing/screenshots/iphone/` and `marketing/screenshots/ipad/`

### References

- [App Store Connect screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications)

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created
