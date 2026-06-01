# Epic 80 Context: Let the Pulse Settle — Timing Offset Detection Continuous Loop

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Replace the one-shot pattern playback in the Timing Offset Detection discipline with a gapless continuous loop that runs until the learner submits a direction answer, capped by a user-configurable maximum repetition count that defaults high. Today the 4-sixteenth pattern (≈600–800 ms at 80–100 BPM) ends before the listener's auditory system has formed a stable pulse — the tested 3rd-sixteenth note arrives ~1.5 intervals in, and beat-induction research puts the pulse-stabilisation window at 2–3 intervals. The task therefore measures working-memory encoding more than offset perception. This epic is the first concrete application of the Performance Principle: disciplines must give listeners the exposure they need to demonstrate genuine ability; artificial exposure constraints are the failure mode, not the relaxed setting.

## Stories

- Story 80.1: Gapless looped pattern playback in TimingOffsetDetectionSession
- Story 80.2: Max-repetitions setting end-to-end
- Story 80.3: Settings UI contribution + localisation
- Story 80.4: Training-screen visual treatment for looped playback
- Story 80.5: Documentation touch-up (conditional)

## Requirements & Constraints

- Playback loops the existing 4-sixteenth pattern gaplessly. No inter-repetition silence, no fade. The current pattern is exactly one quarter-note long, so gapless looping produces a continuous sixteenth stream with the accent on every downbeat and the displaced 3rd-sixteenth recurring every quarter — no loop-boundary artefact to mitigate.
- Looping ends on user action (direction submission) or when the configured maximum repetition count is reached — whichever comes first. Pattern completion alone does not end the trial.
- The max-repetitions setting ranges from 1 to a practically-infinite cap, default high. UI surfaces the upper bound as "∞" / "until you decide" rather than a literal large number.
- The existing grid-aligned next-trial behaviour is preserved: after `awaitingAnswer` resolves, the next trial still begins on the next quarter-note grid boundary.
- The 4-sixteenth pattern, the adaptive strategy, the perceptual-profile schema and storage, the SwiftData `TrainingRecord` envelope, and the CSV contract are all unchanged. No schema migration.
- Discipline remains research-only: activation stays inside the `#if PEACH_RESEARCH` block in `DisciplineBootstrap`, so the App Store cut never links these types.
- German UI strings use informal `du` / imperative form (project-wide convention).
- Out of scope for this epic: additional patterns, pattern-selection model, loop-boundary treatment for patterns with internal rests, and decision-time instrumentation by repetition count.

## Technical Decisions

- **State machine.** `TimingOffsetDetectionSession` gains a `playingPatternLoop` state that re-enters pattern playback at the loop boundary without an audible gap. Transition out of `playingPatternLoop` is driven by user submission or the rep cap — not by pattern completion.
- **Setting plumbing follows the Epic 77 plugin model.** `maxRepetitions` is a feature-local setting: it lives on `TimingOffsetDetectionSettings`, with its UserDefaults key and default in a feature-local `SettingsKeys`-style file, and is read through a feature-local `UserSettings` port owned by the discipline directory. It does not touch `Peach/Core/Ports/UserSettings.swift` or `Peach/Settings/AppUserSettings.swift`. The session's `LifecycleContribution` consumes the feature-local port directly rather than routing it through `TrainingLifecycleCoordinator`.
- **Settings UI as a discipline contribution.** The Settings row is contributed by the discipline via `TrainingDisciplineUI`, not added to a central `SettingsScreen` switch. `SettingsScreen` iterates `TrainingDisciplineRegistry.shared.allUI` and renders whatever the discipline returns.
- **Localization.** New English and German strings go in `Localizable.xcstrings`. Both languages are required before the story is considered done.
- **Defaults align with the Performance Principle.** Factory default for `maxRepetitions` is high (effectively "loop until decision"), not a low test-purity number. The 1-rep option remains available for users who deliberately want the constraint.
- **Documentation update is conditional.** Architecture / arc42 only need a touch-up if 80.1's state-machine shape is worth documenting beyond a source-code comment. If not, 80.5 is closed `wont-do` at the retrospective.

## UX & Interaction Patterns

- **Training screen.** During `playingPatternLoop`, `litDotCount` cycles continuously in sync with the audio loop so the visual matches the audio and the learner can see the pattern is still running. The cycling indicator must read as "repeating until you answer," not as a stuck UI.
- **Help text.** `TimingOffsetDetectionHelp.swift` is updated to describe the loop-until-decision model so the documented behaviour matches the runtime behaviour.
- **Settings row shape.** Picker vs. stepper is deferred to story-creation time. Whichever is chosen, the high-end value must read as "∞" / "until you decide" rather than a raw integer, and the German label must use informal `du`.

## Cross-Story Dependencies

- **Within the epic.** Strict order: 80.1 → 80.2 → 80.3 → 80.4 → 80.5. 80.3 and 80.4 may run in parallel after 80.2 lands. 80.5 is last and conditional.
- **On Epic 77.** This epic assumes the post-77 plugin model is in place: feature-local settings ports, discipline-contributed Settings rows via `TrainingDisciplineUI`, no central enum cases to extend. Do not introduce centralised seams that 77 just removed.
- **On Epic 76.** The discipline is build-gated behind `PEACH_RESEARCH`. New files must remain inside that gating envelope so the App Store cut is unaffected.
