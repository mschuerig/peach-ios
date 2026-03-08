# 5. Building Block View

## Level 1 — Overall System

```mermaid
graph TB
    subgraph "Peach App"
        App["App/<br><i>Composition root,<br>navigation shell</i>"]

        subgraph "Feature Modules"
            Start["Start/<br><i>Home screen,<br>training entry points</i>"]
            PitchComparison["PitchComparison/<br><i>Pitch comparison training<br>screen + UI</i>"]
            PitchMatching["PitchMatching/<br><i>Pitch matching<br>screen + slider</i>"]
            Profile["Profile/<br><i>Profile visualization,<br>statistics</i>"]
            Settings["Settings/<br><i>Configuration UI</i>"]
            Info["Info/<br><i>About screen</i>"]
        end

        subgraph "Core"
            Audio["Core/Audio/<br><i>NotePlayer, SoundFont,<br>PlaybackHandle</i>"]
            Algorithm["Core/Algorithm/<br><i>NextPitchComparisonStrategy,<br>KazezNoteStrategy</i>"]
            Data["Core/Data/<br><i>TrainingDataStore,<br>SwiftData models</i>"]
            ProfileCore["Core/Profile/<br><i>PerceptualProfile,<br>ProgressTimeline</i>"]
            Training["Core/Training/<br><i>Session protocols,<br>domain value types</i>"]
        end
    end

    App --> Start
    Start --> PitchComparison
    Start --> PitchMatching
    Start --> Profile
    Start --> Settings
    Start --> Info

    PitchComparison --> Training
    PitchComparison --> Audio
    PitchMatching --> Training
    PitchMatching --> Audio

    Training --> Algorithm
    Training --> ProfileCore
    Training --> Data
    Algorithm --> ProfileCore

    Profile --> ProfileCore
    Profile --> Data
    Settings -.->|"@AppStorage<br>(UserDefaults)"| Training
```

### Contained Building Blocks

