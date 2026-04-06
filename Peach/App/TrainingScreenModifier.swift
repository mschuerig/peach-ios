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
            .toolbar { toolbarContent }
            .sheet(isPresented: $showHelpSheet) { helpSheetContent }
            .onChange(of: showHelpSheet) { _, isShowing in
                if isShowing {
                    lifecycle.helpSheetPresented()
                } else {
                    isFocused = true
                    lifecycle.helpSheetDismissed()
                }
            }
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
        ToolbarItem(placement: .principal) {
            title
        }
        ToolbarItem(placement: .automatic) {
            HStack(spacing: 20) {
                Button {
                    showHelpSheet = true
                } label: {
                    Label("Help", systemImage: "questionmark.circle")
                }

                NavigationLink(value: NavigationDestination.settings) {
                    Image(systemName: "gearshape")
                        .imageScale(.large)
                }
                .accessibilityLabel("Settings")

                NavigationLink(value: NavigationDestination.profile) {
                    Image(systemName: "chart.xyaxis.line")
                        .imageScale(.large)
                }
                .accessibilityLabel("Profile")
            }
        }
    }

    private var helpSheetContent: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    HelpContentView(sections: helpSections)
                }
                .padding()
            }
            .navigationTitle(String(localized: "Training Help"))
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Done")) {
                        showHelpSheet = false
                    }
                }
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
