import Foundation

extension TrainingDisciplineID {
    /// Routing target for navigating to this discipline's training screen.
    ///
    /// Lives in the App layer because ``NavigationDestination`` is App-layer.
    /// Adding a new discipline ID requires extending this switch.
    var navigationDestination: NavigationDestination {
        switch self {
        case .unisonPitchDiscrimination:    .pitchDiscrimination(isIntervalMode: false)
        case .intervalPitchDiscrimination:  .pitchDiscrimination(isIntervalMode: true)
        case .unisonPitchMatching:          .pitchMatching(isIntervalMode: false)
        case .intervalPitchMatching:        .pitchMatching(isIntervalMode: true)
        case .timingOffsetDetection:        .timingOffsetDetection
        case .continuousRhythmMatching:     .continuousRhythmMatching
        default:
            preconditionFailure("Unknown TrainingDisciplineID: \(slug)")
        }
    }
}
