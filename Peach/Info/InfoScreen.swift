import SwiftUI

struct InfoScreen: View {
    @Environment(\.dismiss) private var dismiss
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"

    static let developerName = "Michael Schürig"
    static let licenseName = "MIT"
    static let copyrightYear = Calendar.current.component(.year, from: Date())
    static let gitHubURL: URL = {
        guard let url = URL(string: "https://github.com/mschuerig/peach") else {
            preconditionFailure("Invalid GitHub URL constant")
        }
        return url
    }()
    static let appDescription = String(localized: "Peach helps you train your ear for music. Practice hearing the difference between notes and learn to match pitches accurately.")

    static let trainingModesDescription = String(localized: "**Hear & Compare – Single Notes** – Listen to two notes and decide which one is higher.\n\n**Hear & Compare – Intervals** – The same idea, but with musical intervals between notes.\n\n**Tune & Match – Single Notes** – Hear a note and slide to match its pitch.\n\n**Tune & Match – Intervals** – Match pitches using musical intervals.")

    static let gettingStartedText = String(localized: "Just pick any training mode on the home screen and start practicing. Peach adapts to your skill level automatically.")

    static let acknowledgmentsText = String(localized: "Sounds provided by [GeneralUser GS by S. Christian Collins](https://schristiancollins.com/generaluser.php).")

    static var copyrightNotice: String {
        "© \(copyrightYear) \(developerName)"
    }

    static let helpSections: [HelpSection] = [
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

    static let acknowledgmentsSections: [HelpSection] = [
        HelpSection(
            title: String(localized: "Acknowledgments"),
            body: acknowledgmentsText
        ),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    HelpContentView(sections: Self.helpSections)
                    HelpContentView(sections: Self.acknowledgmentsSections)
                }
                .padding()
            }
            .navigationTitle("Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 6) {
            Text("Peach")
                .font(.largeTitle)
                .bold()

            Text("Version \(appVersion)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(verbatim: Self.copyrightNotice)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("License: \(Self.licenseName)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Link(String("GitHub"), destination: Self.gitHubURL)
                .font(.caption)
        }
    }
}

#Preview {
    InfoScreen()
}
