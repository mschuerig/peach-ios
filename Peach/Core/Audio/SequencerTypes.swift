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

// MARK: - SequencerTiming

/// Snapshot of all timing state needed to interpret sample positions.
/// Reading this as a single value avoids tearing when properties are
/// mutated concurrently (e.g. during stop).
struct SequencerTiming: Sendable {
    let samplePosition: Int64
    let samplesPerStep: Int64
    let samplesPerCycle: Int64
    let sampleRate: SampleRate
}

