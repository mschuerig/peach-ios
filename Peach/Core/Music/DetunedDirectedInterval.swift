/// A directed interval with a microtonal cent offset — a logical interval
/// identity, the interval-world sibling of `DetunedMIDINote`.
///
/// The offset is in pitch space, applied to the interval's far tone:
/// positive always means the far tone sounds sharper. For descending
/// intervals this is NOT interval-width space — a positive offset on a
/// descending fifth raises the far tone and *narrows* the interval.
///
/// Carries no frequency or tuning knowledge. To convert to a sounding
/// frequency, pass it through the explicit bridge:
/// `TuningSystem.frequency(for:from:referencePitch:)`.
nonisolated struct DetunedDirectedInterval: Hashable, Sendable {
    let interval: DirectedInterval
    let offset: Cents

    init(interval: DirectedInterval, offset: Cents) {
        self.interval = interval
        self.offset = offset
    }

    init(_ interval: DirectedInterval) {
        self.init(interval: interval, offset: Cents(0))
    }
}
