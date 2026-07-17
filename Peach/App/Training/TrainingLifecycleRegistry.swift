import Foundation

/// Maps a ``NavigationDestination`` to its training session and start closure.
final class TrainingLifecycleRegistry {

    /// Per-destination lifecycle wiring.
    struct Contribution {
        let session: any TrainingSession
        let start: () -> Void
        /// Reconciles the session with the live settings snapshot — on iOS when
        /// a paused training screen reappears, and on macOS when a setting
        /// changes while the session is still active (separate Settings window).
        /// Owns the discipline-specific policy: most disciplines simply forward
        /// to `session.resume()`, but a discipline whose settings can change
        /// out from under a running/paused session (e.g. Timing Offset
        /// Detection's pattern) rebuilds the live snapshot here and restarts
        /// fresh when it differs.
        let reconcile: () -> Void
    }

    final class Builder {
        fileprivate var contributions: [NavigationDestination: Contribution] = [:]

        func register(
            destination: NavigationDestination,
            session: any TrainingSession,
            start: @escaping () -> Void,
            reconcile: @escaping () -> Void
        ) {
            precondition(
                contributions[destination] == nil,
                "Duplicate lifecycle contribution for \(destination)"
            )
            contributions[destination] = Contribution(session: session, start: start, reconcile: reconcile)
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

    /// Every registered contribution, in no particular order — for whole-app
    /// operations that must touch every session (e.g. stop-all on a sound
    /// source change).
    var all: [Contribution] {
        Array(byDestination.values)
    }
}
