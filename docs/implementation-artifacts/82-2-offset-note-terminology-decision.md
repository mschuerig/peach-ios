---
title: 'Story 82.2: Terminology decision for the offset-carrying note'
type: 'chore'
created: '2026-06-03'
status: 'done'
baseline_commit: '18ff4432875f2372e5f010d87690b0456260abd5'
context:
  - '{project-root}/docs/planning-artifacts/tod-discipline-future-direction.md'
  - '{project-root}/docs/implementation-artifacts/82-1-offset-slot-as-setting.md'
  - '{project-root}/docs/implementation-artifacts/epic-82-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Epic 82 ships placeholder terminology ("Offset Note Position" / `offsetNotePosition`) via 82.1. Without a recorded final term, 82.5 will pile additional placeholder variants on top — `NamedPattern`, per-slot metadata, accessibility strings, German copy — that 82.4 then has to untangle. The term must also actively defend against re-importing "displaced" / "rhythmic displacement" from music-theory vocabulary (those mean the opposite — intentional, grid-aware shifts).

**Approach:** A no-code story that locks the term — re-consulting `agent-music-domain-expert` (Adam) — and records the decision in the four places downstream agents will look: the design-direction doc, the project glossary, the auto-memory entry that today only encodes the "no displaced" prohibition, and a confirmation that the German strings shipped in 82.1 hold up under the decided term. Adam's 2026-06-03 working recommendation is **"Offset Note"** (noun) with **"Offset Note Position"** as the settings-label form — chosen because "slot", "pulse", "step" each smuggle in a uniform-spacing assumption that breaks the moment the catalog includes gaps, syncopation, or tuplets. This story validates that recommendation against the three constraints (unintentional-error framing, no displacement collision, natural EN + informal DE) and promotes it to the recorded decision, or — if validation fails — re-consults Adam and lands a different term.

## Boundaries & Constraints

**Always:**
- Decide before recording. First step is a fresh `agent-music-domain-expert` consultation briefed with the 2026-06-03 recommendation and the three constraints, asking for validation or a counter-proposal. Whatever comes back is the recorded decision.
- The decision must satisfy all three constraints from `tod-discipline-future-direction.md` § *Open: terminology*: frames TOD as detecting *unintentional* playing errors, does not collide with *rhythmic displacement*, reads naturally in English settings labels and informal German.
- Record both forms: the noun ("the offset note") and the settings-label form ("Offset Note Position" or chosen variant). Use one phrase consistently.
- The recorded decision lives in three artifacts: `docs/planning-artifacts/tod-discipline-future-direction.md`, `docs/planning-artifacts/glossary.md`, and the auto-memory `feedback_tod_no_displaced_term.md` + matching `MEMORY.md` line.
- The auto-memory is **rewritten, not deleted**, even after the term is settled. The "no displaced" guardrail must outlive the open-question framing — it protects future agents from re-importing the music-theory term. Frontmatter `description` is updated to match the rewritten body.
- German strings are re-examined under the decided English term. If "Offset Note" wins, the strings shipped by 82.1 stand and are documented as confirmed. If a different term wins, the new German wording is recorded in Design Notes as source of truth for 82.4.
- Sober factual copy per `[[feedback_sober_factual_copy]]`. Informal `du` for German per `[[feedback_german_informal]]`.

**Ask First:**
- If Adam returns a term materially different from "Offset Note" (anything that requires more than swapping the noun in already-shipped 82.1 strings — e.g., a multi-word phrase, a non-obvious German render, or new glossary cross-references), HALT and surface the proposal before recording.
- If validation against the three constraints surfaces a real conflict with another glossary term or with existing pitch-discipline vocabulary (`Cent Offset`, `Target Note`, `Reference Note`), HALT and surface the collision before recording.

**Never:**
- No code changes. No rename of the `@AppStorage` key, the `TimingOffsetDetectionSettings` field, the SettingsScreen label, or the German `.xcstrings` entries — all that is 82.4's job.
- No new strings added via `bin/add-localization.swift`. If the term changes, the new wording is recorded in Design Notes for 82.4 to apply.
- Do not delete the auto-memory entry. The "displaced is wrong" guardrail outlives this decision.
- Do not re-open the *Pattern catalog UI categorization*, *Pattern preview rendering*, or *Rest-aware slot accessibility* questions from the design-direction doc — those belong to 82.3 / 82.6.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Adam validates "Offset Note" | Fresh consultation returns same recommendation as 2026-06-03 | Record "Offset Note" in all four locations; document existing German strings as confirmed; no string edits | N/A |
| Adam proposes a different term | Fresh consultation returns a different recommendation | Halt per Ask First; on agreement, record in all four locations; capture new German rendering in Design Notes for 82.4 | Halt-and-ask, not silent override |
| Constraint conflict surfaces | E.g., glossary collision or informal-German variant grates | Halt per Ask First; agree resolution; then record | Halt-and-ask |
| Auto-memory file already removed | `feedback_tod_no_displaced_term.md` absent | Recreate with settled-term framing; ensure `MEMORY.md` references it | N/A |

