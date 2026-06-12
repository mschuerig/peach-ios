import Testing
@testable import Peach

@Suite("ChromaticConstructionTrial")
struct ChromaticConstructionTrialTests {

    private func makeAscendingP5Trial() throws -> ChromaticConstructionTrial {
        let path = try MonotonicPath().chromaticPath(
            lowerAnchor: MIDINote(60),
            outerInterval: .up(.perfectFifth)
        )
        return ChromaticConstructionTrial(path: path)
    }

    @Test("initial trial has empty placed and active at position 1 with no preserved value")
    func initialState() throws {
        let trial = try makeAscendingP5Trial()
        #expect(trial.placed.isEmpty)
        #expect(trial.active?.index == 1)
        #expect(trial.active?.preservedValue == nil)
        #expect(!trial.isComplete)
    }

    @Test("place advances active by one and appends a DetunedMIDINote anchored at lowerAnchor")
    func placeAdvancesPosition() throws {
        var trial = try makeAscendingP5Trial()
        trial.place(offset: Cents(95.0))
        #expect(trial.active?.index == 2)
        #expect(trial.active?.preservedValue == nil)
        #expect(trial.placed.count == 1)
        #expect(trial.placed[0] == DetunedMIDINote(note: MIDINote(60), offset: Cents(95.0)))
    }

    @Test("place at the final interior position completes the trial (active becomes nil)")
    func placeFinalCompletesTrial() throws {
        var trial = try makeAscendingP5Trial()  // 6 interior positions
        for k in 1...6 {
            trial.place(offset: Cents(Double(k) * 100.0))
        }
        #expect(trial.isComplete)
        #expect(trial.active == nil)
        #expect(trial.placed.count == 6)
    }

    @Test("stepBack from position 2 re-activates position 1 with the placed value preserved")
    func stepBackPreservesValue() throws {
        var trial = try makeAscendingP5Trial()
        trial.place(offset: Cents(95.0))
        trial.stepBack()
        #expect(trial.active?.index == 1)
        #expect(trial.active?.preservedValue == DetunedMIDINote(note: MIDINote(60), offset: Cents(95.0)))
        #expect(trial.placed.isEmpty)
    }

    @Test("stepBack at position 1 is a no-op")
    func stepBackAtFirstPositionNoOp() throws {
        var trial = try makeAscendingP5Trial()
        let before = trial
        trial.stepBack()
        #expect(trial == before)
    }

    @Test("stepBack twice from position 3 returns to position 1 with the first placed value preserved")
    func stepBackTwiceFromThird() throws {
        var trial = try makeAscendingP5Trial()
        trial.place(offset: Cents(95.0))
        trial.place(offset: Cents(205.0))
        trial.stepBack()  // back to position 2 with 205 preserved
        trial.stepBack()  // back to position 1 with 95 preserved
        #expect(trial.active?.index == 1)
        #expect(trial.active?.preservedValue == DetunedMIDINote(note: MIDINote(60), offset: Cents(95.0)))
        #expect(trial.placed.isEmpty)
    }

    @Test("reopenFinalPosition re-activates final interior position with the placed value preserved")
    func reopenFinalPosition() throws {
        var trial = try makeAscendingP5Trial()
        for k in 1...6 {
            trial.place(offset: Cents(Double(k) * 100.0))
        }
        trial.reopenFinalPosition()
        #expect(trial.active?.index == 6)
        #expect(trial.active?.preservedValue == DetunedMIDINote(note: MIDINote(60), offset: Cents(600.0)))
        #expect(trial.placed.count == 5)
        #expect(!trial.isComplete)
    }

    @Test("reopenFinalPosition is a no-op when trial is not complete")
    func reopenWhileWalkingIsNoOp() throws {
        var trial = try makeAscendingP5Trial()
        trial.place(offset: Cents(95.0))
        let before = trial
        trial.reopenFinalPosition()
        #expect(trial == before)
    }

    @Test("place is a no-op once trial is complete")
    func placeAfterCompleteIsNoOp() throws {
        var trial = try makeAscendingP5Trial()
        for k in 1...6 {
            trial.place(offset: Cents(Double(k) * 100.0))
        }
        let before = trial
        trial.place(offset: Cents(999.0))
        #expect(trial == before)
    }

    @Test("trial with single-interior-position path (M2 ascending) completes after one place")
    func minimumNonDegenerateTrial() throws {
        let path = try MonotonicPath().chromaticPath(
            lowerAnchor: MIDINote(60),
            outerInterval: .up(.majorSecond)
        )
        #expect(path.interiorPositionCount == 1)
        var trial = ChromaticConstructionTrial(path: path)
        trial.place(offset: Cents(95.0))
        #expect(trial.isComplete)
        #expect(trial.active == nil)
    }
}
