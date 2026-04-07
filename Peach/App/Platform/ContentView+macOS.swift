#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.trainingLifecycle) private var lifecycle
    @Environment(\.settingsCoordinator) private var coordinator

    @State private var navigationPath: [NavigationDestination] = []
    @State private var commandState = MenuCommandState()
    @State private var mainWindow: NSWindow?
    @State private var importParseResult: CSVImportParser.ImportResult?
    @State private var importParseError: String?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            StartScreen()
        }
        .frame(minWidth: 400, minHeight: 500)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            lifecycle.handleScenePhase(old: oldPhase, new: newPhase)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            lifecycle.handleAppDeactivated()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            lifecycle.handleAppActivated()
        }
        .focusedSceneValue(commandState)
        .onAppear {
            commandState.settingsCoordinator = coordinator
            commandState.trainingLifecycle = lifecycle
        }
        .background(MainWindowReader(window: $mainWindow))
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            guard let window = notification.object as? NSWindow,
                  window === mainWindow else { return }
            NSApp.terminate(nil)
        }
        .onChange(of: commandState.navigationRequest) {
            guard let request = commandState.navigationRequest else { return }
            lifecycle.navigate(to: request.destination)
        }
        .onChange(of: lifecycle.resolvedNavigation) {
            guard let resolved = lifecycle.resolvedNavigation else { return }
            navigationPath = [resolved.destination]
        }
        .fileImporter(
            isPresented: $commandState.showFileImporter,
            allowedContentTypes: [.commaSeparatedText]
        ) { handleImportFileResult($0) }
        .importDialog(parseResult: $importParseResult, parseErrorMessage: $importParseError)
    }

    // MARK: - File Import

    private func handleImportFileResult(_ result: Result<URL, any Error>) {
        switch result {
        case .success(let url):
            switch coordinator.prepareImport(url: url) {
            case .success(let parseResult):
                importParseResult = parseResult
            case .failure(let message):
                importParseError = message
            }
        case .failure(let error):
            importParseError = error.localizedDescription
        }
    }
}

private struct MainWindowReader: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.window = view.window
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if window == nil {
            DispatchQueue.main.async {
                self.window = nsView.window
            }
        }
    }
}

#Preview {
    ContentView()
        .previewEnvironment()
}
#endif
