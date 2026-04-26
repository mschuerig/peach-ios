import Foundation

extension TrainingDisciplineID {
    /// Help sections shown when the user opens the help sheet for this discipline.
    ///
    /// Lives in the App layer because ``HelpSection`` is App-layer.
    /// Unison and interval variants of the same training type share one array
    /// because the section copy already covers both modes.
    /// Adding a new discipline ID requires extending this switch.
    var helpSections: [HelpSection] {
        switch self {
        case .unisonPitchDiscrimination, .intervalPitchDiscrimination:
            HelpContent.pitchDiscrimination
        case .unisonPitchMatching, .intervalPitchMatching:
            HelpContent.pitchMatching
        case .timingOffsetDetection:
            HelpContent.timingOffsetDetection
        case .continuousRhythmMatching:
            HelpContent.continuousRhythmMatching
        default:
            preconditionFailure("Unknown TrainingDisciplineID: \(slug)")
        }
    }
}
