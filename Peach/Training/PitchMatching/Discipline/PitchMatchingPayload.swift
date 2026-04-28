import Foundation

nonisolated struct PitchMatchingPayload: TrainingDisciplinePayload, Equatable {
    static let disciplineIdentifier = "pitchMatching"
    static let currentPayloadVersion = 1

    var referenceNote: Int
    var targetNote: Int
    var initialCentOffset: Double
    var userCentError: Double
    var interval: Int
    var tuningSystem: String
}
