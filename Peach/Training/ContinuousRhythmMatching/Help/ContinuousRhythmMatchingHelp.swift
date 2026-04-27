import Foundation

enum ContinuousRhythmMatchingHelp {
    /// Help shown on the continuous rhythm matching training screen.
    static let trainingScreen: [HelpSection] = [
        HelpSection(
            title: String(localized: "Goal"),
            body: String(localized: "A continuous stream of 16th notes plays — fill the gap by tapping at the right moment.")
        ),
        HelpSection(
            title: String(localized: "Controls"),
            body: String(localized: "Tap the **Tap** button when the outlined note should sound. The bold first dot marks beat one.\n\nYou can also play any key on a connected **MIDI keyboard** instead of tapping.")
        ),
        HelpSection(
            title: String(localized: "Feedback"),
            body: String(localized: "After each hit, an arrow shows whether you tapped early (←) or late (→) with the offset in milliseconds. The color indicates accuracy: **green** (precise), **yellow** (moderate), **red** (erratic). Stats update after each trial of 16 cycles.")
        ),
    ]

    /// Help for the rhythm tempo settings section. Declared separately from
    /// ``gapPositionsSettingsHelp`` so that ``TimingOffsetDetectionDiscipline``
    /// — which renders the tempo section but not the gap-positions section —
    /// can reference only the help that accompanies its settings.
    static let tempoSettingsHelp: [HelpSection] = [
        HelpSection(
            title: String(localized: "Rhythm"),
            body: String(localized: "**Tempo** controls the playback speed of rhythm patterns, measured in beats per minute (BPM). A lower tempo is easier; increase it as your timing improves.")
        ),
    ]

    /// Help for the rhythm gap-positions settings section.
    static let gapPositionsSettingsHelp: [HelpSection] = [
        HelpSection(
            title: String(localized: "Gap Positions"),
            body: String(localized: "**Gap Positions** control which subdivisions of the beat the gap can land on. Each beat is divided into four 16th-note positions: Beat (downbeat), E, And, A. Disable positions to focus on specific subdivisions.")
        ),
    ]

    /// Per-feature help shown in the Settings help sheet for
    /// ``ContinuousRhythmMatchingDiscipline``: tempo plus gap positions.
    static let settingsHelp: [HelpSection] = tempoSettingsHelp + gapPositionsSettingsHelp

    /// Per-feature help shown in the Profile help sheet for the rhythm spectrogram.
    static let profileHelp: [HelpSection] = [
        HelpSection(
            title: String(localized: "Rhythm Spectrogram",
                          comment: "Spectrogram overview help title"),
            body: String(localized: "The colored grid shows your rhythm accuracy across tempo ranges over time. Each row is a tempo range, each column a time period. The color tells you how precise your timing was.",
                         comment: "Spectrogram overview help body")
        ),
        HelpSection(
            title: String(localized: "Spectrogram Colors",
                          comment: "Spectrogram color help title"),
            body: String(localized: "Teal means excellent, green is precise, yellow is moderate, orange is loose, and red means erratic. Tap any cell for a detailed breakdown of early and late hits.",
                         comment: "Spectrogram color help body")
        ),
    ]
}
