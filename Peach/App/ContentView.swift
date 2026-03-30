import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.trainingLifecycle) private var lifecycle
    @Environment(\.settingsCoordinator) private var coordinator

    @State private var navigationPath: [NavigationDestination] = []

    #if os(macOS)
    @State private var commandState = MenuCommandState()
    @State private var mainWindow: NSWindow?
    @State private var importParseResult: CSVImportParser.ImportResult?
    @State private var importParseError: String?
    #endif

    var body: some View {
        NavigationStack(path: $navigationPath) {
            StartScreen()
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 500)
        #endif
        .onChange(of: scenePhase) { oldPhase, newPhase in
            lifecycle.handleScenePhase(old: oldPhase, new: newPhase)
        }
        #if os(macOS)
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
        .sheet(item: $commandState.helpSheetContent) { content in
            helpSheet(for: content)
        }
        .fileImporter(
            isPresented: $commandState.showFileImporter,
            allowedContentTypes: [.commaSeparatedText]
        ) { handleImportFileResult($0) }
        .importDialog(parseResult: $importParseResult, parseErrorMessage: $importParseError)
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
        guard case .success(let url) = result else { return }
        switch coordinator.prepareImport(url: url) {
        case .success(let parseResult):
            importParseResult = parseResult
        case .failure(let message):
            importParseError = message
        }
    }
    #endif
}

#if os(macOS)
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
#endif

#Preview {
    ContentView()
        .previewEnvironment()
}
