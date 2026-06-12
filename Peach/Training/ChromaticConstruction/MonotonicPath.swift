/// Builds a monotonic chromatic path: all steps go the same direction, as
/// encoded in the supplied `outerInterval`.
///
/// Stateless. Direction is a property of `outerInterval`, not of the strategy;
/// the same strategy serves both ascending and descending trials. When the
/// session wants to randomize per trial, it does so by drawing the
/// `outerInterval` from a `Set<DirectedInterval>` in the settings (mirroring
/// `PitchDiscriminationSession`'s `settings.intervals.randomElement()`
/// pattern).
struct MonotonicPath: NextPathStrategy {
    func chromaticPath(
        lowerAnchor: MIDINote,
        outerInterval: DirectedInterval
    ) throws(ChromaticConstructionError) -> ChromaticPath {
        let steps = Array(repeating: outerInterval.direction, count: outerInterval.interval.semitones)
        return try ChromaticPath(
            lowerAnchor: lowerAnchor,
            outerInterval: outerInterval,
            steps: steps
        )
    }
}
