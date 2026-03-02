# Peach

Peach is a pitch discrimination ear training app for iOS. It helps musicians improve their ability to detect fine pitch differences through rapid, reflexive two-note comparisons.

**Repository:** https://github.com/mschuerig/peach

**Author:** Michael Schürig

## Project Status

Peach is in **active early development**. The core training loop, adaptive algorithm, and profile system are implemented and functional, but the app is not yet released on the App Store. It targets **iOS 26+** and requires Xcode 26.3+ to build.

Known rough edges include a profile visualization that needs redesign, no onboarding for new users, and several UX improvements still in progress. See [future-work.md](docs/implementation-artifacts/future-work.md) for the full list of planned improvements.

## Philosophy

**Training, not testing.** Unlike traditional ear training apps that use test-and-score paradigms with gamification, Peach builds a perceptual profile of the user's hearing across their pitch range and adaptively targets weak spots. No scoring, no sessions, no guilt mechanics — every comparison makes you better.

## Features

- **Adaptive difficulty** — narrows intervals after correct answers, widens after incorrect ones, using Kazez convergence formulas
- **Weak-spot targeting** — concentrates training on notes where pitch discrimination is weakest
- **Perceptual profile** — piano keyboard visualization showing detection thresholds and confidence bands
- **Natural/Mechanical balance** — slider to control whether comparisons stay in nearby pitch regions or jump to target weak spots globally
- **Immediate feedback** — visual and haptic feedback after each comparison
- **One-handed operation** — large tap targets, full portrait and landscape support
- **iPhone and iPad** — responsive layouts for all screen sizes
- **Localization** — English and German
- **Accessibility** — VoiceOver labels, adequate color contrast, minimum 44x44pt tap targets

## Requirements

- Xcode 26.3+
- iOS 26.0+

## Building

Before the first build, download the SF2 SoundFont sample file:

```bash
./bin/download-sf2.sh
```

This downloads GeneralUser GS (~31 MB) to `.cache/` in the project root. The file is not tracked in git. You only need to run this once.

Then open `Peach.xcodeproj` in Xcode and run (Cmd+R), or build from the command line:

```bash
xcodebuild build -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Running Tests

```bash
xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'
```

### Stress Tests

SoundFont preset stress tests are skipped by default. To run them:

```bash
RUN_STRESS_TESTS=1 xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PeachTests/SoundFontPresetStressTests
```

## Tech Stack

- Swift 6 (strict concurrency), SwiftUI
- SwiftData for persistence
- AVAudioEngine for real-time sine wave synthesis
- Swift Testing framework
- Zero third-party dependencies

## Author's Note

This project has three purposes

- The obvious: Provide an app for ear training
- The ambitious: For me to gain experience with agentic software development. I'm using [Claude Code](https://code.claude.com/docs/) and the [BMad method](https://docs.bmad-method.org/) for development.
- The failing: I set out to improve my understanding and skills regarding iOS development and Swift. Not much has come of it, so far.

## Music Domain Expert (Adam)

Peach includes a BMAD agent called **Adam** — a music domain expert that serves as a consultant during development. Adam understands music theory, tuning systems, instrument idiomatics, and notation across all eras, and translates that knowledge into developer-actionable guidance.

Adam is especially useful during planning sessions, where he proactively flags hidden musical assumptions in code and specifications (e.g., implicit 12-TET encoding, heptatonic scale assumptions). He is not needed during routine implementation.

### Using Adam

Adam is installed as a BMAD agent in this project. To activate him in a Claude Code session, use the slash command:

```
/bmad-agent-music-domain-expert
```

His commands:
- **[AA] Audit Assumptions** — Review code or specs for hidden musical assumptions
- **[VI] Validate Implementation** — Check an implementation against musical reality
- **[CM] Concept Map** — Generate a domain concept map for a musical topic

Adam is most valuable during planning sessions, where he can review stories, epics, and specifications before implementation begins. He catches domain-level errors that developers wouldn't know to look for.

## License

Source code is licensed under the [MIT License](LICENSE).

Audio samples and other media assets that may be added in the future could be covered by separate licenses. See [NOTICE](NOTICE) for third-party attribution details.
