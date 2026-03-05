# Peach — Glossary

## Concepts

### Core Training Concepts

| Term | Definition |
|---|---|
| **Training Mode** | One of four training activities: Unison Pitch Comparison, Interval Pitch Comparison, Unison Pitch Matching, Interval Pitch Matching. Each mode has independent progress tracking via `TrainingModeConfig`. User-facing names: "Hear & Compare" (comparison) and "Tune & Match" (matching), each with "Single Notes" (unison) and "Intervals" variants. |
| **Pitch Comparison** | A single pitch comparison training interaction: two sequential notes are played, and the user judges whether the second is higher or lower than the first. The atomic unit of pitch comparison training. Contains a reference note, a target note (possibly at a different interval), and a cent offset applied to the target. |
| **Completed Pitch Comparison** | A pitch comparison bundled with the user's answer, tuning system, and timestamp. Contains the original pitch comparison, whether the user answered higher, whether the answer was correct, and the tuning system. Used for recording and analysis. |
| **Pitch Matching** | A training interaction where the user tunes a note to match a target pitch. A reference note plays for a fixed duration, then a tunable note plays indefinitely at a random offset. The user adjusts pitch via a vertical slider and releases to commit. Results are continuous (signed cent error), not binary. Trains active pitch production rather than passive discrimination. |
| **Pitch Matching Challenge** | The parameters for a single pitch matching attempt: a reference MIDI note, a target MIDI note (at the configured interval), and an initial cent offset for the tunable note. Generated randomly (no adaptive selection). |
| **Completed Pitch Matching** | A pitch matching attempt bundled with results: reference note, target note, initial cent offset, user's cent error, tuning system, and timestamp. Used for recording and profile updates. |
| **Answer** | The user's judgment in a pitch comparison — either "higher" (the second note is higher) or "lower" (the second note is lower). Recorded as `userAnsweredHigher` in the system. |
| **Reference Note** | The anchor note in a training exercise, specified as a `MIDINote`. In pitch comparison, it is the first note played. In pitch matching, it is the note the user hears as a reference. Always an exact MIDI note — no detuning applied. |
| **Target Note** | The note the user judges against or tunes toward. In pitch comparison, the target is a `DetunedMIDINote` (MIDI note + cent offset). In pitch matching, the target is the note the user tries to reproduce. For unison (prime interval), target note = reference note. For intervals, target note = reference note transposed by the interval. |
| **Cent** | Unit of pitch difference. 100 cents = 1 semitone, 1200 cents = 1 octave. Used as the measure of pitch comparison and matching precision. Represented by the `Cents` domain type (a `Double` wrapper). |
| **Cent Offset** | The signed pitch difference applied to a target note. Positive values raise the pitch, negative values lower it. Used in `DetunedMIDINote`, frequency calculations, and `PitchComparisonRecord`. Always refers to the offset from the exact target note pitch. |
| **Initial Cent Offset** | The starting pitch offset of the tunable note in a pitch matching challenge. Random within ±20 cents. Stored in `PitchMatchingRecord` for future analysis. Domain type: `Cents`. |
| **User Cent Error** | The signed difference between the user's final pitch and the target pitch in a pitch matching attempt. Positive = user was sharp, negative = user was flat. The primary metric for matching accuracy. Domain type: `Cents`. |
| **MIDI Note** | A standardized numerical representation of musical pitch (0-127), where 60 is middle C (C4) and 69 is A4. Each increment represents one semitone. Represented by the `MIDINote` domain type (an `Int` wrapper with 0-127 range validation). |
| **DetunedMIDINote** | A MIDI note with a cent offset applied. Bridges the logical world (MIDI notes, intervals) and the physical world (frequencies) through `TuningSystem`. Used as the target in pitch comparisons. |
| **Directed Interval** | A `DirectedInterval` value type combining an `Interval` (prime through octave) with a `Direction` (up or down). Used in settings and session parameterization to specify both the interval and its direction. |

### Algorithm & Strategy

| Term | Definition |
|---|---|
| **Next Pitch Comparison Strategy** | A protocol defining how the next pitch comparison is selected based on the user's perceptual profile and training settings. Takes interval and tuning system parameters. Implementations determine which note to present and what cent offset to use. |
| **Kazez Note Strategy** | The default implementation of `NextPitchComparisonStrategy`. A psychoacoustic staircase algorithm that narrows difficulty on correct answers and widens on incorrect, with asymmetric step sizes and square-root scaling. Named coefficients: `narrowingFactor` (0.95), `wideningFactor` (1.3), `convergenceExponent` (0.5). |
| **Perceptual Profile** | The concrete `@Observable` class tracking both pitch comparison and pitch matching abilities. Conforms to both `PitchComparisonProfile` and `PitchMatchingProfile` protocols. For pitch comparison: tracks per-note statistics (mean detection threshold, standard deviation, sample count) for all 128 MIDI notes using Welford's algorithm. For matching: tracks overall matching accuracy (mean absolute error, standard deviation). In-memory only — rebuilt from records on startup, updated incrementally during training. |
| **Training Mode Config** | A `TrainingModeConfig` struct holding per-mode configuration for progress tracking: display name, unit label, optimal baseline, EWMA half-life, and session gap. Four static instances correspond to the four training modes. |

