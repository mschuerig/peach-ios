# Story 71.4: Capture macOS Screenshots

Status: done

## Story

As a **potential user browsing the Mac App Store**,
I want to see screenshots showing Peach running natively on macOS,
so that I can see it looks and feels like a proper Mac app before downloading.

## Acceptance Criteria

1. **Given** macOS screenshots, **When** captured, **Then** at least 3 screenshots show the app in a Mac window at appropriate resolution covering: Start Screen, a training session in progress, and the Profile Screen.
2. **Given** the screenshots, **When** reviewed, **Then** they show Mac-native chrome (title bar, window controls) and demonstrate the app looks at home on macOS.
3. **Given** the Mac App Store requirements, **When** checked, **Then** screenshot dimensions meet Apple's specifications (2880x1800 px for 16" Retina, or 2560x1600 px for 14" Retina).

## Tasks / Subtasks

- [x] Task 1: Prepare realistic training data on Mac (AC: #1)
  - [x] Run the Mac app and complete several training sessions to populate the profile
  - [x] Ensure the perceptual profile visualization has meaningful data
- [x] Task 2: Set up window for capture (AC: #2)
  - [x] Launch the Mac app
  - [x] Resize the window to a size that looks good and fills most of the screenshot area
  - [x] Consider whether to show the app window on a clean desktop or capture just the window
- [x] Task 3: Capture macOS screenshots (AC: #1, #2)
  - [x] Capture Start Screen showing all training modes
  - [x] Capture a training session in progress
  - [x] Capture Profile Screen with populated perceptual profile visualization
  - [x] Ensure Mac-native chrome is visible: title bar with traffic light buttons, window frame
  - [x] Verify the app uses appropriate macOS layout (not a stretched iPhone UI)
- [x] Task 4: Verify dimensions (AC: #3)
  - [x] Check that screenshots meet Mac App Store dimension requirements
  - [x] If capturing full screen: 2880x1800 (16" Retina) or 2560x1600 (14" Retina)
  - [x] If capturing window only: ensure dimensions are at least 1280x800 px (minimum)
  - [x] Resize/adjust if needed to meet Apple's accepted aspect ratios
- [x] Task 5: Organize files (AC: #1)
  - [x] Store screenshots in `marketing/screenshots/mac/`
  - [x] Use descriptive filenames: `01-start-screen.png`, `02-training-session.png`, `03-profile.png`

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

Manual capture by user (Michael) on 2026-05-09, with verification assistance from Claude (claude-opus-4-7).

### Debug Log References

- BetterDisplay used to add a 1440×900 HiDPI scaled mode to a 4K (3840×2160) external monitor; macOS rendered to a 2880×1800 framebuffer letterboxed on the physical 16:9 panel. Screenshots taken with Cmd+Shift+3 are exactly 2880×1800 — the canonical Mac App Store size.
- Captures done from a fresh macOS user account to ensure a clean menu bar and neutral desktop. Training data moved between accounts via the app's CSV export/import (Epic 33/34) rather than copying the SwiftData store directly.

### Completion Notes List

- 7 screenshots captured at exactly 2880×1800 px covering: Start Screen, four shipping training disciplines (Compare Pitch, Match Pitch, Compare Intervals, Match Intervals), Profile Screen, and Settings. AC #1 satisfied (well above the 3-screen minimum).
- All captures show full Mac-native chrome: Apple menu bar at top with Peach app menus (File, Edit, View, Training, Profile, Window, Help), red/yellow/green traffic-light window controls, native window title bars with discipline names. AC #2 satisfied.
- Dimensions verified via `sips -g pixelWidth -g pixelHeight`: every PNG is 2880×1800. AC #3 satisfied.
- Profile screenshot shows two charts (Compare Pitch, Compare Intervals) with populated confidence bands and trend lines; the other two cards are below the fold given the default window height. Acceptable for initial release; can be re-shot with a larger or scrolled window if App Store browsing data suggests reviewers want all four visible.
- Settings screenshot shows the Settings window stacked over the Match Intervals training window — authentic to native macOS Cmd+, behaviour. Slightly busier than a clean shot but reflects real use.
- App window occupies roughly 25% of the 2880×1800 frame; the remainder is neutral grey desktop. Honest framing of Peach's default window size on Mac (portrait-shaped layout, mirroring iOS); reviewers may prefer richer framing later, but ACs do not require window size to fill the screenshot.
- Training-screen titles in the window title bar (e.g. "Compare Pitch", "Match Pitch") confirm the title fix from the prior session is in effect.

### File List

- marketing/screenshots/mac/01-start-screen.png (added)
- marketing/screenshots/mac/02-compare-pitch.png (added)
- marketing/screenshots/mac/03-match-pitch.png (added)
- marketing/screenshots/mac/04-compare-interval.png (added)
- marketing/screenshots/mac/05-match-interval.png (added)
- marketing/screenshots/mac/06-profile-screen.png (added)
- marketing/screenshots/mac/07-settings-screen.png (added)

## Change Log

- 2026-03-29: Story created
- 2026-05-09: macOS screenshots captured at App Store-required 2880×1800 dimensions; 7 screens covering start, four training disciplines, profile, and settings. Captured from a fresh user account on a 4K monitor scaled to a 1440×900 HiDPI mode via BetterDisplay. Status → done.
