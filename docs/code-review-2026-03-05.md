# Whole-Project Code Review

**Date:** 2026-03-05
**Reviewer:** Claude Opus 4.6 (adversarial)
**Scope:** Full codebase review

---

## Executive Summary

The Peach codebase has excellent architectural foundations: clean layering, protocol-first design, zero cross-feature coupling, and a well-structured composition root. However, a systematic review reveals **domain type discipline has eroded** at the persistence and algorithm boundaries, **terminology has drifted** between the two training modes, and the glossary contains significant amounts of outdated content.

**Issues found:** 12 HIGH, 15 MEDIUM, 10 LOW

---

## 1. Raw Types and Literals Where Domain Types Exist

### HIGH: `NotePlayer.play()` accepts `TimeInterval` instead of `NoteDuration`

The `NotePlayer` protocol at `Core/Audio/NotePlayer.swift:15` declares `duration: TimeInterval`. The domain type `NoteDuration` exists and encodes valid range (0.3-3.0s), but the protocol bypasses it. Both sessions extract `.rawValue` from `NoteDuration` just to pass a raw `TimeInterval`:

- `PitchComparisonSession.swift:47-48` -- `currentNoteDuration` returns `TimeInterval`
- `PitchMatchingSession.swift:209-210` -- same pattern

**Recommendation:** Change `NotePlayer.play()` to accept `NoteDuration`. Convert to `TimeInterval` only inside the implementation.

### HIGH: `PitchMatchingSession.referenceFrequency` is `Double?` instead of `Frequency?`

At `PitchMatchingSession.swift:48`, `referenceFrequency` is stored as `Double?`. It's assigned from `targetFreq.rawValue` (line 254), and then raw arithmetic is performed at lines 131, 145. The `Frequency` domain type exists but is discarded at the session boundary.

**Recommendation:** Store as `Frequency?` and keep the domain type through the calculation chain.

### HIGH: `CompletedPitchMatching` uses `Double` for cent values

At `Core/Training/CompletedPitchMatching.swift:6-7`, `initialCentOffset` and `userCentError` are `Double` when `Cents` exists. Same issue in `PitchMatchingChallenge.swift:4`.

**Recommendation:** Use `Cents` for both fields. This also fixes downstream consumers like `PitchMatchingSession.sliderFrequency()` which currently does raw arithmetic.

### HIGH: `PerceptualProfile.update()` takes `centOffset: Double` instead of `Cents`

The `PitchComparisonProfile` protocol at `PitchComparisonProfile.swift:2` and its implementation at `PerceptualProfile.swift:27` declare `centOffset: Double`. The `Cents` type exists in the same module.

Similarly, `setDifficulty(note:difficulty:)` at line 112 takes `Double` instead of `Cents`, and `PerceptualNote.currentDifficulty` (line 156) and `PerceptualNote.mean` (line 152) are raw `Double` where they semantically represent cent values.

**Recommendation:** Use `Cents` in the profile protocol and implementation.

### MEDIUM: Hard-coded `127` instead of `MIDINote.validRange.upperBound`

Both `KazezNoteStrategy.swift:45` and `PitchMatchingSession.swift:220` use `127` directly:
```swift
maxNote = MIDINote(min(settings.noteRange.upperBound.rawValue, 127 - interval.interval.semitones))
```

`MIDINote` already defines `static let validRange = 0...127`.

**Recommendation:** Use `MIDINote.validRange.upperBound` (and `.lowerBound` for the symmetric case at line 47).

### MEDIUM: `PerceptualProfile` uses `128` magic number

At `PerceptualProfile.swift:21` and `:106`, the array size `128` is hard-coded. This assumes the MIDI range size implicitly.

**Recommendation:** Derive from `MIDINote.validRange.count`.

### MEDIUM: `PianoKeyboardView` uses `Int` throughout instead of `MIDINote`

All methods in `Profile/PianoKeyboardView.swift` (lines 17, 23, 28, 44, 61) accept raw `Int` for MIDI notes. The `MIDINote` type carries validation and documentation that these bare `Int`s lack.

**Recommendation:** Change `midiNote: Int` parameters to `MIDINote`.

### MEDIUM: Persistence boundary -- SwiftData models use raw primitives

`PitchComparisonRecord` and `PitchMatchingRecord` store `referenceNote: Int`, `targetNote: Int`, `centOffset: Double`, `interval: Int`. This is partly a SwiftData constraint, but the conversion to/from domain types should be encapsulated:

**Recommendation:** Add computed properties or factory methods on the record types that bridge to/from domain types (e.g., `var referenceNoteValue: MIDINote { MIDINote(referenceNote) }`). This concentrates the raw-to-domain boundary in one place.

### MEDIUM: `SettingsKeys` stores MIDI note defaults as `Int`

`SettingsKeys.swift:17-18` (`defaultNoteRangeMin/Max`) and `:32-33` (`absoluteMinNote/MaxNote`) are raw `Int`. While `@AppStorage` requires primitives, the defaults could be computed from `MIDINote` constants.

### LOW: `CSVImportParser` validates MIDI range with raw `(0...127)`

At `CSVImportParser.swift:205,209`, the parser uses `(0...127).contains(referenceNote)`. Should use `MIDINote.validRange.contains()`.

### LOW: `SoundFontNotePlayer.decompose()` returns `cents: Double`

At `SoundFontNotePlayer.swift:207`, the decompose function returns `(note: UInt8, cents: Double)` instead of using `Cents`.

---

## 2. Constants That Should Be Extracted to Configuration

### HIGH: Kazez formula factors are undocumented magic numbers

`KazezNoteStrategy.swift:64,68`:
```swift
private func kazezNarrow(p: Double) -> Double {
    p * (1.0 - 0.05 * p.squareRoot())  // 0.05 = narrowing coefficient
}
private func kazezWiden(p: Double) -> Double {
    p * (1.0 + 0.09 * p.squareRoot())  // 0.09 = widening coefficient
}
```

These are the core algorithm parameters. They are not configurable, not documented, and not named. The glossary still references "narrowing factor 0.95" and "widening factor 1.3" which are *different* values -- suggesting the algorithm changed but the glossary didn't.

**Recommendation:** Extract to named constants with documentation explaining the Kazez formula derivation. Update the glossary to match.

### MEDIUM: Feedback duration duplicated across sessions

`feedbackDuration: TimeInterval = 0.4` appears in both `PitchComparisonSession.swift:59` and `PitchMatchingSession.swift:57`. This is a perceptual design constant shared across modes.

**Recommendation:** Extract to a shared constant (e.g., `TrainingConstants.feedbackDuration`).

### MEDIUM: MIDI velocity duplicated

`velocity: MIDIVelocity = 63` appears in both `PitchComparisonSession.swift:57` and `PitchMatchingSession.swift:56`.

**Recommendation:** Extract alongside `feedbackDuration`.

### MEDIUM: Initial cent offset range

`PitchMatchingSession.swift:54`: `static let initialCentOffsetRange: ClosedRange<Double> = -20.0...20.0`

This determines the pitch matching difficulty and slider behavior. It should probably be a `ClosedRange<Cents>` and configurable or at least named more prominently.

### MEDIUM: Time bucket thresholds in `ProgressTimeline`

`ProgressTimeline.swift:333,342,346` uses `24 * 3600`, `7 * 86400`, `30 * 86400` as bucket age thresholds. These define how training history is aggregated for visualization.

**Recommendation:** Extract to named constants (e.g., `recentThreshold`, `weekThreshold`, `monthThreshold`).

### LOW: `maxLoudnessOffsetDB` in `PitchComparisonSession`

At `PitchComparisonSession.swift:55`, `maxLoudnessOffsetDB: Float = 5.0`. This is an audio perception constant that affects training difficulty.

### LOW: Default difficulty `100.0` in `PerceptualNote`

`PerceptualProfile.swift:158`: `currentDifficulty: Double = 100.0`. This is the cold-start difficulty and should be a named constant (and should be `Cents`).

---

## 3. Dependencies and Coupling

### Overall Assessment: EXCELLENT

The architecture is remarkably clean. No violations of the core dependency rules were found:
- Core/ is framework-free
- No cross-feature coupling
- No Combine imports
- SwiftData properly encapsulated
- Protocol-first design throughout

### LOW: Redundant reset calls in PeachApp

`PeachApp.swift:52-53`: After data import, `profile.reset()` is called followed by `profile.resetMatching()`. Since `reset()` clears the entire `noteStats` array (comparison data), and `resetMatching()` clears matching counters -- both are needed because `reset()` does NOT clear matching stats.

Wait -- actually verifying: `PerceptualProfile.reset()` at line 105 only resets `noteStats`. It does NOT call `resetMatching()`. So both calls ARE needed. This is actually correct but **fragile**: `reset()` has a misleading name since it doesn't fully reset.

