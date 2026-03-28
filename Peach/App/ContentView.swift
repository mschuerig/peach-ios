import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.handleScenePhaseChange) private var handleScenePhaseChange

    @State private var navigationPath: [NavigationDestination] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            StartScreen()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(oldPhase, newPhase) {
                navigationPath.removeAll()
            }
        }
    }
}

#Preview {
    ContentView()
}
