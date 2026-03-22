/// Uniform key for looking up per-mode, per-context training statistics.
enum StatisticsKey: Hashable, Sendable {
    case pitch(TrainingDisciplineID)
    case rhythm(TrainingDisciplineID, TempoRange, RhythmDirection)

    var statisticsConfig: StatisticsConfig {
        switch self {
        case .pitch(let mode): mode.config.statistics
        case .rhythm(let mode, _, _): mode.config.statistics
        }
    }
}
