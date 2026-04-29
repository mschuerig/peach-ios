import SwiftUI

struct InfoContentView: View {
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
    static let privacyPolicyURL: URL = {
        guard let url = URL(string: "https://mschuerig.github.io/peach-ios/privacy-policy") else {
            preconditionFailure("Invalid privacy policy URL constant")
        }
        return url
    }()
    static let supportURL: URL = {
        guard let url = URL(string: "mailto:michael@schuerig.de") else {
            preconditionFailure("Invalid support URL constant")
        }
        return url
    }()
    static var copyrightNotice: String {
        "© \(copyrightYear) \(developerName)"
    }

    var body: some View {
        VStack(spacing: 24) {
            headerSection
            HelpContentView(sections: HelpContent.about)
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

            Link(String(localized: "Privacy Policy"), destination: Self.privacyPolicyURL)
                .font(.caption)

            Link(String(localized: "Contact"), destination: Self.supportURL)
                .font(.caption)
        }
    }
}

struct InfoScreen: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                InfoContentView()
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
}

#if DEBUG
#Preview {
    PreviewSupport.bootstrapRegistryIfNeeded()
    return InfoScreen()
}
#endif
