# Story 77.11: Update architecture documentation for plugin-style disciplines

Status: review

## Story

As **a future contributor (human or agent) reading the architecture docs to understand how training disciplines plug into Peach**,
I want `docs/planning-artifacts/architecture.md` and `docs/arc42.md` to reflect the post-77.x plugin model — discipline-owned UI, JSON-envelope persistence with discipline-owned Codable payloads, history+derivation CSV migration, feature-local storage, the SwiftUI-aware `TrainingDisciplineUI` refinement, the per-discipline compile-time activation switch, and the `Peach/Training/<Feature>/` colocation rule — written for the audience each document serves,
so that nobody bases new work on the obsolete v0.5 picture (central enums, `TrainingDiscipline` enum exhaustiveness, category-gated screens, central `enabledGapPositions`, per-discipline `@Model` types, central CSV migration enumeration) and the "add a new discipline" instructions are accurate end-to-end.

## Background

Epic 77 substantially changes how disciplines extend the app, but the documents still describe the v0.5 / pre-77 world:

- `docs/planning-artifacts/architecture.md` ends at v0.8 (Schema Versioning, 2026-04-something). Its v0.5 amendment (lines 2695–2982) is the most recent description of the discipline registry; it describes ports/adapters and the `TrainingDiscipline` protocol but knows nothing about UI contributions, the `TrainingDisciplineUI` refinement, the central kinds enums introduced and then deleted by 77.1/77.2, the per-discipline compile-time activation switch, the JSON-envelope persistence model introduced by 77.4 (and the dissolution of per-discipline `@Model` types it replaces), the history+derivation CSV migration plugin contract introduced by 77.5, or `enabledGapPositions` leaving `Core/Ports/UserSettings` (77.6).
- `docs/arc42.md` (header: "Status: Current with codebase as of v0.5") explicitly tracks v0.5. Section 8.7 ("Training Discipline Registry") and the "Adding a new discipline requires…" enumeration still describe the v0.5 surface — no UI contributions, no compile-time per-discipline switch, no feature-directory colocation rule for view types and feature-local storage.

The two documents have **different audiences and different reading contracts**:

- **`architecture.md` is for agents.** It is structured as an append-only sequence of versioned amendments (v0.1 → v0.8). It is the most detailed reference — it carries directory-tree snapshots, file-by-file lists, exact protocol surfaces, exception declarations (e.g., "SwiftData in the TrainingDiscipline Chain"), supersedes-and-implementation-stories pointers, and verbose rationale. An agent that has lost session context should be able to reconstruct the current architectural rules from this file alone. Updates extend the series with a new amendment that names what it supersedes and why.
- **`arc42.md` is for humans.** It is a versioned single-narrative document (currently version 3.0). It conveys *what the architecture is now* and *why*, at a level that fits in a developer's head — quality goals, building-block diagrams, runtime scenarios, ADRs. It does not list every file or every protocol method. Updates rewrite the affected narrative sections in place and bump the version.

This story applies the appropriate update style to each document. It does **not** rewrite either document from scratch and does **not** consolidate across them.

This story runs **after** 77.2 / 77.3 / 77.4 / 77.5 / 77.6 / 77.7 / 77.8 / 77.9 reach `done` so the documentation describes the actual landed state, not a moving target. Wait for all of them before starting.

## Acceptance Criteria

### AC 1: `architecture.md` carries a v0.9 (or current-next) amendment for epic 77

**Given** the existing append-only structure of `architecture.md` (v0.5 last described the discipline registry; v0.6 / v0.7 / v0.8 added latency, MIDI, and schema versioning amendments)
**When** epic 77's documentation update lands
**Then** a new versioned amendment section is appended after `## v0.8 Architecture Amendment — Schema Versioning`, named `## v0.9 Architecture Amendment — Plugin-Style Discipline Contributions` (or whatever next-integer version fits if v0.9 has been used by another in-flight change). The amendment follows the existing template:

