import SwiftUI

/// Caches a discipline's `DisciplineProgress` in view-local state, recomputing
/// only when the profile's data changes.
///
/// The caching is written once here via `Memoized`; a card applies it by
/// wrapping its content, so no card repeats the boilerplate and
/// `ProgressTimeline` stays a stateless computation layer. The compute is
/// synchronous (no first-frame flash, no lag) and re-runs only when
/// `dataGeneration` changes — a trial, reset, or import.
struct CachedProgress<Content: View>: View {
    let mode: TrainingDisciplineID
    @ViewBuilder let content: (DisciplineProgress) -> Content

    @Environment(\.progressTimeline) private var progressTimeline
    @Environment(\.perceptualProfile) private var profile
    @State private var memo = Memoized<DisciplineProgress>()

    var body: some View {
        content(memo.value(generation: profile.dataGeneration) {
            progressTimeline.snapshot(for: mode)
        })
    }
}