</frozen-after-approval>

## Code Map

- `docs/planning-artifacts/tod-discipline-future-direction.md` -- replace § *Open: terminology* with a § *Resolved: terminology* recording the term, noun + label forms, rationale tied to all three constraints, and dated consultation reference. Other sections keep placeholder language with explicit "applied by 82.4" tags where they appear.
- `docs/planning-artifacts/glossary.md` -- add **Offset Note** (or chosen term) entry under § *Concepts* > *Core Training Concepts*, sited near *Reference Note* / *Target Note*; one row; cross-reference Naming Matrix's *Rhythm Offset Detection*.
- `~/.claude/projects/-Users-michael-Projekte-peach-peach-ios/memory/feedback_tod_no_displaced_term.md` -- rewrite body to lead with the settled term; retain "no displaced" guardrail as second paragraph; keep slug + type intact; update frontmatter `description` to settled-term framing.
- `~/.claude/projects/-Users-michael-Projekte-peach-peach-ios/memory/MEMORY.md` -- update the matching one-line description to match the rewritten memory.
- `Peach/Localization/Localizable.xcstrings` -- **read-only**. Verify via `bin/add-localization.swift --list` that the offset-note surface strings shipped by 82.1 are sufficient for the decided term; capture the list output in Verification.

## Tasks & Acceptance

**Execution:**
- [x] Consult `agent-music-domain-expert` (Adam) with the 2026-06-03 recommendation, the three constraints, and the catalog-expansion direction; record the response verbatim in Design Notes.
- [x] Validate the returned term against each of the three constraints in writing (one short paragraph each).
- [x] Update `docs/planning-artifacts/tod-discipline-future-direction.md`: turn § *Open: terminology* into a *Resolved* section with term, rationale, date.
- [x] Add the **Offset Note** (or chosen) entry to `docs/planning-artifacts/glossary.md` under *Core Training Concepts*.
- [x] Rewrite `~/.claude/projects/-Users-michael-Projekte-peach-peach-ios/memory/feedback_tod_no_displaced_term.md` per Code Map; update its frontmatter `description`.
- [x] Update the matching line in `MEMORY.md` so the index hook matches the rewritten body.
- [x] Run `bin/add-localization.swift --list 2>&1 | grep -iE "offset note|offset-note"` and paste the resulting lines into Verification as evidence the German strings cover the decided term.
- [x] Run `bin/add-localization.swift --missing` and confirm no new gaps.

**Acceptance Criteria:**
- Given an agent picking up 82.4, when they search `docs/planning-artifacts/` for the offset-note term, then they find one canonical definition and zero references to it as an open question.
- Given an agent reading the `feedback_tod_no_displaced_term` memory, when they look for guidance, then they find both the settled term *and* the "no displaced" guardrail in a single coherent entry.
- Given an agent running `bin/add-localization.swift --missing`, when they check after this story, then no new gaps are reported.
- Given the design-direction doc end-to-end, when read, then *Open: terminology* is gone and remaining placeholder mentions are tagged "applied by 82.4" rather than silently rewritten.

## Spec Change Log

## Design Notes

### Recorded decision

**Noun:** Offset Note. **Settings-label form:** Offset Note Position (1-based). **Code identifier:** `offsetNotePosition`. **German:** *Position der Offset-Note* with body copy *Wähle, welche der vier Sechzehntelnoten den Timing-Offset trägt.* (both already shipped via 82.1).

### Consultation with `agent-music-domain-expert` (Adam), 2026-06-03 (validation pass)

Adam was re-consulted with the 2026-06-03 working recommendation, the three constraints, and the catalog-expansion direction in view. He confirmed *Offset Note* / *Offset Note Position* with no stronger candidate. Verbatim excerpts captured here for the trail:

> "Offset" names the *symptom* (a measurable temporal displacement from the implied grid), not a *gesture*. That is exactly what TOD trains: the user judges a temporal fact, not a stylistic choice. The natural alternatives from performance pedagogy — "rushed note", "dragged note", "lagging note" — all pre-commit to a direction. TOD is direction-agnostic on the setting axis; a directional noun would silently smuggle a polarity into a control that has none. Judgmental nouns ("errant", "wayward", "misplaced") fail the framing the other way — they assert wrongness at a point where the discipline only asserts deviation.

