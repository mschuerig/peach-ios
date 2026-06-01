---
stepsCompleted: [1]
inputDocuments: []
session_topic: 'Timing Offset Detection — continuous vs. one-shot pattern playback, with configurable repetition count'
session_goals: 'Explore design alternatives for how the rhythmic pattern is presented in the Timing Offset Detection discipline (currently one-shot). Consider continuous looping until user decides, a repetition-count setting (1 to indefinite), and any musical/UX/perceptual implications. Music domain expert (Adam) to participate.'
selected_approach: 'progressive-flow'
techniques_used: []
ideas_generated: []
context_file: ''
---

# Brainstorming Session Results

**Facilitator:** Michael
**Date:** 2026-06-01

## Session Overview

**Topic:** Timing Offset Detection — continuous vs. one-shot pattern playback, with configurable repetition count

**Goals:** Explore design alternatives for how the rhythmic pattern is presented in the Timing Offset Detection discipline. The discipline currently plays the pattern once; the idea on the table is to let it play continuously until the user makes a decision, possibly exposed as a setting (1 repetition → indefinitely long). Goal is to surface musical, perceptual, UX, and implementation implications, with the Music Domain Expert (Adam) participating.

### Context Guidance

_No context file provided. Session will incorporate the Music Domain Expert (Adam) as a participating voice per user request._

### Session Setup

Structured progressive flow proposed but **declined by user** — preference was for an informal conversation with the Music Domain Expert (Adam) in the room. Session document used as running record rather than as a phase-by-phase artifact.

---

## Conversation Log

### Adam's Opening Take

**Clarifying questions Adam needs answered before committing to a recommendation:**

1. What "offset" model is the discipline using? Three plausible variants:
   - Single-onset displacement inside an otherwise regular pattern
   - Pattern A vs. pattern B comparison ("was B ahead or behind A?")
   - Pattern played against a reference click/metronome
2. How long is the pattern, in beats and seconds? A 4-onset phrase at 100 BPM is gone in ~2.4 s — one-shot may simply be too short.

**Pro-repetition arguments:**

- Beat induction requires ~2–3 onsets before the auditory system locks into a stable pulse (London/Patel). One-shot may measure working-memory encoding rather than offset perception.
- Real-music context is rarely "play once and judge" — ensemble counts-in, listening to a groove settle, etc. Repetition is closer to the transfer domain Peach trains for.
- Offset JNDs (10–50 ms trained, 50–150 ms learners) require an entrained pulse to even be measurable.

**Against unconstrained repetition:**

- Adaptation/habituation: sensitivity drops after ~4–6 reps of identical stimulus. Infinite loop is psychoacoustically *worse*, not better.
- Test-taking strategy drift: users learn to wait for the loop to "settle" → inflated decision times, score decoupled from ability.
- Per-trial duration grows → total trials per session drop → adaptive algorithm starved of data per minute.

**Adam's starting hypothesis (subject to challenge):**

