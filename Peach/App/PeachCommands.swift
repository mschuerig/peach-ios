#if os(macOS)
import SwiftUI
import AppKit

// MARK: - Command State

@Observable
final class MenuCommandState {
    var navigationRequest: NavigationRequest?
    var showFileImporter = false
    var settingsCoordinator: SettingsCoordinator?
    var trainingLifecycle: TrainingLifecycleCoordinator?
}

// MARK: - Commands

struct PeachCommands: Commands {
    @FocusedValue(MenuCommandState.self) private var commandState
    @Environment(\.openWindow) private var openWindow
    @AppStorage(SettingsKeys.autoStartTraining) private var autoStartTraining = SettingsKeys.defaultAutoStartTraining

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

            let currentDestination = commandState?.trainingLifecycle?.currentTrainingDestination
            Section("Pitch") {
                trainingButton("Compare Pitch", destination: .pitchDiscrimination(isIntervalMode: false), currentDestination: currentDestination)
                trainingButton("Match Pitch", destination: .pitchMatching(isIntervalMode: false), currentDestination: currentDestination)
            }
            Section("Intervals") {
                trainingButton("Compare Intervals", destination: .pitchDiscrimination(isIntervalMode: true), currentDestination: currentDestination)
                trainingButton("Match Intervals", destination: .pitchMatching(isIntervalMode: true), currentDestination: currentDestination)
            }
            Section("Rhythm") {
                trainingButton("Compare Timing", destination: .timingOffsetDetection, currentDestination: currentDestination)
                trainingButton("Fill the Gap", destination: .continuousRhythmMatching, currentDestination: currentDestination)
            }
        }
    }

    // MARK: - Profile Menu

    private var profileMenu: some Commands {
        CommandMenu("Profile") {
            Button("Show Profile") {
                navigate(to: .profile)
            }
            .keyboardShortcut("p", modifiers: .command)
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
                HelpPanelController.shared.show(
                    title: String(localized: "About Peach"),
                    view: InfoContentView()
                )
            }

            Divider()

            Button("Pitch Compare Help") {
                HelpPanelController.shared.show(content: .pitchDiscrimination)
            }
            Button("Pitch Match Help") {
                HelpPanelController.shared.show(content: .pitchMatching)
            }
            Button("Rhythm Compare Help") {
                HelpPanelController.shared.show(content: .timingOffsetDetection)
            }
            Button("Fill the Gap Help") {
                HelpPanelController.shared.show(content: .continuousRhythmMatching)
            }
        }
    }

    // MARK: - Navigation

    @ViewBuilder
    private func trainingButton(_ title: LocalizedStringKey, destination: NavigationDestination, currentDestination: NavigationDestination?) -> some View {
        let isCurrent = currentDestination == destination
        Button {
            navigate(to: destination)
        } label: {
            if isCurrent {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    private func navigate(to destination: NavigationDestination) {
        commandState?.navigationRequest = NavigationRequest(destination: destination)
    }
}

// MARK: - Help Sheet Content

enum HelpSheetContent: Identifiable, Hashable, Codable {
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
            HelpContent.about
        case .pitchDiscrimination:
            HelpContent.pitchDiscrimination
        case .pitchMatching:
            HelpContent.pitchMatching
        case .timingOffsetDetection:
            HelpContent.timingOffsetDetection
        case .continuousRhythmMatching:
            HelpContent.continuousRhythmMatching
        }
    }
}

// MARK: - Single-Window App Configuration

func configureSingleWindowApp() {
    NSWindow.allowsAutomaticWindowTabbing = false
}
#endif
