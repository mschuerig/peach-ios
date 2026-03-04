import SwiftUI

struct InfoScreen: View {
    @Environment(\.dismiss) private var dismiss
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"

    struct TrainingMode {
        let name: String
        let description: String
    }

    static let developerName = "Michael Schürig"
    static let licenseName = "MIT"
    static let copyrightYear = Calendar.current.component(.year, from: Date())
    static let gitHubURL: URL = {
        guard let url = URL(string: "https://github.com/mschuerig/peach") else {
            preconditionFailure("Invalid GitHub URL constant")
        }
        return url
    }()
    static let soundFontCredit = "GeneralUser GS by S. Christian Collins"
    static let soundFontURL: URL = {
        guard let url = URL(string: "https://schristiancollins.com/generaluser.php") else {
            preconditionFailure("Invalid SoundFont URL constant")
        }
        return url
    }()

    static let appDescription = String(localized: "Peach helps you train your ear for music. Practice hearing the difference between notes and learn to match pitches accurately.")

    static let trainingModes: [TrainingMode] = [
        TrainingMode(
            name: String(localized: "Hear & Compare – Single Notes"),
            description: String(localized: "Listen to two notes and decide which one is higher.")
        ),
        TrainingMode(
            name: String(localized: "Hear & Compare – Intervals"),
            description: String(localized: "The same idea, but with musical intervals between notes.")
        ),
        TrainingMode(
            name: String(localized: "Tune & Match – Single Notes"),
            description: String(localized: "Hear a note and slide to match its pitch.")
        ),
        TrainingMode(
            name: String(localized: "Tune & Match – Intervals"),
            description: String(localized: "Match pitches using musical intervals.")
        ),
    ]

    static let gettingStartedText = String(localized: "Just pick any training mode on the home screen and start practicing. Peach adapts to your skill level automatically.")

    static var copyrightNotice: String {
        "© \(copyrightYear) \(developerName)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    helpSection
                    acknowledgmentsSection
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

    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("What is Peach?")
                    .font(.headline)
                Text(Self.appDescription)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Training Modes")
                    .font(.headline)
                ForEach(Array(Self.trainingModes.enumerated()), id: \.offset) { _, mode in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mode.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(mode.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Getting Started")
                    .font(.headline)
                Text(Self.gettingStartedText)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var acknowledgmentsSection: some View {
        VStack(spacing: 6) {
            Text("Acknowledgments")
                .font(.headline)
            Link(Self.soundFontCredit, destination: Self.soundFontURL)
                .font(.caption)
        }
    }
}

#Preview {
    InfoScreen()
}
