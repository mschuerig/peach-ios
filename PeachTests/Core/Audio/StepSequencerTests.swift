import Testing
@testable import Peach

@Suite("StepSequencer Domain Types")
struct StepSequencerTests {

    // MARK: - StepPosition

    @Test("StepPosition has four cases with raw values 0–3")
    func stepPositionRawValues() async {
        #expect(StepPosition.first.rawValue == 0)
        #expect(StepPosition.second.rawValue == 1)
        #expect(StepPosition.third.rawValue == 2)
        #expect(StepPosition.fourth.rawValue == 3)
    }

    @Test("StepPosition allCases contains exactly four positions")
    func stepPositionAllCases() async {
        #expect(StepPosition.allCases.count == 4)
        #expect(StepPosition.allCases == [.first, .second, .third, .fourth])
    }

    @Test("StepPosition is Sendable and Hashable")
    func stepPositionConformances() async {
        let set: Set<StepPosition> = [.first, .second, .first]
        #expect(set.count == 2)

        // Sendable: compile-time check — if this compiles, it's Sendable
        let _: any Sendable = StepPosition.first
    }

    // MARK: - CycleDefinition

    @Test("CycleDefinition stores gap position")
    func cycleDefinitionGapPosition() async {
        let definition = CycleDefinition(gapPosition: .third)
        #expect(definition.gapPosition == .third)
    }

    @Test("CycleDefinition is Sendable")
    func cycleDefinitionSendable() async {
        let _: any Sendable = CycleDefinition(gapPosition: .first)
    }

    // MARK: - StepVelocity

    @Test("StepVelocity accent is 127 and normal is 100")
    func stepVelocityConstants() async {
        #expect(StepVelocity.accent == MIDIVelocity(127))
        #expect(StepVelocity.normal == MIDIVelocity(100))
    }
}
