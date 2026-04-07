import Foundation

enum HelpContent {
    static let pitchDiscrimination: [HelpSection] = [
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
            body: String(localized: "In interval mode, the two notes are separated by a specific **musical interval** (like a fifth or an octave) instead of a small pitch difference. You still decide which note is higher — but now you're training your sense of musical distance.")
        ),
    ]

    static let pitchMatching: [HelpSection] = [
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
            body: String(localized: "In interval mode, your target pitch is a specific **musical interval** away from the reference note. Instead of matching the same note, you're matching a note that's a certain distance above or below it.")
        ),
    ]

    static let timingOffsetDetection: [HelpSection] = [
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

    static let continuousRhythmMatching: [HelpSection] = [
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

    static let settings: [HelpSection] = [
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
            body: String(localized: "**Vary Loudness** changes the volume of notes randomly. This makes training harder but more realistic — in real music, notes are rarely played at the same volume. Applies to all training modes.\n\n**Note Gap** adds a pause between the two notes in Compare training. At zero, notes play back-to-back.")
        ),
        HelpSection(
            title: String(localized: "Rhythm"),
            body: String(localized: "**Tempo** controls the speed for all rhythm training modes, measured in beats per minute (BPM). A lower tempo is easier; increase it as your timing improves.\n\n**Gap Positions** control which subdivisions of the beat are used in Fill the Gap training. Each beat is divided into four 16th-note positions: Beat (downbeat), E, And, A. Disable positions to focus on specific subdivisions.")
        ),
        HelpSection(
            title: String(localized: "Data"),
            body: String(localized: "**Export** saves your training data as a file you can keep as a backup or transfer to another device.\n\n**Import** loads training data from a file. You can replace your current data or merge it with existing records.\n\n**Reset** permanently deletes all training data and resets your profile. This cannot be undone.")
        ),
    ]

    static let profile: [HelpSection] = [
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

    static let appDescription = String(localized: "Peach helps you train your ear for music. Practice hearing the difference between notes and learn to match pitches accurately.")

    static let trainingModesDescription = String(localized: "**Compare Pitch** – Listen to two notes and decide which one is higher.\n\n**Compare Intervals** – The same idea, but with musical intervals between notes.\n\n**Match Pitch** – Hear a note and slide to match its pitch.\n\n**Match Intervals** – Match pitches using musical intervals.\n\n**Compare Rhythm** – Hear a short rhythmic pattern and decide whether the tested note was early or late.\n\n**Fill the Gap** – A continuous stream of notes plays — tap at the right moment to fill the gap.")

    static let gettingStartedText = String(localized: "Just pick any training mode on the home screen and start practicing. Peach adapts to your skill level automatically.")

    static let acknowledgmentsText = String(localized: "Piano sounds from [FluidR3_GM by Frank Wen](https://member.keymusician.com/Member/FluidR3_GM/index.html) (MIT License). All other sounds from [GeneralUser GS by S. Christian Collins](https://schristiancollins.com/generaluser.php).")

    static let info: [HelpSection] = [
        HelpSection(
            title: String(localized: "What is Peach?"),
            body: appDescription
        ),
        HelpSection(
            title: String(localized: "Training Modes"),
            body: trainingModesDescription
        ),
        HelpSection(
            title: String(localized: "Getting Started"),
            body: gettingStartedText
        ),
    ]

    static let acknowledgments: [HelpSection] = [
        HelpSection(
            title: String(localized: "Acknowledgments"),
            body: acknowledgmentsText
        ),
    ]

    static var about: [HelpSection] { info + acknowledgments }
}
