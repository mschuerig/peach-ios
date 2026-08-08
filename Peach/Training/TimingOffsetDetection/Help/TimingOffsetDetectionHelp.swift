import Foundation

enum TimingOffsetDetectionHelp {
    /// Help shown on the timing offset detection training screen.
    static let trainingScreen: [HelpSection] = [
        HelpSection(
            title: String(localized: "Goal"),
            body: String(localized: "You'll hear a repeating rhythmic pattern. One of the notes in the pattern arrives slightly **early** or **late** on each trial — choose which one in Settings. Your job is to decide which it was.")
        ),
        HelpSection(
            title: String(localized: "Controls"),
            body: String(localized: "Tap **Early** or **Late** as soon as you decide — you don't need to wait for the pattern to stop. By default the pattern repeats until you answer; you can cap the repetitions in Settings.")
        ),
        HelpSection(
            title: String(localized: "Feedback"),
            body: String(localized: "After each answer you'll see a **checkmark** (correct) or **X** (incorrect), along with the current difficulty in milliseconds.")
        ),
        HelpSection(
            title: String(localized: "Difficulty"),
            body: String(localized: "The offset shows how far off-beat the last note was, in milliseconds — a smaller number means a harder challenge. Your **session best** tracks the smallest offset you answered correctly.")
        ),
    ]

    static let patternPickerSettingsHelp: [HelpSection] = [
        HelpSection(
            title: String(localized: "Pattern"),
            body: String(localized: "**Pattern** picks the rhythmic figure played on each trial. Each row shows the pattern's shape as a row of dots — a large dot marks the first note (the metric anchor), smaller dots mark the other notes, and empty cells mark rests. Picking a pattern resets the Offset Note Position to that pattern's default.")
        ),
    ]

    static let offsetNotePositionSettingsHelp: [HelpSection] = [
        HelpSection(
            title: String(localized: "Offset Note Position"),
            body: String(localized: "**Offset Note Position** chooses which note in the pattern carries the timing offset on each trial. The other notes stay exactly on the beat. The first note (the metric anchor) is never selectable — the listener uses it as the reference for the early/late judgment.")
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
