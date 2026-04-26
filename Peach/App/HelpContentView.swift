import SwiftUI

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
        .frame(maxWidth: 700, alignment: .leading)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    HelpContentView(sections: [
        HelpSection(title: "Section One", body: "This is **bold** and *italic* text."),
        HelpSection(title: "Section Two", body: "Another section with a [link](https://example.com)."),
    ])
    .padding()
}
