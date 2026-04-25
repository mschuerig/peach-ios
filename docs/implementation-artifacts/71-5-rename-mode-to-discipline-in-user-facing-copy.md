# Story 71.5: Rename "mode" to "discipline" in user-facing copy and active docs

Status: ready-for-dev

## Story

As a Peach contributor (and a future App Store reviewer reading our docs),
I want every user-facing reference to a training **discipline** to use that word — never "mode" —
so that the vocabulary is consistent between the canonical types in code (`TrainingDiscipline`, `TrainingDisciplineConfig`, `TrainingDisciplineRegistry`), our marketing copy (App Store description, review notes), and our help text.

## Context

The 2026-03-21 terminology rename (`tech-spec-domain-terminology-rename.md`) moved the type system from `TrainingMode` to `TrainingDiscipline`. That rename was scoped to type names, file names, and the glossary. It deliberately left **user-facing strings and prose in active docs** alone, so colloquial "training mode" usage survived in:

- `Peach/App/HelpContent.swift` — four `String(localized:)` strings + one section title
- `Peach/Resources/Localizable.xcstrings` — the same five English keys, each with a German translation that uses "Trainingsmodi"/"Trainingsmodus"
- Two test method `@Test(...)` description strings (`StartScreenTests`, `ProgressChartViewTests`)
- Active planning docs: `docs/arc42.md`, `docs/project-context.md`, `docs/planning-artifacts/glossary.md`, `prd.md`, `architecture.md`, `ux-design-specification.md`

Stage 71.2 (App Store Review Notes) confirmed the user-facing terminology is "disciplines, six of them"; Story 71.1 (App Store Description) already shipped "six training disciplines". This cleanup brings the in-app help and architecture docs into alignment with that vocabulary.

This is a cleanup story analogous to `cleanup-rename-discrimination-to-pitch-comparison` (top-level entry in `sprint-status.yaml`).

## Scope Boundaries

- **In scope:** every user-facing English/German string and every active-doc prose reference using "training mode(s)" or "interval mode".
- **In scope:** the help-copy phrasing `"In interval mode, ..."` (`HelpContent.swift:23,42`) and the German `"Im Intervallmodus, ..."` (`Localizable.xcstrings:1362,1372`) → rewritten to `"For interval training, ..."` / `"Beim Intervalltraining, ..."` (or another factually equivalent phrasing without "mode" / "Modus"). User-facing copy must not use "mode".
- **Out of scope:** internal symbols like `isIntervalMode: Bool` parameters, internal variable names, and any non-user-facing API. Treat as implementation detail (per project lead). If a future cleanup wants those renamed, a separate story tracks it.
- **Out of scope:** historical implementation artifacts, retrospectives, code-review docs, walkthrough docs, completed tech specs, and arc42 sections that quote a historical type name (`TrainingMode` as a literal symbol in a rationale). Do not mass-edit those.

## Acceptance Criteria

### AC 1: All user-facing English strings updated

**Given** `Peach/App/HelpContent.swift`
**When** the cleanup is complete
**Then** every occurrence of "training mode(s)" or "interval mode" in a `String(localized:)` is replaced with a phrase that does not use the word "mode", and the section-title key `"Training Modes"` becomes `"Training Disciplines"`.

Specific lines to update:
- `:23` — `"In interval mode, the two notes are separated by..."` → `"For interval training, the two notes are separated by..."` (or equivalent phrasing without "mode")
- `:42` — `"In interval mode, your target pitch is a specific..."` → `"For interval training, your target pitch is a specific..."` (or equivalent phrasing without "mode")
- `:95` — `"Applies to all training modes."` → `"Applies to all disciplines."`
- `:99` — `"all rhythm training modes"` → `"all rhythm disciplines"`
- `:154` — the long `trainingModesDescription` block uses the word "mode" implicitly through its variable name only — the body text is already discipline-neutral, but rename the **identifier** `trainingModesDescription` → `trainingDisciplinesDescription`
- `:156` — `"Just pick any training mode on the home screen and start practicing."` → `"Just pick a discipline on the home screen and start practicing."`
- `:166` — `title: String(localized: "Training Modes")` → `title: String(localized: "Training Disciplines")`

