import SwiftUI

struct HelpSection {
    let title: String
    let body: String
}

struct HelpContentView: View {
    let sections: [HelpSection]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.title)
                        .font(.headline)
                    markdownText(section.body)
                        .font(.body)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func markdownText(_ string: String) -> Text {
        if let attributed = try? AttributedString(
            markdown: string,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attributed)
        }
        return Text(string)
    }
}

#Preview {
    HelpContentView(sections: [
        HelpSection(title: "Section One", body: "This is **bold** and *italic* text."),
        HelpSection(title: "Section Two", body: "Another section with a [link](https://example.com)."),
    ])
    .padding()
}
