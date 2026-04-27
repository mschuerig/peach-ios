import SwiftUI

/// Tempo (BPM) stepper. Used by every rhythm discipline that overrides
/// ``TrainingDisciplineUI/settingsSections``; aggregating screens render the
/// section once per declaring discipline and rely on equal `@AppStorage`
/// keys for state coherence.
struct RhythmTempoSettingsSection: View {
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
