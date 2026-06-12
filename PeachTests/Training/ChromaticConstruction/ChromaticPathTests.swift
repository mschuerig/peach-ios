import Testing
@testable import Peach

@Suite("ChromaticPath")
struct ChromaticPathTests {

    @Test("monotonic ascending P5 from C4 has 7 ups and 6 interior positions")
    func ascendingP5() throws {
        let path = try ChromaticPath(
            lowerAnchor: MIDINote(60),
            outerInterval: .up(.perfectFifth),
            steps: Array(repeating: Direction.up, count: 7)
        )
        #expect(path.steps.count == 7)
        #expect(path.interiorPositionCount == 6)
        #expect(path.upperAnchor == MIDINote(67))
    }

    @Test("monotonic descending octave from C5 has 12 downs and 11 interior positions")
    func descendingOctave() throws {
        let path = try ChromaticPath(
            lowerAnchor: MIDINote(72),
            outerInterval: .down(.octave),
            steps: Array(repeating: Direction.down, count: 12)
        )
        #expect(path.interiorPositionCount == 11)
        #expect(path.upperAnchor == MIDINote(60))
    }

    @Test("targetMIDINote walks one semitone per ascending step from the lower anchor")
    func ascendingTargets() throws {
        let path = try ChromaticPath(
            lowerAnchor: MIDINote(60),
            outerInterval: .up(.perfectFifth),
            steps: Array(repeating: Direction.up, count: 7)
        )
        for k in 1...6 {
            #expect(path.targetMIDINote(at: k) == MIDINote(60 + k))
        }
    }

    @Test("targetMIDINote walks one semitone per descending step from the lower anchor")
    func descendingTargets() throws {
        let path = try ChromaticPath(
            lowerAnchor: MIDINote(72),
            outerInterval: .down(.octave),
            steps: Array(repeating: Direction.down, count: 12)
        )
        for k in 1...11 {
            #expect(path.targetMIDINote(at: k) == MIDINote(72 - k))
        }
    }

    @Test("targetOffsetCents is k × 100¢ for ascending monotonic")
    func ascendingOffsets() throws {
        let path = try ChromaticPath(
            lowerAnchor: MIDINote(60),
            outerInterval: .up(.perfectFifth),
            steps: Array(repeating: Direction.up, count: 7)
        )
        for k in 1...6 {
            #expect(path.targetOffsetCents(at: k) == Cents(Double(k) * 100.0))
        }
    }

    @Test("targetOffsetCents is signed-negative for descending and magnitude-matches ascending")
    func descendingSignSymmetry() throws {
        let ascending = try ChromaticPath(
            lowerAnchor: MIDINote(60),
            outerInterval: .up(.octave),
            steps: Array(repeating: Direction.up, count: 12)
        )
        let descending = try ChromaticPath(
            lowerAnchor: MIDINote(72),
            outerInterval: .down(.octave),
            steps: Array(repeating: Direction.down, count: 12)
        )
        for k in 1...11 {
            let asc = ascending.targetOffsetCents(at: k)
            let desc = descending.targetOffsetCents(at: k)
            #expect(desc.rawValue == -asc.rawValue)
        }
    }

    @Test("non-monotonic path with matching net signed span is accepted; targetOffsetCents honors the meander")
    func meanderingPathHonored() throws {
        // outer = M2 ascending (2 semitones). Steps: up, up, down, up, up — net +3? No.
        // We need net = +2. Try: up, up, down, up = net 2 (4 steps, slotCount 3).
        let path = try ChromaticPath(
            lowerAnchor: MIDINote(60),
            outerInterval: .up(.majorSecond),
            steps: [.up, .up, .down, .up]
        )
        #expect(path.interiorPositionCount == 3)
        // Cumulative semitones: pos 1 → +1, pos 2 → +2, pos 3 → +1.
        #expect(path.cumulativeSemitones(at: 1) == 1)
        #expect(path.cumulativeSemitones(at: 2) == 2)
        #expect(path.cumulativeSemitones(at: 3) == 1)
        // Cumulative cents follow the meander, NOT k × 100.
        #expect(path.targetOffsetCents(at: 3) == Cents(100.0))
    }

    @Test("init throws degeneratePath when steps has fewer than two elements")
    func rejectsDegeneratePath() {
        let error0 = capturedError {
            try ChromaticPath(lowerAnchor: MIDINote(60), outerInterval: .up(.prime), steps: [])
        }
        #expect(error0 == .degeneratePath(stepCount: 0))

        let error1 = capturedError {
            try ChromaticPath(lowerAnchor: MIDINote(60), outerInterval: .up(.minorSecond), steps: [.up])
        }
        #expect(error1 == .degeneratePath(stepCount: 1))
    }

    @Test("init throws pathDoesNotReachInterval when net signed steps don't match outerInterval")
    func rejectsNonReachingPath() {
        let error = capturedError {
            try ChromaticPath(
                lowerAnchor: MIDINote(60),
                outerInterval: .up(.perfectFifth),
                steps: Array(repeating: Direction.up, count: 5)
            )
        }
        #expect(error == .pathDoesNotReachInterval(expectedNetSteps: 7, actualNetSteps: 5))
    }

    @Test("init throws pathExceedsMIDIRange when path visits MIDI < 0")
    func rejectsPathBelowMIDIRange() {
        let error = capturedError {
            try ChromaticPath(
                lowerAnchor: MIDINote(5),
                outerInterval: .down(.octave),
                steps: Array(repeating: Direction.down, count: 12)
            )
        }
        guard case let .pathExceedsMIDIRange(lowest, _) = error else {
            Issue.record("expected pathExceedsMIDIRange, got \(String(describing: error))")
            return
        }
        #expect(lowest == -7)
    }

    @Test("init throws pathExceedsMIDIRange when path visits MIDI > 127")
    func rejectsPathAboveMIDIRange() {
        let error = capturedError {
            try ChromaticPath(
                lowerAnchor: MIDINote(120),
                outerInterval: .up(.octave),
                steps: Array(repeating: Direction.up, count: 12)
            )
        }
        guard case let .pathExceedsMIDIRange(_, highest) = error else {
            Issue.record("expected pathExceedsMIDIRange, got \(String(describing: error))")
            return
        }
        #expect(highest == 132)
    }

    /// Captures a `ChromaticConstructionError` thrown by the body, or fails the
    /// test if the body did not throw the expected error type.
    private func capturedError(_ body: () throws -> Void) -> ChromaticConstructionError? {
        do {
            try body()
            Issue.record("expected ChromaticConstructionError, but body returned without throwing")
            return nil
        } catch let error as ChromaticConstructionError {
            return error
        } catch {
            Issue.record("expected ChromaticConstructionError, got \(type(of: error))")
            return nil
        }
    }
}