### AC 2: All English `Localizable.xcstrings` keys updated

**Given** `Peach/Resources/Localizable.xcstrings`
**When** the cleanup is complete
**Then** the five English keys above are renamed (Xcode treats the English text as the key, so these are key renames, not translation edits).

Affected keys (line numbers approximate):
- `:66` — Tempo / rhythm-modes string (legacy variant)
- `:77` — Tempo / Gap Positions string (current variant)
- `:119` — Vary Loudness / Note Gap string (current variant — "Compare training")
- `:129` — Vary Loudness / Note Gap string (legacy variant — "Hear & Compare training")
- `:1361` (approx.) — `"In interval mode, the two notes..."` (Compare-Pitch help body)
- `:1371` (approx.) — `"In interval mode, your target pitch..."` (Match-Pitch help body)
- `:1470` — Getting-started string
- `:3394` — `"Training Modes"` section title

### AC 3: All German translations updated

**Given** the German translations attached to the keys above
**When** the cleanup is complete
**Then** the translations use **"Trainingsdisziplin(en)"** (or a more idiomatic equivalent — see Dev Notes) instead of **"Trainingsmodi"/"Trainingsmodus"**, and follow the project's existing `du`/imperative tone (memory: `feedback_german_informal.md`).

Strings currently containing "Trainingsmodi"/"Trainingsmodus" or "Intervallmodus":
- `:72` — `"Geschwindigkeit aller Rhythmus-Trainingsmodi"` → `"Geschwindigkeit aller Rhythmus-Disziplinen"` (or `"...aller rhythmischen Disziplinen"`)
- `:82` — same as above with Gap Positions appendix
- `:124` — `"Gilt für alle Trainingsmodi."` → `"Gilt für alle Disziplinen."`
- `:135` — same as `:124`, legacy variant
- `:1362` — `"Im Intervallmodus sind die beiden Töne..."` → `"Beim Intervalltraining sind die beiden Töne..."` (or equivalent phrasing without "Modus")
- `:1372` — `"Im Intervallmodus liegt deine Zieltonhöhe..."` → `"Beim Intervalltraining liegt deine Zieltonhöhe..."` (or equivalent phrasing without "Modus")
- `:1475` — `"Wähle einfach einen Trainingsmodus auf dem Startbildschirm..."` → `"Wähle einfach eine Disziplin auf dem Startbildschirm..."`
- `:3399` — `"Trainingsmodi"` → `"Trainingsdisziplinen"`

### AC 4: Test method descriptions updated

**Given** test descriptions that reference "training modes"
**When** the cleanup is complete
**Then** they read "training disciplines":

| File | Line | Current | New |
|---|---|---|---|
| `PeachTests/Start/StartScreenTests.swift` | 187 | `"Info Screen training modes description contains dash-separated mode names"` | `"Info Screen training disciplines description contains dash-separated discipline names"` |
| `PeachTests/Profile/ProgressChartViewTests.swift` | 549 | `"share accessibility label contains mode display name and is non-empty for all training modes"` | `"share accessibility label contains discipline display name and is non-empty for all training disciplines"` |

### AC 5: arc42 updated

**Given** `docs/arc42.md`
**When** the cleanup is complete
**Then** every prose occurrence of "training mode(s)" is rewritten to "discipline" or "training discipline", except where the word "mode" appears inside an architectural rationale explaining the *historical* `TrainingMode` enum or a code comment that quotes legacy code.

Prose occurrences (lines as of 2026-04-25):
- `:35` — "across all six disciplines" — already correct, no change.
- `:106` — "every completed exercise across all six disciplines" — already correct.
- `:223` — "progress chart across all six training disciplines" — already correct.
- `:598` — "extensibility pattern for training modes" → "extensibility pattern for disciplines"
- `:765` — "Four pitch training modes map to..." → "Four pitch disciplines map to..."
- `:897`, `:907`, `:908`, `:914` — `| Discipline-name | Training mode: ... |` table entries → drop "Training mode:" preamble; the entry titles already convey the concept, so reword each definition without the leading phrase.
- `:924` — "Six disciplines exist:" — already correct.
- `:926` — `**Training Mode**` glossary row → either delete (redundant with the existing **Training Discipline** glossary row in `docs/planning-artifacts/glossary.md`) or rename to `**Training Discipline**` with a cross-reference. Decision: delete from arc42, since the canonical entry lives in the planning glossary.

