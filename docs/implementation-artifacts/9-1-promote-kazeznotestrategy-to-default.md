# Story 9.1: Promote KazezNoteStrategy to Default Training Strategy

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **musician using Peach**,
I want the training algorithm to maintain a smooth, continuous difficulty progression regardless of which note is playing,
So that I experience steady convergence to my threshold without jarring difficulty jumps when the note changes.

## Acceptance Criteria

1. **Given** KazezNoteStrategy is the active training strategy
   **When** a note is selected for a comparison
   **Then** the note is selected randomly within `settings.noteRangeMin...settings.noteRangeMax`

2. **Given** KazezNoteStrategy with a `lastComparison` available
   **When** the next comparison's difficulty is determined
   **Then** it uses the Kazez chain from `lastComparison.centDifference` (narrowing on correct, widening on incorrect)
   **And** the difficulty never jumps due to a note change

3. **Given** KazezNoteStrategy with no `lastComparison` (cold start)
   **When** the first comparison's difficulty is determined
   **Then** it uses `profile.overallMean` if it returns a non-nil value (i.e., at least one note has been trained)
   **And** falls back to `settings.maxCentDifference` if `profile.overallMean` is nil (no profile data)

4. **Given** the app is launched
   **When** `PeachApp` creates the training session
   **Then** it uses `KazezNoteStrategy` as the default `NextNoteStrategy`
   **And** `AdaptiveNoteStrategy` remains in the codebase for potential future use

5. **Given** the Settings Screen
   **When** displayed
   **Then** the "Natural vs. Mechanical" slider is removed (it only applies to AdaptiveNoteStrategy)

