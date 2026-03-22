import Foundation

// MARK: - StepPosition

enum StepPosition: Int, CaseIterable, Hashable, Sendable {
    case first = 0
    case second = 1
    case third = 2
    case fourth = 3
}

// MARK: - CycleDefinition

struct CycleDefinition: Sendable {
    let gapPosition: StepPosition
}

// MARK: - StepVelocity

enum StepVelocity {
    static let accent = MIDIVelocity(127)
    static let normal = MIDIVelocity(100)
}

// MARK: - StepProvider

protocol StepProvider {
    func nextCycle() -> CycleDefinition
}

// MARK: - StepSequencer

protocol StepSequencer {
    var currentStep: StepPosition? { get }
    var currentCycle: CycleDefinition? { get }
    func start(tempo: TempoBPM, stepProvider: any StepProvider) async throws
    func stop() async throws
}
