---
stepsCompleted: [1, 2, 3, 4, 5, 6]
inputDocuments: []
workflowType: 'research'
lastStep: 6
research_type: 'domain'
research_topic: 'Detecting and training rushing/dragging tendencies in music performance without an explicit metronome reference'
research_goals: 'Survey scientific work and practical pedagogy that could inform a new Peach training discipline. Identify measurement paradigms and stimulus designs that reconcile the apparent contradiction of implying a steady beat while playing notes that are in front of or behind it.'
user_name: 'Michael'
date: '2026-06-04'
web_research_enabled: true
source_verification: true
---

# Research Report: Rushing and Dragging Detection

**Date:** 2026-06-04
**Author:** Michael (research conducted by Adam, music domain expert)
**Research Type:** Domain (scientific literature + practical pedagogy)

---

## Research Overview

Peach already trains single-note timing offset detection (TOD discipline). The proposed new discipline measures something different: a performer's overall tendency to play in front of or behind an implied beat across many notes — distinct from speeding up or slowing down. The training stimulus must imply a steady pulse while simultaneously presenting notes that deviate from it. This report surveys the relevant scientific literature and pedagogical practice to ground the design.

---

## Domain Research Scope Confirmation

**Research Topic:** Detecting and training rushing/dragging tendencies in music performance, without an explicit metronome reference.

**Research Goals:**
- Identify scientific work on perception of timing deviation from an implied beat
- Distinguish rushing/dragging (stable bias) from tempo drift (acceleration/deceleration) in the literature
- Survey pedagogical practice across drum, jazz, and classical traditions
- Find stimulus paradigms where a steady beat is implied while individual notes deviate from it
- Identify candidate measurement approaches and existing tools

**Research Methodology:**
- Web search of music psychology, sensorimotor synchronization, and music pedagogy literature
- Verify claims against primary sources where accessible
- Confidence levels noted where evidence is thin

**Scope Confirmed:** 2026-06-04

---

## 1. The Science of an Implied Beat

The central question — *can a steady beat be implied while notes deliberately deviate from it?* — has an unambiguous answer in the music-cognition literature: **yes, and the mechanism is well characterised.** The relevant constructs are *beat induction* and *neural resonance*.

### 1.1 Missing-pulse phenomenon

Tal et al. (2017, *Journal of Neuroscience*) showed via MEG that the auditory cortex generates neural activity at the beat frequency even when the beat frequency is **physically absent** from the acoustic spectrum of the stimulus. Highly syncopated patterns induce a felt 1 Hz or 2 Hz pulse despite the Fourier spectrum containing no energy at those frequencies. The strength of this internally-generated pulse response correlated with how quickly listeners could tap the implied pulse.

