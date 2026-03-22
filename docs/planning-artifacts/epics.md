---
stepsCompleted: ['step-01-validate-prerequisites', 'step-02-design-epics', 'step-03-create-stories', 'step-04-final-validation', 'v0.2-step-01-validate-prerequisites', 'v0.2-step-02-design-epics', 'v0.2-step-03-create-stories', 'v0.2-step-04-final-validation', 'v0.3-step-01-validate-prerequisites', 'v0.3-step-02-design-epics', 'v0.3-step-03-create-stories', 'v0.3-step-04-final-validation', 'v0.4-step-01-validate-prerequisites', 'v0.4-step-02-design-epics', 'v0.4-step-03-create-stories', 'v0.4-step-04-final-validation', 'v0.5-sharing']
inputDocuments: ['docs/planning-artifacts/prd.md', 'docs/planning-artifacts/architecture.md', 'docs/planning-artifacts/ux-design-specification.md', 'docs/planning-artifacts/glossary.md', 'docs/project-context.md', 'docs/planning-artifacts/research/technical-profile-screen-chart-ux-research-2026-03-11.md', 'docs/planning-artifacts/rhythm-training-spec.md']
---

# Peach - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for Peach, decomposing the requirements from the PRD, UX Design, and Architecture into implementable stories.

## Requirements Inventory

### Functional Requirements

FR1: User can start a training session immediately from the Start Screen with a single tap
FR2: User can hear two sequential notes played one after another within a comparison
FR3: User can answer whether the second note was higher or lower than the first
FR4: User can see immediate visual feedback (Feedback Indicator) after answering
FR5: User can feel haptic feedback when answering incorrectly
FR6: User can stop training by navigating to Settings or Profile from the Training Screen, or by leaving the app
FR7: System discards incomplete comparisons when training is interrupted (navigation away, app backgrounding, phone call, headphone disconnect)
FR7a: System returns to the Start Screen when the app is foregrounded after being backgrounded during training
FR8: System disables answer controls during the first note and enables them when the second note begins playing
FR9: System selects the next comparison based on the user's perceptual profile
FR10: System adjusts comparison difficulty (cent difference) based on answer correctness — narrower on correct, wider on wrong
FR11: System balances between training nearby the current pitch region and jumping to weak spots, controlled by a tunable ratio
FR12: System initializes new users with random comparisons at 100 cents (1 semitone) with all notes treated as weak
FR13: System maintains the perceptual profile across sessions without requiring explicit save or resume
FR14: System supports fractional cent precision (0.1 cent resolution) with a practical floor of approximately 1 cent
FR15: System exposes algorithm parameters for adjustment during development and testing
FR16: System generates sine wave tones at precise frequencies derived from musical notes and cent offsets
FR17: System plays notes with smooth attack/release envelopes (no audible clicks or artifacts)
FR18: System uses the same timbre for both notes in a comparison
FR19: System supports configurable note duration
FR20: System supports a configurable reference pitch (default A4 = 440Hz)
FR21: User can view their current perceptual profile as a visualization with a piano keyboard axis and confidence band overlay
FR22: User can view a stylized Profile Preview on the Start Screen
FR23: User can navigate from the Start Screen to the full Profile Screen
FR24: User can view summary statistics: arithmetic mean and standard deviation of detectable cent differences over the current training range
FR25: User can see summary statistics as a trend (improving/stable/declining)
FR26: System computes the perceptual profile from stored per-answer data
FR27: System stores every answered comparison as a record containing: two notes, correct/wrong, timestamp
FR28: System persists all training data locally on-device
FR29: System maintains data integrity across app restarts, backgrounding, and device reboots
FR30: User can adjust the algorithm behavior via a "Natural vs. Mechanical" slider
FR31: User can configure the note range (manual bounds or adaptive mode)
FR32: User can configure note duration
FR33: User can configure the reference pitch
FR34: User can select the sound source (MVP: sine wave only)
FR35: System persists all settings across sessions
FR36: System applies setting changes immediately to subsequent comparisons
FR37: User can use the app in English or German
FR38: System provides basic accessibility support (labels, contrast, VoiceOver basics)
FR39: User can use the app on iPhone and iPad
FR40: User can use the app in portrait and landscape orientations
FR41: User can use the app in iPad windowed/compact mode
FR42: User can operate the training loop one-handed with large, imprecise-tap-friendly controls
FR43: User can view an Info Screen from the Start Screen showing app name, developer, copyright, and version number
FR44: User can start pitch matching training from the Start Screen via a dedicated button
FR45: System plays a reference note for the configured note duration, then plays a tunable note indefinitely
FR46: User can adjust the pitch of the tunable note in real time via a large vertical slider control
FR47: System stops the tunable note and records the result when the user releases the slider
FR48: System records pitch matching results: reference note, user's final pitch, error in cents, timestamp
FR49: System provides visual feedback showing the signed cent offset and directional proximity after the user releases the slider (post-release only). No visual feedback during active tuning
FR50: System discards incomplete pitch matching attempts on interruption (navigation away, app backgrounding, phone call, headphone disconnect)
FR50a: System returns to the Start Screen when foregrounded after being backgrounded during pitch matching
FR51: System supports indefinite note playback (no fixed duration) with explicit stop trigger
FR52: System supports real-time frequency adjustment of an actively playing note without audible artifacts
FR53: System represents musical intervals as a value object spanning Prime (unison) through Octave
FR54: System computes the target frequency for an interval using a Tuning System; 12-tone equal temperament (12-TET) is the initial tuning system
FR55: System supports multiple tuning systems beyond 12-TET (e.g., Just Intonation); adding a new tuning system requires no changes to interval or training logic
FR56: User can start interval pitch comparison training from the Start Screen via a dedicated button
FR57: Generalizes FR2: system plays a reference note followed by a second note at the target interval +/- a signed cent deviation
FR58: Generalizes FR3: user answers whether the second note was higher or lower than the correct interval pitch
FR59: FR4, FR5, FR7, FR7a, and FR8 apply to interval comparison identically as to unison comparison
FR60: User can start interval pitch matching training from the Start Screen via a dedicated button
FR61: Generalizes FR45: system plays a reference note for the configured duration, then plays a tunable note indefinitely; the user's target is the correct interval pitch, not unison
FR62: Generalizes FR46: user adjusts the pitch of the tunable note via slider to match the target interval
FR63: FR47, FR49, FR50, and FR50a apply to interval pitch matching identically as to unison pitch matching
FR64: System records interval pitch matching results: reference note, target interval, user's final pitch, error in cents relative to the correct interval pitch, timestamp
FR65: Start Screen shows four training buttons: "Pitch Comparison", "Pitch Matching", "Interval Pitch Comparison", "Interval Pitch Matching"
FR66: Unison comparison and unison pitch matching behave identically to their interval variants with the interval fixed to prime (unison)
FR67: Initial interval training implementation uses a single fixed interval: perfect fifth up (700 cents in 12-TET)
FR68: User can start rhythm comparison training from the Start Screen via a dedicated button
FR69: System plays 4 sixteenth notes using a sharp-attack non-pitched tone at the user's chosen metronome tempo, with the 4th note offset early or late by the current difficulty amount
FR70: User judges whether the 4th note was "Early" or "Late"
FR71: System provides immediate visual feedback and haptic feedback on incorrect answers (same pattern as pitch comparison)
FR72: System tracks early and late as independent difficulty tracks with independent exercise selection per direction
FR73: System discards incomplete rhythm comparison exercises on interruption (navigation away, app backgrounding, phone call, headphone disconnect)
FR73a: System returns to the Start Screen when the app is foregrounded after being backgrounded during rhythm comparison
FR74: User can start rhythm matching training from the Start Screen via a dedicated button
FR75: System plays 3 sixteenth notes at the user's chosen metronome tempo; user taps to produce the 4th note at the correct moment
FR76: System accepts tap input only (clap and MIDI reserved for future; inputMethod field reserved in data model)
FR77: System records rhythm matching results: tempoBPM, userOffsetMs, timestamp
FR78: System tracks separate mean and stdDev for early vs. late errors in rhythm matching
FR79: System discards incomplete rhythm matching exercises on interruption (same rules as FR73)
FR79a: System returns to the Start Screen when the app is foregrounded after being backgrounded during rhythm matching
FR80: System displays non-informative dots during rhythm training — dots light up in sequence as accompaniment with no positional encoding, no target zones, no ghost dots
FR81: In rhythm comparison, 4 dots appear with each note
FR82: In rhythm matching, 3 dots appear with notes; 4th dot appears on user input at the same fixed grid position with color feedback (green/yellow/red) after answer
FR83: System adapts time offset difficulty independently for early and late deviations (asymmetric tracking)
FR84: User can select a fixed metronome tempo in settings; system does not change tempo between exercises
FR85: System enforces a minimum tempo floor of approximately 60 BPM
FR86: System tracks per-tempo statistics: mean, stdDev, sampleCount, currentDifficulty — split by early/late
FR87: System displays rhythm accuracy to users as percentage of one sixteenth note duration (e.g., "4% early", "11% late")
FR88: System stores rhythm data internally as tempo in BPM and a signed time offset in milliseconds (negative=early, positive=late)
FR89: User can view a rhythm profile card headline showing EWMA of the most recent time bucket's combined accuracy across all tempos, with a trend arrow
FR90: User can view a spectrogram-style rhythm detail chart: X-axis progression over time, Y-axis tempos actually trained at, cell color green→yellow→red for accuracy
FR91: Spectrogram displays empty/transparent cells where no training occurred at a given tempo in a given period
FR92: User can tap a spectrogram cell to see early/late breakdown for that tempo and time period
FR93: System schedules rhythm notes with sub-millisecond precision (sample-accurate placement)
FR94: System pre-calculates all note timing before playback begins — no scheduling decisions during audio rendering
FR95: System plays non-pitched percussion tones using available percussion presets
FR96: System configures minimum audio buffer duration for timing-critical rhythm playback
FR97: System stores rhythm comparison results as: tempoBPM, offsetMs (signed), isCorrect, timestamp
FR98: System stores rhythm matching results as: tempoBPM, userOffsetMs, timestamp (inputMethod field reserved for future)
FR99: System derives early/late distinction from the sign of the stored time offset — no separate early/late field per record
FR100: System uses CSV format version 2 for export/import with a trainingType discriminator
FR101: Format version 2 introduces rhythmOffsetDetection and rhythmMatching as new trainingType values with type-specific columns
FR102: V1 exports remain importable; V2 parser handles all training types including V1 records
FR103: System deduplicates merged records by timestamp, tempo, and training type
FR104: Start Screen shows six training buttons: "Pitch Comparison", "Pitch Matching", "Interval Pitch Comparison", "Interval Pitch Matching", "Rhythm Comparison", "Rhythm Matching"
FR105: User can start continuous rhythm matching training from the Start Screen via a dedicated button
FR106: System plays a continuous loop of 4 sixteenth notes at the user's chosen tempo, with step 1 at accent velocity and exactly one step per cycle as a silent gap
FR107: User fills the gap by tapping; system evaluates tap timing against a window centered on the gap
FR108: System silently ignores taps outside the evaluation window; tap button remains visually active at all times
FR109: User can select which gap positions (1–4) are enabled in settings; when multiple are enabled, each cycle randomly selects one
FR110: System aggregates 16 consecutive gap evaluations into a single trial; incomplete trials (< 16 cycles) are discarded on exit
FR111: System displays four dots showing current step position (highlighted) and gap position (outline); step-1 dot visually bolder; gap outline updates at cycle start
FR112: System discards incomplete continuous rhythm matching trials on interruption (same rules as FR79)
FR113: System stores continuous rhythm matching results with aggregate statistics: mean offset, hit rate, per-gap-position breakdown

### NonFunctional Requirements

NFR1: Audio latency — time from triggering a note to audible output must be imperceptible to the user (target < 10ms)
NFR2: Transition between comparisons — next comparison must begin immediately after the user answers, no perceptible loading or delay
NFR3: Frequency precision — generated tones must be accurate to within 0.1 cent of the target frequency
NFR4: App launch to training-ready — Start Screen must be interactive within 2 seconds of app launch
NFR5: Profile Screen rendering — perceptual profile visualization must render within 1 second, including summary statistics computation
NFR6: All interactive controls labeled for VoiceOver
NFR7: Sufficient color contrast ratios for all text and UI elements
NFR8: Tap targets meet minimum size guidelines (44x44 points per Apple HIG)
NFR9: Feedback Indicator provides non-visual feedback (haptic) in addition to visual
NFR10: Training data must survive app crashes, force quits, and unexpected termination without loss
NFR11: Data writes must be atomic — no partial comparison records
NFR12: App updates must preserve all existing training data (no migration data loss)
NFR13: Real-time pitch adjustment: slider input must produce audible frequency change within 20ms — no perceptible lag between gesture and sound
NFR14: Tuning system precision — interval frequency computations must be accurate to within 0.1 cent of the theoretical value for any supported tuning system
NFR-R1: Rhythm note scheduling jitter must not exceed 0.01ms as measured by comparing scheduled vs. actual sample positions in a test harness
NFR-R2: Pre-calculated note schedules must complete before playback begins as verified by unit tests asserting no scheduling calls occur after playback start
NFR-R3: Minimum audio buffer duration: 5ms (0.005s) on supported devices as configured via audio session and verified by measuring actual buffer callback intervals

### Additional Requirements

