---
stepsCompleted: ['step-01-validate-prerequisites', 'step-02-design-epics', 'step-03-create-stories', 'step-04-final-validation', 'v0.2-step-01-validate-prerequisites', 'v0.2-step-02-design-epics', 'v0.2-step-03-create-stories', 'v0.2-step-04-final-validation', 'v0.3-step-01-validate-prerequisites', 'v0.3-step-02-design-epics', 'v0.3-step-03-create-stories', 'v0.3-step-04-final-validation']
inputDocuments: ['docs/planning-artifacts/prd.md', 'docs/planning-artifacts/architecture.md', 'docs/planning-artifacts/ux-design-specification.md', 'docs/planning-artifacts/glossary.md', 'docs/project-context.md']
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
FR56: User can start interval comparison training from the Start Screen via a dedicated button
FR57: Generalizes FR2: system plays a reference note followed by a second note at the target interval +/- a signed cent deviation
FR58: Generalizes FR3: user answers whether the second note was higher or lower than the correct interval pitch
FR59: FR4, FR5, FR7, FR7a, and FR8 apply to interval comparison identically as to unison comparison
FR60: User can start interval pitch matching training from the Start Screen via a dedicated button
FR61: Generalizes FR45: system plays a reference note for the configured duration, then plays a tunable note indefinitely; the user's target is the correct interval pitch, not unison
FR62: Generalizes FR46: user adjusts the pitch of the tunable note via slider to match the target interval
FR63: FR47, FR49, FR50, and FR50a apply to interval pitch matching identically as to unison pitch matching
FR64: System records interval pitch matching results: reference note, target interval, user's final pitch, error in cents relative to the correct interval pitch, timestamp
FR65: Start Screen shows four training buttons: "Comparison", "Pitch Matching", "Interval Comparison", "Interval Pitch Matching"
FR66: Unison comparison and unison pitch matching behave identically to their interval variants with the interval fixed to prime (unison)
FR67: Initial interval training implementation uses a single fixed interval: perfect fifth up (700 cents in 12-TET)

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

### Additional Requirements

**From Architecture:**
- Starter template: Xcode 26.3 iOS App template with SwiftUI lifecycle, Swift language, SwiftData storage — this must be Epic 1, Story 1
- Project folder structure organized by feature (App/, Core/, Training/, Profile/, Settings/, Start/, Info/, Resources/)
- Test target mirroring source structure (PeachTests/)
- Swift 6.2.3, iOS 26 deployment target, explicit Swift modules
- SwiftUI with @Observable pattern (not ObservableObject)
- SwiftData for persistence (ComparisonRecord @Model)
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
- Prerequisite renames: TrainingSession→ComparisonSession, TrainingState→ComparisonSessionState, TrainingScreen→ComparisonScreen, Training/→Comparison/, FeedbackIndicator→ComparisonFeedbackIndicator, NextNoteStrategy→NextComparisonStrategy
- PlaybackHandle protocol: new protocol with stop() and adjustFrequency(); NotePlayer.play() returns handle; stop() removed from NotePlayer; fixed-duration convenience via default extension
- SoundFontPlaybackHandle implementation + MockPlaybackHandle for tests
- PitchMatchingRecord SwiftData @Model: referenceNote, initialCentOffset, userCentError, timestamp
- TrainingDataStore extended with pitch matching CRUD + PitchMatchingObserver conformance
- ModelContainer schema updated to include PitchMatchingRecord
- Profile protocol split: PitchDiscriminationProfile (existing behavior extracted) + PitchMatchingProfile (new matching stats)
- PerceptualProfile conforms to both protocols, rebuilt from both record types at startup
- PitchMatchingSession state machine: idle → playingReference → playingTunable → showingFeedback → loop
- PitchMatchingObserver protocol + CompletedPitchMatching value type
- PitchMatchingChallenge value type (random note + random ±100 cent offset for v0.2)
- New PitchMatching/ feature directory
- PeachApp.swift wiring for PitchMatchingSession + NavigationDestination update
- Implementation sequence: renames → PlaybackHandle → data model → profile split → session → UI → Start Screen → Profile Screen

**From UX Design (v0.2 Amendment):**
- Vertical Pitch Slider: custom DragGesture-based, large thumb (>>44pt), no markings, always starts center, states: inactive/active/dragging/released
- Pitch Matching Feedback Indicator: SF Symbol arrow + signed cent offset, green (<10¢) / yellow (10-30¢) / red (>30¢), green dot for dead center
- Start Screen hierarchy: Start Training (.borderedProminent) above Pitch Matching (.bordered)
- Auto-start tunable note after reference stops — no touch-to-start
- No visual feedback during active tuning — ears-only principle (non-negotiable)
- Same ~400ms feedback duration as comparison training
- Same interruption patterns as comparison training
- VoiceOver: accessibilityAdjustableAction for slider, custom labels for feedback ("4 cents sharp", "Dead center")
- Profile Screen: shows matching statistics alongside discrimination profile (empty state for cold start)

