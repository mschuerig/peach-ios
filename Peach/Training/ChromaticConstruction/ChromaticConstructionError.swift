/// Errors thrown by `ChromaticPath.init`.
///
/// All three conditions are validations on the path's geometry against the
/// declared `lowerAnchor` and `outerInterval`. There are no tuning-system
/// errors: the discipline is implicitly equal-tempered. There are no
/// target-step errors: the step is always one semitone in this discipline.
enum ChromaticConstructionError: Error, Equatable {
    /// The path has fewer than two step elements, leaving no interior
    /// position for the user to place.
    case degeneratePath(stepCount: Int)

    /// The net signed step count does not match the declared outer interval.
    case pathDoesNotReachInterval(expectedNetSteps: Int, actualNetSteps: Int)

    /// The path visits a MIDI value outside `MIDINote.validRange` at some
    /// intermediate position.
    case pathExceedsMIDIRange(lowest: Int, highest: Int)
}
