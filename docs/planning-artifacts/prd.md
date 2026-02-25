---
stepsCompleted: ['step-01-init', 'step-02-discovery', 'step-03-success', 'step-04-journeys', 'step-05-domain', 'step-06-innovation', 'step-07-project-type', 'step-08-scoping', 'step-09-functional', 'step-10-nonfunctional', 'step-11-polish', 'step-12-complete', 'step-e-01-discovery', 'step-e-02-review', 'step-e-03-edit']
inputDocuments: ['docs/brainstorming/brainstorming-session-2026-02-11.md']
documentCounts:
  briefs: 0
  research: 0
  brainstorming: 1
  projectDocs: 0
classification:
  projectType: mobile_app
  domain: edtech_music_training
  complexity: low
  projectContext: greenfield
workflowType: 'prd'
lastEdited: '2026-02-25'
editHistory:
  - date: '2026-02-25'
    changes: 'Added pitch matching training paradigm (v0.2 scope); restructured phases; removed completed/obsolete roadmap items'
---

# Product Requirements Document - Peach

**Author:** Michael
**Date:** 2026-02-12

## Executive Summary

Peach is a pitch ear training app for iOS. It trains musicians' pitch perception through two complementary modes: **Pitch Comparison** (two notes in sequence — user answers higher or lower) and **Pitch Matching** (user tunes a note to match a reference pitch). Both modes build a perceptual profile across the user's range and relentlessly target weak spots.

**Target users:** Musicians (singers, string, woodwind, brass players) for whom intonation is a practical challenge.

**Design philosophy: "Training, not testing."** Existing pitch training apps like InTune follow a test-and-score paradigm — escalating difficulty until failure. Peach inverts this: it builds a perceptual profile of the user's hearing and relentlessly targets weak spots. No scores, no gamification, no sessions. Every exercise makes the user better; no single answer matters.

**Technology:** Native iOS (Swift/SwiftUI), entirely on-device, no backend. This is a personal/learning project with three goals: improve pitch perception, learn iOS development, and explore AI-assisted development.

## Success Criteria

### User Success

- The perceptual profile shows measurable narrowing of detectable cent differences over time through continued training
- The comparison training loop feels instinctive and low-friction — users can do 30 seconds of comparisons without thinking about the app, just about the sounds
- Pitch matching accuracy improves over time — users achieve smaller cent errors with continued training
- Summary statistics (mean and standard deviation of detection thresholds) show a visible improving trend over time
- Users return to the app regularly because it fits into incidental moments (practice breaks, commuting, waiting)

### Business Success

- The app is installed on Michael's iPhone and works according to MVP scope
- This is a personal/learning project — no commercial metrics apply
- Secondary success: meaningful learning in iOS/SwiftUI development and AI-assisted workflows

### Technical Success

- Test-first development with comprehensive coverage — non-negotiable
- Modern, modular architecture using latest Swift/SwiftUI and iOS 26 frameworks
- No backward compatibility constraints — always target latest
- Adaptive algorithm parameters are tunable and discoverable during development
- Audio playback is smooth with proper envelopes (no clicks or artifacts)

### Measurable Outcomes

- Algorithm validation: average detectable cent difference trends downward with sustained training; if it doesn't, the algorithm needs adjustment
- Algorithm parameters are exposed for manual tuning during development/testing
- Training loop throughput: comparisons can be answered at a reflexive pace without UI bottlenecks

## Project Scoping & Phased Development

### MVP Strategy & Philosophy

**MVP Approach:** Experience MVP — the core value is the training feel, not a feature count. Ship the smallest thing that lets a musician train pitch discrimination with adaptive comparison selection and see that it's working.

**Resource:** Solo developer learning iOS/SwiftUI, AI-assisted development.

### MVP Feature Set (Phase 1)

**Core User Journeys Supported:**
- Journey 1 (First Launch), Journey 2 (Daily Training), Journey 4 (Return After Break), Journey 5 (Settings)
- Journey 3 (Checking Progress) supported in simplified form

**Must-Have Capabilities:**
- Core training loop (sequential comparisons, higher/lower, immediate feedback, haptic on wrong)
- Adaptive algorithm with tunable parameters, cold start, profile continuity
- Sine wave audio engine with proper attack/release envelopes
- Start Screen, Training Screen, Profile Screen, Settings Screen, Info Screen
- Perceptual profile visualization (piano keyboard + confidence band — current snapshot only)
- Summary statistics: arithmetic mean and standard deviation of detectable cent differences over current training range (shown as trend)
- Local persistence of all per-answer training data
- iPhone + iPad, portrait + landscape
- English + German localization
- Audio interruption handling (discard incomplete comparison)
- Consistent Settings/Profile navigation from both Start Screen and Training Screen
- App backgrounding during training returns to Start Screen on foreground