**From Glossary (v0.2):**
- Domain terminology confirmed: ComparisonSession, ComparisonSessionState, PlaybackHandle, PitchMatchingSession, PitchMatchingSessionState, PitchMatchingChallenge, CompletedPitchMatching, PitchDiscriminationProfile, PitchMatchingProfile

**From Architecture (v0.3 Amendment — Prerequisite Refactorings):**
- Arch-A: New domain types — `Interval` enum (Prime through Octave, Int raw value), `TuningSystem` enum (equalTemperament initially, extensible via new cases), `Pitch` struct (MIDINote + Cents with frequency computation). `MIDINote` extensions: `transposed(by:)`, `pitch(at:in:)`. `Frequency` gains `.concert440` constant.
- Arch-B: NotePlayer protocol change — takes `Pitch` instead of `Frequency`. `SoundFontNotePlayer` receives Pitch and maps to MIDI + pitch bend. `PlaybackHandle.adjustFrequency` stays as Frequency.
- Arch-C: FrequencyCalculation migration — logic moves to `Pitch.frequency(referencePitch:)` and `MIDINote.frequency(referencePitch:)`; `FrequencyCalculation.swift` deleted after all call sites migrated.
- Arch-D: Unified reference/target naming — `note1`→`referenceNote`, `note2`→`targetNote`, `note2CentOffset`→`centOffset`, `centDifference`→`centOffset` across value types, records, sessions, strategies, observers, data store, tests, and docs.
- Arch-E: SoundSourceProvider protocol — extracts protocol from `SoundFontLibrary`, decouples `SettingsScreen` from concrete implementation.

**From Architecture (v0.3 Amendment — Session & Data):**
- Session parameterization: `startTraining()` and `startPitchMatching()` renamed to `start()` (intervals and tuningSystem read from `userSettings`); `start()` added to `TrainingSession` protocol; `currentInterval` observable state and `isIntervalMode` computed property
- NextComparisonStrategy update: gains `interval` + `tuningSystem` parameters, computes targetNote from interval; MIDI range boundary enforcement (upper bound shrinks by interval semitones)
- Data model updates: `ComparisonRecord` gains `tuningSystem`, renamed fields; `PitchMatchingRecord` gains `targetNote` and `tuningSystem`; value types gain target/tuning fields
- NavigationDestination: `.training`→`.comparison(intervals:)`, `.pitchMatching(intervals:)` — parameterized with interval sets
- Profile impact: record everything, defer computation changes; interval data flows through existing observer paths; no changes to profile protocols

**From UX Design (v0.3 Amendment):**
- Target interval label: conditional `Text` view at top of both training screens, visible in interval mode (`isIntervalMode`), hidden in unison mode; `.headline`/`.title3` styling; VoiceOver accessible ("Target interval: Perfect Fifth Up")
- Start Screen: four buttons in vertical stack with visual separator between unison and interval groups; Comparison remains `.borderedProminent`, all others `.bordered`
- Screen reuse: Comparison Screen and Pitch Matching Screen extended with conditional interval indicator, not duplicated
- Feedback indicators: no change — same patterns for interval and unison modes
- Interruption patterns: identical to unison modes — no interval-specific handling
- No interval settings UI for v0.3 (fixed perfect fifth)

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

## Epic List

### Epic 1: Remember Every Note — Data Foundation
Every comparison the user answers is reliably stored and persists across sessions, crashes, and restarts — so that no training is ever lost.
**FRs covered:** FR27, FR28, FR29

### Epic 2: Hear and Compare — Core Audio Engine
Users can hear precisely generated tones with clean envelopes, enabling the fundamental listening experience.
**FRs covered:** FR16, FR17, FR18, FR19, FR20

### Epic 3: Train Your Ear — The Comparison Loop
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
All MVP names that are now ambiguous with two training modes are renamed to comparison-specific names. Pure refactoring — no functional changes, all tests continue to pass.
**FRs covered:** None (refactoring only)

### Epic 12: Own Every Note — PlaybackHandle Redesign
The NotePlayer protocol is redesigned around a PlaybackHandle that represents ownership of a playing note, enabling both fixed-duration playback (comparisons) and indefinite playback with real-time frequency adjustment (pitch matching).
**FRs covered:** FR51, FR52

