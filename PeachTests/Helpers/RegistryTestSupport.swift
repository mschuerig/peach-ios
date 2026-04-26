import Foundation
@testable import Peach

extension TrainingDisciplineRegistry {
    /// Scoped variant of ``_replaceSharedForTesting(disciplines:)``: installs
    /// the given disciplines for the duration of `body`, then restores
    /// `DisciplineBootstrap.allDisciplines` — the canonical list TEST_HOST
    /// bootstraps for every test. Use this when a test needs a non-canonical
    /// registry; the restoration keeps parallel tests from observing the
    /// test's intermediate state.
    static func _withSharedReplacedForTesting<R>(
        disciplines: [any TrainingDiscipline],
        body: () throws -> R
    ) rethrows -> R {
        defer { _replaceSharedForTesting(disciplines: DisciplineBootstrap.allDisciplines) }
        _replaceSharedForTesting(disciplines: disciplines)
        return try body()
    }
}
