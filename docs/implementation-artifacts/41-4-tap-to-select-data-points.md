# Story 41.4: Tap-to-Select Data Points

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want to tap any data point on my chart to see its details,
so that I can inspect specific periods of my training history.

## Acceptance Criteria

1. **Given** the scrollable chart, **When** the user taps on or near a data point, **Then** a vertical selection indicator (`RuleMark`) appears at the selected X position, **And** an annotation popover shows: EWMA value, +/- stddev, date/period label, and record count.

2. **Given** a selected data point, **When** the user taps a different data point, **Then** the selection moves to the new point.

3. **Given** a selected data point, **When** the user taps empty space or scrolls, **Then** the selection is dismissed.

4. **Given** the annotation popover near a chart edge, **When** it renders, **Then** it uses `.overflowResolution(.fitToChart)` to prevent clipping.

5. **Given** the scrollable chart, **When** the user drags to scroll, **Then** scrolling works normally — tap gestures do not block scroll gestures, **And** this uses `.chartGesture` with `SpatialTapGesture` (not `.chartOverlay` + `.onTapGesture`).

## Tasks / Subtasks

- [ ] Task 1: Selection state and gesture handling (AC: #1, #2, #3, #5)
  - [ ] 1.1 Write tests: tapping at an index X sets `selectedBucketIndex` to the nearest bucket index. Use `findNearestBucketIndex(atX:bucketCount:)` static helper.
  - [ ] 1.2 Write tests: tapping at X < -0.5 or X >= bucketCount returns nil (empty space dismissal)
  - [ ] 1.3 Add `@State private var selectedBucketIndex: Int?` to `ProgressChartView`
  - [ ] 1.4 Add `.chartGesture { proxy in SpatialTapGesture().onEnded { ... } }` modifier to chart. Resolve tap X coordinate via `proxy.value(atX:)`, snap to nearest bucket index using `findNearestBucketIndex(atX:bucketCount:)`. Set `selectedBucketIndex` or nil.
  - [ ] 1.5 Dismiss selection on scroll: add `.onChange(of: scrollPosition) { selectedBucketIndex = nil }`

- [ ] Task 2: Selection indicator RuleMark (AC: #1)
  - [ ] 2.1 Add conditional `RuleMark(x: .value("Selected", Double(selectedIndex)))` inside the `Chart` block, after data marks (Layer 7). Style: `.foregroundStyle(.gray.opacity(0.5))`, `.lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))`.

- [ ] Task 3: Annotation popover (AC: #1, #4)
  - [ ] 3.1 Write tests: `annotationDateLabel(_:size:)` returns descriptive date strings: months → "Jan 2026", days → "Mon, Mar 5", sessions → time "14:30"
  - [ ] 3.2 Implement `annotationDateLabel(_:size:)` static helper using `DateFormatter` with appropriate format per `BucketSize`
  - [ ] 3.3 Add `.annotation(position: .top, overflowResolution: .fitToChart)` on the selection RuleMark. Content: VStack with EWMA (`formatEWMA`), stddev (`formatStdDev`), date label (`annotationDateLabel`), and record count. Style: `.font(.caption)`, compact padding, rounded background.

- [ ] Task 4: Static chart support (AC: #1, #3)
  - [ ] 4.1 Pass `selectedBucketIndex` binding through to `chartContent` (or capture via closure) so selection works on both scrollable and static charts
  - [ ] 4.2 For static charts (no scroll), add the same `.chartGesture` modifier. No `.onChange(of: scrollPosition)` needed since static charts don't scroll — tap empty space dismissal is handled by `findNearestBucketIndex` returning nil.

- [ ] Task 5: Run full test suite (AC: all)
  - [ ] 5.1 Run `bin/test.sh` — all existing + new tests pass
  - [ ] 5.2 Verify no dependency violations with `bin/check-dependencies.sh`

## Dev Notes

### Gesture Architecture: `.chartGesture` vs `.chartOverlay` + `.onTapGesture`

**MUST use `.chartGesture`** (iOS 17+). The `.chartOverlay` + `.onTapGesture` approach conflicts with `.chartScrollableAxes(.horizontal)` — the tap gesture steals scroll gestures, making the chart unscrollable. `.chartGesture` is specifically designed to coexist with chart scrolling.

```swift
// CORRECT:
.chartGesture { proxy in
    SpatialTapGesture()
        .onEnded { value in
            guard let x: Double = proxy.value(atX: value.location.x) else {
                selectedBucketIndex = nil
                return
            }
            selectedBucketIndex = Self.findNearestBucketIndex(atX: x, bucketCount: bucketCount)
        }
}

// WRONG — breaks scrolling:
.chartOverlay { proxy in
    GeometryReader { geo in
        Rectangle().fill(.clear).onTapGesture { location in ... }
    }
}
```

### Index Snapping Logic

The X-axis is index-based (`Double`). Each bucket sits at integer index positions. Tapping between buckets should snap to the nearest one:

```swift
static func findNearestBucketIndex(atX x: Double, bucketCount: Int) -> Int? {
    let index = Int(round(x))
    guard index >= 0, index < bucketCount else { return nil }
    return index
}
```

This is a pure static function — fully testable without SwiftUI.

### Selection Indicator: RuleMark Inside Chart Block

Add as **Layer 7** (after all data marks, before chartOverlay):

```swift
// Layer 7: Selection indicator
if let selectedIndex = selectedBucketIndex, selectedIndex < buckets.count {
    RuleMark(x: .value("Selected", Double(selectedIndex)))
        .foregroundStyle(.gray.opacity(0.5))
        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
        .annotation(position: .top, overflowResolution: .fitToChart) {
            annotationView(for: buckets[selectedIndex])
        }
}
```

The RuleMark clips to the plot area (same behavior as zone dividers from 41.3). The `.annotation` modifier attaches the popover directly to the mark — no manual positioning needed.

### Annotation Content

The annotation popover shows 4 pieces of information:

```swift
private func annotationView(for bucket: TimeBucket) -> some View {
    VStack(alignment: .leading, spacing: 2) {
        Text(Self.annotationDateLabel(bucket.periodStart, size: bucket.bucketSize))
            .font(.caption2)
            .foregroundStyle(.secondary)
        Text(Self.formatEWMA(bucket.mean))
            .font(.caption.bold())
        Text(Self.formatStdDev(bucket.stddev))
            .font(.caption2)
            .foregroundStyle(.secondary)
        Text(String(localized: "\(bucket.recordCount) records"))
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
    .padding(6)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
}
```

### Annotation Date Label Helper

Create a new static helper `annotationDateLabel(_:size:)` that returns a descriptive date string based on bucket granularity:

- **Month**: `"Jan 2026"` — `DateFormatter` with `"MMM yyyy"`
- **Day**: `"Mon, Mar 5"` — `DateFormatter` with `"E, MMM d"`
- **Session**: `"14:30"` — `DateFormatter` with `"HH:mm"`

This is a static function, so fully testable.

### Dismiss on Scroll

When the user scrolls, clear the selection:

```swift
.onChange(of: scrollPosition) { _, _ in
    selectedBucketIndex = nil
}
```

This goes on the scrollable chart body only (static charts don't scroll).

### Passing Selection State to `chartContent`

Currently `chartContent` doesn't know about selection. Two options:

**Option A (recommended):** Since `selectedBucketIndex` is `@State` on the view, it's already accessible in all instance methods. Just reference `selectedBucketIndex` directly in `chartContent` — no parameter changes needed. The `.chartGesture` modifier goes outside `chartContent`, on the caller side (`scrollableChartBody` / `staticChartBody`).

**Option B:** Pass as parameter. Adds unnecessary complexity.

Use Option A — `chartContent` already has access to `self.selectedBucketIndex` as an instance property.

### Localization

Add one localization key:
- `"\(count) records"` — German: `"\(count) Einträge"` — via `bin/add-localization.py`

Use `String(localized:)` for the annotation record count string.

### Rendering Layers (Updated Z-Order)

1. `RectangleMark` — zone background tints (bottommost)
2. `RuleMark(x:)` — zone and year boundary divider lines
3. `AreaMark` — stddev band
4. `LineMark` — EWMA line
5. `PointMark` — session dots
6. `RuleMark(y:)` — baseline
7. **`RuleMark(x:)` + `.annotation` — selection indicator with popover** (NEW)
8. `chartOverlay` — year labels (topmost, text only)

### Existing Code to Understand

**`ProgressChartView.swift` (current state after 41.3):**
- `chartContent(buckets:yDomain:separatorData:yearLabels:)` — main chart rendering with 6 layers. Selection indicator + annotation becomes Layer 7.
- `scrollPosition: Double` — `@State`, index-based scroll state. Used for `.onChange` to dismiss selection.
- `visibleBucketCount = 8` — scroll domain length
- `scrollableChartBody` — applies `.chartScrollableAxes`, `.chartXVisibleDomain`, `.chartScrollPosition`. The `.chartGesture` modifier goes here.
- `staticChartBody` — no scroll modifiers. The `.chartGesture` modifier also goes here.
- `formatEWMA(_:)` — delegates to `TrainingStatsView.formattedCents(value)`. Reuse for annotation.
- `formatStdDev(_:)` — prepends "±". Reuse for annotation.
- `formatAxisLabel(_:size:index:buckets:)` — axis labels, handles "Today" for sessions. Do NOT reuse for annotation — annotation needs more descriptive labels.

**`TimeBucket` struct (in `ProgressTimeline.swift`):**
```swift
struct TimeBucket {
    let periodStart: Date
    var periodEnd: Date
    let bucketSize: BucketSize
    var mean: Double
    var stddev: Double
    var recordCount: Int
}
```

### Testing Patterns

Follow existing `ProgressChartViewTests` patterns:

**Static helper tests:**
1. `findNearestBucketIndex(atX:bucketCount:)`: exact index, between indices (rounds), negative X → nil, X >= count → nil, X at -0.5 boundary → 0, empty bucket count → nil
2. `annotationDateLabel(_:size:)`: month format, day format, session format

**Key test patterns (from 41.3):**
- Every `@Test` function must be `async`
- Behavioral descriptions: `@Test("snaps to nearest bucket index when tapping between data points")`
- Use `#expect(value == expected)`
- Struct-based test suites, factory methods for fixtures
- Use the existing `makeBucketArray(count:)` test helper

### File Placement

Modified files:
- `Peach/Profile/ProgressChartView.swift` — add selection state, `.chartGesture`, selection RuleMark with annotation, `findNearestBucketIndex`, `annotationDateLabel`, `annotationView`
- `PeachTests/Profile/ProgressChartViewTests.swift` — add tests for `findNearestBucketIndex` and `annotationDateLabel`
- `Peach/Resources/Localizable.xcstrings` — add record count string via `bin/add-localization.py`

### What NOT To Do

- Do NOT use `.chartOverlay` + `.onTapGesture` — breaks scroll gestures. Use `.chartGesture` with `SpatialTapGesture`.
- Do NOT use `@GestureState` or `DragGesture` — `SpatialTapGesture` is the correct gesture for tap-to-select.
- Do NOT add a separate `PointMark` for selected state highlight — the `RuleMark` + `.annotation` is sufficient.
- Do NOT modify `chartContent` signature to accept selection binding — use the `@State` property directly.
- Do NOT create a separate selection view or overlay view — keep everything in the Chart block.
- Do NOT add explicit `@MainActor` annotations (redundant with default isolation).
- Do NOT use XCTest — use Swift Testing (`@Test`, `@Suite`, `#expect`).
- Do NOT import third-party dependencies.
- Do NOT modify Core/ files — this story is purely UI-layer in `ProgressChartView.swift`.
- Do NOT add granularity zone labels — removed per user feedback in 41.3.
- Do NOT add TipKit tips — that is Story 41.6.
- Do NOT add narrative headlines — that is Story 41.8.
- Do NOT add session-level markers — that is Story 41.9.
- Do NOT restore the fixed Y-axis HStack — removed in 41.3 because alignment was unreliable.
- Do NOT use hardcoded color values (hex, RGB) — use semantic colors.
- Do NOT create `Utils/` or `Helpers/` directories.

### Project Structure Notes

- All chart view changes stay in `Peach/Profile/ProgressChartView.swift`
- No Core/ files modified — this is a pure UI feature
- `ProfileScreen.swift` should NOT need changes
- Run `bin/check-dependencies.sh` after implementation to verify import rules

### Previous Story Intelligence (41.3)

Key learnings from Story 41.3 implementation:
- `RuleMark(x:)` inside `Chart` clips correctly to the plot area — use this same pattern for the selection indicator
- `.chartOverlay` is only for TEXT (year labels) — never for interactive elements or lines
- Zone separator dividers use `.foregroundStyle(.secondary)` — selection indicator should use a different style (`.gray.opacity(0.5)` + dashed) to distinguish from zone dividers
- Index-based coordinates: every bucket is at `Double(i)`, selection snapping rounds to nearest integer
- The `chartContent` method is an instance method that can access `@State` properties directly — no need to pass `selectedBucketIndex` as parameter
- 1047 tests pass after 41.3 completion

### Git Intelligence

Recent commits:
```
d97a9be Review story 41.3: extract magic number, remove dead code, add story 41.10
23dcaef Extend period for generated test data to 180 days.
6efd5f5 Fix chart UX: separator positions, label spacing, Today label, session bridge
8f0263f Fix story 41.3: remove zone labels, fix session rendering, strip trailing dots
67a9b41 Implement story 41.3: granularity zone separators
```

All recent work on Story 41.3. Code patterns: commit messages follow `{Verb} story {id}: {description}`. Tests use Swift Testing. Chart uses index-based `Double` X-axis.

### References

- [Source: docs/planning-artifacts/epics.md#Story 41.4] — Full acceptance criteria and technical hints
- [Source: docs/planning-artifacts/epics.md#Epic 41 Requirements] — FR5: Tap-to-select data point annotations
- [Source: docs/implementation-artifacts/41-3-granularity-zone-separators.md] — Previous story: zone separators, RuleMark patterns, index-based rendering
- [Source: docs/implementation-artifacts/41-2-scrollable-chart-with-fixed-y-axis.md] — Scrollable chart, scroll position, data windowing
- [Source: Peach/Profile/ProgressChartView.swift] — Current chart implementation to be extended
- [Source: Peach/Core/Profile/ProgressTimeline.swift] — TimeBucket struct definition
- [Source: docs/project-context.md] — Coding conventions, testing rules, file placement

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
