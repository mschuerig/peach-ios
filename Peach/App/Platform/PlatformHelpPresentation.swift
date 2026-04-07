import SwiftUI

// MARK: - Standard Help Modifier

struct PlatformHelpModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let sections: [HelpSection]
    var onPresented: (() -> Void)?
    var onDismissed: (() -> Void)?

    func body(content: Content) -> some View {
        content
            #if os(iOS)
            .sheet(isPresented: $isPresented) {
                NavigationStack {
                    ScrollView {
                        VStack(spacing: 24) {
                            HelpContentView(sections: sections)
                        }
                        .padding()
                    }
                    .navigationTitle(title)
                    .inlineNavigationBarTitle()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(String(localized: "Done")) {
                                isPresented = false
                            }
                        }
                    }
                }
            }
            #endif
            .onChange(of: isPresented) { _, isShowing in
                if isShowing {
                    onPresented?()
                    #if os(macOS)
                    HelpPanelController.shared.show(
                        title: title,
                        sections: sections,
                        onDismiss: onDismissed
                    )
                    isPresented = false
                    #endif
                } else {
                    #if os(iOS)
                    onDismissed?()
                    #endif
                }
            }
    }
}

// MARK: - Custom iOS Sheet Modifier

/// For cases where the iOS sheet needs custom content (e.g., InfoScreen with a header),
/// while macOS still uses the standard help panel with sections.
struct PlatformHelpWithCustomSheetModifier<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let sections: [HelpSection]
    @ViewBuilder let iosSheet: () -> SheetContent

    func body(content: Content) -> some View {
        content
            #if os(iOS)
            .sheet(isPresented: $isPresented) {
                iosSheet()
            }
            #endif
            .onChange(of: isPresented) { _, isShowing in
                #if os(macOS)
                if isShowing {
                    HelpPanelController.shared.show(title: title, sections: sections)
                    isPresented = false
                }
                #endif
            }
    }
}

// MARK: - View Extensions

extension View {
    func platformHelp(
        isPresented: Binding<Bool>,
        title: String,
        sections: [HelpSection],
        onPresented: (() -> Void)? = nil,
        onDismissed: (() -> Void)? = nil
    ) -> some View {
        modifier(PlatformHelpModifier(
            isPresented: isPresented,
            title: title,
            sections: sections,
            onPresented: onPresented,
            onDismissed: onDismissed
        ))
    }

    func platformHelp<SheetContent: View>(
        isPresented: Binding<Bool>,
        title: String,
        sections: [HelpSection],
        @ViewBuilder iosSheet: @escaping () -> SheetContent
    ) -> some View {
        modifier(PlatformHelpWithCustomSheetModifier(
            isPresented: isPresented,
            title: title,
            sections: sections,
            iosSheet: iosSheet
        ))
    }
}
