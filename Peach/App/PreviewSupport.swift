#if DEBUG
import Foundation

/// Idempotent registry bootstrap for SwiftUI previews. Calls
/// `TrainingDisciplineRegistry.bootstrap(disciplines:)` with the same
/// `DisciplineBootstrap.allDisciplines` the live app uses, so previews
/// see the same registry contents as a running app would. SwiftUI may
/// re-render previews repeatedly in the same process; the helper relies
/// on `bootstrap`'s first-call-wins idempotency so repeated invocation
/// is safe.
enum PreviewSupport {
    static func bootstrapRegistryIfNeeded() {
        TrainingDisciplineRegistry.bootstrap(disciplines: DisciplineBootstrap.allDisciplines)
    }
}
#endif
