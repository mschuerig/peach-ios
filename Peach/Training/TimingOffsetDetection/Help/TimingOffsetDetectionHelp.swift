import Foundation

enum TimingOffsetDetectionHelp {
    /// Help shown on the timing offset detection training screen.
    static let trainingScreen: [HelpSection] = [
        HelpSection(
            title: String(localized: "Goal"),
            body: String(localized: "You'll hear a repeating four-note pattern. One of the four notes in each cycle may arrive slightly **early** or **late** — choose which one in Settings. Your job is to decide which it was.")
        ),
        HelpSection(
            title: String(localized: "Controls"),
            body: String(localized: "Tap **Early** or **Late** as soon as you decide — you don't need to wait for the pattern to stop. By default the pattern repeats until you answer; you can cap the repetitions in Settings.")
        ),
        HelpSection(
            title: String(localized: "Feedback"),
            body: String(localized: "After each answer you'll see a **checkmark** (correct) or **X** (incorrect), along with the current difficulty as a percentage.")
        ),
        HelpSection(
            title: String(localized: "Difficulty"),
            body: String(localized: "The percentage shows how far off-beat the last note was — a smaller number means a harder challenge. Your **session best** tracks the smallest offset you answered correctly.")
        ),
    ]

    static let offsetNotePositionSettingsHelp: [HelpSection] = [
        HelpSection(
            title: String(localized: "Offset Note Position"),
            body: String(localized: "**Offset Note Position** chooses which of the four 16th notes in the pattern arrives slightly early or late on each trial. The other three notes stay exactly on the beat.")
        ),
    ]

    /// Help for the maximum-repetitions settings section. Joined onto the
    /// inherited tempo help by ``TimingOffsetDetectionDiscipline/settingsHelp``
    /// so the Help sheet documents the TOD-specific setting alongside the
    /// shared rhythm tempo setting.
    static let maxRepetitionsSettingsHelp: [HelpSection] = [
        HelpSection(
            title: String(localized: "Maximum Repetitions"),
            body: String(localized: "**Maximum Repetitions** caps how many times the pattern repeats per trial before the audio stops. You can still answer after the audio stops. At **∞**, the pattern keeps repeating until you submit a direction. Pick **1** if you want to restore the single-pattern challenge.")
        ),
    ]
}
