import Foundation

nonisolated struct ContinuousRhythmMatchingPayload: TrainingDisciplinePayload, Equatable {
    static let disciplineIdentifier = "continuousRhythmMatching"
    static let currentPayloadVersion = 1

    var tempoBPM: Int
    var meanOffsetMs: Double
    var meanOffsetMsPosition0: Double?
    var meanOffsetMsPosition1: Double?
    var meanOffsetMsPosition2: Double?
    var meanOffsetMsPosition3: Double?
}
