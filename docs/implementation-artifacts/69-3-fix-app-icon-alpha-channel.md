# Story 69.3: Fix App Icon Alpha Channel

Status: ready-for-dev

## Story

As a **developer preparing for submission**,
I want the app icon exported without an alpha channel,
so that Apple does not reject it for containing transparency.

## Acceptance Criteria

1. **Given** the AppIcon asset **When** inspected **Then** the PNG has no alpha channel (RGB, not RGBA).
2. **Given** the icon **When** viewed on a home screen **Then** it renders identically to the current icon (no visual change).
3. **Given** the project **When** built for both iOS and macOS **Then** no icon-related build warnings appear.

## Tasks / Subtasks

- [ ] Inspect current icon for alpha channel (AC: #1)
  - [ ] Run: `file Peach/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
  - [ ] Run: `sips -g hasAlpha Peach/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
  - [ ] If alpha is present, proceed with re-export
- [ ] Re-export icon without alpha channel (AC: #1, #2)
  - [ ] Use `sips` to flatten alpha: `sips -s format png --setProperty formatOptions 0 -s hasAlpha false <file>`
  - [ ] Alternatively: open in Preview, export as PNG without alpha
  - [ ] Verify result: `sips -g hasAlpha` should report `false`, `sips -g pixelWidth -g pixelHeight` should match original dimensions
- [ ] Visual comparison: confirm no visible change from removing alpha (AC: #2)
- [ ] Build both platforms: `bin/build.sh && bin/build.sh -p mac` (AC: #3)

## Dev Notes

Apple requires app icons to be opaque (no alpha channel). The icon is at `Peach/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`. Xcode may emit `ASSETCATALOG_WARNINGS` if alpha is present, or Apple may reject during upload processing.

The `sips` command-line tool (macOS built-in) can strip alpha without changing visual appearance, provided the icon doesn't use transparency. If the icon relies on transparency for visual effect, composite it onto a solid background first.

### Project Structure Notes

Only `Peach/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` is modified. No code changes.

### References

- Apple HIG: [App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- Apple docs: App icon must not contain alpha/transparency

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created
