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

Open `Peach.xcodeproj` in Xcode and run (Cmd+R), or build from the command line:

```bash
xcodebuild build -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Running Tests

```bash
xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'
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
- The ambitious: For me to gain experience with agentic software development. I'm using [Claude Code]([https://docs.bmad-method.org/](https://code.claude.com/docs)) and the [BMad method](https://docs.bmad-method.org/) for development.
- The failing: I set out to improve my understanding and skills regarding iOS development and Swift. Not much has come of it, so far.

## License

Source code is licensed under the [MIT License](LICENSE).

Audio samples and other media assets that may be added in the future could be covered by separate licenses. See [NOTICE](NOTICE) for third-party attribution details.
