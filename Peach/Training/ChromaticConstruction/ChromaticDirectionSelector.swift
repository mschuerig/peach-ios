import SwiftUI

/// Segmented control for the walk direction. View-local @State only.
struct ChromaticDirectionSelector: View {
    @Binding var mode: ChromaticDirectionMode

    var body: some View {
        Picker(selection: $mode) {
            Text(String(localized: "Ascending")).tag(ChromaticDirectionMode.ascending)
            Text(String(localized: "Descending")).tag(ChromaticDirectionMode.descending)
            Text(String(localized: "Mix")).tag(ChromaticDirectionMode.mix)
        } label: {
            Text(String(localized: "Direction"))
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(String(localized: "Direction"))
    }
}
