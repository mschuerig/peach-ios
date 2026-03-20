# Future Work & Technical Considerations

This document tracks design decisions to revisit, architectural improvements, and technical debt items discovered during development.

## Algorithm & Design

### Investigate Whether Seamless Playback Makes Pitch Comparison Easier

**Priority:** Medium
**Category:** Algorithm Design / Calibration
**Date Added:** 2026-02-17

**Observation:**
After implementing chain-based Kazez convergence, the algorithm quickly converges to sub-2-cent differences. However, the user consistently achieves much finer discrimination in Peach than in InTune (a reference app), where they typically plateau around 5 cents and only occasionally reach below 3 cents.

**Hypothesis:**
Peach plays the two comparison tones seamlessly (back-to-back without a gap), which may make pitch differences perceptually easier to detect than when tones are separated by silence. This could mean the difficulty levels in Peach are not directly comparable to those in apps that use gaps between tones.

**Impact:**
- Peach's difficulty numbers may overstate the user's actual pitch discrimination ability
- Comparison with other ear training apps may be misleading
- The training may be less effective if the task is artificially easier

**Investigation Areas:**
- Compare perceptual difficulty of seamless vs. gap-separated tone pairs at the same cent difference
- Research psychoacoustic literature on the effect of inter-stimulus intervals on pitch discrimination
- Consider adding a configurable gap between tones as an advanced setting
- Evaluate whether the current approach is still valuable for training (even if "easier")

**Related Code:**
- `Peach/Core/Audio/SineWaveNotePlayer.swift` — tone generation and playback
- `Peach/Training/TrainingSession.swift` — playback sequencing

---

## Data & Infrastructure

### Add SwiftData VersionedSchema and SchemaMigrationPlan

**Priority:** Medium
**Category:** Data Infrastructure
**Date Added:** 2026-03-20

**Issue:**
The project has no `VersionedSchema` or `SchemaMigrationPlan`. All schema changes so far have been purely additive (new models), which SwiftData handles via lightweight migration. However, any future change that modifies or removes a field on an existing model will cause a runtime crash on existing installs with no recovery path.

**Impact:**
- Adding, renaming, or removing a property on any `@Model` class will fail without a migration plan
- No safety net for schema evolution — the first non-additive change will be a crash discovered at runtime

**Action:**
- Introduce `VersionedSchema` conformances for the current schema (v1)
- Add a `SchemaMigrationPlan` with lightweight migration stages
- Do this before any story that modifies existing model properties

---

## UX & Onboarding

### No First-Run Onboarding Experience

**Priority:** High
**Category:** User Experience
**Date Added:** 2026-02-18

**Issue:**
There is no guided onboarding for new users. A musician downloading Peach sees the Start Screen with an empty profile preview and can tap "Start Training" — but nothing explains what will happen, what the controls mean, or what "cents" are in the context of pitch discrimination.

**Impact:**
- Musicians may not understand the task format (two sequential tones, tap Higher/Lower)
- The concept of "cents" as a unit of pitch difference is unfamiliar to many musicians who think in terms of "sharp/flat" or "in tune/out of tune"
- The profile visualization (confidence band, log scale) is meaningless without context
- Risk of immediate abandonment if the first experience feels confusing

**Potential Solutions:**
- A brief first-run walkthrough (2-3 screens) explaining the training concept
- Contextual tooltips on first use of each screen
- Musician-friendly language throughout ("pitch accuracy" instead of "cent threshold")
- An introductory training round with wider intervals and explanatory overlays
