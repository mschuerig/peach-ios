import SwiftUI
import UniformTypeIdentifiers

struct SettingsScreen: View {
    @AppStorage(SettingsKeys.noteRangeMin)
    private var noteRangeMin: Int = SettingsKeys.defaultNoteRangeMin

    @AppStorage(SettingsKeys.noteRangeMax)
    private var noteRangeMax: Int = SettingsKeys.defaultNoteRangeMax

    @AppStorage(SettingsKeys.noteDuration)
    private var noteDuration: Double = SettingsKeys.defaultNoteDuration

    @AppStorage(SettingsKeys.referencePitch)
    private var referencePitch: Double = SettingsKeys.defaultReferencePitch

    @AppStorage(SettingsKeys.soundSource)
    private var soundSource: String = SettingsKeys.defaultSoundSource

    @AppStorage(SettingsKeys.varyLoudness)
    private var varyLoudness: Double = SettingsKeys.defaultVaryLoudness

    @AppStorage(SettingsKeys.intervals)
    private var intervalSelection = IntervalSelection.default

    @AppStorage(SettingsKeys.tuningSystem)
    private var tuningSystemIdentifier: String = SettingsKeys.defaultTuningSystem

    @Environment(\.dataStoreResetter) private var dataStoreResetter
    @Environment(\.soundSourceProvider) private var soundSourceProvider
    @Environment(\.trainingDataExportAction) private var trainingDataExportAction
    @Environment(\.trainingDataImportAction) private var trainingDataImportAction

    @State private var showResetConfirmation = false
    @State private var showResetError = false
    @State private var csvExportItem: CSVExportItem?
    @State private var showExportError = false
    @State private var showFileImporter = false
    @State private var importParseResult: CSVImportParser.ImportResult?
    @State private var showImportModeChoice = false
    @State private var showImportSummary = false
    @State private var importSummary: TrainingDataImporter.ImportSummary?
    @State private var showImportError = false
    @State private var importErrorMessage = ""

