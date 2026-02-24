---
stepsCompleted: ['step-01-validate-prerequisites', 'step-02-design-epics', 'step-03-create-stories', 'step-04-final-validation']
inputDocuments: ['docs/planning-artifacts/prd.md', 'docs/planning-artifacts/architecture.md', 'docs/planning-artifacts/ux-design-specification.md', 'docs/planning-artifacts/glossary.md']
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