### Epic 13: Remember Every Match — Pitch Matching Data Layer
Pitch matching results are reliably stored alongside comparison records, extending the data foundation to support both training modes.
**FRs covered:** FR48

### Epic 14: Know Both Skills — Profile Protocol Split
The perceptual profile is split into two protocol interfaces — pitch discrimination and pitch matching — so that each training mode depends only on the statistics it needs.
**FRs covered:** None (architectural refactoring enabling FR45-FR50a)

### Epic 15: Tune Your Ear — PitchMatchingSession
The pitch matching state machine orchestrates the complete training loop: reference note playback, indefinite tunable note, slider-driven frequency adjustment, result recording, and observer notification.
**FRs covered:** FR45, FR47, FR50, FR50a

### Epic 16: See and Slide — Pitch Matching Screen
Users interact with pitch matching through a custom vertical slider and receive post-release visual feedback showing their accuracy.
**FRs covered:** FR46, FR49
**NFRs covered:** NFR13

### Epic 17: Two Modes, One App — Start Screen Integration
Users can access pitch matching from the Start Screen alongside comparison training, with proper navigation routing.
**FRs covered:** FR44

### Epic 18: The Full Picture — Profile Screen Integration
Users can see their pitch matching accuracy statistics alongside their discrimination profile on the Profile Screen.
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

### Story 1.2: Implement ComparisonRecord Data Model and TrainingDataStore

As a **developer**,
I want a persisted data model for comparison records with a store that supports create and read operations,
So that training results can be reliably stored and retrieved.

**Acceptance Criteria:**

**Given** the Xcode project from Story 1.1
**When** a ComparisonRecord is created
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
So that I can train my pitch discrimination with accurate audio.

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

## Epic 3: Train Your Ear — The Comparison Loop

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

### Story 3.2: TrainingSession State Machine and Comparison Loop

As a **musician using Peach**,
I want to hear two notes in sequence and answer whether the second was higher or lower,
So that I can train my pitch discrimination through rapid comparisons.

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
I want the app to build and maintain an accurate map of my pitch discrimination ability,
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
**Then** it identifies notes with the largest detection thresholds (poorest discrimination)

**Given** the PerceptualProfile
**When** no data exists for a MIDI note
**Then** that note is treated as a weak spot (cold start assumption)

**Given** the PerceptualProfile
**When** unit tests are run
**Then** aggregation, incremental update, and weak spot identification are verified

### Story 4.2: Implement NextNoteStrategy Protocol and AdaptiveNoteStrategy

As a **musician using Peach**,
I want the app to intelligently choose which comparisons to present,
So that every comparison maximally improves my pitch discrimination.

**Acceptance Criteria:**

**Given** a NextNoteStrategy protocol
**When** it is defined
**Then** it exposes a method that takes the PerceptualProfile and current settings and returns a Comparison (note1, note2, centDifference)

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
I want to see my pitch discrimination ability visualized as a confidence band over a piano keyboard,
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

Replace the default training strategy with a simpler, research-backed approach. Perceptual learning research shows that pitch discrimination is essentially one unified skill with a roughly uniform threshold across the frequency range. The complex per-note weak spot targeting and natural-vs-mechanical balance in AdaptiveNoteStrategy adds no value and produces annoying difficulty jumps when changing notes. The simpler KazezNoteStrategy — continuous difficulty chain with frequency roving — is both more scientifically sound and more pleasant to use.

See brainstorming session: `docs/brainstorming/brainstorming-session-2026-02-24.md`

### Story 9.1: Promote KazezNoteStrategy to Default Training Strategy

As a **musician using Peach**,
I want the training algorithm to maintain a smooth, continuous difficulty progression regardless of which note is playing,
So that I experience steady convergence to my threshold without jarring difficulty jumps when the note changes.

**Acceptance Criteria:**

**Given** KazezNoteStrategy is the active training strategy
**When** a note is selected for a comparison
**Then** the note is selected randomly within `settings.noteRangeMin...settings.noteRangeMax`

**Given** KazezNoteStrategy with a `lastComparison` available
**When** the next comparison's difficulty is determined
**Then** it uses the Kazez chain from `lastComparison.centDifference` (narrowing on correct, widening on incorrect)
**And** the difficulty never jumps due to a note change

**Given** KazezNoteStrategy with no `lastComparison` (cold start)
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
I want the profile visualization and statistics to reflect that pitch discrimination is one skill, not many separate per-note skills,
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

