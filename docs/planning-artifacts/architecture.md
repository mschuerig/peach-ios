---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
lastStep: 8
status: 'amended'
completedAt: '2026-02-12'
amendedAt: '2026-03-06'
inputDocuments: ['docs/planning-artifacts/prd.md', 'docs/planning-artifacts/ux-design-specification.md', 'docs/planning-artifacts/glossary.md', 'docs/brainstorming/brainstorming-session-2026-02-11.md']
workflowType: 'architecture'
project_name: 'Peach'
user_name: 'Michael'
date: '2026-02-12'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements:**
44 FRs (FR1–FR43 plus FR7a) across 8 categories. The requirements cluster into three tiers of architectural significance:
1. **Algorithm layer** (FR9-FR15): The adaptive comparison selection engine — highest complexity, most design attention needed. Manages perceptual profile, difficulty adjustment, weak spot targeting, and cold start behavior.
2. **Audio layer** (FR16-FR20): Precision tone generation with sub-10ms latency and 0.1-cent accuracy. Protocol-based for swappable sound sources. Envelope shaping to prevent artifacts.
3. **Application layer** (FR1-FR8, FR21-FR42): Training loop UI, profile visualization, data persistence, settings, localization. Straightforward by design — the PRD explicitly keeps UI minimal to keep focus on the training experience.

**Non-Functional Requirements:**
- Audio latency < 10ms (drives audio engine technology choice)
- Frequency precision to 0.1 cent (drives tone generation approach)
- Atomic data writes surviving crashes and force quits (drives persistence strategy)
- Profile visualization rendering < 1 second (drives computation/caching approach)
- App launch to interactive < 2 seconds
- 44x44pt minimum tap targets (Apple HIG compliance)
- VoiceOver, contrast, and accessibility basics

**Scale & Complexity:**
- Primary domain: Native iOS (Swift/SwiftUI, iOS 26+)
- Complexity level: Low-to-moderate
- Estimated architectural components: 5-6 core modules (Audio Engine, Adaptive Algorithm, Data Persistence, Profile Computation, UI Layer, Settings)

### Technical Constraints & Dependencies

- **iOS 26 minimum, latest Swift/SwiftUI** — no backward compatibility. Enables use of newest APIs without legacy constraints.
- **Entirely on-device** — no network layer, no backend, no authentication. All data local.
- **Test-first development** — comprehensive coverage is a non-negotiable constraint, influencing how modules are structured (testable boundaries, injectable dependencies).
- **Solo developer learning iOS** — architecture should be approachable, not over-engineered. Favor clarity over abstraction depth.
- **iPhone + iPad, portrait + landscape** — responsive layout considerations but no complex platform-specific branching.

### Cross-Cutting Concerns Identified

- **Audio interruption handling** — phone calls, headphone disconnects, app backgrounding must gracefully discard incomplete comparisons across Training Loop, Audio Engine, and Data layers
- **Data integrity** — atomic writes and crash resilience affect persistence strategy across all data-producing components
- **Algorithm parameter propagation** — settings changes (Natural/Mechanical slider, range, duration) must immediately affect subsequent comparisons, connecting Settings → Algorithm → Audio Engine
- **Orientation & device adaptability** — all screens must handle portrait/landscape and iPhone/iPad layouts
- **Localization** — English/German across all user-facing strings

## Starter Template & Technology Foundation

### Primary Technology Domain

Native iOS application — Swift / SwiftUI, targeting iOS 26+

### Starter Evaluation

For native iOS, the starter is Xcode 26's built-in iOS App template with SwiftUI lifecycle. No third-party scaffolding tools apply. The architectural decisions are the technology choices configured within the project.

### Selected Foundation: Xcode 26.3 iOS App Template

**Rationale:** Only viable option for native iOS. Xcode 26.3 ships with Swift 6.2.3, explicit modules by default, integrated agentic coding support (Claude Agent, Codex via MCP), and updated SwiftUI with Liquid Glass design language support.

**Initialization:** Create new Xcode project → iOS → App → SwiftUI lifecycle, Swift language, SwiftData storage

### Technology Decisions

**Language & Runtime:**
- Swift 6.2.3 (Xcode 26.3)
- iOS 26 deployment target — no backward compatibility
- Explicit Swift modules enabled (Xcode 26 default)

**UI Framework:**
- SwiftUI (latest iteration) — declarative, state-driven
- No UIKit unless required for specific capabilities
- No third-party architecture framework (TCA, etc.) — native SwiftUI patterns sufficient for app scope

**Testing Framework:**
- Swift Testing (`@Test`, `#expect()`) for all unit tests — modern, parallel by default, async-native
- XCTest reserved only for UI tests if needed later
- Test-first development workflow

**Data Persistence:**
- SwiftData — native SwiftUI integration, minimal boilerplate, built on Core Data/SQLite
- Ideal for the simple per-comparison data model (two notes, correct/wrong, timestamp)
- Atomic writes and crash resilience handled by the underlying SQLite engine

**Audio Engine:**
- AVAudioEngine + AVAudioSourceNode for real-time sine wave generation
- Sub-10ms latency achievable (64-sample buffer at 44.1kHz ≈ 1.5ms)
- No AudioKit dependency — unnecessary for sine wave generation
- Protocol-based abstraction for future swappable sound sources

**Dependency Management:**
- Swift Package Manager (SPM) — zero third-party dependencies anticipated for MVP

**Localization:**
- String Catalogs (Xcode 26 native) for English/German

**Note:** Project creation in Xcode should be the first implementation step.

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (Block Implementation):**
- Data model structure and persistence approach
- Training loop orchestration and service boundaries
- Profile computation strategy
- Audio playback architecture

**Not Applicable to This Project:**
- Authentication & Security — no accounts, no network, no sensitive data
- API & Communication — fully on-device, no backend
- Infrastructure & Deployment — App Store distribution only, no CI/CD pipeline for MVP

### Data Architecture

**Pitch Comparison Record Model:**
- Flat SwiftData `@Model` with explicit fields: note1 (MIDI note), note2 (MIDI note), note2CentOffset, isCorrect, timestamp
- The first note in a comparison is always an exact MIDI note. The second note is the same MIDI note shifted by a cent difference.
- MIDI note range: 0–127

**Settings Storage:**
- `@AppStorage` (UserDefaults) for all settings: Natural/Mechanical slider value, note range bounds, note duration, reference pitch, sound source selection
- Native SwiftUI binding — no custom persistence layer needed

**Profile Computation:**
- Computed on-the-fly for MVP — data volume will not be a bottleneck early on
- Performance optimization deferred until measured

### App Architecture & State Management

**Training Loop Orchestration:**

`TrainingSession` is the central state machine coordinating the training loop. It owns the lifecycle of a comparison: ask strategy → play note 1 → play note 2 → await answer → record result → feedback → repeat.

States: `idle` → `playingNote1` → `playingNote2` → `awaitingAnswer` → `showingFeedback` → (loop)

**Service Layer (protocol-based for testability):**

| Component | Responsibility | MVP Implementation |
|---|---|---|
| `NotePlayer` (protocol) | Plays a single note at a given frequency with envelope. No sequencing, no concept of comparisons. | `SoundFontNotePlayer` |
| `NextNoteStrategy` (protocol) | Given the perceptual profile and settings, returns the next comparison (two notes + cent difference). Decides what to play next. | `AdaptiveNoteStrategy` |
| `TrainingDataStore` | Pure persistence — stores and retrieves comparison records. No computation, no domain logic. | SwiftData implementation |
| `PerceptualProfile` | In-memory aggregate of the user's pitch comparison ability, indexed by MIDI note (0–127). Each slot holds aggregate statistics (arithmetic mean, standard deviation of detection thresholds). Serves as the basis for identifying weak spots. | Loaded from all comparisons on app startup; updated incrementally on each new answer. |
| `TrainingSession` | State machine orchestrating the training loop. Coordinates `NextNoteStrategy`, `NotePlayer`, `TrainingDataStore`, and `PerceptualProfile`. The only component that knows a "comparison" is two notes played in sequence. | Observable object observed by Training Screen |

**Data Flow:**
1. App startup: `TrainingDataStore` → all comparison records → `PerceptualProfile` (full aggregation)
2. Training loop: `NextNoteStrategy` reads `PerceptualProfile` → selects comparison → `TrainingSession` tells `NotePlayer` to play note 1, then note 2 → user answers → result written to `TrainingDataStore` → `PerceptualProfile` updated incrementally
3. Profile Screen: reads `PerceptualProfile` for visualization and summary statistics

**Dependency Injection:**
- All protocols injected into `TrainingSession` for unit testability with mocks
- SwiftUI environment for passing services to views

### Decision Impact Analysis

**Implementation Sequence:**
1. Data model + `TrainingDataStore` (foundation — everything depends on it)
2. `PerceptualProfile` (aggregation logic, startup loading)
3. `NotePlayer` protocol + `SoundFontNotePlayer` (independent of data layer)
4. `NextNoteStrategy` protocol + `AdaptiveNoteStrategy` (depends on `PerceptualProfile`)
5. `TrainingSession` (integrates all services)
6. UI layer (observes `TrainingSession` and `PerceptualProfile`)

**Cross-Component Dependencies:**
- `TrainingSession` depends on all four services — it is the integration point
- `NextNoteStrategy` depends on `PerceptualProfile` — reads weak spots to select comparisons
- `PerceptualProfile` depends on `TrainingDataStore` — loaded from stored records at startup
- `NotePlayer` is fully independent — no dependencies on other components

## Implementation Patterns & Consistency Rules

### Naming Conventions

