# App Store Review Compliance Report

**Date:** 2026-03-28

## Project Summary
- **App Name:** Peach
- **Bundle ID:** de.schuerig.peach
- **Framework:** Native Swift/SwiftUI
- **Deployment Target:** iOS 26.0
- **Platforms:** iPhone + iPad (TARGETED_DEVICE_FAMILY = 1,2)
- **Marketing Version:** 0.1
- **Dependencies:** MIDIKit 0.11.0 (only external dependency)
- **Source Files:** 162 Swift files
- **App Type:** Music ear-training app (pitch discrimination, pitch matching, rhythm exercises)

## Critical Issues (Will Likely Cause Rejection)

### [CRITICAL] Guideline 5.1.1 -- Privacy Manifest Missing
**Issue:** No `PrivacyInfo.xcprivacy` file exists anywhere in the project. Since iOS 17/Xcode 15, Apple requires a privacy manifest for all apps. The app uses `UserDefaults` (via `@AppStorage` and `AppUserSettings`), which is a "required reason API" (`NSPrivacyAccessedAPICategoryUserDefaults`) requiring declaration with reason code `CA92.1`. Additionally, the third-party dependency MIDIKit may need its own privacy manifest entry.
**Location:** Project-wide (no file found)
**Fix:** Create `Peach/Resources/PrivacyInfo.xcprivacy` declaring:
- `NSPrivacyTracking`: false
- `NSPrivacyTrackingDomains`: empty array
- `NSPrivacyCollectedDataTypes`: empty array
- `NSPrivacyAccessedAPITypes`: array with `NSPrivacyAccessedAPICategoryUserDefaults` reason `CA92.1`

Your own research doc at `docs/planning-artifacts/research/technical-ios-app-store-submission-readiness-research-2026-03-09.md` already describes exactly what this file should contain.

### [CRITICAL] Guideline 5.1.1(i) -- No Privacy Policy URL
**Issue:** No privacy policy URL found anywhere in the app code, Info.plist keys, or user-facing screens. Even for apps that collect no personal data, Apple requires a privacy policy URL in App Store Connect and it is strongly recommended to link it in-app.
**Location:** `Peach/Info/InfoScreen.swift` -- has GitHub link and copyright but no privacy policy link
**Fix:** Add a privacy policy URL to the Info screen and ensure it is also set in App Store Connect metadata.

## Warnings (May Cause Rejection)

### [WARNING] Guideline 1.5 -- Developer Contact/Support Information
**Issue:** The Info screen (`Peach/Info/InfoScreen.swift`) shows developer name, GitHub link, and copyright, but no explicit support contact method (email, support URL, or feedback form). The GitHub link may partially serve this purpose, but Apple expects an "easy way to contact you."
**Location:** `Peach/Info/InfoScreen.swift`
**Fix:** Add a support email link or dedicated support URL to the Info screen.

### [WARNING] Guideline 7 (Common Rejection) -- Force Unwraps
**Issue:** Several force unwraps exist in production code:
1. `Bundle.main.url(forResource: "Samples", withExtension: "sf2")!` in `PeachApp.swift:45` -- crash if resource missing
2. `continuation!` in `MIDIKitAdapter.swift:25,42` -- force unwrap of implicitly unwrapped optional
3. `self.gridOrigin!` in `RhythmOffsetDetectionSession.swift:199` -- guarded by nil check on preceding line (low risk, logging only)
4. `rawBuffer.baseAddress!` in `SoundFontEngine.swift:250` -- low-level audio buffer (acceptable in context)

Items 1 and 2 are the most concerning for crash risk, though item 1 would only crash if the bundle is corrupted.
**Location:** See above
**Fix:** Use `guard let` with appropriate error handling for items 1 and 2. Item 3 is safe but could use `gridOrigin` directly with string interpolation. Item 4 is acceptable in low-level audio code.

### [WARNING] Guideline 2.3 -- Missing CFBundleDisplayName
**Issue:** The project uses `GENERATE_INFOPLIST_FILE = YES` and does not explicitly set `INFOPLIST_KEY_CFBundleDisplayName`. The display name will default to the target name ("Peach"), which is fine if intentional, but should be verified. The app name "Peach" is 5 characters (well under 30).
**Location:** `Peach.xcodeproj/project.pbxproj`
**Fix:** Verify the display name renders correctly on the home screen. Consider explicitly setting it if needed.

## Recommendations (Best Practices)

### [INFO] Guideline 2.1 -- Debug-Only Code Properly Guarded
**Observation:** The `#if DEBUG` block in `PreviewDefaults.swift:173` is properly guarded and provides preview-only environment injection. No debug code leaks into production. Clean.

