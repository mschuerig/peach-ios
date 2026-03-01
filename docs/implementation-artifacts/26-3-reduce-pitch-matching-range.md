# Story 26.3: Reduce Pitch Matching Range

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **musician using Peach's pitch matching mode**,
I want the pitch matching range reduced from ±100 cents to ±20 cents,
so that the slider provides finer granularity for precise pitch discrimination training.

## Acceptance Criteria

### AC 1: Pitch matching range is ±20 cents
**Given** a pitch matching session is active
**When** a new challenge is generated
**Then** the initial random cent offset is within the range -20.0 to +20.0 cents (inclusive)
**And** the slider's full travel maps to -20.0 to +20.0 cents (not ±100)

### AC 2: Slider-to-cent mapping uses the new range
**Given** the user is adjusting pitch with the slider
**When** the slider is at its maximum position (top, normalized value 1.0)
**Then** the cent offset is +20.0 cents from the target note
**And** at minimum position (bottom, normalized value -1.0), the cent offset is -20.0 cents

### AC 3: Commit pitch uses the new range
**Given** the user releases the slider to commit their pitch
**When** `commitPitch` is called with the final normalized slider value
**Then** the cent offset is calculated using the ±20 cent range
**And** the recorded `userCentError` reflects the actual deviation from the target

### AC 4: Existing feedback bands still function correctly
**Given** the feedback indicator displays after a pitch matching attempt
**When** the user's cent error is within the ±20 cent range
**Then** the `deadCenter`, `close`, and `moderate` bands trigger correctly per existing thresholds (0, <10, 10–30)
**And** the `far` band (>30 cents) is effectively unreachable with the reduced range — this is expected and acceptable

### AC 5: Existing tests updated to reflect new range
**Given** the full test suite
**When** all tests are run
**Then** all existing tests pass with zero regressions
**And** tests that previously asserted ±100 cent boundaries now assert ±20 cent boundaries
**And** tests that computed expected frequencies using 100.0/1200.0 now use 20.0/1200.0

## Tasks / Subtasks

- [ ] Task 1: Update `initialCentOffsetRange` constant (AC: 1, 2, 3)
  - [ ] Change `PitchMatchingSession.initialCentOffsetRange` from `-100.0...100.0` to `-20.0...20.0`
  - [ ] Verify `adjustPitch`, `commitPitch`, and `generateChallenge` all derive from this single constant (no other changes needed in session)

- [ ] Task 2: Update tests to reflect new range (AC: 5)
  - [ ] Update `PitchMatchingSessionTests.swift` line 105-106: change `#expect(challenge.initialCentOffset >= -100)` to `-20` and `<= 100` to `20`
  - [ ] Update `PitchMatchingSessionTests.swift` line 505: change `100.0 / 1200.0` to `20.0 / 1200.0` in expected frequency calculation

- [ ] Task 3: Run full test suite (AC: 5)
  - [ ] `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [ ] All tests pass with zero regressions

## Dev Notes

### Developer Context — Critical Implementation Intelligence

This story is a **single-constant change** in `PitchMatchingSession.swift` with corresponding test updates. The entire pitch matching range is derived from one constant, making this change minimal and contained.

**The Problem:** The current ±100 cent range is too wide for effective pitch discrimination training. 100 cents = 1 semitone, meaning the slider covers a full semitone up and down. For musicians training pitch matching, ±20 cents provides much finer control — the same physical slider travel now maps to a 5x smaller frequency range, making subtle adjustments possible.

**The Solution:** Change the single `initialCentOffsetRange` constant from `-100.0...100.0` to `-20.0...20.0`. All three usages (`adjustPitch`, `commitPitch`, `generateChallenge`) reference `Self.initialCentOffsetRange.upperBound` or `Self.initialCentOffsetRange`, so they all update automatically.

**Scope of change:** 1 source file + 1 test file. Very low complexity.

### Key Code Location

**The constant (single source of truth):**

| File | Line | Code |
|------|------|------|
| `Peach/PitchMatching/PitchMatchingSession.swift` | 53 | `private static let initialCentOffsetRange: ClosedRange<Double> = -100.0...100.0` |

**Derived usages (no changes needed — they reference the constant):**

| File | Line | Usage |
|------|------|-------|
| `PitchMatchingSession.swift` | 110 | `adjustPitch`: `value * Self.initialCentOffsetRange.upperBound` |
| `PitchMatchingSession.swift` | 125 | `commitPitch`: `value * Self.initialCentOffsetRange.upperBound` |
| `PitchMatchingSession.swift` | 221 | `generateChallenge`: `Double.random(in: Self.initialCentOffsetRange)` |

**Tests requiring update:**

| File | Line | Current | New |
|------|------|---------|-----|
| `PeachTests/PitchMatching/PitchMatchingSessionTests.swift` | 105 | `#expect(challenge.initialCentOffset >= -100)` | `>= -20` |
| `PeachTests/PitchMatching/PitchMatchingSessionTests.swift` | 106 | `#expect(challenge.initialCentOffset <= 100)` | `<= 20` |
| `PeachTests/PitchMatching/PitchMatchingSessionTests.swift` | 505 | `440.0 * pow(2.0, 100.0 / 1200.0)` | `440.0 * pow(2.0, 20.0 / 1200.0)` |

### Feedback Band Impact Analysis

The `PitchMatchingFeedbackIndicator.band(centError:)` thresholds are:
- `deadCenter`: |error| rounds to 0
- `close`: |error| < 10 cents (green)
- `moderate`: |error| 10–30 cents (yellow)
- `far`: |error| > 30 cents (red)

