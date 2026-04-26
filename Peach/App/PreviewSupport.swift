#if DEBUG
import Foundation

/// Installs `DisciplineBootstrap.allDisciplines` on the shared registry for
/// SwiftUI previews. SwiftUI may re-render previews repeatedly in the same
/// process; this helper uses `_replaceSharedForTesting` so each render gets
/// a freshly populated registry without conflicting with the production
/// `bootstrap(disciplines:)` precondition.
enum PreviewSupport {
    static func bootstrapRegistryIfNeeded() {
        TrainingDisciplineRegistry._replaceSharedForTesting(disciplines: DisciplineBootstrap.allDisciplines)
    }
}
#endif