**All code follows standard Swift conventions:**
- Types & protocols: `PascalCase` — `TrainingSession`, `PitchComparisonRecord`, `NotePlayer`
- Properties, methods, parameters: `camelCase` — `isCorrect`, `playNote(frequency:)`, `detectionThreshold`
- Protocols: noun describing capability — `NotePlayer`, `NextNoteStrategy` (not `NotePlayable`, `NoteStrategyProtocol`)
- Protocol implementations: descriptive prefix — `SoundFontNotePlayer`, `AdaptiveNoteStrategy`
- SwiftData models: singular noun — `PitchComparisonRecord`, not `PitchComparisonRecords`
- Files: match the primary type they contain — `TrainingSession.swift`, `NotePlayer.swift`

### Project Organization (By Feature)

```
Peach/
├── App/                          # App entry point, app-level configuration
│   ├── PeachApp.swift
│   └── ContentView.swift
├── Core/                         # Shared services and models (cross-feature)
│   ├── Audio/
│   │   ├── NotePlayer.swift          # Protocol
│   │   └── SoundFontNotePlayer.swift  # AVAudioUnitSampler SF2 implementation
│   ├── Algorithm/
│   │   ├── NextNoteStrategy.swift    # Protocol
│   │   └── AdaptiveNoteStrategy.swift
│   ├── Data/
│   │   ├── PitchComparisonRecord.swift    # SwiftData model
│   │   └── TrainingDataStore.swift
│   └── Profile/
│       └── PerceptualProfile.swift
├── Training/                     # Training feature
│   ├── TrainingSession.swift
│   └── TrainingScreen.swift
├── Profile/                      # Profile feature
│   └── ProfileScreen.swift
├── Settings/                     # Settings feature
│   └── SettingsScreen.swift
├── Start/                        # Start/home feature
│   └── StartScreen.swift
├── Info/                         # Info/about feature
│   └── InfoScreen.swift
└── Resources/
    └── Localizable.xcstrings
```

### Test Organization

Standard separate test target mirroring source structure:

```
PeachTests/
├── Core/
│   ├── Audio/
│   │   └── SoundFontNotePlayerTests.swift
│   ├── Algorithm/
│   │   └── AdaptiveNoteStrategyTests.swift
│   ├── Data/
│   │   └── TrainingDataStoreTests.swift
│   └── Profile/
│       └── PerceptualProfileTests.swift
└── Training/
    └── TrainingSessionTests.swift
```

### Error Handling

**Typed error enums per service:**
- Each service defines its own error enum: `enum AudioError: Error`, `enum DataStoreError: Error`
- Enables exhaustive `catch` patterns and testable error paths
- Errors are specific and descriptive — `AudioError.engineStartFailed`, not generic `.failed`

**TrainingSession as error boundary:**
- `TrainingSession` catches all service errors and handles them gracefully
- The user never sees an error screen during training
- Audio failure → stop training silently
- Data write failure → log internally, continue training (data loss for one comparison is acceptable)
- The training loop is resilient — individual failures don't break the experience

### SwiftUI View Patterns

- Views are thin: observe state, render, send actions. No business logic.
- Use `@Observable` (iOS 26) for service objects — not the older `ObservableObject` / `@Published` pattern
- Extract subviews when a view body exceeds ~40 lines
- Use SwiftUI environment for dependency injection of services into views

### Enforcement Guidelines

**All AI agents working on this project MUST:**
- Follow Swift naming conventions exactly as specified above
- Place new files in the correct feature group or Core/ subgroup
- Mirror source structure in the test target
- Define typed error enums for any new service
- Keep views free of business logic
- Use `@Observable`, never `ObservableObject`

## Project Structure & Boundaries

### Complete Project Directory Structure

```
Peach/
├── App/
│   ├── PeachApp.swift                # @main entry, SwiftData container setup, service initialization
│   └── ContentView.swift             # Root navigation (Start Screen as home)
├── Core/
│   ├── Audio/
│   │   ├── NotePlayer.swift              # Protocol: play(frequency:, duration:, envelope:)
│   │   └── SoundFontNotePlayer.swift      # AVAudioEngine + AVAudioUnitSampler SF2 implementation
│   ├── Algorithm/
│   │   ├── NextNoteStrategy.swift        # Protocol: nextPitchComparison(profile:, settings:) -> PitchComparison
│   │   └── AdaptiveNoteStrategy.swift    # Weak-spot targeting, difficulty adjustment
│   ├── Data/
│   │   ├── PitchComparisonRecord.swift        # SwiftData @Model
│   │   └── TrainingDataStore.swift       # CRUD operations on PitchComparisonRecord
│   └── Profile/
│       └── PerceptualProfile.swift       # In-memory profile indexed by MIDI note (0–127)
├── Training/
│   ├── TrainingSession.swift             # State machine, orchestrates all Core services
│   └── TrainingScreen.swift              # Higher/Lower buttons, Settings/Profile nav, Feedback Indicator
├── Profile/
│   └── ProfileScreen.swift               # Piano keyboard visualization, confidence band, summary stats
├── Settings/
│   └── SettingsScreen.swift              # Slider, range, duration, reference pitch, sound source
├── Start/
│   └── StartScreen.swift                 # Start Training button, Profile Preview, Settings/Profile/Info buttons
├── Info/
│   └── InfoScreen.swift                  # App name, developer, copyright, version
└── Resources/
    ├── Localizable.xcstrings             # English + German
    └── Assets.xcassets

PeachTests/
├── Core/
│   ├── Audio/
│   │   └── SoundFontNotePlayerTests.swift
│   ├── Algorithm/
│   │   └── AdaptiveNoteStrategyTests.swift
│   ├── Data/
│   │   └── TrainingDataStoreTests.swift
│   └── Profile/
│       └── PerceptualProfileTests.swift
└── Training/
    └── TrainingSessionTests.swift
```

### Architectural Boundaries

**Service Boundaries:**
- `NotePlayer` — knows only about frequencies, durations, and envelopes. Has no concept of musical notes, comparisons, or training. Boundary: receives frequency in Hz, plays sound.
- `NextNoteStrategy` — knows about the perceptual profile and settings. Returns a `PitchComparison` value type (note1, note2, centDifference). Has no concept of audio playback or UI. Boundary: reads profile, produces pitch comparison.
- `TrainingDataStore` — pure persistence. Stores and retrieves `PitchComparisonRecord` models. No computation, no aggregation. Boundary: SwiftData CRUD only.
- `PerceptualProfile` — pure computation. Aggregates comparison data into per-MIDI-note statistics. No persistence, no UI awareness. Boundary: receives comparison results, exposes detection thresholds.
- `TrainingSession` — the only component that crosses boundaries. Orchestrates the above four services. Boundary: the integration layer.

**UI Boundaries:**
- Views observe `TrainingSession` and `PerceptualProfile` — they never call services directly
- Views send user actions to `TrainingSession` (start, answer); stopping is triggered by navigation away or app backgrounding
- Settings Screen writes to `@AppStorage` — `TrainingSession` reads settings when selecting next comparison
- No view-to-view communication — all state flows through services

**Data Boundaries:**
- SwiftData `ModelContainer` initialized in `PeachApp.swift`, passed via SwiftUI environment
- `TrainingDataStore` is the sole accessor of `PitchComparisonRecord` — no other component queries SwiftData directly
- `PerceptualProfile` receives data from `TrainingDataStore` at startup and incremental updates from `TrainingSession` during training

### Requirements to Structure Mapping

| FR Category | Component(s) | Directory |
|---|---|---|
| Training Loop (FR1–FR8) | `TrainingSession`, `TrainingScreen` | `Training/` |
| Adaptive Algorithm (FR9–FR15) | `NextNoteStrategy`, `AdaptiveNoteStrategy`, `PerceptualProfile` | `Core/Algorithm/`, `Core/Profile/` |
| Audio Engine (FR16–FR20) | `NotePlayer`, `SoundFontNotePlayer` | `Core/Audio/` |
| Profile & Statistics (FR21–FR26) | `PerceptualProfile`, `ProfileScreen` | `Core/Profile/`, `Profile/` |
| Data Persistence (FR27–FR29) | `PitchComparisonRecord`, `TrainingDataStore` | `Core/Data/` |
| Settings (FR30–FR36) | `SettingsScreen`, `@AppStorage` | `Settings/` |
| Localization (FR37–FR38) | `Localizable.xcstrings` | `Resources/` |
| Device & Platform (FR39–FR42) | All screens (responsive layouts) | All feature directories |
| Info Screen (FR43) | `InfoScreen` | `Info/` |

### Cross-Cutting Concerns Mapping

| Concern | Affected Components | Resolution |
|---|---|---|
| Audio interruption | `SoundFontNotePlayer`, `TrainingSession` | `NotePlayer` reports interruption → `TrainingSession` discards current comparison |
| Settings propagation | `SettingsScreen`, `TrainingSession`, `NextNoteStrategy`, `NotePlayer` | `TrainingSession` reads `@AppStorage` when requesting next comparison; passes duration to `NotePlayer` |
| Data integrity | `TrainingDataStore` | SwiftData atomic writes; `TrainingSession` writes only complete comparison results |
| App lifecycle | `PeachApp`, `TrainingSession` | Backgrounding → `TrainingSession` stops; foregrounding → returns to Start Screen |

## Architecture Validation Results

### Coherence Validation

**Decision Compatibility:** All technology choices are first-party Apple frameworks (Swift 6.2.3, SwiftUI, SwiftData, AVAudioEngine) — fully compatible on iOS 26 with no version conflicts.

**Pattern Consistency:** Protocol-based services support test-first development. `@Observable` aligns with iOS 26 target. By-feature organization matches clear screen/service boundaries. `@AppStorage` for settings is proportionate to the data complexity.

**Structure Alignment:** Project structure directly maps to architectural boundaries. Each service has a clear home. No ambiguity about where new code should go.

### Requirements Coverage

**Functional Requirements:** All 44 FRs (FR1–FR43 plus FR7a) have explicit architectural support mapped to specific components and directories.

