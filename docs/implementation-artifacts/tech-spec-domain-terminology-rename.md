---
title: 'Domain Terminology Rename'
slug: 'domain-terminology-rename'
created: '2026-03-21'
status: 'ready-for-dev'
stepsCompleted: []
tech_stack: ['Swift 6.2', 'SwiftUI', 'SwiftData', 'Swift Testing']
---

# Quick Spec: Domain Terminology Rename

**Created:** 2026-03-21

## Overview

### Problem Statement

The codebase uses terminology that doesn't align with the music/psychoacoustic domain and suffers from naming inconsistencies:

1. **"PitchComparison"** — should be **"PitchDiscrimination"** (standard psychoacoustic term for threshold-based pitch difference detection)
2. **"RhythmComparison"** — should be **"RhythmOffsetDetection"** (the user detects timing offset direction, not "comparing" rhythms)
3. **"PitchMatchingChallenge"** — should be **"PitchMatchingTrial"** and the `PitchComparison` struct should become **"PitchDiscriminationTrial"** (consistent term for one atomic presentation-response cycle)
4. **"TrainingMode"** — should be **"TrainingDiscipline"** (these are ear training disciplines, not modal app states)

These renames were agreed upon in a party-mode discussion with the Architect, Music Domain Expert, and Tech Writer.

### Solution

Mechanical rename across all source files, test files, active planning docs, and the glossary. No functional changes. All tests must continue to pass.

### Rename Reference Table

**Domain concept renames:**

| Current | New | Rationale |
|---------|-----|-----------|
| `PitchComparison` (the struct) | `PitchDiscriminationTrial` | Correct domain term + atomic exercise concept |
| `CompletedPitchComparison` | `CompletedPitchDiscriminationTrial` | Follows trial pattern |
| `PitchComparisonSession` | `PitchDiscriminationSession` | |
| `PitchComparisonSessionState` | `PitchDiscriminationSessionState` | |
| `PitchComparisonScreen` | `PitchDiscriminationScreen` | |
| `PitchComparisonFeedbackIndicator` | `PitchDiscriminationFeedbackIndicator` | |
| `PitchComparisonObserver` | `PitchDiscriminationObserver` | |
| `PitchComparisonRecord` | `PitchDiscriminationRecord` | |
| `PitchComparisonRecordStoring` | `PitchDiscriminationRecordStoring` | |
| `PitchComparisonTrainingSettings` | `PitchDiscriminationSettings` | Drop "Training" — redundant |
| `PitchComparisonProfile` | `PitchDiscriminationProfile` | |
| `NextPitchComparisonStrategy` | `NextPitchDiscriminationStrategy` | |
| `KazezNoteStrategy` | `KazezNoteStrategy` | **No change** — implementation name, not domain |
| `PitchMatchingChallenge` | `PitchMatchingTrial` | Consistent trial concept |
| `CompletedPitchMatching` | `CompletedPitchMatchingTrial` | Follows trial pattern |
| `CompletedRhythmComparison` | `CompletedRhythmOffsetDetectionTrial` | |
| `RhythmComparisonObserver` | `RhythmOffsetDetectionObserver` | |
| `RhythmComparisonRecord` | `RhythmOffsetDetectionRecord` | |
| `CompletedRhythmMatching` | `CompletedRhythmMatchingTrial` | Follows trial pattern |
| `RhythmMatchingObserver` | `RhythmMatchingObserver` | **No change** — already correct |
| `RhythmMatchingRecord` | `RhythmMatchingRecord` | **No change** |
| `TrainingMode` | `TrainingDiscipline` | Ear training disciplines, not app modes |
| `TrainingModeConfig` | `TrainingDisciplineConfig` | |
| `TrainingModeStatistics` | `TrainingDisciplineStatistics` | |
| `PitchMatchingTrainingSettings` | `PitchMatchingSettings` | Drop "Training" for symmetry |

**Protocol method renames:**

| Current | New |
|---------|-----|
| `pitchComparisonCompleted(_:)` | `pitchDiscriminationCompleted(_:)` |
| `nextPitchComparison(...)` | `nextPitchDiscriminationTrial(...)` |
| `fetchAllPitchComparisons()` | `fetchAllPitchDiscriminations()` |
| `rhythmComparisonCompleted(_:)` | `rhythmOffsetDetectionCompleted(_:)` |

**Enum case renames (in `TrainingDiscipline`):**

| Current | New |
|---------|-----|
| `.unisonPitchComparison` | `.unisonPitchDiscrimination` |
| `.intervalPitchComparison` | `.intervalPitchDiscrimination` |
| `.unisonMatching` | `.unisonPitchMatching` |
| `.intervalMatching` | `.intervalPitchMatching` |
| `.rhythmComparison` | `.rhythmOffsetDetection` |
| `.rhythmMatching` | `.rhythmMatching` |

**NavigationDestination case renames:**

