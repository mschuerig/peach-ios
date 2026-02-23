---
project_name: 'Peach'
user_name: 'Michael'
date: '2026-02-21'
sections_completed: ['technology_stack', 'language_rules', 'framework_rules', 'testing_rules', 'code_quality', 'workflow_rules', 'critical_rules']
status: 'complete'
rule_count: 85
optimized_for_llm: true
---

# Project Context for AI Agents

_This file contains critical rules and patterns that AI agents must follow when implementing code in this project. Focus on unobvious details that agents might otherwise miss._

---

## Technology Stack & Versions

- **Swift 6.0** — strict concurrency enforced; all UI-facing types require `@MainActor`; `Sendable` checked at compile time
- **iOS 26.0** deployment target — use latest APIs freely, no backward compatibility
- **SwiftUI** — declarative UI with SwiftUI lifecycle; **no UIKit in views** (UIKit only through protocol abstractions like `HapticFeedback`)
- **SwiftData** — `@Model` for persistence; **only `TrainingDataStore` accesses SwiftData** — no direct `ModelContext` usage elsewhere
- **AVAudioEngine** — each `NotePlayer` implementation owns its own engine instance; `SineWaveNotePlayer` (sine waves), `SoundFontNotePlayer` (SF2 sampler). `RoutingNotePlayer` selects the active one
- **Swift Testing** — `@Test`, `@Suite`, `#expect()` for all tests; **never use XCTest** (`XCTAssertEqual`, `XCTestCase`, `setUp/tearDown` are all wrong)
- **@Observable** — modern observation macro; **never use `ObservableObject`/`@Published`**
- **@AppStorage** — user preferences; keys centralized in `SettingsKeys.swift`
- **String Catalogs** — English + German localization via `Localizable.xcstrings`
- **Zero third-party dependencies** — do not add external packages without explicit approval
- **Universal app** — iPhone + iPad, portrait + landscape

## Critical Implementation Rules

### Language-Specific Rules (Swift 6)

**Concurrency (compiler-enforced):**
- **`@MainActor` on all service classes and mocks** — the compiler enforces isolation boundaries; UI-facing types must be explicitly isolated
- **`Sendable` conformance enforced** — types crossing isolation boundaries must be `Sendable`; use value types to satisfy this naturally
- **`nonisolated` only when compiler requires it** — needed for protocol conformance (`Hashable`, `Codable`) on `@MainActor` types; do not use it to bypass isolation
- **Closures crossing isolation boundaries** — closures from `@MainActor` contexts passed to non-isolated APIs need explicit `@Sendable` annotation; Swift 6 rejects implicit captures

**Async/Await:**
- **`async/await` for all asynchronous work** — no completion handlers, no Combine (`PassthroughSubject`, `sink`, etc.); structured concurrency only
- **`withCheckedThrowingContinuation`** for bridging callback APIs — **continuation must be resumed exactly once** on every code path, including errors
- **Task cancellation** — check for `CancellationError` before generic error handling; cancellation is a graceful stop, not a failure
- **Spawned `Task`s must produce observable side effects** — state changes or callbacks that tests can synchronize on; no fire-and-forget without test hooks

**Access Control:**
- **Default to `private`** — only use `internal` when cross-file access within the module is needed
- **Never use `public` or `open`** — single-module app, no external consumers

**Type Design:**
- **Value types by default** — `struct` for data carriers; `class` only for `@Observable` or reference semantics
- **`final class`** — mark classes `final` unless inheritance is explicitly designed for
- **No force unwrapping (`!`)** — no `@IBOutlet`, no implicit unwraps

**Error Handling:**
- **Typed error enums per service** — `enum AudioError: Error`, `enum DataStoreError: Error`; errors are specific and descriptive
- **Protocol-first design** — define protocol before implementation; enables test mocking without frameworks

### Framework-Specific Rules

**SwiftUI Views:**
- **Views are thin** — observe state, render, send actions; no business logic in views
- **Views only interact with `TrainingSession` and `PerceptualProfile`** — never import or reference `NotePlayer`, `NextNoteStrategy`, or `TrainingDataStore` from views
- **`@Environment` for dependency injection** — custom `EnvironmentKey` types (e.g., `TrainingSessionKey`); **never use `@EnvironmentObject`** (incompatible with `@Observable`)
- **Extract subviews at ~40 lines** — when a view body exceeds ~40 lines, extract child views
- **Responsive layout** — detect `@Environment(\.verticalSizeClass)` for compact/regular; extract layout parameters to `static` methods for unit testability
- **`NavigationDestination` enum** for type-safe routing — no string-based navigation

**SwiftData:**
- **`TrainingDataStore` is the sole data accessor** — all CRUD goes through this single service
- **`ComparisonRecord` is the only `@Model`** — flat structure: `note1`, `note2`, `note2CentOffset`, `isCorrect`, `timestamp`
- **`ModelContainer` initialized once in `PeachApp.swift`** — passed via SwiftUI environment; new models must be registered in the schema there