With two training modes, several MVP names are now ambiguous. All ambiguous names are renamed to comparison-specific names before any new feature work begins. This is pure refactoring — no functional changes, all tests continue to pass.

### Story 11.1: Rename Training Types and Files to Comparison

As a **developer**,
I want all ambiguous "Training" names renamed to comparison-specific names,
So that the codebase clearly distinguishes comparison training from future training modes and the namespace is clean for pitch matching.

**Acceptance Criteria:**

**Given** the type `TrainingSession` exists
**When** the rename is applied
**Then** it becomes `ComparisonSession` in all source files, test files, and references
**And** the file is renamed from `TrainingSession.swift` to `ComparisonSession.swift`
**And** the test file is renamed from `TrainingSessionTests.swift` to `ComparisonSessionTests.swift`

**Given** the enum `TrainingState` exists
**When** the rename is applied
**Then** it becomes `ComparisonSessionState` in all source files, test files, and references

**Given** the file `TrainingScreen.swift` exists
**When** the rename is applied
**Then** it becomes `ComparisonScreen.swift`
**And** all references to `TrainingScreen` in source and test files are updated

**Given** the `Training/` feature directory exists
**When** the rename is applied
**Then** it becomes `Comparison/`
**And** the test directory `PeachTests/Training/` becomes `PeachTests/Comparison/`

**Given** the view `FeedbackIndicator` exists
**When** the rename is applied
**Then** it becomes `ComparisonFeedbackIndicator` in all source files, test files, and references
**And** the file is renamed from `FeedbackIndicator.swift` to `ComparisonFeedbackIndicator.swift`

**Given** the protocol `NextNoteStrategy` exists
**When** the rename is applied
**Then** it becomes `NextComparisonStrategy` in all source files, test files, and references
**And** the file is renamed from `NextNoteStrategy.swift` to `NextComparisonStrategy.swift`
**And** the method `nextNote()` is renamed to `nextComparison()` (or equivalent, matching existing method name)

**Given** the following names exist in the codebase
**When** the rename is applied
**Then** these names remain UNCHANGED: `TrainingDataStore`, `TrainingSettings`, `ComparisonObserver`, `Comparison`, `CompletedComparison`, `PerceptualProfile`, `NotePlayer`, `HapticFeedbackManager`

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
**When** existing comparison training call sites use `play(frequency:duration:velocity:amplitudeDB:)`
**Then** they continue to work without any call-site changes — the convenience method delegates to the handle internally

**Given** the full test suite
**When** all tests are run
**Then** all existing tests pass
**And** new tests verify: PlaybackHandle stop idempotency, adjustFrequency updates, MockPlaybackHandle tracking, fixed-duration convenience method behavior

### Story 12.2: ~~ComparisonSession PlaybackHandle Integration~~ — Won't Do

**Status:** Won't Do — Superseded by Story 12.1

**Rationale:** Story 12.1 introduced `NotePlayer.stopAll()` and a fixed-duration convenience method with internal handle management. ComparisonSession already uses these simpler interfaces effectively: `play(frequency:duration:velocity:amplitudeDB:)` for normal playback and `stopAll()` for interruption cleanup. Adding explicit `PlaybackHandle` tracking to ComparisonSession would introduce unnecessary complexity — the convenience method deliberately hides handle lifecycle, and `stopAll()` provides a more robust interruption mechanism than per-handle stopping. ComparisonSession's responsibility is orchestrating comparisons, not managing audio note lifecycles.

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

**Given** no `CompletedPitchMatching` value type exists
**When** it is created
**Then** it is a struct with fields: `referenceNote` (Int), `initialCentOffset` (Double), `userCentError` (Double), `timestamp` (Date)
**And** the file is located at `PitchMatching/CompletedPitchMatching.swift`

**Given** no `PitchMatchingChallenge` value type exists
**When** it is created
**Then** it is a struct with fields: `referenceNote` (Int, MIDI 0-127), `initialCentOffset` (Double, random ±100 cents)
**And** the file is located at `PitchMatching/PitchMatchingChallenge.swift`

**Given** no `PitchMatchingObserver` protocol exists
**When** it is created
**Then** it defines `func pitchMatchingCompleted(_ result: CompletedPitchMatching)`
**And** the file is located at `PitchMatching/PitchMatchingObserver.swift`

**Given** `TrainingDataStore` currently handles only comparison records
**When** pitch matching CRUD is added
**Then** it supports `save(_ record: PitchMatchingRecord) throws`, `fetchAllPitchMatching() throws -> [PitchMatchingRecord]`, and `deleteAllPitchMatching() throws`
**And** `TrainingDataStore` conforms to `PitchMatchingObserver`, automatically persisting completed pitch matching attempts

