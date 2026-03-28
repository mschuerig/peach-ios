---
stepsCompleted: [1, 2, 3, 4, 5]
inputDocuments: ['project-context.md', 'arc42.md']
workflowType: 'research'
lastStep: 5
research_type: 'technical'
research_topic: 'macOS compatibility for Peach'
research_goals: 'Feasibility study comparing Mac Catalyst vs native SwiftUI multiplatform, with effort estimates grounded in the actual codebase, to decide whether macOS support is worth pursuing'
user_name: 'Michael'
date: '2026-03-28'
web_research_enabled: true
source_verification: true
---

# Research Report: macOS Compatibility for Peach

**Date:** 2026-03-28
**Author:** Michael
**Research Type:** Technical Feasibility Study

---

## Executive Summary

Peach is exceptionally well-positioned for macOS support. The codebase is 100% SwiftUI with zero UIKit in views, uses SwiftData (cross-platform), and the only iOS-specific APIs are behind protocol abstractions. The estimated effort ranges from **1-2 days for Mac Catalyst** to **3-5 days for native SwiftUI multiplatform**, with the multiplatform approach being the clear recommendation.

---

## 1. Approach Comparison

### Option A: Mac Catalyst

Mac Catalyst runs your iPad app on macOS using a UIKit compatibility layer. You enable it in Xcode by adding a "Mac (Catalyst)" destination to the existing target.

**How it works for Peach:**
- The entire SwiftUI app would run inside the Catalyst translation layer
- `AVAudioSession` is available under Mac Catalyst (since Mac Catalyst 13.0+), so `SoundFontEngine.configureAudioSession()` and `AudioSessionInterruptionMonitor` would compile without changes
- `UIImpactFeedbackGenerator` compiles but produces no haptic output on Mac hardware (silently no-ops)
- `UIApplication.didEnterBackgroundNotification` works under Catalyst
- MIDIKit supports macOS natively

**Pros:**
- Lowest initial effort (checkbox + minor fixes)
- AVAudioSession API available, no audio code changes needed
- Single target, single build
- Automatic universal purchase with same bundle ID

