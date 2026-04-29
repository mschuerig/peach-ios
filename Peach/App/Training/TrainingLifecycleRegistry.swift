import Foundation

/// Maps a ``NavigationDestination`` to its training session and start closure.
final class TrainingLifecycleRegistry {

    /// Per-destination lifecycle wiring.
    struct Contribution {
        let session: any TrainingSession
        let start: () -> Void
    }

    final class Builder {
        fileprivate var contributions: [NavigationDestination: Contribution] = [:]

        func register(
            destination: NavigationDestination,
            session: any TrainingSession,
            start: @escaping () -> Void
        ) {
            precondition(
                contributions[destination] == nil,
                "Duplicate lifecycle contribution for \(destination)"
            )
            contributions[destination] = Contribution(session: session, start: start)
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
