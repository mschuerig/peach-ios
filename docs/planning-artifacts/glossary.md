# Peach — Glossary

## Concepts

### Core Training Concepts

| Term | Definition |
|---|---|
| **Comparison** | A single comparison training interaction containing Note1, Note2, cent difference, and direction. Two sequential notes are played, and the user judges whether the second is higher or lower than the first. The atomic unit of comparison training. |
| **Completed Comparison** | A comparison bundled with the user's answer and timestamp. Contains the original comparison, whether the user answered higher, and whether the answer was correct. Used for recording and analysis. |
| **Pitch Matching** | A training interaction where the user tunes a note to match a reference pitch (v0.2). A reference note plays for a fixed duration, then a tunable note plays indefinitely at a random offset. The user adjusts pitch via a vertical slider and releases to commit. Results are continuous (signed cent error), not binary. Trains active pitch production rather than passive discrimination. |
| **Pitch Matching Challenge** | The parameters for a single pitch matching attempt: a reference MIDI note and an initial cent offset for the tunable note. Generated randomly for v0.2 (no adaptive selection). |
| **Completed Pitch Matching** | A pitch matching attempt bundled with results: reference note, initial cent offset, user's cent error, and timestamp. Used for recording and profile updates. |
| **Answer** | The user's judgment in a comparison — either "higher" (the second note is higher) or "lower" (the second note is lower). Recorded as `userAnsweredHigher` in the system. |
| **Note1** | The reference note in a comparison, specified as a MIDI number (0-127). The first note played in each comparison. |
| **Note2** | The target note in a comparison, specified as a MIDI number (0-127). Typically the same MIDI number as Note1, with pitch difference applied through cent offset. The second note played in each comparison. |
| **Cent** | Unit of pitch difference. 100 cents = 1 semitone. Used as the measure of discrimination and matching precision. |
| **Cent Difference** | The magnitude of pitch difference between two notes, always positive. 100 cents equals 1 semitone. Converted to signed cent offset based on direction. |
| **Cent Offset** | The signed pitch difference applied to a note. Positive values raise the pitch, negative values lower it. Used in frequency calculations and profile statistics. |
| **Initial Cent Offset** | The starting pitch offset of the tunable note in a pitch matching challenge. Random within ±100 cents for v0.2. Stored in `PitchMatchingRecord` for future analysis. |
| **User Cent Error** | The signed difference between the user's final pitch and the reference pitch in a pitch matching attempt. Positive = user was sharp, negative = user was flat. The primary metric for matching accuracy. |
| **MIDI Note** | A standardized numerical representation of musical pitch (0-127), where 60 is middle C (C4) and 69 is A4. Each increment represents one semitone. |

### Algorithm & Strategy

| Term | Definition |
|---|---|
| **Next Comparison Strategy** | A protocol defining how the next comparison is selected based on the user's perceptual profile and training settings. Implementations determine which note to present and what cent difference to use. Formerly "Next Note Strategy" — renamed for v0.2 clarity. |
| **Adaptive Note Strategy** | The intelligent comparison selection algorithm. Balances between exploring nearby notes (Natural mode) and targeting weak spots (Mechanical mode). Adjusts difficulty regionally based on user performance. |
| **Natural vs. Mechanical** | The user-facing algorithm behavior slider (0.0 to 1.0). Natural (0.0) selects nearby notes for regional training. Mechanical (1.0) jumps to weak spots across the range. Values in between use weighted probability. |
| **Weak Spot** | A note where the user's detection threshold is relatively large, indicating lower discrimination ability. Identified by comparing absolute mean values across notes — untrained notes are considered the weakest spots. The algorithm prioritizes these in Mechanical mode. |
| **Regional Range** | The pitch range (±12 semitones = one octave) defining a training region. Within this range: (1) difficulty persists and adjusts gradually based on performance, (2) Natural mode selects nearby notes to maintain regional focus. Jumping beyond this range resets difficulty to the mean detection threshold and switches training zones. |
| **Narrowing Factor** | The multiplier (0.95 = 5% harder) applied to cent difference after a correct answer within the same regional range. Makes subsequent comparisons progressively more challenging. |
| **Widening Factor** | The multiplier (1.3 = 30% easier) applied to cent difference after an incorrect answer within the same regional range. Makes subsequent comparisons easier to help the user succeed. |
| **Current Difficulty** | The active cent difference being used for a note during regional training. Starts at the mean detection threshold when jumping to a new region, then adjusts via narrowing/widening factors based on correctness. Distinct from mean detection threshold, which tracks historical averages across all comparisons. |
| **Range Mean** | The average detection threshold calculated across all trained notes in the note range. Used as the initial difficulty for untrained notes when no nearby trained notes exist. Falls back to 100 cents if no notes are trained. |

### Profile & Statistics