**Cons:**
- **Tahoe (macOS 2025/2026) issues:** Developers report crashes, toolbar rendering bugs, and visual glitches with Catalyst apps since Liquid Glass shipped. Fixes are being deployed but the situation is unstable ([source](https://mjtsai.com/blog/2026/03/19/catalyst-in-tahoe/))
- App looks and feels like an iPad app on Mac — no native Mac chrome
- `verticalSizeClass` / `horizontalSizeClass` may behave unexpectedly in resizable Mac windows
- No native macOS menu bar integration (would need `#if targetEnvironment(macCatalyst)` workarounds)
- No native Settings window (macOS convention is Cmd+, opening a dedicated window)
- Apple's investment in Catalyst appears to be waning — SwiftUI multiplatform is the clearly preferred direction
- Window resizing can produce awkward layouts designed for fixed iOS screen sizes
- Future maintenance risk: Catalyst bugs may not get priority fixes

**Verdict:** Technically easiest, but results in a second-class Mac experience and carries platform stability risk.

### Option B: Native SwiftUI Multiplatform

Add a native "Mac" (not Catalyst) destination to the Xcode project. The app compiles against the macOS SDK directly, with full access to macOS-native APIs. SwiftUI adapts its rendering to native macOS controls.

**How it works for Peach:**
- Same SwiftUI views compile natively for macOS with native Mac appearance
- SwiftData, `@AppStorage`, `@Observable`, TipKit, NavigationStack all work cross-platform
- `AVAudioEngine` and `AVAudioUnitSampler` work on macOS (they predate iOS)
- `AVAudioSession` does NOT exist on macOS — requires `#if os(iOS)` conditional compilation
- `UIImpactFeedbackGenerator` does NOT exist on macOS — requires platform abstraction (already behind `HapticFeedback` protocol)
- `UIApplication` notifications don't exist — need `NSApplication` equivalents or SwiftUI `.scenePhase`
- MIDIKit fully supports macOS (macOS 10.15+)

**Pros:**
- Native Mac look and feel out of the box (Liquid Glass, native controls, proper window chrome)
- Full macOS SDK access (menu bar, keyboard shortcuts, Settings window via `Settings` scene)
- SwiftUI multiplatform is Apple's clearly preferred path forward
- Better long-term maintainability and platform stability
- Proper window management (resizable windows work naturally with SwiftUI layout)
- Can still do universal purchase via shared bundle ID

**Cons:**
- Requires handling `AVAudioSession` absence (platform-conditional code)
- Requires `NSApplication` notification equivalents or `scenePhase`-based lifecycle
- Slightly more effort than Catalyst checkbox
- Need to test on actual Mac hardware

**Verdict:** Moderately more effort, but results in a first-class Mac app with better long-term prospects.

### Option C: Designed for iPad (Apple Silicon only)

Runs the unmodified iPad app on Apple Silicon Macs. Zero code changes.

**Verdict:** Not recommended. The app runs in a fixed iPad-sized window with no Mac integration. Poor user experience, no keyboard shortcuts, no menu bar. Suitable only as a stopgap if you want to list on the Mac App Store immediately while building a proper Mac version.

---

## 2. Component-by-Component Impact Assessment

### 2.1 SwiftUI Views (Zero changes expected)

| Component | Catalyst | Native Mac | Notes |
|-----------|----------|------------|-------|
| All screens (Start, Training, Profile, Settings, Info) | Works | Works | Pure SwiftUI, no UIKit |
| `NavigationStack` | Works | Works | Hub-and-spoke pattern is fine for single-window |
| `@Environment(\.verticalSizeClass)` | May be nil on Mac | Returns `.regular` | Views already handle both compact/regular |
| `@AppStorage` | Works | Works | Identical cross-platform behavior |
| `TipKit` | Works | Works | Available on macOS 14+ (not a concern at iOS 26 target) |
| `Form` / `Section` in Settings | Works | Works | Native Mac form styling applied automatically |
| Charts (Profile) | Works | Works | Swift Charts is cross-platform |

**Effort: 0 days** for either approach. The UI layer is clean.

### 2.2 Audio Engine

| Component | Catalyst | Native Mac | Notes |
|-----------|----------|------------|-------|
| `AVAudioEngine` | Works | Works | Available on macOS since 10.10 |
| `AVAudioUnitSampler` | Works | Works | SF2/SoundFont loading identical API |
| `SoundFontEngine` (lock-free double buffer) | Works | Works | Pure audio thread code, platform-agnostic |
| `AVAudioSession.setCategory(.playback)` | Works (Catalyst shim) | **NOT AVAILABLE** | Needs `#if os(iOS)` |
| `AVAudioSession.setPreferredIOBufferDuration` | Works | **NOT AVAILABLE** | macOS uses system default buffer size |
| `AVAudioSession.interruptionNotification` | Works | **NOT AVAILABLE** | macOS doesn't have audio interruptions the same way |
| `AVAudioSession.routeChangeNotification` | Works | **NOT AVAILABLE** | Less relevant on macOS (no phone calls) |
| SF2 file loading (`loadSoundBankInstrument`) | Works | Works | Same API on macOS |

**Native Mac changes needed:**
- `SoundFontEngine.configureAudioSession()` — wrap in `#if os(iOS)` (macOS doesn't need audio session configuration; `AVAudioEngine` works without it)
- `AudioSessionInterruptionMonitor` — the `AVAudioSession.interruptionNotification` and `routeChangeNotification` observers need `#if os(iOS)` guards. Background/foreground observers already use injected notification names, so they just need macOS equivalents

**Effort: 0.5 days** (native Mac), **0 days** (Catalyst)

### 2.3 Haptic Feedback

| Component | Catalyst | Native Mac | Notes |
|-----------|----------|------------|-------|
| `HapticFeedbackManager` | Compiles, no-ops silently | **Won't compile** | `UIImpactFeedbackGenerator` unavailable |
| `HapticFeedback` protocol | Works | Works | Protocol is platform-agnostic |

The architecture already has this right: `HapticFeedback` is a protocol, and `HapticFeedbackManager` is an implementation injected from the composition root.

**Native Mac solution:** Create a `MacHapticFeedbackManager` that either:
- No-ops (simplest — Macs don't have taptic engines except in trackpads)
- Uses `NSHapticFeedbackManager` for Force Touch trackpad feedback (subtle, optional)

Or simpler: use `#if os(iOS)` in `PeachApp.swift` to inject the real manager on iOS and a no-op on macOS.

**Effort: 0.25 days** (native Mac), **0 days** (Catalyst)

### 2.4 App Lifecycle & Notifications

| Component | Catalyst | Native Mac | Notes |
|-----------|----------|------------|-------|
| `scenePhase` in `ContentView` | Works | Works | SwiftUI cross-platform |
| `UIApplication.didEnterBackgroundNotification` | Works | **NOT AVAILABLE** | Need `NSApplication` equivalent |
| `UIApplication.willEnterForegroundNotification` | Works | **NOT AVAILABLE** | Need `NSApplication` equivalent |
| `TrainingLifecycleCoordinator` | Works | Needs adaptation | Background/foreground concept differs on macOS |

The architecture helps here: notification names are already injected as parameters to `AudioSessionInterruptionMonitor` and `PitchMatchingSession`. For macOS, inject `NSApplication.didResignActiveNotification` / `NSApplication.didBecomeActiveNotification` instead, or rely on SwiftUI `scenePhase` entirely.

**Native Mac solution:** In `PeachApp.swift`, use `#if os(iOS)` to select the right notification names:
```swift
#if os(iOS)
let bgNotification = UIApplication.didEnterBackgroundNotification
let fgNotification = UIApplication.willEnterForegroundNotification
#else
let bgNotification = NSApplication.didResignActiveNotification
let fgNotification = NSApplication.didBecomeActiveNotification
#endif
```

**Effort: 0.5 days** (native Mac), **0 days** (Catalyst)

### 2.5 MIDI Input

| Component | Catalyst | Native Mac | Notes |
|-----------|----------|------------|-------|
| MIDIKit | Works | Works | Fully cross-platform (macOS 10.15+) |
| `MIDIKitAdapter` | Works | Works | CoreMIDI available on both platforms |

MIDIKit is explicitly designed as a "modern multi-platform Swift CoreMIDI wrapper." macOS has arguably *better* MIDI support than iOS, since MIDI controllers are a natural Mac peripheral.

**Effort: 0 days** for either approach.

### 2.6 Data Layer

| Component | Catalyst | Native Mac | Notes |
|-----------|----------|------------|-------|
| SwiftData `@Model` types | Works | Works | Cross-platform |
| `TrainingDataStore` | Works | Works | No platform-specific code |
| CSV export/import | Works | Works | Pure Swift |
| `ModelContainer` setup | Works | Works | Identical API |

**Effort: 0 days** for either approach.

### 2.7 Dependencies

| Dependency | macOS Support | Notes |
|------------|--------------|-------|
| MIDIKit v0.11.0 | macOS 10.15+ | Full support, cross-platform by design |
| swift-timecode v3.1.0 | macOS 10.15+ | Transitive dependency, cross-platform |

**No blocking dependencies.** Both support macOS.

---

## 3. macOS-Specific Enhancements (Optional)

These aren't required for compatibility but would make the Mac version feel native:

| Enhancement | Effort | Impact |
|-------------|--------|--------|
| **Keyboard shortcuts** (space to start, arrow keys for answers) | 0.5 days | High — expected on Mac |
| **Menu bar** (File > Export, Help menu) | 0.5 days | Medium — Mac convention |
| **Settings scene** (Cmd+, opens native Settings window) | 0.25 days | Medium — Mac convention |
| **Window title** | Trivial | Low — polish |
| **Drag & drop CSV import** | 0.5 days | Medium — Mac-native interaction |
| **Touch Bar support** (legacy MacBook Pros) | Skip | Not worth it |

---

## 4. Distribution

### Universal Purchase (Recommended)
- Use the same bundle ID for iOS and macOS
- Users who bought the iOS app automatically get the Mac app (and vice versa)
- Single app record in App Store Connect
- Works with both Catalyst and native Mac targets
- Enabled by default for Catalyst; requires bundle ID matching for native

### Separate Listing (Alternative)
- Different bundle ID, separate App Store listing
- Allows different pricing for Mac vs iOS
- More App Store management overhead
- Not recommended for Peach (same app, same audience)

### Notarization
- Required for all Mac App Store submissions (automatic via Xcode)
- Required for direct distribution outside the App Store (manual via `notarytool`)
- No additional effort if distributing through Mac App Store

---

## 5. Effort Summary

### Mac Catalyst Path

| Task | Effort |
|------|--------|
| Add Catalyst destination in Xcode | 0.25 days |
| Fix any compilation issues | 0.25 days |
| Test audio playback on Mac | 0.25 days |
| Test MIDI input on Mac | 0.25 days |
| UI/layout testing and fixes | 0.5 days |
| **Total** | **~1.5 days** |

### Native SwiftUI Multiplatform Path

| Task | Effort |
|------|--------|
| Add Mac destination in Xcode | 0.25 days |
| `#if os(iOS)` for `AVAudioSession` in `SoundFontEngine` | 0.25 days |
| `#if os(iOS)` for `AudioSessionInterruptionMonitor` | 0.25 days |
| Platform-conditional haptic feedback injection | 0.25 days |
| Platform-conditional lifecycle notifications | 0.25 days |
| Keyboard shortcuts (basic) | 0.5 days |
| Settings scene (Cmd+,) | 0.25 days |
| UI testing and layout adjustments | 0.5 days |
| Test audio playback on Mac | 0.25 days |
| Test MIDI input on Mac | 0.25 days |
| **Total** | **~3 days** |

### Optional Mac-Native Polish (on top of either path)

| Task | Effort |
|------|--------|
| Menu bar integration | 0.5 days |
| Drag & drop CSV import | 0.5 days |
| Mac App Store metadata + screenshots | 0.5 days |
| **Total** | **~1.5 days** |

---

## 6. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| AVAudioEngine behaves differently on macOS (latency, buffer sizes) | Low | Medium | Test on hardware; macOS audio stack is mature |
| SwiftUI layout oddities on macOS | Low | Low | Views are responsive already; test and fix |
| Catalyst Liquid Glass bugs on Tahoe | Medium | High | Avoid Catalyst; go native |
| MIDIKit macOS issues | Very Low | Low | MIDIKit is explicitly multiplatform |
| App Store review rejection | Very Low | Low | No unusual capabilities required |
| SwiftData migration issues cross-platform | Very Low | Low | Same schema, same framework |

---

## 7. Recommendation

**Go with native SwiftUI multiplatform.** Here's why:

1. **The codebase is ready.** 100% SwiftUI, protocol-abstracted platform dependencies, injected notification names. The architecture was (perhaps unintentionally) built for this.

2. **The effort difference is small.** ~3 days vs ~1.5 days. The extra 1.5 days buys you a first-class Mac citizen instead of an iPad-on-Mac wrapper.

3. **Catalyst is risky in 2026.** Tahoe/Liquid Glass introduced significant Catalyst regressions, and Apple's investment clearly favors SwiftUI multiplatform. Building on Catalyst means betting on a platform Apple may deprioritize.

4. **Mac users have expectations.** Keyboard shortcuts, Cmd+, for settings, a proper menu bar — these are table stakes for a Mac app. Native SwiftUI makes them trivial to add; Catalyst makes them awkward.

5. **The changes are surgical.** Only 3 files need platform conditionals (`SoundFontEngine`, `AudioSessionInterruptionMonitor`, `PeachApp`). One protocol implementation needs a Mac variant (`HapticFeedbackManager`). Everything else compiles as-is.

**Estimated total effort for a polished Mac release: ~4-5 days** (including keyboard shortcuts, Settings scene, and App Store preparation).

---

## Sources

- [Catalyst in Tahoe — Michael Tsai](https://mjtsai.com/blog/2026/03/19/catalyst-in-tahoe/)
- [Native macOS, SwiftUI, and Mac Catalyst — Doran Gao](https://medium.com/@dorangao/native-macos-swiftui-and-mac-catalyst-the-3-apple-app-models-every-developer-should-understand-017e1fbff4eb)
- [SwiftUI for Mac 2025 — TrozWare](https://troz.net/post/2025/swiftui-mac-2025/)
- [Configuring a Multiplatform App — Apple Documentation](https://developer.apple.com/documentation/xcode/configuring-a-multiplatform-app-target)
- [MIDIKit — Swift Package Index](https://swiftpackageindex.com/orchetect/MIDIKit)
- [MIDIKit — GitHub](https://github.com/orchetect/MIDIKit)
- [Food Truck: Building a SwiftUI Multiplatform App — Apple](https://developer.apple.com/documentation/SwiftUI/food-truck-building-a-swiftui-multiplatform-app)
- [Universal Purchase Support — AppleInsider](https://appleinsider.com/articles/20/03/23/app-store-rolls-out-universal-purchase-support-for-mac-apps)
- [Mac Catalyst — Apple Developer](https://developer.apple.com/mac-catalyst/)
- [Haptics on Apple Platforms — Marco Eidinger](https://blog.eidinger.info/haptics-on-apple-platforms)
- [AVAudioSession — Apple Developer Forums](https://developer.apple.com/forums/thread/123716)
- [Considering Mac Catalyst? A word of caution — thatvirtualboy](https://thatvirtualboy.com/remove-macos-catalyst/)
- [Building a Unified Multiplatform Architecture with SwiftUI — Medium](https://medium.com/@mrhotfix/building-a-unified-multiplatform-architecture-with-swiftui-ios-macos-and-visionos-6214b307466a)
