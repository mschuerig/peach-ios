import Foundation

/// Stable identifier for a training discipline.
///
/// Identity is the `slug` string. Named instances (`.unisonPitchDiscrimination`,
/// `.timingOffsetDetection`, …) are declared in `App/Training/DisciplineIDs.swift`
/// — Core owns only the identifier shape; App owns the identity catalog.
struct TrainingDisciplineID: Hashable, Sendable, Codable {
    let slug: String

    nonisolated init(_ slug: String) {
        self.slug = slug
    }

    var config: TrainingDisciplineConfig {
        TrainingDisciplineRegistry.shared[self].config
    }

    var statisticsKeys: [StatisticsKey] {
        TrainingDisciplineRegistry.shared[self].statisticsKeys
    }
}
