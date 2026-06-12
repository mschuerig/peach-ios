import Testing
import Foundation
@testable import Peach

@Suite("Ladder Tests")
struct LadderTests {

    // MARK: - Valid construction — ascending P5

    @Test("Ascending P5 ladder constructs with slotCount = 6")
    func ascendingPerfectFifth() async throws {
        let ladder = try Ladder(
            lowerAnchor: Anchor(note: MIDINote(60)),
            upperAnchor: Anchor(note: MIDINote(67)),
            outerCents: Cents(700.0),
            path: Array(repeating: Direction.up, count: 7),
            targetStepCents: Cents(100.0),
            tuningSystem: .equalTemperament
        )
        // Interior slots only — upper anchor is fixed: slotCount = path.count - 1 = 6.
        #expect(ladder.slotCount == 6)
        #expect(ladder.lowerAnchor.note == MIDINote(60))
        #expect(ladder.upperAnchor.note == MIDINote(67))
        #expect(ladder.outerCents == Cents(700.0))
        #expect(ladder.targetStepCents == Cents(100.0))
        #expect(ladder.tuningSystem == .equalTemperament)
    }

    // MARK: - Valid construction — descending octave

    @Test("Descending octave ladder constructs with slotCount = 11")
    func descendingOctave() async throws {
        let ladder = try Ladder(
            lowerAnchor: Anchor(note: MIDINote(72)),
            upperAnchor: Anchor(note: MIDINote(60)),
            outerCents: Cents(-1200.0),
            path: Array(repeating: Direction.down, count: 12),
            targetStepCents: Cents(100.0),
            tuningSystem: .equalTemperament
        )
        #expect(ladder.slotCount == 11)
    }

    // MARK: - Tuning-system rejection