With ±20 cent range, the maximum possible `userCentError` is approximately ±20 cents. The `far` band (>30 cents) becomes effectively unreachable. This is **expected and correct** — in a ±20 cent exercise, being 20 cents off is "moderate", not "far". No feedback threshold changes needed.

### What This Story Changes

| File | Change | Why |
|------|--------|-----|
| `Peach/PitchMatching/PitchMatchingSession.swift` | Change `initialCentOffsetRange` from `-100.0...100.0` to `-20.0...20.0` | Core range reduction |
| `PeachTests/PitchMatching/PitchMatchingSessionTests.swift` | Update 3 test assertions to use ±20 instead of ±100 | Test alignment |

### What This Story Does NOT Change

- `Peach/PitchMatching/VerticalPitchSlider.swift` — operates in normalized -1.0...1.0, completely decoupled from cent range
- `Peach/PitchMatching/PitchMatchingFeedbackIndicator.swift` — feedback bands remain unchanged
- `Peach/PitchMatching/PitchMatchingScreen.swift` — no layout changes
- `Peach/PitchMatching/PitchMatchingSession.swift` (beyond the constant) — `adjustPitch`, `commitPitch`, `generateChallenge` logic unchanged
- Data models (`PitchMatchingChallenge`, `CompletedPitchMatching`, `PitchMatchingRecord`) — field types unchanged
- Profile, observers, settings — all untouched
- Localization — no new strings

### Architecture Compliance

1. **Single source of truth** — one constant change propagates to all usages [Source: Peach/PitchMatching/PitchMatchingSession.swift:53]
2. **No cross-feature coupling** — change contained within `PitchMatching/` [Source: docs/project-context.md#Dependency Direction Rules]
3. **No new dependencies** — no new imports, frameworks, or packages
4. **No documentation drive-bys** — only modify the constant and test assertions [Source: docs/project-context.md#Code Quality]

### Library/Framework Requirements

- **Swift 6.2** with strict concurrency — no concurrency changes in this story
- **No new dependencies** — zero third-party packages
- **No localization changes** — no new user-facing strings

### File Structure — Files to Modify

| File | Change | Why |
|------|--------|-----|
| `Peach/PitchMatching/PitchMatchingSession.swift` | Change constant value | Core range reduction |
| `PeachTests/PitchMatching/PitchMatchingSessionTests.swift` | Update 3 assertions | Test alignment |

**Files NOT to modify:**
- `Peach/PitchMatching/VerticalPitchSlider.swift` — slider is normalized, no cent knowledge
- `Peach/PitchMatching/PitchMatchingFeedbackIndicator.swift` — bands unchanged
- `Peach/PitchMatching/PitchMatchingScreen.swift` — layout unchanged
- All other test files — no behavioral changes

### Testing Requirements

**TDD approach:**
1. Update test assertions for ±20 range first (tests will fail because code still uses ±100)
2. Change the constant (tests pass)
3. Run full suite

**Specific test changes:**
- `PitchMatchingSessionTests.swift:105-106` — boundary assertions: `-100` → `-20`, `100` → `20`
- `PitchMatchingSessionTests.swift:505` — expected frequency: `100.0/1200.0` → `20.0/1200.0`

**Automated test execution:** `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'` — all tests must pass.

### Previous Story Intelligence (Story 26.2)

From story 26.2 implementation:
- `PitchMatchingScreen` layout was restructured: feedback indicator moved from `.overlay` to above slider
- `PitchMatchingSession` logic was NOT modified in 26.2
- Added `PitchMatchingScreenTests.swift` with `feedbackAnimation` tests
- Code review added `.accessibilityHidden` for opacity-0 feedback indicator
- **Commit pattern:** `Add story X.Y: Title` → `Implement story X.Y: Title` → `Fix code review findings for story X.Y and mark done`

### Git Intelligence

Recent commits:
```
f021146 Fix code review findings for story 26.2 and mark done
c96bdee Implement story 26.2: Reposition Feedback Indicator Above Slider
64187d6 Add story 26.2: Reposition Feedback Indicator Above Slider
f40ce41 Fix code review findings for story 26.1 and mark done
c1c8cf8 Implement story 26.1: Delay targetNote Until Slider Touch
```

### Project Structure Notes

- All changes within `Peach/PitchMatching/` and `PeachTests/PitchMatching/`
- No new files created
- No new directories needed
- No cross-feature coupling introduced

### References

- [Source: Peach/PitchMatching/PitchMatchingSession.swift:53] — `initialCentOffsetRange` constant
- [Source: Peach/PitchMatching/PitchMatchingSession.swift:110] — `adjustPitch` cent offset calculation
- [Source: Peach/PitchMatching/PitchMatchingSession.swift:125] — `commitPitch` cent offset calculation
- [Source: Peach/PitchMatching/PitchMatchingSession.swift:221] — `generateChallenge` random offset
- [Source: PeachTests/PitchMatching/PitchMatchingSessionTests.swift:105-106] — boundary assertions
- [Source: PeachTests/PitchMatching/PitchMatchingSessionTests.swift:505] — frequency calculation test
- [Source: Peach/PitchMatching/PitchMatchingFeedbackIndicator.swift:38-48] — feedback band thresholds
- [Source: Peach/PitchMatching/VerticalPitchSlider.swift:97-103] — normalized slider range
- [Source: docs/project-context.md#Testing Rules] — Swift Testing, full suite before commit
- [Source: docs/implementation-artifacts/26-2-reposition-feedback-indicator-above-slider.md] — Previous story context
- [Source: docs/implementation-artifacts/sprint-status.yaml#Epic 26] — "Reduce cent range from ±100 to ±20"

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