**Non-Functional Requirements:**
- Audio latency < 10ms → AVAudioSourceNode with 64-sample buffer (~1.5ms)
- Frequency precision 0.1 cent → mathematical sine generation
- Atomic writes / crash resilience → SwiftData (SQLite-backed)
- Profile rendering < 1s → in-memory PerceptualProfile (128-slot fixed structure)
- App launch < 2s → minimal startup, single aggregation pass
- Accessibility → SwiftUI native accessibility support

### Gap Analysis

**Critical gaps:** None

**Important gaps:** None

**Minor notes:**
- Haptic feedback (FR5) uses `UIImpactFeedbackGenerator` — implementation detail, not architectural. Called from `TrainingSession` on wrong answer.

### Architecture Completeness Checklist

**Requirements Analysis**
- [x] Project context thoroughly analyzed
- [x] Scale and complexity assessed (low-to-moderate)
- [x] Technical constraints identified (iOS 26, on-device, test-first, solo dev)
- [x] Cross-cutting concerns mapped (audio interruption, data integrity, settings propagation, lifecycle, localization)

**Architectural Decisions**
- [x] All critical decisions documented with versions
- [x] Technology stack fully specified (Swift 6.2.3, SwiftUI, SwiftData, AVAudioEngine, Swift Testing)
- [x] Service boundaries and protocols defined
- [x] Data flow documented end-to-end

**Implementation Patterns**
- [x] Naming conventions established (Swift standard)
- [x] Project organization defined (by feature)
- [x] Error handling patterns specified (typed enums, TrainingSession as boundary)
- [x] SwiftUI view patterns documented (@Observable, thin views)

**Project Structure**
- [x] Complete directory structure defined
- [x] Component boundaries established (5 services, clear responsibilities)
- [x] FR-to-structure mapping complete
- [x] Cross-cutting concerns mapped to resolution strategies

### Architecture Readiness Assessment

**Overall Status:** READY FOR IMPLEMENTATION

**Confidence Level:** High

**Key Strengths:**
- Clean separation of concerns — each service has a single, well-named responsibility
- Entire stack is first-party Apple — no third-party dependency risk
- Protocol-based services enable thorough test-first development
- Architecture complexity matches project complexity — not over-engineered

**Areas for Future Enhancement (Post-MVP):**
- iCloud sync will require SwiftData CloudKit integration — may affect `TrainingDataStore` and `PitchComparisonRecord`
- Swappable sound sources already supported by `NotePlayer` protocol — just add new implementations
- Profile caching/snapshots for temporal progress visualization if performance demands it

### Implementation Handoff

**AI Agent Guidelines:**
- Follow all architectural decisions exactly as documented
- Use implementation patterns consistently across all components
- Respect project structure and boundaries
- Refer to this document for all architectural questions

**First Implementation Priority:**
Create Xcode 26.3 project → iOS → App → SwiftUI lifecycle, Swift language, SwiftData storage. Establish folder structure as defined. Then begin with `PitchComparisonRecord` + `TrainingDataStore` (the data foundation everything depends on).

## v0.2 Architecture Amendment — Pitch Matching

*Amended: 2026-02-25*

This amendment extends the MVP architecture to support Pitch Matching (v0.2), a second training paradigm where the user tunes a note to match a reference pitch. It also documents prerequisite renames needed to disambiguate existing components before adding the new feature.

**Input documents for this amendment:**
- PRD v0.2 additions (FR44–FR52)
- UX Design Specification v0.2 amendment
- Existing codebase analysis

### Prerequisite Renames

With two training modes, several MVP names are now ambiguous. These renames must be completed before implementing Pitch Matching:

| Current Name | New Name | Reason |
|---|---|---|
| `TrainingSession` | `PitchComparisonSession` | Only handles comparison training; "Training" is now ambiguous |
| `TrainingState` | `PitchComparisonSessionState` | States are comparison-specific |
| `TrainingScreen` | `PitchComparisonScreen` | The comparison training UI, not all training |
| `Training/` directory | `PitchComparison/` | Feature directory for comparison training |
| `FeedbackIndicator` | `PitchComparisonFeedbackIndicator` | Distinguishes from pitch matching feedback |
| `NextNoteStrategy` | `NextPitchComparisonStrategy` | Returns a `PitchComparison`, not a generic note; method is `nextPitchComparison()` |

**Names that remain unchanged:**
- `TrainingDataStore` — stores all training data (both modes); "training" means "ear training"
- `TrainingSettings` — shared settings (note range, reference pitch, note duration) apply to both modes
- `PitchComparisonObserver`, `PitchComparison`, `CompletedPitchComparison` — already specific
- `PerceptualProfile` — the concrete class conforms to both pitch comparison and matching protocols
- `NotePlayer` — generic by design, serves both training modes
- `HapticFeedbackManager` — comparison-only behavior, but name doesn't claim "training"

**Rename scope:** Code files, class/struct/enum names, all references in `docs/project-context.md`, `docs/planning-artifacts/architecture.md`, and `docs/planning-artifacts/glossary.md`. Implementation artifact stories referencing old names should be updated if they are not yet completed.

### NotePlayer Protocol Redesign — PlaybackHandle Pattern

The MVP `NotePlayer` protocol assumes fixed-duration playback with an ambient `stop()`. Pitch Matching requires indefinite playback with real-time frequency adjustment. The protocol is redesigned around a `PlaybackHandle` that represents ownership of a playing note.

**New protocol design:**

```swift
protocol PlaybackHandle {
    /// Stops playback. First call sends noteOff; subsequent calls are no-ops.
    func stop() async throws

    /// Adjusts the frequency of the currently playing note in real time.
    /// Caller passes absolute frequency in Hz; implementation computes
    /// the relative pitch bend from the base note.
    func adjustFrequency(_ frequency: Double) async throws
}

protocol NotePlayer {
    /// Starts playing a note at the given frequency.
    /// Returns immediately after onset (does not await duration).
    /// The caller owns the returned handle and is responsible for stopping playback.
    func play(frequency: Double, velocity: UInt8, amplitudeDB: Float) async throws -> PlaybackHandle

    /// Convenience: plays a note for a fixed duration, then stops automatically.
    /// Default implementation uses PlaybackHandle internally.
    func play(frequency: Double, duration: TimeInterval, velocity: UInt8, amplitudeDB: Float) async throws
}
```

**Default implementation for fixed-duration playback:**

```swift
extension NotePlayer {
    func play(frequency: Double, duration: TimeInterval, velocity: UInt8, amplitudeDB: Float) async throws {
        let handle = try await play(frequency: frequency, velocity: velocity, amplitudeDB: amplitudeDB)
        try await Task.sleep(for: .seconds(duration))
        try await handle.stop()
    }
}
```

**Design rationale:**

- **PlaybackHandle makes note ownership explicit.** The caller that starts a note controls that specific note's lifecycle. No ambient "stop whatever is playing" on the player.
- **`stop()` removed from NotePlayer.** Stopping is always done through the handle. Sessions hold a `currentHandle: PlaybackHandle?` for interruption cleanup.
- **Fixed-duration convenience method preserved.** Existing comparison training call sites continue to work via the default protocol extension. The handle-returning method is the primitive; the duration method is syntactic sugar.
- **`adjustFrequency()` takes absolute Hz.** The caller doesn't need to know about MIDI pitch bend internals. The `SoundFontPlaybackHandle` tracks the base MIDI note and computes the relative pitch bend to reach the target frequency. The ±100 cent offset fits within the standard ±2-semitone (±200 cent) pitch bend range.
- **`play()` is `async throws` for setup, not duration.** It returns as soon as the note is audibly playing. The `async` covers engine start and preset loading.
- **No deinit safety on PlaybackHandle for v0.2.** All code paths explicitly stop notes (session stop, interruption handling). Auto-stop on deallocation can be added later if orphaned notes become an issue.

**`PlaybackHandle` is a protocol** for testability. `SoundFontNotePlayer` returns `SoundFontPlaybackHandle`; `MockNotePlayer` returns `MockPlaybackHandle`.

**Impact on PitchComparisonSession (formerly TrainingSession):**

The comparison training loop continues to use the fixed-duration convenience method — no call-site changes required. The session holds `currentHandle: PlaybackHandle?` for interruption cleanup only when using the handle-returning method directly (e.g., for early termination on navigate-away). The `stop()` method calls `currentHandle?.stop()`.

### PitchMatchingSession State Machine

`PitchMatchingSession` is a new `@Observable final class` that orchestrates the pitch matching training loop. It follows the same patterns as `PitchComparisonSession` (error boundary, observer injection, environment injection) but with different state semantics.

**States:**

```swift
enum PitchMatchingSessionState {
    case idle               // Not started or stopped
    case playingReference   // Reference note playing; slider visible but disabled
    case playingTunable     // Tunable note playing indefinitely; slider active
    case showingFeedback    // Note stopped, result recorded, feedback displayed (~400ms)
}
```

**State transition flow:**

```
idle
  ↓ startPitchMatching()
playingReference (configured duration)
  ↓ reference note handle stops after duration
playingTunable (indefinite — auto-starts immediately)
  ↓ user releases slider → tunableHandle.stop(), result recorded
showingFeedback (~400ms)
  ↓ feedback timer expires
playingReference (next challenge, loop)

Any state → idle (via stop(), triggered by: navigate away, background, interruption)
```

**Interruption handling (stop()):**

When `stop()` is called from any state:
- `playingReference` → stop reference handle, transition to idle
- `playingTunable` → stop tunable handle, discard incomplete attempt, transition to idle
- `showingFeedback` → cancel feedback timer, transition to idle
- `idle` → no-op

The session holds `currentHandle: PlaybackHandle?` and `stop()` always calls `currentHandle?.stop()`.

**Dependencies:**

```swift
init(
    notePlayer: NotePlayer,
    profile: PitchMatchingProfile,
    observers: [PitchMatchingObserver] = [],
    settingsOverride: TrainingSettings? = nil,
    noteDurationOverride: TimeInterval? = nil,
    notificationCenter: NotificationCenter = .default
)
```