**AVAudioEngine:**
- **Each `NotePlayer` implementation owns its own `AVAudioEngine` instance** — `SineWaveNotePlayer` uses `AVAudioPlayerNode`, `SoundFontNotePlayer` uses `AVAudioUnitSampler`. `RoutingNotePlayer` ensures only one is active at a time
- **`RoutingNotePlayer`** — wraps `SineWaveNotePlayer` and optional `SoundFontNotePlayer`; reads `SettingsKeys.soundSource` (`"sine"` or `"cello"`) on each `play()` call to select the active player
- **Protocol boundary: `NotePlayer`** — knows only frequencies (Hz), durations, envelopes; no concept of MIDI notes, comparisons, or training
- **MIDI-to-Hz conversion** — use existing `FrequencyCalculation.swift`, never reimplement. Includes `midiNoteAndCents(frequency:referencePitch:)` for Hz→MIDI reverse conversion
- **Audio interruption handling** — `SineWaveNotePlayer` reports interruptions; `TrainingSession` discards current comparison

**State Management:**
- **`TrainingSession` is the central state machine** — `idle` → `playingNote1` → `playingNote2` → `awaitingAnswer` → `showingFeedback` → (loop)
- **State transitions are guarded** — preconditions enforced; never skip states
- **Observer pattern** — `ComparisonObserver` protocol; observers injected as array into `TrainingSession`
- **Settings read live** — `TrainingSession` reads `@AppStorage` on each comparison, not cached; `RoutingNotePlayer` reads `soundSource` on each `play()` call

**Composition Root (`PeachApp.swift`):**
- **All service instantiation happens in `PeachApp.swift`** — this is the single dependency graph source of truth
- **Never create service instances elsewhere** — new services get wired here and injected via environment

**When Adding New Components:**
- New injectable service → create `EnvironmentKey`, extend `EnvironmentValues`, wire in `PeachApp.swift`
- New `ComparisonObserver` → add to observer array in `PeachApp.swift`; inject only needed mocks in tests
- New SwiftData `@Model` → register in `ModelContainer` schema in `PeachApp.swift`
- New layout logic → extract to `static` methods for unit testability
- New state transitions → respect existing guards in `TrainingSession`; use `waitForState` helper in tests

### Testing Rules

**Run the full suite before every commit:**
`xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
Never run only specific test files — always the complete suite.

**Framework & Structure:**
- **Swift Testing only** — `@Test("behavioral description")`, `@Suite("name")`, `#expect()`
- **Struct-based suites** — no classes, no `setUp`/`tearDown`; use factory methods for fixtures
- **Every `@Test` function must be `@MainActor async`** — Swift Testing runs tests in parallel; without `@MainActor`, data races against isolated services
- **No `test` prefix on function names** — `@Test` attribute marks the test; name describes behavior: `func startsInIdleState()`, not `func testStartsInIdleState()`
- **Behavioral test descriptions** — `@Test("plays note 1 after starting")`, not `@Test("test playNote1 method")`

**Test Organization:**
- **Mirror source structure** — `PeachTests/Core/Audio/` mirrors `Peach/Core/Audio/`
- **One test file per source file** — `SineWaveNotePlayer.swift` → `SineWaveNotePlayerTests.swift`
- **Mock files live in test target** — `MockNotePlayer.swift`, `MockTrainingDataStore.swift`, etc.
- **Fresh mocks per test** — create via factory method in each test; never share mocks across tests (parallel execution)

**SwiftData in Tests:**
- **In-memory `ModelContainer`** — tests must use `ModelConfiguration(isStoredInMemoryOnly: true)`; never use the production container

**Mock Contract (all new mocks must follow):**
- Conform to the same protocol as the production implementation
- `@MainActor` isolated
- Track all method calls with counters and captured parameters (`playCallCount`, `lastFrequency`, `playHistory`)
- Support error injection (`shouldThrowError`, `errorToThrow`)
- Provide synchronous callback hooks (`onPlayCalled`, `onStopCalled`) that fire before any async delays
- Include `instantPlayback` mode for deterministic timing
- Provide `reset()` method for cleanup

**Test Helpers:**
- **`waitForState` helper** — async assertion for `TrainingSession` state transitions; **never use raw `#expect` immediately after an async action** — the state change races
- **Factory methods return tuples** — `makeTrainingSession() -> (session:, notePlayer:, strategy:, ...)` so each test accesses specific mocks for verification
- **Layout tests use `static` methods** — test layout logic without instantiating SwiftUI views

**Coverage:**
- **All new code requires tests** — test-first development workflow

### Code Quality & Style Rules

**Project-Specific Naming (non-obvious conventions):**
- **Protocols:** capability nouns — `NotePlayer`, `NextNoteStrategy` (not `-able`, not `-Protocol` suffix)
- **Protocol implementations:** descriptive prefix — `SineWaveNotePlayer`, `AdaptiveNoteStrategy`
- **Screens:** `{Name}Screen.swift` — not `{Name}View` or `{Name}ViewController`
- **Subviews:** `{Name}View.swift` — `PianoKeyboardView.swift`, `FeedbackIndicator.swift`
- **Mocks:** `Mock{Name}.swift` — not `{Name}Mock`, `Fake{Name}`, or `Stub{Name}`
- **Boolean properties:** `is`/`has`/`should` prefix — `isCorrect`, `isCompact`, `shouldThrowError`
- **Enum cases:** `lowerCamelCase` — `case playingNote1`, not `case PlayingNote1`
- **SwiftData models:** singular noun — `ComparisonRecord`, not `ComparisonRecords`

