# Story 35.3: Visual Design Polish

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **musician using Peach**,
I want the Start Screen to feel welcoming and well-designed,
so that opening the app is an inviting experience.

## Acceptance Criteria

1. **Given** the Start Screen **When** it is displayed **Then** spacing, typography, and layout are improved over the current plain button stack **And** training buttons use a card-style or visually distinct treatment (final design to be confirmed during implementation).

2. **Given** the Start Screen layout **When** viewed in portrait and landscape on iPhone and iPad **Then** the layout adapts gracefully to all form factors **And** the one-handed, thumb-friendly design principle is preserved.

3. **Given** navigation to Profile, Settings, and Info **When** the screen is redesigned **Then** all navigation paths remain accessible and discoverable.

## Tasks / Subtasks

- [ ] Task 1: Design card-style button treatment (AC: #1)
  - [ ] 1.1 Discuss visual direction with user: card-style buttons with rounded corners, subtle shadows/fills, or material-based backgrounds. Confirm approach before coding.
  - [ ] 1.2 Implement the chosen button style replacing `.borderedProminent`/`.bordered` + `.controlSize(.large)` with a custom card treatment that visually distinguishes the four training modes.
  - [ ] 1.3 Ensure "Hear & Compare (Single Notes)" retains visual prominence as the primary/recommended training mode.

- [ ] Task 2: Improve typography and spacing (AC: #1, #2)
  - [ ] 2.1 Review section headers ("Single Notes", "Intervals") — consider `.title3` or `.title2` instead of `.headline`, or add a subtitle/description.
  - [ ] 2.2 Adjust spacing between sections and within sections for a more spacious, breathable layout.
  - [ ] 2.3 Extract any new layout constants to `static` methods for testability (matching existing `vstackSpacing` pattern).

- [ ] Task 3: Verify adaptive layout on all form factors (AC: #2)
  - [ ] 3.1 Verify portrait iPhone, landscape iPhone, portrait iPad, landscape iPad all render gracefully.
  - [ ] 3.2 Ensure thumb-friendly button targets are preserved (minimum 44pt touch targets).
  - [ ] 3.3 Verify dynamic type scaling at all accessibility sizes.

- [ ] Task 4: Verify all navigation paths remain functional (AC: #3)
  - [ ] 4.1 Confirm toolbar items (Info, Profile, Settings) remain accessible and discoverable after redesign.
  - [ ] 4.2 Confirm all four training NavigationLinks still navigate correctly.

- [ ] Task 5: Update layout tests if constants change (AC: #1, #2)
  - [ ] 5.1 Update `StartScreenLayoutTests` if spacing constants change or new static layout methods are added.
  - [ ] 5.2 Run `bin/build.sh` and `bin/test.sh` to verify clean build and all tests pass.

- [ ] Task 6: Add German localization for any new strings (AC: #1)
  - [ ] 6.1 If any new descriptive text is added (e.g., subtitles), add German translations via `bin/add-localization.py`.

## Dev Notes

### Current Implementation (after Story 35.2)

`Peach/Start/StartScreen.swift` (128 lines) has:
- **Portrait**: `VStack` with `Spacer` → `singleNotesSection` → `Divider` → `intervalsSection` → `Spacer`, spacing 16pt
- **Landscape**: `HStack` with `singleNotesSection` → `Divider` → `intervalsSection`, spacing 24pt
- **Section pattern**: `VStack` → `Text("Section Header").font(.headline)` → 2× `NavigationLink` with `Label(..., systemImage:).frame(maxWidth: .infinity)`
- **Button styles**: First button `.borderedProminent` + `.controlSize(.large)`, remaining three `.bordered` + `.controlSize(.large)`
- **Toolbar**: Leading info button, trailing profile + settings NavigationLinks
- **Navigation**: `NavigationDestination` enum with `.comparison(intervals:)`, `.pitchMatching(intervals:)`, `.settings`, `.profile`

### Design Direction Candidates

Discuss with user in Task 1. Options include:

**Option A: Card-style buttons**
- Replace system button styles with custom `RoundedRectangle` backgrounds
- Subtle fill color differentiation (e.g., `.tint` for primary, `.secondary` background for others)
- Rounded corners (12–16pt), subtle shadow or stroke
- Icon and text arranged vertically or horizontally within the card

**Option B: Material-based cards**
- Use `.ultraThinMaterial` or `.regularMaterial` backgrounds
- Gives a modern, translucent feel consistent with iOS design language
- Works well in both light and dark mode automatically

**Option C: Grouped list style**
- Wrap sections in a `Form` or `List` with `.insetGrouped` style
- Leverages system styling, minimal custom code
- May feel too "settings-like" for a start screen

**The final approach must be confirmed with the user before implementation.**

### Architecture & Constraints

- **File to modify**: `Peach/Start/StartScreen.swift` — all changes stay in this one file (possibly extracting a `TrainingCardButton` subview within `Start/` if >40 lines)
- **Subview extraction**: If the card button view exceeds ~40 lines, extract to `Start/TrainingCardView.swift` per project conventions
- **No new dependencies**: Pure SwiftUI — no third-party libraries
- **iOS 26.0**: All SwiftUI APIs available (materials, `UnevenRoundedRectangle`, etc.)
- **`@Environment(\.verticalSizeClass)`**: Keep detecting compact/regular for layout switching
- **Static layout methods**: Extract new spacing/sizing constants to `static` methods for testability (pattern: `StartScreen.vstackSpacing(isCompact:)`)
- **No business logic in views**: This is purely visual — no session, data, or service changes
- **Accessibility**: `Label` for icon+text (established in 35.2), no `.accessibilityLabel` overrides needed unless text changes. Minimum 44pt touch targets.
- **Dark mode**: Test in both light and dark. System materials and semantic colors handle this automatically.
- **Localization**: No new strings expected unless subtitles/descriptions are added. If so, use `bin/add-localization.py`.

### Key Files

| File | Change |
|------|--------|
| `Peach/Start/StartScreen.swift` | Rework button styles, spacing, typography |
| `Peach/Start/TrainingCardView.swift` | New file only if card button subview exceeds ~40 lines |
| `PeachTests/Start/StartScreenLayoutTests.swift` | Update if spacing constants change or new static methods added |

### Testing Standards

- **Swift Testing** framework only (`@Test`, `@Suite`, `#expect`)
- Run full test suite with `bin/test.sh` — never just specific files
- Build with `bin/build.sh`
- Existing `StartScreenLayoutTests` test `vstackSpacing` static method — update if values change, add tests for new static methods
- Existing `StartScreenTests` test instantiation and navigation — should continue passing unchanged
- No UI snapshot tests in this project — visual verification is manual (Xcode preview or simulator)

### What NOT to Do

- Do NOT change navigation logic or `NavigationDestination` — navigation is unchanged
- Do NOT modify toolbar items (Info, Profile, Settings) positioning — only visual treatment
- Do NOT add new screens or sheets — this is a visual polish of the existing screen
- Do NOT change button labels or icons — those were finalized in Stories 35.1 and 35.2
- Do NOT use UIKit — pure SwiftUI only
- Do NOT add third-party dependencies
- Do NOT create `Utils/`, `Helpers/`, or `Common/` directories
- Do NOT add `.accessibilityLabel` overrides — `Label` title serves as VoiceOver label automatically
- Do NOT remove the `Divider` between sections without discussing with user first

### Previous Story Intelligence (35.1 + 35.2)

**From Story 35.1:**
- StartScreen was significantly reworked: ProfilePreviewView removed, toolbar navigation added, landscape HStack layout with sections
- Section headers added: "Single Notes" and "Intervals" with `.font(.headline)`
- Button labels changed to "Hear & Compare" and "Tune & Match"
- Training screen nav titles updated to match
- 927 tests pass, build clean
- Localization key ordering matters — keys sorted alphabetically in review

**From Story 35.2:**
- Icons chosen: `ear` for "Hear & Compare", `arrow.up.and.down` for "Tune & Match"
- Replaced `Text(...)` with `Label(..., systemImage:)` — minimal change
- SwiftUI `Label` provides decorative icon behavior for VoiceOver and automatic dynamic type scaling
- No new localization strings needed
- 927 tests pass, no regressions

**Key pattern**: Both previous stories made minimal, focused changes. This story has more design freedom but should still follow the principle of clean, focused changes.

### Git Intelligence

Recent commits (all Story 35.x work):
- `0db340b` Review story 35.2: Fix documentation issues and mark done
- `07a527e` Implement story 35.2: Add SF Symbol Icons to Training Buttons
- `0433d10` Create story 35.2: Add SF Symbol Icons to Training Buttons
- `72137ae` Review story 35.1: Remove orphaned code and fix localization key ordering
- `0ef06f5` Implement story 35.1: Rename training buttons and rework Start Screen layout

Codebase is clean and ready for the next change.

### Project Structure Notes

- All changes isolated to `Peach/Start/` directory
- Possible new file `TrainingCardView.swift` in `Peach/Start/` if subview extraction needed
- No conflicts or variances with project structure
- No cross-feature coupling — Start/ is the navigation router (exempt from cross-feature rules)

### References

- [Source: docs/planning-artifacts/epics.md#Epic 35, Story 35.3]
- [Source: Peach/Start/StartScreen.swift — current implementation after Story 35.2]
- [Source: docs/project-context.md#Framework-Specific Rules — SwiftUI views, responsive layout, subview extraction]
- [Source: docs/project-context.md#Code Quality — file placement, naming conventions]
- [Source: docs/implementation-artifacts/35-2-add-sf-symbol-icons-to-training-buttons.md — previous story learnings]
- [Source: docs/implementation-artifacts/35-1-rename-training-buttons-with-user-friendly-labels.md — layout rework learnings]
- [Source: PeachTests/Start/StartScreenLayoutTests.swift — existing layout tests]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