**From Architecture:**
- Starter template: Xcode 26.3 iOS App template with SwiftUI lifecycle, Swift language, SwiftData storage — this must be Epic 1, Story 1
- Project folder structure organized by feature (App/, Core/, Training/, Profile/, Settings/, Start/, Info/, Resources/)
- Test target mirroring source structure (PeachTests/)
- Swift 6.2.3, iOS 26 deployment target, explicit Swift modules
- SwiftUI with @Observable pattern (not ObservableObject)
- SwiftData for persistence (PitchDiscriminationRecord @Model)
- @AppStorage (UserDefaults) for settings
- AVAudioEngine + AVAudioSourceNode for real-time audio
- Swift Testing framework (@Test, #expect()) for all unit tests
- Protocol-based service architecture: NotePlayer, NextNoteStrategy, TrainingDataStore, PerceptualProfile, TrainingSession
- Typed error enums per service (AudioError, DataStoreError, etc.)
- TrainingSession as error boundary — user never sees error screens
- Dependency injection via SwiftUI environment
- Implementation sequence: Data → Profile → Audio → Algorithm → TrainingSession → UI
- String Catalogs for English/German localization

**From UX Design:**
- Liquid Glass design language (iOS 26 default appearance)
- Stock SwiftUI components everywhere — no custom styles or appearance overrides
- Hub-and-spoke navigation: Start Screen as hub, all secondary screens return to Start Screen
- NavigationStack for navigation, .sheet() for Info Screen
- Training Screen: Higher/Lower buttons large and thumb-friendly, optimized for eyes-closed one-handed operation
- Feedback Indicator: SF Symbols thumbs up/down, system green/red, ~300-500ms display duration
- Profile visualization: SwiftUI Canvas for piano keyboard, Swift Charts AreaMark for confidence band
- Profile Preview: simplified version of full visualization, tappable to navigate to Profile Screen
- Empty/cold-start states: keyboard renders, placeholder band at 100 cents, "Start training to build your profile" text
- Settings Screen: stock SwiftUI Form with Slider, Stepper, Picker controls
- No onboarding, no tutorials, no session summaries, no gamification
- Sensory hierarchy: ears > fingers > eyes (audio-haptic primary, visual secondary)

**From Architecture (v0.2 Amendment):**
- Prerequisite renames: TrainingSession→PitchDiscriminationSession, TrainingState→PitchDiscriminationSessionState, TrainingScreen→PitchDiscriminationScreen, Training/→PitchDiscrimination/, FeedbackIndicator→PitchDiscriminationFeedbackIndicator, NextNoteStrategy→NextPitchDiscriminationStrategy
- PlaybackHandle protocol: new protocol with stop() and adjustFrequency(); NotePlayer.play() returns handle; stop() removed from NotePlayer; fixed-duration convenience via default extension
- SoundFontPlaybackHandle implementation + MockPlaybackHandle for tests
- PitchMatchingRecord SwiftData @Model: referenceNote, initialCentOffset, userCentError, timestamp
- TrainingDataStore extended with pitch matching CRUD + PitchMatchingObserver conformance
- ModelContainer schema updated to include PitchMatchingRecord
- Profile protocol split: PitchDiscriminationProfile (existing behavior extracted) + PitchMatchingProfile (new matching stats)
- PerceptualProfile conforms to both protocols, rebuilt from both record types at startup
- PitchMatchingSession state machine: idle → playingReference → playingTunable → showingFeedback → loop
- PitchMatchingObserver protocol + CompletedPitchMatchingTrial value type
- PitchMatchingTrial value type (random note + random ±100 cent offset for v0.2)
- New PitchMatching/ feature directory
- PeachApp.swift wiring for PitchMatchingSession + NavigationDestination update
- Implementation sequence: renames → PlaybackHandle → data model → profile split → session → UI → Start Screen → Profile Screen

**From UX Design (v0.2 Amendment):**
- Vertical Pitch Slider: custom DragGesture-based, large thumb (>>44pt), no markings, always starts center, states: inactive/active/dragging/released
- Pitch Matching Feedback Indicator: SF Symbol arrow + signed cent offset, green (<10¢) / yellow (10-30¢) / red (>30¢), green dot for dead center
- Start Screen hierarchy: Start Training (.borderedProminent) above Pitch Matching (.bordered)
- Auto-start tunable note after reference stops — no touch-to-start
- No visual feedback during active tuning — ears-only principle (non-negotiable)
- Same ~400ms feedback duration as pitch comparison training
- Same interruption patterns as pitch comparison training
- VoiceOver: accessibilityAdjustableAction for slider, custom labels for feedback ("4 cents sharp", "Dead center")
- Profile Screen: shows matching statistics alongside pitch comparison profile (empty state for cold start)

**From Glossary (v0.2):**
- Domain terminology confirmed: PitchDiscriminationSession, PitchDiscriminationSessionState, PlaybackHandle, PitchMatchingSession, PitchMatchingSessionState, PitchMatchingTrial, CompletedPitchMatchingTrial, PitchDiscriminationProfile, PitchMatchingProfile

**From Architecture (v0.3 Amendment — Prerequisite Refactorings):**
- Arch-A: New domain types — `Interval` enum (Prime through Octave, Int raw value), `TuningSystem` enum (equalTemperament initially, extensible via new cases), `Pitch` struct (MIDINote + Cents with frequency computation). `MIDINote` extensions: `transposed(by:)`, `pitch(at:in:)`. `Frequency` gains `.concert440` constant.
- Arch-B: NotePlayer protocol change — takes `Pitch` instead of `Frequency`. `SoundFontNotePlayer` receives Pitch and maps to MIDI + pitch bend. `PlaybackHandle.adjustFrequency` stays as Frequency.
- Arch-C: FrequencyCalculation migration — logic moves to `Pitch.frequency(referencePitch:)` and `MIDINote.frequency(referencePitch:)`; `FrequencyCalculation.swift` deleted after all call sites migrated.
- Arch-D: Unified reference/target naming — `note1`→`referenceNote`, `note2`→`targetNote`, `note2CentOffset`→`centOffset`, `centDifference`→`centOffset` across value types, records, sessions, strategies, observers, data store, tests, and docs.
- Arch-E: SoundSourceProvider protocol — extracts protocol from `SoundFontLibrary`, decouples `SettingsScreen` from concrete implementation.

**From Architecture (v0.3 Amendment — Session & Data):**
- Session parameterization: `startTraining()` and `startPitchMatching()` renamed to `start()` (intervals and tuningSystem read from `userSettings`); `start()` added to `TrainingSession` protocol; `currentInterval` observable state and `isIntervalMode` computed property
- NextPitchDiscriminationStrategy update: gains `interval` + `tuningSystem` parameters, computes targetNote from interval; MIDI range boundary enforcement (upper bound shrinks by interval semitones)
- Data model updates: `PitchDiscriminationRecord` gains `tuningSystem`, renamed fields; `PitchMatchingRecord` gains `targetNote` and `tuningSystem`; value types gain target/tuning fields
- NavigationDestination: `.training`→`.pitchDiscrimination(intervals:)`, `.pitchMatching(intervals:)` — parameterized with interval sets
- Profile impact: record everything, defer computation changes; interval data flows through existing observer paths; no changes to profile protocols

**From UX Design (v0.3 Amendment):**
- Target interval label: conditional `Text` view at top of both training screens, visible in interval mode (`isIntervalMode`), hidden in unison mode; `.headline`/`.title3` styling; VoiceOver accessible ("Target interval: Perfect Fifth Up")
- Start Screen: four buttons in vertical stack with visual separator between unison and interval groups; Pitch Comparison remains `.borderedProminent`, all others `.bordered`
- Screen reuse: Pitch Comparison Screen and Pitch Matching Screen extended with conditional interval indicator, not duplicated
- Feedback indicators: no change — same patterns for interval and unison modes
- Interruption patterns: identical to unison modes — no interval-specific handling
- No interval settings UI for v0.3 (fixed perfect fifth)

**From Architecture (v0.4 Amendment — Prerequisite Refactorings):**
- Core/Audio/ → Core/Music/ + Core/Audio/ directory split: musical domain value types (MIDINote, Cents, Interval, etc.) move to Core/Music/; audio infrastructure (NotePlayer, PlaybackHandle, SoundFontNotePlayer, etc.) stays in Core/Audio/. File moves only, no type renames.
- PerceptualProfile cleanup: remove stale MIDI-note-indexed comparison tracking, normalize naming conventions, prepare class for multi-mode extension. Must complete before rhythm implementation.
- SoundFontEngine extraction: new internal class that owns AVAudioEngine, AVAudioUnitSampler(s), and AVAudioSourceNode. Consolidates audio hardware ownership from SoundFontNotePlayer.
- SoundFontNotePlayer refactoring: delegates to SoundFontEngine instead of owning AVAudioEngine directly. NotePlayer protocol unchanged.

**From Architecture (v0.4 Amendment — Audio & Sessions):**
- Three-layer audio architecture: SoundFontEngine (shared engine) → SoundFontNotePlayer + SoundFontRhythmPlayer (mid-level) → NotePlayer + RhythmPlayer protocols (high-level)
- RhythmPlayer protocol: play(RhythmPattern) async throws → RhythmPlaybackHandle; stopAll()
- RhythmPattern value type: pre-computed events with absolute sample offsets, sampleRate, totalDuration
- SoundFontRhythmPlayer: concrete implementation using render-thread scheduling via AVAudioSourceNode + scheduleMIDIEventBlock
- RhythmOffsetDetectionSession: Observable state machine (idle → playingPattern → awaitingAnswer → showingFeedback → loop)
- RhythmMatchingSession: Observable state machine (idle → playingLeadIn → awaitingTap → showingFeedback → loop)
- NextRhythmOffsetStrategy protocol: decides direction (early/late) and magnitude based on asymmetric profile
- Observer protocols: RhythmOffsetDetectionObserver, RhythmMatchingObserver with CompletedRhythmOffsetDetectionTrial/CompletedRhythmMatchingTrial value types
- RhythmProfile protocol: updateRhythmOffsetDetection, updateRhythmMatching, rhythmStats(tempo:direction:), trainedTempos, rhythmOverallAccuracy, resetRhythm
- New domain types: TempoBPM (Int), RhythmOffset (Duration, signed), RhythmDirection (early/late)
- RhythmOffsetDetectionRecord + RhythmMatchingRecord SwiftData @Model types
- TrainingDataStore extended with rhythm CRUD + observer conformances
- TrainingDiscipline enum grows from 4 to 6 cases (rhythmOffsetDetection, rhythmMatching)
- NavigationDestination gains .rhythmOffsetDetection and .rhythmMatching (no parameters — tempo from settings)
- CSV format v2: CSVImportParserV2, CSVExportSchemaV2 extending chain-of-responsibility pattern
- 20-step implementation sequence defining dependency ordering

**From Architecture (v0.4 Amendment — Percussion & Timing):**
- ~5 user-facing percussion sounds resolved via SoundSourceID through existing SoundSourceProvider pattern
- AVAudioSourceNode render callback as master clock; events dispatched with exact sample offsets via scheduleMIDIEventBlock
- Minimum audio buffer duration 5ms configured via audio session

### UX Design Requirements

UX-DR1: Rhythm Dot View — 4 dots horizontal, ~16pt diameter, ~24pt spacing, dim (opacity 0.2) / lit (opacity 1.0) states, instant transitions matching percussive attack, .accessibilityHidden(true)
UX-DR2: Early/Late Buttons — side-by-side half-width, directional arrows (SF Symbols arrow.left / arrow.right), .borderedProminent style, disabled during playback, enabled during awaitingAnswer
UX-DR3: Rhythm Tap Button — full-width single button filling space below dots, always enabled, "Tap" label, .borderedProminent style, VoiceOver hint "Tap at the correct moment to match the rhythm"
UX-DR4: Spectrogram Profile View — time × tempo × color grid, square cells, parameterized color thresholds (precise ≤5% green, moderate 5-15% yellow, erratic >15% red), transparent empty cells, tap-to-detail for early/late breakdown
UX-DR5: Rhythm Profile Card — same card structure as pitch cards, headline "Rhythm" + EWMA RhythmDeviation + trend arrow + share button, spectrogram below, empty state with dashes and placeholder text
UX-DR6: Start Screen 6-button layout — section labels ("Pitch", "Intervals", "Rhythm"), portrait vertical stack (scrollable), landscape 3-column grid, Pitch Comparison remains .borderedProminent hero, all others .bordered
UX-DR7: Settings tempo stepper — "Rhythm" section below pitch settings, Stepper 40-200 BPM range step 1, default 80 BPM, "BPM" unit label, @AppStorage auto-save
UX-DR8: Feedback Line — rhythm comparison: checkmark/cross + current difficulty as RhythmDeviation (e.g., "4%"); rhythm matching: arrow + signed RhythmDeviation (e.g., "← 3% early" or "→ 8% late")
UX-DR9: VoiceOver rhythm comparison — "Early" and "Late" button labels, feedback announced as "Correct, 4 percent" or "Incorrect, 4 percent"
UX-DR10: VoiceOver rhythm matching — "Tap" label with hint, feedback announced as "3 percent early" or "8 percent late"
UX-DR11: VoiceOver spectrogram — per-column summaries (e.g., "March week 2: 120 BPM precise, 100 BPM moderate"), activate for detail overlay
UX-DR12: Rhythm Comparison Screen layout — summary stat line + dots above + Early/Late buttons below, full vertical button space
UX-DR13: Rhythm Matching Screen layout — summary stat line + dots above + Tap button below, full vertical button space
UX-DR14: Landscape/iPad adaptive layouts for all rhythm screens and spectrogram

### FR Coverage Map

| FR | Epic | Description |
|---|---|---|
| FR1 | Epic 3 | Start training with single tap |
| FR2 | Epic 3 | Hear two sequential notes |
| FR3 | Epic 3 | Answer higher or lower |
| FR4 | Epic 3 | Immediate visual feedback |
| FR5 | Epic 3 | Haptic feedback on incorrect |
| FR6 | Epic 3 | Stop training via navigation |
| FR7 | Epic 3 | Discard incomplete comparisons |
| FR7a | Epic 3 | Return to Start Screen on foreground |
| FR8 | Epic 3 | Button disable/enable during notes |
| FR9 | Epic 4 | Profile-based comparison selection |
| FR10 | Epic 4 | Difficulty adjustment on correctness |
| FR11 | Epic 4 | Natural vs. Mechanical balance |
| FR12 | Epic 4 | Cold start at 100 cents |
| FR13 | Epic 4 | Profile continuity across sessions |
| FR14 | Epic 4 | Fractional cent precision |
| FR15 | Epic 4 | Expose algorithm parameters |
| FR16 | Epic 2 | Generate precise sine waves |
| FR17 | Epic 2 | Smooth attack/release envelopes |
| FR18 | Epic 2 | Same timbre for both notes |
| FR19 | Epic 2 | Configurable note duration |
| FR20 | Epic 2 | Configurable reference pitch |
| FR21 | Epic 5 | Profile visualization with keyboard + band |
| FR22 | Epic 5 | Profile Preview on Start Screen |
| FR23 | Epic 5 | Navigate to full Profile Screen |
| FR24 | Epic 5 | Summary statistics (mean, std dev) |
| FR25 | Epic 5 | Statistics trend indicator |
| FR26 | Epic 5 | Compute profile from stored data |
| FR27 | Epic 1 | Store comparison records |
| FR28 | Epic 1 | Local on-device persistence |
| FR29 | Epic 1 | Data integrity across restarts |
| FR30 | Epic 6 | Natural vs. Mechanical slider |
| FR31 | Epic 6 | Note range configuration |
| FR32 | Epic 6 | Note duration configuration |
| FR33 | Epic 6 | Reference pitch configuration |
| FR34 | Epic 6 | Sound source selection |
| FR35 | Epic 6 | Settings persistence |
| FR36 | Epic 6 | Immediate settings application |
| FR37 | Epic 7 | English + German localization |
| FR38 | Epic 7 | Basic accessibility support |
| FR39 | Epic 7 | iPhone and iPad support |
| FR40 | Epic 7 | Portrait and landscape |
| FR41 | Epic 7 | iPad windowed/compact mode |
| FR42 | Epic 3 | One-handed, large tap targets |
| FR43 | Epic 7 | Info Screen |
| FR44 | Epic 17 | Start pitch matching from Start Screen |
| FR45 | Epic 15 | Reference note + indefinite tunable note |
| FR46 | Epic 16 | Real-time pitch adjustment via slider |
| FR47 | Epic 15 | Stop tunable on slider release, record result |
| FR48 | Epic 13 | Pitch matching result recording |
| FR49 | Epic 16 | Post-release visual feedback (arrow + cents) |
| FR50 | Epic 15 | Discard incomplete pitch matching on interruption |
| FR50a | Epic 15 | Return to Start Screen on foreground after backgrounding |
| FR51 | Epic 12 | Indefinite note playback with explicit stop |
| FR52 | Epic 12 | Real-time frequency adjustment of playing note |
| FR53 | Epic 21 | Interval value object (Prime through Octave) |
| FR54 | Epic 21 | Target frequency computation via TuningSystem |
| FR55 | Epic 21 | Extensible tuning systems (no training logic changes) |
| FR56 | Epic 24 | Start interval comparison from Start Screen |
| FR57 | Epic 23 | Reference note + second note at target interval ± deviation |
| FR58 | Epic 23 | User judges higher/lower relative to correct interval pitch |
| FR59 | Epic 23 | Feedback, haptic, interruption apply identically |
| FR60 | Epic 24 | Start interval pitch matching from Start Screen |
| FR61 | Epic 23 | Interval pitch matching: target is interval pitch, not unison |
| FR62 | Epic 23 | Slider adjustment to match target interval |
| FR63 | Epic 23 | PM feedback, interruption apply identically |
| FR64 | Epic 23 | Interval PM result recording with interval context |
| FR65 | Epic 24 | Four training buttons on Start Screen |
| FR66 | Epic 23 | Unison = prime case of interval variants |
| FR67 | Epic 24 | Fixed interval: perfect fifth up (700 cents) |
| FR68 | Epic 48 | Start rhythm comparison from Start Screen |
| FR69 | Epic 48 | Play 4 sixteenth notes with offset 4th |
| FR70 | Epic 48 | User judges Early or Late |
| FR71 | Epic 48 | Visual + haptic feedback on incorrect |
| FR72 | Epic 48 | Independent early/late difficulty tracks |
| FR73 | Epic 48 | Discard incomplete rhythm comparison on interruption |
| FR73a | Epic 48 | Return to Start Screen on foreground after backgrounding |
| FR74 | Epic 49 | Start rhythm matching from Start Screen |
| FR75 | Epic 49 | Play 3 sixteenth notes, user taps 4th |
| FR76 | Epic 49 | Tap input only (clap/MIDI reserved) |
| FR77 | Epic 49 | Record rhythm matching results |
| FR78 | Epic 49 | Separate early/late mean and stdDev |
| FR79 | Epic 49 | Discard incomplete rhythm matching on interruption |
| FR79a | Epic 49 | Return to Start Screen on foreground after backgrounding |
| FR80 | Epic 48 | Non-informative dot visualization |
| FR81 | Epic 48 | 4 dots in rhythm comparison |
| FR82 | Epic 49 | 3+1 dots with color feedback in rhythm matching |
| FR83 | Epic 48 | Asymmetric early/late difficulty adaptation |
| FR84 | Epic 50 | User-selected fixed metronome tempo |
| FR85 | Epic 50 | Minimum tempo floor ~60 BPM |
| FR86 | Epic 47 | Per-tempo stats split by early/late |
| FR87 | Epic 45 | Display rhythm accuracy as % of sixteenth note |
| FR88 | Epic 45 | Store rhythm data as BPM + signed ms offset |
| FR89 | Epic 51 | Rhythm profile card with EWMA + trend arrow |
| FR90 | Epic 51 | Spectrogram: time × tempo × color |
| FR91 | Epic 51 | Transparent cells for no-data periods |
| FR92 | Epic 51 | Tap spectrogram cell for early/late breakdown |
| FR93 | Epic 46 | Sub-millisecond note scheduling precision |
| FR94 | Epic 46 | Pre-calculated timing before playback |
| FR95 | Epic 46 | Percussion tone playback via SoundFont presets |
| FR96 | Epic 46 | Minimum audio buffer duration configuration |
| FR97 | Epic 47 | Rhythm comparison record storage |
| FR98 | Epic 47 | Rhythm matching record storage |
| FR99 | Epic 45 | Early/late derived from offset sign |
| FR100 | Epic 52 | CSV format version 2 with trainingType |
| FR101 | Epic 52 | rhythmOffsetDetection and rhythmMatching discriminators |
| FR102 | Epic 52 | V1 backward compatibility |
| FR103 | Epic 52 | Deduplication by timestamp + tempo + type |
| FR104 | Epic 50 | Six training buttons on Start Screen |

## Epic List

### Epic 1: Remember Every Note — Data Foundation
Every comparison the user answers is reliably stored and persists across sessions, crashes, and restarts — so that no training is ever lost.
**FRs covered:** FR27, FR28, FR29

### Epic 2: Hear and Compare — Core Audio Engine
Users can hear precisely generated tones with clean envelopes, enabling the fundamental listening experience.
**FRs covered:** FR16, FR17, FR18, FR19, FR20

### Epic 3: Train Your Ear — The Pitch Comparison Loop
Users can start training immediately and answer comparisons in a rapid, reflexive loop with instant feedback. This is the core product experience.
**FRs covered:** FR1, FR2, FR3, FR4, FR5, FR6, FR7, FR7a, FR8, FR42

### Epic 4: Smart Training — Adaptive Algorithm
The system intelligently selects comparisons based on the user's strengths and weaknesses, with cold start behavior for new users and continuous profile adaptation.
**FRs covered:** FR9, FR10, FR11, FR12, FR13, FR14, FR15

### Epic 5: See Your Progress — Profile & Statistics
Users can view their perceptual profile as a visualization, see summary statistics with trends, and access a profile preview from the Start Screen.
**FRs covered:** FR21, FR22, FR23, FR24, FR25, FR26

### Epic 6: Make It Yours — Settings & Configuration
Users can customize the training experience: algorithm behavior, note range, duration, reference pitch, and sound source selection.
**FRs covered:** FR30, FR31, FR32, FR33, FR34, FR35, FR36

### Epic 7: Polish & Ship — Platform, Localization & Info
Users can use the app in English or German, on iPhone and iPad, in both orientations, with accessibility support and an Info Screen.
**FRs covered:** FR37, FR38, FR39, FR40, FR41, FR43

### Epic 10: Vary Loudness Training Complication
Users can enable loudness variation in Settings so that note2 is played at a slightly different volume than note1, adding a perceptual challenge that trains the ear to distinguish pitch from loudness.
**FRs covered:** FR1 (E10), FR2 (E10), FR3 (E10), FR4 (E10), FR5 (E10)
**NFRs covered:** NFR1 (E10), NFR2 (E10)

### Epic 11: Clear the Decks — Prerequisite Renames
All MVP names that are now ambiguous with two training modes are renamed to pitch-comparison-specific names. Pure refactoring — no functional changes, all tests continue to pass.
**FRs covered:** None (refactoring only)

### Epic 12: Own Every Note — PlaybackHandle Redesign
The NotePlayer protocol is redesigned around a PlaybackHandle that represents ownership of a playing note, enabling both fixed-duration playback (comparisons) and indefinite playback with real-time frequency adjustment (pitch matching).
**FRs covered:** FR51, FR52

### Epic 13: Remember Every Match — Pitch Matching Data Layer
Pitch matching results are reliably stored alongside comparison records, extending the data foundation to support both training modes.
**FRs covered:** FR48

### Epic 14: Know Both Skills — Profile Protocol Split
The perceptual profile is split into two protocol interfaces — pitch comparison and pitch matching — so that each training mode depends only on the statistics it needs.
**FRs covered:** None (architectural refactoring enabling FR45-FR50a)

### Epic 15: Tune Your Ear — PitchMatchingSession
The pitch matching state machine orchestrates the complete training loop: reference note playback, indefinite tunable note, slider-driven frequency adjustment, result recording, and observer notification.
**FRs covered:** FR45, FR47, FR50, FR50a

### Epic 16: See and Slide — Pitch Matching Screen
Users interact with pitch matching through a custom vertical slider and receive post-release visual feedback showing their accuracy.
**FRs covered:** FR46, FR49
**NFRs covered:** NFR13

### Epic 17: Two Modes, One App — Start Screen Integration
Users can access pitch matching from the Start Screen alongside pitch comparison training, with proper navigation routing.
**FRs covered:** FR44

### Epic 18: The Full Picture — Profile Screen Integration
Users can see their pitch matching accuracy statistics alongside their pitch comparison profile on the Profile Screen.
**FRs covered:** None (extends FR21-FR26 to include matching data)

### Epic 19: Clean Foundations — Code Review Refactoring
Address all code review findings from the initial implementation: replace magic values with named constants, wrap primitives in validated Value Objects, encapsulate UserDefaults behind a protocol, extract long methods, and introduce a TrainingSession protocol.
**FRs covered:** None (refactoring only)

### Epic 20: Right Direction — Dependency Inversion Cleanup
Resolve all dependency direction violations: move shared domain types from feature modules to Core/, remove SwiftUI and UIKit imports from domain code, consolidate @Entry environment keys, inject services instead of creating them in views, and use protocols at module boundaries.
**FRs covered:** None (refactoring only)

### Epic 21: Speak the Language — Interval Domain Foundation
The system can represent musical intervals and compute precise interval frequencies using tuning systems — the domain foundation for all interval training features.
**FRs covered:** FR53, FR54, FR55
**NFRs covered:** NFR14

### Epic 22: Clean Slate — Prerequisite Refactorings
Codebase uses unified reference/target naming, domain-native Pitch type throughout NotePlayer, and decoupled sound source dependency — so that interval generalization proceeds cleanly without conflating new features with refactoring.
**FRs covered:** None (refactoring only, enables FR56–FR67)
**Depends on:** Epic 21

### Epic 23: Intervals Everywhere — Generalize Training for Intervals
Both comparison and pitch matching sessions accept interval parameters, data models record full interval context, the adaptive algorithm computes interval-aware targets, and training screens show the target interval — generalizing the training experience from unison-only to any musical interval.
**FRs covered:** FR57, FR58, FR59, FR61, FR62, FR63, FR64, FR66
**Depends on:** Epic 22

### Epic 24: Four Modes, One App — Start Screen Integration
Users see four training modes on the Start Screen and can launch interval comparison or interval pitch matching with a single tap, starting with the perfect fifth interval.
**FRs covered:** FR56, FR60, FR65, FR67
**Depends on:** Epic 23

### Epic 25: Directed Intervals — Full Interval Training
The system supports directed intervals (ascending and descending), allowing musicians to train interval recognition in both directions. Users can select which directed intervals are active for training via the Settings screen.
**FRs covered:** None (extends FR56–FR67 with directional intervals)
**Depends on:** Epic 24

### Epic 26: Pitch Matching UX Refinements
Pitch matching training UX is refined with delayed target note playback, repositioned feedback, and a tighter pitch range for more precise training.
**FRs covered:** None (UX improvement to FR45, FR46, FR49)

### Epic 27: SoundFontNotePlayer Quality
SoundFontNotePlayer's play() method is decomposed into intent-revealing sub-operations, and a stress test suite is created to hunt for preset-specific crashes.
**FRs covered:** None (code quality and reliability)

### Epic 28: Domain Foundations Audit — Adam Reviews the Music Layer
The music domain expert audits all domain types and the full NotePlayer pipeline for hidden assumptions, musical correctness, and readiness for non-12-TET tuning systems.
**FRs covered:** None (audit, enables FR55)

### Epic 29: Tuning System Landscape — Research Practical Alternatives to 12-TET
The music domain expert researches which tuning systems beyond 12-TET are used by musicians in practice, recommending the most relevant first implementation.
**FRs covered:** FR55 (research)
**Depends on:** Epic 28

### Epic 30: Implement Most Relevant Tuning System
The recommended tuning system — 5-limit just intonation — is implemented as a new TuningSystem case, with a Settings picker and a tuning system indicator on interval training screens.
**FRs covered:** FR55
**Depends on:** Epic 29

### Epic 31: Structured Notes — NoteRange Refactoring
Replace scattered `noteRangeMin`/`noteRangeMax` pairs with a domain-wide `NoteRange` value type that validates its own constraints and is reused across settings, training sessions, strategy, and profile visualization.
**FRs covered:** None (refactoring only, improves FR31 implementation)

### Epic 32: Everything in Its Place — Settings Screen Reorganization
Settings are grouped logically and ordered for intuitive discoverability, preparing a clean home for new features like export and import.
**FRs covered:** None (UX improvement)

### Epic 33: Take Your Data — Training Data Export
Users can export all training data as a single CSV file for analysis in spreadsheet applications, with a format designed for extensibility as new training types are added.
**FRs covered:** None (new feature, not in original PRD)

### Epic 34: Bring Your Data — Training Data Import
Users can import training data from CSV with the choice to replace all existing data or merge with duplicate detection.
**FRs covered:** None (new feature, not in original PRD)
**Depends on:** Epic 33

### Epic 35: Welcome Home — Start Screen Redesign
The Start Screen greets users with approachable training names, suitable icons, and a more inviting visual design.
**FRs covered:** None (UX improvement to FR65)

### Epic 36: Speak Clearly — Localization & Wording Polish
All German translations and English wordings are reviewed and improved through interactive dialog, ensuring the app communicates clearly and naturally in both languages.
**FRs covered:** FR37 (improvement)
**Depends on:** Epic 32, Epic 35

### Epic 37: Show Me How — Built-in Help
Users can access contextual help on the Start Screen, Settings Screen, and Training Screens to understand what the app does, what each setting controls, and how to interact with training.
**FRs covered:** None (new feature, not in original PRD)
**Depends on:** Epic 32, Epic 35

### Epic 38: See Your Strengths — Perceptual Profile Visualization ✅ Done
Users see a useful and easily understandable visualization of their perceptual profile that encourages them by showing progress and highlights weak spots where further training would give the most improvement.
**FRs covered:** FR21 (redesign/enhancement)

### Epic 43: Share Your Progress — Sharing
Users can share training data via the system share sheet (replacing the file exporter) and share individual progress chart images from the Profile Screen.
**FRs covered:** None (new feature, replaces Epic 33 export UI approach)
**Depends on:** Epic 33, Epic 41

### Epic 44: Solid Ground — Prerequisite Refactorings
Move domain value types from Core/Audio/ to Core/Music/ and clean up PerceptualProfile — removing stale tracking, normalizing naming, preparing for multi-mode extension. Pure refactoring with no functional changes, preparing the codebase for rhythm extension.
**FRs covered:** None directly (architecture prerequisite A + B)

### Epic 45: Rhythm Domain — Types and Contracts
Introduce TempoBPM, RhythmOffset, RhythmDirection domain types with full test coverage. Define the observer protocols (RhythmOffsetDetectionObserver, RhythmMatchingObserver) and completed-result value types. Define the RhythmProfile protocol.
**FRs covered:** FR87, FR88, FR99

### Epic 46: One Engine — Audio Architecture Redesign
Extract SoundFontEngine from SoundFontNotePlayer, refactor NotePlayer to delegate, then build RhythmPlayer protocol and SoundFontRhythmPlayer with sample-accurate render-thread scheduling. Includes an on-device POC — a temporary demo screen that plays a pre-computed rhythm pattern at a fixed tempo, proving that the three-layer audio architecture delivers audibly tight timing on real hardware. The POC is removed once rhythm training screens are in place.
**FRs covered:** FR93, FR94, FR95, FR96
**NFRs covered:** NFR-R1, NFR-R2, NFR-R3

### Epic 47: Remember Every Beat — Rhythm Data Layer
RhythmOffsetDetectionRecord and RhythmMatchingRecord SwiftData models, TrainingDataStore extension with rhythm CRUD and observer conformances, PerceptualProfile RhythmProfile conformance, ProgressTimeline extension to 6 modes.
**FRs covered:** FR86, FR97, FR98

### Epic 48: Four Clicks — Rhythm Comparison Training
Full rhythm comparison training: session state machine, adaptive difficulty strategy with asymmetric early/late tracking, screen with dot visualization, Early/Late buttons, feedback line, and haptics. Users can start rhythm comparison from the Start Screen and train their timing detection.
**FRs covered:** FR68, FR69, FR70, FR71, FR72, FR73, FR73a, FR80, FR81, FR83
**UX-DRs covered:** UX-DR1, UX-DR2, UX-DR8, UX-DR9, UX-DR12

### Epic 49: Hit That Beat — Rhythm Matching Training
Full rhythm matching training: session state machine, screen with dot visualization (3+1 with color feedback), tap button, signed deviation feedback. Users can start rhythm matching from the Start Screen and train their timing production.
**FRs covered:** FR74, FR75, FR76, FR77, FR78, FR79, FR79a, FR82
**UX-DRs covered:** UX-DR1, UX-DR3, UX-DR8, UX-DR10, UX-DR13

### Epic 50: Six Modes, One App — Start Screen & Settings
6-button Start Screen layout with section labels (Pitch/Intervals/Rhythm), NavigationDestination updates, tempo stepper in Settings (40–200 BPM). Portrait vertical stack with landscape 3-column grid.
**FRs covered:** FR84, FR85, FR104
**UX-DRs covered:** UX-DR6, UX-DR7, UX-DR14

### Epic 51: See Your Rhythm — Profile Visualization
RhythmSpectrogramView with color-coded tempo × time grid, RhythmProfileCardView with EWMA headline + trend arrow, Profile Screen integration, tap-to-detail, empty states, VoiceOver per-column summaries.
**FRs covered:** FR89, FR90, FR91, FR92
**UX-DRs covered:** UX-DR4, UX-DR5, UX-DR11

### Epic 52: Version Your Exports — CSV Format v2
CSVImportParserV2 and CSVExportSchemaV2 extending the chain-of-responsibility pattern. Exporter/importer updates for rhythm records. V1 backward compatibility preserved. Deduplication by timestamp + tempo + training type.
**FRs covered:** FR100, FR101, FR102, FR103

### Epic 53: Rhythm in Every Language — Localization
English + German UI strings for all rhythm training screens, Start Screen section labels, Settings tempo section, Profile rhythm cards, feedback text, and spectrogram accessibility descriptions.
**FRs covered:** None directly (cross-cutting)

### Epic 54: Fill the Gap — Continuous Rhythm Matching
Continuous step-sequencer-style rhythm matching training, built as a new training discipline alongside the existing rhythm matching mode (Epic 49). A looping 4-step cycle of 16th notes plays at the user's tempo with beat-1 accent. One step per cycle is a silent gap — the user fills it by tapping at the right moment. Gap positions are configurable in settings; when multiple are enabled, each cycle randomly selects one. Taps are silently evaluated against a timing window around the gap. A trial aggregates 16 consecutive cycles into a single statistical unit; incomplete trials are discarded on exit.
**FRs covered:** FR105, FR106, FR107, FR108, FR109, FR110, FR111, FR112, FR113
**Depends on:** Epic 48 (reuses audio infrastructure), Epic 50 (Start Screen extension)

## Epic 1: Remember Every Note — Data Foundation

Every comparison the user answers is reliably stored and persists across sessions, crashes, and restarts — so that no training is ever lost. This includes establishing the Xcode project and folder structure as the implementation foundation.

### Story 1.1: Create Xcode Project and Folder Structure

As a **developer**,
I want a properly configured Xcode project with the defined folder structure and test target,
So that all subsequent development has a consistent, organized foundation.

**Acceptance Criteria:**

**Given** no existing Xcode project
**When** the project is created
**Then** it uses Xcode 26.3 iOS App template with SwiftUI lifecycle, Swift language, and SwiftData storage
**And** the deployment target is iOS 26
**And** the folder structure matches the architecture document (App/, Core/Audio/, Core/Algorithm/, Core/Data/, Core/Profile/, Training/, Profile/, Settings/, Start/, Info/, Resources/)
**And** a PeachTests/ test target exists mirroring the source structure
**And** Swift Testing framework is configured for the test target
**And** the project builds and runs successfully on the simulator

### Story 1.2: Implement PitchDiscriminationRecord Data Model and TrainingDataStore

As a **developer**,
I want a persisted data model for comparison records with a store that supports create and read operations,
So that training results can be reliably stored and retrieved.

**Acceptance Criteria:**

**Given** the Xcode project from Story 1.1
**When** a PitchDiscriminationRecord is created
**Then** it contains fields: note1 (MIDI note), note2 (MIDI note), note2CentOffset, isCorrect (Bool), timestamp (Date)
**And** it is a SwiftData @Model

**Given** a TrainingDataStore instance
**When** a comparison record is saved
**Then** the record persists across app restarts
**And** the write is atomic — no partial records are stored

**Given** a TrainingDataStore with stored records
**When** all records are fetched
**Then** every previously stored record is returned with all fields intact
**And** records survive app crashes, force quits, and unexpected termination

**Given** the TrainingDataStore
**When** unit tests are run using Swift Testing (@Test, #expect())
**Then** all CRUD operations are verified
**And** a typed DataStoreError enum exists for error cases

## Epic 2: Hear and Compare — Core Audio Engine

Users can hear precisely generated tones with clean envelopes, enabling the fundamental listening experience.

### Story 2.1: Implement NotePlayer Protocol and SineWaveNotePlayer

As a **musician using Peach**,
I want to hear clean, precisely tuned sine wave tones,
So that I can train my pitch comparison with accurate audio.

**Acceptance Criteria:**

**Given** a NotePlayer protocol
**When** it is defined
**Then** it exposes a method to play a note at a given frequency with a specified duration and envelope
**And** it exposes a method to stop playback

**Given** a SineWaveNotePlayer (implementing NotePlayer)
**When** a note is played at a target frequency
**Then** the generated tone is accurate to within 0.1 cent of the target frequency
**And** audio latency from trigger to audible output is < 10ms
**And** the implementation uses AVAudioEngine + AVAudioSourceNode

**Given** a SineWaveNotePlayer
**When** a note is played
**Then** it has a smooth attack/release envelope with no audible clicks or artifacts

**Given** two notes played in sequence
**When** both are rendered
**Then** they use the same timbre (sine wave)

**Given** the SineWaveNotePlayer
**When** unit tests are run
**Then** frequency generation accuracy is verified
**And** a typed AudioError enum exists for error cases (e.g., AudioError.engineStartFailed)

### Story 2.2: Support Configurable Note Duration and Reference Pitch

As a **musician using Peach**,
I want notes to play at a configurable duration and tuning standard,
So that the training experience matches my preferences.

**Acceptance Criteria:**

**Given** a NotePlayer
**When** a note duration is specified
**Then** the note plays for exactly that duration (with envelope attack/release within the duration)

**Given** a default configuration
**When** no reference pitch is set
**Then** frequencies are derived from A4 = 440Hz

**Given** a configurable reference pitch
**When** a different reference pitch value is provided (e.g., A4 = 442Hz)
**Then** all generated frequencies are derived from the new reference pitch

**Given** a MIDI note number and a cent offset
**When** a frequency is calculated
**Then** the frequency is mathematically derived from the reference pitch using standard equal temperament with the cent offset applied
**And** fractional cent precision (0.1 cent resolution) is supported

## Epic 3: Train Your Ear — The Pitch Comparison Loop

Users can start training immediately and answer comparisons in a rapid, reflexive loop with instant feedback. This is the core product experience.

### Story 3.1: Start Screen and Navigation Shell

As a **musician using Peach**,
I want to see a Start Screen when I open the app with a prominent Start Training button,
So that I can begin training immediately with a single tap.

**Acceptance Criteria:**

**Given** the app is launched
**When** the Start Screen appears
**Then** it displays a prominent Start Training button (`.borderedProminent`)
**And** it displays navigation buttons for Settings, Profile, and Info (icon-only, SF Symbols)
**And** it displays a placeholder area for the Profile Preview (to be implemented in Epic 5)
**And** the Start Screen is interactive within 2 seconds of app launch

**Given** the Start Screen
**When** the user taps Start Training
**Then** the Training Screen is presented via NavigationStack

**Given** the Start Screen
**When** the user taps Settings, Profile, or Info
**Then** the corresponding screen is navigated to (placeholder screens for now)
**And** each returns to the Start Screen when dismissed

**Given** the navigation structure
**When** any secondary screen is dismissed
**Then** the user always returns to the Start Screen (hub-and-spoke)

### Story 3.2: TrainingSession State Machine and Pitch Comparison Loop

As a **musician using Peach**,
I want to hear two notes in sequence and answer whether the second was higher or lower,
So that I can train my pitch comparison through rapid comparisons.

**Acceptance Criteria:**

**Given** a TrainingSession (@Observable)
**When** it is initialized
**Then** it coordinates NotePlayer, TrainingDataStore, and a comparison source (using random comparisons at 100 cents as a temporary placeholder until Epic 4)
**And** it progresses through states: idle → playingNote1 → playingNote2 → awaitingAnswer → showingFeedback → loop

**Given** the Training Screen is displayed
**When** training starts
**Then** the first comparison begins immediately — no countdown, no transition animation
**And** the first note plays, followed by the second note

**Given** the user answers a comparison
**When** the answer is recorded
**Then** the result is written to TrainingDataStore
**And** the next comparison begins immediately with no perceptible delay

**Given** the TrainingSession
**When** a service error occurs (audio failure, data write failure)
**Then** the TrainingSession handles it gracefully — the user never sees an error screen
**And** audio failure stops training silently
**And** data write failure logs internally but training continues

**Given** the TrainingSession
**When** unit tests are run
**Then** all state transitions are verified using mock protocol implementations

### Story 3.3: Training Screen UI with Higher/Lower Buttons and Feedback

As a **musician using Peach**,
I want large, thumb-friendly Higher/Lower buttons with immediate visual and haptic feedback,
So that I can train reflexively, even one-handed and with eyes closed.

**Acceptance Criteria:**

**Given** the Training Screen
**When** it is displayed
**Then** it shows Higher and Lower buttons that are large, thumb-friendly, and exceed 44x44pt minimum tap targets
**And** it shows Settings and Profile navigation buttons (visually subordinate to Higher/Lower)
**And** it uses stock SwiftUI components with no custom styles

**Given** the first note is playing
**When** the user looks at the Higher/Lower buttons
**Then** they are disabled (stock SwiftUI `.disabled()` appearance)

**Given** the second note begins playing
**When** the buttons become enabled
**Then** the user can tap Higher or Lower at any point during or after the second note

**Given** the user taps Higher or Lower
**When** the answer is submitted
**Then** both buttons disable immediately to prevent double-tap
**And** a Feedback Indicator appears: thumbs up (SF Symbol, system green) for correct, thumbs down (SF Symbol, system red) for incorrect
**And** if incorrect, a single haptic tick fires simultaneously (`UIImpactFeedbackGenerator`)
**And** if correct, no haptic (silence = confirmation)
**And** the Feedback Indicator displays for ~300-500ms then clears
**And** the next comparison begins

### Story 3.4: Training Interruption and App Lifecycle Handling

As a **musician using Peach**,
I want training to stop cleanly when I navigate away or leave the app,
So that no data is lost and I return to the Start Screen seamlessly.

**Acceptance Criteria:**

**Given** training is in progress
**When** the user taps Settings or Profile on the Training Screen
**Then** training stops immediately
**And** any incomplete comparison is silently discarded
**And** the user navigates to the selected screen
**And** that screen returns to the Start Screen when dismissed

**Given** training is in progress
**When** the app is backgrounded (home button, app switcher, phone call, headphone disconnect)
**Then** training stops and the incomplete comparison is discarded

**Given** the app was backgrounded during training
**When** the app is foregrounded
**Then** the user is returned to the Start Screen (not the Training Screen)

**Given** training is in the showingFeedback state
**When** the app is backgrounded
**Then** the already-answered comparison was already saved — no data loss

## Epic 4: Smart Training — Adaptive Algorithm

The system intelligently selects comparisons based on the user's strengths and weaknesses, with cold start behavior for new users and continuous profile adaptation.

### Story 4.1: Implement PerceptualProfile

As a **musician using Peach**,
I want the app to build and maintain an accurate map of my pitch comparison ability,
So that training targets my actual weaknesses.

**Acceptance Criteria:**

**Given** a PerceptualProfile
**When** it is initialized
**Then** it holds aggregate statistics (arithmetic mean, standard deviation of detection thresholds) indexed by MIDI note (0–127)

**Given** a TrainingDataStore with existing comparison records
**When** the app starts
**Then** the PerceptualProfile is loaded by aggregating all stored records into per-note statistics

**Given** a new comparison result is recorded during training
**When** the PerceptualProfile is updated
**Then** it updates incrementally (not by re-aggregating all records)

**Given** a PerceptualProfile
**When** queried for weak spots
**Then** it identifies notes with the largest detection thresholds (poorest pitch comparison)

**Given** the PerceptualProfile
**When** no data exists for a MIDI note
**Then** that note is treated as a weak spot (cold start assumption)

**Given** the PerceptualProfile
**When** unit tests are run
**Then** aggregation, incremental update, and weak spot identification are verified

### Story 4.2: Implement NextNoteStrategy Protocol and AdaptiveNoteStrategy

As a **musician using Peach**,
I want the app to intelligently choose which comparisons to present,
So that every comparison maximally improves my pitch comparison.

**Acceptance Criteria:**

**Given** a NextNoteStrategy protocol
**When** it is defined
**Then** it exposes a method that takes the PerceptualProfile and current settings and returns a PitchDiscriminationTrial (note1, note2, centDifference)

**Given** an AdaptiveNoteStrategy (implementing NextNoteStrategy)
**When** the user answers correctly
**Then** the next comparison at that note uses a narrower cent difference (harder)

**Given** an AdaptiveNoteStrategy
**When** the user answers incorrectly
**Then** the next comparison at that note uses a wider cent difference (easier)

**Given** an AdaptiveNoteStrategy
**When** selecting the next comparison
**Then** it balances between training nearby the current pitch region and jumping to weak spots, controlled by a tunable ratio (Natural vs. Mechanical)

**Given** a new user with no training history
**When** comparisons are generated
**Then** they use random note selection at 100 cents (1 semitone) with all notes treated as weak (cold start)

**Given** the AdaptiveNoteStrategy
**When** cent differences are computed
**Then** fractional cent precision (0.1 cent resolution) is supported with a practical floor of approximately 1 cent

**Given** the AdaptiveNoteStrategy
**When** unit tests are run
**Then** difficulty adjustment, weak spot targeting, cold start behavior, and Natural/Mechanical balance are verified

### Story 4.3: Integrate Adaptive Algorithm into TrainingSession

As a **musician using Peach**,
I want the training loop to use the adaptive algorithm instead of random comparisons,
So that my training is personalized and my profile persists across sessions.

**Acceptance Criteria:**

**Given** the TrainingSession from Epic 3
**When** it is updated
**Then** it uses AdaptiveNoteStrategy (via NextNoteStrategy protocol) instead of the temporary random placeholder

**Given** the app is launched with existing training data
**When** training starts
**Then** the PerceptualProfile is loaded from stored data and the algorithm continues from the user's last known state

**Given** a training session
**When** comparisons are answered
**Then** the PerceptualProfile is updated incrementally after each answer
**And** the next comparison reflects the updated profile

**Given** algorithm parameters
**When** development/testing is in progress
**Then** all algorithm parameters are exposed and adjustable for tuning and discovery

**Given** the integration
**When** unit tests are run
**Then** end-to-end flow from profile loading → comparison selection → answer recording → profile update is verified with mocks

## Epic 5: See Your Progress — Profile & Statistics

Users can view their perceptual profile as a visualization, see summary statistics with trends, and access a profile preview from the Start Screen.

### Story 5.1: Profile Screen with Perceptual Profile Visualization

As a **musician using Peach**,
I want to see my pitch comparison ability visualized as a confidence band over a piano keyboard,
So that I can understand where my hearing is strong and where it needs work.

**Acceptance Criteria:**

**Given** the Profile Screen
**When** it is displayed with training data
**Then** it shows a piano keyboard along the X-axis spanning the training range with note names at octave boundaries (C2, C3, C4, etc.)
**And** a confidence band (filled area chart) overlaid above the keyboard showing detection thresholds per note
**And** the band's width represents uncertainty — wider where data is sparse, narrower where many comparisons exist
**And** the Y-axis is inverted so improvement (smaller cent differences) moves the band downward toward the keyboard
**And** it uses system semantic colors (system blue/tint for band fill, opacity for confidence range)
**And** it renders within 1 second including computation

**Given** the Profile Screen
**When** there is no training data (cold start)
**Then** the piano keyboard renders fully
**And** the confidence band is absent or shown as a faint uniform placeholder at the 100-cent level
**And** text "Start training to build your profile" appears centered above the keyboard

**Given** the Profile Screen with sparse data
**When** only some notes have been trained
**Then** the confidence band renders where data exists and fades out where it doesn't
**And** no interpolation across large data gaps

**Given** the profile visualization
**When** VoiceOver is active
**Then** it provides an aggregate summary: "Perceptual profile showing detection thresholds from [lowest note] to [highest note]. Average threshold: [X] cents."

**Given** the profile visualization
**When** rendered in dark mode
**Then** it uses system semantic colors and maintains sufficient contrast

### Story 5.2: Summary Statistics with Trend Indicator

As a **musician using Peach**,
I want to see my mean detection threshold, standard deviation, and whether I'm improving,
So that I have factual confirmation that training is working.

**Acceptance Criteria:**

**Given** the Profile Screen with training data
**When** summary statistics are displayed
**Then** they show the arithmetic mean of detectable cent differences over the current training range
**And** the standard deviation of detectable cent differences
**And** a trend indicator (improving/stable/declining) presented as an understated directional signal

**Given** the Profile Screen with no training data (cold start)
**When** summary statistics are displayed
**Then** dashes or "—" appear instead of numbers
**And** the trend indicator is hidden

**Given** the PerceptualProfile
**When** summary statistics are computed
**Then** they are derived from stored per-answer data (FR26)

### Story 5.3: Profile Preview on Start Screen and Navigation

As a **musician using Peach**,
I want to see a miniature of my pitch profile on the Start Screen that I can tap to see details,
So that I can glance at my progress without navigating away.

**Acceptance Criteria:**

**Given** the Start Screen
**When** it is displayed
**Then** a Profile Preview is shown — a compact, simplified version of the full profile visualization (same confidence band shape, no axis labels, no note names, no numerical values)
**And** it is sized appropriately as a secondary element (~full width, ~60-80pt tall)

**Given** the Profile Preview
**When** the user taps it
**Then** it navigates to the full Profile Screen

**Given** the Profile Preview with no training data
**When** displayed on the Start Screen
**Then** it shows a placeholder shape that looks intentional, not broken

**Given** the Profile Preview
**When** VoiceOver is active
**Then** it announces "Your pitch profile. Tap to view details." (or with threshold data if available)

**Given** the Profile Screen
**When** dismissed (back navigation or swipe)
**Then** the user returns to the Start Screen

**Given** the Profile Preview rendering
**When** compared to the full visualization
**Then** it shares the same rendering logic, scaled down and stripped of labels (single implementation)

## Epic 6: Make It Yours — Settings & Configuration

Users can customize the training experience: algorithm behavior, note range, duration, reference pitch, and sound source selection.

### Story 6.1: Settings Screen with All Configuration Options

As a **musician using Peach**,
I want to customize algorithm behavior, note range, note duration, reference pitch, and sound source,
So that the training experience matches my preferences and musical context.

**Acceptance Criteria:**

**Given** the Settings Screen
**When** it is displayed
**Then** it shows the following controls in a stock SwiftUI Form with logical section grouping:
- Natural vs. Mechanical slider (`Slider`)
- Note range lower bound (`Picker` or `Stepper`)
- Note range upper bound (`Picker` or `Stepper`)
- Note duration (`Stepper` or `Slider`)
- Reference pitch (`Stepper`, default A4 = 440Hz)
- Sound source selection (`Picker`, MVP: sine wave only)

**Given** the user changes any setting
**When** the value is adjusted
**Then** it is persisted immediately via `@AppStorage` — no save/cancel buttons

**Given** settings controls
**When** interacted with
**Then** all controls are bounded (sliders have min/max, steppers have ranges) — no form validation needed

**Given** the Settings Screen
**When** dismissed (back navigation or swipe)
**Then** the user returns to the Start Screen

**Given** the Settings Screen
**When** accessed from the Training Screen
**Then** training stops, the Settings Screen is shown, and dismissal returns to the Start Screen

### Story 6.2: Apply Settings to Training in Real Time

As a **musician using Peach**,
I want my setting changes to take effect immediately on the next comparison,
So that I can feel the difference and find my preferred configuration.

**Acceptance Criteria:**

**Given** the user has changed the Natural vs. Mechanical slider
**When** the next comparison is selected
**Then** the AdaptiveNoteStrategy uses the updated balance ratio

**Given** the user has changed the note range bounds
**When** the next comparison is selected
**Then** the AdaptiveNoteStrategy only selects notes within the new range

**Given** the user has changed the note duration
**When** the next note is played
**Then** the NotePlayer uses the updated duration

**Given** the user has changed the reference pitch
**When** the next note is played
**Then** frequencies are derived from the new reference pitch

**Given** settings are persisted
**When** the app is restarted
**Then** all settings retain their last configured values
**And** training uses the persisted settings

**Given** the settings integration
**When** unit tests are run
**Then** the flow from settings change → TrainingSession reading updated values → effect on next comparison/note is verified

## Epic 7: Polish & Ship — Platform, Localization & Info

Users can use the app in English or German, on iPhone and iPad, in both orientations, with accessibility support and an Info Screen.

### Story 7.1: English and German Localization

As a **musician using Peach**,
I want to use the app in English or German,
So that the interface is in my preferred language.

**Acceptance Criteria:**

**Given** all user-facing strings in the app
**When** localization is applied
**Then** every string is externalized to String Catalogs (Localizable.xcstrings)
**And** English and German translations are provided for all strings

**Given** the device language is set to German
**When** the app is launched
**Then** all UI text appears in German

**Given** the device language is set to English (or any unsupported language)
**When** the app is launched
**Then** all UI text appears in English (default)

**Given** custom components (profile visualization, profile preview, feedback indicator)
**When** they display text (e.g., "Start training to build your profile", statistics labels)
**Then** that text is also localized

### Story 7.2: Accessibility Audit and Custom Component Labels

As a **musician using Peach**,
I want all screens to be fully accessible with VoiceOver, Dynamic Type, and sufficient contrast,
So that the app is usable with assistive technology.

**Acceptance Criteria:**

**Given** all stock SwiftUI components
**When** VoiceOver is active
**Then** they are automatically labeled and navigable (no additional work needed)

**Given** custom components (profile visualization, profile preview, feedback indicator)
**When** VoiceOver is active
**Then** the profile visualization announces an aggregate summary of detection thresholds
**And** the profile preview announces "Your pitch profile. Tap to view details." (with threshold data if available)
**And** the feedback indicator announces "Correct" or "Incorrect"

**Given** all text in the app
**When** Dynamic Type is set to the largest accessibility size
**Then** text scales correctly and layout does not break

**Given** all UI elements
**When** tested for color contrast
**Then** system semantic colors provide sufficient contrast in both light and dark mode

**Given** the Training Screen
**When** tested with eyes closed
**Then** the audio-haptic loop works without visual feedback — a complete training session can be performed

**Given** system settings
**When** Reduce Motion is enabled
**Then** any transitions (feedback indicator appearance/disappearance) respect the setting

### Story 7.3: iPhone, iPad, Portrait, and Landscape Support

As a **musician using Peach**,
I want to use the app on my iPhone or iPad in any orientation,
So that training works on whatever device I have at hand.

**Acceptance Criteria:**

**Given** the app running on iPhone
**When** displayed in portrait
**Then** all screens render correctly with Training Screen buttons optimized for one-handed thumb reach

**Given** the app running on iPhone
**When** rotated to landscape
**Then** all screens adapt via SwiftUI automatic layout
**And** Training Screen buttons reflow to a horizontal arrangement

**Given** the app running on iPad
**When** displayed in any orientation
**Then** layouts scale naturally — no iPad-specific layouts or split views

**Given** the app running on iPad
**When** used in windowed/compact mode
**Then** layouts compress gracefully, the same way they do on smaller iPhones

**Given** all screens
**When** tested on iPhone 17 Pro
**Then** layouts are functional and visually appropriate

### Story 7.4: Info Screen

As a **musician using Peach**,
I want to view basic information about the app,
So that I know the version and who made it.

**Acceptance Criteria:**

**Given** the Start Screen
**When** the user taps the Info button (`info.circle` SF Symbol)
**Then** an Info Screen is presented as a `.sheet()`

**Given** the Info Screen
**When** displayed
**Then** it shows the app name (Peach), developer name, copyright notice, and app version number (pulled from bundle)
**And** it uses stock SwiftUI layout with minimal content

**Given** the Info Screen
**When** dismissed (swipe down or tap dismiss)
**Then** the user returns to the Start Screen

**Given** the Info Screen text
**When** localization is active
**Then** static labels are localized (app name and developer name remain as-is)

### Story 7.5: App Icon Design and Implementation

As a **musician using Peach**,
I want the app to have a distinctive icon that reflects its purpose,
So that I can easily identify it on my home screen and it communicates the app's focus on pitch training.

**Acceptance Criteria:**

**Given** the app icon design requirements
**When** creating the icon
**Then** it incorporates a peach as the primary visual element (leveraging the "Peach"/"pitch" homophone)
**And** it includes a musical element (such as a sound wave, musical note, or frequency visualization) integrated with the peach
**And** the design works at all required iOS icon sizes (from 20pt to 1024pt)
**And** it follows Apple's iOS icon design guidelines (no transparency, rounded square filled edge-to-edge)

**Given** the icon design concept
**When** selecting visual style
**Then** it uses a simple, bold design that remains recognizable at small sizes (20pt-40pt on home screen)
**And** it uses colors that stand out on iOS home screens (warm peach/orange tones with contrasting accent)

**Given** the final icon assets
**When** added to the Xcode project
**Then** all required icon sizes are provided in Assets.xcassets/AppIcon
**And** the icon appears correctly on the home screen, in Settings, in Spotlight search, and in the App Store

**Given** the icon on a user's home screen
**When** viewed alongside other music/education apps
**Then** it is visually distinctive and clearly communicates "pitch training" through the peach/pitch wordplay

**Design Notes:**

**Concept Directions to Explore:**
1. **Peach + Waveform:** A stylized peach with a sound wave or frequency curve flowing through it or emerging from it
2. **Peach + Musical Staff:** A peach positioned on or integrated with a musical staff line, suggesting both fruit and pitch
3. **Peach + Tuning Fork:** A tuning fork incorporated into the peach's stem or leaf, directly referencing pitch
4. **Abstract Peach-Pitch:** Geometric/modern interpretation combining circular peach form with wave patterns

**Color Palette:**
- Primary: Warm peach/orange (#FF9966 to #FFCC99 range)
- Accent: Teal or deep green for musical elements (sound waves, stems)
- Background: Complementary gradient or solid color for depth

**Technical Requirements:**
- Provide 1024x1024px master artwork
- Export all iOS icon sizes via Xcode or icon generator
- Ensure legibility at 40x40px (smallest common home screen size)
- Test on both light and dark home screen wallpapers

**Implementation:**
- Create icon assets (design tool: Figma, Sketch, or SF Symbols + image editing)
- Add to `Peach/Resources/Assets.xcassets/AppIcon.appiconset/`
- Verify in Xcode that all sizes are properly assigned
- Test on device at various home screen densities

## Epic 9: Evidence-Based Training — Note Selection Strategy

Replace the default training strategy with a simpler, research-backed approach. Perceptual learning research shows that pitch comparison is essentially one unified skill with a roughly uniform threshold across the frequency range. The complex per-note weak spot targeting and natural-vs-mechanical balance in AdaptiveNoteStrategy adds no value and produces annoying difficulty jumps when changing notes. The simpler KazezNoteStrategy — continuous difficulty chain with frequency roving — is both more scientifically sound and more pleasant to use.

See brainstorming session: `docs/brainstorming/brainstorming-session-2026-02-24.md`

### Story 9.1: Promote KazezNoteStrategy to Default Training Strategy

As a **musician using Peach**,
I want the training algorithm to maintain a smooth, continuous difficulty progression regardless of which note is playing,
So that I experience steady convergence to my threshold without jarring difficulty jumps when the note changes.

**Acceptance Criteria:**

**Given** KazezNoteStrategy is the active training strategy
**When** a note is selected for a comparison
**Then** the note is selected randomly within `settings.noteRangeMin...settings.noteRangeMax`

**Given** KazezNoteStrategy with a `lastPitchDiscriminationTrial` available
**When** the next comparison's difficulty is determined
**Then** it uses the Kazez chain from `lastPitchDiscriminationTrial.centDifference` (narrowing on correct, widening on incorrect)
**And** the difficulty never jumps due to a note change

**Given** KazezNoteStrategy with no `lastPitchDiscriminationTrial` (cold start)
**When** the first comparison's difficulty is determined
**Then** it uses `profile.overallMean` if sufficient data exists (sampleCount > 0 for at least one note)
**And** falls back to `settings.maxCentDifference` if no profile data exists

**Given** the app is launched
**When** `PeachApp` creates the training session
**Then** it uses `KazezNoteStrategy` as the default `NextNoteStrategy`
**And** `AdaptiveNoteStrategy` remains in the codebase for potential future use

**Given** the Settings Screen
**When** displayed
**Then** the "Natural vs. Mechanical" slider is removed (it only applies to AdaptiveNoteStrategy)

**Given** the `naturalVsMechanical` property on `TrainingSettings`
**When** this story is complete
**Then** the property remains in `TrainingSettings` (it's still used by `AdaptiveNoteStrategy`)
**But** it is no longer read from `@AppStorage` or displayed in Settings UI

**Given** the full test suite
**When** all tests are run
**Then** all existing tests pass (KazezNoteStrategy tests updated for new behavior, AdaptiveNoteStrategy tests unchanged)
**And** new tests verify the cold-start-from-profile behavior

### Story 9.2: Rethink Profile Display and Progress Tracking

_Placeholder — to be detailed after story 9.1 is implemented._

As a **musician using Peach**,
I want the profile visualization and statistics to reflect that pitch comparison is one skill, not many separate per-note skills,
So that my progress display is meaningful and accurate.

**Notes for future design:**
- Current per-note profile visualization may be misleading if thresholds are uniform
- Session-level threshold convergence may be more meaningful than per-note maps
- Consider showing session history, trend over time, best/average thresholds
- The PerceptualProfile data model still collects per-note data (for future analysis), but display should focus on overall ability

## Epic 10: Vary Loudness Training Complication

Users can enable loudness variation in Settings so that note2 is played at a slightly different volume than note1, adding a perceptual challenge that trains the ear to distinguish pitch from loudness. This requires first correcting the existing audio parameter semantics (renaming amplitude to velocity) and researching independent volume control.

**FRs covered:** FR1, FR2, FR3, FR4, FR5
**NFRs covered:** NFR1, NFR2

- **FR1:** Developer can understand how to control sound volume (dB) independently of MIDI velocity in SoundFontNotePlayer using AVAudioUnitSampler / AVAudioEngine
- **FR2:** System uses "velocity" (MIDI 0-127) instead of "amplitude" (0.0-1.0) throughout NotePlayer protocol, SoundFontNotePlayer, TrainingSession, and all tests — the current "amplitude" parameter is renamed and retyped to reflect what it actually controls
- **FR3:** NotePlayer.play accepts an amplitude parameter that controls sound volume independently of velocity
- **FR4:** User can adjust a "Vary Loudness" slider in Settings
- **FR5:** TrainingSession applies a random loudness offset to note2 relative to note1, drawn from a range of ±(sliderValue × maxOffset) dB, where sliderValue is the "Vary Loudness" setting normalized to 0.0–1.0 and maxOffset is a tunable constant (initially 2 dB)
- **NFR1:** The velocity-to-amplitude refactoring must not change any audible behavior — pure rename/retype, verified by existing tests passing
- **NFR2:** The "Vary Loudness" setting must be localized in English and German

### Story 10.1: Research Volume Control in AVAudioUnitSampler

As a **developer**,
I want to understand how to control sound volume (dB) independently of MIDI velocity in AVAudioUnitSampler / AVAudioEngine,
So that I can make informed implementation decisions for the amplitude parameter in subsequent stories.

**Acceptance Criteria:**

**Given** the current SoundFontNotePlayer uses AVAudioUnitSampler with MIDI velocity to control note intensity
**When** the developer researches AVAudioEngine's audio graph capabilities
**Then** a short findings document is produced that answers:
- Can sound volume be controlled independently of MIDI velocity? If so, through what mechanism (e.g., node volume, mixer gain, AVAudioUnitSampler properties)?
- What unit does the mechanism use (linear 0.0–1.0, dB, other)?
- How to convert between dB offsets and the native unit?
- Are there any gotchas (e.g., clipping, latency, per-note vs. global volume)?

**And** the findings document is saved to `docs/implementation-artifacts/` for reference during implementation of stories 10.3–10.5

### Story 10.2: Rename Amplitude to Velocity

As a **developer**,
I want the existing "amplitude" parameter renamed to "velocity" with proper MIDI velocity typing (UInt8, 0–127) throughout the codebase,
So that the audio API correctly reflects what it actually controls and makes room for a true amplitude (loudness) parameter.

**Acceptance Criteria:**

**Given** the `NotePlayer` protocol declares `play(frequency:duration:amplitude:)` with amplitude as `Double` (0.0–1.0)
**When** the refactoring is applied
**Then** the protocol signature becomes `play(frequency:duration:velocity:)` with velocity as `UInt8` (0–127)

**Given** `SoundFontNotePlayer` contains a `midiVelocity(forAmplitude:)` conversion helper
**When** the refactoring is applied
**Then** the helper is removed and velocity is passed directly to `sampler.startNote(_:withVelocity:onChannel:)`

**Given** `SoundFontNotePlayer` validates amplitude in the range 0.0–1.0 and throws `AudioError.invalidAmplitude`
**When** the refactoring is applied
**Then** validation checks velocity in the range 0–127 and the error case is renamed to `AudioError.invalidVelocity`

**Given** `TrainingSession` holds a private constant `amplitude: Double = 0.5`
**When** the refactoring is applied
**Then** it holds a velocity constant of type `UInt8` with the equivalent MIDI value (63)

**Given** `MockNotePlayer` tracks `lastAmplitude` and `playHistory` with amplitude fields
**When** the refactoring is applied
**Then** these are renamed to `lastVelocity` and the history tuple uses `velocity: UInt8`

**Given** all existing tests pass before the refactoring
**When** the refactoring is complete
**Then** all existing tests pass with updated parameter names and types, and no audible behavior changes (NFR1)

### Story 10.3: Add Amplitude Parameter to NotePlayer

As a **developer**,
I want `NotePlayer.play` to accept an amplitude parameter that controls sound volume independently of velocity,
So that the audio engine can play notes at different loudness levels for the Vary Loudness feature.

**Acceptance Criteria:**

**Given** the `NotePlayer` protocol declares `play(frequency:duration:velocity:)`
**When** the amplitude parameter is added
**Then** the signature becomes `play(frequency:duration:velocity:amplitude:)` where amplitude controls sound volume using the mechanism identified in Story 10.1

**Given** amplitude is not explicitly provided
**When** a note is played
**Then** the note plays at a default amplitude (no volume change), so existing callers are unaffected

**Given** `SoundFontNotePlayer` receives an amplitude value
**When** a note is played
**Then** the sound volume is adjusted according to the amplitude value, independently of the MIDI velocity

**Given** an amplitude value outside the valid range is provided
**When** `play` is called
**Then** an `AudioError.invalidAmplitude` error is thrown

**Given** `MockNotePlayer` is used in tests
**When** a note is played with an amplitude value
**Then** the mock captures the amplitude in `lastAmplitude` and `playHistory` for test verification

### Story 10.4: Add "Vary Loudness" Slider to Settings

As a **musician**,
I want a "Vary Loudness" slider in the Settings screen,
So that I can control how much the volume varies between notes during training.

**Acceptance Criteria:**

**Given** the user navigates to the Settings screen
**When** the screen is displayed
**Then** a "Vary Loudness" slider is visible, labeled in the current locale (English: "Vary Loudness", German: localized equivalent)

**Given** the slider range is 0.0 (left) to 1.0 (right)
**When** the slider is all the way to the left
**Then** the label or context communicates that there will be no loudness variation

**Given** the slider is all the way to the right
**When** the user reads the label or context
**Then** it communicates maximum loudness variation

**Given** the user adjusts the slider to any position
**When** the user leaves Settings
**Then** the value is persisted via `@AppStorage` using a new key in `SettingsKeys.swift`

**Given** the app is restarted
**When** the user opens Settings
**Then** the slider reflects the previously saved value

**Given** no value has been set (fresh install or existing user)
**When** the slider is first displayed
**Then** it defaults to 0.0 (no loudness variation — existing behavior preserved)

### Story 10.5: Apply Loudness Variation in Training

As a **musician**,
I want note2 to sometimes play at a slightly different volume than note1 during training,
So that I learn to distinguish pitch from loudness and sharpen my pitch perception.

**Acceptance Criteria:**

**Given** the "Vary Loudness" slider is set to 0.0
**When** a comparison is played
**Then** both notes are played at the same amplitude (no loudness offset applied to note2)

**Given** the "Vary Loudness" slider is set to 1.0
**When** a comparison is played
**Then** note2's amplitude is offset by a random value in the range ±maxOffset dB (initially 2 dB) relative to note1

**Given** the "Vary Loudness" slider is set to a value between 0.0 and 1.0 (e.g., 0.5)
**When** a comparison is played
**Then** note2's amplitude offset is drawn from ±(sliderValue × maxOffset) dB (e.g., ±1 dB at 0.5)

**Given** `TrainingSession` is about to play a comparison
**When** it reads the "Vary Loudness" setting
**Then** it reads the current value from `@AppStorage` live (not cached), consistent with how other settings are read

**Given** the random offset would push the amplitude outside the valid range
**When** the offset is calculated
**Then** the resulting amplitude is clamped to the valid range so no error is thrown

**Given** the maxOffset constant is defined
**When** a developer needs to adjust it after testing
**Then** it is a single tunable constant, easy to find and change

## Epic 11: Clear the Decks — Prerequisite Renames

With two training modes, several MVP names are now ambiguous. All ambiguous names are renamed to pitch-comparison-specific names before any new feature work begins. This is pure refactoring — no functional changes, all tests continue to pass.

### Story 11.1: Rename Training Types and Files to Pitch Comparison

As a **developer**,
I want all ambiguous "Training" names renamed to pitch-comparison-specific names,
So that the codebase clearly distinguishes pitch comparison training from future training modes and the namespace is clean for pitch matching.

**Acceptance Criteria:**

**Given** the type `TrainingSession` exists
**When** the rename is applied
**Then** it becomes `PitchDiscriminationSession` in all source files, test files, and references
**And** the file is renamed from `TrainingSession.swift` to `PitchDiscriminationSession.swift`
**And** the test file is renamed from `TrainingSessionTests.swift` to `PitchDiscriminationSessionTests.swift`

**Given** the enum `TrainingState` exists
**When** the rename is applied
**Then** it becomes `PitchDiscriminationSessionState` in all source files, test files, and references

**Given** the file `TrainingScreen.swift` exists
**When** the rename is applied
**Then** it becomes `PitchDiscriminationScreen.swift`
**And** all references to `TrainingScreen` in source and test files are updated

**Given** the `Training/` feature directory exists
**When** the rename is applied
**Then** it becomes `PitchDiscrimination/`
**And** the test directory `PeachTests/Training/` becomes `PeachTests/PitchDiscrimination/`

**Given** the view `FeedbackIndicator` exists
**When** the rename is applied
**Then** it becomes `PitchDiscriminationFeedbackIndicator` in all source files, test files, and references
**And** the file is renamed from `FeedbackIndicator.swift` to `PitchDiscriminationFeedbackIndicator.swift`

**Given** the protocol `NextNoteStrategy` exists
**When** the rename is applied
**Then** it becomes `NextPitchDiscriminationStrategy` in all source files, test files, and references
**And** the file is renamed from `NextNoteStrategy.swift` to `NextPitchDiscriminationStrategy.swift`
**And** the method `nextNote()` is renamed to `nextPitchDiscriminationTrial()` (or equivalent, matching existing method name)

**Given** the following names exist in the codebase
**When** the rename is applied
**Then** these names remain UNCHANGED: `TrainingDataStore`, `TrainingSettings`, `PitchDiscriminationObserver`, `PitchDiscriminationTrial`, `CompletedPitchDiscriminationTrial`, `PerceptualProfile`, `NotePlayer`, `HapticFeedbackManager`

**Given** `docs/project-context.md` references old names (TrainingSession, TrainingScreen, TrainingState, NextNoteStrategy, FeedbackIndicator)
**When** the rename is applied
**Then** all references in `docs/project-context.md` are updated to use the new names

**Given** the full test suite
**When** all tests are run after the rename
**Then** all existing tests pass with zero functional changes — this is a pure rename/refactoring operation

## Epic 12: Own Every Note — PlaybackHandle Redesign

The NotePlayer protocol is redesigned around a PlaybackHandle that represents ownership of a playing note. Every started note has an explicit owner responsible for stopping it. This enables both fixed-duration playback (comparisons, via convenience method) and indefinite playback with real-time frequency adjustment (pitch matching).

### Story 12.1: PlaybackHandle Protocol and NotePlayer Redesign

As a **developer**,
I want the audio layer redesigned around a PlaybackHandle pattern where callers own the notes they start,
So that the audio engine supports both fixed-duration and indefinite playback with explicit note lifecycle management.

**Acceptance Criteria:**

**Given** no `PlaybackHandle` protocol exists
**When** the protocol is created
**Then** `PlaybackHandle` defines `func stop() async throws` (first call sends noteOff, subsequent calls are no-ops) and `func adjustFrequency(_ frequency: Double) async throws` (adjusts pitch of the playing note in real time, caller passes absolute Hz)
**And** the file is located at `Core/Audio/PlaybackHandle.swift`

**Given** the current `NotePlayer` protocol has `play(frequency:duration:velocity:amplitudeDB:)` and `stop()`
**When** the protocol is redesigned
**Then** the primary method becomes `func play(frequency: Double, velocity: UInt8, amplitudeDB: Float) async throws -> PlaybackHandle` which returns immediately after note onset
**And** `stop()` is removed from the `NotePlayer` protocol — stopping is done through the handle only
**And** a default extension provides `func play(frequency: Double, duration: TimeInterval, velocity: UInt8, amplitudeDB: Float) async throws` that internally uses the handle (play → sleep → stop)

**Given** `SoundFontNotePlayer` is the sole `NotePlayer` implementation
**When** it is updated
**Then** `play(frequency:velocity:amplitudeDB:)` returns a `SoundFontPlaybackHandle` that wraps the MIDI note and sampler reference
**And** `SoundFontPlaybackHandle` implements `stop()` by sending MIDI noteOff (idempotent)
**And** `SoundFontPlaybackHandle` implements `adjustFrequency()` by computing the relative pitch bend from the base MIDI note to the target Hz and applying it via the sampler's pitch bend API
**And** `SoundFontPlaybackHandle.swift` is located at `Core/Audio/SoundFontPlaybackHandle.swift`

**Given** `MockNotePlayer` is used in tests
**When** it is updated
**Then** `play(frequency:velocity:amplitudeDB:)` returns a `MockPlaybackHandle`
**And** `MockPlaybackHandle` tracks `stopCallCount`, `adjustFrequencyCallCount`, `lastAdjustedFrequency`
**And** `MockPlaybackHandle` supports `instantPlayback` mode and `shouldThrowError` injection
**And** `MockPlaybackHandle.swift` is located in the test target

**Given** the fixed-duration convenience method is provided via default protocol extension
**When** existing pitch comparison training call sites use `play(frequency:duration:velocity:amplitudeDB:)`
**Then** they continue to work without any call-site changes — the convenience method delegates to the handle internally

**Given** the full test suite
**When** all tests are run
**Then** all existing tests pass
**And** new tests verify: PlaybackHandle stop idempotency, adjustFrequency updates, MockPlaybackHandle tracking, fixed-duration convenience method behavior

### Story 12.2: ~~PitchDiscriminationSession PlaybackHandle Integration~~ — Won't Do

**Status:** Won't Do — Superseded by Story 12.1

**Rationale:** Story 12.1 introduced `NotePlayer.stopAll()` and a fixed-duration convenience method with internal handle management. PitchDiscriminationSession already uses these simpler interfaces effectively: `play(frequency:duration:velocity:amplitudeDB:)` for normal playback and `stopAll()` for interruption cleanup. Adding explicit `PlaybackHandle` tracking to PitchDiscriminationSession would introduce unnecessary complexity — the convenience method deliberately hides handle lifecycle, and `stopAll()` provides a more robust interruption mechanism than per-handle stopping. PitchDiscriminationSession's responsibility is orchestrating comparisons, not managing audio note lifecycles.

## Epic 13: Remember Every Match — Pitch Matching Data Layer

Pitch matching results are reliably stored alongside comparison records, with the observer pattern enabling decoupled persistence. This extends the data foundation to support both training modes.

### Story 13.1: PitchMatchingRecord Data Model and TrainingDataStore Extension

As a **developer**,
I want pitch matching results persisted in SwiftData alongside comparison records,
So that all training data is reliably stored and available for profile computation and future analysis.

**Acceptance Criteria:**

**Given** no `PitchMatchingRecord` model exists
**When** the model is created
**Then** it is a SwiftData `@Model` with fields: `referenceNote` (Int, MIDI 0-127), `initialCentOffset` (Double, ±100 cents), `userCentError` (Double, signed — positive = sharp, negative = flat), `timestamp` (Date)
**And** the file is located at `Core/Data/PitchMatchingRecord.swift`

**Given** no `CompletedPitchMatchingTrial` value type exists
**When** it is created
**Then** it is a struct with fields: `referenceNote` (Int), `initialCentOffset` (Double), `userCentError` (Double), `timestamp` (Date)
**And** the file is located at `PitchMatching/CompletedPitchMatchingTrial.swift`

**Given** no `PitchMatchingTrial` value type exists
**When** it is created
**Then** it is a struct with fields: `referenceNote` (Int, MIDI 0-127), `initialCentOffset` (Double, random ±100 cents)
**And** the file is located at `PitchMatching/PitchMatchingTrial.swift`

**Given** no `PitchMatchingObserver` protocol exists
**When** it is created
**Then** it defines `func pitchMatchingCompleted(_ result: CompletedPitchMatchingTrial)`
**And** the file is located at `PitchMatching/PitchMatchingObserver.swift`

**Given** `TrainingDataStore` currently handles only comparison records
**When** pitch matching CRUD is added
**Then** it supports `save(_ record: PitchMatchingRecord) throws`, `fetchAllPitchMatching() throws -> [PitchMatchingRecord]`, and `deleteAllPitchMatching() throws`
**And** `TrainingDataStore` conforms to `PitchMatchingObserver`, automatically persisting completed pitch matching attempts

**Given** the `ModelContainer` in `PeachApp.swift` registers only `PitchDiscriminationRecord`
**When** the schema is updated
**Then** it registers both `PitchDiscriminationRecord.self` and `PitchMatchingRecord.self`

**Given** the full test suite
**When** all tests are run
**Then** all existing tests pass
**And** new tests verify: PitchMatchingRecord CRUD operations, TrainingDataStore pitch matching persistence, atomic writes, in-memory ModelContainer for tests

## Epic 14: Know Both Skills — Profile Protocol Split

The perceptual profile is split into two protocol interfaces representing the two distinct skills being trained. Each training mode depends only on the statistics it needs, maintaining clean dependency boundaries.

### Story 14.1: Extract PitchDiscriminationProfile Protocol

As a **developer**,
I want the existing PerceptualProfile pitch comparison interface extracted into a protocol,
So that PitchDiscriminationSession and NextPitchDiscriminationStrategy depend on an abstract interface rather than the concrete class.

**Acceptance Criteria:**

**Given** `PerceptualProfile` exposes pitch comparison methods directly
**When** the protocol is extracted
**Then** `PitchDiscriminationProfile` protocol defines: `func update(note: Int, centOffset: Double, isCorrect: Bool)`, `func weakSpots(count: Int) -> [Int]`, `var overallMean: Double? { get }`, `var overallStdDev: Double? { get }`, `func statsForNote(_ note: Int) -> PerceptualNote`, `func averageThreshold(midiRange: ClosedRange<Int>) -> Int?`, `func setDifficulty(note: Int, difficulty: Double)`, `func reset()`
**And** the file is located at `Core/Profile/PitchDiscriminationProfile.swift`

**Given** `PerceptualProfile` already implements all these methods
**When** it conforms to `PitchDiscriminationProfile`
**Then** no implementation changes are needed — conformance is declarative

**Given** `PitchDiscriminationSession` currently depends on `PerceptualProfile` (concrete)
**When** the dependency is updated
**Then** it depends on `PitchDiscriminationProfile` (protocol) — accepting any conforming type

**Given** `NextPitchDiscriminationStrategy` (and implementations like `KazezNoteStrategy`) depend on `PerceptualProfile`
**When** the dependency is updated
**Then** they depend on `PitchDiscriminationProfile` (protocol)

**Given** the full test suite
**When** all tests are run
**Then** all existing tests pass with zero functional changes — this is a pure extraction refactoring

### Story 14.2: PitchMatchingProfile Protocol and Matching Statistics

As a **developer**,
I want PerceptualProfile to track pitch matching statistics via a new protocol,
So that PitchMatchingSession can record and read matching accuracy data through a clean interface.

**Acceptance Criteria:**

**Given** no `PitchMatchingProfile` protocol exists
**When** it is created
**Then** it defines: `func updateMatching(note: Int, centError: Double)`, `var matchingMean: Double? { get }` (mean absolute error in cents), `var matchingStdDev: Double? { get }` (standard deviation), `var matchingSampleCount: Int { get }`, `func resetMatching()`
**And** the file is located at `Core/Profile/PitchMatchingProfile.swift`

**Given** `PerceptualProfile` does not track matching statistics
**When** `PitchMatchingProfile` conformance is added
**Then** `PerceptualProfile` stores aggregate matching statistics: running mean absolute error, running standard deviation (Welford's algorithm), and sample count
**And** these are overall aggregates — not per-note for v0.2

**Given** `PerceptualProfile` conforms to `PitchMatchingProfile`
**When** it also conforms to `PitchMatchingObserver`
**Then** `pitchMatchingCompleted(_:)` calls `updateMatching(note:centError:)` to update matching statistics incrementally

**Given** the app starts up and `PitchMatchingRecord` data exists in SwiftData
**When** `PerceptualProfile` is rebuilt
**Then** it loads both `PitchDiscriminationRecord` data (pitch comparison) and `PitchMatchingRecord` data (matching) to reconstruct the complete profile

**Given** no pitch matching data exists (cold start or comparison-only user)
**When** matching statistics are queried
**Then** `matchingMean` and `matchingStdDev` return `nil`, `matchingSampleCount` returns `0`

**Given** `resetMatching()` is called
**When** matching statistics are queried afterward
**Then** all matching statistics are cleared (`nil`/`0`) while pitch comparison statistics remain untouched

**Given** the full test suite
**When** all tests are run
**Then** all existing tests pass
**And** new tests verify: matching statistics update via Welford's, cold start nil values, reset independence from pitch comparison, profile rebuild from both record types

## Epic 15: Tune Your Ear — PitchMatchingSession

The pitch matching state machine orchestrates the complete training loop: play a reference note, auto-start a tunable note, accept real-time frequency adjustments from the slider, record the result on release, show feedback, and repeat.

### Story 15.1: PitchMatchingSession Core State Machine

As a **musician using Peach**,
I want a pitch matching training loop where I hear a reference note, then tune a second note to match it,
So that I train my ability to actively reproduce a target pitch.

**Acceptance Criteria:**

**Given** no `PitchMatchingSession` exists
**When** it is created
**Then** it is an `@Observable final class` with dependencies: `notePlayer: NotePlayer`, `profile: PitchMatchingProfile`, `observers: [PitchMatchingObserver]`, `settingsOverride: TrainingSettings?`, `noteDurationOverride: TimeInterval?`, `notificationCenter: NotificationCenter`
**And** it starts in the `idle` state

**Given** `PitchMatchingSessionState` does not exist
**When** it is created
**Then** it defines cases: `idle`, `playingReference`, `playingTunable`, `showingFeedback`

**Given** the session is in `idle` state
**When** `startPitchMatching()` is called
**Then** the session generates a random `PitchMatchingTrial` (random MIDI note within configured training range, random initial offset ±100 cents)
**And** it plays the reference note for the configured note duration using `notePlayer.play(frequency:duration:velocity:amplitudeDB:)` (fixed-duration convenience)
**And** the state transitions to `playingReference`

**Given** the session is in `playingReference` state
**When** the reference note finishes playing
**Then** the session immediately starts the tunable note at the offset frequency using `notePlayer.play(frequency:velocity:amplitudeDB:)` (handle-returning, indefinite)
**And** the state transitions to `playingTunable`
**And** the session holds the returned `PlaybackHandle`

**Given** the session is in `playingTunable` state
**When** `adjustFrequency(_ frequency: Double)` is called (from slider movement)
**Then** the session calls `currentHandle?.adjustFrequency(frequency)` to change the pitch in real time

**Given** the session is in `playingTunable` state
**When** `commitResult(userFrequency: Double)` is called (slider released)
**Then** the session calls `currentHandle?.stop()` to stop the tunable note
**And** it computes the signed cent error between the user's final frequency and the reference frequency using `FrequencyCalculation`
**And** it creates a `CompletedPitchMatchingTrial` with: referenceNote, initialCentOffset, userCentError, timestamp
**And** it notifies all observers via `pitchMatchingCompleted(_:)`
**And** the state transitions to `showingFeedback`

**Given** the session is in `showingFeedback` state
**When** ~400ms elapses
**Then** the session automatically starts the next challenge (back to `playingReference`)

**Given** `PitchMatchingSession` generates a challenge
**When** note selection occurs
**Then** the note is random within `TrainingSettings.noteRangeMin...noteRangeMax`
**And** the initial cent offset is random within ±100 cents
**And** this logic is a private method — no protocol, no separate file

**Given** the full test suite
**When** all tests are run
**Then** all existing tests pass
**And** new tests verify: state transitions (idle → playingReference → playingTunable → showingFeedback → loop), random challenge generation within configured range, adjustFrequency delegation to handle, commitResult computation and observer notification, feedback timer auto-advance

### Story 15.2: PitchMatchingSession Interruption and Lifecycle Handling

As a **musician using Peach**,
I want pitch matching to handle interruptions gracefully — discarding incomplete attempts and returning to the Start Screen when appropriate,
So that my training data is never corrupted and the app behaves predictably when I switch away.

**Acceptance Criteria:**

**Given** the session is in `playingReference` state
**When** `stop()` is called
**Then** the reference note handle is stopped
**And** the state transitions to `idle`
**And** no result is recorded

**Given** the session is in `playingTunable` state
**When** `stop()` is called
**Then** the tunable note handle is stopped via `currentHandle?.stop()`
**And** the incomplete attempt is discarded — no result recorded, no observer notification
**And** the state transitions to `idle`

**Given** the session is in `showingFeedback` state
**When** `stop()` is called
**Then** the feedback timer is cancelled
**And** the state transitions to `idle`

**Given** the session is in `idle` state
**When** `stop()` is called
**Then** it is a no-op

**Given** the app is backgrounded during pitch matching (any state except idle)
**When** the `UIApplication.didEnterBackgroundNotification` is received
**Then** `stop()` is called automatically
**And** the session transitions to `idle` (FR50a — the view layer handles returning to Start Screen, same pattern as PitchDiscriminationSession)

**Given** an audio interruption occurs (phone call, Siri, headphone disconnect)
**When** the `AVAudioSession.interruptionNotification` is received with `.began` type
**Then** `stop()` is called automatically
**And** the incomplete attempt is discarded

**Given** the user navigates to Settings or Profile from the Pitch Matching Screen
**When** navigation occurs
**Then** the view calls `session.stop()` before navigating
**And** incomplete attempts are discarded

**Given** the full test suite
**When** all tests are run
**Then** all existing tests pass
**And** new tests verify: stop() from each state, background notification handling, audio interruption handling, idempotent stop calls, no observer notification on discarded attempts

## Epic 16: See and Slide — Pitch Matching Screen

Users interact with pitch matching through a custom vertical slider control and receive post-release visual feedback showing directional accuracy. The screen follows the same navigation and layout patterns as the Pitch Comparison Screen.

### Story 16.1: Vertical Pitch Slider Component

As a **musician using Peach**,
I want a large vertical slider that changes the pitch of the tunable note as I drag it,
So that I can tune by ear using an intuitive physical gesture — up for sharper, down for flatter.

**Acceptance Criteria:**

**Given** no `VerticalPitchSlider` component exists
**When** it is created
**Then** it is a custom SwiftUI view using `DragGesture` for vertical pitch control
**And** dragging up increases the cent offset (sharper), dragging down decreases it (flatter)
**And** the slider occupies most of the available screen height
**And** the file is located at `PitchMatching/VerticalPitchSlider.swift`

**Given** the slider thumb/handle
**When** rendered
**Then** it significantly exceeds 44x44pt for imprecise one-handed grip
**And** the track has no markings — no tick marks, no labels, no center indicator (a blank instrument)

**Given** the slider's starting position
**When** a new pitch matching challenge begins
**Then** the slider always starts at the same physical position (center of track) regardless of the pitch offset

**Given** the slider is in `inactive` state (during reference note)
**When** the user attempts to drag
**Then** the slider does not respond to touch
**And** it is visually dimmed per stock SwiftUI disabled appearance

**Given** the slider is in `active` state (tunable note playing)
**When** the user drags the thumb
**Then** a continuous cent offset value is produced
**And** the `onFrequencyChange` callback fires with the computed frequency

**Given** the user releases the slider
**When** the drag gesture ends
**Then** the `onRelease` callback fires with the final frequency
**And** the slider returns to inactive appearance

**Given** VoiceOver is active
**When** the slider is focused
**Then** it has the accessibility label "Pitch adjustment slider"
**And** it supports `accessibilityAdjustableAction` for increment/decrement tuning as a fallback

**Given** the slider renders in portrait orientation
**When** the device is rotated to landscape
**Then** the slider remains vertical (the up=higher metaphor is non-negotiable)
**And** it uses the reduced screen height, mapping the same ±100 cent range

**Given** the full test suite
**When** all tests are run
**Then** all existing tests pass
**And** new tests verify: cent offset calculation from drag position, frequency computation from cent offset (using FrequencyCalculation), callback invocations, inactive state ignores gestures

### Story 16.2: Pitch Matching Feedback Indicator

As a **musician using Peach**,
I want to see a brief directional arrow and cent offset after each pitch matching attempt,
So that I know how close I was and in which direction I erred — without judgment.

**Acceptance Criteria:**

**Given** no `PitchMatchingFeedbackIndicator` exists
**When** it is created
**Then** it is a SwiftUI view showing a directional arrow (or green dot) and signed cent offset text
**And** the file is located at `PitchMatching/PitchMatchingFeedbackIndicator.swift`

**Given** the user's cent error is approximately 0 cents (dead center)
**When** feedback is displayed
**Then** a green dot (`circle.fill` SF Symbol) is shown in system green
**And** the text reads "0 cents"

**Given** the user's cent error is positive and < 10 cents (slightly sharp)
**When** feedback is displayed
**Then** a short upward arrow (`arrow.up` SF Symbol) is shown in system green
**And** the text reads the signed offset (e.g., "+4 cents")

**Given** the user's cent error is negative and magnitude < 10 cents (slightly flat)
**When** feedback is displayed
**Then** a short downward arrow (`arrow.down` SF Symbol) is shown in system green
**And** the text reads the signed offset (e.g., "-3 cents")

**Given** the user's cent error magnitude is 10-30 cents (moderate)
**When** feedback is displayed
**Then** a medium-length arrow (up or down matching sign) is shown in system yellow

**Given** the user's cent error magnitude is > 30 cents (far off)
**When** feedback is displayed
**Then** a long arrow (up or down matching sign) is shown in system red

**Given** the feedback is displayed
**When** ~400ms elapses
**Then** the indicator clears with `.transition(.opacity)` — same pattern as `PitchDiscriminationFeedbackIndicator`

**Given** VoiceOver is active
**When** feedback is displayed
**Then** it announces the result verbally: "4 cents sharp", "27 cents flat", or "Dead center"

**Given** no haptic feedback
**When** pitch matching feedback is displayed
**Then** no haptic vibration occurs — pitch matching feedback is purely visual (UX spec decision)

**Given** the full test suite
**When** all tests are run
**Then** all existing tests pass
**And** new tests verify: correct arrow direction and color for each band, cent offset text formatting, green dot for dead center, band threshold boundaries (0, 10, 30)

### Story 16.3: Pitch Matching Screen Assembly

As a **musician using Peach**,
I want a complete Pitch Matching Screen that assembles the slider, feedback, and navigation,
So that I can do a full pitch matching training session with the same navigation patterns as pitch comparison training.

**Acceptance Criteria:**

**Given** no `PitchMatchingScreen` exists
**When** it is created
**Then** it is a SwiftUI view observing `PitchMatchingSession` via `@Environment`
**And** it contains: `VerticalPitchSlider`, `PitchMatchingFeedbackIndicator`, Settings button, Profile button
**And** the file is located at `PitchMatching/PitchMatchingScreen.swift`

**Given** the screen appears
**When** displayed
**Then** `PitchMatchingSession.startPitchMatching()` is called to begin the loop

**Given** the session is in `playingReference` state
**When** the screen renders
**Then** the `VerticalPitchSlider` is visible but inactive (disabled appearance)
**And** the feedback indicator is hidden

**Given** the session is in `playingTunable` state
**When** the user drags the slider
**Then** the screen calls `session.adjustFrequency()` with the computed frequency from the slider
**And** the slider is active and responsive

**Given** the user releases the slider
**When** the drag gesture ends
**Then** the screen calls `session.commitResult(userFrequency:)` with the final frequency

**Given** the session is in `showingFeedback` state
**When** the screen renders
**Then** the `PitchMatchingFeedbackIndicator` displays the result from the session
**And** the slider is inactive

**Given** the user taps the Settings button
**When** navigation occurs
**Then** `session.stop()` is called before navigating to Settings Screen
**And** the session discards any incomplete attempt

**Given** the user taps the Profile button
**When** navigation occurs
**Then** `session.stop()` is called before navigating to Profile Screen

**Given** the screen renders in portrait
**When** the device is rotated to landscape
**Then** the layout adapts — slider remains vertical, controls reflow appropriately

**Given** the full test suite
**When** all tests are run
**Then** all existing tests pass

## Epic 17: Two Modes, One App — Start Screen Integration

Users can access both pitch comparison training and pitch matching from the Start Screen, with clear visual hierarchy and proper navigation routing.

### Story 17.1: Pitch Matching Button and Navigation Routing

As a **musician using Peach**,
I want a "Pitch Matching" button on the Start Screen below "Start Training",
So that I can start pitch matching with a single tap, just like pitch comparison training.

**Acceptance Criteria:**

**Given** the Start Screen currently shows a "Start Training" button
**When** the Pitch Matching button is added
**Then** a "Pitch Matching" button appears below the "Start Training" button
**And** "Start Training" retains `.borderedProminent` style (primary/hero action)
**And** "Pitch Matching" uses `.bordered` style (secondary — visible but visually subordinate)

**Given** `NavigationDestination` currently has no pitch matching case
**When** the destination is added
**Then** `NavigationDestination` includes a `.pitchMatching` case
**And** the navigation stack resolves `.pitchMatching` to `PitchMatchingScreen`

**Given** `PeachApp.swift` currently creates only `PitchDiscriminationSession`
**When** `PitchMatchingSession` is wired
**Then** `PeachApp.swift` creates a `PitchMatchingSession` with `notePlayer`, `profile` (as `PitchMatchingProfile`), and observers (`trainingDataStore`, `perceptualProfile`)
**And** `PitchMatchingSession` is injected via `@Environment` using `@Entry var pitchMatchingSession`

**Given** the user taps the "Pitch Matching" button
**When** navigation occurs
**Then** the app navigates to `PitchMatchingScreen`
**And** pitch matching begins automatically

**Given** the "Pitch Matching" button label
**When** localization is active
**Then** the label is localized in both English and German

**Given** the full test suite
**When** all tests are run
**Then** all existing tests pass

## Epic 18: The Full Picture — Profile Screen Integration

Users can see their pitch matching accuracy statistics alongside their pitch comparison profile on the Profile Screen, giving a complete view of both training skills.

### Story 18.1: Display Pitch Matching Statistics on Profile Screen

As a **musician using Peach**,
I want to see my pitch matching accuracy on the Profile Screen alongside my pitch comparison profile,
So that I can track improvement in both training modes from one place.

**Acceptance Criteria:**

**Given** the Profile Screen currently shows only pitch comparison statistics (mean detection threshold, standard deviation, trend)
**When** pitch matching statistics are added
**Then** a new section displays: matching mean absolute error (cents), matching standard deviation (cents), and matching sample count
**And** the section is visually distinct from the pitch comparison section

**Given** the user has pitch matching data
**When** the Profile Screen is displayed
**Then** matching statistics are computed from the `PitchMatchingProfile` protocol
**And** values are formatted to a reasonable precision (e.g., 1 decimal place for cents)

**Given** the user has NO pitch matching data (cold start or comparison-only user)
**When** the Profile Screen is displayed
**Then** the matching section shows an empty state: a brief message like "Start pitch matching to see your accuracy" (localized)
**And** no placeholder numbers are shown — honest absence of data

**Given** the matching statistics labels
**When** localization is active
**Then** all labels and the empty state message are localized in English and German

**Given** the Profile Screen renders in portrait
**When** the device is rotated to landscape
**Then** the layout adapts — matching statistics section reflows with the existing layout

**Given** the full test suite
**When** all tests are run
**Then** all existing tests pass

## Epic 19: Clean Foundations — Code Review Refactoring

Address all code review findings from the initial implementation: replace magic values with named constants, wrap primitives in validated Value Objects, encapsulate UserDefaults behind a protocol, extract long methods, and introduce a TrainingSession protocol to decouple views from concrete session types.

### Story 19.1: Clamping Utility and Magic Value Constants

As a **developer maintaining Peach**,
I want inline clamping patterns and magic numeric literals replaced with a reusable utility and named constants,
So that the code is easier to read, harder to get wrong, and changes to domain bounds propagate from a single source of truth.

**Acceptance Criteria:**

**Given** inline `min(max(...))` / `max(..., min(...))` clamping patterns exist in production code
**When** the refactoring is applied
**Then** a `Comparable.clamped(to:)` extension replaces all inline patterns
**And** the local `clamp()` helper in `AdaptiveNoteStrategy.swift` is removed

**Given** the magic literal `-100.0...100.0` in `PitchMatchingSession.swift`
**When** the refactoring is applied
**Then** it is replaced with a named `static let` constant with a descriptive name

**Given** the magic literals `-90.0` and `12.0` used as amplitude dB bounds in `PitchDiscriminationSession.swift`
**When** the refactoring is applied
**Then** they are replaced with a named constant

**Given** the full test suite
**When** all tests are run
**Then** all existing tests pass with zero regressions

### Story 19.2: Value Objects for Domain Primitives

As a **developer maintaining Peach**,
I want naked primitive types (Int, Double, UInt8, Float) wrapped in validated domain-specific Value Objects,
So that MIDI note ranges, cent values, frequencies, velocities, and amplitudes are enforced at compile time and the code communicates intent clearly.

**Acceptance Criteria:**

**Given** no domain-specific value types exist
**When** the value objects are created
**Then** `MIDINote` (validated 0–127), `MIDIVelocity` (validated 1–127), `Cents` (signed Double), `Frequency` (positive Double), and `AmplitudeDB` (Float clamped to -90…12) exist in `Peach/Core/Audio/`
**And** each supports `ExpressibleByLiteral` conformance and `Comparable`

**Given** `NotePlayer.play()`, `PlaybackHandle.adjustFrequency()`, profile methods, and session signatures use raw primitives
**When** the value objects are adopted
**Then** signatures use `Frequency`, `MIDIVelocity`, `AmplitudeDB`, `MIDINote`, and `Cents` where appropriate

**Given** `PitchDiscriminationTrial` stores `note1: Int`, `note2: Int`, `isSecondNoteHigher: Bool`
**When** the redesign is applied
**Then** `note1` and `note2` are `MIDINote`, `centDifference` is signed `Cents`, and `isSecondNoteHigher` is a computed property

**Given** `PitchDiscriminationRecord` and `PitchMatchingRecord` are SwiftData `@Model` types
**When** value objects are adopted
**Then** the records retain raw `Int` and `Double` storage to avoid SwiftData migration
**And** conversion happens at boundaries via `.rawValue` and constructor calls

**Given** the full test suite
**When** all tests are run
**Then** all existing tests pass with zero regressions
**And** each new value type has its own test file

### Story 19.3: UserSettings Wrapper for UserDefaults

As a **developer maintaining Peach**,
I want all `UserDefaults.standard` access encapsulated behind a `UserSettings` protocol with typed properties,
So that business logic is decoupled from the persistence singleton, type casting and default fallbacks are centralized, and tests can inject a mock instead of using override parameters.

**Acceptance Criteria:**

**Given** sessions and `SoundFontNotePlayer` access `UserDefaults.standard` directly
**When** the `UserSettings` protocol is created
**Then** it exposes typed read-only properties for all user-configurable settings
**And** `AppUserSettings` reads from `UserDefaults.standard` internally

**Given** `PitchDiscriminationSession`, `PitchMatchingSession`, and `SoundFontNotePlayer` accept override parameters for testing
**When** dependency injection is applied
**Then** they accept a `UserSettings` parameter instead of accessing `UserDefaults.standard` directly
**And** override parameters (`settingsOverride`, `noteDurationOverride`, `varyLoudnessOverride`) are removed

**Given** tests that previously relied on overrides or `UserDefaults.standard` manipulation
**When** `MockUserSettings` is created
**Then** tests inject `MockUserSettings` with mutable properties instead

**Given** `SettingsScreen` uses `@AppStorage`
**When** the refactoring is applied
**Then** `SettingsScreen` is unchanged — it writes to the same `UserDefaults` backing store

**Given** the full test suite
**When** all tests are run
**Then** all existing tests pass with zero regressions

### Story 19.4: Extract Long Methods

As a **developer maintaining Peach**,
I want the three long methods (`PeachApp.init()`, `PitchDiscriminationSession.handleAnswer()`, `PitchDiscriminationSession.playNextPitchDiscriminationTrial()`) broken into smaller, named helper methods,
So that each method does one thing, the code is easier to read and navigate, and the former inline comments become self-documenting method names.

**Acceptance Criteria:**

**Given** `PeachApp.init()` is ~70 lines with comment-delimited sections
**When** it is extracted
**Then** each section (create model container, create dependencies, populate profile, create sessions) becomes a named method

**Given** `PitchDiscriminationSession.handleAnswer()` is ~60 lines
**When** it is extracted
**Then** it is split into helpers: stopping note 2 if playing, tracking session best, and transitioning to feedback state

**Given** `PitchDiscriminationSession.playNextPitchDiscriminationTrial()` is ~70 lines
**When** it is extracted
**Then** it is split into helpers: calculating note 2 amplitude from loudness variation, and playing the comparison note pair

**Given** three `REVIEW:` comments exist on the extracted methods
**When** the extraction is complete
**Then** all three `REVIEW:` comments are removed

**Given** the full test suite
**When** all tests are run
**Then** all existing tests pass with zero regressions

### Story 19.5: TrainingSession Protocol and Dependency Cleanup

As a **developer maintaining Peach**,
I want `ContentView` decoupled from concrete session types via a `TrainingSession` protocol, and `VerticalPitchSlider` simplified to produce normalized values instead of frequencies,
So that the view layer depends only on abstractions, components have single responsibilities, and the pitch domain logic lives entirely in `PitchMatchingSession`.

**Acceptance Criteria:**

**Given** `ContentView.handleAppBackgrounding()` checks two concrete session types
**When** the `TrainingSession` protocol is created
**Then** both `PitchDiscriminationSession` and `PitchMatchingSession` conform to it with `stop()` and `isIdle`
**And** `ContentView` calls `activeSession?.stop()` on a single `TrainingSession?` reference

**Given** `PeachApp` creates both session types
**When** active session tracking is added
**Then** `PeachApp` tracks which session is currently active and injects it into `ContentView` via environment

**Given** `VerticalPitchSlider` exposes `centRange`, `referenceFrequency`, `onFrequencyChange`, and `onRelease` parameters
**When** the slider is simplified
**Then** it produces values in `-1.0...1.0` only via `onNormalizedValueChange` and `onCommit`
**And** `PitchMatchingSession` owns the conversion from normalized value to frequency

**Given** `REVIEW:` comments on `ContentView.swift` and `VerticalPitchSlider.swift`
**When** the refactoring is complete
**Then** all `REVIEW:` comments are removed

**Given** the full test suite
**When** all tests are run
**Then** all existing tests pass with zero regressions

## Epic 20: Right Direction — Dependency Inversion Cleanup

Resolve all dependency direction violations found by adversarial code review: move shared domain types from feature modules to Core/, remove SwiftUI and UIKit imports from domain code, consolidate @Entry environment keys, inject services instead of creating them in views, and use protocols instead of concrete types at module boundaries.

### Story 20.1: Move Shared Domain Types to Core/Training/

As a **developer maintaining Peach**,
I want shared domain types (`PitchDiscriminationTrial`, `CompletedPitchDiscriminationTrial`, `PitchDiscriminationObserver`, `CompletedPitchMatchingTrial`, `PitchMatchingObserver`) moved from feature directories to `Core/Training/`,
So that Core/ no longer has upward dependencies on feature modules, and the dependency arrows point in the correct direction.

**Acceptance Criteria:**

**Given** `PitchDiscriminationTrial`, `CompletedPitchDiscriminationTrial`, and `PitchDiscriminationObserver` are defined in `PitchDiscrimination/` and `CompletedPitchMatchingTrial` and `PitchMatchingObserver` are defined in `PitchMatching/`
**When** they are moved to `Peach/Core/Training/`
**Then** no Core/ file depends on any type defined in a feature directory
**And** the full test suite passes with zero code changes (single-module app resolves types by name)

### Story 20.2: Move SoundSourceID to Core/Audio/

As a **developer maintaining Peach**,
I want `SoundSourceID` moved from `Settings/` to `Core/Audio/`,
So that `SoundFontNotePlayer` no longer depends on the Settings module, and audio domain types are co-located.

**Acceptance Criteria:**

**Given** `SoundSourceID.swift` lives in `Settings/` but is consumed by `SoundFontNotePlayer` in `Core/Audio/`
**When** it is moved to `Peach/Core/Audio/SoundSourceID.swift`
**Then** no Core/ file references any type defined in Settings/
**And** the full test suite passes with zero code changes

### Story 20.3: Move NoteDuration to Core/Audio/

As a **developer maintaining Peach**,
I want `NoteDuration` moved from `Settings/` to `Core/Audio/`,
So that all audio domain value types are co-located in `Core/Audio/`, the `UserSettings` protocol references only `Core/` types, and no Core/ consumer depends on Settings/.

**Acceptance Criteria:**

**Given** `NoteDuration.swift` lives in `Settings/` but is a domain value type like `MIDINote`, `Frequency`, `Cents`, and `SoundSourceID`
**When** it is moved to `Peach/Core/Audio/NoteDuration.swift`
**Then** every type in the `UserSettings` protocol signature is defined in `Core/`
**And** the full test suite passes with zero code changes

### Story 20.4: Remove Cross-Feature Feedback Icon Size Dependency

As a **developer maintaining Peach**,
I want `PitchMatchingFeedbackIndicator` to define its own icon size constant instead of referencing `PitchDiscriminationFeedbackIndicator.defaultIconSize`,
So that PitchMatching/ has no dependency on PitchDiscrimination/ and each feature module is self-contained.

**Acceptance Criteria:**

**Given** `PitchMatchingFeedbackIndicator` references `PitchDiscriminationFeedbackIndicator.defaultIconSize`
**When** a local `private static let defaultIconSize: CGFloat = 100` is defined
**Then** `PitchMatchingFeedbackIndicator.swift` contains no reference to `PitchDiscriminationFeedbackIndicator`
**And** the full test suite passes

### Story 20.5: Use Protocols in Profile Views

As a **developer maintaining Peach**,
I want `SummaryStatisticsView` and `MatchingStatisticsView` to depend on protocols (`PitchDiscriminationProfile` and `PitchMatchingProfile`) instead of the concrete `PerceptualProfile` class,
So that the views follow the Dependency Inversion Principle and depend on abstractions rather than implementations.

**Acceptance Criteria:**

**Given** `SummaryStatisticsView.computeStats(from:)` takes `PerceptualProfile` and `MatchingStatisticsView.computeMatchingStats(from:)` takes `PerceptualProfile`
**When** parameter types are changed to `PitchDiscriminationProfile` and `PitchMatchingProfile` respectively
**Then** the methods accept any protocol-conforming type
**And** the full test suite passes (existing tests pass `PerceptualProfile` which conforms to both)

### Story 20.6: Extract @Entry Environment Keys from Core/

As a **developer maintaining Peach**,
I want all `@Entry` environment key definitions consolidated into a single `App/EnvironmentKeys.swift` file,
So that Core/ files no longer import SwiftUI, the domain layer is framework-free, and all environment wiring is visible in one place.

**Acceptance Criteria:**

**Given** four Core/ files (`SoundFontLibrary`, `TrendAnalyzer`, `ThresholdTimeline`, `TrainingSession`) import SwiftUI solely for `@Entry` definitions
**When** all `@Entry` definitions are moved to `App/EnvironmentKeys.swift`
**Then** no file in Core/ imports SwiftUI
**And** SwiftUI previews for all screens still render
**And** the full test suite passes

### Story 20.7: Remove UIKit from AudioSessionInterruptionMonitor

As a **developer maintaining Peach**,
I want `AudioSessionInterruptionMonitor` to not import UIKit by accepting notification names as parameters instead of hardcoding `UIApplication` constants,
So that Core/ files have no UIKit dependency and the monitor is more testable.

**Acceptance Criteria:**

**Given** `AudioSessionInterruptionMonitor` imports UIKit for `UIApplication.didEnterBackgroundNotification`
**When** the `observeBackgrounding: Bool` parameter is replaced with `backgroundNotificationName: Notification.Name? = nil`
**Then** `AudioSessionInterruptionMonitor.swift` has no `import UIKit`
**And** `PeachApp` provides the UIKit notification names at the composition root
**And** the full test suite passes

### Story 20.8: Resettable Protocol for PitchDiscriminationSession Dependencies

As a **developer maintaining Peach**,
I want `PitchDiscriminationSession` to depend on a `Resettable` protocol instead of storing `TrendAnalyzer` and `ThresholdTimeline` as concrete types,
So that the session is decoupled from specific profile/analytics implementations and only knows that some of its dependencies can be reset.

**Acceptance Criteria:**

**Given** `PitchDiscriminationSession` stores `TrendAnalyzer?` and `ThresholdTimeline?` solely for their `reset()` method
**When** a `Resettable` protocol is introduced and both types conform
**Then** `PitchDiscriminationSession` stores `[Resettable]` instead of named concrete types
**And** `resetTrainingData()` calls `resettables.forEach { $0.reset() }`
**And** the full test suite passes

### Story 20.9: Move MockHapticFeedbackManager to Test Target

As a **developer maintaining Peach**,
I want `MockHapticFeedbackManager` moved from the production target to the test target,
So that mock types do not ship in the production binary and the project follows its own convention that mocks belong in `PeachTests/`.

**Acceptance Criteria:**

**Given** `MockHapticFeedbackManager` exists in `Peach/PitchDiscrimination/HapticFeedbackManager.swift`
**When** it is moved to `PeachTests/PitchDiscrimination/MockHapticFeedbackManager.swift`
**Then** no mock class exists in the production target
**And** all tests using `MockHapticFeedbackManager` still pass via `@testable import Peach`

### Story 20.10: Inject TrainingDataStore into SettingsScreen

As a **developer maintaining Peach**,
I want `SettingsScreen` to receive `TrainingDataStore` via `@Environment` instead of constructing it from a raw `ModelContext`,
So that the view no longer imports SwiftData, service instantiation stays in the composition root, and the persistence implementation detail is hidden behind the existing abstraction.

**Acceptance Criteria:**

**Given** `SettingsScreen` creates `TrainingDataStore(modelContext:)` directly and imports SwiftData
**When** `TrainingDataStore` is injected via `@Environment(\.trainingDataStore)`
**Then** `SettingsScreen.swift` has no `import SwiftData` and no `ModelContext` reference
**And** Reset All Training Data still works correctly
**And** the full test suite passes

### Story 20.11: Update Documentation

As a **developer maintaining Peach**,
I want all architecture documentation updated to reflect the dependency direction cleanup from Epic 20,
So that the docs accurately describe the current codebase, new conventions are captured, and resolved technical debt is marked.

**Acceptance Criteria:**

**Given** Epic 20 changes the directory structure, dependency patterns, and conventions
**When** documentation is updated
**Then** arc42 sections 5, 8, 9, and 11 reflect the new architecture
**And** `project-context.md` includes new file placement rules and framework import restrictions
**And** `epics.md` includes Epic 20 with all stories
**And** `sprint-status.yaml` includes Epic 20 entries

## Epic 21: Speak the Language — Interval Domain Foundation

The system can represent musical intervals and compute precise interval frequencies using tuning systems — the domain foundation for all interval training features. All types are pure value types with no dependencies on existing code.

### Story 21.1: Implement Interval Enum and MIDINote Transposition

As a **developer building interval training**,
I want an `Interval` enum representing musical intervals from Prime through Octave, with a `MIDINote.transposed(by:)` extension and an `Interval.between(_:_:)` factory,
So that intervals are first-class domain concepts with compile-time safety and the system can compute transposed notes.

**Acceptance Criteria:**

**Given** the `Interval` enum exists with cases Prime through Octave
**When** accessing `Interval.perfectFifth.semitones`
**Then** it returns `7`
**And** all 13 cases (Prime through Octave) have correct semitone values (0–12)

**Given** a MIDINote within valid range
**When** calling `MIDINote(60).transposed(by: .perfectFifth)`
**Then** it returns `MIDINote(67)`

**Given** two MIDINote values 7 semitones apart
**When** calling `Interval.between(MIDINote(60), MIDINote(67))`
**Then** it returns `.perfectFifth`

**Given** two MIDINote values more than 12 semitones apart
**When** calling `Interval.between(_:_:)`
**Then** it throws an error (distance outside Prime–Octave range)

**Given** `Interval` conforms to `Hashable`, `Sendable`, `CaseIterable`, `Codable`
**When** encoding and decoding an `Interval` value
**Then** round-trip produces the same value

### Story 21.2: Implement TuningSystem Enum

As a **developer building interval training**,
I want a `TuningSystem` enum that computes the cent offset for any interval,
So that interval frequencies are derived from a pluggable tuning system with 0.1-cent precision (NFR14).

**Acceptance Criteria:**

**Given** `TuningSystem.equalTemperament`
**When** calling `centOffset(for: .perfectFifth)`
**Then** it returns `700.0` (exactly 7 × 100)

**Given** `TuningSystem.equalTemperament`
**When** calling `centOffset(for: .prime)`
**Then** it returns `0.0`

**Given** `TuningSystem.equalTemperament`
**When** calling `centOffset(for: .octave)`
**Then** it returns `1200.0`

**Given** `TuningSystem` conforms to `Hashable`, `Sendable`, `CaseIterable`, `Codable`
**When** encoding and decoding a `TuningSystem` value
**Then** round-trip produces the same value

**Given** the requirement that adding a new tuning system requires no changes to interval or training logic (FR55)
**When** a hypothetical new case is added to `TuningSystem`
**Then** only `centOffset(for:)` needs a new switch case — no other files change

### Story 21.3: Implement Pitch Value Type and MIDINote Integration

As a **developer building interval training**,
I want a `Pitch` struct (MIDINote + Cents) that computes its frequency, with `MIDINote.pitch(at:in:)` composing Interval + TuningSystem into a Pitch, and `Frequency.concert440`,
So that interval frequency computation flows through domain types with 0.1-cent precision.

**Acceptance Criteria:**

**Given** `Pitch(note: MIDINote(69), cents: 0)`
**When** calling `frequency(referencePitch: .concert440)`
**Then** it returns 440.0 Hz (A4 in 12-TET)

**Given** `Pitch(note: MIDINote(60), cents: 0)` (middle C)
**When** calling `frequency(referencePitch: .concert440)`
**Then** the result is accurate to within 0.1 cent of the theoretical value

**Given** `MIDINote(60)` and interval `.perfectFifth` in `.equalTemperament`
**When** calling `MIDINote(60).pitch(at: .perfectFifth, in: .equalTemperament)`
**Then** it returns `Pitch(note: MIDINote(67), cents: 0)` (G4 in 12-TET, cents = 0)

**Given** `MIDINote(60)` with default parameters
**When** calling `MIDINote(60).pitch()` (defaults: `.prime`, `.equalTemperament`)
**Then** it returns `Pitch(note: MIDINote(60), cents: 0)` (unison case)

**Given** `Frequency.concert440`
**When** accessed as a static constant
**Then** its value is `Frequency(440.0)`

**Given** `Pitch` conforms to `Hashable` and `Sendable`
**When** used as a dictionary key or passed across concurrency boundaries
**Then** it works correctly

## Epic 22: Clean Slate — Prerequisite Refactorings

Codebase establishes the two-world architecture (logical MIDINote/DetunedMIDINote/Interval/Cents vs. physical Frequency, bridged by TuningSystem + ReferencePitch), uses unified reference/target naming, and decouples the sound source dependency — so that interval generalization proceeds cleanly without conflating new features with refactoring. All stories are pure refactoring with no functional changes.

### Story 22.1: Migrate FrequencyCalculation to Domain Types

As a **developer building interval training**,
I want the standalone `FrequencyCalculation.swift` utility replaced by `Pitch.frequency(referencePitch:)` and `MIDINote.frequency(referencePitch:)` domain methods,
So that frequency computation lives on the domain types that own the data, and the redundant utility is deleted.

**Acceptance Criteria:**

**Given** `FrequencyCalculation.frequency(midiNote:cents:referencePitch:)` exists
**When** all call sites are migrated to `Pitch.frequency(referencePitch:)` or `MIDINote.frequency(referencePitch:)`
**Then** `FrequencyCalculation.swift` is deleted
**And** no file imports or references `FrequencyCalculation`
**And** NFR3 (0.1-cent frequency precision) is preserved — existing frequency precision tests pass against the new domain methods
**And** the full test suite passes

### Story 22.2: Domain Type Documentation and API Cleanup ✅

As a **developer maintaining the audio domain layer**,
I want class-level documentation on all 6 audio domain types and explicit parameters on all frequency conversion methods,
So that the API is self-documenting, tuning assumptions are visible at every call site, and there is exactly one path from MIDI note to Hz.

**Acceptance Criteria:**

**Given** the 6 audio domain types (`MIDINote`, `Interval`, `Frequency`, `Pitch`, `TuningSystem`, `Cents`)
**When** documentation is added
**Then** all 6 types have `///` doc comments explaining role, relationships, and design decisions

**Given** `MIDINote.frequency()` convenience method exists
**When** it is removed
**Then** all callers use `Pitch(note:cents:).frequency(referencePitch:)` explicitly

**Given** frequency methods have implicit default parameters
**When** defaults are removed from `Pitch.frequency(referencePitch:)`, `Pitch.init(frequency:referencePitch:)`, `Comparison.note1Frequency(referencePitch:)`, `Comparison.note2Frequency(referencePitch:)`, and `TrainingSettings.init(referencePitch:)`
**Then** all call sites pass explicit parameters
**And** the full test suite passes with no behavioral changes

**Given** `project-context.md` documents MIDI-to-Hz conversion guidance
**When** it is updated
**Then** it reflects the new explicit-parameter API

### Story 22.3: Introduce DetunedMIDINote and Two-World Architecture

As a **developer building interval training**,
I want a `DetunedMIDINote(note:offset:)` value type representing a MIDI note with a cent offset in the logical world, `TuningSystem.frequency(for:referencePitch:)` bridge methods for converting to the physical world, and the `Pitch` struct dissolved,
So that the codebase has a clear two-world architecture: logical (MIDINote, DetunedMIDINote, Interval, Cents) and physical (Frequency), bridged explicitly by TuningSystem + ReferencePitch.

**Acceptance Criteria:**

**Given** a new `DetunedMIDINote` struct
**When** constructed as `DetunedMIDINote(note: MIDINote, offset: Cents)`
**Then** it conforms to `Hashable` and `Sendable`
**And** it represents a MIDI note with a microtonal offset, with no frequency or tuning knowledge

**Given** a plain `MIDINote`
**When** converted to `DetunedMIDINote` via `DetunedMIDINote(note)` convenience init
**Then** it creates a `DetunedMIDINote` with `offset: Cents(0)`

**Given** `TuningSystem`
**When** `frequency(for: DetunedMIDINote, referencePitch: Frequency)` is called
**Then** it returns the correct frequency for that note+offset combination
**And** NFR3 (0.1-cent frequency precision) is preserved

**Given** `TuningSystem`
**When** `frequency(for: MIDINote, referencePitch: Frequency)` convenience overload is called
**Then** it delegates to the `DetunedMIDINote` overload with zero offset

**Given** no bridge method has a default value for `tuningSystem`
**When** any call site computes a frequency
**Then** it must explicitly pass both `tuningSystem` and `referencePitch`

**Given** the `Pitch` struct currently used at 5 production call sites
**When** all call sites are migrated to `DetunedMIDINote` + `TuningSystem.frequency(for:referencePitch:)`
**Then** `Pitch.swift` is deleted
**And** no file references `Pitch` as a type

**Given** `MIDINote.pitch(at:in:)` has zero production callers
**When** the method is removed from `Interval.swift`
**Then** no file references `pitch(at:` or `pitch(in:`

**Given** `SoundFontNotePlayer` and `SoundFontPlaybackHandle` use `Pitch(frequency:referencePitch:)` to decompose Hz into MIDI note + pitch bend
**When** this inverse conversion is moved to a private helper within the SoundFont layer
**Then** the conversion remains a 12-TET implementation detail behind the `NotePlayer` protocol boundary
**And** no code outside the SoundFont layer performs Hz→MIDINote decomposition

**Given** `project-context.md` documents the frequency conversion guidance
**When** it is updated
**Then** it documents the two-world model: logical world (MIDINote, DetunedMIDINote, Interval, Cents) and physical world (Frequency), bridged by `TuningSystem.frequency(for:referencePitch:)`
**And** the full test suite passes

### Story 22.4: Unified Reference/Target Naming

As a **developer building interval training**,
I want `note1`/`note2` renamed to `referenceNote`/`targetNote` and `Comparison.targetNote` changed to `DetunedMIDINote` (absorbing the separate `centDifference` field) across all value types, records, sessions, strategies, observers, data store, tests, and docs,
So that naming is consistent with the reference/target mental model shared by all training modes, and `PitchDiscriminationTrial` naturally expresses its target as a detuned note.

**Acceptance Criteria:**

**Given** `PitchDiscriminationRecord` has fields `note1`, `note2`, `note2CentOffset`
**When** they are renamed to `referenceNote`, `targetNote`, `centOffset`
**Then** all references across code, tests, and docs use the new names
**And** no occurrence of `note1`, `note2`, `note2CentOffset`, or `centDifference` remains in Swift source files (except comments explaining the rename if needed)

**Given** `PitchDiscriminationTrial` has fields `note1: MIDINote`, `note2: MIDINote`, `centDifference: Cents`
**When** refactored
**Then** it becomes `referenceNote: MIDINote`, `targetNote: DetunedMIDINote`
**And** `targetNote.note` replaces the old `note2` and `targetNote.offset` replaces `centDifference`
**And** `PitchDiscriminationSession`, `NextPitchDiscriminationStrategy`, `KazezNoteStrategy`, `PitchDiscriminationObserver` conformances, and all tests use the new shape

**Given** `PitchDiscriminationTrial` frequency methods currently construct `Pitch` inline
**When** refactored
**Then** `note1Frequency` becomes `referenceFrequency` using `tuningSystem.frequency(for: referenceNote, referencePitch:)`
**And** `note2Frequency` becomes `targetFrequency` using `tuningSystem.frequency(for: targetNote, referencePitch:)`
**And** both methods require explicit `tuningSystem` and `referencePitch` parameters

**Given** `CompletedPitchDiscriminationTrial` has fields `comparison.note1`, `comparison.note2`
**When** accessed through the refactored `PitchDiscriminationTrial` struct
**Then** all code paths use `comparison.referenceNote`, `comparison.targetNote`

**Given** `PitchMatchingRecord.referenceNote`, `PitchMatchingTrial.referenceNote`, `CompletedPitchMatchingTrial.referenceNote` already use correct naming
**When** the rename is complete
**Then** these names remain unchanged

**Given** this is a rename and type change with no functional changes
**When** the full test suite is run
**Then** all tests pass with no behavioral changes

### Story 22.5: Extract SoundSourceProvider Protocol

As a **developer building interval training**,
I want a `SoundSourceProvider` protocol extracted from `SoundFontLibrary` so that `SettingsScreen` depends on the protocol via `@Environment`, not the concrete library,
So that the Settings feature is decoupled from the audio implementation.

**Acceptance Criteria:**

**Given** `SettingsScreen` directly depends on `SoundFontLibrary`
**When** `SoundSourceProvider` protocol is created with `availableSources` and `displayName(for:)`
**Then** `SoundFontLibrary` conforms to `SoundSourceProvider`
**And** `SettingsScreen` depends on `SoundSourceProvider` via `@Environment`

**Given** `SoundSourceProvider.swift` is created in `Core/Audio/`
**When** the protocol is used
**Then** `SettingsScreen` has no import of or reference to `SoundFontLibrary`

**Given** the sound source picker in Settings
**When** it renders available sources
**Then** behavior is identical to before the refactoring
**And** the full test suite passes

## Epic 23: Intervals Everywhere — Generalize Training for Intervals

Both comparison and pitch matching sessions accept interval parameters, data models record full interval context, the adaptive algorithm computes interval-aware targets, and training screens show the target interval — generalizing the training experience from unison-only to any musical interval. All frequency computations flow through the two-world bridge: `TuningSystem.frequency(for:referencePitch:)`. No tuning system parameter has a default value.

### Story 23.1: Data Model and Value Type Updates for Interval Context

As a **developer building interval training**,
I want `PitchDiscriminationRecord` and `PitchMatchingRecord` to carry `interval` and `tuningSystem` fields, `PitchMatchingTrial` and `CompletedPitchMatchingTrial` to carry `targetNote`, and all value types confirmed compatible with the two-world architecture,
So that every training result records full interval context for data integrity and future analysis.

**Acceptance Criteria:**

**Given** `PitchDiscriminationRecord` has `referenceNote`, `targetNote`, `centOffset`, `isCorrect`, `timestamp`
**When** `interval: Interval` and `tuningSystem: TuningSystem` fields are added
**Then** the SwiftData schema accepts the new fields
**And** `TrainingDataStore` saves and loads both
**And** `interval` is stored explicitly for efficient querying (even though it is derivable from `referenceNote` and `targetNote`)

**Given** `PitchMatchingRecord` has `referenceNote`, `initialCentOffset`, `userCentError`, `timestamp`
**When** `targetNote: MIDINote`, `interval: Interval`, and `tuningSystem: TuningSystem` fields are added
**Then** `TrainingDataStore` saves and loads all new fields
**And** `targetNote` represents the note the user was trying to match (equals `referenceNote` for unison)

**Given** `PitchDiscriminationTrial` already has `referenceNote: MIDINote` and `targetNote: DetunedMIDINote` (from Story 22.4)
**When** no structural changes are needed to `PitchDiscriminationTrial`
**Then** its shape is confirmed correct for interval training — `targetNote.note` is the transposed note, `targetNote.offset` is the training cent offset

**Given** `CompletedPitchDiscriminationTrial` value type
**When** `tuningSystem: TuningSystem` field is added
**Then** `PitchDiscriminationSession` populates it from its session-level parameter
**And** `TrainingDataStore` (as `PitchDiscriminationObserver`) persists it to `PitchDiscriminationRecord`

**Given** `PitchMatchingTrial` value type
**When** `targetNote: MIDINote` field is added
**Then** it represents the correct interval note the user should tune toward
**And** for unison: `targetNote == referenceNote`
**And** for intervals: `targetNote == referenceNote.transposed(by: interval)`

**Given** `CompletedPitchMatchingTrial` value type
**When** `targetNote: MIDINote` and `tuningSystem: TuningSystem` fields are added
**Then** `PitchMatchingSession` populates them from session-level parameters
**And** `TrainingDataStore` (as `PitchMatchingObserver`) persists them to `PitchMatchingRecord`

**Given** no production user base exists
**When** SwiftData schema changes are applied
**Then** no `SchemaMigrationPlan` is needed — fresh schema version is acceptable

### Story 23.2: PitchDiscriminationSession Start Rename and Strategy Interval Support

As a **developer building interval training**,
I want `PitchDiscriminationSession.startTraining()` renamed to `start()`, reading `intervals` and `tuningSystem` from `userSettings`, `NextPitchDiscriminationStrategy` to compute interval-aware targets using `MIDINote.transposed(by:)`, and `currentInterval`/`isIntervalMode` observable state,
So that pitch comparison training works with any musical interval while unison (`[.prime]`) behaves identically to current behavior (FR66).

**Acceptance Criteria:**

**Given** `UserSettings` protocol has no `intervals` or `tuningSystem` properties
**When** `intervals: Set<Interval>` and `tuningSystem: TuningSystem` are added to the protocol
**Then** `AppUserSettings` returns hardcoded `[.perfectFifth]` for `intervals` and `.equalTemperament` for `tuningSystem` (no UserDefaults backing yet)
**And** `MockUserSettings` exposes both as mutable properties for test injection

**Given** `PitchDiscriminationSession` has a `startTraining()` method
**When** it is renamed to `start()`
**Then** it reads `intervals` and `tuningSystem` from the injected `userSettings`
**And** the interval set must be non-empty (enforced by precondition)

**Given** a training session with `intervals: [.prime]`
**When** comparisons are generated
**Then** behavior is identical to pre-interval implementation — `targetNote.note == referenceNote`

**Given** a training session with `intervals: [.perfectFifth]`
**When** a comparison is generated
**Then** the strategy picks a reference note, then `targetNote.note = referenceNote.transposed(by: .perfectFifth)`
**And** `targetNote` is a `DetunedMIDINote` with the training cent offset applied
**And** reference note selection constrains the upper bound by `interval.semitones` to keep `targetNote.note` within MIDI range (0–127)

**Given** `NextPitchDiscriminationStrategy` protocol
**When** it gains `interval: Interval` and `tuningSystem: TuningSystem` parameters (no defaults)
**Then** `KazezNoteStrategy` computes `targetNote.note` from the interval via `transposed(by:)`

**Given** the frequency computation for playback
**When** the session needs to play the reference and target notes
**Then** reference frequency uses `tuningSystem.frequency(for: referenceNote, referencePitch:)`
**And** target frequency uses `tuningSystem.frequency(for: targetNote, referencePitch:)` where `targetNote` is the `DetunedMIDINote`

**Given** `PitchDiscriminationSession` has `currentInterval` and `isIntervalMode` properties
**When** `currentInterval` is `.prime`
**Then** `isIntervalMode` returns `false`
**When** `currentInterval` is `.perfectFifth`
**Then** `isIntervalMode` returns `true`

**Given** `CompletedPitchDiscriminationTrial` now carries `tuningSystem`
**When** `PitchDiscriminationObserver` (TrainingDataStore) receives it
**Then** `tuningSystem` is persisted to `PitchDiscriminationRecord`

### Story 23.3: PitchMatchingSession Start Rename, Interval Support, and Protocol Update

As a **developer building interval training**,
I want `PitchMatchingSession.startPitchMatching()` renamed to `start()`, reading `intervals` and `tuningSystem` from `userSettings`, and `start()` pulled up into the `TrainingSession` protocol,
So that pitch matching training works with any musical interval while unison (`[.prime]`) behaves identically to current behavior (FR66), and both session types share a common start interface.

**Acceptance Criteria:**

**Given** `PitchMatchingSession` has a `startPitchMatching()` method
**When** it is renamed to `start()`
**Then** it reads `intervals` and `tuningSystem` from the injected `userSettings`
**And** the interval set must be non-empty (enforced by precondition)

**Given** a pitch matching session with `intervals: [.prime]`
**When** a challenge is generated
**Then** `targetNote == referenceNote` — identical to pre-interval behavior

**Given** a pitch matching session with `intervals: [.perfectFifth]`
**When** a challenge is generated
**Then** `targetNote = referenceNote.transposed(by: .perfectFifth)`
**And** `initialCentOffset` is applied relative to the target note
**And** reference note selection constrains the upper bound by `interval.semitones`

**Given** the reference note frequency for playback
**When** the session computes it
**Then** it uses `tuningSystem.frequency(for: referenceNote, referencePitch:)`

**Given** the detuned starting frequency for the tunable note
**When** the session computes it
**Then** it uses `tuningSystem.frequency(for: DetunedMIDINote(note: targetNote, offset: Cents(initialCentOffset)), referencePitch:)`

**Given** the slider adjusts the tunable note in real time
**When** `adjustPitch` and `commitPitch` are called
**Then** they apply cent-based frequency arithmetic relative to the already-computed reference frequency
**And** this remains physical-world arithmetic (no bridge crossing needed)

**Given** `userCentError` represents deviation from the correct interval pitch
**When** the session computes it
**Then** it measures cents between user's final frequency and the correct target frequency (FR64)

**Given** `CompletedPitchMatchingTrial` carries `targetNote` and `tuningSystem`
**When** `PitchMatchingObserver` (TrainingDataStore) receives it
**Then** both fields are persisted to `PitchMatchingRecord`

**Given** `PitchMatchingSession` has `currentInterval` and `isIntervalMode` properties
**When** `currentInterval` is `.perfectFifth`
**Then** `isIntervalMode` returns `true`

**Given** `TrainingSession` protocol currently requires `stop()` and `isIdle`
**When** `start()` is added to the protocol
**Then** both `PitchDiscriminationSession` and `PitchMatchingSession` satisfy the requirement through their renamed `start()` methods
**And** any holder of a `TrainingSession` reference can call `start()` without knowing the concrete type

### Story 23.4: Training Screen Interval Label and Observer Verification

As a **developer building interval training**,
I want both `PitchDiscriminationScreen` and `PitchMatchingScreen` to show a conditional target interval label when in interval mode, and verify that observers/profiles handle the updated value types,
So that users see what interval they're training and all data flows correctly through the system.

**Acceptance Criteria:**

**Given** `PitchDiscriminationScreen` receives an `intervals` parameter
**When** `session.isIntervalMode` is `true`
**Then** a `Text` label showing the current interval name (e.g., "Perfect Fifth Up") is visible at the top of the screen, below navigation buttons and above the training interaction area
**And** the label uses `.headline` or `.title3` styling

**Given** `PitchDiscriminationScreen` is entered in unison mode (`intervals: [.prime]`)
**When** `session.isIntervalMode` is `false`
**Then** no interval label is visible — the screen looks exactly as pre-v0.3

**Given** `PitchMatchingScreen` receives an `intervals` parameter
**When** `session.isIntervalMode` is `true`
**Then** a `Text` label showing the current interval name is visible at the top
**When** `session.isIntervalMode` is `false`
**Then** no interval label is visible

**Given** the target interval label
**When** VoiceOver is active
**Then** it reads "Target interval: Perfect Fifth Up" (or equivalent accessible label)

**Given** `PitchDiscriminationObserver` and `PitchMatchingObserver` receive updated value types with `tuningSystem` and `targetNote`
**When** interval training results flow through the observer path
**Then** profiles receive all data regardless of interval — no filtering, no interval-aware aggregation
**And** all frequency computations in screens flow through `TuningSystem.frequency(for:referencePitch:)`

## Epic 24: Four Modes, One App — Start Screen Integration

Users see four training modes on the Start Screen and can launch interval comparison or interval pitch matching with a single tap, starting with the perfect fifth interval.

### Story 24.1: NavigationDestination Parameterization and Routing

As a **musician using Peach**,
I want the navigation system to route interval training modes to the existing training screens with the correct interval parameters,
So that tapping an interval button launches the same screen with the interval context passed through.

**Acceptance Criteria:**

**Given** `NavigationDestination` has a `.training` case
**When** it is renamed to `.pitchDiscrimination(intervals: Set<Interval>)`
**Then** all existing navigation to pitch comparison training uses `.pitchDiscrimination(intervals: [.prime])`

**Given** `NavigationDestination` has a `.pitchMatching` case
**When** it gains an `intervals` parameter as `.pitchMatching(intervals: Set<Interval>)`
**Then** all existing navigation to pitch matching uses `.pitchMatching(intervals: [.prime])`

**Given** the destination handler in `ContentView`
**When** routing `.pitchDiscrimination(let intervals)`
**Then** `PitchDiscriminationScreen(intervals: intervals)` is created
**And** the screen calls `session.start()`

**Given** the destination handler routing `.pitchMatching(let intervals)`
**When** navigating
**Then** `PitchMatchingScreen(intervals: intervals)` is created
**And** the screen calls `session.start()`

**Given** `NavigationDestination` conforms to `Hashable`
**When** `Set<Interval>` is a parameter
**Then** the enum remains `Hashable` (since `Interval` is `Hashable`)

### Story 24.2: Start Screen Four Training Buttons

As a **musician using Peach**,
I want to see four training buttons on the Start Screen — Comparison, Pitch Matching, Interval Comparison, and Interval Pitch Matching — with a visual separator between unison and interval groups,
So that I can launch any training mode with a single tap (FR65).

**Acceptance Criteria:**

**Given** the Start Screen
**When** it loads
**Then** four training buttons are visible in a vertical stack:
1. "Comparison" — `.borderedProminent` style (hero action, unchanged position)
2. "Pitch Matching" — `.bordered` style
3. A subtle visual separator (spacing or divider)
4. "Interval Comparison" — `.bordered` style
5. "Interval Pitch Matching" — `.bordered` style

**Given** the "Interval Comparison" button
**When** tapped
**Then** it navigates to `.pitchDiscrimination(intervals: [.perfectFifth])` (FR56, FR67)

**Given** the "Interval Pitch Matching" button
**When** tapped
**Then** it navigates to `.pitchMatching(intervals: [.perfectFifth])` (FR60, FR67)

**Given** the "Comparison" button
**When** tapped
**Then** it navigates to `.pitchDiscrimination(intervals: [.prime])` — unchanged behavior

**Given** the "Pitch Matching" button
**When** tapped
**Then** it navigates to `.pitchMatching(intervals: [.prime])` — unchanged behavior

**Given** the Start Screen layout
**When** viewed in portrait and landscape on iPhone and iPad
**Then** all four buttons are accessible and the visual separator is visible
**And** the one-handed, thumb-friendly layout is preserved

## Epic 25: Directed Intervals — Full Interval Training

The system supports directed intervals (ascending and descending), allowing musicians to train interval recognition in both directions. Users can select which directed intervals are active for training via the Settings screen.

### Story 25.1: Direction Enum and DirectedInterval

As a **musician using Peach**,
I want interval training to distinguish between ascending and descending intervals,
So that I can train my ear to recognize intervals in both directions for comprehensive musicianship.

**Acceptance Criteria:**

**Given** the Core/Audio domain
**When** a `Direction` enum is defined
**Then** it supports `.up` and `.down` cases
**And** conforms to `Hashable`, `Comparable`, `Sendable`, `CaseIterable`, `Codable`
**And** has a `displayName` property returning localized "Up" or "Down"

**Given** the Core/Audio domain
**When** a `DirectedInterval` value type is created from an `Interval` and a `Direction`
**Then** it stores both components
**And** conforms to `Hashable`, `Comparable`, `Sendable`, `Codable`
**And** has a `displayName` property (e.g., "Perfect Fifth Up", "Major Third Down", "Prime")
**And** provides static factories: `.prime`, `.up(_)`, `.down(_)`

**Given** a `MIDINote`
**When** transposed by a `DirectedInterval`
**Then** `.up` adds semitones and `.down` subtracts semitones
**And** precondition enforces result stays in MIDI range 0–127

**Given** the training system APIs
**When** a training session starts
**Then** `TrainingSession.start(intervals: Set<DirectedInterval>)` is the protocol signature
**And** `PitchDiscriminationSession`, `PitchMatchingSession`, and `NextPitchDiscriminationStrategy` use `DirectedInterval`
**And** `KazezNoteStrategy` adjusts note range bounds for downward transposition

**Given** the navigation and settings system
**When** training mode buttons are tapped
**Then** `NavigationDestination` cases use `Set<DirectedInterval>`
**And** `UserSettings.intervals` returns `Set<DirectedInterval>`

### Story 25.2: Interval Selector on Settings Screen

As a **musician using Peach**,
I want to select which directed intervals are active for training on the Settings screen,
So that I can customize my interval ear training to focus on specific intervals and directions.

**Acceptance Criteria:**

**Given** the Settings screen
**When** the user scrolls to the Intervals section
**Then** a two-row grid displays with row headers ⏶ (up) and ⏷ (down)
**And** columns for all 13 intervals: P1, m2, M2, m3, M3, P4, d5, P5, m6, M6, m7, M7, P8
**And** each cell is a toggle button showing the interval abbreviation
**And** the Prime (P1) column only has an active toggle in the Up row

**Given** the user toggles intervals on/off in the selector
**When** the app is restarted
**Then** the previously selected intervals are restored via UserDefaults
**And** the default value is `[.up(.perfectFifth)]`

**Given** the interval selector with exactly one interval active
**When** the user attempts to deactivate the last remaining interval
**Then** the toggle is prevented — the user cannot reach an empty selection state

**Given** the user has selected specific intervals in Settings
**When** the user taps "Interval Comparison" or "Interval Pitch Matching" on the Start screen
**Then** the training session uses the user-selected intervals
**And** unison-mode buttons continue using `[.prime]` regardless of settings

## Epic 26: Pitch Matching UX Refinements

Pitch matching training UX is refined with delayed target note playback, repositioned feedback, and a tighter pitch range for more precise training.

### Story 26.1: Delay targetNote Until Slider Touch

As a **musician using Peach**,
I want the target note to play only when I first touch the pitch slider,
So that I have a moment of silence to internalize the reference pitch before the tunable note begins.

**Acceptance Criteria:**

**Given** the reference note has finished playing
**When** the session transitions from `playingReference`
**Then** the state becomes `awaitingSliderTouch` (not `playingTunable`)
**And** no tunable note is playing yet

**Given** the session is in `awaitingSliderTouch` state
**When** the user first touches the slider
**Then** the tunable note begins playing and the state transitions to `playingTunable`

**Given** the new state machine: `idle` → `playingReference` → `awaitingSliderTouch` → `playingTunable` → `showingFeedback` → (loop)
**When** multiple challenges are completed in sequence
**Then** each cycle includes the `awaitingSliderTouch` pause
**And** audio interruptions, background, and route changes all stop cleanly from any state

### Story 26.2: Reposition Feedback Indicator Above Slider

As a **musician using Peach's pitch matching mode**,
I want the feedback indicator positioned above the slider near the top of the screen,
So that my dragging finger does not obscure the feedback while I am adjusting pitch.

**Acceptance Criteria:**

**Given** the pitch matching session is in `showingFeedback` state
**When** the feedback indicator appears
**Then** it is rendered in a dedicated area above the `VerticalPitchSlider`
**And** positioned in the upper portion of the pitch matching screen

**Given** the feedback indicator appears and disappears during the training loop
**When** the state transitions between `showingFeedback` and other states
**Then** the slider does not jump or resize — layout remains stable

**Given** the session is in interval mode
**When** the interval label and feedback indicator are both relevant
**Then** the interval label remains visible at the top
**And** the feedback indicator is positioned below the interval label but above the slider

### Story 26.3: Reduce Pitch Matching Range

As a **musician using Peach's pitch matching mode**,
I want the pitch matching range reduced from ±100 cents to ±20 cents,
So that the slider provides finer granularity for precise pitch comparison training.

**Acceptance Criteria:**

**Given** a pitch matching session is active
**When** a new challenge is generated
**Then** the initial random cent offset is within the range -20.0 to +20.0 cents
**And** the slider's full travel maps to ±20.0 cents

**Given** the user releases the slider to commit their pitch
**When** `commitPitch` is called with the final normalized slider value
**Then** the cent offset is calculated using the ±20 cent range

## Epic 27: SoundFontNotePlayer Quality

SoundFontNotePlayer's `play()` method is decomposed into intent-revealing sub-operations, and a stress test suite is created to hunt for preset-specific crashes.

### Story 27.1: Decompose Play Method

As a **developer maintaining SoundFontNotePlayer**,
I want the `play()` method decomposed into named sub-operations at a uniform abstraction level,
So that the method reads as a clear sequence of intent-revealing steps and each sub-operation can be understood and modified independently.

**Acceptance Criteria:**

**Given** the `play()` method
**When** it is refactored
**Then** it reads as a short sequence of named calls — no inline implementation details remain in the body
**And** each extracted method has a single responsibility at a consistent abstraction level
**And** no behavioral change — all existing `SoundFontNotePlayerTests` pass without modification
**And** all extracted methods are `private`
**And** no new files — refactoring stays within `SoundFontNotePlayer.swift`

### Story 27.2: Preset Crash Investigation Tests

As a **developer maintaining SoundFontNotePlayer**,
I want a systematic test suite that iterates all SF2 presets across the MIDI note range with varied durations and velocities,
So that any preset-specific crashes are detected and root causes can be identified.

**Acceptance Criteria:**

**Given** a new `SoundFontPresetStressTests.swift` test file
**When** gated by `RUN_STRESS_TESTS` environment variable
**Then** tests iterate all melodic presets discovered by `SoundFontLibrary`
**And** exercise multiple MIDI note values, durations, and velocity levels per preset
**And** report which preset/note/duration combination causes a failure
**And** regular test suite still passes without `RUN_STRESS_TESTS`

## Epic 28: Domain Foundations Audit — Adam Reviews the Music Layer

The music domain expert audits all domain types and the full NotePlayer pipeline for hidden assumptions, musical correctness, and readiness for non-12-TET tuning systems.

### Story 28.1: Audit Interval and TuningSystem Domain Types

As a **developer preparing to add alternative tuning systems**,
I want the music domain expert to audit Interval, DirectedInterval, Direction, TuningSystem, MIDINote, DetunedMIDINote, Frequency, and Cents for hidden musical assumptions and correctness,
So that domain-level errors are caught before building on these foundations.

**Acceptance Criteria:**

**Given** each domain type in `Core/Audio/`
**When** reviewed by the music domain expert
**Then** a written audit report is produced
**And** hidden 12-TET assumptions in types claiming to be tuning-system-agnostic are flagged
**And** the `TuningSystem.centOffset(for:)` and `TuningSystem.frequency(for:referencePitch:)` methods are verified
**And** the two-world architecture (logical vs. physical, bridged by TuningSystem) is assessed for soundness
**And** the audit report is saved in `docs/implementation-artifacts/`

### Story 28.2: Audit NotePlayer and Frequency Computation Chain

As a **developer preparing to add alternative tuning systems**,
I want the music domain expert to audit the full pipeline from domain types through `TuningSystem.frequency()` to `SoundFontNotePlayer`,
So that implementation-level errors, hidden assumptions, and precision issues are caught before building non-12-TET playback on these foundations.

**Acceptance Criteria:**

**Given** the complete forward pipeline
**When** reviewed by the music domain expert
**Then** `TuningSystem.frequency()` → `NotePlayer.play()` → `SoundFontNotePlayer.startNote()` is verified
**And** the inverse pipeline (`decompose()`) is verified for mathematical correctness
**And** the end-to-end precision chain is verified to maintain ≤0.1-cent accuracy
**And** the pipeline's behavior with non-12-TET cent offsets (>50¢ from 12-TET grid) is assessed
**And** the `NotePlayer` protocol boundary taking `Frequency` (not `DetunedMIDINote`) is assessed
**And** the audit report is saved in `docs/implementation-artifacts/`

## Epic 29: Tuning System Landscape — Research Practical Alternatives to 12-TET

The music domain expert researches which tuning systems beyond 12-TET are used by musicians in practice, assessing practical relevance, pedagogical value, and architectural fit to recommend the most relevant first implementation.

> **Depends on:** Epic 28

### Story 29.1: Research Tuning Systems Used by Musicians in Practice

As a **developer preparing to add alternative tuning systems to Peach**,
I want the music domain expert to research which tuning systems beyond 12-TET are actually used by musicians in practice,
So that the implementation targets the most practically relevant tuning system.

**Acceptance Criteria:**

**Given** the major tuning system families (equal temperaments, just intonation, Pythagorean, well temperaments, meantone, non-Western)
**When** surveyed by the music domain expert
**Then** each is classified by practical usage frequency and ear training relevance

**Given** the Peach architecture constraints from Epic 28
**When** candidates are evaluated
**Then** each is assessed for architectural fit with `centOffset(for:)` and the ±200 cent pipeline limit

**Given** the research findings
**When** a recommendation is made
**Then** a single most relevant tuning system is recommended with clear rationale
**And** the complete cent offset table for all 13 intervals (P1–P8) is provided
**And** the research report is saved in `docs/implementation-artifacts/`

## Epic 30: Implement Most Relevant Tuning System

The recommended tuning system from Epic 29 — 5-limit just intonation — is implemented as a new `TuningSystem` case, with a Settings picker and a tuning system indicator on interval training screens.

> **Depends on:** Epic 29

### Story 30.1: Add Just Intonation Tuning System Case

As a **developer extending Peach's tuning system support**,
I want to add a `.justIntonation` case to the `TuningSystem` enum with its complete `centOffset(for:)` implementation,
So that the app can compute interval frequencies using 5-limit just intonation ratios.

**Acceptance Criteria:**

**Given** `TuningSystem` enum
**When** inspecting its cases
**Then** a new `.justIntonation` case exists alongside `.equalTemperament`

**Given** `TuningSystem.justIntonation`
**When** calling `centOffset(for:)` for each of the 13 intervals (P1–P8)
**Then** it returns the 5-limit just intonation cent values (e.g., P5=701.955, M3=386.314, P8=1200.000)

**Given** `TuningSystem.justIntonation`
**When** computing `frequency(for:referencePitch:)`
**Then** the result is accurate to within 0.1 cent of the theoretical value
**And** no changes to the method implementation are needed — it works via the universal cents-based formula

**Given** no other source files besides `TuningSystem.swift` and its test file
**When** this story is complete
**Then** no changes were made to training, data, or session logic (FR55 verification)

### Story 30.2: Add Tuning System Picker to Settings

As a **musician using Peach**,
I want to select between Equal Temperament and Just Intonation in the Settings screen,
So that I can train my ear with the tuning system that matches my musical context.

**Acceptance Criteria:**

**Given** the Settings screen Audio section
**When** viewing the options
**Then** a "Tuning System" Picker lists both "Equal Temperament" and "Just Intonation"

**Given** a fresh install
**When** opening Settings
**Then** "Equal Temperament" is selected by default

**Given** `AppUserSettings.tuningSystem`
**When** called
**Then** it reads the live value from UserDefaults (no longer hardcoded to `.equalTemperament`)
**And** unknown or corrupted values fall back to `.equalTemperament`

**Given** the Tuning System Picker
**When** displayed in English and German
**Then** display names and section footer text are properly localized

### Story 30.3: Add Tuning System Indicator to Interval Training Screens

As a **musician training intervals in Peach**,
I want to see which tuning system is active on the interval training screens,
So that I know whether I'm training with Equal Temperament or Just Intonation intervals.

**Acceptance Criteria:**

**Given** an interval training session
**When** `isIntervalMode` is true
**Then** the active tuning system's `displayName` is shown below the interval name as secondary text

**Given** a unison (prime) training session
**When** `isIntervalMode` is false
**Then** no tuning system indicator is shown

**Given** the tuning system indicator
**When** VoiceOver is active
**Then** the interval name and tuning system are combined into a single accessible label

**Given** `PitchDiscriminationSession.sessionTuningSystem` and `PitchMatchingSession.sessionTuningSystem`
**When** read from a view
**Then** they return the tuning system captured at `start()`

---

## Epic 31: Structured Notes — NoteRange Refactoring

Replace scattered `noteRangeMin`/`noteRangeMax` pairs with a domain-wide `NoteRange` value type that validates its own constraints and is reused across settings, training sessions, strategy, and profile visualization.

### Story 31.1: Create NoteRange Value Type

As a **developer**,
I want a validated `NoteRange` value type that encapsulates a lower and upper MIDI note bound,
So that note range constraints are expressed once and reused throughout the codebase.

**Acceptance Criteria:**

**Given** a new `NoteRange` struct in `Core/Audio/`
**When** it is created with `lowerBound: MIDINote` and `upperBound: MIDINote`
**Then** it validates that `upperBound` is at least 12 semitones above `lowerBound`
**And** invalid ranges are rejected at construction time (fatalError or throwing initializer, consistent with `MIDINote` pattern)

**Given** a valid `NoteRange`
**When** `contains(_ note: MIDINote)` is called
**Then** it returns `true` if the note is within `[lowerBound, upperBound]`, `false` otherwise

**Given** a valid `NoteRange`
**When** `clamped(_ note: MIDINote)` is called
**Then** it returns the note clamped to `[lowerBound, upperBound]`

**Given** a valid `NoteRange`
**When** `semitoneSpan` is accessed
**Then** it returns `upperBound.rawValue - lowerBound.rawValue`

**Given** `NoteRange`
**When** checked for protocol conformance
**Then** it conforms to `Equatable`, `Sendable`, and `Hashable`

**Given** the `NoteRange` type
**When** unit tests are run
**Then** all computed properties, validation, and edge cases are covered

### Story 31.2: Adopt NoteRange in UserSettings and Settings Screen

As a **developer**,
I want `UserSettings` to expose a single `noteRange: NoteRange` instead of separate `noteRangeMin`/`noteRangeMax`,
So that all consumers work with a validated range object.

**Acceptance Criteria:**

**Given** the `UserSettings` protocol
**When** it is updated
**Then** `noteRangeMin: MIDINote` and `noteRangeMax: MIDINote` are replaced by `noteRange: NoteRange`

**Given** `AppUserSettings`
**When** it implements the updated protocol
**Then** it constructs `NoteRange` from the two `@AppStorage` values
**And** the `@AppStorage` keys remain unchanged (backward compatible)

**Given** `SettingsScreen`
**When** the user adjusts the note range steppers
**Then** validation is performed through `NoteRange` (minimum 12-semitone gap)
**And** the two-stepper UX remains unchanged

**Given** `SettingsKeys`
**When** default range values are accessed
**Then** they are expressed as a `NoteRange` (default: C2–C6)

**Given** all existing tests
**When** the test suite is run
**Then** all tests pass with the updated interface

### Story 31.3: Adopt NoteRange in Training Sessions and Strategy

As a **developer**,
I want training sessions and the note selection strategy to accept `NoteRange` instead of separate min/max values,
So that range handling is consistent and validated at the boundary.

**Acceptance Criteria:**

**Given** `TrainingSettings`
**When** it is updated
**Then** `noteRangeMin`/`noteRangeMax` are replaced by `noteRange: NoteRange`

**Given** `PitchDiscriminationSession`
**When** it reads settings for a new comparison
**Then** it passes `NoteRange` to the strategy

**Given** `PitchMatchingSession`
**When** it reads settings for a new challenge
**Then** it uses `NoteRange` for note selection

**Given** the `NextPitchDiscriminationStrategy` protocol and `KazezNoteStrategy`
**When** they receive a `NoteRange`
**Then** they use `noteRange.contains(_:)` and `noteRange.clamped(_:)` for boundary enforcement
**And** upper bound shrinking for intervals uses `NoteRange` arithmetic

**Given** `MockNextPitchDiscriminationStrategy` and other test mocks
**When** updated
**Then** they accept `NoteRange` consistent with the protocol change

### Story 31.4: Adopt NoteRange in Profile and Visualization

As a **developer**,
I want profile computation and keyboard visualization to use `NoteRange`,
So that range references are consistent domain-wide.

**Acceptance Criteria:**

**Given** `PerceptualProfile`
**When** it references the displayed note range
**Then** it uses `NoteRange`

**Given** `PianoKeyboardView`
**When** it receives range parameters
**Then** it accepts `NoteRange` instead of separate min/max values

**Given** any other code that references `noteRangeMin`/`noteRangeMax` individually
**When** the codebase is searched
**Then** no direct min/max pairs remain — all are expressed through `NoteRange`

**Given** the full test suite
**When** run after all adoptions
**Then** all tests pass

---

## Epic 32: Everything in Its Place — Settings Screen Reorganization

Settings are grouped logically and ordered for intuitive discoverability, preparing a clean home for new features like export and import.

### Story 32.1: Reorganize Settings Screen Sections

As a **musician using Peach**,
I want settings grouped logically and in a sensible order,
So that I can find and understand settings intuitively.

**Acceptance Criteria:**

**Given** the current `SettingsScreen`
**When** it is reorganized
**Then** sections are reordered into logical groups (proposed order to be confirmed during implementation):
1. **Training Range** — note range (the most fundamental constraint)
2. **Intervals** — which intervals to train
3. **Sound** — instrument/sound source, note duration, reference pitch, tuning system
4. **Difficulty** — vary loudness (and any future difficulty parameters)
5. **Data** — reset, and later export/import

**Given** each section
**When** it is displayed
**Then** it has a clear, descriptive section header
**And** settings within each section are ordered from most-used to least-used

**Given** the reorganized screen
**When** viewed on iPhone and iPad in portrait and landscape
**Then** all settings remain accessible and functional
**And** no settings are lost or duplicated

**Given** the reorganized screen
**When** German localization is active
**Then** all section headers and labels are properly translated

---

## Epic 33: Take Your Data — Training Data Export

Users can export all training data as a single CSV file for analysis in spreadsheet applications, with a format designed for extensibility as new training types are added.

### Story 33.1: Define and Document CSV Export Schema

As a **developer**,
I want a well-defined CSV schema for training data export,
So that the format is clear, extensible, and spreadsheet-friendly.

**Acceptance Criteria:**

**Given** the export schema
**When** it is defined
**Then** it uses a `trainingType` discriminator column with values like `comparison` and `pitchMatching`
**And** common columns are: `trainingType`, `timestamp`, `referenceNote`, `referenceNoteName`, `targetNote`, `targetNoteName`, `interval`, `tuningSystem`
**And** pitch-comparison-specific columns are: `centOffset`, `isCorrect`
**And** pitch-matching-specific columns are: `initialCentOffset`, `userCentError`
**And** non-applicable cells are left empty

**Given** the `timestamp` column
**When** a record is exported
**Then** it uses ISO 8601 format (e.g., `2026-03-03T14:30:00Z`)

**Given** the `referenceNoteName` and `targetNoteName` columns
**When** a record is exported
**Then** they contain human-readable note names (e.g., `C4`, `A#3`) alongside the MIDI numbers

**Given** a future training type
**When** it is added to the app
**Then** new type-specific columns can be appended without breaking existing exports

### Story 33.2: Implement CSV Export Service

As a **developer**,
I want an export service that generates a CSV file from all training records,
So that the export logic is testable and decoupled from the UI.

**Acceptance Criteria:**

**Given** a `TrainingDataExporter` (or similar) in `Core/Data/`
**When** `export()` is called
**Then** it queries all `PitchDiscriminationRecord`s and `PitchMatchingRecord`s from `TrainingDataStore`
**And** generates a CSV string with headers and data rows
**And** rows are sorted by timestamp (ascending)

**Given** the generated CSV
**When** opened in a spreadsheet application
**Then** columns are correctly separated and parseable
**And** special characters in note names do not break parsing

**Given** no training data exists
**When** `export()` is called
**Then** it returns only the header row (or indicates empty data)

**Given** the export service
**When** unit tests are run
**Then** CSV generation is verified for both record types, mixed data, edge cases, and empty data

### Story 33.3: Add Export UI to Settings Screen

As a **musician using Peach**,
I want to export my training data from the Settings screen,
So that I can analyze my progress in a spreadsheet.

**Acceptance Criteria:**

**Given** the Settings Screen data section
**When** it is displayed
**Then** an "Export Training Data" button is visible

**Given** training data exists
**When** the user taps "Export Training Data"
**Then** a system share sheet appears with a CSV file
**And** the filename follows the pattern `peach-training-data-YYYY-MM-DD.csv`

**Given** no training data exists
**When** the export button is displayed
**Then** it is disabled or shows a message indicating no data to export

**Given** the share sheet
**When** the user selects a sharing target (Files, AirDrop, etc.)
**Then** the CSV file is shared successfully

---

## Epic 34: Bring Your Data — Training Data Import

Users can import training data from CSV with the choice to replace all existing data or merge with duplicate detection.

### Story 34.1: Implement CSV Import Parser

As a **developer**,
I want a parser that reads the export CSV format and converts rows back to record objects,
So that import logic is testable and decoupled from the UI.

**Acceptance Criteria:**

**Given** a valid CSV file matching the export schema
**When** it is parsed
**Then** each row is mapped to the correct record type based on the `trainingType` column
**And** `PitchDiscriminationRecord` fields are populated: referenceNote, targetNote, centOffset, isCorrect, interval, tuningSystem, timestamp
**And** `PitchMatchingRecord` fields are populated: referenceNote, targetNote, initialCentOffset, userCentError, interval, tuningSystem, timestamp

**Given** a CSV with invalid headers
**When** it is parsed
**Then** a descriptive validation error is returned

**Given** a CSV with rows containing invalid data (out-of-range MIDI notes, non-numeric cent values, etc.)
**When** it is parsed
**Then** invalid rows are collected as errors with row numbers
**And** valid rows are still parsed successfully

**Given** the parser
**When** unit tests are run
**Then** parsing is verified for valid data, missing columns, invalid values, empty files, and mixed record types

### Story 34.2: Implement Merge Logic with Duplicate Detection

As a **developer**,
I want merge and replace strategies for imported data,
So that users can choose how to combine imported data with existing records.

**Acceptance Criteria:**

**Given** a duplicate is defined as a record matching on `timestamp` + `referenceNote` + `targetNote` + `trainingType`
**When** merge mode is selected
**Then** only non-duplicate records are inserted
**And** existing records are not modified

**Given** replace mode is selected
**When** import is executed
**Then** all existing training data is deleted
**And** all imported records are inserted

**Given** an import operation completes
**When** the result is returned
**Then** it includes a summary: records imported, records skipped (duplicates), records with errors

**Given** the merge and replace logic
**When** unit tests are run
**Then** both modes are verified including edge cases: empty import, all duplicates, mixed valid/invalid rows

### Story 34.3: Add Import UI with Replace/Merge Choice

As a **musician using Peach**,
I want to import training data from a CSV file and choose whether to replace or merge,
So that I can restore backups or combine data from multiple devices.

**Acceptance Criteria:**

**Given** the Settings Screen data section
**When** it is displayed
**Then** an "Import Training Data" button is visible

**Given** the user taps "Import Training Data"
**When** the file picker appears
**Then** it filters for CSV files

**Given** a CSV file is selected
**When** it is validated successfully
**Then** a choice dialog appears: "Replace All Data" vs "Merge with Existing Data"
**And** the "Replace All Data" option warns that existing data will be permanently deleted

**Given** the user confirms their choice
**When** the import completes
**Then** a summary is shown: number of records imported, skipped, and errors
**And** the perceptual profile is rebuilt from the updated data

**Given** the CSV file contains validation errors
**When** it is imported
**Then** the user sees a clear error message describing the issue

---

## Epic 35: Welcome Home — Start Screen Redesign

The Start Screen greets users with approachable training names, suitable icons, and a more inviting visual design.

### Story 35.1: Rename Training Buttons with User-Friendly Labels

As a **musician using Peach**,
I want the training buttons to have approachable, descriptive names,
So that I understand what each training mode does without needing music theory knowledge.

**Acceptance Criteria:**

**Given** the Start Screen training buttons
**When** they are displayed
**Then** the labels use user-friendly names (e.g., "Hear & Compare", "Tune & Match", "Hear Intervals", "Tune Intervals" — final names to be confirmed during implementation)

**Given** the German localization
**When** the Start Screen is displayed in German
**Then** the button labels are appropriately translated

**Given** all navigation and accessibility labels
**When** buttons are renamed
**Then** VoiceOver labels accurately describe each training mode

### Story 35.2: Add SF Symbol Icons to Training Buttons

As a **musician using Peach**,
I want each training button to have a suitable icon,
So that the Start Screen is more visually appealing and the modes are quickly distinguishable.

**Acceptance Criteria:**

**Given** each training button
**When** it is displayed
**Then** it shows a leading SF Symbol icon that visually represents the training mode

**Given** dynamic type sizes
**When** the user changes text size
**Then** icons scale appropriately alongside the text

**Given** VoiceOver
**When** a button is focused
**Then** the icon does not add redundant accessibility information (decorative)

### Story 35.3: Visual Design Polish

As a **musician using Peach**,
I want the Start Screen to feel welcoming and well-designed,
So that opening the app is an inviting experience.

**Acceptance Criteria:**

**Given** the Start Screen
**When** it is displayed
**Then** spacing, typography, and layout are improved over the current plain button stack
**And** training buttons use a card-style or visually distinct treatment (final design to be confirmed during implementation)

**Given** the Start Screen layout
**When** viewed in portrait and landscape on iPhone and iPad
**Then** the layout adapts gracefully to all form factors
**And** the one-handed, thumb-friendly design principle is preserved

**Given** navigation to Profile, Settings, and Info
**When** the screen is redesigned
**Then** all navigation paths remain accessible and discoverable

---

## Epic 36: Speak Clearly — Localization & Wording Polish

All German translations and English wordings are reviewed and improved through interactive dialog, ensuring the app communicates clearly and naturally in both languages.

### Story 36.1: Interactive Localization and Wording Review

As a **musician using Peach**,
I want all text in the app to be clear, natural, and consistent in both English and German,
So that the app feels polished and professional regardless of language.

**Acceptance Criteria:**

**Given** all strings in `Localizable.xcstrings`
**When** they are reviewed interactively with the developer
**Then** awkward, unclear, or inconsistent wordings are identified and discussed

**Given** approved wording changes
**When** they are applied
**Then** both English and German translations are updated in `Localizable.xcstrings`

**Given** all strings after the review
**When** the localization catalog is checked
**Then** no missing translations remain for either language

**Given** the updated wordings
**When** the app is used in German
**Then** all text reads naturally and uses consistent terminology throughout

**Note:** This story is inherently interactive — the developer and agent review strings together in dialog, discussing alternatives and agreeing on improvements. It cannot be fully automated.

---

## Epic 37: Show Me How — Built-in Help

Users can access contextual help on the Start Screen, Settings Screen, and Training Screens to understand what the app does, what each setting controls, and how to interact with training.

### Story 37.1: Start Screen Help

As a **new user of Peach**,
I want to understand what this app is about and what the different training modes do,
So that I can choose the right training for my goals.

**Acceptance Criteria:**

**Given** the Start Screen
**When** a help trigger is activated (e.g., info button, help icon — exact mechanism to be decided during implementation)
**Then** a help view appears explaining:
- What Peach is and its purpose (ear training / pitch comparison)
- What each training mode does in plain language
- How to get started

**Given** the help content
**When** displayed in English or German
**Then** all text is properly localized

**Given** the help view
**When** the user dismisses it
**Then** they return to the Start Screen without side effects

### Story 37.2: Settings Screen Help

As a **musician using Peach**,
I want to understand what each setting does,
So that I can configure the app to match my training goals.

**Acceptance Criteria:**

**Given** the Settings Screen
**When** help is accessed (per-section info buttons, a help sheet, or inline descriptions — exact mechanism to be decided during implementation)
**Then** each setting group has a clear explanation of what it controls and why a user might change it

**Given** settings with non-obvious implications (e.g., tuning system, vary loudness, reference pitch)
**When** their help is viewed
**Then** the explanation includes practical context (e.g., "Most musicians use 440 Hz. Some orchestras tune to 442 Hz.")

**Given** the help content
**When** displayed in English or German
**Then** all text is properly localized

### Story 37.3: Training Screen Help

As a **musician using Peach**,
I want to understand the goal of the current training and how to use the controls,
So that I can focus on training rather than figuring out the interface.

**Acceptance Criteria:**

**Given** a Training Screen (comparison or pitch matching)
**When** help is accessed (e.g., help button — must not interfere with training flow)
**Then** a help view explains:
- The goal of this specific training mode
- How to interact with the controls (buttons for comparison, slider for pitch matching)
- What the feedback indicators mean

**Given** interval training mode
**When** the help is shown
**Then** it additionally explains what interval training means and how it differs from unison

**Given** the help trigger
**When** it is available during active training
**Then** accessing help pauses or stops the current training (no state corruption)

**Given** the help content
**When** displayed in English or German
**Then** all text is properly localized

---

## Epic 38: See Your Strengths — Perceptual Profile Visualization ✅ Done

Users see a useful and easily understandable visualization of their perceptual profile that encourages them by showing progress and highlights weak spots where further training would give the most improvement.

### Story 38.1: Brainstorm and Design Profile Visualization

As the **product team**,
We want to explore visualization concepts through interactive brainstorming,
So that we design a profile visualization that is encouraging, actionable, and understandable without music theory prerequisites.

**Acceptance Criteria:**

**Given** an interactive brainstorming session with the developer
**When** visualization concepts are explored
**Then** the following design goals are addressed:
- **Encouragement:** Users see their progress and feel motivated to continue
- **Weak spot identification:** Users see where further training would give the most improvement
- **Understandability:** The visualization makes sense without music theory background

**Given** the brainstorming output
**When** concepts are evaluated
**Then** at least 3 distinct visualization approaches are considered (e.g., heatmaps, progress arcs, radar charts, before/after comparisons, difficulty curves, achievement milestones)

**Given** a selected concept
**When** it is documented
**Then** a UX concept is produced with enough detail for implementation (layout sketches, data mapping, interaction patterns)
**And** the concept is approved by the developer before implementation begins

**Note:** Implementation stories (38.2+) defined after design approval in 38.1. Approved concept: Progress Timeline with Adaptive Buckets (see story file for full UX spec).

### Story 38.2: ProgressTimeline Core — EWMA, Adaptive Buckets, and TrainingDisciplineConfig

As a **developer**,
I want a core data pipeline that computes EWMA statistics over adaptive time buckets per training mode,
So that the profile visualization has a clean, testable, configurable data source.

**Acceptance Criteria:**

**Given** a `TrainingDisciplineConfig` struct
**When** it is initialized for any training mode
**Then** it centralizes all tuneable parameters: display name, unit label, optimal baseline, EWMA halflife, cold start thresholds, and bucket boundaries
**And** no magic numbers exist outside this configuration type

**Given** a set of `PitchDiscriminationRecord` entries for unison pitch comparison
**When** `ProgressTimeline` processes them
**Then** it groups records into adaptive time buckets (per-session for last 24h, per-day for last 7d, per-week for last 30d, per-month beyond)
**And** computes EWMA with the configured halflife (default 7 days)
**And** computes standard deviation per bucket
**And** pitch comparison mode uses `centOffset` on correct answers only as its metric

**Given** a set of `PitchMatchingRecord` entries
**When** `ProgressTimeline` processes them
**Then** matching mode uses `abs(userCentError)` as its metric
**And** the same EWMA and bucketing logic applies (parameterized, not duplicated)

**Given** `ProgressTimeline` is `@Observable`
**When** a new training record is added via observer protocol
**Then** it updates incrementally without re-scanning all records

**Given** fewer than 20 records for a training mode
**When** `ProgressTimeline` is queried
**Then** it reports cold-start state (no trend computation, limited display data)

**Technical hints:**
- New files: `Core/Profile/ProgressTimeline.swift`, `Core/Profile/TrainingDisciplineConfig.swift`
- Protocol: `TrainingDisciplineMetrics` for parameterization across modes
- Conforms to `PitchDiscriminationObserver` and `PitchMatchingObserver` for incremental updates
- All thresholds and parameters configurable via `TrainingDisciplineConfig`
- Reference approved UX concept in `docs/implementation-artifacts/38-1-brainstorm-and-design-profile-visualization.md`

### Story 38.3: ProgressChartView and Profile Screen Redesign

As a **user**,
I want to see my training progress on the Profile Screen as one card per training mode with a timeline chart,
So that I can understand how my ear training is improving over time.

**Depends on:** Story 38.2

**Acceptance Criteria:**

**Given** the user navigates to the Profile Screen
**When** they have training data for one or more modes
**Then** they see one card per trained mode, stacked vertically
**And** each card shows: headline EWMA value + stddev + trend indicator above the chart
**And** each card shows a chart with EWMA line, stddev band, and optimal baseline (dashed)
**And** modes with no data are not shown

**Given** the chart renders adaptive time buckets
**When** the user views it
**Then** recent time is shown in detail (per-session/per-day) and older time is compressed (per-week/per-month)
**And** bucket labels show appropriate time formats ("2h ago", "Mon", "Mar 1", "Jan")

**Given** fewer than 20 records for a mode
**When** the card is displayed
**Then** it shows an encouraging cold-start message instead of a chart
**And** for 1-19 records: "Keep going! X more sessions to see your trend"

**Given** the chart view
**When** it renders on iPhone and iPad in portrait and landscape
**Then** it adapts responsively using SwiftUI layout

**Given** the chart view
**When** VoiceOver is active
**Then** all visual elements have accessibility descriptions

**Technical hints:**
- New file: `Profile/ProgressChartView.swift` — single parameterized view taking `TrainingDisciplineMetrics`
- Refactor `ProfileScreen.swift` to card-based layout iterating over modes
- Use Apple Charts framework (AreaMark for stddev band, LineMark for EWMA, RuleMark for baseline)
- Old views (`ThresholdTimelineView`, `SummaryStatisticsView`, `MatchingStatisticsView`) replaced by new layout
- Reference approved UX concept in `docs/implementation-artifacts/38-1-brainstorm-and-design-profile-visualization.md`

### Story 38.4: Focus+Context Chart Interaction

As a **user**,
I want to tap a time region on my progress chart to see more detail,
So that I can explore specific periods of my training history.

**Depends on:** Story 38.3

**Acceptance Criteria:**

**Given** the progress chart on the Profile Screen
**When** the user taps a time bucket region
**Then** that bucket expands into finer granularity (month -> weeks, week -> days)
**And** surrounding buckets compress proportionally to maintain chart width
**And** the expansion animates smoothly

**Given** an expanded bucket region
**When** the user taps it again or taps a different region
**Then** the expanded region collapses back to its original bucket size
**And** the collapse animates smoothly

**Given** the focus+context interaction
**When** used with VoiceOver
**Then** the interaction is accessible (tap targets have labels, expanded state is announced)

**Technical hints:**
- Implemented within `ProgressChartView` using chart overlay gestures
- `ProgressTimeline` must support querying sub-buckets for a given time range
- Smooth SwiftUI animation for expand/collapse transitions
- Reference approved UX concept in `docs/implementation-artifacts/38-1-brainstorm-and-design-profile-visualization.md`

### Story 38.5: Start Screen Sparkline and Training Screen Summary

As a **user**,
I want a quick glance at my progress on the Start Screen and a text summary during training,
So that I feel encouraged without navigating to the full Profile Screen.

**Depends on:** Story 38.2

**Acceptance Criteria:**

**Given** the Start Screen
**When** the user has training data for one or more modes
**Then** a small sparkline appears for each trained mode (tiny EWMA line, no axes or labels)
**And** the sparkline is tinted green if improving, amber if stable, subtle gray if declining
**And** the current EWMA value appears beside it as small text (e.g., "8.2c")

**Given** the Start Screen
**When** the user has no training data
**Then** no sparklines are shown

**Given** a Training Screen (Comparison or Pitch Matching)
**When** the user is in a training session for a mode with sufficient data (20+ records)
**Then** a single-line text summary appears: "Current accuracy: X.X cents (improving/stable/declining)"

**Given** a Training Screen
**When** the user has fewer than 20 records for that mode
**Then** no accuracy summary is shown

**Technical hints:**
- New file: `Profile/SparklineView.swift` or `Start/ProgressSparklineView.swift`
- Sparkline reads from same `ProgressTimeline` data via environment
- Training screen text derived from `ProgressTimeline` EWMA value and trend
- Keep views thin — all computation in Core
- Reference approved UX concept in `docs/implementation-artifacts/38-1-brainstorm-and-design-profile-visualization.md`

---

## Epic 39: App Icon Redesign — AI-Generated Peach Icon

Users get a polished, professional app icon that clearly conveys "peach" and "hearing/sound", replacing the previous icon with a new AI-generated design assembled in Icon Composer with Liquid Glass effects.

### Story 39.1: App Icon Redesign

As a **musician using Peach**,
I want the app to have a polished, professional icon that clearly conveys "peach" and "hearing/sound",
so that the app looks credible on the App Store and my home screen, and communicates its ear-training purpose at a glance.

**Acceptance Criteria:**

**Given** the icon design, **when** viewed, **then** it prominently features a recognizable peach fruit that does NOT resemble a human posterior
**Given** the icon design, **when** viewed, **then** it incorporates a visual element representing hearing or sound integrated naturally with the peach
**Given** the icon design, **when** evaluated against Apple's iOS icon guidelines, **then** foreground layers have clearly defined edges, no baked-in shadows or specular highlights, and artwork is 1024x1024px in sRGB or Display P3 color space
**Given** the icon at small sizes (40x40px), **when** viewed on a home screen, **then** the design remains recognizable and the key elements are still distinguishable
**Given** the final icon, **when** assembled in Icon Composer and added to the Xcode project as a `.icon` file, **then** it replaces the existing `AppIcon` asset catalog entry and the build succeeds with zero warnings
**Given** the AI image generation process, **when** creating the icon, **then** a well-crafted prompt is developed through iteration, and the selected AI tool and final prompt are documented for reproducibility
**Given** the layered icon design, **when** assembled in Icon Composer, **then** the icon has at least a background layer and one foreground layer group, producing a Liquid Glass effect with depth and vitality

**Technical hints:**
- AI-generated foreground artwork on transparent background, assembled in Icon Composer
- Background color/gradient set in Icon Composer, not baked into artwork
- Output: `AppIcon.icon` file replacing existing `AppIcon.appiconset`
- No Swift code changes required

---

## Epic 40: Version Your Data — CSV Export Format Versioning

Exported CSV files include format version metadata so future app versions can correctly interpret and import data even if the format evolves, using a chain-of-responsibility architecture for versioned parsing.

### Story 40.1: Add CSV Format Version Metadata

As a **user who exports and imports training data**,
I want exported CSV files to contain a format version identifier,
so that future versions of the app can correctly interpret and import my data even if the format evolves.

**Acceptance Criteria:**

**Given** an export operation, **when** CSV files are generated, **then** a metadata line `# peach-export-format:1` appears as the very first line before the header row
**Given** an import operation, **when** a file is loaded, **then** a version reader extracts the format version from the metadata line before any parsing occurs
**Given** a file without a metadata line, **when** imported, **then** it is rejected with a clear error
**Given** a file with an unrecognized version, **when** imported, **then** a localized error tells the user to update the app
**Given** version-specific parsing, **when** a new format version is needed, **then** adding a new `CSVVersionedParser` conformance and registering it is sufficient — no changes to existing parsers or orchestrator
**Given** the existing v1 parsing logic, **when** the refactoring is complete, **then** all current parsing behavior is preserved exactly
**Given** existing export and import tests, **when** run after changes, **then** all pass with no regressions

**Technical hints:**
- Chain of responsibility: `CSVVersionedParser` protocol with version-specific conformances
- New version reader extracts format version before parsing
- Additive architecture: new versions require only a new conformance + registration

---

## Epic 41 Requirements (Profile Screen Chart UX Redesign)

**Source:** `docs/planning-artifacts/research/technical-profile-screen-chart-ux-research-2026-03-11.md`
**Context:** Third iteration of profile visualization. Research supersedes older planning artifacts for profile chart UX.

### Functional Requirements

FR1: Horizontally scrollable chart with multi-granularity timeline (months → days → sessions left-to-right)
FR2: Fixed Y-axis that remains visible while scrolling the chart body
FR3: Chart pinned to the right edge (most recent data) on initial display
FR4: Granularity zone separators with background tint, vertical dividers, and zone labels
FR5: Tap-to-select data points showing detail annotation (EWMA, stddev, date, record count)
FR6: TipKit help overlay system with sequential tips for chart elements (EWMA line, stddev band, baseline, zones)
FR7: Persistent "?" button in card header to replay all tips on demand
FR8: Narrative headlines above each chart ("Improved by 2.3¢ this week", variability callouts, baseline proximity)
FR9: Multi-granularity bucket concatenation from ProgressTimeline (monthly + daily + session-level)
FR10: Session-level markers in the rightmost zone for individual recent practice sessions

### Non-Functional Requirements

NFR1: WCAG 1.4.1 compliance — color must not be the sole information carrier for granularity zones
NFR2: VoiceOver accessibility — each zone needs an accessibility container with summary label
NFR3: Dynamic Type support — axis labels and headlines must use scaled fonts; Y-axis column width expands with font size
NFR4: Reduce Motion respect — scroll-to-position animation must check isReduceMotionEnabled
NFR5: Increase Contrast support — semantic colors and stronger contrast variants for chart elements
NFR6: Swift Charts performance — total data points must stay well under 2K; session-level data limited to 2-3 days

### Additional Requirements

- Use `.chartGesture` with `SpatialTapGesture` instead of `.chartOverlay` + `.onTapGesture` (iOS 18 scroll+tap conflict workaround)
- Data windowing for visible data slice to mitigate iOS 18 redraw loop with synchronized scroll positions
- Protocol-based `GranularityZoneConfig` following chain-of-responsibility pattern (new zones are additive, no changes to existing code)
- `NarrativeFormatter` and `ChartLayoutCalculator` as pure Core-layer functions (no UI dependencies, fully testable)

### FR Coverage Map

FR1: Epic 41, Story 41.2 — Horizontally scrollable multi-granularity timeline
FR2: Epic 41, Story 41.2 — Fixed Y-axis visible while scrolling
FR3: Epic 41, Story 41.2 — Chart pinned to right edge on load
FR4: Epic 41, Stories 41.1/41.3 — Granularity zone separators (tint + dividers + labels)
FR5: Epic 41, Story 41.4 — Tap-to-select data point annotations
FR6: Epic 41, Story 41.6 — TipKit sequential help overlay system
FR7: Epic 41, Story 41.7 — Persistent "?" button to replay tips
FR8: Epic 41, Story 41.8 — Narrative headlines above charts
FR9: Epic 41, Story 41.1 — Multi-granularity bucket concatenation from ProgressTimeline
FR10: Epic 41, Story 41.9 — Session-level markers for recent sessions

## Epic 41: Read Your Chart — Profile Screen Chart UX Redesign

Users can understand their training progress at a glance through a scrollable multi-granularity chart, contextual TipKit help overlays, narrative headlines, and session-level detail markers. The fixed Y-axis stays visible while scrolling, granularity zones are clearly labeled, and the chart opens pinned to the most recent data.

### Story 41.1: Multi-Granularity Bucket Pipeline

As a **developer**,
I want `ProgressTimeline` to produce concatenated multi-granularity buckets and a layout calculator to compute zone geometry,
So that the scrollable chart has a clean, testable data source with all granularity zones in a single ordered array.

**Acceptance Criteria:**

**Given** `ProgressTimeline` with training data spanning multiple months
**When** `allGranularityBuckets(for:)` is called
**Then** it returns `[TimeBucket]` ordered chronologically with months for data >30 days, days for 1–30 days, and sessions for <24 hours — all concatenated left-to-right
**And** each bucket retains its `BucketSize` tag so the UI can distinguish zones

**Given** the concatenated bucket array
**When** passed to `ChartLayoutCalculator`
**Then** it computes total chart width from bucket count x per-granularity point widths
**And** it returns zone boundary indices marking where granularity transitions occur

**Given** a `GranularityZoneConfig` protocol
**When** concrete conformances exist for `MonthlyZoneConfig`, `DailyZoneConfig`, `SessionZoneConfig`
**Then** each provides `pointWidth: CGFloat`, `backgroundTint: Color`, and `axisLabelFormatter: (Date) -> String`
**And** adding a new granularity (e.g., weekly) requires only a new conformance — no changes to existing code

**Given** a user with only 1 day of training data
**When** `allGranularityBuckets(for:)` is called
**Then** it returns only session-granularity buckets (no empty month/day zones)

**Given** the existing `buckets(for:)` API
**When** the new method is added
**Then** the existing API continues to work unchanged (no breaking changes)

**Technical hints:**
- Extend `ProgressTimeline` with `allGranularityBuckets(for:)` — do not modify `buckets(for:)`
- New files: `Core/Profile/ChartLayoutCalculator.swift`, `Core/Profile/GranularityZoneConfig.swift`
- `ChartLayoutCalculator` and `GranularityZoneConfig` conformances are pure Core (no SwiftUI import except `Color` in the config — or use a wrapper)
- TDD: write tests first in `PeachTests/Core/Profile/`

### Story 41.2: Scrollable Chart with Fixed Y-Axis

As a **user**,
I want to scroll horizontally through my training history with the Y-axis always visible,
So that I can explore my full progress timeline without losing context for what the numbers mean.

**Depends on:** Story 41.1

**Acceptance Criteria:**

**Given** the Profile Screen with a progress card
**When** the chart renders
**Then** it displays as an HStack with a fixed-width non-scrolling Y-axis on the left and a horizontally scrollable chart body on the right
**And** both share the same Y domain (`chartYScale(domain:)`) so vertical scales match

**Given** the scrollable chart
**When** it first appears
**Then** it is pinned to the right edge (most recent data) via `chartScrollPosition(initialX:)`

**Given** the scrollable chart with many months of data
**When** the user scrolls left
**Then** older data (monthly buckets) becomes visible
**And** scrolling is smooth with no frame drops on supported devices

**Given** the data for the visible viewport
**When** the chart renders
**Then** only the visible data slice plus a small buffer is passed to the chart (data windowing)
**And** this mitigates the known iOS 18 redraw loop with synchronized scroll positions

**Given** the fixed Y-axis
**When** the chart is scrolled
**Then** the Y-axis remains stationary and aligned with the scrollable chart body

**Technical hints:**
- Replace current `ProgressChartView` chart section with new HStack layout
- Fixed Y-axis: narrow `Chart` with `.chartXAxis(.hidden)` or plain `VStack` of labels
- Scrollable body: `Chart` with `.chartScrollableAxes(.horizontal)`, `.chartXVisibleDomain(length:)`, `.chartYAxis(.hidden)`
- Keep headline row (EWMA, stddev, trend arrow) unchanged for now
- Retain existing `AreaMark` (stddev band), `LineMark` (EWMA), `RuleMark` (baseline)

### Story 41.3: Granularity Zone Separators

As a **user**,
I want to see clear visual boundaries between monthly, daily, and session-level zones on my chart,
So that I understand the time scale changes as I scroll through my history.

**Depends on:** Story 41.2

**Acceptance Criteria:**

**Given** a chart with multiple granularity zones
**When** the chart renders
**Then** each zone has a subtle background tint using semantic colors (`Color(.systemBackground)` vs `Color(.secondarySystemBackground)`)
**And** a thin vertical divider line marks each zone boundary
**And** a small caption label at the top of each zone identifies it (e.g., "Monthly", "Daily", "Sessions" — localized DE+EN)

**Given** the zone separators
**When** viewed in Dark Mode
**Then** semantic colors adapt automatically with no hardcoded color values

**Given** the zone separators
**When** evaluated for WCAG 1.4.1 compliance
**Then** color is not the sole information carrier — the vertical divider line and zone label text also communicate the transition (NFR1)

**Given** a chart with only one granularity zone (e.g., new user with sessions only)
**When** the chart renders
**Then** no zone separators or labels are shown (nothing to separate)

**Technical hints:**
- Use `GranularityZoneConfig.backgroundTint` from 41.1 for zone tints
- Zone boundaries from `ChartLayoutCalculator` zone boundary indices
- Localize zone labels via `add-localization.py`
- `RectangleMark` or background `Rectangle` for tint areas; `RuleMark` for vertical dividers

### Story 41.4: Tap-to-Select Data Points

As a **user**,
I want to tap any data point on my chart to see its details,
So that I can inspect specific periods of my training history.

**Depends on:** Story 41.2

**Acceptance Criteria:**

**Given** the scrollable chart
**When** the user taps on or near a data point
**Then** a vertical selection indicator (`RuleMark`) appears at the selected X position
**And** an annotation popover shows: EWMA value, ± stddev, date/period label, and record count

**Given** a selected data point
**When** the user taps a different data point
**Then** the selection moves to the new point

**Given** a selected data point
**When** the user taps empty space or scrolls
**Then** the selection is dismissed

**Given** the annotation popover near a chart edge
**When** it renders
**Then** it uses `.overflowResolution(.fitToChart)` to prevent clipping

**Given** the scrollable chart
**When** the user drags to scroll
**Then** scrolling works normally — tap gestures do not block scroll gestures
**And** this uses `.chartGesture` with `SpatialTapGesture` (not `.chartOverlay` + `.onTapGesture`)

**Technical hints:**
- Use `.chartGesture` modifier (iOS 18+ safe, avoids scroll+tap conflict)
- `@State private var selectedBucketIndex: Int?` for selection state
- Annotation content: reuse `formatEWMA`, `formatStdDev`, `bucketLabel` from existing helpers
- Remove the disabled `chartExpansionEnabled` code path — this replaces that interaction model

### Story 41.5: Accessibility and Performance Hardening

As a **user with accessibility needs**,
I want the redesigned chart to work well with VoiceOver, Dynamic Type, Increase Contrast, and Reduce Motion,
So that the chart is usable regardless of my accessibility settings.

**Depends on:** Stories 41.2–41.4

**Acceptance Criteria:**

**Given** VoiceOver is active
**When** the user navigates to a progress card
**Then** each granularity zone has an accessibility container with a summary label (e.g., "Monthly view: November through January, pitch trend from 15 to 11 cents") (NFR2)

**Given** Dynamic Type is set to an accessibility size
**When** the chart renders
**Then** axis labels and headline text use scaled fonts
**And** the fixed Y-axis column width expands to accommodate larger text (NFR3)

**Given** Reduce Motion is enabled
**When** the chart appears with scroll-to-position
**Then** no scroll animation plays — the chart starts at the right edge without animating (NFR4)

**Given** Increase Contrast is enabled
**When** the chart renders
**Then** the EWMA line, stddev band, and baseline use stronger contrast variants via `UIAccessibility.darkerSystemColorsEnabled` (NFR5)

**Given** a user with extensive training history
**When** the chart renders with all granularity zones
**Then** total data point count stays well under 2,000 (NFR6)
**And** session-level data is limited to the last 2-3 days as defined by `allGranularityBuckets(for:)`

**Technical hints:**
- VoiceOver: `.accessibilityElement(children: .contain)` on zone containers with `.accessibilityLabel`
- Dynamic Type: use `.font(.caption)` (already scaled) for axis labels; test with `sizeCategory` environment override
- Reduce Motion: check `AccessibilityEnvironment.reduceMotion` or `UIAccessibility.isReduceMotionEnabled`
- Increase Contrast: conditional color modifiers checking `colorSchemeContrast` environment value

### Story 41.6: TipKit Help Overlay System

As a **first-time user**,
I want guided explanations of each chart element to appear one at a time,
So that I understand what the EWMA line, stddev band, baseline, and granularity zones mean without needing external documentation.

**Depends on:** Story 41.2

**Acceptance Criteria:**

**Given** the user views a progress card for the first time
**When** the card appears
**Then** an inline tip card displays above the chart: "This chart shows how your pitch perception is developing over time"

**Given** the user dismisses the first tip
**When** the next profile visit occurs
**Then** the next tip in the ordered sequence appears (EWMA line → stddev band → baseline → granularity zones)
**And** tips are managed via `TipGroup(.ordered)` so only one displays at a time

**Given** a tip is dismissed
**When** the user revisits the profile later
**Then** TipKit's built-in persistence ensures dismissed tips do not reappear
**And** display frequency is configured to avoid tip fatigue (e.g., `.weekly`)

**Given** VoiceOver is active
**When** a tip is displayed
**Then** the tip content is accessible and announced appropriately

**Technical hints:**
- Define tip structs: `ChartOverviewTip`, `EWMALineTip`, `StdDevBandTip`, `BaselineTip`, `GranularityZoneTip`
- Use `TipGroup(.ordered)` (iOS 18+)
- Inline tip: `TipView` above chart; popover tips: `.popoverTip()` on relevant chart elements
- New file: `Profile/ChartTips.swift`
- Localize all tip titles and messages (DE+EN) via `add-localization.py`

### Story 41.7: Help Button with Tip Reset

As a **returning user**,
I want a "?" button on each progress card that replays all chart help tips,
So that I can re-read the explanations whenever I need a refresher.

**Depends on:** Story 41.6

**Acceptance Criteria:**

**Given** a progress card header
**When** the card renders
**Then** a "?" button is visible in the card header area

**Given** all tips have been previously dismissed
**When** the user taps the "?" button
**Then** all chart tips are reset and the sequential tip flow restarts from the first tip

**Given** the "?" button
**When** VoiceOver is active
**Then** the button has an accessibility label "Show chart help"

**Technical hints:**
- Add "?" button to card header row (alongside mode title and trend arrow)
- On tap: call `Tips.resetDatastore()` scoped to chart tips, or invalidate display rules
- SF Symbol: `questionmark.circle`

### Story 41.8: Narrative Headlines

As a **user**,
I want plain-language progress summaries above my chart instead of just raw numbers,
So that I can understand whether I'm improving without interpreting the chart myself.

**Depends on:** Story 41.2

**Acceptance Criteria:**

**Given** the user's EWMA trend is improving
**When** the progress card headline renders
**Then** it shows a sentence like "Improved by 2.3¢ this week" (using the actual delta)

**Given** the user's stddev has widened significantly compared to prior periods
**When** the headline renders
**Then** it includes a variability callout like "More variable this week — fatigue or new difficulty?"

**Given** the user's EWMA approaches `optimalBaseline`
**When** the headline renders
**Then** it includes a proximity callout like "Approaching expert level (8¢)"

**Given** a stable trend with no notable variability change
**When** the headline renders
**Then** it shows a neutral summary like "Consistent at 10.1¢"

**Given** the `NarrativeFormatter`
**When** tested with all combinations of trend × variability × baseline proximity
**Then** it produces correct localized strings (DE+EN) for every combination
**And** it lives in Core with no UI dependencies

**Technical hints:**
- New file: `Core/Profile/NarrativeFormatter.swift` — pure function taking EWMA, stddev, trend, baseline, locale
- Integrates with existing `TrainingDisciplineConfig` metadata (baseline values, unit labels) and `ProgressTimeline` trend
- Replace or augment current headline row in `ProgressChartView`
- TDD: write tests first in `PeachTests/Core/Profile/NarrativeFormatterTests.swift`
- Localize via `add-localization.py`

### Story 41.9: Session-Level Detail Markers

As a **user**,
I want to see individual recent practice sessions as distinct markers on the rightmost chart zone,
So that I can reflect on specific sessions and understand what caused variability in my recent performance.

**Depends on:** Story 41.2

**Acceptance Criteria:**

**Given** session-granularity buckets in the rightmost chart zone
**When** individual sessions contain only 1 record group (single session)
**Then** a visible marker symbol (e.g., `PointMark` or `LineMark` with `.symbol()`) appears at each session data point
**And** markers are visually distinct from the EWMA line (different shape or emphasis)

**Given** a session marker
**When** the user taps it (using the existing tap-to-select from 41.4)
**Then** the annotation popover shows session-specific detail: date/time, duration, record count, mean accuracy

**Given** session-level data
**When** the chart renders
**Then** session markers only appear in the session-granularity zone (last 2-3 days)
**And** monthly and daily zones show only the EWMA line and stddev band as before

**Technical hints:**
- Add `PointMark` or symbol annotation within the session zone in the scrollable chart
- Session duration derivable from first-to-last record timestamp within the session bucket
- Reuse existing `TimeBucket` data — no new data source needed
- The existing tap-to-select (41.4) already handles annotation display

### Story 41.10: Year Label Positioning via AnnotationMark

As a **user**,
I want year labels below the chart X-axis to adapt correctly to different text sizes and devices,
So that the labels remain readable regardless of Dynamic Type or screen size.

**Depends on:** Story 41.3

**Acceptance Criteria:**

**Given** the chart with monthly buckets spanning multiple years
**When** year labels render
**Then** they are positioned using `AnnotationMark` (or equivalent Chart-native positioning) instead of a hardcoded Y-offset
**And** they adapt automatically to axis label height changes from Dynamic Type

**Given** year labels rendered via the new approach
**When** compared to the previous hardcoded offset rendering
**Then** the visual result is equivalent or better — no overlap with axis labels, no clipping

**Given** a chart with no monthly zone (new user)
**When** the chart renders
**Then** no year labels appear and no extra padding is added (same as current behavior)

**Technical hints:**
- Current implementation uses `chartOverlay` with `plotFrame.maxY + 28` — a hardcoded offset that doesn't adapt to Dynamic Type
- Investigate `AnnotationMark` positioning within the Chart block as a replacement
- If `AnnotationMark` doesn't support below-axis positioning, consider `chartBackground` or `alignmentGuide` alternatives
- The existing `yearLabels(for:)` static method provides the data; only the rendering approach needs to change
- Preserve the `yearLabelYOffset` constant as fallback if Chart-native positioning proves insufficient

---

## Epic 42 Requirements (Custom SoundFont Assembly)

**Source:** [Alternative GM SoundFont Research (2026-03-14)](research/technical-alternative-gm-soundfont-sf2-research-2026-03-14.md)

**Problem:** GeneralUser GS v2.0.3's piano presets crash on iPhone 17 Pro (A18 Pro) due to a bug in Apple's ARM-optimized sample interpolation code inside AVAudioUnitSampler. Device testing confirmed FluidR3_GM's piano does not crash. The solution is a custom SF2 combining FluidR3_GM piano with GeneralUser GS non-piano presets, assembled manually in Polyphone.

**Functional Requirements Addressed:**
- FR34: User can select the sound source
- FR16/FR17: System generates tones at precise frequencies with smooth envelopes (piano preset must not crash)

**Non-functional Requirements:**
- The custom SF2 should be committed to the repository (estimated ~35-40 MB)
- Source SF2 files should be downloadable via script for reproducibility
- SoundFontLibrary and SoundFontNotePlayer should not depend on a specific SF2's bank structure

## Epic 42: Fix Your Piano — Custom SoundFont Assembly

Replace the crashing GeneralUser GS piano presets with FluidR3_GM piano presets by assembling a custom SoundFont. Clean up SoundFontLibrary and SoundFontNotePlayer to work with any single SF2 file without hardcoded bank/program defaults.

### Story 42.1: Extend Download Script for Multiple SoundFont Sources

As a **developer**,
I want `bin/download-sf2.sh` to support downloading multiple SF2 files to `.cache`,
So that all source SoundFonts needed for the custom SF2 assembly are available locally and their integrity is verified.

**Acceptance Criteria:**

**Given** the download script and config
**When** `bin/download-sf2.sh` is run
**Then** it downloads all SF2 files listed in `bin/sf2-sources.conf` to `.cache/`
**And** each file's SHA-256 checksum is verified against the expected value in the config
**And** files that already exist with the correct checksum are skipped (idempotent)

**Given** `bin/sf2-sources.conf`
**When** a developer reads it
**Then** it contains entries for at least:
- GeneralUser GS v2.0.3 (existing entry — non-piano presets source)
- FluidR3_GM (MIT license — piano presets source)
- JNSGM2 (CC0 — reference/comparison)
**And** each entry includes: url, filename, sha256, license, and attribution fields

**Given** a download failure for one file
**When** the script runs
**Then** it reports the failure clearly and continues downloading remaining files
**And** exits with a non-zero status if any download failed

**Given** the config file format
**When** a developer needs to add a new SF2 source
**Then** they add a new entry block to `bin/sf2-sources.conf` following the existing format

**Technical hints:**
- Extend the existing `bin/sf2-sources.conf` to support multiple entries (e.g., INI-style sections or repeated key blocks separated by blank lines)
- The existing `bin/download-sf2.sh` handles single-file download with checksum — generalize the loop
- FluidR3_GM download URL: `https://sourceforge.net/projects/pianobooster/files/pianobooster/1.0.0/FluidR3_GM.sf2/download` (or a GitHub mirror for stability)
- JNSGM2 download URL: `https://github.com/wrightflyer/SF2_SoundFonts/raw/master/Jnsgm2.sf2`
- Xcode build should continue to reference the single assembled SF2 in `.cache/`, not the source files

### Story 42.2: Clean Up SoundFontLibrary and SoundFontNotePlayer Defaults

As a **developer**,
I want SoundFontLibrary to work with a single explicitly provided SF2 file and SoundFontNotePlayer to receive all configuration explicitly,
So that the audio code does not depend on a specific SF2's bank structure or hardcoded preset defaults.

**Acceptance Criteria:**

**Given** `SoundFontLibrary`
**When** initialized
**Then** it accepts an explicit SF2 URL (no scanning for all `.sf2` files in the bundle)
**And** it discovers presets only from that single SF2 file

**Given** `SoundFontNotePlayer`
**When** initialized
**Then** it does not use default arguments for `sf2Name` — the caller must provide it explicitly
**And** the default preset (program and bank) is provided explicitly at init, not hardcoded as constants
**And** the hardcoded `defaultPresetProgram = 80` and `defaultPresetBank = 8` are removed

**Given** the app's composition root (`PeachApp` or environment setup)
**When** it creates the SoundFontNotePlayer
**Then** it provides the SF2 filename and default preset explicitly
**And** changing which SF2 or default preset is used requires changing only the composition root, not the library or player

**Given** the existing test suite
**When** all tests are run after the refactor
**Then** all tests pass — behavior is unchanged, only the wiring is explicit

**Technical hints:**
- `SoundFontLibrary.init(bundle:)` → `SoundFontLibrary.init(sf2URL:)` — accept one URL, not a bundle scan
- `SoundFontNotePlayer.init(sf2Name:userSettings:stopPropagationDelay:)` → remove default for `sf2Name`, add explicit `defaultProgram: Int` and `defaultBank: Int` parameters
- Update `PeachApp` / `EnvironmentKeys` to wire the explicit values
- The default preset for the custom SF2 should be configurable — likely String Ensemble (bank 0, program 48) or whatever the custom SF2 uses as a neutral default
- `MockUserSettings` and test helpers may need updating for the new init signatures
- No behavioral changes — this is a wiring refactor only

---

## Epic 43: Share Your Progress — Sharing

Users can share training data via the system share sheet (replacing the file exporter) and share individual progress chart images from the Profile Screen.

### Story 43.1: Make CSV Export Data Transferable

As a **developer**,
I want a `Transferable` type that provides the CSV export as a file with the correct UTType,
So that `ShareLink` can share a properly typed .csv file that AirDrop and other targets handle correctly.

**Acceptance Criteria:**

**Given** a `Transferable` type for CSV export (e.g., `CSVExportFile` or conformance on an existing type)
**When** it provides its transfer representation
**Then** it uses `FileRepresentation` with UTType `.commaSeparatedText`
**And** the exported file has a `.csv` extension

**Given** the filename
**When** the file is created
**Then** it follows the pattern `peach-training-data-YYYY-MM-DD-HHmm.csv` (minute-precision timestamp)

**Given** the file is shared via AirDrop to a Mac
**When** the Mac receives it
**Then** the file has a `.csv` extension (not `.txt`)

**Given** the existing `CSVDocument` (`FileDocument` conformance)
**When** the new `Transferable` type is introduced
**Then** `CSVDocument` is either adapted to also conform to `Transferable` or replaced, depending on what is cleaner — the `.fileExporter()` usage in `SettingsScreen` will be removed in story 43.2

**Given** unit tests
**When** they verify the transfer representation
**Then** the UTType is `.commaSeparatedText` and the filename includes a minute-precision timestamp

**Design Note (from 43.1 code review):** `CSVDocument.transferRepresentation` calls `exportFileName()` at transfer time, generating a new timestamp on each invocation. When story 43.2 wires up `ShareLink`, consider capturing the export date when the `CSVDocument` is constructed (e.g., a stored `exportDate: Date` property) so the filename remains stable across share-sheet retries and multiple share targets.

### Story 43.2: Replace File Exporter with ShareLink in Settings

As a **musician using Peach**,
I want to share my training data from the Settings screen via the system share sheet,
So that I can send it via AirDrop, save to Files, email, or use any other sharing destination.

**Acceptance Criteria:**

**Given** the Settings Screen data section
**When** it is displayed
**Then** the "Export Training Data" button is present with its existing icon (`square.and.arrow.up`)

**Given** training data exists
**When** the user taps "Export Training Data"
**Then** the system share sheet appears with a .csv file attachment
**And** the share sheet includes destinations like AirDrop, Files, Messages, Mail

**Given** no training data exists
**When** the export button is displayed
**Then** it is disabled (same behavior as current implementation)

**Given** the user selects "Save to Files" in the share sheet
**When** iCloud Drive is available
**Then** the user can save the CSV to iCloud (same capability as the current `.fileExporter()`)

**Given** the current `.fileExporter()` modifier on `SettingsScreen`
**When** this story is implemented
**Then** the `.fileExporter()` modifier and its associated state (`showExporter`) are removed
**And** replaced with a `ShareLink` using the `Transferable` type from story 43.1

**Given** the import functionality (`.fileImporter()`)
**When** the export is changed to `ShareLink`
**Then** the import is unchanged — `.fileImporter()` remains as-is

**Given** the `TrainingDataTransferService`
**When** the export path changes to `ShareLink`
**Then** any state or methods that existed solely to support `.fileExporter()` are cleaned up if no longer needed

### Story 43.3: Render Progress Chart as Shareable Image

As a **developer**,
I want a view that renders a progress chart card as a static image suitable for sharing,
So that the chart image rendering is testable and decoupled from the share interaction.

**Acceptance Criteria:**

**Given** a training mode with data
**When** the export chart view is rendered
**Then** it includes: the headline row (mode display name, current EWMA value, stddev, trend arrow), the full chart visualization (EWMA line, stddev band, session dots, baseline, zone backgrounds), a localized timestamp, and a small "Peach" attribution text

**Given** the localized timestamp
**When** rendered in German locale
**Then** it shows a locale-appropriate format (e.g., "15. März 2026, 14:32")
**And** in English locale it shows the English format (e.g., "March 15, 2026, 2:32 PM")
**And** it uses standard `Date.FormatStyle` with locale-aware formatting

**Given** the export chart view
**When** compared to the live `ProgressChartView`
**Then** it excludes: the share button, interactive elements (selection indicator, tap gesture), tip views, and navigation chrome

**Given** SwiftUI `ImageRenderer`
**When** it renders the export chart view
**Then** it produces a raster image at `@2x` or device scale
**And** the background is a solid fill (not transparent) so the image looks complete outside the app

**Given** the rendered image filename
**When** it is generated
**Then** it follows the pattern `peach-{mode-slug}-{YYYY-MM-DD-HHmm}.png` where the mode slug is derived from the training mode (e.g., `pitch-comparison`, `pitch-matching`, `interval-comparison`, `interval-matching`)

### Story 43.4: Add Share Button to Progress Chart Cards

As a **musician using Peach**,
I want to share a progress chart image from the Profile Screen,
So that I can show my training progress to others.

**Acceptance Criteria:**

**Given** a `ProgressChartView` card on the Profile Screen
**When** it is displayed for a training mode with data
**Then** a share button (SF Symbol `square.and.arrow.up`) appears in the headline row, trailing after the trend arrow

**Given** the share button
**When** it is displayed
**Then** it is sized to match the headline text (not oversized — it's a secondary action)
**And** it scales with Dynamic Type alongside the headline row

**Given** the user taps the share button
**When** the chart has data
**Then** the system share sheet appears with the rendered chart image (from story 43.3)
**And** the image filename includes the training mode and a minute-precision timestamp

**Given** VoiceOver is active
**When** the share button is focused
**Then** VoiceOver reads "Share [mode display name] chart" (e.g., "Share Pitch Comparison chart")

**Given** the share button in the rendered export image
**When** the chart is rendered for sharing (story 43.3)
**Then** the share button is not visible in the exported image

---

## Epic 44: Solid Ground — Prerequisite Refactorings

Move domain value types from Core/Audio/ to Core/Music/ and clean up PerceptualProfile — removing stale tracking, normalizing naming, preparing for multi-mode extension. Pure refactoring with no functional changes, preparing the codebase for rhythm extension.

### Story 44.1: Split Core/Audio into Core/Music and Core/Audio

As a **developer**,
I want musical domain value types in their own Core/Music/ directory separate from audio infrastructure in Core/Audio/,
So that the codebase has clean separation between domain concepts and audio machinery before adding rhythm types.

**Acceptance Criteria:**

**Given** the following files currently in Core/Audio/: MIDINote.swift, DetunedMIDINote.swift, Frequency.swift, Cents.swift, Interval.swift, DirectedInterval.swift, Direction.swift, TuningSystem.swift, MIDIVelocity.swift, AmplitudeDB.swift, NoteDuration.swift, NoteRange.swift, SoundSourceID.swift
**When** the directory split is performed
**Then** all 13 files are moved to Core/Music/ with matching Xcode group structure

**Given** the following files remain in Core/Audio/: NotePlayer.swift, PlaybackHandle.swift, SoundFontNotePlayer.swift, SoundFontPlaybackHandle.swift, SoundFontLibrary.swift, SF2PresetParser.swift, SoundSourceProvider.swift, AudioSessionInterruptionMonitor.swift
**When** the directory split is performed
**Then** all 8 audio infrastructure files remain in Core/Audio/

**Given** test files that mirror the source structure
**When** the source files are moved
**Then** corresponding test files are moved to PeachTests/Core/Music/ (e.g., MIDINoteTests.swift, CentsTests.swift, etc.)

**Given** the single-module app architecture (no cross-module imports)
**When** all files are moved
**Then** the project builds with zero errors and zero warnings
**And** all existing tests pass without modification

**Given** this is a pure file-move refactoring
**When** the changes are reviewed
**Then** no type renames, no API changes, and no behavioral changes have occurred

### Story 44.2: Clean Up PerceptualProfile for Multi-Mode Extension

As a **developer**,
I want PerceptualProfile cleaned up with stale tracking removed and naming normalized,
So that it has clean extension points for the new RhythmProfile protocol conformance.

**Acceptance Criteria:**

**Given** PerceptualProfile currently contains per-MIDI-note comparison tracking
**When** the cleanup is performed
**Then** any unused per-MIDI-note tracking that doesn't serve current pitch training functionality is removed

**Given** PerceptualProfile conforms to PitchDiscriminationProfile and PitchMatchingProfile
**When** internal naming is reviewed
**Then** naming conventions are normalized to align with the protocol-first pattern (PitchDiscriminationProfile, PitchMatchingProfile, future RhythmProfile)

**Given** the cleanup is complete
**When** PerceptualProfile is inspected
**Then** it has clean extension points where new protocol conformances (e.g., RhythmProfile) can be added without modifying existing protocol conformances

**Given** all existing pitch comparison and pitch matching tests
**When** they are run after cleanup
**Then** all tests pass — no behavioral changes to existing functionality

### Story 44.3: Re-Architect Profile and Progress Responsibilities

As a **developer**,
I want PerceptualProfile to own all per-mode statistical state (Welford, EWMA, trend) and ProgressTimeline to be a pure presentation layer that reads from the profile,
So that domain truth lives in one place, storage coupling is removed, and both types have clear single responsibilities.

**Acceptance Criteria:**

**Given** PerceptualProfile currently tracks only 2 aggregates (comparison, matching)
**When** the refactoring is complete
**Then** it tracks 4 independent modes (unisonPitchDiscrimination, intervalPitchDiscrimination, unisonPitchMatching, intervalPitchMatching) with per-mode Welford statistics, EWMA, and trend

**Given** ProgressTimeline currently duplicates Welford's algorithm in its ModeState
**When** the refactoring is complete
**Then** a single shared ModeStatistics value type is used by PerceptualProfile, and ProgressTimeline contains no statistical computation of its own

**Given** ProgressTimeline currently conforms to PitchDiscriminationObserver and PitchMatchingObserver
**When** the refactoring is complete
**Then** only PerceptualProfile conforms to those observer protocols; ProgressTimeline receives no training events directly

**Given** ProgressTimeline currently takes storage records in its rebuild method
**When** the refactoring is complete
**Then** neither PerceptualProfile nor ProgressTimeline imports or references storage record types; record-to-metric mapping lives in the app composition layer

**Given** ProgressTimeline currently owns bucketing, EWMA, trend, and state queries
**When** the refactoring is complete
**Then** ProgressTimeline retains only time bucketing / chart formatting and delegates statistical queries to PerceptualProfile

**Given** all existing tests
**When** they are run after the refactoring
**Then** all tests pass — no behavioral changes to user-visible functionality

### Story 44.4: Typed Metrics, Generic Accumulator, and Incremental Profile Init

As a **developer**,
I want MetricPoint to carry typed measurement data, WelfordAccumulator to be generic over measurement type, and PerceptualProfile to initialize incrementally via a closure-based builder,
So that domain typing is preserved through the statistical pipeline, the accumulator is reusable for future measurement types (including 2D), and profile initialization doesn't require loading all records into memory at once.

**Acceptance Criteria:**

**Given** MetricPoint currently stores a bare `Double` value
**When** the refactoring is complete
**Then** MetricPoint carries a typed measurement (e.g., `Cents` for pitch comparisons) rather than an erased `Double`, and the type information is preserved through the statistical pipeline

**Given** WelfordAccumulator currently operates on `Double` with `Cents`-specific accessors (`centsMean`, `centsStdDev`) baked in
**When** the refactoring is complete
**Then** WelfordAccumulator is generic over measurement type, the statistical algorithm is separated from domain units, and `Cents`-specific accessors are removed from the accumulator itself

**Given** PerceptualProfile currently requires `rebuild(metrics: [TrainingDiscipline: [MetricPoint]])` which loads all records into a dictionary
**When** the refactoring is complete
**Then** `rebuild` is removed; PerceptualProfile offers a closure-based initializer where the closure receives an accumulator proxy with a single `addPoint` method, and derived computations (EWMA, trend) run once after the closure completes

**Given** PeachApp.loadPerceptualProfile currently fetches all records, maps them, and passes the full dictionary to `rebuild`
**When** the refactoring is complete
**Then** PeachApp uses the closure-based initializer, streaming records through MetricPointMapper into the proxy without materializing the full dataset

**Given** the closure-based initializer receives a proxy parameter
**When** the closure executes
**Then** the proxy is a separate type with only an `addPoint` method — not the profile itself — because the profile is not yet fully initialized during the closure

**Given** all existing tests
**When** they are run after the refactoring
**Then** all tests pass — no behavioral changes to user-visible functionality

## Epic 45: Rhythm Domain — Types and Contracts

Introduce TempoBPM, RhythmOffset, RhythmDirection domain types with full test coverage. Define the observer protocols (RhythmOffsetDetectionObserver, RhythmMatchingObserver) and completed-result value types. Define the RhythmProfile protocol.

### Story 45.1: TempoBPM Domain Type

As a **developer**,
I want a `TempoBPM` value type representing tempo in beats per minute,
So that all rhythm APIs use a domain type instead of raw `Int` values.

**Acceptance Criteria:**

**Given** `TempoBPM` with an `Int` value
**When** it is used across the codebase
**Then** it conforms to `Hashable`, `Sendable`, `Codable`, `Comparable`

**Given** a `TempoBPM` value
**When** `sixteenthNoteDuration` is computed
**Then** it returns `Duration.seconds(60.0 / (Double(value) * 4.0))`
**And** unit tests verify known values (e.g., 120 BPM → 125ms sixteenth note)

**Given** file location conventions
**When** the file is created
**Then** it is placed at `Core/Music/TempoBPM.swift` with tests at `PeachTests/Core/Music/TempoBPMTests.swift`

### Story 45.2: RhythmOffset and RhythmDirection Domain Types

As a **developer**,
I want `RhythmOffset` (signed duration) and `RhythmDirection` (early/late) types,
So that rhythm timing data uses domain types with direction derived from sign (FR99).

**Acceptance Criteria:**

**Given** `RhythmOffset` with a `Duration` value
**When** the duration is negative
**Then** `direction` returns `.early`

**Given** `RhythmOffset` with a positive or zero duration
**When** `direction` is accessed
**Then** it returns `.late` (zero treated as on-the-beat, classified as late per architecture)

**Given** a `RhythmOffset` and a `TempoBPM`
**When** `percentageOfSixteenthNote(at:)` is called
**Then** it returns `abs(duration / tempo.sixteenthNoteDuration) * 100` (FR87)
**And** unit tests verify known values (e.g., 12.5ms offset at 120 BPM = 10% of 125ms sixteenth note)

**Given** `RhythmDirection` enum
**When** inspected
**Then** it has cases `.early` and `.late` and conforms to `Hashable`, `Sendable`, `Codable`

**Given** `RhythmOffset`
**When** `Comparable` is applied
**Then** ordering is based on absolute magnitude (for difficulty comparison)

**Given** file location conventions
**When** files are created
**Then** `RhythmOffset.swift` and `RhythmDirection.swift` are in `Core/Music/` with corresponding tests

### Story 45.3: Rhythm Observer Protocols and Result Types

As a **developer**,
I want `RhythmOffsetDetectionObserver` and `RhythmMatchingObserver` protocols with their completed-result value types,
So that rhythm sessions can notify observers using the same pattern as pitch training.

**Acceptance Criteria:**

**Given** `RhythmOffsetDetectionObserver` protocol
**When** inspected
**Then** it declares `rhythmOffsetDetectionCompleted(_ result: CompletedRhythmOffsetDetectionTrial)`

**Given** `CompletedRhythmOffsetDetectionTrial` value type
**When** inspected
**Then** it contains `tempo: TempoBPM`, `offset: RhythmOffset`, `isCorrect: Bool`, `timestamp: Date`
**And** it conforms to `Sendable`

**Given** `RhythmMatchingObserver` protocol
**When** inspected
**Then** it declares `rhythmMatchingCompleted(_ result: CompletedRhythmMatchingTrial)`

**Given** `CompletedRhythmMatchingTrial` value type
**When** inspected
**Then** it contains `tempo: TempoBPM`, `expectedOffset: RhythmOffset`, `userOffset: RhythmOffset`, `timestamp: Date`
**And** it conforms to `Sendable`

**Given** file locations
**When** files are created
**Then** observer protocols are in `Core/Training/` and value types in `Core/Training/` with corresponding tests

### Story 45.4: RhythmProfile Protocol

As a **developer**,
I want a `RhythmProfile` protocol defining the contract for rhythm perceptual data,
So that sessions and views can depend on the protocol while PerceptualProfile provides the implementation.

**Acceptance Criteria:**

**Given** the `RhythmProfile` protocol
**When** inspected
**Then** it declares: `updateRhythmOffsetDetection(tempo:offset:isCorrect:)`, `updateRhythmMatching(tempo:userOffset:)`, `rhythmStats(tempo:direction:) -> RhythmTempoStats`, `trainedTempos: [TempoBPM]`, `rhythmOverallAccuracy: Double?`, `resetRhythm()`

**Given** the `RhythmTempoStats` struct
**When** inspected
**Then** it contains `mean: RhythmOffset`, `stdDev: RhythmOffset`, `sampleCount: Int`, `currentDifficulty: RhythmOffset`

**Given** the protocol file
**When** it is created
**Then** it is placed at `Core/Profile/RhythmProfile.swift` with `RhythmTempoStats` in the same file
**And** unit tests for `RhythmTempoStats` are created

## Epic 46: One Engine — Audio Architecture Redesign

Extract SoundFontEngine from SoundFontNotePlayer, refactor NotePlayer to delegate, then build RhythmPlayer protocol and SoundFontRhythmPlayer with sample-accurate render-thread scheduling. Includes an on-device POC — a temporary demo screen that plays a pre-computed rhythm pattern at a fixed tempo, proving that the three-layer audio architecture delivers audibly tight timing on real hardware. The POC is removed once rhythm training screens are in place.

### Story 46.1: Extract SoundFontEngine from SoundFontNotePlayer

As a **developer**,
I want a `SoundFontEngine` class that owns `AVAudioEngine`, `AVAudioUnitSampler`, and audio session configuration,
So that audio hardware ownership is consolidated in one place before adding rhythm playback.

**Acceptance Criteria:**

**Given** `SoundFontEngine` is created
**When** inspected
**Then** it owns `AVAudioEngine` and `AVAudioUnitSampler` (melodic) that were previously owned by `SoundFontNotePlayer`

**Given** `SoundFontEngine`
**When** it provides immediate MIDI dispatch
**Then** `startNote`/`stopNote` methods are available for pitch training (existing behavior)

**Given** `SoundFontEngine`
**When** it manages SoundFont preset loading
**Then** it loads presets for the melodic bank using existing `SoundFontLibrary` infrastructure

**Given** `SoundFontEngine` is a concrete internal class (not a protocol)
**When** created
**Then** it is placed at `Core/Audio/SoundFontEngine.swift` with tests at `PeachTests/Core/Audio/SoundFontEngineTests.swift`

### Story 46.2: Refactor SoundFontNotePlayer to Delegate to SoundFontEngine

As a **developer**,
I want `SoundFontNotePlayer` to delegate to `SoundFontEngine` instead of owning `AVAudioEngine` directly,
So that pitch training continues to work identically while sharing the engine with future rhythm playback.

**Acceptance Criteria:**

**Given** `SoundFontNotePlayer` is refactored
**When** it receives a `SoundFontEngine` dependency
**Then** it delegates all MIDI dispatch to the engine's immediate dispatch methods

**Given** the `NotePlayer` protocol
**When** inspected after refactoring
**Then** it is completely unchanged — no API changes

**Given** the `PlaybackHandle` protocol and `SoundFontPlaybackHandle`
**When** inspected after refactoring
**Then** `SoundFontPlaybackHandle` uses the engine's immediate dispatch but its public interface is unchanged

**Given** all existing pitch comparison and pitch matching tests
**When** run after refactoring
**Then** all tests pass without modification — no behavioral changes

### Story 46.3: Add Render-Thread Scheduling to SoundFontEngine

As a **developer**,
I want `SoundFontEngine` to support sample-accurate scheduled MIDI dispatch via an `AVAudioSourceNode` render callback,
So that rhythm patterns can be played with sub-millisecond timing precision (NFR-R1).

**Acceptance Criteria:**

**Given** `SoundFontEngine` with render-thread scheduling
**When** an `AVAudioSourceNode` is attached to the audio engine
**Then** it serves as the master clock on the audio render thread
**And** the source node outputs silence (it exists purely for its render callback)

**Given** a schedule of MIDI events with absolute sample offsets
**When** a render cycle occurs
**Then** the engine checks for events falling within the current buffer window
**And** dispatches them via `scheduleMIDIEventBlock` with the exact sample offset

**Given** the audio session
**When** rhythm scheduling is active
**Then** minimum buffer duration is configured to 5ms (0.005s) per FR96

**Given** the scheduling mechanism
**When** tested with known event times
**Then** scheduled vs. actual sample positions differ by no more than 0.01ms (NFR-R1)

### Story 46.4: RhythmPlayer Protocol and SoundFontRhythmPlayer

As a **developer**,
I want a `RhythmPlayer` protocol and `SoundFontRhythmPlayer` implementation,
So that rhythm sessions can play pre-computed patterns through a clean protocol boundary.

**Acceptance Criteria:**

**Given** the `RhythmPlayer` protocol
**When** inspected
**Then** it declares `play(_ pattern: RhythmPattern) async throws -> RhythmPlaybackHandle` and `stopAll() async throws`

**Given** the `RhythmPlaybackHandle` protocol
**When** inspected
**Then** it declares `stop() async throws` where first call silences audio and subsequent calls are no-ops

**Given** the `RhythmPattern` value type
**When** inspected
**Then** it contains `events: [Event]` (each with `sampleOffset: Int64`, `soundSourceID: SoundSourceID`, `velocity: MIDIVelocity`), `sampleRate: Double`, and `totalDuration: Duration`
**And** events use absolute sample offsets from pattern start (no relative deltas)

**Given** `SoundFontRhythmPlayer` delegates to `SoundFontEngine`
**When** `play(_:)` is called with a `RhythmPattern`
**Then** all pattern events are pre-calculated before playback starts (FR94)
**And** events are dispatched on the render thread via the engine's scheduling mechanism

**Given** `SoundFontRhythmPlayer`
**When** it loads percussion sounds
**Then** it resolves `SoundSourceID` values through the existing `SoundSourceProvider` pattern (FR95)

**Given** `MockRhythmPlayer` and `MockRhythmPlaybackHandle`
**When** created for testing
**Then** they are placed in `PeachTests/Mocks/` for use by session tests in later epics

**Given** file locations
**When** files are created
**Then** protocols are at `Core/Audio/RhythmPlayer.swift` and `Core/Audio/RhythmPlaybackHandle.swift`; implementations at `Core/Audio/SoundFontRhythmPlayer.swift` and `Core/Audio/SoundFontRhythmPlaybackHandle.swift`

### Story 46.5: On-Device Rhythm Timing POC

As a **developer testing the architecture**,
I want a temporary demo screen accessible from the Start Screen that plays a pre-computed 4-click rhythm pattern at a fixed tempo,
So that I can verify on real hardware that the three-layer audio architecture delivers audibly tight timing before building sessions on top of it.

**Acceptance Criteria:**

**Given** a temporary "Rhythm POC" button on the Start Screen
**When** tapped
**Then** it navigates to a minimal demo screen

**Given** the demo screen
**When** displayed
**Then** it shows a "Play Pattern" button and a tempo label (e.g., "120 BPM")

**Given** the user taps "Play Pattern"
**When** the button is tapped
**Then** the system plays 4 percussion clicks at sixteenth-note intervals at 120 BPM using `SoundFontRhythmPlayer`
**And** the pattern is pre-computed as a `RhythmPattern` with absolute sample offsets

**Given** the user taps "Play Pattern" again
**When** the previous pattern is still playing
**Then** the previous pattern is stopped before the new one starts

**Given** the demo screen
**When** a second tempo option is available (e.g., a stepper or toggle between 80/120/160 BPM)
**Then** the user can switch tempos and hear the pattern at different speeds to verify timing at various rates

**Given** this is a temporary POC
**When** rhythm training screens are implemented (Epics 48–49)
**Then** the POC screen and its Start Screen button are removed

**Given** the POC plays audio
**When** evaluated on a real iPhone
**Then** the 4 clicks sound evenly spaced with no audible jitter or drift — confirming the architecture works

## Epic 47: Remember Every Beat — Rhythm Data Layer

RhythmOffsetDetectionRecord and RhythmMatchingRecord SwiftData models, TrainingDataStore extension with rhythm CRUD and observer conformances, PerceptualProfile RhythmProfile conformance, ProgressTimeline extension to 6 modes.

### Story 47.1: Rhythm SwiftData Records

As a **developer**,
I want `RhythmOffsetDetectionRecord` and `RhythmMatchingRecord` SwiftData models,
So that rhythm training results can be persisted locally.

**Acceptance Criteria:**

**Given** `RhythmOffsetDetectionRecord` `@Model`
**When** inspected
**Then** it contains `tempoBPM: Int`, `offsetMs: Double` (signed, negative=early, positive=late), `isCorrect: Bool`, `timestamp: Date`

**Given** `RhythmMatchingRecord` `@Model`
**When** inspected
**Then** it contains `tempoBPM: Int`, `userOffsetMs: Double` (signed), `timestamp: Date`
**And** a comment reserves `inputMethod` for future non-tap input

**Given** the `ModelContainer` schema in `PeachApp.swift`
**When** updated
**Then** it includes `RhythmOffsetDetectionRecord.self` and `RhythmMatchingRecord.self` alongside existing pitch records

**Given** raw types at the SwiftData boundary
**When** compared with domain types
**Then** `Int`/`Double` are used at the persistence boundary (consistent with pitch record pattern), domain types at all other boundaries

### Story 47.2: TrainingDataStore Rhythm CRUD and Observer Conformance

As a **developer**,
I want `TrainingDataStore` extended with rhythm record CRUD and observer conformances,
So that rhythm results are automatically persisted when sessions notify observers.

**Acceptance Criteria:**

**Given** `TrainingDataStore`
**When** extended for rhythm
**Then** it provides: `save(_ record: RhythmOffsetDetectionRecord) throws`, `save(_ record: RhythmMatchingRecord) throws`, `fetchAllRhythmOffsetDetections() throws -> [RhythmOffsetDetectionRecord]`, `fetchAllRhythmMatching() throws -> [RhythmMatchingRecord]`, `deleteAllRhythmOffsetDetections() throws`, `deleteAllRhythmMatching() throws`

**Given** `TrainingDataStore` conforms to `RhythmOffsetDetectionObserver`
**When** `rhythmOffsetDetectionCompleted(_:)` is called
**Then** a `RhythmOffsetDetectionRecord` is created from the result and saved

**Given** `TrainingDataStore` conforms to `RhythmMatchingObserver`
**When** `rhythmMatchingCompleted(_:)` is called
**Then** a `RhythmMatchingRecord` is created from the result and saved

**Given** save errors
**When** they occur
**Then** they are logged via `os.Logger` at `.warning` level (consistent with existing error handling)

**Given** unit tests
**When** they verify CRUD operations
**Then** save, fetch, and delete work correctly for both record types

### Story 47.3: PerceptualProfile RhythmProfile Conformance

As a **developer**,
I want `PerceptualProfile` to conform to `RhythmProfile`,
So that rhythm statistics are tracked per-tempo with asymmetric early/late tracking (FR86).

**Acceptance Criteria:**

**Given** `PerceptualProfile` conforms to `RhythmProfile`
**When** `updateRhythmOffsetDetection(tempo:offset:isCorrect:)` is called
**Then** it updates per-(tempo, direction) statistics for rhythm comparison

**Given** `PerceptualProfile` conforms to `RhythmProfile`
**When** `updateRhythmMatching(tempo:userOffset:)` is called
**Then** it updates per-(tempo, direction) statistics for rhythm matching

**Given** `rhythmStats(tempo:direction:)` is called
**When** data exists for the given tempo and direction
**Then** it returns `RhythmTempoStats` with mean, stdDev, sampleCount, currentDifficulty

**Given** `trainedTempos`
**When** accessed
**Then** it returns all tempos that have any rhythm training data

**Given** `rhythmOverallAccuracy`
**When** accessed with rhythm data
**Then** it returns the combined overall accuracy for EWMA headline display (FR89)

**Given** `PerceptualProfile` on app startup
**When** rebuilt from stored records
**Then** it loads `RhythmOffsetDetectionRecord` and `RhythmMatchingRecord` data alongside existing pitch data

**Given** `resetRhythm()` is called
**When** executed
**Then** all rhythm statistics are cleared while pitch statistics remain untouched

### Story 47.4: ProgressTimeline Extension to Six Training Modes

As a **developer**,
I want `ProgressTimeline` and `TrainingDiscipline` extended to track six training modes,
So that rhythm training progress is tracked with EWMA smoothing and trend analysis.

**Acceptance Criteria:**

**Given** `TrainingDiscipline` enum
**When** extended
**Then** it has six cases: `unisonPitchDiscrimination`, `intervalPitchDiscrimination`, `unisonPitchMatching`, `intervalPitchMatching`, `rhythmOffsetDetection`, `rhythmMatching`

**Given** `TrainingDisciplineConfig` for each new rhythm mode
**When** configured
**Then** each has display name, unit label (percentage of sixteenth note), optimal baseline, EWMA half-life, and session gap

**Given** `ProgressTimeline`
**When** it conforms to `RhythmOffsetDetectionObserver` and `RhythmMatchingObserver`
**Then** it tracks rhythm training modes for trend analysis using the same bucketing as pitch modes

**Given** `HapticFeedbackManager`
**When** it conforms to `RhythmOffsetDetectionObserver`
**Then** it triggers haptic feedback on incorrect rhythm comparison answers (same pattern as pitch comparison)

**Given** all existing pitch progress tracking tests
**When** run after extension
**Then** they pass without modification

## Epic 48: Four Clicks — Rhythm Comparison Training

Full rhythm comparison training: session state machine, adaptive difficulty strategy with asymmetric early/late tracking, screen with dot visualization, Early/Late buttons, feedback line, and haptics. Users can start rhythm comparison from the Start Screen and train their timing detection.

### Story 48.1: NextRhythmOffsetStrategy Protocol and Initial Implementation

As a **developer**,
I want a `NextRhythmOffsetStrategy` that decides rhythm comparison challenge parameters based on asymmetric early/late profile data,
So that rhythm comparison difficulty adapts independently per direction (FR83).

**Acceptance Criteria:**

**Given** the `NextRhythmOffsetStrategy` protocol
**When** inspected
**Then** it declares `nextRhythmChallenge(profile:settings:lastResult:) -> RhythmChallenge`

**Given** the `RhythmChallenge` value type
**When** inspected
**Then** it contains `tempo: TempoBPM` and `offset: RhythmOffset` (signed — encodes direction + magnitude)

**Given** the initial implementation (e.g., `AdaptiveRhythmOffsetStrategy`)
**When** it selects the next challenge
**Then** it considers the profile's asymmetric early/late tracking and the last completed result to decide both direction and magnitude

**Given** the strategy receives a profile with no data
**When** selecting the first challenge
**Then** it provides a reasonable starting difficulty (analogous to 100 cents cold start for pitch)

**Given** unit tests with a `MockRhythmProfile`
**When** various profile states are tested
**Then** the strategy adapts difficulty appropriately — narrower on correct, wider on wrong, per direction

**Given** file locations
**When** created
**Then** protocol at `Core/Algorithm/NextRhythmOffsetStrategy.swift`, implementation at `Core/Algorithm/AdaptiveRhythmOffsetStrategy.swift`, challenge at `RhythmOffsetDetection/RhythmChallenge.swift`

### Story 48.2: RhythmOffsetDetectionSession State Machine

As a **developer**,
I want a `RhythmOffsetDetectionSession` that plays 4-note patterns and records Early/Late judgments,
So that the rhythm comparison training loop works end-to-end with proper state management.

**Acceptance Criteria:**

**Given** `RhythmOffsetDetectionSession` is `@Observable`
**When** inspected
**Then** it follows the state machine: `idle → playingPattern → awaitingAnswer → showingFeedback → loop`

**Given** `start()` is called
**When** the session transitions from idle
**Then** it calls `strategy.nextRhythmChallenge(profile:settings:lastResult:)` to get a `RhythmChallenge`
**And** builds a `RhythmPattern` with 4 events at sixteenth-note intervals, 4th shifted by the challenge offset
**And** calls `rhythmPlayer.play(pattern)` and awaits the handle

**Given** the pattern completes
**When** the session transitions to `awaitingAnswer`
**Then** the user can tap "Early" or "Late"

**Given** the user answers
**When** the answer is recorded
**Then** observers are notified with a `CompletedRhythmOffsetDetectionTrial`
**And** the session transitions to `showingFeedback` for ~400ms
**And** then automatically starts the next challenge

**Given** interruption occurs (navigation away, backgrounding, headphone disconnect)
**When** in any state other than idle
**Then** the session stops via `rhythmPlaybackHandle.stop()`, discards incomplete exercises, and transitions to idle (FR73, FR73a)

**Given** the session's constructor
**When** inspected
**Then** it accepts `rhythmPlayer: RhythmPlayer`, `strategy: NextRhythmOffsetStrategy`, `profile: RhythmProfile`, `observers: [RhythmOffsetDetectionObserver]`, `settingsOverride: TrainingSettings?`, `notificationCenter: NotificationCenter`

**Given** unit tests using `MockRhythmPlayer` and `MockNextRhythmOffsetStrategy`
**When** all state transitions are tested
**Then** full coverage of the state machine including interruption paths

### Story 48.3: RhythmOffsetDetectionScreen with Dot Visualization

As a **musician using Peach**,
I want a rhythm comparison screen showing dots that light up with each note and Early/Late buttons to answer,
So that I can train my ability to detect timing deviations.

**Acceptance Criteria:**

**Given** the Rhythm Comparison Screen
**When** displayed
**Then** it shows a summary stat line, 4 horizontal dots (~16pt diameter, ~24pt spacing), and side-by-side Early/Late buttons below (UX-DR12)

**Given** the dots
**When** a note plays
**Then** the corresponding dot transitions from dim (opacity 0.2) to lit (opacity 1.0) instantly, matching the percussive attack (UX-DR1)
**And** dots are `.accessibilityHidden(true)`

**Given** the Early/Late buttons
**When** the pattern is playing
**Then** both buttons are disabled
**When** the pattern completes (awaitingAnswer state)
**Then** both buttons are enabled (UX-DR2)

**Given** the buttons
**When** displayed
**Then** they show directional arrows (SF Symbols `arrow.left` / `arrow.right`) with `.borderedProminent` style, each taking half the width

**Given** the feedback line
**When** the user answers
**Then** it shows checkmark/cross + current difficulty as percentage (e.g., "4%") (UX-DR8)

**Given** VoiceOver is active
**When** buttons are focused
**Then** they read "Early" and "Late" respectively
**When** feedback is shown
**Then** it announces "Correct, 4 percent" or "Incorrect, 4 percent" (UX-DR9)

**Given** landscape orientation or iPad
**When** the screen is displayed
**Then** layout adapts appropriately (UX-DR14)

## Epic 49: Hit That Beat — Rhythm Matching Training

Full rhythm matching training: session state machine, screen with dot visualization (3+1 with color feedback), tap button, signed deviation feedback. Users can start rhythm matching from the Start Screen and train their timing production.

### Story 49.1: RhythmMatchingSession State Machine

As a **developer**,
I want a `RhythmMatchingSession` that plays 3 lead-in notes and measures the user's tap timing,
So that the rhythm matching training loop works end-to-end with proper state management.

**Acceptance Criteria:**

**Given** `RhythmMatchingSession` is `@Observable`
**When** inspected
**Then** it follows the state machine: `idle → playingLeadIn → awaitingTap → showingFeedback → loop`

**Given** `start()` is called
**When** the session transitions from idle
**Then** it builds a `RhythmPattern` with 3 events at sixteenth-note intervals at the configured tempo
**And** calls `rhythmPlayer.play(pattern)` and awaits the handle

**Given** the lead-in pattern completes
**When** the session transitions to `awaitingTap`
**Then** the session records the expected tap time (pattern end + one sixteenth-note duration)

**Given** the user taps
**When** tap timing is measured
**Then** the session uses `CACurrentMediaTime()` for microsecond precision
**And** computes error = actual tap time - expected tap time, stored as `RhythmOffset`
**And** observers are notified with a `CompletedRhythmMatchingTrial`

**Given** the session transitions to `showingFeedback`
**When** ~400ms elapses
**Then** it automatically starts the next lead-in

**Given** interruption occurs
**When** in any state other than idle
**Then** the session stops, discards incomplete exercises, transitions to idle (FR79, FR79a)

**Given** no strategy protocol is needed (per architecture)
**When** challenged
**Then** selection is trivial — play 3 notes at the configured tempo

**Given** unit tests using `MockRhythmPlayer`
**When** all state transitions are tested
**Then** full coverage including interruption and tap timing measurement

### Story 49.2: RhythmMatchingScreen with Tap Button and Color Feedback

As a **musician using Peach**,
I want a rhythm matching screen showing dots that light up with lead-in notes, a large Tap button, and color-coded feedback on my 4th dot,
So that I can train my ability to produce accurate timing.

**Acceptance Criteria:**

**Given** the Rhythm Matching Screen
**When** displayed
**Then** it shows a summary stat line, 4 horizontal dots, and a full-width Tap button below (UX-DR13)

**Given** the 3 lead-in notes
**When** each plays
**Then** the corresponding dot (1st, 2nd, 3rd) transitions from dim to lit instantly (UX-DR1)

**Given** the 4th dot position
**When** the user taps
**Then** the 4th dot appears at the same fixed grid position as dots 1–3
**And** after the answer is recorded, the dot shows color feedback: green (precise), yellow (moderate), red (erratic) (FR82)

**Given** the Tap button
**When** displayed
**Then** it is full-width, `.borderedProminent` style, "Tap" label, always enabled (UX-DR3)

**Given** the feedback line
**When** feedback is shown after tap
**Then** it displays an arrow + signed percentage (e.g., "← 3% early" or "→ 8% late") (UX-DR8)

**Given** VoiceOver is active
**When** the Tap button is focused
**Then** it reads "Tap" with hint "Tap at the correct moment to match the rhythm" (UX-DR10)
**When** feedback is shown
**Then** it announces "3 percent early" or "8 percent late"

**Given** landscape orientation or iPad
**When** the screen is displayed
**Then** layout adapts appropriately (UX-DR14)

## Epic 50: Six Modes, One App — Start Screen & Settings

6-button Start Screen layout with section labels (Pitch/Intervals/Rhythm), NavigationDestination updates, tempo stepper in Settings (40–200 BPM). Portrait vertical stack with landscape 3-column grid.

### Story 50.1: NavigationDestination and Settings for Rhythm

As a **developer**,
I want `NavigationDestination` to include rhythm cases and `AppUserSettings`/`UserSettings` to include a tempo property,
So that rhythm training can be navigated to and tempo can be configured.

**Acceptance Criteria:**

**Given** `NavigationDestination` enum
**When** extended
**Then** it includes `.rhythmOffsetDetection` and `.rhythmMatching` cases with no parameters (tempo read from settings)

**Given** `ContentView`
**When** updated with navigation destination handling
**Then** `.rhythmOffsetDetection` navigates to `RhythmOffsetDetectionScreen` and `.rhythmMatching` navigates to `RhythmMatchingScreen`

**Given** `SettingsKeys`
**When** extended
**Then** it includes a rhythm tempo key with default 80 BPM

**Given** `AppUserSettings`/`UserSettings`
**When** extended
**Then** they include a `tempoBPM: TempoBPM` property backed by `@AppStorage`

**Given** the tempo value
**When** set below the minimum floor
**Then** it is clamped to ~60 BPM (FR85)

### Story 50.2: Start Screen Six-Button Layout with Section Labels

As a **musician using Peach**,
I want the Start Screen to show six training buttons organized by section (Pitch, Intervals, Rhythm),
So that I can easily find and start any training mode (FR104).

**Acceptance Criteria:**

**Given** the Start Screen in portrait
**When** displayed
**Then** it shows section labels ("Pitch", "Intervals", "Rhythm") with two buttons per section in a scrollable vertical stack (UX-DR6)

**Given** the button styling
**When** displayed
**Then** Pitch Comparison remains `.borderedProminent` (hero button), all others use `.bordered` style

**Given** the Rhythm section
**When** displayed
**Then** it shows "Rhythm Comparison" and "Rhythm Matching" buttons that navigate to the corresponding screens

**Given** landscape orientation
**When** the Start Screen is displayed
**Then** it uses a 3-column grid layout (UX-DR6)

**Given** iPad
**When** the Start Screen is displayed
**Then** layout adapts to the wider form factor (UX-DR14)

### Story 50.3: Settings Screen Tempo Stepper

As a **musician using Peach**,
I want a tempo stepper in Settings to choose my rhythm training tempo,
So that I can train at my preferred speed (FR84).

**Acceptance Criteria:**

**Given** the Settings Screen
**When** displayed
**Then** a "Rhythm" section appears below existing pitch settings

**Given** the tempo stepper
**When** displayed
**Then** it shows a `Stepper` with range 40–200 BPM, step 1, with "BPM" label (UX-DR7)

**Given** the tempo value
**When** changed by the user
**Then** it is immediately persisted via `@AppStorage`
**And** subsequent rhythm training sessions use the new tempo

**Given** the minimum tempo floor
**When** the stepper is at its minimum
**Then** it cannot go below 40 BPM (conservative floor below the ~60 BPM functional minimum per FR85)

## Epic 51: See Your Rhythm — Profile Visualization

RhythmSpectrogramView with color-coded tempo × time grid, RhythmProfileCardView with EWMA headline + trend arrow, Profile Screen integration, tap-to-detail, empty states, VoiceOver per-column summaries.

### Story 51.1: RhythmSpectrogramView

As a **musician using Peach**,
I want a spectrogram-style chart showing my rhythm accuracy across time and tempo,
So that I can see how my timing precision evolves and identify which tempos need more practice.

**Acceptance Criteria:**

**Given** the `RhythmSpectrogramView`
**When** displayed with rhythm data
**Then** it shows a grid where X-axis is time progression (same bucketing as pitch charts) and Y-axis is tempos actually trained at (FR90)
**And** only tempos with data appear — no empty rows for untrained tempos

**Given** cell coloring
**When** accuracy is computed for a cell
**Then** green (precise, ≤5%), yellow (moderate, 5–15%), red (erratic, >15%) thresholds are applied (UX-DR4)
**And** thresholds are parameterized for future tuning

**Given** cells with no training data
**When** displayed
**Then** they are empty/transparent (FR91)

**Given** the user taps a cell
**When** data exists for that tempo and time period
**Then** an early/late breakdown detail is shown (FR92, UX-DR4)

**Given** VoiceOver is active
**When** the spectrogram is navigated
**Then** per-column summaries are announced (e.g., "March week 2: 120 BPM precise, 100 BPM moderate") (UX-DR11)
**And** activating a column shows the detail overlay

### Story 51.2: RhythmProfileCardView and Profile Screen Integration

As a **musician using Peach**,
I want a rhythm profile card on the Profile Screen showing my overall rhythm accuracy and the spectrogram,
So that I can track my rhythm training progress alongside my pitch progress.

**Acceptance Criteria:**

**Given** the `RhythmProfileCardView`
**When** displayed with rhythm data
**Then** it shows a headline with "Rhythm" label, EWMA of the most recent time bucket's combined accuracy, and a trend arrow (FR89, UX-DR5)
**And** the spectrogram view appears below the headline
**And** a share button appears in the headline row (same pattern as pitch profile cards)

**Given** no rhythm training data
**When** the card is displayed
**Then** it shows dashes for the EWMA value and placeholder text encouraging the user to start training (UX-DR5)

**Given** the Profile Screen
**When** updated
**Then** it includes the `RhythmProfileCardView` alongside existing pitch profile cards

**Given** landscape or iPad layout
**When** the Profile Screen is displayed
**Then** the rhythm card adapts appropriately

## Epic 52: Version Your Exports — CSV Format v2

CSVImportParserV2 and CSVExportSchemaV2 extending the chain-of-responsibility pattern. Exporter/importer updates for rhythm records. V1 backward compatibility preserved. Deduplication by timestamp + tempo + training type.

### Story 52.1: CSV Export Schema v2

As a **developer**,
I want a `CSVExportSchemaV2` that exports all four training types with a `trainingType` discriminator column,
So that rhythm training data can be exported alongside pitch data (FR100, FR101).

**Acceptance Criteria:**

**Given** `CSVExportSchemaV2`
**When** it formats export data
**Then** each row includes a `trainingType` column with values: `pitchDiscrimination`, `pitchMatching`, `rhythmOffsetDetection`, `rhythmMatching`

**Given** rhythm comparison records
**When** exported
**Then** type-specific columns include tempoBPM, offsetMs, isCorrect, timestamp

**Given** rhythm matching records
**When** exported
**Then** type-specific columns include tempoBPM, userOffsetMs, timestamp

**Given** `TrainingDataExporter`
**When** updated
**Then** it exports all four record types using the v2 schema

**Given** unit tests
**When** they verify v2 export
**Then** output CSV contains correct headers, discriminators, and type-specific columns for all four training types

### Story 52.2: CSV Import Parser v2 with Backward Compatibility

As a **developer**,
I want a `CSVImportParserV2` that imports all four training types and maintains V1 backward compatibility,
So that users can import rhythm data and existing pitch exports remain importable (FR102).

**Acceptance Criteria:**

**Given** `CSVImportParserV2` conforms to `CSVVersionedParser`
**When** inspected
**Then** it has `supportedVersion: 2`

**Given** a v2 CSV file with all four training types
**When** imported
**Then** it correctly parses `pitchDiscrimination`, `pitchMatching`, `rhythmOffsetDetection`, and `rhythmMatching` records

**Given** a v1 CSV file (pitch records only)
**When** imported
**Then** the existing V1 parser handles it — V1 records remain importable (FR102)

**Given** `CSVImportParser`
**When** updated
**Then** it registers the V2 parser in the chain alongside V1

**Given** deduplication
**When** importing records that already exist
**Then** rhythm records are deduplicated by timestamp + tempo + training type (FR103)
**And** pitch records continue to use existing deduplication logic

**Given** `TrainingDataImporter`
**When** updated
**Then** it imports rhythm records with deduplication through the V2 parser

**Given** unit tests
**When** they verify V2 import
**Then** all four training types parse correctly, V1 backward compatibility is confirmed, and deduplication works

> **Note (from 47.2 review):** `replaceAllRecords` currently deletes all four record types but only re-inserts pitch records. When this story adds rhythm import support, `replaceAllRecords` must be updated to accept and re-insert rhythm record arrays too — otherwise a "replace" import silently destroys rhythm training data.

## Epic 53: Rhythm in Every Language — Localization

English + German UI strings for all rhythm training screens, Start Screen section labels, Settings tempo section, Profile rhythm cards, feedback text, and spectrogram accessibility descriptions.

### Story 53.1: Rhythm Training Localization

As a **musician using Peach in German**,
I want all rhythm training UI text available in both English and German,
So that the app provides a consistent localized experience across all training modes.

**Acceptance Criteria:**

**Given** `Localizable.xcstrings`
**When** updated
**Then** it includes English and German translations for all new rhythm UI strings

**Given** rhythm comparison screen strings
**When** localized
**Then** button labels ("Early"/"Late" → "Früh"/"Spät"), feedback text, and screen titles are translated

**Given** rhythm matching screen strings
**When** localized
**Then** button label ("Tap" → "Tippen"), feedback text, and screen titles are translated

**Given** Start Screen section labels
**When** localized
**Then** "Pitch", "Intervals", "Rhythm" are translated ("Tonhöhe", "Intervalle", "Rhythmus")

**Given** Settings Screen rhythm section
**When** localized
**Then** "Rhythm" section title and "BPM" label are translated

**Given** Profile Screen rhythm card
**When** localized
**Then** "Rhythm" card title, spectrogram accessibility descriptions, and empty-state text are translated

**Given** VoiceOver accessibility descriptions
**When** localized
**Then** all rhythm-specific VoiceOver labels, hints, and announcements have German translations

**Given** German abbreviation conventions
**When** translations are reviewed
**Then** no trailing dots on German abbreviations (consistent with existing localization conventions)

---

## Epic 54: Fill the Gap — Continuous Rhythm Matching

Continuous step-sequencer-style rhythm matching training, built as a new training discipline alongside the existing rhythm matching mode (Epic 49). A looping 4-step cycle of 16th notes plays at the user's tempo with beat-1 accent. One step per cycle is a silent gap — the user fills it by tapping at the right moment. Gap positions are configurable in settings; when multiple are enabled, each cycle randomly selects one. Taps are silently evaluated against a timing window around the gap. A trial aggregates 16 consecutive cycles into a single statistical unit; incomplete trials are discarded on exit.

### Story 54.1: StepSequencer Protocol and Audio Engine

As a **developer**,
I want a `StepSequencer` protocol and audio engine implementation that loops a 4-step cycle with callback-driven step configuration,
so that continuous rhythm training has sample-accurate, indefinitely looping playback with per-cycle gap selection.

**Acceptance Criteria:**

**Given** a `StepSequencer` protocol
**When** inspected
**Then** it exposes `start(tempo:stepProvider:)` and `stop()` methods, where `StepProvider` supplies a `CycleDefinition` at the top of each 4-step loop

**Given** `start()` is called with a tempo and step provider
**When** the sequencer runs
**Then** it plays a continuous loop of 4 sixteenth notes at the given tempo, calling back to the step provider at each cycle boundary for the next `CycleDefinition`

**Given** a `CycleDefinition` with a gap at position N
**When** the cycle plays
**Then** step 1 plays at accent velocity (127), non-gap steps 2–4 play at normal velocity (100), and the gap step is pure silence (no MIDI event)

**Given** the sequencer is running
**When** `stop()` is called
**Then** playback ceases immediately and the sequencer can be restarted

**Given** the sequencer completes a cycle
**When** the next cycle begins
**Then** it calls `stepProvider.nextCycle()` to get the gap position for the upcoming cycle

**Given** the underlying audio infrastructure
**When** the sequencer schedules events
**Then** it reuses `SoundFontEngine` for sample-accurate MIDI event rendering on the audio thread, with no allocations or locks during rendering

**Given** unit tests with a mock audio engine
**When** the sequencer is tested
**Then** cycle timing, gap silence, accent velocity, and stop behavior are verified

### Story 54.2: ContinuousRhythmMatchingSession

As a **developer**,
I want a `ContinuousRhythmMatchingSession` that acts as the step provider, evaluates tap timing against gap windows, counts cycles, and aggregates 16 cycles into a single trial,
so that the continuous rhythm matching training loop works end-to-end.

**Acceptance Criteria:**

**Given** `ContinuousRhythmMatchingSession` conforms to `TrainingSession` and `StepProvider`
**When** inspected
**Then** it manages the step sequencer lifecycle and provides `CycleDefinition` per cycle

**Given** `start()` is called
**When** the session begins
**Then** it starts the step sequencer at the configured tempo, providing itself as the `StepProvider`

**Given** the step provider is called for `nextCycle()`
**When** multiple gap positions are enabled
**Then** it randomly selects one of the enabled positions; when exactly one is enabled, it always uses that position

**Given** the user taps
**When** the tap falls within the evaluation window (±50% of one sixteenth-note duration centered on the gap)
**Then** the session records the signed offset and marks the gap as hit

**Given** the user taps
**When** the tap falls outside the evaluation window
**Then** the tap is silently ignored — no feedback, no recording

**Given** the user does not tap during a gap's evaluation window
**When** the window closes
**Then** the gap is recorded as a miss

**Given** 16 consecutive gap evaluations have been recorded (hits + misses)
**When** the cycle count reaches 16
**Then** the session packages a `CompletedContinuousRhythmMatchingTrial` with aggregate statistics and notifies observers, then resets the cycle counter and begins the next trial

**Given** `stop()` is called or an interruption occurs
**When** the current trial has fewer than 16 cycles
**Then** the incomplete trial is discarded

**Given** the session is `@Observable`
**When** state changes
**Then** the screen can observe: `isRunning`, `currentStep`, `currentGapPosition`, `cyclesInCurrentTrial`, `lastTrialResult`

**Given** unit tests with mock step sequencer and mock observers
**When** all behaviors are tested
**Then** full coverage of gap selection, tap evaluation, trial aggregation, and interruption

### Story 54.3: Gap Position Settings

As a **musician using Peach**,
I want to select which gap positions (1–4) are enabled for continuous rhythm matching,
so that I can focus my training on specific subdivisions within the beat.

**Acceptance Criteria:**

**Given** `ContinuousRhythmMatchingSettings`
**When** inspected
**Then** it has `enabledGapPositions: Set<StepPosition>` (default: all four enabled) and `tempo: TempoBPM`

**Given** the Settings Screen
**When** the user navigates to it
**Then** a "Gap Positions" section is visible with toggles for positions 1–4, labeled with their musical function (e.g., "Beat", "E", "And", "A")

**Given** the gap position toggles
**When** the user disables a position
**Then** it is removed from the enabled set; when all other positions are disabled, the last remaining position cannot be disabled (at least one must be enabled)

**Given** the settings are persisted via `@AppStorage`
**When** the app restarts
**Then** the enabled gap positions are restored

**Given** `ContinuousRhythmMatchingSettings.from(_ userSettings:)`
**When** called
**Then** it reads the user's tempo and gap position preferences from `UserSettings`

**Given** unit tests
**When** settings serialization and validation are tested
**Then** encoding/decoding of `Set<StepPosition>` round-trips correctly and the "at least one" invariant holds

### Story 54.4: Continuous Rhythm Matching Screen

As a **musician using Peach**,
I want a training screen with four dots that show my position in the beat cycle and which note is the gap, plus a tap button to fill the gap,
so that I can train my rhythmic timing in a continuous, groove-locked flow.

**Acceptance Criteria:**

**Given** the Continuous Rhythm Matching Screen
**When** displayed
**Then** it shows four horizontal dots and a full-width Tap button below

**Given** the four dots
**When** the sequencer advances through steps
**Then** the current step's dot is highlighted (filled/bright), and dots for completed steps dim back down

**Given** the gap position for the current cycle
**When** the dots are displayed
**Then** the gap dot is rendered as an outline circle while non-gap dots are filled, updating at the start of each cycle

**Given** the step-1 dot
**When** displayed
**Then** it is visually bolder/larger than dots 2–4, reflecting the beat-1 accent

**Given** the Tap button
**When** displayed
**Then** it is full-width, `.borderedProminent`, always visually active — never disabled or dimmed

**Given** the user taps
**When** inside the evaluation window
**Then** brief visual feedback appears on the gap dot (green/yellow/red color based on timing accuracy)

**Given** the user taps
**When** outside the evaluation window
**Then** no visual feedback occurs

**Given** a trial completes (16 cycles)
**When** the result is available
**Then** a stats summary updates showing the trial's hit rate and mean offset

**Given** `onAppear`
**When** the screen loads
**Then** the step sequencer starts immediately

**Given** `onDisappear` or interruption
**When** the screen exits
**Then** the session stops and any incomplete trial is discarded

**Given** VoiceOver is active
**When** the Tap button is focused
**Then** it reads "Tap" with hint "Tap to fill the gap in the rhythm"

### Story 54.5: Data Model and Storage

As a **developer**,
I want a `ContinuousRhythmMatchingRecord` SwiftData model and `TrainingDataStore` integration,
so that continuous rhythm matching trials are persisted and available for profile visualization and export.

**Acceptance Criteria:**

**Given** `ContinuousRhythmMatchingRecord` as a SwiftData `@Model`
**When** inspected
**Then** it stores: `tempoBPM: Int`, `meanOffsetMs: Double`, `hitRate: Double`, `gapPositionBreakdown: Data` (encoded JSON), `cycleCount: Int`, `timestamp: Date`

**Given** `TrainingDataStore`
**When** it conforms to `ContinuousRhythmMatchingObserver`
**Then** `continuousRhythmMatchingCompleted(_:)` converts the trial to a record and persists it

**Given** `TrainingDataStore`
**When** CRUD methods are called
**Then** `save`, `fetchAll`, and `deleteAll` operations work for `ContinuousRhythmMatchingRecord`

**Given** `PerceptualProfile`
**When** it conforms to `ContinuousRhythmMatchingObserver`
**Then** it updates rhythm statistics keyed by `TempoRange` using the trial's mean offset

**Given** `TrainingDisciplineConfig`
**When** a `.continuousRhythmMatching` discipline is registered
**Then** it has appropriate display name, unit label, and optimal baseline

**Given** `ProgressTimeline`
**When** extended for the new discipline
**Then** it tracks trend data for continuous rhythm matching

**Given** unit tests
**When** all data operations are tested
**Then** save/fetch/delete, observer conversion, and profile update are verified

### Story 54.6: Start Screen and Navigation

As a **musician using Peach**,
I want a dedicated button on the Start Screen to launch continuous rhythm matching training,
so that I can access the new training mode alongside existing modes.

**Acceptance Criteria:**

**Given** `NavigationDestination`
**When** inspected
**Then** it includes a `.continuousRhythmMatching` case

**Given** the Start Screen
**When** displayed
**Then** a 7th training button appears in the Rhythm section labeled "Fill the Gap" with an appropriate SF Symbol icon

**Given** the 7th button
**When** tapped
**Then** it navigates to `ContinuousRhythmMatchingScreen`

**Given** the Start Screen layout
**When** displayed in portrait
**Then** the Rhythm section accommodates 3 buttons; in landscape, the grid layout adapts

**Given** the `navigationDestination` modifier
**When** `.continuousRhythmMatching` is pushed
**Then** `ContinuousRhythmMatchingScreen` is rendered with proper environment injection

**Given** VoiceOver
**When** the button is focused
**Then** it reads the training mode name with an appropriate hint

### Story 54.7: Profile Visualization

As a **musician using Peach**,
I want to see my continuous rhythm matching progress in the Profile Screen,
so that I can track my gap-filling accuracy across tempos and over time.

**Acceptance Criteria:**

**Given** the Profile Screen
**When** the user has continuous rhythm matching data
**Then** a profile card appears showing the EWMA of recent accuracy with a trend arrow

**Given** the spectrogram view
**When** continuous rhythm matching data exists
**Then** it renders alongside or integrated with the existing rhythm spectrogram, showing tempo × time accuracy with green/yellow/red color coding

**Given** tap-to-detail on a spectrogram cell
**When** tapped
**Then** it shows hit rate and mean offset for that tempo/time bucket

**Given** no continuous rhythm matching data
**When** the profile is displayed
**Then** the card shows an appropriate empty state

**Given** VoiceOver
**When** the profile card is focused
**Then** it reads the accuracy value, trend, and training mode name

### Story 54.8: CSV Export/Import

As a **musician using Peach**,
I want my continuous rhythm matching data included in CSV exports and importable from CSV files,
so that my training data is portable and backed up alongside all other training records.

**Acceptance Criteria:**

**Given** `CSVExportSchemaV2`
**When** extended
**Then** it supports a `continuousRhythmMatching` training type with columns for: `tempoBPM`, `meanOffsetMs`, `hitRate`, `cycleCount`, `timestamp`

**Given** `CSVImportParserV2`
**When** it encounters a `continuousRhythmMatching` row
**Then** it parses it into a `ContinuousRhythmMatchingRecord` with validation

**Given** export
**When** the user exports data
**Then** all `ContinuousRhythmMatchingRecord` entries are included alongside existing training types

**Given** import with merge
**When** duplicate detection runs
**Then** continuous rhythm matching records are deduplicated by `timestamp + tempoBPM + trainingType`

**Given** a V2 CSV without `continuousRhythmMatching` rows
**When** imported
**Then** it imports successfully — the new type is optional

**Given** unit tests
**When** export/import round-trip is tested
**Then** continuous rhythm matching records survive the cycle intact

### Story 54.9: Localization

As a **musician using Peach**,
I want all continuous rhythm matching UI text available in English and German,
so that the app communicates clearly in both languages.

**Acceptance Criteria:**

**Given** the continuous rhythm matching screen
**When** displayed in German
**Then** all UI text (button labels, stats, feedback, help content) is localized

**Given** the gap position settings
**When** displayed in German
**Then** section headers, toggle labels, and position names are localized

**Given** the Start Screen button
**When** displayed in German
**Then** the training mode label is localized

**Given** the profile card and spectrogram
**When** displayed in German
**Then** all labels, empty states, and accessibility descriptions are localized

**Given** VoiceOver in German
**When** navigating the continuous rhythm matching screens
**Then** all accessibility labels and hints are localized

**Given** `bin/add-localization.swift --missing`
**When** run
**Then** no missing keys are reported for continuous rhythm matching strings

---
