import SwiftUI

struct ImportDialogModifier: ViewModifier {
    @Environment(\.settingsCoordinator) private var coordinator

    @Binding var parseResult: CSVImportParser.ImportResult?
    @Binding var parseErrorMessage: String?

    @State private var showModeChoice = false
    @State private var showSummary = false
    @State private var summary: TrainingDataImporter.ImportSummary?
    @State private var showError = false
    @State private var errorMessage = ""

    func body(content: Content) -> some View {
        content
            .onChange(of: parseResult != nil) {
                if parseResult != nil {
                    showModeChoice = true
                }
            }
            .onChange(of: parseErrorMessage) {
                if let message = parseErrorMessage {
                    errorMessage = message
                    showError = true
                    parseErrorMessage = nil
                }
            }
            .confirmationDialog("Import Training Data", isPresented: $showModeChoice, titleVisibility: .visible) {
                Button("Replace All Data", role: .destructive) {
                    completeImport(mode: .replace)
                }
                Button("Merge with Existing Data") {
                    completeImport(mode: .merge)
                }
            } message: {
                Text("Replace deletes all existing data first. Merge keeps existing data and skips duplicates.")
            }
            .alert("Import Complete", isPresented: $showSummary) {
                Button("OK") { }
            } message: {
                if let summary {
                    Text(coordinator.formatImportSummary(summary))
                }
            }
            .alert("Import Failed", isPresented: $showError) {
                Button("OK") { }
            } message: { Text(errorMessage) }
    }

    private func completeImport(mode: TrainingDataImporter.ImportMode) {
        guard let parseResult else { return }
        do {
            let result = try coordinator.executeImport(parseResult: parseResult, mode: mode)
            summary = result
            showSummary = true
        } catch {
            errorMessage = String(localized: "Could not import the training data. Please try again.")
            showError = true
        }
        self.parseResult = nil
    }
}

extension View {
    func importDialog(
        parseResult: Binding<CSVImportParser.ImportResult?>,
        parseErrorMessage: Binding<String?>
    ) -> some View {
        modifier(ImportDialogModifier(parseResult: parseResult, parseErrorMessage: parseErrorMessage))
    }
}
