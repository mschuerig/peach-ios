import SwiftUI

struct TrainingScreenModifier<Title: View>: ViewModifier {
    let helpSections: [HelpSection]
    let destination: NavigationDestination
    let title: Title

    @Environment(\.trainingLifecycle) private var lifecycle
    @Environment(\.dismiss) private var dismiss

    @FocusState private var isFocused: Bool
    @State private var showHelpSheet = false

    func body(content: Content) -> some View {
        content
            .inlineNavigationBarTitle()
            .platformPrincipalToolbarItem { title }
            .toolbar { toolbarContent }
            .platformHelp(
                isPresented: $showHelpSheet,
                title: String(localized: "Training Help"),
                sections: helpSections,
                onPresented: { lifecycle.helpSheetPresented() },
                onDismissed: {
                    isFocused = true
                    lifecycle.helpSheetDismissed()
                }
            )
            .focusable()
            .focusEffectDisabled()
            .focused($isFocused)
            .onKeyPress(.escape) {
                dismiss()
                return .handled
            }
            .onAppear {
                isFocused = true
                lifecycle.trainingScreenAppeared(destination: destination)
            }
            .onDisappear {
                lifecycle.trainingScreenDisappeared()
            }
            .trainingIdleOverlay()
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            HStack(spacing: 20) {
                Button {
                    showHelpSheet = true
                } label: {
                    Label("Help", systemImage: "questionmark.circle")
                }

                PlatformSettingsButton(imageScale: .large)

                NavigationLink(value: NavigationDestination.profile) {
                    Image(systemName: "chart.xyaxis.line")
                        .imageScale(.large)
                }
                .accessibilityLabel("Profile")
            }
        }
    }

}

extension View {
    func trainingScreen<Title: View>(
        helpSections: [HelpSection],
        destination: NavigationDestination,
        @ViewBuilder title: () -> Title
    ) -> some View {
        modifier(TrainingScreenModifier(
            helpSections: helpSections,
            destination: destination,
            title: title()
        ))
    }
}