| Building Block | Responsibility |
|---|---|
| **App/** | Composition root (`PeachApp.swift`): wires all dependencies, injects services into SwiftUI environment. Navigation shell (`ContentView.swift`): hub-and-spoke `NavigationStack`. |
| **Start/** | Home screen with four training entry points (Pitch Comparison, Pitch Matching, Interval Pitch Comparison, Interval Pitch Matching), profile preview sparkline, and navigation to Settings/Profile/Info. |
| **PitchComparison/** | Pitch comparison training UI: Higher/Lower buttons, feedback indicator, difficulty display. Reads `PitchComparisonSession` from environment. |
| **PitchMatching/** | Pitch matching UI: vertical pitch slider, feedback indicator. Reads `PitchMatchingSession` from environment. |
| **Profile/** | Perceptual profile visualization: progress chart with EWMA-smoothed accuracy over time (Swift Charts), per-note piano keyboard heatmap, summary statistics with trend indicators. |
| **Settings/** | Configuration interface: interval selector, note range, duration, reference pitch, loudness variation, tuning system, sound source picker, reset button. All backed by `@AppStorage`. |
| **Info/** | Static about screen: app name, developer, copyright, version. |
| **Core/Audio/** | Audio playback: `NotePlayer` protocol, `SoundFontNotePlayer` (AVAudioEngine + AVAudioUnitSampler), `PlaybackHandle` for note lifecycle, `SoundFontLibrary` for preset discovery, `AudioSessionInterruptionMonitor`. |
| **Core/Algorithm/** | Pitch comparison selection: `NextPitchComparisonStrategy` protocol, `KazezNoteStrategy` (psychoacoustic staircase algorithm). |
| **Core/Data/** | Persistence: `TrainingDataStore` (SwiftData CRUD), `PitchComparisonRecord` and `PitchMatchingRecord` models, `TrainingDataTransferService` (CSV export/import with merge and replace modes). |
| **Core/Profile/** | User model: `PerceptualProfile` (per-note statistics via Welford's algorithm), `ProgressTimeline` (per-mode EWMA progress tracking with trend analysis), `TrainingModeConfig` (per-mode display and baseline configuration). |
| **Core/Training/** | Domain types and session protocols: `PitchComparison`, `CompletedPitchComparison`, `CompletedPitchMatching`, observer protocols, `TrainingSession` protocol, `Resettable`. |

---

## Level 2 — Core/Audio

```mermaid
classDiagram
    class NotePlayer {
        <<protocol>>
        +play(frequency, ...) PlaybackHandle
        +stopAll()
    }

    class PlaybackHandle {
        <<protocol>>
        +stop()
        +adjustFrequency(Frequency)
    }

    class SoundSourceProvider {
        <<protocol>>
        +availableSources
        +displayName(for id)
    }

    class SoundFontNotePlayer {
        NotePlayer implementation
        AVAudioEngine + AVAudioUnitSampler
    }

    class SoundFontLibrary {
        SoundSourceProvider implementation
        Parses SF2 preset metadata
    }

    class AudioSessionInterruptionMonitor {
        Fires callback on interruption
    }

    NotePlayer <|.. SoundFontNotePlayer
    PlaybackHandle <|.. SoundFontPlaybackHandle
    SoundSourceProvider <|.. SoundFontLibrary
    SoundFontNotePlayer ..> SoundFontPlaybackHandle : creates
    SoundFontNotePlayer ..> AudioSessionInterruptionMonitor : uses
```

The audio layer knows only frequencies (Hz), velocities, and amplitudes. It has no concept of MIDI notes, musical intervals, or training context. Internally, `SoundFontNotePlayer` decomposes a frequency into the nearest MIDI note + pitch bend for the sampler, but this is invisible to callers.

**Key interface — `PlaybackHandle`:** Every `play()` call returns a handle that owns the playing note. The caller controls the note's lifecycle — `stop()` to end, `adjustFrequency()` for real-time pitch changes. This supports both fixed-duration playback (pitch comparison) and indefinite playback with live adjustment (pitch matching).

---

## Level 2 — Core/Training (Sessions)

```mermaid
classDiagram
    class TrainingSession {
        <<protocol>>
        +start(intervals)
        +stop()
        +isIdle: Bool
    }

    class PitchComparisonSession {
        State machine: idle → playingNote1 →
        playingNote2 → awaitingAnswer → showingFeedback
    }

    class PitchMatchingSession {
        State machine: idle → playingReference →
        awaitingSliderTouch → playingTunable → showingFeedback
    }

    class PitchComparisonObserver {
        <<protocol>>
        +pitchComparisonCompleted(result)
    }

    class PitchMatchingObserver {
        <<protocol>>
        +pitchMatchingCompleted(result)
    }

    TrainingSession <|.. PitchComparisonSession
    TrainingSession <|.. PitchMatchingSession
    PitchComparisonSession ..> PitchComparisonObserver : notifies
    PitchMatchingSession ..> PitchMatchingObserver : notifies
```

Both sessions are `@Observable` state machines with the same structural patterns: protocol-based dependency injection, observer fan-out for side effects (persistence, profile updates, haptics, progress tracking), and error boundary behavior — audio or persistence failures never crash the training loop.

---

## Level 2 — Core/Profile

```mermaid
classDiagram
    class PitchComparisonProfile {
        <<protocol>>
        Per-note statistics and weak spots
    }

    class PitchMatchingProfile {
        <<protocol>>
        Matching accuracy statistics
    }

    class PerceptualProfile {
        128-slot per-note statistics
        Welford's online algorithm
        Rebuilt from records on startup
    }

    class ProgressTimeline {
        Per-mode EWMA-smoothed accuracy
        Adaptive time bucketing
        Trend analysis
    }

    PitchComparisonProfile <|.. PerceptualProfile
    PitchMatchingProfile <|.. PerceptualProfile
    PitchComparisonObserver <|.. PerceptualProfile
    PitchMatchingObserver <|.. PerceptualProfile
    PitchComparisonObserver <|.. ProgressTimeline
    PitchMatchingObserver <|.. ProgressTimeline
```

**PerceptualProfile** is the central user model — a 128-slot array indexed by MIDI note, each holding online statistics via Welford's algorithm. It is never persisted; it is rebuilt from raw training records on every app launch and updated incrementally during training.

**ProgressTimeline** tracks training progress across all four modes independently (unison/interval × comparison/matching). It uses EWMA smoothing with adaptive time bucketing (session → day → week → month granularity) and provides trend analysis (improving / stable / declining).