    @Test("Just intonation throws tuningSystemNotEqualTempered")
    func rejectJustIntonation() async {
        #expect(throws: ChromaticConstructionError.tuningSystemNotEqualTempered(.justIntonation)) {
            try Ladder(
                lowerAnchor: Anchor(note: MIDINote(60)),
                upperAnchor: Anchor(note: MIDINote(67)),
                outerCents: Cents(700.0),
                path: Array(repeating: Direction.up, count: 7),
                targetStepCents: Cents(100.0),
                tuningSystem: .justIntonation
            )
        }
    }

    // MARK: - Outer cents / anchor mismatch

    @Test("Outer cents not matching anchor span throws outerCentsMismatchesAnchors")
    func rejectOuterCentsMismatch() async {
        // C4 to G4 is P5 = 700 cents in 12-TET, but we declare 1200.
        #expect(throws: ChromaticConstructionError.outerCentsMismatchesAnchors(declared: Cents(1200.0), actual: Cents(700.0))) {
            try Ladder(
                lowerAnchor: Anchor(note: MIDINote(60)),
                upperAnchor: Anchor(note: MIDINote(67)),
                outerCents: Cents(1200.0),
                path: Array(repeating: Direction.up, count: 12),
                targetStepCents: Cents(100.0),
                tuningSystem: .equalTemperament
            )
        }
    }

    // MARK: - Path length mismatch

    @Test("Path length not matching outerCents / targetStep throws pathLengthMismatch")
    func rejectPathLengthMismatch() async {
        #expect(throws: ChromaticConstructionError.pathLengthMismatch(expected: 7, actual: 5)) {
            try Ladder(
                lowerAnchor: Anchor(note: MIDINote(60)),
                upperAnchor: Anchor(note: MIDINote(67)),
                outerCents: Cents(700.0),
                path: Array(repeating: Direction.up, count: 5),
                targetStepCents: Cents(100.0),
                tuningSystem: .equalTemperament
            )
        }
    }

    // MARK: - Non-monotonic path accepted

    @Test("Non-monotonic path with matching net span is accepted (ladder is meandering-ready)")
    func acceptNonMonotonicPath() async throws {
        // Net span: 3 up + 2 down = +1 up step net → 100 cents net.
        // Total step count = 5.
        let path: ChromaticPath = [.up, .down, .up, .down, .up]
        let ladder = try Ladder(
            lowerAnchor: Anchor(note: MIDINote(60)),
            upperAnchor: Anchor(note: MIDINote(61)),
            outerCents: Cents(100.0),
            path: path,
            targetStepCents: Cents(100.0),
            tuningSystem: .equalTemperament
        )
        // slotCount = path.count - 1 = 4 (slots between steps).
        #expect(ladder.slotCount == 4)
    }

    // MARK: - slotCount derivation

    @Test("slotCount returns path.count - 1")
    func slotCountDerivation() async throws {
        let ladder = try Ladder(
            lowerAnchor: Anchor(note: MIDINote(60)),
            upperAnchor: Anchor(note: MIDINote(64)),
            outerCents: Cents(400.0),
            path: Array(repeating: Direction.up, count: 4),
            targetStepCents: Cents(100.0),
            tuningSystem: .equalTemperament
        )
        #expect(ladder.slotCount == 3)
    }

    // MARK: - targetCents(forSlotIndex:)

    @Test("targetCents for ascending P5 slot 3 returns 300 cents (lower-anchor-relative)")
    func targetCentsAscending() async throws {
        let ladder = try Ladder(
            lowerAnchor: Anchor(note: MIDINote(60)),
            upperAnchor: Anchor(note: MIDINote(67)),
            outerCents: Cents(700.0),
            path: Array(repeating: Direction.up, count: 7),
            targetStepCents: Cents(100.0),
            tuningSystem: .equalTemperament
        )
        #expect(ladder.targetCents(forSlotIndex: 3) == Cents(300.0))
    }

    @Test("targetCents for descending octave slot 5 returns -500 cents")
    func targetCentsDescending() async throws {
        let ladder = try Ladder(
            lowerAnchor: Anchor(note: MIDINote(72)),
            upperAnchor: Anchor(note: MIDINote(60)),
            outerCents: Cents(-1200.0),
            path: Array(repeating: Direction.down, count: 12),
            targetStepCents: Cents(100.0),
            tuningSystem: .equalTemperament
        )
        #expect(ladder.targetCents(forSlotIndex: 5) == Cents(-500.0))
    }

    // MARK: - Q3 consultation: cent-step math invariants

    // (a) Direct multiplication, not recurrence.
    @Test("targetCents uses direct multiplication, not recurrent summation")
    func targetCentsIsDirectMultiplication() async throws {
        // A fractional target step where any recurrent summation would accumulate
        // floating-point error: 750 / 7 = 107.142857142857... cents per step.
        // The contract: targetCents(forSlotIndex: K) computes K * targetStepCents
        // by direct multiplication. A future refactor to recurrent summation
        // (sum of K * targetStepCents) would accumulate per-step rounding error
        // beyond the direct form; this test pins the direct-multiplication form
        // by asserting each slot's targetCents matches the freshly-computed
        // direct product to bit-exact equality.
        let ladder = Ladder.testFixture(
            lowerAnchor: Anchor(note: MIDINote(60)),
            outerCents: Cents(750.0),
            slotCount: 7,
            tuningSystem: .equalTemperament
        )
        for k in 1...7 {
            let direct = Cents(Double(k) * ladder.targetStepCents.rawValue)
            let computed = ladder.targetCents(forSlotIndex: k)
            #expect(computed == direct, "Slot \(k): expected direct-mult \(direct.rawValue), got \(computed.rawValue)")
        }
    }

    // (c) Sign symmetry between ascending and descending.
    @Test("Descending ladder targetCents are sign-symmetric with ascending")
    func descendingSignSymmetry() async throws {
        let ascending = try Ladder(
            lowerAnchor: Anchor(note: MIDINote(60)),
            upperAnchor: Anchor(note: MIDINote(72)),
            outerCents: Cents(1200.0),
            path: Array(repeating: Direction.up, count: 12),
            targetStepCents: Cents(100.0),
            tuningSystem: .equalTemperament
        )
        let descending = try Ladder(
            lowerAnchor: Anchor(note: MIDINote(72)),
            upperAnchor: Anchor(note: MIDINote(60)),
            outerCents: Cents(-1200.0),
            path: Array(repeating: Direction.down, count: 12),
            targetStepCents: Cents(100.0),
            tuningSystem: .equalTemperament
        )
        for k in 1...ascending.slotCount {
            let asc = ascending.targetCents(forSlotIndex: k)
            let desc = descending.targetCents(forSlotIndex: k)
            #expect(asc > Cents(0.0))
            #expect(desc < Cents(0.0))
            #expect(asc.magnitude == desc.magnitude)
        }
    }
}