**Given** the `ModelContainer` in `PeachApp.swift` registers only `ComparisonRecord`
**When** the schema is updated
**Then** it registers both `ComparisonRecord.self` and `PitchMatchingRecord.self`

**Given** the full test suite
**When** all tests are run
**Then** all existing tests pass
**And** new tests verify: PitchMatchingRecord CRUD operations, TrainingDataStore pitch matching persistence, atomic writes, in-memory ModelContainer for tests

## Epic 14: Know Both Skills — Profile Protocol Split

The perceptual profile is split into two protocol interfaces representing the two distinct skills being trained. Each training mode depends only on the statistics it needs, maintaining clean dependency boundaries.

### Story 14.1: Extract PitchDiscriminationProfile Protocol

As a **developer**,
I want the existing PerceptualProfile discrimination interface extracted into a protocol,
So that ComparisonSession and NextComparisonStrategy depend on an abstract interface rather than the concrete class.

**Acceptance Criteria:**

**Given** `PerceptualProfile` exposes discrimination methods directly
**When** the protocol is extracted
**Then** `PitchDiscriminationProfile` protocol defines: `func update(note: Int, centOffset: Double, isCorrect: Bool)`, `func weakSpots(count: Int) -> [Int]`, `var overallMean: Double? { get }`, `var overallStdDev: Double? { get }`, `func statsForNote(_ note: Int) -> PerceptualNote`, `func averageThreshold(midiRange: ClosedRange<Int>) -> Int?`, `func setDifficulty(note: Int, difficulty: Double)`, `func reset()`
**And** the file is located at `Core/Profile/PitchDiscriminationProfile.swift`

**Given** `PerceptualProfile` already implements all these methods
**When** it conforms to `PitchDiscriminationProfile`
**Then** no implementation changes are needed — conformance is declarative

**Given** `ComparisonSession` currently depends on `PerceptualProfile` (concrete)
**When** the dependency is updated
**Then** it depends on `PitchDiscriminationProfile` (protocol) — accepting any conforming type

**Given** `NextComparisonStrategy` (and implementations like `KazezNoteStrategy`) depend on `PerceptualProfile`
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
**Then** it loads both `ComparisonRecord` data (discrimination) and `PitchMatchingRecord` data (matching) to reconstruct the complete profile

**Given** no pitch matching data exists (cold start or comparison-only user)
**When** matching statistics are queried
**Then** `matchingMean` and `matchingStdDev` return `nil`, `matchingSampleCount` returns `0`

**Given** `resetMatching()` is called
**When** matching statistics are queried afterward
**Then** all matching statistics are cleared (`nil`/`0`) while discrimination statistics remain untouched

**Given** the full test suite
**When** all tests are run
**Then** all existing tests pass
**And** new tests verify: matching statistics update via Welford's, cold start nil values, reset independence from discrimination, profile rebuild from both record types

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
**Then** the session generates a random `PitchMatchingChallenge` (random MIDI note within configured training range, random initial offset ±100 cents)
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
**And** it creates a `CompletedPitchMatching` with: referenceNote, initialCentOffset, userCentError, timestamp
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
**And** the session transitions to `idle` (FR50a — the view layer handles returning to Start Screen, same pattern as ComparisonSession)

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

Users interact with pitch matching through a custom vertical slider control and receive post-release visual feedback showing directional accuracy. The screen follows the same navigation and layout patterns as the Comparison Screen.

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
**Then** the indicator clears with `.transition(.opacity)` — same pattern as `ComparisonFeedbackIndicator`

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
So that I can do a full pitch matching training session with the same navigation patterns as comparison training.

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

Users can access both comparison training and pitch matching from the Start Screen, with clear visual hierarchy and proper navigation routing.

### Story 17.1: Pitch Matching Button and Navigation Routing

As a **musician using Peach**,
I want a "Pitch Matching" button on the Start Screen below "Start Training",
So that I can start pitch matching with a single tap, just like comparison training.

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

**Given** `PeachApp.swift` currently creates only `ComparisonSession`
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

Users can see their pitch matching accuracy statistics alongside their discrimination profile on the Profile Screen, giving a complete view of both training skills.

### Story 18.1: Display Pitch Matching Statistics on Profile Screen

As a **musician using Peach**,
I want to see my pitch matching accuracy on the Profile Screen alongside my discrimination profile,
So that I can track improvement in both training modes from one place.

**Acceptance Criteria:**

