import SwiftUI

extension View {
    func inlineNavigationBarTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #elseif os(macOS)
        self
        #else
        #error("Unsupported platform")
        #endif
    }

    func platformFormStyle() -> some View {
        #if os(iOS)
        self
        #elseif os(macOS)
        self.formStyle(.grouped)
        #else
        #error("Unsupported platform")
        #endif
    }
}

extension Color {
    static var platformBackground: Color {
        #if os(iOS)
        Color(.systemBackground)
        #elseif os(macOS)
        Color(.windowBackgroundColor)
        #else
        #error("Unsupported platform")
        #endif
    }

    static var platformSecondaryBackground: Color {
        #if os(iOS)
        Color(.secondarySystemBackground)
        #elseif os(macOS)
        Color(.controlBackgroundColor)
        #else
        #error("Unsupported platform")
        #endif
    }
}
