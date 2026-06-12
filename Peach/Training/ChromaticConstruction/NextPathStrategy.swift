/// Builds a `ChromaticPath` from high-level inputs.
///
/// The protocol surface is RNG-free. Strategies that need randomness hold it
/// as an implementation detail (matching the `NextPitchDiscriminationStrategy`
/// precedent — `KazezNoteStrategy` uses `Bool.random()` and
/// `MIDINote.random(in:)` with the implicit `SystemRandomNumberGenerator`,
/// no RNG parameter at the call site).
///
/// Stateless by contract. A future signature evolution may add a `profile`
/// parameter for difficulty-aware strategies; that addition is additive.
protocol NextPathStrategy: Sendable {
    func chromaticPath(
        lowerAnchor: MIDINote,
        outerInterval: DirectedInterval
    ) throws(ChromaticConstructionError) -> ChromaticPath
}