**Given** the Profile Screen currently shows only discrimination statistics (mean detection threshold, standard deviation, trend)
**When** pitch matching statistics are added
**Then** a new section displays: matching mean absolute error (cents), matching standard deviation (cents), and matching sample count
**And** the section is visually distinct from the discrimination section

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

**Given** the magic literals `-90.0` and `12.0` used as amplitude dB bounds in `ComparisonSession.swift`
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

**Given** `Comparison` stores `note1: Int`, `note2: Int`, `isSecondNoteHigher: Bool`
**When** the redesign is applied
**Then** `note1` and `note2` are `MIDINote`, `centDifference` is signed `Cents`, and `isSecondNoteHigher` is a computed property

**Given** `ComparisonRecord` and `PitchMatchingRecord` are SwiftData `@Model` types
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

**Given** `ComparisonSession`, `PitchMatchingSession`, and `SoundFontNotePlayer` accept override parameters for testing
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
I want the three long methods (`PeachApp.init()`, `ComparisonSession.handleAnswer()`, `ComparisonSession.playNextComparison()`) broken into smaller, named helper methods,
So that each method does one thing, the code is easier to read and navigate, and the former inline comments become self-documenting method names.

**Acceptance Criteria:**

**Given** `PeachApp.init()` is ~70 lines with comment-delimited sections
**When** it is extracted
**Then** each section (create model container, create dependencies, populate profile, create sessions) becomes a named method

**Given** `ComparisonSession.handleAnswer()` is ~60 lines
**When** it is extracted
**Then** it is split into helpers: stopping note 2 if playing, tracking session best, and transitioning to feedback state

**Given** `ComparisonSession.playNextComparison()` is ~70 lines
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
**Then** both `ComparisonSession` and `PitchMatchingSession` conform to it with `stop()` and `isIdle`
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
I want shared domain types (`Comparison`, `CompletedComparison`, `ComparisonObserver`, `CompletedPitchMatching`, `PitchMatchingObserver`) moved from feature directories to `Core/Training/`,
So that Core/ no longer has upward dependencies on feature modules, and the dependency arrows point in the correct direction.

**Acceptance Criteria:**

**Given** `Comparison`, `CompletedComparison`, and `ComparisonObserver` are defined in `Comparison/` and `CompletedPitchMatching` and `PitchMatchingObserver` are defined in `PitchMatching/`
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
I want `PitchMatchingFeedbackIndicator` to define its own icon size constant instead of referencing `ComparisonFeedbackIndicator.defaultIconSize`,
So that PitchMatching/ has no dependency on Comparison/ and each feature module is self-contained.

**Acceptance Criteria:**

**Given** `PitchMatchingFeedbackIndicator` references `ComparisonFeedbackIndicator.defaultIconSize`
**When** a local `private static let defaultIconSize: CGFloat = 100` is defined
**Then** `PitchMatchingFeedbackIndicator.swift` contains no reference to `ComparisonFeedbackIndicator`
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

### Story 20.8: Resettable Protocol for ComparisonSession Dependencies

As a **developer maintaining Peach**,
I want `ComparisonSession` to depend on a `Resettable` protocol instead of storing `TrendAnalyzer` and `ThresholdTimeline` as concrete types,
So that the session is decoupled from specific profile/analytics implementations and only knows that some of its dependencies can be reset.

**Acceptance Criteria:**

**Given** `ComparisonSession` stores `TrendAnalyzer?` and `ThresholdTimeline?` solely for their `reset()` method
**When** a `Resettable` protocol is introduced and both types conform
**Then** `ComparisonSession` stores `[Resettable]` instead of named concrete types
**And** `resetTrainingData()` calls `resettables.forEach { $0.reset() }`
**And** the full test suite passes

### Story 20.9: Move MockHapticFeedbackManager to Test Target

As a **developer maintaining Peach**,
I want `MockHapticFeedbackManager` moved from the production target to the test target,
So that mock types do not ship in the production binary and the project follows its own convention that mocks belong in `PeachTests/`.

**Acceptance Criteria:**

**Given** `MockHapticFeedbackManager` exists in `Peach/Comparison/HapticFeedbackManager.swift`
**When** it is moved to `PeachTests/Comparison/MockHapticFeedbackManager.swift`
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
So that naming is consistent with the reference/target mental model shared by all training modes, and `Comparison` naturally expresses its target as a detuned note.

**Acceptance Criteria:**

**Given** `ComparisonRecord` has fields `note1`, `note2`, `note2CentOffset`
**When** they are renamed to `referenceNote`, `targetNote`, `centOffset`
**Then** all references across code, tests, and docs use the new names
**And** no occurrence of `note1`, `note2`, `note2CentOffset`, or `centDifference` remains in Swift source files (except comments explaining the rename if needed)

