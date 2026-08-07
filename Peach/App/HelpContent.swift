import Foundation

enum HelpContent {
    /// Always-on common help for the Settings screen. Per-discipline help is
    /// contributed by each ``TrainingDisciplineUI`` and spliced in by
    /// ``settingsHelpSections()``.
    private static let commonSettings: [HelpSection] = [
        HelpSection(
            title: String(localized: "Training Range"),
            body: String(localized: "Set the **lowest** and **highest note** for your training. A wider range is more challenging. If you're just starting out, try a smaller range and expand it as your ear improves.")
        ),
        HelpSection(
            title: String(localized: "Intervals"),
            body: String(localized: "Intervals are the distance between two notes. Choose which intervals you want to practice. Start with a few and add more as you gain confidence.")
        ),
        HelpSection(
            title: String(localized: "Sound"),
            body: String(localized: "Pick the **sound** you want to train with — each instrument has a different character.\n\n**Duration** controls how long each note plays.\n\n**Concert Pitch** sets the reference tuning. Most musicians use 440 Hz. Some orchestras tune to 442 Hz.\n\n**Tuning System** determines how intervals are calculated. Equal Temperament divides the octave into 12 equal steps and is standard for most Western music. Just Intonation uses pure frequency ratios and sounds smoother for some intervals.")
        ),
        HelpSection(
            title: String(localized: "Difficulty"),
            body: String(localized: "**Vary Loudness** changes the volume of notes randomly. This makes training harder but more realistic — in real music, notes are rarely played at the same volume.\n\n**Note Gap** adds a pause between the two notes in pitch comparison. At zero, notes play back-to-back.")
        ),
    ]

    private static let dataSettingsHelp = HelpSection(
        title: String(localized: "Data"),
        body: String(localized: "**Export** saves your training data as a file you can keep as a backup or transfer to another device.\n\n**Import** loads training data from a file. You can replace your current data or merge it with existing records.\n\n**Reset** permanently deletes all training data and resets your profile. This cannot be undone.")
    )

    /// Always-on common help for the Profile screen. Per-discipline help is
    /// contributed by each ``TrainingDisciplineUI`` and spliced in by
    /// ``profileHelpSections()``.
    private static let commonProfile: [HelpSection] = [
        HelpSection(
            title: String(localized: "Your Progress Chart",
                          comment: "Chart overview help title"),
            body: String(localized: "This chart shows how your pitch perception is developing over time.",
                         comment: "Chart overview help body")
        ),
        HelpSection(
            title: String(localized: "Trend Line",
                          comment: "EWMA line help title"),
            body: String(localized: "The blue line shows your smoothed average — it filters out random ups and downs to reveal your real progress.",
                         comment: "EWMA line help body")
        ),
        HelpSection(
            title: String(localized: "Variability Band",
                          comment: "Stddev band help title"),
            body: String(localized: "The shaded area around the line shows how consistent you are — a narrower band means more reliable results.",
                         comment: "Stddev band help body")
        ),
        HelpSection(
            title: String(localized: "Target Baseline",
                          comment: "Baseline help title"),
            body: String(localized: "The green dashed line is your goal — as the trend line approaches it, your ear is getting sharper.",
                         comment: "Baseline help body")
        ),
        HelpSection(
            title: String(localized: "Time Zones",
                          comment: "Granularity zone help title"),
            body: String(localized: "The chart groups your data by time: months on the left, recent days in the middle, and today's sessions on the right.",
                         comment: "Granularity zone help body")
        ),
    ]

    /// Assembled Settings help: common sections, then each registered
    /// discipline's ``TrainingDisciplineUI/settingsHelp`` in registration
    /// order, then the trailing Data section. Identical entries declared by
    /// multiple disciplines (e.g. the rhythm tempo help mirrored by both
    /// rhythm disciplines) render once.
    static func settingsHelpSections() -> [HelpSection] {
        var sections = commonSettings
        sections.append(contentsOf: dedupedDisciplineHelp(\.settingsHelp))
        sections.append(dataSettingsHelp)
        return sections
    }

    /// Assembled Profile help: common sections, then each registered
    /// discipline's ``TrainingDisciplineUI/profileHelp`` in registration
    /// order. Identical entries declared by multiple disciplines render once.
    static func profileHelpSections() -> [HelpSection] {
        var sections = commonProfile
        sections.append(contentsOf: dedupedDisciplineHelp(\.profileHelp))
        return sections
    }

    /// Concatenates the per-discipline help at `keyPath` in registration
    /// order, dropping later entries whose `(title, body)` already appeared.
    /// Content-based dedup lets multiple disciplines safely declare the
    /// same shared section without aggregators needing to know which
    /// discipline "owns" it.
    private static func dedupedDisciplineHelp(
        _ keyPath: KeyPath<any TrainingDisciplineUI, [HelpSection]>
    ) -> [HelpSection] {
        var seen: Set<String> = []
        var result: [HelpSection] = []
        for discipline in TrainingDisciplineRegistry.shared.allUI {
            for section in discipline[keyPath: keyPath] {
                let key = "\(section.title)|\(section.body)"
                if seen.insert(key).inserted {
                    result.append(section)
                }
            }
        }
        return result
    }

    static let appDescription = String(localized: "Peach helps you train your ear for music. Practice hearing the difference between notes, matching pitches accurately, and judging the timing of notes in a rhythmic pattern.")

    /// Markdown body for the "Training Disciplines" section of the Info screen.
    /// Generated once from the registry at first access: one paragraph per
    /// registered discipline, grouped by category. The registry's contents do
    /// not change after bootstrap, so this is safe to cache.
    static let trainingDisciplinesDescription: String = {
        let registry = TrainingDisciplineRegistry.shared
        var paragraphs: [String] = []
        for category in registry.activeCategories {
            for discipline in registry.disciplines(in: category) {
                let config = discipline.config
                paragraphs.append("**\(config.displayName)** – \(config.helpDescription)")
            }
        }
        return paragraphs.joined(separator: "\n\n")
    }()

    static let gettingStartedText = String(localized: "Just pick a discipline on the home screen and start practicing. Peach adapts to your skill level automatically.")

    static let acknowledgmentsText = String(localized: "Piano sounds from [FluidR3_GM by Frank Wen](https://member.keymusician.com/Member/FluidR3_GM/index.html) (MIT License). All other sounds from [GeneralUser GS by S. Christian Collins](https://schristiancollins.com/generaluser.php).")

    static var info: [HelpSection] {
        [
            HelpSection(
                title: String(localized: "What is Peach?"),
                body: appDescription
            ),
            HelpSection(
                title: String(localized: "Training Disciplines"),
                body: trainingDisciplinesDescription
            ),
            HelpSection(
                title: String(localized: "Getting Started"),
                body: gettingStartedText
            ),
        ]
    }

    static let acknowledgments: [HelpSection] = [
        HelpSection(
            title: String(localized: "Acknowledgments"),
            body: acknowledgmentsText
        ),
    ]

    static var about: [HelpSection] { info + acknowledgments }
}
