# Story 35.2: Add SF Symbol Icons to Training Buttons

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **musician using Peach**,
I want each training button to have a suitable icon,
so that the Start Screen is more visually appealing and the modes are quickly distinguishable.

## Acceptance Criteria

1. **Given** each training button **When** it is displayed **Then** it shows a leading SF Symbol icon that visually represents the training mode.

2. **Given** dynamic type sizes **When** the user changes text size **Then** icons scale appropriately alongside the text.

3. **Given** VoiceOver **When** a button is focused **Then** the icon does not add redundant accessibility information (decorative).

## Tasks / Subtasks

- [x] Task 1: Choose SF Symbol icons for each training mode (AC: #1)
  - [x] 1.1 Select icons that visually distinguish the four buttons — two "Hear & Compare" buttons and two "Tune & Match" buttons — while communicating each mode's character. Confirm with user before proceeding.
- [x] Task 2: Add `Label` with SF Symbol to each NavigationLink (AC: #1, #2, #3)
  - [x] 2.1 Replace `Text("Hear & Compare")` with `Label("Hear & Compare", systemImage: "ear")` in `singleNotesSection`
  - [x] 2.2 Replace `Text("Tune & Match")` with `Label("Tune & Match", systemImage: "arrow.up.and.down")` in `singleNotesSection`
  - [x] 2.3 Replace `Text("Hear & Compare")` with `Label("Hear & Compare", systemImage: "ear")` in `intervalsSection`
  - [x] 2.4 Replace `Text("Tune & Match")` with `Label("Tune & Match", systemImage: "arrow.up.and.down")` in `intervalsSection`
- [x] Task 3: Ensure icons are decorative for accessibility (AC: #3)
  - [x] 3.1 Verify that SwiftUI `Label` in a `NavigationLink` reads only the text to VoiceOver (default behavior — the icon is decorative). No `.accessibilityLabel` override should be needed. Confirm by reading Apple docs or testing.
- [x] Task 4: Verify dynamic type scaling (AC: #2)
  - [x] 4.1 Confirm `Label` with `systemImage:` scales the SF Symbol alongside text automatically (this is default SwiftUI behavior). No extra code needed.
- [x] Task 5: Add German localization if any new strings introduced (AC: #1)
  - [x] 5.1 No new localization strings expected — button text is unchanged from Story 35.1, and SF Symbols are language-independent. Skipped — no new text added.
- [x] Task 6: Build and run full test suite
  - [x] 6.1 Run `bin/build.sh` to verify no build errors
  - [x] 6.2 Run `bin/test.sh` to verify all tests pass (927 tests passed)

## Dev Notes

### Current Implementation (after Story 35.1)

`Peach/Start/StartScreen.swift` (127 lines) has four `NavigationLink` buttons organized in two sections (`singleNotesSection` and `intervalsSection`), each with a section header (`Text("Single Notes")` / `Text("Intervals")`). The layout uses `HStack` in landscape and `VStack` in portrait, separated by `Divider`.

Current button pattern (repeated 4 times):
```swift
NavigationLink(value: NavigationDestination.comparison(intervals: [.prime])) {
    Text("Hear & Compare")
        .frame(maxWidth: .infinity)
}
.buttonStyle(.borderedProminent)  // or .bordered
.controlSize(.large)
```

### Implementation Approach

Replace `Text(...)` with `Label(..., systemImage:)` inside each `NavigationLink`. The `.frame(maxWidth: .infinity)` modifier stays on the `Label`. This is the minimal change.

```swift
NavigationLink(value: NavigationDestination.comparison(intervals: [.prime])) {
    Label("Hear & Compare", systemImage: "ear")
        .frame(maxWidth: .infinity)
}
```

**SwiftUI `Label` behavior:**
- In a `.bordered`/`.borderedProminent` button, `Label` renders the icon leading the text
- SF Symbols scale with dynamic type automatically — no extra code
- VoiceOver reads the `Label` title text; the icon is decorative by default
- No `.accessibilityLabel` needed (same as Story 35.1 approach)

### SF Symbol Selection Guidance

The four buttons need distinct icons. The same button name appears in both sections ("Hear & Compare" in Single Notes and Intervals), so icons should differentiate the **mode** (comparison vs matching), not the interval context (the section headers already do that).

**Candidate icons (discuss with user):**
- "Hear & Compare" → `ear` (listening/hearing), `waveform` (sound wave comparison), `speaker.wave.2` (audio)
- "Tune & Match" → `tuningfork` (tuning), `slider.horizontal.below.rectangle` (slider-based matching), `dial.medium` (fine-tuning)

Alternatively, all four buttons could use unique icons if the sections feel too similar:
- Single Notes / Hear & Compare → `ear`
- Single Notes / Tune & Match → `tuningfork`
- Intervals / Hear & Compare → `music.note.list` or `ear.badge.waveform`
- Intervals / Tune & Match → `pianokeys` or `slider.horizontal.3`

**The final icon choice should be confirmed with the user during Task 1.**

### Architecture & Constraints

- **Localization**: No new strings needed — button labels unchanged, SF Symbols are language-independent
- **No `.accessibilityLabel` on buttons** — `Label` title serves as the VoiceOver label automatically (confirmed pattern from Story 35.1)
- **No layout changes** — keep spacing, button styles, `.controlSize(.large)`, `.frame(maxWidth: .infinity)` exactly as-is. Layout rework is Story 35.3.
- **Zero third-party dependencies** — SF Symbols are built into iOS
- **iOS 26.0** — all SF Symbol versions available (SF Symbols 6+)

### Key File to Modify

| File | Change |
|------|--------|
| `Peach/Start/StartScreen.swift` | Replace 4 `Text(...)` with `Label(..., systemImage:)` in button content |

No other files need modification. Tests don't assert on button content structure, only layout spacing.

### Testing Standards

- **Swift Testing** framework only (`@Test`, `@Suite`, `#expect`)
- Run full test suite with `bin/test.sh` — never just specific files
- Existing `StartScreenLayoutTests` test spacing values only — no changes needed
- No new test file needed unless icon selection introduces testable logic (unlikely)

### What NOT to Do

- Do NOT change button styles, layout, or spacing — that's Story 35.3
- Do NOT add `.accessibilityLabel` modifiers — `Label` title already serves as VoiceOver label
- Do NOT restructure the view or extract new subviews — keep changes minimal
- Do NOT add new localization strings unless absolutely necessary
- Do NOT use `Image(systemName:)` + `Text(...)` separately — use `Label` which is the SwiftUI-idiomatic approach for icon+text
- Do NOT change section headers ("Single Notes" / "Intervals") — unchanged from Story 35.1

### Previous Story Intelligence (35.1)

Key learnings from Story 35.1:
- StartScreen was significantly reworked: ProfilePreviewView removed, toolbar navigation added, landscape HStack layout with sections
- Section headers added: "Single Notes" and "Intervals" with `.font(.headline)`
- Button labels changed to "Hear & Compare" and "Tune & Match"
- Training screen nav titles also updated to match (ComparisonScreen → "Hear & Compare", PitchMatchingScreen → "Tune & Match")
- 927 tests pass, build clean (3 orphaned ProfilePreviewView tests removed in 35.1 review)
- Localization key ordering matters — keys were sorted alphabetically in review

### Git Intelligence

Recent commits show Story 35.1 implementation and review:
- `72137ae` Review story 35.1: Remove orphaned code and fix localization key ordering
- `0ef06f5` Implement story 35.1: Rename training buttons and rework Start Screen layout

The codebase is clean and ready for the next change.

### Project Structure Notes

- Fully aligned with project structure. Change is isolated to `Peach/Start/StartScreen.swift`.
- No conflicts or variances detected.

### References

- [Source: docs/planning-artifacts/epics.md#Epic 35, Story 35.2]
- [Source: Peach/Start/StartScreen.swift — current button implementation after Story 35.1]
- [Source: docs/project-context.md#Framework-Specific Rules — SwiftUI views, accessibility]
- [Source: docs/implementation-artifacts/35-1-rename-training-buttons-with-user-friendly-labels.md — previous story learnings]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None — clean implementation with no issues.

### Completion Notes List

- Icons chosen with user: `ear` for "Hear & Compare", `arrow.up.and.down` for "Tune & Match" (visual appearance confirmed in Xcode preview)
- Replaced 4 `Text(...)` with `Label(..., systemImage:)` in StartScreen.swift
- SwiftUI `Label` provides decorative icon behavior for VoiceOver and automatic dynamic type scaling — no extra code needed
- No new localization strings introduced (button text unchanged, SF Symbols are language-independent)
- Build succeeded, all 927 tests pass, no regressions

### Change Log

- 2026-03-04: Implemented story 35.2 — added SF Symbol icons to all four training buttons on Start Screen
- 2026-03-04: Code review — 3 LOW documentation issues fixed (stale test count, modified candidate list, missing visual verification note). All ACs verified, all tasks confirmed done, 927 tests pass.

### File List

- `Peach/Start/StartScreen.swift` (modified)
