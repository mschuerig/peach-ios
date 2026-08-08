# Xcode Security Settings

Security build-setting and entitlement decisions for **Peach**.

Created 2026-08-08 during story 83.4, following the project's first-ever run of
`/audit-xcode-security-settings`. Before that run no such document existed, which is why the
gaps below went unobserved through the 1.0.0 release — the 2026-03-28 App Store audit did not
examine entitlements at all.

This file is append/update-only. Entries are never removed; a setting that changes status moves
section and keeps its prior rationale as context.

**Project shape relevant to these decisions:** pure Swift (454 `.swift` files, zero C/C++/ObjC).
Two targets — `Peach` (`com.apple.product-type.application`) and `PeachTests`
(`com.apple.product-type.bundle.unit-test`). Four build configurations: Debug, Release,
Debug (Research), Release (Research). No `.xcconfig` files; settings live in `project.pbxproj`.
Dependencies are SPM and built from source (MIDIKit, swift-async-algorithms, plus
swift-collections and swift-timecode transitively) — there are no binary frameworks.

## Enabled settings

Adopted in story 83.4:

- `ENABLE_ENHANCED_SECURITY`: set at project level, so present in all four configurations.
  Required by no App Store guideline on any platform — adopted as hardening, not compliance.
- `com.apple.security.hardened-process` (entitlement): the main toggle. Without it the runtime
  protections below are inert.
- `com.apple.security.hardened-process.enhanced-security-version-string` to `2`.
- `com.apple.security.hardened-process.hardened-heap`: extra type-isolation buckets in the
  allocator at runtime.
- `com.apple.security.hardened-process.dyld-ro`: marks dyld state read-only.
- `com.apple.security.hardened-process.platform-restrictions-string` to `2`: dyld and Mach
  messaging restrictions.

Entitlements live in `Peach/Resources/Peach.entitlements`, wired via `CODE_SIGN_ENTITLEMENTS` on
all four **app-target** configurations. The test target is deliberately excluded — its product
type is not supported by the capability.

Cascaded automatically by `ENABLE_ENHANCED_SECURITY` **per Apple's and the audit skill's
documentation** — not set explicitly here, and not individually observed in this project:
`ENABLE_SECURITY_COMPILER_WARNINGS`, `GCC_WARN_SHADOW`, `CLANG_WARN_EMPTY_BODY`,
`CLANG_CXX_STANDARD_LIBRARY_HARDENING`, `CLANG_ENABLE_C_TYPED_ALLOCATOR_SUPPORT`,
`CLANG_ENABLE_CPLUSPLUS_TYPED_ALLOCATOR_SUPPORT`. Of these, only
`ENABLE_SECURITY_COMPILER_WARNINGS` and `CLANG_WARN_EMPTY_BODY` appear in the resolved dump taken
during story 83.4; the other four do not, and `CLANG_WARN_EMPTY_BODY` is an Xcode template default
regardless. Recorded for completeness, not as measured project state.

> Note on expected value: because Peach is pure Swift, essentially all of the *compiler-driven*
> half of Enhanced Security is inert here — enabling it produced zero new warnings on either
> platform. The value is entirely in the entitlement-driven *runtime* protections.

Already active before this audit (Xcode template defaults, left as-is):

- `ENABLE_USER_SCRIPT_SANDBOXING`
- `DEAD_CODE_STRIPPING`
- `CLANG_ANALYZER_LOCALIZABILITY_NONLOCALIZED`, `CLANG_ANALYZER_NONNULL`,
  `CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION` to `YES_AGGRESSIVE`
- `GCC_WARN_ABOUT_RETURN_TYPE` to `YES_ERROR`, `GCC_WARN_UNINITIALIZED_AUTOS` to
  `YES_AGGRESSIVE`, `GCC_WARN_64_TO_32_BIT_CONVERSION`, `GCC_WARN_UNDECLARED_SELECTOR`,
  `GCC_WARN_UNUSED_FUNCTION`, `GCC_WARN_UNUSED_VARIABLE`

## Disabled settings

- `ENABLE_POINTER_AUTHENTICATION` to `NO`: **deliberate opt-out**, overriding the default that
  Enhanced Security would otherwise cascade. Enabling it builds the app for `arm64e`.

  Rationale: it could not be established whether `arm64e` binaries are accepted for third-party
  App Store distribution. Apple's *Enabling enhanced security for your app* and *Preparing your
  app to work with pointer authentication* pages say nothing about submission or distribution
  either way, and the one contrary claim encountered — that "arm64e is not supported for
  third-party user space code" — was an uncorroborated search snippet, not a citable source.
  Story 83.3 ships a release from this configuration, and shipping a release on an unverified
  premise is not acceptable. Apple's documentation explicitly supports the opt-out: *"If you need
  to turn off pointer authentication for your target… set the `ENABLE_POINTER_AUTHENTICATION`
  build setting to `No`."*

  Verified consequence: the built binary is `arm64`, not `arm64e`.

  **To revisit**, two things are needed: (1) a citable answer on App Store acceptance of `arm64e`;
  and (2) SPM handling — Swift Package dependencies are *not* built for `arm64e` automatically,
  so `iOSPackagesShouldBuildARM64e` and `macOSPackagesShouldBuildARM64e` must be set in
  `Peach.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings`. Peach has two
  direct SPM dependencies, so this is not optional.