No `NextPitchComparisonStrategy` dependency — note selection is random for v0.2 (see Note Selection below).

**Service table (addition):**

| Component | Responsibility | MVP Implementation |
|---|---|---|
| `PitchMatchingSession` | State machine orchestrating the pitch matching loop. Coordinates `NotePlayer`, `PitchMatchingProfile`, and observers. Generates random challenges, manages indefinite playback, handles slider-driven frequency adjustment. The only component that knows a "pitch matching challenge" is a reference note followed by a tunable note. | Observable object observed by Pitch Matching Screen |

**Data flow:**

1. `PitchMatchingSession` generates a random challenge (note + offset)
2. Plays reference note via `NotePlayer` (fixed duration) using handle
3. Plays tunable note via `NotePlayer` (indefinite) using handle
4. Receives frequency updates from slider → `handle.adjustFrequency(newFreq)`
5. On slider release → `handle.stop()`, records result, notifies observers
6. Observers persist (`TrainingDataStore`) and update profile (`PerceptualProfile`)

### PitchMatchingRecord Data Model

New SwiftData `@Model` for recording pitch matching attempts:

```swift
@Model
final class PitchMatchingRecord {
    /// Reference note as MIDI number (0-127) — exact, no cent offset
    var referenceNote: Int

    /// Starting cent offset of the tunable note (±100 cents for v0.2)
    var initialCentOffset: Double

    /// Signed cent error: user's final pitch minus reference pitch.
    /// Positive = user was sharp, negative = user was flat.
    var userCentError: Double

    /// When the attempt was completed (slider released)
    var timestamp: Date
}
```

**Design notes:**
- `initialCentOffset` stored for future analysis (sharp vs. flat starting bias)
- `userCentError` is signed — enables directional analysis
- User's final absolute pitch is derivable: reference note frequency + `userCentError` cents
- Registered in `ModelContainer` schema in `PeachApp.swift`
- File location: `Core/Data/PitchMatchingRecord.swift`

### PitchMatchingObserver Pattern

Follows the same decoupled observer pattern as comparison training:

```swift
protocol PitchMatchingObserver {
    func pitchMatchingCompleted(_ result: CompletedPitchMatching)
}
```

**Value type:**

```swift
struct CompletedPitchMatching {
    let referenceNote: Int
    let initialCentOffset: Double
    let userCentError: Double
    let timestamp: Date
}
```

**Conforming types for v0.2:**
- `TrainingDataStore` — persists `PitchMatchingRecord` to SwiftData
- `PerceptualProfile` — updates matching statistics via `PitchMatchingProfile` protocol

**Not conforming (by design):**
- `HapticFeedbackManager` — no haptics for pitch matching (UX spec decision)

**File locations:** `PitchMatching/PitchMatchingObserver.swift`, `PitchMatching/CompletedPitchMatching.swift`

### Profile Protocol Split — PitchComparisonProfile & PitchMatchingProfile

The existing `PerceptualProfile` class is split into two protocols representing the two distinct skills being trained:

**PitchComparisonProfile** (existing behavior, extracted to protocol):

```swift
protocol PitchComparisonProfile: AnyObject {
    func update(note: Int, centOffset: Double, isCorrect: Bool)
    func weakSpots(count: Int) -> [Int]
    var overallMean: Double? { get }
    var overallStdDev: Double? { get }
    func statsForNote(_ note: Int) -> PerceptualNote
    func averageThreshold(noteRange: NoteRange) -> Int?
    func setDifficulty(note: Int, difficulty: Double)
    func reset()
}
```

**PitchMatchingProfile** (new):

```swift
protocol PitchMatchingProfile {
    /// Updates with a pitch matching result
    func updateMatching(note: Int, centError: Double)
    /// Overall mean absolute matching error (cents)
    var matchingMean: Double? { get }
    /// Overall standard deviation of matching error (cents)
    var matchingStdDev: Double? { get }
    /// Total pitch matching attempts
    var matchingSampleCount: Int { get }
    func resetMatching()
}
```

**`PerceptualProfile` conforms to both:**

```swift
@Observable
final class PerceptualProfile: PitchComparisonProfile, PitchMatchingProfile {
    // Existing: 128-slot noteStats array for pitch comparison
    // New: aggregate matching statistics (overall, not per-note for v0.2)
}
```

**v0.2 matching statistics:** Overall aggregates only (mean absolute error, standard deviation, sample count). Per-note matching breakdown deferred until data shows meaningful per-note variation. The protocol allows expansion.

**Dependency boundaries:**
- `PitchComparisonSession` depends on `PitchComparisonProfile`
- `PitchMatchingSession` depends on `PitchMatchingProfile`
- `NextPitchComparisonStrategy` depends on `PitchComparisonProfile`
- Profile Screen depends on both (shows pitch comparison visualization + matching stats)

**Loading on startup:** `PerceptualProfile` rebuilt from both `PitchComparisonRecord` (pitch comparison) and `PitchMatchingRecord` (matching) data on app startup.

**Observer conformance:** `PerceptualProfile` conforms to both `PitchComparisonObserver` and `PitchMatchingObserver`.

### TrainingDataStore Extension

Extend the existing `TrainingDataStore` with pitch matching CRUD. It remains the sole SwiftData accessor.

**New methods:**
- `save(_ record: PitchMatchingRecord) throws`
- `fetchAllPitchMatching() throws -> [PitchMatchingRecord]`
- `deleteAllPitchMatching() throws`

**Observer conformance:** `TrainingDataStore` conforms to `PitchMatchingObserver`, automatically persisting completed pitch matching attempts.

**Schema update:** Register `PitchMatchingRecord.self` in the `ModelContainer` schema in `PeachApp.swift`:

```swift
let container = try ModelContainer(for: PitchComparisonRecord.self, PitchMatchingRecord.self)
```

### Note Selection (v0.2)

No adaptive algorithm for pitch matching in v0.2. Selection is random:
- **Note:** Random MIDI note within the configured training range (from `TrainingSettings`)
- **Initial offset:** Random within ±100 cents (one semitone in either direction)
- **Slider starting position:** Always the same physical position regardless of offset

**Implementation:** Private method inside `PitchMatchingSession`. No protocol, no separate file, no abstraction. When adaptive matching is needed in the future, extract to a protocol then.

**Value type for a challenge:**

```swift
struct PitchMatchingChallenge {
    let referenceNote: Int        // MIDI note (0-127)
    let initialCentOffset: Double // Random ±100 cents
}
```

**File location:** `PitchMatching/PitchMatchingChallenge.swift`

### Updated Project Structure (v0.2)

```
Peach/
├── App/
│   ├── PeachApp.swift                    # Updated: wire PitchMatchingSession, register PitchMatchingRecord
│   ├── ContentView.swift                 # Updated: add pitch matching navigation
│   └── NavigationDestination.swift       # Updated: add .pitchMatching case
├── Core/
│   ├── Audio/
│   │   ├── NotePlayer.swift              # Updated: PlaybackHandle pattern
│   │   ├── PlaybackHandle.swift          # New: PlaybackHandle protocol
│   │   ├── SoundFontNotePlayer.swift     # Updated: returns SoundFontPlaybackHandle
│   │   ├── SoundFontPlaybackHandle.swift # New: PlaybackHandle implementation
│   │   ├── SoundFontLibrary.swift
│   │   ├── SF2PresetParser.swift
│   │   └── FrequencyCalculation.swift
│   ├── Algorithm/
│   │   ├── NextPitchComparisonStrategy.swift  # Renamed from NextNoteStrategy
│   │   ├── KazezNoteStrategy.swift
│   │   └── AdaptiveNoteStrategy.swift
│   ├── Data/
│   │   ├── PitchComparisonRecord.swift
│   │   ├── PitchMatchingRecord.swift     # New
│   │   ├── TrainingDataStore.swift       # Updated: pitch matching CRUD + PitchMatchingObserver
│   │   ├── PitchComparisonRecordStoring.swift
│   │   └── DataStoreError.swift
│   └── Profile/
│       ├── PerceptualProfile.swift           # Updated: conforms to both profile protocols
│       ├── PitchComparisonProfile.swift  # New: protocol extracted from PerceptualProfile
│       ├── PitchMatchingProfile.swift        # New: protocol for matching statistics
│       ├── TrendAnalyzer.swift
│       └── ThresholdTimeline.swift
├── PitchComparison/                           # Renamed from Training/
│   ├── PitchComparisonSession.swift           # Renamed from TrainingSession
│   ├── PitchComparisonScreen.swift            # Renamed from TrainingScreen
│   ├── PitchComparison.swift
│   ├── PitchComparisonObserver.swift
│   ├── HapticFeedbackManager.swift
│   ├── PitchComparisonFeedbackIndicator.swift # Renamed from FeedbackIndicator
│   └── DifficultyDisplayView.swift
├── PitchMatching/                        # New feature directory
│   ├── PitchMatchingSession.swift
│   ├── PitchMatchingScreen.swift
│   ├── PitchMatchingChallenge.swift
│   ├── CompletedPitchMatching.swift
│   ├── PitchMatchingObserver.swift
│   ├── PitchMatchingFeedbackIndicator.swift
│   └── VerticalPitchSlider.swift
├── Profile/
│   ├── ProfileScreen.swift               # Updated: shows both profile types
│   ├── PianoKeyboardView.swift
│   ├── SummaryStatisticsView.swift
│   └── ThresholdTimelineView.swift
├── Start/
│   ├── StartScreen.swift                 # Updated: add Pitch Matching button
│   └── ProfilePreviewView.swift
├── Settings/
│   ├── SettingsScreen.swift
│   └── SettingsKeys.swift
├── Info/
│   └── InfoScreen.swift
└── Resources/
    ├── Assets.xcassets
    └── Localizable.xcstrings
```

**Test structure mirrors source:**

