import SwiftUI

struct HelpSection: Identifiable {
    let id = UUID()
    let title: String
    let body: String
    let attributedBody: AttributedString?

    init(title: String, body: String) {
        self.title = title
        self.body = body
        self.attributedBody = try? AttributedString(
            markdown: body,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )
    }
}

struct HelpContentView: View {
    let sections: [HelpSection]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.title)
                        .font(.headline)
                    Text(section.attributedBody ?? AttributedString(section.body))
                        .font(.body)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    HelpContentView(sections: [
        HelpSection(title: "Section One", body: "This is **bold** and *italic* text."),
        HelpSection(title: "Section Two", body: "Another section with a [link](https://example.com)."),
    ])
    .padding()
}
