---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
lastStep: 8
status: 'complete'
completedAt: '2026-02-12'
inputDocuments: ['docs/planning-artifacts/prd.md', 'docs/planning-artifacts/glossary.md', 'docs/brainstorming/brainstorming-session-2026-02-11.md']
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

**Comparison Record Model:**
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
| `PerceptualProfile` | In-memory aggregate of the user's pitch discrimination ability, indexed by MIDI note (0–127). Each slot holds aggregate statistics (arithmetic mean, standard deviation of detection thresholds). Serves as the basis for identifying weak spots. | Loaded from all comparisons on app startup; updated incrementally on each new answer. |
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
- Types & protocols: `PascalCase` — `TrainingSession`, `ComparisonRecord`, `NotePlayer`
- Properties, methods, parameters: `camelCase` — `isCorrect`, `playNote(frequency:)`, `detectionThreshold`
- Protocols: noun describing capability — `NotePlayer`, `NextNoteStrategy` (not `NotePlayable`, `NoteStrategyProtocol`)
- Protocol implementations: descriptive prefix — `SoundFontNotePlayer`, `AdaptiveNoteStrategy`
- SwiftData models: singular noun — `ComparisonRecord`, not `ComparisonRecords`
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
│   │   ├── ComparisonRecord.swift    # SwiftData model
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
│   │   ├── NextNoteStrategy.swift        # Protocol: nextComparison(profile:, settings:) -> Comparison
│   │   └── AdaptiveNoteStrategy.swift    # Weak-spot targeting, difficulty adjustment
│   ├── Data/
│   │   ├── ComparisonRecord.swift        # SwiftData @Model
│   │   └── TrainingDataStore.swift       # CRUD operations on ComparisonRecord
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
- `NextNoteStrategy` — knows about the perceptual profile and settings. Returns a `Comparison` value type (note1, note2, centDifference). Has no concept of audio playback or UI. Boundary: reads profile, produces comparison.
- `TrainingDataStore` — pure persistence. Stores and retrieves `ComparisonRecord` models. No computation, no aggregation. Boundary: SwiftData CRUD only.
- `PerceptualProfile` — pure computation. Aggregates comparison data into per-MIDI-note statistics. No persistence, no UI awareness. Boundary: receives comparison results, exposes detection thresholds.
- `TrainingSession` — the only component that crosses boundaries. Orchestrates the above four services. Boundary: the integration layer.

**UI Boundaries:**
- Views observe `TrainingSession` and `PerceptualProfile` — they never call services directly
- Views send user actions to `TrainingSession` (start, answer); stopping is triggered by navigation away or app backgrounding
- Settings Screen writes to `@AppStorage` — `TrainingSession` reads settings when selecting next comparison
- No view-to-view communication — all state flows through services

**Data Boundaries:**
- SwiftData `ModelContainer` initialized in `PeachApp.swift`, passed via SwiftUI environment
- `TrainingDataStore` is the sole accessor of `ComparisonRecord` — no other component queries SwiftData directly
- `PerceptualProfile` receives data from `TrainingDataStore` at startup and incremental updates from `TrainingSession` during training

### Requirements to Structure Mapping

| FR Category | Component(s) | Directory |
|---|---|---|
| Training Loop (FR1–FR8) | `TrainingSession`, `TrainingScreen` | `Training/` |
| Adaptive Algorithm (FR9–FR15) | `NextNoteStrategy`, `AdaptiveNoteStrategy`, `PerceptualProfile` | `Core/Algorithm/`, `Core/Profile/` |
| Audio Engine (FR16–FR20) | `NotePlayer`, `SoundFontNotePlayer` | `Core/Audio/` |
| Profile & Statistics (FR21–FR26) | `PerceptualProfile`, `ProfileScreen` | `Core/Profile/`, `Profile/` |
| Data Persistence (FR27–FR29) | `ComparisonRecord`, `TrainingDataStore` | `Core/Data/` |
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
- iCloud sync will require SwiftData CloudKit integration — may affect `TrainingDataStore` and `ComparisonRecord`
- Swappable sound sources already supported by `NotePlayer` protocol — just add new implementations
- Profile caching/snapshots for temporal progress visualization if performance demands it

### Implementation Handoff

**AI Agent Guidelines:**
- Follow all architectural decisions exactly as documented
- Use implementation patterns consistently across all components
- Respect project structure and boundaries
- Refer to this document for all architectural questions

**First Implementation Priority:**
Create Xcode 26.3 project → iOS → App → SwiftUI lifecycle, Swift language, SwiftData storage. Establish folder structure as defined. Then begin with `ComparisonRecord` + `TrainingDataStore` (the data foundation everything depends on).