### AC 6: project-context updated

**Given** `docs/project-context.md`
**When** the cleanup is complete
**Then** the line `- **Four training modes** — unison comparison, ...` (line 257) is rewritten to reflect the **six** current disciplines (it still says "Four") **and** uses "disciplines" instead of "modes".

This line is double-stale: count is wrong (six, not four — the rhythm disciplines were added later) and vocabulary is wrong. Both must be fixed.

### AC 7: glossary updated

**Given** `docs/planning-artifacts/glossary.md`
**When** the cleanup is complete
**Then**:
- The existing **Training Discipline** entry (line 16) keeps its "Replaces 'Training Mode' —" preamble (this is intentional historical context).
- The existing **Training Discipline Config** entry (line 41) keeps its "Formerly 'Training Mode Config'." trailer (same reason).
- The discipline count in the **Training Discipline Config** entry is updated from "Four static instances" to "Six static instances" if the codebase confirms six (verify via `TrainingDisciplineConfig.swift` static members).

### AC 8: prd, architecture, ux-design-specification updated

**Given** `docs/planning-artifacts/prd.md`, `architecture.md`, `ux-design-specification.md`
**When** the cleanup is complete
**Then** all narrative prose uses "discipline" instead of "training mode", with these exceptions explicitly preserved as legitimate historical-rationale references:
- Section headings or change-log entries that quote the historical name (e.g. "Training Modes Extension" as a section heading documenting the v0.4 amendment).
- Quoted code identifiers like `TrainingDisciplineConfig` (no change — already correct).

The bulk-edit scope is: every line listed by `grep -n "training mode\|training-mode\|TrainingMode\b" docs/planning-artifacts/prd.md docs/planning-artifacts/architecture.md docs/planning-artifacts/ux-design-specification.md`. Line counts as of 2026-04-25:
- `prd.md`: 5 lines (123, 147, 337, 375, 541)
- `architecture.md`: ~17 lines (470, 486, 916, 1079, 1551, 1553, 1585, 1592, 1601, 1603, 2077, 2207, 2368, 2545, 2598, 2623, 2705)
- `ux-design-specification.md`: ~12 lines (1028, 1284, 1386, 1400, 1455, 1764, 1821, 1880, 1889, 2060, 2249, 2258)

For each line, prefer the minimally invasive rewrite ("training mode" → "discipline" or "training discipline"), avoiding restructured paragraphs.

### AC 9: Historical artifacts left untouched

**Given** `docs/implementation-artifacts/*.md` (completed story files), `docs/code-review-*.md`, `docs/walkthrough/*`, retrospectives, and any tech-specs already marked `done`
**When** the cleanup is complete
**Then** these files are NOT modified — they document what was true at the time of implementation. (Same convention as story 61.2 AC 6.)

### AC 10: No regressions

**Given** the full test suite on iOS and macOS
**When** run
**Then** all tests pass with zero regressions, and the build emits zero new warnings related to the renamed strings.

Note: renaming `Localizable.xcstrings` keys means the `String(localized:)` call sites change in lockstep — the compiler and Xcode's string-catalog tooling will catch mismatches. After the rename, run `bin/build.sh && bin/build.sh -p mac` and confirm no missing-localization warnings.

## Tasks / Subtasks

- [ ] Task 1: Update English copy in source (AC: 1)
  - [ ] 1.1 Edit the two "interval mode" help-body strings (`HelpContent.swift:23,42`)
  - [ ] 1.2 Edit the four "training mode(s)" `String(localized:)` strings and the `"Training Modes"` section title (`HelpContent.swift:95,99,156,166`)
  - [ ] 1.3 Rename the `trainingModesDescription` identifier to `trainingDisciplinesDescription` (and any references)
  - [ ] 1.4 Build iOS — confirm no compiler errors