### Version 0.2 Scope (Phase 2 — Pitch Matching)

**Core addition:** A second training paradigm — Pitch Matching — where the user tunes a note to match a reference pitch, training active pitch production rather than passive discrimination.

**Must-Have Capabilities:**
- Pitch Matching Screen with large vertical slider for pitch adjustment
- Reference note plays for configured duration, then tunable note plays indefinitely
- User adjusts tunable note pitch via slider; releasing the slider stops the note and records the result
- Visual feedback showing proximity to reference pitch
- Pitch matching results recorded: reference note, user's final pitch, error in cents, timestamp
- Start Screen integration: dedicated "Pitch Matching" button below "Start Training"
- Audio engine support for indefinite playback and real-time frequency adjustment
- Same interruption handling as comparison training (discard on navigation away, backgrounding, etc.)

**User Journey Supported:** Journey 6 (Pitch Matching)

### Future Ideas

- Full temporal progress visualization (profile snapshots over time)
- Per-note detail view with trend data
- iCloud sync across devices
- CSV export of training history
- Custom SoundFont import (user-provided .sf2 files)
- Configurable pause between notes
- Deeper accessibility improvements

### Risk Mitigation Strategy

**Technical risk:** Adaptive algorithm requires parameter tuning — mitigated by exposing all parameters for manual adjustment during development. Algorithm is the intellectual core; UI is deliberately kept simple.

**Resource risk:** Solo developer on unfamiliar platform — mitigated by AI-assisted development, latest frameworks (less legacy baggage), and lean MVP scope.

**No market risk:** Developer is the primary user and knows the problem domain intimately.

## User Journeys

### Journey 1: First Launch — "Just Let Me Start"

**Persona:** Sarah, a semi-professional cellist who's been told her intonation in the upper registers is inconsistent. She's tried InTune but found that its score-driven approach and slow round-trips between comparisons get in the way of actual training.

**Opening Scene:** Sarah downloads Peach after a frustrating orchestra rehearsal. She opens the app and sees the Start Screen with a prominent Start Training Button, a brief description of what the app does, and buttons for Settings and Profile she ignores. No sign-up, no tutorial, no onboarding wizard.

**Rising Action:** She taps "Start Training." Two notes play in sequence — she taps "Higher." Thumbs up. Two more notes. "Lower." Thumbs up. Another comparison — she's wrong, feels a subtle haptic buzz, sees the thumbs down, but the next comparison is already coming. Within 10 seconds she's in a rhythm. It feels like a reflex game, not a test.

**Climax:** After 2 minutes, she stops. There's no score screen, no "you got 73%." She just... stops. She checks the visualization — it's sparse, mostly showing the cold-start state, but she can already see a few data points forming. It feels like the beginning of something, not a judgment.

**Resolution:** She puts her phone away thinking "that was easy." No cognitive overhead. She'll do it again tomorrow during her warm-up break.

**Requirements revealed:** Zero-friction onboarding, no account creation, immediate training access, cold start algorithm behavior, graceful sparse-data visualization.

### Journey 2: Daily Training — "Thirty Seconds on the Bus"

**Persona:** Sarah, three weeks in. She's on the bus to a gig.

**Opening Scene:** She pulls out her phone, opens Peach, taps "Start Training." Earbuds in, one hand holding the grab rail.

**Rising Action:** Comparisons come fast. She's tapping with her thumb — the buttons are large enough that she doesn't need to look carefully. Higher. Lower. Higher. Higher. She gets one wrong and feels the haptic. The algorithm shifts — the interval was tighter than usual, probing the edge of her perception around B5.

**Climax:** Her bus stop comes. She just switches away from the app. The incomplete comparison is silently discarded. No "are you sure?" dialog, no session summary, no guilt.

**Resolution:** Total elapsed time: 40 seconds. She answered maybe 15 comparisons. The app recorded every answer. Tomorrow, the algorithm will pick up exactly where the profile left off.

