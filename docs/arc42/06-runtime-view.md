# 6. Runtime View

## Pitch Comparison Training Loop

The core training interaction — the user answers a stream of pitch comparisons.

```mermaid
sequenceDiagram
    actor User
    participant CS as PitchComparisonSession
    participant Strategy as KazezNoteStrategy
    participant NP as NotePlayer
    participant Observers as Observers<br>(DataStore, Profile,<br>Haptic, ProgressTimeline)

    User->>CS: start(intervals)
    activate CS

    loop Each pitch comparison
        CS->>Strategy: select next comparison<br>(based on profile and settings)
        Strategy-->>CS: PitchComparison

        CS->>NP: play note 1 (fixed duration)
        CS->>NP: play note 2 (fixed duration)
        Note over CS: Answer buttons enabled<br>during note 2

        User->>CS: answer: higher / lower
        CS->>Observers: fan-out completed result

        CS->>CS: show feedback (400ms)
    end

    User->>CS: stop (navigate away / background)
    deactivate CS
```

**Key behavior:**
- The user can answer while note 2 is still playing — no need to wait
- The 400ms feedback phase is skippable by navigating away
- Audio interruptions (phone call, headphone disconnect) trigger automatic stop via `AudioSessionInterruptionMonitor`

## Pitch Matching Loop

The user tunes a note to match a target pitch.

```mermaid
sequenceDiagram
    actor User
    participant PMS as PitchMatchingSession
    participant NP as NotePlayer
    participant Handle as PlaybackHandle
    participant Observers as Observers<br>(DataStore, Profile,<br>ProgressTimeline)

    User->>PMS: start(intervals)
    activate PMS

    loop Each pitch matching attempt
        PMS->>PMS: generate challenge<br>(reference + random offset)

        PMS->>NP: play reference (fixed duration)

        PMS->>NP: play tunable note → handle
        Note over PMS: Awaiting slider touch

        loop User drags slider
            User->>PMS: adjust pitch
            PMS->>Handle: adjustFrequency (real-time)
        end

        User->>PMS: commit (release slider)
        PMS->>Handle: stop()
        PMS->>Observers: fan-out completed result

        PMS->>PMS: show feedback (400ms)
    end

    User->>PMS: stop (navigate away / background)
    deactivate PMS
```

**Key behavior:**
- After the reference plays, the tunable note starts but the slider waits for user touch before the session advances
- Real-time pitch adjustment via `PlaybackHandle.adjustFrequency()` — the user hears the change as they drag
- No visual feedback during active tuning — only after the slider is released

## App Startup and Profile Rebuild

```mermaid
sequenceDiagram
    participant App as PeachApp.init()
    participant DS as TrainingDataStore
    participant Profile as PerceptualProfile
    participant PT as ProgressTimeline

    App->>App: Create ModelContainer

    App->>DS: fetch all comparison records
    loop Each record
        App->>Profile: update statistics
        App->>PT: update progress
    end

    App->>DS: fetch all matching records
    loop Each record
        App->>Profile: update matching statistics
        App->>PT: update progress
    end

    Note over App: Inject all services<br>into SwiftUI environment
```

The perceptual profile and progress timeline are never persisted — they are always rebuilt from raw records. This ensures consistency with stored data and simplifies the data model.

## Audio Interruption Handling

```mermaid
stateDiagram-v2
    [*] --> Training : User taps Start

    Training --> Interrupted : Phone call / Headphone disconnect /<br>App backgrounded

    state Interrupted {
        [*] --> StopCurrentNote : AudioSessionInterruptionMonitor<br>fires onStopRequired
        StopCurrentNote --> DiscardIncomplete : Incomplete pitch comparison/<br>match discarded
        DiscardIncomplete --> ReturnToStart : state = idle
    }

    Interrupted --> StartScreen : Navigation stack<br>pops to root

    StartScreen --> Training : User taps Start again
```

Interruption handling is identical for both training modes. The session discards any incomplete attempt — no partial data is ever persisted.
