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
            let registry = TrainingDisciplineRegistry.shared
            ForEach(registry.activeCategories, id: \.self) { category in
                Section(category.localizedTitle) {
                    ForEach(registry.disciplines(in: category), id: \.id) { discipline in
                        trainingButton(
                            discipline.config.displayName,
                            destination: discipline.id.navigationDestination,
                            currentDestination: currentDestination
                        )
                    }
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
            .keyboardShortcut("p", modifiers: [.command, .shift])
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

            ForEach(TrainingDisciplineRegistry.shared.all, id: \.id) { discipline in
                Button(discipline.config.displayName) {
                    HelpPanelController.shared.show(content: .discipline(discipline.id))
                }
            }
        }
    }

    // MARK: - Navigation

    private func trainingButton(_ title: String, destination: NavigationDestination, currentDestination: NavigationDestination?) -> some View {
        Toggle(isOn: Binding(
            get: { currentDestination == destination },
            set: { newValue in
                if newValue {
                    navigate(to: destination)
                }
            }
        )) {
            Text(title)
        }
    }

    private func navigate(to destination: NavigationDestination) {
        commandState?.navigationRequest = NavigationRequest(destination: destination)
    }
}

// MARK: - Help Sheet Content

enum HelpSheetContent: Identifiable, Hashable, Codable {
    case about
    case discipline(TrainingDisciplineID)

    var id: Self { self }

    var title: String {
        switch self {
        case .about:
            String(localized: "About Peach")
        case .discipline(let id):
            TrainingDisciplineRegistry.shared[id].config.displayName
        }
    }

    var sections: [HelpSection] {
        switch self {
        case .about:
            HelpContent.about
        case .discipline(let id):
            HelpContent.sections(for: id)
        }
    }
}

// MARK: - Single-Window App Configuration

func configureSingleWindowApp() {
    NSWindow.allowsAutomaticWindowTabbing = false
}
#endif