**Requirements revealed:** One-handed operation, large tap targets, instant start/stop, no session boundaries, interrupted comparison handling, algorithm continuity across sessions, haptic feedback, portrait mode usability, app backgrounding returns to Start Screen.

### Journey 3: Checking Progress — "Is This Actually Working?"

**Persona:** Sarah, six weeks in. She's curious whether she's improving.

**Opening Scene:** From the Start Screen, she taps the Profile Preview — a stylized miniature of her pitch landscape.

**Rising Action:** The Profile Screen opens: a piano keyboard along the X-axis with a confidence band overlaid showing her current detection thresholds across the frequency range. She can see she's strong around A3-A4 (her most-played range) and weaker in the extremes. The summary statistics show her mean detection threshold and standard deviation, with a trend indicator showing improvement.

**Climax:** The numbers confirm what she suspected — her mean threshold has dropped from 45 cents to 28 cents over six weeks. The improvement is real and undeniable — not as a score, but as a factual measurement of her perception sharpening.

*Future: The Profile Screen may expand to include tappable per-note detail views and temporal progress visualization showing profile snapshots over time.*

**Resolution:** She feels motivated. Not because she "leveled up" but because the data shows her perception is genuinely changing. She starts another quick training session.

**Requirements revealed:** Profile Preview on Start Screen, Profile Screen with confidence band visualization, summary statistics with trend, navigation from Start Screen to Profile Screen.

### Journey 4: Returning After a Break — "Where Was I?"

**Persona:** Sarah, back after a three-week vacation with no training.

**Opening Scene:** She opens Peach. The Start Screen looks exactly the same. No "welcome back!" banner, no guilt trip about missed days, no streak counter reset.

**Rising Action:** She taps "Start Training." The algorithm doesn't reset or re-test. It picks up from her existing profile — starting with areas it already knows are weak, at difficulty levels calibrated to her last known thresholds.

**Climax:** After a few comparisons she notices she's getting more wrong answers than she used to. The algorithm naturally responds — widening the intervals slightly, adapting to her current (slightly degraded) perception. No announcement, no "your skills have decreased" message. Just quiet recalibration.

**Resolution:** Within a few sessions over the next week, her profile tightens back up. The summary statistics show a small dip and recovery — an honest record, not a judgment.

**Requirements revealed:** No special return-from-break logic, algorithm resilience to skill regression, no streak/engagement mechanics, profile persistence across long gaps, honest data (showing dips too).

### Journey 5: Tweaking Settings — "Make It Feel Different"

**Persona:** Sarah wants to adjust how the app behaves. The default feels a bit too mechanical — comparisons jump around the keyboard unpredictably.

**Opening Scene:** She navigates to the Settings Screen from the Start Screen.

**Rising Action:** She finds the "Natural vs. Mechanical" slider. She moves it toward "Natural" — comparisons now tend to stay in nearby pitch regions more often before jumping to a weak spot. She also extends her note range upward since she's been working on higher positions. She adjusts note duration to be slightly shorter — she wants to sharpen her reflexes.

**Climax:** She starts a training session with the new settings. It feels different immediately — more musical, less random. The comparisons flow in a way that feels closer to real playing.

**Resolution:** She finds her sweet spot after a couple of adjustments over the next few days. The algorithm is the same underneath, but the experience feels tailored to her.

**Requirements revealed:** Settings Screen with algorithm slider, note range configuration, note duration configuration, reference pitch setting, sound source selection, immediate effect on training behavior, settings persistence.

### Journey 6: Pitch Matching — "Tune Your Ear"

**Persona:** Sarah, two months into comparison training. She wants to challenge herself differently — not just hearing pitch differences, but actively producing a target pitch.

**Opening Scene:** She opens Peach and sees the familiar Start Screen. Below "Start Training" there's a "Pitch Matching" button. She taps it.

**Rising Action:** A reference note plays — she listens closely. It stops, and a second note begins playing continuously. A large vertical slider fills the screen where the Higher/Lower buttons usually are. The second note is off-pitch. She drags the slider, and the pitch shifts in real time — she can hear it moving closer. A visual indicator shows she's getting warmer. She fine-tunes, nudging the slider in tiny increments, listening intently to the beating between her memory of the reference and the live tone.

**Climax:** She releases the slider. The note stops. The result is recorded — she was 4 cents off. No score, no judgment. The next reference note plays. She goes again. The rhythm is different from comparisons — slower, more deliberate, more like tuning an actual instrument. After a minute she's answered six matches. It feels like a different kind of exercise — active rather than reactive.