| Term | Definition |
|---|---|
| **Perceptual Profile** | The concrete class tracking both pitch discrimination and pitch matching abilities. Conforms to both `PitchDiscriminationProfile` and `PitchMatchingProfile` protocols. For discrimination: tracks per-note statistics (mean detection threshold, standard deviation, sample count) for all 128 MIDI notes. For matching: tracks overall matching accuracy (mean absolute error, standard deviation). Updated incrementally as comparisons or pitch matching attempts complete. Visualized on the Profile Screen. |
| **Pitch Discrimination Profile** | Protocol defining the interface for pitch discrimination statistics — the ability to distinguish between two pitches. Tracks per-note detection thresholds, weak spots, and overall mean/standard deviation. Used by `ComparisonSession` and `NextComparisonStrategy`. Conformed to by `PerceptualProfile`. |
| **Pitch Matching Profile** | Protocol defining the interface for pitch matching statistics — the ability to reproduce a target pitch. Tracks overall matching accuracy (mean absolute error, standard deviation, sample count). Used by `PitchMatchingSession`. Conformed to by `PerceptualProfile`. |
| **Mean Detection Threshold** | The average signed cent offset at which comparisons have been presented for a specific note. Positive values indicate more "higher" comparisons, negative values indicate more "lower" comparisons. Represents the estimated pitch difference the user can discriminate at that note. Derived incrementally from comparison history using Welford's algorithm. Used to identify weak spots and set difficulty. |
| **Standard Deviation** | A measure of consistency in pitch discrimination for a note. Lower values indicate more consistent performance. Calculated incrementally using Welford's algorithm. |
| **Sample Count** | The number of comparisons completed for a specific note. Notes with zero sample count are considered untrained. Used to determine whether a note has sufficient training data. |
| **Trained Note** | A note with at least one completed comparison (sample count > 0). Has statistical data (mean, standard deviation) that can inform difficulty selection. |
| **Untrained Note** | A note with zero completed comparisons. Receives highest priority as a weak spot. Initial difficulty determined from range mean or defaults to 100 cents. |
| **Welford's Algorithm** | An incremental statistical method for calculating mean and variance without storing all historical data. Enables efficient real-time profile updates as each comparison completes. |
| **Cold Start** | The initial state for a new user or untrained note. All notes have zero sample count, no statistical data exists. Comparisons default to 100-cent differences, and note selection is either random or prioritizes untrained notes as weak spots. |
| **Confidence Band** | The visual representation of detection thresholds across the note range, overlaid on the piano keyboard in the perceptual profile visualization. |

### Audio

| Term | Definition |
|---|---|
| **Note Player** | A protocol for playing musical notes at specified frequencies. Returns a `PlaybackHandle` for controlling the playing note. Knows only frequencies (Hz), velocities, and amplitudes — no concept of MIDI notes, comparisons, or training. Serves both comparison and pitch matching modes. |
| **Playback Handle** | A protocol representing ownership of a currently playing note. Returned by `NotePlayer.play()`. Provides `stop()` to end playback (idempotent — subsequent calls are no-ops) and `adjustFrequency()` to change the pitch of the playing note in real time. Ensures every started note has an explicit owner responsible for stopping it. |
| **Indefinite Playback** | A note that plays until explicitly stopped via its `PlaybackHandle`. Used for the tunable note in pitch matching. No fixed duration — the user decides when to commit by releasing the slider. |

### Training & State

| Term | Definition |
|---|---|
| **Comparison Session** | The central orchestrator for the comparison training loop state machine. Coordinates comparison generation, note playback, answer handling, observer notification, and feedback display. Manages graceful error handling and audio interruptions. Formerly "Training Session" — renamed for v0.2 clarity. |
| **Comparison Session State** | The current phase of the comparison training loop. Values: `idle` (not training), `playingNote1` (first note playing, buttons disabled), `playingNote2` (second note playing, buttons enabled), `awaitingAnswer` (both notes finished, waiting for user), `showingFeedback` (displaying result before next comparison). Formerly "Training State" — renamed for v0.2 clarity. |
| **Pitch Matching Session** | The orchestrator for the pitch matching training loop state machine (v0.2). Coordinates reference note playback, tunable note playback with real-time frequency adjustment, result recording, and observer notification. Follows the same patterns as `ComparisonSession` (error boundary, observer injection, environment injection). |
| **Pitch Matching Session State** | The current phase of the pitch matching loop (v0.2). Values: `idle` (not started), `playingReference` (reference note playing, slider visible but disabled), `playingTunable` (tunable note playing indefinitely, slider active), `showingFeedback` (note stopped, result displayed ~400ms). |
| **Comparison Observer** | Protocol for receiving completed comparison results. Conforming types: `TrainingDataStore` (persistence), `PerceptualProfile` (statistics), `HapticFeedbackManager` (haptic on incorrect), `TrendAnalyzer`, `ThresholdTimeline`. |
| **Pitch Matching Observer** | Protocol for receiving completed pitch matching results (v0.2). Conforming types: `TrainingDataStore` (persistence), `PerceptualProfile` (matching statistics). No haptic observer — pitch matching has no haptic feedback. |
| **Haptic Feedback** | Tactile vibration provided through the device when a comparison answer is incorrect. Uses a double heavy-intensity impact pattern. No haptic occurs for correct answers (silence = confirmation). Enables eyes-closed comparison training. Not used for pitch matching. |
| **Audio Interruption** | An external event that disrupts audio playback, such as phone calls, Siri activation, alarms, or headphone disconnection. Automatically stops the active session (comparison or pitch matching), requiring explicit user restart. |

