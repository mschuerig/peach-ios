@testable import Peach

final class MockStepProvider: StepProvider {
    private let definitions: [CycleDefinition]
    private(set) var nextCycleCallCount = 0
    private var index = 0

    init(definitions: [CycleDefinition]) {
        precondition(!definitions.isEmpty)
        self.definitions = definitions
    }

    convenience init(gapPositions: [StepPosition]) {
        self.init(definitions: gapPositions.map { CycleDefinition(gapPosition: $0) })
    }

    func nextCycle() -> CycleDefinition {
        nextCycleCallCount += 1
        let definition = definitions[index % definitions.count]
        index += 1
        return definition
    }

    func reset() {
        index = 0
        nextCycleCallCount = 0
    }
}
