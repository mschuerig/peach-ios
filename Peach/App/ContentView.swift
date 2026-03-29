import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.trainingLifecycle) private var lifecycle
    @Environment(\.settingsCoordinator) private var coordinator

    @State private var navigationPath: [NavigationDestination] = []

    #if os(macOS)
    @State private var commandState = MenuCommandState()
    @State private var importParseResult: CSVImportParser.ImportResult?
    @State private var showImportModeChoice = false
    @State private var showImportSummary = false
    @State private var importSummary: TrainingDataImporter.ImportSummary?
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    #endif

    var body: some View {
        NavigationStack(path: $navigationPath) {
            StartScreen()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            lifecycle.handleScenePhase(old: oldPhase, new: newPhase) {
                navigationPath.removeAll()
            }
        }
        #if os(macOS)
        .focusedSceneValue(commandState)
        .onAppear {
            commandState.settingsCoordinator = coordinator
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            guard let window = notification.object as? NSWindow, window.isKeyWindow else { return }
            NSApp.terminate(nil)
        }
        .onChange(of: commandState.navigationRequest) {
            guard let request = commandState.navigationRequest else { return }
            navigationPath.removeAll()
            Task {
                try? await Task.sleep(for: .milliseconds(50))
                navigationPath = [request.destination]
            }
        }
        .sheet(item: $commandState.helpSheetContent) { content in
            helpSheet(for: content)
        }
        .fileImporter(
            isPresented: $commandState.showFileImporter,
            allowedContentTypes: [.commaSeparatedText]
        ) { handleImportFileResult($0) }
        .confirmationDialog("Import Training Data", isPresented: $showImportModeChoice, titleVisibility: .visible) {
            importModeButtons
        } message: {
            Text("Replace deletes all existing data first. Merge keeps existing data and skips duplicates.")
        }
        .alert("Import Complete", isPresented: $showImportSummary) {
            Button("OK") { }
        } message: { importSummaryMessage }
        .alert("Import Failed", isPresented: $showImportError) {
            Button("OK") { }
        } message: { Text(importErrorMessage) }
        #endif
    }

    // MARK: - macOS Help Sheet

    #if os(macOS)
    private func helpSheet(for content: HelpSheetContent) -> some View {
        NavigationStack {
            ScrollView {
                HelpContentView(sections: content.sections)
                    .padding()
            }
            .navigationTitle(content.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        commandState.helpSheetContent = nil
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
    #endif

    // MARK: - macOS File Import

    #if os(macOS)
    private func handleImportFileResult(_ result: Result<URL, any Error>) {
        switch result {
        case .success(let url):
            switch coordinator.prepareImport(url: url) {
            case .success(let parseResult):
                importParseResult = parseResult
                showImportModeChoice = true
            case .failure(let message):
                importErrorMessage = message
                showImportError = true
            }
        case .failure:
            break
        }
    }

    @ViewBuilder
    private var importModeButtons: some View {
        Button("Replace") {
            completeImport(mode: .replace)
        }
        Button("Merge") {
            completeImport(mode: .merge)
        }
        Button("Cancel", role: .cancel) { }
    }

    @ViewBuilder
    private var importSummaryMessage: some View {
        if let summary = importSummary {
            Text(coordinator.formatImportSummary(summary))
        }
    }

    private func completeImport(mode: TrainingDataImporter.ImportMode) {
        guard let parseResult = importParseResult else { return }
        do {
            let summary = try coordinator.executeImport(parseResult: parseResult, mode: mode)
            importSummary = summary
            showImportSummary = true
        } catch {
            importErrorMessage = error.localizedDescription
            showImportError = true
        }
    }
    #endif
}

#Preview {
    ContentView()
        .previewEnvironment()
}
