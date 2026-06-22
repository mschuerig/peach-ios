import Foundation

/// Maps a ``NavigationDestination`` to its training session and start closure.
final class TrainingLifecycleRegistry {

    /// Per-destination lifecycle wiring.
    struct Contribution {
        let session: any TrainingSession
        let start: () -> Void
        /// Re-engages a paused session when the training screen reappears.
        /// Owns the discipline-specific resume policy: most disciplines simply
        /// forward to `session.resume()`, but a discipline whose settings can
        /// change while paused (e.g. Timing Offset Detection's pattern) rebuilds
        /// the live snapshot here and restarts fresh when it differs.
        let resume: () -> Void
    }

    final class Builder {
        fileprivate var contributions: [NavigationDestination: Contribution] = [:]

        func register(
            destination: NavigationDestination,
            session: any TrainingSession,
            start: @escaping () -> Void,
            resume: @escaping () -> Void
        ) {
            precondition(
                contributions[destination] == nil,
                "Duplicate lifecycle contribution for \(destination)"
            )
            contributions[destination] = Contribution(session: session, start: start, resume: resume)
        }
    }

    private let byDestination: [NavigationDestination: Contribution]

    init(_ build: (Builder) -> Void) {
        let builder = Builder()
        build(builder)
        self.byDestination = builder.contributions
    }

    func contribution(for destination: NavigationDestination) -> Contribution? {
        byDestination[destination]
    }
}
