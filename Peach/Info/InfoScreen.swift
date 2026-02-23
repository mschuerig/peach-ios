import SwiftUI

struct InfoScreen: View {
    @Environment(\.dismiss) private var dismiss
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"

    static let developerName = "Michael Schürig"
    static let developerEmail = "michael@schuerig.de"
    static let licenseName = "MIT"
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                Text("Peach")
                    .font(.largeTitle)
                    .bold()

                Text("Version \(appVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(spacing: 6) {
                    Text("Developer: \(Self.developerName)")
                        .font(.body)
                    Text(verbatim: Self.developerEmail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 6) {
                    Link(String("GitHub"), destination: Self.gitHubURL)
                        .font(.body)
                    Text("License: \(Self.licenseName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("© 2026")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(spacing: 6) {
                    Text("Acknowledgments")
                        .font(.headline)
                    Link(Self.soundFontCredit, destination: Self.soundFontURL)
                        .font(.caption)
                }
            }
            .padding()
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
}

#Preview {
    InfoScreen()
}
