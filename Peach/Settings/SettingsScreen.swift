import SwiftUI

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

    @State private var showResetConfirmation = false
    @State private var showResetError = false
    @State private var csvExportItem: CSVExportItem?
    @State private var showExportError = false

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
