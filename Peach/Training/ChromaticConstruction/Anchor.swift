import Foundation

/// A pitched note at one end of a chromatic-construction ladder. Anchors are
/// fixed for a trial and always tappable for playback — they are the only
/// ground truth the user has during the walk.
struct Anchor: Hashable, Sendable {
    let note: MIDINote

    func frequency(in tuningSystem: TuningSystem, referencePitch: Frequency) -> Frequency {
        tuningSystem.frequency(for: note, referencePitch: referencePitch)
    }
}
