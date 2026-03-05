# 12. Glossary

The comprehensive glossary is maintained separately at [docs/planning-artifacts/glossary.md](../planning-artifacts/glossary.md). It covers all domain terms, technical terms, screen names, and control names used in the project.

The following table summarizes the most architecturally significant terms:

| Term | Definition |
|---|---|
| **Training Mode** | One of four activities: Unison Pitch Comparison, Interval Pitch Comparison, Unison Pitch Matching, Interval Pitch Matching. Each has independent progress tracking via `TrainingModeConfig`. |
| **Pitch Comparison** | A single pitch comparison interaction: two sequential notes, user judges higher/lower. The atomic unit of pitch comparison training. |
| **Pitch Matching** | A training interaction where the user tunes a note to match a target pitch via a vertical slider. Results are continuous (signed cent error), not binary. |
| **Perceptual Profile** | The in-memory user model: 128-slot array indexed by MIDI note, each slot holding Welford's online mean/variance/stdDev. Rebuilt from records on startup, updated incrementally during training. Conforms to both `PitchComparisonProfile` and `PitchMatchingProfile`. |
| **Cent** | Unit of pitch difference. 100 cents = 1 semitone, 1200 cents = 1 octave. Represented by the `Cents` domain type at public API boundaries. |
| **DetunedMIDINote** | A MIDI note with a cent offset applied. Bridges the logical world (MIDI) and physical world (frequency) through `TuningSystem`. |
| **PlaybackHandle** | Protocol representing ownership of a playing note. Provides `stop()` and `adjustFrequency()`. Returned by `NotePlayer.play()`. |
| **PitchComparisonSession** | State machine orchestrating the pitch comparison training loop. Coordinates strategy, audio, persistence, and profile updates. |
| **PitchMatchingSession** | State machine orchestrating the pitch matching loop. Manages reference playback, slider interaction, and result recording. |
| **Kazez Note Strategy** | The psychoacoustic staircase algorithm: narrows difficulty on correct answers, widens on wrong, with asymmetric step sizes and square-root scaling. Named coefficients in `KazezConfiguration`. |
| **Two-World Architecture** | Strict separation between logical types (MIDINote, Interval, Cents) and physical types (Frequency). Bridged exclusively through `TuningSystem`. |
| **Observer Fan-Out** | Pattern where sessions notify an array of observers (DataStore, Profile, ProgressTimeline, Haptic) after each completed exercise. Each observer handles its own errors. |
| **Welford's Algorithm** | Incremental online algorithm for computing mean and variance without storing all historical data. Used in `PerceptualProfile` for O(1) per-record updates. |
| **TuningSystem** | Enum (`.equalTemperament`) that maps musical intervals to cent offsets and computes frequencies from detuned MIDI notes. |
| **ProgressTimeline** | Tracks training progress over time for all four modes independently. Uses EWMA smoothing with adaptive time bucketing. Provides trend analysis. |
| **DirectedInterval** | Value type combining `Interval` + `Direction` (up/down) for session parameterization. |
| **TrainingConstants** | Shared configuration (feedback duration 400ms, default velocity, default amplitude) used by both session types. |
