import SwiftUI

private struct TrainingIdleOverlay: ViewModifier {
    @Environment(\.trainingLifecycle) private var lifecycle

    private var showOverlay: Bool {
        !lifecycle.shouldAutoStartTraining && !lifecycle.isTrainingActive
    }

    func body(content: Content) -> some View {
        content
            .opacity(showOverlay ? 0.35 : 1.0)
            .allowsHitTesting(!showOverlay)
            .overlay {
                if showOverlay {
                    Button {
                        lifecycle.startCurrentSession()
                    } label: {
                        Label(String(localized: "Start Training"), systemImage: "play.fill")
                            .font(.title2)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [])
                }
            }
    }
}

extension View {
    func trainingIdleOverlay() -> some View {
        modifier(TrainingIdleOverlay())
    }
}
