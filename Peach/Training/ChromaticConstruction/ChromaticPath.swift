import Foundation

/// A validated chromatic walk from a lower anchor MIDI note to an upper anchor,
/// expressed as a sequence of one-semitone direction steps.
///
/// The discipline is locked to one-semitone steps (12-TET). The cumulative
/// position at slot `k` is `lowerAnchor` displaced by the net signed step
/// count of the prefix `steps.prefix(k)`. Non-monotonic ("meandering") paths
/// are permitted as long as every intermediate MIDI value stays in
/// `MIDINote.validRange` and the net signed step count equals the declared
/// outer interval.
///
/// Only a `NextPathStrategy` should construct instances. The `init` is
/// `throws` because validation can fail; no defensive `precondition` in
/// callers — callers receive a typed throw.
struct ChromaticPath: Hashable, Sendable {
    let lowerAnchor: MIDINote
    let outerInterval: DirectedInterval
    let steps: [Direction]

    init(
        lowerAnchor: MIDINote,
        outerInterval: DirectedInterval,
        steps: [Direction]
    ) throws(ChromaticConstructionError) {
        guard steps.count >= 2 else {
            throw .degeneratePath(stepCount: steps.count)
        }

        let netSigned = Self.netSignedSteps(steps)
        let expectedNetSigned = outerInterval.signedSemitones
        guard netSigned == expectedNetSigned else {
            throw .pathDoesNotReachInterval(
                expectedNetSteps: expectedNetSigned,
                actualNetSteps: netSigned
            )
        }

        let (lowest, highest) = Self.midiBounds(lowerAnchor: lowerAnchor, steps: steps)
        guard MIDINote.validRange.contains(lowest), MIDINote.validRange.contains(highest) else {
            throw .pathExceedsMIDIRange(lowest: lowest, highest: highest)
        }

        self.lowerAnchor = lowerAnchor
        self.outerInterval = outerInterval
        self.steps = steps
    }

    /// The path's destination, derived from `lowerAnchor` and `outerInterval`.
    var upperAnchor: MIDINote { lowerAnchor.transposed(by: outerInterval) }

    /// Number of interior positions the user fills in. The final step lands on
    /// `upperAnchor`, which is not a slot — hence `steps.count - 1`.
    var interiorPositionCount: Int { steps.count - 1 }

    /// Cumulative signed semitone offset from `lowerAnchor` at 1-based slot `k`.
    /// Honors meandering paths by summing the prefix.
    func cumulativeSemitones(at k: Int) -> Int {
        Self.netSignedSteps(steps.prefix(k))
    }

    /// Target MIDI note at 1-based slot `k`.
    func targetMIDINote(at k: Int) -> MIDINote {
        MIDINote(lowerAnchor.rawValue + cumulativeSemitones(at: k))
    }

    /// Cumulative cent offset from `lowerAnchor` at 1-based slot `k`.
    func targetOffsetCents(at k: Int) -> Cents {
        Double(cumulativeSemitones(at: k)) * Cents.perSemitone
    }

    // MARK: - Helpers

    private static func netSignedSteps(_ steps: some Collection<Direction>) -> Int {
        steps.reduce(0) { $0 + ($1 == .up ? 1 : -1) }
    }

    private static func midiBounds(lowerAnchor: MIDINote, steps: [Direction]) -> (lowest: Int, highest: Int) {
        var current = lowerAnchor.rawValue
        var lowest = current
        var highest = current
        for step in steps {
            current += step == .up ? 1 : -1
            lowest = min(lowest, current)
            highest = max(highest, current)
        }
        return (lowest, highest)
    }
}

// MARK: - DirectedInterval signed semitones

private extension DirectedInterval {
    /// Signed semitone count: positive for ascending, negative for descending.
    var signedSemitones: Int {
        direction == .up ? interval.semitones : -interval.semitones
    }
}
