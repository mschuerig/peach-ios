#if DEBUG
import Foundation

/// Installs `DisciplineBootstrap.allDisciplines` and the matching CSV
/// histories on the shared registry slots for SwiftUI previews. SwiftUI may
/// re-render previews repeatedly in the same process; this helper uses the
/// debug-only `_replaceSharedForPreviewSupport` entry point so each render
/// gets a freshly populated registry without conflicting with the production
/// `bootstrap(disciplines:)` precondition.
enum PreviewSupport {
    static func bootstrapRegistryIfNeeded() {
        TrainingDisciplineRegistry._replaceSharedForPreviewSupport(disciplines: DisciplineBootstrap.allDisciplines)
        CSVHistoryRegistry._replaceSharedForPreviewSupport(histories: DisciplineBootstrap.allCSVHistories)
    }
}
#endif