### Profile & Statistics

| Term | Definition |
|---|---|
| **Pitch Comparison Profile** | Protocol defining the interface for pitch comparison statistics — the ability to distinguish between two pitches. Tracks per-note detection thresholds, weak spots, and overall mean/standard deviation. All cent-valued properties use the `Cents` domain type. Used by `PitchComparisonSession` and `NextPitchComparisonStrategy`. Conformed to by `PerceptualProfile`. |
| **Pitch Matching Profile** | Protocol defining the interface for pitch matching statistics — the ability to reproduce a target pitch. Tracks overall matching accuracy (mean absolute error, standard deviation, sample count). All cent-valued properties use the `Cents` domain type. Used by `PitchMatchingSession`. Conformed to by `PerceptualProfile`. |
| **Mean Detection Threshold** | The average cent offset at which pitch comparisons have been presented for a specific note. Represents the estimated pitch difference the user can distinguish at that note. Derived incrementally using Welford's algorithm. Used to identify weak spots and set difficulty. |
| **Standard Deviation** | A measure of consistency in pitch perception for a note. Lower values indicate more consistent performance. Calculated incrementally using Welford's algorithm. |
| **Sample Count** | The number of pitch comparisons completed for a specific note. Notes with zero sample count are considered untrained. |
| **Trained Note** | A note with at least one completed pitch comparison (sample count > 0). Has statistical data (mean, standard deviation) that can inform difficulty selection. |
| **Untrained Note** | A note with zero completed pitch comparisons. Receives highest priority as a weak spot. Initial difficulty determined from overall mean or defaults to 100 cents. |
| **Welford's Algorithm** | An incremental statistical method for calculating mean and variance without storing all historical data. Enables efficient real-time profile updates as each comparison completes. Used internally by `PerceptualProfile` (operating on raw `Double` values, not `Cents` wrappers). |
| **Cold Start** | The initial state for a new user or untrained note. All notes have zero sample count, no statistical data exists. Pitch comparisons default to 100-cent differences, and note selection prioritizes untrained notes as weak spots. |
| **Confidence Band** | The visual representation of detection thresholds across the note range, overlaid on the piano keyboard in the perceptual profile visualization. |
| **Progress Timeline** | A `ProgressTimeline` class that tracks training progress over time for all four training modes independently. Uses EWMA smoothing with adaptive time bucketing. Provides trend analysis (improving/stable/declining) and latest values for each mode. Conforms to both `PitchComparisonObserver` and `PitchMatchingObserver`. |
| **EWMA** | Exponentially Weighted Moving Average — a smoothing technique that gives more weight to recent data points. Used by `ProgressTimeline` to smooth raw training metrics over time, with a configurable half-life (default 7 days). |
| **Time Bucket** | A grouping of training records by time proximity for progress tracking. Records within a `sessionGap` (30 minutes) of each other are grouped into the same bucket. Each bucket's metric is averaged, then EWMA-smoothed across buckets. `BucketSize` enum determines display resolution (hourly, daily, weekly, monthly). |

### Audio

| Term | Definition |
|---|---|
| **Note Player** | A protocol for playing musical notes at specified pitches. Returns a `PlaybackHandle` for controlling the playing note. Knows `Pitch` (MIDINote + Cents), velocities (`MIDIVelocity`), and amplitudes (`AmplitudeDB`). No concept of training or comparisons. Serves both pitch comparison and pitch matching modes. |
| **Playback Handle** | A protocol representing ownership of a currently playing note. Returned by `NotePlayer.play()`. Provides `stop()` to end playback (idempotent) and `adjustFrequency()` to change pitch in real time. Ensures every started note has an explicit owner responsible for stopping it. |
| **Indefinite Playback** | A note that plays until explicitly stopped via its `PlaybackHandle`. Used for the tunable note in pitch matching. No fixed duration — the user decides when to commit by releasing the slider. |
| **Two-World Architecture** | Strict separation between logical types (`MIDINote`, `Interval`, `Cents`, `DetunedMIDINote`) and physical types (`Frequency`). Bridged exclusively through `TuningSystem.frequency(for:referencePitch:)`. Forward conversion always goes through `TuningSystem`; inverse is internal to `SoundFontNotePlayer`. |

### Training & State