**Given** `Comparison` has fields `note1: MIDINote`, `note2: MIDINote`, `centDifference: Cents`
**When** refactored
**Then** it becomes `referenceNote: MIDINote`, `targetNote: DetunedMIDINote`
**And** `targetNote.note` replaces the old `note2` and `targetNote.offset` replaces `centDifference`
**And** `ComparisonSession`, `NextComparisonStrategy`, `KazezNoteStrategy`, `ComparisonObserver` conformances, and all tests use the new shape

**Given** `Comparison` frequency methods currently construct `Pitch` inline
**When** refactored
**Then** `note1Frequency` becomes `referenceFrequency` using `tuningSystem.frequency(for: referenceNote, referencePitch:)`
**And** `note2Frequency` becomes `targetFrequency` using `tuningSystem.frequency(for: targetNote, referencePitch:)`
**And** both methods require explicit `tuningSystem` and `referencePitch` parameters

**Given** `CompletedComparison` has fields `comparison.note1`, `comparison.note2`
**When** accessed through the refactored `Comparison` struct
**Then** all code paths use `comparison.referenceNote`, `comparison.targetNote`

**Given** `PitchMatchingRecord.referenceNote`, `PitchMatchingChallenge.referenceNote`, `CompletedPitchMatching.referenceNote` already use correct naming
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
I want `ComparisonRecord` and `PitchMatchingRecord` to carry `interval` and `tuningSystem` fields, `PitchMatchingChallenge` and `CompletedPitchMatching` to carry `targetNote`, and all value types confirmed compatible with the two-world architecture,
So that every training result records full interval context for data integrity and future analysis.

**Acceptance Criteria:**

**Given** `ComparisonRecord` has `referenceNote`, `targetNote`, `centOffset`, `isCorrect`, `timestamp`
**When** `interval: Interval` and `tuningSystem: TuningSystem` fields are added
**Then** the SwiftData schema accepts the new fields
**And** `TrainingDataStore` saves and loads both
**And** `interval` is stored explicitly for efficient querying (even though it is derivable from `referenceNote` and `targetNote`)

**Given** `PitchMatchingRecord` has `referenceNote`, `initialCentOffset`, `userCentError`, `timestamp`
**When** `targetNote: MIDINote`, `interval: Interval`, and `tuningSystem: TuningSystem` fields are added
**Then** `TrainingDataStore` saves and loads all new fields
**And** `targetNote` represents the note the user was trying to match (equals `referenceNote` for unison)

**Given** `Comparison` already has `referenceNote: MIDINote` and `targetNote: DetunedMIDINote` (from Story 22.4)
**When** no structural changes are needed to `Comparison`
**Then** its shape is confirmed correct for interval training — `targetNote.note` is the transposed note, `targetNote.offset` is the training cent offset

**Given** `CompletedComparison` value type
**When** `tuningSystem: TuningSystem` field is added
**Then** `ComparisonSession` populates it from its session-level parameter
**And** `TrainingDataStore` (as `ComparisonObserver`) persists it to `ComparisonRecord`

**Given** `PitchMatchingChallenge` value type
**When** `targetNote: MIDINote` field is added
**Then** it represents the correct interval note the user should tune toward
**And** for unison: `targetNote == referenceNote`
**And** for intervals: `targetNote == referenceNote.transposed(by: interval)`

**Given** `CompletedPitchMatching` value type
**When** `targetNote: MIDINote` and `tuningSystem: TuningSystem` fields are added
**Then** `PitchMatchingSession` populates them from session-level parameters
**And** `TrainingDataStore` (as `PitchMatchingObserver`) persists them to `PitchMatchingRecord`

**Given** no production user base exists
**When** SwiftData schema changes are applied
**Then** no `SchemaMigrationPlan` is needed — fresh schema version is acceptable

### Story 23.2: ComparisonSession Start Rename and Strategy Interval Support

As a **developer building interval training**,
I want `ComparisonSession.startTraining()` renamed to `start()`, reading `intervals` and `tuningSystem` from `userSettings`, `NextComparisonStrategy` to compute interval-aware targets using `MIDINote.transposed(by:)`, and `currentInterval`/`isIntervalMode` observable state,
So that comparison training works with any musical interval while unison (`[.prime]`) behaves identically to current behavior (FR66).

**Acceptance Criteria:**

