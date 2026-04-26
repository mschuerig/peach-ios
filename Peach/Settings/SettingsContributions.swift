import SwiftUI

/// App-layer mapping from ``SettingsSectionKind`` — a Core enum that any
/// ``TrainingDiscipline`` may contribute via ``settingsContributions`` — to
/// the concrete SwiftUI section. Adding a new section is an additive change
/// in this file: declare the new case in ``SettingsSectionKind`` (Core) and
/// add a branch here, plus a `View` struct describing it. ``SettingsScreen``
/// itself does not need to be edited.
@ViewBuilder
func contributedSettingsSection(for kind: SettingsSectionKind) -> some View {
    switch kind {
    case .rhythmTempo:
        RhythmTempoSettingsSection()
    case .rhythmGapPositions:
        RhythmGapPositionsSettingsSection()
    }
}

private struct RhythmTempoSettingsSection: View {
    @AppStorage(SettingsKeys.tempoBPM)
    private var tempoBPM: Int = SettingsKeys.defaultTempoBPM.value

    var body: some View {
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
}

private struct RhythmGapPositionsSettingsSection: View {
    @AppStorage(SettingsKeys.enabledGapPositions)
    private var enabledGapPositionsEncoded: String = GapPositionEncoding.encode(SettingsKeys.defaultEnabledGapPositions)

    @State private var enabledGapPositions: Set<StepPosition> = []

    var body: some View {
        Section {
            GridToggleRow(selection: $enabledGapPositions) { position in
                "\(position.rawValue + 1)"
            }
        } header: {
            Text(String(localized: "Gap Positions"))
        } footer: {
            Text(String(localized: "Select which gap positions to practice. At least one must remain active."))
        }
        .onAppear {
            enabledGapPositions = GapPositionEncoding.decodeWithDefault(enabledGapPositionsEncoded)
        }
        .onChange(of: enabledGapPositions) {
            enabledGapPositionsEncoded = GapPositionEncoding.encode(enabledGapPositions)
        }
    }
}
