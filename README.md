# Peach

Peach is a pitch discrimination ear training app for iOS. It helps musicians improve their ability to detect fine pitch differences through rapid, reflexive two-note comparisons.

[![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/de/app/peach-geh%C3%B6rtrainer/id6773384465)

**Repository:** https://github.com/mschuerig/peach-ios

**Author:** Michael Schürig

## Project Status

Peach is available on the App Store and in **active early development**. The core training loop, adaptive algorithm, and profile system are implemented and functional. It targets **iOS 26+** and requires Xcode 26.3+ to build.

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
- iOS 26.0+ / macOS 26.0+

## Building

Open `Peach.xcodeproj` in Xcode and run (Cmd+R), or build from the command line:

```bash
bin/build.sh            # iOS Simulator (default)
bin/build.sh -p mac     # macOS
```

## Running Tests

```bash
bin/test.sh             # iOS Simulator (default)
bin/test.sh -p mac      # macOS
```

Both platforms must pass before committing.

### Stress Tests

SoundFont preset stress tests are skipped by default. To run them:

```bash
bin/test.sh -S          # stress tests only
bin/test.sh -a          # all tests including stress tests
```

## Tech Stack

- Swift 6 (strict concurrency), SwiftUI
- SwiftData for persistence
- AVAudioEngine with SoundFont (SF2) instrument playback
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
/agent-music-domain-expert
```

His commands:
- **[AA] Audit Assumptions** — Review code or specs for hidden musical assumptions
- **[VI] Validate Implementation** — Check an implementation against musical reality
- **[CM] Concept Map** — Generate a domain concept map for a musical topic

Adam is most valuable during planning sessions, where he can review stories, epics, and specifications before implementation begins. He catches domain-level errors that developers wouldn't know to look for.

## Installing & Updating BMad

This project is developed with the [BMad method](https://docs.bmad-method.org/). BMad lives under `_bmad/` and deploys its agent skills to `.claude/skills/`; both are git-ignored **except** the manifest (`_bmad/_config/manifest.yaml`) and module configs, which are committed so the installed module set is reproducible.

Two **custom agents** are maintained in a separate repository — [mschuerig/claude-plugins](https://github.com/mschuerig/claude-plugins) — and installed here as BMad custom modules:

- **Adam** — Music Domain Expert (`/agent-music-domain-expert`); see [above](#music-domain-expert-adam).
- **Gernot** — arc42 Documentation Architect (`/agent-arc42-documentation-architect`), for creating and maintaining architecture documentation.

All commands below run from the project root.

### Install BMad (first time)

```bash
npx bmad-method install
```

Select the modules to install when prompted. This populates `_bmad/` and deploys the agent skills into `.claude/skills/`.

### Update BMad

⚠️ **Use Quick Update, not "Modify".** Run the installer and choose **Quick Update** (the first menu option), or run it non-interactively:

```bash
npx bmad-method install --action quick-update
```

Do **not** use the "Modify BMAD Installation" flow (`--action update`) for a routine update: it removes any module you don't re-select, and the external modules (`bmb`, `cis`, `tea`) and the custom agents **cannot** be re-selected from the menu — so they get wiped. Quick Update preserves every installed module and only refreshes them.

### Install or update the custom agents

The custom agents are installed from the `claude-plugins` repo. Use this after a fresh BMad install, or to pull new versions of Adam and Gernot:

```bash
npx bmad-method install --action update --yes \
  --custom-source "https://github.com/mschuerig/claude-plugins/tree/v1.0.0/bmad/arc42-documentation-architect,https://github.com/mschuerig/claude-plugins/tree/v1.0.0/bmad/music-domain-expert"
```

⚠️ **`--yes` is required.** Without it, `--custom-source` clears the module selection and drops every other module. With `--yes`, the installer keeps all installed modules and adds the custom agents on top. Swap `/tree/v1.0.0/` for `/tree/main/` (or omit it) to track the latest commit instead of the pinned release.

Restart the Claude Code session afterward so the new skills load, then verify with `/bmad-help` or by activating an agent.

## Feature Flags

| Flag | Location | Default | Description |
|------|----------|---------|-------------|
| `chartExpansionEnabled` | `ProgressChartView` | `false` | Tap-to-expand chart buckets into finer granularity. Disabled because the interaction lacks visual feedback — the chart changes shape on tap without indicating what expanded or why. The data layer (`subBuckets` API) is fully implemented and tested. Re-enable when a clear UX direction is established. |

## License

Source code is licensed under the [MIT License](LICENSE).

Audio samples and other media assets that may be added in the future could be covered by separate licenses. See [NOTICE](NOTICE) for third-party attribution details.
