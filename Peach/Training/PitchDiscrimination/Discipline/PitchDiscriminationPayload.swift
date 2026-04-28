import Foundation

nonisolated struct PitchDiscriminationPayload: TrainingDisciplinePayload, Equatable {
    static let disciplineIdentifier = "pitchDiscrimination"
    static let currentPayloadVersion = 1

    var referenceNote: Int
    var targetNote: Int
    var centOffset: Double
    var isCorrect: Bool
    var interval: Int
    var tuningSystem: String
}