```
PeachTests/
├── Core/
│   ├── Audio/
│   │   ├── SoundFontNotePlayerTests.swift    # Updated for PlaybackHandle
│   │   └── SoundFontPlaybackHandleTests.swift # New
│   ├── Algorithm/
│   │   └── ...
│   ├── Data/
│   │   └── TrainingDataStoreTests.swift      # Updated for pitch matching CRUD
│   └── Profile/
│       ├── PerceptualProfileTests.swift      # Updated for matching stats
│       └── ...
├── PitchComparison/                               # Renamed from Training/
│   └── PitchComparisonSessionTests.swift          # Renamed from TrainingSessionTests
├── PitchMatching/                            # New
│   └── PitchMatchingSessionTests.swift
└── Mocks/
    ├── MockNotePlayer.swift                  # Updated for PlaybackHandle
    ├── MockPlaybackHandle.swift              # New
    └── ...
```

### Updated Requirements to Structure Mapping (v0.2)

| FR Category | Component(s) | Directory |
|---|---|---|
| Training Loop (FR1–FR8) | `PitchComparisonSession`, `PitchComparisonScreen` | `PitchComparison/` |
| Pitch Matching (FR44–FR50a) | `PitchMatchingSession`, `PitchMatchingScreen` | `PitchMatching/` |
| Adaptive Algorithm (FR9–FR15) | `NextPitchComparisonStrategy`, `KazezNoteStrategy`, `PerceptualProfile` | `Core/Algorithm/`, `Core/Profile/` |
| Audio Engine (FR16–FR20, FR51–FR52) | `NotePlayer`, `PlaybackHandle`, `SoundFontNotePlayer`, `SoundFontPlaybackHandle` | `Core/Audio/` |
| Profile & Statistics (FR21–FR26) | `PerceptualProfile`, `ProfileScreen` | `Core/Profile/`, `Profile/` |
| Data Persistence (FR27–FR29, FR48) | `PitchComparisonRecord`, `PitchMatchingRecord`, `TrainingDataStore` | `Core/Data/` |
| Settings (FR30–FR36) | `SettingsScreen`, `@AppStorage` | `Settings/` |
| Localization (FR37–FR38) | `Localizable.xcstrings` | `Resources/` |
| Device & Platform (FR39–FR42) | All screens (responsive layouts) | All feature directories |
| Info Screen (FR43) | `InfoScreen` | `Info/` |

### Updated Cross-Cutting Concerns (v0.2)

| Concern | Affected Components | Resolution |
|---|---|---|
| Audio interruption (comparison) | `SoundFontNotePlayer`, `PitchComparisonSession` | `PlaybackHandle` reports interruption → `PitchComparisonSession` discards current comparison |
| Audio interruption (pitch matching) | `SoundFontNotePlayer`, `PitchMatchingSession` | `PlaybackHandle` reports interruption → `PitchMatchingSession` discards current attempt |
| Settings propagation | `SettingsScreen`, `PitchComparisonSession`, `PitchMatchingSession`, `NextPitchComparisonStrategy`, `NotePlayer` | Both sessions read `@AppStorage` when starting next challenge; `NotePlayer` reads `soundSource` on each `play()` call |
| Data integrity | `TrainingDataStore` | SwiftData atomic writes; sessions write only complete results |
| App lifecycle | `PeachApp`, `PitchComparisonSession`, `PitchMatchingSession` | Backgrounding → active session stops; foregrounding → returns to Start Screen |
| Note ownership | `PitchComparisonSession`, `PitchMatchingSession` | PlaybackHandle pattern ensures every started note has an explicit owner responsible for stopping it |

### v0.2 Implementation Sequence

1. **Prerequisite renames** (no functional changes — pure refactoring)
2. **PlaybackHandle protocol + NotePlayer redesign** (refactors audio layer and PitchComparisonSession)
3. **PitchMatchingRecord + TrainingDataStore extension** (data layer)
4. **Profile protocol split** (PitchComparisonProfile + PitchMatchingProfile)
5. **PitchMatchingSession** (state machine, integrates NotePlayer + observers + profile)
6. **PitchMatchingScreen + custom components** (VerticalPitchSlider, PitchMatchingFeedbackIndicator)
7. **Start Screen integration + navigation** (Pitch Matching button, routing)
8. **Profile Screen integration** (display matching statistics alongside pitch comparison profile)

### v0.2 Architecture Validation

**Decision Compatibility:** All v0.2 additions use the same first-party Apple frameworks. PlaybackHandle is a protocol-level change with no new dependencies. PitchMatchingRecord integrates into the existing SwiftData container.

**Pattern Consistency:** PitchMatchingSession follows the same patterns as PitchComparisonSession (observable, error boundary, observer injection, environment injection). Profile protocols follow protocol-first design. PlaybackHandle follows the existing protocol-based testability pattern.

**Backward Compatibility:** The fixed-duration `play()` convenience method in the NotePlayer protocol extension preserves existing call semantics. Pitch comparison training is functionally unchanged after renames.

**Requirements Coverage:** All new FRs (FR44–FR52) mapped to specific components and directories.

**Gap Analysis:** No critical gaps. Profile Screen UX design for matching statistics is noted as pending — the architecture supports it, but the visual design needs a separate UX workflow.

## v0.3 Architecture Amendment — Interval Training

*Amended: 2026-02-28*

This amendment extends the architecture to support Interval Training (v0.3), which generalizes both existing training modes from unison to musical intervals. It also documents prerequisite refactorings to enrich domain types and unify naming before adding interval support.

**Input documents for this amendment:**
- PRD v0.3 additions (FR53–FR67, User Journeys 7–8)
- UX Design Specification v0.3 amendment
- UX Design Validation Report (2026-02-28)
- PRD Validation Report (2026-02-28)
- Existing codebase analysis

### Central Design Principle

FR66 states: *"Unison comparison and unison pitch matching behave identically to their interval variants with the interval fixed to prime (unison)."* This drives every decision in this amendment: unison is the prime case, not a separate concept. Existing sessions, screens, and data models are generalized — not duplicated — to support intervals.

### Prerequisite Refactorings

Before implementing interval training, several refactorings are required to enrich domain types, unify naming, and decouple dependencies.

#### A. New Domain Types — Interval, TuningSystem, Pitch

Three new value types in `Core/Audio/`:

**Interval** (FR53):

```swift
enum Interval: Int, Hashable, Sendable, CaseIterable, Codable {
    case prime = 0
    case minorSecond = 1
    case majorSecond = 2
    case minorThird = 3
    case majorThird = 4
    case perfectFourth = 5
    case tritone = 6
    case perfectFifth = 7
    case minorSixth = 8
    case majorSixth = 9
    case minorSeventh = 10
    case majorSeventh = 11
    case octave = 12

    var semitones: Int { rawValue }
}
```

`Interval` is an enum because the domain is well-bounded (Prime through Octave, per PRD). `Int` raw value gives free `Codable`, `Comparable`, and the semitone count. No direction (up/down) modeled for v0.3 — the interval is always "up." Direction is deferred to when the PRD adds directional interval selection.

**Static factory — deriving interval from two notes:**

```swift
extension Interval {
    /// Returns the interval between two MIDI notes.
    /// Throws if the semitone distance is outside Prime–Octave range.
    static func between(_ reference: MIDINote, _ target: MIDINote) throws -> Interval
}
```

**TuningSystem** (FR54–FR55):

```swift
enum TuningSystem: Hashable, Sendable, CaseIterable, Codable {
    case equalTemperament
    // Future: case justIntonation, case pythagorean

    /// Cent offset from the root for a given interval.
    func centOffset(for interval: Interval) -> Double {
        switch self {
        case .equalTemperament:
            return Double(interval.semitones) * 100.0
        }
    }
}
```

`TuningSystem` is an enum (not a protocol) to support a future Settings picker. FR55 requires that adding a new tuning system requires no changes to interval or training logic — adding a case to this enum and implementing its `centOffset` method satisfies that.

**Pitch** — a MIDI note with cent offset:

```swift
struct Pitch: Hashable, Sendable {
    let note: MIDINote
    let cents: Cents  // offset from the exact MIDI note frequency

    func frequency(referencePitch: Frequency = .concert440) -> Frequency
}
```

`Pitch` is a resolved representation of a specific point in pitch space. By the time a `Pitch` exists, any tuning system computation has already been applied — the cent offset is baked in. `Pitch.frequency(referencePitch:)` is pure math: `referencePitch × 2^((note - 69 + cents/100) / 12)`. No TuningSystem parameter needed at this level.

**MIDINote extensions:**

```swift
extension MIDINote {
    /// Semitone transposition — returns the MIDI note at the given interval.
    func transposed(by interval: Interval) -> MIDINote

    /// Exact pitch for an interval in a given tuning system.
    /// For 12-TET, cents is always 0. For other systems, cents captures the deviation
    /// from the nearest MIDI note (e.g., Just Intonation P5 = MIDINote + ~1.955 cents).
    func pitch(
        at interval: Interval = .prime,
        in tuningSystem: TuningSystem = .equalTemperament
    ) -> Pitch
}
```

**Frequency static constant:**

```swift
extension Frequency {
    static let concert440 = Frequency(440.0)
}
```

**File locations:**
- `Core/Audio/Interval.swift`
- `Core/Audio/TuningSystem.swift`
- `Core/Audio/Pitch.swift`
- Extensions on `MIDINote` and `Frequency` in their existing files

#### B. NotePlayer Protocol — Takes Pitch

The current `NotePlayer` protocol takes `Frequency` (raw Hz). `SoundFontNotePlayer` internally converts Hz → MIDI note + pitch bend, which is its native domain. With the `Pitch` type, we eliminate this conversion at the protocol boundary:

**Current:**

```swift
protocol NotePlayer {
    func play(frequency: Frequency, velocity: MIDIVelocity, amplitudeDB: AmplitudeDB) async throws -> PlaybackHandle
    func play(frequency: Frequency, duration: TimeInterval, velocity: MIDIVelocity, amplitudeDB: AmplitudeDB) async throws
    func stopAll() async throws
}
```

