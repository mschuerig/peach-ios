import SwiftUI
import UniformTypeIdentifiers

struct SettingsScreen: View {
    @AppStorage(SettingsKeys.noteRangeMin)
    private var noteRangeMin: Int = SettingsKeys.defaultNoteRangeMin.rawValue

    @AppStorage(SettingsKeys.noteRangeMax)
    private var noteRangeMax: Int = SettingsKeys.defaultNoteRangeMax.rawValue

    @AppStorage(SettingsKeys.noteDuration)
    private var noteDuration: Double = SettingsKeys.defaultNoteDuration.rawValue

    @AppStorage(SettingsKeys.referencePitch)
    private var referencePitch: Double = SettingsKeys.defaultReferencePitch.rawValue

    @AppStorage(SettingsKeys.soundSource)
    private var soundSource: String = SettingsKeys.defaultSoundSource

    @AppStorage(SettingsKeys.varyLoudness)
    private var varyLoudness: Double = SettingsKeys.defaultVaryLoudness.rawValue

    @AppStorage(SettingsKeys.intervals)
    private var intervalSelection = IntervalSelection.default

    @AppStorage(SettingsKeys.tuningSystem)
    private var tuningSystemIdentifier: String = SettingsKeys.defaultTuningSystem.identifier

    @AppStorage(SettingsKeys.noteGap)
    private var noteGap: Double = 0.0

    @AppStorage(SettingsKeys.tempoBPM)
    private var tempoBPM: Int = SettingsKeys.defaultTempoBPM.value

    @AppStorage(SettingsKeys.enabledGapPositions)
    private var enabledGapPositionsEncoded: String = GapPositionEncoding.encode(SettingsKeys.defaultEnabledGapPositions)

    @Environment(\.dataStoreResetter) private var dataStoreResetter
    @Environment(\.soundSourceProvider) private var soundSourceProvider
    @Environment(\.soundPreviewPlay) private var soundPreviewPlay
    @Environment(\.soundPreviewStop) private var soundPreviewStop
    @Environment(\.prepareImport) private var prepareImport
    @Environment(\.executeImport) private var executeImport
    @Environment(\.trainingDataTransferService) private var transferService

    @State private var showHelpSheet = false
    @State private var showResetConfirmation = false
    @State private var showResetError = false
    @State private var previewTask: Task<Void, Never>?
    @State private var showFileImporter = false
    @State private var importParseResult: CSVImportParser.ImportResult?
    @State private var showImportModeChoice = false
    @State private var showImportSummary = false
    @State private var importSummary: TrainingDataImporter.ImportSummary?
    @State private var showImportError = false
    @State private var importErrorMessage = ""

    static let previewDuration: Duration = .seconds(2)

    static let helpSections: [HelpSection] = [
        HelpSection(
            title: String(localized: "Training Range"),
            body: String(localized: "Set the **lowest** and **highest note** for your training. A wider range is more challenging. If you're just starting out, try a smaller range and expand it as your ear improves.")
        ),
        HelpSection(
            title: String(localized: "Intervals"),
            body: String(localized: "Intervals are the distance between two notes. Choose which intervals you want to practice. Start with a few and add more as you gain confidence.")
        ),
        HelpSection(
            title: String(localized: "Sound"),
            body: String(localized: "Pick the **sound** you want to train with — each instrument has a different character.\n\n**Duration** controls how long each note plays.\n\n**Concert Pitch** sets the reference tuning. Most musicians use 440 Hz. Some orchestras tune to 442 Hz.\n\n**Tuning System** determines how intervals are calculated. Equal Temperament divides the octave into 12 equal steps and is standard for most Western music. Just Intonation uses pure frequency ratios and sounds smoother for some intervals.")
        ),
        HelpSection(
            title: String(localized: "Difficulty"),
            body: String(localized: "**Vary Loudness** changes the volume of notes randomly. This makes training harder but more realistic — in real music, notes are rarely played at the same volume. Applies to all training modes.\n\n**Note Gap** adds a pause between the two notes in Hear & Compare training. At zero, notes play back-to-back.")
        ),
        HelpSection(
            title: String(localized: "Rhythm"),
            body: String(localized: "**Tempo** controls the speed for all rhythm training modes, measured in beats per minute (BPM). A lower tempo is easier; increase it as your timing improves.\n\n**Gap Positions** control which subdivisions of the beat are used in Fill the Gap training. Each beat is divided into four 16th-note positions: Beat (downbeat), E, And, A. Disable positions to focus on specific subdivisions.")
        ),
        HelpSection(
            title: String(localized: "Data"),
            body: String(localized: "**Export** saves your training data as a file you can keep as a backup or transfer to another device.\n\n**Import** loads training data from a file. You can replace your current data or merge it with existing records.\n\n**Reset** permanently deletes all training data and resets your profile. This cannot be undone.")
        ),
    ]

