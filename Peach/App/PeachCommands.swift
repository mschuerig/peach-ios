#if os(macOS)
import SwiftUI
import AppKit

// MARK: - Command State

@Observable
final class MenuCommandState {
    var navigationRequest: NavigationRequest?
    var helpSheetContent: HelpSheetContent?
    var showFileImporter = false
    var settingsCoordinator: SettingsCoordinator?
    var trainingLifecycle: TrainingLifecycleCoordinator?
}

// MARK: - Commands

struct PeachCommands: Commands {
    @FocusedValue(MenuCommandState.self) private var commandState
    @Environment(\.openWindow) private var openWindow
    @AppStorage(SettingsKeys.autoStartTraining) private var autoStartTraining = false

    var body: some Commands {
        CommandGroup(replacing: .newItem) { }
        CommandGroup(replacing: .singleWindowList) { }

        CommandGroup(replacing: .appSettings) {
            Button("Settings...") {
                openWindow(id: "settings")
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        trainingMenu
        profileMenu
        fileCommands
        helpCommands
    }

    // MARK: - Training Menu

    private var trainingMenu: some Commands {
        CommandMenu("Training") {
            if let lifecycle = commandState?.trainingLifecycle {
                Button(lifecycle.isTrainingActive
                       ? String(localized: "Stop Training")
                       : String(localized: "Start Training")) {
                    lifecycle.toggleTraining()
                }
                .keyboardShortcut("t", modifiers: .command)
                .disabled(lifecycle.currentTrainingDestination == nil)

                Toggle(String(localized: "Auto-Start"), isOn: $autoStartTraining)
                    .onChange(of: autoStartTraining) { _, newValue in
                        lifecycle.autoStartSetting = newValue
                    }

                Divider()
            }

            Section("Pitch") {
                Button("Compare Pitch") {
                    navigate(to: .pitchDiscrimination(isIntervalMode: false))
                }
                Button("Match Pitch") {
                    navigate(to: .pitchMatching(isIntervalMode: false))
                }
            }
            Section("Intervals") {
                Button("Compare Intervals") {
                    navigate(to: .pitchDiscrimination(isIntervalMode: true))
                }
                Button("Match Intervals") {
                    navigate(to: .pitchMatching(isIntervalMode: true))
                }
            }
            Section("Rhythm") {
                Button("Compare Timing") {
                    navigate(to: .timingOffsetDetection)
                }
                Button("Fill the Gap") {
                    navigate(to: .continuousRhythmMatching)
                }
            }
        }
    }

    // MARK: - Profile Menu

    private var profileMenu: some Commands {
        CommandMenu("Profile") {
            Button("Show Profile") {
                navigate(to: .profile)
            }
        }
    }

    // MARK: - File Commands

    private var fileCommands: some Commands {
        CommandGroup(after: .importExport) {
            Section {
                if let url = commandState?.settingsCoordinator?.exportFileURL {
                    ShareLink(
                        item: url,
                        preview: SharePreview("Peach Training Data")
                    ) {
                        Text("Export Training Data...")
                    }
                    .keyboardShortcut("e")
                } else {
                    Button("Export Training Data...") { }
                        .disabled(true)
                        .keyboardShortcut("e")
                }

                Button("Import Training Data...") {
                    commandState?.showFileImporter = true
                }
                .keyboardShortcut("i")
            }
        }
    }

    // MARK: - Help Commands

    private var helpCommands: some Commands {
        CommandGroup(replacing: .help) {
            Button("About Peach") {
                commandState?.helpSheetContent = .about
            }

            Divider()

            Button("Pitch Compare Help") {
                commandState?.helpSheetContent = .pitchDiscrimination
            }
            Button("Pitch Match Help") {
                commandState?.helpSheetContent = .pitchMatching
            }
            Button("Rhythm Compare Help") {
                commandState?.helpSheetContent = .timingOffsetDetection
            }
            Button("Fill the Gap Help") {
                commandState?.helpSheetContent = .continuousRhythmMatching
            }
        }
    }

    // MARK: - Navigation

    private func navigate(to destination: NavigationDestination) {
        commandState?.navigationRequest = NavigationRequest(destination: destination)
    }
}

// MARK: - Help Sheet Content

enum HelpSheetContent: Identifiable, Hashable {
    case about
    case pitchDiscrimination
    case pitchMatching
    case timingOffsetDetection
    case continuousRhythmMatching

    var id: Self { self }

    var title: String {
        switch self {
        case .about: String(localized: "About Peach")
        case .pitchDiscrimination: String(localized: "Pitch Compare Help")
        case .pitchMatching: String(localized: "Pitch Match Help")
        case .timingOffsetDetection: String(localized: "Rhythm Compare Help")
        case .continuousRhythmMatching: String(localized: "Fill the Gap Help")
        }
    }

    var sections: [HelpSection] {
        switch self {
        case .about:
            InfoScreen.helpSections + InfoScreen.acknowledgmentsSections
        case .pitchDiscrimination:
            PitchDiscriminationScreen.helpSections
        case .pitchMatching:
            PitchMatchingScreen.helpSections
        case .timingOffsetDetection:
            TimingOffsetDetectionScreen.helpSections
        case .continuousRhythmMatching:
            ContinuousRhythmMatchingScreen.helpSections
        }
    }
}

// MARK: - Single-Window App Configuration

func configureSingleWindowApp() {
    NSWindow.allowsAutomaticWindowTabbing = false
}
#endif