**Recommendation:** Either rename `reset()` to `resetComparison()` for clarity, or have `reset()` also call `resetMatching()` and remove the redundant second call.

### MEDIUM: `check-dependencies.sh` gaps

The script is good but misses:
1. **Feature directory naming is stale**: Line 89 checks for `"Comparison"` but the actual directory is `PitchComparison/`. The grep works by accident because it scans all of `$SRC_DIR/*/` including `PitchComparison/`, but the exclusion pattern `HapticFeedbackManager.swift` at line 92 would miss if the file moved.
2. **No check for `import os` vs `import OSLog` inconsistency** (minor)
3. **No check for `print()` statements in production code** -- these bypass structured logging
4. **Cross-feature checks only look at Screen types** (line 113-114), not other types. If `PitchComparison/` exported a helper type used in `PitchMatching/`, it wouldn't be caught.

**Recommendation:** Fix the feature directory naming, add a `print()` check, broaden cross-feature type scanning.

---

## 4. Code Duplication

### MEDIUM: Session state machine boilerplate

`PitchComparisonSession` and `PitchMatchingSession` share significant structural patterns:
- Logger setup, feedback task lifecycle, audio interruption monitor wiring, observer notification, stop/reset logic, `currentSettings`/`currentNoteDuration` derivation, tuning system tracking.

I counted ~60 lines of near-identical code. However, the two sessions have genuinely different state machines and control flow, so a base class would be forced. This is a judgment call.

**Recommendation:** Extract shared constants (velocity, feedbackDuration) and consider a `SessionLifecycle` helper struct that owns feedbackTask management and observer notification -- but don't force inheritance. The current duplication is tolerable given the different workflows.

### MEDIUM: Screen toolbar and lifecycle patterns

`PitchComparisonScreen` and `PitchMatchingScreen` both have:
- Identical help sheet presentation (~8 lines)
- Identical toolbar structure with help/settings/profile (~20 lines)
- Identical `onAppear`/`onDisappear` logging pattern (~8 lines)

**Recommendation:** Extract a `TrainingToolbar` view and a `HelpSheetModifier` to eliminate the duplication.

### MEDIUM: Bucket statistics calculation duplicated

`ProgressTimeline.swift` computes mean/stddev from point arrays in three places: `assignBuckets` (lines 367-375), `assignSubBuckets` (lines 433-441), and `updateBucket` (lines 253-265). The first two are identical.

**Recommendation:** Extract a `BucketStatistics.from(points:)` helper.

### LOW: Observer protocol pattern duplication

`PitchComparisonObserver` and `PitchMatchingObserver` are structurally identical one-method protocols. A generic `TrainingObserver<Result>` could unify them, but the current approach is explicit and clear.

**Recommendation:** Keep as-is unless a third training mode is added.

---

## 5. Logging

### HIGH: `TrainingDataStore` uses `print()` instead of `Logger`

At `TrainingDataStore.swift:125,127,154,157`:
```swift
print("Warning: TrainingDataStore pitch matching save error: \(error.localizedDescription)")
```

These are error-path messages that bypass structured logging entirely. They can't be filtered, categorized, or captured by diagnostic tools.

**Recommendation:** Add a `Logger` to `TrainingDataStore` and replace all `print()` calls with `logger.error()`.

### MEDIUM: Device disconnection logged at wrong level

`AudioSessionInterruptionMonitor.swift:130`: Device disconnection uses `logger.info()` but this is a significant user-facing event that stops training. Should be `logger.warning()`.

### MEDIUM: `SoundFontNotePlayer` lacks lifecycle logging

No logging for `play()`, `stopAll()`, or preset load failures. When debugging audio issues, there's a black hole between "Challenge generated" and "Result recorded".

**Recommendation:** Add `logger.debug()` for play/stop operations and `logger.warning()` for preset fallbacks.

### LOW: `import OSLog` vs `import os` inconsistency

`KazezNoteStrategy.swift` and `PerceptualProfile.swift` use `import OSLog`; all other files use `import os`.

**Recommendation:** Standardize on `import os`.

### LOW: Error level too severe for UI race condition

`PitchComparisonSession.swift:133`: `logger.error("handleAnswer() called but currentPitchComparison is nil")` -- this is a recoverable race condition, not a system error. Should be `logger.warning()`.

---

## 6. Terminology and Glossary

### HIGH: Glossary contains outdated algorithm terminology