### Configuration

| Term | Definition |
|---|---|
| **Reference Pitch** | The tuning standard used to derive all note frequencies. Default: A4 = 440Hz (standard concert pitch). Supports alternative tunings including A442 (orchestral), A432 (alternative), and A415 (baroque). Configurable in settings. Used by both comparison and pitch matching training. |
| **Note Range** | The span of MIDI notes used for training, defined by minimum and maximum boundaries (noteRangeMin and noteRangeMax in TrainingSettings). Default: C2 to C6 (MIDI 36-84), covering typical vocal and instrument ranges. Configurable in settings. Used by both comparison and pitch matching training. |
| **Training Settings** | Configuration parameters that control training behavior. Includes note range boundaries, Natural/Mechanical balance, reference pitch, and difficulty bounds (min/max cent difference). Shared across both training modes; some fields (Natural/Mechanical, difficulty bounds) are comparison-specific. |
| **Min Cent Difference** | The difficulty floor — the smallest cent difference the algorithm will use. Default: 1.0 cent, representing the practical limit of human pitch discrimination. Prevents comparisons from becoming impossibly difficult. |
| **Max Cent Difference** | The difficulty ceiling — the largest cent difference the algorithm will use. Default: 100.0 cents (1 semitone), representing easily detectable intervals. Prevents comparisons from becoming too easy. |

## Screens

| Term | Definition |
|---|---|
| **Start Screen** | The app's home screen. Shows the Start Training Button, the Pitch Matching Button (v0.2), a short app description, the Profile Preview (tappable), and buttons for Settings Screen, Profile Screen, and Info Screen. |
| **Info Screen** | Displays app name, developer, copyright, and version number. Accessible from the Start Screen. |
| **Comparison Screen** | The active comparison training interface. Shows the Higher Button, Lower Button, and Comparison Feedback Indicator, plus buttons for Settings Screen and Profile Screen. Navigating to Settings or Profile stops training. Minimal by design — no distractions. Formerly "Training Screen" — renamed for v0.2 clarity. |
| **Pitch Matching Screen** | The active pitch matching interface (v0.2). Shows the Vertical Pitch Slider and Pitch Matching Feedback Indicator, plus buttons for Settings Screen and Profile Screen. Navigating to Settings or Profile stops the session and discards incomplete attempts. |
| **Profile Screen** | The full perceptual profile visualization. Shows the piano keyboard with confidence band overlay, summary statistics (mean and standard deviation with trend), and pitch matching accuracy statistics (v0.2). Accessible from both Start Screen and training screens. Always returns to Start Screen. |
| **Settings Screen** | Configuration interface. Contains the Natural vs. Mechanical slider, note range, note duration, reference pitch, and sound source selection. |

## Controls

| Term | Definition |
|---|---|
| **Start Training Button** | Prominent button on the Start Screen that immediately begins a comparison training session. The primary call to action. |
| **Pitch Matching Button** | Secondary button on the Start Screen (v0.2) that begins a pitch matching session. Visually subordinate to Start Training — `.bordered` style below the `.borderedProminent` Start Training button. |
| **Higher Button** | Comparison Screen control. User taps this when they judge the second note to be higher than the first. Disabled during the first note, enabled when the second note plays. |
| **Lower Button** | Comparison Screen control. User taps this when they judge the second note to be lower than the first. Disabled during the first note, enabled when the second note plays. |
| **Profile Preview** | Stylized miniature of the perceptual profile shown on the Start Screen. Tappable to navigate to the full Profile Screen. |
| **Comparison Feedback Indicator** | Visual element on the Comparison Screen showing thumbs up (correct) or thumbs down (incorrect) after each comparison. Displays for 0.4 seconds before the next comparison begins. Accompanied by haptic feedback on incorrect answers. Formerly "Feedback Indicator" — renamed for v0.2 clarity. |
| **Vertical Pitch Slider** | Custom `DragGesture`-based vertical slider on the Pitch Matching Screen (v0.2). Occupies most of the screen height. Up = sharper, down = flatter. Always starts at the same physical position (center) regardless of pitch offset. No markings — a blank instrument. States: inactive (during reference), active (tunable playing), dragging, released. |
| **Pitch Matching Feedback Indicator** | Visual element on the Pitch Matching Screen (v0.2) showing directional arrow and signed cent offset after each attempt. Green dot for dead center (~0 cents), short green arrow (<10 cents), medium yellow arrow (10-30 cents), long red arrow (>30 cents). Displays for ~400ms. No haptic feedback. |