- [ ] Task 2: Update string-catalog keys and German translations (AC: 2, 3)
  - [ ] 2.1 In `Localizable.xcstrings`, rename each affected English key
  - [ ] 2.2 Update each German translation to use "Disziplin(en)" / "Trainingsdisziplin(en)" with `du`/imperative tone
  - [ ] 2.3 Run `bin/add-localization.swift --list` and `--missing` to verify no orphaned keys or missing translations
- [ ] Task 3: Update test method descriptions (AC: 4)
  - [ ] 3.1 `StartScreenTests.swift:187`
  - [ ] 3.2 `ProgressChartViewTests.swift:549`
- [ ] Task 4: Update arc42 (AC: 5)
  - [ ] 4.1 Edit prose lines 598, 765 (rename "training modes" → "disciplines")
  - [ ] 4.2 Reword glossary table rows at 897, 907, 908, 914 to drop the "Training mode:" preamble
  - [ ] 4.3 Delete the `**Training Mode**` glossary row at line 926
- [ ] Task 5: Update project-context (AC: 6)
  - [ ] 5.1 Rewrite line 257 to "Six training disciplines" with the correct list
- [ ] Task 6: Update planning glossary (AC: 7)
  - [ ] 6.1 Verify static-instance count of `TrainingDisciplineConfig` and update glossary entry from "Four" to current number
- [ ] Task 7: Update prd, architecture, ux-design-specification (AC: 8)
  - [ ] 7.1 Apply minimally invasive edits to each listed line
  - [ ] 7.2 Re-grep after edits to confirm no remaining "training mode" prose (excluding deliberate historical references)
- [ ] Task 8: Build & test on both platforms (AC: 10)
  - [ ] 8.1 `bin/build.sh && bin/build.sh -p mac` — zero new warnings
  - [ ] 8.2 `bin/test.sh && bin/test.sh -p mac` — all tests green

## Dev Notes

### German wording

The most natural German equivalent of "training discipline" is **Disziplin** (used standalone) or **Trainingsdisziplin** (compound). Both are acceptable; prefer **Disziplin** in body text and **Trainingsdisziplinen** as a section title to mirror the English. Avoid awkward direct translations like *"Trainingssparte"*. Maintain `du`/imperative tone per `feedback_german_informal.md`.

### Tone

This is a vocabulary cleanup, not a content rewrite. Do not soften, expand, or restructure copy beyond what is needed to remove the word "mode". Per memory rule `feedback_sober_factual_copy.md`, the existing factual tone is already correct — just swap the term.

### Why "interval mode" copy is in scope but `isIntervalMode` is not

Project lead decision (2026-04-25): "interval mode" is acceptable as an **internal implementation detail** (e.g. the `isIntervalMode: Bool` parameter on `NavigationDestination.pitchDiscrimination(isIntervalMode:)` and downstream view inits) but must not appear in **user-facing** copy. This story therefore rewrites every user-facing English/German occurrence of "interval mode"/"Intervallmodus" and leaves the internal parameter alone. If the internal rename is wanted later, file a separate cleanup story.

### References

- Memory: `feedback_disciplines_not_modes.md` — the rule that motivates this cleanup
- Memory: `feedback_german_informal.md` — German tone
- Prior art: `tech-spec-domain-terminology-rename.md` (the type rename)
- Prior art: `cleanup-rename-discrimination-to-pitch-comparison` in `sprint-status.yaml`

## Dev Agent Record

### Completion Notes List

(to be filled in by the dev workflow)

### File List

(to be filled in by the dev workflow)

## Change Log

- 2026-04-25: Story drafted as a follow-up to story 71.2 (review notes), which surfaced the inconsistency.
- 2026-04-25: Scope locked after project-lead decision: user-facing "interval mode" copy is in scope (rewritten); internal `isIntervalMode: Bool` parameter is out of scope (treated as implementation detail).
- 2026-04-25: Filed under epic 71 as Story 71.5; status → ready-for-dev.