**New:**

```swift
protocol NotePlayer {
    func play(pitch: Pitch, velocity: MIDIVelocity, amplitudeDB: AmplitudeDB) async throws -> PlaybackHandle
    func play(pitch: Pitch, duration: TimeInterval, velocity: MIDIVelocity, amplitudeDB: AmplitudeDB) async throws
    func stopAll() async throws
}
```

The default extension for fixed-duration playback is preserved, using `pitch:` instead of `frequency:`.

**SoundFontNotePlayer impact:** Receives `Pitch` (MIDINote + Cents) and maps directly to MIDI noteOn + pitch bend — its natural domain. The implementation details of this mapping (computing pitch bend range, channel management) stay encapsulated. The interface does not assume or constrain the implementation's internal representation.

**`PlaybackHandle.adjustFrequency` stays as `Frequency`.** Unlike `NotePlayer.play()`, which initiates a new note (where `Pitch` is the natural input), `adjustFrequency` shifts an already-playing note to an absolute frequency. The session computes the target frequency from a `Pitch` via `pitch.frequency(referencePitch:)` and passes the result to the handle. This keeps `PlaybackHandle` a low-level audio primitive.

**Design principle:** Interfaces must not assume the implementation's internal representation. `Pitch` is friendly to MIDI-based implementations (it IS a MIDI note + cent offset) but that's by design, not by coupling. A hypothetical future `SineWaveNotePlayer` would call `pitch.frequency(referencePitch:)` internally to get Hz.

#### C. FrequencyCalculation Migration

The standalone `FrequencyCalculation.swift` utility becomes redundant as its logic migrates to domain types:

| Current (FrequencyCalculation) | New location |
|---|---|
| `frequency(midiNote:cents:referencePitch:)` | `Pitch.frequency(referencePitch:)` and `MIDINote.frequency(referencePitch:)` |
| `midiNoteAndCents(frequency:referencePitch:)` | `Pitch.init(frequency:referencePitch:)` or static factory on `Pitch` |

`FrequencyCalculation.swift` is deleted after all call sites are migrated. The NFR for 0.1-cent precision is preserved in the domain type implementations.

#### D. Unified Reference/Target Naming

Across all training modes, the abstract concept is the same: a **reference note** (the anchor the system plays) and a **target note** (what the user judges against or tunes toward). Current naming is inconsistent:

| Current | New | Where |
|---|---|---|
| `note1` | `referenceNote` | `PitchComparisonRecord`, `PitchComparison`, `CompletedPitchComparison` |
| `note2` | `targetNote` | `PitchComparisonRecord`, `PitchComparison`, `CompletedPitchComparison` |
| `note2CentOffset` | `centOffset` | `PitchComparisonRecord` |
| `centDifference` | `centOffset` | `PitchComparison` |

**Rename scope:** Code files, class/struct/enum field names, all references in `PitchComparisonSession`, `NextPitchComparisonStrategy`, `KazezNoteStrategy`, `PitchComparisonObserver` conformances, `TrainingDataStore`, tests, and `docs/project-context.md`.

**Names that remain unchanged:**
- `PitchMatchingRecord.referenceNote` — already correct
- `PitchMatchingChallenge.referenceNote` — already correct
- `CompletedPitchMatching.referenceNote` — already correct

**Names that gain a field:**
- `PitchMatchingRecord` — gains `targetNote` (see Data Model section)
- `PitchMatchingChallenge` — gains `targetNote`
- `CompletedPitchMatching` — gains `targetNote`

#### E. SoundSourceProvider Protocol

`SettingsScreen` currently depends directly on `SoundFontLibrary`. This violates the dependency direction rule that feature directories must not couple to implementation-specific types. A protocol decouples them:

```swift
protocol SoundSourceProvider {
    var availableSources: [SoundSourceID] { get }
    func displayName(for source: SoundSourceID) -> String
}
```

`SoundFontLibrary` conforms to `SoundSourceProvider`. `SettingsScreen` depends on `SoundSourceProvider` via `@Environment`, not the concrete `SoundFontLibrary`.

**File location:** `Core/Audio/SoundSourceProvider.swift`

### Session Parameterization

Both `PitchComparisonSession` and `PitchMatchingSession` are parameterized with an interval set — not duplicated into separate interval session classes.

**Start methods renamed — intervals read from `userSettings`:**

```swift
// PitchComparisonSession + PitchMatchingSession (both conform to TrainingSession)
func start()  // reads intervals and tuningSystem from injected userSettings
```

`start()` reads `userSettings.intervals` (must be non-empty, enforced by precondition) and `userSettings.tuningSystem`, storing both for the duration of the training run. On each exercise, the session randomly selects one interval from the set.

**Start Screen usage:**
- "Pitch Comparison" → `session.start()` (userSettings has `[.prime]`)
- "Pitch Matching" → `session.start()` (userSettings has `[.prime]`)
- "Interval Pitch Comparison" → `session.start()` (userSettings has `[.perfectFifth]`)
- "Interval Pitch Matching" → `session.start()` (userSettings has `[.perfectFifth]`)

**Observable state for UI:**

```swift
// On both sessions
private(set) var currentInterval: Interval = .prime
var isIntervalMode: Bool { currentInterval != .prime }
```

`currentInterval` updates each exercise. The screen conditionally shows the target interval label based on `isIntervalMode`.

**What stays unchanged:**
- One `PitchComparisonSession` instance, one `PitchMatchingSession` instance in PeachApp
- `activeSession` tracking (only one active at a time)
- Observer pattern — observers notified the same way
- Feedback timing (0.4s), haptic behavior, interruption handling — all identical

### NextPitchComparisonStrategy Update

The strategy protocol gains interval and tuning system parameters:

```swift
protocol NextPitchComparisonStrategy {
    func nextPitchComparison(
        profile: PitchComparisonProfile,
        settings: TrainingSettings,
        lastPitchComparison: CompletedPitchComparison?,
        interval: Interval,
        tuningSystem: TuningSystem
    ) -> PitchComparison
}
```

The strategy selects a reference note and difficulty (cent offset magnitude) as before, then computes `targetNote = referenceNote.transposed(by: interval)`. For `.prime`, targetNote = referenceNote — identical to current behavior.

**MIDI range boundary:** `MIDINote.transposed(by:)` will crash if the result exceeds 0–127 (e.g., MIDINote(121) + perfect fifth = 128). The strategy must constrain its reference note selection range to `settings.noteRangeMin...(settings.noteRangeMax - interval.semitones)` to ensure the target note stays within valid MIDI range. For `.prime` (0 semitones), the constraint has no effect. For `.perfectFifth` (7 semitones), the upper bound shrinks by 7. `PitchMatchingSession` applies the same constraint when selecting random reference notes.

**PitchMatchingSession** challenge generation remains internal (random note selection, no strategy protocol). It computes the target from the selected interval:

```swift
let interval = intervals.randomElement()!  // safe — set is non-empty
let targetNote = referenceNote.transposed(by: interval)
let challenge = PitchMatchingChallenge(
    referenceNote: referenceNote,
    targetNote: targetNote,
    initialCentOffset: randomOffset
)
```

### Data Model Updates

#### PitchComparisonRecord

```swift
@Model
final class PitchComparisonRecord {
    var referenceNote: Int       // was note1
    var targetNote: Int          // was note2
    var centOffset: Double       // was note2CentOffset
    var isCorrect: Bool
    var timestamp: Date
    var tuningSystem: TuningSystem = .equalTemperament  // NEW
}
```

No `targetInterval` field — the interval is derived from the two notes via `Interval.between(MIDINote(referenceNote), MIDINote(targetNote))`. For unison, referenceNote = targetNote → interval is `.prime`.

**SwiftData migration:** The property renames (`note1`→`referenceNote`, `note2`→`targetNote`, `note2CentOffset`→`centOffset`) plus the new `tuningSystem` field constitute a schema change. SwiftData treats property renames as "delete old column + add new column," which drops existing data for those columns. This is acceptable — there is no production user base yet. No `SchemaMigrationPlan` needed; the schema changes are applied as a fresh model version.

#### PitchMatchingRecord

```swift
@Model
final class PitchMatchingRecord {
    var referenceNote: Int
    var targetNote: Int             // NEW — what the user was trying to match
    var initialCentOffset: Double   // offset from target pitch
    var userCentError: Double       // final error from target pitch
    var timestamp: Date
    var tuningSystem: TuningSystem = .equalTemperament  // NEW
}
```

**SwiftData migration:** Adding `targetNote` and `tuningSystem` alongside existing fields is a schema change. As with `PitchComparisonRecord`, there is no production user base yet — existing data loss from schema changes is acceptable. No `SchemaMigrationPlan` needed.

#### Value Types

**PitchComparison** (updated):

```swift
struct PitchComparison {
    let referenceNote: MIDINote  // was note1
    let targetNote: MIDINote     // was note2
    let centOffset: Cents        // was centDifference — offset from correct target pitch
}
```

**CompletedPitchComparison** (updated):

```swift
struct CompletedPitchComparison {
    let pitchComparison: PitchComparison
    let userAnsweredHigher: Bool
    let tuningSystem: TuningSystem    // NEW — recorded for data integrity
    let timestamp: Date
}
```

`PitchComparisonSession` populates `tuningSystem` from its session-level parameter so that `TrainingDataStore` (as `PitchComparisonObserver`) can persist it to `PitchComparisonRecord`.

**PitchMatchingChallenge** (updated):

```swift
struct PitchMatchingChallenge {
    let referenceNote: MIDINote
    let targetNote: MIDINote          // NEW
    let initialCentOffset: Double
}
```

**CompletedPitchMatching** (updated):