- Don't go "1 → ∞". Go "1 → auto-stop on decision, with a cap." Default around 3 repetitions, soft cap ~6–8.
- The interesting axes aren't "count" alone but:
  - Fixed N vs. play-until-decision (user's answer ends playback)
  - With inter-rep silence vs. gapless loop — gapless changes perceived meter and can make the offset coincide with a loop boundary, which would mask it
- Peach already records decision time → empirical answers are available before any code change.

**Open questions back to Michael:**

1. Which offset model is the discipline using today?
2. What triggered the idea — abandoned trials, slow profile convergence, or aesthetic ("feels rushed")?

### Michael's Answers

- Trigger: current one-shot is **rushed and probably too difficult**.
- Direction: "1 → auto-stop on decision, with cap" is correct, **but allow the cap to reach (practically) infinity** as a user choice.
- Offset model: **single-onset displacement** (confirmed below).
- Open to **additional patterns** beyond the existing 4-sixteenth one.

### Findings From Code (`TimingOffsetDetectionSession.swift`)

- Pattern is hardcoded to exactly **4 sixteenth-notes** (`patternNoteCount = 4`).
- Test note is the **3rd sixteenth** (`testedNoteIndex = 2`); other 3 are on-grid.
- First note is accented (downbeat marker), others normal.
- Click sound is MIDI 76 (hi-hat).
- After pattern + one sixteenth of silence → `awaitingAnswer` (open until user decides).
- Between trials the session waits for the **next quarter-note grid alignment** before the next pattern → already grid-aware, but the pulse is silent (in the user's head).

### Adam's Updated Assessment

**"Rushed" is psychoacoustically real:** at 100 BPM, the entire 4-sixteenth pattern is **600 ms**. The test note arrives at t=300 ms — only ~1.5 intervals in. Beat induction needs 2–3 stable intervals, so the test note often arrives before the listener's auditory system has stabilized the pulse. The task currently asks for judgment against a percept the listener hasn't yet formed.

**Reconciled position on "infinity":**

- Default ≈ 3 reps with **auto-stop on decision**.
- Setting range: 1 → very high cap (labeled "∞" or "until you decide").
- Caveat for later: decision-time distributions may diverge significantly between low- and high-rep-count users. Score may not reflect underlying ability the same way. Worth instrumenting; not worth blocking the epic on.

**Additional patterns (ordered easy → hard for offset detection):**

1. **8 straight sixteenths, one bar** — twice the runway, much better beat induction; offset on note 3 or note 7.
2. **Quarter-note pulse, 4 quarters** — clearest pulse, but offset semantics differ from sixteenth-scale; needs UX/data thought.
3. **Eighth-note pulse with offset on the off-beat** ("&" of 2) — musically most ecological; matches real-world swing/push/drag.
4. **Triplet pattern, offset on middle triplet** — tests subdivision-against-pulse; strong pedagogical value.
5. **Syncopated figure** — hardest; offset detection without continuous subdivision scaffold.

**Pattern-selection model — open design question:**

- User-picks-mix (settings UI)
- Adaptive-picks (`AdaptiveTimingOffsetDetectionStrategy` selects pattern jointly with offset magnitude)
- Both (user enables a subset; adaptive picks within the enabled set)

**Loop-boundary concern:**

- Gapless loop merges the trailing rest into the next iteration's downbeat → perceived meter shifts; displaced 3rd-sixteenth becomes adjacent to a strong downbeat that "shouldn't" be there → can mask the offset.
- **Recommendation:** loop with one beat of rest (or a quiet tail tick) between iterations so each repetition re-enters on a clear downbeat. Needs listening prototype before committing.

**Adam's two questions to Michael:**

1. Pattern selection model: user-picks-mix, adaptive-picks, or both?
2. Loop boundary: decide now, or sketch as "needs UX/audio prototyping" in the epic?

### Michael's Direction

- **Design philosophy reminder:** Across all disciplines, Peach optimizes for users to *perform their best*. We do not artificially make things harder. → Adam's "score comparability" caveat dropped as misaligned with this principle.
- **Patterns:** Don't get absorbed. Continuous-subdivision patterns are essentially equivalent; the interesting space is *non*-continuous-subdivision patterns, with syncopation as the closest example. Defer pattern enumeration to story-writing time.
- **Playback:** No gap that disrupts the pulse. Infrastructure for continuous looping already exists (used by `ContinuousRhythmMatching`).

### Adam's Final Position

- **Loop boundary concern withdrawn** for the current 4-sixteenth pattern: it is one quarter-note long, so gapless looping produces a continuous sixteenth stream with the accent on every downbeat and the displaced 3rd-sixteenth recurring every quarter. The loop boundary lands precisely where the next downbeat belongs — nothing to mask. The concern only matters for patterns with internal rests (defer with the patterns discussion).
- **Score-comparability caveat withdrawn:** test-purity thinking, incompatible with Peach's "help users perform their best" principle.
- **Default rep setting should be high**, not low: e.g. "until decision, soft cap ≈ 20." The 1-rep option remains available for users who deliberately want the constraint.

---

## Synthesis — Shape of the Proposed Change

**Core change**

- One-shot → **gapless continuous loop of the pattern**, ending when the user submits a direction answer.

**New setting**

- Max repetitions: **1 → (practically) ∞**, default high.

**Unchanged**

- Perceptual profile schema and storage.
- Adaptive strategy.
- Grid alignment between trials.
- The current 4-sixteenth pattern (the displaced 3rd-sixteenth).

**Deferred to story-writing time**

- Additional patterns. Continuous-subdivision variants offer little; non-continuous patterns and syncopated figures are the interesting space.
- Pattern selection model (user-picks / adaptive / both).
- Loop-boundary treatment for patterns with internal rests.
- Whether to instrument decision-time distributions by rep count (informational only — does not change scoring).

**Project-philosophy reminder captured**

- Disciplines optimize for best user performance. No artificial difficulty. This applies to *all* disciplines, not just Timing Offset Detection.

---

## Ready for Hand-off

Next workflow step: **`bmad-correct-course`** (insert as new epic before resuming epic-74) — or skip to **`bmad-create-epics-and-stories`** to draft the epic directly.



