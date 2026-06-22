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

#if os(macOS)
/// While a macOS auxiliary window (Settings or Help) suspends the foreground
/// session, makes the training surface non-interactive and dims it so a stray
/// click — e.g. a Timing Offset Detection answer button — can't resume audio
/// behind the open window. No overlay text: the open window is self-explanatory.
private struct TrainingSuspendedGate: ViewModifier {
    @Environment(\.trainingLifecycle) private var lifecycle

    func body(content: Content) -> some View {
        content
            .opacity(lifecycle.isForegroundSuspended ? 0.35 : 1.0)
            .allowsHitTesting(!lifecycle.isForegroundSuspended)
    }
}
#endif

extension View {
    /// macOS-only: see `TrainingSuspendedGate`. A no-op on iOS, where Settings is
    /// a pushed screen and Help is a modal sheet — both already cover the surface.
    func trainingSuspendedGate() -> some View {
        #if os(macOS)
        modifier(TrainingSuspendedGate())
        #else
        self
        #endif
    }
}