6. **Given** the `naturalVsMechanical` property on `TrainingSettings`
   **When** this story is complete
   **Then** the property remains in `TrainingSettings` (it's still used by `AdaptiveNoteStrategy`)
   **But** it is no longer read from `@AppStorage` or displayed in Settings UI

7. **Given** the full test suite
   **When** all tests are run
   **Then** all existing tests pass (KazezNoteStrategy tests updated for new behavior, AdaptiveNoteStrategy tests unchanged)
   **And** new tests verify the cold-start-from-profile behavior

## Tasks / Subtasks

- [ ] Task 1: Update KazezNoteStrategy to respect settings range (AC: #1)
  - [ ] 1.1 Replace hardcoded `noteRangeMin = 48` / `noteRangeMax = 72` with `settings.noteRangeMin` / `settings.noteRangeMax`
  - [ ] 1.2 Update existing tests to verify range from settings is used

- [ ] Task 2: Add cold-start-from-profile behavior (AC: #3)
  - [ ] 2.1 When `lastComparison` is nil, check `profile.overallMean` — if profile has any trained notes (sampleCount > 0), use `overallMean` as starting difficulty instead of `settings.maxCentDifference`
  - [ ] 2.2 If no profile data exists, keep current behavior (start at `settings.maxCentDifference`)
  - [ ] 2.3 Write tests: cold start with empty profile → maxCentDifference; cold start with existing profile → overallMean

- [ ] Task 3: Switch default strategy in PeachApp (AC: #4)
  - [ ] 3.1 In `PeachApp.init()`, change `AdaptiveNoteStrategy()` to `KazezNoteStrategy()`
  - [ ] 3.2 Update the comment to reference this story (9.1)

- [ ] Task 4: Remove Natural vs. Mechanical slider from Settings UI (AC: #5, #6)
  - [ ] 4.1 Remove the "Natural vs. Mechanical" slider from `SettingsScreen.swift`
  - [ ] 4.2 Keep `SettingsKeys.naturalVsMechanical` and `SettingsKeys.defaultNaturalVsMechanical` in `SettingsKeys.swift` (AdaptiveNoteStrategy still references them)
  - [ ] 4.3 Remove related localized strings from `Localizable.xcstrings` if they exist
  - [ ] 4.4 Update any Settings tests that reference the slider

- [ ] Task 5: Update KazezNoteStrategy doc comments (AC: #2)
  - [ ] 5.1 Remove "evaluation only" language from the class doc comment — it is now the primary training strategy
  - [ ] 5.2 Update the log message from "evaluation mode" to reflect production use
  - [ ] 5.3 Add a brief reference to the research rationale (brainstorming session document)

- [ ] Task 6: Update project-context.md (AC: #4)
  - [ ] 6.1 Update the "State Management" section: `KazezNoteStrategy` is the default, `AdaptiveNoteStrategy` is retained
  - [ ] 6.2 Remove or update references to `naturalVsMechanical` as a user-facing setting
  - [ ] 6.3 Update the `NextNoteStrategy` doc comment in `NextNoteStrategy.swift` to reflect `KazezNoteStrategy` as primary

- [ ] Task 7: Verify full test suite passes (AC: #7)
  - [ ] 7.1 Run full test suite and confirm zero failures
  - [ ] 7.2 Confirm AdaptiveNoteStrategy tests still pass unchanged

## Dev Notes

### Background and Rationale

This story is the result of a brainstorming session (see `docs/brainstorming/brainstorming-session-2026-02-24.md`) that examined the note selection strategy from first principles, informed by perceptual learning research.

**Key findings:**
- Pitch discrimination is essentially **one unified skill** with a roughly uniform threshold across the frequency range (Hawkey et al. 2004, Irvine et al. 2000)
- Per-note "weak spots" in the profile are mostly **data collection artifacts**, not real perceptual differences
- **Frequency roving** (random note selection) is not harmful and may build more robust representations (Amitay et al. 2005)
- **Stimulus-specific adaptation** makes switching frequencies beneficial — it prevents neural habituation
- The existing `KazezNoteStrategy` already implements the core of what's needed: a continuous difficulty chain with random note selection
- The `naturalVsMechanical` parameter in `AdaptiveNoteStrategy` was solving a problem that doesn't exist

**What KazezNoteStrategy already does right:**
- Single continuous difficulty chain via `lastComparison` — no difficulty jumps on note change
- Random note selection — prevents habituation, provides profile coverage
- Stateless — no complex state to manage
- Kazez √P-scaled convergence formulas

**What this story adds:**
- Respect `settings.noteRangeMin/Max` (currently hardcoded to MIDI 48-72)
- Smarter cold start using `profile.overallMean` (currently always starts at 100 cents)
- Default strategy in production (currently labeled "evaluation only")

### Technical Requirements

- **Kazez coefficients stay at 0.05 / 0.09** — these are the original Kazez et al. (2001) values. AdaptiveNoteStrategy uses a modified 0.08 / 0.09, but for the simpler roving strategy the original coefficients are appropriate since the chain is never interrupted by per-note difficulty lookups.
- **No changes to PerceptualProfile** — it still records per-note data via the observer pattern. The profile data is used for display and cold start, just not for note selection.
- **No changes to TrainingSession** — it already accepts any `NextNoteStrategy` via protocol injection.
- **AdaptiveNoteStrategy stays in the codebase** — no deletion, no deprecation warnings. It may be useful for future experiments.

### Architecture Compliance

- **Protocol-first design**: `KazezNoteStrategy` already conforms to `NextNoteStrategy`. The swap in `PeachApp.swift` is a one-line change. [Source: docs/project-context.md — "Protocol-first design"]
- **Settings read live**: `TrainingSession` reads `@AppStorage` on each comparison and constructs `TrainingSettings`. The `naturalVsMechanical` field will still be populated (from its default) but `KazezNoteStrategy` ignores it. [Source: docs/project-context.md — "Settings read live"]
- **Views only interact with TrainingSession and PerceptualProfile**: Removing the slider from Settings doesn't affect this boundary. [Source: docs/project-context.md — "Views are thin"]

### Library & Framework Requirements

- No new dependencies. Net reduction in UI complexity (one slider removed).

### File Structure Requirements

**Modified files:**
```
Peach/Core/Algorithm/KazezNoteStrategy.swift     # Respect settings range, smarter cold start, update docs
Peach/Settings/SettingsScreen.swift               # Remove Natural vs. Mechanical slider
Peach/App/PeachApp.swift                          # Swap AdaptiveNoteStrategy → KazezNoteStrategy
Peach/Core/Algorithm/NextNoteStrategy.swift       # Update protocol doc comment
docs/project-context.md                           # Update strategy documentation
```

**Modified test files:**
```
PeachTests/Core/Algorithm/KazezNoteStrategyTests.swift    # Update for settings range, add cold start tests
PeachTests/Settings/SettingsTests.swift                    # Remove slider-related tests if any
```

**No new files. No deleted files.**

### Testing Requirements

- **Updated tests**: `KazezNoteStrategyTests` — verify note selection respects `settings.noteRangeMin/Max` instead of hardcoded range
- **New tests**: Cold start with profile data — verify `overallMean` is used when profile has data
- **New tests**: Cold start without profile data — verify `maxCentDifference` is used
- **Unchanged tests**: All `AdaptiveNoteStrategyTests` must pass without modification
- **All tests `@MainActor async`** per project testing rules

### Previous Story Intelligence

**From story 8.3 (most recent):**
- `PeachApp.init()` currently creates `AdaptiveNoteStrategy()` and passes it to `TrainingSession` — this is the single line to change
- Clean composition root pattern: create strategy, pass to session
- `TrainingSession` accepts `any NextNoteStrategy` — no type coupling

**From stories 4.2 and 4.3 (original strategy implementation):**
- `KazezNoteStrategy` was created as an evaluation tool alongside `AdaptiveNoteStrategy`
- `MockNextNoteStrategy` exists for testing — unchanged by this story
- `TrainingSession` reads `@AppStorage` values into a `TrainingSettings` struct each comparison

### Project Structure Notes

- No new directories needed
- No structural changes
- Net reduction: one UI control removed from Settings

### References

- [Source: docs/brainstorming/brainstorming-session-2026-02-24.md] — Brainstorming session with literature review
- [Source: docs/project-context.md] — Architecture rules, testing conventions
- [Source: Peach/Core/Algorithm/KazezNoteStrategy.swift] — Current implementation (lines 30-91)
- [Source: Peach/Core/Algorithm/AdaptiveNoteStrategy.swift] — Strategy being replaced as default
- [Source: Peach/App/PeachApp.swift:51] — Current strategy instantiation
- [Source: Peach/Settings/SettingsScreen.swift] — Natural vs. Mechanical slider location

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
