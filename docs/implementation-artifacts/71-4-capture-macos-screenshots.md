# Story 71.4: Capture macOS Screenshots

Status: ready-for-dev

## Story

As a **potential user browsing the Mac App Store**,
I want to see screenshots showing Peach running natively on macOS,
so that I can see it looks and feels like a proper Mac app before downloading.

## Acceptance Criteria

1. **Given** macOS screenshots, **When** captured, **Then** at least 3 screenshots show the app in a Mac window at appropriate resolution covering: Start Screen, a training session in progress, and the Profile Screen.
2. **Given** the screenshots, **When** reviewed, **Then** they show Mac-native chrome (title bar, window controls) and demonstrate the app looks at home on macOS.
3. **Given** the Mac App Store requirements, **When** checked, **Then** screenshot dimensions meet Apple's specifications (2880x1800 px for 16" Retina, or 2560x1600 px for 14" Retina).

## Tasks / Subtasks

- [ ] Task 1: Prepare realistic training data on Mac (AC: #1)
  - [ ] Run the Mac app and complete several training sessions to populate the profile
  - [ ] Ensure the perceptual profile visualization has meaningful data
- [ ] Task 2: Set up window for capture (AC: #2)
  - [ ] Launch the Mac app
  - [ ] Resize the window to a size that looks good and fills most of the screenshot area
  - [ ] Consider whether to show the app window on a clean desktop or capture just the window
- [ ] Task 3: Capture macOS screenshots (AC: #1, #2)
  - [ ] Capture Start Screen showing all training modes
  - [ ] Capture a training session in progress
  - [ ] Capture Profile Screen with populated perceptual profile visualization
  - [ ] Ensure Mac-native chrome is visible: title bar with traffic light buttons, window frame
  - [ ] Verify the app uses appropriate macOS layout (not a stretched iPhone UI)
- [ ] Task 4: Verify dimensions (AC: #3)
  - [ ] Check that screenshots meet Mac App Store dimension requirements
  - [ ] If capturing full screen: 2880x1800 (16" Retina) or 2560x1600 (14" Retina)
  - [ ] If capturing window only: ensure dimensions are at least 1280x800 px (minimum)
  - [ ] Resize/adjust if needed to meet Apple's accepted aspect ratios
- [ ] Task 5: Organize files (AC: #1)
  - [ ] Store screenshots in `marketing/screenshots/mac/`
  - [ ] Use descriptive filenames: `01-start-screen.png`, `02-training-session.png`, `03-profile.png`

## Dev Notes

### Mac App Store Screenshot Dimensions
- **Required:** At least one set matching an accepted Mac display resolution
- **2880x1800 px** — 16" MacBook Pro Retina (recommended, most common submission size)
- **2560x1600 px** — 14" MacBook Pro Retina (also accepted)
- **Minimum:** 1280x800 px
- **Maximum:** 2880x1800 px
- Accepted formats: PNG, JPEG (PNG preferred for UI screenshots)

### Screens to Capture (minimum 3)
1. **Start Screen** — all seven training modes visible, establishes the Mac-native look
2. **Training session** — active session showing core interaction in a Mac window
3. **Profile Screen** — perceptual profile visualization with training data

### Mac-Native Appearance Checklist
- Window title bar with red/yellow/green traffic light buttons visible
- Appropriate window size (not too small, not full-screen unless that looks better)
- Mac-style spacing and typography (SwiftUI should handle this automatically)
- If the app has a toolbar or sidebar on Mac, show it

### Capture Methods
- **Window only:** Cmd+Shift+4, then Space, then click the window — captures with shadow (can remove shadow via `defaults write com.apple.screencapture disable-shadow -bool true`)
- **Full screen region:** Cmd+Shift+4, drag to select — useful for exact dimensions
- **Full screen:** Cmd+Shift+3 — captures entire display, crop to needed dimensions afterward
- Recommended: capture the window with no shadow for the cleanest look in the App Store

### Tips
- Use Light mode for screenshots unless the app has a particularly compelling Dark mode appearance
- Ensure the desktop wallpaper is neutral if any desktop is visible
- Run on a Retina display to get 2x resolution screenshots

### Project Structure Notes

- Screenshots stored in `marketing/screenshots/mac/`

### References

- [App Store Connect screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications)
- [Mac App Store product page best practices](https://developer.apple.com/macos/submit/)

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created
