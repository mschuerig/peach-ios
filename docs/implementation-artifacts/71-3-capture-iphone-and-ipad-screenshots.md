# Story 71.3: Capture iPhone and iPad Screenshots

Status: done

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

- [x] Task 1: Prepare realistic training data (AC: #3)
  - [x] Run several training sessions across multiple disciplines to populate the profile with data
  - [x] Ensure the perceptual profile visualization has enough data points to look meaningful
  - [x] Verify data appears on both iPhone and iPad simulators (or use shared SwiftData store)
- [x] Task 2: Capture iPhone screenshots (AC: #1)
  - [x] Launch app on iPhone 17 Pro Max Simulator (6.9" display)
  - [x] Capture Start Screen showing all training disciplines
  - [x] Capture training sessions in progress (Compare Pitch, Match Pitch, Compare Intervals, Match Intervals)
  - [x] Capture Profile Screen with populated perceptual profile visualization
  - [x] Capture Settings screen
  - [x] Verify each screenshot is 1320x2868 px
- [x] Task 3: Capture iPad screenshots (AC: #2)
  - [x] Launch app on iPad Pro 13-inch (M4) Simulator
  - [x] Capture Start Screen
  - [x] Capture training sessions in progress (Compare Pitch, Match Pitch, Compare Intervals, Match Intervals)
  - [x] Capture Profile Screen with populated data
  - [x] Capture Settings screen
  - [x] Verify each screenshot is 2064x2752 px
- [x] Task 4: Review and compare (AC: #4)
  - [x] Compare iPhone and iPad screenshots side by side
  - [x] Verify layouts adapt appropriately (no stretched or cramped UI)
  - [x] Verify text is readable at both sizes
  - [x] Check that screenshots collectively tell a clear story of the app's functionality
- [x] Task 5: Organize files (AC: #1, #2)
  - [x] Store screenshots in `marketing/screenshots/iphone/`
  - [x] Store screenshots in `marketing/screenshots/ipad/`
  - [x] Use descriptive filenames: `01-start-screen.png`, `02-compare-pitch.png`, etc.

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

Manual capture by user (Michael) on 2026-05-04, with verification assistance from Claude (claude-opus-4-7).

### Debug Log References

None.

### Completion Notes List

- Captured 7 screenshots per device (start screen, four training disciplines — Compare Pitch, Match Pitch, Compare Intervals, Match Intervals — profile screen, settings screen).
- Initial capture used wrong devices (iPhone 17 Pro at 1206×2622, iPad Air 13" at 2048×2732); re-captured on iPhone 17 Pro Max (1320×2868) and iPad Pro 13-inch M4 (2064×2752) to match App Store Connect's required dimensions for the largest iPhone and iPad display classes.
- Profile screenshots show months of varied training data across all four shipping disciplines — confidence bands, trend lines, and numerical scores all populated (no empty states). AC #3 verified.
- iPad layout shows four chart cards visible, iPhone shows three; layout adapts cleanly without stretched UI. AC #4 verified.
- Locale note: simulator was set to English language with German region, so iPad status bar shows `100 %` (German number formatting). App text is fully English. Acceptable for initial release; can be tightened to en_US region later if desired.

### File List

- marketing/screenshots/iphone/01-start-screen.png (added)
- marketing/screenshots/iphone/02-compare-pitch.png (added)
- marketing/screenshots/iphone/03-match-pitch.png (added)
- marketing/screenshots/iphone/04-compare-interval.png (added)
- marketing/screenshots/iphone/05-match-interval.png (added)
- marketing/screenshots/iphone/06-profile-screen.png (added)
- marketing/screenshots/iphone/07-settings-screen.png (added)
- marketing/screenshots/ipad/01-start-screen.png (added)
- marketing/screenshots/ipad/02-compare-pitch.png (added)
- marketing/screenshots/ipad/03-match-pitch.png (added)
- marketing/screenshots/ipad/04-compare-interval.png (added)
- marketing/screenshots/ipad/05-match-interval.png (added)
- marketing/screenshots/ipad/06-profile-screen.png (added)
- marketing/screenshots/ipad/07-settings-screen.png (added)

## Change Log

- 2026-03-29: Story created
- 2026-05-04: Screenshots captured at App Store-required dimensions (iPhone 1320×2868, iPad 2064×2752); 7 screens per device covering start, four training disciplines, profile, and settings. Status → done.
