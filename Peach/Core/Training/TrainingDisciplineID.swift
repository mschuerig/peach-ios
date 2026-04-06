import Foundation

/// Stable identifier for each training discipline.
enum TrainingDisciplineID: String, CaseIterable, Sendable {
    case unisonPitchDiscrimination = "pitch-discrimination"
    case intervalPitchDiscrimination = "interval-discrimination"
    case unisonPitchMatching = "pitch-matching"
    case intervalPitchMatching = "interval-matching"
    case timingOffsetDetection = "timing-offset-detection"
    case continuousRhythmMatching = "continuous-rhythm-matching"

    var config: TrainingDisciplineConfig {
        TrainingDisciplineRegistry.shared[self].config
    }

    var statisticsKeys: [StatisticsKey] {
        TrainingDisciplineRegistry.shared[self].statisticsKeys
    }

    var slug: String { rawValue }
}
