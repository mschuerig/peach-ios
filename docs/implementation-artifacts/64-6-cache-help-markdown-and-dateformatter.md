# Story 64.6: Cache Help Markdown Parsing and DateFormatter Allocation

Status: done

## Story

As a **user navigating the app**,
I want help screens and chart exports to render without unnecessary allocations,
so that opening help is instant and chart sharing doesn't create throwaway objects.

## Acceptance Criteria

1. **Given** `HelpContentView` renders help sections **When** the view body is evaluated **Then** `AttributedString(markdown:)` is NOT called — markdown is pre-parsed and cached, not parsed on every render.

2. **Given** `HelpContentView` ForEach **When** rendering sections **Then** ForEach uses a stable identity (not `\.offset` from enumeration).

3. **Given** `ChartImageRenderer.exportFileName()` **When** called **Then** it uses a static `DateFormatter` instead of creating a new `DateFormatter` on every call.

4. **Given** `SettingsScreen.gapPositionsBinding` **When** the Form body is evaluated **Then** the Binding is not recreated on every render — it is stored or computed once.

5. **Given** the full test suite **When** run **Then** all existing tests pass with zero regressions.

## Tasks / Subtasks

- [x] Task 1: Cache markdown parsing in `HelpContentView` (AC: #1, #2)
  - [x] 1.1 Make `HelpSection` conform to `Identifiable` (add `let id = UUID()` or use title as id)
  - [x] 1.2 Pre-parse markdown in `HelpSection.init` or add a lazy `attributedBody` property that caches the `AttributedString` result
  - [x] 1.3 In `HelpContentView.body`, use the pre-parsed attributed string instead of calling `markdownText()` during render
  - [x] 1.4 Replace `ForEach(Array(sections.enumerated()), id: \.offset)` with `ForEach(sections)` using the new Identifiable conformance

- [x] Task 2: Make `ChartImageRenderer.exportFileName` DateFormatter static (AC: #3)
  - [x] 2.1 Extract the `DateFormatter` in `exportFileName()` to a `private static let` property
  - [x] 2.2 Verify thread safety — `DateFormatter` is not thread-safe, but this code runs on MainActor so a single static instance is fine

- [x] Task 3: Fix `SettingsScreen.gapPositionsBinding` recreation (AC: #4)
  - [x] 3.1 The current `gapPositionsBinding` computed property creates a new `Binding(get:set:)` on every body evaluation, with `GapPositionEncoding.decodeWithDefault()` in the getter
  - [x] 3.2 Options: (a) store a `@State private var enabledGapPositions: Set<StepPosition>` and sync it with `@AppStorage` via `onChange`, or (b) use a cached binding that only decodes when the encoded string changes
  - [x] 3.3 Choose the simplest approach that avoids per-render decode/encode

- [x] Task 4: Run full test suite (AC: #5)

## Dev Agent Record

### Implementation Plan

- Task 1: Made `HelpSection` conform to `Identifiable` with `let id = UUID()`. Markdown is now pre-parsed in `init` into a stored `attributedBody: AttributedString?` property. `HelpContentView.body` uses the cached attributed string directly (falling back to plain text if parsing failed). Removed `markdownText()` helper. `ForEach` now uses `Identifiable` conformance instead of `\.offset`.
- Task 2: Extracted `DateFormatter` to `private static let fileNameFormatter` with closure-based initialization. Thread-safe on MainActor.
- Task 3: Chose option (a) — `@State private var enabledGapPositions: Set<StepPosition>` initialized from `UserDefaults`, synced bidirectionally with `@AppStorage` via two `onChange` modifiers. Removed the `gapPositionsBinding` computed property entirely; `GridToggleRow` now binds directly to `$enabledGapPositions`.

### Completion Notes

All 4 tasks implemented and verified. 1534 tests pass with zero regressions. 5 new tests added for `HelpSection` (Identifiable conformance, distinct IDs, attributedBody parsing, stability, empty string handling).

## File List

- `Peach/App/HelpContentView.swift` — Modified: HelpSection now Identifiable with pre-parsed attributedBody; HelpContentView uses cached markdown and ForEach with stable identity
- `Peach/Profile/ChartImageRenderer.swift` — Modified: DateFormatter extracted to static let
- `Peach/Settings/SettingsScreen.swift` — Modified: gapPositionsBinding replaced with @State + onChange sync
- `PeachTests/App/HelpContentViewTests.swift` — Modified: Added 5 tests for Identifiable conformance and attributedBody caching

## Change Log

- 2026-03-28: Implemented story 64.6 — cached help markdown parsing, static DateFormatter, and gapPositionsBinding fix

## Dev Notes

### HelpContentView Markdown Parsing

`HelpContentView.markdownText()` calls `AttributedString(markdown:options:)` inside body for each section. This does full markdown parsing (tokenize, build attributed string, apply styles) on every render. Since help sections are static constants defined with `String(localized:)`, the markdown content never changes at runtime. Pre-parsing once eliminates this cost entirely.

### ChartImageRenderer DateFormatter

`exportFileName()` creates `DateFormatter()`, sets `dateFormat`, `locale`, and `timeZone` on every call. `DateFormatter` init is expensive (~0.1ms per allocation). This is called from a `.task(id:)` modifier, so it runs whenever record count changes. A static instance is the standard fix.

### SettingsScreen gapPositionsBinding

The computed property `gapPositionsBinding` returns a new `Binding(get:set:)` each time. The `get` closure calls `GapPositionEncoding.decodeWithDefault(enabledGapPositionsEncoded)` — string splitting + Set construction — on every read. Since `@AppStorage` already triggers view invalidation when the encoded string changes, a `@State` + `onChange` pattern would compute the decoded value once per change.

### Source File Locations

| File | Path |
|------|------|
| HelpContentView | `Peach/App/HelpContentView.swift` |
| ChartImageRenderer | `Peach/Profile/ChartImageRenderer.swift` |
| SettingsScreen | `Peach/Settings/SettingsScreen.swift` |

### References

- [Source: Peach/App/HelpContentView.swift:25-33] — markdownText in body
- [Source: Peach/Profile/ChartImageRenderer.swift:33-36] — DateFormatter per call
- [Source: Peach/Settings/SettingsScreen.swift:271-276] — gapPositionsBinding