| Term | Definition |
|---|---|
| **Pitch Comparison Session** | The central orchestrator for the pitch comparison training loop state machine. Coordinates pitch comparison generation, note playback, answer handling, observer notification, and feedback display. Manages graceful error handling and audio interruptions. |
| **Pitch Comparison Session State** | The current phase of the pitch comparison training loop. Values: `idle`, `playingNote1`, `playingNote2`, `awaitingAnswer`, `showingFeedback`. |
| **Pitch Matching Session** | The orchestrator for the pitch matching training loop state machine. Coordinates reference note playback, tunable note playback with real-time frequency adjustment, result recording, and observer notification. Follows the same patterns as `PitchComparisonSession` (error boundary, observer injection, environment injection). |
| **Pitch Matching Session State** | The current phase of the pitch matching loop. Values: `idle`, `playingReference`, `awaitingSliderTouch`, `playingTunable`, `showingFeedback`. |
| **Training Session** | A protocol that both `PitchComparisonSession` and `PitchMatchingSession` conform to. Defines the common interface: `start(intervals:)`, `stop()`, `isIdle`. Enables the `activeSession` tracking in `PeachApp`. |
| **Pitch Comparison Observer** | Protocol for receiving completed pitch comparison results. Conforming types: `TrainingDataStore` (persistence), `PerceptualProfile` (statistics), `HapticFeedbackManager` (haptic on incorrect), `ProgressTimeline` (trend tracking). |
| **Pitch Matching Observer** | Protocol for receiving completed pitch matching results. Conforming types: `TrainingDataStore` (persistence), `PerceptualProfile` (matching statistics), `ProgressTimeline` (trend tracking). |
| **Training Constants** | A `TrainingConstants` enum providing shared configuration values used across both training sessions: `feedbackDuration` (400ms), `defaultNoteVelocity`, `defaultAmplitudeDB`. |
| **Haptic Feedback** | Tactile vibration provided through the device when a pitch comparison answer is incorrect. Uses a double heavy-intensity impact pattern. No haptic occurs for correct answers (silence = confirmation). Not used for pitch matching. |
| **Audio Interruption** | An external event that disrupts audio playback, such as phone calls, Siri activation, alarms, or headphone disconnection. Automatically stops the active session, requiring explicit user restart. |

### Configuration

| Term | Definition |
|---|---|
| **Reference Pitch** | The tuning standard used to derive all note frequencies. Default: A4 = 440Hz. Supports alternatives including A442, A432, A415. Configurable in settings. Used by both training modes. |
| **Note Range** | The span of MIDI notes used for training, defined as a `NoteRange` (closed range of `MIDINote`). Default: C2 to C6 (MIDI 36-84). Configurable in settings. For interval training, the effective upper bound is reduced by the interval's semitone count to keep the target note within valid MIDI range. |
| **Training Settings** | Configuration parameters that control training behavior, read from `UserSettings` protocol. Includes note range, reference pitch, intervals, tuning system, note duration. Shared across both training modes. |
| **Tuning System** | An enum (`.equalTemperament`) that maps musical intervals to cent offsets and computes frequencies from `DetunedMIDINote` values. Extensible to future systems (just intonation, Pythagorean). |
| **Min Cent Difference** | The difficulty floor — the smallest cent difference the algorithm will use. Default: 1.0 cent. |
| **Max Cent Difference** | The difficulty ceiling — the largest cent difference the algorithm will use. Default: 100.0 cents (1 semitone). |

## Screens

| Term | Definition |
|---|---|
| **Start Screen** | The app's home screen. Shows four training mode buttons (two unison, two interval), the Profile Preview (tappable), and buttons for Settings, Profile, and Info screens. |
| **Info Screen** | Displays app name, developer, copyright, and version number. |
| **Pitch Comparison Screen** | The active pitch comparison training interface. Shows Higher/Lower buttons and the Pitch Comparison Feedback Indicator, plus interval label when in interval mode. Navigating away stops training. |
| **Pitch Matching Screen** | The active pitch matching interface. Shows the Vertical Pitch Slider and Pitch Matching Feedback Indicator, plus interval label when in interval mode. Navigating away stops the session. |
| **Profile Screen** | The full perceptual profile visualization. Shows the piano keyboard with confidence band overlay, summary statistics with trend, pitch matching accuracy, and progress timeline cards for all four training modes. |
| **Settings Screen** | Configuration interface. Contains note range, note duration, reference pitch, sound source selection, and interval selector. |

## Controls

| Term | Definition |
|---|---|
| **Higher Button** | Pitch Comparison Screen control. User taps when they judge the second note to be higher. Disabled during the first note. |
| **Lower Button** | Pitch Comparison Screen control. User taps when they judge the second note to be lower. Disabled during the first note. |
| **Profile Preview** | Stylized miniature of the perceptual profile shown on the Start Screen. Tappable to navigate to the full Profile Screen. |
| **Pitch Comparison Feedback Indicator** | Visual element showing thumbs up (correct) or thumbs down (incorrect) after each pitch comparison. Displays for 400ms. Accompanied by haptic feedback on incorrect answers. |
| **Vertical Pitch Slider** | Custom `DragGesture`-based vertical slider on the Pitch Matching Screen. Occupies most of the screen height. Up = sharper, down = flatter. Always starts at the same physical position regardless of pitch offset. No markings — a blank instrument. |
| **Pitch Matching Feedback Indicator** | Visual element showing directional arrow and signed cent offset after each attempt. Green dot for ~0 cents, short green arrow (<10 cents), medium yellow arrow (10-30 cents), long red arrow (>30 cents). Displays for 400ms. No haptic feedback. |