### [INFO] Guideline 1.6 -- Data Security: Good Practices
**Observation:** No API keys, secrets, tokens, or hardcoded credentials found. No `.env` files. No `NSAllowsArbitraryLoads`. No localhost/staging URLs. No network calls detected at all -- the app appears to be fully offline. UserDefaults stores only user preferences (sound settings, note ranges), not sensitive data. Good security posture.

### [INFO] Guideline 3.1 -- No IAP/Payment Issues
**Observation:** No StoreKit imports, no IAP, no payment SDKs, no subscriptions. The app is free with no monetization. No compliance issues here.

### [INFO] Guideline 4.8 -- No Login/Authentication
**Observation:** No third-party login, no account creation, no `AuthenticationServices`. Sign in with Apple is not required. Account deletion (5.1.1v) is not applicable.

### [INFO] Guideline 5.1.2 -- No Tracking/Ad SDKs
**Observation:** No ad SDKs, no analytics SDKs, no tracking frameworks, no `AppTrackingTransparency` needed. Clean.

### [INFO] Guideline 2.5.4 -- No Background Modes
**Observation:** No `UIBackgroundModes` declared, consistent with a foreground-only training app. Audio playback via AVAudioEngine does not require background mode since training is interactive.

### [INFO] Guideline 1.2 -- No UGC
**Observation:** No user-generated content, no social features, no chat, no comments. Content moderation not required.

### [INFO] Guideline 2.4 -- iPad Support
**Observation:** `TARGETED_DEVICE_FAMILY = "1,2"` supports both iPhone and iPad. All orientations supported on iPad; portrait + landscape on iPhone. No hardcoded screen sizes detected.

### [INFO] -- Third-Party Dependency Privacy Manifests
**Observation:** MIDIKit (0.11.0) is the sole third-party dependency. Verify that MIDIKit ships its own `PrivacyInfo.xcprivacy` or add coverage in the app's manifest for any APIs it uses. MIDIKit uses CoreMIDI which does not appear on Apple's required-reason API list, so this is likely a non-issue.

### [INFO] -- Data Export Feature
**Observation:** The app has a CSV export/import feature via `ShareLink` and file import in `SettingsScreen.swift`. This is local data management (training records), not cloud sync. No privacy concerns.

## Checklist Summary
- [x] Project type & framework detected (Native Swift/SwiftUI)
- [x] Info.plist metadata complete (generated, versions set)
- [x] App display name <= 30 characters ("Peach" = 5)
- [x] No references to other mobile platforms
- [x] All NS*UsageDescription keys present (none needed -- no camera/location/etc.)
- [x] No hardcoded secrets or API keys
- [x] App Transport Security configured (no overrides)
- [ ] **Privacy manifest present and complete** -- MISSING
- [ ] **Privacy policy URL in app** -- MISSING
- [x] Data minimization -- no broad permissions requested
- [x] Sign in with Apple (N/A -- no third-party login)
- [x] Account deletion (N/A -- no account creation)
- [x] IAP for digital goods (N/A -- no IAP)
- [x] Restore Purchases exists (N/A -- no IAP)
- [x] Subscription terms before purchase (N/A)
- [x] No debug/test code in production (properly guarded)
- [x] No placeholder/TODO content in user-facing strings
- [x] No beta/trial/demo labels
- [x] No dynamic code loading / hot-patching
- [x] Background modes match actual usage (none declared, none needed)
- [x] No ads in extensions/widgets/App Clips (N/A)
- [x] ATT implemented (N/A -- no tracking)
- [x] UGC moderation (N/A -- no UGC)
- [ ] **Support URL accessible in-app** -- GitHub only, no direct contact
- [x] No on-device crypto mining
- [x] No dark patterns in purchase flows
- [x] No illegal media downloading

## Final Verdict

**NEEDS FIXES** -- Two critical items must be addressed before submission:

1. **Create a `PrivacyInfo.xcprivacy` file** declaring UserDefaults API usage with reason code `CA92.1`. Without this, Apple will reject the binary.

2. **Add a privacy policy URL** both in-app (Info screen) and in App Store Connect. Even for apps collecting no personal data, this is required.

One recommended improvement:

3. **Add a support contact method** (email or support URL) to the Info screen beyond the GitHub link.

The app is otherwise in excellent shape for submission -- no IAP complications, no tracking, no UGC, no third-party login, no sensitive permissions, clean architecture with no debug leaks. The fixes are straightforward and small in scope.
