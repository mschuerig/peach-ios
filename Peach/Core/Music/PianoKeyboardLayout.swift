import Foundation

/// Pure geometry for laying out a piano keyboard across a horizontal extent.
///
/// White keys are evenly distributed across `totalWidth`; black keys sit at the
/// midpoint between their two adjacent white keys. The layout is keyed by
/// pitch-class arithmetic (`MIDINote.rawValue % 12`), so it works for any
/// `NoteRange` whose endpoints fall on white keys at the extremes (A0–C8 in
/// practice for this app).
struct PianoKeyboardLayout: Hashable, Sendable {
    let noteRange: NoteRange

    nonisolated private static let whitePitchClasses: Set<Int> = [0, 2, 4, 5, 7, 9, 11]

    nonisolated static func isWhiteKey(_ note: MIDINote) -> Bool {
        whitePitchClasses.contains(note.rawValue % 12)
    }

    nonisolated static func isOctaveBoundary(_ note: MIDINote) -> Bool {
        note.rawValue % 12 == 0
    }

    var whiteKeyCount: Int {
        notes.lazy.filter { Self.isWhiteKey($0) }.count
    }

    func whiteKeyWidth(totalWidth: CGFloat) -> CGFloat {
        totalWidth / CGFloat(whiteKeyCount)
    }

    /// Centre x-position of `note`'s key within `totalWidth`.
    func xPosition(forNote note: MIDINote, totalWidth: CGFloat) -> CGFloat {
        let keyWidth = whiteKeyWidth(totalWidth: totalWidth)

        if Self.isWhiteKey(note) {
            let whiteIndex = notes.lazy
                .prefix(while: { $0 < note })
                .filter { Self.isWhiteKey($0) }
                .count
            return (CGFloat(whiteIndex) + 0.5) * keyWidth
        }

        let prevWhite = notes.lazy
            .prefix(while: { $0 < note })
            .reversed()
            .first(where: { Self.isWhiteKey($0) }) ?? noteRange.lowerBound
        let nextWhite = notes.lazy
            .drop(while: { $0 <= note })
            .first(where: { Self.isWhiteKey($0) }) ?? noteRange.upperBound

        let prevX = xPosition(forNote: prevWhite, totalWidth: totalWidth)
        let nextX = xPosition(forNote: nextWhite, totalWidth: totalWidth)
        return (prevX + nextX) / 2
    }

    /// Inverse of `xPosition`: returns the in-range note whose centre is nearest `x`.
    /// `x` outside `[0, totalWidth]` is clamped (returns the boundary note).
    func midiNote(at x: CGFloat, totalWidth: CGFloat) -> MIDINote {
        var best = noteRange.lowerBound
        var bestDistance = abs(xPosition(forNote: best, totalWidth: totalWidth) - x)
        for note in notes.dropFirst() {
            let distance = abs(xPosition(forNote: note, totalWidth: totalWidth) - x)
            if distance < bestDistance {
                best = note
                bestDistance = distance
            }
        }
        return best
    }

    var octaveBoundaries: [MIDINote] {
        notes.filter { Self.isOctaveBoundary($0) }
    }

    private var notes: [MIDINote] {
        (noteRange.lowerBound.rawValue...noteRange.upperBound.rawValue).map(MIDINote.init)
    }
}
