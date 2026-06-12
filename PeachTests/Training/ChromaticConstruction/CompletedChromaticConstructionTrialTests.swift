import Foundation
import Testing
@testable import Peach

@Suite("CompletedChromaticConstructionTrial")
struct CompletedChromaticConstructionTrialTests {

    private func makeCompletedTrial(
        outerInterval: DirectedInterval = .up(.perfectFifth),
        offsets: [Cents]
    ) throws -> CompletedChromaticConstructionTrial {
        let path = try MonotonicPath().chromaticPath(
            lowerAnchor: MIDINote(60),
            outerInterval: outerInterval
        )
        var trial = ChromaticConstructionTrial(path: path)
        for offset in offsets {
            trial.place(offset: offset)
        }
        return CompletedChromaticConstructionTrial(trial: trial, timestamp: Date(timeIntervalSince1970: 0))
    }

    @Test("absoluteErrorCents is zero when placements match targets exactly")
    func zeroAbsoluteErrorOnExactPlacements() throws {
        let completed = try makeCompletedTrial(offsets: (1...6).map { Cents(Double($0) * 100.0) })
        for k in 1...6 {
            #expect(completed.absoluteErrorCents(at: k) == Cents(0))
        }
    }

    @Test("absoluteErrorCents returns magnitude regardless of placement sign relative to target")
    func absoluteErrorIsMagnitude() throws {
        // Target at slot 1 is 100¢; place at 95¢ → error 5¢. Slot 2 target 200¢; place at 210¢ → error 10¢.
        let completed = try makeCompletedTrial(offsets: [
            Cents(95.0),  Cents(210.0), Cents(300.0),
            Cents(400.0), Cents(500.0), Cents(600.0)
        ])
        #expect(completed.absoluteErrorCents(at: 1) == Cents(5.0))
        #expect(completed.absoluteErrorCents(at: 2) == Cents(10.0))
        #expect(completed.absoluteErrorCents(at: 3) == Cents(0))
    }

    @Test("relativeErrorCents at k=1 measures placed[0] against expected one-semitone step from 0")
    func relativeErrorFirstStep() throws {
        let completed = try makeCompletedTrial(offsets: [
            Cents(95.0),  Cents(195.0), Cents(295.0),
            Cents(395.0), Cents(495.0), Cents(595.0)
        ])
        // Expected step from 0 = +100¢; realized = +95¢ → error 5¢.
        #expect(completed.relativeErrorCents(at: 1) == Cents(5.0))
        // From slot 1 to slot 2 expected +100¢, realized 195 - 95 = 100 → error 0.
        #expect(completed.relativeErrorCents(at: 2) == Cents(0))
    }

    @Test("relativeErrorCents accumulates drift correctly when placements are consistent but offset")
    func relativeErrorOnConsistentDrift() throws {
        // Each step exactly +100¢, but starting placement is 50¢ instead of 100¢.
        let completed = try makeCompletedTrial(offsets: [
            Cents(50.0),  Cents(150.0), Cents(250.0),
            Cents(350.0), Cents(450.0), Cents(550.0)
        ])
        // First step: realized +50¢ vs expected +100¢ → 50¢ error.
        #expect(completed.relativeErrorCents(at: 1) == Cents(50.0))
        // Each subsequent step is exactly +100¢ → 0 error.
        for k in 2...6 {
            #expect(completed.relativeErrorCents(at: k) == Cents(0))
        }
    }

    @Test("relativeErrorCents uses signed expected step for descending paths")
    func relativeErrorForDescending() throws {
        // Descending P5: 7 .down steps, 6 interior positions. Expected step −100¢.
        let completed = try makeCompletedTrial(
            outerInterval: .down(.perfectFifth),
            offsets: (1...6).map { Cents(-Double($0) * 100.0) }
        )
        for k in 1...6 {
            #expect(completed.relativeErrorCents(at: k) == Cents(0))
        }
    }
}
