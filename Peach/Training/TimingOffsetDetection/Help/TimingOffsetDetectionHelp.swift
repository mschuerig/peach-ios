import Foundation

enum TimingOffsetDetectionHelp {
    /// Help shown on the timing offset detection training screen.
    static let trainingScreen: [HelpSection] = [
        HelpSection(
            title: String(localized: "Goal"),
            body: String(localized: "You'll hear four clicks — a short rhythmic pattern. The **third** click may arrive slightly **early** or **late**. Your job is to decide which one it was.")
        ),
        HelpSection(
            title: String(localized: "Controls"),
            body: String(localized: "Once the pattern finishes, the **Early** and **Late** buttons become active. Tap the one that matches what you heard.")
        ),
        HelpSection(
            title: String(localized: "Feedback"),
            body: String(localized: "After each answer you'll see a **checkmark** (correct) or **X** (incorrect), along with the current difficulty as a percentage.")
        ),
        HelpSection(
            title: String(localized: "Difficulty"),
            body: String(localized: "The percentage shows how far off-beat the last click was — a smaller number means a harder challenge. Your **session best** tracks the smallest offset you answered correctly.")
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
