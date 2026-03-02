# Claude Code Session Analysis: Peach Project

**336 commits, 417 sessions, 19 days (Feb 11 – Mar 2, 2026)**

---

## 1. CLAUDE.md Recommendations

These are patterns extracted from your repeated corrections across sessions. Each recommendation is something you told Claude Code more than once — making them prime candidates for encoding as standing instructions.

### Architecture & Design

- **Prefer stateless designs.** You corrected this at least 6 times: strategies and algorithms should be stateless whenever possible. All mutable state should reside in a single, clear owner (e.g., PerceptualProfile), not scattered across strategy objects. If something *can* be computed on the fly from existing state, it should be.

- **No special-casing for cold start.** Behavior should follow naturally from the data. If the profile is empty, the algorithm should handle that as a regular case, not a special code path.

- **Prefer protocols and value types.** Use protocols for abstraction boundaries (NotePlayer, NextNoteStrategy). Use value types (structs) where domain invariants can be enforced. Wrap raw Float/Double in domain-specific types when the interface is ambiguous.

### Naming & Terminology

- **Maintain a glossary and use it consistently.** You pushed back on terminology drift at least 18 times. Domain terms like "comparison," "difficulty," "threshold," "weak spot" have precise meanings in this project. Claude should check the glossary before introducing or renaming terms.

- **Don't over-dramatize names.** "Test-anxiety" was called out as overblown. Prefer precise, neutral terminology.

- **Follow Apple community conventions.** The `-able` suffix is standard and acceptable. Don't invent restrictions without checking community practice.

- **Implementation details don't belong in the glossary.** Only concepts with important, domain-level meaning should be documented there.

### Testing

- **Never leave failing tests behind.** You said this explicitly: "something like this must not happen." All tests must pass before moving to the next task. This was a recurring issue (19+ instances of test failure corrections).

- **Probabilistic tests must be robust.** If a test must be probabilistic, make the failure probability vanishingly small (e.g., 1000 iterations, not 10). Don't assert exact values — use ranges. This came up at least 3 times.

- **No tautological assertions.** Tests that can't fail aren't tests.

- **Don't proceed by trial and error with test fixes.** You explicitly called this out: "I expect code that doesn't just work, but that is obviously correct on inspection." When tests fail, understand *why* before changing code.

### Process Discipline

- **Fix issues before proceeding.** You had to say "before continuing, fix X" at least 10 times. Don't move to the next task while known issues remain in the current one.

- **Don't delete or overwrite existing content when adding new content.** This happened with the epics file. When adding a new entry to an existing document, append — never replace the whole file.

- **Commit messages should be meaningful.** Don't forget to commit, and use descriptive messages.

- **Document findings for future work.** When you discover something that shouldn't be addressed now, create a tracking entry so it doesn't get lost.

### Avoiding Over-Engineering

- **Don't add features or complexity that wasn't asked for.** You pushed back on unnecessary additions at least 13 times. If something is "not necessary to belabor," skip it.

- **Start simple.** For new implementations, hardwire simple choices rather than building configuration/toggle infrastructure upfront.

- **Explanations for well-known patterns are unnecessary.** Observer pattern, common Swift conventions, etc. don't need inline explanations.

### iOS / Xcode Specifics

- **You cannot run Xcode builds or simulator tests.** Accept this limitation and write code that is correct by construction. When the user reports a runtime failure, reason carefully about the cause rather than making speculative changes.

- **Audio code needs special care.** AVAudioEngine, AVAudioUnitSampler, and related APIs have subtle threading and lifecycle requirements. Don't assume straightforward async/await patterns work for audio.

- **Check for deprecated APIs.** `masterGain` was deprecated in iOS 15.0. Always verify API availability for the target deployment version.

---

## 2. Opus vs Sonnet Comparison

### Usage Split

| Metric | Opus 4.6 | Sonnet 4.5 |
|--------|-----------|------------|
| Commits | 271 (83%) | 55 (17%) |
| Period | Feb 11 – Mar 2 | Feb 12 – Feb 15 |

Sonnet was used exclusively in the first 4 days of the project, after which you switched entirely to Opus. This matters for interpreting the numbers below — the early project phase naturally involves more design discussion and course correction.

### Correction Rates

| Metric | Opus | Sonnet |
|--------|------|--------|
| Mean corrections/commit | 0.31 | 1.22 |
| Commits with any correction | 18% | 64% |
| Freeform human turns/commit | 3.7 | 7.5 |
| Median session duration | 18 min | 34 min |

Sonnet required roughly **4× the correction rate** and **2× the interaction density** per commit.

### Controlling for Project Phase

To check whether this is a Sonnet problem or an early-project problem, I compared early Opus (Feb 11–15, same period as Sonnet) against later Opus:

| Period | n | Mean corrections/commit | % with corrections |
|--------|---|------------------------|--------------------|
| Early Opus (Feb 11–15) | 20 | 1.40 | 45% |
| Late Opus (Feb 17+) | 251 | 0.22 | 16% |
| Sonnet (Feb 12–15) | 55 | 1.22 | 64% |

**Interpretation:** Early Opus had a similar correction *rate* to Sonnet (1.40 vs 1.22), so the higher mean is partly explained by the project phase. However, Sonnet had corrections in **64%** of commits vs Opus's **45%** in the same period — meaning Sonnet more consistently needed course correction, even accounting for the exploratory phase.

### Where Sonnet Struggled Most

The worst Sonnet sessions were concentrated in:

- **SineWaveNotePlayer implementation** (5 corrections) — this was the "trial and error" session where you had to tell Sonnet to go back to the drawing board. Audio code with AVAudioEngine threading proved especially difficult.
- **Training loop state machine bugs** (4 corrections across multiple commits) — runtime behavior that couldn't be caught without Xcode, but Sonnet's fixes were often speculative rather than principled.
- **Probabilistic test reliability** (3 corrections) — Sonnet wrote flaky tests that failed intermittently.

### Where Sonnet Was Fine

- **Story creation** (6 commits, 0.17 corrections/commit) — essentially identical to Opus's rate (0.16). Documentation and planning tasks showed no meaningful difference.
- **Clean code review fixes** — when the scope was well-defined and narrow.

### Task Type Suitability

| Task Type | Opus corr/commit | Sonnet corr/commit |
|-----------|-------------------|--------------------|
| story_creation | 0.16 | 0.17 |
| implementation | 0.21 | 0.89 |
| code_review | 0.11 | 1.36 |
| bugfix | 1.00 | 2.29 |

**Summary:** Sonnet is roughly comparable for planning/documentation tasks but noticeably weaker for implementation, code review, and especially bugfixing — tasks that require deeper reasoning about code behavior and consequences.

### Multi-Session Rate (Rework)

- Opus: 27% of commits needed multiple sessions
- Sonnet: 9% of commits needed multiple sessions

This initially looks favorable for Sonnet, but it's likely because Sonnet commits were smaller in scope. Opus was tackling more complex tasks by the time you switched to it exclusively.

---

## Summary

**Highest-ROI changes for your workflow:**

1. **Encode the correction patterns above into CLAUDE.md** — especially "tests must pass before proceeding," "stateless by default," and "don't delete existing content."

2. **Your model choice is already correct.** The switch to Opus for all implementation work is well-supported by the data. Sonnet could be used for story creation and documentation where the correction rates are equivalent, if cost or speed matters.

3. **The BMAD workflow is working.** The create-story → dev-story → code-review cycle gives you natural checkpoints. The code review step catches real issues (83 Opus code review commits with only 0.11 corrections/commit shows the reviews themselves are running smoothly).
