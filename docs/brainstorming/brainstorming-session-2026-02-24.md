---
stepsCompleted: [1, 2, 3]
inputDocuments: []
session_topic: 'Note selection strategy for pitch discrimination training'
session_goals: 'Determine the best note selection approach, grounded in perceptual learning research'
selected_approach: 'AI-Recommended'
techniques_used: ['reframing', 'assumption-challenging', 'literature-review']
ideas_generated: []
context_file: ''
---

# Brainstorming Session Results

**Facilitator:** Michael
**Date:** 2026-02-24

## Session Overview

**Initial Topic:** Design a new NextNoteStrategy with a tunable parameter controlling how aggressively the algorithm reacts to mistakes (jumping to weak spots vs. staying in the neighborhood).

**Evolved Topic:** Through brainstorming, the question shifted fundamentally from "what new complex strategy do we need?" to "is the existing simple KazezNoteStrategy already close to what we need?"

## Brainstorming Journey

### Starting Point: Dissatisfaction with AdaptiveNoteStrategy

The `naturalVsMechanical` parameter in AdaptiveNoteStrategy controls a probabilistic coin flip between selecting nearby notes ("natural") and jumping to weak spots ("mechanical"). The initial complaint was that this naming is unintuitive and the parameter doesn't capture the right concept. The initial idea was a new strategy where note selection reacts to recent mistakes with adjustable "insistence."

### Key Reframing: Is Pitch Discrimination One Skill or Many?

The brainstorming took a critical turn when we examined the assumption that different MIDI notes represent different skills to be trained separately. Michael's experience with the app showed:

- **Thresholds are roughly uniform across the range** (except at the extremes)
- **"Weak spots" in the profile are mostly data collection artifacts**, not real perceptual differences
- **Thresholds vary considerably between sessions** (3 cents one day, 8 cents the next), which is normal
- **Jumping to a "weak spot" with a different stored difficulty is annoying** because the difficulty mismatch is artificial - it reflects stale or sparse data, not the user's actual current ability

This meant the entire AdaptiveNoteStrategy complexity - weak spot detection, natural vs. mechanical balance, per-note difficulty tracking, weighted effective difficulty from neighbors - was solving a problem that doesn't exist.

### The Real Question: Why Move Between Notes At All?

If pitch discrimination is one skill with one threshold, the most efficient approach would be to stay at a single note and let Kazez converge. We identified several reasons to still move between notes:

1. **Habituation avoidance** - prolonged exposure to one frequency causes stimulus-specific neural adaptation
2. **Boredom prevention** - hearing the same frequency 50 times is numbing
3. **Profile completeness** - collecting data across the range for display purposes
4. **Verification** - confirming the threshold is indeed uniform, catching edge-of-range differences

### Critical Distinction: Note Jumping vs. Difficulty Jumping

Random note selection across the range is **not** annoying in itself. What is annoying is when note jumping is **combined with difficulty jumping** - landing on a note with a different stored difficulty and being presented with a trivially easy or frustratingly hard comparison that doesn't match the user's current ability.

The KazezNoteStrategy already solves this: it carries the difficulty chain continuously via `lastComparison`, regardless of which note is selected. The difficulty never jumps.

### Conclusion: Promote KazezNoteStrategy

The existing `KazezNoteStrategy` already implements the core of what's needed:

- **Single continuous difficulty chain** across note changes (no difficulty jumps)
- **Random note selection** (prevents habituation, provides coverage)
- **Stateless** (no complex state to manage)
- **Ignores per-note profile data for note selection** (correct, since it's one skill)

It needs only minor refinements to become the primary training strategy:

1. Respect `settings.noteRangeMin/Max` instead of hardcoded MIDI 48-72
2. Smarter cold start using profile data instead of always starting at `maxCentDifference`
3. Keep AdaptiveNoteStrategy around for potential future use

## Literature Review: Pitch Discrimination Training

### Transfer Across Frequencies

Frequency discrimination learning is **mostly generalizable** across frequencies. The frequency-specific component is small and barely statistically significant.

- Hawkey et al. (2004) tested at 750, 1500, 3000, and 6000 Hz and found cross-frequency transfer was strong and essentially complete. The ratio of improvement at trained vs. untrained frequencies was not statistically significant (2.3-fold vs. 2.0-fold).
- Irvine et al. (2000) found a frequency-specific component that was barely significant (p = 0.049), while overall improvement was highly significant (p = 0.00001).
- Micheyl et al. (2012) found partial pitch specificity only when controlling for spectral region, and this specificity disappeared rapidly during multi-frequency post-training.

**Implication:** Treating pitch discrimination as one unified skill is well-supported. Per-note "weak spots" likely reflect data sparsity, not real perceptual differences.

### Roving vs. Fixed-Frequency Paradigms

Amitay et al. (2005) compared fixed-standard, slight-roving, and wide-roving conditions for frequency discrimination training:

- **For good listeners:** Wide roving paradoxically did not hurt compared to narrow roving. Fixed-frequency training produced faster initial convergence but **failed to transfer to roving conditions**.
- **For poor listeners:** Any variation slowed learning.
- Training with roving may build more robust, generalizable representations.

**Implication:** Random note selection (as in KazezNoteStrategy) is not just acceptable - it may produce more robust training. Consider narrower roving ranges for beginners.

### Stimulus-Specific Adaptation and Habituation

Repeated exposure to the same frequency causes neural adaptation that is **frequency-specific**:

- Neural responses to a repeated frequency decline over time while responses to novel frequencies remain strong (stimulus-specific adaptation).
- Switching frequencies "dishabituates" the neural response.
- This occurs even at moderate stimulus levels.

**Implication:** Periodically changing the note during training maintains neural responsiveness. This is a concrete scientific reason to roam across frequencies.

### Session Length and Learning Efficiency

Molloy et al. (2012) compared 100, 200, 400, and 800 trials/day:

- **100 trials (~8 minutes)** showed significantly faster learning in early stages than all longer groups.
- **800 trials (>1 hour)** showed the slowest learning with performance deteriorating toward session end.
- All groups reached equivalent final performance - "more training is not necessarily better."
- Between-session improvements (overnight consolidation) did the heavy lifting.

Banai & Lavner (2014) found that a 30-minute break mid-session completely abolished across-day improvement, while continuous practice and breaks under 6 minutes preserved learning.

**Implication:** Short, uninterrupted sessions are optimal. The algorithm doesn't need to be complex because there aren't many trials per session.

### Minimum Training Volume for Consolidation

Research indicates >360 trials/day are required for learning to consolidate across days. Below this threshold, the "transient memory store" may not reach the learning threshold.

**Implication:** Sessions should aim for at least 360 comparisons to ensure cross-day benefit, though the optimal range appears to be 360-400 trials. Going much beyond this yields diminishing or negative returns.

### Adaptive Psychophysical Methods

Standard staircase methods (like Kazez) require ~100+ trials for reliable threshold estimates. Bayesian methods (QUEST) can achieve reliable estimates in ~30 trials.

- 80-trial blocks are a practical optimum for staircase procedures in learning studies.
- The Kazez √P-scaled formula is a variant of traditional staircase methods with smoother convergence properties.

**Implication:** The Kazez convergence chain is a reasonable adaptive method. QUEST could be more efficient but would be a larger architectural change.

### Sleep and Overnight Consolidation

Auditory discrimination performance improves significantly after retention periods that include sleep but not after equivalent time awake. Training before sleep correlates with next-day improvement proportional to sleep duration.

**Implication:** Spacing sessions across days (with sleep between) is beneficial. The algorithm should focus on maximizing within-session efficiency rather than trying to achieve all improvement in one sitting.

### Typical Thresholds

- Untrained non-musicians: ~16-22 cents (some start at 50-100+ cents)
- Trained musicians: ~8-11 cents
- Optimal laboratory conditions: as low as ~3.5 cents
- Non-musicians reached musician-level performance after 4-8 hours of laboratory training

## References

- Amitay, S., Irwin, A., & Moore, D. R. (2005). Auditory frequency discrimination learning is affected by stimulus variability. *Perception & Psychophysics*.
- Banai, K., & Lavner, Y. (2014). Disruption of Perceptual Learning by a Brief Practice Break. *PLOS ONE*.
- Delhommeau, K., Micheyl, C., Jouvent, R., & Collet, L. (2002). Transfer of learning across durations and ears in auditory frequency discrimination. *Perception & Psychophysics*.
- Hawkey, D. J. C., Amitay, S., & Moore, D. R. (2004). Early and rapid perceptual learning. *Nature Neuroscience*.
- Irvine, D. R. F., Martin, R. L., Klimkeit, E., & Smith, R. (2000). Specificity of perceptual learning in a frequency discrimination task. *Journal of the Acoustical Society of America*.
- Kazez, D., Kazez, B., Zembar, M. J., & Andrews, D. (2001). A Computer Program for Testing (and Improving?) Pitch Perception. *College Music Society National Conference*.
- Leek, M. R. (2001). Adaptive procedures in psychophysical research. *Perception & Psychophysics*.
- Levitt, H. (1971). Transformed Up-Down Methods in Psychoacoustics. *Journal of the Acoustical Society of America*.
- Micheyl, C., Delhommeau, K., Perrot, X., & Oxenham, A. J. (2006). Influence of musical and psychoacoustical training on pitch discrimination. *Hearing Research*.
- Micheyl, C., Divis, K., Wrobleski, D. M., & Bhatt, A. (2012). Does Fundamental-Frequency Discrimination Measure Virtual Pitch Discrimination? *Journal of the Acoustical Society of America*.
- Molloy, K., Moore, D. R., Sohoglu, E., & Amitay, S. (2012). Less Is More: Latent Learning Is Maximized by Shorter Training Sessions in Auditory Perceptual Learning. *PLOS ONE*.
- Watson, A. B., & Pelli, D. G. (1983). QUEST: A Bayesian adaptive psychometric method. *Perception & Psychophysics*.