**Resolution:** She switches back to comparison training for a quick burst, then closes the app. Both modes feed her perceptual profile. Tomorrow she'll do a few minutes of each.

**Requirements revealed:** Pitch Matching Screen, indefinite note playback, real-time pitch adjustment via slider, visual proximity feedback, result recording, Start Screen integration, same interruption handling as comparison training.

### Journey Requirements Summary

| Capability Area | Journeys | Priority |
|---|---|---|
| Zero-friction start (no onboarding) | 1 | MVP |
| Core training loop (comparisons, feedback, haptic) | 1, 2 | MVP |
| One-handed / large tap targets | 2, 6 | MVP |
| Instant start/stop, no session boundaries | 2, 4 | MVP |
| Interrupted comparison handling | 2 | MVP |
| Cold start algorithm | 1 | MVP |
| Adaptive algorithm with profile continuity | 2, 4 | MVP |
| Perceptual profile visualization (current snapshot) | 3 | MVP |
| Summary statistics with trend | 3, 4 | MVP |
| Settings (slider, range, duration, pitch, sound) | 5 | MVP |
| Algorithm resilience to skill regression | 4 | MVP |
| No gamification / no guilt mechanics | 1, 4 | MVP (design constraint) |
| Consistent Settings/Profile nav from Start + Training | 2, 3, 5 | MVP |
| App backgrounding returns to Start Screen | 2 | MVP |
| Pitch Matching Screen with slider control | 6 | v0.2 |
| Indefinite note playback with real-time pitch adjustment | 6 | v0.2 |
| Visual proximity feedback for pitch matching | 6 | v0.2 |
| Pitch matching result recording | 6 | v0.2 |
| Interrupted pitch matching handling | 6 | v0.2 |
| Temporal progress visualization | 3 | Future |
| Per-note detail view | 3 | Future |

## Mobile App Specific Requirements

### Platform & Device

- Native iOS: Swift / SwiftUI (latest iteration), targeting iOS 26 minimum
- No backward compatibility — always target latest
- iPhone and iPad, with iPad supporting windowed/compact mode
- Portrait (primary) + landscape
- No cross-platform considerations

### Device Capabilities

- Audio output (speaker and headphones) — no microphone required
- Haptic engine for wrong-answer feedback
- System volume only — no in-app audio controls
- No camera, location, contacts, push notifications, or other permissions

### Data & Privacy

- Fully offline by design — no network access required
- No account creation or authentication
- Privacy nutrition label: training data stored locally only
- iCloud sync post-MVP

### App Store

- Standard App Store review — no special content concerns
- No in-app purchases (MVP)
- No user-generated content

### Architecture

- Protocol-based audio engine supporting both finite note playback (comparisons) and indefinite playback with real-time frequency adjustment (pitch matching)
- Test-first development with comprehensive coverage
- Per-comparison data model: two notes, correct/wrong, timestamp
- Per-pitch-matching data model: reference note, user's final pitch, error in cents, timestamp

## Functional Requirements

### Training Loop

- **FR1:** User can start a training session immediately from the Start Screen with a single tap
- **FR2:** User can hear two sequential notes played one after another within a comparison
- **FR3:** User can answer whether the second note was higher or lower than the first
- **FR4:** User can see immediate visual feedback (Feedback Indicator) after answering
- **FR5:** User can feel haptic feedback when answering incorrectly
- **FR6:** User can stop training by navigating to Settings or Profile from the Training Screen, or by leaving the app
- **FR7:** System discards incomplete comparisons when training is interrupted (navigation away, app backgrounding, phone call, headphone disconnect)
- **FR7a:** System returns to the Start Screen when the app is foregrounded after being backgrounded during training
- **FR8:** System disables answer controls during the first note and enables them when the second note begins playing

### Pitch Matching

- **FR44:** User can start pitch matching training from the Start Screen via a dedicated button
- **FR45:** System plays a reference note for the configured note duration, then plays a tunable note indefinitely
- **FR46:** User can adjust the pitch of the tunable note in real time via a large vertical slider control
- **FR47:** System stops the tunable note and records the result when the user releases the slider
- **FR48:** System records pitch matching results: reference note, user's final pitch, error in cents, timestamp
- **FR49:** System provides visual feedback showing the signed cent offset and directional proximity after the user releases the slider (post-release only). No visual feedback is provided during active tuning
- **FR50:** System discards incomplete pitch matching attempts on interruption (navigation away, app backgrounding, phone call, headphone disconnect)
- **FR50a:** System returns to the Start Screen when the app is foregrounded after being backgrounded during pitch matching