This is the foundational result: a stimulus can robustly imply a pulse it never plays. ([Tal et al., *J Neurosci* 2017](https://pmc.ncbi.nlm.nih.gov/articles/PMC5490067/))

### 1.2 Neural Resonance Theory (Large)

Edward Large's Neural Resonance Theory models beat perception as nonlinear coupling between two oscillator networks — a *sensory* network tracking the stimulus and a *motor* network integrating those inputs. Pulse emerges as a stable oscillation in the motor network, and it can be stable at a frequency the sensory input does not directly contain. The theory accounts for both regular and irregular stimuli, and predicts the missing-pulse phenomenon. ([Large 2015, *Frontiers in Systems Neuroscience*](https://pmc.ncbi.nlm.nih.gov/articles/PMC4658578/); [Music Dynamics Lab GrFNN toolbox](https://musicdynamicslab.uconn.edu/home/multimedia/grfnn-toolbox/pulse-perception-model/))

### 1.3 Bass dominance in timing perception

Hove et al. (2014, *PNAS*) demonstrated that **lower-pitched tones drive timing perception and motor entrainment more strongly than higher-pitched tones**. The encoding of timing at the auditory cortex is better for low pitches; the lower tone has greater influence on both timing perception and motor synchronisation. This is the neuroscientific basis for the bass-and-drums convention in popular music and a directly usable principle for Peach's stimulus design: a low-register voice can carry the implied pulse while a higher-register voice carries the rushing/dragging deviation. ([Hove et al., *PNAS* 2014](https://www.pnas.org/doi/10.1073/pnas.1402039111))

### 1.4 Perceptual thresholds

Friberg & Sundberg (1993, *JASA*) measured the just-noticeable difference (JND) for the timing displacement of a tone embedded in a metrical sequence. The JND was approximately **10 ms** for short notes (< 240 ms) and **~5% of the inter-onset interval** for longer notes. ([Friberg & Sundberg 1993, *JASA*](https://pubs.aip.org/asa/jasa/article/94/3_Supplement/1859/735054/Perception-of-just-noticeable-time-displacement-of); [DiVA full text](https://www.diva-portal.org/smash/get/diva2:1246573/FULLTEXT01.pdf))

Madison & Merker subsequently reported a JND for systematic timing discrepancies of **~2.5% of the beat length for musically trained listeners** and **~4.4% for non-musicians** across tempi between 60 and 200 BPM. ([Sounds Familiar? Datta & Hannon 2022, *APP*](https://link.springer.com/article/10.3758/s13414-021-02393-z))

**Implication for Peach:** at 120 BPM (500 ms beat), the trained-musician JND is ~12.5 ms; offsets below this are below threshold and cannot meaningfully be discriminated. This sets a hard floor on the difficulty range.

---

## 2. Rushing and Dragging as a Stable Tendency

The literature consistently distinguishes a *systematic* (repeating, individual-trait) timing bias from *tempo drift* (gradual acceleration or deceleration). Both can coexist, but they are mechanistically and statistically separable.

### 2.1 Negative Mean Asynchrony (NMA)

The most-studied form of systematic timing bias is the well-replicated finding that humans tap **ahead** of an isochronous metronome — on average between 20 and 80 ms early at moderate tempi. This is Negative Mean Asynchrony.

Key facts from Bruno Repp's review literature ([Repp 2005, *Psychonomic Bulletin & Review*](http://users.df.uba.ar/anita/f1_labo/clase1/repp%20psycho%20bull%20rev%202006%20synchro%20tapping%20review.pdf); [Repp & Su 2013, *Psychonomic Bulletin & Review*](https://link.springer.com/article/10.3758/s13423-012-0371-2)):

- **Individual differences are very large.** Some participants tap up to 180 ms ahead; others near zero.
- **Musical training reduces NMA and reduces variability.** Musicians tap closer to the beat with lower jitter.
- **NMA is a stable trait** for a given individual within a session and across sessions.
- Recent work (Mendoza Garay et al. 2021) refines the classical NMA picture: anticipation tendency is not a fixed bias but covaries with timing variability. ([Tapping ahead of time, Mendoza Garay 2018, *Psychological Research*](https://link.springer.com/article/10.1007/s00426-018-1043-2))

NMA is the closest scientific construct to what Peach wants to measure. *Rushing* in the pedagogical sense and *negative asynchrony* in the SMS literature are the same phenomenon, measured the same way (mean signed deviation across many onsets).

### 2.2 Systematic vs unsystematic microtiming

Madison et al. (2011) and Madison & Sioros (2014) introduced a useful distinction:

- **Systematic microtiming** — repeating, position-specific deviations (e.g., always 20 ms behind on beat 1).
- **Unsystematic microtiming** — non-repeating, position-independent variability.

This maps directly onto Michael's framing: rushing/dragging is a systematic tendency in the *signed-mean* dimension; jitter is unsystematic in the *variance* dimension. The two are independent statistics. ([Madison & Sioros 2014, *Frontiers in Psychology*](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2015.01232/full))

Polak (2010 onward) extended this to non-Western traditions and showed that genre-specific systematic microtiming patterns are reproducible across performances. ([Madison & Sioros review of microtiming research](https://online.ucpress.edu/mp/article/41/3/176/199793/There-s-More-to-Timing-than-TimeInvestigating))

### 2.3 Drift detection and detrending

Linear or nonlinear detrending procedures are the standard tool for separating tempo drift from systematic offset. The signal is decomposed into (a) a slowly-varying tempo component (drift) and (b) residual asynchronies relative to the local instantaneous tempo (offset). Drift is then treated as a nuisance variable for studies of offset. ([Drift detection, Ahissar et al. 2004, *Acta Psychologica*](https://www.sciencedirect.com/science/article/abs/pii/S0001691804000514); [Goebl & Palmer, *Individuality That Is Unheard Of* 2013](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3604639/))

**Implication for Peach:** if Peach's stimulus is built from a fixed, known-tempo MIDI sequence, drift in the stimulus is zero by construction. Drift in user *production* (if Peach later does production training) is detectable and separable from offset by detrending; the discipline can report both numbers independently.

### 2.4 Individual timing fingerprints

Goebl & Palmer (2013) showed that pianists' scale performances contain systematic temporal deviations that recur from one performance to another — an inaudible but measurable "pianistic fingerprint." This corroborates the picture of rushing/dragging tendencies as stable personal traits. ([*Individuality That Is Unheard Of*, Goebl & Palmer 2013](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3604639/))

---

## 3. Implied-Beat Paradigms in Real Music: Soloist Against Rhythm Section

The most directly relevant in-the-wild paradigm is the jazz **soloist-against-rhythm-section** asymmetry, studied quantitatively by Friberg & Sundström and others.

### 3.1 Friberg & Sundström (2002)

Analysing six recorded jazz solos, Friberg & Sundström found that at slow tempi, soloists' downbeats land **after** the cymbal while their offbeats remain **synchronised** with the cymbal. The soloist plays "behind" while the rhythm section establishes a steady pulse. ([Friberg & Sundström 2002, *Music Perception*](https://online.ucpress.edu/mp/article-abstract/19/3/333/61900/Swing-Ratios-and-Ensemble-Timing-in-Jazz))

This is exactly the design Michael needs in miniature: one voice carries the steady pulse; another voice carries the bias.

### 3.2 Downbeat delays as a key swing component

A 2022 *Communications Physics* paper analysed thousands of jazz recordings and confirmed that systematic downbeat delays from soloists are widespread and constitute a measurable component of swing — distinct from swing ratio. ([Downbeat delays in swing, *Communications Physics* 2022](https://www.nature.com/articles/s42005-022-00995-z))

### 3.3 Dilla time

Microtiming analyses of producer J Dilla's beats reveal another in-the-wild model: a **drum machine** carries a strictly quantised pulse while specific drum voices (snare, hi-hat, kick) are programmed to play consistently early or consistently late by tens of milliseconds. The "Dilla feel" *is* a systematic offset against an implied (and partly explicit) grid. ([Manuel 2014, "21st Century Funk: A Microtiming Analysis of the Beats of J Dilla"](https://www.academia.edu/24528600/21st_Century_Funk_A_Microtiming_Analysis_of_the_Beats_of_Hip_Hop_Producer_J_Dilla))

### 3.4 Ensemble-asynchrony perception

Listeners can detect "togetherness" issues in ensemble performances. Wing et al.'s work on string-quartet synchronisation shows listeners are sensitive both to the variance of asynchronies and to their micro-structure. Trained listeners can hear when one voice is consistently early or late, separate from tempo or pitch issues. ([Perception of string quartet synchronization, Wing et al. 2014](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4196478/))

---

## 4. Practical Pedagogy

### 4.1 The dropout / gap-click technique

The dominant pedagogical method for training the internal clock is some form of **click reduction**:

- **Gap click**: metronome plays one bar, drops out one bar (or longer), then returns. The student lands "on" or notices they have drifted. This is the textbook approach for moving the student off external dependence.
- **Sparse click**: click on beats 1+3, on 2+4, on 1 only, or only on the downbeat of each bar. Famously, jazz pedagogy often uses 2+4 (snare-like, energizing); Hal Galper has argued for 1+3 (calming, harmonic-resolution-supporting). ([Hal Galper, "Practice and Performance Goals"](https://halgalper.com/articles/practice-and-performance-goals/); [Hal Galper on technique](https://www.jazzguitar.be/forum/guitar-technique/25823-hal-galper-technique.html))
- **Off-beat click**: click on "and" of every beat. Trains the user to feel the implied downbeat.
- **Probabilistic dropout**: modern app feature where the click drops out at random intervals. ([Eastman Community Music School, *The Metronome*](https://www.esm.rochester.edu/community/the-metronome-getting-started/); [Mastering the Metronome, BlackSwamp](https://www.blackswamp.com/post/mastering-the-metronome-practice-tips-to-improve-your-timing); [Stonekick metronome exercises](https://stonekick.com/blog/metronome-exercises.html))

All of these share an architecture: an **external pulse, partially obscured**, with the student's playing being the part that reveals the deviation. The same architecture works in reverse for Peach: an **internal pulse, perfectly steady, partially obscured behind sparse cues**, with a melodic layer that exhibits the deviation the user must detect.

### 4.2 Recording yourself

Recording and listening back is universally recommended in drum, jazz, and classical pedagogy. The retrospective perspective makes deviations audible that were invisible in the moment. ([Soundbrenner, 5 tips for drummers](https://www.soundbrenner.com/blogs/articles/5-tips-for-drummers-to-avoid-rushing-or-dragging); [Drummer Cafe, Rushing and Dragging](https://drummercafe.com/education/articles-commentary/problems-with-rushing-and-dragging))

### 4.3 "Behind", "on", "on top" as stylistic vocabulary

In jazz, hip-hop, and (some) funk pedagogy, *behind / on / on top* are explicit categories that performers learn to inhabit deliberately, not faults to be eliminated. Dexter Gordon plays back of the beat; Pat Martino plays dead-centre; Erroll Garner switches between feels within a single performance. ([Jazz Guitar Forum: Swinging vs. behind the beat](https://www.jazzguitar.be/forum/improvisation/6262-whats-difference-between-swinging-playing-behind-beat.html); [TalkBass: Walking ahead or on top of the beat](https://www.talkbass.com/threads/walking-ahead-or-on-top-of-the-beat.969486/))

**Implication for Peach:** the discipline should not frame in-front-of and behind-the-beat as **errors**. They are *positions*. Centred is one position among three. The discipline measures *which position* the user tends toward — and ideally trains the user to inhabit any of the three on demand.

### 4.4 Pedagogical literature

Peter Erskine's *Time Awareness for All Musicians* (Alfred) is the most cited generalist text on this topic. It poses Michael's question almost verbatim: "should the phrasing be behind, on, or on top of the beat?" — and treats the answer as something a musician must develop awareness of and choose, not a fixed correct answer. ([Erskine, *Time Awareness for All Musicians*](https://petererskine.com/erskine-books/time-awareness-for-all-musicians/))

---

## 5. Existing Tools

The market gap is significant.

### 5.1 Click-based timing tools

The dominant category — Soundbrenner, MetronomeBot, Tempo, Pro Metronome, etc. — provide variations on the click (subdivisions, polyrhythms, accents, vocal counting, dropout) but always centre on an explicit external pulse. ([Best Metronome Apps for Drummers 2026, Melodics](https://melodics.com/blog/best-metronome-apps-for-drummers-2026); [Best Metronome Apps for Internal Clock, Rhythm Notes](https://rhythmnotes.net/best-metronome-apps/))

### 5.2 Metronome Hero

The closest existing analog to what Peach is contemplating. Metronome Hero scores incoming audio/MIDI for two independent dimensions: **accuracy** (how close each hit lands to the beat) and **consistency** (steadiness over time). It explicitly skews the hit-zone so that *laying back* is scored more generously than *pushing ahead* — encoding the editorial judgement that rushing is the more common and harder-to-self-diagnose fault. ([Metronome Hero](https://metronomehero.com/))

Notably, Metronome Hero is **production-side** (the user plays, the app listens) and **uses a click**. Peach's contemplated discipline can occupy a different niche: **perception-side, no click**.

### 5.3 Rhythm-dictation apps

Apps like Complete Rhythm Trainer, Tenuto, and Rhythm Trainer test the user's ability to *reproduce* or *identify* rhythms but do not directly address rushing/dragging as a tendency. They focus on rhythmic literacy, not time feel.

### 5.4 Conclusion

**No widely-available app trains rushing/dragging perception without a metronome click.** This is the white space the proposed Peach discipline would occupy.

---

## 6. Candidate Measurement Paradigms

Synthesising sections 1–5, five stimulus paradigms emerge as candidates. Each has a different cost/benefit profile.

### A. Bass-establishes-pulse, melody-deviates ("Soloist" paradigm)

A bass-register voice plays a steady, simple pattern (e.g., a walking bass line, a kick-and-hat groove, or a single bass note on every beat). A melody in a higher register plays each note with a fixed offset — uniformly rushed or dragged by *X* ms. The user judges whether the melody is in front, behind, or centred.

- **Strengths**: directly grounded in Hove et al. (bass dominance) and Friberg & Sundström (soloist-against-rhythm-section). Most ecologically valid. Easy to generate procedurally from existing SoundFont infrastructure.
- **Weaknesses**: requires careful balance — too prominent a bass becomes a de-facto metronome.

### B. Missing-pulse paradigm

A syncopated rhythmic pattern that *induces* a felt pulse without playing on that pulse. A target voice then aligns or deviates from the implied pulse.

- **Strengths**: elegant; rigorously matches Tal et al. and NRT.
- **Weaknesses**: fragile — pulse induction is not uniform across listeners; some users may simply not perceive the implied pulse. Probably too research-y for a first release.

### C. Drop-out paradigm

Standard click for *N* bars, click drops out for *M* bars, melody plays during the dropout. The user judges whether the melody was on, ahead, or behind the implied continuation.

- **Strengths**: directly imports the established pedagogical technique; familiar to any user with metronome training; uses a click but only as scaffolding.
- **Weaknesses**: contains a click — partly contradicts Michael's "we don't have the luxury of a metronome beat and that is as it should be." But the click is *gone* during the judgement window, which is arguably the same situation as paradigm A from the perceiver's standpoint.

### D. 2-AFC adaptive threshold

Two short passages: one with mean offset zero, one with mean offset *X*. User picks which has the bias. Staircase to find threshold.

- **Strengths**: maps cleanly to TOD's existing measurement style; rigorous psychophysics; gives a single number per user (rushing/dragging threshold).
- **Weaknesses**: forced-choice between two stimuli is less musical than judging a single passage; pedagogical value of the absolute *direction* judgement (ahead vs behind) is lost in the AFC format. **Mitigation**: use 3-AFC with options "first ahead", "second ahead", "same".

### E. Production-side (tap or play along)

The user taps or plays along with a backing track of bass and drums. Peach measures mean signed asynchrony across *N* onsets, separately reports the variance, classifies the user as rusher / dragger / centred relative to their own variance.

- **Strengths**: maps directly to NMA methodology; gives a number that is comparable to a large scientific literature; trains *production* not just *perception*.
- **Weaknesses**: requires reliable audio input. Peach currently has no MIDI/audio input pipeline. This is a substantial architectural extension beyond a new discipline. Likely a separate epic.

---

## 6A. The Reference-Pulse Question: Solo Performance

Paradigms A–E all carry an external pulse source. In paradigm A it is the bass+drums accompaniment; in paradigm B it is a syncopated pattern induced by acoustic cues; in paradigm C it is a literal click; in paradigm D it is the paired comparison stimulus; in paradigm E it is the backing track. **None of them is a true-solo paradigm.** A reasonable critique is that a bass-and-drums accompaniment, however cleverly arranged, is a metronome dressed up in timbres.

This raises a sharper question: **can rushing/dragging be defined for a soloist at all — independently of intent, and without any accompaniment?**

### 6A.1 The strict answer is no

For a strictly isolated solo performance (no notation, no accompaniment, no listener prior), "rushing" has no operational definition. A solo with every onset shifted by +50 ms is indistinguishable from the same solo performed correctly with a 50 ms earlier start. The performer's own notes define their own grid; without an external anchor, *global* tendency is unmeasurable. This is structurally analogous to absolute pitch needing a reference frequency.

### 6A.2 Soloists are never truly isolated

But the strict-isolation case is empty. Soloists are heard against one of four reference pulses, none of which is an external click:

1. **Notation.** When a piece is notated 4/4 at quarter = 120, the intended grid is fixed by the score. Performance deviates from notation. This is *expressive timing analysis* — well-studied for solo performance (Repp on Schumann's *Träumerei*; Goebl & Palmer 2013 on solo scales).

2. **Self-entrainment within the performance.** The soloist's own earlier notes induce a pulse percept in the listener, and later notes are judged against that internal percept. The listener's brain provides the reference. Neural Resonance Theory and the missing-pulse paradigm (section 1) predict and confirm that the percept persists through gaps and ambiguity in the stimulus.

3. **Genre and metric expectation.** A Bach gigue carries an implied pulse from the moment a competent listener identifies it as a gigue. Harmonic rhythm, phrase shape, and articulation set up strong prior expectations about the local pulse from non-timing cues.

4. **Collective performance practice.** "Most cellists play this passage with these onsets" provides a community-internalised baseline. This is what critics actually mean when they say a solo Bach performance is "behind" — relative to a tradition, not a clock.

Critics, teachers, and listeners use "rushing" and "dragging" for solo performance routinely, and they mean something real every time. They rely on one of these four references without naming it.

### 6A.3 Implication: solo-only paradigms are feasible

If the reference pulse can be provided by the *listener's own entrainment* to a self-consistent passage (option 2 above) or by the *score* (option 1), then paradigms with no accompaniment at all become possible. The implied pulse is constructed inside the listener — exactly the construction Tal et al. and Large describe.

This unlocks three additional paradigms.

### F. Self-entrainment with measurement window

A solo phrase. The first segment is rhythmically unambiguous (clear quarter notes, strong metric cues, repeated downbeat-aligned figures). The listener entrains. The remainder of the phrase continues the implied pulse but is uniformly offset by *X* ms — every onset in the measurement window is rushed or dragged relative to the pulse the first segment induced. The user judges direction.

- **Strengths**: no accompaniment at any point. The listener's brain *is* the metronome, calibrated by the opening. Pedagogically the deepest of the candidates — trains exactly the skill that distinguishes a great musician's ear (hearing whether a solo is keeping its own time). Closest scientific precedent: missing-pulse paradigms where the pulse is internally generated.
- **Weaknesses**: entrainment quality varies across listeners. The boundary between "entraining segment" and "measurement segment" must be perceptually invisible to avoid signposting the answer. Stimulus construction is more delicate.

### G. Two-take A/B (score-as-reference)

Two recordings of the same notated solo phrase. One is centred on its own implied pulse; the other has every onset displaced by *X* ms uniformly. The user picks which is the "rusher" (or dragger).

- **Strengths**: reference is the score (the listener reconstructs the intended grid from the music's structure). Procedurally easy to generate from a single notated source by shifting all onsets. Clean psychometric — forced choice, adaptive staircase.
- **Weaknesses**: forced choice between two stimuli is less musical than judging a single passage; direction information is preserved (user picks *which* is rushing) but the absolute "ahead/behind/centred" judgement is split across two trials. Mitigation: 3-AFC with "first rushes" / "second rushes" / "they match" options.

### H. Phrase-internal position-conditional asymmetry

A solo phrase whose pulse is implied by its own structure (e.g., consistent quarter notes alternating between two pitches, or a clear metric repetition). Even-indexed notes (or downbeats) are on the grid; odd-indexed notes (or offbeats) are offset by *X* ms. The user perceives the offset against the pattern's own implied pulse, fitted implicitly by the brain to the un-offset positions.

- **Strengths**: directly models what Goebl & Palmer measured in solo scale performance (systematic, position-locked deviations against a self-fitted grid). No accompaniment; the soloist's own notes are both the pulse generator and the deviating voice, but at different metric positions. Genuinely novel for a training discipline.
- **Weaknesses**: more abstract framing for users. The user is not detecting "this passage is rushing" but "the offbeats are ahead of the downbeats" — closer to swing-ratio perception than to rushing/dragging proper. May be a *different discipline* rather than a variant of this one.

### 6A.4 What we are actually measuring

Strictly, the new discipline does not train detection of rushing/dragging as a global property of a performance — because, in the strict-isolation case, that property is undefined. What it trains is **detection of deviation from a reference pulse**, where the reference is provided by one of: an accompaniment (A), an inferred missing pulse (B), a remembered click (C), a paired comparison (D, G), a backing track (E), the listener's own entrainment to the opening of the phrase (F), or the phrase's own self-consistent positions (H).

The colloquial framing musicians use ("rushing" / "dragging") and the operational definition ("deviation from an implied pulse") will diverge slightly in any UI copy. This is a copy decision, not a science decision. The colloquial term is the right one for the user — but the implementation must be clear-eyed about what reference each paradigm provides.

---

## 7. Recommendations for Peach Discipline Design

Recommendations updated after section 6A. The bass-and-drums paradigm (A) is still useful but is no longer the headline recommendation — it is an *easier scaffolded level*, not the destination.

### 7.1 Start perception-side, not production-side

The existing TOD discipline is perception-side. The new discipline should be too, for three reasons:

1. Same input model — no MIDI/audio input pipeline needed.
2. Cleaner measurement — every offset is known exactly by construction.
3. Natural progression — the discipline trains *the ear for tendency* before any future production discipline trains *the body to avoid it*.

### 7.2 Build the discipline as a progression of pulse-reference difficulty

The four reference sources identified in section 6A.2 form a natural difficulty gradient — from externally-provided pulse (easy) to entirely listener-constructed pulse (hard). Map paradigms onto that gradient:

1. **Easy — paradigm A (bass+drums establishes pulse).** Accompaniment carries a steady pulse via a low-register voice; melody is offset uniformly. Scientifically supported by Hove et al. (bass dominance) and Friberg & Sundström (soloist-against-rhythm-section). Procedurally easy to generate. Acts as a scaffolded entry point, not a pretence of solo performance.
2. **Medium — paradigm F (self-entrainment with measurement window).** Solo phrase, first segment unambiguous, measurement segment uniformly offset against the entrained pulse. No accompaniment at any point; the listener's brain is the metronome. This is the *pedagogically central* paradigm — it trains the skill of holding an internal pulse against a sole voice.
3. **Hard — paradigm G (two-take A/B with score reference) or H (phrase-internal asymmetry).** Both demand stronger pulse construction from the listener. Paradigm G is procedurally simpler and has cleaner psychometrics; paradigm H is more novel but may belong as a separate discipline.

Paradigm A by itself would be a metronome-in-disguise discipline. Paradigm F by itself may be too hard for entry users. The progression resolves both concerns.

### 7.3 Measure mean signed offset and dispersion as two separate axes

Following Madison & Sioros (systematic vs unsystematic microtiming) and the NMA literature:

- **Bias**: mean signed offset across *N* user judgements (positive = rushing, negative = dragging).
- **Sensitivity**: smallest |X| at which the user can reliably distinguish direction (this is what TOD already does for single notes; for the new discipline it would be the same psychometric, but over a *pattern* offset rather than a *note* offset).

These two numbers correspond to two distinct user-facing claims:
- *"You tend to hear neutral playing as rushed"* (a perceptual bias, mirrors NMA).
- *"You can reliably tell when a passage is ≥ Y ms off-centre"* (a perceptual threshold).

### 7.4 Three-way response format, not two

Pedagogically (Erskine, jazz tradition) and scientifically (the sign of offset matters, not just its magnitude), the response format should be **ahead / centred / behind**, not binary right/wrong. "Centred" is a real third option, not the negation of the other two.

### 7.5 Respect the Performance Principle (CLAUDE.md)

The CLAUDE.md Performance Principle says: do not constrain users for the sake of test purity. Apply this here. Offer the user the *option* of a quiet click in addition to the bass/drum stimulus (training mode), and the option to turn it off (assessment mode). Either configuration should produce a valid measurement; the click only changes the difficulty.

---

## 8. Refined Recommendation Under Implementation Constraints

Sections 1–7 surveyed the field as if the design space were open. For an actual Peach discipline, three further constraints narrow it sharply:

1. **What can easily be realised with the existing machinery** — `SoundFontStepSequencer`, the `Beat`/`Subdivision`/nested-tuplet rhythm abstraction, `SoundFontPlayer`, the existing perception-side session pattern from TOD. No audio/MIDI input. No new generative content beyond what the step sequencer can already play.
2. **This is not about intentional microtiming.** Rushing/dragging here is *not* a stylistic position (Dilla feel, jazz "behind", swing ratio). Those phenomena were useful as scientific anchors in the literature review, but the training target is different.
3. **It is about detecting insecure timing manifested as rushing/dragging.** The target performer in the user's ear is not a master who chose to play behind — it is a learner whose internal pulse drifts off-centre without their awareness. The NMA literature (section 2.1) is the right scientific anchor: large signed asynchronies that the performer does not intend and often cannot self-diagnose.
4. **Tendency, not single note.** Unlike TOD (which tests perception of one note's offset), this discipline tests perception of a *bias across many notes*.

### 8.1 What these constraints eliminate

- **Paradigm B (missing pulse).** Too research-y; stimulus construction is delicate beyond what the step sequencer naturally produces. Cut.
- **Paradigm C (drop-out with click).** Uses a metronome click — conceptually fine pedagogically, but does not advance over what existing metronome apps already do, and contradicts the Peach principle of training without a click. Cut.
- **Paradigm E (production-side).** Requires audio/MIDI input pipeline. Out of machinery scope. Cut.
- **Paradigm H (phrase-internal asymmetry).** Position-conditional offset between downbeats and offbeats *is* swing-ratio / intentional microtiming structure. Explicitly out of scope per constraint 2. Cut, with a note that it could be a separate discipline later if Peach ever wanted to train swing-ratio perception.
- **Paradigm A (bass+drums establishes pulse).** Operationally a metronome with timbral dressing. Provides no advance over click-based tools. The literature endorses it (Hove et al., Friberg & Sundström) as a *real-music* paradigm — but Peach is not modelling real-music ensemble timing, it is training the user's ear for insecure timing. Cut as a primary paradigm. Optionally retain as a *scaffolded entry difficulty level* — see 8.4.

### 8.2 What survives

Two paradigms fit all four constraints:

- **Paradigm F — self-entrainment with measurement window.** Single solo voice. First segment establishes the pulse via clear metric structure; second segment continues with all onsets uniformly offset by *X* ms. User judges direction of the second segment (ahead / centred / behind).
- **Paradigm G — two-take A/B (with score reference).** Two playbacks of the same notated pattern. One is on-grid; the other has every onset displaced by *X* ms. User picks which is the rusher.

Both are implementable with the existing step sequencer: each note in the pattern can be scheduled with an explicit timing offset against its nominal grid position.

### 8.3 Recommended primary paradigm: F

Paradigm F is the recommended design, for four reasons.

1. **Single-trial flow matches TOD.** One stimulus per trial, one judgement per trial. Session shape is essentially `playingEntrainmentSegment` → `playingMeasurementSegment` → `awaitingAnswer` → `showingFeedback` → loop. This drops cleanly into the existing `TrainingSession` protocol.
2. **No accompaniment, no metronome.** Honours the project principle. The listener's own entrainment is the reference; the discipline trains *the act of holding internal time*, which is the actual skill behind insecure timing.
3. **Tendency framing is built in.** Every onset in the measurement segment carries the same offset. The user accumulates evidence over many notes, exactly the discipline-defining difference from TOD.
4. **Procedurally generable.** A repeating quarter-note or eighth-note pattern on a single SoundFont voice, with the second half of the pattern uniformly offset. No new musical content infrastructure required.

The transition between entrainment and measurement segments must be seamless — same pitch material, same loudness, same articulation. Only the timing of onsets changes. Whether the offset begins at a bar boundary, a phrase boundary, or mid-phrase is an open empirical question (see 9.6) but does not affect feasibility.

### 8.4 Optional scaffolding: paradigm A as an easier mode

Paradigm A (bass+drums under a melody) was rejected as the primary paradigm but can survive as a training-only, *easier* difficulty level — explicitly marked as scaffolding. In this mode, an accompaniment voice carries the pulse externally, and the user learns to detect the melody's offset against an audible reference before being asked to do the same with only an internal reference (paradigm F). The accompaniment in this mode is acknowledged as a soft metronome; this is a feature of the scaffolding, not a hidden defect.

Whether to ship paradigm A at all is a scope decision. The initial release could plausibly ship paradigm F alone; paradigm A could be added later if user testing shows entrainment quality is a barrier.

### 8.5 Paradigm G as deferred fallback

Paradigm G (two-take A/B) is a viable alternative if paradigm F's entrainment proves unreliable in pilot testing. Same step-sequencer machinery, different trial structure (two stimuli per judgement instead of one). Keep in mind as a fallback but do not build first.

### 8.6 What the discipline is, in one sentence

*Given a single-voice pattern whose opening establishes a pulse, judge whether the continuation falls in front of, behind, or on that pulse.*

This is the operational definition. The user-facing description should use the colloquial "rushing / dragging / on time," as established in section 6A.4.

---

## 9. Open Questions for Adam to Consult on Further

Open questions narrowed to those that remain after section 8.

1. **Length of the entrainment segment.** How many onsets must precede the measurement window for the listener to form a robust pulse percept that survives the transition? The NMA literature suggests ≥ 20 paced onsets stabilises a participant's tapping; perception likely entrains faster but the boundary is not well-studied. Pilot at 4, 8, and 16 onsets.
2. **Length of the measurement segment.** Pattern bias is detectable in fewer onsets than NMA studies typically use (those measure production variance). Pilot at 4, 8, and 16 measurement onsets.
3. **Whether to mark or hide the boundary.** If the entrainment-to-measurement transition is perceptually invisible (same pitch, same instrument, same loudness), only the offset reveals it — which is the goal. But if listeners cannot identify where measurement begins, accumulation of evidence may feel arbitrary. Worth piloting both an unmarked boundary and one with a soft cue (e.g., a slight register shift or a phrase-marking rest).
4. **Tempo range.** Friberg/Madison JNDs are ~2.5% of beat length (musicians) across 60–200 BPM. At 80 BPM (750 ms beat) the trained JND is ~19 ms — workable. At 160 BPM (375 ms beat) it falls to ~9 ms, close to the perceptual floor. Recommend a 70–110 BPM band initially.
5. **Choice of pattern content.** A repeating short figure (e.g., eighth notes, or a four-note motif looped) maximises entrainment reliability and is trivially generable from the step sequencer. Worth keeping the first release to a single, fixed pattern type and adding variety later.
6. **Stimulus voicing.** Piano (clear onsets) is the safest starting choice. Legato voicings inflate JND by softening onset perception; pitched percussion is sharper but less musical. Start with piano-on-piano, revisit after pilot.
7. **Single-direction levels vs. mixed-sign trials.** A given session can present only-rushing trials, only-dragging trials, or mixed-sign trials. Mixed-sign is the standard psychophysical design (it prevents response bias) and should be the default; single-direction is a possible practice-only mode.

---

## 10. Citations and Sources

Primary sources, grouped by topic.

**Implied beat / neural mechanism:**
- Tal et al. (2017). *Neural Entrainment to the Beat: The "Missing-Pulse" Phenomenon.* J Neurosci. <https://pmc.ncbi.nlm.nih.gov/articles/PMC5490067/>
- Large (2015). *Neural Networks for Beat Perception in Musical Rhythm.* Frontiers in Systems Neuroscience. <https://pmc.ncbi.nlm.nih.gov/articles/PMC4658578/>
- Hove et al. (2014). *Superior time perception for lower musical pitch explains why bass-ranged instruments lay down musical rhythms.* PNAS. <https://www.pnas.org/doi/10.1073/pnas.1402039111>

**JND for timing displacement:**
- Friberg & Sundberg (1993). *Perception of just-noticeable time displacement of a tone presented in a metrical sequence at different tempos.* JASA. <https://www.diva-portal.org/smash/get/diva2:1246573/FULLTEXT01.pdf>

**Sensorimotor synchronisation and NMA:**
- Repp (2005). *Sensorimotor synchronization: A review of the tapping literature.* Psychonomic Bulletin & Review. <http://users.df.uba.ar/anita/f1_labo/clase1/repp%20psycho%20bull%20rev%202006%20synchro%20tapping%20review.pdf>
- Repp & Su (2013). *Sensorimotor synchronization: A review of recent research (2006–2012).* Psychonomic Bulletin & Review. <https://link.springer.com/article/10.3758/s13423-012-0371-2>
- Mendoza Garay (2018). *Tapping ahead of time: its association with timing variability.* Psychological Research. <https://link.springer.com/article/10.1007/s00426-018-1043-2>

**Microtiming / soloist-against-rhythm-section:**
- Friberg & Sundström (2002). *Swing Ratios and Ensemble Timing in Jazz Performance.* Music Perception. <https://online.ucpress.edu/mp/article-abstract/19/3/333/61900/Swing-Ratios-and-Ensemble-Timing-in-Jazz>
- Downbeat delays in swing (2022). Communications Physics. <https://www.nature.com/articles/s42005-022-00995-z>
- Madison & Sioros (2014). *Microtiming in Swing and Funk affects the body movement behavior of music expert listeners.* Frontiers in Psychology. <https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2015.01232/full>
- *There's More to Timing than Time* (microtiming review). Music Perception. <https://online.ucpress.edu/mp/article/41/3/176/199793/There-s-More-to-Timing-than-TimeInvestigating>
- Manuel (2014). *21st Century Funk: A Microtiming Analysis of the Beats of Hip Hop Producer J Dilla.* <https://www.academia.edu/24528600/21st_Century_Funk_A_Microtiming_Analysis_of_the_Beats_of_Hip_Hop_Producer_J_Dilla>

**Drift vs offset, individual timing fingerprints:**
- Drift detection in sound sequences. Acta Psychologica. <https://www.sciencedirect.com/science/article/abs/pii/S0001691804000514>
- Goebl & Palmer (2013). *Individuality That Is Unheard Of: Systematic Temporal Deviations in Scale Playing Leave an Inaudible Pianistic Fingerprint.* <https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3604639/>

**Ensemble synchronisation perception:**
- Wing et al. *Perception of string quartet synchronization.* <https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4196478/>

**Pedagogy:**
- Galper, *Practice and Performance Goals.* <https://halgalper.com/articles/practice-and-performance-goals/>
- Erskine, *Time Awareness for All Musicians.* <https://petererskine.com/erskine-books/time-awareness-for-all-musicians/>
- Eastman Community Music School, *The Metronome: Getting Started.* <https://www.esm.rochester.edu/community/the-metronome-getting-started/>
- BlackSwamp Percussion, *Mastering the Metronome.* <https://www.blackswamp.com/post/mastering-the-metronome-practice-tips-to-improve-your-timing>
- Soundbrenner, *5 tips for drummers to avoid rushing or dragging.* <https://www.soundbrenner.com/blogs/articles/5-tips-for-drummers-to-avoid-rushing-or-dragging>
- Drummer Cafe, *Problems and Solutions With Rushing and Dragging.* <https://drummercafe.com/education/articles-commentary/problems-with-rushing-and-dragging>
- Jazz Guitar Forum, *Swinging vs. behind the beat.* <https://www.jazzguitar.be/forum/improvisation/6262-whats-difference-between-swinging-playing-behind-beat.html>

**Existing tools:**
- Metronome Hero. <https://metronomehero.com/>
- Best Metronome Apps for Drummers 2026. <https://melodics.com/blog/best-metronome-apps-for-drummers-2026>

---

## Research Status

**Steps completed:** 1–8 (scope confirmation through synthesis).
**Confidence:** High on the science (sections 1–3, well-cited primary literature). Medium on the in-the-wild paradigms (section 3; the soloist-rhythm-section pattern is robust, the Dilla literature is more analytical than experimental). High on pedagogy (section 4; consensus across sources). High on the market gap claim (section 5).

**Author's note (Adam):** This was a particularly clean research question — the contradiction Michael identified ("imply a steady beat AND play notes that deviate from it") has a precise scientific name (*missing pulse* / *neural resonance*), a measurable signature (NMA / systematic microtiming), an in-the-wild musical model (soloist against rhythm section), and an established pedagogical lineage (dropout metronome, sparse click).

The document went through two rounds of narrowing:

- **Section 6A** was added after Michael pushed back that a bass-and-drums accompaniment is essentially a metronome in disguise. That forced a sharper analysis of what reference pulse rushing/dragging is measured *against*, and produced three additional paradigms (F, G, H) that use no accompaniment.
- **Section 8** was added after Michael imposed three further constraints: implementability with the existing `SoundFontStepSequencer` machinery, not-about-intentional-microtiming, and tendency-not-single-note. Those constraints eliminated paradigms B, C, E, H outright and demoted A to optional scaffolding. The recommendation converged on **paradigm F (self-entrainment with measurement window)** as the primary design, with paradigm G as a deferred fallback.

The operational one-sentence definition of the discipline: *given a single-voice pattern whose opening establishes a pulse, judge whether the continuation falls in front of, behind, or on that pulse.* The two independent scoring axes (bias and sensitivity) and the three-way response (ahead / centred / behind) are retained from the earlier recommendation. That is the design I would defend in a working session before story drafting begins.