| Current | New |
|---------|-----|
| `.pitchComparison(intervals:)` | `.pitchDiscrimination(intervals:)` |
| `.rhythmComparison` | `.rhythmOffsetDetection` |

**Environment key renames:**

| Current | New |
|---------|-----|
| `pitchComparisonSession` | `pitchDiscriminationSession` |

**Directory renames:**

| Current | New |
|---------|-----|
| `Peach/PitchComparison/` | `Peach/PitchDiscrimination/` |
| `PeachTests/PitchComparison/` | `PeachTests/PitchDiscrimination/` |

**File renames** follow mechanically from directory + type renames.

**User-facing names remain unchanged:** "Hear & Compare", "Tune & Match", "Single Notes", "Intervals" stay as-is in the UI.

### Scope

**In Scope:**
- All source file renames (types, files, directories)
- All test file renames and content updates
- SwiftData model renames with best-effort lightweight migration (fall back to data wipe if fiddly — pre-release, single user)
- CSV export: new `trainingType` values (`pitchDiscrimination`, `rhythmOffsetDetection`)
- CSV import: V1 parser normalizes legacy type names for backward compatibility
- Glossary update (`docs/planning-artifacts/glossary.md`)
- Active planning docs: `epics.md`, `project-context.md`, `prd.md`, `architecture.md`, `ux-design-specification.md`, `rhythm-training-spec.md`
- `sprint-status.yaml` — update story identifiers where old names appear
- Localization `.xcstrings` keys if they reference internal type names

**Out of Scope:**
- Historical docs (completed story files, code reviews, retrospectives, research docs, completed tech specs)
- arc42 documentation (separate update)
- Any functional changes

## Execution Plan

This is a large but mechanical rename. Execute in phases, **one commit per phase**, to keep git history clean and reviewable.

### Phase 1: TrainingMode → TrainingDiscipline

Smallest blast radius — an enum used across many files but with no file/directory renames.

**Files to modify (source):**
- `Peach/Core/Profile/ProgressTimeline.swift` — enum definition
- `Peach/Core/Profile/TrainingModeConfig.swift` → rename file to `TrainingDisciplineConfig.swift`
- `Peach/Core/Profile/TrainingModeStatistics.swift` → rename file to `TrainingDisciplineStatistics.swift`
- `Peach/Core/Profile/StatisticsKey.swift` — references
- `Peach/Core/Profile/StatisticalSummary.swift` — references
- `Peach/Core/Profile/TrainingProfile.swift` — references
- `Peach/Core/Profile/PerceptualProfile.swift` — references
- `Peach/App/MetricPointMapper.swift` — references
- `Peach/Profile/ProfileScreen.swift` — references
- `Peach/Profile/ProgressChartView.swift` — references
- `Peach/Profile/ExportChartView.swift` — references
- `Peach/Profile/ChartImageRenderer.swift` — references
- `Peach/Start/StartScreen.swift` — references
- `Peach/Start/ProgressSparklineView.swift` — references

**Files to modify (tests):**
- `PeachTests/Core/Profile/TrainingModeTests.swift` → rename to `TrainingDisciplineTests.swift`
- `PeachTests/Core/Profile/TrainingModeConfigTests.swift` → rename to `TrainingDisciplineConfigTests.swift`
- `PeachTests/Core/Profile/TrainingModeStatisticsTests.swift` → rename to `TrainingDisciplineStatisticsTests.swift`
- `PeachTests/Core/Profile/ProgressTimelineTests.swift`
- `PeachTests/Core/Profile/PerceptualProfileTests.swift`
- `PeachTests/Core/Profile/StatisticsKeyTests.swift`
- `PeachTests/Core/Profile/StatisticalSummaryTests.swift`
- `PeachTests/Profile/ProfileScreenTests.swift`
- `PeachTests/Profile/ProgressChartViewTests.swift`
- `PeachTests/Profile/ExportChartViewTests.swift`
- `PeachTests/Profile/ChartImageRendererTests.swift`
- `PeachTests/Start/StartScreenTests.swift`

**Gate:** `bin/test.sh` passes.

### Phase 2: PitchComparison → PitchDiscrimination + Trial

Directory rename + type renames for the pitch discrimination family.

1. Rename directories: `Peach/PitchComparison/` → `Peach/PitchDiscrimination/`, `PeachTests/PitchComparison/` → `PeachTests/PitchDiscrimination/`
2. Rename all files and types per the reference table
3. Rename `PitchComparison` struct to `PitchDiscriminationTrial`
4. Rename `CompletedPitchComparison` to `CompletedPitchDiscriminationTrial`
5. Update all protocol methods, properties, and local variables
6. Update `NavigationDestination`, `EnvironmentKeys`, `PeachApp.swift`
7. **SwiftData:** Attempt lightweight migration for `PitchComparisonRecord` → `PitchDiscriminationRecord` using `SchemaMigrationPlan` with a `.lightweight` stage. If SwiftData handles the entity rename automatically, keep it. If it requires manual mapping that gets fiddly, fall back to data wipe (pre-release, single user).

