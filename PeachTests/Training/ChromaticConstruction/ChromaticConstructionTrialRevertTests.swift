import Testing
@testable import Peach

@Suite("ChromaticConstructionTrial.revertTo atomic step-back")
struct ChromaticConstructionTrialRevertTests {

    private func ascendingP5Trial() throws -> ChromaticConstructionTrial {
        let path = try ChromaticPath(
            lowerAnchor: MIDINote(60),
            outerInterval: .up(.perfectFifth),
            steps: Array(repeating: .up, count: 7)
        )
        return ChromaticConstructionTrial(path: path)
    }

    @Test("revertTo(k) from walking drops placed entries beyond k")
    func revertFromWalkingDropsLaterEntries() throws {
        var trial = try ascendingP5Trial()
        trial.place(offset: Cents(100))
        trial.place(offset: Cents(205))
        trial.place(offset: Cents(310))
        trial.place(offset: Cents(420))
        // Active at position 5; placed has 4 entries.
        trial.revertTo(positionIndex: 2)
        #expect(trial.placed.count == 1)
        #expect(trial.placed[0].offset.rawValue == 100)
        #expect(trial.active?.index == 2)
        #expect(trial.active?.preservedValue?.offset.rawValue == 205)
    }

    @Test("revertTo(k) from completion reopens then steps back to k")
    func revertFromCompletionReopensAndSteps() throws {
        var trial = try ascendingP5Trial()
        for cents in stride(from: 100.0, through: 600.0, by: 100.0) {
            trial.place(offset: Cents(cents))
        }
        #expect(trial.isComplete)
        trial.revertTo(positionIndex: 4)
        #expect(trial.placed.count == 3)
        #expect(trial.active?.index == 4)
        #expect(trial.active?.preservedValue?.offset.rawValue == 400)
    }

    @Test("revertTo(k) is no-op for k > current active index")
    func revertToFutureIsNoOp() throws {
        var trial = try ascendingP5Trial()
        trial.place(offset: Cents(100))
        trial.revertTo(positionIndex: 5)
        #expect(trial.placed.count == 1)
        #expect(trial.active?.index == 2)
    }

    @Test("revertTo(0) is no-op (position 1 is the lowest valid)")
    func revertToZeroIsNoOp() throws {
        var trial = try ascendingP5Trial()
        trial.place(offset: Cents(100))
        trial.place(offset: Cents(205))
        trial.revertTo(positionIndex: 0)
        #expect(trial.placed.count == 2)
        #expect(trial.active?.index == 3)
    }

    @Test("audibleOffsets has one entry per interior position")
    func audibleOffsetsLengthMatchesPath() throws {
        let trial = try ascendingP5Trial()
        #expect(trial.audibleOffsets.count == trial.path.interiorPositionCount)
    }

    @Test("audibleOffsets values are within ±50¢ by construction")
    func audibleOffsetsWithinDeclaredRange() throws {
        // Run a handful of trials to spot a value outside the declared range.
        for _ in 0..<32 {
            let trial = try ascendingP5Trial()
            for offset in trial.audibleOffsets {
                #expect(ChromaticConstructionTrial.maxOffsetRange.contains(offset.rawValue))
            }
        }
    }

    @Test("explicit-offsets init preserves the array verbatim (deterministic for tests)")
    func explicitOffsetsInitPreservesArray() throws {
        let path = try ChromaticPath(
            lowerAnchor: MIDINote(60),
            outerInterval: .up(.perfectFifth),
            steps: Array(repeating: .up, count: 7)
        )
        let offsets: [Cents] = [Cents(-30), Cents(10), Cents(-15), Cents(40), Cents(0), Cents(20)]
        let trial = ChromaticConstructionTrial(path: path, audibleOffsets: offsets)
        #expect(trial.audibleOffsets == offsets)
    }
}
