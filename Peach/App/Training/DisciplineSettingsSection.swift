import SwiftUI

/// A single ``Section`` a ``TrainingDisciplineUI`` contributes to
/// ``SettingsScreen``, identified by a stable string id.
///
/// The id distinguishes sections by purpose, not by declaring discipline:
/// the rhythm tempo section carries the same id whether it is contributed
/// by ``ContinuousRhythmMatchingDiscipline`` or
/// ``TimingOffsetDetectionDiscipline``. The aggregating screen renders
/// each id once, in registration order, so disciplines may freely declare
/// shared sections without producing duplicates.
struct DisciplineSettingsSection: Identifiable {
    let id: String
    let view: AnyView

    init<V: View>(id: String, @ViewBuilder view: () -> V) {
        self.id = id
        self.view = AnyView(view())
    }

    /// Flattens each discipline's contributed sections in registration order,
    /// keeping the first declaration of each id. This is the aggregation
    /// rule used by ``SettingsScreen``; exposing it as a static helper lets
    /// tests pin the ordering and dedup behavior without instantiating the
    /// view.
    static func aggregated(from disciplines: [any TrainingDisciplineUI]) -> [DisciplineSettingsSection] {
        var seen: Set<String> = []
        var result: [DisciplineSettingsSection] = []
        for discipline in disciplines {
            for section in discipline.settingsSections where seen.insert(section.id).inserted {
                result.append(section)
            }
        }
        return result
    }
}
