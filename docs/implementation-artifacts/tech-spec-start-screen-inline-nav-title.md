---
title: 'Start Screen Inline Navigation Title'
slug: 'start-screen-inline-nav-title'
created: '2026-03-08'
status: 'ready-for-dev'
stepsCompleted: [1, 2, 3, 4]
tech_stack: ['SwiftUI']
files_to_modify: ['Peach/Start/StartScreen.swift']
code_patterns: ['toolbar principal placement', 'navigationBarTitleDisplayMode']
test_patterns: []
---

# Tech-Spec: Start Screen Inline Navigation Title

**Created:** 2026-03-08

## Overview

### Problem Statement

The "Peach" app title on the start screen uses the default large navigation title display mode, which renders it below the toolbar icons (info, profile, settings) and takes up unnecessary vertical space. Additionally, in landscape orientation the system renders the inline title in a smaller font than in portrait, creating visual inconsistency.

### Solution

Replace `.navigationTitle("Peach")` with a custom `ToolbarItem(placement: .principal)` containing a `Text("Peach")` view with an explicit font, ensuring the title appears inline between the leading and trailing toolbar icons with a consistent size across all orientations.

### Scope

**In Scope:**
- Remove `.navigationTitle("Peach")` from StartScreen
- Add a `ToolbarItem(placement: .principal)` with a styled `Text("Peach")` view
- Ensure consistent title font size in portrait and landscape

**Out of Scope:**
- Other navigation bar styling changes
- Icon changes or reordering
- Layout changes to the card content area
- Localization of the app name (it's a proper noun)

## Context for Development

### Codebase Patterns

- StartScreen already uses a `.toolbar` block with `ToolbarItem` and `ToolbarItemGroup` for the info, profile, and settings buttons (lines 44-63)
- The view detects `@Environment(\.verticalSizeClass)` for compact/regular layout but the title should be orientation-independent

### Files to Reference

| File | Purpose |
| ---- | ------- |
| `Peach/Start/StartScreen.swift` | The only file to modify; contains the navigation title and toolbar |

### Technical Decisions

- **Custom principal toolbar item over `.navigationTitle`**: The standard `.navigationBarTitleDisplayMode(.inline)` still lets iOS shrink the title font in compact height class. A `.principal` toolbar item gives full control over the font.
- **Font choice: `.headline`**: Matches the visual weight of a standard inline navigation title while remaining consistent across size classes. Adjust if a different weight is preferred after visual review.

## Implementation Plan

### Tasks

- [ ] Task 1: Replace large navigation title with custom inline principal title
  - File: `Peach/Start/StartScreen.swift`
  - Action: Remove `.navigationTitle("Peach")` (line 43). Add a `ToolbarItem(placement: .principal)` inside the existing `.toolbar` block (before or after the existing toolbar items):
    ```swift
    ToolbarItem(placement: .principal) {
        Text("Peach")
            .font(.headline)
    }
    ```
  - Notes: The existing `ToolbarItem(placement: .navigationBarLeading)` and `ToolbarItemGroup(placement: .navigationBarTrailing)` remain unchanged. No other files need modification.

### Acceptance Criteria

- **AC1: Title appears inline in portrait**
  - Given the app is launched in portrait orientation
  - When the start screen is displayed
  - Then "Peach" appears centered in the navigation bar between the info button (leading) and profile/settings buttons (trailing)

- **AC2: Title appears inline in landscape**
  - Given the app is in landscape orientation
  - When the start screen is displayed
  - Then "Peach" appears centered in the navigation bar with the same font size as in portrait

- **AC3: No large title area**
  - Given the start screen is displayed
  - When the user views the screen in any orientation
  - Then there is no large title area below the navigation bar

## Additional Context

### Dependencies

None. This is a self-contained UI change.

### Testing Strategy

This is a visual-only change with no business logic. Manual verification in portrait and landscape on iPhone and iPad is sufficient. No unit tests required.

### Notes

- If `.headline` doesn't match the desired visual weight, consider `.body.bold()` or a custom size. Visual review in Simulator recommended.
- The existing `ToolbarItem(placement: .navigationBarLeading)` and `ToolbarItemGroup(placement: .navigationBarTrailing)` remain unchanged.