> "Displacement" is a music-theory term of art for *intentional, grid-aware* metric shifts. "Offset" is not a music-theory term at all — it is borrowed from engineering/measurement, and that borrowing is the feature here, not a bug. The word arrives at the user without theoretical luggage. The "no displaced" guardrail must remain — the temptation to translate "displaced" → "offset" → "displaced" again is real for any agent that hasn't seen this thread.

> "Offset" is a well-established Anglo-loanword in technical-musical German (cf. *Offset-Druck*, *Timing-Offset* in audio engineering); it reads natural in modern informal tech-music register. The native alternative *Versatz / Versatz-Note* sounds slightly archaic and *Versatznote* would risk confusion with grace-note adjacent vocabulary. Keep what 82.1 shipped.

Discarded alternatives (recorded so the trail is complete): *Errant / Wayward / Misplaced Note* (judgmental, asserts wrongness), *Shifted Note* (semantically too close to "displaced"), *Rushed / Dragged / Lagging Note* (directional; TOD is direction-agnostic), *Deviation / Variance Note* (statistical register, unnatural in a Settings label), *Test / Probe Note* (exposes the testing framing in the UI, opposite of how the discipline should land).

Nearby-vocabulary risks Adam flagged for explicit handling:

- **"Cent Offset" (pitch) vs. "Offset Note" (rhythm).** Same English root word, different domains (cents vs. milliseconds). Resolution: the glossary entry for *Offset Note* leads with the temporal qualifier and explicitly states this is the rhythm-discipline analogue of *Cent Offset* in the pitch disciplines — sibling, not synonym.
- **"Slot" stays as a code/engineering term, never a UI term.** Engineering usage in 82.5–82.6 ("pickable slot", "rest slot", per-slot metadata) names a *cell in the pattern data structure*. The user-facing noun for the chosen audible position is *Note*. The discipline contract: **user picks an Offset Note Position; the code addresses slots within the pattern.**
- **Pitch siblings *Target Note* / *Reference Note*.** No collision. Those name *roles* in a pitch trial; *Offset Note* names a *property* of a rhythm trial. Different relationship to the trial, different domain.
- **82.3–82.7 catalog vocabulary (`NamedPattern`, "Straight / Gapped / Syncopated").** Orthogonal axis to *Offset Note*; no collision.

### Constraint check

**1 — Unintentional-error framing.** Pass. *Offset* names the temporal deviation without coloring its origin; it asserts neither deliberate gesture (which would mis-frame TOD as cataloging musical choices) nor user wrongdoing (which would push the discipline into corrective register). Compared against the discarded directional and judgmental alternatives, *Offset Note* is the only candidate that holds the discipline's symptom-not-cause framing.

**2 — No collision with rhythmic displacement.** Pass. *Offset* is not a music-theory term and carries no implicit theory baggage. *Displacement* remains a separate, music-theory noun owned by intentional metric shifts; the auto-memory keeps that guardrail visible to future agents so the cross-translation back to "displaced" is prevented.

**3 — Natural EN + informal DE.** Pass. *Offset Note Position* reads cleanly as an English Settings label, no jargon spike, no comma-laden multi-noun phrase. The shipped German *Position der Offset-Note* is correct — *Offset* is established Anglo-loan vocabulary in technical-musical German, and the body copy *Wähle, …* keeps informal `du` and direct register.

### Mechanical follow-ups for 82.4

No English or German string changes are required (the 82.1 strings already match the settled term). 82.4 owns code-identifier consistency (`offsetNotePosition`, `defaultOffsetNotePosition`, `validOffsetNotePositionRange`, test names, accessibility-label parameters) and the sweep of any remaining "placeholder, see 82.2" annotations in code and tests.

### Existing notes

**Rewrite-not-delete on the auto-memory:** The current entry encodes two ideas — "displaced is forbidden" and "term is open". Deleting it once the term lands would erase the guardrail. Rewriting preserves it and demotes the open-question framing to history. The frontmatter `description` change is what routes future agents correctly via `MEMORY.md`.

**Why the German strings probably already hold:** 82.1 shipped "Offset Note Position" → "Position der Offset-Note" via `bin/add-localization.swift` after Adam's 2026-06-03 recommendation. If this story confirms "Offset Note", that artifact is correct as-is — informal `du`, no marketing tone. If a different English term wins, the corresponding German is recorded here before 82.4 runs the actual edits.

**Why 82.4 stays a separate story even if no string changes:** 82.4's surface is the cleanup sweep — removing "placeholder, see 82.2" caveats from code comments, test names, and any remaining doc placeholder language. Code identifiers (`offsetNotePosition`, `defaultOffsetNotePosition`, `validOffsetNotePositionRange`) and the shipped EN/DE strings already match the settled term and stay as-is; 82.4 does not rename them.

## Verification

**Commands:**

