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

    @Environment(\.trainingDataStore) private var dataStore
    @Environment(\.comparisonSession) private var comparisonSession
    @Environment(\.soundFontLibrary) private var soundFontLibrary
    @Environment(\.perceptualProfile) private var profile

    @State private var showResetConfirmation = false
    @State private var showResetError = false

    var body: some View {
        Form {
            noteRangeSection
            audioSection
            instrumentSection
            dataSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Migrate legacy tags to SF2 format
            if soundSource == "sine" {
                soundSource = "sf2:8:80"
            } else if soundSource == "cello" {
                soundSource = "sf2:0:42"
            } else if soundSource.hasPrefix("sf2:"),
                      soundFontLibrary.preset(forTag: soundSource) == nil {
                soundSource = SettingsKeys.defaultSoundSource
            }
        }
        .alert("Reset Failed", isPresented: $showResetError) {
            Button("OK") { }
        } message: {
            Text("Could not delete training records. Please try again.")
        }
    }

    // MARK: - Sections

    private var noteRangeSection: some View {
        Section("Note Range") {
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

    private var audioSection: some View {
        Section("Audio") {
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

    private var instrumentSection: some View {
        Section("Instrument") {
            Picker("Sound Source", selection: validatedSoundSource) {
                ForEach(soundFontLibrary.availablePresets, id: \.tag) { preset in
                    Text(preset.name).tag(preset.tag)
                }
            }
        }
    }

    private var validatedSoundSource: Binding<String> {
        Binding(
            get: {
                let current = soundSource
                // Migrate legacy tags
                if current == "sine" {
                    return SettingsKeys.defaultSoundSource
                }
                if current == "cello" {
                    return "sf2:0:42"
                }
                // Validate sf2: tags exist in library
                if current.hasPrefix("sf2:"), soundFontLibrary.preset(forTag: current) == nil {
                    return SettingsKeys.defaultSoundSource
                }
                return current
            },
            set: { newValue in
                soundSource = newValue
            }
        )
    }

    private var dataSection: some View {
        Section("Data") {
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
        // Guard: only clear convergence/profile/trend if data deletion succeeds
        guard let dataStore else { return }
        do {
            try dataStore.deleteAll()
        } catch {
            showResetError = true
            return
        }

        comparisonSession.resetTrainingData()
        profile.resetMatching()
    }
}

#Preview {
    NavigationStack {
        SettingsScreen()
    }
}