**Gate:** `bin/test.sh` passes.

### Phase 3: PitchMatchingChallenge → PitchMatchingTrial + CompletedPitchMatchingTrial

1. Rename `PitchMatchingChallenge` → `PitchMatchingTrial` (file + type)
2. Rename `CompletedPitchMatching` → `CompletedPitchMatchingTrial` (file + type)
3. Update `PitchMatchingSession`, observers, data store, tests

**Gate:** `bin/test.sh` passes.

### Phase 4: RhythmComparison → RhythmOffsetDetection + Trial

1. Rename `CompletedRhythmComparison` → `CompletedRhythmOffsetDetectionTrial`
2. Rename `RhythmComparisonObserver` → `RhythmOffsetDetectionObserver`
3. Rename `RhythmComparisonRecord` → `RhythmOffsetDetectionRecord`
4. Rename `CompletedRhythmMatching` → `CompletedRhythmMatchingTrial`
5. Update data store, profile, progress timeline, tests
6. Update `NavigationDestination` if rhythm cases already exist
7. **SwiftData:** Same migration approach as Phase 2 for `RhythmComparisonRecord` → `RhythmOffsetDetectionRecord` and `RhythmMatchingRecord` (unchanged name, but include in migration plan for completeness)

**Gate:** `bin/test.sh` passes.

### Phase 5: PitchMatchingTrainingSettings / PitchComparisonTrainingSettings cleanup

1. `PitchComparisonTrainingSettings` → `PitchDiscriminationSettings`
2. `PitchMatchingTrainingSettings` → `PitchMatchingSettings`

**Gate:** `bin/test.sh` passes.

### Phase 6: CSV Export & Import

1. `CSVExportSchema.TrainingType` — rename enum cases: `.pitchComparison` → `.pitchDiscrimination`, `.rhythmComparison` → `.rhythmOffsetDetection`
2. `CSVRecordFormatter` — update any raw string values written to CSV
3. `CSVImportParserV1` — add normalization map so legacy exports remain importable:
   - `"pitchComparison"` → `.pitchDiscrimination`
   - `"rhythmComparison"` → `.rhythmOffsetDetection`
4. Update `CSVImportParser` (protocol/router) if it references old type names
5. Update `TrainingDataExporter`, `TrainingDataImporter` if they reference old type names
6. Update all CSV-related tests: `CSVImportParserTests`, `CSVRecordFormatterTests`, `TrainingDataExporterTests`, `TrainingDataImporterTests`, `TrainingDataTransferServiceTests`
7. **Add test cases** verifying that CSVs with old type names (`pitchComparison`, `rhythmComparison`) still import correctly

**No new CSV format version.** This is a vocabulary change on the discriminator column, not a structural change. Epic 52 (CSV v2) will use the new names from the start.

**Gate:** `bin/test.sh` passes.

### Phase 7: Glossary Update

Update `docs/planning-artifacts/glossary.md`:

- Add **Trial** definition (one atomic presentation-response cycle)
- Add **Training Discipline** definition (replaces Training Mode)
- Rename all `PitchComparison*` references to `PitchDiscrimination*`
- Rename `PitchMatchingChallenge` to `PitchMatchingTrial`
- Rename `RhythmComparison*` to `RhythmOffsetDetection*`
- Add `*Trial` suffixes to completed types
- Update the naming matrix:

| Perceptual Domain | Threshold Task (passive) | Reproduction Task (active) |
|---|---|---|
| **Pitch** | Pitch Discrimination | Pitch Matching |
| **Rhythm** | Rhythm Offset Detection | Rhythm Matching |

### Phase 8: Active Planning Docs

Update these active docs with new terminology (types, enum cases, protocol names):

- `docs/planning-artifacts/epics.md` — all upcoming epics/stories (48+)
- `docs/planning-artifacts/prd.md` — functional requirements text
- `docs/planning-artifacts/architecture.md` — type references
- `docs/planning-artifacts/ux-design-specification.md` — screen/type references
- `docs/planning-artifacts/rhythm-training-spec.md` — domain type references
- `docs/project-context.md` — type references and patterns
- `docs/implementation-artifacts/sprint-status.yaml` — identifier names

**Do NOT update:**
- Historical story files (completed implementation artifacts)
- Code review docs
- Retrospective docs
- Completed tech specs
- arc42 docs (separate update)

## Verification

After all phases:
1. `bin/build.sh` — zero errors, zero warnings
2. `bin/test.sh` — all tests pass
3. `grep -r "PitchComparison\|PitchMatchingChallenge\|TrainingMode\b\|RhythmComparison" Peach/ PeachTests/` — zero hits (excluding this spec)
4. Verify no user-facing strings changed (UI text stays as-is)
