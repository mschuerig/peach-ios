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

    func platformHoverEffect() -> some View {
        #if os(iOS)
        self.hoverEffect(.highlight)
        #elseif os(macOS)
        self
        #else
        #error("Unsupported platform")
        #endif
    }

    func platformPrincipalTitle(_ title: String) -> some View {
        #if os(iOS)
        self.toolbar {
            ToolbarItem(placement: .principal) {
                Text(title)
                    .font(.headline)
            }
        }
        #elseif os(macOS)
        self
        #else
        #error("Unsupported platform")
        #endif
    }

    func platformPrincipalToolbarItem<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        #if os(iOS)
        self.toolbar {
            ToolbarItem(placement: .principal) {
                content()
            }
        }
        #elseif os(macOS)
        self
        #else
        #error("Unsupported platform")
        #endif
    }
}

struct PlatformSettingsButton: View {
    var imageScale: Image.Scale = .medium

    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    var body: some View {
        #if os(iOS)
        NavigationLink(value: NavigationDestination.settings) {
            Image(systemName: "gearshape")
                .imageScale(imageScale)
        }
        .accessibilityLabel("Settings")
        #elseif os(macOS)
        Button {
            openWindow(id: "settings")
        } label: {
            Image(systemName: "gearshape")
                .imageScale(imageScale)
        }
        .accessibilityLabel("Settings")
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
