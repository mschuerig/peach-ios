import Foundation

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