- A leading paragraph stating motivation and the implementation-stories pointer (`Epic 77 (77.1, 77.2, 77.3, 77.4, 77.5, 77.6) in docs/implementation-artifacts/`).
- An explicit `**Supersedes:**` block naming each part of the v0.5 amendment that no longer holds. At minimum, it must supersede the v0.5 "Discipline Registry" section's claim that the protocol surface is closed (it now splits across `TrainingDiscipline` in Core and `TrainingDisciplineUI` in App), the "Expected Result / Adding a discipline requires…" enumeration (it is shorter now and lives in the feature directory), any v0.5 statement that places UI fragments in central screens, the v0.5 statement that each discipline persists via its own SwiftData `@Model` (replaced by the envelope model in 77.4), and the v0.5 statement that CSV migrations are enumerated centrally (replaced by per-discipline history+derivation in 77.5). If 77.2 deletes `Peach/Settings/SettingsContributions.swift`, `Peach/Profile/ProfileContributions.swift`, and `Peach/Core/Training/Discipline/UIContributions.swift`, the amendment must say so by name. Likewise if 77.4 removes `extension SchemaV1 { @Model … }` from each feature directory and 77.5 deletes `V1ToV2Migration.swift` / `V2ToV3Migration.swift` (the v0.5 directory snapshots are file-by-file; the v0.9 supersession must be too).
- Subsections covering, at minimum:
  1. **Two-protocol split along the Core/App seam.** Why the split exists (Core's no-SwiftUI rule for data services), the exact members on `TrainingDisciplineUI` (`profileCard: AnyView`, `settingsSections: AnyView`, `settingsHelp: [HelpSection]`, `profileHelp: [HelpSection]`), the defaults each provides, and where the protocol file lives (`Peach/App/Training/TrainingDisciplineUI.swift` or wherever 77.2 places it).
  2. **Feature-directory colocation rule.** Every feature-specific view, struct, payload type, encoding helper, help body, and feature-local UserDefaults key lives under `Peach/Training/<Feature>/`. State this as an architectural rule, list the file moves 77.2 / 77.3 / 77.4 / 77.6 perform, and name the audit guardrail (`CategoryLiteralAuditTests` and any extensions added in 77.2 / 77.3 / 77.4 / 77.5 / 77.6).
  3. **Per-discipline compile-time activation.** Document the single source-of-truth file (`Peach/App/Training/DisciplineBootstrap.swift`), the chosen activation shape (Shape A: `(active: Bool, factory: () -> any TrainingDiscipline)` candidates list with `compactMap`), the `PEACH_RESEARCH` envelope behavior (`#if PEACH_RESEARCH` physically excludes timing-discipline factories from the App Store binary), and the explicit non-goals (no runtime UI, no `UserDefaults` flag, no debug menu — see story 77.1's "What this story is NOT").
  4. **JSON-envelope persistence (77.4).** Document the single `@Model TrainingRecord` envelope (`disciplineIdentifier: String`, `timestamp: Date`, `payloadVersion: Int`, `payloadData: Data`); the `TrainingDisciplinePayload: Codable, Sendable` protocol with `disciplineIdentifier` and `currentPayloadVersion`; that `SchemaV1.models` is `[TrainingRecord.self]` and never grows; that `extension SchemaV1 { @Model … }` declarations and top-level record-type typealiases are gone; that adapters mediate envelope ↔ payload encode/decode; the explicit no-deployed-user / no-migration decision and its gating on `72-1`. Show the envelope shape and one representative payload struct (e.g., `PitchDiscriminationPayload`) as short code blocks. Cite story 77.4.
  5. **History+derivation CSV migration (77.5).** Document the `csvHistory` member on `TrainingDiscipline`: each entry is a snapshot at a CSV format version (identifier + columns + optional value transforms from previous version); the runner derives column-rename / trainingType-rename / value-transform operations by diffing adjacent entries; the central `V1ToV2Migration.swift` / `V2ToV3Migration.swift` files are deleted; the runner's contract for absent-at-version (no operation) and retired-at-version (rows dropped) cases. Cite story 77.5.
  6. **Feature-local storage for `enabledGapPositions` (77.6).** Document that `enabledGapPositions` is no longer in `Core/Ports/UserSettings.swift`, `Settings/SettingsKeys.swift`, or `Settings/AppUserSettings.swift`; the UserDefaults key string and `GapPositionEncoding` are now under `Peach/Training/ContinuousRhythmMatching/`; the byte-identical key string and encoding preserve backwards-compatibility with pre-77.6 user data; the chosen wiring mechanism for `ContinuousRhythmMatchingSettings.from(_:)` (UserDefaults parameter, feature-local port, or whatever 77.6 picks).
  7. **Updated "Adding a new discipline requires" sequence.** Replace the v0.5 enumeration (which lived under "Expected Result") with the post-77 sequence: create `Peach/Training/<Feature>/` with the discipline conformance to `TrainingDisciplineUI`, the Codable payload struct conforming to `TrainingDisciplinePayload`, the session, the screen, observer protocol, store adapter, any feature-local UserDefaults storage, scoped help, settings sections, profile card view, and a `csvHistory` declaration; add one factory line to `DisciplineBootstrap.candidates`; add a `NavigationDestination` case; add localization strings. Compare to v0.5: the four-step list becomes "new directory + one bootstrap line + nav case + strings" — explicitly call out what is no longer needed (no central enum case, no central screen edit, no central help-content edit, no central UserSettings edit, no SwiftData schema edit, no central CSV migration edit).
  8. **Updated project structure snapshot for `Peach/Training/<Feature>/`.** Show one representative feature directory (e.g., `ContinuousRhythmMatching/`) listing the post-77 file inventory: discipline conformance, payload struct, session, screen, observer protocol, store adapter, settings sections, profile card view, help bodies, feature-local UserDefaults keys (for CRM only), encoding helper. Mirror the level of detail used in the v0.5 directory snapshots — agents reading this section need to know what files exist and where.
  9. **Updated central-files inventory for `Peach/Core/Data/`, `Peach/Settings/`, `Peach/Profile/`, `Peach/App/HelpContent.swift`, and `Peach/Core/Ports/UserSettings.swift`.** Show what these files contain *after* 77.x: only common / cross-cutting code, the single `TrainingRecord` envelope and the migration runner in `Peach/Core/Data/`, no feature-specific fragments, no category-literal gates, no enumeration of discipline-only settings, no per-discipline `@Model` types or `V*Migration.swift` files.

The amendment is **append-only**: do not edit the v0.5 / v0.6 / v0.7 / v0.8 sections in place. Pre-existing sections retain their historical text. The new amendment section is the authoritative current statement and supersedes the listed pieces.

### AC 2: `architecture.md` v0.9 amendment is agent-shaped

**Given** the audience is agents reconstructing architectural rules from text
**When** the v0.9 amendment is read in isolation
**Then** it satisfies the existing v0.5–v0.8 quality bar:

- Every claim that names a file, type, protocol member, or compilation flag uses the literal name in code (e.g., `TrainingDisciplineUI`, `profileCard: AnyView`, `PEACH_RESEARCH`, `Peach/App/Training/DisciplineBootstrap.swift`). No paraphrased substitutes ("the UI protocol", "the bootstrap file") for the first reference in each subsection.
- Where 77.x supersedes a v0.5 claim, the amendment quotes the superseded claim in enough detail that an agent reading only v0.9 can identify which v0.5 paragraph no longer holds (the v0.5 amendment uses this style — see the `**Supersedes:**` block at line 2701).
- Code examples, when used, are short and concrete. The `DisciplineBootstrap` activation shape may be shown as the actual compile-time-gated candidates list; `TrainingDisciplineUI` may be shown as a 6-line protocol snippet with the four members and their defaults.
- Cross-references to story files are explicit: each subsection ends with `[Source: docs/implementation-artifacts/77-N-...md]` linking to the implementing story (this is the `architecture.md` convention; see how v0.5 cites Epic 55 stories at line 2708).

### AC 3: `arc42.md` Section 8.7 rewritten in place

**Given** the existing `arc42.md` Section 8.7 ("Training Discipline Registry") was written for v0.5 and reads as a closed, single-protocol picture
**When** epic 77's documentation update lands
**Then** Section 8.7 is rewritten to describe the post-77 plugin model in arc42's narrative style:

- Introduce the two-protocol split (`TrainingDiscipline` in Core for data/persistence; `TrainingDisciplineUI` in App for view-producing methods) at a level that conveys the intent without enumerating every method. One sentence on the Core/App seam justification (no-SwiftUI rule for `TrainingDataExporter` / `CSVImportParser` / `TrainingDataStore`).
- Replace the v0.5 "Adding a new discipline requires" five-step list (currently at lines 613–620) with the post-77 sequence in the same prose style. The new list is *shorter and flatter*: a feature directory, a registration line, a navigation case, localization. Conveying that adding a discipline is a one-directory operation is the load-bearing point — readers should walk away with that picture, not the file inventory.
- Add a short paragraph (3–5 sentences) on **per-discipline compile-time activation** and the `PEACH_RESEARCH` envelope, with the rationale at the level of "why compile-time, not runtime". One-sentence pointer to ADR-10 (added in AC 4) for full reasoning.
- Note the **feature-directory colocation rule** in the section's closing paragraph: every file belonging to one discipline lives in `Peach/Training/<Feature>/`. The rule is the architectural commitment; the audit test is implementation detail and stays out of arc42.

The rewrite preserves the section's existing flavor: prose-first, mermaid-diagram-only-when-it-clarifies, no file-by-file inventories, no protocol-member listings beyond what fits in one sentence per role. The architecture.md v0.9 amendment carries the detail; arc42 carries the picture.

### AC 4: `arc42.md` gains an ADR-10 entry for per-discipline activation

**Given** `arc42.md` Section 9 is the human-readable register of architecture decisions and the per-discipline compile-time activation is a deliberate decision with rejected alternatives
**When** the activation mechanism is documented
**Then** Section 9 gains a new entry `### ADR-10: Per-Discipline Compile-Time Activation` placed after ADR-9 in the existing template:

- **Context:** the v0.5 / 76.4 state allowed only category-grained activation via `PEACH_RESEARCH`; per-discipline experimentation required hunting through gates in screens; central category gates became misleading once one rhythm discipline could be excluded while the other registered.
- **Decision:** per-discipline activation lives in a single file (`Peach/App/Training/DisciplineBootstrap.swift`) as a list of `() -> any TrainingDiscipline` factories; the four pitch disciplines are unconditionally listed; the two timing disciplines are gated by `#if PEACH_RESEARCH` so they are physically absent from App Store binaries; any developer disables a discipline locally by commenting out its factory line.
- **Status:** Implemented (epic 77.1, refined by 77.2 / 77.3 / 77.4 / 77.5 / 77.6).
- **Consequences:** standard arc42 (+) / (–) bullets — additive (one-line edit), honest binary (App Store has no dormant timing code), preserves the published `Debug` / `Debug (Research)` / `Release` / `Release (Research)` matrix; against: requires rebuild to toggle (no live experimentation), one-off discipline disabling is per-developer state that should not be committed.

ADR-10 references story 77.1 in its body (see ADR-7 / ADR-8 / ADR-9 for the citation style — story numbers, not file paths).

### AC 5: `arc42.md` cross-cutting updates

**Given** the rewrite of Section 8.7 + ADR-10 establishes the post-77 picture
**When** other cross-cutting `arc42.md` sections are checked
**Then** the following sections are touched only where they make claims that no longer hold:

- **Header (lines 1–6):** version bumped (e.g., `**Version:** 3.1`), date bumped to today, `Status:` line updated to reflect epic-77 amendments. Keep the format identical to today's header.
- **Section 4 Solution Strategy (line 153 specifically):** the `Simplicity` row mentions "discipline registry for additive extensibility" — extend or rephrase to reflect plugin-style colocation, but do **not** restructure the table. One-row tweak only if the existing wording is now misleading; otherwise leave as-is.
- **Section 12 Glossary:** add or update entries for `TrainingDisciplineUI`, `DisciplineBootstrap`, and adjust the `TrainingDisciplineRegistry` definition (line 931) to reflect the protocol split. Add a `**PEACH_RESEARCH**` entry if not already present (it is referenced throughout but not defined). Glossary entries are one-line definitions in the existing tabular style.
- **Section 11 Technical Debt:** remove or update the `Original architecture document partially outdated` row (line 890) if 77.11 lands the v0.9 amendment that would resolve the partial-outdate-ness. If `architecture.md` is now fully current with the post-77 codebase, the row can shrink to "predates implementation; arc42 + v0.6+ amendments are the current source of truth" or be removed entirely — dev's call based on the actual landed state of `architecture.md`.

Do not touch any section that does not make a claim invalidated by epic 77. Section 5.1 / 5.2 / 5.3 (building blocks) describe sessions and audio and are not affected. Section 6 (runtime view) is not affected. Sections 7–8.6 are not affected.

### AC 6: `epics.md` Story 77.11 entry added

**Given** `docs/planning-artifacts/epics.md` enumerates epic 77's stories (77.1 → 77.10 after the 2026-04-28 renumberings)
**When** 77.11 is added to the canonical story list
**Then** a new section `### Story 77.11: Update architecture documentation for plugin-style disciplines` is appended after the 77.10 section, in the same style: user story (`As a … I want … so that …`), `**Acceptance Criteria:**` numbered list summarizing the AC 1–AC 5 checks above (one-sentence-per-AC summary, not the full text). The work-order paragraph already includes 77.11 as the last story (documents the landed state and runs after the others).

### AC 7: Internal and external consistency

**Given** the documentation updates land together
**When** the four touched documents are read in sequence
**Then** they agree:

- File paths, type names, and protocol members named in `architecture.md` v0.9 match the actual landed state of the codebase after 77.6 (no aspirational references to a `TrainingDisciplineUI` member that 77.2 did not implement, no references to a `Peach/Settings/SettingsContributions.swift` that 77.2 deleted, no references to per-discipline `@Model` types that 77.4 dissolved, no references to `V*Migration.swift` files that 77.5 deleted).
- Names used in `arc42.md` match `architecture.md` (`TrainingDisciplineUI`, `DisciplineBootstrap`, `PEACH_RESEARCH`).
- Story 77.11's own status moves from `ready-for-dev` → `review` → `done` in the usual workflow; `epics.md` stays canonical (the AC-1–AC-5 summaries in the epics 77.11 entry do not duplicate the full text from this file).

A grep for legacy claims should return zero hits **in the touched sections only**:

- In `architecture.md` v0.9 amendment (only): no statement of the v0.5 form "Adding a discipline requires … Add a `TrainingDiscipline` enum case" (that enum is gone since v0.5).
- In `arc42.md` Section 8.7 + ADR-10: no `if activeCategories.contains(.rhythm)` example, no `switch discipline.category` example, no claim that disciplines need a central enum case.

Pre-77 amendments (v0.5–v0.8) keep their historical text — do not rewrite history; the v0.9 amendment is what readers see as current.

### AC 8: Build/test sanity

**Given** the changes are documentation-only
**When** the test suite runs
**Then** `bin/test.sh && bin/test.sh -p mac` is green (the docs do not affect compilation, but a full run guards against an unrelated drift). No new warnings from `bin/build.sh && bin/build.sh -p mac`. No code changes are expected; if any code change would be needed, the story is mis-scoped — flag it instead of expanding.

## Tasks / Subtasks

- [x] Task 1: Verify the landed post-77 state before writing anything (AC: 1, 7)
  - [x] 1.1 Confirm 77.2, 77.3, 77.4, 77.5, 77.6 are all `done` in `sprint-status.yaml`. If any are still `ready-for-dev` / `in-progress` / `review`, halt — this story documents the landed state and must run after the implementation stories land.
  - [x] 1.2 Read each of 77.2 / 77.3 / 77.4 / 77.5 / 77.6's `## Dev Agent Record` → `Completion Notes` and `File List` to extract the actual landed file paths, the chosen `TrainingDisciplineUI` member set, the chosen registry-access mechanism (App-layer extension vs. parallel typed list vs. registry-in-App), the chosen `TrainingDisciplinePayload` adapter shape, the chosen `csvHistory` shape and runner contract, and the chosen `enabledGapPositions` wiring (UserDefaults parameter vs. feature-local port).
  - [x] 1.3 Read 77.1's `Completion Notes` for the activation shape rationale (Shape A) and the `#if PEACH_RESEARCH` decision; this is the authoritative source for the ADR-10 rationale.
  - [x] 1.4 Read the `TrainingDiscipline` and `TrainingDisciplineUI` source files directly — protocol member names and defaults must match actual code, not story prose. If the source disagrees with the story, the source wins; flag the discrepancy in Completion Notes.

- [x] Task 2: Write the `architecture.md` v0.9 amendment (AC: 1, 2)
  - [x] 2.1 Append after the v0.8 amendment (line 3097). Do not edit any earlier section in place.
  - [x] 2.2 Lead with motivation, implementation-stories pointer (`Epic 77 (77.1, 77.2, 77.3, 77.4, 77.5, 77.6)`), and the explicit `**Supersedes:**` block.
  - [x] 2.3 Write subsections for the nine topics in AC 1: protocol split, colocation rule, activation, JSON-envelope persistence, history+derivation CSV migration, feature-local storage, "Adding a new discipline" sequence, project structure snapshot, central-files inventory.
  - [x] 2.4 Use literal type names, file paths, and code snippets per AC 2.
  - [x] 2.5 Add `[Source: docs/implementation-artifacts/77-N-...md]` references at subsection ends.

- [x] Task 3: Rewrite `arc42.md` Section 8.7 in place (AC: 3)
  - [x] 3.1 Replace the existing Section 8.7 body (lines 596–620) with the post-77 picture: two-protocol split, plugin-as-feature-directory framing, shorter "Adding a new discipline" list, per-discipline activation paragraph, colocation closing paragraph.
  - [x] 3.2 Keep the section title (`### 8.7 Training Discipline Registry`), prose-first style, and any existing diagram approach. Do not introduce new file inventories.
  - [x] 3.3 Pointer to ADR-10 for activation rationale.

- [x] Task 4: Add ADR-10 to `arc42.md` Section 9 (AC: 4)
  - [x] 4.1 Insert `### ADR-10: Per-Discipline Compile-Time Activation` after ADR-9 (current insertion point is line 822, after ADR-9's closing bullet).
  - [x] 4.2 Use the existing ADR template: Context, Decision, Status, Consequences (with (+) / (–) bullets).
  - [x] 4.3 Cite story 77.1 in the body (story-number citation style, not file path).

- [x] Task 5: Cross-cutting `arc42.md` touch-ups (AC: 5)
  - [x] 5.1 Bump header version (3.0 → 3.1) and date; update `Status:` line.
  - [x] 5.2 Section 4 / Solution Strategy table: re-read line 153 ("discipline registry for additive extensibility") and rephrase only if now misleading.
  - [x] 5.3 Section 12 Glossary: add `TrainingDisciplineUI`, `DisciplineBootstrap`, `PEACH_RESEARCH`; update `TrainingDisciplineRegistry` definition (line 931) to reflect the protocol split.
  - [x] 5.4 Section 11 Technical Debt: re-evaluate the `Original architecture document partially outdated` row (line 890) and update or remove based on the v0.9 amendment's coverage.

- [x] Task 6: Append Story 77.11 to `epics.md` (AC: 6)
  - [x] 6.1 Append `### Story 77.11: …` after the 77.10 section.
  - [x] 6.2 Confirm the work-order paragraph already includes 77.11 (added during the 2026-04-28 renumbering); if not, add it.
  - [x] 6.3 Use one-sentence-per-AC summaries; do not duplicate this story file's full text.

- [x] Task 7: Verify and ship (AC: 7, 8)
  - [x] 7.1 Read the four touched sections back-to-back as a sequence: `architecture.md` v0.9 → `arc42.md` Section 8.7 → ADR-10 → `epics.md` Story 77.11. Check for name disagreements (member names, file paths, flag names).
  - [x] 7.2 Grep the touched sections for the legacy phrases listed in AC 7. Expected: zero hits.
  - [x] 7.3 `bin/test.sh && bin/test.sh -p mac` green; `bin/build.sh && bin/build.sh -p mac` no new warnings.
  - [x] 7.4 Update story file Status to `review`; update `sprint-status.yaml` `77-11-…: review` with last_updated bumped.

## Dev Notes

### Why two documents with different update styles

The user has explicitly distinguished the audiences:

> architecture.md and arc42.md have different audiences: architecture.md is mostly aimed at agents and as such is very detailed. arc42.md is for human developers and is intended to convey an overview.

This mirrors the existing structure:

- `architecture.md` is append-only versioned amendments (v0.1 → v0.8). Each amendment is self-contained, names what it supersedes, points to implementation stories, and carries directory-tree snapshots and protocol surfaces. An agent that has lost session context can reconstruct architectural rules from this file alone. The v0.9 amendment continues that pattern.
- `arc42.md` is a single in-place narrative versioned at the document level (currently 3.0). Sections are rewritten when reality changes. ADRs are an append-only register inside Section 9. The post-77 update rewrites Section 8.7, adds ADR-10, and bumps the document version.

This story does not consolidate the two documents and does not introduce a single "current" view across them. The two-document split is the established editorial structure. See the `**Architecture Documentation**` feedback memory, if present, for any additional editorial conventions; otherwise honor the existing style of each document.

### What this story is NOT

- **Not a code change.** Pure documentation. If implementation drift is discovered while writing, raise it as a finding in Completion Notes, not as in-scope rework. (Boy Scout Rule still applies: file separate stories for code drift; do not silently fix.)
- **Not a rewrite of the v0.5–v0.8 amendments.** Those stand as historical record. Append v0.9; supersede explicitly.
- **Not a wholesale `arc42.md` overhaul.** Only Section 8.7, ADR-10, glossary entries, header, and the two narrow touch-ups in §4 and §11. Sections 1–7, 8.1–8.6, 8.8, and 10 are not affected by epic 77.
- **Not a glossary cleanup.** Add three entries (`TrainingDisciplineUI`, `DisciplineBootstrap`, `PEACH_RESEARCH`) and adjust one (`TrainingDisciplineRegistry`); leave the rest alone.
- **Not a "consolidate everything that should be in arc42 but is in architecture.md" exercise.** The two documents serve different audiences; their content overlap is intentional.

### How to keep the v0.9 amendment in `architecture.md`'s house style

Before writing, read the v0.5 amendment (`docs/planning-artifacts/architecture.md` lines 2695–2982) end-to-end. It is the closest stylistic template:

- Has a leading paragraph + `**Supersedes:**` block + `**Implementation stories:**` line.
- Has subsections that are noun-phrase-titled and start with one-or-two-line context, then exact protocol surfaces / file lists / code snippets.
- Closes with `### Updated Project Structure (v0.5 — …)` and `### Updated Service Boundaries (v0.5)` and `### v0.5 Architecture Validation`.

Mirror that shape for v0.9. The validation subsection at the end (decision compatibility, pattern consistency, backward compatibility, risk) is short and worth keeping — readers use it as a sanity gate.

### How to keep the arc42 rewrite in arc42's voice

Before rewriting Section 8.7, read the existing Section 8.6 / 8.7 / 8.8 / ADR-9 end-to-end. The voice is:

- Prose-first; one mermaid diagram per section at most, only when it clarifies a multi-component picture.
- "Each discipline self-describes via a single struct conformance" — the existing 8.7 framing is plugin-shaped already; the rewrite extends rather than replaces the framing.
- ADRs follow Context / Decision / Status / Consequences with (+)/(-) bullets. ADR-10 fits cleanly.
- One-line glossary entries in tabular form.

Do not introduce file-by-file directory listings, full protocol surfaces, or code blocks longer than 3–5 lines. That detail belongs in `architecture.md`.

### Coordination with story 76.4's outcomes

76.4 introduced the `Debug` / `Debug (Research)` / `Release` / `Release (Research)` build-configuration matrix and the `PEACH_RESEARCH` Swift compilation flag. The v0.9 amendment must not contradict that matrix — per-discipline activation lives **inside** the envelope, not alongside it. Story 77.1's "Why the `PEACH_RESEARCH` envelope is preserved" Dev Note (line 260 in `77-1-...md`) is the authoritative wording; quote or paraphrase it directly in the v0.9 activation subsection and in ADR-10.

### Coordination with future epics

If a future epic re-organizes ports (e.g., a feature-local port for CRM gap positions becomes a pattern), the v0.9 amendment may itself need superseding. That is fine — `architecture.md` is append-only; future amendments will supersede v0.9. Do not attempt to design for that hypothetical: write v0.9 to describe the present.

### References

- Story 77.1 — `docs/implementation-artifacts/77-1-plugin-style-discipline-ui-contributions.md`. Authoritative source for the activation mechanism (Shape A, `#if PEACH_RESEARCH`), the plugin framing, and the rejection of runtime activation.
- Story 77.2 — `docs/implementation-artifacts/77-2-discipline-owned-ui-contributions.md`. Authoritative source for the `TrainingDisciplineUI` protocol split, the file-move list, and the central-deletion list.
- Story 77.3 — `docs/implementation-artifacts/77-3-discipline-owned-data-declarations.md`. Authoritative source for the data-layer audit findings (likely no-op or near-no-op).
- Story 77.4 — `docs/implementation-artifacts/77-4-json-envelope-storage-redesign.md`. Authoritative source for the envelope `@Model TrainingRecord`, the `TrainingDisciplinePayload` protocol, and the no-deployed-user / no-migration decision.
- Story 77.5 — `docs/implementation-artifacts/77-5-csv-migration-plugin-contract.md`. Authoritative source for the `csvHistory` shape, the runner's history-diffing contract, and the deletion of `V1ToV2Migration.swift` / `V2ToV3Migration.swift`.
- Story 77.6 — `docs/implementation-artifacts/77-6-feature-owned-gap-positions-storage.md`. Authoritative source for the `enabledGapPositions` move and the chosen wiring mechanism.
- Story 77.7 — `docs/implementation-artifacts/77-7-collapse-merge-import-boilerplate.md`. Authoritative source for any generic merge-import helper that replaces the four near-identical encode-and-insert-if-new loops.
- Story 77.8 — `docs/implementation-artifacts/77-8-typed-discipline-payload-associated-type.md`. Authoritative source for the decision on whether `TrainingDiscipline` adopts an associated `Payload` type and how the registry boundary handles the existential.
- Story 77.9 — `docs/implementation-artifacts/77-9-payload-streaming-iteration.md`. Authoritative source for the streaming/batched payload-iteration API on `TrainingDataStore`.
- `docs/planning-artifacts/architecture.md` — line 2695 (v0.5 start), line 2701 (`**Supersedes:**` example), line 2877 (v0.5 "Expected Result / Adding a discipline" enumeration), line 2897 (v0.5 directory snapshot), line 2962 (v0.5 service-boundaries table), line 2974 (v0.5 validation), line 3097 (v0.8 end / v0.9 insertion point).
- `docs/arc42.md` — line 1 (header), line 153 (Section 4 row), lines 596–620 (Section 8.7), line 808 (ADR-9 / ADR-10 insertion point), line 822 (ADR-9 closing), line 890 (Section 11 outdated-architecture row), line 925 (Section 12 `StatisticsKey` for style reference), line 931 (`TrainingDisciplineRegistry` glossary entry).
- `docs/planning-artifacts/epics.md` — Epic 77 section. Story-list entries 77.1 → 77.10 are present; this story appends the 77.11 entry.
- Memory: `feedback_arc42_intent_not_implementation` — arc42 conveys What/Why at a high level; code/architecture.md has the How details. Story 77.11 honors this split.

## Dev Agent Record

### Completion Notes

- Wrote `architecture.md` v0.9 amendment (`Plugin-Style Discipline Contributions`) appended after v0.8. The amendment includes a leading paragraph + `**Supersedes:**` block (5 superseded v0.5 claims: protocol-surface-is-closed, the v0.5 Adding-a-discipline four-step list, central UI fragments, per-discipline `@Model` declarations, central CSV migration enumeration with named deletions of `SettingsContributions.swift` / `ProfileContributions.swift` / `UIContributions.swift` / `V1ToV2Migration.swift` / `V2ToV3Migration.swift` / per-feature `@Model` declarations) + `**Implementation stories:**` line citing 77.1–77.10 + 77.12, then 9 substantive subsections (two-protocol split, feature-directory colocation rule, per-discipline compile-time activation, JSON-envelope persistence, history+derivation CSV migration, feature-local storage for `enabledGapPositions`, updated "Adding a new discipline" sequence, updated project-structure snapshot for `Peach/Training/<Feature>/`, updated central-files inventory) + the `### v0.9 Architecture Validation` block. Each subsection ends with a `[Source: …]` citation, every named symbol uses its literal Swift identifier, and code examples are concrete: the actual `TrainingDiscipline` / `TrainingDisciplineUI` member surfaces, the `TrainingRecord` envelope shape, a representative payload struct, and the `DisciplineBootstrap` candidates list with its `#if PEACH_RESEARCH` block.
- Dispatched the BMAD `arc42-documentation-architect` persona (Gernot, the arc42 architect) for Tasks 3, 4, and 5 to keep the `arc42.md` rewrite in arc42's prose-first voice. The agent rewrote Section 8.7 in place (5 paragraphs + a 3-step "Adding a new discipline" list), inserted ADR-10 after ADR-9 with the standard Context / Decision / Status / Consequences template (4 (+) / 2 (–) bullets), bumped the header (Version 3.1, today's date, Status line referencing epic 77 plugin-style disciplines), tweaked the Section 4 `Simplicity` row, shrunk the Section 11 outdated-architecture row to a one-line "predates implementation; arc42 + v0.6+ amendments are the source of truth" framing, and added/updated glossary entries for `TrainingDisciplineUI`, `DisciplineBootstrap`, `PEACH_RESEARCH`, `TrainingRecord`, `Training Discipline`, and `TrainingDisciplineRegistry`. After the agent's pass I added one missing glossary entry — `TrainingDisciplinePayload` — to align the count with what the epics.md 77.11 entry promises.
- Confirmed Story 77.11 entry already present in `docs/planning-artifacts/epics.md` with one-sentence-per-AC summaries; the work-order paragraph already lists 77.11 at the end. No edits needed.
- Consistency greps (`activeCategories.contains`, `switch discipline.category`, `TrainingDiscipline enum case`, `V1ToV2Migration`, `V2ToV3Migration`, `SettingsContributions.swift`, `ProfileContributions.swift`, `UIContributions.swift`) returned zero hits in the touched arc42.md sections. Hits in `architecture.md` v0.5 are intentional historical text; the v0.9 supersession block and central-files-inventory list reference the deleted central files by name as required by AC 1.
- iOS and macOS test suites green (1479 / 1473 passing). Builds clean (the `appintentsmetadataprocessor` warning is pre-existing Apple framework noise, unrelated to documentation changes).

### File List

Modified:
- `docs/planning-artifacts/architecture.md` — appended v0.9 amendment after v0.8 (line 3097); 9 subsections + project-structure snapshot + central-files inventory + validation block.
- `docs/arc42.md` — header version bumped to 3.1 with date 2026-04-30; Section 4 line 153 row tweaked; Section 8.7 (lines ~596–614) rewritten in place; ADR-10 inserted after ADR-9 (lines ~818–832); Section 11 outdated-architecture row trimmed; Section 12 Glossary additions (`DisciplineBootstrap`, `PEACH_RESEARCH`, `TrainingDisciplinePayload`, `TrainingDisciplineUI`, `TrainingRecord`) and updates (`Training Discipline`, `TrainingDisciplineRegistry`).
- `docs/implementation-artifacts/77-11-update-architecture-documentation-for-plugin-style-disciplines.md` — Status → review, Tasks marked `[x]`, this Dev Agent Record / File List / Change Log entry added.
- `docs/implementation-artifacts/sprint-status.yaml` — `77-11-update-architecture-documentation-for-plugin-style-disciplines: review`; `last_updated` bumped to 2026-04-30.

## Change Log

- 2026-04-27: Drafted as Story 77.5, the documentation-update follow-up after 77.1 / 77.2 / 77.3 / 77.4 land. Status → ready-for-dev.
- 2026-04-28: Renumbered to 77.10 (envelope storage and CSV migration plugin take 77.4 and 77.5; gap-positions storage moves to 77.6). Scope expanded to also document 77.4 (JSON envelope persistence) and 77.5 (history+derivation CSV migration). The "runs after" gate now includes 77.5 and 77.6.
- 2026-04-28: Renumbered from 77.7 to 77.10 to make room for three new stories (77.7 merge-import helper, 77.8 typed payload associated type, 77.9 payload streaming) deferred from the 77.4 review. The "runs after" gate now includes 77.7 / 77.8 / 77.9.
- 2026-04-28: Renumbered to 77.11 to make room for 77.10 (test isolation for shared registries) deferred from the 77.5 review. The "runs after" gate now includes 77.10.
- 2026-04-30: Documentation update implemented. v0.9 amendment landed in `architecture.md`; arc42 Section 8.7 + ADR-10 + cross-cutting touch-ups landed in `arc42.md`. Status → review.