**Given** `UserSettings` protocol has no `intervals` or `tuningSystem` properties
**When** `intervals: Set<Interval>` and `tuningSystem: TuningSystem` are added to the protocol
**Then** `AppUserSettings` returns hardcoded `[.perfectFifth]` for `intervals` and `.equalTemperament` for `tuningSystem` (no UserDefaults backing yet)
**And** `MockUserSettings` exposes both as mutable properties for test injection

**Given** `ComparisonSession` has a `startTraining()` method
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

**Given** `NextComparisonStrategy` protocol
**When** it gains `interval: Interval` and `tuningSystem: TuningSystem` parameters (no defaults)
**Then** `KazezNoteStrategy` computes `targetNote.note` from the interval via `transposed(by:)`

**Given** the frequency computation for playback
**When** the session needs to play the reference and target notes
**Then** reference frequency uses `tuningSystem.frequency(for: referenceNote, referencePitch:)`
**And** target frequency uses `tuningSystem.frequency(for: targetNote, referencePitch:)` where `targetNote` is the `DetunedMIDINote`

**Given** `ComparisonSession` has `currentInterval` and `isIntervalMode` properties
**When** `currentInterval` is `.prime`
**Then** `isIntervalMode` returns `false`
**When** `currentInterval` is `.perfectFifth`
**Then** `isIntervalMode` returns `true`

**Given** `CompletedComparison` now carries `tuningSystem`
**When** `ComparisonObserver` (TrainingDataStore) receives it
**Then** `tuningSystem` is persisted to `ComparisonRecord`

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

**Given** `CompletedPitchMatching` carries `targetNote` and `tuningSystem`
**When** `PitchMatchingObserver` (TrainingDataStore) receives it
**Then** both fields are persisted to `PitchMatchingRecord`

**Given** `PitchMatchingSession` has `currentInterval` and `isIntervalMode` properties
**When** `currentInterval` is `.perfectFifth`
**Then** `isIntervalMode` returns `true`

**Given** `TrainingSession` protocol currently requires `stop()` and `isIdle`
**When** `start()` is added to the protocol
**Then** both `ComparisonSession` and `PitchMatchingSession` satisfy the requirement through their renamed `start()` methods
**And** any holder of a `TrainingSession` reference can call `start()` without knowing the concrete type

### Story 23.4: Training Screen Interval Label and Observer Verification

As a **developer building interval training**,
I want both `ComparisonScreen` and `PitchMatchingScreen` to show a conditional target interval label when in interval mode, and verify that observers/profiles handle the updated value types,
So that users see what interval they're training and all data flows correctly through the system.

**Acceptance Criteria:**

**Given** `ComparisonScreen` receives an `intervals` parameter
**When** `session.isIntervalMode` is `true`
**Then** a `Text` label showing the current interval name (e.g., "Perfect Fifth Up") is visible at the top of the screen, below navigation buttons and above the training interaction area
**And** the label uses `.headline` or `.title3` styling

**Given** `ComparisonScreen` is entered in unison mode (`intervals: [.prime]`)
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

**Given** `ComparisonObserver` and `PitchMatchingObserver` receive updated value types with `tuningSystem` and `targetNote`
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
**When** it is renamed to `.comparison(intervals: Set<Interval>)`
**Then** all existing navigation to comparison training uses `.comparison(intervals: [.prime])`

**Given** `NavigationDestination` has a `.pitchMatching` case
**When** it gains an `intervals` parameter as `.pitchMatching(intervals: Set<Interval>)`
**Then** all existing navigation to pitch matching uses `.pitchMatching(intervals: [.prime])`

**Given** the destination handler in `ContentView`
**When** routing `.comparison(let intervals)`
**Then** `ComparisonScreen(intervals: intervals)` is created
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
**Then** it navigates to `.comparison(intervals: [.perfectFifth])` (FR56, FR67)

**Given** the "Interval Pitch Matching" button
**When** tapped
**Then** it navigates to `.pitchMatching(intervals: [.perfectFifth])` (FR60, FR67)

**Given** the "Comparison" button
**When** tapped
**Then** it navigates to `.comparison(intervals: [.prime])` — unchanged behavior

**Given** the "Pitch Matching" button
**When** tapped
**Then** it navigates to `.pitchMatching(intervals: [.prime])` — unchanged behavior

**Given** the Start Screen layout
**When** viewed in portrait and landscape on iPhone and iPad
**Then** all four buttons are accessible and the visual separator is visible
**And** the one-handed, thumb-friendly layout is preserved

---

## Action Items

- [ ] **Future Epic:** Extend `SettingsScreen` to let users choose `tuningSystem` and `intervals`, backed by UserDefaults in `AppUserSettings` (currently hardcoded in Story 23.2)
