import SwiftUI

struct GridToggleRow<Element: CaseIterable & Hashable>: View where Element.AllCases: RandomAccessCollection {
    @Binding var selection: Set<Element>
    let label: (Element) -> String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(Element.allCases), id: \.self) { element in
                let isActive = selection.contains(element)
                let isLast = Self.isLastRemaining(element, in: selection)

                Button {
                    Self.toggle(element, in: &selection)
                } label: {
                    Text(label(element))
                        .font(.caption2)
                        .frame(width: 32, height: 32)
                        .background(isActive ? Color.accentColor : Color.secondary.opacity(0.2))
                        .foregroundStyle(isActive ? .white : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(isLast)
            }
        }
    }

    // MARK: - Logic (static for testability)

    static func toggle(_ element: Element, in selection: inout Set<Element>) {
        if selection.contains(element) {
            guard selection.count > 1 else { return }
            selection.remove(element)
        } else {
            selection.insert(element)
        }
    }

    static func isLastRemaining(_ element: Element, in selection: Set<Element>) -> Bool {
        selection.count == 1 && selection.contains(element)
    }
}
