import Foundation

enum PitchDiscriminationHelp {
    /// Help shown on the pitch comparison training screens.
    static let trainingScreen: [HelpSection] = [
        HelpSection(
            title: String(localized: "Goal"),
            body: String(localized: "Two notes play one after the other. Your job is to decide: was the **second note higher or lower** than the first? The closer the notes are, the harder it gets — and the sharper your ear becomes.")
        ),
        HelpSection(
            title: String(localized: "Controls"),
            body: String(localized: "Once the second note starts playing, the **Higher** and **Lower** buttons become active. Tap the one that matches what you heard.")
        ),
        HelpSection(
            title: String(localized: "Feedback"),
            body: String(localized: "After each answer you'll see a brief **checkmark** (correct) or **X** (incorrect). Use this to calibrate your listening — over time, you'll notice patterns in what you get right.")
        ),
        HelpSection(
            title: String(localized: "Difficulty"),
            body: String(localized: "The number at the top shows the **cent difference** between the two notes — a smaller number means a harder comparison. Your **session best** tracks the smallest difference you answered correctly.")
        ),
        HelpSection(
            title: String(localized: "Intervals"),
            body: String(localized: "For interval training, the two notes are separated by a specific **musical interval** (like a fifth or an octave) instead of a small pitch difference. You still decide which note is higher — but now you're training your sense of musical distance.")
        ),
    ]
}
