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
    static var copyrightNotice: String {
        "© \(copyrightYear) \(developerName)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    HelpContentView(sections: HelpContent.about)
                }
                .padding()
            }
            .navigationTitle("Info")
            .inlineNavigationBarTitle()
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
