import Foundation

enum PitchMatchingHelp {
    /// Help shown on the pitch matching training screens.
    static let trainingScreen: [HelpSection] = [
        HelpSection(
            title: String(localized: "Goal"),
            body: String(localized: "You'll hear a **reference note**. Your goal is to match its pitch by sliding to the exact same frequency. The closer you get, the better your ear is becoming.")
        ),
        HelpSection(
            title: String(localized: "Controls"),
            body: String(localized: "**Touch** the slider to hear your note, then **drag** to adjust the pitch. When you think you've matched the reference, **release** the slider to lock in your answer.\n\nYou can also use a **MIDI controller** — move the pitch bend wheel to adjust the pitch continuously.")
        ),
        HelpSection(
            title: String(localized: "Feedback"),
            body: String(localized: "After each attempt, you'll see how many **cents** off you were. A smaller number means a closer match — zero would be perfect. Use the feedback to fine-tune your listening.")
        ),
        HelpSection(
            title: String(localized: "Intervals"),
            body: String(localized: "For interval training, your target pitch is a specific **musical interval** away from the reference note. Instead of matching the same note, you're matching a note that's a certain distance above or below it.")
        ),
    ]
}