The glossary defines:
- **Narrowing Factor**: "0.95 = 5% harder" -- The code uses the Kazez formula `p * (1.0 - 0.05 * sqrt(p))`, which is NOT a simple multiplier. The glossary description is wrong.
- **Widening Factor**: "1.3 = 30% easier" -- Same issue. The code uses `p * (1.0 + 0.09 * sqrt(p))`.
- **Current Difficulty**: Describes "starts at mean detection threshold when jumping to a new region, then adjusts via narrowing/widening factors" -- The code doesn't have "regions" anymore.
- **Regional Range**: "±12 semitones" -- No code implements regional training logic. This concept appears to have been removed.
- **Range Mean**: Describes a concept that may not be in the current algorithm.

**Recommendation:** Remove or rewrite these entries to match the actual Kazez algorithm behavior.

### HIGH: Glossary still uses Note1/Note2 terminology

The glossary defines **Note1** and **Note2** as the "reference" and "target" notes. The codebase consistently uses `referenceNote` and `targetNote`. The Note1/Note2 terminology is legacy.

**Recommendation:** Remove the Note1/Note2 entries and update the Pitch Comparison entry to use referenceNote/targetNote.

### HIGH: "Weak Spot" definition is stale

The glossary says weak spots are "identified by comparing absolute mean values across notes -- untrained notes are considered the weakest spots. The algorithm prioritizes these in Mechanical mode." But the `KazezNoteStrategy` doesn't implement any Mechanical mode or weak-spot targeting. The `weakSpots()` method exists on `PerceptualProfile` but is not called by any production code.

**Recommendation:** Either remove the concept or document it as "profile analysis only, not used in note selection."

### HIGH: Training modes are missing from the glossary

The code defines four `TrainingMode` cases (`unisonPitchComparison`, `intervalPitchComparison`, `unisonMatching`, `intervalMatching`) in `ProgressTimeline.swift:18-21` with user-facing names ("Hear & Compare -- Single Notes", "Tune & Match -- Intervals", etc.). These are a primary organizational concept but appear nowhere in the glossary.

**Recommendation:** Add a "Training Mode" glossary entry. Consider whether "Training Mode" is the best term -- alternatives: "Practice Mode", "Exercise Type", "Activity". I'd lean toward "Training Mode" since it's already established in the code.

### MEDIUM: "Cent Difference" vs "Cent Offset" vs "Cent Error" terminology creep

Three related-but-distinct concepts use overlapping terms:
- **Cent Difference**: magnitude of pitch separation (unsigned, used in comparisons)
- **Cent Offset**: signed pitch displacement (target note detuning)
- **Cent Error**: user's accuracy deviation in matching (signed)

The codebase uses these somewhat consistently, but `PitchComparisonSession.sessionBestCentDifference` (line 24) vs `PitchMatchingSession.sessionBestCentError` (line 25) illustrate the divergence. The glossary defines all three but doesn't clearly distinguish them.

**Recommendation:** Add a note to the glossary explicitly distinguishing these three concepts and when each applies.

### MEDIUM: "Natural vs. Mechanical" is in the glossary but not in the code

The glossary defines "Natural vs. Mechanical" as a user-facing slider, but no code implements this. The `KazezNoteStrategy` has no Natural/Mechanical parameter. The `TrainingSettings` struct likely doesn't include it.

**Recommendation:** Remove unless this is a planned feature, in which case mark it as "planned."

### MEDIUM: "Adaptive Note Strategy" name is stale

The glossary calls it "Adaptive Note Strategy" but the implementation is `KazezNoteStrategy`. The glossary entry describes behaviors (weak-spot targeting, Natural/Mechanical, regional training) that the Kazez implementation doesn't have.

**Recommendation:** Replace with an entry for "Kazez Note Strategy" describing the actual algorithm.

### LOW: "Confidence Band" not clearly linked to code

The glossary mentions "Confidence Band" as a visualization overlay, but it's not obvious which view component implements this.

### LOW: Missing glossary entry for `TrainingModeConfig`

This struct controls EWMA half-life, session gaps, and optimal baselines -- important algorithm parameters that deserve documentation.

### LOW: Missing glossary entry for `ProgressTimeline`

The central analytics engine for the Profile screen has no glossary entry.

---

## 7. Document Improvement Suggestions

### architecture.md

1. **Add Training Modes section**: The architecture should document the four training modes as a first-class concept and how they're tracked independently.
2. **Update algorithm description**: Remove references to Natural/Mechanical, regional ranges, and narrowing/widening factors. Document the actual Kazez formula.
3. **Add ProgressTimeline**: This is a significant component not in the original architecture since it was added later.
4. **Interval support**: Document the `DirectedInterval` concept and how both sessions support interval training.