    var body: some View {
        Form {
            trainingRangeSection
            intervalSection
            soundSection
            difficultySection
            rhythmSection
            gapPositionsSection
            dataSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { settingsToolbar }
        .sheet(isPresented: $showHelpSheet) { helpSheetContent }
        .onAppear { transferService.refreshExport() }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.commaSeparatedText]
        ) { handleImportFileResult($0) }
        .confirmationDialog("Import Training Data", isPresented: $showImportModeChoice, titleVisibility: .visible) {
            importModeButtons
        } message: {
            Text("Replace deletes all existing data first. Merge keeps existing data and skips duplicates.")
        }
        .alert("Reset Failed", isPresented: $showResetError) {
            Button("OK") { }
        } message: { Text("Could not delete training records. Please try again.") }
        .alert("Import Complete", isPresented: $showImportSummary) {
            Button("OK") { }
        } message: { importSummaryMessage }
        .alert("Import Failed", isPresented: $showImportError) {
            Button("OK") { }
        } message: { Text(importErrorMessage) }
    }

    // MARK: - Toolbar & Sheets

    @ToolbarContentBuilder
    private var settingsToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showHelpSheet = true
            } label: {
                Label("Help", systemImage: "questionmark.circle")
            }
        }
    }

    private var helpSheetContent: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    HelpContentView(sections: Self.helpSections)
                }
                .padding()
            }
            .navigationTitle(String(localized: "Settings Help"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Done")) {
                        showHelpSheet = false
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var importModeButtons: some View {
        Button("Replace All Data", role: .destructive) {
            completeImport(mode: .replace)
        }
        Button("Merge with Existing Data") {
            completeImport(mode: .merge)
        }
    }

    @ViewBuilder
    private var importSummaryMessage: some View {
        if let summary = importSummary {
            Text(transferService.formatImportSummary(summary))
        }
    }

    // MARK: - Sections

    private var trainingRangeSection: some View {
        Section(String(localized: "Training Range")) {
            Stepper(
                "Lowest Note: \(MIDINote(noteRangeMin).name)",
                value: $noteRangeMin,
                in: SettingsKeys.lowerBoundRange(noteRangeMax: noteRangeMax),
                step: 1
            )
            Stepper(
                "Highest Note: \(MIDINote(noteRangeMax).name)",
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

    private var isPreviewPlaying: Bool { previewTask != nil }

    private var soundSection: some View {
        Section {
            HStack {
                Picker(String(localized: "Sound"), selection: $soundSource) {
                    ForEach(soundSourceProvider.availableSources, id: \.rawValue) { source in
                        Text(source.displayName).tag(source.rawValue)
                    }
                }
                Button {
                    togglePreview()
                } label: {
                    Image(systemName: isPreviewPlaying ? "stop.fill" : "speaker.wave.2")
                }
                .buttonStyle(.bordered)
            }
            Stepper(
                "Duration: \(noteDuration, specifier: "%.1f")s",
                value: $noteDuration,
                in: 0.3...3.0,
                step: 0.1
            )
            .accessibilityValue(Text("\(noteDuration, specifier: "%.1f") seconds"))
            Stepper(
                "Concert Pitch: \(Int(referencePitch)) Hz",
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
        .onChange(of: soundSource) {
            stopPreview()
        }
        .onDisappear {
            stopPreview()
        }
    }

    private var difficultySection: some View {
        Section(String(localized: "Difficulty")) {
            VStack(alignment: .leading) {
                Text("Vary Loudness (All Modes)")
                Slider(value: $varyLoudness, in: 0...1) {
                    Text("Vary Loudness")
                } minimumValueLabel: {
                    Text("Off")
                } maximumValueLabel: {
                    Text("Max")
                }
            }
            Stepper(
                "Note Gap (Hear & Compare): \(noteGap, specifier: "%.1f")s",
                value: $noteGap,
                in: 0.0...5.0,
                step: 0.1
            )
            .accessibilityValue(Text("\(noteGap, specifier: "%.1f") seconds"))
        }
    }

    private var enabledGapPositions: Set<StepPosition> {
        let decoded = GapPositionEncoding.decode(enabledGapPositionsEncoded)
        return decoded.isEmpty ? SettingsKeys.defaultEnabledGapPositions : decoded
    }

    private func isGapPositionEnabled(_ position: StepPosition) -> Bool {
        enabledGapPositions.contains(position)
    }

    private func isLastEnabledGapPosition(_ position: StepPosition) -> Bool {
        enabledGapPositions.count == 1 && enabledGapPositions.contains(position)
    }

    private func toggleGapPosition(_ position: StepPosition) {
        var positions = enabledGapPositions
        if positions.contains(position) {
            positions.remove(position)
        } else {
            positions.insert(position)
        }
        enabledGapPositionsEncoded = GapPositionEncoding.encode(positions)
    }

    private static let gapPositionLabels: [(position: StepPosition, label: LocalizedStringResource)] = [
        (.first, "1 — Beat"),
        (.second, "2 — E"),
        (.third, "3 — And"),
        (.fourth, "4 — A"),
    ]

    private var gapPositionsSection: some View {
        Section {
            ForEach(Self.gapPositionLabels, id: \.position) { item in
                Toggle(
                    String(localized: item.label),
                    isOn: Binding(
                        get: { isGapPositionEnabled(item.position) },
                        set: { _ in toggleGapPosition(item.position) }
                    )
                )
                .disabled(isLastEnabledGapPosition(item.position))
            }
        } header: {
            Text(String(localized: "Gap Positions"))
        } footer: {
            Text(String(localized: "Select which gap positions to practice. At least one must remain active."))
        }
    }

    private var rhythmSection: some View {
        Section(String(localized: "Rhythm")) {
            Stepper(
                "Tempo: \(tempoBPM) BPM",
                value: $tempoBPM,
                in: 40...200,
                step: 1
            )
            .accessibilityValue(Text("\(tempoBPM) beats per minute"))
        }
    }

    private var dataSection: some View {
        Section("Data") {
            if let url = transferService.exportFileURL {
                ShareLink(
                    item: url,
                    preview: SharePreview("Peach Training Data")
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

    private func togglePreview() {
        if let task = previewTask {
            task.cancel()
            previewTask = nil
            Task { await soundPreviewStop?() }
        } else {
            previewTask = Task {
                await soundPreviewPlay?(Self.previewDuration)
                previewTask = nil
            }
        }
    }

    private func stopPreview() {
        guard previewTask != nil else { return }
        previewTask?.cancel()
        previewTask = nil
        Task { await soundPreviewStop?() }
    }

    private func resetAllTrainingData() {
        do {
            try dataStoreResetter?()
        } catch {
            showResetError = true
        }
    }

    private func handleImportFileResult(_ result: Result<URL, any Error>) {
        switch result {
        case .success(let url):
            guard let prepareImport else { break }
            switch prepareImport(url) {
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

    private func completeImport(mode: TrainingDataImporter.ImportMode) {
        guard let parseResult = importParseResult, let executeImport else { return }
        do {
            let summary = try executeImport(parseResult, mode)
            importSummary = summary
            showImportSummary = true
        } catch {
            importErrorMessage = String(localized: "Could not import the training data. Please try again.")
            showImportError = true
        }
        importParseResult = nil
    }
}

#Preview {
    NavigationStack {
        SettingsScreen()
    }
}