**File Placement (decision tree):**
- Protocol or service used across features → `Core/{subdomain}/`
- Screen the user navigates to → `{Feature}/{Feature}Screen.swift`
- Subview used by one screen → same feature directory as the screen
- **Do not create `Utils/`, `Helpers/`, `Shared/`, `Common/` directories** — none exist and agents must not create them preemptively

**Code Style:**
- **Trailing closure syntax for single closures only** — use labeled parameters when multiple closures are involved
- **`// MARK:` only in files with multiple distinct sections** — don't scatter in small files
- **No documentation drive-bys** — don't add comments, docstrings, or type annotations to code you didn't write or change
- **No unnecessary comments** — code should be self-explanatory; only comment where logic isn't self-evident

### Development Workflow Rules

**Before Starting Any Task:**
- **Check for uncommitted changes** — run `git status`; do not start new work with a dirty working tree
- **Read the story file** — find the relevant story in `docs/implementation-artifacts/`; understand all acceptance criteria before writing code

**Test-Driven Development (TDD):**
1. Read story and acceptance criteria
2. Write failing tests that encode the ACs
3. Implement until tests pass
4. Refactor if needed (tests must still pass)
5. Run full test suite
6. Commit

- **Bug fixes:** write a failing test that reproduces the bug before fixing it

**Git Workflow:**
- **Commit directly to `main`** — no feature branches unless explicitly asked
- **Commit after each meaningful task** — one commit per story or sub-task
- **Commit message format:** `{Verb} story {id}: {description}` — e.g., `Implement story 7.5: App Icon Design and Implementation`
- **Do not batch unrelated changes** into a single commit
- **Do not push to remote** unless explicitly asked

**Pre-Commit Gate:**
- Run full test suite: `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
- **All tests must pass** — do not commit with failing tests
- **Never run only specific test files** — always the complete suite

**Tool Scripts:**
- Analysis/processing code goes in `tools/` directory as named script files
- Ask for review before execution; commit scripts alongside the work that introduced them

### Critical Don't-Miss Rules

**The Golden Rule:**
- **Read before writing** — before implementing anything, read the existing implementation of the component you're modifying or the closest analogous component; the codebase is the primary source of truth for patterns

**Architectural Boundaries (hard rules):**
- **Views contain zero business logic** — no computation, no conditional logic beyond rendering; derived values come from `TrainingSession` or `PerceptualProfile` as computed properties
- **`TrainingSession` is the ONLY component that understands "comparisons" as a training sequence** — `NotePlayer` knows frequencies, `NextNoteStrategy` knows note selection, neither knows about the loop
- **`PerceptualProfile` is in-memory only** — rebuilt from `ComparisonRecord` on startup, updated incrementally; never persist it to SwiftData

**Domain Rules Agents Will Get Wrong:**
- **MIDI note range: 0–127** — `PerceptualProfile` is indexed by MIDI note (128 slots, 0-based); out-of-range = crash
- **Cent offset applies to note 2 only** — note 1 is exact MIDI note, note 2 = note 1 + cent offset; never offset both notes
- **Use `FrequencyCalculation.swift` for all Hz conversions** — don't approximate; the app requires 0.1-cent precision
- **Feedback phase is 0.4 seconds** — preserve this timing in the training loop; it's a perceptual learning design decision

**Never Do This:**
- `ObservableObject` / `@Published` → use `@Observable`
- `@EnvironmentObject` → use `@Environment` with custom `EnvironmentKey`
- `import XCTest` → use `import Testing`
- Combine (`PassthroughSubject`, `sink`) → use `async/await`
- Third `AVAudioEngine` instance → each `NotePlayer` implementation owns one engine; `RoutingNotePlayer` ensures only one is active
- Direct `ModelContext` queries → go through `TrainingDataStore`
- Sleep/fixed delays in tests → use `instantPlayback` mocks and `waitForState`
- `@testable import` to test private methods → test through protocol interfaces
- Premature abstractions, `Utils/` directories, speculative features → keep it simple

**Error Resilience:**
- **`TrainingSession` is the error boundary** — catches all service errors; training loop continues gracefully
- **Audio interruption mid-comparison** → discard incomplete comparison, stop training
- **App backgrounding** → stop training; return to Start Screen on foreground
- **Empty profile (cold start)** → `NextNoteStrategy` uses exploration mode; handle gracefully

---

## Usage Guidelines

**For AI Agents:**
- Read this file before implementing any code
- Follow ALL rules exactly as documented
- When in doubt, prefer the more restrictive option
- Update this file if new patterns emerge

**For Humans:**
- Keep this file lean and focused on agent needs
- Update when technology stack changes
- Review quarterly for outdated rules
- Remove rules that become obvious over time

Last Updated: 2026-02-21
