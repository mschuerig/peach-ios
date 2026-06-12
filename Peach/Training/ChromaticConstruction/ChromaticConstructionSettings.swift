import Foundation

/// Value-type snapshot of a chromatic-construction trial's parameterization.
/// Constructed via `from(...)` at the start of each trial; the screen calls
/// the factory again per trial (per the spec's `nextTrial()` → `start(...)`
/// loop), so a `.mix` policy resolves to a concrete direction per trial via
/// the injected RNG.
struct ChromaticConstructionSettings: Sendable {
    let ladder: Ladder
    let directionPolicy: ChromaticConstructionDirectionPolicy
    let referencePitch: Frequency

    /// Constructs settings for one trial. For `.ascending`/`.descending`, the
    /// direction is fixed. For `.mix`, the effective direction is resolved by
    /// rolling a coin via `rng`. The returned `directionPolicy` preserves the
    /// caller's intent (e.g. `.mix`) for documentation/UI purposes; the
    /// `ladder` is concrete.
    ///
    /// `lowerAnchor` is the user's chosen *starting* MIDI note. For an
    /// ascending walk it is the lower-pitched anchor and the destination
    /// (upperAnchor) is `lowerAnchor + semitones`. For a descending walk it
    /// is the higher-pitched anchor and the destination is
    /// `lowerAnchor - semitones`. In the constructed `Ladder`,
    /// `lowerAnchor`/`upperAnchor` denote *start*/*destination* (per
    /// `chromatic-construction-discipline-direction.md` § Core concepts),
    /// not pitch position — for descending walks, `lowerAnchor.note.rawValue
    /// > upperAnchor.note.rawValue`. `Ladder.init` accepts the relative
    /// pitch order; it validates `outerCents` matches the *signed* semitone
    /// span (`upperAnchor.rawValue - lowerAnchor.rawValue`).
    static func from<RNG: RandomNumberGenerator>(
        userSettings: any UserSettings,
        outerCents: Cents,
        lowerAnchor: MIDINote,
        directionPolicy: ChromaticConstructionDirectionPolicy,
        targetStepCents: Cents = Cents(100.0),
        rng: inout RNG
    ) throws(ChromaticConstructionError) -> ChromaticConstructionSettings {
        precondition(outerCents > Cents(0.0), "outerCents must be positive (factory derives sign from policy); got \(outerCents.rawValue)")
        precondition(targetStepCents > Cents(0.0), "targetStepCents must be positive; got \(targetStepCents.rawValue)")

        let effectiveDirection = Self.resolveEffectiveDirection(directionPolicy, rng: &rng)
        let semitones = Int((outerCents / targetStepCents).rounded())

        let lowerAnchorNote: MIDINote
        let upperAnchorNote: MIDINote
        let signedOuter: Cents
        let path: ChromaticPath
        switch effectiveDirection {
        case .ascending:
            lowerAnchorNote = lowerAnchor
            upperAnchorNote = MIDINote(lowerAnchor.rawValue + semitones)
            signedOuter = outerCents
            path = MonotonicAscendingPath().path(
                forOuterCents: signedOuter,
                targetStep: targetStepCents,
                rng: &rng
            )
        case .descending:
            // Model A: `lowerAnchor` is the start (higher pitch for descending);
            // `upperAnchor` is the destination (lower pitch). See spec change
            // log entry for 2026-06-12.
            lowerAnchorNote = lowerAnchor
            upperAnchorNote = MIDINote(lowerAnchor.rawValue - semitones)
            signedOuter = -outerCents
            path = MonotonicDescendingPath().path(
                forOuterCents: signedOuter,
                targetStep: targetStepCents,
                rng: &rng
            )
        case .mix:
            preconditionFailure("mix should have been resolved by resolveEffectiveDirection")
        }

        let ladder = try Ladder(
            lowerAnchor: Anchor(note: lowerAnchorNote),
            upperAnchor: Anchor(note: upperAnchorNote),
            outerCents: signedOuter,
            path: path,
            targetStepCents: targetStepCents,
            tuningSystem: userSettings.tuningSystem
        )

        return ChromaticConstructionSettings(
            ladder: ladder,
            directionPolicy: directionPolicy,
            referencePitch: userSettings.referencePitch
        )
    }

    /// Resolves `.mix` to a concrete `.ascending` / `.descending` via the RNG.
    /// `.ascending`/`.descending` pass through.
    private static func resolveEffectiveDirection<RNG: RandomNumberGenerator>(
        _ policy: ChromaticConstructionDirectionPolicy,
        rng: inout RNG
    ) -> ChromaticConstructionDirectionPolicy {
        switch policy {
        case .ascending, .descending:
            return policy
        case .mix:
            return Bool.random(using: &rng) ? .ascending : .descending
        }
    }
}