## Deferred

Settings considered but not yet enabled. Revisit later.

- `com.apple.security.hardened-process.checked-allocations` (hardware memory tagging, MTE):
  default-OFF, and the audit skill does not auto-enable it. Hardware backing requires A19-class
  iPhone/iPad or M5-class Mac/Vision Pro, so it is unobservable on most current devices.
  Recommended rollout is soft mode first. Revisit when there is a device to validate against.

- `ENABLE_APP_SANDBOX` and `ENABLE_HARDENED_RUNTIME`: **not deferred out of preference — they
  belong to a different submission.** Both are required by App Store Review Guideline 2.4.5(i)
  for *Mac App Store* distribution only; iOS apps are sandboxed by the OS unconditionally and
  have no equivalent entitlement. Ownership sits with **Epic 74** (macOS distribution, paused),
  which already tracks them as unchecked items at
  `docs/implementation-artifacts/74-1-submit-to-mac-app-store.md:23-24`. Story 83.4 created the
  `.entitlements` file these keys will live in, but deliberately did not add them.

  When Epic 74 resumes, Peach will need at minimum
  `com.apple.security.files.user-selected.read-write` — CSV import goes through `.fileImporter`
  and export through `ShareLink`. Audio output and CoreMIDI need no exception, and there is no
  CoreBluetooth usage, so no Bluetooth entitlement is required.

- `ENABLE_C_BOUNDS_SAFETY` / `ENABLE_CPLUSPLUS_BOUNDS_SAFE_BUFFERS`: **not applicable.** Both are
  annotation-based programming models for C and C++. Peach contains no C-family source. Recorded
  so a future audit does not re-evaluate them from scratch.

## Verification performed (2026-08-08)

- `plutil -lint` on the entitlements file: OK; exactly the five `hardened-process` keys.
- Resolved build settings confirm `ENABLE_ENHANCED_SECURITY = YES`,
  `ENABLE_POINTER_AUTHENTICATION = NO`, `CODE_SIGN_ENTITLEMENTS` wired, `ARCHS = arm64`, and
  `ENABLE_SECURITY_COMPILER_WARNINGS = YES` — consistent with the cascade having fired, though no
  pre-change baseline reading was taken, so this observation alone does not distinguish the cascade
  from an Xcode 26 default.
- Test target confirmed free of all three settings **at target level**, by `project.pbxproj`
  inspection. Note this is not a resolved-settings result: `PeachTests` *inherits* the
  project-level `ENABLE_ENHANCED_SECURITY = YES`, as every target does. That is inert — the test
  bundle has no entitlements, so the runtime protections never provision, and the compiler half is
  inert in pure Swift. The resolved check for the test target could not be run: `xcodebuild
  -showBuildSettings` dies on `CoreSimulatorService connection became invalid` inside the agent
  sandbox.
- `bin/build.sh` and `bin/build.sh -p mac`: both succeed, zero new warnings.
- Four-scheme test gate: all green (iOS Debug 2275, macOS Debug 2262, iOS Research 2438,
  macOS Research 2424–2425 — see `PF-086` for why that last figure is a range).

- `Peach (Release)` archive → **Validate App passed** (Michael, 2026-08-08), with no entitlement
  complaint. Confirms the five-key `hardened-process` set is well-formed for **iOS** distribution.
  Not evidence for macOS — see the caveat below.

- Audio and MIDI listening test → **passed** (Michael, 2026-08-08), **on a physical iOS device**:
  Grand Piano and Sine Wave at `noteDuration = 1 s`; no dropouts, clicks, stuck notes or latency
  change; MIDI pitch-bend input still drives a Match discipline. Archive validation checks the
  entitlement *shape*, not the runtime effect of `hardened-heap` and `platform-restrictions` under
  a real-time render callback — those are different questions and only the second one can catch a
  dropout. The device matters: the iOS Simulator does not enforce `com.apple.security.hardened-process`,
  and the four-scheme test gate's iOS halves run on the Simulator, so the gate cannot substitute
  for this check.

**Still unverified — the macOS runtime path.** Every verification above was performed on iOS
(`lipo`, `codesign`, the `Peach (Release)` archive, the listening test). The same target ships
macOS (`SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx"`) and the same entitlements apply
there, but no signed macOS product was validated and no listening test was run on the Mac build.
Note the asymmetry: the Guideline 2.4.5(i) rejection report that motivated validating at all is
*Mac App Store*-only, so the platform whose risk drove the check is the one not covered. Epic 74
should not assume this file is already proven correct for macOS.

Related open question for Epic 74: whether these runtime protections are in force on macOS at all
while `ENABLE_HARDENED_RUNTIME = NO`. The deferral below is argued purely on App Store *compliance*
grounds; whether Hardened Runtime is also a precondition for *efficacy* on macOS was not
established either way.
