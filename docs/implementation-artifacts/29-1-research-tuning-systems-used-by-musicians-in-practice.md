# Story 29.1: Research Tuning Systems Used by Musicians in Practice

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer preparing to add alternative tuning systems to Peach**,
I want the music domain expert (Adam) to research which tuning systems beyond 12-TET are actually used by musicians in practice — who uses them, in what contexts, and what value they offer for ear training,
so that Epic 30's implementation targets the most practically relevant tuning system rather than a theoretically interesting but rarely used one.

## Acceptance Criteria

1. Adam identifies the major tuning system families beyond 12-TET (equal temperaments, just intonation variants, Pythagorean, well temperaments, historical meantone, non-Western systems) and classifies each by practical usage frequency
2. For each tuning system family, Adam documents: who uses it (instrument types, ensemble contexts, genres), what problem it solves compared to 12-TET, and whether it is actively taught or encountered by working musicians
3. Adam assesses which tuning systems are relevant for ear training specifically — distinguishing between "theoretically important" and "practically useful for training a musician's ear"
4. Adam evaluates each candidate against the Peach architecture constraints established in stories 28.1 and 28.2: fixed-ratio (position-independent) interval offsets via `centOffset(for:)`, cent offset values within ±200 cents of the 12-TET grid, and no changes to `frequency(for:referencePitch:)` or the `NotePlayer` pipeline
5. Adam recommends the single most relevant tuning system for Peach to implement first, with a clear rationale based on: practical relevance to musicians, pedagogical value for ear training, architectural fit with the existing codebase, and implementation simplicity
6. Adam provides the complete cent offset table for the recommended tuning system (all 13 intervals P1–P8), ready for direct use in `TuningSystem.centOffset(for:)`
7. Adam identifies any edge cases or limitations that the recommended tuning system introduces (e.g., intervals that don't map cleanly to the fixed-ratio model, cultural/pedagogical caveats)
8. The research report is saved as a document in `docs/implementation-artifacts/`
9. If the research reveals that the `centOffset(for:)` API shape (position-independent) is insufficient for the recommended system, Adam documents the gap and proposes a migration path

## Tasks / Subtasks

- [x] Task 1: Load the Adam agent persona (`/bmad-agent-music-domain-expert`) (AC: all)
- [x] Task 2: Survey tuning system families and practical usage (AC: #1, #2)
  - [x] 2.1 Equal temperament variants (19-TET, 31-TET, 53-TET, etc.) — who uses them, where
  - [x] 2.2 Just intonation — fixed-ratio intervals (5-limit, 7-limit) as used in ear training and choral/ensemble practice
  - [x] 2.3 Pythagorean tuning — historical and pedagogical significance
  - [x] 2.4 Well temperaments (Werckmeister, Kirnberger, Vallotti) — historical keyboard practice
  - [x] 2.5 Meantone temperaments (quarter-comma, third-comma) — Renaissance/Baroque practice
  - [x] 2.6 Non-Western tuning systems — brief survey of practical relevance for Peach's target audience
- [x] Task 3: Ear training relevance assessment (AC: #3)
  - [x] 3.1 Which tuning systems are actively used in ear training curricula?
  - [x] 3.2 What pedagogical value does non-12-TET ear training offer to working musicians?
  - [x] 3.3 Which systems help musicians understand intonation differences they encounter in practice (e.g., string quartet tuning, choral intonation)?
- [x] Task 4: Architecture compatibility assessment (AC: #4, #9)
  - [x] 4.1 Classify each candidate as "position-independent" (fits `centOffset(for:)`) or "position-dependent" (would require API extension)
  - [x] 4.2 Verify cent offset ranges against ±200 cent pipeline limit
  - [x] 4.3 Confirm no pipeline changes needed for compatible candidates (cross-reference 28.2 conclusions)
- [x] Task 5: Recommendation and cent offset table (AC: #5, #6, #7)
  - [x] 5.1 Score each candidate on: practical relevance, pedagogical value, architectural fit, implementation simplicity
  - [x] 5.2 Recommend the top candidate with full rationale
  - [x] 5.3 Provide the complete cent offset table (P1–P8) for the recommended system
  - [x] 5.4 Document edge cases and limitations
- [x] Task 6: Write research report (AC: #8)
  - [x] 6.1 Executive summary with recommendation
  - [x] 6.2 Tuning system survey with usage classification
  - [x] 6.3 Ear training relevance analysis
  - [x] 6.4 Architecture compatibility matrix
  - [x] 6.5 Recommended system detail with cent offset table
  - [x] 6.6 Save report to `docs/implementation-artifacts/`

## Dev Notes

### This is a research story — NOT a code implementation story

The dev agent for this story should:
1. Load the Adam agent persona via `/bmad-agent-music-domain-expert`
2. Use Adam's domain expertise to survey tuning systems with practical, not just theoretical, knowledge
3. Use web research to verify current usage patterns and ear training curricula
4. Produce a written research report as the primary deliverable
5. **Do NOT make code changes** — the report informs Epic 30's implementation

### Architecture Constraints from Epic 28 Audits

**From story 28.1 (Domain Types Audit):**

- `centOffset(for:)` assumes interval size is position-independent — holds for equal temperaments and fixed-ratio interval sets, fails for well temperaments and full just-intonation scales
- No ear training app in common use implements position-dependent tuning — the limitation is acceptable
- The `frequency(for:referencePitch:)` formula is universal via the cents mechanism — no changes needed for any tuning system
- `centOffset(for:)` is the designed extension point: add a new `TuningSystem` case with its own switch branch

**From story 28.2 (NotePlayer Pipeline Audit):**

- Pipeline handles non-12-TET intervals correctly — verified with just P5 (+1.955 cents) and just M3 (-13.686 cents)
- ±200 cent pitch bend range accommodates all common non-12-TET deviations with margin (largest common deviation: ~31 cents for septimal minor seventh)
- End-to-end precision: 0.025 cents worst case — 4x below 0.1-cent NFR14 target
- No pipeline changes required to support non-12-TET tuning systems
- `decompose()` correctly rounds to the nearest MIDI note for all tested non-12-TET frequencies

**Key constraint summary:**
The recommended tuning system MUST be "fixed-ratio" — each interval has a single cent value regardless of root note. This is the only model that fits `centOffset(for: Interval) -> Double` without API changes.

### FR55 Requirement

> System supports multiple tuning systems beyond 12-TET (e.g., Just Intonation); adding a new tuning system requires no changes to interval or training logic.

The research must verify that the recommended system satisfies FR55: only a new `TuningSystem` case and its `centOffset(for:)` switch branch should be needed.

### What Epic 30 Needs from This Research

Epic 30 will implement the recommended tuning system. It needs:
1. **The chosen system name** — for the `TuningSystem` enum case (e.g., `.justIntonation`)
2. **Complete cent offset table** — all 13 intervals (P1 through P8) in cents, ready for the `centOffset(for:)` switch
3. **Storage identifier** — for `storageIdentifier` and `fromStorageIdentifier()` (e.g., `"justIntonation"`)
4. **Localized display name** — English and German names for the Settings picker
5. **User-facing description** — what this tuning system is and why a musician might want to train with it
6. **Edge case documentation** — any intervals where the fixed-ratio model is a simplification

### Previous Story Intelligence

**28.1 Findings relevant to this research:**
- F-2: `centOffset(for:)` API shape limits generalizability to position-independent systems — this is the key constraint
- F-6: `centOffset(for:)` is unused in production but is the designed extension point for new tuning systems
- Architecture verdict: "No changes needed for adding fixed-ratio tuning system variants (the expected use case for Epic 29/30)"

**28.2 Findings relevant to this research:**
- Just P5 (+1.955 cents from 12-TET) and just M3 (-13.686 cents) both traced through the full pipeline correctly
- Septimal minor seventh (-31.174 cents) is within the ±200 cent pitch bend range
- All "12-TET-looking" code is actually MIDI spec infrastructure, not tuning assumptions
- Conclusion: "No pipeline changes are required to support non-12-TET tuning systems"

### Git Intelligence

Recent commits (all in Epic 28):
- `2f5c355` Review story 28.2: Audit NotePlayer and Frequency Computation Chain
- `c9ccf11` Implement story 28.2: Audit NotePlayer and Frequency Computation Chain
- `aefa316` Review story 28.1: Audit Interval and TuningSystem Domain Types
- `f68ce92` Implement story 28.1: Audit Interval and TuningSystem Domain Types
- `9b84156` Sprint planning: add epics 28-30 for tuning system research and implementation

### Project Structure Notes

- Tuning system implementation: `Peach/Core/Audio/TuningSystem.swift`
- Current implementation: single `.equalTemperament` case with `centOffset(for:)` returning `semitones * 100.0`
- Tests: `PeachTests/Core/Audio/TuningSystemTests.swift` (25 tests covering cent offsets for all intervals, frequency precision, storage identifiers)
- Research report output: `docs/implementation-artifacts/29-1-research-report-tuning-systems-used-by-musicians.md`

### References

- [Source: Peach/Core/Audio/TuningSystem.swift] — Current TuningSystem enum with `.equalTemperament` only
- [Source: docs/implementation-artifacts/28-1-audit-report-interval-and-tuningsystem-domain-types.md] — Domain types audit (F-2 on centOffset API shape, generalizability assessment)
- [Source: docs/implementation-artifacts/28-2-audit-report-noteplayer-and-frequency-computation-chain.md] — Pipeline audit (non-12-TET generalizability, precision analysis)
- [Source: docs/implementation-artifacts/28-2-audit-noteplayer-and-frequency-computation-chain.md] — Story 28.2 file (previous story intelligence)
- [Source: docs/implementation-artifacts/28-1-audit-interval-and-tuningsystem-domain-types.md] — Story 28.1 file
- [Source: docs/project-context.md] — Two-world architecture, domain rules, NFR14 (0.1-cent precision)
- [Source: docs/planning-artifacts/architecture.md] — Architecture Decision Document
- [Source: PeachTests/Core/Audio/TuningSystemTests.swift] — 25 tests for TuningSystem

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (claude-opus-4-6)

### Debug Log References

No debug issues encountered. This is a research story with no code changes.

### Completion Notes List

- **Task 1:** Loaded Adam (Music Domain Expert) agent persona from `_bmad/standalone/agents/music-domain-expert.md`. Adopted domain expertise for all subsequent research tasks.
- **Task 2:** Surveyed six tuning system families with practical usage classification:
  - Equal temperament variants (19-TET, 31-TET, 53-TET): experimental/niche, no practical relevance
  - 5-limit Just Intonation: core practical relevance — used daily by string quartets, choirs, wind ensembles
  - Pythagorean: partial practical use (fifths/fourths), pedagogically significant
  - Well temperaments: historical keyboard niche, position-dependent (breaks API)
  - Meantone: historical early music niche, position-dependent (breaks API)
  - Non-Western systems: architecturally incompatible with Western interval model
- **Task 3:** Assessed ear training relevance. Only JI is regularly used in music education ear training curricula. JI training develops ensemble tuning skills, chord tuning awareness, and intonation flexibility. Web research confirmed existing apps (INTUNATOR, tuneUp, Sonofield) are adding JI support.
- **Task 4:** Architecture compatibility assessment confirmed: JI is position-independent (fits `centOffset(for:)`), all deviations within ±18¢ (well within ±200¢ limit), no pipeline changes needed. Well temperaments and meantone are position-dependent and incompatible. FR55 fully satisfied. AC #9 finding: the `centOffset(for:)` API shape is sufficient for the recommended system.
- **Task 5:** Recommended 5-limit Just Intonation, scoring 19/20 on practical relevance, pedagogical value, architectural fit, and implementation simplicity. Provided complete 13-interval cent offset table. Documented 4 edge cases: broken M2/m7 octave complement (syntonic comma), tritone ambiguity (45/32 vs 64/45), m7 ratio choice (9/5 vs 16/9 vs 7/4), position-independence as a simplification of real-world JI.
- **Task 6:** Wrote comprehensive research report (6 sections + 2 appendices) saved to `docs/implementation-artifacts/29-1-research-report-tuning-systems-used-by-musicians.md`. Report includes all deliverables Epic 30 needs: system name (`.justIntonation`), storage identifier (`"justIntonation"`), localized names (EN: "Just Intonation", DE: "Reine Stimmung"), user-facing descriptions, complete cent offset table, Swift implementation preview, and edge case documentation.

### Implementation Plan

This is a research story. No code was changed. The research report is the sole deliverable.

### Senior Developer Review (AI)

**Reviewer:** Michael (via adversarial code review workflow)
**Date:** 2026-03-02
**Verdict:** Approved with fixes applied

**AC Validation:** All 9 acceptance criteria verified as implemented. All 13 cent offset values mathematically verified against `1200 × log₂(ratio)`. All Interval enum case names cross-referenced against `Peach/Core/Audio/Interval.swift`.

**Issues found:** 0 High, 3 Medium, 3 Low

**MEDIUM issues (fixed):**
1. **Appendix A M6 derivation error** — First derivation attempt `P5 × M3 ÷ P8` produces 15/16, not 5/3. Removed incorrect derivation, kept correct one (`P8 ÷ m3 = 2/(6/5)`).
2. **Scoring matrix inflated to 20/20** — Report documents 4 edge cases yet gave 5/5 on "implementation simplicity." Adjusted to 4/5 (19/20 total), acknowledging edge cases require careful documentation.
3. **"Used daily by millions of musicians" imprecise** — Musicians adjust toward just intervals by ear, not by consciously "using JI." Rephrased to "the target intonation for millions of ensemble musicians."

**LOW issues (noted, not fixed):**
4. AC #2 structure inconsistently applied across sections (JI section thorough, others implicit)
5. External URL references (10+ links) unverifiable from code review
6. Tritone edge case could explicitly address DirectedInterval interaction for Epic 30 implementers

### Change Log

- 2026-03-02: Research report created at `docs/implementation-artifacts/29-1-research-report-tuning-systems-used-by-musicians.md`
- 2026-03-02: All 6 tasks completed; story status updated to "review"
- 2026-03-02: Code review — 3 MEDIUM issues fixed in research report (M6 derivation error, scoring inflation, imprecise usage claim); story status updated to "done"

### File List

- `docs/implementation-artifacts/29-1-research-report-tuning-systems-used-by-musicians.md` (new) — Complete research report with recommendation, survey, compatibility analysis, and Epic 30 implementation specification
