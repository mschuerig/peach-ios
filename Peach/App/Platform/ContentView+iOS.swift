#if os(iOS)
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.trainingLifecycle) private var lifecycle

    @State private var navigationPath: [NavigationDestination] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            StartScreen()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            lifecycle.handleScenePhase(old: oldPhase, new: newPhase)
        }
    }
}

#Preview {
    ContentView()
        .previewEnvironment()
}
#endif