### glossary.md

1. **Remove stale entries**: Note1, Note2, Narrowing Factor, Widening Factor, Current Difficulty, Regional Range, Range Mean, Natural vs. Mechanical, Adaptive Note Strategy (as currently described).
2. **Add missing entries**: Training Mode (the four categories), TrainingModeConfig, ProgressTimeline, Kazez Note Strategy, EWMA, TimeBucket/BucketSize, DirectedInterval (separate from Interval).
3. **Clarify cent terminology**: Add a disambiguation note for Cent Difference vs Cent Offset vs Cent Error.
4. **Update Weak Spot**: Note it's a profile analysis concept, not used in active note selection.
5. **Update Perceptual Profile**: Add matching statistics description.

### project-context.md

1. **Line 64**: Add `ProgressTimeline` to the list of types views may interact with (it's already injected via environment in screens).
2. **Line 85**: State machine description is only for PitchComparison. Add PitchMatchingSession state machine.
3. **Line 219**: "PitchComparisonSession is the ONLY component that understands pitch comparisons as a training sequence" -- PitchMatchingSession is the same for matching. Generalize or add a parallel statement.
4. **Add interval training context**: The project context doesn't mention `DirectedInterval` or interval-based training at all.
5. **Add ProgressTimeline rules**: This component has complex observer conformances and EWMA behavior that agents should know about.
6. **Line 226**: "Feedback phase is 0.4 seconds" -- document that this applies to both training modes.

### bin/check-dependencies.sh

1. **Fix feature directory naming**: `"Comparison"` on line 89 should handle `PitchComparison/` correctly (it does by accident, but the exclude pattern is fragile).
2. **Add `print()` check**: Warn on `print(` in production code (excluding tests and scripts).
3. **Broaden cross-feature checks**: Currently only checks Screen type references. Add checks for other exported types (e.g., `PitchComparisonSession` referenced from `PitchMatching/`).
4. **Add `import OSLog` check**: Flag `import OSLog` and suggest `import os` for consistency.

---

## Summary by Priority

### Must Fix (HIGH) -- 12 issues
1. `TrainingDataStore` uses `print()` instead of `Logger`
2. `NotePlayer.play()` accepts `TimeInterval` instead of `NoteDuration`
3. `PitchMatchingSession.referenceFrequency` is `Double?` not `Frequency?`
4. `CompletedPitchMatching` uses `Double` for cent values
5. `PerceptualProfile.update()` takes `Double` instead of `Cents`
6. Kazez formula factors are undocumented magic numbers
7. Glossary: outdated algorithm terminology (narrowing/widening/regional)
8. Glossary: stale Note1/Note2 entries
9. Glossary: stale "Weak Spot" definition
10. Glossary: missing Training Mode concept
11. Glossary: stale "Natural vs. Mechanical" (not in code)
12. Glossary: stale "Adaptive Note Strategy" description

### Should Fix (MEDIUM) -- 15 issues
1. Hard-coded `127` instead of `MIDINote.validRange.upperBound`
2. `PerceptualProfile` uses `128` magic number
3. `PianoKeyboardView` uses `Int` instead of `MIDINote`
4. Persistence boundary raw primitives (add bridging helpers)
5. `SettingsKeys` MIDI defaults as raw `Int`
6. Feedback duration duplicated across sessions
7. MIDI velocity duplicated across sessions
8. Initial cent offset range should use `Cents`
9. Time bucket thresholds are magic numbers
10. `check-dependencies.sh` gaps
11. Device disconnection logged at wrong level
12. `SoundFontNotePlayer` lacks lifecycle logging
13. Cent terminology creep (difference/offset/error)
14. Session state machine boilerplate duplication
15. Screen toolbar/lifecycle duplication

### Nice to Fix (LOW) -- 10 issues
1. `CSVImportParser` MIDI range validation
2. `SoundFontNotePlayer.decompose()` returns raw cents
3. `PerceptualNote.currentDifficulty` default `100.0`
4. `maxLoudnessOffsetDB` should be named constant
5. Observer protocol duplication
6. Bucket statistics calculation duplication
7. `import os` vs `import OSLog` inconsistency
8. Error level too severe for UI race condition
9. Missing glossary entries (TrainingModeConfig, ProgressTimeline)
10. `PerceptualProfile.reset()` naming ambiguity
