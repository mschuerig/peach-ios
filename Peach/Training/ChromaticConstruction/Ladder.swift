import Foundation

enum ChromaticConstructionError: Error, Equatable {
    case tuningSystemNotEqualTempered(TuningSystem)
    case outerCentsMismatchesAnchors(declared: Cents, actual: Cents)
    case pathLengthMismatch(expected: Int, actual: Int)
}

/// The trial structure for a chromatic-construction walk. Validates that the
/// tuning system is equal-tempered (the discipline is musically incoherent
/// otherwise — see `chromatic-construction-discipline-direction.md` §
/// Tuning-system constraint), that the declared `outerCents` matches the
/// span between anchors in 12-TET, and that `path.count == outerCents /
/// targetStepCents` in absolute value.
struct Ladder: Hashable, Sendable {
    let lowerAnchor: Anchor
    let upperAnchor: Anchor
    let outerCents: Cents
    let path: ChromaticPath
    let targetStepCents: Cents
    let tuningSystem: TuningSystem

    init(
        lowerAnchor: Anchor,
        upperAnchor: Anchor,
        outerCents: Cents,
        path: ChromaticPath,
        targetStepCents: Cents,
        tuningSystem: TuningSystem
    ) throws(ChromaticConstructionError) {
        guard tuningSystem == .equalTemperament else {
            throw .tuningSystemNotEqualTempered(tuningSystem)
        }

        // Anchor span in 12-TET: every semitone is exactly 100 cents.
        let semitoneSpan = upperAnchor.note.rawValue - lowerAnchor.note.rawValue
        let actualOuterCents = Double(semitoneSpan) * Cents.perSemitone
        guard actualOuterCents == outerCents else {
            throw .outerCentsMismatchesAnchors(declared: outerCents, actual: actualOuterCents)
        }

        // Validate that the path's net signed step count, multiplied by
        // targetStepCents, equals outerCents. This permits non-monotonic paths
        // (meandering-ready) — length is not enforced, only net span.
        let netSignedSteps = path.reduce(0) { partial, direction in
            partial + (direction == .up ? 1 : -1)
        }
        let requiredNetSteps = Int((outerCents / targetStepCents).rounded())
        guard netSignedSteps == requiredNetSteps else {
            // "expected" surfaces the monotonic-path length the caller most
            // likely intended; "actual" is the actual path length supplied.
            throw .pathLengthMismatch(expected: abs(requiredNetSteps), actual: path.count)
        }

        self.lowerAnchor = lowerAnchor
        self.upperAnchor = upperAnchor
        self.outerCents = outerCents
        self.path = path
        self.targetStepCents = targetStepCents
        self.tuningSystem = tuningSystem
    }

    /// Number of interior slots (between steps). The upper anchor is fixed,
    /// so the last step lands on it and is not a slot.
    var slotCount: Int {
        path.count - 1
    }

    /// Lower-anchor-relative target cents for the given slot index. Direct
    /// multiplication, NOT recurrent summation — recurrent summation would
    /// accumulate floating-point drift for fractional `targetStepCents`.
    ///
    /// Sign matches the walk direction: ascending paths produce positive
    /// values, descending paths produce negative values.
    func targetCents(forSlotIndex k: Int) -> Cents {
        let signedStep = outerCents < Cents(0.0) ? -targetStepCents.magnitude : targetStepCents.magnitude
        return Cents(Double(k) * signedStep)
    }
}

#if DEBUG
extension Ladder {
    /// Test-only fixture that bypasses production invariants — used by the
    /// fractional-step direct-multiplication test (Q3 (a) consultation). Do
    /// not call from production code.
    static func testFixture(
        lowerAnchor: Anchor,
        outerCents: Cents,
        slotCount: Int,
        tuningSystem: TuningSystem
    ) -> Ladder {
        Ladder(
            lowerAnchor: lowerAnchor,
            upperAnchor: lowerAnchor, // upper anchor unused by the targeted assertion
            outerCents: outerCents,
            path: Array(repeating: outerCents < Cents(0.0) ? Direction.down : Direction.up, count: slotCount),
            targetStepCents: outerCents / Double(slotCount),
            tuningSystem: tuningSystem,
            unsafelyBypassingInvariants: ()
        )
    }

    /// Memberwise bypass for the test fixture above. The `()` discriminator
    /// keeps this initializer out of normal call-completion.
    fileprivate init(
        lowerAnchor: Anchor,
        upperAnchor: Anchor,
        outerCents: Cents,
        path: ChromaticPath,
        targetStepCents: Cents,
        tuningSystem: TuningSystem,
        unsafelyBypassingInvariants: Void
    ) {
        self.lowerAnchor = lowerAnchor
        self.upperAnchor = upperAnchor
        self.outerCents = outerCents
        self.path = path
        self.targetStepCents = targetStepCents
        self.tuningSystem = tuningSystem
    }
}
#endif
