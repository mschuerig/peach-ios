import SwiftUI

/// Maximum-repetitions slider for ``TimingOffsetDetectionDiscipline``. Binds
/// directly to the same `@AppStorage` key that
/// ``AppTimingOffsetDetectionUserSettings`` reads from, so the discipline's
/// feature-local port and the Settings UI share a single source of truth.
///
/// Renders as a ``DiscreteStopsSlider`` snapping to the qualitative stops
/// `[1, 2, 3, 5, 10, ∞]`. The cap (``TimingOffsetDetectionSettingsKeys/defaultMaxRepetitions``)
/// is shown as `"∞"` — at this cap a TOD trial loops until the user submits
/// a direction. See ``ContinuousValueSlider`` for the Settings control taxonomy
/// this row belongs to.
struct TimingOffsetDetectionMaxRepetitionsSettingsSection: View {
    @AppStorage(TimingOffsetDetectionSettingsKeys.maxRepetitions)
    private var maxRepetitions: Int = TimingOffsetDetectionSettingsKeys.defaultMaxRepetitions

    private static let choices: [Int] = [1, 2, 3, 5, 10, TimingOffsetDetectionSettingsKeys.defaultMaxRepetitions]

    var body: some View {
        Section {
            DiscreteStopsSlider(
                label: "Maximum Repetitions",
                value: $maxRepetitions,
                stops: Self.choices,
                displayFormat: { DiscreteStopsSlider.displayMaxRepetitions($0, capValue: TimingOffsetDetectionSettingsKeys.defaultMaxRepetitions) },
                accessibilityFormat: { DiscreteStopsSlider.accessibilityMaxRepetitions($0, capValue: TimingOffsetDetectionSettingsKeys.defaultMaxRepetitions) }
            )
        } footer: {
            Text(String(localized: "At ∞, the pattern keeps repeating until you submit a direction. Pick 1 to restore the single-pattern challenge."))
        }
    }
}
