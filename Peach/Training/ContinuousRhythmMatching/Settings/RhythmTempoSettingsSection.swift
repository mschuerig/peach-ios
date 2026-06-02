import SwiftUI

/// Tempo (BPM) slider. Used by every rhythm discipline that overrides
/// ``TrainingDisciplineUI/settingsSections``; aggregating screens render the
/// section once per declaring discipline and rely on equal `@AppStorage`
/// keys for state coherence.
struct RhythmTempoSettingsSection: View {
    @AppStorage(SettingsKeys.tempoBPM)
    private var tempoBPM: Int = SettingsKeys.defaultTempoBPM.value

    var body: some View {
        Section(String(localized: "Rhythm")) {
            ContinuousValueSlider(
                label: "Tempo",
                value: $tempoBPM.asDouble,
                range: 40...200,
                step: 1,
                displayFormat: ContinuousValueSlider.displayTempo,
                accessibilityFormat: { ContinuousValueSlider.accessibilityTempo($0) }
            )
        }
    }
}

private extension Binding where Value == Int {
    /// Bridges `@AppStorage(Int)` to a `Binding<Double>` so the value can drive
    /// `Slider`, which requires `BinaryFloatingPoint`. Rounds on write to keep
    /// the stored Int aligned with the snapped slider position.
    var asDouble: Binding<Double> {
        Binding<Double>(
            get: { Double(wrappedValue) },
            set: { wrappedValue = Int($0.rounded()) }
        )
    }
}