```swift
struct CompletedPitchMatching {
    let referenceNote: MIDINote
    let targetNote: MIDINote          // NEW
    let initialCentOffset: Double
    let userCentError: Double
    let tuningSystem: TuningSystem    // NEW — recorded for data integrity
    let timestamp: Date
}
```

### Navigation & Start Screen

**NavigationDestination** (updated):

```swift
enum NavigationDestination: Hashable {
    case pitchComparison(intervals: Set<Interval>)   // renamed from .training
    case pitchMatching(intervals: Set<Interval>)
    case settings
    case profile
}
```

No separate interval cases. The interval set is a parameter — FR66 (unison = prime case) is reflected in the navigation model. Renaming `.training` → `.pitchComparison` aligns with the v0.2 session/screen renames.

**Start Screen routing — four buttons, two screens:**

```swift
// Unison modes
NavigationLink(value: .pitchComparison(intervals: [.prime]))       { Text("Pitch Comparison") }
NavigationLink(value: .pitchMatching(intervals: [.prime]))    { Text("Pitch Matching") }

// Visual separator

// Interval modes
NavigationLink(value: .pitchComparison(intervals: [.perfectFifth]))    { Text("Interval Pitch Comparison") }
NavigationLink(value: .pitchMatching(intervals: [.perfectFifth])) { Text("Interval Pitch Matching") }
```

**Button styling** (per UX spec):
- "Pitch Comparison" — `.borderedProminent` (hero action, unchanged)
- "Pitch Matching" — `.bordered`
- "Interval Pitch Comparison" — `.bordered`
- "Interval Pitch Matching" — `.bordered`

Subtle visual separator (spacing or divider) between unison and interval groups.

**Destination handler** passes intervals to the screen, which passes them to the session's start method:

```swift
.navigationDestination(for: NavigationDestination.self) { destination in
    switch destination {
    case .pitchComparison(let intervals):
        PitchComparisonScreen(intervals: intervals)
    case .pitchMatching(let intervals):
        PitchMatchingScreen(intervals: intervals)
    case .settings:
        SettingsScreen()
    case .profile:
        ProfileScreen()
    }
}
```

**Target Interval Label** — a conditional `Text` view at the top of both training screens:
- Visible when `session.isIntervalMode` is true — shows `currentInterval` display name (e.g., "Perfect Fifth Up")
- Hidden when `session.isIntervalMode` is false — screen looks exactly as pre-v0.3
- Standard SwiftUI `Text` with `.headline` or `.title3` styling
- Automatic VoiceOver and Dynamic Type support

### Profile Impact

Record everything, defer computation changes. For v0.3:
- Interval comparison results flow through the same `PitchComparisonObserver` path
- Interval pitch matching results flow through the same `PitchMatchingObserver` path
- Profiles receive all data regardless of interval — no filtering, no interval-aware aggregation
- All records carry full context (referenceNote, targetNote, tuningSystem) so future profile work has solid data to work with
- No changes to `PitchComparisonProfile` or `PitchMatchingProfile` protocols or computation

### Updated Project Structure (v0.3)

```
Peach/
├── App/
│   ├── PeachApp.swift                    # Updated: SoundSourceProvider wiring
│   ├── ContentView.swift                 # Updated: .pitchComparison/.pitchMatching destinations
│   ├── NavigationDestination.swift       # Updated: parameterized with intervals
│   └── EnvironmentKeys.swift             # Updated: SoundSourceProvider entry
├── Core/
│   ├── Audio/
│   │   ├── NotePlayer.swift              # Updated: takes Pitch instead of Frequency
│   │   ├── PlaybackHandle.swift
│   │   ├── Pitch.swift                   # NEW: MIDINote + Cents value type
│   │   ├── Interval.swift                # NEW: Prime through Octave enum
│   │   ├── TuningSystem.swift            # NEW: 12-TET enum
│   │   ├── SoundSourceProvider.swift     # NEW: protocol for SettingsScreen decoupling
│   │   ├── SoundFontNotePlayer.swift     # Updated: receives Pitch, maps to MIDI + pitch bend
│   │   ├── SoundFontPlaybackHandle.swift
│   │   ├── SoundFontLibrary.swift        # Updated: conforms to SoundSourceProvider
│   │   ├── SF2PresetParser.swift
│   │   ├── MIDINote.swift                # Updated: transposed(by:), pitch(at:in:), frequency uses Pitch
│   │   ├── Frequency.swift               # Updated: .concert440 constant
│   │   ├── Cents.swift
│   │   ├── MIDIVelocity.swift
│   │   ├── AmplitudeDB.swift
│   │   ├── NoteDuration.swift
│   │   ├── SoundSourceID.swift
│   │   └── AudioSessionInterruptionMonitor.swift
│   ├── Algorithm/
│   │   ├── NextPitchComparisonStrategy.swift  # Updated: interval + tuningSystem parameters
│   │   └── KazezNoteStrategy.swift       # Updated: computes targetNote from interval
│   ├── Data/
│   │   ├── PitchComparisonRecord.swift        # Updated: renamed fields, tuningSystem
│   │   ├── PitchMatchingRecord.swift     # Updated: targetNote, tuningSystem
│   │   ├── PitchComparisonRecordStoring.swift
│   │   ├── DataStoreError.swift
│   │   └── TrainingDataStore.swift       # Updated: renamed fields in queries/saves
│   ├── Profile/
│   │   ├── PerceptualProfile.swift       # Updated: handles renamed fields
│   │   ├── PitchComparisonProfile.swift
│   │   ├── PitchMatchingProfile.swift
│   │   ├── TrendAnalyzer.swift
│   │   └── ThresholdTimeline.swift
│   ├── Training/
│   │   ├── PitchComparison.swift              # Updated: referenceNote, targetNote, centOffset
│   │   ├── PitchComparisonObserver.swift
│   │   ├── CompletedPitchMatching.swift  # Updated: targetNote, tuningSystem
│   │   ├── PitchMatchingObserver.swift
│   │   └── Resettable.swift
│   ├── TrainingSession.swift
│   ├── Comparable+Clamped.swift
│   └── UnitInterval.swift
├── PitchComparison/
│   ├── PitchComparisonSession.swift           # Updated: intervals + tuningSystem params, currentInterval
│   ├── PitchComparisonScreen.swift            # Updated: receives intervals, shows interval label
│   ├── PitchComparisonFeedbackIndicator.swift
│   ├── DifficultyDisplayView.swift
│   └── HapticFeedbackManager.swift
├── PitchMatching/
│   ├── PitchMatchingSession.swift        # Updated: intervals + tuningSystem params, currentInterval
│   ├── PitchMatchingScreen.swift         # Updated: receives intervals, shows interval label
│   ├── PitchMatchingChallenge.swift      # Updated: targetNote
│   ├── PitchMatchingFeedbackIndicator.swift
│   └── VerticalPitchSlider.swift
├── Profile/
│   ├── ProfileScreen.swift
│   ├── PianoKeyboardView.swift
│   ├── SummaryStatisticsView.swift
│   ├── MatchingStatisticsView.swift
│   └── ThresholdTimelineView.swift
├── Start/
│   ├── StartScreen.swift                 # Updated: 4 buttons with interval sets
│   └── ProfilePreviewView.swift
├── Settings/
│   ├── SettingsScreen.swift              # Updated: depends on SoundSourceProvider, not SoundFontLibrary
│   ├── SettingsKeys.swift
│   ├── AppUserSettings.swift
│   └── UserSettings.swift
├── Info/
│   └── InfoScreen.swift
└── Resources/
    ├── Assets.xcassets
    └── Localizable.xcstrings

DELETED:
├── Core/Audio/FrequencyCalculation.swift  # Logic migrated to Pitch, MIDINote domain methods
```

**Test structure mirrors source — new test files:**

```
PeachTests/
├── Core/Audio/
│   ├── IntervalTests.swift               # NEW
│   ├── TuningSystemTests.swift           # NEW
│   ├── PitchTests.swift                  # NEW
│   ├── SoundFontNotePlayerTests.swift    # Updated for Pitch
│   └── MIDINoteTests.swift               # Updated: transposed(by:), pitch(at:in:)
├── PitchComparison/
│   └── PitchComparisonSessionTests.swift      # Updated: interval parameterization
├── PitchMatching/
│   └── PitchMatchingSessionTests.swift   # Updated: interval parameterization
└── Mocks/
    ├── MockNotePlayer.swift              # Updated for Pitch
    └── ...
```

### Updated Requirements to Structure Mapping (v0.3)

| FR Category | Component(s) | Directory |
|---|---|---|
| Training Loop (FR1–FR8) | `PitchComparisonSession`, `PitchComparisonScreen` | `PitchComparison/` |
| Pitch Matching (FR44–FR50a) | `PitchMatchingSession`, `PitchMatchingScreen` | `PitchMatching/` |
| Interval Domain (FR53–FR55) | `Interval`, `TuningSystem`, `Pitch` | `Core/Audio/` |
| Interval Pitch Comparison (FR56–FR59) | `PitchComparisonSession` (parameterized), `PitchComparisonScreen`, `NextPitchComparisonStrategy` | `PitchComparison/`, `Core/Algorithm/` |
| Interval Pitch Matching (FR60–FR64) | `PitchMatchingSession` (parameterized), `PitchMatchingScreen` | `PitchMatching/` |
| Start Screen Integration (FR65–FR66) | `StartScreen`, `NavigationDestination` | `Start/`, `App/` |
| Fixed Interval Scope (FR67) | Hardcoded `[.perfectFifth]` in Start Screen navigation links | `Start/` |
| Adaptive Algorithm (FR9–FR15) | `NextPitchComparisonStrategy`, `KazezNoteStrategy`, `PerceptualProfile` | `Core/Algorithm/`, `Core/Profile/` |
| Audio Engine (FR16–FR20, FR51–FR52) | `NotePlayer`, `PlaybackHandle`, `SoundFontNotePlayer` | `Core/Audio/` |
| Profile & Statistics (FR21–FR26) | `PerceptualProfile`, `ProfileScreen` | `Core/Profile/`, `Profile/` |
| Data Persistence (FR27–FR29, FR48, FR64) | `PitchComparisonRecord`, `PitchMatchingRecord`, `TrainingDataStore` | `Core/Data/` |
| Settings (FR30–FR36) | `SettingsScreen`, `SoundSourceProvider`, `@AppStorage` | `Settings/`, `Core/Audio/` |
| Localization (FR37–FR38) | `Localizable.xcstrings` | `Resources/` |
| Device & Platform (FR39–FR42) | All screens (responsive layouts) | All feature directories |
| Info Screen (FR43) | `InfoScreen` | `Info/` |

