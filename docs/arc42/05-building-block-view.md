# 5. Building Block View

## Level 1: System Decomposition

```
Peach/
├── App/              Composition root, navigation shell, EnvironmentKeys
├── Core/             Shared services (cross-feature)
│   ├── Audio/        Tone generation, value types, SF2 parsing
│   ├── Algorithm/    Comparison selection
│   ├── Data/         Persistence
│   ├── Profile/      User statistics, timeline
│   └── Training/     Shared domain types (Comparison, observers, Resettable)
├── Comparison/       Comparison training loop feature
├── PitchMatching/    Pitch matching training feature
├── Profile/          Profile visualization feature
├── Settings/         Configuration feature
├── Start/            Home screen feature
├── Info/             About screen feature
└── Resources/        Localization, assets
```

## Level 2: Core Services

### Service Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                     ComparisonSession                            │
│              (state machine, error boundary)                     │
│                                                                  │
│    ┌──────────┐  ┌────────────────┐  ┌──────────────────┐       │
│    │NotePlayer│  │NextComparison  │  │PerceptualProfile │       │
│    │(protocol)│  │Strategy (prot.)│  │   (@Observable)  │       │
│    └────┬─────┘  └──────┬─────────┘  └────────┬─────────┘       │
│         │               │                      │                 │
│    ┌────▼─────┐  ┌──────▼─────────┐           │                 │
│    │SoundFont │  │Kazez           │           │                 │
│    │NotePlayer│  │NoteStrategy    │◀──────────┘                 │
│    └──────────┘  └────────────────┘  reads profile              │
│                                                                  │
│    Observers: [ComparisonObserver]                               │
│    ┌──────────┬──────────┬──────────┬──────────┬──────────┐     │
│    │Training  │Perceptual│Haptic    │Trend     │Threshold │     │
│    │DataStore │Profile   │Feedback  │Analyzer  │Timeline  │     │
│    │(persist) │(analytic)│Manager   │(trends)  │(history) │     │
│    └──────────┴──────────┴──────────┴──────────┴──────────┘     │
└──────────────────────────────────────────────────────────────────┘
```

### ComparisonSession

**File:** `Comparison/ComparisonSession.swift`
**Role:** Central orchestrator. The only component that understands a "comparison" as two notes played in sequence with a user answer.

- `@MainActor @Observable final class`
- State machine: `idle` → `playingNote1` → `playingNote2` → `awaitingAnswer` → `showingFeedback` → loop
- Coordinates `NotePlayer`, `NextComparisonStrategy`, `PerceptualProfile`
- Notifies `[ComparisonObserver]` on each completed comparison
- Catches all service errors — training continues gracefully
- Reads settings live via `UserSettings` protocol on each comparison
- Stores `[Resettable]` for reset-capable dependencies (TrendAnalyzer, ThresholdTimeline)

### NotePlayer (protocol) → SoundFontNotePlayer

**Files:** `Core/Audio/NotePlayer.swift`, `Core/Audio/SoundFontNotePlayer.swift`
**Role:** Plays a tone at a given frequency for a given duration.

- Knows only frequencies (Hz), durations, amplitudes
- No concept of MIDI notes, comparisons, or training
- `AVAudioEngine` + `AVAudioUnitSampler` for SF2 soundfont playback
- Returns a `PlaybackHandle` for stop/adjust control
- Reads `userSettings.soundSource` on each `play()` call to select the SF2 preset

### NextComparisonStrategy (protocol) → KazezNoteStrategy

**Files:** `Core/Algorithm/NextComparisonStrategy.swift`, `Core/Algorithm/KazezNoteStrategy.swift`
**Role:** Selects the next comparison based on the user's profile and settings.

- Stateless: reads `PitchDiscriminationProfile` and `lastComparison`, returns a `Comparison`
- **Difficulty:** Kazez convergence formulas — correct answer narrows (`N = P × [1 - 0.08 × √P]`), wrong answer widens (`N = P × [1 + 0.09 × √P]`)
- **Bootstrap:** when no previous comparison exists, uses neighbor-weighted effective difficulty from up to 5 trained notes in each direction

### PerceptualProfile

**File:** `Core/Profile/PerceptualProfile.swift`
**Role:** In-memory aggregate of pitch discrimination ability per MIDI note.

- `@Observable @MainActor final class`
- 128-slot array (MIDI 0–127), each slot holds `PerceptualNote`: mean, stdDev, m2, sampleCount, currentDifficulty
- Welford's online algorithm for incremental mean and variance
- Never persisted — rebuilt from `ComparisonRecord`s on every app launch
- Weak spot identification: untrained notes prioritized, then highest absolute threshold
- Also implements `ComparisonObserver` for automatic incremental updates

### TrainingDataStore

**File:** `Core/Data/TrainingDataStore.swift`
**Role:** Pure persistence layer for `ComparisonRecord`.

- `@MainActor final class`
- CRUD operations: `save`, `fetchAll`, `delete`, `deleteAll`
- Sole accessor of SwiftData `ModelContext`
- Implements `ComparisonObserver` — automatically persists each completed comparison
- Errors are logged but don't propagate (observers don't block training)

### ComparisonRecord

**File:** `Core/Data/ComparisonRecord.swift`
**Role:** SwiftData model for comparison training.

- Fields: `note1` (Int), `note2` (Int), `note2CentOffset` (Double), `isCorrect` (Bool), `timestamp` (Date)
- `note1` and `note2` are always the same MIDI note (note2 differs by cents only)
- Signed `note2CentOffset`: positive = higher, negative = lower

### PitchMatchingRecord

**File:** `Core/Data/PitchMatchingRecord.swift`
**Role:** SwiftData model for pitch matching training.

- Fields: `referenceNote` (Int), `initialCentOffset` (Double), `userCentError` (Double), `timestamp` (Date)

### ThresholdTimeline

**File:** `Core/Profile/ThresholdTimeline.swift`
**Role:** Tracks threshold history snapshots for timeline visualization.

- Implements `ComparisonObserver` for incremental updates
- Implements `Resettable` for data reset support
- Injected via `@Environment(\.thresholdTimeline)`

### TrendAnalyzer

**File:** `Core/Profile/TrendAnalyzer.swift`
**Role:** Computes improving/stable/declining trend from historical records.

- Bisects comparison history to compare recent vs. older performance
- Implements `ComparisonObserver` for incremental updates
- Injected via `@Environment(\.trendAnalyzer)`

### FrequencyCalculation

**File:** `Core/Audio/FrequencyCalculation.swift`
**Role:** MIDI note + cent offset → frequency in Hz.

- Static methods, no state
- 0.1-cent precision required — all frequency conversion must go through this file
- Standard formula: `f = referencePitch × 2^((midiNote - 69 + cents/100) / 12)`

## Level 2: Features (UI)

### Screens

| Screen | File | Observes | User Actions |
|---|---|---|---|
| **StartScreen** | `Start/StartScreen.swift` | `PerceptualProfile` (preview) | Start Comparison/PitchMatching, navigate to Profile/Settings/Info |
| **ComparisonScreen** | `Comparison/ComparisonScreen.swift` | `ComparisonSession` | Higher/Lower buttons, navigate to Settings/Profile |
| **PitchMatchingScreen** | `PitchMatching/PitchMatchingScreen.swift` | `PitchMatchingSession` | Vertical pitch slider, submit answer |
| **ProfileScreen** | `Profile/ProfileScreen.swift` | `PerceptualProfile`, `TrendAnalyzer` | View threshold timeline, summary stats, matching stats |
| **SettingsScreen** | `Settings/SettingsScreen.swift` | `@AppStorage` | Adjust slider, range, duration, pitch; reset data |
| **InfoScreen** | `Info/InfoScreen.swift` | — | View app info |

### Supporting Views

| View | File | Purpose |
|---|---|---|
| `ProfilePreviewView` | `Start/ProfilePreviewView.swift` | Miniature profile on Start Screen |
| `ComparisonFeedbackIndicator` | `Comparison/ComparisonFeedbackIndicator.swift` | Thumbs up/down overlay |
| `DifficultyDisplayView` | `Comparison/DifficultyDisplayView.swift` | Current difficulty indicator |
| `HapticFeedbackManager` | `Comparison/HapticFeedbackManager.swift` | Wrong-answer haptic (ComparisonObserver) |
| `VerticalPitchSlider` | `PitchMatching/VerticalPitchSlider.swift` | Draggable pitch slider for matching |
| `PitchMatchingFeedbackIndicator` | `PitchMatching/PitchMatchingFeedbackIndicator.swift` | Pitch matching result overlay |
| `PianoKeyboardView` | `Profile/PianoKeyboardView.swift` | Canvas-rendered keyboard axis |
| `ThresholdTimelineView` | `Profile/ThresholdTimelineView.swift` | Threshold history chart |
| `SummaryStatisticsView` | `Profile/SummaryStatisticsView.swift` | Mean, stdDev, trend display |
| `MatchingStatisticsView` | `Profile/MatchingStatisticsView.swift` | Pitch matching statistics display |
| `ContentView` | `App/ContentView.swift` | Root navigation shell |
| `NavigationDestination` | `App/NavigationDestination.swift` | Type-safe routing enum |
| `EnvironmentKeys` | `App/EnvironmentKeys.swift` | Centralized `@Entry` environment key registry |

## File Counts

- **Source:** 61 Swift files in `Peach/`
- **Tests:** 65 Swift files in `PeachTests/` (mirrors source structure)
