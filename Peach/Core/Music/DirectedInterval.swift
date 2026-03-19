import Foundation

struct DirectedInterval: Hashable, Comparable, Sendable, Codable {
    let interval: Interval
    let direction: Direction

    var displayName: String {
        if interval == .prime { return interval.name }
        return "\(interval.name) \(direction.displayName)"
    }

    // MARK: - Static Factories

    static let prime = DirectedInterval(interval: .prime, direction: .up)

    static func up(_ interval: Interval) -> DirectedInterval {
        DirectedInterval(interval: interval, direction: .up)
    }

    static func down(_ interval: Interval) -> DirectedInterval {
        if interval == .prime { return .prime }
        return DirectedInterval(interval: interval, direction: .down)
    }

    // MARK: - Comparable

    static func < (lhs: DirectedInterval, rhs: DirectedInterval) -> Bool {
        if lhs.interval != rhs.interval { return lhs.interval < rhs.interval }
        return lhs.direction < rhs.direction
    }

    // MARK: - Between

    static func between(_ reference: MIDINote, _ target: MIDINote) throws -> DirectedInterval {
        let interval = try Interval.between(reference, target)
        let direction: Direction = target.rawValue >= reference.rawValue ? .up : .down
        return DirectedInterval(interval: interval, direction: direction)
    }
}

// MARK: - MIDINote Transposition

extension MIDINote {
    func transposed(by directedInterval: DirectedInterval) -> MIDINote {
        let delta = directedInterval.direction == .up
            ? directedInterval.interval.semitones
            : -directedInterval.interval.semitones
        let newValue = rawValue + delta
        precondition(Self.validRange.contains(newValue),
            "Transposed note \(newValue) out of MIDI range 0-127")
        return MIDINote(newValue)
    }
}
