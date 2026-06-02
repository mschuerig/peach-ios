import SwiftUI

/// Maximum-repetitions picker for ``TimingOffsetDetectionDiscipline``. Binds
/// directly to the same `@AppStorage` key that
/// ``AppTimingOffsetDetectionUserSettings`` reads from, so the discipline's
/// feature-local port and the Settings UI share a single source of truth.
///
/// The highest offered value (``TimingOffsetDetectionSettingsKeys/defaultMaxRepetitions``)
/// is rendered as `"∞"` — at this cap a TOD trial loops until the user
/// submits a direction.
struct TimingOffsetDetectionMaxRepetitionsSettingsSection: View {
    @AppStorage(TimingOffsetDetectionSettingsKeys.maxRepetitions)
    private var maxRepetitions: Int = TimingOffsetDetectionSettingsKeys.defaultMaxRepetitions

    private static let choices: [Int] = [1, 2, 3, 5, 10, TimingOffsetDetectionSettingsKeys.defaultMaxRepetitions]

    var body: some View {
        Section {
            Picker(String(localized: "Maximum Repetitions"), selection: $maxRepetitions) {
                ForEach(Self.choices, id: \.self) { value in
                    Text(Self.label(for: value)).tag(value)
                }
            }
        } footer: {
            Text(String(localized: "At ∞, the pattern keeps repeating until you submit a direction. Pick 1 to restore the single-pattern challenge."))
        }
    }

    private static func label(for value: Int) -> String {
        value == TimingOffsetDetectionSettingsKeys.defaultMaxRepetitions ? "∞" : "\(value)"
    }
}