    var body: some View {
        Form {
            trainingRangeSection
            intervalSection
            soundSection
            difficultySection
            dataSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !soundSourceProvider.availableSources.contains(where: { $0.rawValue == soundSource }) {
                soundSource = SettingsKeys.defaultSoundSource
            }
            prepareExport()
        }
        .alert("Reset Failed", isPresented: $showResetError) {
            Button("OK") { }
        } message: {
            Text("Could not delete training records. Please try again.")
        }
        .alert("Export Failed", isPresented: $showExportError) {
            Button("OK") { }
        } message: {
            Text("Could not export training data. Please try again.")
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.commaSeparatedText]
        ) { result in
            handleFileSelection(result)
        }
        .confirmationDialog(
            "Import Training Data",
            isPresented: $showImportModeChoice,
            titleVisibility: .visible
        ) {
            Button("Replace All Data", role: .destructive) {
                performImport(mode: .replace)
            }
            Button("Merge with Existing Data") {
                performImport(mode: .merge)
            }
        } message: {
            Text("Replace deletes all existing data first. Merge keeps existing data and skips duplicates.")
        }
        .alert("Import Complete", isPresented: $showImportSummary) {
            Button("OK") { }
        } message: {
            if let summary = importSummary {
                Text(importSummaryMessage(summary))
            }
        }
        .alert("Import Failed", isPresented: $showImportError) {
            Button("OK") { }
        } message: {
            Text(importErrorMessage)
        }
    }

    // MARK: - Sections

    private var trainingRangeSection: some View {
        Section(String(localized: "Training Range")) {
            Stepper(
                "Lower: \(PianoKeyboardLayout.noteName(midiNote: noteRangeMin))",
                value: $noteRangeMin,
                in: SettingsKeys.lowerBoundRange(noteRangeMax: noteRangeMax),
                step: 1
            )
            Stepper(
                "Upper: \(PianoKeyboardLayout.noteName(midiNote: noteRangeMax))",
                value: $noteRangeMax,
                in: SettingsKeys.upperBoundRange(noteRangeMin: noteRangeMin),
                step: 1
            )
        }
    }

    private var intervalSection: some View {
        Section {
            IntervalSelectorView(selection: $intervalSelection)
        } header: {
            Text(String(localized: "Intervals"))
        } footer: {
            Text(String(localized: "Select which intervals to practice. At least one must remain active."))
        }
    }

    private var soundSection: some View {
        Section {
            Picker(String(localized: "Sound Source"), selection: validatedSoundSource) {
                ForEach(soundSourceProvider.availableSources, id: \.self) { source in
                    Text(soundSourceProvider.displayName(for: source)).tag(source.rawValue)
                }
            }
            Stepper(
                "Duration: \(noteDuration, specifier: "%.1f")s",
                value: $noteDuration,
                in: 0.3...3.0,
                step: 0.1
            )
            Stepper(
                "Reference Pitch: \(Int(referencePitch)) Hz",
                value: $referencePitch,
                in: 380...500,
                step: 1
            )
            Picker(String(localized: "Tuning System"), selection: $tuningSystemIdentifier) {
                ForEach(TuningSystem.allCases, id: \.self) { system in
                    Text(system.displayName).tag(system.identifier)
                }
            }
        } header: {
            Text(String(localized: "Sound"))
        } footer: {
            Text(String(localized: "Select how intervals are tuned. Equal Temperament divides the octave into 12 equal steps. Just Intonation uses pure frequency ratios."))
        }
    }

    private var validatedSoundSource: Binding<String> {
        Binding(
            get: {
                let current = soundSource
                if !soundSourceProvider.availableSources.contains(where: { $0.rawValue == current }) {
                    return SettingsKeys.defaultSoundSource
                }
                return current
            },
            set: { newValue in
                soundSource = newValue
            }
        )
    }

    private var difficultySection: some View {
        Section(String(localized: "Difficulty")) {
            VStack(alignment: .leading) {
                Text("Vary Loudness")
                Slider(value: $varyLoudness, in: 0...1) {
                    Text("Vary Loudness")
                } minimumValueLabel: {
                    Text("Off")
                } maximumValueLabel: {
                    Text("Max")
                }
            }
        }
    }

    private var dataSection: some View {
        Section("Data") {
            if let csvExportItem {
                ShareLink(
                    item: csvExportItem,
                    preview: SharePreview("Peach Training Data", image: Image(systemName: "doc.text"))
                ) {
                    Label("Export Training Data", systemImage: "square.and.arrow.up")
                }
            } else {
                Label("Export Training Data", systemImage: "square.and.arrow.up")
                    .foregroundStyle(.secondary)
            }

            Button {
                showFileImporter = true
            } label: {
                Label("Import Training Data", systemImage: "square.and.arrow.down")
            }

            Button("Reset All Training Data", role: .destructive) {
                showResetConfirmation = true
            }
            .confirmationDialog(
                "Reset Training Data",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    resetAllTrainingData()
                }
            } message: {
                Text("This will permanently delete all training data and reset your profile. This cannot be undone.")
            }
        }
    }

    // MARK: - Actions

    private func resetAllTrainingData() {
        do {
            try dataStoreResetter?()
            csvExportItem = nil
        } catch {
            showResetError = true
        }
    }

    private func handleFileSelection(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                importErrorMessage = String(localized: "Could not access the selected file.")
                showImportError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let csvString = try String(contentsOf: url, encoding: .utf8)
                let parseResult = CSVImportParser.parse(csvString)
                if parseResult.comparisons.isEmpty && parseResult.pitchMatchings.isEmpty {
                    if parseResult.errors.isEmpty {
                        importErrorMessage = String(localized: "The file contains no valid training data.")
                    } else {
                        let details = parseResult.errors.prefix(5).map { $0.errorDescription ?? "" }.joined(separator: "\n")
                        importErrorMessage = String(localized: "The file contains no valid training data.") + "\n\n" + details
                    }
                    showImportError = true
                    return
                }
                importParseResult = parseResult
                showImportModeChoice = true
            } catch {
                importErrorMessage = String(localized: "Could not read the selected file.")
                showImportError = true
            }
        case .failure:
            break
        }
    }

    private func performImport(mode: TrainingDataImporter.ImportMode) {
        guard let parseResult = importParseResult else { return }
        do {
            let summary = try trainingDataImportAction?(parseResult, mode)
            importSummary = summary
            showImportSummary = true
            prepareExport()
        } catch {
            importErrorMessage = String(localized: "Could not import the training data. Please try again.")
            showImportError = true
        }
        importParseResult = nil
    }

    private func importSummaryMessage(_ summary: TrainingDataImporter.ImportSummary) -> String {
        var parts: [String] = []
        parts.append(String(localized: "\(summary.totalImported) records imported"))
        if summary.totalSkipped > 0 {
            parts.append(String(localized: "\(summary.totalSkipped) duplicates skipped"))
        }
        if summary.parseErrorCount > 0 {
            parts.append(String(localized: "\(summary.parseErrorCount) errors"))
        }
        return parts.joined(separator: ", ") + "."
    }

    private func prepareExport() {
        do {
            guard let csv = try trainingDataExportAction?() else { return }
            if csv != CSVExportSchema.headerRow {
                csvExportItem = CSVExportItem(csvString: csv, fileName: CSVExportItem.exportFileName())
            } else {
                csvExportItem = nil
            }
        } catch {
            showExportError = true
        }
    }
}

#Preview {
    NavigationStack {
        SettingsScreen()
    }
}