### Updated Cross-Cutting Concerns (v0.3)

| Concern | Affected Components | Resolution |
|---|---|---|
| Audio interruption (comparison) | `SoundFontNotePlayer`, `PitchComparisonSession` | PlaybackHandle reports interruption → session discards current comparison (same as v0.2) |
| Audio interruption (pitch matching) | `SoundFontNotePlayer`, `PitchMatchingSession` | PlaybackHandle reports interruption → session discards current attempt (same as v0.2) |
| Settings propagation | `SettingsScreen`, `PitchComparisonSession`, `PitchMatchingSession`, `NextPitchComparisonStrategy`, `NotePlayer` | Both sessions read `@AppStorage` when starting next challenge (same as v0.2) |
| Data integrity | `TrainingDataStore` | SwiftData atomic writes; sessions write only complete results with full context (reference, target, tuningSystem) |
| App lifecycle | `PeachApp`, `PitchComparisonSession`, `PitchMatchingSession` | Backgrounding → active session stops; foregrounding → returns to Start Screen (same as v0.2) |
| Note ownership | `PitchComparisonSession`, `PitchMatchingSession` | PlaybackHandle pattern ensures every started note has an explicit owner (same as v0.2) |
| Interval consistency | `PitchComparisonSession`, `PitchMatchingSession`, `NextPitchComparisonStrategy` | Interval and tuning system are set once per training run; all exercises in a run use the same set |
| Tuning system precision (NFR) | `TuningSystem`, `Pitch`, `MIDINote` | Interval frequency computations accurate to 0.1 cent; precision preserved from `FrequencyCalculation` |
| Sound source decoupling | `SettingsScreen`, `SoundSourceProvider`, `SoundFontLibrary` | SettingsScreen depends on protocol, not concrete library |

### v0.3 Implementation Sequence

1. **New domain types** — `Interval`, `TuningSystem`, `Pitch` with full test coverage (no dependencies on existing code)
2. **MIDINote extensions** — `transposed(by:)`, `pitch(at:in:)`, `frequency` updated to use `Pitch` internally
3. **FrequencyCalculation migration** — move logic to domain types, update all call sites, delete `FrequencyCalculation.swift`
4. **Prerequisite renames** — `note1`→`referenceNote`, `note2`→`targetNote`, `note2CentOffset`→`centOffset`, `.training`→`.pitchComparison`
5. **NotePlayer protocol change** — `Frequency` → `Pitch`, update `SoundFontNotePlayer` and all call sites
6. **SoundSourceProvider protocol** — extract from `SoundFontLibrary`, update `SettingsScreen`
7. **Data model updates** — add `targetNote` and `tuningSystem` fields to records, SwiftData migration
8. **Value type updates** — `PitchComparison`, `CompletedPitchComparison`, `PitchMatchingChallenge`, `CompletedPitchMatching` gain target/tuning fields
9. **Session parameterization** — `start()` reads `intervals` and `tuningSystem` from `userSettings`; `currentInterval` observable state
10. **NextPitchComparisonStrategy update** — receives `interval`, computes `targetNote`
11. **NavigationDestination update** — parameterized with `intervals: Set<Interval>`
12. **Start Screen update** — four buttons with visual separator, interval sets
13. **Training screen updates** — conditional target interval label on `PitchComparisonScreen` and `PitchMatchingScreen`
14. **Observer/profile pass-through** — verify PitchComparisonObserver and PitchMatchingObserver handle updated value types

### v0.3 Architecture Validation

**Decision Compatibility:** All v0.3 additions use the same first-party Apple frameworks. `Interval`, `TuningSystem`, and `Pitch` are pure Swift value types with no dependencies. `NotePlayer` protocol change is internal to the app module. No new third-party dependencies.

**Pattern Consistency:** `Interval` and `TuningSystem` follow existing value type patterns (`MIDINote`, `Cents`, `Frequency`). Session parameterization follows existing patterns (sessions already accept configuration via init/start parameters). `SoundSourceProvider` follows the protocol-first pattern used throughout (`NotePlayer`, `NextPitchComparisonStrategy`, `PitchComparisonProfile`).

**FR66 Compliance:** Unison modes use the same code paths as interval modes with `intervals: [.prime]`. No code duplication, no conditional branching based on "is this interval mode" — the prime case flows through the same generalized logic.

**Backward Compatibility:** Existing data migrates cleanly — `targetNote` defaults to `referenceNote` (unison), `tuningSystem` defaults to `.equalTemperament`. `NavigationDestination.pitchComparison(intervals: [.prime])` replaces `.training` with the same behavior. The NotePlayer protocol change requires updating all call sites but preserves the same semantics.

**Requirements Coverage:** All 15 new FRs (FR53–FR67) mapped to specific components. All prerequisite refactorings have clear scope and rationale. NFR for tuning system precision (0.1 cent) preserved through domain type migration.

**Gap Analysis:** No critical gaps. Profile computation for interval-specific statistics is explicitly deferred — the data foundation is in place for future work.

## Code Review Amendment — Domain Type Strengthening and Progress Tracking

*Amended: 2026-03-06*

This amendment documents architectural refinements identified during a comprehensive code review. No new features — these are structural improvements to type safety, constant management, logging, and progress tracking.

### Domain Type Threading

Raw `Double`/`Int`/`TimeInterval` values have been replaced with domain types at all public API boundaries:

| Interface | Before | After |
|---|---|---|
| `PitchComparisonProfile` methods | `Double` for cent values | `Cents` |
| `PitchMatchingProfile` methods | `Double` for cent values | `Cents` |
| `CompletedPitchMatching` fields | `Double` for offsets/errors | `Cents` |
| `PitchMatchingChallenge.initialCentOffset` | `Double` | `Cents` |
| Session `sessionBestCentError` | `Double` | `Cents` |
| Session `referenceFrequency` | `Double` | `Frequency` |
| Session `feedbackDuration` | `TimeInterval` | `Duration` |
| `TrainingStatsView` metric values | `Double` | `Cents` |

**Deliberate exceptions** (raw types preserved):
- `PerceptualNote` internals — Welford's algorithm arithmetic would be noisy with `Cents` wrappers
- Persistence records (`PitchComparisonRecord`, `PitchMatchingRecord`) — SwiftData boundary uses raw `Double`/`Int`
- `NotePlayer.play(duration:)` — stays `TimeInterval`; `NoteDuration` clamps to 0.3-3.0 which breaks test values

### Constant Extraction

Magic numbers have been extracted to named constants:

| Constant | Location | Value |
|---|---|---|
| `Cents.perOctave` | `Cents.swift` | `1200.0` |
| `SoundFontNotePlayer.pitchBendRangeSemitones` | `SoundFontNotePlayer.swift` | `2` |
| `SoundFontNotePlayer.pitchBendRangeCents` | `SoundFontNotePlayer.swift` | `200.0` |
| `TrainingConstants.feedbackDuration` | `TrainingConstants.swift` | `.milliseconds(400)` |
| `TrainingConstants.defaultNoteVelocity` | `TrainingConstants.swift` | `MIDIVelocity(63)` |
| `TrainingConstants.defaultAmplitudeDB` | `TrainingConstants.swift` | `AmplitudeDB(0.0)` |
| `TrainingModeConfig.defaultEWMAHalflife` | `TrainingModeConfig.swift` | `.seconds(7 * 86400)` |
| `TrainingModeConfig.defaultSessionGap` | `TrainingModeConfig.swift` | `.seconds(1800)` |
| `ProgressTimeline` bucket thresholds | `ProgressTimeline.swift` | Named constants |
| `KazezNoteStrategy` coefficients | `KazezNoteStrategy.swift` | Named via `KazezConfiguration` |

### Training Modes and Progress Tracking

Four training modes are now formally tracked:

```
enum TrainingMode: CaseIterable {
    case unisonPitchComparison
    case intervalPitchComparison
    case unisonMatching
    case intervalMatching
}
```

Each mode has a `TrainingModeConfig` with independent parameters for:
- Display name and unit label
- Optimal baseline (expert-level target)
- EWMA half-life for smoothing
- Session gap for bucket grouping

`ProgressTimeline` tracks all four modes independently, conforms to both observer protocols, and provides trend analysis per mode. It is injected as an observer into both sessions and as an `@Environment` dependency for profile views.

### Logging Standards

- `TrainingDataStore` migrated from `print()` to `os.Logger` at `.warning` level for save errors
- `PitchMatchingSession` and `PitchComparisonSession` use `os.Logger` for lifecycle events
- `PeachApp` uses `os.Logger` for startup timing
- `bin/check-dependencies.sh` now enforces: no `print()` calls in production code

### Updated Service Table

| Component | Responsibility |
|---|---|
| `TrainingConstants` | Shared configuration constants used by both sessions: feedback duration, default velocity, default amplitude |
| `TrainingModeConfig` | Per-mode configuration for progress tracking: display names, EWMA parameters, baselines |
| `ProgressTimeline` | Progress tracking across four training modes with EWMA smoothing, adaptive bucketing, and trend analysis. Conforms to both observer protocols |
| `DirectedInterval` | Value type combining `Interval` + `Direction` (up/down) for settings and session parameterization |