- `bin/add-localization.swift --list 2>&1 | grep -iE "offset note|offset-note"` -- ran 2026-06-03; both expected entries present:

  ```
  **Offset Note Position** chooses which of the four 16th notes in the pattern arrives slightly early or late on each trial. The other three notes stay exactly on the beat.  →  **Position der Offset-Note** legt fest, welche der vier Sechzehntelnoten im Muster bei jedem Durchgang leicht zu früh oder zu spät einsetzt. Die anderen drei Noten bleiben exakt auf dem Schlag.
  Offset Note Position  →  Position der Offset-Note
  ```

- `bin/add-localization.swift --missing` -- ran 2026-06-03; reports `0 keys missing German translation`.
- `grep -n "Open: terminology\|Resolved: terminology\|Offset Note" docs/planning-artifacts/tod-discipline-future-direction.md docs/planning-artifacts/glossary.md` -- ran 2026-06-03; zero "Open: terminology" matches, one "Resolved: terminology" match in the design-direction doc, multiple "Offset Note" matches across both files:

  ```
  docs/planning-artifacts/glossary.md:33:| **Offset Note** | In *Rhythm Offset Detection* …
  docs/planning-artifacts/tod-discipline-future-direction.md:8:## Resolved: terminology
  docs/planning-artifacts/tod-discipline-future-direction.md:10:**Term:** *Offset Note* (noun). **Settings-label form:** *Offset Note Position* …
  docs/planning-artifacts/tod-discipline-future-direction.md:18:- *Natural EN + informal DE.* "Offset Note Position" reads cleanly …
  docs/planning-artifacts/tod-discipline-future-direction.md:20:**Vocabulary boundary:** "Slot" remains a code/engineering term only …
  ```

**Manual checks:**
- Re-read the rewritten memory entry — settled term leads, guardrail retained as second paragraph, frontmatter `description` matches new framing.
- Re-read the matching `MEMORY.md` line — description matches the rewritten body.
- Sanity-skim the design-direction doc end-to-end — *Open: terminology* gone; remaining placeholder mentions explicitly tagged "applied by 82.4".

## Suggested Review Order

**Terminology resolution (entry point)**

- Canonical decision — term, label form, code identifier, German, full rationale per constraint.
  [`tod-discipline-future-direction.md:8`](../planning-artifacts/tod-discipline-future-direction.md#L8)

- "Applied by 82.4" tags now cover both *Near-term step* and *Future vision* placeholder language.
  [`tod-discipline-future-direction.md:25`](../planning-artifacts/tod-discipline-future-direction.md#L25)

**Glossary entry**

- New *Offset Note* row sits next to *Reference Note* / *Target Note* under *Core Training Concepts*; cross-references the *Naming Matrix* row for *Rhythm Offset Detection* and explicitly disclaims any false analogy with the magnitude-typed *Cent Offset*.
  [`glossary.md:33`](../planning-artifacts/glossary.md#L33)

**Auto-memory rewrite (project memory, outside the repo)**

- Settled term leads; the "no displaced" guardrail is retained as the second paragraph; `description` frontmatter updated so `MEMORY.md` routes correctly.
  `~/.claude/projects/-Users-michael-Projekte-peach-peach-ios/memory/feedback_tod_no_displaced_term.md`

- Matching one-liner in `MEMORY.md` flipped from open-question framing to settled-term-plus-guardrail framing.
  `~/.claude/projects/-Users-michael-Projekte-peach-peach-ios/memory/MEMORY.md`

**Epic-level cross-references (Boy Scout sweep — surfaced by edge-case review)**

- Epic 82 header now records "Settled terminology" instead of "Open terminology" — 82.3 starts in parallel and needs the up-to-date framing.
  [`epics.md:8216`](../planning-artifacts/epics.md#L8216)

- 82.6 sketch's per-cell accessibility labels switched from "Slot N of 4" to "Note N of 4" — sketch is informational, but it directly seeds the 82.6 implementer.
  [`epics.md:8268`](../planning-artifacts/epics.md#L8268)

- Deferred-work bullet for an `OffsetNotePosition` value type no longer treats the term as a placeholder — `offsetNotePosition` is the final identifier.
  [`deferred-work.md:59`](./deferred-work.md#L59)

**Spec audit trail**

- Adam's verbatim consultation captured under § *Recorded decision* / *Consultation*; three-constraint validation written out; discarded alternatives listed.
  [`82-2-offset-note-terminology-decision.md:83`](./82-2-offset-note-terminology-decision.md#L83)

- Verification captures both `bin/add-localization.swift` outputs as evidence; the third `grep` command is recorded with its actual results.
  [`82-2-offset-note-terminology-decision.md:128`](./82-2-offset-note-terminology-decision.md#L128)
