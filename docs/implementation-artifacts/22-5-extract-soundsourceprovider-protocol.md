# Story 22.5: Extract SoundSourceProvider Protocol

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer building interval training**,
I want a `SoundSourceProvider` protocol extracted from `SoundFontLibrary` so that `SettingsScreen` depends on the protocol via `@Environment`, not the concrete library,
So that the Settings feature is decoupled from the audio implementation.

## Acceptance Criteria

1. **Given** `SettingsScreen` directly depends on `SoundFontLibrary`
   **When** `SoundSourceProvider` protocol is created with `availableSources` and `displayName(for:)`
   **Then** `SoundFontLibrary` conforms to `SoundSourceProvider`
   **And** `SettingsScreen` depends on `SoundSourceProvider` via `@Environment`

2. **Given** `SoundSourceProvider.swift` is created in `Core/Audio/`
   **When** the protocol is used
   **Then** `SettingsScreen` has no import of or reference to `SoundFontLibrary`

3. **Given** the sound source picker in Settings
   **When** it renders available sources
   **Then** behavior is identical to before the refactoring
   **And** the full test suite passes

## Tasks / Subtasks

- [x] Task 1: Create `SoundSourceProvider` protocol (AC: #1, #2)
  - [x] 1.1 Create `Peach/Core/Audio/SoundSourceProvider.swift`
  - [x] 1.2 Define protocol with `availableSources: [SoundSourceID]` and `displayName(for: SoundSourceID) -> String`
  - [x] 1.3 Mark protocol `@MainActor` (SoundFontLibrary is `@MainActor`) — implicit via Swift 6.2 default MainActor isolation
- [x] Task 2: Conform `SoundFontLibrary` to `SoundSourceProvider` (AC: #1)
  - [x] 2.1 Add `SoundSourceProvider` conformance to `SoundFontLibrary`
  - [x] 2.2 Implement `availableSources` — map `availablePresets` to `[SoundSourceID]` (use `SF2Preset.tag`)
  - [x] 2.3 Implement `displayName(for:)` — look up preset name by SoundSourceID
- [x] Task 3: Update `EnvironmentKeys.swift` (AC: #1)
  - [x] 3.1 Add new `@Entry var soundSourceProvider: any SoundSourceProvider = SoundFontLibrary()`
- [x] Task 4: Update `PeachApp.swift` composition root (AC: #1)
  - [x] 4.1 Inject `soundFontLibrary` as `soundSourceProvider` environment value
- [x] Task 5: Refactor `SettingsScreen` to use `SoundSourceProvider` (AC: #1, #2, #3)
  - [x] 5.1 Replace `@Environment(\.soundFontLibrary)` with `@Environment(\.soundSourceProvider)`
  - [x] 5.2 Replace `soundFontLibrary.availablePresets` iteration with `soundSourceProvider.availableSources`
  - [x] 5.3 Replace `preset.name` with `soundSourceProvider.displayName(for: source)`
  - [x] 5.4 Replace `soundFontLibrary.preset(forTag:) == nil` validation with `!availableSources.contains(...)` check
  - [x] 5.5 Verify no remaining references to `SoundFontLibrary` in SettingsScreen
- [x] Task 6: Update `project-context.md` (AC: #2)
  - [x] 6.1 Document `SoundSourceProvider` protocol and its role
  - [x] 6.2 Update SoundFontLibrary description to note protocol conformance
- [x] Task 7: Run full test suite and verify (AC: #3)
  - [x] 7.1 Run `xcodebuild test` — all tests pass
  - [x] 7.2 Run `tools/check-dependencies.sh` — all dependency rules pass

## Dev Notes

### Protocol Design (from architecture.md)

The architecture specifies this exact protocol shape:

```swift
protocol SoundSourceProvider {
    var availableSources: [SoundSourceID] { get }
    func displayName(for source: SoundSourceID) -> String
}
```

File location: `Peach/Core/Audio/SoundSourceProvider.swift`

This abstracts away `SF2Preset` entirely from the Settings feature. SettingsScreen will work with `SoundSourceID` (which wraps the raw tag string) and display names, not preset structs.

### Current SoundFontLibrary API (what SettingsScreen uses today)

`SoundFontLibrary` exposes two members consumed by SettingsScreen:

1. **`availablePresets: [SF2Preset]`** — used in `ForEach` to populate the instrument Picker
2. **`preset(forTag: String) -> SF2Preset?`** — used for validation (checks if stored tag still exists)

The protocol maps these to:
- `availablePresets` → `availableSources: [SoundSourceID]` (each preset's `.tag` becomes a `SoundSourceID`)
- `preset(forTag:)` nil check → `availableSources.contains(SoundSourceID(tag))`
- `preset.name` display → `displayName(for: SoundSourceID) -> String`

### Current SettingsScreen Usage Patterns to Refactor

**Picker population** (current):
```swift
ForEach(soundFontLibrary.availablePresets, id: \.tag) { preset in
    Text(preset.name).tag(preset.tag)
}
```

**Picker population** (after):
```swift
ForEach(soundSourceProvider.availableSources, id: \.self) { source in
    Text(soundSourceProvider.displayName(for: source)).tag(source.rawValue)
}
```

**Validation** (current):
```swift
if soundSource.hasPrefix("sf2:"),
   soundFontLibrary.preset(forTag: soundSource) == nil {
    soundSource = SettingsKeys.defaultSoundSource
}
```

**Validation** (after):
```swift
if !soundSourceProvider.availableSources.contains(where: { $0.rawValue == soundSource }) {
    soundSource = SettingsKeys.defaultSoundSource
}
```

Note: The `hasPrefix("sf2:")` check is no longer needed — if the stored tag doesn't match any available source, reset it regardless of prefix.

### Environment Key Pattern

Current `EnvironmentKeys.swift` has:
```swift
@Entry var soundFontLibrary = SoundFontLibrary()
```

Add a new entry (keep existing for `SoundFontNotePlayer` which still needs the concrete type):
```swift
@Entry var soundSourceProvider: any SoundSourceProvider = SoundFontLibrary()
```

In `PeachApp.swift`, the existing `soundFontLibrary` instance is injected as both:
```swift
.environment(\.soundFontLibrary, soundFontLibrary)
.environment(\.soundSourceProvider, soundFontLibrary)
```

This allows `SoundFontNotePlayer` (which needs the concrete class for preset loading) to keep using `\.soundFontLibrary`, while `SettingsScreen` switches to `\.soundSourceProvider`.

### SoundSourceID Reference

`SoundSourceID` is already defined in `Core/Audio/SoundSourceID.swift`:
```swift
struct SoundSourceID: Hashable, Sendable {
    let rawValue: String
    init(_ rawValue: String) {
        self.rawValue = rawValue.isEmpty ? "sf2:8:80" : rawValue
    }
}
```

It wraps the tag string (e.g., `"sf2:0:42"` for Cello). It's `Hashable` and `Sendable`, suitable for protocol use.

### SF2Preset Reference

`SF2Preset` has a computed `tag` property: `"sf2:\(bank):\(program)"`. The `SoundFontLibrary` conformance will map each preset to `SoundSourceID(preset.tag)`.

### @MainActor Consideration

`SoundFontLibrary` is NOT explicitly `@MainActor` in the current source — it's a plain `final class`. However, `project-context.md` describes it as `@MainActor` and it's injected via SwiftUI `@Environment` (which is MainActor-isolated). The protocol should match: mark it `@MainActor` if SoundFontLibrary is, or leave it unmarked if SoundFontLibrary isn't explicitly annotated. Check the actual class declaration at implementation time.

### Files to Modify

| File | Change |
|------|--------|
| `Peach/Core/Audio/SoundSourceProvider.swift` | **NEW** — Protocol definition |
| `Peach/Core/Audio/SoundFontLibrary.swift` | Add `SoundSourceProvider` conformance |
| `Peach/App/EnvironmentKeys.swift` | Add `soundSourceProvider` entry |
| `Peach/App/PeachApp.swift` | Inject `soundFontLibrary` as `soundSourceProvider` |
| `Peach/Settings/SettingsScreen.swift` | Switch from `soundFontLibrary` to `soundSourceProvider` |
| `docs/project-context.md` | Document `SoundSourceProvider` protocol |

### Files NOT to Modify

- `SoundFontNotePlayer.swift` — still needs concrete `SoundFontLibrary` for preset loading
- `SoundFontLibraryTests.swift` — tests the concrete class, not the protocol
- `SF2PresetParser.swift` — implementation detail behind SoundFontLibrary

### Project Structure Notes

- `SoundSourceProvider.swift` goes in `Core/Audio/` per architecture spec and file placement rules
- Protocol in `Core/` must NOT import SwiftUI (enforced by `check-dependencies.sh`)
- `SoundSourceID` is already in `Core/Audio/` — no cross-feature coupling

### Dependency Direction Compliance

- `Core/Audio/SoundSourceProvider.swift` depends only on `SoundSourceID` (same directory) — no framework imports
- `Settings/SettingsScreen.swift` depends on protocol from `Core/` — correct direction
- No cross-feature coupling introduced

### Previous Story Intelligence (from 22.4)

- **Pattern:** Domain type changes propagate from core outward — define protocol first, then conform, then update consumers
- **Commit pattern:** Single implementation commit, then code review fixes commit
- **Verification:** Run full test suite with `xcodebuild test`, then `tools/check-dependencies.sh`
- **Code review found:** Stale comments and misleading descriptions — double-check doc comments

### References

- [Source: docs/planning-artifacts/epics.md#Epic 22, Story 22.5]
- [Source: docs/planning-artifacts/architecture.md#SoundSourceProvider Protocol (v0.3)]
- [Source: docs/planning-artifacts/architecture.md#Project File Structure]
- [Source: docs/project-context.md#SoundFontLibrary]
- [Source: docs/project-context.md#Dependency Direction Rules]
- [Source: docs/project-context.md#File Placement Rules]
- [Source: docs/implementation-artifacts/22-4-unified-reference-target-naming.md#Dev Notes]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None — clean implementation with no issues.

### Completion Notes List

- Created `SoundSourceProvider` protocol in `Core/Audio/` with `availableSources` and `displayName(for:)` — no framework imports, depends only on `SoundSourceID`
- Protocol is implicitly `@MainActor` via Swift 6.2 default actor isolation (no explicit annotation per project rules)
- Added `SoundSourceProvider` conformance to `SoundFontLibrary` via extension — `availableSources` maps presets to `[SoundSourceID]`, `displayName` looks up preset by tag
- Added `@Entry var soundSourceProvider` to `EnvironmentKeys.swift`, wired in `PeachApp.swift` using existing `soundFontLibrary` instance
- Refactored `SettingsScreen` to depend on `soundSourceProvider` protocol — removed all `soundFontLibrary` references; Picker uses `availableSources`/`displayName`, validation uses `contains` check instead of `preset(forTag:)` nil check
- Simplified validation: removed `hasPrefix("sf2:")` guard — any unrecognized tag now resets to default
- Updated `project-context.md` to document `SoundSourceProvider` protocol and `SoundFontLibrary` conformance
- Full test suite passed (0 regressions), dependency rules all pass

### Change Log

- 2026-03-01: Implemented story 22.5 — extracted `SoundSourceProvider` protocol, decoupled `SettingsScreen` from `SoundFontLibrary`

### File List

- `Peach/Core/Audio/SoundSourceProvider.swift` (NEW)
- `Peach/Core/Audio/SoundFontLibrary.swift` (MODIFIED)
- `Peach/App/EnvironmentKeys.swift` (MODIFIED)
- `Peach/App/PeachApp.swift` (MODIFIED)
- `Peach/Settings/SettingsScreen.swift` (MODIFIED)
- `docs/project-context.md` (MODIFIED)
- `docs/implementation-artifacts/sprint-status.yaml` (MODIFIED)
- `docs/implementation-artifacts/22-5-extract-soundsourceprovider-protocol.md` (MODIFIED)
