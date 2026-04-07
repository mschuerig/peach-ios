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
    private var intervalSelection = SettingsKeys.defaultIntervalSelection

    @AppStorage(SettingsKeys.tuningSystem)
    private var tuningSystemIdentifier: String = SettingsKeys.defaultTuningSystem.identifier

    @AppStorage(SettingsKeys.noteGap)
    private var noteGap: Double = SettingsKeys.defaultNoteGapSeconds

    @AppStorage(SettingsKeys.tempoBPM)
    private var tempoBPM: Int = SettingsKeys.defaultTempoBPM.value

    @AppStorage(SettingsKeys.enabledGapPositions)
    private var enabledGapPositionsEncoded: String = GapPositionEncoding.encode(SettingsKeys.defaultEnabledGapPositions)

    @Environment(\.soundSourceProvider) private var soundSourceProvider
    @Environment(\.settingsCoordinator) private var coordinator

    @State private var enabledGapPositions: Set<StepPosition> = []
    @State private var showHelpSheet = false
    @State private var showResetConfirmation = false
    @State private var showResetError = false
    @State private var previewTask: Task<Void, Never>?
    @State private var showFileImporter = false
    @State private var importParseResult: CSVImportParser.ImportResult?
    @State private var importParseError: String?

    static let previewDuration: Duration = .seconds(2)

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
        .platformFormStyle()
        .navigationTitle("Settings")
        .inlineNavigationBarTitle()
        .toolbar { settingsToolbar }
        .platformHelp(
            isPresented: $showHelpSheet,
            title: String(localized: "Settings Help"),
            sections: HelpContent.settings
        )
        .onAppear {
            enabledGapPositions = GapPositionEncoding.decodeWithDefault(enabledGapPositionsEncoded)
            coordinator.refreshExport()
        }
        .onChange(of: enabledGapPositions) {
            enabledGapPositionsEncoded = GapPositionEncoding.encode(enabledGapPositions)
        }
        .platformFileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.commaSeparatedText]
        ) { handleImportFileResult($0) }
        .importDialog(parseResult: $importParseResult, parseErrorMessage: $importParseError)
        .alert("Reset Failed", isPresented: $showResetError) {
            Button("OK") { }
        } message: { Text("Could not delete training records. Please try again.") }
    }

    // MARK: - Toolbar & Sheets

    @ToolbarContentBuilder
    private var settingsToolbar: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button {
                showHelpSheet = true
            } label: {
                Label("Help", systemImage: "questionmark.circle")
            }
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
                .accessibilityLabel(isPreviewPlaying ? String(localized: "Stop Preview") : String(localized: "Play Preview"))
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
                "Note Gap (Compare): \(noteGap, specifier: "%.1f")s",
                value: $noteGap,
                in: 0.0...5.0,
                step: 0.1
            )
            .accessibilityValue(Text("\(noteGap, specifier: "%.1f") seconds"))
        }
    }

    private var gapPositionsSection: some View {
        Section {
            GridToggleRow(selection: $enabledGapPositions) { position in
                "\(position.rawValue + 1)"
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
            if let url = coordinator.exportFileURL {
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
                importTrainingData()
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
            Task { await coordinator.stopSoundPreview() }
        } else {
            previewTask = Task {
                await coordinator.playSoundPreview(duration: Self.previewDuration)
                previewTask = nil
            }
        }
    }

    private func stopPreview() {
        guard previewTask != nil else { return }
        previewTask?.cancel()
        previewTask = nil
        Task { await coordinator.stopSoundPreview() }
    }

    private func resetAllTrainingData() {
        do {
            try coordinator.resetAllData()
        } catch {
            showResetError = true
        }
    }

    private func importTrainingData() {
        showFileImporter = true
    }

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

#Preview {
    NavigationStack {
        SettingsScreen()
    }
    .previewEnvironment()
}