### Adaptive Algorithm

- **FR9:** System selects the next comparison based on the user's perceptual profile
- **FR10:** System adjusts comparison difficulty (cent difference) based on answer correctness — narrower on correct, wider on wrong
- **FR11:** System balances between training nearby the current pitch region and jumping to weak spots, controlled by a tunable ratio
- **FR12:** System initializes new users with random comparisons at 100 cents (1 semitone) with all notes treated as weak
- **FR13:** System maintains the perceptual profile across sessions without requiring explicit save or resume
- **FR14:** System supports fractional cent precision (0.1 cent resolution) with a practical floor of approximately 1 cent
- **FR15:** System exposes algorithm parameters for adjustment during development and testing

### Audio Engine

- **FR16:** System generates tones at precise frequencies derived from musical notes and cent offsets
- **FR17:** System plays notes with smooth attack/release envelopes (no audible clicks or artifacts)
- **FR18:** System uses the same timbre for both notes in a comparison or pitch matching exercise
- **FR19:** System supports configurable note duration
- **FR20:** System supports a configurable reference pitch (default A4 = 440Hz)
- **FR51:** System supports indefinite note playback (no fixed duration) with explicit stop trigger
- **FR52:** System supports real-time frequency adjustment of an actively playing note without audible artifacts

### Perceptual Profile & Statistics

- **FR21:** User can view their current perceptual profile as a visualization with a piano keyboard axis and confidence band overlay
- **FR22:** User can view a stylized Profile Preview on the Start Screen
- **FR23:** User can navigate from the Start Screen to the full Profile Screen
- **FR24:** User can view summary statistics: arithmetic mean and standard deviation of detectable cent differences over the current training range
- **FR25:** User can see summary statistics as a trend (improving/stable/declining)
- **FR26:** System computes the perceptual profile from stored per-answer data

### Data Persistence

- **FR27:** System stores every answered comparison as a record containing: two notes, correct/wrong, timestamp
- **FR28:** System persists all training data locally on-device
- **FR29:** System maintains data integrity across app restarts, backgrounding, and device reboots

### Settings & Configuration

- **FR30:** User can adjust the algorithm behavior via a "Natural vs. Mechanical" slider
- **FR31:** User can configure the note range (manual bounds or adaptive mode)
- **FR32:** User can configure note duration
- **FR33:** User can configure the reference pitch
- **FR34:** User can select from available SoundFont presets as the sound source
- **FR35:** System persists all settings across sessions
- **FR36:** System applies setting changes immediately to subsequent comparisons

### Localization & Accessibility

- **FR37:** User can use the app in English or German
- **FR38:** System provides basic accessibility support (labels, contrast, VoiceOver basics)

### Device & Platform

- **FR39:** User can use the app on iPhone and iPad
- **FR40:** User can use the app in portrait and landscape orientations
- **FR41:** User can use the app in iPad windowed/compact mode
- **FR42:** User can operate the training loop one-handed with large, imprecise-tap-friendly controls

### Info Screen

- **FR43:** User can view an Info Screen from the Start Screen showing app name, developer, copyright, and version number

## Non-Functional Requirements

### Performance

- Audio latency: time from triggering a note to audible output must be imperceptible to the user (target < 10ms)
- Transition between comparisons: next comparison must begin immediately after the user answers — no perceptible loading or delay
- Frequency precision: generated tones must be accurate to within 0.1 cent of the target frequency
- App launch to training-ready: Start Screen must be interactive within 2 seconds of app launch
- Real-time pitch adjustment: slider input must produce audible frequency change within 20ms — no perceptible lag between gesture and sound
- Profile Screen rendering: perceptual profile visualization must render within 1 second, including summary statistics computation

### Accessibility

- All interactive controls labeled for VoiceOver
- Sufficient color contrast ratios for all text and UI elements
- Tap targets meet minimum size guidelines (44x44 points per Apple HIG)
- Feedback Indicator provides non-visual feedback (haptic) in addition to visual

### Data Integrity

- Training data must survive app crashes, force quits, and unexpected termination without loss
- Data writes must be atomic — no partial comparison records
- App updates must preserve all existing training data (no migration data loss)

---

*See [Glossary](glossary.md) for definitions of all product terms.*
